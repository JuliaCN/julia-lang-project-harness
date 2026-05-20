using JuliaLangProjectHarness: parse_julia_file

@testset "parser" begin
    temp = mktempdir()
    source = joinpath(temp, "valid.jl")
    write(source, "module Valid\nexport run\nrun() = 1\nend\n")

    parsed = parse_julia_file(source)

    @test parsed.report.is_valid
    @test isnothing(parsed.report.parse_error)
    @test parsed.syntax_facts.has_syntax_tree
end
