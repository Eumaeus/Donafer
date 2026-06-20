
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