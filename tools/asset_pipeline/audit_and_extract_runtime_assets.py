"""Audit Bespren's local Addons vault and curate runtime 2D/audio assets.

Every signature-detected ZIP/Krita/Animate or Unity-package container is
path-safety checked and fully decompressed for integrity validation. Vendor
archives/directories remain untouched. Only the
explicitly reviewed files below are copied into Godot's managed ``assets``
folders, and a SHA-256 provenance manifest is written for regression tests.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import struct
import sys
import tempfile
import wave
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any

try:
    from .deep_asset_audit import (
        DeepAuditError,
        _archive_member_records,
        _container_format_from_path,
    )
except ImportError:
    from deep_asset_audit import (  # type: ignore[no-redef]
        DeepAuditError,
        _archive_member_records,
        _container_format_from_path,
    )


IMAGE_EXTENSIONS = {".png", ".webp", ".jpg", ".jpeg", ".svg"}
AUDIO_EXTENSIONS = {".wav", ".ogg", ".mp3"}
@dataclass(frozen=True, slots=True)
class RuntimeAsset:
    source: str
    destination: str
    category: str
    purpose: str
    license_id: str


RUNTIME_ASSETS: tuple[RuntimeAsset, ...] = (
    RuntimeAsset(
        "Addons/ClawAndBlade_v1.5.0/ClawAndBlade/Tilemaps/Grounds/ground_grass_dirt_light.png",
        "assets/tiles/claw_forest_ground.png",
        "tile_atlas",
        "Metsa grass, flower, dirt, and road-shoulder variation",
        "spirit_claw_free_asset_license",
    ),
    RuntimeAsset(
        "Addons/ClawAndBlade_v1.5.0/ClawAndBlade/Tilemaps/Trees/trees_all.png",
        "assets/tiles/claw_forest_trees.png",
        "sprite_atlas",
        "forest canopy and foliage variants",
        "spirit_claw_free_asset_license",
    ),
    RuntimeAsset(
        "Addons/Godot-4-Tower-Defense-Template-master/"
        "Godot-4-Tower-Defense-Template-master/Assets/bullets/bullet2.png",
        "assets/sprites/projectile_bullet_strip.png",
        "sprite",
        "six-frame projectile head strip sliced to one 16x16 frame at runtime",
        "tower_defense_template_mit",
    ),
    RuntimeAsset(
        "Addons/Game-Component-Bundle-d8ee7d645a4f6216016316ac6f822ebcfbc2c4c9/"
        "Game-Component-Bundle-d8ee7d645a4f6216016316ac6f822ebcfbc2c4c9/"
        "Exponaut Components/Assets/Sounds/sfx/laser_shot.wav",
        "assets/audio/shoot_laser.wav",
        "audio",
        "player projectile firing feedback",
        "game_component_bundle_mit",
    ),
    RuntimeAsset(
        "Addons/Starter-Kit-City-Builder-main/Starter-Kit-City-Builder-main/"
        "sounds/placement-a.ogg",
        "assets/audio/build_placement.ogg",
        "audio",
        "base and structure placement feedback",
        "kenney_city_builder_mit",
    ),
    RuntimeAsset(
        "Addons/Game-Component-Bundle-d8ee7d645a4f6216016316ac6f822ebcfbc2c4c9/"
        "Game-Component-Bundle-d8ee7d645a4f6216016316ac6f822ebcfbc2c4c9/"
        "Exponaut Components/Assets/Sounds/sfx/collect.wav",
        "assets/audio/harvest_collect.wav",
        "audio",
        "resource harvesting feedback",
        "game_component_bundle_mit",
    ),
    RuntimeAsset(
        "Addons/Starter-Kit-City-Builder-main/Starter-Kit-City-Builder-main/"
        "sounds/toggle.ogg",
        "assets/audio/ui_click.ogg",
        "audio",
        "command and navigation button feedback",
        "kenney_city_builder_cc0_audio",
    ),
    RuntimeAsset(
        "Addons/ClawAndBlade_v1.5.0/ClawAndBlade/Documentation/License.txt",
        "assets/licenses/spirit_claw_license.txt",
        "license",
        "license text for ClawAndBlade runtime art",
        "spirit_claw_free_asset_license",
    ),
    RuntimeAsset(
        "Addons/Game-Component-Bundle-d8ee7d645a4f6216016316ac6f822ebcfbc2c4c9/"
        "Game-Component-Bundle-d8ee7d645a4f6216016316ac6f822ebcfbc2c4c9/"
        "license.txt",
        "assets/licenses/game_component_bundle_mit.txt",
        "license",
        "license text for Exponaut-derived runtime audio",
        "game_component_bundle_mit",
    ),
    RuntimeAsset(
        "Addons/Starter-Kit-City-Builder-main/Starter-Kit-City-Builder-main/LICENSE.md",
        "assets/licenses/kenney_city_builder_mit.md",
        "license",
        "license text for city-builder placement audio",
        "kenney_city_builder_mit",
    ),
    RuntimeAsset(
        "Addons/Starter-Kit-City-Builder-main/Starter-Kit-City-Builder-main/README.md",
        "assets/licenses/kenney_city_builder_readme.md",
        "license",
        "CC0 statement for included city-builder sound effects",
        "kenney_city_builder_cc0_audio",
    ),
    RuntimeAsset(
        "Addons/Godot-4-Tower-Defense-Template-master/"
        "Godot-4-Tower-Defense-Template-master/LICENSE",
        "assets/licenses/tower_defense_template_mit.txt",
        "license",
        "license text for the sliced projectile sprite",
        "tower_defense_template_mit",
    ),
)


class AuditError(RuntimeError):
    """Raised when source data cannot be safely promoted."""


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def audit_archive(path: Path, project_root: Path) -> dict[str, Any]:
    archive_data = path.read_bytes()
    display_name = path.relative_to(project_root).as_posix()
    try:
        container_format = _container_format_from_path(path)
        if container_format is None:
            raise AuditError(f"Unsupported archive signature: {display_name}")
        member_records: list[dict[str, Any]] = []
        _archive_member_records(
            archive_data,
            display_name,
            0,
            member_records,
            container_format,
        )
    except DeepAuditError as error:
        raise AuditError(str(error)) from error

    grouped: dict[tuple[str, int, str], list[dict[str, Any]]] = defaultdict(list)
    for record in member_records:
        key = (
            str(record["container"]),
            int(record["depth"]),
            str(record["container_format"]),
        )
        grouped[key].append(record)
    container_records: list[dict[str, Any]] = []
    for (container_path, depth, record_format), records in sorted(grouped.items()):
        extension_counts = Counter(str(record["extension"]) for record in records)
        container_records.append(
            {
                "path": container_path,
                "format": record_format,
                "depth": depth,
                "members": len(records),
                "unpacked_bytes_crc_validated": sum(int(record["bytes"]) for record in records),
                "unpacked_bytes_integrity_validated": sum(
                    int(record["bytes"]) for record in records
                ),
                "extension_counts": dict(sorted(extension_counts.items())),
                "status": "safe_integrity_valid",
            }
        )
    return {
        "path": display_name,
        "format": container_format,
        "sha256": hashlib.sha256(archive_data).hexdigest(),
        "containers_recursive": len(container_records),
        "members_recursive": sum(record["members"] for record in container_records),
        "unpacked_bytes_crc_validated": sum(
            record["unpacked_bytes_crc_validated"] for record in container_records
        ),
        "unpacked_bytes_integrity_validated": sum(
            record["unpacked_bytes_integrity_validated"] for record in container_records
        ),
        "containers": container_records,
        "status": "safe_integrity_valid",
    }


def validate_runtime_asset(path: Path) -> None:
    if not path.is_file() or path.stat().st_size <= 0:
        raise AuditError(f"Missing or empty selected asset: {path}")
    suffix = path.suffix.lower()
    with path.open("rb") as handle:
        signature = handle.read(12)
    if suffix == ".png" and not signature.startswith(b"\x89PNG\r\n\x1a\n"):
        raise AuditError(f"Invalid PNG signature: {path}")
    if suffix == ".ogg" and not signature.startswith(b"OggS"):
        raise AuditError(f"Invalid OGG signature: {path}")
    if suffix == ".wav":
        try:
            with wave.open(str(path), "rb") as stream:
                if stream.getnchannels() <= 0 or stream.getframerate() <= 0:
                    raise AuditError(f"Invalid WAV format: {path}")
        except (EOFError, wave.Error) as error:
            raise AuditError(f"Invalid WAV stream {path}: {error}") from error


def inspect_runtime_asset(path: Path) -> dict[str, Any]:
    suffix = path.suffix.lower()
    metadata: dict[str, Any] = {"extension": suffix, "bytes": path.stat().st_size}
    if suffix == ".png":
        with path.open("rb") as handle:
            header = handle.read(24)
        width, height = struct.unpack(">II", header[16:24])
        metadata.update({"width": width, "height": height})
    elif suffix == ".wav":
        with wave.open(str(path), "rb") as stream:
            frames = stream.getnframes()
            sample_rate = stream.getframerate()
            metadata.update(
                {
                    "channels": stream.getnchannels(),
                    "sample_rate_hz": sample_rate,
                    "sample_width_bits": stream.getsampwidth() * 8,
                    "duration_seconds": round(frames / sample_rate, 6),
                }
            )
    elif suffix == ".ogg":
        metadata.update(_inspect_ogg_vorbis(path))
    return metadata


def _inspect_ogg_vorbis(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    identification = data.find(b"\x01vorbis")
    if identification < 0 or identification + 16 > len(data):
        raise AuditError(f"OGG stream is not Vorbis: {path}")
    channels = data[identification + 11]
    sample_rate = int.from_bytes(data[identification + 12 : identification + 16], "little")
    last_granule = 0
    cursor = 0
    while True:
        page = data.find(b"OggS", cursor)
        if page < 0 or page + 27 > len(data):
            break
        granule = int.from_bytes(data[page + 6 : page + 14], "little")
        if granule < (1 << 63):
            last_granule = max(last_granule, granule)
        segment_count = data[page + 26]
        if page + 27 + segment_count > len(data):
            raise AuditError(f"Truncated OGG page: {path}")
        body_size = sum(data[page + 27 : page + 27 + segment_count])
        cursor = page + 27 + segment_count + body_size
    if channels <= 0 or sample_rate <= 0:
        raise AuditError(f"Invalid OGG Vorbis metadata: {path}")
    return {
        "channels": channels,
        "sample_rate_hz": sample_rate,
        "duration_seconds": round(last_granule / sample_rate, 6),
    }


def atomic_copy(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.is_file() and sha256_file(source) == sha256_file(destination):
        return
    file_descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{destination.name}.", suffix=".tmp", dir=destination.parent
    )
    os.close(file_descriptor)
    temporary_path = Path(temporary_name)
    try:
        shutil.copy2(source, temporary_path)
        if sha256_file(source) != sha256_file(temporary_path):
            raise AuditError(f"Copy verification failed: {source} -> {destination}")
        temporary_path.replace(destination)
    finally:
        temporary_path.unlink(missing_ok=True)


def atomic_write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    file_descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
    )
    os.close(file_descriptor)
    temporary_path = Path(temporary_name)
    try:
        temporary_path.write_text(
            json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        temporary_path.replace(path)
    finally:
        temporary_path.unlink(missing_ok=True)


def audit_and_extract(project_root: Path, copy_runtime_assets: bool = True) -> dict[str, Any]:
    project_root = project_root.resolve()
    addons_root = (project_root / "Addons").resolve()
    if not (project_root / "project.godot").is_file():
        raise AuditError(f"Not a Godot project root: {project_root}")
    if not addons_root.is_dir():
        raise AuditError(f"Addons source root is missing: {addons_root}")

    all_files = sorted(path for path in addons_root.rglob("*") if path.is_file())
    extension_counts: Counter[str] = Counter()
    package_counts: dict[str, Counter[str]] = defaultdict(Counter)
    package_bytes: Counter[str] = Counter()
    keyword_counts: Counter[str] = Counter()
    keywords = (
        "nature",
        "forest",
        "tree",
        "grass",
        "foliage",
        "tile",
        "shoot",
        "projectile",
        "build",
        "harvest",
        "collect",
        "click",
    )
    for path in all_files:
        relative = path.relative_to(addons_root)
        extension = path.suffix.lower() or "<none>"
        extension_counts[extension] += 1
        package = relative.parts[0] if relative.parts else "<root>"
        package_counts[package][extension] += 1
        package_bytes[package] += path.stat().st_size
        lowered = relative.as_posix().lower()
        for keyword in keywords:
            if keyword in lowered:
                keyword_counts[keyword] += 1

    archive_paths: list[Path] = []
    for path in all_files:
        try:
            if _container_format_from_path(path) is not None:
                archive_paths.append(path)
        except DeepAuditError as error:
            raise AuditError(str(error)) from error
    archive_records = [audit_archive(path, project_root) for path in archive_paths]
    archive_by_hash: dict[str, str] = {}
    duplicate_archives = 0
    for record in archive_records:
        archive_hash = str(record["sha256"])
        if archive_hash in archive_by_hash:
            record["status"] = "safe_integrity_valid_duplicate"
            record["duplicate_of"] = archive_by_hash[archive_hash]
            duplicate_archives += 1
        else:
            archive_by_hash[archive_hash] = str(record["path"])

    selected_records: list[dict[str, Any]] = []
    for asset in RUNTIME_ASSETS:
        source = (project_root / asset.source).resolve()
        destination = (project_root / asset.destination).resolve()
        try:
            source.relative_to(addons_root)
            destination.relative_to(project_root / "assets")
        except ValueError as error:
            raise AuditError(f"Selected asset escapes an approved root: {asset}") from error
        validate_runtime_asset(source)
        if copy_runtime_assets:
            atomic_copy(source, destination)
        validate_runtime_asset(destination)
        source_hash = sha256_file(source)
        destination_hash = sha256_file(destination)
        if source_hash != destination_hash:
            raise AuditError(f"Runtime asset hash mismatch: {asset.destination}")
        selected_records.append(
            {
                "source": asset.source,
                "destination": "res://" + Path(asset.destination).as_posix(),
                "category": asset.category,
                "purpose": asset.purpose,
                "license_id": asset.license_id,
                "bytes": destination.stat().st_size,
                "sha256": destination_hash,
                "metadata": inspect_runtime_asset(destination),
            }
        )

    package_summary = {
        name: {
            "files": sum(counts.values()),
            "bytes": package_bytes[name],
            "extension_counts": dict(sorted(counts.items())),
        }
        for name, counts in sorted(package_counts.items())
    }
    physical_archive_format_counts = Counter(str(record["format"]) for record in archive_records)
    recursive_archive_format_counts: Counter[str] = Counter()
    for archive_record in archive_records:
        recursive_archive_format_counts.update(
            str(container["format"])
            for container in archive_record["containers"]
        )
    manifest: dict[str, Any] = {
        "schema_version": 1,
        "generator": "tools/asset_pipeline/audit_and_extract_runtime_assets.py",
        "source_root": str(addons_root),
        "summary": {
            "files_audited": len(all_files),
            "source_bytes": sum(path.stat().st_size for path in all_files),
            "archives_audited": len(archive_records),
            "archive_containers_audited": sum(
                record["containers_recursive"] for record in archive_records
            ),
            "physical_archive_format_counts": dict(
                sorted(physical_archive_format_counts.items())
            ),
            "recursive_archive_format_counts": dict(
                sorted(recursive_archive_format_counts.items())
            ),
            "archive_members_audited": sum(
                record["members_recursive"] for record in archive_records
            ),
            "archive_bytes_unpacked_for_crc_validation": sum(
                record["unpacked_bytes_crc_validated"] for record in archive_records
            ),
            "archive_bytes_unpacked_for_integrity_validation": sum(
                record["unpacked_bytes_integrity_validated"] for record in archive_records
            ),
            "duplicate_archives": duplicate_archives,
            "runtime_assets_selected": len(selected_records),
            "extension_counts": dict(sorted(extension_counts.items())),
            "keyword_counts": dict(sorted(keyword_counts.items())),
        },
        "top_level_packages": package_summary,
        "archives": archive_records,
        "runtime_assets": selected_records,
    }
    manifest_path = project_root / "assets" / "runtime_asset_manifest.json"
    atomic_write_json(manifest_path, manifest)
    return manifest


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
        help="Godot project root containing Addons and project.godot",
    )
    parser.add_argument(
        "--manifest-only",
        action="store_true",
        help="Validate existing promoted destinations and rewrite only the audit manifest.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        manifest = audit_and_extract(args.project_root, copy_runtime_assets=not args.manifest_only)
    except AuditError as error:
        print(f"RUNTIME ASSET AUDIT FAILED | {error}", file=sys.stderr)
        return 2
    summary = manifest["summary"]
    print(
        "RUNTIME ASSET AUDIT OK | "
        f"files={summary['files_audited']} "
        f"archives={summary['archives_audited']} "
        f"members={summary['archive_members_audited']} "
        f"selected={summary['runtime_assets_selected']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
