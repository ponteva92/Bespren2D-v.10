"""Produce a file-by-file forensic and runtime-fit audit of the Addons vault.

This is intentionally separate from the promotion script.  It never edits or
extracts into ``Addons``. Every source file is hashed and classified, every
signature-detected ZIP or Unity-package member is decompressed and hashed
recursively, and raster sources receive bounded format/dimension inspection.
The resulting JSONL ledgers are meant to
be searchable evidence, not a claim that an automated classifier replaces art
direction or license counsel.
"""

from __future__ import annotations

import argparse
import binascii
import hashlib
import io
import json
import os
import stat
import struct
import tarfile
import tempfile
import zipfile
import zlib
from collections import Counter, defaultdict
from pathlib import Path, PurePosixPath
from typing import Any, BinaryIO, Iterable

from PIL import Image


SCHEMA_VERSION = 1
READ_BLOCK_BYTES = 1024 * 1024
MAX_ARCHIVE_DEPTH = 4
MAX_ARCHIVE_MEMBER_BYTES = 192 * 1024 * 1024
MAX_ARCHIVE_TOTAL_BYTES = 2 * 1024 * 1024 * 1024
MAX_COMPRESSION_RATIO = 100.0

RASTER_EXTENSIONS = {
    ".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".tga",
    ".tif", ".tiff", ".psd", ".ico",
}
VECTOR_EXTENSIONS = {".svg"}
AUDIO_EXTENSIONS = {".wav", ".ogg", ".mp3", ".flac", ".m4a"}
VIDEO_EXTENSIONS = {".ogv", ".mp4", ".webm", ".mov", ".avi"}
MODEL_EXTENSIONS = {
    ".blend", ".fbx", ".obj", ".mtl", ".gltf", ".glb", ".dae",
    ".3ds", ".stl", ".usd", ".usda", ".usdc",
}
SOURCE_ART_EXTENSIONS = {".aseprite", ".kra", ".xcf", ".ai"}
FONT_EXTENSIONS = {".ttf", ".otf", ".woff", ".woff2"}
CONTAINER_EXTENSIONS = {".zip", ".unitypackage", ".kra", ".fla"}
ZIP_SIGNATURES = (b"PK\x03\x04", b"PK\x05\x06", b"PK\x07\x08")
GZIP_SIGNATURE = b"\x1f\x8b"
LICENSE_NAMES = {
    "license", "licence", "copying", "copyright", "notice",
    "third_party", "third-party",
}
GENERATED_EXTENSIONS = {".import", ".uid", ".cache", ".tmp", ".pyc", ".pyo"}
CODE_EXTENSIONS = {
    ".gd", ".gdshader", ".py", ".cs", ".cpp", ".c", ".h", ".hpp",
    ".js", ".ts", ".tsx", ".jsx", ".java", ".kt", ".swift", ".shader",
}
PROJECT_EXTENSIONS = {
    ".tscn", ".tres", ".res", ".godot", ".cfg", ".ini", ".json",
    ".xml", ".yaml", ".yml", ".toml", ".tmx", ".tsx",
}
DOCUMENT_EXTENSIONS = {".md", ".txt", ".pdf", ".rtf", ".url", ".po", ".pot"}

ROLE_KEYWORDS: dict[str, tuple[str, ...]] = {
    "camp": ("camp", "tent", "campfire", "firepit", "refuge", "shelter"),
    "tower": ("tower", "turret", "sentry", "defense", "barricade", "landmine", "trap"),
    "building": ("building", "house", "hut", "castle", "ruin", "wall", "bridge", "shed"),
    "nature": ("nature", "forest", "tree", "bush", "grass", "foliage", "plant", "moss", "root"),
    "terrain": ("terrain", "ground", "tile", "road", "path", "floor", "dirt", "rock", "stone"),
    "prop": ("prop", "crate", "barrel", "scrap", "wreck", "log", "stump", "fence", "sign", "debris"),
    "resource": ("wood", "metal", "tech", "ore", "resource", "collect", "harvest"),
    "ui": ("ui", "gui", "hud", "button", "icon", "panel", "menu", "cursor", "font"),
    "character": ("character", "player", "hero", "survivor", "enemy", "monster", "zombie", "boss"),
    "effect": ("effect", "vfx", "particle", "projectile", "bullet", "laser", "explosion", "light"),
    "audio": ("audio", "sound", "music", "sfx", "shoot", "hit", "click", "ambient"),
}


class DeepAuditError(RuntimeError):
    """Raised when the source vault violates a hard safety invariant."""


def _sha256_stream(handle: BinaryIO) -> str:
    digest = hashlib.sha256()
    for block in iter(lambda: handle.read(READ_BLOCK_BYTES), b""):
        digest.update(block)
    return digest.hexdigest()


def _sha256_file(path: Path) -> str:
    with path.open("rb") as handle:
        return _sha256_stream(handle)


def _safe_member(name: str) -> bool:
    normalized = name.replace("\\", "/")
    member = PurePosixPath(normalized)
    return not (
        member.is_absolute()
        or ".." in member.parts
        or (len(normalized) >= 2 and normalized[1] == ":")
    )


def _container_format_from_prefix(prefix: bytes) -> str | None:
    if any(prefix.startswith(signature) for signature in ZIP_SIGNATURES):
        return "zip"
    if prefix.startswith(GZIP_SIGNATURE):
        return "gzip_tar"
    return None


def _container_format_from_path(path: Path) -> str | None:
    with path.open("rb") as handle:
        prefix = handle.read(4)
    detected = _container_format_from_prefix(prefix)
    if path.suffix.casefold() in CONTAINER_EXTENSIONS and detected is None:
        raise DeepAuditError(f"Named container has an unsupported signature: {path}")
    return detected


def _content_kind(extension: str, container_format: str | None = None) -> str:
    if container_format is not None:
        return "archive"
    if extension in RASTER_EXTENSIONS:
        return "raster_image"
    if extension in VECTOR_EXTENSIONS:
        return "vector_image"
    if extension in AUDIO_EXTENSIONS:
        return "audio"
    if extension in VIDEO_EXTENSIONS:
        return "video"
    if extension in MODEL_EXTENSIONS:
        return "3d_source"
    if extension in SOURCE_ART_EXTENSIONS:
        return "editable_art_source"
    if extension in FONT_EXTENSIONS:
        return "font"
    if extension in CODE_EXTENSIONS:
        return "code"
    if extension in PROJECT_EXTENSIONS:
        return "project_data"
    if extension in DOCUMENT_EXTENSIONS:
        return "document"
    if extension in GENERATED_EXTENSIONS:
        return "generated_metadata"
    return "binary_or_unknown"


def _role_tags(path_text: str) -> list[str]:
    lowered = path_text.casefold().replace("_", " ").replace("-", " ")
    return [
        role
        for role, keywords in ROLE_KEYWORDS.items()
        if any(keyword in lowered for keyword in keywords)
    ]


def _is_license_path(path: Path | PurePosixPath) -> bool:
    stem = path.stem.casefold().replace("-", "_")
    lowered = str(path).casefold()
    return any(name in stem or name in lowered for name in LICENSE_NAMES)


def _decision(
    relative: PurePosixPath,
    extension: str,
    content_kind: str,
    roles: list[str],
    selected_runtime_sources: set[str],
) -> tuple[str, str]:
    project_relative = f"Addons/{relative.as_posix()}"
    lowered = project_relative.casefold()
    if project_relative in selected_runtime_sources:
        return "selected_runtime", "Reviewed, licensed, hash-tracked runtime dependency."
    if _is_license_path(relative):
        return "retain_provenance", "License or attribution evidence; never prune independently of its package."
    if extension in GENERATED_EXTENSIONS or any(
        marker in lowered for marker in ("/.godot/", "/__pycache__/", "/.git/")
    ):
        return "exclude_generated_cache", "Generated/import/cache metadata; not a production visual asset."
    if content_kind == "archive":
        return "retain_audited_container", "Source container; recursively path, CRC, size, and member audited."
    if content_kind == "3d_source":
        return "retain_source_only", "Valid source art, but mismatched with the shipping 2D mobile runtime."
    if content_kind in {"code", "project_data"}:
        return "retain_vendor_project_only", "Vendor project implementation data; not copied into the game runtime."
    if content_kind == "document":
        return "retain_reference", "Documentation or attribution context for the source package."
    if content_kind in {"raster_image", "vector_image", "editable_art_source", "font"}:
        if roles:
            return "candidate_visual_review", "Role-relevant source; compare perspective, silhouette, license, and 480x270 readability."
        return "retain_source_library", "Art source without a direct current gameplay role."
    if content_kind == "audio":
        if "audio" in roles or "ui" in roles or "effect" in roles:
            return "candidate_audio_review", "Role-relevant audio source; loudness and device audibility still require review."
        return "retain_source_library", "Audio source not mapped to a current cue."
    if content_kind == "video":
        return "retain_source_only", "Preview/cinematic source; not suitable for the current runtime budget."
    return "retain_unclassified_source", "Retained because the vault is immutable; no production mapping established."


def _inspect_raster(path: Path) -> tuple[dict[str, Any], list[str]]:
    metadata: dict[str, Any] = {}
    flags: list[str] = []
    try:
        with Image.open(path) as image:
            metadata = {
                "format": image.format,
                "width": image.width,
                "height": image.height,
                "mode": image.mode,
                "frames": int(getattr(image, "n_frames", 1)),
                "has_alpha": "A" in image.getbands() or "transparency" in image.info,
                "megapixels": round(image.width * image.height / 1_000_000.0, 4),
            }
            if image.width <= 0 or image.height <= 0:
                flags.append("invalid_dimensions")
            if max(image.width, image.height) > 4096:
                flags.append("oversized_for_direct_mobile_use")
            if min(image.width, image.height) < 16:
                flags.append("tiny_source")
            if metadata["frames"] > 1:
                flags.append("animated_or_multiframe")
    # Image plugins can raise format-specific parser exceptions for truncated
    # layered sources. Record the exact failure and keep the exhaustive ledger
    # moving; interrupts and process exits still propagate because they do not
    # derive from Exception.
    except Exception as error:
        metadata = {
            "inspection_error": type(error).__name__,
            "inspection_error_message": str(error)[:240],
        }
        flags.append("raster_metadata_unreadable")
    return metadata, flags


def _package_license_index(all_files: list[Path], addons_root: Path) -> dict[str, list[str]]:
    result: dict[str, list[str]] = defaultdict(list)
    for path in all_files:
        relative = path.relative_to(addons_root)
        package = relative.parts[0] if relative.parts else "<root>"
        if _is_license_path(PurePosixPath(relative.as_posix())):
            result[package].append(relative.as_posix())
    return {key: sorted(value) for key, value in result.items()}


def _load_selected_sources(project_root: Path) -> set[str]:
    manifest_path = project_root / "assets" / "runtime_asset_manifest.json"
    if not manifest_path.is_file():
        return set()
    payload = json.loads(manifest_path.read_text(encoding="utf-8"))
    return {
        str(record.get("source", ""))
        for record in payload.get("runtime_assets", [])
        if record.get("source")
    }


def _file_records(project_root: Path, addons_root: Path) -> list[dict[str, Any]]:
    all_files = sorted(path for path in addons_root.rglob("*") if path.is_file())
    selected = _load_selected_sources(project_root)
    license_index = _package_license_index(all_files, addons_root)
    records: list[dict[str, Any]] = []
    hashes: dict[str, list[int]] = defaultdict(list)
    for sequence, path in enumerate(all_files, start=1):
        relative_path = path.relative_to(addons_root)
        relative = PurePosixPath(relative_path.as_posix())
        package = relative.parts[0] if relative.parts else "<root>"
        extension = path.suffix.casefold() or "<none>"
        container_format = _container_format_from_path(path)
        kind = _content_kind(extension, container_format)
        roles = _role_tags(relative.as_posix())
        decision, reason = _decision(relative, extension, kind, roles, selected)
        digest = _sha256_file(path)
        metadata: dict[str, Any] = {}
        flags: list[str] = []
        if extension in RASTER_EXTENSIONS:
            metadata, flags = _inspect_raster(path)
        if path.stat().st_size == 0:
            flags.append("empty_file")
        record = {
            "schema_version": SCHEMA_VERSION,
            "sequence": sequence,
            "path": f"Addons/{relative.as_posix()}",
            "package": package,
            "extension": extension,
            "bytes": path.stat().st_size,
            "sha256": digest,
            "content_kind": kind,
            "role_tags": roles,
            "license_references_in_package": license_index.get(package, []),
            "license_signal": "references_present" if package in license_index else "not_detected",
            "decision": decision,
            "decision_reason": reason,
            "metadata": metadata,
            "quality_flags": flags,
        }
        if container_format is not None:
            record["container_format"] = container_format
        hashes[digest].append(len(records))
        records.append(record)
    for indices in hashes.values():
        if len(indices) < 2:
            continue
        canonical_path = records[indices[0]]["path"]
        for duplicate_rank, record_index in enumerate(indices):
            records[record_index]["duplicate_count"] = len(indices)
            records[record_index]["duplicate_rank"] = duplicate_rank
            records[record_index]["duplicate_of"] = None if duplicate_rank == 0 else canonical_path
    return records


def _archive_member_records(
    archive_bytes: bytes,
    container_path: str,
    depth: int,
    output: list[dict[str, Any]],
    container_format: str | None = None,
) -> None:
    if depth > MAX_ARCHIVE_DEPTH:
        raise DeepAuditError(f"Archive nesting exceeds {MAX_ARCHIVE_DEPTH}: {container_path}")
    resolved_format = container_format or _container_format_from_prefix(archive_bytes[:4])
    if resolved_format is None:
        raise DeepAuditError(f"Unsupported archive signature: {container_path}")
    if resolved_format == "zip":
        _zip_member_records(archive_bytes, container_path, depth, output)
        return
    if resolved_format == "gzip_tar":
        _gzip_tar_member_records(archive_bytes, container_path, depth, output)
        return
    raise DeepAuditError(f"Unsupported archive format {resolved_format}: {container_path}")


def _nested_container_format(
    data: bytes,
    member_path: PurePosixPath,
    logical_path: str | None = None,
) -> str | None:
    detected = _container_format_from_prefix(data[:4])
    semantic_path = PurePosixPath(logical_path) if logical_path else member_path
    if semantic_path.suffix.casefold() in CONTAINER_EXTENSIONS and detected is None:
        raise DeepAuditError(f"Named nested container has an unsupported signature: {semantic_path}")
    return detected


def _member_record(
    *,
    container_path: str,
    container_format: str,
    depth: int,
    member_path: PurePosixPath,
    extension: str,
    declared_bytes: int,
    compressed_bytes: int | None,
    crc32: str | None,
    data: bytes,
    status: str,
    logical_path: str | None = None,
    nested_container_format: str | None = None,
) -> dict[str, Any]:
    kind = _content_kind(extension, nested_container_format)
    roles = _role_tags(logical_path or member_path.as_posix())
    decision = "retain_archive_member"
    semantic_path = PurePosixPath(logical_path) if logical_path else member_path
    if _is_license_path(semantic_path):
        decision = "retain_provenance"
    elif kind in {"raster_image", "vector_image", "editable_art_source", "font"} and roles:
        decision = "candidate_visual_review"
    elif kind == "3d_source":
        decision = "retain_source_only"
    record: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "container": container_path,
        "container_format": container_format,
        "depth": depth,
        "member": member_path.as_posix(),
        "extension": extension,
        "bytes": declared_bytes,
        "compressed_bytes": compressed_bytes,
        "crc32": crc32,
        "sha256": hashlib.sha256(data).hexdigest(),
        "content_kind": kind,
        "role_tags": roles,
        "decision": decision,
        "status": status,
    }
    if logical_path:
        record["logical_path"] = logical_path
    if nested_container_format is not None:
        record["nested_container_format"] = nested_container_format
    return record


def _normalized_zip_bytes(archive_bytes: bytes, container_path: str) -> bytes:
    try:
        with zipfile.ZipFile(io.BytesIO(archive_bytes)):
            return archive_bytes
    except zipfile.BadZipFile as original_error:
        eocd_offset = archive_bytes.rfind(b"PK\x05\x06")
        if eocd_offset < 0 or eocd_offset + 22 > len(archive_bytes):
            raise DeepAuditError(f"Unreadable archive {container_path}: {original_error}") from original_error
        try:
            (
                _signature,
                _disk_number,
                _central_disk,
                _entries_on_disk,
                _entries_total,
                recorded_central_bytes,
                central_offset,
                comment_bytes,
            ) = struct.unpack_from("<4s4H2LH", archive_bytes, eocd_offset)
        except struct.error as error:
            raise DeepAuditError(f"Unreadable archive {container_path}: {original_error}") from error
        if (
            eocd_offset + 22 + comment_bytes != len(archive_bytes)
            or central_offset >= eocd_offset
            or not archive_bytes.startswith(b"PK\x01\x02", central_offset)
        ):
            raise DeepAuditError(f"Unreadable archive {container_path}: {original_error}") from original_error
        actual_central_bytes = eocd_offset - central_offset
        if recorded_central_bytes == actual_central_bytes:
            raise DeepAuditError(f"Unreadable archive {container_path}: {original_error}") from original_error
        repaired = bytearray(archive_bytes)
        struct.pack_into("<L", repaired, eocd_offset + 12, actual_central_bytes)
        repaired_bytes = bytes(repaired)
        try:
            with zipfile.ZipFile(io.BytesIO(repaired_bytes)):
                return repaired_bytes
        except zipfile.BadZipFile as repaired_error:
            raise DeepAuditError(f"Unreadable archive {container_path}: {repaired_error}") from repaired_error


def _zip_local_orphan_records(
    archive_bytes: bytes,
    container_path: str,
    depth: int,
    central_infos: list[zipfile.ZipInfo],
) -> tuple[list[dict[str, Any]], list[tuple[str, bytes, str]]]:
    """Audit valid local file headers omitted from a malformed central directory.

    Adobe Animate can write a valid duplicate local member while reporting a
    stale central-directory byte count. Standard readers expose only the
    indexed entry. This bounded scanner records the otherwise invisible local
    payload and validates its size and CRC without extracting it to disk.
    """

    central_counts: Counter[tuple[str, int, int, int]] = Counter(
        (
            info.filename.replace("\\", "/").casefold(),
            int(info.CRC),
            int(info.compress_size),
            int(info.file_size),
        )
        for info in central_infos
        if not info.is_dir()
    )
    central_by_offset = {int(info.header_offset): info for info in central_infos}
    local_counts: Counter[tuple[str, int, int, int]] = Counter()
    orphans: list[dict[str, Any]] = []
    nested: list[tuple[str, bytes, str]] = []
    eocd_offset = archive_bytes.rfind(b"PK\x05\x06")
    if eocd_offset < 0:
        raise DeepAuditError(f"Missing ZIP end record: {container_path}")
    first_local = archive_bytes.find(b"PK\x03\x04")
    if first_local < 0 or first_local >= eocd_offset:
        return orphans, nested
    position = first_local
    while position < eocd_offset and archive_bytes.startswith(b"PK\x03\x04", position):
        if position + 30 > len(archive_bytes):
            raise DeepAuditError(f"Truncated ZIP local header: {container_path}@{position}")
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
        name_start = position + 30
        name_end = name_start + name_bytes
        data_start = name_end + extra_bytes
        if data_start > len(archive_bytes):
            raise DeepAuditError(f"Truncated ZIP member name: {container_path}@{position}")
        encoding = "utf-8" if flags & 0x800 else "cp437"
        member_name = archive_bytes[name_start:name_end].decode(encoding, errors="replace")
        indexed = central_by_offset.get(position)
        crc32 = int(indexed.CRC) if indexed is not None else int(local_crc)
        compressed_bytes = (
            int(indexed.compress_size) if indexed is not None else int(local_compressed_bytes)
        )
        uncompressed_bytes = (
            int(indexed.file_size) if indexed is not None else int(local_uncompressed_bytes)
        )
        data_end = data_start + compressed_bytes
        if data_end > len(archive_bytes):
            raise DeepAuditError(f"Truncated ZIP payload: {container_path}!{member_name}")
        normalized_name = member_name.replace("\\", "/").casefold()
        if normalized_name.endswith("/"):
            position = data_end
            continue
        key = (normalized_name, crc32, compressed_bytes, uncompressed_bytes)
        local_counts[key] += 1
        if local_counts[key] > central_counts[key]:
            compressed_data = archive_bytes[data_start:data_end]
            if method == zipfile.ZIP_STORED:
                data = compressed_data
            elif method == zipfile.ZIP_DEFLATED:
                try:
                    data = zlib.decompress(compressed_data, -15)
                except zlib.error as error:
                    raise DeepAuditError(
                        f"Unreadable orphan ZIP payload: {container_path}!{member_name}"
                    ) from error
            else:
                raise DeepAuditError(
                    f"Unsupported orphan ZIP compression method {method}: "
                    f"{container_path}!{member_name}"
                )
            if len(data) != uncompressed_bytes:
                raise DeepAuditError(f"Orphan ZIP size mismatch: {container_path}!{member_name}")
            if binascii.crc32(data) & 0xFFFFFFFF != crc32:
                raise DeepAuditError(f"Orphan ZIP CRC failure: {container_path}!{member_name}")
            member_path = PurePosixPath(member_name.replace("\\", "/"))
            extension = member_path.suffix.casefold() or "<none>"
            nested_format = _nested_container_format(data, member_path)
            record = _member_record(
                container_path=container_path,
                container_format="zip",
                depth=depth,
                member_path=member_path,
                extension=extension,
                declared_bytes=uncompressed_bytes,
                compressed_bytes=compressed_bytes,
                crc32=f"{crc32:08x}",
                data=data,
                status="path_safe_crc_valid_decompressed_unindexed_local_header",
                nested_container_format=nested_format,
            )
            record["member_occurrence"] = local_counts[key]
            record["quality_flags"] = ["unindexed_duplicate_local_header"]
            orphans.append(record)
            if nested_format is not None:
                nested.append((f"{container_path}!{member_path.as_posix()}", data, nested_format))
        position = data_end
        if flags & 0x08:
            next_offsets = [
                offset
                for signature in (b"PK\x03\x04", b"PK\x01\x02")
                if (offset := archive_bytes.find(signature, position, min(position + 25, len(archive_bytes)))) >= 0
            ]
            if not next_offsets:
                raise DeepAuditError(f"Missing ZIP data descriptor boundary: {container_path}")
            position = min(next_offsets)
    return orphans, nested


def _zip_member_records(
    archive_bytes: bytes,
    container_path: str,
    depth: int,
    output: list[dict[str, Any]],
) -> None:
    try:
        normalized_archive_bytes = _normalized_zip_bytes(archive_bytes, container_path)
        with zipfile.ZipFile(io.BytesIO(normalized_archive_bytes)) as archive:
            infos = archive.infolist()
            total_bytes = sum(info.file_size for info in infos if not info.is_dir())
            if total_bytes > MAX_ARCHIVE_TOTAL_BYTES:
                raise DeepAuditError(f"Archive expansion budget exceeded: {container_path}")
            normalized_names: set[str] = set()
            nested: list[tuple[str, bytes, str]] = []
            for info in infos:
                if not _safe_member(info.filename):
                    raise DeepAuditError(f"Unsafe member path: {container_path}!{info.filename}")
                normalized = info.filename.replace("\\", "/").casefold()
                if normalized in normalized_names:
                    raise DeepAuditError(f"Duplicate member path: {container_path}!{info.filename}")
                normalized_names.add(normalized)
                unix_mode = info.external_attr >> 16
                if stat.S_ISLNK(unix_mode) or info.flag_bits & 0x1:
                    raise DeepAuditError(f"Symlink/encrypted member: {container_path}!{info.filename}")
                if info.is_dir():
                    continue
                if info.file_size > MAX_ARCHIVE_MEMBER_BYTES:
                    raise DeepAuditError(f"Oversized archive member: {container_path}!{info.filename}")
                ratio = info.file_size / max(info.compress_size, 1)
                if info.compress_size > 0 and ratio > MAX_COMPRESSION_RATIO:
                    raise DeepAuditError(f"Compression ratio exceeded: {container_path}!{info.filename}")
                data = archive.read(info)
                member_path = PurePosixPath(info.filename.replace("\\", "/"))
                extension = member_path.suffix.casefold() or "<none>"
                nested_format = _nested_container_format(data, member_path)
                output.append(_member_record(
                    container_path=container_path,
                    container_format="zip",
                    depth=depth,
                    member_path=member_path,
                    extension=extension,
                    declared_bytes=info.file_size,
                    compressed_bytes=info.compress_size,
                    crc32=f"{info.CRC:08x}",
                    data=data,
                    status="path_safe_crc_valid_decompressed",
                    nested_container_format=nested_format,
                ))
                if nested_format is not None:
                    nested.append((f"{container_path}!{member_path.as_posix()}", data, nested_format))
            bad_member = archive.testzip()
            if bad_member is not None:
                raise DeepAuditError(f"CRC failure: {container_path}!{bad_member}")
            orphan_records, orphan_nested = _zip_local_orphan_records(
                normalized_archive_bytes,
                container_path,
                depth,
                infos,
            )
            output.extend(orphan_records)
            nested.extend(orphan_nested)
    except (OSError, zipfile.BadZipFile, RuntimeError) as error:
        if isinstance(error, DeepAuditError):
            raise
        raise DeepAuditError(f"Unreadable archive {container_path}: {error}") from error
    for nested_path, nested_bytes, nested_format in nested:
        _archive_member_records(nested_bytes, nested_path, depth + 1, output, nested_format)


def _gzip_tar_member_records(
    archive_bytes: bytes,
    container_path: str,
    depth: int,
    output: list[dict[str, Any]],
) -> None:
    try:
        with tarfile.open(fileobj=io.BytesIO(archive_bytes), mode="r:gz") as archive:
            members = archive.getmembers()
            normalized_names: set[str] = set()
            total_bytes = 0
            for member in members:
                if not _safe_member(member.name):
                    raise DeepAuditError(f"Unsafe member path: {container_path}!{member.name}")
                normalized = member.name.replace("\\", "/").casefold()
                if normalized in normalized_names:
                    raise DeepAuditError(f"Duplicate member path: {container_path}!{member.name}")
                normalized_names.add(normalized)
                if member.issym() or member.islnk():
                    raise DeepAuditError(f"Symlink/hardlink member: {container_path}!{member.name}")
                if member.isdir():
                    continue
                if not member.isfile():
                    raise DeepAuditError(f"Unsupported tar member type: {container_path}!{member.name}")
                if member.size > MAX_ARCHIVE_MEMBER_BYTES:
                    raise DeepAuditError(f"Oversized archive member: {container_path}!{member.name}")
                total_bytes += member.size
            if total_bytes > MAX_ARCHIVE_TOTAL_BYTES:
                raise DeepAuditError(f"Archive expansion budget exceeded: {container_path}")
            if archive_bytes and total_bytes / len(archive_bytes) > MAX_COMPRESSION_RATIO:
                raise DeepAuditError(f"Compression ratio exceeded: {container_path}")

            logical_paths: dict[str, str] = {}
            for member in members:
                member_path = PurePosixPath(member.name.replace("\\", "/"))
                if not member.isfile() or member_path.name != "pathname":
                    continue
                extracted = archive.extractfile(member)
                if extracted is None:
                    raise DeepAuditError(f"Unreadable pathname member: {container_path}!{member.name}")
                logical_paths[member_path.parent.as_posix()] = extracted.read().decode(
                    "utf-8-sig", errors="replace"
                ).strip()

            nested: list[tuple[str, bytes, str]] = []
            for member in members:
                if not member.isfile():
                    continue
                member_path = PurePosixPath(member.name.replace("\\", "/"))
                extracted = archive.extractfile(member)
                if extracted is None:
                    raise DeepAuditError(f"Unreadable archive member: {container_path}!{member.name}")
                data = extracted.read()
                if len(data) != member.size:
                    raise DeepAuditError(f"Truncated archive member: {container_path}!{member.name}")
                logical_path = logical_paths.get(member_path.parent.as_posix())
                asset_logical_path = logical_path if member_path.name == "asset" else None
                semantic_path = PurePosixPath(asset_logical_path) if asset_logical_path else member_path
                extension = semantic_path.suffix.casefold() or member_path.suffix.casefold() or "<none>"
                nested_format = _nested_container_format(data, member_path, asset_logical_path)
                output.append(_member_record(
                    container_path=container_path,
                    container_format="gzip_tar",
                    depth=depth,
                    member_path=member_path,
                    extension=extension,
                    declared_bytes=member.size,
                    compressed_bytes=None,
                    crc32=None,
                    data=data,
                    status="path_safe_gzip_crc_valid_decompressed",
                    logical_path=asset_logical_path,
                    nested_container_format=nested_format,
                ))
                if nested_format is not None:
                    nested.append((f"{container_path}!{member_path.as_posix()}", data, nested_format))
    except (OSError, tarfile.TarError, RuntimeError) as error:
        if isinstance(error, DeepAuditError):
            raise
        raise DeepAuditError(f"Unreadable archive {container_path}: {error}") from error
    for nested_path, nested_bytes, nested_format in nested:
        _archive_member_records(nested_bytes, nested_path, depth + 1, output, nested_format)


def _all_archive_members(project_root: Path, file_records: list[dict[str, Any]]) -> list[dict[str, Any]]:
    members: list[dict[str, Any]] = []
    for record in file_records:
        container_format = record.get("container_format")
        if container_format is None:
            continue
        path = project_root / record["path"]
        _archive_member_records(path.read_bytes(), record["path"], 0, members, str(container_format))
    return members


def _atomic_write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    os.close(descriptor)
    temporary = Path(temporary_name)
    try:
        temporary.write_text(text, encoding="utf-8")
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def _write_jsonl(path: Path, records: Iterable[dict[str, Any]]) -> None:
    _atomic_write_text(
        path,
        "".join(json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n" for record in records),
    )


def _build_summary(
    file_records: list[dict[str, Any]],
    archive_members: list[dict[str, Any]],
) -> dict[str, Any]:
    decision_counts = Counter(record["decision"] for record in file_records)
    kind_counts = Counter(record["content_kind"] for record in file_records)
    role_counts: Counter[str] = Counter()
    package_counts: Counter[str] = Counter()
    extension_counts: Counter[str] = Counter()
    total_bytes = 0
    duplicate_files = 0
    duplicate_bytes = 0
    physical_container_formats: Counter[str] = Counter()
    nested_container_formats: Counter[str] = Counter()
    archive_member_container_formats: Counter[str] = Counter()
    packages_with_license_signal: set[str] = set()
    packages_without_license_signal: set[str] = set()
    candidate_visual_without_license = 0
    for record in file_records:
        total_bytes += int(record["bytes"])
        package_counts[record["package"]] += 1
        extension_counts[record["extension"]] += 1
        role_counts.update(record["role_tags"])
        if record.get("container_format"):
            physical_container_formats[str(record["container_format"])] += 1
        if record.get("license_signal") == "references_present":
            packages_with_license_signal.add(str(record["package"]))
        else:
            packages_without_license_signal.add(str(record["package"]))
        if (
            record.get("decision") == "candidate_visual_review"
            and record.get("license_signal") != "references_present"
        ):
            candidate_visual_without_license += 1
        if record.get("duplicate_rank", 0) > 0:
            duplicate_files += 1
            duplicate_bytes += int(record["bytes"])
    packages_without_license_signal.difference_update(packages_with_license_signal)

    archive_hashes: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for record in archive_members:
        archive_member_container_formats[str(record["container_format"])] += 1
        if record.get("nested_container_format"):
            nested_container_formats[str(record["nested_container_format"])] += 1
        archive_hashes[str(record["sha256"])].append(record)
    archive_duplicate_groups = 0
    archive_duplicate_members = 0
    archive_duplicate_bytes = 0
    for records in archive_hashes.values():
        if len(records) < 2:
            continue
        archive_duplicate_groups += 1
        ordered = sorted(
            records,
            key=lambda record: (
                str(record["container"]),
                int(record["depth"]),
                str(record["member"]),
            ),
        )
        archive_duplicate_members += len(ordered) - 1
        archive_duplicate_bytes += sum(int(record["bytes"]) for record in ordered[1:])

    all_container_formats = physical_container_formats + nested_container_formats
    return {
        "schema_version": SCHEMA_VERSION,
        "scope": (
            "Every physical file under Addons plus every recursively nested, "
            "signature-detected ZIP or gzip-tar container member."
        ),
        "files_audited": len(file_records),
        "source_bytes": total_bytes,
        "physical_archive_containers_audited": sum(physical_container_formats.values()),
        "nested_archive_containers_audited": sum(nested_container_formats.values()),
        "archive_containers_audited": sum(all_container_formats.values()),
        "physical_archive_format_counts": dict(sorted(physical_container_formats.items())),
        "nested_archive_format_counts": dict(sorted(nested_container_formats.items())),
        "archive_format_counts": dict(sorted(all_container_formats.items())),
        "archive_member_container_format_counts": dict(
            sorted(archive_member_container_formats.items())
        ),
        "archive_members_audited": len(archive_members),
        "archive_member_bytes_decompressed_and_hashed": sum(int(record["bytes"]) for record in archive_members),
        "archive_duplicate_hash_groups": archive_duplicate_groups,
        "archive_duplicate_members": archive_duplicate_members,
        "archive_duplicate_bytes": archive_duplicate_bytes,
        "duplicate_files": duplicate_files,
        "duplicate_bytes": duplicate_bytes,
        "packages_with_license_signal": len(packages_with_license_signal),
        "packages_without_license_signal": len(packages_without_license_signal),
        "candidate_visual_files_without_license_signal": candidate_visual_without_license,
        "decision_counts": dict(sorted(decision_counts.items())),
        "content_kind_counts": dict(sorted(kind_counts.items())),
        "role_counts": dict(sorted(role_counts.items())),
        "extension_counts": dict(sorted(extension_counts.items())),
        "package_counts": dict(sorted(package_counts.items())),
        "limitations": [
            "Filename role tags and format checks are automated triage, not a license opinion.",
            "Visual replacement decisions still require gameplay-scale comparison and runtime validation.",
            "Signature recursion covers ordinary ZIPs, ZIP-based Krita KRA and Adobe Animate FLA files, gzip-tar Unity packages, and their supported nested containers; other non-container compound binary formats receive file-level hashes only.",
            "Integrated Poly Haven model and terrain pipelines are outside the Addons vault totals and retain separate source, license, derived-asset, workshop, and runtime manifests.",
        ],
    }


def _markdown_summary(summary: dict[str, Any]) -> str:
    decisions = "\n".join(
        f"| `{name}` | {count:,} |" for name, count in summary["decision_counts"].items()
    )
    return f"""# Addons deep asset audit

This audit covers **{summary['files_audited']:,} physical files** ({summary['source_bytes']:,} bytes),
**{summary['archive_containers_audited']:,} signature-detected physical/nested containers**, and
**{summary['archive_members_audited']:,} recursively nested file members**. Every physical file and member
is SHA-256 hashed. ZIP members are path-checked, decompressed, and CRC-validated; Unity-package gzip-tar
members are path-checked, fully decompressed, and gzip-integrity validated.

The source vault was not modified. Decisions are runtime-fit classifications for the established Godot
4.7 Mobile 2D build, not deletion instructions.

## Decision ledger

| Decision | Files |
|---|---:|
{decisions}

## Evidence files

- `addons_file_ledger.jsonl`: one record for every physical Addons file.
- `archive_member_ledger.jsonl`: one record for every recursively nested ZIP or Unity-package file member.
- `deep_asset_audit_summary.json`: aggregate counts, duplicate footprint, roles, formats, and limitations.

## Container and external-source boundaries

Signature recursion includes ordinary ZIP files, ZIP-based Krita `.kra` and Adobe Animate `.fla` files,
gzip-tar Unity `.unitypackage` files, and supported nested containers such as the three embedded Unity
packages and the archived duplicate FLA. Other non-container compound binary formats retain exhaustive
physical-file hashes but do not receive an invented extraction contract.

The integrated Poly Haven model and terrain pipelines are deliberately outside these local `Addons`
totals. Their source IDs, CC0 evidence, downloaded/source hashes, Blender workshops, derived textures,
and runtime usage remain tracked by the separate Poly Haven environment and terrain manifests.

## Interpretation boundary

Automated format, exact-duplicate, path, supported-container, dimension, license-signal, and role checks are exhaustive.
Gameplay suitability is then proven only for promoted assets through scene integration, 480x270 captures,
collision checks, and focused Godot validators.
"""


def run(project_root: Path) -> dict[str, Any]:
    root = project_root.resolve()
    addons_root = root / "Addons"
    if not (root / "project.godot").is_file() or not addons_root.is_dir():
        raise DeepAuditError(f"Expected a Godot project with Addons at: {root}")
    file_records = _file_records(root, addons_root)
    archive_members = _all_archive_members(root, file_records)
    summary = _build_summary(file_records, archive_members)
    output = root / "artifacts" / "asset_audit"
    _write_jsonl(output / "addons_file_ledger.jsonl", file_records)
    _write_jsonl(output / "archive_member_ledger.jsonl", archive_members)
    _atomic_write_text(
        output / "deep_asset_audit_summary.json",
        json.dumps(summary, indent=2, ensure_ascii=False, sort_keys=True) + "\n",
    )
    _atomic_write_text(output / "DEEP_ASSET_AUDIT.md", _markdown_summary(summary))
    return summary


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
    )
    return parser.parse_args()


def main() -> int:
    try:
        summary = run(parse_args().project_root)
    except DeepAuditError as error:
        print(f"DEEP ASSET AUDIT FAILED | {error}")
        return 2
    print(
        "DEEP ASSET AUDIT OK | "
        f"files={summary['files_audited']} "
        f"containers={summary['archive_containers_audited']} "
        f"members={summary['archive_members_audited']} "
        f"duplicates={summary['duplicate_files']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
