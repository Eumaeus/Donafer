#!/usr/bin/env julia

"""
generate_drill.jl

Command-line vocabulary drill generator for Donafer.

Usage examples:
    julia --project=. scripts/generate_vocab_drill.jl
    julia --project=. scripts/generate_vocab_drill.jl --chapter 4 --questions 80
    julia --project=. scripts/generate_vocab_drill.jl -c 5 -q 120
    julia --project=. scripts/generate_vocab_drill.jl --config config/custom.toml -c 3
    julia --project=. scripts/generate_vocab_drill.jl --categories verb --pp-id 0.6 -c 4
    julia --project=. scripts/generate_vocab_drill.jl --categories verb --pp-id 0.5 --pp-meaning 0.1 -c 4 -q 50
    julia --project=. scripts/generate_vocab_drill.jl --categories verb --pp-forms 0.15 --pp-forms-max 6 -c 4 -q 50
    julia --project=. scripts/generate_vocab_drill.jl --categories verb --pp-gloss 0.5 --pp-id 0.3 -c 4 -q 50
"""

# The below are unnecessary if launching with `julia --project=. …`
#using Pkg
#Pkg.activate(@__DIR__)

using ArgParse

# Load Donafer modules at top level
include("../src/VocabDrill/VocabDrill.jl")
using .VocabDrill

function parse_commandline()
    s = ArgParseSettings(
        description = "Generate vocabulary drills in GIFT format for Moodle"
    )

    @add_arg_table! s begin
        "--chapter", "-c"
            help = "Override current chapter (from config)"
            arg_type = Int
            default = nothing
        "--questions", "-q"
            help = "Override total number of questions"
            arg_type = Int
            default = nothing
        "--categories"
            help = "Comma-separated category filter (e.g. verb). Empty = all."
            arg_type = String
            default = nothing
        "--pp-id"
            help = "Fraction of lemma questions that are principal-part identification (0–1)"
            arg_type = Float64
            default = nothing
        "--pp-meaning"
            help = "Fraction of the quiz reserved for lemma-independent “what each PP is” questions (0–1)"
            arg_type = Float64
            default = nothing
        "--pp-meaning-max"
            help = "Hard cap on PP-meaning questions per quiz"
            arg_type = Int
            default = nothing
        "--pp-forms"
            help = "Fraction of the quiz reserved for lemma-independent “forms from PP” questions (0–1)"
            arg_type = Float64
            default = nothing
        "--pp-forms-max"
            help = "Hard cap on PP-forms questions per quiz"
            arg_type = Int
            default = nothing
        "--pp-gloss"
            help = "Fraction of lemma questions that match PP form ↔ tense-appropriate English (0–1; needs numbered English data)"
            arg_type = Float64
            default = nothing
        "--config"
            help = "Path to configuration TOML file"
            default = "config/vocab_drill.toml"
    end

    return parse_args(s)
end

function main()
    args = parse_commandline()

    println("🚀 Generating vocabulary drill...")
    println("   Config file : $(args["config"])")

    if args["chapter"] !== nothing
        println("   Chapter     : $(args["chapter"])  ← override")
    end
    if args["questions"] !== nothing
        println("   Questions   : $(args["questions"])  ← override")
    end
    if args["categories"] !== nothing
        println("   Categories  : $(args["categories"])  ← override")
    end
    if args["pp-id"] !== nothing
        println("   PP-ID frac  : $(args["pp-id"])  ← override")
    end
    if args["pp-meaning"] !== nothing
        println("   PP-meaning  : $(args["pp-meaning"])  ← override")
    end
    if args["pp-meaning-max"] !== nothing
        println("   PP-mean max : $(args["pp-meaning-max"])  ← override")
    end
    if args["pp-forms"] !== nothing
        println("   PP-forms    : $(args["pp-forms"])  ← override")
    end
    if args["pp-forms-max"] !== nothing
        println("   PP-forms max: $(args["pp-forms-max"])  ← override")
    end
    if args["pp-gloss"] !== nothing
        println("   PP-gloss    : $(args["pp-gloss"])  ← override")
    end

    # Call with overrides if provided
    output_file = build_vocab_drill(
        args["config"];
        current_chapter = args["chapter"],
        num_questions   = args["questions"],
        include_categories = args["categories"],
        pp_id_fraction  = args["pp-id"],
        pp_meaning_fraction = args["pp-meaning"],
        pp_meaning_max_count = args["pp-meaning-max"],
        pp_forms_fraction = args["pp-forms"],
        pp_forms_max_count = args["pp-forms-max"],
        pp_gloss_fraction = args["pp-gloss"],
    )
    println("\n✅ Done!")
    println("   Output file : $output_file")
end

main()
