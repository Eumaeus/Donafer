using Pkg
Pkg.activate(".")

include("src/VocabDrill/VocabDrill.jl")
using .VocabDrill
using Random

println("=== QuestionBuilder Test Suite ===\n")

# Load everything
all_items = parse_vocabulary_file("data/vocabulary/hq.txt")
println("Loaded $(length(all_items)) vocabulary items from hq.txt\n")

# Select a reasonable pool
selection = select_quiz_items(
    all_items;
    current_chapter = 2,
    num_questions = 30,
    current_chapter_fraction = 0.6,
    seed = 123
)

rng = MersenneTwister(42)

# ============================================================
# 1. Basic Greek → English
# ============================================================
println("=== 1. Greek → English (normal case) ===\n")
item1 = selection.items[3]
q1 = build_question(item1, all_items; direction=:greek_to_english, num_choices=5, rng=rng)
println("Stem: ", q1.stem)
println("Correct: ", q1.correct_answers)
println(to_gift(q1; qid="G2E_Normal"))
println()

# ============================================================
# 2. Verb Principal Part (Greek → English)
# ============================================================
println("=== 2. Verb Principal Part ===\n")
verb_items = filter(i -> i.is_verb_principal_part, selection.items)
if !isempty(verb_items)
    verb_item = verb_items[1]
    q_verb = build_question(verb_item, all_items; direction=:greek_to_english, num_choices=5, rng=rng)
    println("Stem (Principal Part): ", q_verb.stem)
    println("Correct: ", q_verb.correct_answers)
    println(to_gift(q_verb; qid="Verb_PP"))
else
    println("No verb principal parts found in selection.")
end
println()

# ============================================================
# 3. English → Greek
# ============================================================
println("=== 3. English → Greek ===\n")
item3 = selection.items[5]
q3 = build_question(item3, all_items; direction=:english_to_greek, num_choices=5, rng=rng)
println("Stem: ", q3.stem)
println("Correct answers: ", q3.correct_answers)
println(to_gift(q3; qid="E2G"))
println()

# ============================================================
# 4. Looking for Multi-Correct potential (English → Greek)
# ============================================================
println("=== 4. Checking for Multi-Correct potential ===\n")

# Find English meanings that appear more than once across different Greek forms
english_counts = Dict{String, Int}()
for item in all_items
    english_counts[item.english] = get(english_counts, item.english, 0) + 1
end

multi_meaning_englishs = [k for (k, v) in english_counts if v > 1]

if !isempty(multi_meaning_englishs)
    test_english = first(multi_meaning_englishs)
    println("Found English meaning that appears multiple times: \"$test_english\"")
    
    # Pick one item with this English
    matching_items = filter(i -> i.english == test_english, all_items)
    test_item = first(matching_items)
    
    q_multi = build_question(test_item, all_items; direction=:english_to_greek, num_choices=5, rng=rng)
    println("Stem: ", q_multi.stem)
    println("Correct answers found: ", q_multi.correct_answers)
    println(to_gift(q_multi; qid="MultiCorrect"))
else
    println("No duplicate English meanings found in the current data (multi-correct not triggered in this run).")
    println("This is normal in early chapters. The machinery is ready when it appears.")
end

println("\n=== Test complete ===")