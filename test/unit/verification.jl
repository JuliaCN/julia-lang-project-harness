function write_verification_project(root::AbstractString)
    write(
        joinpath(root, "Project.toml"),
        """
        name = "VerifyExample"
        uuid = "11111111-1111-1111-1111-111111111111"
        version = "0.1.0"

        [deps]
        JuliaLangProjectHarness = "67259778-f152-405a-bc38-ee6219bce977"

        [weakdeps]
        JSON3 = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"

        [extensions]
        VerifyJSONExt = ["JSON3"]

        [compat]
        JSON3 = "1"
        JuliaLangProjectHarness = "0.1"

        [extras]
        Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

        [targets]
        test = ["Test"]
        """,
    )
    mkpath(joinpath(root, "src"))
    mkpath(joinpath(root, "test"))
    mkpath(joinpath(root, "ext"))
    write(
        joinpath(root, "src", "VerifyExample.jl"),
        """
        module VerifyExample
        export run
        \"\"\"Run the verification fixture value.\"\"\"
        run(value) = value
        end
        """,
    )
    write(
        joinpath(root, "test", "runtests.jl"),
        """
        using JuliaLangProjectHarness
        using Test

        @test true
        assert_julia_project_harness_test_profile_clean(dirname(@__DIR__))
        """,
    )
    write(joinpath(root, "ext", "VerifyJSONExt.jl"), "module VerifyJSONExt\nend\n")
end

@testset "verification task index" begin
    root = mktempdir()
    write_verification_project(root)

    index = build_julia_verification_task_index(root)
    kinds = [record.kind for record in index.records]

    @test index.project_root == root
    @test kinds == ["extension_boundary", "harness_policy", "pkg_test", "syntax_search"]
    @test all(record -> record.state == "pending", index.records)
    @test any(record -> occursin("Pkg.test()", join(record.command, " ")), index.records)
    @test any(
        record -> record.kind == "harness_policy" &&
                  occursin(
                      "assert_julia_project_harness_test_profile_clean",
                      join(record.command, " "),
                  ),
        index.records,
    )
    @test any(
        record -> record.kind == "extension_boundary" &&
                  record.evidence["extension"] == "VerifyJSONExt",
        index.records,
    )

    rendered = render_julia_verification_task_index(index)
    json = render_julia_verification_task_index_json(index)

    @test occursin("VerificationTasks: count=4", rendered)
    @test occursin("owner=test/runtests.jl", rendered)
    @test occursin("\"records\"", json)
    @test occursin("VerifyJSONExt", json)

    profile = assert_julia_project_harness_test_profile_clean(root)
    @test profile.report.project_scope.project_root == root
    @test [record.kind for record in profile.task_index.records] == kinds
    @test length(profile.profile_index.candidates) == 3

    profile_rendered = render_julia_verification_profile(profile)
    profile_json = render_julia_verification_profile_json(profile)

    @test occursin("VerificationProfiles: count=3", profile_rendered)
    @test occursin("responsibilities=test_profile_gate", profile_rendered)
    @test occursin("responsibilities=public_api", profile_rendered)
    @test occursin("responsibilities=extension_boundary", profile_rendered)
    @test occursin("\"profile_index\"", profile_json)
    @test occursin("extension_boundary", profile_json)
end
