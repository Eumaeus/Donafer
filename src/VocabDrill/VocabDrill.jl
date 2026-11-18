module VocabDrill

include("DataParser.jl")
include("ItemSelector.jl")
include("QuestionBuilder.jl")
include("QuizBuilder.jl")

using .DataParser: parse_vocabulary_file, VocabItem, RawVocabEntry,
                   is_numbered_english_field, parse_english_field
using .ItemSelector: select_quiz_items, SelectionResult
using .QuestionBuilder: Question, build_question, to_gift, ordinal_label,
                        principal_parts_for_lemma, form_similarity, select_pp_form_distractors,
                        PRINCIPAL_PART_GLOSSES, principal_part_gloss, build_pp_meaning_question,
                        PRINCIPAL_PART_PARADIGMS, ALL_PARADIGM_LABELS, paradigms_for_pp,
                        pp_for_paradigm, build_pp_forms_question,
                        english_glosses_for_pp, select_pp_english_distractors
using .QuizBuilder: DrillConfig, load_config, build_vocab_drill, write_gift_file,
                    pp_meaning_question_count, pp_forms_question_count

export 
    # Core types & low-level functions
    VocabItem, parse_vocabulary_file,
    is_numbered_english_field, parse_english_field,
    select_quiz_items, SelectionResult,
    Question, build_question, to_gift,
    ordinal_label, principal_parts_for_lemma,
    form_similarity, select_pp_form_distractors,
    PRINCIPAL_PART_GLOSSES, principal_part_gloss, build_pp_meaning_question,
    PRINCIPAL_PART_PARADIGMS, ALL_PARADIGM_LABELS, paradigms_for_pp,
    pp_for_paradigm, build_pp_forms_question,
    english_glosses_for_pp, select_pp_english_distractors,

    # High-level quiz builder
    DrillConfig, load_config, build_vocab_drill, write_gift_file,
    pp_meaning_question_count, pp_forms_question_count

end # module VocabDrill
