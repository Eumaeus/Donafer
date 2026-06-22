# src/VocabDrill/QuestionBuilder.jl

module QuestionBuilder

using ..DataParser
using Random

export Question, build_question, to_gift

struct Question
    stem::String
    correct_answers::Vector{String}
    distractors::Vector{String}
    feedback_correct::String
    feedback_wrong::Dict{String, String}
    chapter::Int
    category::String
end

# Helper: remove leading principal-part number (e.g. "4 ἦρχα" → "ἦρχα")
function clean_greek_form(display::String)
    return replace(display, r"^\d+\s+" => "")
end

function build_question(
    item::VocabItem,
    pool::Vector{VocabItem};
    direction::Symbol = :greek_to_english,
    num_choices::Int = 5,
    rng = Random.default_rng()
)::Question

    if direction == :greek_to_english
        stem = clean_greek_form(item.greek_display)
        full_correct_answers = find_all_matching_english(item.greek_display, pool)

        distractor_items = select_distractors(item, pool, num_choices - 1, rng)
        distractor_answers = unique([d.english for d in distractor_items])

        guaranteed = rand(rng, full_correct_answers)
        all_options = unique([guaranteed; distractor_answers])

        actual_correct_answers = [ans for ans in all_options if ans in full_correct_answers]
        actual_distractors     = [ans for ans in all_options if !(ans in actual_correct_answers)]

        feedback_correct = build_feedback(item, direction)
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

        feedback_correct = build_feedback(item, direction)
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

function to_gift(q::Question; qid::String = "Q")::String
    io = IOBuffer()
    println(io, "::$(qid)::[markdown]$(q.stem):{")

    # Combine and shuffle options so correct answer isn't always first
    options = [(ans, true, q.feedback_correct) for ans in q.correct_answers]
    append!(options, [(dist, false, get(q.feedback_wrong, dist, "Incorrect.")) for dist in q.distractors])

    shuffle!(options)   # ← This is the key change

    for (text, is_correct, fb) in options
        marker = is_correct ? "~%100%" : "~%-100%"
        println(io, "\t$(marker)$(text)#$(fb)")
    end

    println(io, "}")
    return String(take!(io))
end

end # module QuestionBuilder