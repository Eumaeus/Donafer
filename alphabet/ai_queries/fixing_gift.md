You recently helped me generate a quiz to be used in Moodle, in `.gift` format. It was practice on the Greek alphabet. That convesation is at: <https://grok.com/share/c2hhcmQtMg_69c6b927-149a-488d-89a6-8ddb65a9b392>.

The quiz looks great, but (alas) my institution's Moodle has disabled the "shuffle within questions" setting. So in the quiz you made for me, the correct answer is alwys "a".

Below are two representative questions:

~~~

::Characters 02::
Select the correct Latin-alphabet transliteration of the following Greek character:<br><br><span style="font-size:1.9em;">ἀ</span> {
	=a#Correct.
	~ha#That would appear in Greek as 'ἁ'.
	~e#That would appear in Greek as 'ἐ'.
	~o#That would appear in Greek as 'ὀ'.
	~ē#That would appear in Greek as 'ἠ'.
}

::Characters 03::
Select the correct Latin-alphabet transliteration of the following Greek character:<br><br><span style="font-size:1.9em;">ἁ</span> {
	=ha#Correct.
	~a#That would appear in Greek as 'ἀ'.
	~hē#That would appear in Greek as 'ἡ'.
	~ho#That would appear in Greek as 'ὁ'.
	~hi#That would appear in Greek as 'ἱ'.
}

~~~

## Specific Request

I work in Julia. Could you help me make a Julia script that will generate any number of Greek-aphabet-quizzes, with parameters to define construction?

I would like:

- A list that I can edit of individual letters and letter-diacritical combinations, with their preferred Latin transliterations.
- A similar list of syllables, mapped to preferred transliterations.
- A list of Greek words, mapped to preferred transliterations.
- A pool of "confusions": pairs of characters that are likely to confuse new learners. Like `χ ξ, ρ π, σ ο, γ υ, Υ Γ`. The script should be weighted to offer those confusions, at least in the character-only part of the quiz.

Conversation at: <https://grok.com/share/c2hhcmQtMg_b0c1a400-a2ac-46d2-b899-28e2532b689a>


---


~~~ bash

julia generate_greek_quiz.jl
julia generate_greek_quiz.jl --n-chars 40 --n-syllables 30 --n-words 30
julia generate_greek_quiz.jl --seed 2026 --out quiz_section_a.gift
julia generate_greek_quiz.jl --help

~~~