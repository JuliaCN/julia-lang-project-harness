@testset "project runner reports public failure contract advice" begin
    root = mktempdir()
    write_project(root, "Example")
    mkpath(joinpath(root, "src"))
    write(
        joinpath(root, "src", "Example.jl"),
        """
        module Example
        export parse_payload
        \"\"\"Parse the payload text.\"\"\"
        function parse_payload(text)
            isempty(text) && error("empty payload")
            text
        end
        end
        """,
    )

    report = run_julia_project_harness(root)
    rendered = render_julia_project_harness(report)

    @test JuliaLangProjectHarness.is_clean(report)
    @test occursin("AGENT-JL-R026", rendered)
    @test occursin("Public failure path lacks a contract", rendered)
    @test occursin("failure paths without a failure contract: error", rendered)
    @test length(JuliaLangProjectHarness.advisory_findings(report)) == 1
end

@testset "project runner reports public assertion contract advice" begin
    root = mktempdir()
    write_project(root, "Example")
    mkpath(joinpath(root, "src"))
    write(
        joinpath(root, "src", "Example.jl"),
        """
        module Example
        export normalize
        \"\"\"Normalize a positive value.\"\"\"
        function normalize(value)
            @assert value > 0
            value
        end
        end
        """,
    )

    report = run_julia_project_harness(root)
    rendered = render_julia_project_harness(report)

    @test JuliaLangProjectHarness.is_clean(report)
    @test occursin("AGENT-JL-R026", rendered)
    @test occursin("failure paths without a failure contract: @assert", rendered)
    @test length(JuliaLangProjectHarness.advisory_findings(report)) == 1
end

@testset "project runner accepts documented public failure contract" begin
    root = mktempdir()
    write_project(root, "Example")
    mkpath(joinpath(root, "src"))
    write(
        joinpath(root, "src", "Example.jl"),
        """
        module Example
        export parse_payload
        \"\"\"Parse the payload text.

        Throws `ArgumentError` when the payload is empty.
        \"\"\"
        function parse_payload(text)
            isempty(text) && throw(ArgumentError("empty payload"))
            text
        end
        end
        """,
    )

    report = run_julia_project_harness(root)

    @test JuliaLangProjectHarness.is_clean(report)
    @test isempty(JuliaLangProjectHarness.advisory_findings(report))
end
