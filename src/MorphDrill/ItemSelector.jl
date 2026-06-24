# src/MorphDrill/ItemSelector.jl

module ItemSelector

const DataParser = parentmodule(@__MODULE__).DataParser

export select_morph_forms

using Random

function select_morph_forms(all_forms::Vector{DataParser.MorphForm};
                            num_questions::Int,
                            seed::Union{Int, Nothing} = nothing)
    rng = seed === nothing ? Random.default_rng() : MersenneTwister(seed)

    n = min(num_questions, length(all_forms))
    if n == 0
        return DataParser.MorphForm[]
    end

    selected = rand(rng, all_forms, n)
    shuffle!(rng, selected)
    return selected
end

end # module ItemSelector