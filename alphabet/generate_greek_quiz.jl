#!/usr/bin/env julia
# ============================================================
# generate_greek_quiz.jl
#
# C. Blackwell & Grok.ai
#
# Generate Moodle GIFT quizzes on the Ancient Greek alphabet.
#
# Why this exists
# ---------------
# Some Moodle sites disable "shuffle within questions". In that
# case GIFT answers appear in file order, so a quiz that always
# writes the correct option first (`=...`) makes every correct
# answer "A". This script shuffles the five options so the
# correct answer can land in any position.
#
# Usage
# -----
#   julia generate_greek_quiz.jl
#   julia generate_greek_quiz.jl --n-chars 40 --n-syllables 30 --n-words 30
#   julia generate_greek_quiz.jl --seed 2026 --out my_quiz.gift
#
# Edit the three data lists and the CONFUSIONS table below to
# change what the generator knows.
# ============================================================

using Random
using Printf
using Dates

# ------------------------------------------------------------
# Command-line parameters
# ------------------------------------------------------------
function parse_args(args)
    opts = Dict{String,Any}(
        "n_chars"      => 40,
        "n_syllables"  => 30,
        "n_words"      => 30,
        "n_options"    => 5,          # 1 correct + 4 distractors
        "seed"         => nothing,    # nothing = use current time
        "out"          => "gifts/greek_alphabet_quiz.gift",
        "title_prefix" => "",
        "font_em"      => Dict("char"=>"1.9", "syllable"=>"1.8", "word"=>"1.5"),
    )
    i = 1
    while i <= length(args)
        a = args[i]
        if a in ("-h", "--help")
            println("""
Generate a Moodle GIFT Greek-alphabet quiz.

Options:
  --n-chars N        number of character questions      (default 40)
  --n-syllables N    number of syllable questions       (default 30)
  --n-words N        number of word questions           (default 30)
  --n-options N      choices per question, incl. key    (default 5)
  --seed N           RNG seed for reproducible quizzes
  --out FILE         output path                        (default greek_alphabet_quiz.gift)
  --title-prefix S   prefixed to every question title
  -h, --help         this message
""")
            exit(0)
        elseif a == "--n-chars";      opts["n_chars"] = parse(Int, args[i+=1])
        elseif a == "--n-syllables";  opts["n_syllables"] = parse(Int, args[i+=1])
        elseif a == "--n-words";      opts["n_words"] = parse(Int, args[i+=1])
        elseif a == "--n-options";    opts["n_options"] = parse(Int, args[i+=1])
        elseif a == "--seed";         opts["seed"] = parse(Int, args[i+=1])
        elseif a == "--out";          opts["out"] = args[i+=1]
        elseif a == "--title-prefix"; opts["title_prefix"] = args[i+=1]
        else
            error("Unknown argument: $a  (try --help)")
        end
        i += 1
    end
    return opts
end

# ============================================================
# DATA  —  edit these lists freely
# ============================================================
#
# Each entry is  greek  =>  preferred Latin transliteration.
#
# Conventions used here (change them if your course differs):
#   rough breathing → h     (ἁ = ha, ῥ = rh)
#   smooth breathing omitted
#   accents omitted
#   iota subscript omitted
#   η = ē , ω = ō , υ = u   (never y)
#   θ = th, φ = ph, χ = ch, ψ = ps, ξ = x
#   κ = k                   (even when an English cognate uses c)
#
# You may list the same Latin form more than once (ἀ and α both
# map to "a"). That is expected.

const CHARACTERS = [
    # vowels, plain
    "α" => "a",  "ε" => "e",  "η" => "ē",  "ι" => "i",
    "ο" => "o",  "υ" => "u",  "ω" => "ō",
    # vowels, smooth breathing
    "ἀ" => "a",  "ἐ" => "e",  "ἠ" => "ē",  "ἰ" => "i",
    "ὀ" => "o",  "ὐ" => "u",  "ὠ" => "ō",
    # vowels, rough breathing
    "ἁ" => "ha", "ἑ" => "he", "ἡ" => "hē", "ἱ" => "hi",
    "ὁ" => "ho", "ὑ" => "hu", "ὡ" => "hō",
    # vowels, acute + breathing
    "ἄ" => "a",  "ἔ" => "e",  "ἤ" => "ē",  "ἴ" => "i",
    "ὄ" => "o",  "ὔ" => "u",  "ὤ" => "ō",
    "ἅ" => "ha", "ἕ" => "he", "ἥ" => "hē", "ἵ" => "hi",
    "ὅ" => "ho", "ὕ" => "hu", "ὥ" => "hō",
    # vowels, circumflex + breathing (a sample)
    "ἆ" => "a",  "ἦ" => "ē",  "ἶ" => "i",  "ὖ" => "u",  "ὦ" => "ō",
    "ἇ" => "ha", "ἧ" => "hē", "ἷ" => "hi", "ὗ" => "hu", "ὧ" => "hō",
    # iota subscript (ignored in Latin)
    "ᾳ" => "a",  "ῃ" => "ē",  "ῳ" => "ō",
    "ᾀ" => "a",  "ᾐ" => "ē",  "ᾠ" => "ō",
    "ᾁ" => "ha", "ᾑ" => "hē", "ᾡ" => "hō",
    # consonants
    "β" => "b",  "γ" => "g",  "δ" => "d",  "ζ" => "z",
    "θ" => "th", "κ" => "k",  "λ" => "l",  "μ" => "m",
    "ν" => "n",  "ξ" => "x",  "π" => "p",  "ρ" => "r",
    "ῥ" => "rh", "σ" => "s",  "ς" => "s",  "τ" => "t",
    "φ" => "ph", "χ" => "ch", "ψ" => "ps",
    # a few capitals (useful once students meet names)
    "Α" => "a",  "Β" => "b",  "Γ" => "g",  "Δ" => "d",
    "Ε" => "e",  "Ζ" => "z",  "Η" => "ē",  "Θ" => "th",
    "Ι" => "i",  "Κ" => "k",  "Λ" => "l",  "Μ" => "m",
    "Ν" => "n",  "Ξ" => "x",  "Ο" => "o",  "Π" => "p",
    "Ρ" => "r",  "Σ" => "s",  "Τ" => "t",  "Υ" => "u",
    "Φ" => "ph", "Χ" => "ch", "Ψ" => "ps", "Ω" => "ō",
    "Ἀ" => "a",  "Ἁ" => "ha", "Ἐ" => "e",  "Ἑ" => "he",
    "Ἠ" => "ē",  "Ἡ" => "hē", "Ἰ" => "i",  "Ἱ" => "hi",
    "Ὀ" => "o",  "Ὁ" => "ho", "Ὑ" => "hu", "Ὠ" => "ō",  "Ὡ" => "hō",
]

const SYLLABLES = [
    "βα"  => "ba",   "γά"  => "ga",   "δέ"  => "de",   "ζῆ"  => "zē",
    "θά"  => "tha",  "κί"  => "ki",   "λά"  => "la",   "μή"  => "mē",
    "νό"  => "no",   "ξέ"  => "xe",   "πά"  => "pa",   "ῥά"  => "rha",
    "σό"  => "so",   "τύ"  => "tu",   "φί"  => "phi",  "χό"  => "cho",
    "ψή"  => "psē",  "ἁβ"  => "hab",  "ἐγ"  => "eg",   "ἡδ"  => "hēd",
    "βί"  => "bi",   "γῆ"  => "gē",   "δῶ"  => "dō",   "θεά" => "thea",
    "κἀ"  => "ka",   "λῇ"  => "lē",   "μῦ"  => "mu",   "νῷ"  => "nō",
    "πῦ"  => "pu",   "φῶ"  => "phō",  "χαῖ" => "chai", "θοῦ" => "thou",
    "γυ"  => "gu",   "χυ"  => "chu",  "ξυ"  => "xu",   "ρυ"  => "ru",
    "πρα" => "pra",  "στρα"=> "stra", "βλη" => "blē",  "κλε" => "kle",
]

# Odyssey names + transparent English cognates.
# Latin forms follow the same letter-by-letter rules (υ = u, κ = k).
const WORDS = [
    "θεός"        => "theos",
    "λόγος"       => "logos",
    "φίλος"       => "philos",
    "βίος"        => "bios",
    "γῆ"          => "gē",
    "ὕδωρ"        => "hudōr",
    "πῦρ"         => "pur",
    "ἵππος"       => "hippos",
    "κύκλος"      => "kuklos",
    "σοφία"       => "sophia",
    "δημοκρατία"  => "dēmokratia",
    "φιλοσοφία"   => "philosophia",
    "ἁρμονία"     => "harmonia",
    "ἱστορία"     => "historia",
    "Ἀθήνη"       => "Athēnē",
    "Ζεύς"        => "Zeus",
    "Ἥρα"         => "Hēra",
    "Ποσειδῶν"    => "Poseidōn",
    "Ἑρμῆς"       => "Hermēs",
    "Ἀπόλλων"     => "Apollōn",
    "Ὀδυσσεύς"    => "Odusseus",
    "Πηνελόπη"    => "Pēnelopē",
    "Τηλέμαχος"   => "Tēlemachos",
    "Κίρκη"       => "Kirkē",
    "Καλυψώ"      => "Kalupsō",
    "Νέστωρ"      => "Nestōr",
    "Εὐρύκλεια"   => "Eurukleia",
    "ἄνδρα"       => "andra",
    "μῆνιν"       => "mēnin",
    "θεά"         => "thea",
    "ναῦς"        => "naus",
    "οἶκος"       => "oikos",
    "πόλις"       => "polis",
    "ἀνήρ"        => "anēr",
    "γυνή"        => "gunē",
    "θυμός"       => "thumos",
    "νόος"        => "noos",
    "ἔργον"       => "ergon",
    "χρόνος"      => "chronos",
    "ψυχή"        => "psuchē",
]

# ------------------------------------------------------------
# Confusions
# ------------------------------------------------------------
# Pairs (or small groups) of Greek characters that new learners
# mix up. Used heavily when building character-question
# distractors; also used, more lightly, for syllables/words.
#
# You can add a pair in either order; the script treats the
# relation as undirected.

const CONFUSIONS = [
    ("χ", "ξ"),
    ("ρ", "π"),
    ("σ", "ο"),
    ("ς", "ο"),
    ("γ", "υ"),
    ("Υ", "Γ"),
    ("ν", "υ"),
    ("Ν", "Υ"),
    ("θ", "φ"),
    ("φ", "ψ"),
    ("η", "ε"),
    ("ω", "ο"),
    ("η", "ι"),
    ("ι", "υ"),
    ("κ", "χ"),
    ("κ", "ξ"),
    ("β", "θ"),
    ("μ", "ν"),
    ("λ", "χ"),          # especially in some handwriting
    ("ζ", "ξ"),
    ("ἁ", "ἀ"),          # breathing
    ("ἑ", "ἐ"),
    ("ἡ", "ἠ"),
    ("ἱ", "ἰ"),
    ("ὁ", "ὀ"),
    ("ὑ", "ὐ"),
    ("ὡ", "ὠ"),
    ("ῥ", "ρ"),
    ("ῃ", "η"),          # iota subscript
    ("ᾳ", "α"),
    ("ῳ", "ω"),
]

# Common systematic Latin-side mistakes (used as extra distractors
# for words / syllables). Pair is  (wrong_latin, feedback_greek).
# Leave feedback_greek empty ("") to let the script invent one
# from the character table when possible.
const LATIN_TRAPS = [
    ("y",   "υ"),     # the forbidden y-for-upsilon
    ("c",   "κ"),     # English-cognate c for kappa
    ("f",   "φ"),     # f for ph
    ("kh",  "χ"),     # kh for ch
    ("ks",  "ξ"),     # ks for x
    ("ē",   "η"),
    ("ō",   "ω"),
    ("e",   "ε"),
    ("o",   "ο"),
]

# ============================================================
# Lookup tables built from the lists above
# ============================================================

latin_of(pair::Pair) = pair.second
greek_of(pair::Pair) = pair.first

function build_latin_to_greeks(pairs)
    d = Dict{String,Vector{String}}()
    for (g, lat) in pairs
        push!(get!(d, lat, String[]), g)
    end
    return d
end

function build_greek_to_latin(pairs)
    Dict{String,String}(g => lat for (g, lat) in pairs)
end

const CHAR_G2L = build_greek_to_latin(CHARACTERS)
const CHAR_L2G = build_latin_to_greeks(CHARACTERS)
const SYL_G2L  = build_greek_to_latin(SYLLABLES)
const SYL_L2G  = build_latin_to_greeks(SYLLABLES)
const WORD_G2L = build_greek_to_latin(WORDS)
const WORD_L2G = build_latin_to_greeks(WORDS)

function build_confusion_graph(pairs)
    g = Dict{String,Set{String}}()
    for (a, b) in pairs
        push!(get!(g, a, Set{String}()), b)
        push!(get!(g, b, Set{String}()), a)
    end
    return g
end

const CONFUSION_GRAPH = build_confusion_graph(CONFUSIONS)

# A representative Greek for a Latin form, preferring an item
# from `preferred_pool` (the same list the question came from).
function greek_for(latin::AbstractString; preferred=CHAR_L2G)
    if haskey(preferred, latin) && !isempty(preferred[latin])
        return first(preferred[latin])
    elseif haskey(CHAR_L2G, latin) && !isempty(CHAR_L2G[latin])
        return first(CHAR_L2G[latin])
    else
        return latin   # last resort: show the Latin itself
    end
end

# ============================================================
# Distractor construction
# ============================================================

"""
Return up to `n` Latin distractors for a character question,
weighted toward visual confusions.
"""
function character_distractors(greek::AbstractString, correct::AbstractString, n::Int)
    used = Set{String}([correct])
    out  = String[]

    # 1. Direct visual confusions of this glyph
    if haskey(CONFUSION_GRAPH, greek)
        for partner in shuffle(collect(CONFUSION_GRAPH[greek]))
            lat = get(CHAR_G2L, partner, nothing)
            if lat !== nothing && lat ∉ used
                push!(out, lat); push!(used, lat)
                length(out) >= n && return out
            end
        end
    end

    # 2. Confusions of the "base" letter (strip combining marks-ish
    #    by also checking any character that shares this Latin form
    #    and looking at *their* partners).
    for sibling in get(CHAR_L2G, correct, String[])
        if haskey(CONFUSION_GRAPH, sibling)
            for partner in shuffle(collect(CONFUSION_GRAPH[sibling]))
                lat = get(CHAR_G2L, partner, nothing)
                if lat !== nothing && lat ∉ used
                    push!(out, lat); push!(used, lat)
                    length(out) >= n && return out
                end
            end
        end
    end

    # 3. Breathing / accent twins: other glyphs that share the
    #    vowel but differ in h- vs no-h.
    if startswith(correct, "h") && length(correct) > 1
        bare = correct[2:end]
        if bare ∉ used && haskey(CHAR_L2G, bare)
            push!(out, bare); push!(used, bare)
            length(out) >= n && return out
        end
    else
        hform = "h" * correct
        if hform ∉ used && haskey(CHAR_L2G, hform)
            push!(out, hform); push!(used, hform)
            length(out) >= n && return out
        end
    end

    # 4. Fill from the remaining character inventory
    pool = shuffle(unique(latin_of.(CHARACTERS)))
    for lat in pool
        if lat ∉ used
            push!(out, lat); push!(used, lat)
            length(out) >= n && return out
        end
    end
    return out
end

"""
Distractors for a syllable: confuse the first letter when possible,
otherwise pick other syllables' Latin forms.
"""
function syllable_distractors(greek::AbstractString, correct::AbstractString, n::Int)
    used = Set{String}([correct])
    out  = String[]

    firstchar = string(Base.first(greek))
    if haskey(CONFUSION_GRAPH, firstchar)
        rest = greek[nextind(greek, 1):end]
        for partner in shuffle(collect(CONFUSION_GRAPH[firstchar]))
            candidate_g = partner * rest
            lat = get(SYL_G2L, candidate_g, get(CHAR_G2L, partner, nothing))
            # If we don't have that exact syllable, synthesize a
            # plausible Latin from the partner's letter + remainder.
            if lat === nothing
                partner_lat = get(CHAR_G2L, partner, nothing)
                first_lat = get(CHAR_G2L, firstchar, "")
                if partner_lat !== nothing && startswith(correct, first_lat)
                    lat = partner_lat * correct[ncodeunits(first_lat)+1:end]
                else
                    lat = partner_lat
                end
            end
            if lat !== nothing && lat ∉ used && !isempty(lat)
                push!(out, lat); push!(used, lat)
                length(out) >= n && return out
            end
        end
    end

    pool = shuffle(unique(latin_of.(SYLLABLES)))
    for lat in pool
        if lat ∉ used
            push!(out, lat); push!(used, lat)
            length(out) >= n && return out
        end
    end
    # last resort: character inventory
    for lat in shuffle(unique(latin_of.(CHARACTERS)))
        if lat ∉ used
            push!(out, lat); push!(used, lat)
            length(out) >= n && return out
        end
    end
    return out
end

"""
Distractors for a word: other words, plus a couple of systematic
traps (y-for-u, c-for-k) when they actually change the form.
"""
function word_distractors(greek::AbstractString, correct::AbstractString, n::Int)
    used = Set{String}([correct, lowercase(correct)])
    out  = String[]

    # Systematic traps that produce a *different* string
    traps = String[]
    push!(traps, replace(correct, "u" => "y", "U" => "Y"))
    push!(traps, replace(correct, "k" => "c", "K" => "C"))
    push!(traps, replace(correct, "ph" => "f", "Ph" => "F"))
    push!(traps, replace(correct, "ch" => "kh", "Ch" => "Kh"))
    push!(traps, replace(correct, "x" => "ks", "X" => "Ks"))
    if startswith(correct, "h") || startswith(correct, "H")
        push!(traps, correct[2:end])
    else
        push!(traps, "h" * lowercase(correct))
    end
    for t in unique(traps)
        if lowercase(t) ∉ used && t != correct && !isempty(t)
            push!(out, t); push!(used, lowercase(t))
            length(out) >= n && return out
        end
    end

    pool = shuffle(collect(WORDS))
    for (g, lat) in pool
        if lowercase(lat) ∉ used
            push!(out, lat); push!(used, lowercase(lat))
            length(out) >= n && return out
        end
    end
    return out
end

# Feedback Greek for a distractor Latin form.
# Returns `nothing` when the Latin is not in any lexicon (typical
# of a systematic trap such as y-for-υ or c-for-κ).
function feedback_greek(latin::AbstractString, source::Symbol)
    preferred = source === :char ? CHAR_L2G :
                source === :syllable ? SYL_L2G : WORD_L2G
    if haskey(preferred, latin) && !isempty(preferred[latin])
        return first(preferred[latin])
    elseif haskey(CHAR_L2G, latin) && !isempty(CHAR_L2G[latin])
        return first(CHAR_L2G[latin])
    else
        return nothing
    end
end

function trap_explanation(wrong::AbstractString, correct::AbstractString)
    bits = String[]
    if occursin("y", lowercase(wrong)) && occursin("u", lowercase(correct))
        push!(bits, "υ is written u, not y")
    end
    if occursin(r"[cC]", wrong) && occursin(r"[kK]", correct)
        push!(bits, "κ is written k, not c")
    end
    if occursin(r"[fF]", wrong) && occursin("ph", lowercase(correct))
        push!(bits, "φ is written ph, not f")
    end
    if occursin("kh", lowercase(wrong)) && occursin("ch", lowercase(correct))
        push!(bits, "χ is written ch, not kh")
    end
    if occursin("ks", lowercase(wrong)) && occursin("x", lowercase(correct))
        push!(bits, "ξ is written x, not ks")
    end
    if lowercase(wrong) == lowercase(correct)[2:end] &&
       (startswith(correct, "h") || startswith(correct, "H"))
        push!(bits, "the rough breathing must be written as h")
    end
    if startswith(lowercase(wrong), "h") && length(wrong) > 1 &&
       lowercase(wrong)[2:end] == lowercase(correct)
        push!(bits, "there is no rough breathing here, so no h")
    end
    if isempty(bits)
        return "That is not the letter-by-letter transliteration used in this quiz."
    else
        return "Not under this quiz's rules (" * join(bits, "; ") * ")."
    end
end

# ============================================================
# GIFT rendering
# ============================================================

function gift_question(title, prompt_html, correct, distractors, source::Symbol)
    # Build option records, then SHUFFLE so the key is not always A.
    opts = Tuple{Bool,String,String}[]
    push!(opts, (true, correct, "Correct."))
    for d in distractors
        g = feedback_greek(d, source)
        if g === nothing
            fb = trap_explanation(d, correct)
        else
            fb = "That would appear in Greek as '$g'."
        end
        push!(opts, (false, d, fb))
    end
    shuffle!(opts)

    io = IOBuffer()
    println(io, "::", title, "::")
    println(io, prompt_html, " {")
    for (is_key, ans, fb) in opts
        mark = is_key ? "=" : "~"
        println(io, "\t", mark, ans, "#", fb)
    end
    println(io, "}")
    println(io)
    return String(take!(io))
end

function prompt_for(kind::Symbol, greek::AbstractString, font_em)
    label = kind === :char ? "character" : kind === :syllable ? "syllable" : "word"
    em = font_em[string(kind == :char ? "char" : kind == :syllable ? "syllable" : "word")]
    return "Select the correct Latin-alphabet transliteration of the following Greek $label:<br><br><span style=\"font-size:$(em)em;\">$greek</span>"
end

function pick_items(pairs, n)
    n <= 0 && return eltype(pairs)[]
    if n <= length(pairs)
        return pairs[randperm(length(pairs))[1:n]]
    else
        # allow repeats if the user asks for more items than we have
        return [pairs[rand(1:length(pairs))] for _ in 1:n]
    end
end

function header_text(opts)
    ntot = opts["n_chars"] + opts["n_syllables"] + opts["n_words"]
    seed = opts["seed"] === nothing ? "(time-based)" : string(opts["seed"])
    return """
\$CATEGORY: Intro/Greek_Alphabet_$(today())

// ============================================================
// Introductory Ancient Greek – Alphabet, Syllables & Words
// $ntot multiple-choice questions in GIFT format for Moodle
//
// Generated by generate_greek_quiz.jl   seed = $seed
// Options within each question are shuffled so the key is
// not always A (needed when Moodle has disabled intra-question
// shuffle).
//
// Progression:
//   $(opts["n_chars"]) character questions
//   $(opts["n_syllables"]) syllable questions
//   $(opts["n_words"]) word questions
//
// Transliteration rules applied:
//   rough breathing → h   (ἁ = ha, ῥ = rh)
//   smooth breathing → (nothing)
//   accents (acute / grave / circumflex) → omitted
//   iota subscript → omitted
//   η = ē , ω = ō , υ = u  (never y)
//   θ = th , φ = ph , χ = ch , ψ = ps , ξ = x
//   kappa = k  (even when English cognates use c)
//
// Distractor feedback: "That would appear in Greek as '…'."
// ============================================================

"""
end

# ============================================================
# Main
# ============================================================

function generate(opts)
    if opts["seed"] !== nothing
        Random.seed!(opts["seed"])
    end

    n_dist = opts["n_options"] - 1
    n_dist < 1 && error("--n-options must be at least 2")

    prefix = opts["title_prefix"]
    font   = opts["font_em"]
    parts  = String[header_text(opts)]

    # Characters
    items = pick_items(CHARACTERS, opts["n_chars"])
    for (i, (g, lat)) in enumerate(items)
        dists = character_distractors(g, lat, n_dist)
        title = @sprintf("%sCharacters %02d", prefix, i)
        push!(parts, gift_question(title, prompt_for(:char, g, font), lat, dists, :char))
    end

    # Syllables
    items = pick_items(SYLLABLES, opts["n_syllables"])
    for (i, (g, lat)) in enumerate(items)
        dists = syllable_distractors(g, lat, n_dist)
        title = @sprintf("%sSyllables %02d", prefix, i)
        push!(parts, gift_question(title, prompt_for(:syllable, g, font), lat, dists, :syllable))
    end

    # Words
    items = pick_items(WORDS, opts["n_words"])
    for (i, (g, lat)) in enumerate(items)
        dists = word_distractors(g, lat, n_dist)
        title = @sprintf("%sWords %02d", prefix, i)
        push!(parts, gift_question(title, prompt_for(:word, g, font), lat, dists, :word))
    end

    open(opts["out"], "w") do io
        write(io, join(parts))
    end

    ntot = opts["n_chars"] + opts["n_syllables"] + opts["n_words"]
    println("Wrote $ntot questions → $(opts["out"])")
end

function main()
    opts = parse_args(ARGS)
    generate(opts)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
