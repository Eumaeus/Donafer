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
            help = "Fraction of questions that are principal-part identification (0–1)"
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

    # Call with overrides if provided
    output_file = build_vocab_drill(
        args["config"];
        current_chapter = args["chapter"],
        num_questions   = args["questions"],
        include_categories = args["categories"],
        pp_id_fraction  = args["pp-id"]
    )
    println("\n✅ Done!")
    println("   Output file : $output_file")
end

main()
