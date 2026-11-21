# Donafer

Code and data for generating practice drills, quizzes, and exercises for students of Ancient Greek. Output is in `.gift` format, for importing into Moodle.

## Code

The code is in Julia. Scripts for running it are in <scripts/>.

You will need to add `ArgParse` to your Julia installation.

Run a script with:

`julia --project=. scripts/check_morphology_integrity.jl`

(That script confirms that the morphology forms are valid and well-formed.)

Further instructions are in the scripts.

## Data

The directory <data/> includes the raw data for vocabulary and morphology. Currently, the dataset is aimed at the *Hansen & Quinn* textbook. 

The morphology data is intended to be independent of any specific textbook. Forms are captured in individual files, and aligned to chapters in a textbook by means of one or more `.tsv` files in <data/morphology/chapters>.

### Vocabulary verbs (principal-part English)

Verb lines in `data/vocabulary/hq.txt` preferably use **split Greek / numbered-English** fields so each principal part can carry tense-appropriate glosses (multiple glosses per PP allowed). Legacy shared English (`unbind; free`) still parses. Field rules are documented in the header comments of `hq.txt`. Config knobs live in `config/vocab_drill.toml` (`pp_gloss_fraction`, default `0.0`).

### Vocabulary prepositions (case senses)

Prep lines preferably keep one sense per case as `lemma + gen|dat|acc#glosses` (alternate forms of the same case may share a line with `;`). An optional consolidated form uses lemma-only Greek with case-tagged English (`παρά#gen …; dat …; acc …`). Both are documented in the `hq.txt` header. Case-sense drills are toggled with `prep_case_fraction` / `prep_case_max_count` (default off) in `config/vocab_drill.toml`.

## References

- [Moodle `.gift`  documentation](https://docs.moodle.org/502/en/GIFT_format)