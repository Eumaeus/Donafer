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

## References

- [Moodle `.gift`  documentation](https://docs.moodle.org/502/en/GIFT_format)