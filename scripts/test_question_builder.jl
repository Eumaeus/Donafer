# test_QuestionBuilder.jl
# Quick demonstration of the new QuestionBuilder logic
# Run from the project root with:
#   julia --project=. test_QuestionBuilder.jl

using Random

# Load the modules (adjust paths if your structure differs)
include("../src/VocabDrill/DataParser.jl")
include("../src/VocabDrill/QuestionBuilder.jl")

using .DataParser
using .QuestionBuilder

# ============================================================
# Create a small mock vocabulary pool for testing
# ============================================================
function make_mock_pool()::Vector{VocabItem}
    pool = VocabItem[]

    # Greek word with TWO English meanings (tests g2e multi-correct possibility)
    push!(pool, VocabItem(1, "verb", "λύω", "to loose", false, nothing, nothing, "λύω"))
    push!(pool, VocabItem(1, "verb", "λύω", "to destroy", false, nothing, nothing, "λύω"))

    # Another Greek word that shares one English meaning ("to loose")
    # → this enables multi-correct in english_to_greek
    push!(pool, VocabItem(1, "verb", "ἀπολύω", "to loose", false, nothing, nothing, "ἀπολύω"))

    # Distractors from same and different categories
    push!(pool, VocabItem(1, "noun", "ἀγορά", "marketplace", false, nothing, nothing, "ἀγορά"))
    push!(pool, VocabItem(1, "noun", "πόλις", "city", false, nothing, nothing, "πόλις"))
    push!(pool, VocabItem(1, "prep", "ἐν", "in; among", false, nothing, nothing, "ἐν"))
    push!(pool, VocabItem(2, "adj", "καλός", "beautiful; good", false, nothing, nothing, "καλός"))

    # Extra items so distractor selection has room to work
    for i in 1:8
        push!(pool, VocabItem(1, "verb", "verb$i", "meaning$i", false, nothing, nothing, "verb$i"))
    end

    return pool
end

pool = make_mock_pool()
rng = MersenneTwister(42)   # fixed seed for reproducible runs

println("=== Test 1: greek_to_english (stem = Greek) ===")
item1 = pool[1]   # λύω (first meaning)
q1 = build_question(item1, pool; direction=:greek_to_english, num_choices=5, rng=rng)

println("Stem: ", q1.stem)
println("Correct answers: ", q1.correct_answers)
println("Distractors:     ", q1.distractors)
println("\nGIFT output:\n", to_gift(q1; qid="Q1"))
println()

println("=== Test 2: english_to_greek (stem = English) ===")
item2 = pool[1]   # using the "to loose" item
q2 = build_question(item2, pool; direction=:english_to_greek, num_choices=5, rng=rng)

println("Stem: ", q2.stem)
println("Correct answers: ", q2.correct_answers)
println("Distractors:     ", q2.distractors)
println("\nGIFT output:\n", to_gift(q2; qid="Q2"))
println()

println("=== Test 3: Multiple random english_to_greek questions ===")
println("(Watch for occasional multi-correct when a second Greek sneaks into the distractors)\n")

for i in 1:6
    q = build_question(item2, pool; direction=:english_to_greek, num_choices=4, rng=rng)
    is_multi = length(q.correct_answers) > 1
    println("Q$(i): corrects = $(q.correct_answers)   |   multi-correct = $is_multi")
end

println("\n=== Done! ===")
println("Try changing the seed or num_choices to see different behavior.")