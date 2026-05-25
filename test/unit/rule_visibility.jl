@testset "rule visibility API exposes accepted AST shapes" begin
    r027 = julia_rule_visibility("AGENT-JL-R027")
    @test r027 isa JuliaRuleVisibility
    @test any(occursin("@test_throws ExceptionType public_function", shape) for shape in r027.accepted_ast_shapes)
    @test any(occursin("helper", shape) for shape in r027.rejected_ast_shapes)
    @test any(occursin("parse_payload", example) for example in r027.minimal_examples)

    rendered = render_julia_rule_visibility("AGENT-JL-R027")
    @test occursin("Accepted AST shapes", rendered)
    @test occursin("@test_throws", rendered)
    @test occursin("Rejected AST shapes", rendered)

    @test isnothing(julia_rule_visibility("UNKNOWN-RULE"))
    @test render_julia_rule_visibility("UNKNOWN-RULE") == ""
end

@testset "finding render includes compact rule visibility" begin
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

    rendered = render_julia_project_harness(run_julia_project_harness(root))

    @test occursin("Accepted AST:", rendered)
    @test occursin("@test_throws ExceptionType public_function", rendered)
    @test occursin("Detected covered methods: none", rendered)
end
