@testset "runner" begin
    temp = mktempdir()
    source = joinpath(temp, "valid.jl")
    write(source, "value() = 1\n")

    report = run_julia_lang_harness([source])

    @test JuliaLangProjectHarness.file_count(report) == 1
    @test JuliaLangProjectHarness.parsed_count(report) == 1
    @test JuliaLangProjectHarness.is_clean(report)
    @test isnothing(report.project_scope)
    @test render_julia_project_harness(report) == "[ok] julia\n"
end

@testset "runner reports syntax errors" begin
    temp = mktempdir()
    source = joinpath(temp, "invalid.jl")
    write(source, "function broken(\n")

    report = run_julia_lang_harness([source])
    rendered = render_julia_project_harness(report)

    @test JuliaLangProjectHarness.file_count(report) == 1
    @test JuliaLangProjectHarness.parsed_count(report) == 0
    @test !JuliaLangProjectHarness.is_clean(report)
    @test occursin("JULIA-SYN-R001", rendered)
    @test occursin("Julia source does not parse", rendered)
    @test occursin("Contract:", rendered)
end

@testset "runner rejects missing roots" begin
    missing = joinpath(mktempdir(), "missing")

    @test_throws ErrorException run_julia_lang_harness([missing])
    @test_throws ErrorException run_julia_project_harness(missing)
end
