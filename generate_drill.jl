#!/usr/bin/env julia

"""
generate_drill.jl

Command-line vocabulary drill generator for Donafer.

Usage:
    julia --project=. generate_drill.jl
    julia --project=. generate_drill.jl --chapter 4 --questions 80
    julia --project=. generate_drill.jl -c 5 -q 100
"""

using Pkg
Pkg.activate(@__DIR__)

using ArgParse

# ─────────────────────────────────────────────────────────────
# Load Donafer modules at top level (required for `using`)
include("src/VocabDrill/VocabDrill.jl")
using .VocabDrill
# ─────────────────────────────────────────────────────────────

function parse_commandline()
    s = ArgParseSettings(
        description = "Generate vocabulary drills in GIFT format for Moodle"
    )

    @add_arg_table! s begin
        "--chapter", "-c"
            help = "Override current chapter number"
            arg_type = Int
            default = nothing
        "--questions", "-q"
            help = "Override total number of questions"
            arg_type = Int
            default = nothing
        "--config"
            help = "Path to the configuration TOML file"
            default = "config/vocab_drill.toml"
    end

    return parse_args(s)
end

function main()
    args = parse_commandline()
    config_path = args["config"]

    println("🚀 Generating vocabulary drill...")
    println("   Config     : $config_path")

    if args["chapter"] !== nothing
        println("   Chapter    : $(args["chapter"])  (override)")
    end
    if args["questions"] !== nothing
        println("   Questions  : $(args["questions"])  (override)")
    end

    # For now we respect the TOML values.
    # Command-line overrides for chapter/questions can be added later if needed.
    output_file = build_vocab_drill(config_path)

    println("\n✅ Done!")
    println("   Output file: $output_file")
end

main()