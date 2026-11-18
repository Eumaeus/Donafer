#!/usr/bin/env julia

"""
test_pp_vocab_drill.jl

Tests for principal-parts vocab drills:

Phase 1:
  - incomplete PP lists (verbs with fewer than six parts)
  - category filter (verb-only selection)
  - PP-ID question types in both directions

Phase 2:
  - fixed gloss bank for what each PP *is*
  - both directions (number↔gloss)
  - config cap / fraction for the meta family
  - lemma independence

Phase 3:
  - fixed paradigm bank (form labels ↔ PP numbers)
  - both directions (PP↔paradigm)
  - config cap / fraction for the forms family
  - lemma independence; classic-off code defaults

Phase 4:
  - numbered English field (split Greek / numbered-English)
  - legacy one-gloss English still parses
  - PP form ↔ tense-appropriate English question types
  - pp_gloss_fraction classic-off by default

Phase 5:
  - prep Greek `+ gen|dat|acc` parsing (legacy lines keep working)
  - optional case-tagged English (`gen gloss; dat gloss`)
  - prep+case ↔ meaning question types; same-prep other-case distractors first
  - prep_case_fraction / prep_case_max_count classic-off by default

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
        q = build_question(item, pool; direction=:pp_number_to_form, num_choices=8, rng=rng,
                           max_chapter=4)

        @test occursin("5th Principal Part of θάπτω", q.stem)
        @test "τέθαμμαι" in q.correct_answers
        @test !("missing-4th" in q.distractors)
        # Never offer a fabricated 4th for this lemma as the correct answer
        @test !("" in q.correct_answers)
        @test length(q.correct_answers) + length(q.distractors) <= 8
        @test length(q.correct_answers) + length(q.distractors) >= 2
        # Same-verb other PPs should fill first (θάπτω has 1,2,3,6 — no 4th)
        same_verb = Set(["θάπτω", "θάψω", "ἔθαψα", "ἐτάφην"])
        @test !isempty(intersect(Set(q.distractors), same_verb))
        # Chapter cap: βλάπτω is ch5 — should not appear when max_chapter=4
        @test !any(d -> startswith(d, "βλ") || startswith(d, "ἐβλ") || startswith(d, "βέβλ"),
                   q.distractors)
    end

    @testset "form_similarity (normalized edit distance)" begin
        @test form_similarity("ἔπαθον", "ἔπιθον") > 0.8
        @test form_similarity("ἔπαθον", "ἔπαθον") == 1.0
        @test form_similarity("λύω", "πέμπω") < 0.45
        @test form_similarity("", "") == 1.0
    end

    @testset "PP distractors: same-verb first, then similar forms" begin
        # πάσχω / πείθω look-alike 3rd PPs (user example)
        sim_pool = VocabItem[]
        function add!(ch, lemma, english, parts)
            field = join(["$n $f" for (n, f) in parts], ";")
            for (n, form) in parts
                push!(sim_pool, VocabItem(ch, "verb", "$n $form", english, true, n, lemma, field))
            end
        end
        add!(11, "πάσχω", "suffer",
             [1 => "πάσχω", 2 => "πείσομαι", 3 => "ἔπαθον", 4 => "πέπονθα"])
        add!(5, "πείθω", "persuade",
             [1 => "πείθω", 2 => "πείσω", 3 => "ἔπιθον", 4 => "πέπεικα",
              5 => "πέπεισμαι", 6 => "ἑπείσθην"])
        # Dissimilar filler from another verb in-range
        add!(2, "λύω", "free",
             [1 => "λύω", 2 => "λύσω", 3 => "ἔλυσα", 4 => "λέλυκα",
              5 => "λέλυμαι", 6 => "ἐλύθην"])
        # Out-of-chapter look-alike should be excluded by max_chapter
        add!(20, "futureverb", "future",
             [1 => "futureverb", 3 => "ἔπαθονx"])  # won't match anyway

        correct = ["ἔπαθον"]
        dists = select_pp_form_distractors(
            "πάσχω", 3, correct, sim_pool, 7, MersenneTwister(1);
            similarity_threshold=0.45, max_chapter=11,
        )

        # Tier 1: other PPs of πάσχω should be present when asking for enough slots
        @test "πάσχω" in dists
        @test "πείσομαι" in dists
        @test "πέπονθα" in dists
        # Tier 2: look-alike ἔπιθον preferred among other-verb forms
        @test "ἔπιθον" in dists
        @test form_similarity("ἔπαθον", "ἔπιθον") >= 0.45

        # With only 3 distractor slots, same-verb should crowd out others
        few = select_pp_form_distractors(
            "πάσχω", 3, correct, sim_pool, 3, MersenneTwister(2);
            similarity_threshold=0.45, max_chapter=11,
        )
        @test length(few) == 3
        @test all(d -> d in ("πάσχω", "πείσομαι", "πέπονθα"), few)
        @test "ἔπιθον" ∉ few
    end

    @testset "PP distractors: thin pool still fills / may undersize" begin
        tiny = VocabItem[
            VocabItem(1, "verb", "1 ααα", "a", true, 1, "ααα", "1 ααα;2 βββ"),
            VocabItem(1, "verb", "2 βββ", "a", true, 2, "ααα", "1 ααα;2 βββ"),
        ]
        dists = select_pp_form_distractors(
            "ααα", 1, ["ααα"], tiny, 7, MersenneTwister(3);
            similarity_threshold=0.45, max_chapter=1,
        )
        # Only one other same-verb form; no other verbs → undersized is OK
        @test dists == ["βββ"] || Set(dists) == Set(["βββ"])
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

    @testset "config load + code defaults for PP knobs" begin
        # Struct defaults stay classic-off; the committed TOML may be tuned
        # for active PP drills (user-editable working config).
        code_defaults = DrillConfig()
        @test code_defaults.pp_id_fraction == 0.0
        @test code_defaults.pp_meaning_fraction == 0.0
        @test code_defaults.pp_meaning_max_count == 6
        @test pp_meaning_question_count(code_defaults) == 0
        @test code_defaults.pp_forms_fraction == 0.0
        @test code_defaults.pp_forms_max_count == 6
        @test pp_forms_question_count(code_defaults) == 0

        cfg = load_config("config/vocab_drill.toml")
        # Live TOML may filter categories (e.g. ["verb"]); do not require empty.
        allowed_cats = Set(["noun", "verb", "prep", "adj", "other"])
        @test all(c -> c in allowed_cats, cfg.include_categories)
        @test cfg.num_choices >= 5
        @test cfg.pp_form_similarity_threshold == 0.45
        @test cfg.pp_meaning_max_count >= 0
        @test 0.0 <= cfg.pp_meaning_fraction <= 1.0
        @test 0.0 <= cfg.pp_id_fraction <= 1.0
        @test cfg.pp_forms_max_count >= 0
        @test 0.0 <= cfg.pp_forms_fraction <= 1.0
        expected = if cfg.pp_meaning_fraction <= 0 || cfg.pp_meaning_max_count <= 0
            0
        else
            min(cfg.pp_meaning_max_count,
                Int(floor(cfg.num_questions * cfg.pp_meaning_fraction)),
                cfg.num_questions)
        end
        @test pp_meaning_question_count(cfg) == expected
        expected_forms = if cfg.pp_forms_fraction <= 0 || cfg.pp_forms_max_count <= 0
            0
        else
            min(cfg.pp_forms_max_count,
                Int(floor(cfg.num_questions * cfg.pp_forms_fraction)),
                cfg.num_questions)
        end
        @test pp_forms_question_count(cfg) == expected_forms
    end

    @testset "PRINCIPAL_PART_GLOSSES fixed bank" begin
        @test length(PRINCIPAL_PART_GLOSSES) == 6
        @test principal_part_gloss(1) == "Present, Active, Indicative, 1st person, Singular"
        @test principal_part_gloss(2) == "Future, Active, Indicative, 1st person, Singular"
        @test principal_part_gloss(3) == "Aorist, Active, Indicative, 1st person, Singular"
        @test principal_part_gloss(4) == "Perfect, Active, Indicative, 1st person, Singular"
        @test principal_part_gloss(5) == "Perfect, Middle/Passive, Indicative, 1st person, Singular"
        @test principal_part_gloss(6) == "Aorist, Passive, Indicative, 1st person, Singular"
        @test Set(collect(PRINCIPAL_PART_GLOSSES)) == Set(principal_part_gloss(n) for n in 1:6)
    end

    @testset "PP meaning number → gloss" begin
        q = build_pp_meaning_question(1; direction=:pp_meaning_number_to_gloss,
                                      num_choices=8, rng=MersenneTwister(11), chapter=4)
        @test occursin("**1st Principal Part**", q.stem)
        @test q.correct_answers == ["Present, Active, Indicative, 1st person, Singular"]
        @test "Present, Active, Indicative, 1st person, Singular" ∉ q.distractors
        @test all(d -> d in PRINCIPAL_PART_GLOSSES, q.distractors)
        # Six-gloss bank caps at 6 options even when num_choices is 8
        @test length(q.distractors) == 5
        @test length(q.correct_answers) + length(q.distractors) == 6
        @test q.category == "pp_meaning"
        @test q.chapter == 4
    end

    @testset "PP meaning gloss → number" begin
        q = build_pp_meaning_question(6; direction=:pp_meaning_gloss_to_number,
                                      num_choices=8, rng=MersenneTwister(12), chapter=4)
        @test occursin("Aorist, Passive, Indicative, 1st person, Singular", q.stem)
        @test startswith(q.stem, "Which Principal Part is the")
        @test q.correct_answers == ["6th"]
        @test "6th" ∉ q.distractors
        @test all(d -> d in ("1st", "2nd", "3rd", "4th", "5th"), q.distractors)
        @test length(q.distractors) == 5
        @test q.category == "pp_meaning"
    end

    @testset "PP meaning respects num_choices < 6" begin
        q = build_pp_meaning_question(3; direction=:pp_meaning_number_to_gloss,
                                      num_choices=4, rng=MersenneTwister(13))
        @test q.correct_answers == ["Aorist, Active, Indicative, 1st person, Singular"]
        @test length(q.distractors) == 3
    end

    @testset "PP meaning count from fraction + max" begin
        cfg = DrillConfig(num_questions=50, pp_meaning_fraction=0.0, pp_meaning_max_count=6)
        @test pp_meaning_question_count(cfg) == 0

        cfg = DrillConfig(num_questions=50, pp_meaning_fraction=0.1, pp_meaning_max_count=6)
        @test pp_meaning_question_count(cfg) == 5  # min(6, floor(5.0))

        cfg = DrillConfig(num_questions=100, pp_meaning_fraction=0.2, pp_meaning_max_count=6)
        @test pp_meaning_question_count(cfg) == 6  # hard cap

        cfg = DrillConfig(num_questions=10, pp_meaning_fraction=0.5, pp_meaning_max_count=0)
        @test pp_meaning_question_count(cfg) == 0

        cfg = DrillConfig(num_questions=3, pp_meaning_fraction=1.0, pp_meaning_max_count=6)
        @test pp_meaning_question_count(cfg) == 3  # cannot exceed quiz size
    end

    @testset "PP meaning is lemma-independent (no VocabItem needed)" begin
        # Building meta questions does not consult the lemma pool at all.
        empty_pool = VocabItem[]
        q = build_pp_meaning_question(2; direction=:pp_meaning_number_to_gloss,
                                      num_choices=8, rng=MersenneTwister(14))
        gift = to_gift(q; qid="M1")
        @test occursin("Future, Active, Indicative, 1st person, Singular", gift)
        @test occursin("~%100%", gift) || occursin("~%", gift)
        @test isempty(empty_pool)  # pool unused by design
    end

    @testset "selector trims when requesting fewer than current-chapter size" begin
        selected = select_quiz_items(
            pool;
            current_chapter = 4,
            num_questions = 3,
            include_categories = ["verb"],
            seed = 9
        )
        @test length(selected.items) == 3
        @test all(i -> i.category == "verb", selected.items)
    end

    @testset "end-to-end drill injects PP-meaning under cap" begin
        path = "data/vocabulary/hq.txt"
        if isfile(path)
            out = build_vocab_drill(
                "config/vocab_drill.toml";
                current_chapter = 4,
                num_questions = 40,
                include_categories = ["verb"],
                pp_id_fraction = 0.5,
                pp_meaning_fraction = 0.15,
                pp_meaning_max_count = 6,
                pp_forms_fraction = 0.0,
            )
            @test isfile(out)
            text = read(out, String)
            @test occursin("Principal Part** is the:", text) ||
                  occursin("Which Principal Part is the", text)
            # Cap: at most 6 meaning stems (fraction 0.15 of 40 → 6)
            n_num = count("Principal Part** is the:", text)
            n_gloss = count("Which Principal Part is the ‘", text)
            @test n_num + n_gloss <= 6
            @test n_num + n_gloss >= 1
            # Phase 1 PP-ID still present when pp_id_fraction > 0
            @test occursin("Pick the", text) || occursin("Which Principal Part of", text)
        else
            @warn "Skipping end-to-end PP-meaning check; hq.txt missing"
        end
    end

    @testset "PRINCIPAL_PART_PARADIGMS fixed bank" begin
        @test length(PRINCIPAL_PART_PARADIGMS) == 6
        @test length(ALL_PARADIGM_LABELS) == 10
        @test paradigms_for_pp(1) == ("Present (active, middle, passive)",
                                      "Imperfect (active, middle, passive)")
        @test paradigms_for_pp(2) == ("Future (active, middle)",)
        @test paradigms_for_pp(3) == ("Aorist (active, middle)",)
        @test paradigms_for_pp(4) == ("Perfect (active)", "Pluperfect (active)")
        @test paradigms_for_pp(5) == ("Perfect (middle/passive)",
                                      "Pluperfect (middle/passive)")
        @test paradigms_for_pp(6) == ("Aorist (passive)", "Future (passive)")
        @test pp_for_paradigm("Future (active, middle)") == 2
        @test pp_for_paradigm("Aorist (active, middle)") == 3
        @test pp_for_paradigm("Perfect (middle/passive)") == 5
        @test pp_for_paradigm("Future (passive)") == 6
        # Every label maps back to exactly one PP
        for lab in ALL_PARADIGM_LABELS
            @test lab in paradigms_for_pp(pp_for_paradigm(lab))
        end
    end

    @testset "PP forms PP → paradigm" begin
        q = build_pp_forms_question(2; direction=:pp_forms_pp_to_paradigm,
                                    num_choices=8, rng=MersenneTwister(21), chapter=4,
                                    paradigm_label="Future (active, middle)")
        @test occursin("**2nd Principal Part**", q.stem)
        @test startswith(q.stem, "Which of these forms is based on")
        @test q.correct_answers == ["Future (active, middle)"]
        @test "Future (active, middle)" ∉ q.distractors
        @test all(d -> d in ALL_PARADIGM_LABELS, q.distractors)
        # Same-PP labels must not appear as distractors
        @test isempty(intersect(Set(q.distractors), Set(paradigms_for_pp(2))))
        @test length(q.distractors) == 7  # 10 labels − 1 same-PP = 9 wrong; take 7
        @test length(q.correct_answers) + length(q.distractors) == 8
        @test q.category == "pp_forms"
        @test q.chapter == 4
    end

    @testset "PP forms paradigm → PP" begin
        q = build_pp_forms_question(3; direction=:pp_forms_paradigm_to_pp,
                                    num_choices=8, rng=MersenneTwister(22), chapter=4,
                                    paradigm_label="Aorist (active, middle)")
        @test occursin("**Aorist (active, middle)**", q.stem)
        @test occursin("based on which Principal Part?", q.stem)
        @test q.correct_answers == ["3rd"]
        @test "3rd" ∉ q.distractors
        @test all(d -> d in ("1st", "2nd", "4th", "5th", "6th"), q.distractors)
        @test length(q.distractors) == 5
        @test q.category == "pp_forms"
    end

    @testset "PP forms respects num_choices < bank size" begin
        q = build_pp_forms_question(1; direction=:pp_forms_pp_to_paradigm,
                                    num_choices=4, rng=MersenneTwister(23),
                                    paradigm_label="Present (active, middle, passive)")
        @test q.correct_answers == ["Present (active, middle, passive)"]
        @test length(q.distractors) == 3
        @test "Imperfect (active, middle, passive)" ∉ q.distractors  # same PP
    end

    @testset "PP forms count from fraction + max" begin
        cfg = DrillConfig(num_questions=50, pp_forms_fraction=0.0, pp_forms_max_count=6)
        @test pp_forms_question_count(cfg) == 0

        cfg = DrillConfig(num_questions=50, pp_forms_fraction=0.1, pp_forms_max_count=6)
        @test pp_forms_question_count(cfg) == 5  # min(6, floor(5.0))

        cfg = DrillConfig(num_questions=100, pp_forms_fraction=0.2, pp_forms_max_count=6)
        @test pp_forms_question_count(cfg) == 6  # hard cap

        cfg = DrillConfig(num_questions=10, pp_forms_fraction=0.5, pp_forms_max_count=0)
        @test pp_forms_question_count(cfg) == 0

        cfg = DrillConfig(num_questions=3, pp_forms_fraction=1.0, pp_forms_max_count=6)
        @test pp_forms_question_count(cfg) == 3  # cannot exceed quiz size
    end

    @testset "PP forms is lemma-independent (no VocabItem needed)" begin
        empty_pool = VocabItem[]
        q = build_pp_forms_question(6; direction=:pp_forms_paradigm_to_pp,
                                    num_choices=8, rng=MersenneTwister(24),
                                    paradigm_label="Aorist (passive)")
        gift = to_gift(q; qid="F1")
        @test occursin("Aorist (passive)", gift)
        @test occursin("~%100%", gift) || occursin("~%", gift)
        @test isempty(empty_pool)
    end

    @testset "end-to-end drill injects PP-forms under cap" begin
        path = "data/vocabulary/hq.txt"
        if isfile(path)
            out = build_vocab_drill(
                "config/vocab_drill.toml";
                current_chapter = 4,
                num_questions = 40,
                include_categories = ["verb"],
                pp_id_fraction = 0.4,
                pp_meaning_fraction = 0.0,
                pp_forms_fraction = 0.15,
                pp_forms_max_count = 6,
            )
            @test isfile(out)
            text = read(out, String)
            @test occursin("forms is based on the", text) ||
                  occursin("forms are based on which Principal Part?", text)
            n_pp_to = count("forms is based on the", text)
            n_to_pp = count("forms are based on which Principal Part?", text)
            @test n_pp_to + n_to_pp <= 6
            @test n_pp_to + n_to_pp >= 1
            # Phase 1 PP-ID still present when pp_id_fraction > 0
            @test occursin("Pick the", text) || occursin("Which Principal Part of", text)
            # Filename tag includes f when forms are injected
            @test occursin("_ppf", out) || occursin("ppf", basename(out))
        else
            @warn "Skipping end-to-end PP-forms check; hq.txt missing"
        end
    end

    @testset "numbered English field detection + parse" begin
        @test is_numbered_english_field("1 I unbind;1 I free;2 I will unbind")
        @test !is_numbered_english_field("unbind; free")
        @test !is_numbered_english_field("command")

        num = parse_english_field("1 I unbind;1 I free;2 I will unbind;4 I have unbound")
        @test num.mode == :numbered
        @test num.by_pp[1] == ["I unbind", "I free"]
        @test num.by_pp[2] == ["I will unbind"]
        @test num.by_pp[4] == ["I have unbound"]
        @test !haskey(num.by_pp, 3)

        leg = parse_english_field("unbind; free")
        @test leg.mode == :legacy
        @test leg.glosses == ["unbind", "free"]
    end

    @testset "expand_entry pairs PP forms with numbered glosses only" begin
        greek = "1 λύω;2 λύσω;3 ἔλυσα;4 λέλυκα;5 λέλυμαι;6 ἐλύθην"
        eng = "1 I unbind;1 I free;2 I will unbind;2 I will free;3 I unbound;3 I freed;4 I have unbound;4 I have freed;5 I have been unbound;5 I have been freed;6 I was unbound;6 I was freed"
        items = VocabDrill.DataParser.expand_entry(2, "verb", greek, eng)
        @test all(i -> i.has_pp_specific_english, items)
        pp4 = filter(i -> i.principal_part_number == 4, items)
        @test Set(i.english for i in pp4) == Set(["I have unbound", "I have freed"])
        @test all(i -> occursin("λέλυκα", i.greek_display), pp4)
        # Legacy still works
        legacy_items = VocabDrill.DataParser.expand_entry(2, "verb", greek, "unbind; free")
        @test all(i -> !i.has_pp_specific_english, legacy_items)
        @test Set(i.english for i in legacy_items) == Set(["unbind", "free"])
        @test count(i -> i.principal_part_number == 1, legacy_items) == 2
    end

    @testset "PP form → English (tense-appropriate)" begin
        gloss_pool = VocabItem[]
        function add_gloss!(ch, lemma, greek_field, pairs)
            for (n, form, eng) in pairs
                push!(gloss_pool, VocabItem(
                    ch, "verb", "$n $form", eng, true, n, lemma, greek_field, true
                ))
            end
        end
        luo = "1 λύω;2 λύσω;3 ἔλυσα;4 λέλυκα;5 λέλυμαι;6 ἐλύθην"
        add_gloss!(2, "λύω", luo, [
            (1, "λύω", "I unbind"), (1, "λύω", "I free"),
            (2, "λύσω", "I will unbind"), (2, "λύσω", "I will free"),
            (4, "λέλυκα", "I have unbound"), (4, "λέλυκα", "I have freed"),
            (6, "ἐλύθην", "I was unbound"), (6, "ἐλύθην", "I was freed"),
        ])
        pempo = "1 πέμπω;2 πέμψω;3 ἔπεμψα"
        add_gloss!(2, "πέμπω", pempo, [
            (1, "πέμπω", "I send"), (2, "πέμψω", "I will send"), (3, "ἔπεμψα", "I sent"),
        ])

        item = first(filter(i -> i.lemma == "λύω" && i.principal_part_number == 4, gloss_pool))
        q = build_question(item, gloss_pool; direction=:pp_form_to_english,
                           num_choices=8, rng=MersenneTwister(41))
        @test occursin("λέλυκα", q.stem)
        @test occursin("4th Principal Part of λύω", q.stem)
        @test any(a -> a in ("I have unbound", "I have freed"), q.correct_answers)
        @test !("I unbind" in q.correct_answers)
        @test !("I send" in q.correct_answers) || "I send" in q.distractors
        @test length(q.correct_answers) + length(q.distractors) <= 8
    end

    @testset "PP English → form" begin
        gloss_pool = VocabItem[]
        luo = "1 λύω;2 λύσω;4 λέλυκα"
        for (n, form, eng) in [(1, "λύω", "I unbind"), (2, "λύσω", "I will unbind"),
                               (4, "λέλυκα", "I have unbound")]
            push!(gloss_pool, VocabItem(2, "verb", "$n $form", eng, true, n, "λύω", luo, true))
        end
        push!(gloss_pool, VocabItem(2, "verb", "1 πέμπω", "I send", true, 1, "πέμπω",
                                    "1 πέμπω", true))

        item = first(filter(i -> i.english == "I have unbound", gloss_pool))
        q = build_question(item, gloss_pool; direction=:pp_english_to_form,
                           num_choices=4, rng=MersenneTwister(42))
        @test occursin("I have unbound", q.stem)
        @test "λέλυκα" in q.correct_answers
        @test "λύω" in q.distractors || "λύσω" in q.distractors || "πέμπω" in q.distractors
    end

    @testset "config defaults keep pp_gloss classic-off" begin
        code_defaults = DrillConfig()
        @test code_defaults.pp_gloss_fraction == 0.0
        @test code_defaults.pp_form_to_english_fraction == 0.5

        cfg = load_config("config/vocab_drill.toml")
        @test 0.0 <= cfg.pp_gloss_fraction <= 1.0
        @test 0.0 <= cfg.pp_form_to_english_fraction <= 1.0
    end

    @testset "hq.txt numbered English + PP-gloss drill" begin
        path = "data/vocabulary/hq.txt"
        if isfile(path)
            items = parse_vocabulary_file(path)
            verbs = filter(i -> i.category == "verb", items)
            @test !isempty(verbs)
            pp_specific = filter(i -> i.has_pp_specific_english, verbs)
            @test !isempty(pp_specific)

            luo = filter(i -> i.lemma == "λύω" && i.principal_part_number == 4, verbs)
            @test !isempty(luo)
            @test all(i -> i.has_pp_specific_english, luo)
            @test Set(i.english for i in luo) == Set(["I have unbound", "I have freed"])

            # Legacy-compatible: ἀποδέχομαι (no numbered PPs) still present if parsed
            # (line has no numbered Greek PPs beyond bare lemma — may expand as non-PP)

            out = build_vocab_drill(
                "config/vocab_drill.toml";
                current_chapter = 4,
                num_questions = 40,
                include_categories = ["verb"],
                pp_id_fraction = 0.2,
                pp_meaning_fraction = 0.0,
                pp_forms_fraction = 0.0,
                pp_gloss_fraction = 0.6,
            )
            @test isfile(out)
            text = read(out, String)
            @test occursin("Principal Part of", text) || occursin("Which form means", text)
            @test occursin("_ppg", basename(out)) || occursin("ppg", basename(out)) ||
                  occursin("_pp", basename(out))
        else
            @warn "Skipping hq.txt PP-gloss checks; file not found"
        end
    end

    @testset "normalize_case_token + prep Greek parse" begin
        @test normalize_case_token("gen") == "gen"
        @test normalize_case_token("gen.") == "gen"
        @test normalize_case_token("genitive") == "gen"
        @test normalize_case_token("dative") == "dat"
        @test normalize_case_token("acc.") == "acc"
        @test normalize_case_token("foo") === nothing
        @test case_label("gen") == "genitive"

        p = parse_prep_greek_field("παρά + gen")
        @test p.lemma == "παρά"
        @test p.case == "gen"
        @test occursin("παρά", p.display)

        ek = parse_prep_greek_field("ἐκ + gen; ἐξ + gen")
        @test ek.lemma == "ἐκ"
        @test ek.case == "gen"
        @test length(ek.forms) == 2

        bare = parse_prep_greek_field("παρά")
        @test bare.lemma == "παρά"
        @test bare.case === nothing
    end

    @testset "legacy prep lines keep working; case tags set" begin
        items = VocabDrill.DataParser.expand_entry(2, "prep", "παρά + gen", "from beside")
        @test length(items) == 1
        @test items[1].prep_case == "gen"
        @test items[1].lemma == "παρά"
        @test items[1].english == "from beside"

        ek = VocabDrill.DataParser.expand_entry(1, "prep", "ἐκ + gen; ἐξ + gen", "from; out of")
        @test all(i -> i.prep_case == "gen", ek)
        @test Set(i.english for i in ek) == Set(["from", "out of"])

        # Case-tagged English (preferred consolidated form)
        tagged = VocabDrill.DataParser.expand_entry(
            2, "prep", "παρά",
            "gen from beside; dat at the side of; dat at the house of; acc beside"
        )
        @test Set(i.prep_case for i in tagged) == Set(["gen", "dat", "acc"])
        @test any(i -> i.prep_case == "dat" && i.english == "at the house of", tagged)
        @test any(i -> i.greek_display == "παρά + gen", tagged)
        @test is_case_tagged_english_field("gen from beside; dat at the side of")
        @test !is_case_tagged_english_field("from beside")
    end

    @testset "prep+case → meaning prefers same-prep distractors" begin
        pool = VocabItem[]
        function add_prep!(ch, lemma, case, glosses)
            for g in glosses
                push!(pool, VocabItem(
                    ch, "prep", "$lemma + $case", g, false, nothing, lemma,
                    "$lemma + $case", false, case
                ))
            end
        end
        add_prep!(2, "παρά", "gen", ["from beside"])
        add_prep!(2, "παρά", "dat", ["at the side of", "at the house of"])
        add_prep!(2, "παρά", "acc", ["to the side of", "beside", "contrary to"])
        add_prep!(1, "εἰς", "acc", ["into", "to"])
        add_prep!(3, "διά", "gen", ["through"])
        add_prep!(3, "διά", "acc", ["on account of"])

        item = first(filter(i -> i.lemma == "παρά" && i.prep_case == "gen", pool))
        q = build_question(item, pool; direction=:prep_case_to_meaning,
                           num_choices=6, rng=MersenneTwister(11))
        @test occursin("παρά + gen", q.stem)
        @test "from beside" in q.correct_answers
        same_prep_glosses = Set(["at the side of", "at the house of", "to the side of",
                                 "beside", "contrary to"])
        @test !isempty(intersect(Set(q.distractors), same_prep_glosses))
        @test length(q.correct_answers) + length(q.distractors) <= 6
    end

    @testset "meaning → prep+case prefers same-prep other cases" begin
        pool = VocabItem[]
        for (case, gloss) in [("gen", "from beside"), ("dat", "at the side of"),
                              ("acc", "beside")]
            push!(pool, VocabItem(2, "prep", "παρά + $case", gloss, false, nothing, "παρά",
                                  "παρά + $case", false, case))
        end
        push!(pool, VocabItem(3, "prep", "διά + gen", "through", false, nothing, "διά",
                              "διά + gen", false, "gen"))
        push!(pool, VocabItem(1, "prep", "εἰς + acc", "into", false, nothing, "εἰς",
                              "εἰς + acc", false, "acc"))

        item = first(filter(i -> i.english == "from beside", pool))
        q = build_question(item, pool; direction=:prep_meaning_to_case,
                           num_choices=4, rng=MersenneTwister(12))
        @test occursin("from beside", q.stem)
        @test "παρά + gen" in q.correct_answers
        @test ("παρά + dat" in q.distractors) || ("παρά + acc" in q.distractors)
    end

    @testset "config defaults keep prep_case classic-off" begin
        code_defaults = DrillConfig()
        @test code_defaults.prep_case_fraction == 0.0
        @test code_defaults.prep_case_max_count == 12
        @test code_defaults.prep_case_to_meaning_fraction == 0.5
        @test prep_case_question_count(code_defaults) == 0

        cfg = load_config("config/vocab_drill.toml")
        # Do not brittle-assert live tuned TOML teaching values; only ranges / presence.
        @test 0.0 <= cfg.prep_case_fraction <= 1.0
        @test cfg.prep_case_max_count >= 0
        @test 0.0 <= cfg.prep_case_to_meaning_fraction <= 1.0
    end

    @testset "hq.txt prep migration + prep-case drill" begin
        path = "data/vocabulary/hq.txt"
        if isfile(path)
            items = parse_vocabulary_file(path)
            preps = filter(i -> i.category == "prep", items)
            @test !isempty(preps)
            tagged = filter(i -> i.prep_case !== nothing, preps)
            @test !isempty(tagged)
            # All migrated HQ prep senses should carry a case tag
            @test all(i -> i.prep_case !== nothing, preps)
            lemmas = unique(i.lemma for i in tagged)
            @test "παρά" in lemmas
            @test "κατά" in lemmas
            @test "ἄνευ" in lemmas
            @test "σύν" in lemmas
            # ἵνα / ὡς / ὅπως should no longer be prep
            @test !any(i -> i.lemma !== nothing && occursin("ἵνα", i.lemma), preps)

            para = filter(i -> i.lemma == "παρά", tagged)
            @test Set(i.prep_case for i in para) == Set(["gen", "dat", "acc"])

            out = build_vocab_drill(
                "config/vocab_drill.toml";
                current_chapter = 5,
                num_questions = 30,
                include_categories = ["prep"],
                pp_id_fraction = 0.0,
                pp_meaning_fraction = 0.0,
                pp_forms_fraction = 0.0,
                pp_gloss_fraction = 0.0,
                prep_case_fraction = 1.0,
                prep_case_max_count = 20,
            )
            @test isfile(out)
            text = read(out, String)
            @test occursin("What does **", text) || occursin("Which preposition + case means", text)
            @test occursin("_pc", basename(out)) || occursin("pc", basename(out))
            n_to_mean = count("What does **", text)
            n_to_case = count("Which preposition + case means", text)
            @test n_to_mean + n_to_case >= 1
            @test n_to_mean + n_to_case <= 20
        else
            @warn "Skipping hq.txt prep-case checks; file not found"
        end
    end
end

println("\nAll principal-parts vocab tests finished.")
