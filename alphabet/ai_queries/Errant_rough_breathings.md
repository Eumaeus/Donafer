You have been helping me with a Julia script for generating `.gift`-formatted quizzes, intended for Moodle, to help my students get used to the Ancient Greek alphabet.

I really love what we've got.

The last conversation is at <https://grok.com/share/c2hhcmQtMg_62ccfb2d-d0cb-4ef2-b8c2-d984dbfd2734>

The code for this project is on GitHub at: <https://github.com/Eumaeus/Donafer/tree/main/alphabet>.

The script is at <https://github.com/Eumaeus/Donafer/tree/main/alphabet>.

The latest output from the script is at <https://github.com/Eumaeus/Donafer/blob/main/alphabet/generate_greek_quiz.jl>.

I would like help with one change.

This is one generated question that illustrates the problem:

~~~

::Words 09::
Select the correct Latin-alphabet transliteration of the following Greek word:<br><br><span style="font-size:1.5em;">δῶρον</span> {
	~hdōron#Not under this quiz's rules (there is no rough breathing here, so no h).
	=dōron#Correct.
	~tōn#That would appear in Greek as 'τῶν'.
	~luō#That would appear in Greek as 'λύω'.
	~Odusseus#That would appear in Greek as 'Ὀδυσσεύς'.
}

~~~

The first item, a distractor, has `hdōron` as the (incorrect) answer. The feedback notes that there is no rough-breathing on the question-word `δῶρον`, which is true enough. 

But there would never be a rough-breathing on a consonant, so I don't think this is a helpful distractor.

I have not gotten familiar enough with the code to see where it is generating distractors. I can see where it will (cleverly!) offer the a correct answer for an item that begins with a vowel and smooth-breathing, and then offer a distractor of the same word but as thought it had a rough-breathing. 

But it should not do so when the word does not beging with a vowel. Can you point me to where in the code I can make what I think will be a simple edit?

Thank you! 

Conversation at: <https://grok.com/share/c2hhcmQtMg_62ccfb2d-d0cb-4ef2-b8c2-d984dbfd2734>