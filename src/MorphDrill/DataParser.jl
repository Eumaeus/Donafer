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

function build_forms_index(forms_root::String)::Dict{String,String}
    index = Dict{String,String}()
    for (dir, _, files) in walkdir(forms_root)
        for f in files
            if endswith(lowercase(f), ".txt")
                if !haskey(index, f)
                    index[f] = joinpath(dir, f)
                end
            end
        end
    end
    return index
end

function parse_forms_file(full_path::AbstractString, chapter::Int, category::AbstractString,
                          basename::AbstractString, include_vocative::Bool, include_dual::Bool,
                          template_root::AbstractString)

    lines = readlines(full_path)

    if length(lines) < 2
        error("Too few lines in $basename")
    end

    template_name = split(lines[1], "#", limit=2)[2]
    lemma = split(lines[2], "#", limit=2)[2]

    template_path = joinpath(template_root, template_name)

    if !isfile(template_path)
        error("Missing template '$template_name' for $basename")
    end

    template_lines = readlines(template_path)
    descriptions = [strip(l) for l in template_lines 
                    if !isempty(strip(l)) && !startswith(strip(l), "//")]

    greek_forms = String[]
    for line in lines[3:end]
        s = strip(line)
        if !isempty(s) && !startswith(s, "//")
            push!(greek_forms, s)
        end
    end

    if length(descriptions) != length(greek_forms)
        @warn "Line count mismatch in $basename"
    end

    forms = MorphForm[]
    for (desc, form) in zip(descriptions, greek_forms)
        skip = false
        if !include_vocative && occursin("voc.", desc) skip = true end
        if !include_dual && occursin("dual", lowercase(desc)) skip = true end
        if !skip
            push!(forms, MorphForm(chapter, category, lemma, desc, form, basename))
        end
    end

    return forms
end

function parse_morphology_forms(chapters_file::String, forms_root::String,
                                include_categories::Vector{String},
                                from_chapter::Int, current_chapter::Int,
                                include_vocative::Bool, include_dual::Bool)

    forms_index = build_forms_index(forms_root)
    println("Built forms index with $(length(forms_index)) .txt files")

    # Compute template root once from the reliable forms_root
    morphology_root = dirname(forms_root)          # data/morphology
    template_root = joinpath(morphology_root, "templates")

    all_forms = MorphForm[]

    for raw in readlines(chapters_file)
        line = strip(raw)
        isempty(line) || startswith(line, "//") && continue

        parts = split(line, '\t')
        length(parts) == 3 || continue

        ch = parse(Int, parts[1])
        cat = strip(parts[2])
        fname = strip(parts[3])

        (ch < from_chapter || ch > current_chapter) && continue
        !(cat in include_categories) && continue

        if !haskey(forms_index, fname)
            @warn "Not found in index: $fname"
            continue
        end

        full_path = forms_index[fname]

        try
            parsed = parse_forms_file(full_path, ch, cat, fname, include_vocative, include_dual, template_root)
            append!(all_forms, parsed)
        catch e
            @warn "Failed to parse $fname" exception=(e, catch_backtrace())
        end
    end

    return all_forms
end

end # module DataParser