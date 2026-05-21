const JULIA_PACKAGE_SEARCH_DOC_ENTRY_CANDIDATES = ["make.jl"]
const JULIA_PACKAGE_SEARCH_EXAMPLE_ENTRY_CANDIDATES = [
    "runexamples.jl",
    "runtests.jl",
    "examples.jl",
]
const JULIA_PACKAGE_SEARCH_BENCHMARK_ENTRY_CANDIDATES = [
    ("benchmark", ["runbenchmarks.jl", "benchmarks.jl", "runtests.jl"]),
    ("benchmarks", ["runbenchmarks.jl", "benchmarks.jl", "runtests.jl"]),
    ("perf", ["runtests.jl", "runbenchmarks.jl", "benchmarks.jl"]),
    (joinpath("test", "perf"), ["runtests.jl", "runbenchmarks.jl", "benchmarks.jl"]),
]

function scope_search_paths(scope::JuliaProjectHarnessScope)
    selected = vcat(scope_monitored_paths(scope), scope.package_paths)
    isempty(selected) ? [scope.project_root] : unique_paths(selected)
end

function pkg_package_paths(project_root::AbstractString)
    root = abspath(String(project_root))
    paths = String[]
    add_pkg_auxiliary_path!(
        paths,
        root,
        "docs",
        JULIA_PACKAGE_SEARCH_DOC_ENTRY_CANDIDATES;
        require_project=true,
    )
    add_pkg_auxiliary_path!(
        paths,
        root,
        "examples",
        JULIA_PACKAGE_SEARCH_EXAMPLE_ENTRY_CANDIDATES;
        require_project=true,
    )
    for (relative_root, entry_names) in JULIA_PACKAGE_SEARCH_BENCHMARK_ENTRY_CANDIDATES
        add_pkg_auxiliary_path!(
            paths,
            root,
            relative_root,
            entry_names;
            require_project=false,
        )
    end
    unique_paths(paths)
end

function add_pkg_auxiliary_path!(
    paths::Vector{String},
    project_root::AbstractString,
    relative_root::AbstractString,
    entry_names::Vector{String};
    require_project::Bool,
)
    auxiliary_root = joinpath(project_root, relative_root)
    isdir(auxiliary_root) || return paths
    if require_project
        isfile(joinpath(auxiliary_root, "Project.toml")) || return paths
    end
    any(entry_name -> isfile(joinpath(auxiliary_root, entry_name)), entry_names) ||
        return paths
    add_existing_path!(paths, auxiliary_root)
end

function unique_paths(paths::Vector{String})
    sort!(unique(normpath.(paths)))
end
