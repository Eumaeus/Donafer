# src/VocabDrill/QuestionBuilder.jl

module QuestionBuilder

using ..DataParser
using Random

export Question, build_question, to_gift, ordinal_label, principal_parts_for_lemma

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
    rng = Random.default_rng()
)::Question

    if direction == :pp_number_to_form
        return build_pp_number_to_form(item, pool; num_choices=num_choices, rng=rng)
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
)::Question
    lemma = item.lemma === nothing ? clean_greek_form(item.greek_display) : item.lemma
    pp_num = item.principal_part_number
    pp_num === nothing && error("pp_number_to_form requires a principal-part item")

    pps = principal_parts_for_lemma(lemma, pool)
    correct_forms = get(pps, pp_num, String[clean_greek_form(item.greek_display)])
    isempty(correct_forms) && (correct_forms = String[clean_greek_form(item.greek_display)])

    stem = "Pick the $(ordinal_label(pp_num)) Principal Part of $(lemma)."

    needed = max(num_choices - 1, 0)
    distractor_answers = select_pp_form_distractors(lemma, pp_num, correct_forms, pool, needed, rng)

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

function select_pp_form_distractors(
    lemma::String,
    pp_num::Int,
    correct_forms::Vector{String},
    pool::Vector{VocabItem},
    needed::Int,
    rng,
)::Vector{String}
    needed <= 0 && return String[]

    same_pp = String[]
    other = String[]
    for x in pool
        x.is_verb_principal_part || continue
        x.lemma == lemma && continue
        form = clean_greek_form(x.greek_display)
        form in correct_forms && continue
        if x.principal_part_number == pp_num
            form in same_pp || push!(same_pp, form)
        else
            form in other || push!(other, form)
        end
    end

    chosen = String[]
    if !isempty(same_pp)
        n = min(needed, length(same_pp))
        append!(chosen, rand(rng, same_pp, n))
        chosen = unique(chosen)
    end
    remaining = needed - length(chosen)
    if remaining > 0 && !isempty(other)
        candidates = [f for f in other if !(f in chosen)]
        n = min(remaining, length(candidates))
        n > 0 && append!(chosen, rand(rng, candidates, n))
        chosen = unique(chosen)
    end
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
