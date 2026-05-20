@testset "self apply policy" begin
    root = pkgdir(JuliaLangProjectHarness)

    profile = assert_julia_project_harness_test_profile_clean(root)
    report = profile.report

    @test JuliaLangProjectHarness.is_clean(report)
    @test isempty(JuliaLangProjectHarness.advisory_findings(report))
    @test !isempty(profile.task_index.records)
    @test render_julia_project_harness(report) == "[ok] julia\n"
end
