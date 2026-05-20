function run_julia_lang_harness(paths::Vector{<:AbstractString}; config=default_julia_harness_config())
    for path in paths
        ispath(path) || error("harness path does not exist: $(path)")
    end
    run_paths(String.(paths), config)
end

function run_julia_project_harness(project_root::AbstractString; config=default_julia_harness_config())
    isdir(project_root) || error("project root does not exist: $(project_root)")
    run_paths(monitored_project_paths(project_root, config), config; project_root=String(project_root))
end

function assert_julia_lang_harness_clean(paths::Vector{<:AbstractString}; config=default_julia_harness_config())
    report = run_julia_lang_harness(paths; config)
    assert_clean(report)
end

function assert_julia_project_harness_clean(project_root::AbstractString; config=default_julia_harness_config())
    report = run_julia_project_harness(project_root; config)
    assert_clean(report)
end

function run_paths(paths::Vector{String}, config::JuliaHarnessConfig; project_root=nothing)
    parsed_files = [parse_julia_file(path) for path in discover_julia_files(paths, config)]
    findings = evaluate_default_rule_packs(parsed_files, config)
    JuliaHarnessReport(
        [parsed.report for parsed in parsed_files],
        findings,
        paths,
        copy(config.blocking_severities),
        isnothing(project_root) ? nothing : JuliaProjectHarnessScope(
            String(project_root),
            existing_configured_paths(project_root, config.source_dir_names),
            config.include_tests ? existing_configured_paths(project_root, config.test_dir_names) :
            String[],
            String[],
            String[],
        ),
        JuliaProjectHarnessScope[],
    )
end

function monitored_project_paths(project_root::AbstractString, config::JuliaHarnessConfig)
    source_paths = existing_configured_paths(project_root, config.source_dir_names)
    test_paths = config.include_tests ? existing_configured_paths(project_root, config.test_dir_names) :
                 String[]
    selected = vcat(source_paths, test_paths)
    isempty(selected) ? [String(project_root)] : selected
end

function existing_configured_paths(project_root::AbstractString, path_names::Vector{String})
    [joinpath(project_root, path_name) for path_name in path_names if ispath(joinpath(project_root, path_name))]
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
