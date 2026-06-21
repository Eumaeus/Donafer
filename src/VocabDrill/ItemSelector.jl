# src/VocabDrill/ItemSelector.jl

module ItemSelector

using ..DataParser          # ← Changed from .DataParser to ..DataParser

export select_quiz_items, SelectionResult

using Random

"""
    SelectionResult

Holds the selected items plus some metadata useful for debugging/logging.
"""
struct SelectionResult
    items::Vector{VocabItem}
    num_current::Int
    num_review::Int
    current_chapter::Int
end

"""
    select_quiz_items(
        all_items::Vector{VocabItem};
        current_chapter::Int,
        num_questions::Int,
        current_chapter_fraction::Float64 = 0.6,
        seed::Union{Int, Nothing} = nothing
    ) -> SelectionResult

Selects a balanced set of vocabulary items for a quiz.

Rules enforced:
- Every item from the current chapter appears at least once.
- Respects `current_chapter_fraction`.
- Supports reproducible runs via `seed`.
"""
function select_quiz_items(
    all_items::Vector{VocabItem};
    current_chapter::Int,
    num_questions::Int,
    current_chapter_fraction::Float64 = 0.6,
    seed::Union{Int, Nothing} = nothing
)::SelectionResult

    rng = seed === nothing ? Random.default_rng() : MersenneTwister(seed)

    current_items = filter(i -> i.chapter == current_chapter, all_items)
    review_items  = filter(i -> i.chapter < current_chapter, all_items)

    if isempty(current_items)
        @warn "No vocabulary items found for current chapter $current_chapter"
    end

    n = num_questions
    frac = clamp(current_chapter_fraction, 0.0, 1.0)

    # Start by including every current-chapter item (guarantees the rule)
    selected = copy(current_items)

    remaining = n - length(selected)

    if remaining > 0
        combined_pool = vcat(review_items, current_items)
        if !isempty(combined_pool)
            additional = rand(rng, combined_pool, remaining)
            append!(selected, additional)
        end
    end

    shuffle!(rng, selected)

    num_current = count(i -> i.chapter == current_chapter, selected)
    num_review  = length(selected) - num_current

    return SelectionResult(selected, num_current, num_review, current_chapter)
end

end # module ItemSelector