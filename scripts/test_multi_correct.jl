#!/usr/bin/env julia

"""
test_multi_correct.jl

Quick test to verify that multi-correct questions can be generated.
It looks for English meanings that map to multiple Greek forms
(especially useful for verbs with multiple principal parts).
"""

#using Pkg
#Pkg.activate(@__DIR__)

include("../src/VocabDrill/VocabDrill.jl")
using .VocabDrill
using Random

function find_multi_potential_englishs(all_items::Vector{VocabItem})
    # Group Greek forms by English meaning
    english_to_greeks = Dict{String, Vector{String}}()

    for item in all_items
        if !haskey(english_to_greeks, item.english)
            english_to_greeks[item.english] = String[]
        end
        push!(english_to_greeks[item.english], item.greek_display)
    end

    # Return only those with 2+ distinct Greek forms
    multi = Dict{String, Vector{String}}()
    for (eng, greeks) in english_to_greeks
        unique_greeks = unique(greeks)
        if length(unique_greeks) ≥ 2
            multi[eng] = unique_greeks
        end
    end
    return multi
end

function main()
    println("Loading vocabulary...")
    all_items = parse_vocabulary_file("data/vocabulary/hq.txt")

    multi_potential = find_multi_potential_englishs(all_items)
    println("Found $(length(multi_potential)) English meanings with multiple Greek forms.\n")

    if isempty(multi_potential)
        println("No multi-potential meanings found. Check your data.")
        return
    end

    # Pick a few interesting examples (prefer verbs if possible)
    examples = collect(multi_potential)
    sort!(examples, by = x -> occursin("verb", join(x[2], " ")) ? 0 : 1)

    println("=== Testing Multi-Correct Generation ===\n")

    rng = MersenneTwister(44)

    for (i, (english, greeks)) in enumerate(examples[1:min(15, end)])
        println("Test $(i): English = \"$english\"")
        println("   Possible Greek forms: $(greeks)")

        # Find one item with this English meaning
        target_item = first(filter(x -> x.english == english, all_items))

        # Generate a question (force english_to_greek)
        q = build_question(
            target_item, 
            all_items;
            direction = :english_to_greek,
            num_choices = 4,
            rng = rng
        )

        is_multi = length(q.correct_answers) > 1

        println("   Generated question:")
        println("     Stem: $(q.stem)")
        println("     Correct answers: $(q.correct_answers)")
        println("     Distractors:     $(q.distractors)")
        println("     Multi-correct?   $(is_multi ? "YES ✓" : "No")")
        println()
    end

    println("=== Summary ===")
    println("If you see any 'Multi-correct? YES', the logic is working correctly.")
    println("Multi-correct is most likely with verbs (multiple principal parts) or words like οὐ/μή.")
end

main()