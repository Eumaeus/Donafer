# src/MorphDrill/QuizBuilder.jl

module QuizBuilder

using TOML
using Random

const DataParser   = parentmodule(@__MODULE__).DataParser
const ItemSelector = parentmodule(@__MODULE__).ItemSelector
const QuestionBuilder = parentmodule(@__MODULE__).QuestionBuilder

using .DataParser: MorphForm, parse_morphology_forms
using .ItemSelector: select_morph_forms
using .QuestionBuilder: Question, build_question, to_gift

export MorphDrillConfig, load_config, build_morph_drill, write_gift_file

Base.@kwdef struct MorphDrillConfig
    chapters_file::String = "data/morphology/chapters/hq.tsv"
    from_chapter::Int = 1
    current_chapter::Int = 4
    num_questions::Int = 80
    random_seed::Union{Int, Nothing} = nothing
    output_directory::String = "generated/morph"
    output_filename_prefix::String = "morph_drill_hq"

    include_categories::Vector{String} = ["noun", "pronoun", "adjective", "verb", "participle"]
    distracter_mode::String = "all"
    number_choices::Int = 5
    active_knowledge_fraction::Float64 = 0.5
    include_vocative::Bool = false
    include_dual::Bool = false

    category_prefix::String = "Morphology/HansenQuinn"
    verbose::Bool = true
end

function load_config(path::String = "config/morph_drill.toml")::MorphDrillConfig
    if !isfile(path)
        error("Config file not found: $path")
    end
    raw = TOML.parsefile(path)

    general = get(raw, "general", Dict())
    selection = get(raw, "selection", Dict())
    moodle = get(raw, "moodle", Dict())
    debug = get(raw, "debug", Dict())

    seed = get(general, "random_seed", nothing)
    if seed isa AbstractString && lowercase(seed) in ("null", "none", "")
        seed = nothing
    end

    return MorphDrillConfig(
        chapters_file = get(general, "chapters_file", "data/morphology/chapters/hq.tsv"),
        from_chapter = get(general, "from_chapter", 1),
        current_chapter = get(general, "current_chapter", 4),
        num_questions = get(general, "num_questions", 80),
        random_seed = seed,
        output_directory = get(general, "output_directory", "generated/morph"),
        output_filename_prefix = get(general, "output_filename_prefix", "morph_drill_hq"),

        include_categories = get(selection, "include_categories",
                                 ["noun", "pronoun", "adjective", "verb", "participle"]),
        distracter_mode = get(selection, "distracter_mode", "all"),
        number_choices = get(selection, "number_choices", 5),
        active_knowledge_fraction = get(selection, "active_knowledge_fraction", 0.5),
        include_vocative = get(selection, "include_vocative", false),
        include_dual = get(selection, "include_dual", false),

        category_prefix = get(moodle, "category_prefix", "Morphology/HansenQuinn"),
        verbose = get(debug, "verbose", true),
    )
end

function build_morph_drill(config_path::String = "config/morph_drill.toml";
                           current_chapter::Union{Int, Nothing} = nothing,
                           num_questions::Union{Int, Nothing} = nothing,
                           categories::Union{String, Nothing} = nothing)::String

    cfg = load_config(config_path)

    # Apply overrides
    overrides = Dict{Symbol, Any}()
    if current_chapter !== nothing
        overrides[:current_chapter] = current_chapter
    end
    if num_questions !== nothing
        overrides[:num_questions] = num_questions
    end
    if categories !== nothing
        overrides[:include_categories] = split(categories, r"[,;]\s*")
    end

    if !isempty(overrides)
        cfg = MorphDrillConfig(;
            (k => getfield(cfg, k) for k in fieldnames(MorphDrillConfig))...,
            overrides...
        )
    end

    if cfg.verbose
        println("Loading morphology config from: $config_path")
        println("Chapters: $(cfg.from_chapter)–$(cfg.current_chapter)")
        println("Categories: $(cfg.include_categories)")
        println("Questions: $(cfg.num_questions)")
        println("Distracter mode: $(cfg.distracter_mode)")
    end

    all_forms = parse_morphology_forms(
        cfg.chapters_file,
        "data/morphology/forms",
        cfg.include_categories,
        cfg.from_chapter,
        cfg.current_chapter,
        cfg.include_vocative,
        cfg.include_dual
    )

    if cfg.verbose
        println("Parsed $(length(all_forms)) morphological forms")
    end

    selected = select_morph_forms(all_forms;
                                  num_questions = cfg.num_questions,
                                  seed = cfg.random_seed)

    if cfg.verbose
        println("Selected $(length(selected)) forms for the drill")
    end

    rng = cfg.random_seed === nothing ? Random.default_rng() : MersenneTwister(cfg.random_seed)

    questions = Question[]
    for form in selected
        direction = rand(rng) < cfg.active_knowledge_fraction ? :active : :passive
        q = build_question(form, all_forms;
                           direction = direction,
                           num_choices = cfg.number_choices,
                           distracter_mode = cfg.distracter_mode,
                           rng = rng)
        push!(questions, q)
    end

    if cfg.verbose
        multi = count(q -> length(q.correct_answers) > 1, questions)
        println("Built $(length(questions)) questions ($multi multi-correct)")
    end

    mkpath(cfg.output_directory)
    filename = "$(cfg.output_filename_prefix)_ch$(cfg.current_chapter).gift"
    output_path = joinpath(cfg.output_directory, filename)

    write_gift_file(questions, output_path;
                    category = "$(cfg.category_prefix)/Ch$(cfg.current_chapter)")

    if cfg.verbose
        println("Wrote GIFT file: $output_path")
    end

    return output_path
end

function write_gift_file(questions::Vector{Question}, path::String; category::String = "")
    open(path, "w") do io
        if !isempty(category)
            println(io, "\$CATEGORY: $category")
            println(io)
        end
        for (i, q) in enumerate(questions)
            gift = to_gift(q; qid = "Q$(lpad(i, 3, '0'))")
            println(io, gift)
            println(io)
        end
    end
end

end # module QuizBuilder