@testset "self apply policy" begin
    root = pkgdir(JuliaLangProjectHarness)

    report = assert_julia_project_harness_pkg_test_clean(root)

    @test JuliaLangProjectHarness.is_clean(report)
    @test isempty(JuliaLangProjectHarness.advisory_findings(report))
    @test render_julia_project_harness(report) == "[ok] julia\n"
end
