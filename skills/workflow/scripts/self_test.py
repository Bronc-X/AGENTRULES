#!/usr/bin/env python3
"""Regression tests for scaffolding, evidence binding, and optimization claims."""

from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path

from workflow_pack_lib import canonical_json_sha256, definition_digest, sha256_file


SCRIPT_DIR = Path(__file__).resolve().parent
NEW_PACK = SCRIPT_DIR / "new_workflow_pack.py"
QA_PACK = SCRIPT_DIR / "qa_workflow_pack.py"
RUNNER = SCRIPT_DIR / "run_validation_commands.py"


def run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, "-X", "utf8", *args],
        text=True,
        encoding="utf-8",
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def evidence_ref(root: Path, relative: str, value: object) -> dict[str, str]:
    path = root / relative
    if isinstance(value, str):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value, encoding="utf-8", newline="\n")
    else:
        write_json(path, value)
    return {"path": relative, "sha256": sha256_file(path)}


def create_pack(root: Path, workflow_id: str) -> int:
    return run(
        str(NEW_PACK),
        "--workflow-id",
        workflow_id,
        "--title",
        "Sample \"workflow\"",
        "--destination",
        str(root),
        "--source-project-id",
        "sample-project",
    ).returncode


def complete_fixture(root: Path, mode: str = "unassessed", selected: str = "candidate-b") -> None:
    source_ref = evidence_ref(root, "evidence/source-run.json", {"result": "accepted"})
    acceptance_ref = evidence_ref(root, "evidence/acceptance.json", {"accepted": True})
    golden_ref = evidence_ref(root, "evidence/golden.json", {"result": "same"})
    negative_ref = evidence_ref(root, "evidence/negative.json", {"blocked": True})
    boundary_ref = evidence_ref(root, "evidence/boundary.json", {"edge": "handled"})
    ablation_ref = evidence_ref(root, "evidence/ablation.json", {"removal_broke": "traceability"})

    spec_path = root / "WORKFLOW_SPEC.json"
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    spec.update(
        {
            "version": "1.0.0",
            "status": "VERIFIED",
            "source_run": {
                "status": "PASS",
                "evidence": [source_ref],
                "artifact_hashes": ["sha256:" + "a" * 64],
            },
            "success_contract": {
                "observable_outcome": "A new operator reproduces the accepted artifact.",
                "scope_in": ["verified task family"],
                "scope_out": ["production release"],
                "acceptance_evidence": [acceptance_ref],
            },
            "validated_scope": {
                "input_types": ["frozen local fixture"],
                "environments": [f"Python {sys.version_info.major}.{sys.version_info.minor}"],
                "scale_bounds": ["one representative artifact"],
                "risk_levels": ["local reversible output"],
                "unverified_conditions": ["live production release"],
            },
            "inputs": ["frozen source"],
            "outputs": ["accepted artifact"],
            "steps": [
                {
                    "id": "build-output",
                    "title": "Build and verify the output",
                    "kind": "INVARIANT",
                    "executor": "AI",
                    "side_effect": "REVERSIBLE_LOCAL",
                    "inputs": ["frozen source"],
                    "outputs": ["accepted artifact"],
                    "exit_criteria": ["quality gate passes"],
                    "gate_ids": ["quality-gate"],
                }
            ],
            "gates": [
                {
                    "id": "quality-gate",
                    "type": "QUALITY",
                    "condition": "golden output and boundary behavior match",
                    "failure_action": "stop and report the mismatch",
                    "step_ids": ["build-output"],
                    "case_ids": ["negative-001", "boundary-001"],
                }
            ],
            "conditional_branches": [],
            "stop_conditions": ["stop before unapproved external writes"],
            "detours_removed": ["unverified planning is not labeled as a verified run"],
            "skill_export": {
                "requested": False,
                "artifact_root": None,
                "artifact_manifest": None,
                "source_workflows": [],
                "rules": [],
            },
            "validation": {
                "golden_case_ids": ["golden-001"],
                "negative_case_ids": ["negative-001"],
                "boundary_case_ids": ["boundary-001"],
                "independent_forward_test": {
                    "status": "PASS",
                    "evidence_path": "evidence/FORWARD_TEST.json",
                },
                "commands": [
                    {
                        "id": "smoke",
                        "argv": ["python", "-c", "print('workflow-smoke-ok')"],
                        "cwd": ".",
                        "timeout_seconds": 30,
                        "evidence_path": "evidence/commands/smoke.json",
                    }
                ],
            },
        }
    )
    spec["optimization"] = {
        "hard_constraints": [
            "outcome_correctness",
            "authorization_and_safety",
            "traceability_and_repeatability",
        ],
        "secondary_objectives": [
            {
                "metric": "user_touchpoints",
                "direction": "MINIMIZE",
                "priority": 1,
                "rationale": "Reduce repeated confirmations after hard constraints pass.",
            }
        ],
        "claim": "UNASSESSED",
        "comparison_metric": None,
        "selected_candidate_id": None,
        "candidate_paths": [],
        "ablation_case_ids": [],
    }

    cases_path = root / "tests" / "CASES.json"
    cases_doc = json.loads(cases_path.read_text(encoding="utf-8"))
    cases_by_id = {row["case_id"]: row for row in cases_doc["cases"]}
    cases_by_id["golden-001"].update(
        {
            "status": "PASS",
            "request": "Reproduce the accepted output.",
            "expected": "Protected output invariants remain equal.",
            "covers_step_ids": ["build-output"],
            "actual_evidence": [golden_ref],
        }
    )
    cases_by_id["negative-001"].update(
        {
            "status": "PASS",
            "request": "Run with a known invalid output.",
            "expected": "The quality gate blocks completion.",
            "covers_step_ids": ["build-output"],
            "covers_gate_ids": ["quality-gate"],
            "actual_evidence": [negative_ref],
        }
    )
    cases_by_id["boundary-001"].update(
        {
            "status": "PASS",
            "request": "Run at the declared boundary.",
            "expected": "Boundary behavior remains explicit.",
            "covers_step_ids": ["build-output"],
            "covers_gate_ids": ["quality-gate"],
            "actual_evidence": [boundary_ref],
        }
    )

    if mode == "irreducible":
        spec["steps"][0]["ablation_case_id"] = "ablation-001"
        spec["optimization"]["claim"] = "IRREDUCIBLE_WITHIN_VALIDATED_SCOPE"
        spec["optimization"]["ablation_case_ids"] = ["ablation-001"]
        cases_by_id["ablation-001"].update(
            {
                "status": "PASS",
                "request": "Remove build-output from the path.",
                "expected": "A protected invariant fails.",
                "covers_step_ids": ["build-output"],
                "actual_evidence": [ablation_ref],
            }
        )
    elif mode == "shortest":
        candidate_a_path = {
            "step_ids": ["build-output", "ask-again"],
            "branch_ids": [],
            "gate_ids": ["quality-gate"],
            "configuration": {"confirmation_mode": "twice"},
        }
        candidate_b_path = {
            "step_ids": ["build-output"],
            "branch_ids": [],
            "gate_ids": ["quality-gate"],
            "configuration": {"confirmation_mode": "once"},
        }
        candidate_a_fingerprint = canonical_json_sha256(candidate_a_path)
        candidate_b_fingerprint = canonical_json_sha256(candidate_b_path)
        candidate_a_metrics = {"user_touchpoints": 2}
        candidate_b_metrics = {"user_touchpoints": 1}
        candidate_a_ref = evidence_ref(
            root,
            "evidence/candidate-a.json",
            {
                "schema_version": "1.0",
                "candidate_id": "candidate-a",
                "path_fingerprint": candidate_a_fingerprint,
                "hard_constraints_pass": True,
                "metrics": candidate_a_metrics,
                "result_summary": "The two-touchpoint path passed all hard constraints.",
            },
        )
        candidate_b_ref = evidence_ref(
            root,
            "evidence/candidate-b.json",
            {
                "schema_version": "1.0",
                "candidate_id": "candidate-b",
                "path_fingerprint": candidate_b_fingerprint,
                "hard_constraints_pass": True,
                "metrics": candidate_b_metrics,
                "result_summary": "The one-touchpoint path passed all hard constraints.",
            },
        )
        spec["optimization"].update(
            {
                "claim": "SHORTEST_AMONG_TESTED_CANDIDATES",
                "comparison_metric": "user_touchpoints",
                "selected_candidate_id": selected,
                "candidate_paths": [
                    {
                        "id": "candidate-a",
                        "status": "PASS",
                        "hard_constraints_pass": True,
                        **candidate_a_path,
                        "path_fingerprint": candidate_a_fingerprint,
                        "metrics": candidate_a_metrics,
                        "evidence": [candidate_a_ref],
                    },
                    {
                        "id": "candidate-b",
                        "status": "PASS",
                        "hard_constraints_pass": True,
                        **candidate_b_path,
                        "path_fingerprint": candidate_b_fingerprint,
                        "metrics": candidate_b_metrics,
                        "evidence": [candidate_b_ref],
                    },
                ],
            }
        )

    golden_path = root / "golden" / "REFERENCE.json"
    golden = json.loads(golden_path.read_text(encoding="utf-8"))
    golden.update(
        {
            "status": "PASS",
            "input_summary": "Frozen representative input",
            "expected_outcome": "Accepted representative output",
            "evidence": [golden_ref],
            "protected_invariants": ["result", "authorization", "traceability"],
        }
    )

    workflow_md = f"""# Sample workflow

<!-- workflow:status={spec["status"]} -->
<!-- workflow:optimization-claim={spec["optimization"]["claim"]} -->

<!-- workflow:short-path -->
## Short path
Freeze evidence → build → verify.
<!-- workflow:success-contract -->
## Success
The accepted artifact is reproduced.
<!-- workflow:scope -->
## Scope
Local, reversible fixtures only.
<!-- workflow:io -->
## Input and output
Frozen input to accepted output.
<!-- workflow:execution -->
## Execution
Run the single bound step.
<!-- workflow:gates -->
## Gates
Quality gate blocks mismatches.
<!-- workflow:branches -->
## Branches
No conditional branch in this fixture.
<!-- workflow:stop-recovery -->
## Stop and recovery
Stop before external writes.
<!-- workflow:validation -->
## Validation
Evidence-bound replay and forward test.
"""
    (root / "WORKFLOW.md").write_text(workflow_md, encoding="utf-8", newline="\n")
    (root / "DETOURS_AND_GUARDRAILS.md").write_text(
        "# Detours and guardrails\n\nA reproducible detour is blocked by the quality gate.\n",
        encoding="utf-8",
        newline="\n",
    )
    (root / "QA.md").write_text(
        "# QA\n\nGolden, negative, boundary, command, and forward evidence are bound.\n",
        encoding="utf-8",
        newline="\n",
    )
    (root / "CHANGE_POLICY.md").write_text(
        "# Change policy\n\nRe-run bound validation after every definition change.\n",
        encoding="utf-8",
        newline="\n",
    )
    write_json(spec_path, spec)
    write_json(cases_path, cases_doc)
    write_json(golden_path, golden)

    digest = definition_digest(root)
    at = datetime.now().astimezone().isoformat(timespec="seconds")
    forward = {
        "schema_version": "1.0",
        "workflow_id": spec["workflow_id"],
        "workflow_version": spec["version"],
        "status": "PASS",
        "independent_executor": "independent-evaluator-01",
        "input_summary_sha256": hashlib.sha256(b"independent raw input").hexdigest(),
        "workflow_definition_sha256": digest,
        "started_at": at,
        "completed_at": at,
        "result_summary": "Independent replay produced the accepted observable result.",
    }
    write_json(root / "evidence" / "FORWARD_TEST.json", forward)


def bind_commands(root: Path) -> int:
    return run(str(RUNNER), str(root), "--execute").returncode


def refresh_forward_digest(root: Path) -> None:
    spec = json.loads((root / "WORKFLOW_SPEC.json").read_text(encoding="utf-8"))
    forward_path = root / "evidence" / "FORWARD_TEST.json"
    forward = json.loads(forward_path.read_text(encoding="utf-8"))
    forward["workflow_version"] = spec["version"]
    forward["workflow_definition_sha256"] = definition_digest(root)
    write_json(forward_path, forward)


def create_export_artifact(root: Path) -> tuple[str, dict[str, str]]:
    artifact_root = root / "exported-skill" / "sample-skill"
    (artifact_root / "agents").mkdir(parents=True, exist_ok=True)
    (artifact_root / "SKILL.md").write_text(
        "---\nname: sample-skill\ndescription: Reuse an evidenced sample workflow.\n---\n\n"
        "# Sample skill\n\nPreserve the accepted result and authorization boundary.\n",
        encoding="utf-8",
        newline="\n",
    )
    (artifact_root / "agents" / "openai.yaml").write_text(
        'interface:\n  display_name: "Sample Skill"\n'
        '  short_description: "Reuse an evidenced and redacted workflow"\n'
        '  default_prompt: "Use $sample-skill to repeat the verified task."\n',
        encoding="utf-8",
        newline="\n",
    )
    relative_root = "exported-skill/sample-skill"
    files = [
        {
            "path": path.relative_to(artifact_root).as_posix(),
            "sha256": sha256_file(path),
        }
        for path in sorted(artifact_root.rglob("*"))
        if path.is_file()
    ]
    manifest = {
        "schema_version": "1.0",
        "artifact_root": relative_root,
        "created_at": datetime.now().astimezone().isoformat(timespec="seconds"),
        "files": files,
    }
    return relative_root, evidence_ref(
        root, "evidence/skill-export-manifest.json", manifest
    )


def source_workflow(
    root: Path,
    project_id: str,
    workflow_id: str,
    digest_char: str,
    *,
    valid_receipt: bool = True,
) -> dict[str, object]:
    digest = digest_char * 64
    receipt: object
    if valid_receipt:
        receipt = {
            "schema_version": "1.0",
            "project_id": project_id,
            "workflow_id": workflow_id,
            "workflow_version": "1.0.0",
            "status": "VERIFIED",
            "workflow_definition_sha256": digest,
            "strict_qa_result": "PASS",
            "verified_at": datetime.now().astimezone().isoformat(timespec="seconds"),
            "result_summary": "Independent replay and strict QA passed in the declared scope.",
        }
    else:
        receipt = {"claimed": "verified but not bound to a source workflow"}
    receipt_ref = evidence_ref(
        root, f"evidence/source-workflows/{project_id}.json", receipt
    )
    return {
        "project_id": project_id,
        "workflow_id": workflow_id,
        "workflow_version": "1.0.0",
        "workflow_definition_sha256": digest,
        "verification_status": "VERIFIED",
        "evidence": receipt_ref,
    }


def configure_skill_export(root: Path, *, valid_sources: bool) -> None:
    artifact_root, manifest_ref = create_export_artifact(root)
    sources = [
        source_workflow(
            root,
            "source-project-a",
            "source-workflow-a",
            "a",
            valid_receipt=valid_sources,
        )
    ]
    classification = "POLICY"
    if valid_sources:
        sources.append(
            source_workflow(
                root,
                "source-project-b",
                "source-workflow-b",
                "b",
                valid_receipt=True,
            )
        )
        classification = "EMPIRICAL"
    spec_path = root / "WORKFLOW_SPEC.json"
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    spec["skill_export"] = {
        "requested": True,
        "artifact_root": artifact_root,
        "artifact_manifest": manifest_ref,
        "source_workflows": sources,
        "rules": [
            {
                "rule_id": "preserve-accepted-result",
                "classification": classification,
                "source_project_ids": [row["project_id"] for row in sources],
                "generalization_basis": "The rule is supported by the declared sources.",
                "redaction_status": "PASS",
            }
        ],
    }
    write_json(spec_path, spec)
    refresh_forward_digest(root)


def refresh_export_manifest(root: Path) -> None:
    spec_path = root / "WORKFLOW_SPEC.json"
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    export = spec["skill_export"]
    artifact_root = root / export["artifact_root"]
    manifest_path = root / export["artifact_manifest"]["path"]
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["files"] = [
        {
            "path": path.relative_to(artifact_root).as_posix(),
            "sha256": sha256_file(path),
        }
        for path in sorted(artifact_root.rglob("*"))
        if path.is_file()
    ]
    write_json(manifest_path, manifest)
    export["artifact_manifest"]["sha256"] = sha256_file(manifest_path)
    write_json(spec_path, spec)
    refresh_forward_digest(root)


def main() -> int:
    results: dict[str, int] = {}
    with tempfile.TemporaryDirectory(prefix="workflow_skill_selftest_") as temp_name:
        temp = Path(temp_name)
        draft = temp / "draft"
        results["create_draft"] = create_pack(draft, "sample-workflow")
        results["refuse_overwrite"] = create_pack(draft, "sample-workflow")
        results["structure_draft"] = run(str(QA_PACK), str(draft)).returncode
        results["strict_rejects_draft"] = run(str(QA_PACK), str(draft), "--strict").returncode

        draft_with_claim = temp / "draft-with-claim"
        shutil.copytree(draft, draft_with_claim)
        draft_spec_path = draft_with_claim / "WORKFLOW_SPEC.json"
        draft_spec = json.loads(draft_spec_path.read_text(encoding="utf-8"))
        draft_spec["optimization"]["claim"] = "IRREDUCIBLE_WITHIN_VALIDATED_SCOPE"
        write_json(draft_spec_path, draft_spec)
        results["structure_rejects_draft_optimization_claim"] = run(
            str(QA_PACK), str(draft_with_claim)
        ).returncode

        verified = temp / "verified"
        create_pack(verified, "verified-workflow")
        complete_fixture(verified)
        results["runner_executes_commands"] = bind_commands(verified)
        results["strict_accepts_verified"] = run(str(QA_PACK), str(verified), "--strict").returncode
        results["optimization_is_separate"] = run(
            str(QA_PACK), str(verified), "--require-optimization"
        ).returncode

        unproven_heading = temp / "unproven-shortest-heading"
        create_pack(unproven_heading, "unproven-shortest-heading-workflow")
        complete_fixture(unproven_heading)
        heading_path = unproven_heading / "WORKFLOW.md"
        heading_text = heading_path.read_text(encoding="utf-8").replace(
            "## Short path", "## 最短用户路径"
        )
        heading_path.write_text(heading_text, encoding="utf-8", newline="\n")
        refresh_forward_digest(unproven_heading)
        bind_commands(unproven_heading)
        results["strict_rejects_unproven_shortest_heading"] = run(
            str(QA_PACK), str(unproven_heading), "--strict"
        ).returncode

        unproven_body = temp / "unproven-shortest-body"
        create_pack(unproven_body, "unproven-shortest-body-workflow")
        complete_fixture(unproven_body)
        body_path = unproven_body / "WORKFLOW.md"
        body_text = body_path.read_text(encoding="utf-8").replace(
            "Freeze evidence → build → verify.", "这是最短用户路径。"
        )
        body_path.write_text(body_text, encoding="utf-8", newline="\n")
        refresh_forward_digest(unproven_body)
        bind_commands(unproven_body)
        results["strict_rejects_unproven_shortest_body"] = run(
            str(QA_PACK), str(unproven_body), "--strict"
        ).returncode

        plan_only = temp / "plan-only"
        create_pack(plan_only, "plan-only-workflow")
        complete_fixture(plan_only)
        plan_spec_path = plan_only / "WORKFLOW_SPEC.json"
        plan_spec = json.loads(plan_spec_path.read_text(encoding="utf-8"))
        plan_spec["validation"]["commands"][0]["argv"] = [
            "python",
            "-c",
            "from pathlib import Path; Path('plan-only-side-effect.txt').write_text('ran')",
        ]
        write_json(plan_spec_path, plan_spec)
        refresh_forward_digest(plan_only)
        plan_result = run(str(RUNNER), str(plan_only))
        results["runner_defaults_to_plan_only"] = (
            0
            if plan_result.returncode == 2
            and not (plan_only / "plan-only-side-effect.txt").exists()
            and not (plan_only / "evidence" / "commands" / "smoke.json").exists()
            else 99
        )

        missing = temp / "missing-evidence"
        shutil.copytree(verified, missing)
        (missing / "evidence" / "source-run.json").unlink()
        results["strict_rejects_missing_evidence"] = run(
            str(QA_PACK), str(missing), "--strict"
        ).returncode

        tampered = temp / "tampered-definition"
        shutil.copytree(verified, tampered)
        with (tampered / "WORKFLOW.md").open("a", encoding="utf-8") as handle:
            handle.write("\nChanged after validation.\n")
        results["strict_rejects_stale_digest"] = run(
            str(QA_PACK), str(tampered), "--strict"
        ).returncode

        false_exit = temp / "false-exit"
        shutil.copytree(verified, false_exit)
        command_path = false_exit / "evidence" / "commands" / "smoke.json"
        command = json.loads(command_path.read_text(encoding="utf-8"))
        command["exit_code"] = False
        write_json(command_path, command)
        results["strict_rejects_boolean_exit"] = run(
            str(QA_PACK), str(false_exit), "--strict"
        ).returncode

        forged_version = temp / "forged-runner-version"
        shutil.copytree(verified, forged_version)
        forged_path = forged_version / "evidence" / "commands" / "smoke.json"
        forged = json.loads(forged_path.read_text(encoding="utf-8"))
        forged["runner_version"] = "forged"
        write_json(forged_path, forged)
        results["strict_rejects_forged_runner_version"] = run(
            str(QA_PACK), str(forged_version), "--strict"
        ).returncode

        forged_hash = temp / "forged-runner-hash"
        shutil.copytree(verified, forged_hash)
        forged_hash_path = forged_hash / "evidence" / "commands" / "smoke.json"
        forged_record = json.loads(forged_hash_path.read_text(encoding="utf-8"))
        forged_record["runner_script_sha256"] = "0" * 64
        write_json(forged_hash_path, forged_record)
        results["strict_rejects_forged_runner_hash"] = run(
            str(QA_PACK), str(forged_hash), "--strict"
        ).returncode

        malformed = temp / "malformed"
        shutil.copytree(verified, malformed)
        spec_path = malformed / "WORKFLOW_SPEC.json"
        spec = json.loads(spec_path.read_text(encoding="utf-8"))
        spec["optimization"] = []
        write_json(spec_path, spec)
        malformed_run = run(str(QA_PACK), str(malformed))
        results["malformed_shape_structured_fail"] = (
            1 if malformed_run.returncode == 1 and "Traceback" not in malformed_run.stdout else 99
        )

        irreducible = temp / "irreducible"
        create_pack(irreducible, "irreducible-workflow")
        complete_fixture(irreducible, mode="irreducible")
        bind_commands(irreducible)
        results["irreducible_claim_passes"] = run(
            str(QA_PACK), str(irreducible), "--require-optimization"
        ).returncode

        shortest = temp / "shortest"
        create_pack(shortest, "shortest-workflow")
        complete_fixture(shortest, mode="shortest", selected="candidate-b")
        bind_commands(shortest)
        results["shortest_tested_candidate_passes"] = run(
            str(QA_PACK), str(shortest), "--require-optimization"
        ).returncode

        wrong_shortest = temp / "wrong-shortest"
        create_pack(wrong_shortest, "wrong-shortest-workflow")
        complete_fixture(wrong_shortest, mode="shortest", selected="candidate-a")
        bind_commands(wrong_shortest)
        results["nonshortest_candidate_rejected"] = run(
            str(QA_PACK), str(wrong_shortest), "--require-optimization"
        ).returncode

        strict_wrong_shortest = temp / "strict-wrong-shortest"
        create_pack(strict_wrong_shortest, "strict-wrong-shortest-workflow")
        complete_fixture(
            strict_wrong_shortest, mode="shortest", selected="candidate-a"
        )
        bind_commands(strict_wrong_shortest)
        results["strict_auto_rejects_false_shortest_claim"] = run(
            str(QA_PACK), str(strict_wrong_shortest), "--strict"
        ).returncode

        duplicate_candidates = temp / "duplicate-candidate-paths"
        create_pack(duplicate_candidates, "duplicate-candidate-paths-workflow")
        complete_fixture(duplicate_candidates, mode="shortest", selected="candidate-b")
        duplicate_spec_path = duplicate_candidates / "WORKFLOW_SPEC.json"
        duplicate_spec = json.loads(duplicate_spec_path.read_text(encoding="utf-8"))
        candidate_a = duplicate_spec["optimization"]["candidate_paths"][0]
        candidate_b = duplicate_spec["optimization"]["candidate_paths"][1]
        for field in ("step_ids", "branch_ids", "gate_ids", "configuration"):
            candidate_a[field] = candidate_b[field]
        normalized_duplicate = {
            field: candidate_a[field]
            for field in ("step_ids", "branch_ids", "gate_ids", "configuration")
        }
        candidate_a["path_fingerprint"] = canonical_json_sha256(normalized_duplicate)
        candidate_a_receipt_path = duplicate_candidates / candidate_a["evidence"][0]["path"]
        candidate_a_receipt = json.loads(
            candidate_a_receipt_path.read_text(encoding="utf-8")
        )
        candidate_a_receipt["path_fingerprint"] = candidate_a["path_fingerprint"]
        candidate_a_receipt["metrics"] = candidate_a["metrics"]
        write_json(candidate_a_receipt_path, candidate_a_receipt)
        candidate_a["evidence"][0]["sha256"] = sha256_file(candidate_a_receipt_path)
        write_json(duplicate_spec_path, duplicate_spec)
        refresh_forward_digest(duplicate_candidates)
        bind_commands(duplicate_candidates)
        results["strict_rejects_duplicate_candidate_paths"] = run(
            str(QA_PACK), str(duplicate_candidates), "--strict"
        ).returncode

        unselected_gate_case = temp / "unselected-gate-case"
        create_pack(unselected_gate_case, "unselected-gate-case-workflow")
        complete_fixture(unselected_gate_case)
        gate_spec_path = unselected_gate_case / "WORKFLOW_SPEC.json"
        gate_spec = json.loads(gate_spec_path.read_text(encoding="utf-8"))
        gate_spec["gates"][0]["case_ids"] = ["negative-002"]
        write_json(gate_spec_path, gate_spec)
        gate_cases_path = unselected_gate_case / "tests" / "CASES.json"
        gate_cases = json.loads(gate_cases_path.read_text(encoding="utf-8"))
        for row in gate_cases["cases"]:
            if row["case_id"] in {"negative-001", "boundary-001"}:
                row["covers_gate_ids"] = []
        gate_cases["cases"].append(
            {
                "case_id": "negative-002",
                "kind": "NEGATIVE",
                "status": "PASS",
                "request": "Exercise an undeclared invalid path.",
                "expected": "The gate blocks it.",
                "covers_step_ids": ["build-output"],
                "covers_gate_ids": ["quality-gate"],
                "covers_branch_ids": [],
                "actual_evidence": [],
            }
        )
        write_json(gate_cases_path, gate_cases)
        refresh_forward_digest(unselected_gate_case)
        bind_commands(unselected_gate_case)
        results["strict_rejects_unselected_unevidenced_gate_case"] = run(
            str(QA_PACK), str(unselected_gate_case), "--strict"
        ).returncode

        asymmetric_branch = temp / "asymmetric-branch"
        create_pack(asymmetric_branch, "asymmetric-branch-workflow")
        complete_fixture(asymmetric_branch)
        branch_spec_path = asymmetric_branch / "WORKFLOW_SPEC.json"
        branch_spec = json.loads(branch_spec_path.read_text(encoding="utf-8"))
        branch_spec["steps"].append(
            {
                "id": "optional-action",
                "title": "Run the optional action",
                "kind": "CONDITIONAL",
                "executor": "AI",
                "side_effect": "REVERSIBLE_LOCAL",
                "inputs": ["accepted artifact"],
                "outputs": ["optional artifact"],
                "exit_criteria": ["optional artifact exists"],
                "gate_ids": ["quality-gate"],
                "branch_id": "optional-branch",
            }
        )
        branch_spec["gates"][0]["step_ids"].append("optional-action")
        branch_spec["conditional_branches"] = [
            {
                "id": "optional-branch",
                "when": "The optional output is requested.",
                "step_ids": ["build-output"],
                "gate_ids": ["quality-gate"],
                "case_ids": ["boundary-001"],
            }
        ]
        write_json(branch_spec_path, branch_spec)
        branch_cases_path = asymmetric_branch / "tests" / "CASES.json"
        branch_cases = json.loads(branch_cases_path.read_text(encoding="utf-8"))
        for row in branch_cases["cases"]:
            if row["case_id"] == "boundary-001":
                row["covers_branch_ids"] = ["optional-branch"]
        write_json(branch_cases_path, branch_cases)
        refresh_forward_digest(asymmetric_branch)
        bind_commands(asymmetric_branch)
        results["strict_rejects_asymmetric_branch_binding"] = run(
            str(QA_PACK), str(asymmetric_branch), "--strict"
        ).returncode

        invalid_export = temp / "invalid-skill-export"
        create_pack(invalid_export, "invalid-skill-export-workflow")
        complete_fixture(invalid_export)
        configure_skill_export(invalid_export, valid_sources=False)
        bind_commands(invalid_export)
        results["strict_rejects_unbound_skill_source"] = run(
            str(QA_PACK), str(invalid_export), "--strict"
        ).returncode

        valid_export = temp / "valid-skill-export"
        create_pack(valid_export, "valid-skill-export-workflow")
        complete_fixture(valid_export)
        configure_skill_export(valid_export, valid_sources=True)
        bind_commands(valid_export)
        results["strict_accepts_evidenced_skill_export"] = run(
            str(QA_PACK), str(valid_export), "--strict"
        ).returncode

        leaking_export = temp / "leaking-skill-export"
        create_pack(leaking_export, "leaking-skill-export-workflow")
        complete_fixture(leaking_export)
        configure_skill_export(leaking_export, valid_sources=True)
        leaking_skill = leaking_export / "exported-skill" / "sample-skill" / "SKILL.md"
        with leaking_skill.open("a", encoding="utf-8") as handle:
            handle.write("\nSource: source-project-a; contact alice@example.com.\n")
        refresh_export_manifest(leaking_export)
        bind_commands(leaking_export)
        results["strict_rejects_private_skill_export_content"] = run(
            str(QA_PACK), str(leaking_export), "--strict"
        ).returncode

    expected = {
        "create_draft": 0,
        "refuse_overwrite": 1,
        "structure_draft": 0,
        "strict_rejects_draft": 1,
        "structure_rejects_draft_optimization_claim": 1,
        "runner_executes_commands": 0,
        "strict_accepts_verified": 0,
        "optimization_is_separate": 1,
        "strict_rejects_unproven_shortest_heading": 1,
        "strict_rejects_unproven_shortest_body": 1,
        "runner_defaults_to_plan_only": 0,
        "strict_rejects_missing_evidence": 1,
        "strict_rejects_stale_digest": 1,
        "strict_rejects_boolean_exit": 1,
        "strict_rejects_forged_runner_version": 1,
        "strict_rejects_forged_runner_hash": 1,
        "malformed_shape_structured_fail": 1,
        "irreducible_claim_passes": 0,
        "shortest_tested_candidate_passes": 0,
        "nonshortest_candidate_rejected": 1,
        "strict_auto_rejects_false_shortest_claim": 1,
        "strict_rejects_duplicate_candidate_paths": 1,
        "strict_rejects_unselected_unevidenced_gate_case": 1,
        "strict_rejects_asymmetric_branch_binding": 1,
        "strict_rejects_unbound_skill_source": 1,
        "strict_accepts_evidenced_skill_export": 0,
        "strict_rejects_private_skill_export_content": 1,
    }
    passed = results == expected
    print(
        json.dumps(
            {"result": "PASS" if passed else "FAIL", "actual": results, "expected": expected},
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
