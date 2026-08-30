#!/usr/bin/env python3
"""Shared, side-effect-free helpers for workflow pack tools."""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
from typing import Any


DEFINITION_FILES = (
    "WORKFLOW.md",
    "WORKFLOW_SPEC.json",
    "DETOURS_AND_GUARDRAILS.md",
    "CHANGE_POLICY.md",
    "golden/REFERENCE.json",
    "tests/CASES.json",
)
SHA256_RE = re.compile(r"^[0-9a-fA-F]{64}$")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_json_sha256(value: object) -> str:
    payload = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def definition_digest(root: Path) -> str:
    """Hash immutable workflow definition files in a stable order."""
    root = root.resolve()
    digest = hashlib.sha256()
    for relative in DEFINITION_FILES:
        path = root / relative
        if not path.is_file():
            raise FileNotFoundError(f"definition file missing: {relative}")
        data = path.read_bytes()
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        digest.update(str(len(data)).encode("ascii"))
        digest.update(b"\0")
        digest.update(data)
        digest.update(b"\0")
    return digest.hexdigest()


def resolve_pack_path(root: Path, raw: Any, *, evidence_only: bool = False) -> Path:
    if not isinstance(raw, str) or not raw.strip():
        raise ValueError("path must be a non-empty string")
    relative = Path(raw)
    if relative.is_absolute() or relative.drive or ".." in relative.parts:
        raise ValueError("path must be relative and cannot contain '..'")
    root = root.resolve()
    resolved = (root / relative).resolve()
    try:
        resolved.relative_to(root)
    except ValueError as exc:
        raise ValueError("path escapes the workflow pack") from exc
    if evidence_only:
        evidence_root = (root / "evidence").resolve()
        try:
            resolved.relative_to(evidence_root)
        except ValueError as exc:
            raise ValueError("evidence path must stay under evidence/") from exc
    return resolved


def verify_evidence_ref(root: Path, value: Any) -> tuple[bool, str]:
    if not isinstance(value, dict):
        return False, "evidence reference must be an object"
    raw_path = value.get("path")
    expected = value.get("sha256")
    if not isinstance(expected, str) or not SHA256_RE.fullmatch(expected):
        return False, "evidence sha256 must be 64 hexadecimal characters"
    try:
        path = resolve_pack_path(root, raw_path, evidence_only=True)
    except ValueError as exc:
        return False, str(exc)
    if not path.is_file() or path.stat().st_size == 0:
        return False, f"evidence file missing or empty: {raw_path}"
    actual = sha256_file(path)
    if actual.lower() != expected.lower():
        return False, f"evidence hash mismatch: {raw_path}"
    return True, str(raw_path)


def load_json_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"JSON root must be an object: {path}")
    return value
