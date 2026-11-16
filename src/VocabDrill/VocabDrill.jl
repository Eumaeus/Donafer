module VocabDrill

include("DataParser.jl")
include("ItemSelector.jl")
include("QuestionBuilder.jl")
include("QuizBuilder.jl")

using .DataParser: parse_vocabulary_file, VocabItem, RawVocabEntry
using .ItemSelector: select_quiz_items, SelectionResult
using .QuestionBuilder: Question, build_question, to_gift, ordinal_label,
                        principal_parts_for_lemma, form_similarity, select_pp_form_distractors
using .QuizBuilder: DrillConfig, load_config, build_vocab_drill, write_gift_file

export 
    # Core types & low-level functions
    VocabItem, parse_vocabulary_file,
    select_quiz_items, SelectionResult,
    Question, build_question, to_gift,
    ordinal_label, principal_parts_for_lemma,
    form_similarity, select_pp_form_distractors,

    # High-level quiz builder
    DrillConfig, load_config, build_vocab_drill, write_gift_file

end # module VocabDrill
