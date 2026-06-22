#!/usr/bin/env julia

"""
generate_drill.jl

One-command generator for vocabulary drills.
Usage:
    julia --project=. generate_drill.jl
    julia --project=. generate_drill.jl path/to/custom.config.toml
"""

using Pkg
Pkg.activate(@__DIR__)
# Pkg.instantiate()   # uncomment the first time if you want it fully automatic

include("src/VocabDrill/VocabDrill.jl")
using .VocabDrill

config_path = length(ARGS) ≥ 1 ? ARGS[1] : "config/vocab_drill.toml"

println("🚀 Generating vocabulary drill...")
println("   Config: $config_path")

output_file = build_vocab_drill(config_path)

println("\n✅ Success!")
println("   GIFT file written to: $output_file")
println("   Ready for Moodle import.")