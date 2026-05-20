function type_field_search_entries(parsed::ParsedJuliaFile)
    entries = JuliaSearchIndexEntry[]
    for type_fact in parsed.syntax_facts.types
        for field_fact in type_fact.field_facts
            push!(
                entries,
                search_index_entry(
                    parsed,
                    field_fact.line,
                    field_fact.column,
                    "field",
                    "$(type_fact.name).$(field_fact.name)";
                    detail=display_type_field_search_detail(type_fact, field_fact),
                    tags=["type", "field", type_fact.kind],
                ),
            )
        end
    end
    entries
end

function display_type_field_search_detail(
    type_fact::JuliaTypeSyntax,
    field_fact::JuliaTypeFieldSyntax,
)
    owner_kind = type_fact.kind == "struct" && type_fact.is_mutable ? "mutable struct" :
                 type_fact.kind
    type_suffix = isnothing(field_fact.type_annotation) ? "" :
                  "::$(field_fact.type_annotation)"
    default_suffix = field_fact.has_default ? " default" : ""
    "$(owner_kind) $(field_fact.owner_name).$(field_fact.name)$(type_suffix)$(default_suffix)"
end
