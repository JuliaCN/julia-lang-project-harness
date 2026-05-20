const JULIA_VERIFICATION_ADVICE_EVIDENCE_KEYS = [
    "responsibilities",
    "network_roots",
    "persistence_roots",
    "security_roots",
    "performance_roots",
    "file_io_calls",
    "process_calls",
    "performance_calls",
    "performance_macros",
    "direct_deps",
    "imported_deps",
]

"""Render non-blocking pending verification work for agent-facing test logs."""
function render_julia_verification_pending_advice(profile::JuliaVerificationProfile)
    records = pending_agent_verification_tasks(profile)
    isempty(records) && return ""
    lines = ["[verify-advice] pending=$(length(records))"]
    for record in records
        push!(
            lines,
            "- kind=$(record.kind) phase=$(record.phase) owner=" *
            verification_owner_path(profile.task_index, record),
        )
        push!(lines, "  fingerprint=$(record.fingerprint)")
        advice_evidence = compact_advice_evidence(record)
        !isempty(advice_evidence) && push!(lines, "  evidence=$(advice_evidence)")
        required_evidence = compact_required_evidence(record)
        !isempty(required_evidence) && push!(lines, "  requires=$(required_evidence)")
        push!(lines, "  next=$(record.reason)")
    end
    join(lines, "\n") * "\n"
end

function pending_agent_verification_tasks(profile::JuliaVerificationProfile)
    [
        record for record in profile.task_index.records if
        record.kind in JULIA_AGENT_VERIFICATION_TASK_KINDS && record.state == "pending"
    ]
end

function compact_advice_evidence(record::JuliaVerificationTaskRecord)
    evidence = [
        "$(key)=$(record.evidence[key])" for key in JULIA_VERIFICATION_ADVICE_EVIDENCE_KEYS if
        haskey(record.evidence, key)
    ]
    join(evidence, ";")
end
