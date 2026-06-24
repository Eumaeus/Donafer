# src/MorphDrill/DataParser.jl

module DataParser

export MorphForm, parse_morphology_forms, find_forms_file

struct MorphForm
    chapter::Int
    category::String
    lemma::String
    description::String
    greek_form::String
    forms_file::String
end

function find_forms_file(root::String, basename::String)::String
    for (dir, _, files) in walkdir(root)
        if basename in files
            return joinpath(dir, basename)
        end
    end
    error("Forms file not found: $basename in $root")
end

function parse_forms_file(full_path::String, chapter::Int, category::String,
                          basename::String, include_vocative::Bool, include_dual::Bool)
    lines = readlines(full_path)
    if length(lines) < 2
        error("Invalid forms file (too short): $full_path")
    end

    # Metadata
    template_name = split(lines[1], "#")[2]
    lemma = split(lines[2], "#")[2]

    # Load template descriptions
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

    # Collect Greek forms (skip comments and blanks)
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
        if !include_vocative && occursin("voc.", desc)
            continue
        end
        if !include_dual && occursin("dual", lowercase(desc))
            continue
        end
        push!(forms, MorphForm(chapter, category, lemma, desc, form, basename))
    end
    return forms
end

function parse_morphology_forms(chapters_file::String, forms_root::String,
                                include_categories::Vector{String},
                                from_chapter::Int, current_chapter::Int,
                                include_vocative::Bool, include_dual::Bool)
    all_forms = MorphForm[]

    lines = readlines(chapters_file)
    for line in lines
        s = strip(line)
        if isempty(s) || startswith(s, "//")
            continue
        end
        parts = split(s, '\t')
        if length(parts) != 3
            continue
        end
        ch = parse(Int, parts[1])
        cat = strip(parts[2])
        fname = strip(parts[3])

        if ch < from_chapter || ch > current_chapter
            continue
        end
        if !(cat in include_categories)
            continue
        end

        try
            full_path = find_forms_file(forms_root, fname)
            parsed = parse_forms_file(full_path, ch, cat, fname, include_vocative, include_dual)
            append!(all_forms, parsed)
        catch e
            @warn "Could not parse forms file $fname: $e"
        end
    end

    return all_forms
end

end # module DataParser