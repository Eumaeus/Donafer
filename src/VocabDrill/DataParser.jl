# src/VocabDrill/DataParser.jl

module DataParser

export parse_vocabulary_file, VocabItem, RawVocabEntry,
       is_numbered_english_field, parse_english_field,
       is_case_tagged_english_field, normalize_case_token,
       parse_prep_greek_field, case_label

using TOML

"""
    VocabItem

A single granular item ready for quiz generation.
Each English translation and each principal part becomes its own item.

When `has_pp_specific_english` is true, `english` is a tense-appropriate gloss
for `principal_part_number` (numbered-English field in hq.txt). Legacy one-gloss
verb lines keep `has_pp_specific_english = false` and share the same English
across all principal parts.

For prepositions, `prep_case` is `"gen"`, `"dat"`, or `"acc"` when the sense is
tagged by case (Phase 5). `lemma` holds the preposition headword.
"""
struct VocabItem
    chapter::Int
    category::String                    # "noun", "verb", "prep", "adj", "other"
    greek_display::String               # What the student sees (e.g. "1 κελεύω" or "παρά + gen")
    english::String                     # One specific meaning
    is_verb_principal_part::Bool
    principal_part_number::Union{Int, Nothing}
    lemma::Union{String, Nothing}       # Base form for feedback (e.g. "κελεύω" / "παρά")
    full_greek_field::String            # Original Greek field from the data file (for rich feedback)
    has_pp_specific_english::Bool       # true when English came from numbered PP glosses
    prep_case::Union{String, Nothing}   # "gen"/"dat"/"acc" for case-tagged prepositions
end

# Backward-compatible constructors (legacy / tests without newer fields).
VocabItem(ch, cat, greek, eng, is_pp, pp_num, lemma, full_greek) =
    VocabItem(ch, cat, greek, eng, is_pp, pp_num, lemma, full_greek, false, nothing)

VocabItem(ch, cat, greek, eng, is_pp, pp_num, lemma, full_greek, has_pp) =
    VocabItem(ch, cat, greek, eng, is_pp, pp_num, lemma, full_greek, has_pp, nothing)

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

const CASE_TOKEN_RE = r"^(gen(?:itive)?|dat(?:ive)?|acc(?:usative)?)\.?$"i
const PREP_PLUS_CASE_RE = r"^(.*?)\s*\+\s*(gen(?:itive)?|dat(?:ive)?|acc(?:usative)?)\.?\s*$"i
const CASE_TAGGED_GLOSS_RE = r"^(gen(?:itive)?|dat(?:ive)?|acc(?:usative)?)\.?\s+(.+)$"i
const ENGLISH_PAREN_CASE_RE = r"\(\s*\+\s*(gen(?:itive)?|dat(?:ive)?|acc(?:usative)?)\.?\s*\)"i

"""
    normalize_case_token(token) -> Union{String, Nothing}

Map gen/genitive/dat/dative/acc/accusative (optional trailing period) to
`"gen"`, `"dat"`, or `"acc"`. Returns `nothing` when unrecognized.
"""
function normalize_case_token(token::AbstractString)::Union{String, Nothing}
    t = lowercase(strip(token))
    t = replace(t, r"\.+$" => "")
    t in ("gen", "genitive") && return "gen"
    t in ("dat", "dative") && return "dat"
    t in ("acc", "accusative") && return "acc"
    return nothing
end

"""
    case_label(case) -> String

Short pedagogical label for stems/feedback (`genitive`, `dative`, `accusative`).
"""
function case_label(case::AbstractString)::String
    c = normalize_case_token(case)
    c === nothing && return String(case)
    c == "gen" && return "genitive"
    c == "dat" && return "dative"
    return "accusative"
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
    is_case_tagged_english_field(english_field) -> Bool

True when the English field uses Phase 5 case-tagged glosses
(`gen from beside; dat at the side of; acc beside`). Detection: at least one
semicolon-separated segment starts with gen/dat/acc (optional period) plus a gloss.
"""
function is_case_tagged_english_field(english_field::AbstractString)::Bool
    for seg in split(english_field, ';')
        m = match(CASE_TAGGED_GLOSS_RE, strip(seg))
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
Parse case-tagged English (`gen gloss; dat gloss; …`) into case → glosses.
Segments without a recognized case tag are ignored.
"""
function parse_case_tagged_english(english_field::AbstractString)::Dict{String, Vector{String}}
    by_case = Dict{String, Vector{String}}()
    for seg in split(english_field, ';')
        s = strip(seg)
        isempty(s) && continue
        m = match(CASE_TAGGED_GLOSS_RE, s)
        m === nothing && continue
        c = normalize_case_token(m.captures[1])
        c === nothing && continue
        gloss = String(strip(m.captures[2]))
        isempty(gloss) && continue
        push!(get!(by_case, c, String[]), gloss)
    end
    return by_case
end

"""
    parse_prep_greek_field(greek_field) -> NamedTuple

Parse a preposition Greek field.

Supports:
- Legacy one-line-per-sense: `παρά + gen`, `ἐκ + gen; ἐξ + gen`
- Lemma-only (for case-tagged English): `παρά`

Returns `(lemma, case, display, forms)` where `case` may be `nothing` when
no `+ case` marker is present.
"""
function parse_prep_greek_field(greek_field::AbstractString)
    segments = [String(strip(p)) for p in split(greek_field, ';') if !isempty(strip(p))]
    isempty(segments) && return (lemma = nothing, case = nothing,
                                 display = String(strip(greek_field)), forms = String[])

    cases = String[]
    forms = String[]
    for seg in segments
        m = match(PREP_PLUS_CASE_RE, seg)
        if m !== nothing
            form = String(strip(m.captures[1]))
            c = normalize_case_token(m.captures[2])
            push!(forms, form)
            c !== nothing && push!(cases, c)
        else
            push!(forms, String(seg))
        end
    end

    lemma = isempty(forms) ? nothing : extract_lemma(forms[1])
    case = isempty(cases) ? nothing : first(cases)
    # Prefer a stable display: keep the original field (preserves ἐκ; ἐξ pairs).
    display = String(strip(greek_field))
    return (lemma = lemma, case = case, display = display, forms = forms)
end

function _case_from_english_parens(english_field::AbstractString)::Union{String, Nothing}
    m = match(ENGLISH_PAREN_CASE_RE, english_field)
    m === nothing && return nothing
    return normalize_case_token(m.captures[1])
end

function _strip_english_paren_case(gloss::AbstractString)::String
    s = replace(String(gloss), ENGLISH_PAREN_CASE_RE => "")
    return String(strip(replace(s, r"\s{2,}" => " ")))
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

        # Detect new unit/chapter before skipping comments (Unit markers are // lines).
        if occursin(r"// Unit\s+(\d+)", line)
            m = match(r"// Unit\s+(\d+)", line)
            current_chapter = parse(Int, m.captures[1])
            continue
        end
        startswith(line, "//") && continue

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

Handles splitting of principal parts (verbs), preposition case senses, and
multiple English translations. Supports both legacy shared glosses and Phase 4
numbered per-PP glosses.
"""
function expand_entry(
    chapter::Int,
    category::AbstractString,
    greek_field::AbstractString,
    english_field::AbstractString
)
    result = VocabItem[]

    if category == "prep"
        return expand_prep_entry(chapter, greek_field, english_field)
    end

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
                            true, pp_num, lemma, String(greek_field), false, nothing
                        ))
                    else
                        for g in glosses
                            push!(result, VocabItem(
                                chapter, String(category), "$pp_num $form", g,
                                true, pp_num, lemma, String(greek_field), true, nothing
                            ))
                        end
                    end
                else
                    for g in eng.glosses
                        push!(result, VocabItem(
                            chapter, String(category), "$pp_num $form", g,
                            true, pp_num, lemma, String(greek_field), false, nothing
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
                        false, nothing, lemma, String(greek_field), false, nothing
                    ))
                end
            end
        end
    else
        # Non-verb / non-prep: whole Greek field is one form (always legacy-style English)
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
                false,
                nothing
            ))
        end
    end

    return result
end

"""
Expand a `prep` line into VocabItems tagged by case when possible.

Formats:
1. **Legacy** (one line per case sense): `παρά + gen#from beside`
   Case is read from the Greek `+ gen|dat|acc` marker. Alternate forms of the
   same case stay on one line (`ἐκ + gen; ἐξ + gen`).
2. **Preferred Phase 5** (case-tagged English): `παρά#gen from beside; dat …; acc …`
   Greek field is the lemma (no `+ case`); each English segment is tagged.
3. Bare lemma with case only in English parens (legacy ἄνευ-style): case is
   recovered from `(+ gen.)` when present.
"""
function expand_prep_entry(
    chapter::Int,
    greek_field::AbstractString,
    english_field::AbstractString,
)::Vector{VocabItem}
    result = VocabItem[]
    greek = String(strip(greek_field))
    english = String(strip(english_field))

    if is_case_tagged_english_field(english)
        lemma = extract_lemma(greek)
        by_case = parse_case_tagged_english(english)
        for (case, glosses) in by_case
            display = "$lemma + $case"
            for g in glosses
                push!(result, VocabItem(
                    chapter, "prep", display, g,
                    false, nothing, lemma, greek, false, case
                ))
            end
        end
        return result
    end

    parsed = parse_prep_greek_field(greek)
    lemma = parsed.lemma
    case = parsed.case
    if case === nothing
        case = _case_from_english_parens(english)
    end

    # Build a clean display: if we recovered case for a bare lemma, show "+ case".
    display = if case !== nothing && parsed.case === nothing && lemma !== nothing
        "$lemma + $case"
    else
        parsed.display
    end

    glosses = [String(strip(e)) for e in split(english, ';') if !isempty(strip(e))]
    if case !== nothing
        glosses = [_strip_english_paren_case(g) for g in glosses]
        glosses = [g for g in glosses if !isempty(g)]
    end
    isempty(glosses) && (glosses = String[""])

    for g in glosses
        push!(result, VocabItem(
            chapter, "prep", display, g,
            false, nothing, lemma, greek, false, case
        ))
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
