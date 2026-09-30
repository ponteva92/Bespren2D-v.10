"""Focused regression gate for signature-detected Addons containers."""

from __future__ import annotations

import hashlib
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT / "tools" / "asset_pipeline"))

from deep_asset_audit import _container_format_from_path  # noqa: E402


AUDIT_ROOT = PROJECT_ROOT / "artifacts" / "asset_audit"
FILE_LEDGER = AUDIT_ROOT / "addons_file_ledger.jsonl"
MEMBER_LEDGER = AUDIT_ROOT / "archive_member_ledger.jsonl"
SUMMARY_PATH = AUDIT_ROOT / "deep_asset_audit_summary.json"

UNITY_PATH = (
    "Addons/Pixel Art Top Down - Basic v1.2.3/"
    "Pixel Art Top Down - Basic v1.2.3.unitypackage"
)
KRA_PATH = (
    "Addons/godot-2d-topdown-template-main/godot-2d-topdown-template-main/"
    "scenes/props/.spikes.png-autosave.kra"
)
FLA_PATH = (
    "Addons/Starter-Kit-City-Builder-main/Starter-Kit-City-Builder-main/"
    "vector/sprites.fla"
)
FLA_ZIP_PATH = "Addons/Starter-Kit-City-Builder-main.zip"
FLA_ZIP_MEMBER = "Starter-Kit-City-Builder-main/vector/sprites.fla"
NESTED_FLA_CONTAINER = f"{FLA_ZIP_PATH}!{FLA_ZIP_MEMBER}"

EXPECTED = {
    "files_audited": 31_404,
    "source_bytes": 2_355_834_247,
    "physical_archive_containers_audited": 145,
    "nested_archive_containers_audited": 14,
    "archive_containers_audited": 159,
    "archive_members_audited": 4_684,
    "archive_member_bytes_decompressed_and_hashed": 892_666_069,
}


def _read_jsonl(path: Path) -> list[dict[str, Any]]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()]


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    file_records = _read_jsonl(FILE_LEDGER)
    member_records = _read_jsonl(MEMBER_LEDGER)
    summary = json.loads(SUMMARY_PATH.read_text(encoding="utf-8"))
    checks = 0

    for key, expected_value in EXPECTED.items():
        _require(summary.get(key) == expected_value, f"Summary mismatch for {key}")
        checks += 1
    _require(summary.get("physical_archive_format_counts") == {"gzip_tar": 1, "zip": 144}, "Physical container formats")
    checks += 1
    _require(summary.get("nested_archive_format_counts") == {"gzip_tar": 3, "zip": 11}, "Nested container formats")
    checks += 1
    _require(summary.get("archive_format_counts") == {"gzip_tar": 4, "zip": 155}, "Recursive container formats")
    checks += 1
    _require(summary.get("archive_member_container_format_counts") == {"gzip_tar": 1392, "zip": 3292}, "Member parent formats")
    checks += 1

    files_by_path = {str(record["path"]): record for record in file_records}
    live_file_bytes: dict[str, int] = {}
    live_containers: dict[str, str] = {}
    for path in sorted((PROJECT_ROOT / "Addons").rglob("*")):
        if not path.is_file():
            continue
        relative_path = path.relative_to(PROJECT_ROOT).as_posix()
        live_file_bytes[relative_path] = path.stat().st_size
        detected_format = _container_format_from_path(path)
        if detected_format is not None:
            live_containers[relative_path] = detected_format
    _require(set(live_file_bytes) == set(files_by_path), "Every live physical file has one ledger record")
    _require(
        all(int(files_by_path[path]["bytes"]) == size for path, size in live_file_bytes.items()),
        "Every live physical file size matches the ledger",
    )
    checks += 2
    ledger_containers = {
        path: str(record["container_format"])
        for path, record in files_by_path.items()
        if record.get("container_format")
    }
    _require(live_containers == ledger_containers, "Every live signature container has one ledger record")
    _require(Counter(live_containers.values()) == Counter({"zip": 144, "gzip_tar": 1}), "Live signature format totals")
    checks += 2

    for path, expected_format in (
        (UNITY_PATH, "gzip_tar"),
        (KRA_PATH, "zip"),
        (FLA_PATH, "zip"),
    ):
        record = files_by_path.get(path)
        _require(record is not None, f"Missing physical ledger record: {path}")
        _require(record.get("container_format") == expected_format, f"Wrong format: {path}")
        _require(record.get("content_kind") == "archive", f"Wrong content kind: {path}")
        _require(record.get("sha256") == _sha256(PROJECT_ROOT / path), f"Stale hash: {path}")
        checks += 4

    unity_outer = [
        record
        for record in member_records
        if record["container"] == UNITY_PATH and int(record["depth"]) == 0
    ]
    unity_nested = [
        record
        for record in member_records
        if str(record["container"]).startswith(f"{UNITY_PATH}!") and int(record["depth"]) == 1
    ]
    _require(len(unity_outer) == 1228, "Unity package outer member coverage")
    _require(sum(record.get("nested_container_format") == "gzip_tar" for record in unity_outer) == 3, "Unity nested package discovery")
    _require(len(unity_nested) == 164, "Unity nested member coverage")
    _require(sum(int(record["bytes"]) for record in unity_outer + unity_nested) == 9_329_294, "Unity package byte coverage")
    checks += 4

    kra_members = [record for record in member_records if record["container"] == KRA_PATH]
    fla_members = [record for record in member_records if record["container"] == FLA_PATH]
    _require(len(kra_members) == 11, "Krita member coverage")
    _require(sum(int(record["bytes"]) for record in kra_members) == 56_938, "Krita byte coverage")
    _require(len(fla_members) == 20, "Animate member coverage")
    _require(sum(int(record["bytes"]) for record in fla_members) == 205_659, "Animate byte coverage")
    _require(sum(bool(record.get("quality_flags")) for record in fla_members) == 1, "Animate orphan local member coverage")
    checks += 5

    archived_fla = [
        record
        for record in member_records
        if record["container"] == FLA_ZIP_PATH and record["member"] == FLA_ZIP_MEMBER
    ]
    archived_fla_children = [
        record for record in member_records if record["container"] == NESTED_FLA_CONTAINER
    ]
    _require(len(archived_fla) == 1, "Archived FLA container record")
    _require(archived_fla[0].get("nested_container_format") == "zip", "Archived FLA signature discovery")
    _require(len(archived_fla_children) == 20, "Archived duplicate FLA member coverage")
    _require(sum(int(record["bytes"]) for record in archived_fla_children) == 205_659, "Archived duplicate FLA byte coverage")
    _require(sum(bool(record.get("quality_flags")) for record in archived_fla_children) == 1, "Archived FLA orphan local member coverage")
    checks += 5

    unique_member_keys = {
        (
            str(record["container"]),
            int(record["depth"]),
            str(record["member"]),
            int(record.get("member_occurrence", 1)),
        )
        for record in member_records
    }
    _require(len(unique_member_keys) == len(member_records), "Archive ledger keys are unique")
    checks += 1

    print(f"DEEP ASSET AUDIT VALIDATION OK ({checks} checks)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
