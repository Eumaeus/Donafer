# src/MorphDrill/QuestionBuilder.jl

module QuestionBuilder

using ..DataParser
using Random

export Question, build_question, to_gift

struct Question
    stem::String
    correct_answers::Vector{String}
    distractors::Vector{String}
    feedback_correct::String
    feedback_wrong::Dict{String, String}
    chapter::Int
    category::String
end

function make_description_choice(desc::String, lemma::String)
    return "$(desc) of $(lemma)"
end

function find_all_matching_descriptions(greek::String, lemma::String, pool::Vector{MorphForm})
    matches = filter(x -> x.greek_form == greek && x.lemma == lemma, pool)
    return unique(make_description_choice(x.description, x.lemma) for x in matches)
end

function find_all_matching_greeks(desc::String, lemma::String, pool::Vector{MorphForm})
    matches = filter(x -> x.description == desc && x.lemma == lemma, pool)
    return unique(x.greek_form for x in matches)
end

function select_distractors(target::MorphForm, pool::Vector{MorphForm}, needed::Int,
                            mode::String, rng)
    candidates = filter(x -> !(x.greek_form == target.greek_form &&
                               x.description == target.description &&
                               x.lemma == target.lemma), pool)

    if mode == "lemma"
        candidates = filter(x -> x.lemma == target.lemma, candidates)
    elseif mode == "type"
        candidates = filter(x -> x.category == target.category, candidates)
    # "all" → keep everything
    end

    if isempty(candidates)
        return MorphForm[]
    end
    n = min(needed, length(candidates))
    return rand(rng, candidates, n)
end

function build_feedback(item::MorphForm, direction::Symbol)
    if direction == :passive
        return "Correct: **$(item.greek_form)** is $(item.description) of $(item.lemma) (Chapter $(item.chapter))."
    else
        return "Correct: **$(item.greek_form)** is the correct form for $(item.description) of $(item.lemma) (Chapter $(item.chapter))."
    end
end

function build_wrong_feedback(item::MorphForm, direction::Symbol)
    if direction == :passive
        return "Incorrect. **$(item.greek_form)** is $(item.description) of $(item.lemma) (Ch. $(item.chapter))."
    else
        return "Incorrect. The form for $(item.description) of $(item.lemma) is **$(item.greek_form)** (Ch. $(item.chapter))."
    end
end

function build_question(item::MorphForm, pool::Vector{MorphForm};
                        direction::Symbol = :passive,
                        num_choices::Int = 5,
                        distracter_mode::String = "all",
                        rng = Random.default_rng())
    if direction == :passive
        stem = item.greek_form
        full_correct = find_all_matching_descriptions(item.greek_form, item.lemma, pool)

        dist_items = select_distractors(item, pool, num_choices - 1, distracter_mode, rng)
        dist_answers = unique(make_description_choice(d.description, d.lemma) for d in dist_items)

        guaranteed = isempty(full_correct) ? "" : rand(rng, full_correct)
        all_options = unique([guaranteed; dist_answers])

        actual_correct = [a for a in all_options if a in full_correct]
        actual_distractors = [a for a in all_options if !(a in actual_correct)]

        fb_correct = build_feedback(item, direction)
        fb_wrong = Dict{String,String}()
        for d in dist_items
            key = make_description_choice(d.description, d.lemma)
            fb_wrong[key] = build_wrong_feedback(d, direction)
        end

    else  # :active
        stem = "$(item.description) of $(item.lemma)"
        full_correct = find_all_matching_greeks(item.description, item.lemma, pool)

        dist_items = select_distractors(item, pool, num_choices - 1, distracter_mode, rng)
        dist_answers = unique(d.greek_form for d in dist_items)

        guaranteed = isempty(full_correct) ? "" : rand(rng, full_correct)
        all_options = unique([guaranteed; dist_answers])

        actual_correct = [a for a in all_options if a in full_correct]
        actual_distractors = [a for a in all_options if !(a in actual_correct)]

        fb_correct = build_feedback(item, direction)
        fb_wrong = Dict{String,String}()
        for d in dist_items
            fb_wrong[d.greek_form] = build_wrong_feedback(d, direction)
        end
    end

    return Question(stem, actual_correct, actual_distractors,
                    fb_correct, fb_wrong, item.chapter, item.category)
end

function to_gift(q::Question; qid::String = "Q")::String
    io = IOBuffer()
    println(io, "::$(qid)::[markdown]$(q.stem):{")

    options = [(ans, true, q.feedback_correct) for ans in q.correct_answers]
    append!(options, [(dist, false, get(q.feedback_wrong, dist, "Incorrect.")) for dist in q.distractors])

    shuffle!(options)

    for (text, is_correct, fb) in options
        marker = is_correct ? "~%100%" : "~%-100%"
        println(io, "\t$(marker)$(text)#$(fb)")
    end

    println(io, "}")
    return String(take!(io))
end

end # module QuestionBuilder