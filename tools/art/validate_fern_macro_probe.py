"""Independent validator for the artifact-only Fern 02 macro bake.

This deliberately does not import Blender.  It rehashes the manifest-listed
inputs and generated PNGs, verifies the tightly scoped report schema, and
rejects any output-root or runtime-closure drift before a later context test
can treat the macro frames as review candidates.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
from pathlib import Path
from typing import Any


HERE = Path(__file__).resolve().parent
PROJECT_ROOT = HERE.parent.parent
TRIAL_ROOT = PROJECT_ROOT / "artifacts" / "wild_salvage_trial"
PROBE_ROOT = TRIAL_ROOT / "probes" / "fern_02_macro"
OUTPUT_DIRECTORY = PROBE_ROOT / "polyhaven_wild"
REPORT_PATH = PROBE_ROOT / "fern_macro_render_report.json"
MANIFEST_PATH = HERE / "blender" / "vault" / "polyhaven_wild" / "_fetch_manifest.json"
EXPECTED_KEYS = ("fern_macro_0", "fern_macro_1")
EXPECTED_OUTPUT_ROOT = "artifacts/wild_salvage_trial/probes/fern_02_macro"
EXPECTED_OUTPUT_DIRECTORY = EXPECTED_OUTPUT_ROOT + "/polyhaven_wild"
EXPECTED_RUNTIME_PROMOTION = "forbidden_pending_macro_context_review"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _read_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        value: Any = json.load(handle)
    if not isinstance(value, dict):
        raise RuntimeError("Expected a JSON object: %s" % path)
    return value


def _require_regular_path(path: Path, expected_parent: Path, label: str) -> None:
    if path.is_symlink():
        raise RuntimeError("%s may not be a symlink: %s" % (label, path))
    if not path.exists():
        raise RuntimeError("Missing %s: %s" % (label, path))
    if path.resolve().parent != expected_parent.resolve():
        raise RuntimeError("%s escaped its expected parent: %s" % (label, path))


def _png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        header = handle.read(24)
    if len(header) != 24 or not header.startswith(PNG_SIGNATURE) or header[12:16] != b"IHDR":
        raise RuntimeError("Not a valid PNG header: %s" % path)
    return struct.unpack(">II", header[16:24])


def _manifest_fern_asset() -> dict[str, Any]:
    manifest = _read_json(MANIFEST_PATH)
    if manifest.get("license") != "CC0-1.0":
        raise RuntimeError("Wild manifest is not CC0-1.0")
    for asset in manifest.get("assets", []):
        if isinstance(asset, dict) and asset.get("id") == "fern_02":
            if asset.get("license") != "CC0-1.0":
                raise RuntimeError("Fern 02 is not CC0-1.0")
            return asset
    raise RuntimeError("Wild manifest lacks fern_02")


def _expected_uri_closure(asset: dict[str, Any]) -> list[str]:
    entry = Path(str(asset.get("entry", "")))
    files = {Path(str(item.get("path", ""))) for item in asset.get("files", []) if isinstance(item, dict)}
    if entry not in files or entry.suffix.lower() != ".gltf":
        raise RuntimeError("Fern manifest has no verified glTF entry")
    payload = _read_json(MANIFEST_PATH.parent / entry)
    closure = {entry.as_posix()}
    for section in ("buffers", "images"):
        values = payload.get(section, [])
        if not isinstance(values, list):
            raise RuntimeError("Fern glTF has malformed %s" % section)
        for value in values:
            if not isinstance(value, dict) or "uri" not in value:
                continue
            uri = str(value["uri"])
            if uri.startswith("data:"):
                continue
            relative_uri = Path(uri)
            if relative_uri.is_absolute() or ".." in relative_uri.parts:
                raise RuntimeError("Fern glTF has unsafe URI: %s" % uri)
            resolved = entry.parent / relative_uri
            if resolved not in files:
                raise RuntimeError("Fern glTF URI is not manifest-listed: %s" % uri)
            closure.add(resolved.as_posix())
    return sorted(closure)


def _validate_runtime_exclusion() -> None:
    closure_files = (
        PROJECT_ROOT / "data" / "runtime_export_closure.json",
        PROJECT_ROOT / "scenes" / "build" / "runtime_export_dependencies.tscn",
    )
    prohibited_tokens = ("fern_02_macro", "wild_salvage_trial")
    for closure in closure_files:
        if not closure.is_file():
            raise RuntimeError("Runtime closure evidence is missing: %s" % closure)
        contents = closure.read_text(encoding="utf-8")
        for token in prohibited_tokens:
            if token in contents:
                raise RuntimeError("Artifact-only token leaked into runtime closure: %s" % token)


def validate(report_path: Path = REPORT_PATH) -> None:
    if not (TRIAL_ROOT / ".gdignore").is_file():
        raise RuntimeError("Trial artifact root must remain excluded from Godot scanning")
    if PROBE_ROOT.is_symlink() or OUTPUT_DIRECTORY.is_symlink():
        raise RuntimeError("Macro probe root or output directory is symlinked")
    _require_regular_path(report_path, PROBE_ROOT, "macro report")
    report = _read_json(report_path)
    if report.get("schema_version") != 1 or report.get("mode") != "artifact_only_macro_probe":
        raise RuntimeError("Macro report has wrong schema/mode")
    if report.get("artifact_only") is not True or report.get("runtime_promotion") != EXPECTED_RUNTIME_PROMOTION:
        raise RuntimeError("Macro report does not preserve artifact-only promotion state")
    if report.get("output_root") != EXPECTED_OUTPUT_ROOT or report.get("output_directory") != EXPECTED_OUTPUT_DIRECTORY:
        raise RuntimeError("Macro report output path drifted")
    if report.get("errors"):
        raise RuntimeError("Macro report contains errors: %s" % report["errors"])
    if report.get("frame_size") != 256:
        raise RuntimeError("Macro report frame size is not 256")
    if report.get("background_process_verified") is not True or report.get("loaded_blend_path_verified_empty") is not True:
        raise RuntimeError("Macro report did not verify an empty background Blender process")
    if report.get("required_command_contract") != ["--factory-startup", "--background"]:
        raise RuntimeError("Macro report command contract drifted")
    if _sha256(MANIFEST_PATH) != report.get("source_manifest_sha256"):
        raise RuntimeError("Wild source manifest hash drifted")
    dependencies = report.get("pipeline_dependencies")
    expected_dependencies = {
        "render_polyhaven_fern_macro.py": HERE / "render_polyhaven_fern_macro.py",
        "render_polyhaven_wild_sprites.py": HERE / "render_polyhaven_wild_sprites.py",
        "render_polyhaven_district_sprites.py": HERE / "render_polyhaven_district_sprites.py",
        "wild_bake_contract.py": HERE / "wild_bake_contract.py",
    }
    if not isinstance(dependencies, dict):
        raise RuntimeError("Macro report lacks pipeline dependency hashes")
    for name, path in expected_dependencies.items():
        if _sha256(path) != dependencies.get(name):
            raise RuntimeError("Macro pipeline dependency hash drifted: %s" % name)
    if report.get("worker_sha256") != _sha256(HERE / "render_polyhaven_fern_macro.py"):
        raise RuntimeError("Macro worker hash drifted")

    asset = _manifest_fern_asset()
    source = report.get("source")
    if not isinstance(source, dict):
        raise RuntimeError("Macro report lacks source provenance")
    if source.get("family") != "polyhaven_wild" or source.get("id") != "fern_02":
        raise RuntimeError("Macro report source identity drifted")
    if source.get("entry") != asset.get("entry"):
        raise RuntimeError("Macro report entry drifted")
    expected_closure = _expected_uri_closure(asset)
    if source.get("gltf_uri_closure") != expected_closure:
        raise RuntimeError("Macro report glTF URI closure drifted")
    report_files = source.get("files")
    manifest_files = asset.get("files")
    if not isinstance(report_files, list) or not isinstance(manifest_files, list):
        raise RuntimeError("Macro report source-file list is malformed")
    expected_file_rows = {
        str(item.get("path")): item
        for item in manifest_files
        if isinstance(item, dict)
    }
    if len(report_files) != len(expected_file_rows):
        raise RuntimeError("Macro report source-file count drifted")
    for row in report_files:
        if not isinstance(row, dict):
            raise RuntimeError("Malformed macro source-file row")
        relative = Path(str(row.get("path", "")))
        expected = expected_file_rows.get(relative.as_posix())
        if expected is None:
            raise RuntimeError("Unexpected macro source file: %s" % relative)
        source_file = MANIFEST_PATH.parent / relative
        if source_file.is_symlink() or not source_file.is_file():
            raise RuntimeError("Macro source file is missing or linked: %s" % source_file)
        if _sha256(source_file) != expected.get("sha256") or row.get("sha256") != expected.get("sha256"):
            raise RuntimeError("Macro source hash mismatch: %s" % source_file)
        if row.get("bytes") != source_file.stat().st_size:
            raise RuntimeError("Macro source byte count mismatch: %s" % source_file)

    gates = report.get("quality_gates")
    if not isinstance(gates, dict):
        raise RuntimeError("Macro report lacks local quality gates")
    expected_frames = {str(frame.get("key")): frame for frame in report.get("frames", []) if isinstance(frame, dict)}
    if tuple(sorted(expected_frames)) != EXPECTED_KEYS:
        raise RuntimeError("Macro report frame identities drifted: %s" % sorted(expected_frames))
    for key in EXPECTED_KEYS:
        frame = expected_frames[key]
        if frame.get("quality_status") != "passed":
            raise RuntimeError("Macro frame did not pass its local quality gate: %s" % key)
        expected_file = OUTPUT_DIRECTORY / (key + ".png")
        if frame.get("file") != expected_file.name:
            raise RuntimeError("Macro frame file name drifted: %s" % key)
        _require_regular_path(expected_file, OUTPUT_DIRECTORY, "macro frame")
        if _sha256(expected_file) != frame.get("sha256"):
            raise RuntimeError("Macro output hash mismatch: %s" % key)
        if _png_size(expected_file) != (256, 256):
            raise RuntimeError("Macro output dimensions drifted: %s" % key)
        if int(frame.get("visible_pixels", 0)) < int(gates.get("minimum_visible_pixels", 0)):
            raise RuntimeError("Macro output visible-pixel gate failed: %s" % key)
        if float(frame.get("alpha_bbox_density", 0.0)) < float(gates.get("minimum_alpha_bbox_density", 1.0)):
            raise RuntimeError("Macro output bbox-density gate failed: %s" % key)
        if int(frame.get("alpha_bbox_width_px", 0)) < int(gates.get("minimum_alpha_bbox_width_px", 0)):
            raise RuntimeError("Macro output bbox-width gate failed: %s" % key)
        if int(frame.get("alpha_bbox_height_px", 0)) < int(gates.get("minimum_alpha_bbox_height_px", 0)):
            raise RuntimeError("Macro output bbox-height gate failed: %s" % key)
        if int(frame.get("edge_margin_px", -1)) < int(gates.get("minimum_edge_margin_px", 0)):
            raise RuntimeError("Macro output edge-margin gate failed: %s" % key)
        if float(frame.get("alpha_weighted_luma", 0.0)) < float(gates.get("minimum_alpha_weighted_luma", 0.0)):
            raise RuntimeError("Macro output luma gate failed: %s" % key)
    _validate_runtime_exclusion()
    print("FERN MACRO PROBE VALIDATION OK | frames=2 | hashes=verified | artifact-only=true")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", type=Path, default=REPORT_PATH)
    args = parser.parse_args()
    validate(args.report.resolve())


if __name__ == "__main__":
    main()
