# src/MorphDrill/MorphDrill.jl

module MorphDrill

include("DataParser.jl")
include("ItemSelector.jl")
include("QuestionBuilder.jl")
include("QuizBuilder.jl")

using .DataParser: MorphForm, parse_morphology_forms
using .ItemSelector: select_morph_forms
using .QuestionBuilder: Question, build_question, to_gift
using .QuizBuilder: MorphDrillConfig, load_config, build_morph_drill, write_gift_file

export MorphForm, parse_morphology_forms, select_morph_forms,
       Question, build_question, to_gift,
       MorphDrillConfig, load_config, build_morph_drill, write_gift_file

end # module MorphDrill