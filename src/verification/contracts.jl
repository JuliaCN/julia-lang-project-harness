const JULIA_VERIFICATION_REQUIRED_EVIDENCE = Dict(
    "stress" => [
        "scenario",
        "load_steps",
        "p50_ms",
        "p99_ms",
        "threshold",
        "result",
    ],
    "performance" => [
        "benchmark_command",
        "baseline",
        "regression_threshold",
        "latency_or_throughput",
        "allocation_profile",
        "artifact",
    ],
    "chaos" => [
        "injected_failure",
        "degradation_behavior",
        "recovery_result",
    ],
    "security" => [
        "attack_classes",
        "authorization_boundary",
        "result",
    ],
)

const JULIA_VERIFICATION_RECEIPT_CONTRACTS = Dict(
    "stress" => "report latency percentiles, load steps, threshold, and pass/fail result",
    "performance" =>
        "report benchmark command, baseline, regression threshold, runtime or allocation metric, and artifact",
    "chaos" => "report injected failure, degraded behavior, and recovery result",
    "security" => "report scanned attack classes, authorization boundary, and pass/fail result",
)

function verification_task_required_evidence(record::JuliaVerificationTaskRecord)
    get(JULIA_VERIFICATION_REQUIRED_EVIDENCE, record.kind, String[])
end

function verification_task_required_receipt(record::JuliaVerificationTaskRecord)
    get(JULIA_VERIFICATION_RECEIPT_CONTRACTS, record.kind, "")
end

function compact_required_evidence(record::JuliaVerificationTaskRecord)
    join(verification_task_required_evidence(record), ",")
end
