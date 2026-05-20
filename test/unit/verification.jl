function write_verification_project(root::AbstractString)
    write(
        joinpath(root, "Project.toml"),
        """
        name = "VerifyExample"
        uuid = "11111111-1111-1111-1111-111111111111"
        version = "0.1.0"

        [deps]
        JuliaLangProjectHarness = "67259778-f152-405a-bc38-ee6219bce977"

        [weakdeps]
        JSON3 = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"

        [extensions]
        VerifyJSONExt = ["JSON3"]

        [compat]
        JSON3 = "1"
        JuliaLangProjectHarness = "0.1"

        [extras]
        Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

        [targets]
        test = ["Test"]
        """,
    )
    mkpath(joinpath(root, "src"))
    mkpath(joinpath(root, "test"))
    mkpath(joinpath(root, "ext"))
    write(
        joinpath(root, "src", "VerifyExample.jl"),
        """
        module VerifyExample
        export run
        \"\"\"Run the verification fixture value.\"\"\"
        run(value) = value
        end
        """,
    )
    write(
        joinpath(root, "test", "runtests.jl"),
        """
        using JuliaLangProjectHarness
        using Test

        @test true
        assert_julia_project_harness_test_profile_clean(dirname(@__DIR__))
        """,
    )
    write(joinpath(root, "ext", "VerifyJSONExt.jl"), "module VerifyJSONExt\nend\n")
end

function write_responsibility_project(root::AbstractString)
    write(
        joinpath(root, "Project.toml"),
        """
        name = "ResponsibilityExample"
        uuid = "11111111-1111-1111-1111-111111111111"
        version = "0.1.0"

        [deps]
        HTTP = "cd3eb016-35fb-5094-929b-558a96fad6f3"
        JSON3 = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"

        [compat]
        HTTP = "1"
        JSON3 = "1"
        """,
    )
    mkpath(joinpath(root, "src"))
    write(
        joinpath(root, "src", "ResponsibilityExample.jl"),
        """
        module ResponsibilityExample
        using HTTP
        using JSON3
        using SHA
        using LinearAlgebra
        export fetch_config

        \"\"\"Fetch and decode a remote config payload.\"\"\"
        function fetch_config(urls)
            digests = mapreduce(url -> bytes2hex(sha256(url)), vcat, urls)
            response = HTTP.get(first(urls))
            data = open("config.json") do io
                JSON3.read(read(io, String))
            end
            return norm(digests), response, data
        end
        end
        """,
    )
end

@testset "verification task index" begin
    root = mktempdir()
    write_verification_project(root)

    index = build_julia_verification_task_index(root)
    kinds = [record.kind for record in index.records]

    @test index.project_root == root
    @test kinds == ["extension_boundary", "harness_policy", "pkg_test", "stress", "syntax_search"]
    @test all(record -> record.state == "pending", index.records)
    @test any(record -> occursin("Pkg.test()", join(record.command, " ")), index.records)
    @test any(
        record -> record.kind == "harness_policy" &&
                  occursin(
                      "assert_julia_project_harness_test_profile_clean",
                      join(record.command, " "),
                  ),
        index.records,
    )
    @test any(
        record -> record.kind == "extension_boundary" &&
                  record.evidence["extension"] == "VerifyJSONExt",
        index.records,
    )

    rendered = render_julia_verification_task_index(index)
    json = render_julia_verification_task_index_json(index)
    template = render_julia_verification_receipt_template(index)

    @test occursin("VerificationTasks: count=5", rendered)
    @test occursin("owner=test/runtests.jl", rendered)
    @test occursin("fingerprint=", rendered)
    @test occursin("kind=stress", rendered)
    @test occursin("requires=scenario,load_steps,p50_ms,p99_ms,threshold,result", rendered)
    @test occursin("\"records\"", json)
    @test occursin("\"required_evidence\"", json)
    @test occursin("VerifyJSONExt", json)
    @test occursin("\"receipts\"", template)
    @test occursin("\"scenario\":\"\"", template)
    @test occursin("\"required_receipt\"", template)

    advice_out = IOBuffer()
    profile = assert_julia_project_harness_test_profile_clean(root; advice_io=advice_out)
    advice = String(take!(advice_out))
    @test profile.report.project_scope.project_root == root
    @test [record.kind for record in profile.task_index.records] == kinds
    @test length(profile.profile_index.candidates) == 3
    @test isempty(profile.receipt_reviews)
    @test occursin("[verify-advice] pending=1", advice)
    @test occursin("kind=stress", advice)
    @test occursin("fingerprint=stress", advice)
    @test occursin("requires=scenario,load_steps,p50_ms,p99_ms,threshold,result", advice)

    profile_rendered = render_julia_verification_profile(profile)
    profile_json = render_julia_verification_profile_json(profile)

    @test occursin("VerificationProfiles: count=3", profile_rendered)
    @test occursin("responsibilities=test_profile_gate", profile_rendered)
    @test occursin("responsibilities=public_api", profile_rendered)
    @test occursin("responsibilities=extension_boundary", profile_rendered)
    @test occursin("\"profile_index\"", profile_json)
    @test occursin("\"receipt_reviews\"", profile_json)
    @test occursin("extension_boundary", profile_json)
end

@testset "verification profile infers agent responsibilities from project facts" begin
    root = mktempdir()
    write_responsibility_project(root)

    index = build_julia_verification_profile_index(root)
    rendered = render_julia_verification_profile_index(index)
    candidate = only(index.candidates)

    @test candidate.responsibilities == [
        "public_api",
        "external_dependency",
        "persistence",
        "security_boundary",
        "latency_sensitive",
        "availability_critical",
    ]
    @test candidate.task_kinds == [
        "pkg_test",
        "syntax_search",
        "stress",
        "performance",
        "chaos",
        "security",
    ]
    @test candidate.evidence["direct_deps"] == "HTTP,JSON3"
    @test candidate.evidence["network_roots"] == "HTTP"
    @test candidate.evidence["persistence_roots"] == "JSON3"
    @test candidate.evidence["security_roots"] == "SHA"
    @test candidate.evidence["performance_roots"] == "LinearAlgebra"
    @test occursin("responsibilities=public_api,external_dependency", rendered)
    @test occursin("tasks=pkg_test,syntax_search,stress,performance,chaos,security", rendered)

    task_index = build_julia_verification_task_index(root)
    task_kinds = [record.kind for record in task_index.records]
    task_rendered = render_julia_verification_task_index(task_index)

    @test task_kinds == ["chaos", "performance", "pkg_test", "security", "stress"]
    @test occursin("kind=performance state=pending phase=after_unit_tests_pass", task_rendered)
    @test occursin("kind=security state=pending phase=before_release", task_rendered)
    @test occursin("fingerprint=performance", task_rendered)
    @test occursin(
        "requires=benchmark_command,baseline,regression_threshold,latency_or_throughput,allocation_profile,artifact",
        task_rendered,
    )
    @test occursin("requires=attack_classes,authorization_boundary,result", task_rendered)
    @test occursin("responsibilities=public_api,external_dependency", task_rendered)
    @test occursin("Agent should add or run Julia-native performance evidence", task_rendered)

    profile = build_julia_project_verification_profile(root)
    advice = render_julia_verification_pending_advice(profile)
    receipt_template = render_julia_verification_receipt_template(task_index)

    @test occursin("[verify-advice] pending=4", advice)
    @test occursin("kind=performance", advice)
    @test occursin("kind=security", advice)
    @test occursin("requires=benchmark_command,baseline,regression_threshold", advice)
    @test occursin("evidence=responsibilities=public_api,external_dependency", advice)
    @test !occursin("exports=", advice)
    @test occursin("\"benchmark_command\":\"\"", receipt_template)
    @test occursin("\"attack_classes\":\"\"", receipt_template)
    @test occursin("\"injected_failure\":\"\"", receipt_template)
end

@testset "verification profile reviews default agent receipt file" begin
    root = mktempdir()
    write_verification_project(root)
    receipt_root = joinpath(root, ".julia-harness")
    mkpath(receipt_root)
    receipt_path = joinpath(receipt_root, "verification-receipts.json")

    index = build_julia_verification_task_index(root)
    stress = only(record for record in index.records if record.kind == "stress")
    write(receipt_path, render_julia_verification_receipt_template(index))

    profile = build_julia_project_verification_profile(root)
    rendered = render_julia_verification_profile(profile)
    json = render_julia_verification_profile_json(profile)

    @test length(profile.receipt_reviews) == 1
    @test only(profile.receipt_reviews).status == :incomplete
    @test occursin("VerificationReceiptReview: count=1 accepted=0 incomplete=1", rendered)
    @test occursin("weak=scenario,load_steps,p50_ms,p99_ms,threshold,result", rendered)
    @test occursin("\"receipt_reviews\"", json)
    @test_throws ErrorException assert_julia_project_harness_test_profile_clean(
        root;
        advice_io=nothing,
    )

    write(
        receipt_path,
        """
        {"receipts":[{"fingerprint":"$(stress.fingerprint)","kind":"stress","owner_path":"src/VerifyExample.jl","scenario":"profile default receipt smoke","load_steps":"1,4,8","p50_ms":"1.0","p99_ms":"4.0","threshold":"p99_ms <= 10","result":"pass"}]}
        """,
    )
    accepted_advice_out = IOBuffer()
    accepted_profile = assert_julia_project_harness_test_profile_clean(
        root;
        advice_io=accepted_advice_out,
    )
    @test length(accepted_profile.receipt_reviews) == 1
    @test only(accepted_profile.receipt_reviews).status == :accepted
    @test isempty(String(take!(accepted_advice_out)))
end

@testset "verification receipt review enforces required evidence" begin
    root = mktempdir()
    write_verification_project(root)

    index = build_julia_verification_task_index(root)
    stress = only(record for record in index.records if record.kind == "stress")
    template = render_julia_verification_receipt_template(index)
    template_path = joinpath(root, "receipt-template.json")
    write(template_path, template)
    template_reviews = review_julia_verification_receipts(
        index,
        read_julia_verification_receipts_json(template_path),
    )

    @test occursin("\"fingerprint\":\"$(stress.fingerprint)\"", template)
    @test occursin("\"task_evidence\"", template)
    @test only(template_reviews).status == :incomplete
    @test only(template_reviews).weak_evidence == [
        "scenario",
        "load_steps",
        "p50_ms",
        "p99_ms",
        "threshold",
        "result",
    ]

    good_receipt = Dict(
        "fingerprint" => stress.fingerprint,
        "kind" => stress.kind,
        "owner_path" => relpath(stress.owner_path, root),
        "scenario" => "public API smoke under generated load",
        "load_steps" => "1,10,25",
        "p50_ms" => "1.2",
        "p99_ms" => "4.8",
        "threshold" => "p99_ms <= 10",
        "result" => "pass",
    )

    reviews = review_julia_verification_receipts(index, [good_receipt])
    @test length(reviews) == 1
    @test only(reviews).status == :accepted
    @test isempty(only(reviews).missing_evidence)
    @test isempty(only(reviews).weak_evidence)
    accepted_reviews = assert_julia_verification_receipts_accepted(index, [good_receipt])
    @test length(accepted_reviews) == 1
    @test only(accepted_reviews).status == :accepted

    mismatched_binding = merge(
        good_receipt,
        Dict("kind" => "performance", "owner_path" => "src/OtherOwner.jl"),
    )
    mismatched_review = only(review_julia_verification_receipts(index, [mismatched_binding]))
    mismatched_rendered = render_julia_verification_receipt_reviews(
        [mismatched_review];
        project_root=root,
    )
    @test mismatched_review.status == :incomplete
    @test isempty(mismatched_review.missing_evidence)
    @test isempty(mismatched_review.weak_evidence)
    @test "receipt kind does not match task kind" in mismatched_review.problems
    @test "receipt owner_path does not match task owner" in mismatched_review.problems
    @test occursin("receipt kind does not match task kind", mismatched_rendered)

    bad_receipt = Dict(
        "fingerprint" => stress.fingerprint,
        "scenario" => "todo",
        "load_steps" => "",
        "p50_ms" => "1.2",
    )
    bad_reviews = review_julia_verification_receipts(index, [bad_receipt])
    bad_rendered = render_julia_verification_receipt_reviews(bad_reviews; project_root=root)
    bad_json = render_julia_verification_receipt_reviews_json(bad_reviews)

    @test only(bad_reviews).status == :incomplete
    @test only(bad_reviews).missing_evidence == ["p99_ms", "threshold", "result"]
    @test only(bad_reviews).weak_evidence == ["scenario", "load_steps"]
    @test occursin("VerificationReceiptReview: count=1 accepted=0 incomplete=1", bad_rendered)
    @test occursin("missing=p99_ms,threshold,result", bad_rendered)
    @test occursin("weak=scenario,load_steps", bad_rendered)
    @test occursin("\"missing_evidence\"", bad_json)
    @test_throws ErrorException assert_julia_verification_receipts_accepted(
        index,
        [bad_receipt],
    )

    weak_waiver = Dict(
        "fingerprint" => stress.fingerprint,
        "state" => "waived",
        "explanation" => "todo add receipt later",
    )
    weak_waiver_review = only(review_julia_verification_receipts(index, [weak_waiver]))
    @test weak_waiver_review.status == :incomplete
    @test occursin("concrete explanation", only(weak_waiver_review.problems))

    concrete_waiver = Dict(
        "fingerprint" => stress.fingerprint,
        "state" => "waived",
        "explanation" =>
            "external release train owns this load gate for the current migration window",
    )
    concrete_waiver_review = only(review_julia_verification_receipts(index, [concrete_waiver]))
    @test concrete_waiver_review.status == :waived

    orphan_reviews = review_julia_verification_receipts(
        index,
        [good_receipt, Dict("fingerprint" => "stale")],
    )
    orphan_review = only(review for review in orphan_reviews if review.status == :orphan)
    @test orphan_review.status == :orphan
    @test occursin("did not match", only(orphan_review.problems))
end
