function write_cli_project(root::AbstractString)
    write(
        joinpath(root, "Project.toml"),
        """
        name = "CliExample"
        uuid = "11111111-1111-1111-1111-111111111111"
        version = "0.1.0"
        """,
    )
    mkpath(joinpath(root, "src"))
    write(
        joinpath(root, "src", "CliExample.jl"),
        """
        module CliExample
        export run
        \"\"\"Run a value through the CLI fixture.\"\"\"
        run(value) = helper(value)
        helper(value) = string(value)
        end
        """,
    )
end

@testset "cli compact report" begin
    root = mktempdir()
    write_cli_project(root)
    out = IOBuffer()
    err = IOBuffer()

    status = run_julia_project_harness_cli([root]; out, err)

    @test status == 0
    @test String(take!(out)) == "[ok] julia\n"
    @test isempty(String(take!(err)))
end

@testset "cli json and snapshot output" begin
    root = mktempdir()
    write_cli_project(root)
    json_out = IOBuffer()
    snapshot_out = IOBuffer()

    json_status = run_julia_project_harness_cli(["--json", root]; out=json_out)
    snapshot_status = run_julia_project_harness_cli(["--agent-snapshot", root]; out=snapshot_out)

    @test json_status == 0
    @test occursin("\"files\"", String(take!(json_out)))
    @test snapshot_status == 0
    @test occursin("Package: CliExample", String(take!(snapshot_out)))
end

@testset "cli search output" begin
    root = mktempdir()
    write_cli_project(root)
    out = IOBuffer()

    status = run_julia_project_harness_cli(
        ["--search", "CLI fixture", "--tag", "doc", "--limit", "2", root];
        out,
    )
    rendered = String(take!(out))

    @test status == 0
    @test occursin("SearchResults: count=1", rendered)
    @test occursin("kind=doc name=run", rendered)
    @test occursin("src/CliExample.jl", rendered)
end

@testset "cli rejects conflicting modes" begin
    root = mktempdir()
    write_cli_project(root)
    out = IOBuffer()
    err = IOBuffer()

    status = run_julia_project_harness_cli(["--json", "--agent-snapshot", root]; out, err)

    @test status == 2
    @test isempty(String(take!(out)))
    @test occursin("expected only one output mode", String(take!(err)))
end
