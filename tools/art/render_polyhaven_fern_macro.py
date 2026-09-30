"""Render two provenance-locked, artifact-only Poly Haven Fern 02 macro patches.

The source glTF contains four separately placed rosettes.  The normal wild
renderer correctly preserves that sparse catalogue arrangement, but it becomes
four tiny islands at the 0.38 gameplay camera.  This narrowly scoped worker
uses the *same* four source meshes and the existing shared stage, only replacing
their source-node transforms with two reviewed macro layouts.  It is an art
review probe, not an atlas builder and never writes to ``assets/``.

Run only from an isolated Blender process, for example:

  $env:BESPREN_WILD_BAKE_ISOLATED='1'
  $env:BESPREN_WILD_BAKE_OUTPUT_ROOT='<project>/artifacts/wild_salvage_trial/probes/fern_02_macro'
  blender --factory-startup --background --python tools/art/render_polyhaven_fern_macro.py

The output root guard lives in ``wild_bake_contract.py``.  Keeping the probe
there means a failed context review cannot accidentally become a runtime
texture or export dependency.
"""

from __future__ import annotations

import hashlib
import json
import os
import sys
from array import array
from pathlib import Path
from typing import Any

import bpy
from mathutils import Matrix, Vector


HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import render_polyhaven_district_sprites as district
import render_polyhaven_wild_sprites as wild
import wild_bake_contract as contract
from wild_bake_contract import (
    FRAME_SIZE,
    PROJECT_ROOT,
    TRIAL_ARTIFACT_ROOT,
    resolve_output_root,
)


FAMILY = "polyhaven_wild"
SOURCE_ID = "fern_02"
OUTPUT_ROOT = resolve_output_root()
OUTPUT_DIRECTORY_NAME = "polyhaven_wild"
REPORT_NAME = "fern_macro_render_report.json"
# Full-card alpha coverage would incorrectly reject a deliberate transparent
# ground patch.  These gates measure the actual alpha silhouette instead:
# dense, substantial foliage with an honest transparent margin—not a crop that
# merely fills a 256px square.
MINIMUM_ALPHA_WEIGHTED_LUMA = 75.0
MINIMUM_VISIBLE_PIXELS = 10_000
MINIMUM_BBOX_DENSITY = 0.45
MINIMUM_BBOX_WIDTH = 160
MINIMUM_BBOX_HEIGHT = 100
MINIMUM_MACRO_EDGE_MARGIN = 24
FRAMING_SCALE = 1.18
RENDER_POLICY = "orthographic_transparent_freestyle_agx_shared_district_rig"

# The clone layouts intentionally replace the source catalogue 2x2 positions.
# Each value is (local x metres, local y metres, z rotation radians, uniform
# scale).  Their metrics were inspected independently before this worker was
# authored; do not turn them into random runtime variation.
MACRO_LAYOUTS: tuple[tuple[str, tuple[tuple[str, float, float, float, float], ...]], ...] = (
    (
        "fern_macro_0",
        (
            ("b", -0.18, 0.12, -0.17, 1.00),
            ("c", 0.22, 0.10, 0.20, 0.95),
            ("a", -0.12, -0.23, 0.33, 1.10),
            ("d", 0.20, -0.22, -0.28, 1.08),
        ),
    ),
    (
        "fern_macro_1",
        (
            ("b", -0.22, 0.10, 0.22, 1.05),
            ("c", 0.17, 0.16, -0.19, 0.90),
            ("a", -0.18, -0.24, -0.12, 1.22),
            ("d", 0.23, -0.20, 0.37, 1.00),
        ),
    ),
)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _read_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        parsed: Any = json.load(handle)
    if not isinstance(parsed, dict):
        raise RuntimeError("Expected a JSON object: %s" % path)
    return parsed


def _source_manifest_path() -> Path:
    return HERE / "blender" / "vault" / FAMILY / "_fetch_manifest.json"


def _verified_source_asset() -> tuple[
    dict[str, Any], list[dict[str, Any]], dict[Path, Path]
]:
    """Return Fern 02 only after every manifest-listed input hashes exactly."""

    manifest_path = _source_manifest_path()
    manifest = _read_json(manifest_path)
    if manifest.get("license") != "CC0-1.0":
        raise RuntimeError("%s is not declared CC0-1.0" % manifest_path)
    assets = {
        str(candidate.get("id", "")): candidate
        for candidate in manifest.get("assets", [])
        if isinstance(candidate, dict)
    }
    asset = assets.get(SOURCE_ID)
    if asset is None:
        raise RuntimeError("%s is missing %s" % (manifest_path, SOURCE_ID))
    if asset.get("license") != "CC0-1.0":
        raise RuntimeError("%s/%s is not declared CC0-1.0" % (FAMILY, SOURCE_ID))
    files: list[dict[str, Any]] = []
    verified_paths: dict[Path, Path] = {}
    for entry in asset.get("files", []):
        if not isinstance(entry, dict):
            raise RuntimeError("Malformed source file entry for %s" % SOURCE_ID)
        relative = Path(str(entry.get("path", "")))
        if relative.is_absolute() or ".." in relative.parts:
            raise RuntimeError("Unsafe manifest path: %s" % relative)
        source_path = manifest_path.parent / relative
        if not source_path.is_file():
            raise RuntimeError("Missing Fern 02 source input: %s" % source_path)
        expected_hash = str(entry.get("sha256", ""))
        actual_hash = _sha256(source_path)
        if actual_hash != expected_hash:
            raise RuntimeError("Fern 02 source SHA-256 mismatch: %s" % source_path)
        files.append(
            {
                "path": relative.as_posix(),
                "sha256": actual_hash,
                "bytes": source_path.stat().st_size,
            }
        )
        verified_paths[relative] = source_path.resolve()
    if not files:
        raise RuntimeError("Fern 02 source has no manifest-listed files")
    return asset, files, verified_paths


def _require_isolated_artifact_root() -> None:
    if os.environ.get(wild.ISOLATED_PROCESS_ENV) != "1":
        raise RuntimeError("Fern macro renderer requires BESPREN_WILD_BAKE_ISOLATED=1")
    if not bpy.app.background:
        raise RuntimeError("Fern macro renderer refuses a non-background Blender process")
    if bpy.data.filepath:
        raise RuntimeError("Fern macro renderer refuses a loaded Blender file: %s" % bpy.data.filepath)
    if not (TRIAL_ARTIFACT_ROOT / ".gdignore").is_file():
        raise RuntimeError("Trial artifact root must remain Godot-scan excluded")
    trial_root = TRIAL_ARTIFACT_ROOT.resolve()
    expected_root = trial_root / "probes" / "fern_02_macro"
    if OUTPUT_ROOT.resolve() != expected_root:
        raise RuntimeError(
            "Fern macro probe must write only to %s, got %s" % (expected_root, OUTPUT_ROOT)
        )
    for component in (TRIAL_ARTIFACT_ROOT / "probes", OUTPUT_ROOT):
        if component.is_symlink():
            raise RuntimeError("Fern macro probe refuses symlinked artifact directory: %s" % component)


def _prepare_output_directory() -> Path:
    """Create and resolve the one legal child directory without link escapes."""

    expected_root = TRIAL_ARTIFACT_ROOT.resolve() / "probes" / "fern_02_macro"
    output_root = OUTPUT_ROOT.resolve()
    if output_root != expected_root:
        raise RuntimeError("Resolved artifact root drifted: %s" % output_root)
    output_directory = output_root / OUTPUT_DIRECTORY_NAME
    output_directory.mkdir(parents=True, exist_ok=True)
    if output_directory.is_symlink() or output_directory.resolve() != output_directory:
        raise RuntimeError("Fern macro probe refuses linked output directory: %s" % output_directory)
    try:
        output_directory.relative_to(expected_root)
    except ValueError as exc:
        raise RuntimeError("Fern macro output escaped artifact root: %s" % output_directory) from exc
    return output_directory


def _prepare_regular_output_file(output_directory: Path, filename: str) -> Path:
    """Return an overwrite-safe artifact file and erase only its old regular copy."""

    target = output_directory / filename
    if target.parent.resolve() != output_directory.resolve():
        raise RuntimeError("Fern macro output parent drifted: %s" % target)
    if target.is_symlink():
        raise RuntimeError("Fern macro probe refuses symlinked output file: %s" % target)
    if target.exists():
        if not target.is_file():
            raise RuntimeError("Fern macro output target is not a regular file: %s" % target)
        target.unlink()
    return target


def _verified_gltf_entry(
    asset: dict[str, Any], verified_paths: dict[Path, Path]
) -> tuple[Path, Path, list[str]]:
    """Permit importing only a hash-verified glTF and its verified local URIs."""

    entry_relative = Path(str(asset.get("entry", "")))
    entry_path = verified_paths.get(entry_relative)
    if entry_path is None or entry_relative.suffix.lower() != ".gltf":
        raise RuntimeError("Fern 02 entry is not a manifest-verified .gltf: %s" % entry_relative)
    try:
        gltf_payload = _read_json(entry_path)
    except UnicodeDecodeError as exc:
        raise RuntimeError("Fern 02 glTF could not be parsed as JSON: %s" % entry_path) from exc
    referenced: list[str] = [entry_relative.as_posix()]
    for section in ("buffers", "images"):
        values = gltf_payload.get(section, [])
        if not isinstance(values, list):
            raise RuntimeError("Fern 02 glTF has malformed %s" % section)
        for value in values:
            if not isinstance(value, dict) or "uri" not in value:
                continue
            uri = str(value["uri"])
            if uri.startswith("data:"):
                continue
            uri_path = Path(uri)
            if uri_path.is_absolute() or ".." in uri_path.parts:
                raise RuntimeError("Fern 02 glTF has unsafe external URI: %s" % uri)
            resolved_relative = entry_relative.parent / uri_path
            verified = verified_paths.get(resolved_relative)
            if verified is None or not verified.is_file():
                raise RuntimeError("Fern 02 glTF URI is not manifest-verified: %s" % uri)
            referenced.append(resolved_relative.as_posix())
    return entry_path, entry_relative, sorted(set(referenced))


def _alpha_bbox_metrics(path: Path) -> dict[str, float | int]:
    """Measure real alpha bounds; full-card coverage is intentionally not a gate."""

    image = bpy.data.images.load(str(path), check_existing=False)
    try:
        width, height = int(image.size[0]), int(image.size[1])
        if width != FRAME_SIZE or height != FRAME_SIZE:
            raise RuntimeError("%s must be %dx%d" % (path.name, FRAME_SIZE, FRAME_SIZE))
        pixels = array("f", [0.0]) * (width * height * 4)
        image.pixels.foreach_get(pixels)
        minimum_x, minimum_y = width, height
        maximum_x, maximum_y = -1, -1
        visible_pixels = 0
        alpha_threshold = 4.0 / 255.0
        for pixel_index in range(width * height):
            if float(pixels[pixel_index * 4 + 3]) <= alpha_threshold:
                continue
            x = pixel_index % width
            y = pixel_index // width
            minimum_x = min(minimum_x, x)
            minimum_y = min(minimum_y, y)
            maximum_x = max(maximum_x, x)
            maximum_y = max(maximum_y, y)
            visible_pixels += 1
        if visible_pixels == 0:
            raise RuntimeError("%s contains no visible alpha pixels" % path.name)
        bbox_width = maximum_x - minimum_x + 1
        bbox_height = maximum_y - minimum_y + 1
        return {
            "alpha_bbox_width_px": bbox_width,
            "alpha_bbox_height_px": bbox_height,
            "alpha_bbox_density": float(visible_pixels) / float(bbox_width * bbox_height),
            "alpha_coverage": float(visible_pixels) / float(width * height),
            "visible_pixels": visible_pixels,
        }
    finally:
        bpy.data.images.remove(image)


def _rosette_key(source: bpy.types.Object) -> str:
    """Map imported root names to the source's four documented rosette ids."""

    name = source.name.lower()
    for key in ("a", "b", "c", "d"):
        if name == key or name.endswith("_" + key) or name.endswith("-" + key):
            return key
    raise RuntimeError("Unexpected Fern 02 root name: %s" % source.name)


def _index_rosettes(meshes: list[bpy.types.Object]) -> dict[str, bpy.types.Object]:
    roots: dict[str, bpy.types.Object] = {}
    for mesh in meshes:
        if mesh.parent is not None:
            raise RuntimeError("Fern 02 mesh root unexpectedly has a parent: %s" % mesh.name)
        key = _rosette_key(mesh)
        if key in roots:
            raise RuntimeError("Duplicate Fern 02 rosette root: %s" % key)
        roots[key] = mesh
    if set(roots) != {"a", "b", "c", "d"}:
        raise RuntimeError("Fern 02 expected roots a/b/c/d, got %s" % sorted(roots))
    return roots


def _clone_macro(
    scene: bpy.types.Scene,
    sources: dict[str, bpy.types.Object],
    layout: tuple[tuple[str, float, float, float, float], ...],
) -> tuple[list[bpy.types.Object], Vector]:
    """Build one tight macro composition with no source transform leakage."""

    clones: list[bpy.types.Object] = []
    for rosette, x, y, z_rotation, scale in layout:
        source = sources.get(rosette)
        if source is None:
            raise RuntimeError("Fern macro references missing rosette: %s" % rosette)
        clone = source.copy()
        # Sharing immutable mesh/material data is intentional: this worker does
        # not edit geometry, UVs, or source materials.
        clone.data = source.data
        scene.collection.objects.link(clone)
        clone.matrix_world = Matrix.Identity(4)
        clone.hide_render = False
        clone.hide_set(False)
        clone.location = Vector((x, y, 0.0))
        clone.rotation_mode = "XYZ"
        clone.rotation_euler = (0.0, 0.0, z_rotation)
        clone.scale = Vector((scale, scale, scale))
        clone["bespren_wild_import"] = True
        clones.append(clone)
    bpy.context.view_layer.update()
    minimum, maximum = district._world_bounds(clones)
    shift = Vector((-(minimum.x + maximum.x) * 0.5, -(minimum.y + maximum.y) * 0.5, -minimum.z))
    for clone in clones:
        clone.location += shift
    bpy.context.view_layer.update()
    return clones, shift


def _remove_objects(objects: list[bpy.types.Object]) -> None:
    for obj in objects:
        if obj.name in bpy.data.objects:
            bpy.data.objects.remove(obj, do_unlink=True)


def _layout_metadata(layout: tuple[tuple[str, float, float, float, float], ...]) -> list[dict[str, float | str]]:
    return [
        {
            "rosette": rosette,
            "x_m": x,
            "y_m": y,
            "z_rotation_rad": z_rotation,
            "scale": scale,
        }
        for rosette, x, y, z_rotation, scale in layout
    ]


def generate() -> dict[str, Any]:
    """Bake two macro patches under an artifact-only provenance contract."""

    _require_isolated_artifact_root()
    asset, source_files, verified_paths = _verified_source_asset()
    gltf, gltf_relative, referenced_source_paths = _verified_gltf_entry(asset, verified_paths)
    output_directory = _prepare_output_directory()
    report: dict[str, Any] = {
        "schema_version": 1,
        "mode": "artifact_only_macro_probe",
        "artifact_only": True,
        "runtime_promotion": "forbidden_pending_macro_context_review",
        "output_root": str(OUTPUT_ROOT.relative_to(PROJECT_ROOT)).replace(os.sep, "/"),
        "output_directory": str(output_directory.relative_to(PROJECT_ROOT)).replace(os.sep, "/"),
        "frame_size": FRAME_SIZE,
        "renderer": "Blender %s" % bpy.app.version_string,
        "worker_sha256": _sha256(Path(__file__).resolve()),
        "required_command_contract": ["--factory-startup", "--background"],
        "background_process_verified": bpy.app.background,
        "loaded_blend_path_verified_empty": bpy.data.filepath == "",
        "render_policy": RENDER_POLICY,
        "framing_scale": FRAMING_SCALE,
        "source_manifest": str(_source_manifest_path().relative_to(PROJECT_ROOT)).replace(os.sep, "/"),
        "source_manifest_sha256": _sha256(_source_manifest_path()),
        "pipeline_dependencies": {
            "render_polyhaven_fern_macro.py": _sha256(Path(__file__).resolve()),
            "render_polyhaven_wild_sprites.py": _sha256(Path(wild.__file__).resolve()),
            "render_polyhaven_district_sprites.py": _sha256(Path(district.__file__).resolve()),
            "wild_bake_contract.py": _sha256(Path(contract.__file__).resolve()),
        },
        "source": {
            "family": FAMILY,
            "id": SOURCE_ID,
            "name": asset.get("name"),
            "url": asset.get("url"),
            "license": asset.get("license"),
            "license_url": "https://polyhaven.com/license",
            "authors": asset.get("authors"),
            "entry": gltf_relative.as_posix(),
            "gltf_uri_closure": referenced_source_paths,
            "files": source_files,
        },
        "quality_gates": {
            "minimum_alpha_weighted_luma": MINIMUM_ALPHA_WEIGHTED_LUMA,
            "minimum_visible_pixels": MINIMUM_VISIBLE_PIXELS,
            "minimum_alpha_bbox_density": MINIMUM_BBOX_DENSITY,
            "minimum_alpha_bbox_width_px": MINIMUM_BBOX_WIDTH,
            "minimum_alpha_bbox_height_px": MINIMUM_BBOX_HEIGHT,
            "minimum_edge_margin_px": MINIMUM_MACRO_EDGE_MARGIN,
        },
        "frames": [],
        "errors": [],
    }
    scene = bpy.context.scene
    previous_frame_size = district.FRAME_SIZE
    imported: list[bpy.types.Object] = []
    accepted_frames = 0
    try:
        wild._prepare_isolated_startup_scene(scene)
        camera, lights = district._configure_stage(scene)
        scene.render.resolution_x = FRAME_SIZE
        scene.render.resolution_y = FRAME_SIZE
        district.FRAME_SIZE = FRAME_SIZE
        imported = wild._import_source(scene, gltf)
        sources = _index_rosettes(imported)
        # The source roots remain alive only as clone templates.  Hiding them
        # prevents the original sparse 2x2 catalogue arrangement from leaking
        # into a macro frame; removing them before ``source.copy`` would leave
        # invalid Blender references.
        for source in imported:
            source.hide_render = True
            source.hide_set(True)
        for key, layout in MACRO_LAYOUTS:
            clones: list[bpy.types.Object] = []
            try:
                clones, centering_shift = _clone_macro(scene, sources, layout)
                district._frame_asset(camera, lights, clones, FRAMING_SCALE)
                target = _prepare_regular_output_file(output_directory, key + ".png")
                scene.render.filepath = str(target)
                stats = wild._render_to_quality(scene, target, key)
                alpha_metrics = _alpha_bbox_metrics(target)
                if int(alpha_metrics["visible_pixels"]) != int(stats["visible_pixels"]):
                    raise RuntimeError("%s alpha metrics disagree after canonicalization" % key)
                luma = float(stats.get("alpha_weighted_luma", 0.0))
                minimum, maximum = district._world_bounds(clones)
                dimensions = maximum - minimum
                frame_record: dict[str, Any] = {
                    "key": key,
                    "file": target.name,
                    "sha256": _sha256(target),
                    "layout": _layout_metadata(layout),
                    "bounds_m": [round(value, 6) for value in dimensions],
                    "centering_shift_m": [round(float(value), 6) for value in centering_shift],
                    "camera_ortho_scale": round(float(camera.data.ortho_scale), 6),
                    "camera_rotation_euler": [round(float(value), 6) for value in camera.rotation_euler],
                    **{
                        metric_key: (round(metric_value, 6) if isinstance(metric_value, float) else metric_value)
                        for metric_key, metric_value in alpha_metrics.items()
                    },
                    **{
                        stat_key: (round(value, 6) if isinstance(value, float) else value)
                        for stat_key, value in stats.items()
                    },
                }
                report["frames"].append(frame_record)
                if int(alpha_metrics["visible_pixels"]) < MINIMUM_VISIBLE_PIXELS:
                    frame_record["quality_status"] = "rejected"
                    raise RuntimeError(
                        "%s visible pixels %d is below %d"
                        % (key, int(alpha_metrics["visible_pixels"]), MINIMUM_VISIBLE_PIXELS)
                    )
                if float(alpha_metrics["alpha_bbox_density"]) < MINIMUM_BBOX_DENSITY:
                    frame_record["quality_status"] = "rejected"
                    raise RuntimeError(
                        "%s alpha-bounds density %.4f is below %.4f"
                        % (key, float(alpha_metrics["alpha_bbox_density"]), MINIMUM_BBOX_DENSITY)
                    )
                if (
                    int(alpha_metrics["alpha_bbox_width_px"]) < MINIMUM_BBOX_WIDTH
                    or int(alpha_metrics["alpha_bbox_height_px"]) < MINIMUM_BBOX_HEIGHT
                ):
                    frame_record["quality_status"] = "rejected"
                    raise RuntimeError(
                        "%s alpha bounds %dx%d are below %dx%d"
                        % (
                            key,
                            int(alpha_metrics["alpha_bbox_width_px"]),
                            int(alpha_metrics["alpha_bbox_height_px"]),
                            MINIMUM_BBOX_WIDTH,
                            MINIMUM_BBOX_HEIGHT,
                        )
                    )
                if int(stats["edge_margin_px"]) < MINIMUM_MACRO_EDGE_MARGIN:
                    frame_record["quality_status"] = "rejected"
                    raise RuntimeError(
                        "%s edge margin %d is below %d"
                        % (key, int(stats["edge_margin_px"]), MINIMUM_MACRO_EDGE_MARGIN)
                    )
                if luma < MINIMUM_ALPHA_WEIGHTED_LUMA:
                    frame_record["quality_status"] = "rejected"
                    raise RuntimeError(
                        "%s alpha-weighted luma %.2f is below %.2f"
                        % (key, luma, MINIMUM_ALPHA_WEIGHTED_LUMA)
                    )
                frame_record["quality_status"] = "passed"
                accepted_frames += 1
            except Exception as exc:  # noqa: BLE001 - report every reviewed layout
                report["errors"].append({"key": key, "error": "%s: %s" % (type(exc).__name__, exc)})
            finally:
                _remove_objects(clones)
        if accepted_frames != len(MACRO_LAYOUTS):
            raise RuntimeError("Not every macro frame met the artifact quality gate")
    except Exception as exc:  # noqa: BLE001 - persist evidence for a failed review gate
        report["errors"].append({"key": "setup", "error": "%s: %s" % (type(exc).__name__, exc)})
    finally:
        district.FRAME_SIZE = previous_frame_size
        district._remove_stage_objects(scene)
        wild._purge_imported()
        report_path = _prepare_regular_output_file(OUTPUT_ROOT, REPORT_NAME)
        with report_path.open("w", encoding="utf-8") as handle:
            json.dump(report, handle, indent=2)
        print(
            "FERN MACRO %s | frames=%d | errors=%d | report=%s"
            % ("OK" if not report["errors"] else "FAILED", len(report["frames"]), len(report["errors"]), report_path),
            flush=True,
        )
    return report


if __name__ == "__main__":
    result = generate()
    if result["errors"]:
        raise SystemExit(1)
