"""Independently validate the artifact-only Grass Medium 01 macro probe.

This validator deliberately runs outside Blender.  It rehashes the exact CC0
source closure and generated PNGs, recomputes alpha/occupancy metrics from the
PNG pixels, locks the reviewed root/layout contract, and rejects any route from
the trial vault into runtime export declarations.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
from pathlib import Path
from typing import Any

from PIL import Image


HERE = Path(__file__).resolve().parent
PROJECT_ROOT = HERE.parent.parent
TRIAL_ROOT = PROJECT_ROOT / "artifacts" / "wild_salvage_trial"
PROBE_ROOT = TRIAL_ROOT / "probes" / "grass_medium_01_macro_v2"
OUTPUT_DIRECTORY = PROBE_ROOT / "polyhaven_wild"
REPORT_PATH = PROBE_ROOT / "grass_macro_render_report.json"
MANIFEST_PATH = HERE / "blender" / "vault" / "polyhaven_wild" / "_fetch_manifest.json"
EXPECTED_OUTPUT_ROOT = "artifacts/wild_salvage_trial/probes/grass_medium_01_macro_v2"
EXPECTED_OUTPUT_DIRECTORY = EXPECTED_OUTPUT_ROOT + "/polyhaven_wild"
EXPECTED_KEYS = ("grass_ground_low_0", "grass_ground_low_1", "grass_ground_mid_0")
EXPECTED_CLASSES = {"grass_ground_low_0": "low", "grass_ground_low_1": "low", "grass_ground_mid_0": "mid"}
EXPECTED_ROOT_KEYS = frozenset(
	{
		"small_a", "small_b",
		"mid_a", "mid_b", "mid_c",
		"large_a", "large_b", "large_c",
		"tiny_a", "tiny_b", "tiny_c", "tiny_d", "tiny_e", "tiny_f",
		"tall_a", "tall_b", "tall_c",
	}
)
EXPECTED_LAYOUTS: dict[str, tuple[tuple[str, float, float, float, float], ...]] = {
	"grass_ground_low_0": (
		("large_a", -0.05, 0.04, -0.18, 0.76),
		("mid_c", 0.11, 0.06, 0.22, 1.08),
		("small_b", -0.08, -0.11, 0.31, 1.18),
		("tiny_e", 0.06, -0.04, -0.26, 2.05),
	),
	"grass_ground_low_1": (
		("large_c", -0.11, -0.03, 0.17, 0.86),
		("large_b", 0.07, 0.10, -0.21, 0.80),
		("small_a", 0.04, -0.08, 0.29, 1.25),
		("tiny_a", -0.10, 0.06, -0.30, 1.75),
	),
	"grass_ground_mid_0": (
		("mid_a", -0.14, -0.02, -0.17, 1.05),
		("mid_b", 0.05, 0.14, 0.23, 1.12),
		("large_c", 0.00, 0.00, 0.10, 0.82),
		("tiny_d", 0.10, -0.09, -0.27, 2.15),
	),
}
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
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
FRAME_SIZE = 256
FRAME_WORLD_SPAN = 120.0
GAMEPLAY_CAMERA_ZOOM = 0.38


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
		raise RuntimeError("Expected JSON object: %s" % path)
	return value


def _is_link_or_junction(path: Path) -> bool:
	junction_check = getattr(path, "is_junction", None)
	return path.is_symlink() or (callable(junction_check) and bool(junction_check()))


def _reject_linked_ancestors(path: Path, expected_parent: Path, label: str) -> None:
	current = path.parent
	boundary = expected_parent.resolve()
	while True:
		if _is_link_or_junction(current):
			raise RuntimeError("%s has a symlinked or junction ancestor: %s" % (label, current))
		if current.resolve() == boundary or current.parent == current:
			return
		current = current.parent


def _require_regular_path(path: Path, expected_parent: Path, label: str) -> None:
	if _is_link_or_junction(path):
		raise RuntimeError("%s may not be a symlink: %s" % (label, path))
	if not path.exists() or not path.is_file():
		raise RuntimeError("%s is missing or not a regular file: %s" % (label, path))
	_reject_linked_ancestors(path, expected_parent, label)
	try:
		path.resolve().relative_to(expected_parent.resolve())
	except ValueError as exc:
		raise RuntimeError("%s escaped its expected parent: %s" % (label, path)) from exc


def _png_size(path: Path) -> tuple[int, int]:
	with path.open("rb") as handle:
		header = handle.read(24)
	if len(header) != 24 or not header.startswith(PNG_SIGNATURE) or header[12:16] != b"IHDR":
		raise RuntimeError("Invalid PNG signature/header: %s" % path)
	return struct.unpack(">II", header[16:24])


def _manifest_grass_asset() -> dict[str, Any]:
	manifest = _read_json(MANIFEST_PATH)
	if manifest.get("license") != "CC0-1.0":
		raise RuntimeError("Wild manifest is not CC0-1.0")
	for asset in manifest.get("assets", []):
		if isinstance(asset, dict) and asset.get("id") == "grass_medium_01":
			if asset.get("license") != "CC0-1.0":
				raise RuntimeError("Grass Medium 01 is not CC0")
			return asset
	raise RuntimeError("Wild manifest lacks grass_medium_01")


def _expected_uri_closure(asset: dict[str, Any]) -> list[str]:
	entry = Path(str(asset.get("entry", "")))
	files = {Path(str(item.get("path", ""))) for item in asset.get("files", []) if isinstance(item, dict)}
	if entry not in files or entry.suffix.lower() != ".gltf":
		raise RuntimeError("Grass manifest entry is not an enumerated glTF")
	gltf_path = MANIFEST_PATH.parent / entry
	gltf = _read_json(gltf_path)
	closure = {entry.as_posix()}
	for section in ("buffers", "images"):
		items = gltf.get(section, [])
		if not isinstance(items, list):
			raise RuntimeError("Grass glTF %s is malformed" % section)
		for item in items:
			if not isinstance(item, dict) or "uri" not in item:
				continue
			uri = str(item["uri"])
			if uri.startswith("data:"):
				continue
			uri_path = Path(uri)
			if uri_path.is_absolute() or ".." in uri_path.parts:
				raise RuntimeError("Grass glTF URI escaped source closure: %s" % uri)
			resolved = entry.parent / uri_path
			if resolved not in files:
				raise RuntimeError("Grass glTF URI is not manifest-enumerated: %s" % uri)
			closure.add(resolved.as_posix())
	return sorted(closure)


def _validate_runtime_exclusion() -> None:
	for closure_path in (
		PROJECT_ROOT / "data" / "runtime_export_closure.json",
		PROJECT_ROOT / "scenes" / "build" / "runtime_export_dependencies.tscn",
	):
		if not closure_path.is_file():
			raise RuntimeError("Missing runtime closure declaration: %s" % closure_path)
		payload = closure_path.read_text(encoding="utf-8")
		for token in ("grass_medium_01_macro", "wild_salvage_trial", "grass_macro_context"):
			if token in payload:
				raise RuntimeError("Artifact-only token leaked into runtime closure: %s" % token)


def _occupancy_components(cells: set[tuple[int, int]]) -> tuple[int, float]:
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
	with Image.open(path) as image:
		if image.size != (FRAME_SIZE, FRAME_SIZE):
			raise RuntimeError("Unexpected PNG dimensions: %s" % path)
		pixels = image.convert("RGBA").load()
		minimum_x, minimum_y = FRAME_SIZE, FRAME_SIZE
		maximum_x, maximum_y = -1, -1
		visible = 0
		alpha_sum = 0.0
		weighted_luma = 0.0
		bright = 0
		occupancy_cells: set[tuple[int, int]] = set()
		bands = [0, 0, 0, 0]
		for y in range(FRAME_SIZE):
			for x in range(FRAME_SIZE):
				red, green, blue, alpha_byte = pixels[x, y]
				if alpha_byte <= 4:
					continue
				alpha = alpha_byte / 255.0
				luma = red * 0.2126 + green * 0.7152 + blue * 0.0722
				minimum_x, minimum_y = min(minimum_x, x), min(minimum_y, y)
				maximum_x, maximum_y = max(maximum_x, x), max(maximum_y, y)
				visible += 1
				alpha_sum += alpha
				weighted_luma += luma * alpha
				bright += 1 if luma > 170.0 else 0
				occupancy_cells.add((x // 8, y // 8))
				bands[min(3, int(luma // 64.0))] += 1
	if visible == 0:
		raise RuntimeError("PNG contains no visible alpha pixels: %s" % path)
	bbox_width, bbox_height = maximum_x - minimum_x + 1, maximum_y - minimum_y + 1
	band_floor = max(16, int(visible * 0.02))
	component_count, largest_component_fraction = _occupancy_components(occupancy_cells)
	return {
		"alpha_bbox_width_px": bbox_width,
		"alpha_bbox_height_px": bbox_height,
		"alpha_bbox_density": float(visible) / float(bbox_width * bbox_height),
		"alpha_coverage": float(visible) / float(FRAME_SIZE * FRAME_SIZE),
		"visible_pixels": visible,
		"edge_margin_px": min(minimum_x, minimum_y, FRAME_SIZE - 1 - maximum_x, FRAME_SIZE - 1 - maximum_y),
		"alpha_weighted_luma": weighted_luma / max(alpha_sum, 0.0001),
		"bright_alpha_fraction": float(bright) / float(visible),
		"occupied_8px_cells": len(occupancy_cells),
		"occupancy_component_count": component_count,
		"largest_occupancy_component_fraction": largest_component_fraction,
		"luma_band_count": sum(1 for count in bands if count >= band_floor),
	}


def _assert_close(actual: float, expected: float, label: str, tolerance: float = 0.0008) -> None:
	if abs(actual - expected) > tolerance:
		raise RuntimeError("%s drifted: %.8f != %.8f" % (label, actual, expected))


def _validate_frame_metrics(frame: dict[str, Any], source_path: Path) -> None:
	key = str(frame.get("key", ""))
	screen_class = EXPECTED_CLASSES[key]
	gates = CLASS_GATES[screen_class]
	measured = _alpha_metrics(source_path)
	for metric, expected in measured.items():
		if isinstance(expected, float):
			_assert_close(float(frame.get(metric, -999.0)), expected, "%s %s" % (key, metric))
		elif int(frame.get(metric, -999)) != expected:
			raise RuntimeError("%s %s drifted: %r != %r" % (key, metric, frame.get(metric), expected))
	def assert_range(metric: str, minimum_key: str, maximum_key: str) -> None:
		value = float(measured[metric])
		if value < float(gates[minimum_key]) or value > float(gates[maximum_key]):
			raise RuntimeError("%s %s is outside its locked local gate" % (key, metric))
	for metric in ("alpha_bbox_width_px", "alpha_bbox_height_px", "visible_pixels", "alpha_bbox_density", "occupied_8px_cells"):
		assert_range(metric, "minimum_" + metric, "maximum_" + metric)
	if int(measured["edge_margin_px"]) < int(COMMON_GATES["minimum_edge_margin_px"]):
		raise RuntimeError("%s violates protected frame margin" % key)
	luma = float(measured["alpha_weighted_luma"])
	if not float(COMMON_GATES["minimum_alpha_weighted_luma"]) <= luma <= float(COMMON_GATES["maximum_alpha_weighted_luma"]):
		raise RuntimeError("%s violates luma envelope" % key)
	if float(measured["bright_alpha_fraction"]) > float(COMMON_GATES["maximum_bright_alpha_fraction"]):
		raise RuntimeError("%s violates bright-alpha cap" % key)
	if int(measured["luma_band_count"]) < int(COMMON_GATES["minimum_luma_band_count"]):
		raise RuntimeError("%s lacks three readable luma bands" % key)
	if float(measured["largest_occupancy_component_fraction"]) < float(COMMON_GATES["minimum_largest_occupancy_component_fraction"]):
		raise RuntimeError("%s is not one coherent 8px occupancy mass" % key)
	projected = frame.get("projected_alpha_bounds")
	if not isinstance(projected, dict):
		raise RuntimeError("%s lacks projected-alpha metadata" % key)
	conversion = FRAME_WORLD_SPAN / FRAME_SIZE * GAMEPLAY_CAMERA_ZOOM
	for metric, source_metric, minimum_key, maximum_key in (
		("alpha_width_px", "alpha_bbox_width_px", "minimum_projected_width_px", "maximum_projected_width_px"),
		("alpha_height_px", "alpha_bbox_height_px", "minimum_projected_height_px", "maximum_projected_height_px"),
	):
		expected = float(measured[source_metric]) * conversion
		_assert_close(float(projected.get(metric, -999.0)), expected, "%s projected %s" % (key, metric))
		if expected < float(gates[minimum_key]) or expected > float(gates[maximum_key]):
			raise RuntimeError("%s projected %s is outside its locked local gate" % (key, metric))
	_assert_close(float(projected.get("world_span", -999.0)), FRAME_WORLD_SPAN, "%s world span" % key)
	_assert_close(float(projected.get("camera_zoom", -999.0)), GAMEPLAY_CAMERA_ZOOM, "%s camera zoom" % key)
	_assert_close(float(projected.get("full_card_px", -999.0)), FRAME_WORLD_SPAN * GAMEPLAY_CAMERA_ZOOM, "%s full card" % key)


def _validate_layout(key: str, frame: dict[str, Any]) -> None:
	layout = frame.get("layout")
	if not isinstance(layout, list) or len(layout) != len(EXPECTED_LAYOUTS[key]):
		raise RuntimeError("%s layout cardinality drifted" % key)
	actual_roots: set[str] = set()
	for row, expected in zip(layout, EXPECTED_LAYOUTS[key], strict=True):
		if not isinstance(row, dict):
			raise RuntimeError("%s layout row malformed" % key)
		root, x, y, rotation, scale = expected
		if row.get("root") != root:
			raise RuntimeError("%s layout root drifted" % key)
		for field, wanted in (("x_m", x), ("y_m", y), ("z_rotation_rad", rotation), ("scale", scale)):
			_assert_close(float(row.get(field, -999.0)), wanted, "%s %s" % (key, field), 0.000001)
		actual_roots.add(root)
	if actual_roots & {"tall_a", "tall_b", "tall_c"}:
		raise RuntimeError("%s illegally included deferred tall grass" % key)


def _validate_source_inventory(report: dict[str, Any]) -> None:
	inventory = report.get("worker_observed_source_root_inventory")
	if not isinstance(inventory, dict) or set(inventory) != EXPECTED_ROOT_KEYS:
		raise RuntimeError("Grass source root inventory drifted")
	for root in EXPECTED_ROOT_KEYS:
		row = inventory[root]
		if not isinstance(row, dict):
			raise RuntimeError("Malformed source root row: %s" % root)
		if row.get("object_name") != "grass_medium_01_%s_LOD0" % root:
			raise RuntimeError("Source object naming contract drifted: %s" % root)
		if int(row.get("vertex_count", 0)) <= 0:
			raise RuntimeError("Source root has no vertices: %s" % root)


def validate(report_path: Path = REPORT_PATH) -> None:
	if not report_path.is_absolute():
		report_path = Path.cwd() / report_path
	if not (TRIAL_ROOT / ".gdignore").is_file():
		raise RuntimeError("Trial artifact root must remain Godot-scan excluded")
	if _is_link_or_junction(PROBE_ROOT) or _is_link_or_junction(OUTPUT_DIRECTORY):
		raise RuntimeError("Grass macro probe root or output directory is symlinked")
	_require_regular_path(report_path, PROBE_ROOT, "grass macro report")
	report = _read_json(report_path)
	if report.get("schema_version") != 1 or report.get("mode") != "artifact_only_grass_macro_probe":
		raise RuntimeError("Grass macro report has wrong schema/mode")
	if report.get("artifact_only") is not True or report.get("runtime_promotion") != "forbidden_pending_grass_context_review":
		raise RuntimeError("Grass macro report does not preserve artifact-only state")
	if report.get("output_root") != EXPECTED_OUTPUT_ROOT or report.get("output_directory") != EXPECTED_OUTPUT_DIRECTORY:
		raise RuntimeError("Grass macro report output path drifted")
	if report.get("errors"):
		raise RuntimeError("Grass macro report contains errors: %s" % report["errors"])
	if report.get("frame_size") != FRAME_SIZE or report.get("frame_world_span") != FRAME_WORLD_SPAN or report.get("gameplay_camera_zoom") != GAMEPLAY_CAMERA_ZOOM:
		raise RuntimeError("Grass macro spatial contract drifted")
	if report.get("metric_semantics") != "finished_rgba8_round_to_nearest_threshold_alpha_gt_4":
		raise RuntimeError("Grass macro metric semantics drifted")
	if report.get("worker_observed_background_process") is not True or report.get("worker_observed_empty_loaded_blend") is not True:
		raise RuntimeError("Grass macro report did not verify isolated Blender state")
	if report.get("required_command_contract") != ["--factory-startup", "--background"]:
		raise RuntimeError("Grass macro command contract drifted")
	if report.get("worker_observed_freestyle_enabled") is not False or report.get("outline_policy") != "forbidden_no_freestyle_no_sleek_sprite_finish_no_posterization":
		raise RuntimeError("Grass macro outline policy drifted")
	if report.get("declared_source_mutation_policy") != "shared_immutable_mesh_material_data_no_geometry_uv_or_material_edits":
		raise RuntimeError("Grass macro source mutation policy drifted")
	if _sha256(MANIFEST_PATH) != report.get("source_manifest_sha256"):
		raise RuntimeError("Wild source manifest hash drifted")
	dependencies = report.get("pipeline_dependencies")
	expected_dependencies = {
		"render_polyhaven_grass_macro.py": HERE / "render_polyhaven_grass_macro.py",
		"render_polyhaven_wild_sprites.py": HERE / "render_polyhaven_wild_sprites.py",
		"render_polyhaven_district_sprites.py": HERE / "render_polyhaven_district_sprites.py",
		"wild_bake_contract.py": HERE / "wild_bake_contract.py",
	}
	if not isinstance(dependencies, dict):
		raise RuntimeError("Grass macro report lacks pipeline dependency hashes")
	for name, path in expected_dependencies.items():
		if _sha256(path) != dependencies.get(name):
			raise RuntimeError("Grass macro pipeline dependency hash drifted: %s" % name)
	if report.get("worker_sha256") != _sha256(HERE / "render_polyhaven_grass_macro.py"):
		raise RuntimeError("Grass macro worker hash drifted")
	if report.get("quality_gates") != {"common": COMMON_GATES, "classes": CLASS_GATES}:
		raise RuntimeError("Grass macro quality-gate contract drifted")
	asset = _manifest_grass_asset()
	source = report.get("source")
	if not isinstance(source, dict) or source.get("family") != "polyhaven_wild" or source.get("id") != "grass_medium_01":
		raise RuntimeError("Grass macro source identity drifted")
	if source.get("entry") != asset.get("entry") or source.get("gltf_uri_closure") != _expected_uri_closure(asset):
		raise RuntimeError("Grass macro source glTF closure drifted")
	report_files = source.get("files")
	manifest_files = asset.get("files")
	if not isinstance(report_files, list) or not isinstance(manifest_files, list) or len(report_files) != len(manifest_files):
		raise RuntimeError("Grass macro source-file list is malformed")
	expected_file_rows = {str(item.get("path")): item for item in manifest_files if isinstance(item, dict)}
	if len(expected_file_rows) != len(manifest_files):
		raise RuntimeError("Grass manifest source-file paths are not unique")
	seen_source_paths: set[str] = set()
	for row in report_files:
		if not isinstance(row, dict):
			raise RuntimeError("Malformed grass source-file row")
		relative = Path(str(row.get("path", "")))
		if relative.as_posix() in seen_source_paths:
			raise RuntimeError("Duplicate grass source-file row: %s" % relative)
		seen_source_paths.add(relative.as_posix())
		expected = expected_file_rows.get(relative.as_posix())
		if expected is None:
			raise RuntimeError("Unexpected grass source file: %s" % relative)
		source_file = MANIFEST_PATH.parent / relative
		_require_regular_path(source_file, MANIFEST_PATH.parent, "grass source file")
		if _sha256(source_file) != expected.get("sha256") or row.get("sha256") != expected.get("sha256"):
			raise RuntimeError("Grass source hash mismatch: %s" % source_file)
		if row.get("bytes") != source_file.stat().st_size:
			raise RuntimeError("Grass source byte count mismatch: %s" % source_file)
	if seen_source_paths != set(expected_file_rows):
		raise RuntimeError("Grass source-file rows do not bijectively cover the manifest")
	_validate_source_inventory(report)
	raw_frames = report.get("frames")
	if not isinstance(raw_frames, list) or len(raw_frames) != len(EXPECTED_KEYS) or any(not isinstance(frame, dict) for frame in raw_frames):
		raise RuntimeError("Grass macro report frame list is malformed")
	raw_keys = [str(frame.get("key")) for frame in raw_frames]
	if len(set(raw_keys)) != len(raw_keys):
		raise RuntimeError("Grass macro report repeats a frame key")
	frames = {str(frame.get("key")): frame for frame in raw_frames}
	if tuple(sorted(frames)) != EXPECTED_KEYS:
		raise RuntimeError("Grass macro frame identities drifted: %s" % sorted(frames))
	for key in EXPECTED_KEYS:
		frame = frames[key]
		if frame.get("quality_status") != "passed" or frame.get("screen_class") != EXPECTED_CLASSES[key]:
			raise RuntimeError("Grass macro frame did not pass the locked class gate: %s" % key)
		expected_file = OUTPUT_DIRECTORY / (key + ".png")
		if frame.get("file") != expected_file.name:
			raise RuntimeError("Grass macro frame file name drifted: %s" % key)
		_require_regular_path(expected_file, OUTPUT_DIRECTORY, "grass macro frame")
		if _sha256(expected_file) != frame.get("sha256") or _png_size(expected_file) != (FRAME_SIZE, FRAME_SIZE):
			raise RuntimeError("Grass macro output hash/dimensions drifted: %s" % key)
		_validate_layout(key, frame)
		_validate_frame_metrics(frame, expected_file)
	_validate_runtime_exclusion()
	print("GRASS MACRO PROBE VALIDATION OK | frames=3 | hashes=verified | artifact-only=true")


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("--report", type=Path, default=REPORT_PATH)
	args = parser.parse_args()
	validate(args.report)


if __name__ == "__main__":
	main()
