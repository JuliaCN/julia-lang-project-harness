using JuliaLangProjectHarness
using Test

@testset "JuliaLangProjectHarness" begin
    include("unit/self_policy.jl")
    include("unit/parser.jl")
    include("unit/runner.jl")
    include("unit/project.jl")
    include("unit/search_index.jl")
    include("unit/agent_snapshot.jl")
    include("unit/render.jl")
    include("unit/rule_catalog.jl")
end
