mutable struct JuliaHarnessCliOptions
    project_root::String
    json::Bool
    agent_snapshot::Bool
    advice::Bool
    search_query::Union{Nothing,String}
    tags::Vector{String}
    limit::Int
    help::Bool
end

function default_julia_harness_cli_options()
    JuliaHarnessCliOptions(pwd(), false, false, false, nothing, String[], 25, false)
end

function run_julia_project_harness_cli(args=ARGS; out=stdout, err=stderr)
    try
        run_julia_project_harness_cli_checked(String.(collect(args)); out, err)
    catch caught
        println(err, "error: $(compact_error_message(caught))")
        2
    end
end

function run_julia_project_harness_cli_checked(args::Vector{String}; out=stdout, err=stderr)
    options = parse_julia_harness_cli_args(args)
    if options.help
        print(out, julia_harness_cli_usage())
        return 0
    end
    validate_julia_harness_cli_options(options)
    if !isnothing(options.search_query)
        results = search_julia_project(
            options.project_root,
            options.search_query;
            tags=options.tags,
            limit=options.limit,
        )
        print(out, render_julia_search_results(results; project_root=options.project_root))
        return 0
    elseif options.agent_snapshot
        print(out, render_julia_project_harness_agent_snapshot(options.project_root))
        return 0
    end

    report = run_julia_project_harness(options.project_root)
    if options.json
        print(out, render_julia_project_harness_json(report))
        print(out, "\n")
    elseif options.advice
        print(out, render_julia_project_harness_advice(report))
    else
        print(out, render_julia_project_harness(report))
    end
    is_clean(report) ? 0 : 1
end

function parse_julia_harness_cli_args(args::Vector{String})
    options = default_julia_harness_cli_options()
    positionals = String[]
    index = 1
    while index <= length(args)
        arg = args[index]
        if arg in ("-h", "--help")
            options.help = true
        elseif arg == "--json"
            options.json = true
        elseif arg == "--agent-snapshot"
            options.agent_snapshot = true
        elseif arg == "--advice"
            options.advice = true
        elseif arg == "--search"
            index += 1
            index <= length(args) || error("--search requires a query")
            options.search_query = args[index]
        elseif arg == "--tag"
            index += 1
            index <= length(args) || error("--tag requires a tag")
            append!(options.tags, split_cli_tags(args[index]))
        elseif arg == "--limit"
            index += 1
            index <= length(args) || error("--limit requires an integer")
            options.limit = Base.parse(Int, args[index])
        elseif startswith(arg, "--")
            error("unknown option: $(arg)")
        else
            push!(positionals, arg)
        end
        index += 1
    end
    length(positionals) <= 1 || error("expected at most one PROJECT_ROOT")
    !isempty(positionals) && (options.project_root = only(positionals))
    options
end

function validate_julia_harness_cli_options(options::JuliaHarnessCliOptions)
    modes = count(identity, [
        options.json,
        options.agent_snapshot,
        options.advice,
        !isnothing(options.search_query),
    ])
    modes <= 1 || error("expected only one output mode")
    options.limit >= 0 || error("--limit must be non-negative")
    options
end

function split_cli_tags(value::AbstractString)
    [strip(tag) for tag in split(String(value), ',') if !isempty(strip(tag))]
end

function julia_harness_cli_usage()
    """
    julia-project-harness [--json | --agent-snapshot | --advice | --search QUERY] [options] [PROJECT_ROOT]

    Compact text is the default agent-facing repair surface.
    Use --agent-snapshot to emit a low-noise project summary.
    Use --search QUERY with --tag TAG and --limit N to query JuliaSyntax facts.
    """
end
