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
using .QuestionBuilder: Question, build_question, to_gift,
                        build_pp_meaning_question, build_pp_forms_question

export DrillConfig, load_config, build_vocab_drill, write_gift_file,
       pp_meaning_question_count, pp_forms_question_count

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

    # [selection]
    include_categories::Vector{String} = String[]

    # [proportions]
    active_to_passive_ratio::Float64 = 0.5
    current_chapter_fraction::Float64 = 0.6
    pp_id_fraction::Float64 = 0.0
    pp_number_to_form_fraction::Float64 = 0.5
    # Lemma-independent “what each PP is” family. Effective count =
    # min(pp_meaning_max_count, floor(num_questions * pp_meaning_fraction)).
    # Fraction 0.0 disables the family (default; does not flood classic drills).
    pp_meaning_fraction::Float64 = 0.0
    pp_meaning_max_count::Int = 6
    # Within PP-meaning items: number→gloss vs gloss→number.
    pp_meaning_number_to_gloss_fraction::Float64 = 0.5
    # Lemma-independent “which forms come from which PP” family.
    # Same budget style as PP-meaning; fraction 0.0 disables (default).
    pp_forms_fraction::Float64 = 0.0
    pp_forms_max_count::Int = 6
    # Within PP-forms items: PP→paradigm vs paradigm→PP.
    pp_forms_pp_to_paradigm_fraction::Float64 = 0.5

    # [question]
    num_choices::Int = 5
    prefer_same_category_distractors::Bool = true   # (currently informational)
    # Normalized edit-distance similarity floor for PP form distractors
    # (1 - levenshtein / max_len). Used after same-verb PPs are exhausted.
    pp_form_similarity_threshold::Float64 = 0.45

    # [moodle]
    category_prefix::String = "Vocabulary/HansenQuinn"

    # [debug]
    verbose::Bool = false
end

function _as_string_vector(val)::Vector{String}
    val === nothing && return String[]
    if val isa AbstractVector
        return String[String(strip(string(x))) for x in val if !isempty(strip(string(x)))]
    end
    s = strip(string(val))
    isempty(s) && return String[]
    return String[String(strip(p)) for p in split(s, r"[,;]") if !isempty(strip(p))]
end

function load_config(path::String = "config/vocab_drill.toml")::DrillConfig
    if !isfile(path)
        error("Config file not found: $path")
    end

    raw = TOML.parsefile(path)

    general = get(raw, "general", Dict())
    selection = get(raw, "selection", Dict())
    proportions = get(raw, "proportions", Dict())
    question = get(raw, "question", Dict())
    moodle = get(raw, "moodle", Dict())
    debug = get(raw, "debug", Dict())

    seed = get(general, "random_seed", nothing)
    if seed isa AbstractString && lowercase(seed) in ("null", "none", "")
        seed = nothing
    end

    # Categories may live under [selection] (preferred) or [general] for older drafts.
    categories = get(selection, "include_categories",
                     get(general, "include_categories", String[]))

    return DrillConfig(
        data_source                  = get(general, "data_source", "data/vocabulary/hq.txt"),
        current_chapter              = get(general, "current_chapter", 1),
        num_questions                = get(general, "num_questions", 50),
        random_seed                  = seed,
        output_directory             = get(general, "output_directory", "generated/vocab"),
        output_filename_prefix       = get(general, "output_filename_prefix", "vocab_drill"),

        include_categories           = _as_string_vector(categories),

        active_to_passive_ratio      = get(proportions, "active_to_passive_ratio", 0.5),
        current_chapter_fraction     = get(proportions, "current_chapter_fraction", 0.6),
        pp_id_fraction               = get(proportions, "pp_id_fraction", 0.0),
        pp_number_to_form_fraction   = get(proportions, "pp_number_to_form_fraction", 0.5),
        pp_meaning_fraction          = get(proportions, "pp_meaning_fraction", 0.0),
        pp_meaning_max_count         = Int(get(proportions, "pp_meaning_max_count", 6)),
        pp_meaning_number_to_gloss_fraction =
            get(proportions, "pp_meaning_number_to_gloss_fraction", 0.5),
        pp_forms_fraction            = get(proportions, "pp_forms_fraction", 0.0),
        pp_forms_max_count           = Int(get(proportions, "pp_forms_max_count", 6)),
        pp_forms_pp_to_paradigm_fraction =
            get(proportions, "pp_forms_pp_to_paradigm_fraction", 0.5),

        num_choices                  = get(question, "num_choices", 5),
        prefer_same_category_distractors = get(question, "prefer_same_category_distractors", true),
        pp_form_similarity_threshold = get(question, "pp_form_similarity_threshold", 0.45),

        category_prefix              = get(moodle, "category_prefix", "Vocabulary/HansenQuinn"),

        verbose                      = get(debug, "verbose", false),
    )
end

function _with_overrides(cfg::DrillConfig; kwargs...)::DrillConfig
    isempty(kwargs) && return cfg
    overrides = Dict{Symbol, Any}(kwargs)
    return DrillConfig(;
        (k => get(overrides, k, getfield(cfg, k)) for k in fieldnames(DrillConfig))...
    )
end

# ============================================================
# Main Quiz Builder
# ============================================================

"""
    pp_meaning_question_count(cfg) -> Int

How many lemma-independent “what each PP is” questions to inject.
`min(pp_meaning_max_count, floor(num_questions * pp_meaning_fraction))`,
or 0 when the fraction is ≤ 0.
"""
function pp_meaning_question_count(cfg::DrillConfig)::Int
    cfg.pp_meaning_fraction <= 0 && return 0
    cfg.pp_meaning_max_count <= 0 && return 0
    target = Int(floor(cfg.num_questions * cfg.pp_meaning_fraction))
    return clamp(target, 0, min(cfg.pp_meaning_max_count, cfg.num_questions))
end

"""
    pp_forms_question_count(cfg) -> Int

How many lemma-independent “forms from PP” questions to inject.
`min(pp_forms_max_count, floor(num_questions * pp_forms_fraction))`,
or 0 when the fraction is ≤ 0.
"""
function pp_forms_question_count(cfg::DrillConfig)::Int
    cfg.pp_forms_fraction <= 0 && return 0
    cfg.pp_forms_max_count <= 0 && return 0
    target = Int(floor(cfg.num_questions * cfg.pp_forms_fraction))
    return clamp(target, 0, min(cfg.pp_forms_max_count, cfg.num_questions))
end

"""
Clamp independent meta-family budgets so meaning + forms never exceed the quiz size.
Meaning is reserved first; forms take whatever remains under the total.
"""
function _meta_question_budgets(cfg::DrillConfig)::Tuple{Int, Int}
    meaning_count = pp_meaning_question_count(cfg)
    forms_count = pp_forms_question_count(cfg)
    remaining = max(cfg.num_questions - meaning_count, 0)
    forms_count = min(forms_count, remaining)
    return meaning_count, forms_count
end

"""
    build_vocab_drill(config_path; current_chapter, num_questions, include_categories,
                      pp_id_fraction, pp_meaning_fraction, pp_meaning_max_count,
                      pp_forms_fraction, pp_forms_max_count)

Main entry point for generating a vocabulary drill.
Accepts either a config path or keyword overrides.
"""
function build_vocab_drill(config_path::String = "config/vocab_drill.toml";
                           current_chapter::Union{Int, Nothing} = nothing,
                           num_questions::Union{Int, Nothing} = nothing,
                           include_categories::Union{Nothing, Vector{String}, AbstractString} = nothing,
                           pp_id_fraction::Union{Float64, Nothing} = nothing,
                           pp_meaning_fraction::Union{Float64, Nothing} = nothing,
                           pp_meaning_max_count::Union{Int, Nothing} = nothing,
                           pp_forms_fraction::Union{Float64, Nothing} = nothing,
                           pp_forms_max_count::Union{Int, Nothing} = nothing)::String

    cfg = load_config(config_path)

    overrides = Dict{Symbol, Any}()
    if current_chapter !== nothing
        overrides[:current_chapter] = current_chapter
    end
    if num_questions !== nothing
        overrides[:num_questions] = num_questions
    end
    if include_categories !== nothing
        overrides[:include_categories] = _as_string_vector(include_categories)
    end
    if pp_id_fraction !== nothing
        overrides[:pp_id_fraction] = pp_id_fraction
    end
    if pp_meaning_fraction !== nothing
        overrides[:pp_meaning_fraction] = pp_meaning_fraction
    end
    if pp_meaning_max_count !== nothing
        overrides[:pp_meaning_max_count] = pp_meaning_max_count
    end
    if pp_forms_fraction !== nothing
        overrides[:pp_forms_fraction] = pp_forms_fraction
    end
    if pp_forms_max_count !== nothing
        overrides[:pp_forms_max_count] = pp_forms_max_count
    end
    cfg = _with_overrides(cfg; overrides...)

    meaning_count, forms_count = _meta_question_budgets(cfg)
    lemma_question_count = max(cfg.num_questions - meaning_count - forms_count, 0)

    if cfg.verbose
        println("Loading configuration from: $config_path")
        println("Current chapter: $(cfg.current_chapter)")
        println("Total questions: $(cfg.num_questions)")
        println("Categories: $(isempty(cfg.include_categories) ? "all" : cfg.include_categories)")
        println("PP-ID fraction: $(cfg.pp_id_fraction)")
        println("PP-meaning count: $meaning_count " *
                "(fraction=$(cfg.pp_meaning_fraction), max=$(cfg.pp_meaning_max_count))")
        println("PP-forms count: $forms_count " *
                "(fraction=$(cfg.pp_forms_fraction), max=$(cfg.pp_forms_max_count))")
        println("Choices per question: $(cfg.num_choices)")
    end

    # 1. Parse vocabulary
    all_items = parse_vocabulary_file(cfg.data_source)
    if cfg.verbose
        println("Parsed $(length(all_items)) vocabulary items from $(cfg.data_source)")
    end

    # Pool used for distractors / PP lookup: respect category filter when set.
    question_pool = if isempty(cfg.include_categories)
        all_items
    else
        filter(i -> i.category in cfg.include_categories, all_items)
    end

    # 2. Select lemma-based items (meta PP slots are filled separately)
    selection = select_quiz_items(
        all_items;
        current_chapter = cfg.current_chapter,
        num_questions = lemma_question_count,
        current_chapter_fraction = cfg.current_chapter_fraction,
        include_categories = cfg.include_categories,
        seed = cfg.random_seed
    )

    if cfg.verbose
        println("Selected $(length(selection.items)) lemma items " *
                "($(selection.num_current) current chapter, $(selection.num_review) review) " *
                "+ $meaning_count PP-meaning + $forms_count PP-forms")
    end

    # 3. Build questions
    rng = cfg.random_seed === nothing ? Random.default_rng() : MersenneTwister(cfg.random_seed)

    questions = Question[]
    for item in selection.items
        direction = choose_direction(item, cfg, rng)

        q = build_question(
            item,
            question_pool;
            direction = direction,
            num_choices = cfg.num_choices,
            rng = rng,
            pp_form_similarity_threshold = cfg.pp_form_similarity_threshold,
            max_chapter = cfg.current_chapter,
        )
        push!(questions, q)
    end

    # 3b. Inject lemma-independent meta questions (both directions)
    append!(questions, build_pp_meaning_questions(cfg, meaning_count, rng))
    append!(questions, build_pp_forms_questions(cfg, forms_count, rng))

    # Keep meta items mixed through the quiz rather than clumped at the end.
    (meaning_count > 0 || forms_count > 0) && shuffle!(rng, questions)

    if cfg.verbose
        multi_correct_count = count(q -> length(q.correct_answers) > 1, questions)
        pp_id_count = count(q -> startswith(q.stem, "Pick the") ||
                                 (startswith(q.stem, "Which Principal Part of")), questions)
        pp_mean_count = count(q -> q.category == "pp_meaning", questions)
        pp_forms_n = count(q -> q.category == "pp_forms", questions)
        println("Built $(length(questions)) questions " *
                "($multi_correct_count multi-correct, $pp_id_count PP-ID, " *
                "$pp_mean_count PP-meaning, $pp_forms_n PP-forms)")
    end

    # 4. Write GIFT file (filename includes chapter)
    mkpath(cfg.output_directory)
    suffix = isempty(cfg.include_categories) ? "" :
             "_" * join(cfg.include_categories, "-")
    pp_tag = (cfg.pp_id_fraction > 0 || meaning_count > 0 || forms_count > 0) ? "_pp" : ""
    meaning_tag = meaning_count > 0 ? "m" : ""
    forms_tag = forms_count > 0 ? "f" : ""
    filename = "$(cfg.output_filename_prefix)_ch$(cfg.current_chapter)$(suffix)$(pp_tag)$(meaning_tag)$(forms_tag).gift"
    output_path = joinpath(cfg.output_directory, filename)

    cat_suffix = isempty(cfg.include_categories) ? string(cfg.current_chapter) :
                 "$(cfg.current_chapter)/$(join(cfg.include_categories, "-"))"
    write_gift_file(questions, output_path;
                    category = "$(cfg.category_prefix)/$(cat_suffix)")

    if cfg.verbose
        println("Wrote GIFT file to: $output_path")
    end

    return output_path
end

"""
Build `count` lemma-independent PP-meaning questions, cycling through PP 1–6
and splitting directions by `pp_meaning_number_to_gloss_fraction`.
"""
function build_pp_meaning_questions(cfg::DrillConfig, count::Int, rng)::Vector{Question}
    count <= 0 && return Question[]
    questions = Question[]
    # Prefer covering all six parts before repeating.
    order = Int[]
    while length(order) < count
        append!(order, shuffle(rng, collect(1:6)))
    end
    resize!(order, count)

    for pp_num in order
        direction = rand(rng) < cfg.pp_meaning_number_to_gloss_fraction ?
                    :pp_meaning_number_to_gloss : :pp_meaning_gloss_to_number
        push!(questions, build_pp_meaning_question(
            pp_num;
            direction = direction,
            num_choices = cfg.num_choices,
            rng = rng,
            chapter = cfg.current_chapter,
        ))
    end
    return questions
end

"""
Build `count` lemma-independent PP-forms questions, cycling through PP 1–6
and splitting directions by `pp_forms_pp_to_paradigm_fraction`.
"""
function build_pp_forms_questions(cfg::DrillConfig, count::Int, rng)::Vector{Question}
    count <= 0 && return Question[]
    questions = Question[]
    order = Int[]
    while length(order) < count
        append!(order, shuffle(rng, collect(1:6)))
    end
    resize!(order, count)

    for pp_num in order
        direction = rand(rng) < cfg.pp_forms_pp_to_paradigm_fraction ?
                    :pp_forms_pp_to_paradigm : :pp_forms_paradigm_to_pp
        push!(questions, build_pp_forms_question(
            pp_num;
            direction = direction,
            num_choices = cfg.num_choices,
            rng = rng,
            chapter = cfg.current_chapter,
        ))
    end
    return questions
end

"""
Choose question direction for one selected item.
Falls back to Greek↔English when PP-ID is requested but the item is not a PP verb.
"""
function choose_direction(item::VocabItem, cfg::DrillConfig, rng)::Symbol
    can_pp = item.is_verb_principal_part &&
             item.principal_part_number !== nothing &&
             item.lemma !== nothing

    if can_pp && cfg.pp_id_fraction > 0 && rand(rng) < cfg.pp_id_fraction
        return rand(rng) < cfg.pp_number_to_form_fraction ?
               :pp_number_to_form : :pp_form_to_number
    end

    return rand(rng) < cfg.active_to_passive_ratio ?
           :greek_to_english : :english_to_greek
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
