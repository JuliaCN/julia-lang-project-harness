"""Return compact capability lines from the optional Moshi package extension."""
function moshi_extension_capabilities()
    extension_module = Base.get_extension(@__MODULE__, :JuliaLangProjectHarnessMoshiExt)
    isnothing(extension_module) && return String[]
    extension_module.moshi_extension_capability_lines()
end
