#!/usr/bin/env julia

"""
migrate_pp_english.jl

Rewrite verb English fields in data/vocabulary/hq.txt to the Phase 4
numbered-English format, using a curated conjugation table.

Only lemmas listed in PP_ENGLISH are rewritten. Others keep legacy English.
Re-run is idempotent for already-migrated lines (detects numbered English).

Usage (from repo root):
    julia --project=. scripts/migrate_pp_english.jl
    julia --project=. scripts/migrate_pp_english.jl --dry-run
"""

using ArgParse

# Each sense: (present, past, past_participle[, voice])
# voice =
#   :active (default) → PP5 “I have been …”, PP6 “I was …”
#   :middle → deponent/middle: PP5 “I have …”, PP6 “I …” (past)
#   :intransitive → emit only for PP 1–4 (skip morphological passives)
#   :passive_only → emit only for PP 5–6 as “I have been …” / “I was …”
# Only emit glosses for PP numbers that appear in the Greek field.
# `present` is the phrase after “I ” (use “am willing”, not “be willing”).

const PP_ENGLISH = Dict{String, Vector{Tuple}}(
    # --- Unit 2 ---
    "κελεύω" => [("command", "commanded", "commanded")],
    "λύω" => [("unbind", "unbound", "unbound"), ("free", "freed", "freed")],
    "παιδεύω" => [("educate", "educated", "educated"), ("teach", "taught", "taught")],
    "πέμπω" => [("send", "sent", "sent")],
    # --- Unit 3 ---
    "γράφω" => [("write", "wrote", "written"), ("draw", "drew", "drawn")],
    "θύω" => [("sacrifice", "sacrificed", "sacrificed")],
    "παύω" => [("stop", "stopped", "stopped"), ("make (someone) stop", "made (someone) stop", "made to stop")],
    "φυλάττω" => [("guard", "guarded", "guarded")],
    # --- Unit 4 ---
    "διδάσκω" => [("teach", "taught", "taught")],
    "ἐθέλω" => [("be willing", "was willing", "been willing", :intransitive),
                ("wish", "wished", "wished", :intransitive)],
    "θάπτω" => [("bury", "buried", "buried")],
    "τάττω" => [
        ("draw up (in battle)", "drew up (in battle)", "drawn up (in battle)"),
        ("arrange", "arranged", "arranged"),
        ("order", "ordered", "ordered"),
    ],
    # --- Unit 5 ---
    "ἄρχω" => [("rule", "ruled", "ruled"), ("command", "commanded", "commanded")],
    "βλάπτω" => [("hurt", "hurt", "hurt"), ("harm", "harmed", "harmed")],
    "πείθω" => [("persuade", "persuaded", "persuaded")],
    "πράττω" => [("do", "did", "done"), ("fare", "fared", "fared", :intransitive)],
    # --- Unit 6 ---
    "δουλεύω" => [("be a slave", "was a slave", "been a slave", :intransitive)],
    "κωλύω" => [("hinder", "hindered", "hindered"), ("prevent", "prevented", "prevented")],
    "πολῑτεύω" => [
        ("live as a citizen", "lived as a citizen", "lived as a citizen", :intransitive),
        ("conduct the government", "conducted the government", "conducted the government", :intransitive),
        ("governed", "was governed", "governed", :passive_only),
    ],
    "χορεύω" => [("dance", "danced", "danced"), ("take part in a dance", "took part in a dance", "taken part in a dance", :intransitive)],
    # --- Unit 7 ---
    "κλέπτω" => [("steal", "stole", "stolen")],
    "λείπω" => [("leave", "left", "left"), ("leave behind", "left behind", "left behind")],
    "σῴζω" => [("save", "saved", "saved")],
    # --- Unit 8 ---
    "ἄγω" => [("lead", "led", "led")],
    "ἥκω" => [("have come", "had come", "come", :intransitive),
              ("be present", "was present", "been present", :intransitive)],
    # --- Unit 9 ---
    "ἀδικέω" => [("do wrong", "did wrong", "done wrong", :intransitive),
                 ("wrong", "wronged", "wronged")],
    "νικάω" => [("win", "won", "won", :intransitive), ("conquer", "conquered", "conquered")],
    "ποιέω" => [("make", "made", "made"), ("do", "did", "done")],
    "τιμάω" => [("honor", "honored", "honored")],
    # --- Unit 10 ---
    "ἀγγέλλλω" => [("announce", "announced", "announced")],
    "ἀξιόω" => [
        ("think worthy of", "thought worthy of", "thought worthy of"),
        ("think it right", "thought it right", "thought it right", :intransitive),
        ("expect", "expected", "expected"),
    ],
    "δηλόω" => [("make clear", "made clear", "made clear"), ("show", "showed", "shown")],
    "καλέω" => [("call", "called", "called")],
    "μένω" => [("remain", "remained", "remained", :intransitive),
               ("stay", "stayed", "stayed", :intransitive)],
    "τελευτάω" => [("finish", "finished", "finished"),
                   ("die", "died", "died", :intransitive)],
    # --- Unit 11 ---
    "ἀκούω" => [("hear", "heard", "heard")],
    "βάλλω" => [("throw", "threw", "thrown"), ("hit", "hit", "hit")],
    "βούλομαι" => [("want", "wanted", "wanted", :middle)],
    "δέχομαι" => [("receive", "received", "received", :middle), ("welcome", "welcomed", "welcomed", :middle)],
    "λαμβάνω" => [("take", "took", "taken")],
    "πάσχω" => [("suffer", "suffered", "suffered", :intransitive)],
)

function sense_voice(sense::Tuple)
    length(sense) >= 4 ? sense[4] : :active
end

function sense_applies(pp::Int, voice::Symbol)::Bool
    voice == :intransitive && return pp in 1:4
    voice == :passive_only && return pp in 5:6
    return true
end

function present_1sg(present::AbstractString)::String
    # “be willing” → “am willing”; future still uses “will be willing”.
    if startswith(present, "be ")
        return "am " * present[4:end]
    end
    return String(present)
end

function gloss_for(pp::Int, present::AbstractString, past::AbstractString,
                   pp_form::AbstractString, voice::Symbol)::Union{String, Nothing}
    sense_applies(pp, voice) || return nothing
    if voice == :middle
        pp == 1 && return "I $(present_1sg(present))"
        pp == 2 && return "I will $present"
        pp == 3 && return "I $past"
        pp == 4 && return "I have $pp_form"
        pp == 5 && return "I have $pp_form"
        pp == 6 && return "I $past"
    elseif voice == :passive_only
        pp == 5 && return "I have been $pp_form"
        pp == 6 && return "I was $pp_form"
    else
        # :active and :intransitive (1–4)
        pp == 1 && return "I $(present_1sg(present))"
        pp == 2 && return "I will $present"
        pp == 3 && return "I $past"
        pp == 4 && return "I have $pp_form"
        pp == 5 && return "I have been $pp_form"
        pp == 6 && return "I was $pp_form"
    end
    return nothing
end

function greek_pp_numbers(greek_field::AbstractString)::Vector{Int}
    nums = Int[]
    for seg in split(greek_field, ';')
        m = match(r"^\s*(\d+)\s+", seg)
        m === nothing && continue
        n = parse(Int, m.captures[1])
        n in nums || push!(nums, n)
    end
    return nums
end

function lemma_from_greek(greek_field::AbstractString)::Union{String, Nothing}
    for seg in split(greek_field, ';')
        m = match(r"^\s*\d+\s+(\S+)", seg)
        m !== nothing && return String(m.captures[1])
    end
    # bare lemma (no numbered PPs)
    s = strip(greek_field)
    isempty(s) && return nothing
    return String(split(s, r"[\s,.;]"; limit=2)[1])
end

function build_numbered_english(lemma::String, greek_field::AbstractString)::Union{String, Nothing}
    senses = get(PP_ENGLISH, lemma, nothing)
    senses === nothing && return nothing
    pp_nums = greek_pp_numbers(greek_field)
    isempty(pp_nums) && return nothing  # e.g. ἀποδέχομαι — leave legacy

    parts = String[]
    for n in pp_nums
        for sense in senses
            present = sense[1]
            past = sense[2]
            pp = sense[3]
            voice = sense_voice(sense)
            g = gloss_for(n, present, past, pp, voice)
            g === nothing && continue
            push!(parts, "$n $g")
        end
    end
    isempty(parts) && return nothing
    return join(parts, ";")
end

function is_numbered_english(english_field::AbstractString)::Bool
    for seg in split(english_field, ';')
        match(r"^\s*[1-6]\s+\S", seg) !== nothing && return true
    end
    return false
end

function transform_line(line::String; force::Bool=false)::Tuple{String, Bool}
    startswith(strip(line), "//") && return (line, false)
    parts = split(line, '#'; limit=4)
    length(parts) != 4 && return (line, false)
    ch, cat, greek, english = parts
    strip(cat) != "verb" && return (line, false)
    if !force && is_numbered_english(english)
        return (line, false)
    end
    lemma = lemma_from_greek(greek)
    lemma === nothing && return (line, false)
    new_eng = build_numbered_english(lemma, greek)
    new_eng === nothing && return (line, false)
    return ("$(ch)#$(cat)#$(greek)#$(new_eng)", true)
end

function parse_commandline()
    s = ArgParseSettings(description = "Migrate hq.txt verbs to numbered per-PP English")
    @add_arg_table! s begin
        "--file"
            help = "Path to vocabulary file"
            default = "data/vocabulary/hq.txt"
        "--dry-run"
            help = "Print changes without writing"
            action = :store_true
        "--force"
            help = "Rewrite even if English is already numbered"
            action = :store_true
    end
    return parse_args(s)
end

function main()
    args = parse_commandline()
    path = args["file"]
    lines = readlines(path)
    out = String[]
    changed = 0
    skipped_known = 0
    for line in lines
        new_line, did = transform_line(line; force=args["force"])
        push!(out, new_line)
        if did
            changed += 1
            println("MIGRATE: $(strip(line))")
            println("     ->  $(strip(new_line))")
        else
            parts = split(line, '#'; limit=4)
            if length(parts) == 4 && strip(parts[2]) == "verb"
                lemma = lemma_from_greek(parts[3])
                if lemma !== nothing && haskey(PP_ENGLISH, lemma) && is_numbered_english(parts[4])
                    skipped_known += 1
                elseif lemma !== nothing && !haskey(PP_ENGLISH, lemma)
                    println("LEAVE:  $lemma (no conjugation table entry)")
                elseif lemma !== nothing && greek_pp_numbers(parts[3]) |> isempty
                    println("LEAVE:  $lemma (no numbered Greek PPs)")
                end
            end
        end
    end

    println("\nChanged $changed verb line(s); $skipped_known already numbered.")
    if args["dry-run"]
        println("Dry run — file not written.")
    else
        open(path, "w") do io
            for (i, line) in enumerate(out)
                print(io, line)
                i < length(out) && print(io, '\n')
            end
            # preserve trailing newline if original had one
            endswith(read(path, String), "\n")  # path already overwritten — use out
        end
        # Ensure file ends with newline
        open(path, "w") do io
            for line in out
                println(io, line)
            end
        end
        println("Wrote $path")
    end
end

main()
