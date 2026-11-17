# src/VocabDrill/QuestionBuilder.jl

module QuestionBuilder

using ..DataParser
using Random

export Question, build_question, to_gift, ordinal_label, principal_parts_for_lemma,
       form_similarity, select_pp_form_distractors,
       PRINCIPAL_PART_GLOSSES, principal_part_gloss, build_pp_meaning_question

struct Question
    stem::String
    correct_answers::Vector{String}
    distractors::Vector{String}
    feedback_correct::Dict{String, String}   # was String
    feedback_wrong::Dict{String, String}
    chapter::Int
    category::String
end

# Helper: remove leading principal-part number (e.g. "4 ἦρχα" → "ἦρχα")
function clean_greek_form(display::String)
    return replace(display, r"^\d+\s+" => "")
end

"""
    ordinal_label(n) -> String

Return a short English ordinal for principal-part numbers (1st…6th).
"""
function ordinal_label(n::Int)::String
    n == 1 && return "1st"
    n == 2 && return "2nd"
    n == 3 && return "3rd"
    return "$(n)th"
end

"""
Fixed answer bank for “what each principal part *is*” drills.
Wording matches the pedagogical glosses in `ai_queries/08_Exending_Vocab_to_PPs.md`.
"""
const PRINCIPAL_PART_GLOSSES = (
    "Present, Active, Indicative, 1st person, Singular",
    "Future, Active, Indicative, 1st person, Singular",
    "Aorist, Active, Indicative, 1st person, Singular",
    "Perfect, Active, Indicative, 1st person, Singular",
    "Perfect, Middle/Passive, Indicative, 1st person, Singular",
    "Aorist, Passive, Indicative, 1st person, Singular",
)

"""
    principal_part_gloss(n) -> String

Return the traditional morphological gloss for principal part `n` (1–6).
"""
function principal_part_gloss(n::Int)::String
    (1 <= n <= length(PRINCIPAL_PART_GLOSSES)) ||
        error("principal_part_gloss expects 1–6, got $n")
    return PRINCIPAL_PART_GLOSSES[n]
end

"""
    principal_parts_for_lemma(lemma, pool) -> Dict{Int, Vector{String}}

Map each principal-part number present for `lemma` to its distinct Greek forms.
Verbs with incomplete lists simply omit missing numbers.
"""
function principal_parts_for_lemma(lemma::String, pool::Vector{VocabItem})::Dict{Int, Vector{String}}
    pps = Dict{Int, Vector{String}}()
    for item in pool
        item.is_verb_principal_part || continue
        item.lemma == lemma || continue
        item.principal_part_number === nothing && continue
        form = clean_greek_form(item.greek_display)
        forms = get!(pps, item.principal_part_number, String[])
        form in forms || push!(forms, form)
    end
    return pps
end

function build_question(
    item::VocabItem,
    pool::Vector{VocabItem};
    direction::Symbol = :greek_to_english,
    num_choices::Int = 5,
    rng = Random.default_rng(),
    pp_form_similarity_threshold::Float64 = 0.45,
    max_chapter::Union{Int, Nothing} = nothing,
)::Question

    if direction == :pp_number_to_form
        return build_pp_number_to_form(
            item, pool;
            num_choices=num_choices, rng=rng,
            similarity_threshold=pp_form_similarity_threshold,
            max_chapter=max_chapter,
        )
    elseif direction == :pp_form_to_number
        return build_pp_form_to_number(item, pool; num_choices=num_choices, rng=rng)
    elseif direction == :greek_to_english
        stem = clean_greek_form(item.greek_display)
        full_correct_answers = find_all_matching_english(item.greek_display, pool)

        distractor_items = select_distractors(item, pool, num_choices - 1, rng)
        distractor_answers = unique([d.english for d in distractor_items])

        guaranteed = rand(rng, full_correct_answers)
        all_options = unique([guaranteed; distractor_answers])

        actual_correct_answers = [ans for ans in all_options if ans in full_correct_answers]
        actual_distractors     = [ans for ans in all_options if !(ans in actual_correct_answers)]

        feedback_correct = Dict{String, String}()
        for ans in actual_correct_answers
            fb_item = item_for_correct_answer(item, ans, direction, pool)
            feedback_correct[ans] = build_feedback(fb_item, direction)
        end

        feedback_wrong = Dict{String, String}()
        for dist_ans in actual_distractors
            matching = filter(x -> x.english == dist_ans, pool)
            feedback_wrong[dist_ans] = !isempty(matching) ? build_wrong_feedback(matching[1]) : "Incorrect."
        end

    else  # :english_to_greek
        stem = item.english
        full_correct_answers_raw = find_all_matching_greek(item.english, pool)
        full_correct_answers = [clean_greek_form(g) for g in full_correct_answers_raw]

        distractor_items = select_distractors(item, pool, num_choices - 1, rng)
        distractor_answers_raw = unique([d.greek_display for d in distractor_items])
        distractor_answers = [clean_greek_form(g) for g in distractor_answers_raw]

        guaranteed = rand(rng, full_correct_answers)
        all_options = unique([guaranteed; distractor_answers])

        actual_correct_answers = [ans for ans in all_options if ans in full_correct_answers]
        actual_distractors     = [ans for ans in all_options if !(ans in actual_correct_answers)]

        feedback_correct = Dict{String, String}()
        for ans in actual_correct_answers
            fb_item = item_for_correct_answer(item, ans, direction, pool)
            feedback_correct[ans] = build_feedback(fb_item, direction)
        end

        feedback_wrong = Dict{String, String}()
        for dist_ans in actual_distractors
            # Find original item for feedback (need full greek_display)
            matching = filter(x -> clean_greek_form(x.greek_display) == dist_ans, pool)
            feedback_wrong[dist_ans] = !isempty(matching) ? build_wrong_feedback(matching[1]) : "Incorrect."
        end
    end

    return Question(stem, actual_correct_answers, actual_distractors,
                    feedback_correct, feedback_wrong, item.chapter, item.category)
end

# --- Principal-part identification ---

function build_pp_number_to_form(
    item::VocabItem,
    pool::Vector{VocabItem};
    num_choices::Int,
    rng,
    similarity_threshold::Float64 = 0.45,
    max_chapter::Union{Int, Nothing} = nothing,
)::Question
    lemma = item.lemma === nothing ? clean_greek_form(item.greek_display) : item.lemma
    pp_num = item.principal_part_number
    pp_num === nothing && error("pp_number_to_form requires a principal-part item")

    pps = principal_parts_for_lemma(lemma, pool)
    correct_forms = get(pps, pp_num, String[clean_greek_form(item.greek_display)])
    isempty(correct_forms) && (correct_forms = String[clean_greek_form(item.greek_display)])

    stem = "Pick the $(ordinal_label(pp_num)) Principal Part of $(lemma)."

    needed = max(num_choices - 1, 0)
    distractor_answers = select_pp_form_distractors(
        lemma, pp_num, correct_forms, pool, needed, rng;
        similarity_threshold=similarity_threshold,
        max_chapter=max_chapter,
    )

    guaranteed = rand(rng, correct_forms)
    all_options = unique([guaranteed; distractor_answers])
    actual_correct = [ans for ans in all_options if ans in correct_forms]
    actual_distractors = [ans for ans in all_options if !(ans in actual_correct)]

    feedback_correct = Dict{String, String}(
        ans => "Correct: **$(ans)** is the $(ordinal_label(pp_num)) Principal Part of **$(lemma)** (Chapter $(item.chapter))."
        for ans in actual_correct
    )

    feedback_wrong = Dict{String, String}()
    for dist in actual_distractors
        matching = filter(x -> x.is_verb_principal_part &&
                               clean_greek_form(x.greek_display) == dist, pool)
        feedback_wrong[dist] = !isempty(matching) ? build_wrong_feedback(matching[1]) : "Incorrect."
    end

    return Question(stem, actual_correct, actual_distractors,
                    feedback_correct, feedback_wrong, item.chapter, item.category)
end

function build_pp_form_to_number(
    item::VocabItem,
    pool::Vector{VocabItem};
    num_choices::Int,
    rng,
)::Question
    lemma = item.lemma === nothing ? clean_greek_form(item.greek_display) : item.lemma
    pp_num = item.principal_part_number
    pp_num === nothing && error("pp_form_to_number requires a principal-part item")
    form = clean_greek_form(item.greek_display)
    correct_label = ordinal_label(pp_num)

    stem = "Which Principal Part of $(lemma) is ‘$(form)’?"

    # Answer bank is the six traditional labels; incomplete verbs still use 1st–6th.
    all_labels = [ordinal_label(n) for n in 1:6]
    wrong_labels = [lab for lab in all_labels if lab != correct_label]
    needed = min(max(num_choices - 1, 0), length(wrong_labels))
    distractors = needed == 0 ? String[] : shuffle(rng, wrong_labels)[1:needed]

    feedback_correct = Dict{String, String}(
        correct_label => "Correct: **$(form)** is the $(correct_label) Principal Part of **$(lemma)** (Chapter $(item.chapter))."
    )
    feedback_wrong = Dict{String, String}(
        lab => "Incorrect. **$(form)** is the $(correct_label) Principal Part of **$(lemma)**, not the $(lab)."
        for lab in distractors
    )

    return Question(stem, String[correct_label], distractors,
                    feedback_correct, feedback_wrong, item.chapter, item.category)
end

# --- What each principal part *is* (lemma-independent meta) ---

"""
    build_pp_meaning_question(pp_num; direction, num_choices, rng, chapter)

Build a lemma-independent question about what principal part `pp_num` represents.

Directions:
- `:pp_meaning_number_to_gloss` — “The **1st Principal Part** is the:” → gloss
- `:pp_meaning_gloss_to_number` — “Which Principal Part is the ‘…’?” → 1st…6th

The answer bank is the six traditional glosses (or the six ordinals). Shared
`num_choices` applies, but these items naturally cap at 6 options.
"""
function build_pp_meaning_question(
    pp_num::Int;
    direction::Symbol = :pp_meaning_number_to_gloss,
    num_choices::Int = 8,
    rng = Random.default_rng(),
    chapter::Int = 0,
)::Question
    (1 <= pp_num <= 6) || error("build_pp_meaning_question expects pp_num 1–6, got $pp_num")

    if direction == :pp_meaning_number_to_gloss
        return build_pp_meaning_number_to_gloss(pp_num; num_choices=num_choices, rng=rng, chapter=chapter)
    elseif direction == :pp_meaning_gloss_to_number
        return build_pp_meaning_gloss_to_number(pp_num; num_choices=num_choices, rng=rng, chapter=chapter)
    else
        error("Unknown PP-meaning direction: $direction")
    end
end

function build_pp_meaning_number_to_gloss(
    pp_num::Int;
    num_choices::Int,
    rng,
    chapter::Int,
)::Question
    correct = principal_part_gloss(pp_num)
    stem = "The **$(ordinal_label(pp_num)) Principal Part** is the:"

    all_glosses = collect(PRINCIPAL_PART_GLOSSES)
    wrong = [g for g in all_glosses if g != correct]
    needed = min(max(num_choices - 1, 0), length(wrong))
    distractors = needed == 0 ? String[] : shuffle(rng, wrong)[1:needed]

    feedback_correct = Dict{String, String}(
        correct => "Correct: the $(ordinal_label(pp_num)) Principal Part is **$(correct)**."
    )
    feedback_wrong = Dict{String, String}(
        g => "Incorrect. The $(ordinal_label(pp_num)) Principal Part is **$(correct)**, not “$(g)”."
        for g in distractors
    )

    return Question(stem, String[correct], distractors,
                    feedback_correct, feedback_wrong, chapter, "pp_meaning")
end

function build_pp_meaning_gloss_to_number(
    pp_num::Int;
    num_choices::Int,
    rng,
    chapter::Int,
)::Question
    gloss = principal_part_gloss(pp_num)
    correct_label = ordinal_label(pp_num)
    stem = "Which Principal Part is the ‘$(gloss)’?"

    all_labels = [ordinal_label(n) for n in 1:6]
    wrong_labels = [lab for lab in all_labels if lab != correct_label]
    needed = min(max(num_choices - 1, 0), length(wrong_labels))
    distractors = needed == 0 ? String[] : shuffle(rng, wrong_labels)[1:needed]

    feedback_correct = Dict{String, String}(
        correct_label => "Correct: ‘$(gloss)’ is the **$(correct_label) Principal Part**."
    )
    feedback_wrong = Dict{String, String}(
        lab => "Incorrect. ‘$(gloss)’ is the **$(correct_label) Principal Part**, not the $(lab)."
        for lab in distractors
    )

    return Question(stem, String[correct_label], distractors,
                    feedback_correct, feedback_wrong, chapter, "pp_meaning")
end

"""
    form_similarity(a, b) -> Float64

Normalized Unicode-aware similarity in `[0, 1]`:
`1 - levenshtein(a, b) / max(length(a), length(b))`.
Used to prefer look-alike Greek forms as PP distractors
(e.g. ἔπαθον ≈ ἔπιθον).
"""
function form_similarity(a::AbstractString, b::AbstractString)::Float64
    a == b && return 1.0
    denom = max(length(a), length(b))
    denom == 0 && return 1.0
    return 1.0 - levenshtein_distance(a, b) / denom
end

function levenshtein_distance(a::AbstractString, b::AbstractString)::Int
    s = collect(a)
    t = collect(b)
    m = length(s)
    n = length(t)
    m == 0 && return n
    n == 0 && return m

    prev = collect(0:n)
    curr = Vector{Int}(undef, n + 1)
    for i in 1:m
        curr[1] = i
        for j in 1:n
            cost = s[i] == t[j] ? 0 : 1
            curr[j + 1] = min(curr[j] + 1,          # insertion
                              prev[j + 1] + 1,      # deletion
                              prev[j] + cost)       # substitution
        end
        prev, curr = curr, prev
    end
    return prev[n + 1]
end

function best_form_similarity(candidate::AbstractString, correct_forms::Vector{String})::Float64
    isempty(correct_forms) && return 0.0
    return maximum(form_similarity(candidate, c) for c in correct_forms)
end

"""
    select_pp_form_distractors(...) -> Vector{String}

Distractor priority for “Pick the Nth Principal Part of X”:

1. Other principal parts of the **same verb**
2. Forms from **other verbs** in chapters `≤ max_chapter` (when set)
   whose normalized edit-distance similarity to a correct form is
   `≥ similarity_threshold` (prefer higher similarity; same PP# as a tie-break)
3. Any remaining chapter-scoped verb forms (prefer same PP#, then any)

When the pool is thin, later tiers fill whatever slots remain; the quiz
may have fewer than `num_choices` options if even the fallback pool is short.
"""
function select_pp_form_distractors(
    lemma::String,
    pp_num::Int,
    correct_forms::Vector{String},
    pool::Vector{VocabItem},
    needed::Int,
    rng;
    similarity_threshold::Float64 = 0.45,
    max_chapter::Union{Int, Nothing} = nothing,
)::Vector{String}
    needed <= 0 && return String[]

    # --- Tier 1: other PPs of the same verb ---
    same_verb_forms = String[]
    pps = principal_parts_for_lemma(lemma, pool)
    for (n, forms) in pps
        n == pp_num && continue
        for form in forms
            form in correct_forms && continue
            form in same_verb_forms || push!(same_verb_forms, form)
        end
    end

    chosen = String[]
    _take_shuffled!(chosen, same_verb_forms, needed, rng)
    remaining = needed - length(chosen)
    remaining <= 0 && return chosen

    # Collect other-verb candidates within the chapter window
    # (form => (best_similarity, same_pp?))
    other_meta = Dict{String, Tuple{Float64, Bool}}()
    for x in pool
        x.is_verb_principal_part || continue
        x.lemma == lemma && continue
        max_chapter !== nothing && x.chapter > max_chapter && continue
        form = clean_greek_form(x.greek_display)
        form in correct_forms && continue
        form in chosen && continue
        sim = best_form_similarity(form, correct_forms)
        same_pp = x.principal_part_number == pp_num
        if haskey(other_meta, form)
            old_sim, old_same = other_meta[form]
            other_meta[form] = (max(old_sim, sim), old_same || same_pp)
        else
            other_meta[form] = (sim, same_pp)
        end
    end

    # --- Tier 2: similar forms from other verbs ---
    similar = [(f, sim, same_pp) for (f, (sim, same_pp)) in other_meta
               if sim >= similarity_threshold]
    # Higher similarity first; prefer same PP#; shuffle within ties via rng key
    sort!(similar, by = x -> (-x[2], x[3] ? 0 : 1, rand(rng)))
    for (form, _, _) in similar
        remaining <= 0 && break
        form in chosen && continue
        push!(chosen, form)
        remaining -= 1
    end
    remaining <= 0 && return chosen

    # --- Tier 3: fill from remaining chapter-scoped forms ---
    fallback_same_pp = String[]
    fallback_other = String[]
    for (form, (_, same_pp)) in other_meta
        form in chosen && continue
        if same_pp
            push!(fallback_same_pp, form)
        else
            push!(fallback_other, form)
        end
    end
    _take_shuffled!(chosen, fallback_same_pp, remaining, rng)
    remaining = needed - length(chosen)
    remaining > 0 && _take_shuffled!(chosen, fallback_other, remaining, rng)

    return chosen
end

function _take_shuffled!(chosen::Vector{String}, candidates::Vector{String}, n::Int, rng)
    n <= 0 && return chosen
    avail = [c for c in candidates if !(c in chosen)]
    isempty(avail) && return chosen
    shuffle!(rng, avail)
    append!(chosen, avail[1:min(n, length(avail))])
    return chosen
end

# Find the VocabItem that actually corresponds to this displayed correct option.
function item_for_correct_answer(
    item::VocabItem,
    answer::String,
    direction::Symbol,
    pool::Vector{VocabItem},
)
    matching = if direction == :greek_to_english
        # stem is Greek; answer is an English gloss
        filter(x -> x.greek_display == item.greek_display && x.english == answer, pool)
    else
        # stem is English; answer is a (cleaned) Greek form
        filter(x -> x.english == item.english &&
                    clean_greek_form(x.greek_display) == answer, pool)
    end

    if isempty(matching) && direction == :greek_to_english
        # verbs: stem was cleaned ("ἦρχα") but greek_display is "4 ἦρχα"
        matching = filter(x -> clean_greek_form(x.greek_display) ==
                               clean_greek_form(item.greek_display) &&
                               x.english == answer, pool)
    end

    return isempty(matching) ? item : first(matching)
end

# --- Helper functions ---

function find_all_matching_greek(english::String, pool::Vector{VocabItem})
    matches = filter(x -> x.english == english, pool)
    return unique([x.greek_display for x in matches])
end

function find_all_matching_english(greek::String, pool::Vector{VocabItem})
    matches = filter(x -> x.greek_display == greek, pool)
    return unique([x.english for x in matches])
end

function select_distractors(item::VocabItem, pool::Vector{VocabItem}, needed::Int, rng)
    same_cat = filter(x -> x.category == item.category && x != item, pool)
    others   = filter(x -> x.category != item.category && x != item, pool)

    chosen = VocabItem[]
    if !isempty(same_cat)
        append!(chosen, rand(rng, same_cat, min(needed, length(same_cat))))
    end
    remaining = needed - length(chosen)
    if remaining > 0 && !isempty(others)
        append!(chosen, rand(rng, others, min(remaining, length(others))))
    end
    return unique(chosen)
end

function build_feedback(item::VocabItem, direction::Symbol)
    if item.is_verb_principal_part
        clean_form = clean_greek_form(item.greek_display)
        return "Correct: **$(clean_form)** is Principal Part $(item.principal_part_number) of **$(item.lemma)** “$(item.english)” (Chapter $(item.chapter))."
    else
        return "Correct: **$(item.greek_display)** → “$(item.english)” (Chapter $(item.chapter))."
    end
end

function build_wrong_feedback(wrong::VocabItem)
    if wrong.is_verb_principal_part
        clean_form = clean_greek_form(wrong.greek_display)
        return "Incorrect. **$(clean_form)** is Principal Part $(wrong.principal_part_number) of **$(wrong.lemma)** “$(wrong.english)” (Chapter $(wrong.chapter))."
    else
        return "Incorrect. **$(wrong.greek_display)** means “$(wrong.english)” (Chapter $(wrong.chapter))."
    end
end

# Weight for each correct option so the weights sum to 100.
# 1 → 100, 2 → 50, 3 → 33.33333 (Moodle’s documented 100/3 form).
function format_correct_weight(n_correct::Int)::String
    n_correct <= 1 && return "100"
    weight = 100 / n_correct
    isinteger(weight) && return string(Int(weight))
    return string(round(weight; digits=5))
end

function to_gift(q::Question; qid::String = "Q")::String
    io = IOBuffer()
    println(io, "::$(qid)::[markdown]$(q.stem):{")

    n_correct = max(length(q.correct_answers), 1)
    correct_marker = "~%$(format_correct_weight(n_correct))%"

    options = [(ans, true, get(q.feedback_correct, ans, "Correct."))
               for ans in q.correct_answers]
    append!(options, [(dist, false, get(q.feedback_wrong, dist, "Incorrect."))
                      for dist in q.distractors])
    shuffle!(options)

    for (text, is_correct, fb) in options
        marker = is_correct ? correct_marker : "~%-100%"
        println(io, "\t$(marker)$(text)#$(fb)")
    end

    println(io, "}")
    return String(take!(io))
end

end # module QuestionBuilder
