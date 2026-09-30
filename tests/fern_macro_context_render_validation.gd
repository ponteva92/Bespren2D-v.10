extends Node2D
## Artifact-only gameplay-context review for the two Fern 02 macro probes.
##
## This deliberately loads ImageTextures from the ignored trial vault, pins both
## frame hashes, and adds a transient z=-5 child beneath the actual WorldMap
## tree.  Nothing here is an atlas, scene dependency, physics object, flow-mask
## input, or export-closure resource.  The gate answers one narrow question:
## can the reviewed macro silhouettes read as subordinate ground flora at the
## live 480x270 / 0.38 camera when they are not hidden by existing scenery?

const NETWORK_PLAYER_SCENE: PackedScene = preload("res://scenes/characters/network_player.tscn")
const SLEEK_CANVAS_SHADER: Shader = preload("res://shaders/sleek_canvas_grade.gdshader")
const MACRO_REPORT_PATH: String = "res://artifacts/wild_salvage_trial/probes/fern_02_macro/fern_macro_render_report.json"
const MACRO_OUTPUT_DIRECTORY: String = "res://artifacts/wild_salvage_trial/probes/fern_02_macro/polyhaven_wild"
const MACRO_FRAME_PATHS: Array[String] = [
	"res://artifacts/wild_salvage_trial/probes/fern_02_macro/polyhaven_wild/fern_macro_0.png",
	"res://artifacts/wild_salvage_trial/probes/fern_02_macro/polyhaven_wild/fern_macro_1.png",
]
const MACRO_FRAME_HASHES: Array[String] = [
	"87b057ca9575176b06cb7d7d7831fd974c230cdab9dcbbc4df3969ecccb8e600",
	"269f543ee62ab03b5cac1f3c3a8765b5e6a3d44efc750b9245f2a073c95e7ad7",
]
const OUTPUT_DIRECTORY_PATH: String = "res://artifacts/wild_salvage_trial/probes/fern_02_macro/context"
const METADATA_OUTPUT_PATH: String = "res://artifacts/wild_salvage_trial/probes/fern_02_macro/fern_macro_context_validation.json"
const GAMEPLAY_CAMERA_ZOOM: float = 0.38
const FRAME_WORLD_SPAN: float = 128.0
const FRAME_VISUAL_RADIUS: float = FRAME_WORLD_SPAN * 0.70710678
const OCCLUSION_MARGIN: float = 32.0
const REQUIRED_CLEARANCE_RADIUS: float = FRAME_VISUAL_RADIUS + OCCLUSION_MARGIN
const REQUIRED_ROAD_CLEARANCE: float = 480.0
const PATCH_TARGET_COUNT: int = 8
const SAMPLE_RING_COUNT: int = 13
const SAMPLE_SPOKE_COUNT: int = 24
const BASELINE_PREFIX: String = "baseline"
const MACRO_PREFIX: String = "macro"
const FRAME_TINTS: Array[Color] = [
	Color(0.66, 0.74, 0.48, 0.66),
	Color(0.59, 0.67, 0.45, 0.46),
]

@onready var camera: Camera2D = %ValidationCamera
@onready var lighting: CanvasModulate = %ValidationLighting
@onready var y_sort_world: Node2D = $YSortWorld
@onready var world_map: BesprenWorldMap2D = $YSortWorld/WorldMap2D as BesprenWorldMap2D

var _player: Node2D
var _structure: PlacedStructure2D


class FernMacroArtifactLayer extends Node2D:
	var _textures: Array[Texture2D] = []
	var _tints: Array[Color] = []
	var _positions: PackedVector2Array = PackedVector2Array()
	var _variants: PackedInt32Array = PackedInt32Array()
	var _rotations: PackedFloat32Array = PackedFloat32Array()
	var _mirrors: PackedByteArray = PackedByteArray()
	var _frame_span: float = 0.0

	func configure(
		frame_paths: Array[String],
		frame_tints: Array[Color],
		positions: PackedVector2Array,
		variants: PackedInt32Array,
		rotations: PackedFloat32Array,
		mirrors: PackedByteArray,
		frame_span: float
	) -> bool:
		if (
			frame_paths.size() != frame_tints.size()
			or positions.size() != variants.size()
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
		_tints = frame_tints.duplicate()
		_positions = positions.duplicate()
		_variants = variants.duplicate()
		_rotations = rotations.duplicate()
		_mirrors = mirrors.duplicate()
		_frame_span = frame_span
		for frame_path: String in frame_paths:
			var image: Image = Image.new()
			if image.load(ProjectSettings.globalize_path(frame_path)) != OK:
				return false
			if image.get_size() != Vector2i(256, 256) or image.generate_mipmaps() != OK:
				return false
			var texture: ImageTexture = ImageTexture.create_from_image(image)
			if texture == null:
				return false
			_textures.append(texture)
		queue_redraw()
		return _textures.size() == frame_paths.size()

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
				_tints[variant]
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
	var layer: FernMacroArtifactLayer = FernMacroArtifactLayer.new()
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
		FRAME_TINTS,
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
	layer.visible = false
	if not await _capture_patch(0, patches[0], "day", Color.WHITE, BASELINE_PREFIX, captures):
		return
	if not await _capture_patch(0, patches[0], "night", NightAtmosphere2D.SAPPHIRE_NIGHT_COLOR, BASELINE_PREFIX, captures):
		return
	layer.visible = true
	for patch_index: int in range(patches.size()):
		if not await _capture_patch(patch_index, patches[patch_index], "day", Color.WHITE, MACRO_PREFIX, captures):
			return
		if not await _capture_patch(
			patch_index,
			patches[patch_index],
			"night",
			NightAtmosphere2D.SAPPHIRE_NIGHT_COLOR,
			MACRO_PREFIX,
			captures
		):
			return
	_write_metadata(patches, captures)
	print("FERN MACRO CONTEXT OK | patches=%d | captures=%d | grayscale=%d" % [
		patches.size(), captures.size(), captures.size(),
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
		or report.get("runtime_promotion") != "forbidden_pending_macro_context_review"
		or report.get("errors") != []
		or report.get("output_directory") != "artifacts/wild_salvage_trial/probes/fern_02_macro/polyhaven_wild"
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
		if "fern_02_macro" in closure_text or "wild_salvage_trial" in closure_text:
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
) -> bool:
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
		_fail("empty viewport for macro patch %d %s" % [patch_index, phase])
		return false
	var logical_size: Vector2i = Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")),
		int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	)
	if image.get_size() != logical_size:
		image.resize(logical_size.x, logical_size.y, Image.INTERPOLATE_LANCZOS)
	var output_stem: String = "%s_%02d_%s" % [prefix, patch_index, phase]
	var output_path: String = "%s/%s.png" % [OUTPUT_DIRECTORY_PATH, output_stem]
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		_fail("could not save macro context image: %s" % error_string(save_error))
		return false
	var grayscale_path: String = "%s/%s_grayscale.png" % [OUTPUT_DIRECTORY_PATH, output_stem]
	if not _save_grayscale(image, grayscale_path):
		return false
	captures.append({
		"prefix": prefix,
		"patch_index": patch_index,
		"pocket_index": patch["pocket_index"],
		"position": [patch_position.x, patch_position.y],
		"phase": phase,
		"output": output_path,
		"grayscale_output": grayscale_path,
	})
	return true


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


func _write_metadata(patches: Array[Dictionary], captures: Array[Dictionary]) -> void:
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
		"patch_count": patches.size(),
		"patches": patches,
		"capture_count": captures.size(),
		"captures": captures,
		"scale_references": ["baked_heikki", "t1_kinetic"],
		"night_lighting_limit": "Sapphire CanvasModulate proxy only; real flashlight and security-light behavior are not exercised",
	}
	var metadata_file: FileAccess = FileAccess.open(METADATA_OUTPUT_PATH, FileAccess.WRITE)
	if metadata_file == null:
		_fail("could not write macro context metadata")
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()


func _fail(message: String) -> void:
	push_error("FERN MACRO CONTEXT FAILED: %s" % message)
	get_tree().quit(1)
