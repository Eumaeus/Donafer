module VocabDrill

include("DataParser.jl")
include("ItemSelector.jl")
include("QuestionBuilder.jl")

using .DataParser: parse_vocabulary_file, VocabItem, RawVocabEntry
using .ItemSelector: select_quiz_items, SelectionResult
using .QuestionBuilder: Question, build_question, to_gift

export 
    VocabItem, parse_vocabulary_file,
    select_quiz_items, SelectionResult,
    Question, build_question, to_gift

end # module VocabDrill