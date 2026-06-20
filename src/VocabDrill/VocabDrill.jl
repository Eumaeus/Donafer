module VocabDrill

# Include the sub-modules in the correct order
include("DataParser.jl")
include("ItemSelector.jl")

# Re-export the most important names so users can do `using .VocabDrill`
export 
    VocabItem,
    parse_vocabulary_file,
    select_quiz_items,
    SelectionResult

end # module VocabDrill