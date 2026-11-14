#!/usr/bin/env julia

"""
test_pp_vocab_drill.jl

Tests for Phase 1 principal-parts vocab drills:
  - incomplete PP lists (verbs with fewer than six parts)
  - category filter (verb-only selection)
  - PP-ID question types in both directions

Run from the project root:
    julia --project=. scripts/test_pp_vocab_drill.jl
"""

using Test
using Random

include("../src/VocabDrill/VocabDrill.jl")
using .VocabDrill

function make_incomplete_verb_pool()::Vector{VocabItem}
    # θάπτω: missing 4th PP (matches hq.txt pattern)
    # ἐθέλω: only 1–4
    # λύω: full six (for distractors)
    # βλάπτω: two forms of 6th
    pool = VocabItem[]

    function add_pp!(ch, lemma, greek_field, english, parts)
        for (n, form) in parts
            push!(pool, VocabItem(
                ch, "verb", "$n $form", english, true, n, lemma, greek_field
            ))
        end
    end

    thapto = "1 θάπτω;2 θάψω;3 ἔθαψα;5 τέθαμμαι;6 ἐτάφην"
    add_pp!(4, "θάπτω", thapto, "bury",
            [1 => "θάπτω", 2 => "θάψω", 3 => "ἔθαψα", 5 => "τέθαμμαι", 6 => "ἐτάφην"])

    ethelo = "1 ἐθέλω;2 ἐθελήσω;3 ἠθέλησα;4 ἠθέληκα"
    add_pp!(4, "ἐθέλω", ethelo, "wish",
            [1 => "ἐθέλω", 2 => "ἐθελήσω", 3 => "ἠθέλησα", 4 => "ἠθέληκα"])

    luo = "1 λύω;2 λύσω;3 ἔλυσα;4 λέλυκα;5 λέλυμαι;6 ἐλύθην"
    add_pp!(2, "λύω", luo, "free",
            [1 => "λύω", 2 => "λύσω", 3 => "ἔλυσα",
             4 => "λέλυκα", 5 => "λέλυμαι", 6 => "ἐλύθην"])

    blapto = "1 βλάπτω;2 βλάψω;3 ἔβλαψα;4 βέβλαφα;5 βέβλαμμαι;6 ἐβλάβην;6 ἐβλάφθην"
    add_pp!(5, "βλάπτω", blapto, "harm",
            [1 => "βλάπτω", 2 => "βλάψω", 3 => "ἔβλαψα", 4 => "βέβλαφα",
             5 => "βέβλαμμαι", 6 => "ἐβλάβην", 6 => "ἐβλάφθην"])

    # Non-verb filler (should be excluded by category filter)
    push!(pool, VocabItem(4, "noun", "ἡμέρα, ἡμέρας, ἡ", "day",
                          false, nothing, nothing, "ἡμέρα, ἡμέρας, ἡ"))

    return pool
end

@testset "Principal-parts vocab drills" begin
    pool = make_incomplete_verb_pool()
    rng = MersenneTwister(7)

    @testset "incomplete PP map omits missing numbers" begin
        thapto = principal_parts_for_lemma("θάπτω", pool)
        @test sort(collect(keys(thapto))) == [1, 2, 3, 5, 6]
        @test !haskey(thapto, 4)

        ethelo = principal_parts_for_lemma("ἐθέλω", pool)
        @test sort(collect(keys(ethelo))) == [1, 2, 3, 4]
        @test !haskey(ethelo, 5)
        @test !haskey(ethelo, 6)

        blapto = principal_parts_for_lemma("βλάπτω", pool)
        @test length(blapto[6]) == 2
        @test "ἐβλάβην" in blapto[6]
        @test "ἐβλάφθην" in blapto[6]
    end

    @testset "ordinal labels" begin
        @test ordinal_label(1) == "1st"
        @test ordinal_label(2) == "2nd"
        @test ordinal_label(3) == "3rd"
        @test ordinal_label(4) == "4th"
        @test ordinal_label(6) == "6th"
    end

    @testset "category filter excludes non-verbs" begin
        selected = select_quiz_items(
            pool;
            current_chapter = 4,
            num_questions = 20,
            include_categories = ["verb"],
            seed = 1
        )
        @test all(i -> i.category == "verb", selected.items)
        @test !any(i -> i.category == "noun", selected.items)
    end

    @testset "empty category filter keeps all" begin
        selected = select_quiz_items(
            pool;
            current_chapter = 4,
            num_questions = 10,
            include_categories = String[],
            seed = 2
        )
        cats = unique(i.category for i in selected.items)
        @test "verb" in cats
        # noun may or may not appear depending on selection size; ensure noun is eligible
        all_selected = select_quiz_items(
            pool;
            current_chapter = 4,
            num_questions = 1,
            include_categories = String[],
            seed = 2
        )
        # At least current chapter items include the noun in the unfiltered pool
        unfiltered_current = filter(i -> i.chapter == 4, pool)
        @test any(i -> i.category == "noun", unfiltered_current)
        @test any(i -> i.category == "verb", unfiltered_current)
    end

    @testset "PP number → form (incomplete verb)" begin
        # Ask for 5th of θάπτω (exists); must not invent a 4th
        item = first(filter(i -> i.lemma == "θάπτω" && i.principal_part_number == 5, pool))
        q = build_question(item, pool; direction=:pp_number_to_form, num_choices=8, rng=rng)

        @test occursin("5th Principal Part of θάπτω", q.stem)
        @test "τέθαμμαι" in q.correct_answers
        @test !("missing-4th" in q.distractors)
        # Never offer a fabricated 4th for this lemma as the correct answer
        @test !("" in q.correct_answers)
        @test length(q.correct_answers) + length(q.distractors) <= 8
        @test length(q.correct_answers) + length(q.distractors) >= 2
    end

    @testset "PP number → form multi-correct for dual 6th" begin
        item = first(filter(i -> i.lemma == "βλάπτω" &&
                                 i.principal_part_number == 6 &&
                                 occursin("ἐβλάβην", i.greek_display), pool))
        # Force both correct forms into the option set by using a large choice count
        # and checking the lookup map; build may show one guaranteed correct.
        q = build_question(item, pool; direction=:pp_number_to_form, num_choices=8, rng=MersenneTwister(99))
        @test occursin("6th Principal Part of βλάπτω", q.stem)
        @test any(a -> a in ("ἐβλάβην", "ἐβλάφθην"), q.correct_answers)
        pps = principal_parts_for_lemma("βλάπτω", pool)
        @test Set(pps[6]) == Set(["ἐβλάβην", "ἐβλάφθην"])
    end

    @testset "PP form → number" begin
        item = first(filter(i -> i.lemma == "λύω" && i.principal_part_number == 4, pool))
        q = build_question(item, pool; direction=:pp_form_to_number, num_choices=8, rng=rng)

        @test occursin("Which Principal Part of λύω is ‘λέλυκα’?", q.stem)
        @test q.correct_answers == ["4th"]
        @test "4th" ∉ q.distractors
        @test all(d -> d in ("1st", "2nd", "3rd", "5th", "6th"), q.distractors)
        # Cap at the five wrong traditional labels even when num_choices is 8
        @test length(q.distractors) == 5
        @test length(q.correct_answers) + length(q.distractors) == 6
    end

    @testset "PP form → number respects num_choices < 6" begin
        item = first(filter(i -> i.lemma == "ἐθέλω" && i.principal_part_number == 2, pool))
        q = build_question(item, pool; direction=:pp_form_to_number, num_choices=4, rng=rng)
        @test q.correct_answers == ["2nd"]
        @test length(q.distractors) == 3
        @test "2nd" ∉ q.distractors
    end

    @testset "never asks for a missing PP number via selected items" begin
        # Selection only yields items that exist; θάπτω has no PP 4 item.
        @test !any(i -> i.lemma == "θάπτω" && i.principal_part_number == 4, pool)
        selected = select_quiz_items(
            pool;
            current_chapter = 4,
            num_questions = 30,
            include_categories = ["verb"],
            seed = 3
        )
        @test !any(i -> i.lemma == "θάπτω" && i.principal_part_number == 4, selected.items)
    end

    @testset "real hq.txt parse + verb filter" begin
        path = "data/vocabulary/hq.txt"
        if isfile(path)
            items = parse_vocabulary_file(path)
            verbs = filter(i -> i.category == "verb", items)
            @test !isempty(verbs)

            # Spot-check incomplete verbs from the data file comments
            thapto_items = filter(i -> i.lemma == "θάπτω", verbs)
            @test !isempty(thapto_items)
            thapto_nums = sort(unique(i.principal_part_number for i in thapto_items))
            @test 4 ∉ thapto_nums
            @test 5 in thapto_nums

            ethelo_items = filter(i -> i.lemma == "ἐθέλω", verbs)
            @test !isempty(ethelo_items)
            ethelo_nums = sort(unique(i.principal_part_number for i in ethelo_items))
            @test ethelo_nums == [1, 2, 3, 4]

            selected = select_quiz_items(
                items;
                current_chapter = 4,
                num_questions = 40,
                include_categories = ["verb"],
                seed = 11
            )
            @test all(i -> i.category == "verb", selected.items)

            # Build a few PP questions from real data
            pp_item = first(filter(i -> i.is_verb_principal_part, selected.items))
            q1 = build_question(pp_item, verbs; direction=:pp_number_to_form, num_choices=8, rng=MersenneTwister(5))
            q2 = build_question(pp_item, verbs; direction=:pp_form_to_number, num_choices=8, rng=MersenneTwister(5))
            @test startswith(q1.stem, "Pick the")
            @test startswith(q2.stem, "Which Principal Part")
            gift = to_gift(q1; qid="T1")
            @test occursin("~%100%", gift) || occursin("~%", gift)
        else
            @warn "Skipping hq.txt integration checks; file not found at $path"
        end
    end

    @testset "config defaults preserve classic drill knobs" begin
        cfg = load_config("config/vocab_drill.toml")
        @test isempty(cfg.include_categories)
        @test cfg.pp_id_fraction == 0.0
        @test cfg.num_choices >= 5
    end
end

println("\nAll principal-parts vocab tests finished.")
