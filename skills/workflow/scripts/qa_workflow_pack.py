#!/usr/bin/env python3
"""Validate workflow structure, evidence binding, coverage, and optional optimization claims."""

from __future__ import annotations

import argparse
import json
import re
from datetime import datetime
from pathlib import Path
from typing import Any

from workflow_pack_lib import (
    SHA256_RE,
    canonical_json_sha256,
    definition_digest,
    load_json_object,
    resolve_pack_path,
    sha256_file,
    verify_evidence_ref,
)


REQUIRED_FILES = (
    "WORKFLOW.md",
    "WORKFLOW_SPEC.json",
    "DETOURS_AND_GUARDRAILS.md",
    "QA.md",
    "CHANGE_POLICY.md",
    "golden/REFERENCE.json",
    "tests/CASES.json",
    "evidence/FORWARD_TEST.json",
)
WORKFLOW_MARKERS = (
    "<!-- workflow:short-path -->",
    "<!-- workflow:success-contract -->",
    "<!-- workflow:scope -->",
    "<!-- workflow:io -->",
    "<!-- workflow:execution -->",
    "<!-- workflow:gates -->",
    "<!-- workflow:branches -->",
    "<!-- workflow:stop-recovery -->",
    "<!-- workflow:validation -->",
)
HARD_CONSTRAINTS = {
    "outcome_correctness",
    "authorization_and_safety",
    "traceability_and_repeatability",
}
ALLOWED_STATUS = {"DRAFT", "LOCALLY_VALIDATED", "VERIFIED", "DEPRECATED"}
ALLOWED_CLAIMS = {
    "UNASSESSED",
    "IRREDUCIBLE_WITHIN_VALIDATED_SCOPE",
    "SHORTEST_AMONG_TESTED_CANDIDATES",
}
ALLOWED_STEP_KINDS = {"INVARIANT", "DEFAULT", "CONDITIONAL"}
ALLOWED_EXECUTORS = {"USER", "AI", "AUTOMATED", "EXTERNAL"}
ALLOWED_SIDE_EFFECTS = {
    "NONE",
    "REVERSIBLE_LOCAL",
    "IRREVERSIBLE_LOCAL",
    "EXTERNAL_WRITE",
}
ALLOWED_GATE_TYPES = {
    "QUALITY",
    "SCOPE",
    "AUTHORIZATION",
    "SAFETY",
    "PRIVACY",
    "RELEASE",
    "TECHNICAL",
}
ALLOWED_CASE_KINDS = {"GOLDEN", "NEGATIVE", "BOUNDARY", "ABLATION"}
UNRESOLVED = re.compile(r"\{\{[^}]+\}\}|__UNRESOLVED__|\[TODO:[^\]]*\]")
ID_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
PROJECT_ID_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
SEMVER_PATTERN = re.compile(r"^\d+\.\d+\.\d+$")
WINDOWS_PATH = re.compile(r"(?:^|[\s\"'])(?:[A-Za-z]:[\\/]|\\\\)")
EXPECTED_RUNNER_VERSION = "1.0.0"
SOURCE_RECEIPT_SCHEMA_VERSION = "1.0"
ARTIFACT_MANIFEST_SCHEMA_VERSION = "1.0"
STATUS_MARKER = re.compile(r"<!--\s*workflow:status=([A-Z_]+)\s*-->")
CLAIM_MARKER = re.compile(
    r"<!--\s*workflow:optimization-claim=([A-Z_]+)\s*-->"
)
UNPROVEN_PATH_CLAIM = re.compile(r"最短|最优|\bshortest\b|\boptimal\b", re.IGNORECASE)
UNPROVEN_VALIDATION_CLAIM = re.compile(
    r"(?:已经|已|这是|本路径是|结论为).{0,12}(?:最短|最优)"
    r"|\b(?:is|proven)\s+(?:the\s+)?(?:shortest|optimal)\b",
    re.IGNORECASE,
)
EMAIL_PATTERN = re.compile(
    r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b", re.IGNORECASE
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate a $workflow pack.")
    parser.add_argument("project_root")
    parser.add_argument("--strict", action="store_true")
    parser.add_argument(
        "--require-optimization",
        action="store_true",
        help="Also require an evidenced irreducibility or tested-candidate claim.",
    )
    return parser.parse_args()


def nonblank(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def nonempty_list(value: Any) -> bool:
    return isinstance(value, list) and len(value) > 0


def is_plain_number(value: Any) -> bool:
    return type(value) in {int, float}


def parse_iso(value: Any) -> bool:
    if not nonblank(value):
        return False
    try:
        datetime.fromisoformat(value.replace("Z", "+00:00"))
        return True
    except ValueError:
        return False


def marked_section(text: str, start: str, end: str | None = None) -> str:
    start_at = text.find(start)
    if start_at < 0:
        return ""
    start_at += len(start)
    if end is None:
        return text[start_at:]
    end_at = text.find(end, start_at)
    return text[start_at:] if end_at < 0 else text[start_at:end_at]


def dict_node(parent: dict[str, Any], key: str, failures: list[str]) -> dict[str, Any]:
    value = parent.get(key)
    if isinstance(value, dict):
        return value
    failures.append(f"{key} must be an object")
    return {}


def list_node(parent: dict[str, Any], key: str, failures: list[str]) -> list[Any]:
    value = parent.get(key)
    if isinstance(value, list):
        return value
    failures.append(f"{key} must be an array")
    return []


def load_json(path: Path, failures: list[str]) -> dict[str, Any]:
    try:
        return load_json_object(path)
    except Exception as exc:
        failures.append(f"invalid JSON {path.name}: {exc}")
        return {}


def verify_refs(
    root: Path,
    refs: Any,
    label: str,
    passes: list[str],
    failures: list[str],
    *,
    required: bool = True,
) -> bool:
    if not isinstance(refs, list) or (required and not refs):
        failures.append(f"{label} must be a non-empty evidence-reference array")
        return False
    ok = True
    for index, ref in enumerate(refs):
        valid, detail = verify_evidence_ref(root, ref)
        if not valid:
            failures.append(f"{label}[{index}]: {detail}")
            ok = False
    if ok:
        passes.append(f"{label} files and hashes")
    return ok


def main() -> int:
    args = parse_args()
    strict = args.strict or args.require_optimization
    root = Path(args.project_root).resolve()
    passes: list[str] = []
    failures: list[str] = []

    if not root.is_dir():
        return emit(strict, args.require_optimization, passes, [f"workflow pack does not exist: {root}"])

    for relative in REQUIRED_FILES:
        path = root / relative
        if path.is_file() and path.stat().st_size > 0:
            passes.append(f"required file: {relative}")
        else:
            failures.append(f"missing or empty required file: {relative}")
    if failures:
        return emit(strict, args.require_optimization, passes, failures)

    spec = load_json(root / "WORKFLOW_SPEC.json", failures)
    golden = load_json(root / "golden" / "REFERENCE.json", failures)
    cases_doc = load_json(root / "tests" / "CASES.json", failures)
    forward_doc = load_json(root / "evidence" / "FORWARD_TEST.json", failures)
    if failures:
        return emit(strict, args.require_optimization, passes, failures)

    source_run = dict_node(spec, "source_run", failures)
    success = dict_node(spec, "success_contract", failures)
    scope = dict_node(spec, "validated_scope", failures)
    optimization = dict_node(spec, "optimization", failures)
    skill_export = dict_node(spec, "skill_export", failures)
    validation = dict_node(spec, "validation", failures)
    steps = list_node(spec, "steps", failures)
    gates = list_node(spec, "gates", failures)
    branches = list_node(spec, "conditional_branches", failures)
    case_rows = list_node(cases_doc, "cases", failures)

    validate_metadata(spec, golden, cases_doc, passes, failures)
    validate_basic_enums(spec, optimization, skill_export, passes, failures)
    cases_by_id = index_cases(case_rows, passes, failures)

    workflow_text = (root / "WORKFLOW.md").read_text(encoding="utf-8")
    missing_markers = [marker for marker in WORKFLOW_MARKERS if marker not in workflow_text]
    if missing_markers:
        failures.append(f"WORKFLOW.md missing contract markers: {', '.join(missing_markers)}")
    else:
        passes.append("WORKFLOW.md section contract")
    status_markers = STATUS_MARKER.findall(workflow_text)
    claim_markers = CLAIM_MARKER.findall(workflow_text)
    if status_markers == [spec.get("status")]:
        passes.append("WORKFLOW.md status matches the machine spec")
    else:
        failures.append("WORKFLOW.md must contain one status marker matching the machine spec")
    if claim_markers == [optimization.get("claim")]:
        passes.append("WORKFLOW.md optimization claim matches the machine spec")
    else:
        failures.append(
            "WORKFLOW.md must contain one optimization marker matching the machine spec"
        )
    short_path_text = marked_section(
        workflow_text,
        "<!-- workflow:short-path -->",
        "<!-- workflow:success-contract -->",
    )
    validation_text = marked_section(workflow_text, "<!-- workflow:validation -->")
    if optimization.get("claim") != "SHORTEST_AMONG_TESTED_CANDIDATES" and (
        UNPROVEN_PATH_CLAIM.search(short_path_text)
        or UNPROVEN_VALIDATION_CLAIM.search(validation_text)
    ):
        failures.append(
            "WORKFLOW.md contains an unproven affirmative shortest/optimal claim"
        )
    else:
        passes.append("WORKFLOW.md wording respects the optimization evidence level")
    if (
        optimization.get("claim") != "SHORTEST_AMONG_TESTED_CANDIDATES"
        and re.search(r"^##\s+最短用户路径\s*$", workflow_text, flags=re.MULTILINE)
    ):
        failures.append(
            "WORKFLOW.md cannot claim a shortest user path without a tested-candidate claim"
        )
    else:
        passes.append("user path heading matches the optimization claim")

    definition_text = "\n".join(
        (root / relative).read_text(encoding="utf-8") for relative in REQUIRED_FILES
    )
    if "{{" in definition_text:
        failures.append("unresolved template token found")
    else:
        passes.append("no unresolved template tokens")

    if strict:
        try:
            digest = definition_digest(root)
        except Exception as exc:
            failures.append(str(exc))
            digest = ""
        strict_validate(
            root,
            spec,
            source_run,
            success,
            scope,
            optimization,
            skill_export,
            validation,
            steps,
            gates,
            branches,
            golden,
            forward_doc,
            cases_by_id,
            definition_text,
            digest,
            passes,
            failures,
        )
        claim = optimization.get("claim")
        if claim != "UNASSESSED" or args.require_optimization:
            validate_optimization_claim(
                root,
                optimization,
                steps,
                cases_by_id,
                passes,
                failures,
            )

    return emit(strict, args.require_optimization, passes, failures)


def validate_metadata(
    spec: dict[str, Any],
    golden: dict[str, Any],
    cases_doc: dict[str, Any],
    passes: list[str],
    failures: list[str],
) -> None:
    if spec.get("schema_version") == "1.1":
        passes.append("spec schema_version")
    else:
        failures.append("WORKFLOW_SPEC schema_version must be 1.1")
    workflow_id = spec.get("workflow_id")
    if nonblank(workflow_id) and ID_PATTERN.fullmatch(workflow_id):
        passes.append("workflow_id format")
    else:
        failures.append("workflow_id must use lowercase letters, digits, and hyphens")
    if nonblank(spec.get("title")):
        passes.append("title")
    else:
        failures.append("title must be non-empty")
    if nonblank(spec.get("version")) and SEMVER_PATTERN.fullmatch(spec["version"]):
        passes.append("semantic version")
    else:
        failures.append("version must use x.y.z")
    if parse_iso(spec.get("created_at")):
        passes.append("created_at ISO-8601")
    else:
        failures.append("created_at must be ISO-8601")
    source_project_id = spec.get("source_project_id")
    if nonblank(source_project_id) and PROJECT_ID_PATTERN.fullmatch(source_project_id):
        passes.append("stable source_project_id")
    else:
        failures.append("source_project_id must be a stable ID, not a local path")
    if (
        golden.get("schema_version") == "1.1"
        and cases_doc.get("schema_version") == "1.1"
    ):
        passes.append("golden and cases schema_version")
    else:
        failures.append("golden and cases schema_version must be 1.1")
    if golden.get("workflow_id") == workflow_id == cases_doc.get("workflow_id"):
        passes.append("workflow_id consistent across JSON files")
    else:
        failures.append("workflow_id mismatch across spec, golden, and cases")


def validate_basic_enums(
    spec: dict[str, Any],
    optimization: dict[str, Any],
    skill_export: dict[str, Any],
    passes: list[str],
    failures: list[str],
) -> None:
    status = spec.get("status")
    claim = optimization.get("claim")
    if status in ALLOWED_STATUS:
        passes.append("status enum")
    else:
        failures.append(f"invalid status: {status!r}")
    if claim in ALLOWED_CLAIMS:
        passes.append("optimization claim enum")
    else:
        failures.append(f"invalid optimization claim: {claim!r}")
    constraints = optimization.get("hard_constraints")
    if isinstance(constraints, list) and set(constraints) == HARD_CONSTRAINTS:
        passes.append("hard optimization constraints")
    else:
        failures.append("hard_constraints must preserve correctness, safety, and traceability")
    if type(skill_export.get("requested")) is bool:
        passes.append("skill_export requested boolean")
    else:
        failures.append("skill_export.requested must be boolean")
    if status != "VERIFIED" and claim != "UNASSESSED":
        failures.append(
            "only VERIFIED workflows may carry a current optimization claim"
        )


def index_cases(
    rows: list[Any], passes: list[str], failures: list[str]
) -> dict[str, dict[str, Any]]:
    indexed: dict[str, dict[str, Any]] = {}
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            failures.append(f"cases[{index}] must be an object")
            continue
        case_id = row.get("case_id")
        if not nonblank(case_id) or not ID_PATTERN.fullmatch(case_id):
            failures.append(f"cases[{index}] invalid case_id")
            continue
        if case_id in indexed:
            failures.append(f"duplicate case_id: {case_id}")
            continue
        if row.get("kind") not in ALLOWED_CASE_KINDS:
            failures.append(f"cases[{index}] invalid kind")
        indexed[case_id] = row
    kinds = {row.get("kind") for row in indexed.values()}
    if {"GOLDEN", "NEGATIVE", "BOUNDARY"}.issubset(kinds):
        passes.append("golden, negative, and boundary cases present")
    else:
        failures.append("tests must include GOLDEN, NEGATIVE, and BOUNDARY cases")
    return indexed


def strict_validate(
    root: Path,
    spec: dict[str, Any],
    source_run: dict[str, Any],
    success: dict[str, Any],
    scope: dict[str, Any],
    optimization: dict[str, Any],
    skill_export: dict[str, Any],
    validation: dict[str, Any],
    steps: list[Any],
    gates: list[Any],
    branches: list[Any],
    golden: dict[str, Any],
    forward_doc: dict[str, Any],
    cases_by_id: dict[str, dict[str, Any]],
    all_text: str,
    digest: str,
    passes: list[str],
    failures: list[str],
) -> None:
    if spec.get("status") == "VERIFIED":
        passes.append("strict status VERIFIED")
    else:
        failures.append("strict mode requires status VERIFIED")
    if not UNRESOLVED.search(all_text):
        passes.append("no unresolved scaffold markers")
    else:
        failures.append("strict mode found an unresolved scaffold marker")

    if source_run.get("status") == "PASS":
        passes.append("source run status PASS")
    else:
        failures.append("source_run.status must be PASS")
    verify_refs(root, source_run.get("evidence"), "source_run.evidence", passes, failures)
    artifact_hashes = source_run.get("artifact_hashes")
    if nonempty_list(artifact_hashes) and all(
        isinstance(value, str)
        and value.startswith("sha256:")
        and SHA256_RE.fullmatch(value[7:])
        for value in artifact_hashes
    ):
        passes.append("source run artifact hashes")
    else:
        failures.append("source_run.artifact_hashes requires sha256:<64 hex>")

    if nonblank(success.get("observable_outcome")):
        passes.append("observable success outcome")
    else:
        failures.append("success_contract.observable_outcome must be non-empty")
    if isinstance(success.get("scope_in"), list) and isinstance(success.get("scope_out"), list):
        passes.append("success scope arrays")
    else:
        failures.append("success scope_in and scope_out must be arrays")
    verify_refs(
        root,
        success.get("acceptance_evidence"),
        "success_contract.acceptance_evidence",
        passes,
        failures,
    )

    for field in ("input_types", "environments", "scale_bounds", "risk_levels"):
        values = scope.get(field)
        if nonempty_list(values) and all(nonblank(value) for value in values):
            passes.append(f"validated_scope.{field}")
        else:
            failures.append(f"validated_scope.{field} must be a non-empty string array")
    if isinstance(scope.get("unverified_conditions"), list):
        passes.append("validated_scope.unverified_conditions explicit")
    else:
        failures.append("validated_scope.unverified_conditions must be an array")

    validate_secondary_objectives(optimization, passes, failures)
    for field in ("inputs", "outputs", "steps", "gates", "stop_conditions"):
        if nonempty_list(spec.get(field)):
            passes.append(f"non-empty {field}")
        else:
            failures.append(f"strict mode requires non-empty {field}")

    step_map, gate_map, branch_map = validate_execution_contracts(
        root, validation, steps, gates, branches, cases_by_id, passes, failures
    )
    validate_selected_cases(root, validation, cases_by_id, passes, failures)
    validate_golden(root, golden, validation, passes, failures)
    validate_forward_test(spec, validation, forward_doc, digest, passes, failures)
    validate_command_evidence(root, spec, validation, digest, passes, failures)
    validate_skill_export(root, spec, skill_export, passes, failures)

    # Silence unused-map warnings while retaining maps for readable diagnostics above.
    if step_map or gate_map or branch_map:
        passes.append("execution references indexed")


def validate_secondary_objectives(
    optimization: dict[str, Any], passes: list[str], failures: list[str]
) -> None:
    rows = optimization.get("secondary_objectives")
    if not isinstance(rows, list) or not rows:
        failures.append("secondary_objectives must declare the project's optimization priorities")
        return
    metrics: list[str] = []
    priorities: list[int] = []
    valid = True
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            failures.append(f"secondary_objectives[{index}] must be an object")
            valid = False
            continue
        metric = row.get("metric")
        priority = row.get("priority")
        if not nonblank(metric) or row.get("direction") not in {"MINIMIZE", "MAXIMIZE"}:
            failures.append(f"secondary_objectives[{index}] invalid metric or direction")
            valid = False
        if type(priority) is not int or priority < 1 or not nonblank(row.get("rationale")):
            failures.append(f"secondary_objectives[{index}] invalid priority or rationale")
            valid = False
        metrics.append(str(metric))
        priorities.append(priority if type(priority) is int else -1)
    if valid and len(metrics) == len(set(metrics)) and len(priorities) == len(set(priorities)):
        passes.append("project-declared secondary objectives")
    else:
        failures.append("secondary objective metrics and priorities must be unique")


def validate_execution_contracts(
    root: Path,
    validation: dict[str, Any],
    steps: list[Any],
    gates: list[Any],
    branches: list[Any],
    cases: dict[str, dict[str, Any]],
    passes: list[str],
    failures: list[str],
) -> tuple[dict[str, dict[str, Any]], dict[str, dict[str, Any]], dict[str, dict[str, Any]]]:
    step_map: dict[str, dict[str, Any]] = {}
    gate_map: dict[str, dict[str, Any]] = {}
    branch_map: dict[str, dict[str, Any]] = {}
    selected_negative = set(validation.get("negative_case_ids") or [])
    selected_boundary = set(validation.get("boundary_case_ids") or [])

    for index, row in enumerate(steps):
        if not isinstance(row, dict):
            failures.append(f"steps[{index}] must be an object")
            continue
        required = ("id", "title", "kind", "executor", "side_effect", "inputs", "outputs", "exit_criteria", "gate_ids")
        missing = [field for field in required if field not in row]
        if missing:
            failures.append(f"steps[{index}] missing: {', '.join(missing)}")
            continue
        step_id = row.get("id")
        if not nonblank(step_id) or not ID_PATTERN.fullmatch(step_id) or step_id in step_map:
            failures.append(f"steps[{index}] invalid or duplicate id")
            continue
        step_map[step_id] = row
        if not nonblank(row.get("title")):
            failures.append(f"step {step_id} title must be non-empty")
        if row.get("kind") not in ALLOWED_STEP_KINDS:
            failures.append(f"step {step_id} invalid kind")
        if row.get("executor") not in ALLOWED_EXECUTORS:
            failures.append(f"step {step_id} invalid executor")
        if row.get("side_effect") not in ALLOWED_SIDE_EFFECTS:
            failures.append(f"step {step_id} invalid side_effect")
        for field in ("inputs", "outputs", "exit_criteria", "gate_ids"):
            if not isinstance(row.get(field), list):
                failures.append(f"step {step_id} {field} must be an array")
        if row.get("kind") == "CONDITIONAL" and not nonblank(row.get("branch_id")):
            failures.append(f"conditional step {step_id} requires branch_id")

    for index, row in enumerate(gates):
        if not isinstance(row, dict):
            failures.append(f"gates[{index}] must be an object")
            continue
        required = ("id", "type", "condition", "failure_action", "step_ids", "case_ids")
        missing = [field for field in required if field not in row]
        if missing:
            failures.append(f"gates[{index}] missing: {', '.join(missing)}")
            continue
        gate_id = row.get("id")
        if not nonblank(gate_id) or not ID_PATTERN.fullmatch(gate_id) or gate_id in gate_map:
            failures.append(f"gates[{index}] invalid or duplicate id")
            continue
        gate_map[gate_id] = row
        if row.get("type") not in ALLOWED_GATE_TYPES:
            failures.append(f"gate {gate_id} invalid type")
        if not nonblank(row.get("condition")) or not nonblank(row.get("failure_action")):
            failures.append(f"gate {gate_id} condition and failure_action must be non-empty")
        if not nonempty_list(row.get("step_ids")) or not nonempty_list(row.get("case_ids")):
            failures.append(f"gate {gate_id} must bind steps and negative/boundary cases")

    for index, row in enumerate(branches):
        if not isinstance(row, dict):
            failures.append(f"conditional_branches[{index}] must be an object")
            continue
        required = ("id", "when", "step_ids", "gate_ids", "case_ids")
        missing = [field for field in required if field not in row]
        if missing:
            failures.append(f"conditional_branches[{index}] missing: {', '.join(missing)}")
            continue
        branch_id = row.get("id")
        if not nonblank(branch_id) or not ID_PATTERN.fullmatch(branch_id) or branch_id in branch_map:
            failures.append(f"conditional_branches[{index}] invalid or duplicate id")
            continue
        branch_map[branch_id] = row
        if not nonblank(row.get("when")) or not nonempty_list(row.get("step_ids")) or not nonempty_list(row.get("case_ids")):
            failures.append(f"branch {branch_id} requires when, step_ids, and case_ids")
        if not isinstance(row.get("gate_ids"), list):
            failures.append(f"branch {branch_id} gate_ids must be an array")

    for step_id, step in step_map.items():
        gate_ids = step.get("gate_ids") if isinstance(step.get("gate_ids"), list) else []
        for gate_id in gate_ids:
            gate = gate_map.get(gate_id)
            if gate is None:
                failures.append(f"step {step_id} references missing gate {gate_id}")
            elif step_id not in (gate.get("step_ids") or []):
                failures.append(f"step/gate binding is not symmetric: {step_id}/{gate_id}")
        if step.get("kind") == "CONDITIONAL" and step.get("branch_id") not in branch_map:
            failures.append(f"step {step_id} references missing branch")
        elif step.get("kind") == "CONDITIONAL":
            branch = branch_map[step.get("branch_id")]
            if step_id not in (branch.get("step_ids") or []):
                failures.append(
                    f"step/branch binding is not symmetric: {step_id}/{step.get('branch_id')}"
                )
        side_effect = step.get("side_effect")
        gate_types = {gate_map[g].get("type") for g in gate_ids if g in gate_map}
        if side_effect == "EXTERNAL_WRITE" and "AUTHORIZATION" not in gate_types:
            failures.append(f"external-write step {step_id} requires an AUTHORIZATION gate")
        if side_effect == "IRREVERSIBLE_LOCAL" and not gate_types.intersection({"SAFETY", "AUTHORIZATION"}):
            failures.append(f"irreversible step {step_id} requires SAFETY or AUTHORIZATION")

    for gate_id, gate in gate_map.items():
        for step_id in gate.get("step_ids") or []:
            step = step_map.get(step_id)
            if step is None:
                failures.append(f"gate {gate_id} references missing step {step_id}")
            elif gate_id not in (step.get("gate_ids") or []):
                failures.append(f"gate/step binding is not symmetric: {gate_id}/{step_id}")
        qualifying = False
        for case_id in gate.get("case_ids") or []:
            case = cases.get(case_id)
            if case is None:
                failures.append(f"gate {gate_id} references missing case {case_id}")
                continue
            if case_id not in selected_negative.union(selected_boundary):
                failures.append(f"gate {gate_id} case {case_id} is outside selected validation coverage")
            if (
                case.get("kind") in {"NEGATIVE", "BOUNDARY"}
                and case.get("status") == "PASS"
                and nonblank(case.get("request"))
                and nonblank(case.get("expected"))
                and verify_refs(
                    root,
                    case.get("actual_evidence"),
                    f"gate {gate_id} case {case_id}",
                    passes,
                    failures,
                )
            ):
                qualifying = True
            if gate_id not in (case.get("covers_gate_ids") or []):
                failures.append(f"gate/case binding is not symmetric: {gate_id}/{case_id}")
        if not qualifying:
            failures.append(f"gate {gate_id} lacks a passing negative or boundary case")

    for branch_id, branch in branch_map.items():
        for step_id in branch.get("step_ids") or []:
            if step_id not in step_map:
                failures.append(f"branch {branch_id} references missing step {step_id}")
            elif (
                step_map[step_id].get("kind") != "CONDITIONAL"
                or step_map[step_id].get("branch_id") != branch_id
            ):
                failures.append(f"branch/step binding is not symmetric: {branch_id}/{step_id}")
        for gate_id in branch.get("gate_ids") or []:
            if gate_id not in gate_map:
                failures.append(f"branch {branch_id} references missing gate {gate_id}")
        boundary_ok = False
        for case_id in branch.get("case_ids") or []:
            case = cases.get(case_id)
            if case is None:
                failures.append(f"branch {branch_id} references missing case {case_id}")
                continue
            if case_id not in selected_boundary:
                failures.append(f"branch {branch_id} case {case_id} is outside boundary coverage")
            if (
                case.get("kind") == "BOUNDARY"
                and case.get("status") == "PASS"
                and nonblank(case.get("request"))
                and nonblank(case.get("expected"))
                and verify_refs(
                    root,
                    case.get("actual_evidence"),
                    f"branch {branch_id} case {case_id}",
                    passes,
                    failures,
                )
            ):
                boundary_ok = True
            if branch_id not in (case.get("covers_branch_ids") or []):
                failures.append(f"branch/case binding is not symmetric: {branch_id}/{case_id}")
        if not boundary_ok:
            failures.append(f"branch {branch_id} lacks a passing boundary case")

    for case_id, case in cases.items():
        for field, universe in (
            ("covers_step_ids", step_map),
            ("covers_gate_ids", gate_map),
            ("covers_branch_ids", branch_map),
        ):
            values = case.get(field)
            if not isinstance(values, list):
                failures.append(f"case {case_id} {field} must be an array")
                continue
            for value in values:
                if value not in universe:
                    failures.append(f"case {case_id} references missing {field}: {value}")
                elif field == "covers_gate_ids" and case_id not in (
                    universe[value].get("case_ids") or []
                ):
                    failures.append(f"case/gate binding is not symmetric: {case_id}/{value}")
                elif field == "covers_branch_ids" and case_id not in (
                    universe[value].get("case_ids") or []
                ):
                    failures.append(f"case/branch binding is not symmetric: {case_id}/{value}")

    if step_map and gate_map:
        passes.append("step, gate, branch, and case coverage")
    return step_map, gate_map, branch_map


def validate_selected_cases(
    root: Path,
    validation: dict[str, Any],
    cases: dict[str, dict[str, Any]],
    passes: list[str],
    failures: list[str],
) -> None:
    for field, kind in (
        ("golden_case_ids", "GOLDEN"),
        ("negative_case_ids", "NEGATIVE"),
        ("boundary_case_ids", "BOUNDARY"),
    ):
        ids = validation.get(field)
        if not nonempty_list(ids):
            failures.append(f"validation.{field} must be non-empty")
            continue
        valid = True
        for case_id in ids:
            case = cases.get(case_id)
            if not case or case.get("kind") != kind:
                failures.append(f"{field} references invalid {kind} case: {case_id}")
                valid = False
                continue
            if case.get("status") != "PASS" or not nonblank(case.get("request")) or not nonblank(case.get("expected")):
                failures.append(f"case {case_id} must PASS with request and expected")
                valid = False
            if not verify_refs(root, case.get("actual_evidence"), f"case {case_id} evidence", passes, failures):
                valid = False
        if valid:
            passes.append(f"validation.{field} coverage")


def validate_golden(
    root: Path,
    golden: dict[str, Any],
    validation: dict[str, Any],
    passes: list[str],
    failures: list[str],
) -> None:
    if (
        golden.get("status") == "PASS"
        and nonblank(golden.get("input_summary"))
        and nonblank(golden.get("expected_outcome"))
        and nonempty_list(golden.get("protected_invariants"))
    ):
        passes.append("golden reference contract")
    else:
        failures.append("golden reference must PASS with summaries and protected invariants")
    verify_refs(root, golden.get("evidence"), "golden.evidence", passes, failures)
    if golden.get("case_id") in (validation.get("golden_case_ids") or []):
        passes.append("golden reference bound to validation")
    else:
        failures.append("golden case_id must appear in validation.golden_case_ids")


def validate_forward_test(
    spec: dict[str, Any],
    validation: dict[str, Any],
    forward: dict[str, Any],
    digest: str,
    passes: list[str],
    failures: list[str],
) -> None:
    declared = validation.get("independent_forward_test")
    if not isinstance(declared, dict):
        failures.append("independent_forward_test must be an object")
        return
    if declared.get("status") != "PASS":
        failures.append("independent_forward_test.status must be PASS")
    if declared.get("evidence_path") != "evidence/FORWARD_TEST.json":
        failures.append("independent forward evidence_path must be evidence/FORWARD_TEST.json")
    checks = (
        forward.get("schema_version") == "1.0",
        forward.get("workflow_id") == spec.get("workflow_id"),
        forward.get("workflow_version") == spec.get("version"),
        forward.get("status") == "PASS",
        nonblank(forward.get("independent_executor"))
        and forward.get("independent_executor").strip().upper() not in {"SELF", "SAME_AGENT"},
        isinstance(forward.get("input_summary_sha256"), str)
        and bool(SHA256_RE.fullmatch(forward["input_summary_sha256"])),
        forward.get("workflow_definition_sha256") == digest,
        parse_iso(forward.get("started_at")),
        parse_iso(forward.get("completed_at")),
        nonblank(forward.get("result_summary")),
    )
    if all(checks):
        passes.append("independent forward test bound to workflow digest")
    else:
        failures.append("independent forward evidence is incomplete, stale, or not independent")


def validate_command_evidence(
    root: Path,
    spec: dict[str, Any],
    validation: dict[str, Any],
    digest: str,
    passes: list[str],
    failures: list[str],
) -> None:
    rows = validation.get("commands")
    if not isinstance(rows, list) or not rows:
        failures.append("validation.commands must be a non-empty array")
        return
    valid = True
    ids: set[str] = set()
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            failures.append(f"validation.commands[{index}] must be an object")
            valid = False
            continue
        command_id = row.get("id")
        argv = row.get("argv")
        timeout = row.get("timeout_seconds", 600)
        if (
            not nonblank(command_id)
            or command_id in ids
            or not isinstance(argv, list)
            or not argv
            or not all(nonblank(part) for part in argv)
            or any(
                WINDOWS_PATH.search(part) or part.lower().startswith("file://")
                for part in argv
            )
            or type(timeout) is not int
            or not 1 <= timeout <= 3600
        ):
            failures.append(f"validation.commands[{index}] invalid contract")
            valid = False
            continue
        ids.add(command_id)
        try:
            path = resolve_pack_path(root, row.get("evidence_path"), evidence_only=True)
            cwd = resolve_pack_path(root, row.get("cwd", "."))
            if not cwd.is_dir():
                raise ValueError("command cwd is not a directory")
            record = load_json_object(path)
        except Exception as exc:
            failures.append(f"command {command_id} evidence invalid: {exc}")
            valid = False
            continue
        record_ok = (
            record.get("schema_version") == "1.0"
            and record.get("runner_version") == EXPECTED_RUNNER_VERSION
            and record.get("runner_script_sha256")
            == sha256_file(Path(__file__).resolve().parent / "run_validation_commands.py")
            and record.get("execution_mode") == "UNSANDBOXED_LOCAL_NO_SHELL"
            and record.get("workflow_id") == spec.get("workflow_id")
            and record.get("workflow_version") == spec.get("version")
            and record.get("workflow_definition_sha256") == digest
            and record.get("command_id") == command_id
            and record.get("argv") == argv
            and record.get("cwd") == row.get("cwd", ".")
            and type(record.get("exit_code")) is int
            and record.get("exit_code") == 0
            and record.get("timed_out") is False
            and parse_iso(record.get("started_at"))
            and parse_iso(record.get("completed_at"))
            and isinstance(record.get("stdout_sha256"), str)
            and bool(SHA256_RE.fullmatch(record["stdout_sha256"]))
            and isinstance(record.get("stderr_sha256"), str)
            and bool(SHA256_RE.fullmatch(record["stderr_sha256"]))
        )
        if not record_ok:
            failures.append(f"command {command_id} evidence is failed, stale, or mismatched")
            valid = False
    if valid:
        passes.append("validation command records match the bundled no-shell runner")


def validate_skill_export(
    root: Path,
    spec: dict[str, Any],
    skill_export: dict[str, Any],
    passes: list[str],
    failures: list[str],
) -> None:
    if skill_export.get("requested") is False:
        passes.append("skill export not requested")
        return
    if skill_export.get("requested") is not True:
        failures.append("skill_export.requested must be boolean")
        return
    sources = skill_export.get("source_workflows")
    rows = skill_export.get("rules")
    if not isinstance(sources, list) or not sources:
        failures.append("skill export requires evidenced source_workflows")
        return
    if not isinstance(rows, list) or not rows:
        failures.append("skill export requires an explicit rule allowlist")
        return
    valid = True
    source_ids: set[str] = set()
    private_identifiers: set[str] = {
        value
        for value in (spec.get("source_project_id"),)
        if nonblank(value)
    }
    for index, source in enumerate(sources):
        if not isinstance(source, dict):
            failures.append(f"skill_export.source_workflows[{index}] must be an object")
            valid = False
            continue
        project_id = source.get("project_id")
        if (
            not nonblank(project_id)
            or not PROJECT_ID_PATTERN.fullmatch(project_id)
            or project_id in source_ids
        ):
            failures.append(f"skill_export.source_workflows[{index}] invalid project_id")
            valid = False
            continue
        source_ids.add(project_id)
        private_identifiers.add(project_id)
        if nonblank(source.get("workflow_id")):
            private_identifiers.add(source["workflow_id"])
        source_ref = source.get("evidence")
        if not verify_refs(
            root,
            [source_ref],
            f"skill export source {project_id}",
            passes,
            failures,
        ):
            valid = False
            continue
        try:
            receipt_path = resolve_pack_path(
                root, source_ref.get("path"), evidence_only=True
            )
            receipt = load_json_object(receipt_path)
            source_contract_ok = (
                receipt.get("schema_version") == SOURCE_RECEIPT_SCHEMA_VERSION
                and receipt.get("project_id") == project_id
                and nonblank(source.get("workflow_id"))
                and ID_PATTERN.fullmatch(source["workflow_id"])
                and receipt.get("workflow_id") == source.get("workflow_id")
                and nonblank(source.get("workflow_version"))
                and SEMVER_PATTERN.fullmatch(source["workflow_version"])
                and receipt.get("workflow_version") == source.get("workflow_version")
                and isinstance(source.get("workflow_definition_sha256"), str)
                and bool(SHA256_RE.fullmatch(source["workflow_definition_sha256"]))
                and receipt.get("workflow_definition_sha256")
                == source.get("workflow_definition_sha256")
                and source.get("verification_status") == "VERIFIED"
                and receipt.get("status") == "VERIFIED"
                and receipt.get("strict_qa_result") == "PASS"
                and parse_iso(receipt.get("verified_at"))
                and nonblank(receipt.get("result_summary"))
            )
            if not source_contract_ok:
                raise ValueError("receipt is not bound to a VERIFIED source workflow")
        except Exception as exc:
            failures.append(
                f"skill export source {project_id} receipt invalid: {exc}"
            )
            valid = False
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            failures.append(f"skill_export.rules[{index}] must be an object")
            valid = False
            continue
        classification = row.get("classification")
        sources = row.get("source_project_ids")
        if (
            not nonblank(row.get("rule_id"))
            or classification not in {"POLICY", "EMPIRICAL"}
            or not isinstance(sources, list)
            or not all(nonblank(source) for source in sources)
            or not nonblank(row.get("generalization_basis"))
            or row.get("redaction_status") != "PASS"
        ):
            failures.append(f"skill_export.rules[{index}] invalid contract")
            valid = False
            continue
        minimum = 2 if classification == "EMPIRICAL" else 1
        if len(set(sources)) < minimum or not set(sources).issubset(source_ids):
            failures.append(
                f"skill_export.rules[{index}] needs {minimum} evidenced independent source(s)"
            )
            valid = False
    serialized = json.dumps(rows, ensure_ascii=False)
    if WINDOWS_PATH.search(serialized) or "file://" in serialized.lower():
        failures.append("skill export allowlist leaks a local absolute path")
        valid = False
    artifact_root_raw = skill_export.get("artifact_root")
    manifest_ref = skill_export.get("artifact_manifest")
    try:
        artifact_root = resolve_pack_path(root, artifact_root_raw)
        if Path(str(artifact_root_raw)).parts[0] != "exported-skill":
            raise ValueError("artifact_root must stay under exported-skill/")
        if not artifact_root.is_dir():
            raise ValueError("artifact_root must be an existing directory")
    except (ValueError, IndexError) as exc:
        failures.append(f"skill export artifact_root invalid: {exc}")
        return
    if not verify_refs(
        root,
        [manifest_ref],
        "skill export artifact_manifest",
        passes,
        failures,
    ):
        return
    try:
        manifest_path = resolve_pack_path(root, manifest_ref.get("path"), evidence_only=True)
        manifest = load_json_object(manifest_path)
        manifest_rows = manifest.get("files")
        if manifest.get("schema_version") != ARTIFACT_MANIFEST_SCHEMA_VERSION:
            raise ValueError("artifact manifest schema_version must be 1.0")
        if manifest.get("artifact_root") != artifact_root_raw:
            raise ValueError("artifact manifest root does not match artifact_root")
        if not parse_iso(manifest.get("created_at")):
            raise ValueError("artifact manifest created_at must be ISO-8601")
        if not isinstance(manifest_rows, list) or not manifest_rows:
            raise ValueError("artifact manifest files must be a non-empty array")
        if not all(
            isinstance(row, dict)
            and nonblank(row.get("path"))
            and isinstance(row.get("sha256"), str)
            and bool(SHA256_RE.fullmatch(row["sha256"]))
            for row in manifest_rows
        ):
            raise ValueError("artifact manifest contains an invalid file entry")
        declared = {row["path"]: row["sha256"] for row in manifest_rows}
        if len(declared) != len(manifest_rows):
            raise ValueError("artifact manifest contains duplicate file paths")
        actual_files = [path for path in artifact_root.rglob("*") if path.is_file()]
        actual_relatives = {
            path.relative_to(artifact_root).as_posix() for path in actual_files
        }
        if set(declared) != actual_relatives:
            raise ValueError("artifact manifest does not cover exactly all exported files")
        for path in actual_files:
            relative = path.relative_to(artifact_root).as_posix()
            resolved = path.resolve()
            resolved.relative_to(artifact_root.resolve())
            if "__pycache__" in path.parts or path.suffix.lower() == ".pyc":
                raise ValueError("exported Skill contains Python cache files")
            expected = declared.get(relative)
            if not isinstance(expected, str) or not SHA256_RE.fullmatch(expected):
                raise ValueError(f"invalid manifest hash for {relative}")
            if sha256_file(path).lower() != expected.lower():
                raise ValueError(f"artifact hash mismatch for {relative}")
            if path.suffix.lower() in {".md", ".txt", ".json", ".yaml", ".yml", ".py", ".ps1"}:
                text = path.read_text(encoding="utf-8", errors="replace")
                if WINDOWS_PATH.search(text) or "file://" in text.lower():
                    raise ValueError(f"exported file leaks a local absolute path: {relative}")
                leaked_identifier = next(
                    (
                        identifier
                        for identifier in private_identifiers
                        if identifier.casefold() in text.casefold()
                    ),
                    None,
                )
                if leaked_identifier is not None:
                    raise ValueError(
                        f"exported file leaks a source identifier: {relative}"
                    )
                if EMAIL_PATTERN.search(text):
                    raise ValueError(f"exported file contains an email address: {relative}")
    except Exception as exc:
        failures.append(f"skill export artifact verification failed: {exc}")
        valid = False
    if valid:
        passes.append("skill export generalization and redaction gate")


def validate_optimization_claim(
    root: Path,
    optimization: dict[str, Any],
    steps: list[Any],
    cases: dict[str, dict[str, Any]],
    passes: list[str],
    failures: list[str],
) -> None:
    claim = optimization.get("claim")
    if claim == "UNASSESSED":
        failures.append("optimization claim is UNASSESSED")
        return
    if claim == "IRREDUCIBLE_WITHIN_VALIDATED_SCOPE":
        ablation_ids = optimization.get("ablation_case_ids")
        if not nonempty_list(ablation_ids):
            failures.append("irreducibility claim requires ablation_case_ids")
            return
        valid = True
        for row in steps:
            if not isinstance(row, dict) or row.get("kind") == "CONDITIONAL":
                continue
            case_id = row.get("ablation_case_id")
            case = cases.get(case_id)
            if (
                case_id not in ablation_ids
                or not case
                or case.get("kind") != "ABLATION"
                or case.get("status") != "PASS"
                or row.get("id") not in (case.get("covers_step_ids") or [])
            ):
                failures.append(f"step {row.get('id')} lacks a passing bound ablation case")
                valid = False
                continue
            if not verify_refs(root, case.get("actual_evidence"), f"ablation {case_id}", passes, failures):
                valid = False
        if valid:
            passes.append("path is irreducible within the validated scope")
        return

    if claim == "SHORTEST_AMONG_TESTED_CANDIDATES":
        objectives = optimization.get("secondary_objectives") or []
        declared_metrics = {
            row.get("metric"): row for row in objectives if isinstance(row, dict)
        }
        metric = optimization.get("comparison_metric")
        selected_id = optimization.get("selected_candidate_id")
        candidates = optimization.get("candidate_paths")
        if (
            not nonblank(metric)
            or metric not in declared_metrics
            or declared_metrics[metric].get("direction") != "MINIMIZE"
        ):
            failures.append("comparison_metric must be a declared MINIMIZE objective")
            return
        if not isinstance(candidates, list) or len(candidates) < 2:
            failures.append("shortest claim requires at least two tested candidate paths")
            return
        valid_candidates: list[tuple[str, float, str]] = []
        seen_candidate_ids: set[str] = set()
        current_main_path = [
            row.get("id")
            for row in steps
            if isinstance(row, dict) and row.get("kind") != "CONDITIONAL"
        ]
        all_valid = True
        for index, row in enumerate(candidates):
            if not isinstance(row, dict):
                failures.append(f"candidate_paths[{index}] must be an object")
                all_valid = False
                continue
            candidate_id = row.get("id")
            metrics = row.get("metrics")
            value = metrics.get(metric) if isinstance(metrics, dict) else None
            step_ids = row.get("step_ids")
            branch_ids = row.get("branch_ids", [])
            gate_ids = row.get("gate_ids", [])
            configuration = row.get("configuration", {})
            path_contract_ok = (
                nonempty_list(step_ids)
                and all(nonblank(value) for value in step_ids)
                and len(step_ids) == len(set(step_ids))
                and isinstance(branch_ids, list)
                and all(nonblank(value) for value in branch_ids)
                and len(branch_ids) == len(set(branch_ids))
                and isinstance(gate_ids, list)
                and all(nonblank(value) for value in gate_ids)
                and len(gate_ids) == len(set(gate_ids))
                and isinstance(configuration, dict)
            )
            normalized_path = {
                "step_ids": step_ids,
                "branch_ids": branch_ids,
                "gate_ids": gate_ids,
                "configuration": configuration,
            }
            expected_fingerprint = (
                canonical_json_sha256(normalized_path) if path_contract_ok else ""
            )
            declared_fingerprint = row.get("path_fingerprint")
            if (
                not nonblank(candidate_id)
                or candidate_id in seen_candidate_ids
                or row.get("status") != "PASS"
                or row.get("hard_constraints_pass") is not True
                or not path_contract_ok
                or not isinstance(declared_fingerprint, str)
                or not SHA256_RE.fullmatch(declared_fingerprint)
                or declared_fingerprint != expected_fingerprint
                or not is_plain_number(value)
            ):
                failures.append(f"candidate_paths[{index}] invalid tested candidate")
                all_valid = False
                continue
            seen_candidate_ids.add(candidate_id)
            if candidate_id == selected_id and step_ids != current_main_path:
                failures.append(
                    "selected candidate step_ids must equal the current workflow main path"
                )
                all_valid = False
            evidence_rows = row.get("evidence")
            evidence_ok = verify_refs(
                root, evidence_rows, f"candidate {candidate_id}", passes, failures
            )
            receipt_ok = False
            if evidence_ok:
                try:
                    receipt_path = resolve_pack_path(
                        root, evidence_rows[0].get("path"), evidence_only=True
                    )
                    receipt = load_json_object(receipt_path)
                    receipt_ok = (
                        receipt.get("schema_version") == "1.0"
                        and receipt.get("candidate_id") == candidate_id
                        and receipt.get("path_fingerprint") == declared_fingerprint
                        and receipt.get("hard_constraints_pass") is True
                        and receipt.get("metrics") == metrics
                        and nonblank(receipt.get("result_summary"))
                    )
                    if not receipt_ok:
                        raise ValueError("candidate receipt does not match path and metrics")
                except Exception as exc:
                    failures.append(f"candidate {candidate_id} receipt invalid: {exc}")
            if evidence_ok and receipt_ok:
                valid_candidates.append(
                    (candidate_id, float(value), declared_fingerprint)
                )
            else:
                all_valid = False
        fingerprints = {fingerprint for _, _, fingerprint in valid_candidates}
        if len(fingerprints) < 2:
            failures.append("shortest claim requires at least two distinct candidate paths")
            all_valid = False
        selected = next(
            (value for cid, value, _ in valid_candidates if cid == selected_id), None
        )
        if selected is None:
            failures.append("selected_candidate_id does not resolve to a valid candidate")
            all_valid = False
        elif selected != min(value for _, value, _ in valid_candidates):
            failures.append("selected candidate is not shortest for comparison_metric")
            all_valid = False
        if all_valid and len(valid_candidates) >= 2:
            passes.append("selected path is shortest among evidenced tested candidates")


def emit(
    strict: bool,
    require_optimization: bool,
    passes: list[str],
    failures: list[str],
) -> int:
    result = {
        "mode": (
            "strict+optimization"
            if require_optimization
            else "strict" if strict else "structure"
        ),
        "result": "PASS" if not failures else "FAIL",
        "pass_count": len(passes),
        "fail_count": len(failures),
        "failures": failures,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
