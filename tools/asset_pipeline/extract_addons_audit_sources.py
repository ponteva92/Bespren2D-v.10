"""Safely materialize every loose Addons file and supported archive member into an audit-only stage.

This is deliberately not a runtime asset importer. It never writes to Addons
or assets and it never calls extract/extractall. Every payload is streamed to
a flat, content-addressed file below a fresh artifacts audit run directory.
Archive and loose source names are evidence only: no source-controlled pathname
is ever used as an output path. Physical archive wrappers are hash-verified but
not copied, because their safely materialized members are the actual evidence.

The production command requires the existing deep-audit ledgers. That turns
the extractor into a provenance gate: physical archive hashes and every
materialized member hash/size must agree with the audited vault before a run
is reported complete.
"""

from __future__ import annotations

import argparse
import binascii
import contextlib
import hashlib
import io
import json
import os
import re
import shutil
import stat
import struct
import sys
import tarfile
import tempfile
import unicodedata
import zipfile
import zlib
from collections import Counter
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, BinaryIO, Iterable, Iterator

try:
    from .deep_asset_audit import DeepAuditError, _normalized_zip_bytes
except ImportError:
    from deep_asset_audit import DeepAuditError, _normalized_zip_bytes  # type: ignore[no-redef]


SCHEMA_VERSION = 2
GENERATOR = "tools/asset_pipeline/extract_addons_audit_sources.py"
READ_BLOCK_BYTES = 1024 * 1024
MAX_REPAIRED_ZIP_BYTES = 8 * 1024 * 1024
MAX_LOGICAL_PATH_BYTES = 8 * 1024
MAX_MEMBER_COMPONENTS = 64
MAX_MEMBER_COMPONENT_CHARS = 180
MAX_MEMBER_PATH_CHARS = 2048
RUN_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")
ZIP_SIGNATURES = (b"PK\x03\x04", b"PK\x05\x06", b"PK\x07\x08")
GZIP_SIGNATURE = b"\x1f\x8b"
CONTAINER_EXTENSIONS = {".zip", ".unitypackage", ".kra", ".fla"}
WINDOWS_RESERVED_NAMES = {
    "CON",
    "PRN",
    "AUX",
    "NUL",
    "CLOCK$",
    *(f"COM{number}" for number in range(1, 10)),
    *(f"LPT{number}" for number in range(1, 10)),
    "COM¹",
    "COM²",
    "COM³",
    "LPT¹",
    "LPT²",
    "LPT³",
}
WINDOWS_INVALID_CHARS = set('<>:"|?*')
FILE_ATTRIBUTE_REPARSE_POINT = 0x400


class ExtractionGateError(RuntimeError):
    """Raised when an archive cannot cross the immutable-source audit gate."""


@dataclass(frozen=True, slots=True)
class ExtractionLimits:
    """Hard limits shared by physical and recursively nested containers."""

    max_depth: int = 4
    max_member_bytes: int = 192 * 1024 * 1024
    max_container_bytes: int = 2 * 1024 * 1024 * 1024
    # The complete immutable vault currently needs ~3.07 GiB after expanding
    # archive members and staging all loose files. Keep this bounded, rather
    # than silently weakening the archive-specific 2 GiB/container ceiling.
    max_run_bytes: int = 4 * 1024 * 1024 * 1024
    max_members: int = 50_000
    max_containers: int = 1_024
    max_compression_ratio: float = 100.0


DEFAULT_LIMITS = ExtractionLimits()
MemberKey = tuple[str, int, str, int]


@dataclass(frozen=True, slots=True)
class LedgerSnapshot:
    """Immutable subset of deep-audit evidence needed by this gate."""

    file_records: dict[str, dict[str, Any]]
    member_records: dict[MemberKey, dict[str, Any]]
    file_ledger_sha256: str
    member_ledger_sha256: str
    file_ledger_schema_versions: tuple[int, ...]
    member_ledger_schema_versions: tuple[int, ...]


@dataclass(frozen=True, slots=True)
class MemberPath:
    """Archive pathname after portable Windows-safe canonicalization."""

    raw: str
    normalized: str
    collision_key: str
    is_directory: bool


@dataclass(frozen=True, slots=True)
class ContainerContext:
    """One physical or nested supported container in the audit graph."""

    source_path: Path
    lineage: str
    physical_source: str
    container_format: str
    depth: int
    container_sha256: str
    instance_id: str


@dataclass(frozen=True, slots=True)
class PayloadResult:
    """Verified staged payload metadata returned after an atomic write."""

    stage_relative_path: str
    sha256: str
    bytes_written: int
    crc32: str
    magic: str
    prefix: bytes
    destination: Path


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(READ_BLOCK_BYTES), b""):
            digest.update(block)
    return digest.hexdigest()


def _jsonl_records(path: Path) -> list[dict[str, Any]]:
    try:
        return [
            json.loads(line)
            for line in path.read_text(encoding="utf-8").splitlines()
            if line.strip()
        ]
    except (OSError, json.JSONDecodeError) as error:
        raise ExtractionGateError(f"Unreadable JSONL ledger: {path.name}: {error}") from error


def _member_key(record: dict[str, Any]) -> MemberKey:
    return (
        str(record["container"]),
        int(record["depth"]),
        str(record["member"]),
        int(record.get("member_occurrence", 1)),
    )


def load_deep_audit_ledgers(project_root: Path) -> LedgerSnapshot:
    """Load the two current deep-audit ledgers and enforce unique keys."""

    audit_root = project_root / "artifacts" / "asset_audit"
    file_ledger = audit_root / "addons_file_ledger.jsonl"
    member_ledger = audit_root / "archive_member_ledger.jsonl"
    if not file_ledger.is_file() or not member_ledger.is_file():
        raise ExtractionGateError(
            "Missing deep-audit ledgers. Run tools/asset_pipeline/deep_asset_audit.py "
            "before materializing an extraction stage."
        )

    file_records: dict[str, dict[str, Any]] = {}
    file_versions: set[int] = set()
    for record in _jsonl_records(file_ledger):
        path = str(record.get("path", ""))
        if not path:
            raise ExtractionGateError("File ledger contains a record without path")
        if path in file_records:
            raise ExtractionGateError(f"Duplicate physical path in file ledger: {path}")
        file_records[path] = record
        file_versions.add(int(record.get("schema_version", -1)))

    member_records: dict[MemberKey, dict[str, Any]] = {}
    member_versions: set[int] = set()
    for record in _jsonl_records(member_ledger):
        try:
            key = _member_key(record)
        except (KeyError, TypeError, ValueError) as error:
            raise ExtractionGateError("Archive ledger contains an invalid member key") from error
        if key in member_records:
            raise ExtractionGateError(f"Duplicate archive member key in ledger: {key}")
        member_records[key] = record
        member_versions.add(int(record.get("schema_version", -1)))

    if not file_records or not member_records:
        raise ExtractionGateError("Deep-audit ledgers must not be empty")
    return LedgerSnapshot(
        file_records=file_records,
        member_records=member_records,
        file_ledger_sha256=_sha256_file(file_ledger),
        member_ledger_sha256=_sha256_file(member_ledger),
        file_ledger_schema_versions=tuple(sorted(file_versions)),
        member_ledger_schema_versions=tuple(sorted(member_versions)),
    )


def _container_format_from_prefix(prefix: bytes) -> str | None:
    if any(prefix.startswith(signature) for signature in ZIP_SIGNATURES):
        return "zip"
    if prefix.startswith(GZIP_SIGNATURE):
        return "gzip_tar"
    return None


def _detect_container_path(path: Path) -> str | None:
    try:
        with path.open("rb") as handle:
            detected = _container_format_from_prefix(handle.read(4))
    except OSError as error:
        raise ExtractionGateError(f"Cannot inspect source file: {path.name}: {error}") from error
    if path.suffix.casefold() in CONTAINER_EXTENSIONS and detected is None:
        raise ExtractionGateError(
            f"Named container has an unsupported signature: {path.as_posix()}"
        )
    return detected


def _detect_nested_container(prefix: bytes, semantic_name: str) -> str | None:
    detected = _container_format_from_prefix(prefix)
    suffix = Path(semantic_name.replace("\\", "/")).suffix.casefold()
    if suffix in CONTAINER_EXTENSIONS and detected is None:
        raise ExtractionGateError(
            f"Named nested container has an unsupported signature: {semantic_name}"
        )
    return detected


def _magic_name(prefix: bytes) -> str:
    if prefix.startswith(b"\x89PNG\r\n\x1a\n"):
        return "png"
    if prefix.startswith(b"GIF87a") or prefix.startswith(b"GIF89a"):
        return "gif"
    if prefix.startswith(b"\xff\xd8\xff"):
        return "jpeg"
    if prefix.startswith(b"RIFF") and prefix[8:12] == b"WEBP":
        return "webp"
    if prefix.startswith(b"OggS"):
        return "ogg"
    if any(prefix.startswith(signature) for signature in ZIP_SIGNATURES):
        return "zip"
    if prefix.startswith(GZIP_SIGNATURE):
        return "gzip"
    if prefix.startswith(b"%PDF-"):
        return "pdf"
    return "unknown"


def _is_reparse_point(path: Path) -> bool:
    try:
        attributes = getattr(path.lstat(), "st_file_attributes", 0)
    except OSError:
        return False
    return path.is_symlink() or bool(attributes & FILE_ATTRIBUTE_REPARSE_POINT)


def _assert_contained(path: Path, root: Path, label: str) -> None:
    try:
        path.resolve(strict=False).relative_to(root.resolve(strict=False))
    except ValueError as error:
        raise ExtractionGateError(f"{label} escapes its approved root") from error


def _assert_no_reparse_components(path: Path, trusted_root: Path) -> None:
    """Reject symlink/junction traversal in a path we intend to write below."""

    _assert_contained(path, trusted_root, "Stage path")
    # Do not call resolve() before inspecting components: doing so would hide a
    # junction that happens to point back inside the approved stage. The
    # resolved containment check above catches escapes; this lexical walk catches
    # *any* intermediate symlink/reparse point, including an in-tree redirect.
    lexical_root = Path(os.path.abspath(trusted_root))
    lexical_path = Path(os.path.abspath(path))
    try:
        relative = lexical_path.relative_to(lexical_root)
    except ValueError as error:
        raise ExtractionGateError("Stage path is not lexically below its approved root") from error
    if lexical_root.exists() and _is_reparse_point(lexical_root):
        raise ExtractionGateError("Approved stage root is a reparse point")
    current = lexical_root
    for component in relative.parts:
        current = current / component
        if current.exists() and _is_reparse_point(current):
            raise ExtractionGateError(f"Stage path crosses a reparse point: {component}")


def _windows_component_is_safe(component: str) -> None:
    if not component:
        raise ExtractionGateError("Archive member contains an empty path component")
    if len(component) > MAX_MEMBER_COMPONENT_CHARS:
        raise ExtractionGateError("Archive member component exceeds the safe length limit")
    if component[-1] in {".", " "}:
        raise ExtractionGateError("Archive member component has a Windows-trailing dot/space")
    if any(ord(character) < 32 for character in component):
        raise ExtractionGateError("Archive member component contains a control character")
    if any(character in WINDOWS_INVALID_CHARS for character in component):
        raise ExtractionGateError("Archive member component contains a Windows-invalid character")
    # Win32 treats a space/dot immediately before an extension as cosmetic for
    # device-name resolution (for example, ``CON .txt``). Reject that alias too.
    basename = component.split(".", 1)[0].rstrip(" .").upper()
    if basename in WINDOWS_RESERVED_NAMES:
        raise ExtractionGateError(f"Archive member uses Windows reserved device name: {component}")


def normalize_member_path(raw_name: str, *, allow_directory: bool = True) -> MemberPath:
    """Validate an archive-owned pathname without using it as an output path."""

    if not isinstance(raw_name, str) or not raw_name:
        raise ExtractionGateError("Archive member pathname is empty or non-text")
    if "\x00" in raw_name or len(raw_name) > MAX_MEMBER_PATH_CHARS:
        raise ExtractionGateError("Archive member pathname contains NUL or exceeds the safe limit")

    slash_normalized = raw_name.replace("\\", "/")
    is_directory = slash_normalized.endswith("/")
    if slash_normalized.startswith("/") or slash_normalized.startswith("//"):
        raise ExtractionGateError(f"Archive member is absolute or UNC-like: {raw_name}")
    if slash_normalized.startswith("//?/") or slash_normalized.startswith("//./"):
        raise ExtractionGateError(f"Archive member uses a Windows device path: {raw_name}")
    if len(slash_normalized) >= 2 and slash_normalized[1] == ":":
        raise ExtractionGateError(f"Archive member is drive-prefixed: {raw_name}")
    if is_directory:
        if not allow_directory:
            raise ExtractionGateError(f"Directory member is not allowed here: {raw_name}")
        slash_normalized = slash_normalized[:-1]
    if not slash_normalized:
        raise ExtractionGateError(f"Archive member has no usable pathname: {raw_name}")

    raw_components = slash_normalized.split("/")
    if len(raw_components) > MAX_MEMBER_COMPONENTS:
        raise ExtractionGateError("Archive member has too many path components")
    normalized_components: list[str] = []
    for component in raw_components:
        if component in {"", ".", ".."}:
            raise ExtractionGateError(f"Archive member has unsafe path component: {raw_name}")
        normalized = unicodedata.normalize("NFC", component)
        _windows_component_is_safe(normalized)
        normalized_components.append(normalized)

    normalized_path = "/".join(normalized_components)
    return MemberPath(
        raw=raw_name,
        normalized=normalized_path,
        collision_key=normalized_path.casefold(),
        is_directory=is_directory,
    )


def _validate_logical_metadata(raw_value: str | None) -> tuple[str | None, str, str | None]:
    """Keep Unity pathname data as metadata only, never an output selector."""

    if raw_value is None:
        return None, "not_present", None
    if len(raw_value.encode("utf-8", errors="replace")) > MAX_LOGICAL_PATH_BYTES:
        return raw_value[:MAX_LOGICAL_PATH_BYTES], "rejected_metadata_not_used", "too_long"
    try:
        normalized = normalize_member_path(raw_value, allow_directory=False)
    except ExtractionGateError as error:
        return raw_value, "rejected_metadata_not_used", str(error)
    return normalized.normalized, "safe_metadata_not_used", None


def _atomic_write_bytes(path: Path, payload: bytes, stage_root: Path | None = None) -> None:
    if stage_root is not None:
        _assert_no_reparse_components(path.parent, stage_root)
        _assert_contained(path, stage_root, "Stage destination")
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        raise ExtractionGateError(f"Refusing to overwrite existing audit evidence: {path.name}")
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        if stage_root is not None:
            _assert_no_reparse_components(path.parent, stage_root)
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def _atomic_write_json(path: Path, payload: dict[str, Any], stage_root: Path | None = None) -> None:
    _atomic_write_bytes(
        path,
        (json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8"),
        stage_root,
    )


def _atomic_write_jsonl(
    path: Path, records: Iterable[dict[str, Any]], stage_root: Path | None = None
) -> None:
    text = "".join(
        json.dumps(record, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n"
        for record in records
    )
    _atomic_write_bytes(path, text.encode("utf-8"), stage_root)


class ExtractionRun:
    """Owns one fresh artifact run and mutable audit state for that run."""

    def __init__(
        self,
        project_root: Path,
        run_root: Path,
        stage_root: Path,
        limits: ExtractionLimits,
        ledgers: LedgerSnapshot | None,
    ) -> None:
        self.project_root = project_root
        self.run_root = run_root
        self.stage_root = stage_root
        self.limits = limits
        self.ledgers = ledgers
        self.records: list[dict[str, Any]] = []
        self.used_expected_keys: set[MemberKey] = set()
        self.used_expected_loose_paths: set[str] = set()
        self.verified_container_paths: set[str] = set()
        self.loose_records_by_path: dict[str, dict[str, Any]] = {}
        self.container_records_by_path: dict[str, dict[str, Any]] = {}
        self.stage_tokens: dict[str, tuple[str, str]] = {}
        self.stage_payloads: set[str] = set()
        self.container_count = 0
        self.container_ordinal = 0
        self.member_count = 0
        self.loose_file_count = 0
        self.entry_count = 0
        self.declared_run_bytes = 0
        self.materialized_bytes = 0
        self.loose_materialized_bytes = 0
        self.post_stage_physical_rehash_count = 0
        self.post_stage_physical_rehash_bytes = 0
        self.skipped_directories = 0

    def register_container(self, context: ContainerContext) -> None:
        if context.depth > self.limits.max_depth:
            raise ExtractionGateError(
                f"Archive nesting exceeds {self.limits.max_depth}: {context.lineage}"
            )
        self.container_count += 1
        if self.container_count > self.limits.max_containers:
            raise ExtractionGateError("Recursive container count exceeds the run limit")

    def make_context(
        self,
        *,
        source_path: Path,
        lineage: str,
        physical_source: str,
        container_format: str,
        depth: int,
        container_sha256: str,
    ) -> ContainerContext:
        """Give every physical/nested container a stable, short Windows-safe instance id."""

        self.container_ordinal += 1
        identity = hashlib.sha256(
            f"{container_sha256}\0{lineage}\0{self.container_ordinal}".encode("utf-8")
        ).hexdigest()
        context = ContainerContext(
            source_path=source_path,
            lineage=lineage,
            physical_source=physical_source,
            container_format=container_format,
            depth=depth,
            container_sha256=container_sha256,
            instance_id=f"{self.container_ordinal:06d}-{identity[:16]}",
        )
        self.register_container(context)
        return context

    def reserve_members(self, declared_bytes: int, count: int, entries: int | None = None) -> None:
        if declared_bytes < 0 or count < 0 or (entries is not None and entries < 0):
            raise ExtractionGateError("Archive declared a negative member budget")
        entry_count = count if entries is None else entries
        if declared_bytes > self.limits.max_container_bytes:
            raise ExtractionGateError("Container expansion exceeds the per-container limit")
        if self.entry_count + entry_count > self.limits.max_members:
            raise ExtractionGateError("Run archive-entry count exceeds the global limit")
        if self.declared_run_bytes + declared_bytes > self.limits.max_run_bytes:
            raise ExtractionGateError("Run expansion exceeds the global limit")
        self.entry_count += entry_count
        self.member_count += count
        self.declared_run_bytes += declared_bytes

    def reserve_loose_file(self, declared_bytes: int) -> None:
        if declared_bytes < 0 or declared_bytes > self.limits.max_member_bytes:
            raise ExtractionGateError("Loose source file exceeds the per-file limit")
        if self.entry_count + 1 > self.limits.max_members:
            raise ExtractionGateError("Run source-entry count exceeds the global limit")
        if self.declared_run_bytes + declared_bytes > self.limits.max_run_bytes:
            raise ExtractionGateError("Run materialization exceeds the global byte limit")
        self.entry_count += 1
        self.loose_file_count += 1
        self.declared_run_bytes += declared_bytes

    def note_directory(self) -> None:
        self.skipped_directories += 1

    def _stage_directory(self, context: ContainerContext) -> Path:
        token = f"c-{context.container_sha256[:24]}-i-{context.instance_id[:16]}"
        owner = (context.container_sha256, context.instance_id)
        prior = self.stage_tokens.get(token)
        if prior is not None and prior != owner:
            raise ExtractionGateError("Container stage-token collision")
        self.stage_tokens[token] = owner
        destination = self.stage_root / "payloads" / token
        _assert_no_reparse_components(destination, self.stage_root)
        destination.mkdir(parents=True, exist_ok=True)
        return destination

    def _loose_stage_directory(self) -> Path:
        destination = self.stage_root / "payloads" / "loose"
        _assert_no_reparse_components(destination, self.stage_root)
        destination.mkdir(parents=True, exist_ok=True)
        return destination

    def stream_payload(
        self,
        chunks: Iterable[bytes],
        context: ContainerContext,
        ordinal: int,
        declared_bytes: int,
        expected_crc32: int | None,
    ) -> PayloadResult:
        """Hash, fsync, and atomically publish one payload inside the fixed stage."""

        if declared_bytes < 0 or declared_bytes > self.limits.max_member_bytes:
            raise ExtractionGateError("Archive member exceeds the per-member limit")
        output_directory = self._stage_directory(context)
        descriptor, temporary_name = tempfile.mkstemp(
            prefix=f".m-{ordinal:06d}.", suffix=".tmp", dir=output_directory
        )
        temporary = Path(temporary_name)
        digest = hashlib.sha256()
        crc = 0
        bytes_written = 0
        prefix = bytearray()
        try:
            with os.fdopen(descriptor, "wb") as output:
                for chunk in chunks:
                    if not isinstance(chunk, bytes):
                        raise ExtractionGateError("Archive stream produced non-bytes data")
                    if not chunk:
                        continue
                    bytes_written += len(chunk)
                    if bytes_written > declared_bytes or bytes_written > self.limits.max_member_bytes:
                        raise ExtractionGateError("Archive member stream exceeds its declared limit")
                    digest.update(chunk)
                    crc = binascii.crc32(chunk, crc)
                    if len(prefix) < 32:
                        prefix.extend(chunk[: 32 - len(prefix)])
                    output.write(chunk)
                output.flush()
                os.fsync(output.fileno())
            if bytes_written != declared_bytes:
                raise ExtractionGateError(
                    f"Archive member size mismatch: expected {declared_bytes}, got {bytes_written}"
                )
            crc &= 0xFFFFFFFF
            if expected_crc32 is not None and crc != expected_crc32:
                raise ExtractionGateError("Archive member CRC verification failed")
            content_hash = digest.hexdigest()
            destination = output_directory / f"m-{ordinal:06d}-{content_hash[:24]}.bin"
            _assert_no_reparse_components(destination.parent, self.stage_root)
            if destination.exists():
                raise ExtractionGateError("Refusing to overwrite a staged payload")
            relative = destination.relative_to(self.run_root).as_posix()
            if relative in self.stage_payloads:
                raise ExtractionGateError("Duplicate stage payload path")
            os.replace(temporary, destination)
            self.stage_payloads.add(relative)
            self.materialized_bytes += bytes_written
            return PayloadResult(
                stage_relative_path=relative,
                sha256=content_hash,
                bytes_written=bytes_written,
                crc32=f"{crc:08x}",
                magic=_magic_name(bytes(prefix)),
                prefix=bytes(prefix),
                destination=destination,
            )
        finally:
            temporary.unlink(missing_ok=True)

    def stream_loose_file(
        self,
        source_path: Path,
        *,
        source_sequence: int,
        declared_bytes: int,
    ) -> PayloadResult:
        """Stream one non-container physical source file into fixed audit storage."""

        self.reserve_loose_file(declared_bytes)
        output_directory = self._loose_stage_directory()
        descriptor, temporary_name = tempfile.mkstemp(
            prefix=f".l-{source_sequence:06d}.", suffix=".tmp", dir=output_directory
        )
        temporary = Path(temporary_name)
        digest = hashlib.sha256()
        crc = 0
        bytes_written = 0
        prefix = bytearray()
        try:
            with os.fdopen(descriptor, "wb") as output, source_path.open("rb") as source:
                for chunk in _stream_handle(source):
                    bytes_written += len(chunk)
                    if bytes_written > declared_bytes or bytes_written > self.limits.max_member_bytes:
                        raise ExtractionGateError("Loose source stream exceeds its declared limit")
                    digest.update(chunk)
                    crc = binascii.crc32(chunk, crc)
                    if len(prefix) < 32:
                        prefix.extend(chunk[: 32 - len(prefix)])
                    output.write(chunk)
                output.flush()
                os.fsync(output.fileno())
            if bytes_written != declared_bytes:
                raise ExtractionGateError(
                    f"Loose source size mismatch: expected {declared_bytes}, got {bytes_written}"
                )
            crc &= 0xFFFFFFFF
            content_hash = digest.hexdigest()
            destination = output_directory / f"l-{source_sequence:06d}-{content_hash[:24]}.bin"
            _assert_no_reparse_components(destination.parent, self.stage_root)
            if destination.exists():
                raise ExtractionGateError("Refusing to overwrite a staged loose source payload")
            relative = destination.relative_to(self.run_root).as_posix()
            if relative in self.stage_payloads:
                raise ExtractionGateError("Duplicate staged loose source payload path")
            os.replace(temporary, destination)
            self.stage_payloads.add(relative)
            self.materialized_bytes += bytes_written
            self.loose_materialized_bytes += bytes_written
            return PayloadResult(
                stage_relative_path=relative,
                sha256=content_hash,
                bytes_written=bytes_written,
                crc32=f"{crc:08x}",
                magic=_magic_name(bytes(prefix)),
                prefix=bytes(prefix),
                destination=destination,
            )
        except OSError as error:
            raise ExtractionGateError(f"Cannot stream loose source file: {source_path.name}: {error}") from error
        finally:
            temporary.unlink(missing_ok=True)

    def expected_member(
        self,
        context: ContainerContext,
        member: str,
        occurrence: int,
        result: PayloadResult,
        declared_bytes: int,
        crc32: str | None,
    ) -> dict[str, Any] | None:
        if self.ledgers is None:
            return None
        key = (context.lineage, context.depth, member, occurrence)
        expected = self.ledgers.member_records.get(key)
        if expected is None:
            raise ExtractionGateError(f"Staged member is absent from deep-audit ledger: {key}")
        if int(expected.get("bytes", -1)) != declared_bytes:
            raise ExtractionGateError(f"Ledger byte mismatch for archive member: {key}")
        if str(expected.get("sha256", "")) != result.sha256:
            raise ExtractionGateError(f"Ledger hash mismatch for archive member: {key}")
        if str(expected.get("container_format", "")) != context.container_format:
            raise ExtractionGateError(f"Ledger format mismatch for archive member: {key}")
        expected_crc = expected.get("crc32")
        if expected_crc is not None and crc32 is not None and str(expected_crc) != crc32:
            raise ExtractionGateError(f"Ledger CRC mismatch for archive member: {key}")
        self.used_expected_keys.add(key)
        return expected

    def expected_loose_file(
        self,
        source_path: str,
        result: PayloadResult,
        declared_bytes: int,
    ) -> dict[str, Any] | None:
        if self.ledgers is None:
            return None
        expected = self.ledgers.file_records.get(source_path)
        if expected is None or expected.get("container_format") is not None:
            raise ExtractionGateError(f"Staged loose file is absent/non-loose in deep file ledger: {source_path}")
        if int(expected.get("bytes", -1)) != declared_bytes:
            raise ExtractionGateError(f"File-ledger byte mismatch for loose source: {source_path}")
        if str(expected.get("sha256", "")) != result.sha256:
            raise ExtractionGateError(f"File-ledger hash mismatch for loose source: {source_path}")
        self.used_expected_loose_paths.add(source_path)
        return expected

    def append_loose_record(
        self,
        *,
        source_path: str,
        source_sequence: int,
        declared_bytes: int,
        result: PayloadResult,
        expected: dict[str, Any] | None,
    ) -> None:
        source_key = hashlib.sha256(f"loose\0{source_path}\0{result.sha256}".encode("utf-8")).hexdigest()
        record = {
                "schema_version": SCHEMA_VERSION,
                "generator": GENERATOR,
                "record_type": "physical_loose_file",
                "source_key": source_key,
                "source_path": source_path,
                "source_sequence": source_sequence,
                "source_bytes": declared_bytes,
                "source_sha256": result.sha256,
                "source_crc32": result.crc32,
                "magic": result.magic,
                "artifact_relative_path": result.stage_relative_path,
                "artifact_sha256": result.sha256,
                "artifact_bytes": result.bytes_written,
                "write_status": "streamed_fsync_atomic_rename",
                "safety_status": "physical_regular_file_contained_no_reparse",
                "integrity_status": "streamed_sha256_file_ledger_valid",
                "ledger_status": "matched" if expected is not None else "not_checked_fixture_mode",
                "content_kind": expected.get("content_kind") if expected is not None else None,
                "decision": expected.get("decision") if expected is not None else None,
                "role_tags": expected.get("role_tags") if expected is not None else [],
                "quality_flags": expected.get("quality_flags") if expected is not None else [],
        }
        if source_path in self.loose_records_by_path:
            raise ExtractionGateError(f"Duplicate loose source evidence record: {source_path}")
        self.loose_records_by_path[source_path] = record
        self.records.append(record)

    def append_container_verification(
        self, container: "PhysicalContainer", expected: dict[str, Any] | None
    ) -> None:
        self.verified_container_paths.add(container.relative_path)
        record = {
                "schema_version": SCHEMA_VERSION,
                "generator": GENERATOR,
                "record_type": "physical_container_verification",
                "source_path": container.relative_path,
                "source_bytes": container.bytes,
                "source_sha256": container.sha256,
                "container_format": container.container_format,
                "materialized_wrapper": False,
                "coverage": "contents_materialized_as_archive_members",
                "write_status": "not_copied_by_design",
                "safety_status": "physical_regular_file_contained_no_reparse",
                "integrity_status": "sha256_file_ledger_valid",
                "ledger_status": "matched" if expected is not None else "not_checked_fixture_mode",
        }
        if container.relative_path in self.container_records_by_path:
            raise ExtractionGateError(
                f"Duplicate physical container verification record: {container.relative_path}"
            )
        self.container_records_by_path[container.relative_path] = record
        self.records.append(record)

    def append_record(
        self,
        *,
        context: ContainerContext,
        member_path: MemberPath,
        member_occurrence: int,
        member_ordinal: int,
        declared_bytes: int,
        compressed_bytes: int | None,
        crc32: str | None,
        result: PayloadResult,
        nested_container_format: str | None,
        expected: dict[str, Any] | None,
        logical_path: str | None = None,
        logical_path_safety: str = "not_present",
        logical_path_reason: str | None = None,
        integrity_status: str = "staged_streamed_crc_valid",
        quality_flags: list[str] | None = None,
    ) -> None:
        compression_ratio = None
        if compressed_bytes is not None:
            compression_ratio = (
                None
                if compressed_bytes == 0 and declared_bytes == 0
                else round(declared_bytes / max(compressed_bytes, 1), 6)
            )
        source_key_input = (
            f"{context.container_sha256}\0{context.depth}\0{member_path.normalized}\0"
            f"{member_occurrence}\0{result.sha256}"
        ).encode("utf-8")
        record: dict[str, Any] = {
            "schema_version": SCHEMA_VERSION,
            "generator": GENERATOR,
            "record_type": "archive_member",
            "source_key": hashlib.sha256(source_key_input).hexdigest(),
            "physical_source": context.physical_source,
            "container": context.lineage,
            "container_sha256": context.container_sha256,
            "container_instance_id": context.instance_id,
            "container_format": context.container_format,
            "depth": context.depth,
            "member": member_path.raw.replace("\\", "/"),
            "member_normalized": member_path.normalized,
            "canonical_member_key": member_path.collision_key,
            "member_occurrence": member_occurrence,
            "member_ordinal": member_ordinal,
            "bytes": declared_bytes,
            "compressed_bytes": compressed_bytes,
            "compression_ratio": compression_ratio,
            "crc32": crc32,
            "member_sha256": result.sha256,
            "magic": result.magic,
            "nested_container_format": nested_container_format,
            "artifact_relative_path": result.stage_relative_path,
            "artifact_sha256": result.sha256,
            "artifact_bytes": result.bytes_written,
            "write_status": "streamed_fsync_atomic_rename",
            "safety_status": "path_safe_windows_safe_contained",
            "integrity_status": integrity_status,
            "ledger_status": "matched" if expected is not None else "not_checked_fixture_mode",
            "deep_audit_status": expected.get("status") if expected is not None else None,
            "content_kind": expected.get("content_kind") if expected is not None else None,
            "decision": expected.get("decision") if expected is not None else None,
            "role_tags": expected.get("role_tags") if expected is not None else [],
            "logical_path": logical_path,
            "logical_path_safety": logical_path_safety,
            "logical_path_reason": logical_path_reason,
            "quality_flags": quality_flags or [],
        }
        self.records.append(record)

    def verify_completion(self) -> None:
        if self.ledgers is None:
            return
        missing = sorted(set(self.ledgers.member_records) - self.used_expected_keys)
        unexpected = sorted(self.used_expected_keys - set(self.ledgers.member_records))
        if unexpected:
            raise ExtractionGateError(f"Unexpected staged member ledger keys: {unexpected[:3]}")
        if missing:
            raise ExtractionGateError(
                f"Deep-audit ledger members not materialized: {len(missing)}; first={missing[0]}"
            )
        expected_loose = {
            path for path, record in self.ledgers.file_records.items() if record.get("container_format") is None
        }
        expected_containers = set(self.ledgers.file_records) - expected_loose
        missing_loose = sorted(expected_loose - self.used_expected_loose_paths)
        unexpected_loose = sorted(self.used_expected_loose_paths - expected_loose)
        if missing_loose or unexpected_loose:
            raise ExtractionGateError(
                "Deep file-ledger loose-file coverage mismatch: "
                f"missing={len(missing_loose)} unexpected={len(unexpected_loose)}"
            )
        missing_containers = sorted(expected_containers - self.verified_container_paths)
        unexpected_containers = sorted(self.verified_container_paths - expected_containers)
        if missing_containers or unexpected_containers:
            raise ExtractionGateError(
                "Deep file-ledger physical-container coverage mismatch: "
                f"missing={len(missing_containers)} unexpected={len(unexpected_containers)}"
            )

    def reject(
        self,
        error: BaseException,
        *,
        scope: str = "run",
        context: ContainerContext | None = None,
        member: str | None = None,
    ) -> None:
        """Persist a non-payload rejection row even when extraction aborts early."""

        self.records.append(
            {
                "schema_version": SCHEMA_VERSION,
                "generator": GENERATOR,
                "record_type": "gate_rejection",
                "safety_status": "rejected",
                "write_status": "not_written",
                "integrity_status": "not_complete",
                "scope": scope,
                "rejection_type": type(error).__name__,
                "rejection_reason": str(error),
                "container": context.lineage if context else None,
                "physical_source": context.physical_source if context else None,
                "container_sha256": context.container_sha256 if context else None,
                "member": member,
                "artifact_relative_path": None,
            }
        )


def _relative_addons_path(project_root: Path, path: Path) -> str:
    """Return a ledger-compatible source identifier without host-specific paths."""

    try:
        relative = path.relative_to(project_root)
    except ValueError as error:
        raise ExtractionGateError("Physical archive is outside the approved project root") from error
    return relative.as_posix()


def _run_id_or_default(run_id: str | None) -> str:
    candidate = run_id or datetime.now(UTC).strftime("vault-%Y%m%dT%H%M%SZ")
    if not RUN_ID_RE.fullmatch(candidate):
        raise ExtractionGateError(
            "Run id must be 1-64 ASCII letters, digits, underscores, or hyphens"
        )
    return candidate


def _create_run_roots(project_root: Path, run_id: str) -> tuple[Path, Path]:
    """Create a fresh audited output root; no caller-controlled archive name participates."""

    audit_root = project_root / "artifacts" / "asset_audit" / "extraction_runs"
    _assert_contained(audit_root, project_root, "Extraction audit root")
    _assert_no_reparse_components(audit_root.parent, project_root)
    audit_root.mkdir(parents=True, exist_ok=True)
    _assert_no_reparse_components(audit_root, project_root)
    run_root = audit_root / run_id
    _assert_contained(run_root, audit_root, "Extraction run root")
    if run_root.exists():
        raise ExtractionGateError(
            f"Extraction run already exists and is immutable: {run_root.name}"
        )
    run_root.mkdir()
    stage_root = run_root / "stage"
    _assert_no_reparse_components(stage_root.parent, audit_root)
    stage_root.mkdir()
    _atomic_write_bytes(
        stage_root / ".gdignore",
        b"# Audit-only archive extraction stage. Never import or promote directly.\n",
        stage_root,
    )
    return run_root, stage_root


def _stream_handle(handle: BinaryIO) -> Iterator[bytes]:
    while True:
        block = handle.read(READ_BLOCK_BYTES)
        if not block:
            return
        yield block


def _source_size(path: Path) -> int:
    try:
        return path.stat().st_size
    except OSError as error:
        raise ExtractionGateError(f"Cannot stat archive source: {path.name}: {error}") from error


def _assert_regular_source(path: Path, approved_root: Path) -> None:
    _assert_contained(path, approved_root, "Archive source")
    if _is_reparse_point(path):
        raise ExtractionGateError(f"Archive source is a symlink/reparse point: {path.name}")
    try:
        mode = path.stat().st_mode
    except OSError as error:
        raise ExtractionGateError(f"Cannot inspect archive source: {path.name}: {error}") from error
    if not stat.S_ISREG(mode):
        raise ExtractionGateError(f"Archive source is not a regular file: {path.name}")


def _zip_mode_is_symlink(info: zipfile.ZipInfo) -> bool:
    return stat.S_ISLNK((int(info.external_attr) >> 16) & 0xFFFF)


def _zip_info_is_directory(info: zipfile.ZipInfo) -> bool:
    return info.is_dir() or info.filename.replace("\\", "/").endswith("/")


@contextlib.contextmanager
def _open_zip_source(source_path: Path, lineage: str) -> Iterator[tuple[zipfile.ZipFile, bytes | None]]:
    """Open ZIP normally, with a bounded Adobe-Animate central-directory repair fallback.

    The fallback is deliberately limited to a small *container* buffer. It exists
    for the two current malformed FLA files already captured by the deep audit;
    ordinary member payloads are always streamed and are never read wholesale.
    """

    try:
        archive = zipfile.ZipFile(source_path, mode="r")
    except zipfile.BadZipFile as original_error:
        source_bytes = _source_size(source_path)
        if source_bytes > MAX_REPAIRED_ZIP_BYTES:
            raise ExtractionGateError(
                f"Malformed ZIP exceeds bounded repair allowance ({MAX_REPAIRED_ZIP_BYTES} bytes): {lineage}"
            ) from original_error
        try:
            with source_path.open("rb") as handle:
                raw = handle.read(MAX_REPAIRED_ZIP_BYTES + 1)
            if len(raw) != source_bytes or len(raw) > MAX_REPAIRED_ZIP_BYTES:
                raise ExtractionGateError(f"Cannot safely buffer malformed ZIP: {lineage}")
            repaired = _normalized_zip_bytes(raw, lineage)
            archive = zipfile.ZipFile(io.BytesIO(repaired), mode="r")
        except (OSError, DeepAuditError, zipfile.BadZipFile) as error:
            raise ExtractionGateError(f"Unreadable ZIP archive: {lineage}: {error}") from error
        try:
            yield archive, repaired
        finally:
            archive.close()
        return
    except OSError as error:
        raise ExtractionGateError(f"Cannot open ZIP archive: {lineage}: {error}") from error
    try:
        yield archive, None
    finally:
        archive.close()


@dataclass(frozen=True, slots=True)
class OrphanZipEntry:
    """A valid local ZIP header omitted by a repaired/stale central directory."""

    name: str
    occurrence: int
    ordinal: int
    declared_bytes: int
    compressed_bytes: int
    crc32: int
    method: int
    compressed_offset: int


def _iter_orphan_zip_entries(
    archive_bytes: bytes,
    lineage: str,
    infos: list[zipfile.ZipInfo],
) -> Iterator[OrphanZipEntry]:
    """Find only unindexed local records, without trusting them as destinations."""

    central_counts: Counter[tuple[str, int, int, int]] = Counter(
        (
            info.filename.replace("\\", "/").casefold(),
            int(info.CRC),
            int(info.compress_size),
            int(info.file_size),
        )
        for info in infos
        if not _zip_info_is_directory(info)
    )
    central_by_offset = {int(info.header_offset): info for info in infos}
    eocd_offset = archive_bytes.rfind(b"PK\x05\x06")
    if eocd_offset < 0:
        raise ExtractionGateError(f"Malformed ZIP has no end record: {lineage}")
    first_local = archive_bytes.find(b"PK\x03\x04")
    if first_local < 0 or first_local >= eocd_offset:
        return
    local_counts: Counter[tuple[str, int, int, int]] = Counter()
    position = first_local
    ordinal = len(infos)
    while position < eocd_offset and archive_bytes.startswith(b"PK\x03\x04", position):
        if position + 30 > len(archive_bytes):
            raise ExtractionGateError(f"Truncated ZIP local header: {lineage}@{position}")
        (
            _signature,
            _version,
            flags,
            method,
            _time,
            _date,
            local_crc,
            local_compressed_bytes,
            local_uncompressed_bytes,
            name_bytes,
            extra_bytes,
        ) = struct.unpack_from("<I5H3L2H", archive_bytes, position)
        if flags & 0x1:
            raise ExtractionGateError(f"Encrypted orphan ZIP member: {lineage}@{position}")
        name_start = position + 30
        name_end = name_start + name_bytes
        data_start = name_end + extra_bytes
        if data_start > len(archive_bytes):
            raise ExtractionGateError(f"Truncated ZIP member name: {lineage}@{position}")
        encoding = "utf-8" if flags & 0x800 else "cp437"
        member_name = archive_bytes[name_start:name_end].decode(encoding, errors="strict")
        member_path = normalize_member_path(member_name)
        indexed = central_by_offset.get(position)
        crc32 = int(indexed.CRC) if indexed is not None else int(local_crc)
        compressed_bytes = int(indexed.compress_size) if indexed is not None else int(local_compressed_bytes)
        declared_bytes = int(indexed.file_size) if indexed is not None else int(local_uncompressed_bytes)
        if compressed_bytes < 0 or declared_bytes < 0:
            raise ExtractionGateError(f"Negative ZIP member size: {lineage}!{member_name}")
        data_end = data_start + compressed_bytes
        if data_end > len(archive_bytes):
            raise ExtractionGateError(f"Truncated ZIP payload: {lineage}!{member_name}")
        key = (member_path.normalized.casefold(), crc32, compressed_bytes, declared_bytes)
        local_counts[key] += 1
        if not member_path.is_directory and local_counts[key] > central_counts[key]:
            if method not in {zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED}:
                raise ExtractionGateError(
                    f"Unsupported orphan ZIP compression method {method}: {lineage}!{member_name}"
                )
            ratio = declared_bytes / max(compressed_bytes, 1)
            if compressed_bytes > 0 and ratio > DEFAULT_LIMITS.max_compression_ratio:
                # The caller repeats this using its actual configured limit; this catches
                # obviously hostile headers before an allocation/decompression decision.
                raise ExtractionGateError(f"Orphan ZIP compression ratio is unsafe: {lineage}!{member_name}")
            ordinal += 1
            yield OrphanZipEntry(
                name=member_name,
                occurrence=local_counts[key],
                ordinal=ordinal,
                declared_bytes=declared_bytes,
                compressed_bytes=compressed_bytes,
                crc32=crc32,
                method=method,
                compressed_offset=data_start,
            )
        position = data_end
        if flags & 0x08:
            nearby_offsets = [
                found
                for signature in (b"PK\x03\x04", b"PK\x01\x02")
                if (found := archive_bytes.find(signature, position, min(position + 25, len(archive_bytes)))) >= 0
            ]
            if not nearby_offsets:
                raise ExtractionGateError(f"Missing ZIP data-descriptor boundary: {lineage}")
            position = min(nearby_offsets)


def _stream_orphan_zip_payload(
    archive_bytes: bytes, entry: OrphanZipEntry
) -> Iterator[bytes]:
    """Yield an orphan local payload incrementally; only stored/deflated are admitted."""

    compressed = memoryview(archive_bytes)[
        entry.compressed_offset : entry.compressed_offset + entry.compressed_bytes
    ]
    if entry.method == zipfile.ZIP_STORED:
        for start in range(0, len(compressed), READ_BLOCK_BYTES):
            yield bytes(compressed[start : start + READ_BLOCK_BYTES])
        return
    decompressor = zlib.decompressobj(-15)
    for start in range(0, len(compressed), READ_BLOCK_BYTES):
        pending = bytes(compressed[start : start + READ_BLOCK_BYTES])
        while pending:
            output = decompressor.decompress(pending, READ_BLOCK_BYTES)
            pending = decompressor.unconsumed_tail
            if output:
                yield output
            elif pending:
                raise ExtractionGateError("Malformed orphan ZIP deflate stream stalled")
    final = decompressor.flush(READ_BLOCK_BYTES)
    if final:
        yield final
    if not decompressor.eof or decompressor.unused_data:
        raise ExtractionGateError("Malformed orphan ZIP deflate stream")


@dataclass(frozen=True, slots=True)
class PhysicalContainer:
    path: Path
    relative_path: str
    container_format: str
    sha256: str
    bytes: int


@dataclass(frozen=True, slots=True)
class PhysicalLooseFile:
    """A physical Addons file that is not itself a supported archive container."""

    path: Path
    relative_path: str
    bytes: int
    source_sequence: int
    expected_sha256: str | None


@dataclass(frozen=True, slots=True)
class DiscoveredSource:
    path: Path
    relative_path: str
    bytes: int
    container_format: str | None


@dataclass(frozen=True, slots=True)
class PreparedTarEntry:
    raw_name: str
    member_path: MemberPath
    size: int
    is_directory: bool


def _discover_physical_sources(project_root: Path) -> dict[str, DiscoveredSource]:
    """Inventory every physical Addons file before any evidence is staged."""

    addons_root = project_root / "Addons"
    if not addons_root.is_dir() or _is_reparse_point(addons_root):
        raise ExtractionGateError("Addons source vault is missing or is a reparse point")
    discovered: dict[str, DiscoveredSource] = {}
    try:
        candidates = sorted(addons_root.rglob("*"), key=lambda item: item.as_posix().casefold())
    except OSError as error:
        raise ExtractionGateError(f"Cannot enumerate Addons vault: {error}") from error
    for path in candidates:
        if not path.is_file():
            continue
        _assert_regular_source(path, addons_root)
        detected = _detect_container_path(path)
        relative = _relative_addons_path(project_root, path)
        if relative in discovered:
            raise ExtractionGateError(f"Duplicate physical source identity: {relative}")
        discovered[relative] = DiscoveredSource(
            path=path,
            relative_path=relative,
            container_format=detected,
            bytes=_source_size(path),
        )
    return discovered


def _preflight_physical_sources(
    project_root: Path, ledgers: LedgerSnapshot | None
) -> tuple[list[PhysicalContainer], list[PhysicalLooseFile]]:
    discovered = _discover_physical_sources(project_root)
    if ledgers is None:
        containers: list[PhysicalContainer] = []
        loose_files: list[PhysicalLooseFile] = []
        for sequence, relative in enumerate(sorted(discovered, key=str.casefold), start=1):
            source = discovered[relative]
            if source.container_format is None:
                loose_files.append(
                    PhysicalLooseFile(
                        path=source.path,
                        relative_path=source.relative_path,
                        bytes=source.bytes,
                        source_sequence=sequence,
                        expected_sha256=None,
                    )
                )
            else:
                containers.append(
                    PhysicalContainer(
                        path=source.path,
                        relative_path=source.relative_path,
                        container_format=source.container_format,
                        sha256=_sha256_file(source.path),
                        bytes=source.bytes,
                    )
                )
        return containers, loose_files

    expected = ledgers.file_records
    missing = sorted(set(expected) - set(discovered))
    extra = sorted(set(discovered) - set(expected))
    if missing or extra:
        raise ExtractionGateError(
            "Physical Addons file set differs from deep-audit file ledger: "
            f"missing={len(missing)} extra={len(extra)}"
        )
    containers: list[PhysicalContainer] = []
    loose_files: list[PhysicalLooseFile] = []
    for relative, record in sorted(
        expected.items(), key=lambda item: (int(item[1].get("sequence", 0)), item[0].casefold())
    ):
        current = discovered[relative]
        expected_format = record.get("container_format")
        if expected_format != current.container_format:
            raise ExtractionGateError(f"Physical source container format changed: {relative}")
        if int(record.get("bytes", -1)) != current.bytes:
            raise ExtractionGateError(f"Physical source byte count changed: {relative}")
        if expected_format is None:
            loose_files.append(
                PhysicalLooseFile(
                    path=current.path,
                    relative_path=relative,
                    bytes=current.bytes,
                    source_sequence=int(record.get("sequence", 0)),
                    expected_sha256=str(record.get("sha256", "")),
                )
            )
            continue
        current_hash = _sha256_file(current.path)
        if str(record.get("sha256", "")) != current_hash:
            raise ExtractionGateError(f"Physical container hash changed: {relative}")
        containers.append(
            PhysicalContainer(
                path=current.path,
                relative_path=relative,
                container_format=str(expected_format),
                sha256=current_hash,
                bytes=current.bytes,
            )
        )
    return containers, loose_files


def _disk_preflight(
    project_root: Path,
    ledgers: LedgerSnapshot | None,
    containers: list[PhysicalContainer],
    loose_files: list[PhysicalLooseFile],
    limits: ExtractionLimits,
) -> dict[str, int]:
    """Reserve enough room for all payloads plus the largest atomic-write temp file."""

    if ledgers is not None:
        archive_member_sizes = [int(record["bytes"]) for record in ledgers.member_records.values()]
        loose_sizes = [int(record["bytes"]) for record in ledgers.file_records.values() if record.get("container_format") is None]
    else:
        # Fixture mode cannot know archive expansion ahead of time. It still
        # reserves all loose source bytes and physical archive source bytes.
        archive_member_sizes = [container.bytes for container in containers]
        loose_sizes = [file.bytes for file in loose_files]
    declared_sizes = archive_member_sizes + loose_sizes
    declared_total = sum(declared_sizes)
    largest_member = max(declared_sizes, default=0)
    if declared_total > limits.max_run_bytes:
        raise ExtractionGateError("Combined archive-member and loose-file total exceeds the run limit")
    if largest_member > limits.max_member_bytes:
        raise ExtractionGateError("Deep-audit member exceeds the configured member limit")
    reserve_bytes = declared_total + largest_member + 64 * 1024 * 1024
    audit_parent = project_root / "artifacts" / "asset_audit"
    audit_parent.mkdir(parents=True, exist_ok=True)
    free_bytes = shutil.disk_usage(audit_parent).free
    if free_bytes < reserve_bytes:
        raise ExtractionGateError(
            f"Insufficient disk for atomic extraction stage: need {reserve_bytes}, have {free_bytes}"
        )
    return {
        "declared_archive_member_bytes": sum(archive_member_sizes),
        "declared_loose_file_bytes": sum(loose_sizes),
        "declared_materialization_bytes": declared_total,
        "largest_member_bytes": largest_member,
        "required_free_bytes": reserve_bytes,
        "observed_free_bytes": free_bytes,
    }


def _assert_context_source_unchanged(context: ContainerContext) -> None:
    if _sha256_file(context.source_path) != context.container_sha256:
        raise ExtractionGateError(f"Archive source changed during extraction: {context.lineage}")


def _materialize_loose_files(
    run: ExtractionRun,
    loose_files: list[PhysicalLooseFile],
) -> None:
    """Stage every non-container physical vault file against the deep file ledger."""

    addons_root = run.project_root / "Addons"
    for source in loose_files:
        _assert_regular_source(source.path, addons_root)
        result = run.stream_loose_file(
            source.path,
            source_sequence=source.source_sequence,
            declared_bytes=source.bytes,
        )
        expected = run.expected_loose_file(source.relative_path, result, source.bytes)
        if source.expected_sha256 is not None and result.sha256 != source.expected_sha256:
            raise ExtractionGateError(f"Loose source hash changed during staging: {source.relative_path}")
        run.append_loose_record(
            source_path=source.relative_path,
            source_sequence=source.source_sequence,
            declared_bytes=source.bytes,
            result=result,
            expected=expected,
        )


def _post_stage_rehash_physical_sources(
    run: ExtractionRun,
    physical_containers: list[PhysicalContainer],
    loose_files: list[PhysicalLooseFile],
) -> None:
    """Close the concurrent-mutation window after every stage payload is published.

    This intentionally re-hashes every physical vault file (including archive
    wrappers that are not copied) after loose-file and archive-member staging.
    A complete manifest can therefore attest to one post-stage file-ledger
    checkpoint, rather than only the moment each individual stream was read.
    """

    addons_root = run.project_root / "Addons"
    for source in loose_files:
        _assert_regular_source(source.path, addons_root)
        if _source_size(source.path) != source.bytes:
            raise ExtractionGateError(f"Loose source changed after staging: {source.relative_path}")
        digest = _sha256_file(source.path)
        expected_hash = source.expected_sha256
        if expected_hash is None:
            record = run.loose_records_by_path.get(source.relative_path)
            expected_hash = str(record.get("source_sha256", "")) if record else None
        if not expected_hash or digest != expected_hash:
            raise ExtractionGateError(f"Loose source hash changed after staging: {source.relative_path}")
        record = run.loose_records_by_path.get(source.relative_path)
        if record is None:
            raise ExtractionGateError(f"Missing loose source evidence record: {source.relative_path}")
        record["post_stage_source_bytes"] = source.bytes
        record["post_stage_source_sha256"] = digest
        record["post_stage_integrity_status"] = "sha256_file_ledger_valid"
        run.post_stage_physical_rehash_count += 1
        run.post_stage_physical_rehash_bytes += source.bytes

    for container in physical_containers:
        _assert_regular_source(container.path, addons_root)
        if _source_size(container.path) != container.bytes:
            raise ExtractionGateError(f"Archive wrapper changed after staging: {container.relative_path}")
        digest = _sha256_file(container.path)
        if digest != container.sha256:
            raise ExtractionGateError(f"Archive wrapper hash changed after staging: {container.relative_path}")
        record = run.container_records_by_path.get(container.relative_path)
        if record is None:
            raise ExtractionGateError(f"Missing physical container evidence record: {container.relative_path}")
        record["post_stage_source_bytes"] = container.bytes
        record["post_stage_source_sha256"] = digest
        record["post_stage_integrity_status"] = "sha256_file_ledger_valid"
        run.post_stage_physical_rehash_count += 1
        run.post_stage_physical_rehash_bytes += container.bytes

    expected_count = len(loose_files) + len(physical_containers)
    if run.post_stage_physical_rehash_count != expected_count:
        raise ExtractionGateError("Post-stage physical source rehash coverage is incomplete")


def _validate_live_file_ledger(
    project_root: Path, ledgers: LedgerSnapshot
) -> tuple[int, int]:
    """Read-only current-source proof used by the production run validator."""

    containers, loose_files = _preflight_physical_sources(project_root, ledgers)
    for source in loose_files:
        if source.expected_sha256 is None or _sha256_file(source.path) != source.expected_sha256:
            raise ExtractionGateError(f"Live loose source hash differs from deep file ledger: {source.relative_path}")
    all_bytes = sum(container.bytes for container in containers) + sum(
        source.bytes for source in loose_files
    )
    return len(containers) + len(loose_files), all_bytes


def _zip_preflight(
    archive: zipfile.ZipFile,
    repaired_bytes: bytes | None,
    context: ContainerContext,
    run: ExtractionRun,
) -> tuple[list[tuple[zipfile.ZipInfo, MemberPath]], list[OrphanZipEntry]]:
    infos = archive.infolist()
    if len(infos) > run.limits.max_members:
        raise ExtractionGateError(f"ZIP has too many central members: {context.lineage}")
    seen: dict[str, str] = {}
    prepared: list[tuple[zipfile.ZipInfo, MemberPath]] = []
    declared_bytes = 0
    file_count = 0
    for info in infos:
        member_path = normalize_member_path(info.filename)
        prior = seen.get(member_path.collision_key)
        if prior is not None:
            raise ExtractionGateError(
                f"ZIP member case/Unicode collision: {context.lineage}!{info.filename} conflicts with {prior}"
            )
        seen[member_path.collision_key] = info.filename
        if _zip_mode_is_symlink(info):
            raise ExtractionGateError(f"ZIP symlink member rejected: {context.lineage}!{info.filename}")
        if int(info.flag_bits) & 0x1:
            raise ExtractionGateError(f"Encrypted ZIP member rejected: {context.lineage}!{info.filename}")
        if _zip_info_is_directory(info):
            prepared.append((info, member_path))
            continue
        if info.file_size < 0 or info.compress_size < 0:
            raise ExtractionGateError(f"ZIP member has negative size: {context.lineage}!{info.filename}")
        if info.file_size > run.limits.max_member_bytes:
            raise ExtractionGateError(f"ZIP member exceeds limit: {context.lineage}!{info.filename}")
        ratio = info.file_size / max(info.compress_size, 1)
        if info.compress_size > 0 and ratio > run.limits.max_compression_ratio:
            raise ExtractionGateError(f"ZIP member compression ratio exceeds limit: {context.lineage}!{info.filename}")
        declared_bytes += int(info.file_size)
        file_count += 1
        prepared.append((info, member_path))

    orphan_entries: list[OrphanZipEntry] = []
    if repaired_bytes is not None:
        orphan_entries = list(_iter_orphan_zip_entries(repaired_bytes, context.lineage, infos))
        for orphan in orphan_entries:
            orphan_path = normalize_member_path(orphan.name)
            prior = seen.get(orphan_path.collision_key)
            if prior is not None and prior.replace("\\", "/") != orphan.name.replace("\\", "/"):
                raise ExtractionGateError(
                    f"ZIP orphan case/Unicode collision: {context.lineage}!{orphan.name} conflicts with {prior}"
                )
            seen.setdefault(orphan_path.collision_key, orphan.name)
            if orphan.declared_bytes > run.limits.max_member_bytes:
                raise ExtractionGateError(f"Orphan ZIP member exceeds limit: {context.lineage}!{orphan.name}")
            ratio = orphan.declared_bytes / max(orphan.compressed_bytes, 1)
            if orphan.compressed_bytes > 0 and ratio > run.limits.max_compression_ratio:
                raise ExtractionGateError(
                    f"Orphan ZIP compression ratio exceeds limit: {context.lineage}!{orphan.name}"
                )
            declared_bytes += orphan.declared_bytes
            file_count += 1
    elif run.ledgers is not None:
        has_orphan_ledger = any(
            key[0] == context.lineage
            and key[1] == context.depth
            and (key[3] > 1 or "unindexed_local_header" in str(record.get("status", "")))
            for key, record in run.ledgers.member_records.items()
        )
        if has_orphan_ledger:
            raise ExtractionGateError(
                f"Deep-audit ledger expects an unindexed ZIP member but no bounded repair applied: {context.lineage}"
            )
    run.reserve_members(declared_bytes, file_count, len(infos) + len(orphan_entries))
    return prepared, orphan_entries


def _extract_zip_container(context: ContainerContext, run: ExtractionRun) -> None:
    try:
        with _open_zip_source(context.source_path, context.lineage) as (archive, repaired_bytes):
            prepared, orphan_entries = _zip_preflight(archive, repaired_bytes, context, run)
            for ordinal, (info, member_path) in enumerate(prepared, start=1):
                if _zip_info_is_directory(info):
                    run.note_directory()
                    continue
                try:
                    with archive.open(info, mode="r") as source:
                        result = run.stream_payload(
                            _stream_handle(source),
                            context,
                            ordinal,
                            int(info.file_size),
                            int(info.CRC),
                        )
                except (OSError, RuntimeError, zipfile.BadZipFile) as error:
                    raise ExtractionGateError(
                        f"Unreadable ZIP member: {context.lineage}!{info.filename}: {error}"
                    ) from error
                raw_member = member_path.raw.replace("\\", "/")
                expected = run.expected_member(
                    context,
                    raw_member,
                    1,
                    result,
                    int(info.file_size),
                    f"{int(info.CRC):08x}",
                )
                nested_format = _detect_nested_container(result.prefix, raw_member)
                run.append_record(
                    context=context,
                    member_path=member_path,
                    member_occurrence=1,
                    member_ordinal=ordinal,
                    declared_bytes=int(info.file_size),
                    compressed_bytes=int(info.compress_size),
                    crc32=f"{int(info.CRC):08x}",
                    result=result,
                    nested_container_format=nested_format,
                    expected=expected,
                )
                if nested_format is not None:
                    _extract_container(
                        run,
                        source_path=result.destination,
                        lineage=f"{context.lineage}!{raw_member}",
                        physical_source=context.physical_source,
                        container_format=nested_format,
                        depth=context.depth + 1,
                        container_sha256=result.sha256,
                    )

            if repaired_bytes is not None:
                for orphan in orphan_entries:
                    member_path = normalize_member_path(orphan.name)
                    result = run.stream_payload(
                        _stream_orphan_zip_payload(repaired_bytes, orphan),
                        context,
                        orphan.ordinal,
                        orphan.declared_bytes,
                        orphan.crc32,
                    )
                    raw_member = member_path.raw.replace("\\", "/")
                    expected = run.expected_member(
                        context,
                        raw_member,
                        orphan.occurrence,
                        result,
                        orphan.declared_bytes,
                        f"{orphan.crc32:08x}",
                    )
                    nested_format = _detect_nested_container(result.prefix, raw_member)
                    run.append_record(
                        context=context,
                        member_path=member_path,
                        member_occurrence=orphan.occurrence,
                        member_ordinal=orphan.ordinal,
                        declared_bytes=orphan.declared_bytes,
                        compressed_bytes=orphan.compressed_bytes,
                        crc32=f"{orphan.crc32:08x}",
                        result=result,
                        nested_container_format=nested_format,
                        expected=expected,
                        integrity_status="staged_streamed_crc_valid_unindexed_local_header",
                        quality_flags=["unindexed_duplicate_local_header"],
                    )
                    if nested_format is not None:
                        _extract_container(
                            run,
                            source_path=result.destination,
                            lineage=f"{context.lineage}!{raw_member}",
                            physical_source=context.physical_source,
                            container_format=nested_format,
                            depth=context.depth + 1,
                            container_sha256=result.sha256,
                        )
    except ExtractionGateError:
        raise
    except (OSError, RuntimeError, zipfile.BadZipFile) as error:
        raise ExtractionGateError(f"Unreadable ZIP archive: {context.lineage}: {error}") from error
    _assert_context_source_unchanged(context)


def _prepare_tar_entries(context: ContainerContext, run: ExtractionRun) -> list[PreparedTarEntry]:
    """Perform a complete header-only TAR pass before publishing any payload."""

    prepared: list[PreparedTarEntry] = []
    seen: dict[str, str] = {}
    declared_bytes = 0
    try:
        with tarfile.open(name=context.source_path, mode="r:gz") as archive:
            while True:
                member = archive.next()
                if member is None:
                    break
                # Count every header, including directories: this prevents a tar
                # header flood from bypassing the payload-member budget.
                if len(prepared) >= run.limits.max_members:
                    raise ExtractionGateError(f"TAR has too many members: {context.lineage}")
                member_path = normalize_member_path(member.name)
                prior = seen.get(member_path.collision_key)
                if prior is not None:
                    raise ExtractionGateError(
                        f"TAR member case/Unicode collision: {context.lineage}!{member.name} conflicts with {prior}"
                    )
                seen[member_path.collision_key] = member.name
                if member.issym() or member.islnk():
                    raise ExtractionGateError(f"TAR symlink/hardlink rejected: {context.lineage}!{member.name}")
                is_directory = member.isdir()
                if not is_directory and not member.isfile():
                    raise ExtractionGateError(
                        f"Unsupported TAR member type rejected: {context.lineage}!{member.name}"
                    )
                if member.size < 0:
                    raise ExtractionGateError(f"TAR member has negative size: {context.lineage}!{member.name}")
                if not is_directory:
                    if member.size > run.limits.max_member_bytes:
                        raise ExtractionGateError(f"TAR member exceeds limit: {context.lineage}!{member.name}")
                    declared_bytes += int(member.size)
                prepared.append(
                    PreparedTarEntry(
                        raw_name=member.name,
                        member_path=member_path,
                        size=int(member.size),
                        is_directory=is_directory,
                    )
                )
    except ExtractionGateError:
        raise
    except (OSError, EOFError, tarfile.TarError) as error:
        raise ExtractionGateError(f"Unreadable gzip TAR archive: {context.lineage}: {error}") from error
    source_bytes = _source_size(context.source_path)
    if source_bytes and declared_bytes / source_bytes > run.limits.max_compression_ratio:
        raise ExtractionGateError(f"gzip TAR compression ratio exceeds limit: {context.lineage}")
    run.reserve_members(
        declared_bytes,
        sum(not item.is_directory for item in prepared),
        len(prepared),
    )
    return prepared


def _tar_logical_paths(
    context: ContainerContext, prepared: list[PreparedTarEntry]
) -> dict[str, tuple[str, bool]]:
    """Read bounded Unity pathname metadata; it remains metadata, never a destination."""

    logical_paths: dict[str, tuple[str, bool]] = {}
    try:
        with tarfile.open(name=context.source_path, mode="r:gz") as archive:
            for expected in prepared:
                member = archive.next()
                if member is None or member.name != expected.raw_name or int(member.size) != expected.size:
                    raise ExtractionGateError(f"TAR headers changed between validation passes: {context.lineage}")
                if expected.is_directory or expected.member_path.normalized.rsplit("/", 1)[-1] != "pathname":
                    continue
                extracted = archive.extractfile(member)
                if extracted is None:
                    raise ExtractionGateError(
                        f"Unreadable Unity pathname metadata: {context.lineage}!{member.name}"
                    )
                with extracted:
                    raw = extracted.read(MAX_LOGICAL_PATH_BYTES + 1)
                if len(raw) > MAX_LOGICAL_PATH_BYTES:
                    decoded = raw[:MAX_LOGICAL_PATH_BYTES].decode("utf-8-sig", errors="replace")
                    logical_paths[
                        expected.member_path.normalized.rsplit("/", 1)[0]
                        if "/" in expected.member_path.normalized
                        else ""
                    ] = (decoded, True)
                    continue
                decoded = raw.decode("utf-8-sig", errors="replace").strip()
                parent = (
                    expected.member_path.normalized.rsplit("/", 1)[0]
                    if "/" in expected.member_path.normalized
                    else ""
                )
                logical_paths[parent] = (decoded, False)
    except ExtractionGateError:
        raise
    except (OSError, EOFError, tarfile.TarError) as error:
        raise ExtractionGateError(f"Cannot read gzip TAR logical metadata: {context.lineage}: {error}") from error
    return logical_paths


def _extract_gzip_tar_container(context: ContainerContext, run: ExtractionRun) -> None:
    prepared = _prepare_tar_entries(context, run)
    logical_paths = _tar_logical_paths(context, prepared)
    try:
        with tarfile.open(name=context.source_path, mode="r:gz") as archive:
            for ordinal, expected_entry in enumerate(prepared, start=1):
                member = archive.next()
                if member is None or member.name != expected_entry.raw_name or int(member.size) != expected_entry.size:
                    raise ExtractionGateError(f"TAR headers changed between validation passes: {context.lineage}")
                if expected_entry.is_directory:
                    run.note_directory()
                    continue
                extracted = archive.extractfile(member)
                if extracted is None:
                    raise ExtractionGateError(f"Unreadable TAR member: {context.lineage}!{member.name}")
                with extracted:
                    result = run.stream_payload(
                        _stream_handle(extracted),
                        context,
                        ordinal,
                        expected_entry.size,
                        None,
                    )
                raw_member = expected_entry.member_path.raw.replace("\\", "/")
                parent = (
                    expected_entry.member_path.normalized.rsplit("/", 1)[0]
                    if "/" in expected_entry.member_path.normalized
                    else ""
                )
                logical_entry = (
                    logical_paths.get(parent)
                    if expected_entry.member_path.normalized.rsplit("/", 1)[-1] == "asset"
                    else None
                )
                raw_logical_path = logical_entry[0] if logical_entry is not None else None
                if logical_entry is not None and logical_entry[1]:
                    safe_logical_path = None
                    logical_safety = "rejected_metadata_not_used"
                    logical_reason = "too_long"
                else:
                    safe_logical_path, logical_safety, logical_reason = _validate_logical_metadata(
                        raw_logical_path
                    )
                semantic_name = safe_logical_path if logical_safety == "safe_metadata_not_used" else raw_member
                expected = run.expected_member(
                    context,
                    raw_member,
                    1,
                    result,
                    expected_entry.size,
                    None,
                )
                nested_format = _detect_nested_container(result.prefix, semantic_name)
                run.append_record(
                    context=context,
                    member_path=expected_entry.member_path,
                    member_occurrence=1,
                    member_ordinal=ordinal,
                    declared_bytes=expected_entry.size,
                    compressed_bytes=None,
                    crc32=None,
                    result=result,
                    nested_container_format=nested_format,
                    expected=expected,
                    logical_path=raw_logical_path,
                    logical_path_safety=logical_safety,
                    logical_path_reason=logical_reason,
                    integrity_status="staged_streamed_gzip_valid",
                )
                if nested_format is not None:
                    _extract_container(
                        run,
                        source_path=result.destination,
                        lineage=f"{context.lineage}!{raw_member}",
                        physical_source=context.physical_source,
                        container_format=nested_format,
                        depth=context.depth + 1,
                        container_sha256=result.sha256,
                    )
    except ExtractionGateError:
        raise
    except (OSError, EOFError, tarfile.TarError) as error:
        raise ExtractionGateError(f"Unreadable gzip TAR archive: {context.lineage}: {error}") from error
    _assert_context_source_unchanged(context)


def _extract_container(
    run: ExtractionRun,
    *,
    source_path: Path,
    lineage: str,
    physical_source: str,
    container_format: str,
    depth: int,
    container_sha256: str,
) -> None:
    if container_format not in {"zip", "gzip_tar"}:
        raise ExtractionGateError(f"Unsupported container format: {container_format}")
    context = run.make_context(
        source_path=source_path,
        lineage=lineage,
        physical_source=physical_source,
        container_format=container_format,
        depth=depth,
        container_sha256=container_sha256,
    )
    if container_format == "zip":
        _extract_zip_container(context, run)
    else:
        _extract_gzip_tar_container(context, run)


def _base_manifest(
    *,
    run: ExtractionRun,
    run_id: str,
    ledgers: LedgerSnapshot | None,
    capacity: dict[str, int] | None,
    physical_containers: list[PhysicalContainer] | None,
    loose_files: list[PhysicalLooseFile] | None,
) -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "generator": GENERATOR,
        "run_id": run_id,
        "created_utc": datetime.now(UTC).isoformat(),
        "status": "in_progress",
        "project_root_relative": ".",
        "source_vault": "Addons",
        "source_vault_write_policy": "immutable_no_write",
        "evidence_scope": "all_physical_loose_files_plus_all_archive_members",
        "physical_archive_wrapper_policy": "hash_verified_not_materialized_contents_are_materialized",
        "stage_relative_path": run.stage_root.relative_to(run.project_root).as_posix(),
        "stage_export_excluded": True,
        "stage_gdignore": (run.stage_root / ".gdignore").relative_to(run.project_root).as_posix(),
        "physical_archive_wrapper_files_materialized": 0,
        "physical_loose_file_payloads_materialized": run.loose_file_count,
        "limits": {
            "max_depth": run.limits.max_depth,
            "max_member_bytes": run.limits.max_member_bytes,
            "max_container_bytes": run.limits.max_container_bytes,
            "max_run_bytes": run.limits.max_run_bytes,
            "max_members": run.limits.max_members,
            "max_containers": run.limits.max_containers,
            "max_compression_ratio": run.limits.max_compression_ratio,
        },
        "deep_audit": (
            {
                "file_ledger_sha256": ledgers.file_ledger_sha256,
                "member_ledger_sha256": ledgers.member_ledger_sha256,
                "file_ledger_schema_versions": list(ledgers.file_ledger_schema_versions),
                "member_ledger_schema_versions": list(ledgers.member_ledger_schema_versions),
                "expected_member_count": len(ledgers.member_records),
                "expected_file_count": len(ledgers.file_records),
            }
            if ledgers is not None
            else {"verification": "fixture_mode_no_deep_ledger"}
        ),
        "disk_preflight": capacity,
        "physical_containers": {
            "count": len(physical_containers or []),
            "formats": dict(sorted(Counter(item.container_format for item in physical_containers or []).items())),
        },
        "physical_file_coverage": {
            "loose_files_expected": len(loose_files or []),
            "archive_wrapper_files_hash_verified": len(physical_containers or []),
        },
    }


def _write_run_evidence(
    run: ExtractionRun,
    manifest: dict[str, Any],
) -> dict[str, Any]:
    ledger_path = run.run_root / "extraction_ledger.jsonl"
    _atomic_write_jsonl(ledger_path, run.records)
    manifest["extraction_ledger_relative_path"] = ledger_path.relative_to(run.project_root).as_posix()
    manifest["extraction_ledger_sha256"] = _sha256_file(ledger_path)
    manifest_path = run.run_root / "run_manifest.json"
    _atomic_write_json(manifest_path, manifest)
    return manifest


def extract_sources(
    project_root: Path,
    *,
    run_id: str | None = None,
    limits: ExtractionLimits = DEFAULT_LIMITS,
    verify_ledgers: bool = True,
) -> dict[str, Any]:
    """Materialize immutable, ledger-verified loose-file and archive-member evidence.

    ``verify_ledgers=False`` exists only for isolated validator fixtures. The
    command-line production path always verifies the current deep-audit ledgers.
    """

    root = project_root.resolve()
    if not (root / "project.godot").is_file():
        raise ExtractionGateError("Project root must contain project.godot")
    if limits.max_depth < 0 or limits.max_members <= 0 or limits.max_containers <= 0:
        raise ExtractionGateError("Extraction limits are invalid")
    if limits.max_member_bytes <= 0 or limits.max_container_bytes <= 0 or limits.max_run_bytes <= 0:
        raise ExtractionGateError("Extraction byte limits are invalid")
    if limits.max_compression_ratio <= 0:
        raise ExtractionGateError("Compression-ratio limit must be positive")

    audit_ledgers = load_deep_audit_ledgers(root) if verify_ledgers else None
    resolved_run_id = _run_id_or_default(run_id)
    run_root, stage_root = _create_run_roots(root, resolved_run_id)
    # Ignore the entire run as well as the payload sub-tree if Godot's scanner is
    # pointed at artifacts by an editor configuration.
    _atomic_write_bytes(
        run_root / ".gdignore",
        b"# Persistent audit evidence; excluded from Godot import and exports.\n",
        None,
    )
    run = ExtractionRun(root, run_root, stage_root, limits, audit_ledgers)
    manifest: dict[str, Any] | None = None
    try:
        physical_containers, loose_files = _preflight_physical_sources(root, audit_ledgers)
        capacity = _disk_preflight(root, audit_ledgers, physical_containers, loose_files, limits)
        for physical in physical_containers:
            expected = audit_ledgers.file_records.get(physical.relative_path) if audit_ledgers else None
            run.append_container_verification(physical, expected)
        for physical in physical_containers:
            _extract_container(
                run,
                source_path=physical.path,
                lineage=physical.relative_path,
                physical_source=physical.relative_path,
                container_format=physical.container_format,
                depth=0,
                container_sha256=physical.sha256,
            )
        _materialize_loose_files(run, loose_files)
        _post_stage_rehash_physical_sources(run, physical_containers, loose_files)
        run.verify_completion()
        manifest = _base_manifest(
            run=run,
            run_id=resolved_run_id,
            ledgers=audit_ledgers,
            capacity=capacity,
            physical_containers=physical_containers,
            loose_files=loose_files,
        )
        manifest.update(
            {
                "status": "complete",
                "completed_utc": datetime.now(UTC).isoformat(),
                "containers_processed": run.container_count,
                "member_payloads_materialized": len(
                    [record for record in run.records if record.get("record_type") == "archive_member"]
                ),
                "loose_file_payloads_materialized": len(
                    [record for record in run.records if record.get("record_type") == "physical_loose_file"]
                ),
                "physical_container_verifications": len(
                    [record for record in run.records if record.get("record_type") == "physical_container_verification"]
                ),
                "archive_entries_seen": run.entry_count,
                "matched_ledger_members": len(run.used_expected_keys),
                "matched_file_ledger_loose_files": len(run.used_expected_loose_paths),
                "post_stage_physical_file_rehash_count": run.post_stage_physical_rehash_count,
                "post_stage_physical_file_rehash_bytes": run.post_stage_physical_rehash_bytes,
                "materialized_bytes": run.materialized_bytes,
                "declared_run_bytes": run.declared_run_bytes,
                "skipped_directory_entries": run.skipped_directories,
                "rejection_rows": 0,
            }
        )
        return _write_run_evidence(run, manifest)
    except BaseException as error:
        # Preserve an explicit, machine-readable negative decision for every
        # operational rejection. Do not delete already staged safe evidence.
        run.reject(error)
        failure_manifest = _base_manifest(
            run=run,
            run_id=resolved_run_id,
            ledgers=audit_ledgers,
            capacity=None,
            physical_containers=None,
            loose_files=None,
        )
        failure_manifest.update(
            {
                "status": "rejected",
                "completed_utc": datetime.now(UTC).isoformat(),
                "failure_type": type(error).__name__,
                "failure_reason": str(error),
                "containers_processed": run.container_count,
                "member_payloads_materialized": len(
                    [record for record in run.records if record.get("record_type") == "archive_member"]
                ),
                "loose_file_payloads_materialized": len(
                    [record for record in run.records if record.get("record_type") == "physical_loose_file"]
                ),
                "physical_container_verifications": len(
                    [record for record in run.records if record.get("record_type") == "physical_container_verification"]
                ),
                "archive_entries_seen": run.entry_count,
                "matched_ledger_members": len(run.used_expected_keys),
                "matched_file_ledger_loose_files": len(run.used_expected_loose_paths),
                "post_stage_physical_file_rehash_count": run.post_stage_physical_rehash_count,
                "post_stage_physical_file_rehash_bytes": run.post_stage_physical_rehash_bytes,
                "materialized_bytes": run.materialized_bytes,
                "declared_run_bytes": run.declared_run_bytes,
                "skipped_directory_entries": run.skipped_directories,
                "rejection_rows": len(
                    [record for record in run.records if record.get("record_type") == "gate_rejection"]
                ),
            }
        )
        try:
            _write_run_evidence(run, failure_manifest)
        except Exception as evidence_error:
            raise ExtractionGateError(
                f"Extraction rejected ({error}); additionally could not persist rejection evidence: {evidence_error}"
            ) from error
        if isinstance(error, (KeyboardInterrupt, SystemExit)):
            raise
        if isinstance(error, ExtractionGateError):
            raise
        raise ExtractionGateError(f"Unexpected extraction failure: {type(error).__name__}: {error}") from error


def validate_extraction_run(run_root: Path) -> dict[str, Any]:
    """Read-only validate staged bytes *and* current deep-audit coverage evidence."""

    lexical_root = Path(os.path.abspath(run_root))
    if _is_reparse_point(lexical_root):
        raise ExtractionGateError("Extraction run root is a reparse point")
    root = lexical_root.resolve()
    _assert_no_reparse_components(root, root.parent)
    manifest_path = root / "run_manifest.json"
    ledger_path = root / "extraction_ledger.jsonl"
    if not manifest_path.is_file() or not ledger_path.is_file():
        raise ExtractionGateError("Run does not contain both manifest and extraction ledger")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ExtractionGateError(f"Unreadable run manifest: {error}") from error
    if manifest.get("status") != "complete":
        raise ExtractionGateError("Only a complete extraction run can validate")
    if manifest.get("evidence_scope") != "all_physical_loose_files_plus_all_archive_members":
        raise ExtractionGateError(
            "Legacy archive-members-only run is immutable evidence, but not all-physical vault coverage"
        )
    stage_relative = str(manifest.get("stage_relative_path", ""))
    stage_parts = Path(stage_relative)
    if not stage_relative or stage_parts.is_absolute() or ".." in stage_parts.parts:
        raise ExtractionGateError("Run manifest has an unsafe stage path")
    try:
        project_root = root.parents[3]
    except IndexError as error:
        raise ExtractionGateError("Run path is too shallow to be an extraction evidence directory") from error
    stage_root = project_root / stage_parts
    direct_stage = root / "stage"
    _assert_no_reparse_components(direct_stage, root)
    if not direct_stage.is_dir() or stage_root.resolve() != direct_stage.resolve():
        raise ExtractionGateError("Run manifest stage path is inconsistent with run directory")
    records = _jsonl_records(ledger_path)
    allowed_types = {
        "archive_member",
        "physical_loose_file",
        "physical_container_verification",
    }
    rejected_or_unknown = [
        record
        for record in records
        if record.get("record_type") not in allowed_types
    ]
    if rejected_or_unknown:
        raise ExtractionGateError("Complete run contains a rejection or unknown evidence record")
    payload_records = [
        record
        for record in records
        if record.get("record_type") in {"archive_member", "physical_loose_file"}
    ]
    total = 0
    for record in payload_records:
        relative = str(record.get("artifact_relative_path", ""))
        artifact_parts = Path(relative)
        if not relative or artifact_parts.is_absolute() or ".." in artifact_parts.parts:
            raise ExtractionGateError("Ledger contains unsafe staged artifact path")
        lexical_destination = root / artifact_parts
        _assert_no_reparse_components(lexical_destination.parent, direct_stage)
        destination = lexical_destination.resolve()
        _assert_contained(destination, direct_stage, "Ledger staged artifact")
        if _is_reparse_point(destination) or not destination.is_file():
            raise ExtractionGateError(f"Staged artifact is missing or a reparse point: {relative}")
        expected_bytes = int(record.get("artifact_bytes", -1))
        if _source_size(destination) != expected_bytes:
            raise ExtractionGateError(f"Staged artifact byte mismatch: {relative}")
        if _sha256_file(destination) != str(record.get("artifact_sha256", "")):
            raise ExtractionGateError(f"Staged artifact hash mismatch: {relative}")
        total += expected_bytes
    if total != int(manifest.get("materialized_bytes", -1)):
        raise ExtractionGateError("Manifest materialized byte count does not match ledger")
    if _sha256_file(ledger_path) != str(manifest.get("extraction_ledger_sha256", "")):
        raise ExtractionGateError("Extraction ledger hash does not match manifest")
    temp_files = list(root.rglob("*.tmp"))
    if temp_files:
        raise ExtractionGateError(f"Incomplete temporary evidence remains: {temp_files[0].name}")

    member_records = [record for record in records if record.get("record_type") == "archive_member"]
    loose_records = [record for record in records if record.get("record_type") == "physical_loose_file"]
    container_records = [
        record for record in records if record.get("record_type") == "physical_container_verification"
    ]
    if len(member_records) != int(manifest.get("member_payloads_materialized", -1)):
        raise ExtractionGateError("Manifest archive-member count does not match ledger")
    if len(loose_records) != int(manifest.get("loose_file_payloads_materialized", -1)):
        raise ExtractionGateError("Manifest loose-file count does not match ledger")
    if len(container_records) != int(manifest.get("physical_container_verifications", -1)):
        raise ExtractionGateError("Manifest physical-container count does not match ledger")

    deep_marker = manifest.get("deep_audit", {})
    if deep_marker.get("verification") == "fixture_mode_no_deep_ledger":
        return {
            "status": "valid_fixture",
            "run_id": manifest.get("run_id"),
            "payloads": len(payload_records),
            "archive_members": len(member_records),
            "loose_files": len(loose_records),
            "materialized_bytes": total,
            "containers_processed": manifest.get("containers_processed"),
        }

    ledgers = load_deep_audit_ledgers(project_root)
    if deep_marker.get("file_ledger_sha256") != ledgers.file_ledger_sha256:
        raise ExtractionGateError("Current deep file-ledger hash differs from extraction manifest")
    if deep_marker.get("member_ledger_sha256") != ledgers.member_ledger_sha256:
        raise ExtractionGateError("Current deep archive-member ledger hash differs from extraction manifest")

    expected_member_keys = set(ledgers.member_records)
    seen_member_keys: set[MemberKey] = set()
    for record in member_records:
        try:
            key = _member_key(record)
        except (KeyError, TypeError, ValueError) as error:
            raise ExtractionGateError("Extraction ledger has an invalid archive-member key") from error
        expected = ledgers.member_records.get(key)
        if expected is None or key in seen_member_keys:
            raise ExtractionGateError(f"Archive-member deep-ledger key mismatch: {key}")
        if (
            int(record.get("bytes", -1)) != int(expected.get("bytes", -2))
            or str(record.get("member_sha256", "")) != str(expected.get("sha256", ""))
            or str(record.get("container_format", "")) != str(expected.get("container_format", ""))
            or str(record.get("crc32")) != str(expected.get("crc32"))
        ):
            raise ExtractionGateError(f"Archive-member deep-ledger content mismatch: {key}")
        seen_member_keys.add(key)
    if seen_member_keys != expected_member_keys:
        raise ExtractionGateError(
            f"Archive-member deep-ledger coverage mismatch: expected={len(expected_member_keys)} got={len(seen_member_keys)}"
        )

    expected_loose = {
        path: record for path, record in ledgers.file_records.items() if record.get("container_format") is None
    }
    seen_loose: set[str] = set()
    for record in loose_records:
        source_path = str(record.get("source_path", ""))
        expected = expected_loose.get(source_path)
        if expected is None or source_path in seen_loose:
            raise ExtractionGateError(f"Loose-file deep-ledger key mismatch: {source_path}")
        if (
            int(record.get("source_bytes", -1)) != int(expected.get("bytes", -2))
            or str(record.get("source_sha256", "")) != str(expected.get("sha256", ""))
            or int(record.get("source_sequence", -1)) != int(expected.get("sequence", -2))
            or int(record.get("post_stage_source_bytes", -1)) != int(expected.get("bytes", -2))
            or str(record.get("post_stage_source_sha256", "")) != str(expected.get("sha256", ""))
            or record.get("post_stage_integrity_status") != "sha256_file_ledger_valid"
        ):
            raise ExtractionGateError(f"Loose-file deep-ledger content mismatch: {source_path}")
        seen_loose.add(source_path)
    if seen_loose != set(expected_loose):
        raise ExtractionGateError(
            f"Loose-file deep-ledger coverage mismatch: expected={len(expected_loose)} got={len(seen_loose)}"
        )

    expected_containers = {
        path: record for path, record in ledgers.file_records.items() if record.get("container_format") is not None
    }
    seen_containers: set[str] = set()
    for record in container_records:
        source_path = str(record.get("source_path", ""))
        expected = expected_containers.get(source_path)
        if expected is None or source_path in seen_containers:
            raise ExtractionGateError(f"Physical-container deep-ledger key mismatch: {source_path}")
        if (
            int(record.get("source_bytes", -1)) != int(expected.get("bytes", -2))
            or str(record.get("source_sha256", "")) != str(expected.get("sha256", ""))
            or str(record.get("container_format", "")) != str(expected.get("container_format", ""))
            or record.get("materialized_wrapper") is not False
            or int(record.get("post_stage_source_bytes", -1)) != int(expected.get("bytes", -2))
            or str(record.get("post_stage_source_sha256", "")) != str(expected.get("sha256", ""))
            or record.get("post_stage_integrity_status") != "sha256_file_ledger_valid"
        ):
            raise ExtractionGateError(f"Physical-container deep-ledger content mismatch: {source_path}")
        seen_containers.add(source_path)
    if seen_containers != set(expected_containers):
        raise ExtractionGateError(
            f"Physical-container deep-ledger coverage mismatch: expected={len(expected_containers)} got={len(seen_containers)}"
        )

    live_count, live_bytes = _validate_live_file_ledger(project_root, ledgers)
    if live_count != len(ledgers.file_records) or live_bytes != sum(
        int(record["bytes"]) for record in ledgers.file_records.values()
    ):
        raise ExtractionGateError("Live physical file-ledger coverage totals are inconsistent")
    if int(manifest.get("post_stage_physical_file_rehash_count", -1)) != live_count:
        raise ExtractionGateError("Manifest post-stage physical file rehash count is incomplete")
    if int(manifest.get("post_stage_physical_file_rehash_bytes", -1)) != live_bytes:
        raise ExtractionGateError("Manifest post-stage physical file rehash bytes are incomplete")

    return {
        "status": "valid",
        "run_id": manifest.get("run_id"),
        "payloads": len(payload_records),
        "archive_members": len(member_records),
        "loose_files": len(loose_records),
        "physical_container_verifications": len(container_records),
        "materialized_bytes": total,
        "containers_processed": manifest.get("containers_processed"),
    }


def _default_project_root() -> Path:
    return Path(__file__).resolve().parents[2]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Immutable Addons archive extraction audit gate")
    parser.add_argument("--project-root", type=Path, default=_default_project_root())
    parser.add_argument("--run-id", help="Fresh evidence-run id (ASCII letters/digits/_/-)")
    parser.add_argument(
        "--validate-run",
        type=Path,
        help="Read-only validate an existing extraction run instead of extracting",
    )
    args = parser.parse_args(argv)
    try:
        if args.validate_run is not None:
            result = validate_extraction_run(args.validate_run)
        else:
            result = extract_sources(args.project_root, run_id=args.run_id)
    except ExtractionGateError as error:
        print(f"EXTRACTION GATE REJECTED: {error}", file=sys.stderr)
        return 2
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
