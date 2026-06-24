#!/usr/bin/env julia

# Basic check on chapter 4 (and earlier) of hq.tsv
# julia --project=. scripts/check_morphology_integrity.jl --chapter 4

# Save a report
# julia --project=. scripts/check_morphology_integrity.jl --chapter 4 --report reports/morph_integrity_ch4.txt

# Check only up to chapter 2
# julia --project=. scripts/check_morphology_integrity.jl -n 2

using ArgParse

function find_file_by_basename(root_dir::String, target_basename::String)
    for (root, dirs, files) in walkdir(root_dir)
        for f in files
            if f == target_basename
                return joinpath(root, f)
            end
        end
    end
    return nothing
end

function parse_chapters_tsv(chapters_file::String, current_chapter::Int)
    referenced = Set{String}()
    open(chapters_file, "r") do io
        for line in eachline(io)
            stripped = strip(line)
            if isempty(stripped) || startswith(stripped, "//")
                continue
            end
            parts = split(stripped, '\t')
            if length(parts) >= 3
                ch_str = strip(parts[1])
                forms_name = strip(parts[3])
                ch = tryparse(Int, ch_str)
                if !isnothing(ch) && ch <= current_chapter
                    push!(referenced, forms_name)
                end
            end
        end
    end
    return referenced
end

function count_template_slots(template_path::String)
    lines = readlines(template_path)
    count(l -> !startswith(strip(l), "//") && !isempty(strip(l)), lines)
end

function count_forms_data_lines(forms_path::String)
    lines = readlines(forms_path)
    count(l -> begin
        s = strip(l)
        !startswith(s, "//") && !isempty(s) && !occursin("#", l)
    end, lines)
end

function generate_report(io::IO, chapters_file, current_chapter, referenced,
                         missing_forms, missing_templates, empty_data, pattern_mismatch)
    println(io, "=== Donafer Morphology Data Integrity Check ===")
    println(io, "Chapters file     : $chapters_file")
    println(io, "Current chapter   : $current_chapter (and earlier)")
    println(io, "Unique forms referenced : $(length(referenced))")
    println(io)

    println(io, "## 1. Forms listed in chapters but NOT found in data/morphology/forms/ (recursive)")
    if isempty(missing_forms)
        println(io, "None.")
    else
        for f in sort(missing_forms)
            println(io, "  - $f")
        end
    end
    println(io)

    println(io, "## 2. Forms files that reference a template which does NOT exist in data/morphology/templates/")
    if isempty(missing_templates)
        println(io, "None.")
    else
        for (f, t) in sort(missing_templates)
            println(io, "  - '$f' → template '$t'")
        end
    end
    println(io)

    println(io, "## 3. Forms files whose data section is entirely empty (0 data lines after headers)")
    if isempty(empty_data)
        println(io, "None.")
    else
        for f in sort(empty_data)
            println(io, "  - $f")
        end
    end
    println(io)

    println(io, "## 4. Forms files with some data but the line count does NOT match the template pattern")
    if isempty(pattern_mismatch)
        println(io, "None.")
    else
        for (f, fc, tc) in sort(pattern_mismatch)
            println(io, "  - '$f' : forms file has $fc data lines, template defines $tc slots")
        end
    end
    println(io)

    total_issues = length(missing_forms) + length(missing_templates) + length(empty_data) + length(pattern_mismatch)
    if total_issues == 0
        println(io, "✅ SUCCESS: All referenced forms files are present, reference existing templates,")
        println(io, "   and have the correct number of data lines matching their template.")
    else
        println(io, "⚠️  Found $total_issues issue(s). Fix the problems above before generating drills.")
    end
end

function main()
    s = ArgParseSettings(
        description = "Integrity checker for Donafer morphology data (templates + forms + chapters)."
    )
    @add_arg_table! s begin
        "--chapters", "-c"
            help = "Path to chapters .tsv file"
            default = "data/morphology/chapters/hq.tsv"
        "--chapter", "-n"
            help = "Current chapter number (include this chapter and all earlier ones)"
            arg_type = Int
            default = 4
        "--forms-dir"
            default = "data/morphology/forms"
        "--templates-dir"
            default = "data/morphology/templates"
        "--report"
            help = "Optional path to write the full report (e.g. reports/morph_integrity.txt)"
            default = ""
    end

    args = parse_args(s)

    chapters_file  = args["chapters"]
    current_chapter = args["chapter"]
    forms_dir      = args["forms-dir"]
    templates_dir  = args["templates-dir"]
    report_path    = args["report"]

    println("Running morphology integrity check...")
    referenced = parse_chapters_tsv(chapters_file, current_chapter)

    missing_forms      = String[]
    missing_templates  = Tuple{String,String}[]
    empty_data         = String[]
    pattern_mismatch   = Vector{Tuple{String,Int,Int}}()

    for forms_name in sort(collect(referenced))
        forms_path = find_file_by_basename(forms_dir, forms_name)
        if forms_path === nothing
            push!(missing_forms, forms_name)
            continue
        end

        # Extract template name
        template_name = nothing
        for line in readlines(forms_path)
            if startswith(strip(line), "template#")
                parts = split(line, '#', limit=2)
                if length(parts) == 2
                    template_name = strip(parts[2])
                end
                break
            end
        end

        if template_name === nothing
            println("WARNING: $forms_name has no 'template#' line — treating as pattern mismatch")
            push!(pattern_mismatch, (forms_name, 0, 0))
            continue
        end

        template_path = joinpath(templates_dir, template_name)
        if !isfile(template_path)
            push!(missing_templates, (forms_name, template_name))
            continue
        end

        template_count = count_template_slots(template_path)
        forms_count    = count_forms_data_lines(forms_path)

        if forms_count == 0
            push!(empty_data, forms_name)
        elseif forms_count != template_count
            push!(pattern_mismatch, (forms_name, forms_count, template_count))
        end
        # else: perfect match — silently good
    end

    # Always print report to stdout
    generate_report(stdout, chapters_file, current_chapter, referenced,
                    missing_forms, missing_templates, empty_data, pattern_mismatch)

    # Optionally write to file
    if !isempty(report_path)
        mkpath(dirname(report_path))
        open(report_path, "w") do io
            generate_report(io, chapters_file, current_chapter, referenced,
                            missing_forms, missing_templates, empty_data, pattern_mismatch)
        end
        println("\nFull report also written to: $report_path")
    end
end

main()