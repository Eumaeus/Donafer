# src/VocabDrill/DataParser.jl

module DataParser

export parse_vocabulary_file, VocabItem, RawVocabEntry,
       is_numbered_english_field, parse_english_field

using TOML

"""
    VocabItem

A single granular item ready for quiz generation.
Each English translation and each principal part becomes its own item.

When `has_pp_specific_english` is true, `english` is a tense-appropriate gloss
for `principal_part_number` (numbered-English field in hq.txt). Legacy one-gloss
verb lines keep `has_pp_specific_english = false` and share the same English
across all principal parts.
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
    has_pp_specific_english::Bool       # true when English came from numbered PP glosses
end

# Backward-compatible constructor (legacy / tests without the flag).
VocabItem(ch, cat, greek, eng, is_pp, pp_num, lemma, full_greek) =
    VocabItem(ch, cat, greek, eng, is_pp, pp_num, lemma, full_greek, false)

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
    is_numbered_english_field(english_field) -> Bool

True when the English field uses the Phase 4 numbered-gloss form
(`1 I unbind;1 I free;2 I will unbind;…`). Detection: at least one
semicolon-separated segment matches `N gloss` with N in 1–6.
Legacy fields (`unbind; free`) return false.
"""
function is_numbered_english_field(english_field::AbstractString)::Bool
    for seg in split(english_field, ';')
        m = match(r"^\s*([1-6])\s+\S", seg)
        m !== nothing && return true
    end
    return false
end

"""
    parse_english_field(english_field) -> NamedTuple

Parse the English field of a vocab line.

Returns either:
- `(mode = :numbered, by_pp = Dict{Int,Vector{String}})` for
  `1 I unbind;2 I will unbind;…` (multiple glosses per PP allowed)
- `(mode = :legacy, glosses = Vector{String})` for `unbind; free`

Field rules (Phase 4, tidier split Greek / numbered-English):
- Greek field (unchanged): `1 form;2 form;…` — missing PPs omitted; duplicate
  numbers allowed (alternate forms of the same PP).
- English field (new): `N gloss;N gloss;…` where `N` is 1–6. Several glosses
  may share the same `N`. A gloss applies only to principal part `N`.
- Legacy English (no leading `N `): every gloss applies to every PP of the verb
  (old one-gloss / multi-gloss lines keep working until migrated).
"""
function parse_english_field(english_field::AbstractString)
    segments = [String(strip(e)) for e in split(english_field, ';') if !isempty(strip(e))]

    if is_numbered_english_field(english_field)
        by_pp = Dict{Int, Vector{String}}()
        for seg in segments
            m = match(r"^([1-6])\s+(.+)$", seg)
            if m !== nothing
                n = parse(Int, m.captures[1])
                gloss = String(strip(m.captures[2]))
                isempty(gloss) && continue
                push!(get!(by_pp, n, String[]), gloss)
            end
            # Non-numbered segments in a numbered field are ignored (prefer correctness).
        end
        return (mode = :numbered, by_pp = by_pp, glosses = String[])
    else
        return (mode = :legacy, by_pp = Dict{Int, Vector{String}}(), glosses = segments)
    end
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
Supports both legacy shared glosses and Phase 4 numbered per-PP glosses.
"""
function expand_entry(
    chapter::Int,
    category::AbstractString,
    greek_field::AbstractString,
    english_field::AbstractString
)
    result = VocabItem[]
    eng = parse_english_field(english_field)

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

                if eng.mode == :numbered
                    glosses = get(eng.by_pp, pp_num, String[])
                    if isempty(glosses)
                        # Form present but no PP gloss yet: keep the form for PP-ID
                        # with empty english so classic Eng↔Greek will not select it
                        # as a meaningful stem (see ItemSelector / choose_direction).
                        push!(result, VocabItem(
                            chapter, String(category), "$pp_num $form", "",
                            true, pp_num, lemma, String(greek_field), false
                        ))
                    else
                        for g in glosses
                            push!(result, VocabItem(
                                chapter, String(category), "$pp_num $form", g,
                                true, pp_num, lemma, String(greek_field), true
                            ))
                        end
                    end
                else
                    for g in eng.glosses
                        push!(result, VocabItem(
                            chapter, String(category), "$pp_num $form", g,
                            true, pp_num, lemma, String(greek_field), false
                        ))
                    end
                end
            else
                # Fallback (no number on Greek segment) — treat as non-PP verb form
                glosses = eng.mode == :numbered ?
                    vcat(values(eng.by_pp)...) :
                    eng.glosses
                isempty(glosses) && (glosses = String[""])
                for g in glosses
                    push!(result, VocabItem(
                        chapter, String(category), String(segment), g,
                        false, nothing, lemma, String(greek_field), false
                    ))
                end
            end
        end
    else
        # Non-verb: whole Greek field is one form (always legacy-style English)
        glosses = eng.mode == :numbered ?
            vcat(values(eng.by_pp)...) :
            eng.glosses
        for g in glosses
            push!(result, VocabItem(
                chapter,
                String(category),
                String(greek_field),
                g,
                false,
                nothing,
                nothing,
                String(greek_field),
                false
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
