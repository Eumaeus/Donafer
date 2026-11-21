module VocabDrill

include("DataParser.jl")
include("ItemSelector.jl")
include("QuestionBuilder.jl")
include("QuizBuilder.jl")

using .DataParser: parse_vocabulary_file, VocabItem, RawVocabEntry,
                   is_numbered_english_field, parse_english_field,
                   is_case_tagged_english_field, normalize_case_token,
                   parse_prep_greek_field, case_label
using .ItemSelector: select_quiz_items, SelectionResult
using .QuestionBuilder: Question, build_question, to_gift, ordinal_label,
                        principal_parts_for_lemma, form_similarity, select_pp_form_distractors,
                        PRINCIPAL_PART_GLOSSES, principal_part_gloss, build_pp_meaning_question,
                        PRINCIPAL_PART_PARADIGMS, ALL_PARADIGM_LABELS, paradigms_for_pp,
                        pp_for_paradigm, build_pp_forms_question,
                        english_glosses_for_pp, select_pp_english_distractors,
                        prep_case_display, english_glosses_for_prep_case,
                        select_prep_case_english_distractors, select_prep_case_form_distractors,
                        build_prep_case_question
using .QuizBuilder: DrillConfig, load_config, build_vocab_drill, write_gift_file,
                    pp_meaning_question_count, pp_forms_question_count, prep_case_question_count

export 
    # Core types & low-level functions
    VocabItem, parse_vocabulary_file,
    is_numbered_english_field, parse_english_field,
    is_case_tagged_english_field, normalize_case_token,
    parse_prep_greek_field, case_label,
    select_quiz_items, SelectionResult,
    Question, build_question, to_gift,
    ordinal_label, principal_parts_for_lemma,
    form_similarity, select_pp_form_distractors,
    PRINCIPAL_PART_GLOSSES, principal_part_gloss, build_pp_meaning_question,
    PRINCIPAL_PART_PARADIGMS, ALL_PARADIGM_LABELS, paradigms_for_pp,
    pp_for_paradigm, build_pp_forms_question,
    english_glosses_for_pp, select_pp_english_distractors,
    prep_case_display, english_glosses_for_prep_case,
    select_prep_case_english_distractors, select_prep_case_form_distractors,
    build_prep_case_question,

    # High-level quiz builder
    DrillConfig, load_config, build_vocab_drill, write_gift_file,
    pp_meaning_question_count, pp_forms_question_count, prep_case_question_count

end # module VocabDrill
