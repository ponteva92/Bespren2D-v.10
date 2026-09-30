"""Preflight and artifact validation for the two-source wild/salvage trial.

This intentionally does not import Blender. It catches path drift and source
provenance failures before a long Blender batch begins, then validates the
renderer's own frame metrics and hashes after isolated CLI renders finish.
It is a technical gate only; it cannot certify 480x270 gameplay readability.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from wild_bake_contract import (
    ENVIRONMENT_ROOT,
    FRAME_SIZE,
    MINIMUM_ALPHA_WEIGHTED_LUMA,
    MINIMUM_FRAME_MARGIN,
    OUTPUT_ROOT_ENV,
    PROJECT_ROOT,
    TRIAL_ARTIFACT_ROOT,
    TRIAL_SOURCES,
    report_path,
    resolve_output_root,
    validate_output_contract,
)
from run_wild_bake import _renderer_environment




def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _read_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        parsed = json.load(handle)
    if not isinstance(parsed, dict):
        raise RuntimeError("Expected a JSON object: %s" % path)
    return parsed


def _source_manifest(family: str) -> Path:
    return PROJECT_ROOT / "tools" / "art" / "blender" / "vault" / family / "_fetch_manifest.json"


def _validate_selected_sources() -> int:
    checked_files = 0
    for family, source_ids in TRIAL_SOURCES.items():
        manifest_path = _source_manifest(family)
        manifest = _read_json(manifest_path)
        if manifest.get("license") != "CC0-1.0":
            raise RuntimeError("%s is not declared CC0-1.0" % manifest_path)
        assets = {str(asset.get("id", "")): asset for asset in manifest.get("assets", [])}
        for source_id in source_ids:
            asset = assets.get(source_id)
            if not isinstance(asset, dict):
                raise RuntimeError("%s is missing %s" % (manifest_path, source_id))
            if asset.get("license") != "CC0-1.0":
                raise RuntimeError("%s/%s is not declared CC0-1.0" % (family, source_id))
            for file_entry in asset.get("files", []):
                relative = Path(str(file_entry.get("path", "")))
                source_path = manifest_path.parent / relative
                if not source_path.is_file():
                    raise RuntimeError("Missing selected source input: %s" % source_path)
                expected_hash = str(file_entry.get("sha256", ""))
                actual_hash = _sha256(source_path)
                if actual_hash != expected_hash:
                    raise RuntimeError("Source SHA-256 mismatch: %s" % source_path)
                checked_files += 1
    return checked_files


def validate_preflight() -> None:
    validate_output_contract(ENVIRONMENT_ROOT)
    validate_output_contract(TRIAL_ARTIFACT_ROOT)
    if not (TRIAL_ARTIFACT_ROOT / ".gdignore").is_file():
        raise RuntimeError("Trial artifact root must stay excluded from Godot scanning")
    if resolve_output_root({}) != ENVIRONMENT_ROOT:
        raise RuntimeError("Default bake output is not the runtime environment root")
    if resolve_output_root({OUTPUT_ROOT_ENV: str(TRIAL_ARTIFACT_ROOT)}) != TRIAL_ARTIFACT_ROOT:
        raise RuntimeError("Trial bake output is not the dedicated artifact root")
    if report_path(ENVIRONMENT_ROOT).parent != ENVIRONMENT_ROOT:
        raise RuntimeError("Production aggregate report path is wrong")
    if report_path(TRIAL_ARTIFACT_ROOT).parent != TRIAL_ARTIFACT_ROOT:
        raise RuntimeError("Trial aggregate report path is wrong")
    production_environment = _renderer_environment(ENVIRONMENT_ROOT)
    if OUTPUT_ROOT_ENV in production_environment:
        raise RuntimeError("Production runner leaked a trial output override")
    trial_environment = _renderer_environment(TRIAL_ARTIFACT_ROOT)
    if trial_environment.get(OUTPUT_ROOT_ENV) != str(TRIAL_ARTIFACT_ROOT):
        raise RuntimeError("Trial runner did not pass its isolated output root")
    if trial_environment.get("BESPREN_WILD_BAKE_ISOLATED") != "1":
        raise RuntimeError("Runner did not mark Blender as isolated")
    try:
        resolve_output_root({OUTPUT_ROOT_ENV: str(PROJECT_ROOT / "tools" / "assets")})
    except RuntimeError:
        pass
    else:
        raise RuntimeError("Trial output guard accepted the old tools/assets root")
    try:
        report_path(TRIAL_ARTIFACT_ROOT, "../escape")
    except ValueError:
        pass
    else:
        raise RuntimeError("Report path guard accepted a path-like source id")
    checked_files = _validate_selected_sources()
    print(
        "WILD BAKE CONTRACT PREFLIGHT OK | root=%s | trial=%s | sources=%d | files=%d"
        % (PROJECT_ROOT, TRIAL_ARTIFACT_ROOT, sum(len(ids) for ids in TRIAL_SOURCES.values()), checked_files)
    )


def validate_trial_report(path: Path) -> None:
    report = _read_json(path)
    if report.get("mode") != "trial":
        raise RuntimeError("Trial report has wrong mode: %s" % path)
    if int(report.get("frame_size", 0)) != FRAME_SIZE:
        raise RuntimeError("Trial report has wrong frame size: %s" % path)
    if report.get("errors"):
        raise RuntimeError("Trial report contains render errors: %s" % report["errors"])
    expected_root = TRIAL_ARTIFACT_ROOT.relative_to(PROJECT_ROOT).as_posix()
    if Path(str(report.get("output_root", ""))).as_posix() != expected_root:
        raise RuntimeError("Trial report output root is not the dedicated artifact root")

    verified_frames = 0
    families = report.get("families", {})
    for family, expected_sources in TRIAL_SOURCES.items():
        entry = families.get(family)
        if not isinstance(entry, dict):
            raise RuntimeError("Trial report has no %s entry" % family)
        if tuple(entry.get("source_ids", [])) != expected_sources:
            raise RuntimeError("Trial report source selection drifted for %s" % family)
        frames = entry.get("frame_list", [])
        if not isinstance(frames, list) or not frames:
            raise RuntimeError("Trial report rendered no frames for %s" % family)
        for frame in frames:
            if str(frame.get("source_id", "")) not in expected_sources:
                raise RuntimeError("Unexpected source in %s trial: %s" % (family, frame))
            frame_path = TRIAL_ARTIFACT_ROOT / family / str(frame.get("file", ""))
            if not frame_path.is_file():
                raise RuntimeError("Trial frame is missing: %s" % frame_path)
            if _sha256(frame_path) != str(frame.get("sha256", "")):
                raise RuntimeError("Trial frame SHA-256 mismatch: %s" % frame_path)
            if int(frame.get("visible_pixels", 0)) <= 0:
                raise RuntimeError("Trial frame has no visible pixels: %s" % frame_path)
            if int(frame.get("edge_margin_px", -1)) < MINIMUM_FRAME_MARGIN:
                raise RuntimeError("Trial frame violates %d px margin: %s" % (MINIMUM_FRAME_MARGIN, frame_path))
            if float(frame.get("alpha_weighted_luma", 0.0)) < MINIMUM_ALPHA_WEIGHTED_LUMA:
                raise RuntimeError("Trial frame violates %.1f luma floor: %s" % (MINIMUM_ALPHA_WEIGHTED_LUMA, frame_path))
            if float(frame.get("world_height_m", 0.0)) <= 0.0:
                raise RuntimeError("Trial frame has no metric height: %s" % frame_path)
            verified_frames += 1
    print(
        "WILD BAKE TRIAL OK | report=%s | frames=%d | margin>=%d | luma>=%.1f | hashes=verified"
        % (path, verified_frames, MINIMUM_FRAME_MARGIN, MINIMUM_ALPHA_WEIGHTED_LUMA)
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--trial-report", type=Path)
    args = parser.parse_args()
    if args.trial_report is None:
        validate_preflight()
    else:
        validate_trial_report(args.trial_report.resolve())


if __name__ == "__main__":
    main()
