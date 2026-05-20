using TOML

function run_julia_lang_harness(paths::Vector{<:AbstractString}; config=default_julia_harness_config())
    for path in paths
        ispath(path) || error("harness path does not exist: $(path)")
    end
    run_paths(abspath.(String.(paths)), config)
end

function run_julia_project_harness(project_root::AbstractString; config=default_julia_harness_config())
    isdir(project_root) || error("project root does not exist: $(project_root)")
    scope = julia_project_harness_scope(project_root, config)
    run_paths(scope_monitored_paths(scope), config; scope)
end

function assert_julia_lang_harness_clean(paths::Vector{<:AbstractString}; config=default_julia_harness_config())
    report = run_julia_lang_harness(paths; config)
    assert_clean(report)
end

function assert_julia_project_harness_clean(project_root::AbstractString; config=default_julia_harness_config())
    report = run_julia_project_harness(project_root; config)
    assert_clean(report)
end

function run_paths(paths::Vector{String}, config::JuliaHarnessConfig; scope=nothing)
    parsed_files = [parse_julia_file(path) for path in discover_julia_files(paths, config)]
    findings = evaluate_default_rule_packs(scope, parsed_files, config)
    JuliaHarnessReport(
        [parsed.report for parsed in parsed_files],
        findings,
        paths,
        copy(config.blocking_severities),
        scope,
        JuliaProjectHarnessScope[],
    )
end

function julia_project_harness_scope(project_root::AbstractString, config::JuliaHarnessConfig)
    root = abspath(String(project_root))
    project_facts = parse_project_toml_facts(root)
    source_paths = existing_configured_paths(project_root, config.source_dir_names)
    test_paths = config.include_tests ? existing_configured_paths(project_root, config.test_dir_names) :
                 String[]
    JuliaProjectHarnessScope(
        root,
        project_facts.path,
        project_facts.package_name,
        package_entry_path(root, project_facts.package_name),
        source_paths,
        test_paths,
        String[],
        String[],
    )
end

function scope_monitored_paths(scope::JuliaProjectHarnessScope)
    selected = vcat(scope.source_paths, scope.test_paths)
    isempty(selected) ? [scope.project_root] : selected
end

function existing_configured_paths(project_root::AbstractString, path_names::Vector{String})
    root = abspath(String(project_root))
    [joinpath(root, path_name) for path_name in path_names if ispath(joinpath(root, path_name))]
end

struct JuliaProjectTomlFacts
    path::Union{Nothing,String}
    package_name::Union{Nothing,String}
end

function parse_project_toml_facts(project_root::AbstractString)
    path = joinpath(project_root, "Project.toml")
    isfile(path) || return JuliaProjectTomlFacts(path, nothing)
    parsed = try
        TOML.parsefile(path)
    catch
        return JuliaProjectTomlFacts(path, nothing)
    end
    package_name = get(parsed, "name", nothing)
    JuliaProjectTomlFacts(path, package_name isa AbstractString ? String(package_name) : nothing)
end

function package_entry_path(project_root::AbstractString, package_name::Union{Nothing,String})
    isnothing(package_name) && return nothing
    path = joinpath(project_root, "src", "$(package_name).jl")
    isfile(path) ? path : nothing
end

function discover_julia_files(paths::Vector{String}, config::JuliaHarnessConfig)
    files = Set{String}()
    for path in paths
        discover_julia_path!(files, path, config.ignored_dir_names)
    end
    sort!(collect(files))
end

function discover_julia_path!(files::Set{String}, path::AbstractString, ignored_dir_names::Set{String})
    should_ignore_path(path, ignored_dir_names) && return
    if isfile(path)
        endswith(lowercase(path), ".jl") && push!(files, String(path))
        return
    end
    isdir(path) || return
    for entry in readdir(path; join=true)
        discover_julia_path!(files, entry, ignored_dir_names)
    end
end

function should_ignore_path(path::AbstractString, ignored_dir_names::Set{String})
    name = basename(path)
    name in ignored_dir_names
end
