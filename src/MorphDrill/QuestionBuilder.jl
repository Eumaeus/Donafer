# src/MorphDrill/QuestionBuilder.jl

module QuestionBuilder

using ..DataParser
using Random

export Question, build_question, to_gift

struct Question
    stem::String
    correct_answers::Vector{String}
    distractors::Vector{String}
    feedback_correct::Dict{String, String}
    feedback_wrong::Dict{String, String}
    chapter::Int
    category::String
end

function make_description_choice(desc::String, lemma::String)
    return "$(desc) of $(lemma)"
end

choice_key(form::MorphForm, direction::Symbol) =
    direction == :passive ?
        make_description_choice(form.description, form.lemma) :
        form.greek_form

function find_all_matching_descriptions(greek::String, lemma::String, pool::Vector{MorphForm})
    matches = filter(x -> x.greek_form == greek && x.lemma == lemma, pool)
    return unique(make_description_choice(x.description, x.lemma) for x in matches)
end

function find_all_matching_greeks(desc::String, lemma::String, pool::Vector{MorphForm})
    matches = filter(x -> x.description == desc && x.lemma == lemma, pool)
    return unique(x.greek_form for x in matches)
end

function candidate_pool(target::MorphForm, pool::Vector{MorphForm}, mode::String)
    candidates = filter(x -> !(x.greek_form == target.greek_form &&
                               x.description == target.description &&
                               x.lemma == target.lemma), pool)
    if mode == "lemma"
        return filter(x -> x.lemma == target.lemma, candidates)
    elseif mode == "type"
        return filter(x -> x.category == target.category, candidates)
    else
        return candidates
    end
end

function fallback_modes(mode::String)
    mode == "lemma" && return ["lemma", "type", "all"]
    mode == "type"  && return ["type", "all"]
    return ["all"]
end

# Unique displayed distractors, without replacement.
# Prefer the configured mode; widen the pool only if needed to reach `needed`.
function select_distractors(target::MorphForm, pool::Vector{MorphForm}, needed::Int,
                            mode::String, rng, direction::Symbol,
                            exclude::Set{String})
    needed <= 0 && return MorphForm[]

    chosen = MorphForm[]
    seen = copy(exclude)

    for m in fallback_modes(mode)
        remaining = needed - length(chosen)
        remaining <= 0 && break

        for x in shuffle(rng, candidate_pool(target, pool, m))
            key = choice_key(x, direction)
            key in seen && continue
            push!(seen, key)
            push!(chosen, x)
            length(chosen) >= needed && break
        end
    end

    return chosen
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
        return "Incorrect. The $(item.description) of $(item.lemma) is **$(item.greek_form)** (Ch. $(item.chapter))."
    else
        return "Incorrect. **$(item.greek_form)** is the $(item.description) of $(item.lemma) (Ch. $(item.chapter))."
    end
end

function item_for_correct_answer(item::MorphForm, answer::String,
                                 direction::Symbol, pool::Vector{MorphForm})
    matching = if direction == :passive
        filter(x -> x.greek_form == item.greek_form &&
                    x.lemma == item.lemma &&
                    make_description_choice(x.description, x.lemma) == answer, pool)
    else
        filter(x -> x.description == item.description &&
                    x.lemma == item.lemma &&
                    x.greek_form == answer, pool)
    end
    return isempty(matching) ? item : first(matching)
end

function build_question(item::MorphForm, pool::Vector{MorphForm};
                        direction::Symbol = :passive,
                        num_choices::Int = 5,
                        distracter_mode::String = "all",
                        rng = Random.default_rng())
    if direction == :passive
        stem = item.greek_form
        full_correct = collect(find_all_matching_descriptions(item.greek_form, item.lemma, pool))
    else
        stem = "$(item.description) of $(item.lemma)"
        full_correct = collect(find_all_matching_greeks(item.description, item.lemma, pool))
    end

    # Always expose every correct analysis, then fill up to number_choices.
    actual_correct = isempty(full_correct) ? String[] : copy(full_correct)
    needed = max(0, num_choices - length(actual_correct))

    dist_items = select_distractors(item, pool, needed, distracter_mode, rng,
                                    direction, Set(actual_correct))
    actual_distractors = unique(choice_key(d, direction) for d in dist_items)
    actual_distractors = [d for d in actual_distractors if !(d in actual_correct)]

    fb_correct = Dict{String,String}()
    for ans in actual_correct
        fb_item = item_for_correct_answer(item, ans, direction, pool)
        fb_correct[ans] = build_feedback(fb_item, direction)
    end

    fb_wrong = Dict{String,String}()
    for d in dist_items
        key = choice_key(d, direction)
        fb_wrong[key] = build_wrong_feedback(d, direction)
    end

    return Question(stem, actual_correct, actual_distractors,
                    fb_correct, fb_wrong, item.chapter, item.category)
end

# 1 → 100, 2 → 50, 3 → 33.333 (Moodle wants three decimals for 100/3).
function format_correct_weight(n_correct::Int)::String
    n_correct <= 1 && return "100"
    weight = 100 / n_correct
    isinteger(weight) && return string(Int(weight))
    return string(round(weight; digits=3))
end

function to_gift(q::Question; qid::String = "Q")::String
    io = IOBuffer()
    println(io, "::$(qid)::[markdown]$(q.stem):{")

    n_correct = max(length(q.correct_answers), 1)
    correct_marker = "~%$(format_correct_weight(n_correct))%"

    options = [(ans, true, get(q.feedback_correct, ans, "Correct."))
               for ans in q.correct_answers]
    append!(options, [(dist, false, get(q.feedback_wrong, dist, "Incorrect."))
                      for dist in q.distractors])
    shuffle!(options)

    for (text, is_correct, fb) in options
        marker = is_correct ? correct_marker : "~%-100%"
        println(io, "\t$(marker)$(text)#$(fb)")
    end

    println(io, "}")
    return String(take!(io))
end

end # module QuestionBuilder