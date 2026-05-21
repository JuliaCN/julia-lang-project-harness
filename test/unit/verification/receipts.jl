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
