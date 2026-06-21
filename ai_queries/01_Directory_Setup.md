
<https://x.com/i/grok/share/d408876eae22443a9f4504896a39f853>

## Rationale for Key Decisions

### `src/Gift.jl` (Reusable Layer)
A dedicated module for everything related to writing Moodle `.gift` format. This will be useful for *all* future generators (morphology, sentences, etc.). Keeps format-specific logic isolated from domain logic.

### `src/VocabDrill/` (Domain Module)
Clean separation for the first major feature. Future modules can follow the exact same pattern:
- `src/Typing/`
- `src/Morphology/`
- `src/SentenceAnalysis/`

### `config/vocab_drill.toml`
All runtime parameters live in one human-readable TOML file (current chapter, number of questions, active/passive ratio, current-vs-review proportion, number of choices, random seed, etc.). This makes experiments and classroom use reproducible and easy to tweak without touching code.

### `generated/` vs `sample_output/`
- `generated/` = fresh output (timestamped, gitignored).
- `sample_output/` = historical reference from the earlier Gifter.jl work.

### Why not put everything under a single `src/Donafer.jl` package?
We want maximum flexibility. Some future components (especially typing practice) may involve JavaScript or shell scripts. Keeping a lightweight structure with clear module directories is more practical than forcing a single monolithic Julia package at this stage.

## Actions Taken (2026-06-20)

- Directories created as proposed:
  - `config/`
  - `src/Gift.jl`
  - `src/VocabDrill/`
  - `scripts/`
  - `generated/vocab/`
  - `test/`
  - `docs/`
- Existing files moved/organized where appropriate (`data/`, `sample_output/`, `ai_queries/`).
- Files committed to the repository.

## Next Steps (Proposed Order)

1. **Define the data model** — Create Julia structs for `VocabItem` (handling chapters/units, categories, principal parts, multiple English translations, etc.).
2. **Write the parser** (`src/VocabDrill/DataParser.jl`) — Robustly read and expand `data/vocabulary/hq.txt` into a list of structured items.
3. **Design the configuration schema** — Create `config/vocab_drill.toml` with all parameters from the project desiderata.
4. **Implement selection logic** (`ItemSelector.jl`) — Current chapter + review items, proportions, “every current-chapter item appears before any repeats,” randomness with optional seed.
5. **Build question logic** (`QuestionBuilder.jl`) — Active vs passive questions, distractors (preferably same category), multi-correct handling, rich feedback with Markdown, principal-part labels.
6. **Implement the generator** and a thin script in `scripts/`.
7. **Test against** the style and requirements shown in `sample_output/`.

## Open Questions / To Be Refined

- Exact TOML parameter names and defaults (we will iterate on this together).
- How strictly to enforce “same category” for distractors when the pool is small (early chapters).
- Whether `Gift.jl` should eventually become its own small registered package or stay internal.
- Naming conventions for question titles/IDs in the generated `.gift` files (for easy Moodle Question Bank organization).
- Long-term: Should we eventually split some modules into separate Julia packages?

---

**Status:** Structure approved and implemented. Ready to begin coding the Vocabulary Drill Generator.

---

I will need to step away shortly, so let's do two at once, and I can plug the next steps in piecemeal over the day;

- Move straight to drafting the data model + parser code for the next step?
- Create a starter `config/vocab_drill.toml` template at the same time?

I am excited to be starting this, and thrilled at the comprehensive and professional followup you gave me with `01_Directory_Setup.` 

---

Okay! In the file DataParser.jl file, we're getting those SubString{String} errors when I run the test code:

  no method matching expand_entry(::Int64, ::SubString{String}, ::SubString{String}, ::SubString{String})

   @ Main.DataParser ~/Dropbox/CITE/grok/Donafer/src/VocabDrill/DataParser.jl:82

This shows up all the time with Julia! What is the cleanest way to deal with this?

**Solution:** Change `String` to `AbstractString` in the function declaration.

---

Okay. I have checked in everything. I copied the file `config.jl` from Dramaturg, where it has worked perfectly. I put it in `src/config.jl`. If it would be better-practice to put it in a sub-directory, please advise me! 

Let's do `ItemSelecter.jl` next. I've done a version of that, in the past, in Scala and in Julia. I will be super interested to see your, certainly more professional, version!

Everything is checked into the repo.

---

~~~julia

include("src/VocabDrill/DataParser.jl")
include("src/VocabDrill/ItemSelector.jl")

using .DataParser, .ItemSelector

all_items = parse_vocabulary_file("data/vocabulary/hq.txt")

result = select_quiz_items(
    all_items;
    current_chapter = 3,
    num_questions = 80,
    current_chapter_fraction = 0.6,
    seed = 42
)

println("Total selected: ", length(result.items))
println("From current chapter: ", result.num_current)
println("From review: ", result.num_review)
println("First 5 items:")
for item in result.items[1:5]
    println("  Ch$(item.chapter) | $(item.greek_display) → $(item.english)")
end

~~~

---

Julia setup problems. I get this when running the first two `include()` commands:

~~~
julia> include("src/VocabDrill/DataParser.jl")
Main.DataParser

julia> include("src/VocabDrill/ItemSelector.jl")
ERROR: LoadError: UndefVarError: `VocabItem` not defined in `Main.ItemSelector`
~~~

---

Yes! Let's update everything we have this point. I think I may have missed something.

When I run the code above, it fails at the first "include":

~~~
julia> include("src/VocabDrill/VocabDrill.jl")
ERROR: LoadError: UndefVarError: `VocabItem` not defined in `Main.VocabDrill.ItemSelector`
~~~

I have been starting Julia with `julia --project=.`, as I have gotten used to doing. If that is a mistake, please let me know!

I have checked in all recent changes to the repository: <https://github.com/Eumaeus/Donafer>

~~~

---

We're still getting that error, or a similar one:

~~~julia

julia> include("src/VocabDrill/VocabDrill.jl")
ERROR: LoadError: UndefVarError: `DataParser` not defined in `Main.VocabDrill.ItemSelector`

Suggestion: check for spelling errors or missing imports.
Stacktrace:
 [1] top-level scope
   @ ~/Dropbox/CITE/grok/Donafer/src/VocabDrill/ItemSelector.jl:5
 [2] include(mapexpr::Function, mod::Module, _path::String)
   @ Base ./Base.jl:307
 [3] top-level scope
   @ ~/Dropbox/CITE/grok/Donafer/src/VocabDrill/VocabDrill.jl:5
 [4] include(mapexpr::Function, mod::Module, _path::String)
   @ Base ./Base.jl:307
 [5] top-level scope
   @ REPL[1]:1
in expression starting at /Users/cblackwell/Dropbox/CITE/grok/Donafer/src/VocabDrill/ItemSelector.jl:3
in expression starting at /Users/cblackwell/Dropbox/CITE/grok/Donafer/src/VocabDrill/VocabDrill.jl:1

~~~

I seem to recall similar submodule hassles with earlier projects. This seems to be a Julia thing that we need to deal with. Once they get sorted, you never think about it until the next new project!

Everything is checked in, in its current state.

---

Still throwing that error. 

~~~
julia> include("src/VocabDrill/VocabDrill.jl")
Main.VocabDrill

julia> using .VocabDrill

julie> all_items = parse_vocabulary_file("data/vocabulary/hq.txt")
ERROR: UndefVarError: `parse_vocabulary_file` not defined in `Main`
Suggestion: check for spelling errors or missing imports.
Stacktrace:
 [1] top-level scope
   @ REPL[3]:1

julia> 
~~~

Is there some cache in `~/.julia`, or something like that that needs to be cleared out? I have compred this code to other projects that work fine, and I cannot see an obvious difference. 

The current state of everything is checked in at <https://github.com/Eumaeus/Donafer>.

---

And it all works! Thank you for sticking with me on this!

All code is checked in! Since we can load vocabulary and select items based on settings in `config/vocab_drill.toml`, we can move on to generating quizzes. 

Samples of output for passive-knowledge questions are in `sample_output`. We don't have to follow that slavishly, but questions like that seemed to work well last year. The list of how I envision the quizzes working are in `ai_queries/00_Project_Description.md`.

So… let's move on to `QuestionBuilder.jl`! 

---

Thanks for teaching me the term "distractors" for what I was calling "wrong answers"!

Here are answers to the questions you asked:

> Do you want QuestionBuilder to decide the direction (:greek_to_english vs :english_to_greek) internally based on the active/passive ratio, or should that decision happen in a higher-level Generator?

My answer: That seems like something for a higher-level generator, something like `QuizBuilder.jl`. I think that separation-of-concerns would have `QuestionBuilder.jl` focus on one question at a time, active or passive as instructed by a paramater passed to it.

> How important is multi-correct support in the first version? (i.e. cases where more than one answer is fully correct)

My answer: Having just invoked separation-of-concerns, this question makes me realize that `QuestionBuilder.jl` has to work with the whole vocabulary list, in order to generate distractors. I think multiple-correct-answers is fundamental.

Let's take the Greek word "καί". It means "and; also; even". Every student of Greek in human history has always seized "and" in their memory as the meaning of "καί", and then gets confused in sentences where it must mean "even". So if we start with an Item "καί = 'and'", but "even" shows up in the distractors, I really want them to have to see that both "and" and "even" are possibilities, and mark them as such, to get full credit. (Since they can keep clicking until they get it right before moving on, this will just reinforce, without punishing them.)

So… let's have multi-correct support from the outset.

> Would you like me to also start a simple to_gift(q::Question) function that turns this into the exact GIFT syntax you used last year?

Yes, please! 

Everything is check in at <https://github.com/Eumaeus/Donafer>.

---

If you could give me a little script for testing QuestionBuilder.jl, that would be great. I can look at it some this morning, and we can move on to QuizBuilder.jl in the next step.

