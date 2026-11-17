
# Overview: Desiderata for "Donafer"

The project currently can generate GIFT-formatted drills on Ancient Greek vocabluary and morphology, which I use via Moodle in my undergraduate classes. I'd like to extend its Vocabulary-drill features to allow more focused practice. 

Vocabulary drill generation is based on the file at `config/vocab_drill.toml`.

The data is drawn from the file at `data/vocabulary/hq.txt`.

I would like the option to have vocabulary drills that focus on particular categories of words.

> **Note:** It seems that I use "quiz" and "drill" interchangeably; both terms refer to "a `.gift`-formatted multiple-choice quiz that allows students to practice recognizing and understanding Ancient Greek vocabulary and morphology." In Moodle, I set these quizzes up with "Adaptive Feedback; No Penalties", so the students can answer each question until they get it right. Incorrect answers provide feedback. I prefer to make quizzes with 50-100 items, each with at least 8 answers, the correct answers plus distracters. The idea is to make "random guessing" more laborious than "learning the thing."

## Focus on the data-files

I would like to focus on extending, editing, or re-formatting the data files (`/data/` in the repository), with an eye toward the future. I did a better job with the morphology data (`/data/morphology`) than with the vocabulary data. The morphology data sets are independent of any specific textbook. The vocabulary data, as it stands, is closely tied with the Hansen & Quinn textbook. That is fine for the immediate future, though.


## Focus on verbs and their Principal Parts

Specifically, I would like to be able to generate a quiz, using the parameters already established in `config/vocab_drill.toml`, but with some additional parameters that let me generate a drill, based on specified chapters, the includes only vocabulary items of a specified type. The categories are: "noun", "verb", "prep", "adj", and "other"

First, I would like to be able to focus my students' drills on the Principal Parts of verbs:

- Generate a GIFT-formatted drill containing only verbs included in the specified chapters.
- Ask questions like: 
	- "Pick the 4th Principal Part of λύω."
	- "Which Principal part λύω is 'λέλυκα'?"
	- Perhaps matching drills, which GIFT can handle, where they are given six Principal Parts of a verb, shuffled, and asked to match them with "1st, 2nd, 3rd, etc.".


## Add practice on *what* the Principal Parts represent

While we're at it, let's add the option to include questions like this:

~~~

The **1st Principal Part** is the:
	~ Aorist, Active, Indicative, 1st person, Singular
	~ Aorist, Passive, Indicative, 1st person, Singular
	= Present, Active, Indicative, 1st person, Singular
	~ Perfect, Active, Indicative, 1st person, Singular
	~ Perfect, Middle/Passive, Indicative, 1st person, Singular
	~ Future, Active, Indicative, 1st person, Singular

~~~

As well as the inverse of the above, asking "Which Principal Part is the 'Aorist, Passive, …' ?".

There should be a parameter to limit how many questions of this type appear in any requested quiz.

## Add practice on what forms are generated from each principal part

Each of the six principal parts is the basis for one or more paradigms.

- 1st PP:
	- Present (active, middle, passive)
	- Imperfect (active, middle passage)
- 2nd PP
	- Future (active, middle)
- 3rd PP
	- Aorist (active, middle)
- 4th PP
	- Perfect (active)
	- Pluperfect (active)
- 5th PP
	- Perfect (middle/passive)
	- Pluperfect (middle/passive)
- 6th PP
	- Aorist (passive)
	- Future (passive)

Drills to test their knowledge of the above, in both directions:

	- "Which of these forms is based on the 2st Principal Part?"
	- "The Aorist Middle forms are based on which Principal Part?"


## Translating the Principal Parts of vocabulary verbs?

Currently, the vocabulary data includes all principal parts for a given verb, but the English is just the most basic translation, *e.g.* "send".

This is a fault built-into the data I originally captured. It would be better, since I've gone to the trouble to include all six principal parts in the Vocabulary for each verb, to have done something like this:

~~~
2#verb#1 λύω, I unbind, I free;2 λύσω, I will unbind, I will free;3 ἔλυσα, I unbound, I freed;4 λέλυκα, I have unbound, I have freed;5 λέλυμαι I have been unbound, I have been freed;6 ἔλύθην, I was unbound, I was freed
~~~

Or, perhaps more tidy:

~~~
2#verb#1 λύω;2 λύσω;3 ἔλυσα;4 λέλυκα;5 λέλυμαι;6 ἔλύθην#1 I unbind;1 I free;2 I will unbind;2 I will free;3 I unbound;3 I freed;4 I have unbound;4 I have freed;5 I have been unbound;5 I have freed;6 I was unbound;6 I was freed 
~~~

This would require me to updating the data, and updating the code to recognize and parse the new data when generating quizzes. 

A data-format like the above is verbose, but I think it would be better pedagocially, in the long term. 

## Focused Preposition Drills

I would like to help my students focus, at times, on prepositions and how their meaning changes according to the case of the object. I'm not sure the existing data-structure would make that easy, but there are a fininte number of prepositions, so editing the existing data would not be too laborious.

## A general refactoring, as seems best

This project evolved over time. I would be happy for any refactoring, small or large, you might suggest.

Since the code and data as they stand is working pretty well, we could branch the repository for new work. I am a little competent at basic branching, pull-requests, and merging. But I suspecdt I do not do this at a granular level that is considered ideal in the world of software development. I would happily accept guidance here.

Likewise, for any of the more sophisticated features of Git. My experience with Git extends over many years, but has been limited to the basics: commit, push, pull, branch, merge.

---

This looks great… thank you!

For questions like "Pick the 2nd Principal Part of ἐθέλω", it would be ideal if the distracters mostly included *other* principal parts of the same verb. With 8 choices, for example, it will not be possible for all distractors to be forms of the same verb.

In the ideal world, when distractors are forms of a different verb, we would preferentially select forms that meet some "approximate match" threshold. So we ask "What is the 3rd Principal Part of πάσχω" (correct answer: ἔπαθον), a good distractor would be "ἔπιθον" (the 3rd PP of πείθω). Assuming, of course, that both πάσχω and πείθω are present in the selected chapters.

I have generated a few drills with different parameters in `config/vocab_drill.toml`, and it looks like it is working really well.

---

Excellent. This is generating good quizzes, just as I had hoped! I think we can move forward!

---

