# src/VocabDrill/ItemSelector.jl

module ItemSelector

export select_quiz_items, SelectionResult

using Random

"""
    SelectionResult

Holds the selected items plus some metadata useful for debugging/logging.
"""
struct SelectionResult
    items::Vector{VocabItem}      # Final list of items for the quiz
    num_current::Int              # How many came from the current chapter
    num_review::Int               # How many came from previous chapters
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

Key behaviors:
- All items from the current chapter appear at least once before any repeats.
- Respects `current_chapter_fraction` as closely as possible.
- Uses review items (previous chapters) to fill the rest.
"""
function select_quiz_items(
    all_items::Vector{VocabItem};
    current_chapter::Int,
    num_questions::Int,
    current_chapter_fraction::Float64 = 0.6,
    seed::Union{Int, Nothing} = nothing
)::SelectionResult

    # Set random seed if provided (for reproducibility)
    rng = seed === nothing ? Random.default_rng() : MersenneTwister(seed)

    # Split into current chapter and review pools
    current_items = filter(i -> i.chapter == current_chapter, all_items)
    review_items  = filter(i -> i.chapter < current_chapter, all_items)

    if isempty(current_items)
        @warn "No items found for current chapter $current_chapter"
    end

    n = num_questions
    frac = clamp(current_chapter_fraction, 0.0, 1.0)

    # Target number from current chapter
    n_current_target = max(length(current_items), round(Int, n * frac))

    selected = VocabItem[]

    # === Phase 1: Guarantee every current-chapter item appears at least once ===
    append!(selected, current_items)

    # === Phase 2: Fill remaining slots ===
    remaining = n - length(selected)

    if remaining > 0
        # Create a combined pool for additional selections
        # We bias toward review items but still allow current items to repeat
        combined_pool = vcat(review_items, current_items)

        if !isempty(combined_pool)
            additional = rand(rng, combined_pool, remaining)
            append!(selected, additional)
        end
    end

    # Shuffle the final list so current items aren't all at the front
    shuffle!(rng, selected)

    num_current = count(i -> i.chapter == current_chapter, selected)
    num_review  = length(selected) - num_current

    return SelectionResult(selected, num_current, num_review, current_chapter)
end

end # module ItemSelector