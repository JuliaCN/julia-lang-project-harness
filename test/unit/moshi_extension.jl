@testset "Moshi extension is inactive until Moshi loads" begin
    @test isempty(moshi_extension_capabilities())
    @test isnothing(Base.get_extension(JuliaLangProjectHarness, :JuliaLangProjectHarnessMoshiExt))
end

@eval using Moshi

@testset "Moshi extension activates through package weakdep" begin
    @test !isnothing(Base.get_extension(JuliaLangProjectHarness, :JuliaLangProjectHarnessMoshiExt))
    capabilities = moshi_extension_capabilities()

    @test "syntax: native JuliaSyntax facts for Moshi @data/@match/@derive" in capabilities
    @test "domain-model: typed domain carriers for stringly branch dispatch behind weakdeps/extensions" in capabilities
    @test "search: agent search and snapshots for Moshi modeling forms" in capabilities
end

@testset "Moshi extension capability names stay compact for agent surfaces" begin
    @test JuliaLangProjectHarness.moshi_extension_capability_names() ==
          ["syntax", "domain-model", "search"]
end
