#!/usr/bin/env python3
"""Run declared validation argv without a shell and bind results to the workflow digest."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import time
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any

from workflow_pack_lib import (
    definition_digest,
    load_json_object,
    resolve_pack_path,
    sha256_file,
)


RUNNER_VERSION = "1.0.0"
MAX_CAPTURE_CHARS = 20000
LOCAL_PATH = re.compile(r"^(?:[A-Za-z]:[\\/]|\\\\)")


def now_iso() -> str:
    return datetime.now().astimezone().isoformat(timespec="milliseconds")


def text_sha256(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8", errors="replace")).hexdigest()


def atomic_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.tmp-{uuid.uuid4().hex}")
    temporary.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    temporary.replace(path)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Execute workflow validation commands and write bound evidence records."
    )
    parser.add_argument("project_root")
    parser.add_argument(
        "--execute",
        action="store_true",
        help="Execute reviewed commands. Without this flag the runner only prints a plan.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = Path(args.project_root).resolve()
    try:
        spec = load_json_object(root / "WORKFLOW_SPEC.json")
        digest = definition_digest(root)
    except Exception as exc:
        print(json.dumps({"result": "FAIL", "error": str(exc)}, ensure_ascii=False))
        return 1

    validation = spec.get("validation")
    commands = validation.get("commands") if isinstance(validation, dict) else None
    if not isinstance(commands, list) or not commands:
        print(json.dumps({"result": "FAIL", "error": "no validation commands"}))
        return 1

    if not args.execute:
        plan = [
            {
                "id": row.get("id"),
                "argv": row.get("argv"),
                "cwd": row.get("cwd", "."),
                "evidence_path": row.get("evidence_path"),
            }
            for row in commands
            if isinstance(row, dict)
        ]
        print(
            json.dumps(
                {
                    "result": "PLAN_ONLY",
                    "warning": "Commands are unsandboxed local processes. Review them, then rerun with --execute.",
                    "workflow_definition_sha256": digest,
                    "commands": plan,
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        return 2

    results: list[dict[str, Any]] = []
    overall_ok = True
    for index, row in enumerate(commands):
        if not isinstance(row, dict):
            results.append({"index": index, "result": "FAIL", "error": "command must be an object"})
            overall_ok = False
            continue
        command_id = row.get("id")
        argv = row.get("argv")
        timeout = row.get("timeout_seconds", 600)
        try:
            if not isinstance(command_id, str) or not command_id.strip():
                raise ValueError("command id must be non-empty")
            if not isinstance(argv, list) or not argv or not all(
                isinstance(part, str) and part for part in argv
            ):
                raise ValueError("argv must be a non-empty string array")
            if any(LOCAL_PATH.search(part) or part.lower().startswith("file://") for part in argv):
                raise ValueError("argv must not embed local absolute paths")
            if type(timeout) is not int or not 1 <= timeout <= 3600:
                raise ValueError("timeout_seconds must be an integer from 1 to 3600")
            cwd = resolve_pack_path(root, row.get("cwd", "."))
            if not cwd.is_dir():
                raise ValueError("cwd must resolve to a directory inside the workflow pack")
            evidence_path = resolve_pack_path(
                root, row.get("evidence_path"), evidence_only=True
            )
        except ValueError as exc:
            results.append({"id": command_id, "result": "FAIL", "error": str(exc)})
            overall_ok = False
            continue

        started_at = now_iso()
        started_clock = time.monotonic()
        timed_out = False
        try:
            completed = subprocess.run(
                argv,
                cwd=cwd,
                shell=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=timeout,
                check=False,
            )
            exit_code = int(completed.returncode)
            stdout = completed.stdout or ""
            stderr = completed.stderr or ""
        except subprocess.TimeoutExpired as exc:
            timed_out = True
            exit_code = 124
            stdout = (exc.stdout or "") if isinstance(exc.stdout, str) else ""
            stderr = (exc.stderr or "") if isinstance(exc.stderr, str) else ""
        except OSError as exc:
            exit_code = 127
            stdout = ""
            stderr = str(exc)

        record = {
            "schema_version": "1.0",
            "runner_version": RUNNER_VERSION,
            "runner_script_sha256": sha256_file(Path(__file__).resolve()),
            "execution_mode": "UNSANDBOXED_LOCAL_NO_SHELL",
            "workflow_id": spec.get("workflow_id"),
            "workflow_version": spec.get("version"),
            "workflow_definition_sha256": digest,
            "command_id": command_id,
            "argv": argv,
            "cwd": row.get("cwd", "."),
            "started_at": started_at,
            "completed_at": now_iso(),
            "duration_seconds": round(time.monotonic() - started_clock, 6),
            "timed_out": timed_out,
            "exit_code": exit_code,
            "stdout_sha256": text_sha256(stdout),
            "stderr_sha256": text_sha256(stderr),
            "stdout_tail": stdout[-MAX_CAPTURE_CHARS:],
            "stderr_tail": stderr[-MAX_CAPTURE_CHARS:],
            "output_truncated": len(stdout) > MAX_CAPTURE_CHARS or len(stderr) > MAX_CAPTURE_CHARS,
        }
        atomic_json(evidence_path, record)
        ok = exit_code == 0
        results.append(
            {"id": command_id, "result": "PASS" if ok else "FAIL", "exit_code": exit_code}
        )
        overall_ok = overall_ok and ok

    print(
        json.dumps(
            {
                "result": "PASS" if overall_ok else "FAIL",
                "workflow_definition_sha256": digest,
                "commands": results,
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0 if overall_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
