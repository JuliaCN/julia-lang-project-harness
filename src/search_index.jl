function julia_lang_search_index(
    paths::Vector{<:AbstractString};
    config=default_julia_harness_config(),
)
    for path in paths
        ispath(path) || error("harness path does not exist: $(path)")
    end
    parsed_files = [parse_julia_file(path) for path in discover_julia_files(abspath.(String.(paths)), config)]
    julia_search_index(parsed_files)
end

function julia_project_search_index(
    project_root::AbstractString;
    config=default_julia_harness_config(),
)
    ispath(project_root) || error("project path does not exist: $(project_root)")
    scope = julia_project_harness_scope(project_root, config)
    workspace_member_scopes = julia_workspace_member_scopes(scope, config)
    monitored_paths = vcat(
        scope_monitored_paths(scope),
        mapreduce(scope_monitored_paths, vcat, workspace_member_scopes; init=String[]),
    )
    parsed_files = [parse_julia_file(path) for path in discover_julia_files(monitored_paths, config)]
    julia_search_index(parsed_files)
end

function julia_search_index(parsed_files::Vector{ParsedJuliaFile})
    entries = JuliaSearchIndexEntry[]
    for parsed in parsed_files
        parsed.report.is_valid || continue
        append!(entries, module_search_entries(parsed))
        append!(entries, public_search_entries(parsed))
        append!(entries, import_search_entries(parsed))
        append!(entries, type_search_entries(parsed))
        append!(entries, function_search_entries(parsed))
        append!(entries, test_search_entries(parsed))
        append!(entries, include_search_entries(parsed))
    end
    sort!(entries; by=entry -> (
        something(entry.location.path, ""),
        entry.location.line,
        entry.location.column,
        entry.kind,
        entry.name,
    ))
end

function module_search_entries(parsed::ParsedJuliaFile)
    [
        search_index_entry(
            parsed,
            module_fact.line,
            module_fact.column,
            "module",
            module_fact.name;
            detail=module_fact.is_bare ? "baremodule" : "module",
            tags=module_fact.is_bare ? ["module", "baremodule"] : ["module"],
        ) for module_fact in parsed.syntax_facts.modules
    ]
end

function public_search_entries(parsed::ParsedJuliaFile)
    entries = JuliaSearchIndexEntry[]
    for public_fact in parsed.syntax_facts.exports
        for name in public_fact.names
            push!(
                entries,
                search_index_entry(
                    parsed,
                    public_fact.line,
                    public_fact.column,
                    public_fact.kind,
                    name;
                    detail="public Julia API symbol",
                    tags=["public", public_fact.kind],
                ),
            )
        end
    end
    entries
end

function import_search_entries(parsed::ParsedJuliaFile)
    entries = JuliaSearchIndexEntry[]
    for import_fact in parsed.syntax_facts.imports
        imported_names = isempty(import_fact.names) ? import_fact.root :
                         "$(import_fact.root):$(join(import_fact.names, ","))"
        push!(
            entries,
            search_index_entry(
                parsed,
                import_fact.line,
                import_fact.column,
                import_fact.kind,
                imported_names;
                detail=import_fact.expression,
                tags=["dependency", import_fact.kind, import_fact.root],
            ),
        )
    end
    entries
end

function type_search_entries(parsed::ParsedJuliaFile)
    [
        search_index_entry(
            parsed,
            type_fact.line,
            type_fact.column,
            type_fact.kind,
            type_fact.name;
            detail=display_type_search_detail(type_fact),
            tags=type_fact.is_mutable ? ["type", "mutable"] : ["type"],
        ) for type_fact in parsed.syntax_facts.types
    ]
end

function function_search_entries(parsed::ParsedJuliaFile)
    [
        search_index_entry(
            parsed,
            function_fact.line,
            function_fact.column,
            function_fact.kind,
            function_fact.name;
            detail=display_function_search_detail(function_fact),
            tags=["method", function_fact.kind, function_fact.terminal_name],
        ) for function_fact in parsed.syntax_facts.functions
    ]
end

function test_search_entries(parsed::ParsedJuliaFile)
    [
        search_index_entry(
            parsed,
            test_fact.line,
            test_fact.column,
            test_fact.kind,
            something(test_fact.label, test_fact.name);
            detail=test_fact.expression,
            tags=["test", test_fact.kind],
        ) for test_fact in parsed.syntax_facts.tests
    ]
end

function include_search_entries(parsed::ParsedJuliaFile)
    [
        search_index_entry(
            parsed,
            include_fact.line,
            include_fact.column,
            "include",
            something(include_fact.target, include_fact.expression);
            detail=include_search_detail(include_fact),
            tags=include_fact.is_literal ? ["include", "literal"] : ["include", "dynamic"],
        ) for include_fact in parsed.syntax_facts.includes
    ]
end

function search_index_entry(
    parsed::ParsedJuliaFile,
    line::Int,
    column::Int,
    kind::AbstractString,
    name::AbstractString;
    detail::AbstractString="",
    tags::Vector{String}=String[],
)
    line_text = something(source_line(parsed.source, line), "")
    search_text = join(
        filter(!isempty, [String(kind), String(name), String(detail), line_text]),
        " ",
    )
    JuliaSearchIndexEntry(
        SourceLocation(parsed.report.path, line, column),
        String(kind),
        String(name),
        String(detail),
        search_text,
        copy(tags),
    )
end

function display_type_search_detail(type_fact::JuliaTypeSyntax)
    kind = type_fact.kind == "struct" && type_fact.is_mutable ? "mutable struct" :
           type_fact.kind
    parameter_suffix = isempty(type_fact.parameters) ? "" : "{$(join(type_fact.parameters, ","))}"
    supertype_suffix = isnothing(type_fact.supertype) ? "" : " <: $(type_fact.supertype)"
    field_suffix = isempty(type_fact.fields) ? "" : " fields=$(join(type_fact.fields, ","))"
    "$(kind) $(type_fact.name)$(parameter_suffix)$(supertype_suffix)$(field_suffix)"
end

function display_function_search_detail(function_fact::JuliaFunctionSyntax)
    positional = join(function_fact.positional_args, ",")
    keyword_suffix = isempty(function_fact.keyword_args) ? "" :
                     ";$(join(function_fact.keyword_args, ","))"
    bool_suffix = isempty(function_fact.bool_positional_args) ? "" :
                  " bool=$(join(function_fact.bool_positional_args, ","))"
    "$(function_fact.kind) $(function_fact.name)($(positional)$(keyword_suffix))$(bool_suffix)"
end

function include_search_detail(include_fact::JuliaIncludeSyntax)
    if include_fact.is_literal
        target = something(include_fact.resolved_target, include_fact.target)
        return "literal include $(target)"
    end
    "dynamic include"
end
