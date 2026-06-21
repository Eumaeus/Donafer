module VocabDrill

# 1. Include submodules
include("DataParser.jl")
include("ItemSelector.jl")

# 2. Bring names from submodules into VocabDrill's namespace
using .DataParser: parse_vocabulary_file, VocabItem, RawVocabEntry
using .ItemSelector: select_quiz_items, SelectionResult

# 3. Re-export the public API
export 
    VocabItem,
    parse_vocabulary_file,
    select_quiz_items,
    SelectionResult

end # module VocabDrill