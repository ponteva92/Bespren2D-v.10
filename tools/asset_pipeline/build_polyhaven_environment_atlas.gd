extends SceneTree
## Deterministically packs reviewed Blender renders and writes provenance data.

const FRAME_SIZE: Vector2i = Vector2i(384, 384)
const ATLAS_COLUMNS: int = 4
const ATLAS_ROWS: int = 3
const REGION_PADDING: int = 6
const OUTPUT_DIRECTORY: String = "res://assets/2d/environment/polyhaven"
const ATLAS_PATH: String = OUTPUT_DIRECTORY + "/polyhaven_environment_atlas.png"
const MANIFEST_PATH: String = OUTPUT_DIRECTORY + "/polyhaven_asset_manifest.json"
const GENERATOR_PATH: String = "res://tools/asset_pipeline/build_polyhaven_environment_atlas.gd"
const BLENDER_RENDERER_PATH: String = "res://tools/art/render_polyhaven_environment_sprites.py"
const WORKSHOP_PATH: String = "res://tools/art/blender/bespren_map_asset_workshop.blend"
const LICENSE_PATH: String = "res://assets/licenses/polyhaven_cc0.md"

const FRAMES: Array[Dictionary] = [
	{&"key": "forest_stump", &"source_id": "tree_stump_01", &"file": "polyhaven_forest_stump_01.png"},
	{&"key": "forest_dead_trunk", &"source_id": "dead_tree_trunk", &"file": "polyhaven_forest_dead_trunk_01.png"},
	{&"key": "moss_rock_01", &"source_id": "rock_moss_set_01", &"file": "polyhaven_moss_rock_01.png"},
	{&"key": "moss_rock_02", &"source_id": "rock_moss_set_01", &"file": "polyhaven_moss_rock_02.png"},
	{&"key": "moss_rock_03", &"source_id": "rock_moss_set_01", &"file": "polyhaven_moss_rock_03.png"},
	{&"key": "moss_rock_04", &"source_id": "rock_moss_set_01", &"file": "polyhaven_moss_rock_04.png"},
	{&"key": "moss_rock_05", &"source_id": "rock_moss_set_01", &"file": "polyhaven_moss_rock_05.png"},
	{&"key": "moss_rock_06", &"source_id": "rock_moss_set_01", &"file": "polyhaven_moss_rock_06.png"},
	{&"key": "city_trash_clean", &"source_id": "metal_trash_can", &"file": "polyhaven_city_trash_can_clean_01.png"},
	{&"key": "city_trash_rust", &"source_id": "metal_trash_can", &"file": "polyhaven_city_trash_can_rust_01.png"},
	{&"key": "city_barrier", &"source_id": "concrete_road_barrier", &"file": "polyhaven_city_concrete_barrier_01.png"},
	{&"key": "city_tyre", &"source_id": "old_tyre", &"file": "polyhaven_city_old_tyre_01.png"},
]

const SOURCE_IDS: Array[String] = [
	"tree_stump_01",
	"dead_tree_trunk",
	"rock_moss_set_01",
	"metal_trash_can",
	"concrete_road_barrier",
	"old_tyre",
]


func _initialize() -> void:
	call_deferred(&"_build")


func _build() -> void:
	var atlas: Image = Image.create(
		FRAME_SIZE.x * ATLAS_COLUMNS,
		FRAME_SIZE.y * ATLAS_ROWS,
		false,
		Image.FORMAT_RGBA8
	)
	atlas.fill(Color(0.0, 0.0, 0.0, 0.0))
	var derived_assets: Array[Dictionary] = []
	for frame_index: int in range(FRAMES.size()):
		var definition: Dictionary = FRAMES[frame_index]
		var source_path: String = "%s/%s" % [OUTPUT_DIRECTORY, definition[&"file"]]
		var source_image: Image = Image.new()
		var load_error: Error = source_image.load(ProjectSettings.globalize_path(source_path))
		if load_error != OK:
			_fail("Cannot load %s: %s" % [source_path, error_string(load_error)])
			return
		if source_image.get_size() != FRAME_SIZE:
			_fail("%s must be exactly %s" % [source_path, FRAME_SIZE])
			return
		if source_image.get_format() != Image.FORMAT_RGBA8:
			source_image.convert(Image.FORMAT_RGBA8)
		var cell: Vector2i = Vector2i(frame_index % ATLAS_COLUMNS, frame_index / ATLAS_COLUMNS)
		var atlas_origin: Vector2i = cell * FRAME_SIZE
		atlas.blit_rect(source_image, Rect2i(Vector2i.ZERO, FRAME_SIZE), atlas_origin)
		var content_bounds: Rect2i = _alpha_content_bounds(source_image)
		if content_bounds.size == Vector2i.ZERO:
			_fail("%s contains no visible pixels" % source_path)
			return
		var padded_bounds: Rect2i = _grow_and_clamp(content_bounds, REGION_PADDING, FRAME_SIZE)
		var atlas_region: Rect2i = Rect2i(atlas_origin + padded_bounds.position, padded_bounds.size)
		derived_assets.append({
			"key": definition[&"key"],
			"source_id": definition[&"source_id"],
			"path": source_path,
			"bytes": _file_size(source_path),
			"sha256": _sha256(source_path),
			"cell_region": _rect_array(Rect2i(atlas_origin, FRAME_SIZE)),
			"content_bounds": _rect_array(content_bounds),
			"padded_atlas_region": _rect_array(atlas_region),
		})

	var save_error: Error = atlas.save_png(ProjectSettings.globalize_path(ATLAS_PATH))
	if save_error != OK:
		_fail("Cannot save atlas: %s" % error_string(save_error))
		return
	var source_assets: Array[Dictionary] = []
	for source_id: String in SOURCE_IDS:
		source_assets.append({
			"id": source_id,
			"type": "model",
			"resolution": "1k",
			"format": "gltf",
			"url": "https://polyhaven.com/a/%s" % source_id,
			"license": "CC0-1.0",
		})
	var manifest: Dictionary = {
		"schema_version": 1,
		"license": "CC0-1.0",
		"license_url": "https://polyhaven.com/license",
		"license_evidence": LICENSE_PATH,
		"source_assets": source_assets,
		"blender_version": "5.0.0",
		"render_policy": "orthographic_transparent_freestyle_agx_mobile_midtones",
		"blender_renderer": BLENDER_RENDERER_PATH,
		"blender_renderer_sha256": _sha256(BLENDER_RENDERER_PATH),
		"workshop": WORKSHOP_PATH,
		"workshop_bytes": _file_size(WORKSHOP_PATH),
		"workshop_sha256": _sha256(WORKSHOP_PATH),
		"atlas_generator": GENERATOR_PATH,
		"atlas_generator_sha256": _sha256(GENERATOR_PATH),
		"atlas": {
			"path": ATLAS_PATH,
			"size": [atlas.get_width(), atlas.get_height()],
			"bytes": _file_size(ATLAS_PATH),
			"sha256": _sha256(ATLAS_PATH),
			"layout": "4x3 deterministic frame order",
		},
		"derived_assets": derived_assets,
	}
	var manifest_file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if manifest_file == null:
		_fail("Cannot write %s" % MANIFEST_PATH)
		return
	manifest_file.store_string(JSON.stringify(manifest, "\t") + "\n")
	manifest_file.close()
	print("POLY HAVEN ATLAS OK | frames=%d | atlas=%dx%d" % [
		derived_assets.size(), atlas.get_width(), atlas.get_height()
	])
	quit(0)


func _alpha_content_bounds(image: Image) -> Rect2i:
	var minimum: Vector2i = image.get_size()
	var maximum: Vector2i = Vector2i(-1, -1)
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.003:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _grow_and_clamp(bounds: Rect2i, padding: int, frame_size: Vector2i) -> Rect2i:
	var position: Vector2i = Vector2i(
		maxi(bounds.position.x - padding, 0),
		maxi(bounds.position.y - padding, 0)
	)
	var end: Vector2i = Vector2i(
		mini(bounds.end.x + padding, frame_size.x),
		mini(bounds.end.y + padding, frame_size.y)
	)
	return Rect2i(position, end - position)


func _rect_array(rectangle: Rect2i) -> Array[int]:
	return [rectangle.position.x, rectangle.position.y, rectangle.size.x, rectangle.size.y]


func _sha256(resource_path: String) -> String:
	return FileAccess.get_sha256(ProjectSettings.globalize_path(resource_path))


func _file_size(resource_path: String) -> int:
	var file: FileAccess = FileAccess.open(resource_path, FileAccess.READ)
	if file == null:
		return -1
	var length: int = file.get_length()
	file.close()
	return length


func _fail(message: String) -> void:
	push_error("POLY HAVEN ATLAS FAILED | %s" % message)
	quit(1)
