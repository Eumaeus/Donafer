# src/MorphDrill/DataParser.jl

module DataParser

export MorphForm, parse_morphology_forms

struct MorphForm
    chapter::Int
    category::String
    lemma::String
    description::String
    greek_form::String
    forms_file::String
end

"""
Build a map from basename to full path by walking the forms directory once.
This works with arbitrarily deep/nested folder structures.
"""
function build_forms_index(forms_root::String)::Dict{String, String}
    index = Dict{String, String}()
    for (dir, _, files) in walkdir(forms_root)
        for f in files
            if endswith(f, ".txt")
                if haskey(index, f)
                    @warn "Duplicate filename found: $f (keeping first occurrence)"
                else
                    index[f] = joinpath(dir, f)
                end
            end
        end
    end
    return index
end

function parse_forms_file(full_path::String, chapter::Int, category::String,
                          basename::String, include_vocative::Bool, include_dual::Bool)
    lines = readlines(full_path)
    if length(lines) < 2
        error("Invalid forms file (too short): $full_path")
    end

    template_name = split(lines[1], "#")[2]
    lemma = split(lines[2], "#")[2]

    template_dir = joinpath(dirname(dirname(full_path)), "templates")
    template_path = joinpath(template_dir, template_name)
    template_lines = readlines(template_path)

    descriptions = String[]
    for line in template_lines
        s = strip(line)
        if !isempty(s) && !startswith(s, "//")
            push!(descriptions, s)
        end
    end

    greek_forms = String[]
    for line in lines[3:end]
        s = strip(line)
        if !isempty(s) && !startswith(s, "//")
            push!(greek_forms, s)
        end
    end

    if length(descriptions) != length(greek_forms)
        @warn "Length mismatch in $basename: $(length(descriptions)) descriptions vs $(length(greek_forms)) forms"
    end

    forms = MorphForm[]
    for (desc, form) in zip(descriptions, greek_forms)
        if !include_vocative && occursin("voc.", desc) continue end
        if !include_dual && occursin("dual", lowercase(desc)) continue end
        push!(forms, MorphForm(chapter, category, lemma, desc, form, basename))
    end
    return forms
end

function parse_morphology_forms(chapters_file::String, forms_root::String,
                                include_categories::Vector{String},
                                from_chapter::Int, current_chapter::Int,
                                include_vocative::Bool, include_dual::Bool)
    forms_index = build_forms_index(forms_root)
    println("Built forms index with $(length(forms_index)) .txt files")  # helpful during testing

    all_forms = MorphForm[]

    lines = readlines(chapters_file)
    for line in lines
        s = strip(line)
        if isempty(s) || startswith(s, "//") continue end

        parts = split(s, '\t')
        length(parts) == 3 || continue

        ch = parse(Int, parts[1])
        cat = strip(parts[2])
        fname = strip(parts[3])

        if ch < from_chapter || ch > current_chapter continue end
        if !(cat in include_categories) continue end

        if !haskey(forms_index, fname)
            @warn "Forms file not found in index: $fname"
            continue
        end

        full_path = forms_index[fname]
        try
            parsed = parse_forms_file(full_path, ch, cat, fname, include_vocative, include_dual)
            append!(all_forms, parsed)
        catch e
            @warn "Could not parse forms file $fname: $e"
        end
    end

    return all_forms
end

end # module DataParser