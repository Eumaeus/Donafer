I would like your help on a project that will probably take some time and a number of steps to complete.

I want your help building tools that will help me teach Ancient Greek, starting at the end of August of this year, AD 2026. I have done things like this before, on my own, but the staggering success of our collaboration on [Dramaturg](https://github.com/Eumaeus/Dramaturg.jl) has shown me what is possible if I work closely with Grok in a systematic way.

I have made a repository for this work: <https://github.com/Eumaeus/Donafer>. The name is a pun based on the Trojan War, the *Aeneid*, and the fact that I will make heavy use of Moodle's `.gift` format for quizzes used in Moodle.

So that you and I can keep on the same page, I will keep a record of each of my queries and follow-ups in the repository, enumerated in the directory `ai_queries/`, beginning with this one.

There will be many steps to this. I will describe the big picture, below, and then suggest the first step for us to work on.

## My Background

I would like to work in Julia, Javascript, and shell scripts. I am on MacOS. I confident in the basic tools of computing: the Unix command-line, git and GitHub (although not the more exotic aspects of Git).

I have taught Greek for 30 years, and have tried to use computational tools to help students that whole time (starting with HyperCard, if you can believe it).

## The Class

There will be two sections of Elementary Greek, each with 18 students. So I am motivated to be as efficient as possible with their time, my time, and especially classroom time. I don't have time to hand-grade a million quizzes, but the students deserve constant, daily, practice and feedback, with as little friction as possible. So we will use machines as labor-saving devices and force-multipliers!

We will be using the textbook: *Greek: An Intensive Course*, 2nd Revised Edition by Hardy Hansen and Gerald M. Quinn, ISBN 978-0823216635. All data and generated activities should be able to be keyed to chapters in this book, drawing on materials in the current chapter and preceding chapters.

## Philosophy

In traditional teaching, a teacher asked students to study some topic, then gave a quiz on that topic. The quiz served as incentive to do the assigned studying, punishment for failure to do it, and offered something concrete to grade. But the quiz was not the actual objective. The actual object was the studying. It was often the case that a student did in fact put in the time studying but this work was not reflected on the quiz.

I would like go straight to the root, and make the act of studying the event to be graded, rewarding students specifically for doing what I asked, rather than using a stressful, time-consuming quiz, and in the process making it possible for any student to ensure good grades for daily work simply by doing the work, and also freeing up time in class and my own time. Also, I would like their "studying" to be based on correct information, so they don't spend a lot of time studying something in a state of confusion or mistaken understanding.

## Types of Activities

- Vocabulary practice: Generated "flashcards" with instant grading and feedback, testing both passive knowledge (English to Greek) and active knowledge (Greek to English). There are many online flashcard applications, but none of them do what I want to do. ** This will be the first step, described below, to work on right now.**
- Greek typing practice: The above will be a matter of pointing and clicking, and students can start on practicing vocabulary immediately. But I want them to be able to type polytonic Greek on their computers (Windows or MacOS) fluently. I would like some concise tutorials on getting started typing Greek, specific to the two major operating systems, and some automatically graded exercises that will give them practice in typing Greek. The trick here is to make something that actually forces them to type, rather than to copy-and-paste from other sources. This will be the second task, for another day.
- Morphology practice: Identifying the forms of Greek words: nouns, pronouns, articles, adjectives, verbs (in all their complexity). This will be the third step, for another day.
- Sentence analysis. I would like some way (and I will need your help), to give students credit for reading and analyzing Greek sentences that they can do efficiently, and that can be graded objectively, automatically, and with helpful feedback. We will read them and talk about them in class, but I want them to be motivated to engage sentences beforehand, on their own. Clearly, asking them to translate a Greek sentence will not work: There are to many ways to translate a given sentence, and the temptation would be for them just to drop it into an AI agent. So this will require some thought. This will be the last thing we work on.

## Tools & Technologies

My University uses Moodle, which offers the excellent and flexible `.gift` format for creating quizzes in plain-text. This should be the basis for many parts of the current project, but probably not all of them: <https://docs.moodle.org/502/en/GIFT_format>.

I made a first attempt at a vocabulary-drill-generator, testing passive knowledge only, which I have used successfully last academic year: <https://github.com/Eumaeus/Gifter.jl/>.

This project, <https://github.com/Eumaeus/Dramaturg.jl>, includes well-tested Julia code for tokenizing texts, which will be useful when working with senteces. It also includes libraries for generating and parsing Perseus-style "Part-of-Speech Tags" and generating human-readable descriptions from them.

This project <https://github.com/Eumaeus/MorphologyDocumenter> offers Javascript code for a user-interface to generate a POS-tag from a Greek word form. This may be useful functionality.

## The First Task

I would like to start from scratch with a "vocabulary-drill generator." 

The heart of this might be a Julia "Gift.jl" library. I couldn't find one on juliapackages.com, so maybe we can make one. Maybe it is not necessary, since `.gift` is such a straightforward plain-text format.

I have vocabulary from the first nine chapters of the textbook entered into this file: `data/vocabulary/hq.txt`.

### Desiderata for a Quiz Generator

I am pretty happy with the output from the old code that I wrote by myself, although it produces only passive-knowledge quizzes. These are in `sample_output` in the repository.

- A config-file should let me set the data-source (for starters, `data/vocabulary/hq.txt`), and which chapter we are currently working on.
- The config should control how many items for the quiz/practice. Since this is both "quiz" and "practice" the number might be large… 50-150.
- The config should control the proportion of active-knowledge questions to passive-knowledge questions, with the default being 50/50.
- A quiz should both drill items in the current chapter and some from previous chapters, for review. I should have control over this via a config.toml.
- Each question should be multiple choice—the number of choices can be set in a config, with 5 being the default—and will present either a Greek form or an English translation.
- Items for the quiz should be chosen at random from the valid pool of items (the current chapter and previous chapters, but not subsequent chapters). This is subject to the requirement that the current chapter's vocabulary appears in proportion to "review questions" (from previous chapters) according to the value set in the config.
- Every vocabulary item for the current chapter should appear in the quiz before any appear twice. As for the definition of "vocabulary item", see below…
- In the data, English translations are separated by semicolons. Each of those should be treated as a separate vocabulary item for a quiz.
- Give the above, there may be more than one correct answer among the multiple choices.
- For verbs, in the Greek, all of the principal parts are given, separated by semi-colons. These should be treated as separate items for quiz questions. The answers should take into account the principal part: "Principal Part 1 of λύω", etc.
- The "wrong answers" can be drawn from any items in the valid pool. They should, if possible, be taken from words in the same category ("prep", "noun", etc.). For early chapters, when there are not many words in the pool, this may not be possible.
- It is possible that in an active-knowledge quiz, more than one Greek word in the vocabulary will have the same translation among its possible translations. So there may be more than one correct answer.
- In cases where there are more than one correct answer for a given item, all correct answers must be chosen to get full credit. There are examples of this in `sample_output`.
- For wrong answers, in the `.gift` file, there should be feedback, giving the correct information for the word offered as a wrong answer. 
- We can use Markdown in both questions and feedback, for basic formatting.
- Each produced `.gift` file should have a header putting it in a useful category, since these will all go into a "Question Bank" in Moodle. We can fine-tune those categories as we go along. It is easier to generate a quiz in Moodle by selecting all of the questions in a named Question Bank than trying to select a sub-set, so there will end up being a lot of Question Banks.
- I will upload these to Moodle, generated quiz-assignments in Moodle, and set them to "Adaptive Mode (No Penalties)", which lets students answer questions, getting feedback, until they get it right. So this is their practice, but at the end they should be able to get 100% every time.

So I'd like to get started with this, beginning with setting up a solid directory structure for this aspect of the project, with an eye toward cleanly adding other modules in the future.

Thanks, in advance, for your advice!