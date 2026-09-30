extends Node2D
## Artifact-only gameplay-context review for the three Grass Medium 01 macro probes.
##
## This is the fern macro gate's successor.  That gate proved the captures could
## be produced but left the verdict to an eye that never rendered one, and it
## composited through a single unexamined tint.  Direct measurement of its own
## output later showed the accent landing 16.0 luma *below* the ground it covered
## while changing 0.37% of the frame, so the recipe - not only the source - was
## the thing under test all along.
##
## This gate therefore sweeps several explicit composition recipes and measures
## each one against its own per-patch baseline, so the artifact carries numbers
## instead of an impression.  It still loads ImageTextures from the ignored trial
## vault, pins every frame hash, and adds a transient z=-5 child beneath the real
## WorldMap tree.  Nothing here is an atlas, scene dependency, physics object,
## flow-mask input, or export-closure resource.

const NETWORK_PLAYER_SCENE: PackedScene = preload("res://scenes/characters/network_player.tscn")
const SLEEK_CANVAS_SHADER: Shader = preload("res://shaders/sleek_canvas_grade.gdshader")
const PROBE_ROOT: String = "res://artifacts/wild_salvage_trial/probes/grass_medium_01_macro_v2"
const MACRO_REPORT_PATH: String = PROBE_ROOT + "/grass_macro_render_report.json"
const MACRO_OUTPUT_DIRECTORY: String = "artifacts/wild_salvage_trial/probes/grass_medium_01_macro_v2/polyhaven_wild"
const MACRO_FRAME_PATHS: Array[String] = [
	PROBE_ROOT + "/polyhaven_wild/grass_ground_low_0.png",
	PROBE_ROOT + "/polyhaven_wild/grass_ground_low_1.png",
	PROBE_ROOT + "/polyhaven_wild/grass_ground_mid_0.png",
]
const MACRO_FRAME_HASHES: Array[String] = [
	"d57a55ab726f4085713bf0498074cfc7c7c32706f387f901d98b0feddc618beb",
	"1cec96bee6937b49667026488164789e7ca199a9147e09e09c0bb563e7826ac2",
	"0191ab3c8b8bd685f6848d2132e5631d1753d9b10be6be52a335b6623a670508",
]
const OUTPUT_DIRECTORY_PATH: String = PROBE_ROOT + "/context"
const METADATA_OUTPUT_PATH: String = PROBE_ROOT + "/grass_macro_context_validation.json"
const GAMEPLAY_CAMERA_ZOOM: float = 0.38
## The probe's projected-size gate was scored against a 120-unit card, so the
## review card must be the same size or the measured logical size is fiction.
const FRAME_WORLD_SPAN: float = 120.0
const FRAME_VISUAL_RADIUS: float = FRAME_WORLD_SPAN * 0.70710678
const OCCLUSION_MARGIN: float = 32.0
const REQUIRED_CLEARANCE_RADIUS: float = FRAME_VISUAL_RADIUS + OCCLUSION_MARGIN
const REQUIRED_ROAD_CLEARANCE: float = 480.0
const PATCH_TARGET_COUNT: int = 8
const SAMPLE_RING_COUNT: int = 13
const SAMPLE_SPOKE_COUNT: int = 24
const BASELINE_PREFIX: String = "baseline"
## A pixel counts as changed once it moves further than this summed 8-bit RGB
## distance.  It is the same threshold the fern captures were measured with, so
## the two families' coverage numbers stay directly comparable.
const CHANGE_THRESHOLD: int = 12

## Each recipe is one complete answer to "how should a ground accent sit on the
## terrain".  `subordinate` reproduces the fern gate's tint exactly so the new
## numbers can be read against the old failure; the others progressively stop
## suppressing the bake.  None of them is approved - the gate reports what each
## one measures.
const RECIPES: Array[Dictionary] = [
	{
		"name": "subordinate",
		"note": "fern gate tint, reproduced for direct comparison",
		"tint": Color(0.66, 0.74, 0.48, 0.66),
	},
	{
		"name": "natural",
		"note": "bake carried at near-full opacity with no colour suppression",
		"tint": Color(1.0, 1.0, 1.0, 0.9),
	},
	{
		"name": "lifted",
		"note": "opaque and modestly brightened to test the readability ceiling",
		"tint": Color(1.18, 1.14, 0.96, 1.0),
	},
]

@onready var camera: Camera2D = %ValidationCamera
@onready var lighting: CanvasModulate = %ValidationLighting
@onready var y_sort_world: Node2D = $YSortWorld
@onready var world_map: BesprenWorldMap2D = $YSortWorld/WorldMap2D as BesprenWorldMap2D

var _player: Node2D
var _structure: PlacedStructure2D


class GrassMacroArtifactLayer extends Node2D:
	var _textures: Array[Texture2D] = []
	var _tint: Color = Color.WHITE
	var _positions: PackedVector2Array = PackedVector2Array()
	var _variants: PackedInt32Array = PackedInt32Array()
	var _rotations: PackedFloat32Array = PackedFloat32Array()
	var _mirrors: PackedByteArray = PackedByteArray()
	var _frame_span: float = 0.0

	func configure(
		frame_paths: Array[String],
		positions: PackedVector2Array,
		variants: PackedInt32Array,
		rotations: PackedFloat32Array,
		mirrors: PackedByteArray,
		frame_span: float
	) -> bool:
		if (
			positions.size() != variants.size()
			or positions.size() != rotations.size()
			or positions.size() != mirrors.size()
			or positions.is_empty()
			or frame_span <= 0.0
		):
			return false
		z_index = -5
		z_as_relative = false
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var grade_material: ShaderMaterial = ShaderMaterial.new()
		grade_material.shader = SLEEK_CANVAS_SHADER
		material = grade_material
		_textures.clear()
		_positions = positions.duplicate()
		_variants = variants.duplicate()
		_rotations = rotations.duplicate()
		_mirrors = mirrors.duplicate()
		_frame_span = frame_span
		for frame_path: String in frame_paths:
			var image: Image = Image.new()
			if image.load(ProjectSettings.globalize_path(frame_path)) != OK:
				return false
			if image.get_size() != Vector2i(256, 256):
				return false
			## Every one of the project's runtime texture imports carries
			## process/fix_alpha_border=true.  Loading the probe PNG straight into an
			## ImageTexture bypasses the importer, so without this the review would
			## minify RGB=0 transparent pixels into the surviving texels and measure a
			## darker sprite than the runtime would ever ship.
			image.fix_alpha_edges()
			if image.generate_mipmaps() != OK:
				return false
			var texture: ImageTexture = ImageTexture.create_from_image(image)
			if texture == null:
				return false
			_textures.append(texture)
		queue_redraw()
		return _textures.size() == frame_paths.size()

	func set_recipe_tint(tint: Color) -> void:
		_tint = tint
		queue_redraw()

	func _draw() -> void:
		if _textures.is_empty() or _frame_span <= 0.0:
			return
		var frame_size: Vector2 = Vector2.ONE * _frame_span
		for patch_index: int in range(_positions.size()):
			var variant: int = _variants[patch_index]
			if variant < 0 or variant >= _textures.size():
				continue
			var mirror_scale: Vector2 = Vector2(-1.0, 1.0) if _mirrors[patch_index] != 0 else Vector2.ONE
			draw_set_transform(_positions[patch_index], _rotations[patch_index], mirror_scale)
			draw_texture_rect(
				_textures[variant],
				Rect2(-frame_size * 0.5, frame_size),
				false,
				_tint
			)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ready() -> void:
	if world_map == null:
		_fail("missing WorldMap2D")
		return
	if not _verify_macro_probe():
		_fail("macro report, output hash, dimensions, or runtime-exclusion contract changed")
		return
	var make_directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY_PATH)
	)
	if make_directory_error != OK:
		_fail("could not create macro-context artifact directory: %s" % error_string(make_directory_error))
		return
	await get_tree().process_frame
	var patches: Array[Dictionary] = _find_render_clear_patches()
	if patches.size() != PATCH_TARGET_COUNT:
		_fail("only found %d/%d wilderness macro positions outside accent and ambient render envelopes" % [
			patches.size(), PATCH_TARGET_COUNT,
		])
		return
	var layer: GrassMacroArtifactLayer = GrassMacroArtifactLayer.new()
	world_map.add_child(layer)
	var positions: PackedVector2Array = PackedVector2Array()
	var variants: PackedInt32Array = PackedInt32Array()
	var rotations: PackedFloat32Array = PackedFloat32Array()
	var mirrors: PackedByteArray = PackedByteArray()
	for patch_index: int in range(patches.size()):
		var patch: Dictionary = patches[patch_index]
		positions.append(patch["position"] as Vector2)
		variants.append(patch_index % MACRO_FRAME_PATHS.size())
		rotations.append([-0.14, 0.09, 0.17, -0.11, 0.05, -0.18, 0.13, -0.07][patch_index])
		mirrors.append(1 if patch_index % 3 == 1 else 0)
	if not layer.configure(
		MACRO_FRAME_PATHS,
		positions,
		variants,
		rotations,
		mirrors,
		FRAME_WORLD_SPAN
	):
		_fail("could not construct macro artifact layer")
		return
	if not _spawn_scale_references(patches[0]["position"] as Vector2):
		_fail("could not construct scale references")
		return
	var captures: Array[Dictionary] = []
	var measurements: Array[Dictionary] = []
	for patch_index: int in range(patches.size()):
		var patch: Dictionary = patches[patch_index]
		for phase: String in ["day", "night"]:
			var light_color: Color = (
				Color.WHITE if phase == "day" else NightAtmosphere2D.SAPPHIRE_NIGHT_COLOR
			)
			layer.visible = false
			var baseline: Image = await _capture_patch(
				patch_index, patch, phase, light_color, BASELINE_PREFIX, captures
			)
			if baseline == null:
				return
			layer.visible = true
			for recipe: Dictionary in RECIPES:
				layer.set_recipe_tint(recipe["tint"] as Color)
				var rendered: Image = await _capture_patch(
					patch_index, patch, phase, light_color, recipe["name"] as String, captures
				)
				if rendered == null:
					return
				measurements.append(
					_measure_against_baseline(baseline, rendered, patch_index, patch, phase, recipe)
				)
	var summary: Dictionary = _summarise(measurements)
	_write_metadata(patches, captures, measurements, summary)
	print("GRASS MACRO CONTEXT OK | patches=%d | recipes=%d | captures=%d | measurements=%d" % [
		patches.size(), RECIPES.size(), captures.size(), measurements.size(),
	])
	for recipe: Dictionary in RECIPES:
		var name: String = recipe["name"] as String
		var day: Dictionary = summary[name]["day"]
		var night: Dictionary = summary[name]["night"]
		print("  %-12s day  cover %.3f%%  ground %5.1f -> accent %5.1f (%+.1f)  peak %+.1f" % [
			name,
			float(day["changed_fraction"]) * 100.0,
			day["ground_luma"], day["accent_luma"], day["luma_delta"], day["peak_luma_delta"],
		])
		print("  %-12s night cover %.3f%%  ground %5.1f -> accent %5.1f (%+.1f)  peak %+.1f" % [
			"",
			float(night["changed_fraction"]) * 100.0,
			night["ground_luma"], night["accent_luma"], night["luma_delta"], night["peak_luma_delta"],
		])
	get_tree().quit(0)


func _verify_macro_probe() -> bool:
	if MACRO_FRAME_PATHS.size() != MACRO_FRAME_HASHES.size():
		return false
	var report_file: FileAccess = FileAccess.open(MACRO_REPORT_PATH, FileAccess.READ)
	if report_file == null:
		return false
	var parsed: Variant = JSON.parse_string(report_file.get_as_text())
	report_file.close()
	if not parsed is Dictionary:
		return false
	var report: Dictionary = parsed
	if (
		report.get("artifact_only") != true
		or report.get("runtime_promotion") != "forbidden_pending_grass_context_review"
		or report.get("errors") != []
		or report.get("output_directory") != MACRO_OUTPUT_DIRECTORY
	):
		return false
	var report_frames_variant: Variant = report.get("frames", [])
	if not report_frames_variant is Array or report_frames_variant.size() != MACRO_FRAME_PATHS.size():
		return false
	var report_hashes: Dictionary = {}
	for frame_variant: Variant in report_frames_variant:
		if not frame_variant is Dictionary:
			return false
		var frame: Dictionary = frame_variant
		if frame.get("quality_status") != "passed":
			return false
		report_hashes[frame.get("file", "")] = frame.get("sha256", "")
	for frame_index: int in range(MACRO_FRAME_PATHS.size()):
		var absolute_path: String = ProjectSettings.globalize_path(MACRO_FRAME_PATHS[frame_index])
		if not FileAccess.file_exists(absolute_path):
			return false
		if FileAccess.get_sha256(absolute_path) != MACRO_FRAME_HASHES[frame_index]:
			return false
		if report_hashes.get(MACRO_FRAME_PATHS[frame_index].get_file(), "") != MACRO_FRAME_HASHES[frame_index]:
			return false
		var image: Image = Image.new()
		if image.load(absolute_path) != OK or image.get_size() != Vector2i(256, 256):
			return false
	for runtime_closure_path: String in [
		"res://data/runtime_export_closure.json",
		"res://scenes/build/runtime_export_dependencies.tscn",
	]:
		var closure_file: FileAccess = FileAccess.open(runtime_closure_path, FileAccess.READ)
		if closure_file == null:
			return false
		var closure_text: String = closure_file.get_as_text()
		closure_file.close()
		if "grass_medium_01" in closure_text or "wild_salvage_trial" in closure_text:
			return false
	return true


func _find_render_clear_patches() -> Array[Dictionary]:
	var ambient: Node2D = world_map.get_node_or_null("AmbientScenery") as Node2D
	var accent: Node2D = world_map.get_node_or_null("WildernessAccent") as Node2D
	if ambient == null or accent == null:
		return []
	var ambient_positions_variant: Variant = ambient.call(&"get_scenery_positions")
	var ambient_radii_variant: Variant = ambient.call(&"get_scenery_visual_radii")
	var accent_positions_variant: Variant = accent.call(&"get_anchor_positions")
	var accent_radii_variant: Variant = accent.call(&"get_anchor_visual_radii")
	if (
		not ambient_positions_variant is PackedVector2Array
		or not ambient_radii_variant is PackedFloat32Array
		or not accent_positions_variant is PackedVector2Array
		or not accent_radii_variant is PackedFloat32Array
	):
		return []
	var ambient_positions: PackedVector2Array = ambient_positions_variant
	var ambient_radii: PackedFloat32Array = ambient_radii_variant
	var accent_positions: PackedVector2Array = accent_positions_variant
	var accent_radii: PackedFloat32Array = accent_radii_variant
	if ambient_positions.size() != ambient_radii.size() or accent_positions.size() != accent_radii.size():
		return []
	var patches: Array[Dictionary] = []
	for pocket_index: int in range(WorldAmbientScenery2D.WILDERNESS_POCKETS.size()):
		var pocket: Vector4 = WorldAmbientScenery2D.WILDERNESS_POCKETS[pocket_index]
		var candidate: Vector2 = _find_clear_candidate_in_pocket(
			pocket,
			ambient_positions,
			ambient_radii,
			accent_positions,
			accent_radii
		)
		if candidate == Vector2.INF:
			continue
		patches.append({"pocket_index": pocket_index, "position": candidate})
		if patches.size() == PATCH_TARGET_COUNT:
			break
	return patches


func _find_clear_candidate_in_pocket(
	pocket: Vector4,
	ambient_positions: PackedVector2Array,
	ambient_radii: PackedFloat32Array,
	accent_positions: PackedVector2Array,
	accent_radii: PackedFloat32Array
) -> Vector2:
	for ring_index: int in range(SAMPLE_RING_COUNT):
		var radius_factor: float = 0.10 + float(ring_index) / float(SAMPLE_RING_COUNT - 1) * 0.74
		for spoke_index: int in range(SAMPLE_SPOKE_COUNT):
			var angle: float = fposmod(float(spoke_index) * 2.399963 + float(ring_index) * 0.37, TAU)
			var candidate: Vector2 = Vector2(pocket.x, pocket.y) + Vector2(
				cos(angle) * pocket.z * radius_factor,
				sin(angle) * pocket.w * radius_factor
			)
			if _is_render_clear_candidate(candidate, ambient_positions, ambient_radii, accent_positions, accent_radii):
				return candidate
	return Vector2.INF


func _is_render_clear_candidate(
	candidate: Vector2,
	ambient_positions: PackedVector2Array,
	ambient_radii: PackedFloat32Array,
	accent_positions: PackedVector2Array,
	accent_radii: PackedFloat32Array
) -> bool:
	if not candidate.is_finite():
		return false
	if not world_map.is_position_walkable(candidate, REQUIRED_CLEARANCE_RADIUS):
		return false
	if world_map.get_minimum_road_edge_distance(candidate) < REQUIRED_ROAD_CLEARANCE:
		return false
	for accent_index: int in range(accent_positions.size()):
		if candidate.distance_to(accent_positions[accent_index]) < accent_radii[accent_index] + REQUIRED_CLEARANCE_RADIUS:
			return false
	for ambient_index: int in range(ambient_positions.size()):
		if candidate.distance_to(ambient_positions[ambient_index]) < ambient_radii[ambient_index] + REQUIRED_CLEARANCE_RADIUS:
			return false
	return true


func _spawn_scale_references(initial_position: Vector2) -> bool:
	_player = NETWORK_PLAYER_SCENE.instantiate() as Node2D
	if _player == null:
		return false
	_player.call(&"configure", 1, &"heikki", initial_position + Vector2(-124.0, 44.0), false)
	y_sort_world.add_child(_player)
	_player.call(&"set_aim_direction", Vector2.RIGHT, false)
	var kinetic_definition: StructureDefinition = StructureCatalog.get_definition(StructureCatalog.T1_KINETIC)
	if kinetic_definition == null:
		return false
	_structure = PlacedStructure2D.new()
	_structure.configure(9003, kinetic_definition, 1, initial_position + Vector2(124.0, 44.0), false)
	y_sort_world.add_child(_structure)
	return true


func _capture_patch(
	patch_index: int,
	patch: Dictionary,
	phase: String,
	light_color: Color,
	prefix: String,
	captures: Array[Dictionary]
) -> Image:
	var patch_position: Vector2 = patch["position"] as Vector2
	if _player != null:
		_player.position = patch_position + Vector2(-124.0, 44.0)
	if _structure != null:
		_structure.position = patch_position + Vector2(124.0, 44.0)
	lighting.color = light_color
	camera.position = patch_position
	camera.zoom = Vector2.ONE * GAMEPLAY_CAMERA_ZOOM
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("empty viewport for macro patch %d %s %s" % [patch_index, prefix, phase])
		return null
	var logical_size: Vector2i = Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")),
		int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	)
	if image.get_size() != logical_size:
		image.resize(logical_size.x, logical_size.y, Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGBA8)
	var output_stem: String = "%s_%02d_%s" % [prefix, patch_index, phase]
	var output_path: String = "%s/%s.png" % [OUTPUT_DIRECTORY_PATH, output_stem]
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		_fail("could not save macro context image: %s" % error_string(save_error))
		return null
	var capture: Dictionary = {
		"prefix": prefix,
		"patch_index": patch_index,
		"pocket_index": patch["pocket_index"],
		"position": [patch_position.x, patch_position.y],
		"phase": phase,
		"output": output_path,
	}
	## Grayscale silhouette review is only needed once per phase; the measured
	## luma columns carry the rest of the evidence.
	if patch_index == 0:
		var grayscale_path: String = "%s/%s_grayscale.png" % [OUTPUT_DIRECTORY_PATH, output_stem]
		if not _save_grayscale(image, grayscale_path):
			return null
		capture["grayscale_output"] = grayscale_path
	captures.append(capture)
	return image


func _measure_against_baseline(
	baseline: Image,
	rendered: Image,
	patch_index: int,
	patch: Dictionary,
	phase: String,
	recipe: Dictionary
) -> Dictionary:
	## Two different questions get two different pixel sets, because conflating them
	## reverses the answer.  Coverage is "how many pixels moved at all", so it is
	## measured over the thresholded set.  Contrast is "is the accent lighter or
	## darker than the ground it covers", and that MUST be measured over a fixed
	## region: thresholding on change preferentially admits pixels where the accent
	## disagrees with the ground and silently drops the ones that match it, which
	## biases the luma delta toward whichever direction the accent differs in.
	var baseline_data: PackedByteArray = baseline.get_data()
	var rendered_data: PackedByteArray = rendered.get_data()
	var width: int = baseline.get_width()
	var pixel_count: int = width * baseline.get_height()
	if baseline_data.size() != rendered_data.size() or baseline_data.size() < pixel_count * 4:
		return {"error": "baseline and rendered capture sizes disagree"}
	var changed: int = 0
	var minimum_x: int = width
	var minimum_y: int = baseline.get_height()
	var maximum_x: int = -1
	var maximum_y: int = -1
	for pixel_index: int in range(pixel_count):
		var offset: int = pixel_index * 4
		var distance: int = (
			absi(baseline_data[offset] - rendered_data[offset])
			+ absi(baseline_data[offset + 1] - rendered_data[offset + 1])
			+ absi(baseline_data[offset + 2] - rendered_data[offset + 2])
		)
		if distance <= CHANGE_THRESHOLD:
			continue
		changed += 1
		var pixel_x: int = pixel_index % width
		var pixel_y: int = pixel_index / width
		minimum_x = mini(minimum_x, pixel_x)
		minimum_y = mini(minimum_y, pixel_y)
		maximum_x = maxi(maximum_x, pixel_x)
		maximum_y = maxi(maximum_y, pixel_y)
	if maximum_x < 0:
		return {
			"recipe": recipe["name"],
			"patch_index": patch_index,
			"pocket_index": patch["pocket_index"],
			"phase": phase,
			"changed_pixels": 0,
			"changed_fraction": 0.0,
			"footprint": [],
			"ground_luma": 0.0,
			"accent_luma": 0.0,
			"luma_delta": 0.0,
			"peak_accent_luma": 0.0,
			"peak_luma_delta": 0.0,
		}
	## The accent's own footprint, measured over every pixel inside it in both
	## captures - matched pixels included - so the delta is honest about dilution.
	var ground_total: float = 0.0
	var accent_total: float = 0.0
	var footprint_pixels: int = 0
	var peak_ground: float = 0.0
	var peak_accent: float = 0.0
	for pixel_y: int in range(minimum_y, maximum_y + 1):
		for pixel_x: int in range(minimum_x, maximum_x + 1):
			var offset: int = (pixel_y * width + pixel_x) * 4
			var ground_luma_value: float = (
				0.2126 * float(baseline_data[offset])
				+ 0.7152 * float(baseline_data[offset + 1])
				+ 0.0722 * float(baseline_data[offset + 2])
			)
			var accent_luma_value: float = (
				0.2126 * float(rendered_data[offset])
				+ 0.7152 * float(rendered_data[offset + 1])
				+ 0.0722 * float(rendered_data[offset + 2])
			)
			ground_total += ground_luma_value
			accent_total += accent_luma_value
			footprint_pixels += 1
			if accent_luma_value > peak_accent:
				peak_accent = accent_luma_value
				peak_ground = ground_luma_value
	var divisor: float = float(maxi(footprint_pixels, 1))
	var ground_luma: float = ground_total / divisor
	var accent_luma: float = accent_total / divisor
	return {
		"recipe": recipe["name"],
		"patch_index": patch_index,
		"pocket_index": patch["pocket_index"],
		"phase": phase,
		"changed_pixels": changed,
		"changed_fraction": float(changed) / float(pixel_count),
		"footprint": [minimum_x, minimum_y, maximum_x - minimum_x + 1, maximum_y - minimum_y + 1],
		"footprint_pixels": footprint_pixels,
		"ground_luma": snappedf(ground_luma, 0.001),
		"accent_luma": snappedf(accent_luma, 0.001),
		"luma_delta": snappedf(accent_luma - ground_luma, 0.001),
		"peak_accent_luma": snappedf(peak_accent, 0.001),
		"peak_luma_delta": snappedf(peak_accent - peak_ground, 0.001),
	}


func _summarise(measurements: Array[Dictionary]) -> Dictionary:
	var summary: Dictionary = {}
	for recipe: Dictionary in RECIPES:
		var name: String = recipe["name"] as String
		summary[name] = {}
		for phase: String in ["day", "night"]:
			var changed_total: int = 0
			var fraction_total: float = 0.0
			var ground_total: float = 0.0
			var accent_total: float = 0.0
			var peak_delta_total: float = 0.0
			var samples: int = 0
			for measurement: Dictionary in measurements:
				if measurement.get("recipe") != name or measurement.get("phase") != phase:
					continue
				changed_total += int(measurement["changed_pixels"])
				fraction_total += float(measurement["changed_fraction"])
				ground_total += float(measurement["ground_luma"])
				accent_total += float(measurement["accent_luma"])
				peak_delta_total += float(measurement["peak_luma_delta"])
				samples += 1
			var divisor: float = float(maxi(samples, 1))
			summary[name][phase] = {
				"samples": samples,
				"changed_pixels": changed_total,
				"changed_fraction": snappedf(fraction_total / divisor, 0.000001),
				"ground_luma": snappedf(ground_total / divisor, 0.001),
				"accent_luma": snappedf(accent_total / divisor, 0.001),
				"luma_delta": snappedf((accent_total - ground_total) / divisor, 0.001),
				"peak_luma_delta": snappedf(peak_delta_total / divisor, 0.001),
			}
	return summary


func _save_grayscale(source: Image, output_path: String) -> bool:
	var grayscale: Image = source.duplicate()
	grayscale.convert(Image.FORMAT_RGBA8)
	for pixel_y: int in range(grayscale.get_height()):
		for pixel_x: int in range(grayscale.get_width()):
			var color: Color = grayscale.get_pixel(pixel_x, pixel_y)
			var luma: float = color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			grayscale.set_pixel(pixel_x, pixel_y, Color(luma, luma, luma, color.a))
	var save_error: Error = grayscale.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		_fail("could not save grayscale macro context image: %s" % error_string(save_error))
		return false
	return true


func _write_metadata(
	patches: Array[Dictionary],
	captures: Array[Dictionary],
	measurements: Array[Dictionary],
	summary: Dictionary
) -> void:
	var recipe_metadata: Array[Dictionary] = []
	for recipe: Dictionary in RECIPES:
		var tint: Color = recipe["tint"] as Color
		recipe_metadata.append({
			"name": recipe["name"],
			"note": recipe["note"],
			"tint_rgba": [tint.r, tint.g, tint.b, tint.a],
		})
	var metadata: Dictionary = {
		"artifact_only": true,
		"runtime_promotion": "forbidden_pending_context_review",
		"macro_report": MACRO_REPORT_PATH,
		"macro_frame_paths": MACRO_FRAME_PATHS,
		"macro_frame_sha256": MACRO_FRAME_HASHES,
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"logical_size": [
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"),
		],
		"camera_zoom": GAMEPLAY_CAMERA_ZOOM,
		"frame_world_span": FRAME_WORLD_SPAN,
		"frame_card_logical_span": FRAME_WORLD_SPAN * GAMEPLAY_CAMERA_ZOOM,
		"frame_visual_radius": FRAME_VISUAL_RADIUS,
		"occlusion_margin": OCCLUSION_MARGIN,
		"required_clearance_radius": REQUIRED_CLEARANCE_RADIUS,
		"required_road_clearance": REQUIRED_ROAD_CLEARANCE,
		"layer_contract": "WorldMap2D child, absolute z=-5, linear mipmaps, shared sleek_canvas_grade",
		"texture_path_contract": (
			"Image.fix_alpha_edges() is applied before mipmap generation to match"
			+ " process/fix_alpha_border=true, which every runtime texture import in this"
			+ " project sets. This is a harness-fidelity correction, not a gate relaxation:"
			+ " without it the review minifies RGB=0 transparent pixels into the sprite and"
			+ " reports a darker accent than the shipping import path would produce."
		),
		"change_threshold_rgb_sum": CHANGE_THRESHOLD,
		"measurement_semantics": (
			"per patch and phase, the accent capture is differenced against its own"
			+ " baseline. changed_pixels counts pixels exceeding the RGB-sum threshold and"
			+ " answers coverage. ground_luma/accent_luma are averaged over every pixel in"
			+ " the accent footprint in both captures - unchanged pixels included - because"
			+ " averaging only the changed set biases the delta toward whichever direction"
			+ " the accent departs from the ground. peak_luma_delta reports the brightest"
			+ " accent pixel against the ground beneath it. All Rec.709 over 8-bit sRGB."
		),
		"fern_comparison": {
			"source": "artifacts/wild_salvage_trial/probes/fern_02_macro/context",
			"recipe": "subordinate",
			"day": {"changed_pixels": 478, "changed_fraction": 0.003688, "ground_luma": 68.7, "accent_luma": 52.7, "luma_delta": -16.0},
			"night": {"changed_pixels": 442, "changed_fraction": 0.003410, "ground_luma": 42.6, "accent_luma": 37.3, "luma_delta": -5.3},
			"verdict": "unreadable: under 0.4% coverage at negative contrast, effectively absent at night",
		},
		"recipes": recipe_metadata,
		"patch_count": patches.size(),
		"patches": patches,
		"capture_count": captures.size(),
		"captures": captures,
		"measurements": measurements,
		"summary": summary,
		"scale_references": ["baked_heikki", "t1_kinetic"],
		"night_lighting_limit": "Sapphire CanvasModulate proxy only; real flashlight and security-light behavior are not exercised",
		"acceptance_limit": (
			"This gate measures readability; it does not approve one. Choosing a recipe and a"
			+ " coverage/contrast floor is an art-direction decision that must be recorded"
			+ " in docs/overhaul/WILD_SALVAGE_TRIAL.md before any runtime promotion."
		),
	}
	var metadata_file: FileAccess = FileAccess.open(METADATA_OUTPUT_PATH, FileAccess.WRITE)
	if metadata_file == null:
		_fail("could not write macro context metadata")
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()


func _fail(message: String) -> void:
	push_error("GRASS MACRO CONTEXT FAILED: %s" % message)
	get_tree().quit(1)
