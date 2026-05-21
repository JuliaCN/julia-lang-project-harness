function parsed_search_entries(parsed::ParsedJuliaFile)
    entries = JuliaSearchIndexEntry[]
    append!(entries, module_search_entries(parsed))
    append!(entries, public_search_entries(parsed))
    append!(entries, import_search_entries(parsed))
    append!(entries, type_search_entries(parsed))
    append!(entries, type_field_search_entries(parsed))
    append!(entries, binding_search_entries(parsed))
    append!(entries, moshi_search_entries(parsed))
    append!(entries, function_search_entries(parsed))
    append!(entries, function_argument_search_entries(parsed))
    append!(entries, call_search_entries(parsed))
    append!(entries, docstring_search_entries(parsed))
    append!(entries, identifier_search_entries(parsed))
    append!(entries, test_search_entries(parsed))
    append!(entries, include_search_entries(parsed))
    entries
end

function parsed_files_for_search_scope(
    scope::JuliaProjectHarnessScope,
    parsed_files::Vector{ParsedJuliaFile},
)
    [
        parsed for parsed in parsed_files if any(
            path -> is_path_under(parsed.report.path, path),
            scope_search_paths(scope),
        )
    ]
end

function search_origin_tags(
    owner_scopes::Vector{JuliaProjectHarnessScope},
    path::AbstractString,
)
    for scope in owner_scopes
        any(root -> is_path_under(path, root), scope_search_paths(scope)) || continue
        role = owner_search_role(scope, path)
        return unique(["project", role])
    end
    String[]
end

function search_entries_with_origin_tags(
    entries::Vector{JuliaSearchIndexEntry},
    origin_tags::Vector{String},
)
    isempty(origin_tags) && return entries
    [search_entry_with_origin_tags(entry, origin_tags) for entry in entries]
end

function search_entry_with_origin_tags(
    entry::JuliaSearchIndexEntry,
    origin_tags::Vector{String},
)
    JuliaSearchIndexEntry(
        entry.location,
        entry.kind,
        entry.name,
        entry.detail,
        entry.search_text,
        unique(vcat(entry.tags, origin_tags)),
    )
end
