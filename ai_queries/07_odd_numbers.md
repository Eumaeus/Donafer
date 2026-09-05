You are helping me with this project: <https://github.com/Eumaeus/Donafer>.

Our last conversation was at: <https://x.com/i/grok/share/e2ab3381db504e0fa20e5d9dc3419397>

I need a little help with some lingering bugs in the code that generates morphology drills.

I am generating drills for Chapter 1, using:

- The config file at `config/morph_drill.toml`
- The script at `scripts/generate_morph_drill.jl`
- The code in `src` invoked by the script
- I'm launching with the command: `julia --project=. scripts/generate_morph_drill.jl -c 1 -q 50`

Let's look at the the output file, checked into GitHub at:

`generated/morph/morph_drill_hq_ch1.gift`

There are a few things things. 

1. In the `morph_drill.toml`, I specify "number_choices = 5".

But in the output, some questions do not have 5 choices. `Q003`, for example, has one correct answer and only two distracters.

2. Second, Question `Q007` in the quiz has two correct answers. That's great! But when this occurs, I would like to force the student to see and mark both of them. So each should award 50% credit.

Should it happen that there are three correct answers—not impossible—Moodle insists on three decimal places for the irrational percentage: ~%33.333%.

3. In the `.toml` there is a comment referring to "intro_mode". I think that is out-of-date, replaced by the richer "distracter_mode". If you can confirm that this is the case, I'll remove that confusing comment.

Thank you!

Conversation at: <https://x.com/i/grok/share/45383f17261142f6be50718964db538b>

Thanks! This looks terrific. I really appreciate both the code and the very clear explanation.

I'll test it out and come back if I have more questions.