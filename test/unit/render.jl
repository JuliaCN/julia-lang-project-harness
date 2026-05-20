@testset "json render" begin
    temp = mktempdir()
    source = joinpath(temp, "valid.jl")
    write(source, "value() = 1\n")

    report = run_julia_lang_harness([source])
    json = render_julia_project_harness_json(report)

    @test occursin("\"files\"", json)
    @test occursin("\"findings\"", json)
    @test occursin("\"blocking_severities\"", json)
end
