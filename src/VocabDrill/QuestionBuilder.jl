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

function build_question(
    item::VocabItem,
    pool::Vector{VocabItem};
    direction::Symbol = :greek_to_english,
    num_choices::Int = 5,
    rng = Random.default_rng()
)::Question

    if direction == :greek_to_english
        stem = item.greek_display
        correct_answers = [item.english]
        distractors = select_distractors(item, pool, num_choices - 1, rng)
        feedback_correct = build_feedback(item, direction)
        feedback_wrong = Dict(d.greek_display => build_wrong_feedback(d) for d in distractors)

    else  # :english_to_greek
        stem = item.english
        correct_answers = find_all_matching_greek(item.english, pool)
        distractors = select_distractors(item, pool, num_choices - 1, rng)
        feedback_correct = build_feedback(item, direction)
        feedback_wrong = Dict(d.greek_display => build_wrong_feedback(d) for d in distractors)
    end

    return Question(stem, correct_answers, [d.greek_display for d in distractors],
                    feedback_correct, feedback_wrong, item.chapter, item.category)
end

# --- Helper functions ---

function find_all_matching_greek(english::String, pool::Vector{VocabItem})
    matches = filter(x -> x.english == english, pool)
    return unique([x.greek_display for x in matches])
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
        return "Correct: **$(item.greek_display)** is Principal Part $(item.principal_part_number) of **$(item.lemma)** “$(item.english)” (Chapter $(item.chapter))."
    else
        return "Correct: **$(item.greek_display)** → “$(item.english)” (Chapter $(item.chapter))."
    end
end

function build_wrong_feedback(wrong::VocabItem)
    return "Incorrect. **$(wrong.greek_display)** means “$(wrong.english)” (Chapter $(wrong.chapter))."
end

function to_gift(q::Question; qid::String = "Q")::String
    io = IOBuffer()
    println(io, "::$(qid)::[markdown]$(q.stem):{")

    for ans in q.correct_answers
        println(io, "\t~%100%$(ans)#$(q.feedback_correct)")
    end
    for dist in q.distractors
        fb = get(q.feedback_wrong, dist, "Incorrect.")
        println(io, "\t~%-100%$(dist)#$(fb)")
    end
    println(io, "}")
    return String(take!(io))
end

end # module QuestionBuilder