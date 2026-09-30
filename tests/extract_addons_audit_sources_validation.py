"""Adversarial regression tests for the immutable Addons extraction gate.

The tests use tiny disposable projects; they never stage the production vault.
"""

from __future__ import annotations

import hashlib
import io
import json
import os
import stat
import struct
import sys
import tarfile
import tempfile
import unicodedata
import warnings
import zipfile
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT / "tools" / "asset_pipeline"))

from extract_addons_audit_sources import (  # noqa: E402
    ExtractionGateError,
    ExtractionLimits,
    extract_sources,
    normalize_member_path,
    validate_extraction_run,
)


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _project(root: Path) -> Path:
    (root / "Addons").mkdir(parents=True)
    (root / "project.godot").write_text("[application]\nconfig/name=\"gate-fixture\"\n", encoding="utf-8")
    return root


def _zip_bytes(entries: dict[str, bytes]) -> bytes:
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for name, data in entries.items():
            archive.writestr(name, data)
    return output.getvalue()


def _tar_add(archive: tarfile.TarFile, name: str, data: bytes) -> None:
    info = tarfile.TarInfo(name)
    info.size = len(data)
    archive.addfile(info, io.BytesIO(data))


def _records(run_root: Path) -> list[dict[str, object]]:
    ledger = run_root / "extraction_ledger.jsonl"
    return [json.loads(line) for line in ledger.read_text(encoding="utf-8").splitlines()]


def _assert_rejected(root: Path, run_id: str, **kwargs: object) -> int:
    try:
        extract_sources(root, run_id=run_id, verify_ledgers=False, **kwargs)
    except ExtractionGateError:
        run_root = root / "artifacts" / "asset_audit" / "extraction_runs" / run_id
        manifest = json.loads((run_root / "run_manifest.json").read_text(encoding="utf-8"))
        _require(manifest.get("status") == "rejected", f"{run_id}: rejected manifest")
        _require(
            any(record.get("record_type") == "gate_rejection" for record in _records(run_root)),
            f"{run_id}: persistent rejection ledger row",
        )
        return 1
    raise AssertionError(f"{run_id}: malicious archive was accepted")


def _write_zip(root: Path, name: str, entries: dict[str, bytes]) -> Path:
    path = root / "Addons" / name
    path.write_bytes(_zip_bytes(entries))
    return path


def test_safe_nested_stream_and_validator(root: Path) -> int:
    nested = _zip_bytes({"inner.txt": b"nested payload"})
    _write_zip(root, "outer.zip", {"alpha.txt": b"alpha", "nested.zip": nested})
    unity = root / "Addons" / "safe.unitypackage"
    with tarfile.open(unity, "w:gz") as archive:
        _tar_add(archive, "unit/pathname", b"Assets/Props/Beacon.png\n")
        _tar_add(archive, "unit/asset", b"unity asset bytes")
    (root / "Addons" / "loose.txt").write_bytes(b"loose vault source")
    before = {path.relative_to(root).as_posix(): _sha256(path) for path in (root / "Addons").rglob("*") if path.is_file()}

    manifest = extract_sources(root, run_id="safe-nested", verify_ledgers=False)
    run_root = root / "artifacts" / "asset_audit" / "extraction_runs" / "safe-nested"
    validation = validate_extraction_run(run_root)
    after = {path.relative_to(root).as_posix(): _sha256(path) for path in (root / "Addons").rglob("*") if path.is_file()}
    payloads = [
        record
        for record in _records(run_root)
        if record.get("record_type") in {"archive_member", "physical_loose_file"}
    ]
    _require(manifest["status"] == "complete", "safe fixture completes")
    _require(manifest["physical_archive_wrapper_files_materialized"] == 0, "archive wrappers are never copied")
    _require(manifest["physical_loose_file_payloads_materialized"] == 1, "every loose file is staged")
    _require(manifest["member_payloads_materialized"] == 5, "outer/nested/TAR member coverage")
    _require(manifest["archive_entries_seen"] == 6, "global archive-entry accounting")
    _require(validation["payloads"] == 6, "read-only validator covers every payload")
    _require(validation["status"] == "valid_fixture", "fixture validator declares non-production scope")
    _require(before == after, "Addons sources remain byte-identical")
    _require(len(payloads) == 6, "archive and loose payload records")
    _require(all(str(record["artifact_relative_path"]).startswith("stage/payloads/") for record in payloads), "flat staged artifacts only")
    _require(not list(run_root.rglob("*.tmp")), "no temporary output remains")
    _require((run_root / ".gdignore").is_file() and (run_root / "stage" / ".gdignore").is_file(), "stage is import-ignored")
    checks = 10
    # Windows symlinks require Developer Mode or elevated rights on some hosts.
    # When available, prove the read-only validator rejects an *intermediate*
    # stage redirect, not merely a reparse file at the final destination.
    archive_record = next(record for record in payloads if record.get("record_type") == "archive_member")
    original = run_root / Path(str(archive_record["artifact_relative_path"])).parent
    redirected = original.with_name(f"{original.name}-real")
    try:
        original.rename(redirected)
        os.symlink(redirected, original, target_is_directory=True)
    except OSError:
        if redirected.exists() and not original.exists():
            redirected.rename(original)
    else:
        try:
            validate_extraction_run(run_root)
        except ExtractionGateError:
            checks += 1
        else:
            raise AssertionError("validator accepted an intermediate stage reparse redirect")
    return checks


def test_production_deep_ledger_crosscheck(root: Path) -> int:
    """Exercise the production file/member expected-key validator on a tiny vault."""

    loose_path = root / "Addons" / "loose.bin"
    loose_path.write_bytes(b"loose production fixture")
    archive_path = _write_zip(root, "bundle.zip", {"member.txt": b"archive production fixture"})
    with zipfile.ZipFile(archive_path, "r") as archive:
        info = archive.getinfo("member.txt")
        member_bytes = archive.read(info)
    file_records = [
        {
            "schema_version": 1,
            "sequence": 1,
            "path": "Addons/loose.bin",
            "bytes": loose_path.stat().st_size,
            "sha256": _sha256(loose_path),
            "content_kind": "binary_or_unknown",
            "decision": "retain_unclassified_source",
            "role_tags": [],
        },
        {
            "schema_version": 1,
            "sequence": 2,
            "path": "Addons/bundle.zip",
            "bytes": archive_path.stat().st_size,
            "sha256": _sha256(archive_path),
            "container_format": "zip",
            "content_kind": "archive",
            "decision": "retain_audited_container",
            "role_tags": [],
        },
    ]
    member_records = [
        {
            "schema_version": 1,
            "container": "Addons/bundle.zip",
            "container_format": "zip",
            "depth": 0,
            "member": "member.txt",
            "bytes": len(member_bytes),
            "compressed_bytes": info.compress_size,
            "crc32": f"{info.CRC:08x}",
            "sha256": hashlib.sha256(member_bytes).hexdigest(),
            "status": "path_safe_crc_valid_decompressed",
            "content_kind": "binary_or_unknown",
            "decision": "retain_archive_member",
            "role_tags": [],
        }
    ]
    audit_root = root / "artifacts" / "asset_audit"
    audit_root.mkdir(parents=True)
    file_ledger = audit_root / "addons_file_ledger.jsonl"
    member_ledger = audit_root / "archive_member_ledger.jsonl"
    file_ledger.write_text("".join(json.dumps(record) + "\n" for record in file_records), encoding="utf-8")
    member_ledger.write_text("".join(json.dumps(record) + "\n" for record in member_records), encoding="utf-8")

    manifest = extract_sources(root, run_id="production-ledger", verify_ledgers=True)
    run_root = root / "artifacts" / "asset_audit" / "extraction_runs" / "production-ledger"
    validation = validate_extraction_run(run_root)
    _require(validation["status"] == "valid", "production validator deep-ledger cross-check")
    _require(manifest["loose_file_payloads_materialized"] == 1, "production loose-file coverage")
    _require(manifest["member_payloads_materialized"] == 1, "production archive-member coverage")
    _require(manifest["physical_container_verifications"] == 1, "production container verification coverage")

    original_loose = loose_path.read_bytes()
    loose_path.write_bytes(b"x" * len(original_loose))
    try:
        validate_extraction_run(run_root)
    except ExtractionGateError:
        pass
    else:
        raise AssertionError("validator accepted a source mutation after staging")
    loose_path.write_bytes(original_loose)
    _require(validate_extraction_run(run_root)["status"] == "valid", "restored source validates again")

    # Same records but a changed source-ledger byte stream: self-consistent stage
    # must not validate against a drifted deep-audit baseline.
    file_ledger.write_text(file_ledger.read_text(encoding="utf-8") + "\n", encoding="utf-8")
    try:
        validate_extraction_run(run_root)
    except ExtractionGateError:
        pass
    else:
        raise AssertionError("validator accepted a run after deep file-ledger drift")
    return 8


def test_windows_path_rejections(root: Path) -> int:
    unsafe = [
        "../escape.txt",
        "..\\escape.txt",
        "/absolute.txt",
        "\\absolute.txt",
        "C:\\escape.txt",
        "C:relative.txt",
        "\\\\server\\share.txt",
        "\\\\?\\C:\\escape.txt",
        "\\\\.\\NUL",
        "file.txt:ads",
        "CON",
        "CON .txt",
        "aux.txt",
        "LPT1.log",
        "trailing.",
        "trailing ",
    ]
    checks = 0
    for value in unsafe:
        try:
            normalize_member_path(value)
        except ExtractionGateError:
            checks += 1
        else:
            raise AssertionError(f"unsafe Windows pathname accepted: {value!r}")
    _write_zip(root, "traversal.zip", {"../outside.txt": b"nope"})
    checks += _assert_rejected(root, "path-traversal")
    _require(not (root.parent / "outside.txt").exists(), "traversal cannot create external file")
    return checks + 1


def test_zip_link_encryption_collision_and_budgets(root: Path) -> int:
    link_root = _project(root / "link")
    link_path = link_root / "Addons" / "link.zip"
    with zipfile.ZipFile(link_path, "w") as archive:
        info = zipfile.ZipInfo("link")
        info.external_attr = (stat.S_IFLNK | 0o777) << 16
        archive.writestr(info, b"target")
    checks = _assert_rejected(link_root, "zip-symlink")

    encrypted_root = _project(root / "encrypted")
    encrypted_path = _write_zip(encrypted_root, "encrypted.zip", {"secret.txt": b"secret"})
    raw = bytearray(encrypted_path.read_bytes())
    local = raw.index(b"PK\x03\x04")
    central = raw.index(b"PK\x01\x02")
    struct.pack_into("<H", raw, local + 6, struct.unpack_from("<H", raw, local + 6)[0] | 0x1)
    struct.pack_into("<H", raw, central + 8, struct.unpack_from("<H", raw, central + 8)[0] | 0x1)
    encrypted_path.write_bytes(raw)
    checks += _assert_rejected(encrypted_root, "zip-encrypted")

    case_root = _project(root / "case")
    _write_zip(case_root, "case.zip", {"Hero.png": b"A", "hero.png": b"B"})
    checks += _assert_rejected(case_root, "zip-case-collision")

    decomposed = unicodedata.normalize("NFD", "Café.png")
    composed = unicodedata.normalize("NFC", "Café.png")
    unicode_root = _project(root / "unicode")
    _write_zip(unicode_root, "unicode.zip", {decomposed: b"A", composed: b"B"})
    checks += _assert_rejected(unicode_root, "zip-unicode-collision")

    duplicate_root = _project(root / "duplicate")
    duplicate_path = duplicate_root / "Addons" / "duplicate.zip"
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", UserWarning)
        with zipfile.ZipFile(duplicate_path, "w") as archive:
            archive.writestr("same.txt", b"first")
            archive.writestr("same.txt", b"second")
    checks += _assert_rejected(duplicate_root, "zip-exact-duplicate")

    limit_root = _project(root / "limit")
    _write_zip(limit_root, "limit.zip", {"large.bin": b"12345"})
    limits = ExtractionLimits(
        max_depth=2,
        max_member_bytes=4,
        max_container_bytes=32,
        max_run_bytes=32,
        max_members=8,
        max_containers=8,
        max_compression_ratio=100.0,
    )
    checks += _assert_rejected(limit_root, "zip-member-budget", limits=limits)

    run_budget_root = _project(root / "run-budget")
    _write_zip(run_budget_root, "run-budget.zip", {"one.bin": b"1234", "two.bin": b"5678"})
    run_limits = ExtractionLimits(
        max_depth=2,
        max_member_bytes=8,
        max_container_bytes=16,
        max_run_bytes=6,
        max_members=8,
        max_containers=8,
        max_compression_ratio=100.0,
    )
    checks += _assert_rejected(run_budget_root, "zip-run-budget", limits=run_limits)

    entry_budget_root = _project(root / "entry-budget")
    _write_zip(entry_budget_root, "entries.zip", {"one/": b"", "two/": b"", "payload.bin": b"1"})
    entry_limits = ExtractionLimits(
        max_depth=2,
        max_member_bytes=8,
        max_container_bytes=32,
        max_run_bytes=32,
        max_members=2,
        max_containers=8,
        max_compression_ratio=100.0,
    )
    checks += _assert_rejected(entry_budget_root, "zip-entry-budget", limits=entry_limits)

    ratio_root = _project(root / "ratio")
    _write_zip(ratio_root, "ratio.zip", {"zeros.bin": b"\0" * 4096})
    ratio_limits = ExtractionLimits(
        max_depth=2,
        max_member_bytes=8192,
        max_container_bytes=8192,
        max_run_bytes=8192,
        max_members=8,
        max_containers=8,
        max_compression_ratio=2.0,
    )
    checks += _assert_rejected(ratio_root, "zip-compression-ratio", limits=ratio_limits)
    return checks


def test_tar_link_types_and_unity_metadata(root: Path) -> int:
    checks = 0
    for label, kind in (("symlink", tarfile.SYMTYPE), ("hardlink", tarfile.LNKTYPE), ("fifo", tarfile.FIFOTYPE)):
        fixture_root = _project(root / label)
        path = fixture_root / "Addons" / f"{label}.unitypackage"
        with tarfile.open(path, "w:gz") as archive:
            info = tarfile.TarInfo("unsafe")
            info.type = kind
            info.linkname = "target"
            archive.addfile(info)
        checks += _assert_rejected(fixture_root, f"tar-{label}")

    metadata_root = _project(root / "metadata")
    unsafe_metadata = metadata_root / "Addons" / "unsafe-metadata.unitypackage"
    with tarfile.open(unsafe_metadata, "w:gz") as archive:
        _tar_add(archive, "entry/pathname", b"../outside.png:ads\n")
        _tar_add(archive, "entry/asset", b"asset bytes")
    manifest = extract_sources(metadata_root, run_id="unity-metadata", verify_ledgers=False)
    records = _records(metadata_root / "artifacts" / "asset_audit" / "extraction_runs" / "unity-metadata")
    asset_record = next(
        record for record in records if record.get("record_type") == "archive_member" and record.get("member") == "entry/asset"
    )
    _require(manifest["status"] == "complete", "unsafe Unity metadata does not become a filesystem path")
    _require(asset_record.get("logical_path_safety") == "rejected_metadata_not_used", "unsafe Unity logical metadata recorded")
    _require(not (metadata_root.parent / "outside.png").exists(), "Unity metadata cannot escape staging")
    return checks + 3


def main() -> int:
    checks = 0
    with tempfile.TemporaryDirectory(prefix="addons-extraction-gate-") as temporary:
        root = _project(Path(temporary) / "safe")
        checks += test_safe_nested_stream_and_validator(root)
    with tempfile.TemporaryDirectory(prefix="addons-extraction-gate-") as temporary:
        root = _project(Path(temporary) / "production")
        checks += test_production_deep_ledger_crosscheck(root)
    with tempfile.TemporaryDirectory(prefix="addons-extraction-gate-") as temporary:
        root = _project(Path(temporary) / "paths")
        checks += test_windows_path_rejections(root)
    with tempfile.TemporaryDirectory(prefix="addons-extraction-gate-") as temporary:
        root = _project(Path(temporary) / "zip")
        checks += test_zip_link_encryption_collision_and_budgets(root)
    with tempfile.TemporaryDirectory(prefix="addons-extraction-gate-") as temporary:
        root = _project(Path(temporary) / "tar")
        checks += test_tar_link_types_and_unity_metadata(root)
    print(f"ADDONS AUDIT EXTRACTION VALIDATION OK ({checks} checks)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
