# src/VocabDrill/DataParser.jl

module DataParser

export parse_vocabulary_file, VocabItem, RawVocabEntry

using TOML

"""
    VocabItem

A single granular item ready for quiz generation.
Each English translation and each principal part becomes its own item.
"""
struct VocabItem
    chapter::Int
    category::String                    # "noun", "verb", "prep", "adj", "other"
    greek_display::String               # What the student sees (e.g. "1 κελεύω" or "ἀγορά, ἀγορᾶς, ἡ")
    english::String                     # One specific meaning
    is_verb_principal_part::Bool
    principal_part_number::Union{Int, Nothing}
    lemma::Union{String, Nothing}       # Base form for feedback (e.g. "κελεύω")
    full_greek_field::String            # Original Greek field from the data file (for rich feedback)
end

"""
    RawVocabEntry

Represents one original line from hq.txt before expansion.
"""
struct RawVocabEntry
    chapter::Int
    category::String
    greek_field::String
    english_field::String
end

"""
    parse_vocabulary_file(path::String) -> Vector{VocabItem}

Reads the Hansen & Quinn vocabulary file and returns a flat list of `VocabItem`s.
Each semicolon-separated English translation and each verb principal part
becomes a separate item.
"""
function parse_vocabulary_file(path::String)::Vector{VocabItem}
    lines = readlines(path)
    items = VocabItem[]
    current_chapter = 0

    for line in lines
        line = strip(line)
        isempty(line) && continue
        startswith(line, "//") && continue

        # Detect new unit/chapter
        if occursin(r"// Unit\s+(\d+)", line)
            m = match(r"// Unit\s+(\d+)", line)
            current_chapter = parse(Int, m.captures[1])
            continue
        end

        # Parse normal entry: chapter#category#Greek#English
        parts = split(line, '#'; limit=4)
        length(parts) != 4 && continue

        ch_str, category, greek_field, english_field = parts
        chapter = tryparse(Int, strip(ch_str))
        chapter === nothing && continue

        # Expand into individual VocabItems
        append!(items, expand_entry(chapter, strip(category), strip(greek_field), strip(english_field)))
    end

    return items
end

"""
    expand_entry(...) -> Vector{VocabItem}

Handles splitting of principal parts (verbs) and multiple English translations.
"""
function expand_entry(
    chapter::Int, 
    category::AbstractString, 
    greek_field::AbstractString, 
    english_field::AbstractString
)
    result = VocabItem[]

    # Split English translations
    english_list = [String(strip(e)) for e in split(english_field, ';') if !isempty(strip(e))]

   if category == "verb"
    pp_segments = [strip(p) for p in split(greek_field, ';') if !isempty(strip(p))]

    # === Determine the true lemma from the FIRST principal part ===
    lemma = nothing
    for segment in pp_segments
        m = match(r"^(\d+)\s+(.+)$", segment)
        if m !== nothing
            first_form = String(strip(m.captures[2]))
            lemma = extract_lemma(first_form)
            break
        end
    end

    for segment in pp_segments
        m = match(r"^(\d+)\s+(.+)$", segment)
        if m !== nothing
            pp_num = parse(Int, m.captures[1])
            form = String(strip(m.captures[2]))

            for eng in english_list
                push!(result, VocabItem(
                    chapter,
                    String(category),
                    "$pp_num $form",
                    eng,
                    true,
                    pp_num,
                    lemma,                    # ← Now uses the real lemma (e.g. "λύω")
                    String(greek_field)
                ))
            end
        else
            # Fallback (no number)
            for eng in english_list
                push!(result, VocabItem(
                    chapter, String(category), String(segment), eng,
                    false, nothing, nothing, String(greek_field)
                ))
            end
        end
    end
else
        # Non-verb: whole Greek field is one form
        for eng in english_list
            push!(result, VocabItem(
                chapter,
                String(category),
                String(greek_field),
                eng,
                false,
                nothing,
                nothing,
                String(greek_field)
            ))
        end
    end

    return result
end

# Very simple lemma extractor (can be improved later)
function extract_lemma(form::String)::String
    # For now just take the first word before any punctuation or space
    first_word = split(form, r"[\s,.;]"; limit=2)[1]
    return strip(first_word)
end

end # module DataParser