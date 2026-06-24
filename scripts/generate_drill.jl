#!/usr/bin/env julia

"""
generate_drill.jl

Command-line vocabulary drill generator for Donafer.

Usage examples:
    julia --project=. generate_drill.jl
    julia --project=. generate_drill.jl --chapter 4 --questions 80
    julia --project=. generate_drill.jl -c 5 -q 120
    julia --project=. generate_drill.jl --config config/custom.toml -c 3
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

    # Call with overrides if provided
    output_file = build_vocab_drill(
        args["config"];
        current_chapter = args["chapter"],
        num_questions   = args["questions"]
    )
    println("\n✅ Done!")
    println("   Output file : $output_file")
end

main()