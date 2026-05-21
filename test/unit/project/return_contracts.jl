@testset "project runner reports public return annotation contract advice" begin
    root = mktempdir()
    write_project(root, "Example")
    mkpath(joinpath(root, "src"))
    write(
        joinpath(root, "src", "Example.jl"),
        """
        module Example
        export encode
        \"\"\"Encode the public payload for wire transport.\"\"\"
        encode(payload)::String = string(payload)
        end
        """,
    )

    report = run_julia_project_harness(root)
    rendered = render_julia_project_harness(report)

    @test JuliaLangProjectHarness.is_clean(report)
    @test occursin("AGENT-JL-R023", rendered)
    @test occursin("Public return annotation lacks a contract", rendered)
    @test occursin("concrete return annotation `::String`", rendered)
    @test length(JuliaLangProjectHarness.advisory_findings(report)) == 1
end

@testset "project runner accepts documented public return annotation contract" begin
    root = mktempdir()
    write_project(root, "Example")
    mkpath(joinpath(root, "src"))
    write(
        joinpath(root, "src", "Example.jl"),
        """
        module Example
        export encode
        \"\"\"Return contract: returns a String payload for the wire format.\"\"\"
        encode(payload)::String = string(payload)
        end
        """,
    )

    report = run_julia_project_harness(root)

    @test JuliaLangProjectHarness.is_clean(report)
    @test isempty(JuliaLangProjectHarness.advisory_findings(report))
end

@testset "project runner accepts generic type parameter return annotations" begin
    root = mktempdir()
    write_project(root, "Example")
    mkpath(joinpath(root, "src"))
    write(
        joinpath(root, "src", "Example.jl"),
        """
        module Example
        export passthrough
        \"\"\"Return the value without changing its concrete type.\"\"\"
        passthrough(value::T)::T where {T} = value
        end
        """,
    )

    report = run_julia_project_harness(root)
    rendered = render_julia_project_harness(report)

    @test JuliaLangProjectHarness.is_clean(report)
    @test !occursin("AGENT-JL-R023", rendered)
end
