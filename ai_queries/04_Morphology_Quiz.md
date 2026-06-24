
You are helping me with this project: <https://github.com/Eumaeus/Donafer>

The record of the conversation that got us to the present state of the work is in the repo at `ai_queries`. The latest conversation was <https://x.com/i/grok/share/69f8d341d801401c9871d410f1d3392f>

You helped me build code for generating `.gift` files for Moodle that contain vocabulary drills. Now let's work on drills for the morphology of nouns, pronouns, adjectives, and verbs.

Then you helped me create a script that validated the integrity of the data I have started to assemble as the basis for generating morphology drills. That was a huge step.

Finally, you gave me a skeleton `.toml` file, `config/morph_drill.toml`.

Everything is up to date in the repository, and I'm ready to start working on generating drills in `.gift` format.

> You seem to have a complete understanding of the `.gift` format, but its docs are at <https://docs.moodle.org/502/en/GIFT_format>, and in case the "human-checking" prevents you from accessing that page (why do they care who accesses the spec for an open-source serialization format?), there is a reference at <https://buypct.com/gift_reference.pdf>.

## Morphology Drill: Overview

As with vocabulary, I would like to select a chapter and generate a drill including all forms in that chapter and in earlier chapters. This will mean having a parameter for `chapter_list` *vel sim.* in `data/morphology/chapters/`. I have a working one at `data/morphology/chapters/hq.tsv`.

Unlike with vocabulary, I see no purpose in weighting items from the current chapter over those presented earlier. The challenge for learners is both to recognize the new forms, but also to differentiate them from all the forms they already know.

BUT, I guess it would be useful to have the option of constraining a drill. So let's have parameters for: `starting_chapter` and `current_chapter`. `starting_chapter` will generally have a value of `1`.

I would like the ability to constrain a generated drill according to word-type. In `data/morphology/chapters/hq.tsv`, you can see that the categories are: pronoun, noun, adjective, participle, verb.

When generating a drill, I would like to specify one *or more* of those types, and include forms in the drill accordingly.

I selected the list of types with this in mind. For specific drills, certain combinations suggest themselves:

- noun + adjective
- adjective + pronoun
- adjective + participle
- verb + participle
- *etc.*

The critical pieces of data will be:

- The `chapter_list` which will allow us to collect forms by chapter, categorized by type, with the file-names for the forms-files presented in those chapters.

- The *lemma*, given on the second line of a forms-file

The first two lines of `data/morphology/forms/adjectives/ἄδικος.txt`:

~~~
template#template_adjective_2.txt
lemma#the adjective “unjust”
~~~

The lemma here is "the adjective “unjust”".

- The template, identified on the first line of a forms-file (see above). This provides labels, morphological descriptions, for each of the forms in the forms-file.

- The forms in the forms file.

The questions should be multiple choice, with choices determined by parameter `number_choices`. These will include the correct answer and distracters.

## Morphology Drill: Multi-Correct Answers

There will be lots of opportunities for multi-correct questions. Nominative/Vocative and Nominative/Accusative/Vocative, alone, will provide opportunities. Some verb forms will as well.

As with vocabulary, I don't think we should seek them out. Let's pick a specific form for our answer, get distracters (see below), and if one of the distracters happens to be a correct answer to the question, mark it as such with partial credit so the student has to get them all.

## Morphology Drill: Distracters

I have added a parameter to the config file, `distracter_mode`, which can have three possible values: "all", "type", or "lemma". With "all", distracters are chosen across all forms in the pool. With "type" distracters are chosen among forms from words of the same type. With "lemma" distracters are constrained to forms of the same lemma.

Because Moodle's purported ability to shuffle multiple-choice answers is not reliable, we should do the shuffling at generation so the correct answer is not always the first answer.

## Morphology Drill: Vocative and Dual

It can be needlessly tedious to force students to spend a lot of time learning the vocative (which is always easy to spot when reading), and the dual (which is rare, usually commented on, and pretty distinctive).

So the config file has the option to exclude any forms with "voc." or "dual" in their description.

I have included vocatives and duals in my data, for the sake of completeness and because this large dataset of forms might be useful in other contexts.

## Morphology Drill: Active and Passive

`active_knowledge_fraction` should determine how many questions test active knowledge and how many test passive knowledge. 

For passive knowledge, "recognizing forms", the question will present a Greek form, and the multiple choices will offer a description and lemma, *e.g.* `masc. nom. singular of the noun “bridge”`.

~~~
Q: ἀνθρώπων
  - nom. sing. of the noun “human being”
  - gen. sing. of the noun “human being”
  - acc. sing. of the noun “human being”
  - gen. pl. of the noun “human being” <-- correct answer
  - dat. sing. of the noun “human being”
~~~

For active knowledge, "producing forms", the question will present a lemma and a morphological description, and the multiple choices will offer different Greek forme:

~~~
Q: nom. sing. of the noun “human being”
  - ἄνθρωποι
  - ἄνθρωπον
  - ἄνθρωπος <-- correct answer
  - ἀνθρώοις
  - ἀνθρώπων
~~~

## Conclusion

I hope this might be enough to go on. I'd like the generation-script to be runnable from the `scripts/` directory, with `julia --project=. scripts/generate_morph_drill.jl`.

With the script for generating vocabulary drills (which I have renamed to `scripts/generate_vocab_drill.jl`), you gave me the option to override parameters on the command-line. That would be very handy. Perhaps "current_chapter", "num_questions", and "categories" would be the ones to override.

So, I'd value a first draft of this, if my description is adequate. 

All files are checked into the repository.






