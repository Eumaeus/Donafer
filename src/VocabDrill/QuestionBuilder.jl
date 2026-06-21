# src/VocabDrill/QuestionBuilder.jl

module QuestionBuilder

using ..DataParser
using Random

export Question, build_question, to_gift

"""
    Question

Represents one multiple-choice question ready to be turned into GIFT format.
"""
struct Question
    stem::String
    correct_answers::Vector{String}      # Can contain multiple correct answers
    distractors::Vector{String}
    feedback_correct::String
    feedback_wrong::Dict{String, String} # distractor => feedback text
    chapter::Int
    category::String
end

"""
    build_question(item, pool; direction, num_choices, rng)

Builds one high-quality multiple choice question.
`direction` can be :greek_to_english or :english_to_greek.
"""
function build_question(
    item::VocabItem,
    pool::Vector{VocabItem};
    direction::Symbol = :greek_to_english,
    num_choices::Int = 5,
    rng = Random.default_rng()
)::Question

    if direction == :greek_to_english
        stem = item.greek_display
        # All possible correct English answers for this exact Greek form
        correct_answers = find_all_correct_answers(item, pool, direction)
        
        # Distractors: prefer same category
        distractors = select_distractors(item, pool, num_choices - 1, rng)
        
        feedback_correct = build_rich_feedback(item, direction, correct_answers)
        feedback_wrong = Dict(d.english => build_wrong_feedback(d, item) for d in distractors)

    else  # :english_to_greek
        stem = item.english
        correct_answers = find_all_correct_answers(item, pool, direction)
        
        distractors = select_distractors(item, pool, num_choices - 1, rng)
        
        feedback_correct = build_rich_feedback(item, direction, correct_answers)
        feedback_wrong = Dict(d.greek_display => build_wrong_feedback(d, item) for d in distractors)
    end

    return Question(
        stem,
        correct_answers,
        [d.greek_display for d in distractors],  # store Greek display for consistency
        feedback_correct,
        feedback_wrong,
        item.chapter,
        item.category
    )
end

# ============================================================
# Helper functions
# ============================================================

function find_all_correct_answers(item::VocabItem, pool::Vector{VocabItem}, direction::Symbol)
    if direction == :greek_to_english
        # For a given Greek form, return all English meanings associated with it
        return [item.english]
    else
        # English → Greek: find every Greek form that has this English meaning
        target_english = item.english
        corrects = filter(x -> x.english == target_english, pool)
        return unique([x.greek_display for x in corrects])
    end
end

function select_distractors(item::VocabItem, pool::Vector{VocabItem}, needed::Int, rng)
    # Prefer same category
    same_category = filter(x -> x.category == item.category && x != item, pool)
    others = filter(x -> x.category != item.category && x != item, pool)

    distractors = VocabItem[]
    if !isempty(same_category)
        append!(distractors, rand(rng, same_category, min(needed, length(same_category))))
    end
    remaining = needed - length(distractors)
    if remaining > 0 && !isempty(others)
        append!(distractors, rand(rng, others, min(remaining, length(others))))
    end
    return unique(distractors)
end

function build_rich_feedback(item::VocabItem, direction::Symbol, correct_answers::Vector{String})
    if item.is_verb_principal_part
        return "Correct: **$(item.greek_display)** is the $(item.principal_part_number)th Principal Part of **$(item.lemma)** “$(item.english)” (Chapter $(item.chapter))."
    else
        return "Correct: **$(item.greek_display)** → \"$(item.english)\" (Chapter $(item.chapter))."
    end
end

function build_wrong_feedback(wrong::VocabItem, correct::VocabItem)
    return "Incorrect. **$(wrong.greek_display)** means “$(wrong.english)” (Chapter $(wrong.chapter))."
end

"""
    to_gift(q::Question; question_id::String = "Q") -> String

Converts a Question into Moodle GIFT format.
"""
function to_gift(q::Question; question_id::String = "Q")::String
    io = IOBuffer()
    
    println(io, "::$(question_id)::[markdown]$(q.stem):{")
    
    # Correct answers (can be multiple)
    for ans in q.correct_answers
        println(io, "\t~%100%$(ans)#$(q.feedback_correct)")
    end
    
    # Distractors
    for dist in q.distractors
        fb = get(q.feedback_wrong, dist, "Incorrect.")
        println(io, "\t~%-100%$(dist)#$(fb)")
    end
    
    println(io, "}")
    return String(take!(io))
end

end # module QuestionBuilder