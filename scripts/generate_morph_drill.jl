#!/usr/bin/env julia

"""
generate_morph_drill.jl

Command-line morphology drill generator for Donafer (Hansen & Quinn).

Usage:
    julia --project=. scripts/generate_morph_drill.jl
    julia --project=. scripts/generate_morph_drill.jl -c 4 -q 100
    julia --project=. scripts/generate_morph_drill.jl --categories "noun,adjective"
"""

using ArgParse

include("../src/MorphDrill/MorphDrill.jl")
using .MorphDrill

function parse_commandline()
    s = ArgParseSettings(description = "Generate morphology drills in GIFT format")

    @add_arg_table! s begin
        "--chapter", "-c"
            help = "Override current chapter"
            arg_type = Int
            default = nothing
        "--questions", "-q"
            help = "Override number of questions"
            arg_type = Int
            default = nothing
        "--categories", "-C"
            help = "Override categories (comma-separated, e.g. noun,adjective)"
            default = nothing
        "--config"
            help = "Path to config file"
            default = "config/morph_drill.toml"
    end

    return parse_args(s)
end

function main()
    args = parse_commandline()

    println("Generating morphology drill...")
    println("   Config: $(args["config"])")

    if args["chapter"] !== nothing
        println("   Chapter override: $(args["chapter"])")
    end
    if args["questions"] !== nothing
        println("   Questions override: $(args["questions"])")
    end
    if args["categories"] !== nothing
        println("   Categories override: $(args["categories"])")
    end

    output_file = build_morph_drill(
        args["config"];
        current_chapter = args["chapter"],
        num_questions   = args["questions"],
        categories      = args["categories"]
    )

    println("\nDone!")
    println("   Output: $output_file")
end

main()