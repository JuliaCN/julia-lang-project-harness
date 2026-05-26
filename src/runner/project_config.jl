const PROJECT_HARNESS_TOOL_TABLE = "JuliaLangProjectHarness"

function project_toml_harness_config(
    project_root::AbstractString,
    base_config::JuliaHarnessConfig,
)
    project_toml = Base.current_project(project_search_start(project_root))
    isnothing(project_toml) && return base_config
    table = project_harness_tool_table(project_toml)
    isempty(table) && return base_config
    merge_project_harness_tool_config(base_config, table)
end

function project_harness_tool_table(project_toml::AbstractString)
    parsed = TOML.parsefile(project_toml)
    tool = get(parsed, "tool", nothing)
    tool isa AbstractDict || return Dict{String,Any}()
    table = get(tool, PROJECT_HARNESS_TOOL_TABLE, nothing)
    table isa AbstractDict || return Dict{String,Any}()
    Dict{String,Any}(String(key) => value for (key, value) in table)
end

function merge_project_harness_tool_config(
    base_config::JuliaHarnessConfig,
    table::Dict{String,Any},
)
    JuliaHarnessConfig(
        Set(string_list(get(table, "ignored_dir_names", collect(base_config.ignored_dir_names)))),
        severity_set(
            get(table, "blocking_severities", severity_label.(collect(base_config.blocking_severities))),
        ),
        string_set(get(table, "disabled_rules", collect(base_config.disabled_rules))),
        string_dict(
            get(table, "disabled_rule_explanations", base_config.disabled_rule_explanations),
        ),
        severity_dict(
            get(table, "rule_severity_overrides", base_config.rule_severity_overrides),
        ),
        string_dict(
            get(
                table,
                "rule_severity_override_explanations",
                base_config.rule_severity_override_explanations,
            ),
        ),
        string_dict(
            get(table, "blocking_severity_explanations", base_config.blocking_severity_explanations),
        ),
        bool_value(get(table, "include_tests", base_config.include_tests), "include_tests"),
        string_list(get(table, "source_dir_names", base_config.source_dir_names)),
        string_list(get(table, "test_dir_names", base_config.test_dir_names)),
        string_dict(get(table, "source_path_explanations", base_config.source_path_explanations)),
        string_dict(get(table, "test_path_explanations", base_config.test_path_explanations)),
        string_dict(
            get(
                table,
                "source_path_exclusion_explanations",
                base_config.source_path_exclusion_explanations,
            ),
        ),
        string_dict(
            get(
                table,
                "test_path_exclusion_explanations",
                base_config.test_path_exclusion_explanations,
            ),
        ),
        project_advice_policy_explanation(table, base_config.agent_advice_allow_explanation),
    )
end

function string_list(value)
    value isa AbstractVector || throw(ArgumentError("expected a string array, got $(typeof(value))"))
    String[string(item) for item in value]
end

function string_set(value)
    Set(string_list(value))
end

function string_dict(value)
    value isa AbstractDict || throw(ArgumentError("expected a string table, got $(typeof(value))"))
    Dict{String,String}(String(key) => string(item) for (key, item) in value)
end

function bool_value(value, name::AbstractString)
    value isa Bool || throw(ArgumentError("`$(name)` must be true or false"))
    value
end

function optional_string(value, name::AbstractString)
    isnothing(value) && return nothing
    value isa AbstractString || throw(ArgumentError("`$(name)` must be a string"))
    String(value)
end

function project_advice_policy_explanation(
    table::Dict{String,Any},
    default_explanation::Union{Nothing,String},
)
    policy = lowercase(strip(string(get(table, "advice", "gate"))))
    policy == "gate" && return default_explanation
    if policy == "report"
        explanation = optional_string(
            get(table, "advice_explanation", nothing),
            "advice_explanation",
        )
        isnothing(explanation) && return ""
        return explanation
    end
    throw(ArgumentError("`advice` must be \"gate\" or \"report\""))
end

function severity_set(value)
    Set(parse_harness_severity.(string_list(value)))
end

function severity_dict(value)
    value isa AbstractDict ||
        throw(ArgumentError("expected a severity override table, got $(typeof(value))"))
    Dict{String,JuliaDiagnosticSeverity}(
        String(rule_id) => parse_harness_severity(string(severity)) for
        (rule_id, severity) in value
    )
end

function parse_harness_severity(value::AbstractString)
    normalized = lowercase(strip(value))
    normalized == "info" && return Info
    normalized == "warning" && return Warning
    normalized == "error" && return Error
    throw(ArgumentError("unknown JuliaLangProjectHarness severity `$(value)`"))
end
