function render_julia_search_results(
    results::Vector{JuliaSearchResult};
    project_root::Union{Nothing,AbstractString}=nothing,
)
    isempty(results) && return "[ok] julia search no-results\n"
    lines = ["SearchResults: count=$(length(results))"]
    for result in results
        entry = result.entry
        push!(
            lines,
            "- score=$(result.score) kind=$(entry.kind) name=$(entry.name) @ " *
            search_result_location(entry.location; project_root),
        )
        if !isempty(entry.tags)
            tags = join(entry.tags, ",")
            push!(lines, "  tags=$(tags)")
        end
        if !isempty(entry.detail)
            push!(lines, "  detail=$(compact_search_detail(entry.detail))")
        end
    end
    join(lines, "\n") * "\n"
end

function search_result_location(
    location::SourceLocation;
    project_root::Union{Nothing,AbstractString}=nothing,
)
    path = isnothing(location.path) ? "<memory>" : slash_path(location.path)
    if !isnothing(project_root) && !isnothing(location.path)
        root = abspath(String(project_root))
        absolute_path = abspath(location.path)
        relative_path = relpath(absolute_path, root)
        parts = splitpath(relative_path)
        if !isabspath(relative_path) && (isempty(parts) || first(parts) != "..")
            path = slash_path(relative_path)
        end
    end
    "$(path):$(location.line):$(location.column + 1)"
end

function compact_search_detail(detail::AbstractString)
    compact = replace(strip(String(detail)), r"\s+" => " ")
    length(compact) <= 160 ? compact : compact[1:160] * "..."
end
