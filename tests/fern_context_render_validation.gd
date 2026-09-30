extends Node2D
## Artifact-only gameplay-context gate for the conditional CC0 fern candidate.
##
## The probe frames stay below artifacts/ and are loaded through Image at test
## time. Nothing here is part of the runtime export closure; this gate exists
## solely to decide whether a reviewed mini-atlas is worth authoring later.

const NETWORK_PLAYER_SCENE: PackedScene = preload("res://scenes/characters/network_player.tscn")
const SLEEK_CANVAS_SHADER: Shader = preload("res://shaders/sleek_canvas_grade.gdshader")
const FERN_FRAME_PATHS: Array[String] = [
	"res://artifacts/wild_salvage_trial/probes/fern_02/polyhaven_wild/fern_0.png",
	"res://artifacts/wild_salvage_trial/probes/fern_02/polyhaven_wild/fern_1.png",
]
const FERN_FRAME_HASHES: Array[String] = [
	"a9887bbbbc9105cbb13ae6169ba5d97163cae4c889fdd7969cd7cc912a9acecb",
	"3a164c90f332303d936e773e7d84fc2272e5cf73c4891ebbd8ad36e5a4588f7d",
]
const DAY_OUTPUT_PATH: String = "res://artifacts/fern_02_context_v2_day_validation.png"
const NIGHT_OUTPUT_PATH: String = "res://artifacts/fern_02_context_v2_night_validation.png"
const METADATA_OUTPUT_PATH: String = "res://artifacts/fern_02_context_v2_validation.json"
const CONTEXT_POSITION: Vector2 = Vector2(-3300.0, -2600.0)
const GAMEPLAY_CAMERA_ZOOM: float = 0.38
## At the live camera this is 45.6 logical px for the whole card. The probe's
## 11-15% alpha coverage makes its largest actual frond group ~16-20px: a
## readable ground layer, not an obstacle or enemy silhouette.
const FERN_FRAME_WORLD_SPAN: float = 120.0
const FERN_FRAME_TINTS: Array[Color] = [
	Color(0.66, 0.74, 0.48, 0.66),
	Color(0.59, 0.67, 0.45, 0.46),
]
## One patch per selected wilderness pocket, rather than a conspicuous ring
## around the player. Positions are deliberately offset from deterministic
## accent anchors and remain artifact-only until a future promotion gate.
const FERN_PATCH_POSITIONS: Array[Vector2] = [
	Vector2(-5837.0, -2160.0),
	Vector2(-3548.0, -2446.0),
	Vector2(2521.0, -2002.0),
	Vector2(5678.0, -1952.0),
	Vector2(-5158.0, 1508.0),
	Vector2(-2825.0, 2866.0),
	Vector2(2477.0, 2508.0),
	Vector2(-3792.0, 6188.0),
]
const FERN_VARIANTS: Array[int] = [0, 1, 0, 1, 0, 1, 0, 0]
const FERN_ROTATIONS: Array[float] = [-0.18, 0.12, 0.07, -0.14, 0.19, -0.08, 0.15, -0.11]
const FERN_MIRRORS: Array[bool] = [false, true, true, false, false, true, false, true]

@onready var camera: Camera2D = %ValidationCamera
@onready var lighting: CanvasModulate = %ValidationLighting
@onready var y_sort_world: Node2D = $YSortWorld
@onready var world_map: Node2D = $YSortWorld/WorldMap2D


class FernArtifactLayer extends Node2D:
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
		frame_span: float,
	) -> bool:
		if (
			frame_paths.size() != frame_tints.size()
			or positions.size() != variants.size()
			or positions.size() != rotations.size()
			or positions.size() != mirrors.size()
			or positions.is_empty()
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
			var load_error: Error = image.load(ProjectSettings.globalize_path(frame_path))
			if load_error != OK or image.get_size() != Vector2i(256, 256):
				return false
			var mip_error: Error = image.generate_mipmaps()
			if mip_error != OK:
				return false
			var texture: ImageTexture = ImageTexture.create_from_image(image)
			if texture == null:
				return false
			_textures.append(texture)
		queue_redraw()
		return _textures.size() == frame_paths.size()

	func get_cluster_count() -> int:
		return _positions.size()

	func _draw() -> void:
		if _textures.is_empty() or _frame_span <= 0.0:
			return
		var frame_size: Vector2 = Vector2.ONE * _frame_span
		for cluster_index: int in range(_positions.size()):
			var variant: int = _variants[cluster_index]
			if variant < 0 or variant >= _textures.size():
				continue
			var mirror_scale: Vector2 = Vector2(-1.0, 1.0) if _mirrors[cluster_index] != 0 else Vector2.ONE
			draw_set_transform(_positions[cluster_index], _rotations[cluster_index], mirror_scale)
			draw_texture_rect(
				_textures[variant],
				Rect2(-frame_size * 0.5, frame_size),
				false,
				_tints[variant]
			)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ready() -> void:
	if not _verify_probe_frames():
		push_error("FERN CONTEXT FAILED: probe source hashes or dimensions changed")
		get_tree().quit(1)
		return
	_spawn_scale_references()
	var fern_layer: FernArtifactLayer = FernArtifactLayer.new()
	## Exercise the same WorldMap2D sibling/layer contract as a future
	## WildernessAccent recipe, rather than hiding the probe beside the map.
	world_map.add_child(fern_layer)
	var fern_positions: PackedVector2Array = PackedVector2Array()
	var fern_variants: PackedInt32Array = PackedInt32Array()
	var fern_rotations: PackedFloat32Array = PackedFloat32Array()
	var fern_mirrors: PackedByteArray = PackedByteArray()
	for patch_index: int in range(FERN_PATCH_POSITIONS.size()):
		fern_positions.append(FERN_PATCH_POSITIONS[patch_index])
		fern_variants.append(FERN_VARIANTS[patch_index])
		fern_rotations.append(FERN_ROTATIONS[patch_index])
		fern_mirrors.append(1 if FERN_MIRRORS[patch_index] else 0)
	if not fern_layer.configure(
		FERN_FRAME_PATHS,
		FERN_FRAME_TINTS,
		fern_positions,
		fern_variants,
		fern_rotations,
		fern_mirrors,
		FERN_FRAME_WORLD_SPAN
	):
		push_error("FERN CONTEXT FAILED: could not build artifact-only fern layer")
		get_tree().quit(1)
		return
	await get_tree().process_frame
	await _capture(CONTEXT_POSITION, Color.WHITE, DAY_OUTPUT_PATH)
	await _capture(CONTEXT_POSITION, NightAtmosphere2D.SAPPHIRE_NIGHT_COLOR, NIGHT_OUTPUT_PATH)
	_write_metadata(fern_layer.get_cluster_count())
	print("FERN CONTEXT OK | clusters=%d | captures=2" % fern_layer.get_cluster_count())
	get_tree().quit(0)


func _verify_probe_frames() -> bool:
	if FERN_FRAME_PATHS.size() != FERN_FRAME_HASHES.size():
		return false
	for frame_index: int in range(FERN_FRAME_PATHS.size()):
		var absolute_path: String = ProjectSettings.globalize_path(FERN_FRAME_PATHS[frame_index])
		if not FileAccess.file_exists(absolute_path):
			return false
		if FileAccess.get_sha256(absolute_path) != FERN_FRAME_HASHES[frame_index]:
			return false
		var image: Image = Image.new()
		if image.load(absolute_path) != OK or image.get_size() != Vector2i(256, 256):
			return false
	return true


func _spawn_scale_references() -> void:
	var player: Node2D = NETWORK_PLAYER_SCENE.instantiate() as Node2D
	if player == null:
		return
	player.call(
		&"configure",
		1,
		&"heikki",
		CONTEXT_POSITION + Vector2(-106.0, 38.0),
		false
	)
	y_sort_world.add_child(player)
	player.call(&"set_aim_direction", Vector2.RIGHT, false)
	var kinetic_definition: StructureDefinition = StructureCatalog.get_definition(StructureCatalog.T1_KINETIC)
	if kinetic_definition == null:
		return
	var structure: PlacedStructure2D = PlacedStructure2D.new()
	structure.configure(
		9002,
		kinetic_definition,
		1,
		CONTEXT_POSITION + Vector2(106.0, 38.0),
		false
	)
	y_sort_world.add_child(structure)


func _capture(camera_position: Vector2, light_color: Color, output_path: String) -> void:
	lighting.color = light_color
	camera.position = camera_position
	camera.zoom = Vector2.ONE * GAMEPLAY_CAMERA_ZOOM
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("FERN CONTEXT FAILED: empty viewport for %s" % output_path)
		get_tree().quit(1)
		return
	var logical_size: Vector2i = Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")),
		int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	)
	if image.get_size() != logical_size:
		image.resize(logical_size.x, logical_size.y, Image.INTERPOLATE_LANCZOS)
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		push_error("FERN CONTEXT FAILED: %s" % error_string(save_error))
		get_tree().quit(1)


func _write_metadata(cluster_count: int) -> void:
	var patch_positions: Array[Array] = []
	for patch_position: Vector2 in FERN_PATCH_POSITIONS:
		patch_positions.append([patch_position.x, patch_position.y])
	var metadata: Dictionary = {
		"artifact_only": true,
		"runtime_promotion": "forbidden_pending_context_review",
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"logical_size": [
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"),
		],
		"camera_position": [CONTEXT_POSITION.x, CONTEXT_POSITION.y],
		"camera_zoom": GAMEPLAY_CAMERA_ZOOM,
		"fern_frame_world_span": FERN_FRAME_WORLD_SPAN,
		"fern_frame_logical_span": FERN_FRAME_WORLD_SPAN * GAMEPLAY_CAMERA_ZOOM,
		"cluster_count": cluster_count,
		"patch_distribution": "eight selected wilderness pockets; one artifact-only patch per pocket",
		"patch_positions": patch_positions,
		"frame_tints": ["a8bd7aa8", "96ab7375"],
		"frame_paths": Array(FERN_FRAME_PATHS),
		"frame_sha256": Array(FERN_FRAME_HASHES),
		"outputs": [DAY_OUTPUT_PATH, NIGHT_OUTPUT_PATH],
		"scale_references": ["baked_heikki", "t1_kinetic"],
		"night_color": "sapphire_night",
	}
	var metadata_file: FileAccess = FileAccess.open(METADATA_OUTPUT_PATH, FileAccess.WRITE)
	if metadata_file == null:
		push_error("FERN CONTEXT FAILED: could not write metadata")
		get_tree().quit(1)
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()
