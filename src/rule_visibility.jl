const RULE_VISIBILITY = Dict(
    AGENT_JL_R005 => JuliaRuleVisibility(
        AGENT_JL_R005,
        [
            "One exported name is defined by functions in one owner file.",
            "One exported `struct` plus outer constructors in the same owner file.",
            "A public method family split across owner files when the owning public method docstring includes an explicit dispatch or extension pattern.",
        ],
        [
            "The same exported name has a `struct` in one file and constructors in another file without an extension pattern.",
            "A public method family is implemented across several owner files without a dispatch or extension pattern.",
        ],
        [
            """
            \"\"\"Public payload type.\"\"\"
            struct Payload
                value::String
            end

            \"\"\"Build a payload from string-like values.

            Dispatch extension pattern: this constructor normalizes accepted input
            values while the type remains the single public data record.
            \"\"\"
            Payload(value::AbstractString) = Payload(String(value))
            """,
        ],
        [
            "For same-file `struct` plus constructor families, document the constructor, not only the struct.",
            "For cross-file method families, document the extension pattern on the method family owner.",
        ],
    ),
    AGENT_JL_R027 => JuliaRuleVisibility(
        AGENT_JL_R027,
        [
            "A monitored test file contains a direct `@test_throws ExceptionType public_function(...)` expression.",
            "The public function call appears inside the `@test_throws` expression itself, not hidden behind an anonymous function or helper.",
            "Included test files are accepted when they are reachable through literal `include(\"...\")` from `test/runtests.jl`.",
        ],
        [
            "`@test_throws ExceptionType helper()` where `helper` calls the public API.",
            "`@test_throws ExceptionType begin ... public_function(...) ... end` when the parser cannot recover the public call name.",
            "Dynamically included test files such as `include(joinpath(@__DIR__, suite))`.",
        ],
        [
            "@test_throws ArgumentError parse_payload(\"\")",
            "@test_throws ErrorException discover_pluto_notebooks(joinpath(@__DIR__, \"missing\"))",
        ],
        [
            "If a finding says `Detected covered methods: none`, the parser did not see a direct public function call inside any monitored `@test_throws` macro.",
            "Keep failure-contract tests parser-visible and boring; do not route them through loops, generated test expressions, or helper wrappers.",
        ],
    ),
)

"""
    julia_rule_visibility(rule_id)

Return the agent-facing visibility contract for `rule_id`, or `nothing` when
the rule has no structured visibility payload yet.
"""
function julia_rule_visibility(rule_id::AbstractString)
    get(RULE_VISIBILITY, String(rule_id), nothing)
end

"""
    render_julia_rule_visibility(rule_id)

Render accepted AST shapes, rejected shapes, examples, and repair notes for a
harness rule. This is intended for Agent repair loops and compact CLI output.
"""
function render_julia_rule_visibility(rule_id::AbstractString)
    visibility = julia_rule_visibility(rule_id)
    isnothing(visibility) && return ""
    render_rule_visibility(visibility)
end

function render_rule_visibility(visibility::JuliaRuleVisibility)
    lines = ["Rule visibility: $(visibility.rule_id)"]
    append_visibility_section!(lines, "Accepted AST shapes", visibility.accepted_ast_shapes)
    append_visibility_section!(lines, "Rejected AST shapes", visibility.rejected_ast_shapes)
    append_visibility_section!(lines, "Minimal examples", visibility.minimal_examples)
    append_visibility_section!(lines, "Repair notes", visibility.repair_notes)
    return join(lines, "\n") * "\n"
end

function append_visibility_section!(lines::Vector{String}, title::AbstractString, values::Vector{String})
    isempty(values) && return lines
    push!(lines, "$title:")
    for value in values
        push!(lines, "- $(strip(value))")
    end
    lines
end
