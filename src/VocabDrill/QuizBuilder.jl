# src/VocabDrill/QuizBuilder.jl

module QuizBuilder

using TOML
using Random

# Robust access to sibling modules
const DataParser   = parentmodule(@__MODULE__).DataParser
const ItemSelector = parentmodule(@__MODULE__).ItemSelector
const QuestionBuilder = parentmodule(@__MODULE__).QuestionBuilder

using .DataParser: parse_vocabulary_file, VocabItem
using .ItemSelector: select_quiz_items, SelectionResult
using .QuestionBuilder: Question, build_question, to_gift

export DrillConfig, load_config, build_vocab_drill, write_gift_file

# ============================================================
# Configuration
# ============================================================

"""
    DrillConfig

Holds all settings loaded from vocab_drill.toml
"""
Base.@kwdef struct DrillConfig
    # [general]
    data_source::String = "data/vocabulary/hq.txt"
    current_chapter::Int = 1
    num_questions::Int = 50
    random_seed::Union{Int, Nothing} = nothing
    output_directory::String = "generated/vocab"
    output_filename_prefix::String = "vocab_drill"

    # [proportions]
    active_to_passive_ratio::Float64 = 0.5
    current_chapter_fraction::Float64 = 0.6

    # [question]
    num_choices::Int = 5
    prefer_same_category_distractors::Bool = true   # (currently informational)

    # [moodle]
    category_prefix::String = "Vocabulary/HansenQuinn"

    # [debug]
    verbose::Bool = false
end

function load_config(path::String = "config/vocab_drill.toml")::DrillConfig
    if !isfile(path)
        error("Config file not found: $path")
    end

    raw = TOML.parsefile(path)

    general = get(raw, "general", Dict())
    proportions = get(raw, "proportions", Dict())
    question = get(raw, "question", Dict())
    moodle = get(raw, "moodle", Dict())
    debug = get(raw, "debug", Dict())

    seed = get(general, "random_seed", nothing)
    if seed isa AbstractString && lowercase(seed) in ("null", "none", "")
        seed = nothing
    end

    return DrillConfig(
        data_source                  = get(general, "data_source", "data/vocabulary/hq.txt"),
        current_chapter              = get(general, "current_chapter", 1),
        num_questions                = get(general, "num_questions", 50),
        random_seed                  = seed,
        output_directory             = get(general, "output_directory", "generated/vocab"),
        output_filename_prefix       = get(general, "output_filename_prefix", "vocab_drill"),

        active_to_passive_ratio      = get(proportions, "active_to_passive_ratio", 0.5),
        current_chapter_fraction     = get(proportions, "current_chapter_fraction", 0.6),

        num_choices                  = get(question, "num_choices", 5),
        prefer_same_category_distractors = get(question, "prefer_same_category_distractors", true),

        category_prefix              = get(moodle, "category_prefix", "Vocabulary/HansenQuinn"),

        verbose                      = get(debug, "verbose", false),
    )
end

# ============================================================
# Main Quiz Builder
# ============================================================

"""
    build_vocab_drill(config_path; current_chapter, num_questions)

Main entry point for generating a vocabulary drill.
Accepts either a config path or keyword overrides.
"""
function build_vocab_drill(config_path::String = "config/vocab_drill.toml";
                           current_chapter::Union{Int, Nothing} = nothing,
                           num_questions::Union{Int, Nothing} = nothing)::String

    cfg = load_config(config_path)

    # Apply command-line / keyword overrides
    if current_chapter !== nothing
        cfg = DrillConfig(;
            (k => getfield(cfg, k) for k in fieldnames(DrillConfig))...,
            current_chapter = current_chapter
        )
    end

    if num_questions !== nothing
        cfg = DrillConfig(;
            (k => getfield(cfg, k) for k in fieldnames(DrillConfig))...,
            num_questions = num_questions
        )
    end

    if cfg.verbose
        println("Loading configuration from: $config_path")
        println("Current chapter: $(cfg.current_chapter)")
        println("Total questions: $(cfg.num_questions)")
    end

    # 1. Parse vocabulary
    all_items = parse_vocabulary_file(cfg.data_source)
    if cfg.verbose
        println("Parsed $(length(all_items)) vocabulary items from $(cfg.data_source)")
    end

    # 2. Select items
    selection = select_quiz_items(
        all_items;
        current_chapter = cfg.current_chapter,
        num_questions = cfg.num_questions,
        current_chapter_fraction = cfg.current_chapter_fraction,
        seed = cfg.random_seed
    )

    if cfg.verbose
        println("Selected $(length(selection.items)) items " *
                "($(selection.num_current) current chapter, $(selection.num_review) review)")
    end

    # 3. Build questions
    rng = cfg.random_seed === nothing ? Random.default_rng() : MersenneTwister(cfg.random_seed)

    questions = Question[]
    for item in selection.items
        direction = rand(rng) < cfg.active_to_passive_ratio ? 
                    :greek_to_english : :english_to_greek

        q = build_question(
            item, 
            all_items;
            direction = direction,
            num_choices = cfg.num_choices,
            rng = rng
        )
        push!(questions, q)
    end

    if cfg.verbose
        multi_correct_count = count(q -> length(q.correct_answers) > 1, questions)
        println("Built $(length(questions)) questions ($multi_correct_count multi-correct)")
    end

    # 4. Write GIFT file (filename includes chapter)
    mkpath(cfg.output_directory)
    filename = "$(cfg.output_filename_prefix)_ch$(cfg.current_chapter).gift"
    output_path = joinpath(cfg.output_directory, filename)

    write_gift_file(questions, output_path; 
                    category = "$(cfg.category_prefix)/$(cfg.current_chapter)")

    if cfg.verbose
        println("Wrote GIFT file to: $output_path")
    end

    return output_path
end

"""
    write_gift_file(questions::Vector{Question}, path::String; category::String = "")

Writes questions in GIFT format with an optional Moodle category header.
"""
function write_gift_file(questions::Vector{Question}, path::String; category::String = "")
    open(path, "w") do io
        if !isempty(category)
            println(io, "\$CATEGORY: $category")
            println(io)
        end

        for (i, q) in enumerate(questions)
            gift = to_gift(q; qid = "Q$(lpad(i, 3, '0'))")
            println(io, gift)
            println(io)  # blank line between questions
        end
    end
end

end # module QuizBuilder