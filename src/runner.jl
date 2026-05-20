using Pkg

function run_julia_lang_harness(paths::Vector{<:AbstractString}; config=default_julia_harness_config())
    for path in paths
        ispath(path) || error("harness path does not exist: $(path)")
    end
    run_paths(abspath.(String.(paths)), config)
end

function run_julia_project_harness(project_root::AbstractString; config=default_julia_harness_config())
    ispath(project_root) || error("project path does not exist: $(project_root)")
    scope = julia_project_harness_scope(project_root, config)
    workspace_member_scopes = julia_workspace_member_scopes(scope, config)
    monitored_paths = vcat(scope_monitored_paths(scope), mapreduce(scope_monitored_paths, vcat, workspace_member_scopes; init=String[]))
    run_paths(monitored_paths, config; scope, workspace_member_scopes)
end

function assert_julia_lang_harness_clean(paths::Vector{<:AbstractString}; config=default_julia_harness_config())
    report = run_julia_lang_harness(paths; config)
    assert_clean(report)
end

function assert_julia_project_harness_clean(project_root::AbstractString; config=default_julia_harness_config())
    report = run_julia_project_harness(project_root; config)
    assert_clean(report)
end

function assert_julia_project_harness_pkg_test_clean(
    project_root::AbstractString;
    config=default_julia_harness_config(),
)
    report = run_julia_project_harness(project_root; config)
    assert_clean(report)
    if isempty(something(config.agent_advice_allow_explanation, ""))
        assert_no_advisory_findings(report)
    end
    report
end

function run_paths(
    paths::Vector{String},
    config::JuliaHarnessConfig;
    scope=nothing,
    workspace_member_scopes=JuliaProjectHarnessScope[],
)
    parsed_files = [parse_julia_file(path) for path in discover_julia_files(paths, config)]
    findings = evaluate_default_rule_packs(
        scope,
        parsed_files,
        config;
        workspace_member_scopes=workspace_member_scopes,
    )
    JuliaHarnessReport(
        [parsed.report for parsed in parsed_files],
        findings,
        paths,
        copy(config.blocking_severities),
        scope,
        workspace_member_scopes,
    )
end

function julia_project_harness_scope(project_root::AbstractString, config::JuliaHarnessConfig)
    project_facts = parse_project_toml_facts(project_root)
    root = project_facts.project_root
    source_paths = existing_configured_paths(root, config.source_dir_names)
    test_paths = config.include_tests ? existing_configured_paths(root, config.test_dir_names) :
                 String[]
    JuliaProjectHarnessScope(
        root,
        project_facts.path,
        project_facts.package_name,
        project_facts.package_uuid,
        project_facts.entryfile,
        package_entry_path(root, project_facts.package_name, project_facts.entryfile),
        project_facts.direct_dependencies,
        project_facts.weak_dependencies,
        project_facts.extra_dependencies,
        project_facts.targets,
        project_facts.compat,
        project_facts.sources,
        project_facts.workspace_projects,
        source_paths,
        test_paths,
        String[],
        String[],
    )
end

function julia_workspace_member_scopes(
    scope::JuliaProjectHarnessScope,
    config::JuliaHarnessConfig,
)
    scopes = JuliaProjectHarnessScope[]
    seen_roots = Set([scope.project_root])
    for project_path in scope.workspace_projects
        member_root = isabspath(project_path) ? normpath(project_path) :
                      normpath(joinpath(scope.project_root, project_path))
        isdir(member_root) || continue
        member_scope = julia_project_harness_scope(member_root, config)
        member_scope.project_root in seen_roots && continue
        push!(seen_roots, member_scope.project_root)
        push!(scopes, member_scope)
    end
    scopes
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
    project_root::String
    path::Union{Nothing,String}
    package_name::Union{Nothing,String}
    package_uuid::Union{Nothing,String}
    entryfile::Union{Nothing,String}
    direct_dependencies::Dict{String,String}
    weak_dependencies::Dict{String,String}
    extra_dependencies::Dict{String,String}
    targets::Dict{String,Vector{String}}
    compat::Dict{String,String}
    sources::Dict{String,Dict{String,String}}
    workspace_projects::Vector{String}
end

function parse_project_toml_facts(project_path::AbstractString)
    start = project_search_start(project_path)
    project_toml = Base.current_project(start)
    if isnothing(project_toml)
        root = abspath(start)
        return empty_project_toml_facts(root, joinpath(root, "Project.toml"))
    end
    root = dirname(project_toml)
    project = try
        Pkg.Types.read_project(project_toml)
    catch
        return empty_project_toml_facts(root, project_toml)
    end
    JuliaProjectTomlFacts(
        root,
        project_toml,
        isnothing(project.name) ? nothing : String(project.name),
        isnothing(project.uuid) ? nothing : string(project.uuid),
        isnothing(project.entryfile) ? nothing : String(project.entryfile),
        string_uuid_dict(project.deps),
        string_uuid_dict(project.weakdeps),
        string_uuid_dict(project.extras),
        string_vector_dict(project.targets),
        string_value_dict(project.compat),
        string_source_dict(project.sources),
        string_workspace_projects(project.workspace),
    )
end

function empty_project_toml_facts(project_root::AbstractString, project_toml::Union{Nothing,String})
    JuliaProjectTomlFacts(
        String(project_root),
        project_toml,
        nothing,
        nothing,
        nothing,
        Dict{String,String}(),
        Dict{String,String}(),
        Dict{String,String}(),
        Dict{String,Vector{String}}(),
        Dict{String,String}(),
        Dict{String,Dict{String,String}}(),
        String[],
    )
end

function string_uuid_dict(values)
    Dict(String(name) => string(uuid) for (name, uuid) in values)
end

function string_value_dict(values)
    Dict(String(name) => project_value_string(value) for (name, value) in values)
end

function project_value_string(value)
    :str in fieldnames(typeof(value)) ? string(getfield(value, :str)) : string(value)
end

function string_vector_dict(values)
    Dict(String(name) => String[string(item) for item in items] for (name, items) in values)
end

function string_source_dict(values)
    sources = Dict{String,Dict{String,String}}()
    for (name, source) in values
        source_name = String(name)
        if source isa AbstractDict
            sources[source_name] = Dict(String(key) => string(value) for (key, value) in source)
        else
            sources[source_name] = Dict("value" => string(source))
        end
    end
    sources
end

function string_workspace_projects(workspace)
    projects = get(workspace, "projects", String[])
    String[string(project) for project in projects]
end

function project_search_start(project_path::AbstractString)
    path = abspath(String(project_path))
    isfile(path) ? dirname(path) : path
end

function package_entry_path(
    project_root::AbstractString,
    package_name::Union{Nothing,String},
    entryfile::Union{Nothing,String},
)
    if !isnothing(entryfile)
        path = isabspath(entryfile) ? normpath(entryfile) : normpath(joinpath(project_root, entryfile))
        return isfile(path) ? path : nothing
    end
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
