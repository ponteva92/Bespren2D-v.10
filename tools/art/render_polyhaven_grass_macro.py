"""Bake a provenance-locked, artifact-only Grass Medium 01 macro cohort.

The original Poly Haven source is a 17-root catalogue strip.  It is valid CC0
source material but, as a single card, it renders as a sparse dark diagonal and
does not read at Bespren's 480x270 / 0.38 gameplay camera.  This worker is a
narrow review probe: it resets a curated subset of *immutable* source roots to
three reviewed local compositions, renders them in an isolated Blender process,
and writes only beneath the ignored trial artifact vault.  It never builds an
atlas, edits a source mesh/material/UV, or creates a runtime dependency.

The output is intentionally not a promotion.  A separate ten-pocket context
gate and independent visual review must both pass before a later runtime design
decision can exist.
"""

from __future__ import annotations

import hashlib
import json
import os
import sys
from array import array
from math import log2
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
from wild_bake_contract import FRAME_SIZE, PROJECT_ROOT, TRIAL_ARTIFACT_ROOT, resolve_output_root


FAMILY = "polyhaven_wild"
SOURCE_ID = "grass_medium_01"
OUTPUT_ROOT = resolve_output_root()
OUTPUT_DIRECTORY_NAME = "polyhaven_wild"
REPORT_NAME = "grass_macro_render_report.json"
FRAME_WORLD_SPAN = 120.0
GAMEPLAY_CAMERA_ZOOM = 0.38
# Fit-to-frame normalises every composition to the same in-frame pixel size, so
# the framing margin - not the authored metre spread - is what decides how large
# a finished frame reads on the fixed 120-unit review card.  Each reviewed screen
# class therefore owns its own margin instead of sharing one.
CLASS_FRAMING_SCALES: dict[str, float] = {"low": 1.42, "mid": 1.08}
RENDER_POLICY = "orthographic_transparent_agx_shared_district_rig_no_freestyle"
OUTLINE_POLICY = "forbidden_no_freestyle_no_sleek_sprite_finish_no_posterization"
SOURCE_MUTATION_POLICY = "shared_immutable_mesh_material_data_no_geometry_uv_or_material_edits"

# The complete source inventory must remain stable.  The worker fails rather
# than silently selecting a renamed or duplicated import root.
EXPECTED_ROOT_KEYS = frozenset(
	{
		"small_a", "small_b",
		"mid_a", "mid_b", "mid_c",
		"large_a", "large_b", "large_c",
		"tiny_a", "tiny_b", "tiny_c", "tiny_d", "tiny_e", "tiny_f",
		"tall_a", "tall_b", "tall_c",
	}
)

# Layout values are local metres after completely replacing the catalogue-strip
# transform: (canonical root, local x, local y, z radians, uniform scale).
# Deliberately no tall_* node appears in Loop 1; its thin silhouette is a later
# separate review question, not a free addition to this artifact.
MACRO_LAYOUTS: tuple[tuple[str, str, tuple[tuple[str, float, float, float, float], ...]], ...] = (
	(
		"grass_ground_low_0",
		"low",
		(
			("large_a", -0.05, 0.04, -0.18, 0.76),
			("mid_c", 0.11, 0.06, 0.22, 1.08),
			("small_b", -0.08, -0.11, 0.31, 1.18),
			("tiny_e", 0.06, -0.04, -0.26, 2.05),
		),
	),
	(
		"grass_ground_low_1",
		"low",
		(
			("large_c", -0.11, -0.03, 0.17, 0.86),
			("large_b", 0.07, 0.10, -0.21, 0.80),
			("small_a", 0.04, -0.08, 0.29, 1.25),
			("tiny_a", -0.10, 0.06, -0.30, 1.75),
		),
	),
	(
		"grass_ground_mid_0",
		"mid",
		(
			("mid_a", -0.14, -0.02, -0.17, 1.05),
			("mid_b", 0.05, 0.14, 0.23, 1.12),
			("large_c", 0.00, 0.00, 0.10, 0.82),
			("tiny_d", 0.10, -0.09, -0.27, 2.15),
		),
	),
)

# This is a deliberately grass-specific local eligibility gate, not the dense
# fern gate.  Its projected measures are the honest alpha bounds at the live
# camera; a green result remains artifact-only until contextual review.
COMMON_GATES: dict[str, float | int] = {
	"minimum_edge_margin_px": 24,
	"minimum_alpha_weighted_luma": 80.0,
	"maximum_alpha_weighted_luma": 150.0,
	"maximum_bright_alpha_fraction": 0.04,
	"minimum_luma_band_count": 3,
	"minimum_largest_occupancy_component_fraction": 0.75,
}
CLASS_GATES: dict[str, dict[str, float | int]] = {
	"low": {
		"minimum_alpha_bbox_width_px": 80,
		"maximum_alpha_bbox_width_px": 170,
		"minimum_alpha_bbox_height_px": 48,
		"maximum_alpha_bbox_height_px": 112,
		"minimum_visible_pixels": 900,
		"maximum_visible_pixels": 10_500,
		"minimum_alpha_bbox_density": 0.10,
		"maximum_alpha_bbox_density": 0.58,
		"minimum_occupied_8px_cells": 30,
		"maximum_occupied_8px_cells": 220,
		"minimum_projected_width_px": 14.0,
		"maximum_projected_width_px": 30.0,
		"minimum_projected_height_px": 8.0,
		"maximum_projected_height_px": 20.0,
	},
	"mid": {
		"minimum_alpha_bbox_width_px": 105,
		"maximum_alpha_bbox_width_px": 208,
		"minimum_alpha_bbox_height_px": 70,
		"maximum_alpha_bbox_height_px": 140,
		"minimum_visible_pixels": 1_400,
		"maximum_visible_pixels": 14_500,
		"minimum_alpha_bbox_density": 0.10,
		"maximum_alpha_bbox_density": 0.62,
		"minimum_occupied_8px_cells": 40,
		"maximum_occupied_8px_cells": 300,
		"minimum_projected_width_px": 18.0,
		"maximum_projected_width_px": 37.0,
		"minimum_projected_height_px": 12.0,
		"maximum_projected_height_px": 25.0,
	},
}


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


def _verified_source_asset() -> tuple[dict[str, Any], list[dict[str, Any]], dict[Path, Path]]:
	"""Return Grass Medium 01 only when every manifest-listed input rehashes."""

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
	if asset is None or asset.get("license") != "CC0-1.0":
		raise RuntimeError("%s/%s is not a CC0 source" % (FAMILY, SOURCE_ID))
	files: list[dict[str, Any]] = []
	verified_paths: dict[Path, Path] = {}
	for entry in asset.get("files", []):
		if not isinstance(entry, dict):
			raise RuntimeError("Malformed source file entry for %s" % SOURCE_ID)
		relative = Path(str(entry.get("path", "")))
		if relative.is_absolute() or ".." in relative.parts:
			raise RuntimeError("Unsafe manifest path: %s" % relative)
		source_path = manifest_path.parent / relative
		if source_path.is_symlink() or not source_path.is_file():
			raise RuntimeError("Missing or linked Grass Medium 01 input: %s" % source_path)
		expected_hash = str(entry.get("sha256", ""))
		actual_hash = _sha256(source_path)
		if actual_hash != expected_hash:
			raise RuntimeError("Grass Medium 01 source SHA-256 mismatch: %s" % source_path)
		files.append({"path": relative.as_posix(), "sha256": actual_hash, "bytes": source_path.stat().st_size})
		verified_paths[relative] = source_path.resolve()
	if len(files) != 5:
		raise RuntimeError("Grass Medium 01 expected five source files, got %d" % len(files))
	return asset, files, verified_paths


def _require_isolated_artifact_root() -> None:
	if os.environ.get(wild.ISOLATED_PROCESS_ENV) != "1":
		raise RuntimeError("Grass macro renderer requires BESPREN_WILD_BAKE_ISOLATED=1")
	if not bpy.app.background:
		raise RuntimeError("Grass macro renderer refuses a non-background Blender process")
	if bpy.data.filepath:
		raise RuntimeError("Grass macro renderer refuses a loaded Blender file: %s" % bpy.data.filepath)
	if not (TRIAL_ARTIFACT_ROOT / ".gdignore").is_file():
		raise RuntimeError("Trial artifact root must remain Godot-scan excluded")
	expected_root = TRIAL_ARTIFACT_ROOT.resolve() / "probes" / "grass_medium_01_macro_v2"
	if OUTPUT_ROOT.resolve() != expected_root:
		raise RuntimeError("Grass macro probe must write only to %s, got %s" % (expected_root, OUTPUT_ROOT))
	for component in (TRIAL_ARTIFACT_ROOT / "probes", OUTPUT_ROOT):
		if component.is_symlink():
			raise RuntimeError("Grass macro probe refuses symlinked artifact directory: %s" % component)


def _prepare_output_directory() -> Path:
	expected_root = TRIAL_ARTIFACT_ROOT.resolve() / "probes" / "grass_medium_01_macro_v2"
	output_root = OUTPUT_ROOT.resolve()
	if output_root != expected_root:
		raise RuntimeError("Resolved artifact root drifted: %s" % output_root)
	output_root.mkdir(parents=True, exist_ok=True)
	if output_root.is_symlink() or output_root.resolve() != output_root:
		raise RuntimeError("Grass macro probe refuses a linked artifact root: %s" % output_root)
	output_directory = output_root / OUTPUT_DIRECTORY_NAME
	output_directory.mkdir(parents=True, exist_ok=True)
	if output_directory.is_symlink() or output_directory.resolve() != output_directory:
		raise RuntimeError("Grass macro probe refuses linked output directory: %s" % output_directory)
	try:
		output_directory.relative_to(expected_root)
	except ValueError as exc:
		raise RuntimeError("Grass macro output escaped artifact root: %s" % output_directory) from exc
	return output_directory


def _prepare_regular_output_file(parent: Path, filename: str) -> Path:
	target = parent / filename
	if target.parent.resolve() != parent.resolve():
		raise RuntimeError("Grass macro output parent drifted: %s" % target)
	if target.is_symlink():
		raise RuntimeError("Grass macro probe refuses a symlinked output: %s" % target)
	if target.exists():
		if not target.is_file():
			raise RuntimeError("Grass macro output is not a regular file: %s" % target)
		target.unlink()
	return target


def _verified_gltf_entry(asset: dict[str, Any], verified_paths: dict[Path, Path]) -> tuple[Path, Path, list[str]]:
	entry_relative = Path(str(asset.get("entry", "")))
	entry_path = verified_paths.get(entry_relative)
	if entry_path is None or entry_relative.suffix.lower() != ".gltf":
		raise RuntimeError("Grass Medium 01 entry is not a manifest-verified .gltf: %s" % entry_relative)
	try:
		gltf_payload = _read_json(entry_path)
	except UnicodeDecodeError as exc:
		raise RuntimeError("Grass Medium 01 glTF could not be parsed as JSON: %s" % entry_path) from exc
	referenced: list[str] = [entry_relative.as_posix()]
	for section in ("buffers", "images"):
		values = gltf_payload.get(section, [])
		if not isinstance(values, list):
			raise RuntimeError("Grass Medium 01 glTF has malformed %s" % section)
		for value in values:
			if not isinstance(value, dict) or "uri" not in value:
				continue
			uri = str(value["uri"])
			if uri.startswith("data:"):
				continue
			uri_path = Path(uri)
			if uri_path.is_absolute() or ".." in uri_path.parts:
				raise RuntimeError("Grass Medium 01 glTF has unsafe external URI: %s" % uri)
			resolved_relative = entry_relative.parent / uri_path
			if resolved_relative not in verified_paths:
				raise RuntimeError("Grass Medium 01 glTF URI is not manifest-verified: %s" % uri)
			referenced.append(resolved_relative.as_posix())
	return entry_path, entry_relative, sorted(set(referenced))


def _canonical_root_key(source: bpy.types.Object) -> str:
	name = source.name.lower()
	prefix = "grass_medium_01_"
	suffix = "_lod0"
	if not name.startswith(prefix) or not name.endswith(suffix):
		raise RuntimeError("Unexpected Grass Medium 01 root name: %s" % source.name)
	key = name[len(prefix):-len(suffix)]
	if key not in EXPECTED_ROOT_KEYS:
		raise RuntimeError("Unexpected Grass Medium 01 root key: %s" % source.name)
	return key


def _index_roots(meshes: list[bpy.types.Object]) -> dict[str, bpy.types.Object]:
	roots: dict[str, bpy.types.Object] = {}
	for mesh in meshes:
		if mesh.parent is not None:
			raise RuntimeError("Grass Medium 01 mesh root unexpectedly has a parent: %s" % mesh.name)
		key = _canonical_root_key(mesh)
		if key in roots:
			raise RuntimeError("Duplicate Grass Medium 01 root: %s" % key)
		roots[key] = mesh
	if set(roots) != EXPECTED_ROOT_KEYS:
		raise RuntimeError("Grass Medium 01 root inventory drifted: %s" % sorted(roots))
	if len(meshes) != len(EXPECTED_ROOT_KEYS):
		raise RuntimeError("Grass Medium 01 expected %d render roots, got %d" % (len(EXPECTED_ROOT_KEYS), len(meshes)))
	return roots


def _occupancy_components(cells: set[tuple[int, int]]) -> tuple[int, float]:
	"""Return 8-neighbour component count and dominant-component share."""

	if not cells:
		return 0, 0.0
	remaining = set(cells)
	largest = 0
	components = 0
	while remaining:
		components += 1
		stack = [remaining.pop()]
		component_size = 0
		while stack:
			cell_x, cell_y = stack.pop()
			component_size += 1
			for offset_x in (-1, 0, 1):
				for offset_y in (-1, 0, 1):
					if offset_x == 0 and offset_y == 0:
						continue
					neighbour = (cell_x + offset_x, cell_y + offset_y)
					if neighbour in remaining:
						remaining.remove(neighbour)
						stack.append(neighbour)
		largest = max(largest, component_size)
	return components, float(largest) / float(len(cells))


def _alpha_metrics(path: Path) -> dict[str, float | int]:
	"""Measure actual alpha bounds and occupancy without treating blades as a blob."""

	image = bpy.data.images.load(str(path), check_existing=False)
	try:
		width, height = int(image.size[0]), int(image.size[1])
		if (width, height) != (FRAME_SIZE, FRAME_SIZE):
			raise RuntimeError("%s must be %dx%d" % (path.name, FRAME_SIZE, FRAME_SIZE))
		pixels = array("f", [0.0]) * (width * height * 4)
		image.pixels.foreach_get(pixels)
		minimum_x, minimum_y = width, height
		maximum_x, maximum_y = -1, -1
		visible = 0
		alpha_sum = 0.0
		weighted_luma = 0.0
		bright = 0
		occupancy_cells: set[tuple[int, int]] = set()
		bands = [0, 0, 0, 0]
		for pixel_index in range(width * height):
			offset = pixel_index * 4
			# The independent validator reads the finished 8-bit PNG through
			# Pillow.  Quantise Blender's float reload the same way *before*
			# thresholding or measuring so a semi-transparent boundary pixel
			# cannot pass in Blender and disappear in the independent check.
			red_byte = max(0, min(255, int(float(pixels[offset]) * 255.0 + 0.5)))
			green_byte = max(0, min(255, int(float(pixels[offset + 1]) * 255.0 + 0.5)))
			blue_byte = max(0, min(255, int(float(pixels[offset + 2]) * 255.0 + 0.5)))
			alpha_byte = max(0, min(255, int(float(pixels[offset + 3]) * 255.0 + 0.5)))
			if alpha_byte <= 4:
				continue
			x, y = pixel_index % width, pixel_index // width
			alpha = float(alpha_byte) / 255.0
			luma = red_byte * 0.2126 + green_byte * 0.7152 + blue_byte * 0.0722
			minimum_x, minimum_y = min(minimum_x, x), min(minimum_y, y)
			maximum_x, maximum_y = max(maximum_x, x), max(maximum_y, y)
			visible += 1
			alpha_sum += alpha
			weighted_luma += luma * alpha
			bright += 1 if luma > 170.0 else 0
			occupancy_cells.add((x // 8, y // 8))
			bands[min(3, int(luma // 64.0))] += 1
		if visible == 0:
			raise RuntimeError("%s contains no visible alpha pixels" % path.name)
		bbox_width, bbox_height = maximum_x - minimum_x + 1, maximum_y - minimum_y + 1
		band_floor = max(16, int(visible * 0.02))
		component_count, largest_component_fraction = _occupancy_components(occupancy_cells)
		return {
			"alpha_bbox_width_px": bbox_width,
			"alpha_bbox_height_px": bbox_height,
			"alpha_bbox_density": float(visible) / float(bbox_width * bbox_height),
			"alpha_coverage": float(visible) / float(width * height),
			"visible_pixels": visible,
			"edge_margin_px": min(minimum_x, minimum_y, width - 1 - maximum_x, height - 1 - maximum_y),
			"alpha_weighted_luma": weighted_luma / max(alpha_sum, 0.0001),
			"bright_alpha_fraction": float(bright) / float(visible),
			"occupied_8px_cells": len(occupancy_cells),
			"occupancy_component_count": component_count,
			"largest_occupancy_component_fraction": largest_component_fraction,
			"luma_band_count": sum(1 for count in bands if count >= band_floor),
		}
	finally:
		bpy.data.images.remove(image)


def _render_to_grass_luma(scene: bpy.types.Scene, target: Path, label: str) -> dict[str, float | int]:
	"""Use exposure only to reach the reviewed readability envelope, never recolour source pixels."""

	baseline_exposure = scene.view_settings.exposure
	try:
		for attempt in range(5):
			bpy.ops.render.render(write_still=True)
			district._canonicalize_png(target)
			metrics = _alpha_metrics(target)
			luma = float(metrics["alpha_weighted_luma"])
			if COMMON_GATES["minimum_alpha_weighted_luma"] <= luma <= COMMON_GATES["maximum_alpha_weighted_luma"]:
				metrics["worker_observed_render_attempt_count"] = attempt + 1
				metrics["worker_observed_final_exposure"] = float(scene.view_settings.exposure)
				return metrics
			if attempt == 4:
				raise RuntimeError("%s luma %.2f is outside %.1f..%.1f after exposure review" % (
					label, luma, COMMON_GATES["minimum_alpha_weighted_luma"], COMMON_GATES["maximum_alpha_weighted_luma"]
				))
			if luma < float(COMMON_GATES["minimum_alpha_weighted_luma"]):
				scene.view_settings.exposure += max(0.18, min(log2(float(COMMON_GATES["minimum_alpha_weighted_luma"]) / max(luma, 1.0)), 0.85))
			else:
				scene.view_settings.exposure -= max(0.18, min(log2(max(luma, 1.0) / float(COMMON_GATES["maximum_alpha_weighted_luma"])), 0.85))
	finally:
		scene.view_settings.exposure = baseline_exposure
	raise RuntimeError("Unreachable grass luma review for %s" % label)


def _clone_macro(
	scene: bpy.types.Scene,
	sources: dict[str, bpy.types.Object],
	layout: tuple[tuple[str, float, float, float, float], ...],
) -> tuple[list[bpy.types.Object], Vector]:
	clones: list[bpy.types.Object] = []
	for root_key, x, y, z_rotation, scale in layout:
		source = sources.get(root_key)
		if source is None:
			raise RuntimeError("Grass macro references missing root: %s" % root_key)
		clone = source.copy()
		# Deliberately share immutable source geometry/materials.  The only edits
		# are clone transforms that replace the source catalogue layout.
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
			"root": root_key,
			"x_m": x,
			"y_m": y,
			"z_rotation_rad": z_rotation,
			"scale": scale,
		}
		for root_key, x, y, z_rotation, scale in layout
	]


def _projected_bounds(metrics: dict[str, float | int]) -> dict[str, float]:
	conversion = FRAME_WORLD_SPAN / float(FRAME_SIZE) * GAMEPLAY_CAMERA_ZOOM
	return {
		"world_span": FRAME_WORLD_SPAN,
		"camera_zoom": GAMEPLAY_CAMERA_ZOOM,
		"alpha_width_px": float(metrics["alpha_bbox_width_px"]) * conversion,
		"alpha_height_px": float(metrics["alpha_bbox_height_px"]) * conversion,
		"full_card_px": FRAME_WORLD_SPAN * GAMEPLAY_CAMERA_ZOOM,
	}


def _collect_frame_metric_failures(frame: dict[str, Any], screen_class: str) -> list[str]:
	gates = CLASS_GATES[screen_class]
	failures: list[str] = []
	def require_range(metric: str, minimum_key: str, maximum_key: str) -> None:
		value = float(frame[metric])
		minimum, maximum = float(gates[minimum_key]), float(gates[maximum_key])
		if value < minimum or value > maximum:
			failures.append("%s %.3f is outside %.3f..%.3f" % (metric, value, minimum, maximum))
	for metric in ("alpha_bbox_width_px", "alpha_bbox_height_px", "visible_pixels", "alpha_bbox_density", "occupied_8px_cells"):
		require_range(metric, "minimum_" + metric, "maximum_" + metric)
	projected = frame["projected_alpha_bounds"]
	if not isinstance(projected, dict):
		return ["projected_alpha_bounds is missing or malformed"]
	for metric, minimum_key, maximum_key in (
		("alpha_width_px", "minimum_projected_width_px", "maximum_projected_width_px"),
		("alpha_height_px", "minimum_projected_height_px", "maximum_projected_height_px"),
	):
		value = float(projected[metric])
		if value < float(gates[minimum_key]) or value > float(gates[maximum_key]):
			failures.append("projected_%s %.3f is outside %.3f..%.3f" % (
				metric, value, float(gates[minimum_key]), float(gates[maximum_key])
			))
	if int(frame["edge_margin_px"]) < int(COMMON_GATES["minimum_edge_margin_px"]):
		failures.append("edge_margin_px is below the protected boundary")
	luma = float(frame["alpha_weighted_luma"])
	if luma < float(COMMON_GATES["minimum_alpha_weighted_luma"]) or luma > float(COMMON_GATES["maximum_alpha_weighted_luma"]):
		failures.append("alpha_weighted_luma is outside the reviewed envelope")
	if float(frame["bright_alpha_fraction"]) > float(COMMON_GATES["maximum_bright_alpha_fraction"]):
		failures.append("bright_alpha_fraction exceeds the highlight cap")
	if int(frame["luma_band_count"]) < int(COMMON_GATES["minimum_luma_band_count"]):
		failures.append("luma_band_count is below three readable bands")
	if float(frame["largest_occupancy_component_fraction"]) < float(COMMON_GATES["minimum_largest_occupancy_component_fraction"]):
		failures.append("largest_occupancy_component_fraction is below the unified-mass floor")
	return failures


def generate() -> dict[str, Any]:
	"""Bake only the three reviewed Grass Medium 01 artifact frames."""

	_require_isolated_artifact_root()
	output_directory = _prepare_output_directory()
	asset, source_files, verified_paths = _verified_source_asset()
	gltf, gltf_relative, referenced_source_paths = _verified_gltf_entry(asset, verified_paths)
	report: dict[str, Any] = {
		"schema_version": 1,
		"mode": "artifact_only_grass_macro_probe",
		"artifact_only": True,
		"runtime_promotion": "forbidden_pending_grass_context_review",
		"output_root": str(OUTPUT_ROOT.relative_to(PROJECT_ROOT)).replace(os.sep, "/"),
		"output_directory": str(output_directory.relative_to(PROJECT_ROOT)).replace(os.sep, "/"),
		"frame_size": FRAME_SIZE,
		"metric_semantics": "finished_rgba8_round_to_nearest_threshold_alpha_gt_4",
		"frame_world_span": FRAME_WORLD_SPAN,
		"gameplay_camera_zoom": GAMEPLAY_CAMERA_ZOOM,
		"renderer": "Blender %s" % bpy.app.version_string,
		"worker_sha256": _sha256(Path(__file__).resolve()),
		"required_command_contract": ["--factory-startup", "--background"],
		"worker_observed_background_process": bpy.app.background,
		"worker_observed_empty_loaded_blend": bpy.data.filepath == "",
		"render_policy": RENDER_POLICY,
		"outline_policy": OUTLINE_POLICY,
		"worker_observed_freestyle_enabled": False,
		"framing_scales": dict(CLASS_FRAMING_SCALES),
		"declared_source_mutation_policy": SOURCE_MUTATION_POLICY,
		"source_manifest": str(_source_manifest_path().relative_to(PROJECT_ROOT)).replace(os.sep, "/"),
		"source_manifest_sha256": _sha256(_source_manifest_path()),
		"pipeline_dependencies": {
			"render_polyhaven_grass_macro.py": _sha256(Path(__file__).resolve()),
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
		"quality_gates": {"common": COMMON_GATES, "classes": CLASS_GATES},
		"worker_observed_source_root_inventory": {},
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
		scene.render.use_freestyle = False
		if scene.render.use_freestyle:
			raise RuntimeError("Grass macro requires Freestyle to be disabled")
		scene.render.resolution_x = FRAME_SIZE
		scene.render.resolution_y = FRAME_SIZE
		district.FRAME_SIZE = FRAME_SIZE
		imported = wild._import_source(scene, gltf)
		sources = _index_roots(imported)
		report["worker_observed_source_root_inventory"] = {
			key: {"object_name": source.name, "vertex_count": len(source.data.vertices)}
			for key, source in sorted(sources.items())
		}
		if any(int(item["vertex_count"]) <= 0 for item in report["worker_observed_source_root_inventory"].values()):
			raise RuntimeError("Grass Medium 01 contains an empty render root")
		for source in imported:
			source.hide_render = True
			source.hide_set(True)
		for key, screen_class, layout in MACRO_LAYOUTS:
			clones: list[bpy.types.Object] = []
			try:
				clones, centering_shift = _clone_macro(scene, sources, layout)
				framing_scale = CLASS_FRAMING_SCALES.get(screen_class, 0.0)
				if framing_scale <= 0.0:
					raise RuntimeError("Grass macro screen class has no reviewed framing scale: %s" % screen_class)
				district._frame_asset(camera, lights, clones, framing_scale)
				target = _prepare_regular_output_file(output_directory, key + ".png")
				scene.render.filepath = str(target)
				metrics = _render_to_grass_luma(scene, target, key)
				minimum, maximum = district._world_bounds(clones)
				frame: dict[str, Any] = {
					"key": key,
					"screen_class": screen_class,
					"file": target.name,
					"sha256": _sha256(target),
					"layout": _layout_metadata(layout),
					"bounds_m": [round(float(value), 6) for value in (maximum - minimum)],
					"centering_shift_m": [round(float(value), 6) for value in centering_shift],
					"framing_scale": framing_scale,
					"camera_ortho_scale": round(float(camera.data.ortho_scale), 6),
					"camera_rotation_euler": [round(float(value), 6) for value in camera.rotation_euler],
					"projected_alpha_bounds": _projected_bounds(metrics),
					**{metric: (round(value, 6) if isinstance(value, float) else value) for metric, value in metrics.items()},
				}
				report["frames"].append(frame)
				failures = _collect_frame_metric_failures(frame, screen_class)
				frame["quality_failures"] = failures
				if failures:
					frame["quality_status"] = "failed"
					raise RuntimeError("; ".join(failures))
				frame["quality_status"] = "passed"
				accepted_frames += 1
			except Exception as exc:  # Persist every failed candidate as evidence.
				report["errors"].append({"key": key, "error": "%s: %s" % (type(exc).__name__, exc)})
			finally:
				_remove_objects(clones)
		if accepted_frames != len(MACRO_LAYOUTS):
			raise RuntimeError("Not every grass macro frame met its artifact-local gate")
	except Exception as exc:  # Persist setup failures too; no hidden fallback is allowed.
		report["errors"].append({"key": "setup", "error": "%s: %s" % (type(exc).__name__, exc)})
	finally:
		district.FRAME_SIZE = previous_frame_size
		district._remove_stage_objects(scene)
		wild._purge_imported()
		report_path = _prepare_regular_output_file(OUTPUT_ROOT, REPORT_NAME)
		with report_path.open("w", encoding="utf-8") as handle:
			json.dump(report, handle, indent=2)
		print(
			"GRASS MACRO %s | frames=%d | errors=%d | report=%s" % (
				"OK" if not report["errors"] else "FAILED", len(report["frames"]), len(report["errors"]), report_path
			),
			flush=True,
		)
	return report


if __name__ == "__main__":
	result = generate()
	if result["errors"]:
		raise SystemExit(1)
