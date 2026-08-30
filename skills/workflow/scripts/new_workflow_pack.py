#!/usr/bin/env python3
"""Create a new workflow evidence pack without overwriting existing work."""

from __future__ import annotations

import argparse
import json
import re
import sys
import tempfile
from datetime import datetime
from pathlib import Path
from typing import NoReturn


WORKFLOW_ID = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
PROJECT_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
TOKEN_PATTERN = re.compile(r"\{\{(?:WORKFLOW_ID|TITLE|CREATED_AT|SOURCE_PROJECT_ID)\}\}")
TEMPLATE_MAP = {
    "WORKFLOW.md.template": Path("WORKFLOW.md"),
    "WORKFLOW_SPEC.json.template": Path("WORKFLOW_SPEC.json"),
    "DETOURS_AND_GUARDRAILS.md.template": Path("DETOURS_AND_GUARDRAILS.md"),
    "QA.md.template": Path("QA.md"),
    "CHANGE_POLICY.md.template": Path("CHANGE_POLICY.md"),
    "REFERENCE.json.template": Path("golden") / "REFERENCE.json",
    "CASES.json.template": Path("tests") / "CASES.json",
    "FORWARD_TEST.json.template": Path("evidence") / "FORWARD_TEST.json",
}


def fail(message: str) -> NoReturn:
    raise SystemExit(f"ERROR: {message}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create a draft workflow pack from the $workflow templates."
    )
    parser.add_argument("--workflow-id", required=True)
    parser.add_argument("--title", required=True)
    parser.add_argument("--destination", required=True)
    parser.add_argument("--source-project-id", default="")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if sys.version_info < (3, 10):
        fail("Python 3.10 or newer is required")
    if not WORKFLOW_ID.fullmatch(args.workflow_id):
        fail("--workflow-id must contain lowercase letters, digits, and single hyphens")
    if not args.title.strip():
        fail("--title cannot be empty")
    source_project_id = args.source_project_id.strip() or args.workflow_id
    if not PROJECT_ID.fullmatch(source_project_id):
        fail("--source-project-id must be a stable ID, not a local filesystem path")

    destination = Path(args.destination).resolve()
    if destination.exists():
        fail(f"destination already exists: {destination}")

    template_root = Path(__file__).resolve().parent.parent / "assets" / "workflow-pack"
    missing = [name for name in TEMPLATE_MAP if not (template_root / name).is_file()]
    if missing:
        fail(f"missing templates: {', '.join(missing)}")

    destination.parent.mkdir(parents=True, exist_ok=True)
    created_at = datetime.now().astimezone().isoformat(timespec="seconds")
    tokens = {
        "{{WORKFLOW_ID}}": args.workflow_id,
        "{{TITLE}}": args.title.strip(),
        "{{CREATED_AT}}": created_at,
        "{{SOURCE_PROJECT_ID}}": source_project_id,
    }
    json_tokens = {
        marker: json.dumps(value, ensure_ascii=False)[1:-1]
        for marker, value in tokens.items()
    }

    with tempfile.TemporaryDirectory(
        prefix=f".{destination.name}.staging-", dir=destination.parent
    ) as staging_name:
        staging = Path(staging_name)
        for template_name, relative_target in TEMPLATE_MAP.items():
            content = (template_root / template_name).read_text(encoding="utf-8")
            replacements = json_tokens if relative_target.suffix == ".json" else tokens
            content = TOKEN_PATTERN.sub(
                lambda match: replacements[match.group(0)], content
            )
            target = staging / relative_target
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content, encoding="utf-8", newline="\n")
        try:
            staging.replace(destination)
        except OSError:
            fail(f"destination was created concurrently: {destination}")

    result = {
        "status": "CREATED_DRAFT",
        "workflow_id": args.workflow_id,
        "destination": str(destination),
        "files": [str(path) for path in TEMPLATE_MAP.values()],
        "next": (
            f"Fill the pack, review the run_validation_commands.py {destination} plan, "
            f"rerun it with --execute, then run qa_workflow_pack.py {destination} --strict"
        ),
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
