extends SceneTree
## Deterministically packs the reviewed Hidden Alley Poly Haven sprite family.

const FRAME_SIZE: Vector2i = Vector2i(384, 384)
const ATLAS_COLUMNS: int = 4
const ATLAS_ROWS: int = 2
const REGION_PADDING: int = 6
const MINIMUM_FRAME_MARGIN: int = 8
const MINIMUM_ALPHA_WEIGHTED_LUMA: float = 50.0
const OUTPUT_DIRECTORY: String = "res://assets/2d/environment/polyhaven_district"
const ATLAS_PATH: String = OUTPUT_DIRECTORY + "/polyhaven_district_atlas.png"
const MANIFEST_PATH: String = OUTPUT_DIRECTORY + "/polyhaven_district_manifest.json"
const GENERATOR_PATH: String = "res://tools/asset_pipeline/build_polyhaven_district_atlas.gd"
const BLENDER_RENDERER_PATH: String = "res://tools/art/render_polyhaven_district_sprites.py"
const WORKSHOP_PATH: String = "res://tools/art/blender/bespren_polyhaven_district_workshop.blend"
const LICENSE_PATH: String = "res://assets/licenses/polyhaven_cc0.md"

const FRAMES: Array[Dictionary] = [
	{&"key": "urban_apartment_block", &"source_id": "modular_urban_apartments_facade", &"file": "polyhaven_district_urban_apartment_block.png"},
	{&"key": "factory_block", &"source_id": "modular_factory_facade", &"file": "polyhaven_district_factory_block.png"},
	{&"key": "chainlink_gate", &"source_id": "modular_chainlink_fence", &"file": "polyhaven_district_chainlink_gate.png"},
	{&"key": "covered_car", &"source_id": "covered_car", &"file": "polyhaven_district_covered_car.png"},
	{&"key": "aircon_cluster", &"source_id": "exterior_aircon_unit", &"file": "polyhaven_district_aircon_cluster.png"},
	{&"key": "street_bench", &"source_id": "modular_street_seating", &"file": "polyhaven_district_street_bench.png"},
	{&"key": "aged_fire_hydrant", &"source_id": "fire_hydrant", &"file": "polyhaven_district_aged_fire_hydrant.png"},
	{&"key": "barrel_stove", &"source_id": "barrel_stove", &"file": "polyhaven_district_barrel_stove.png"},
]

const SOURCE_IDS: Array[String] = [
	"modular_urban_apartments_facade",
	"modular_factory_facade",
	"modular_chainlink_fence",
	"covered_car",
	"exterior_aircon_unit",
	"modular_street_seating",
	"fire_hydrant",
	"barrel_stove",
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
		var content_bounds: Rect2i = _alpha_content_bounds(source_image)
		if content_bounds.size == Vector2i.ZERO:
			_fail("%s contains no visible pixels" % source_path)
			return
		if not _has_safe_margin(content_bounds):
			_fail("%s touches the protected %d-pixel frame margin: %s" % [
				source_path, MINIMUM_FRAME_MARGIN, content_bounds
			])
			return
		var weighted_luma: float = _alpha_weighted_luma(source_image)
		if weighted_luma < MINIMUM_ALPHA_WEIGHTED_LUMA:
			_fail("%s alpha-weighted luma %.2f is below %.2f" % [
				source_path, weighted_luma, MINIMUM_ALPHA_WEIGHTED_LUMA
			])
			return
		var cell: Vector2i = Vector2i(frame_index % ATLAS_COLUMNS, frame_index / ATLAS_COLUMNS)
		var atlas_origin: Vector2i = cell * FRAME_SIZE
		atlas.blit_rect(source_image, Rect2i(Vector2i.ZERO, FRAME_SIZE), atlas_origin)
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
			"edge_margin_px": _edge_margin(content_bounds),
			"visible_pixel_count": _visible_pixel_count(source_image),
			"alpha_coverage": snappedf(_alpha_coverage(source_image), 0.000001),
			"alpha_weighted_luma": snappedf(weighted_luma, 0.001),
			"alpha_weighted_luma_255": snappedf(weighted_luma, 0.001),
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
		"family": "hidden_alley_district",
		"license": "CC0-1.0",
		"license_url": "https://polyhaven.com/license",
		"license_evidence": LICENSE_PATH,
		"source_assets": source_assets,
		"blender_version": "5.0.0",
		"render_policy": "orthographic_transparent_freestyle_agx_hidden_alley_mobile_midtones",
		"runtime_policy": "offline_baked_2d_atlas_only_no_runtime_mesh_or_node3d",
		"quality_gates": {
			"minimum_frame_margin": MINIMUM_FRAME_MARGIN,
			"minimum_alpha_weighted_luma_255": MINIMUM_ALPHA_WEIGHTED_LUMA,
		},
		"blender_renderer": BLENDER_RENDERER_PATH,
		"blender_renderer_bytes": _file_size(BLENDER_RENDERER_PATH),
		"blender_renderer_sha256": _sha256(BLENDER_RENDERER_PATH),
		"workshop": WORKSHOP_PATH,
		"workshop_bytes": _file_size(WORKSHOP_PATH),
		"workshop_sha256": _sha256(WORKSHOP_PATH),
		"atlas_generator": GENERATOR_PATH,
		"atlas_generator_bytes": _file_size(GENERATOR_PATH),
		"atlas_generator_sha256": _sha256(GENERATOR_PATH),
		"atlas": {
			"path": ATLAS_PATH,
			"size": [atlas.get_width(), atlas.get_height()],
			"bytes": _file_size(ATLAS_PATH),
			"sha256": _sha256(ATLAS_PATH),
			"layout": "4x2 deterministic frame order; 8 occupied cells",
		},
		"derived_assets": derived_assets,
	}
	var manifest_file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if manifest_file == null:
		_fail("Cannot write %s" % MANIFEST_PATH)
		return
	manifest_file.store_string(JSON.stringify(manifest, "\t") + "\n")
	manifest_file.close()
	print("POLY HAVEN DISTRICT ATLAS OK | frames=%d | atlas=%dx%d" % [
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


func _has_safe_margin(bounds: Rect2i) -> bool:
	return (
		bounds.position.x >= MINIMUM_FRAME_MARGIN
		and bounds.position.y >= MINIMUM_FRAME_MARGIN
		and bounds.end.x <= FRAME_SIZE.x - MINIMUM_FRAME_MARGIN
		and bounds.end.y <= FRAME_SIZE.y - MINIMUM_FRAME_MARGIN
	)


func _edge_margin(bounds: Rect2i) -> int:
	return mini(
		mini(bounds.position.x, bounds.position.y),
		mini(FRAME_SIZE.x - bounds.end.x, FRAME_SIZE.y - bounds.end.y)
	)


func _visible_pixel_count(image: Image) -> int:
	var count: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.003:
				count += 1
	return count


func _alpha_weighted_luma(image: Image) -> float:
	var weighted_luma: float = 0.0
	var alpha_sum: float = 0.0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a <= 0.003:
				continue
			weighted_luma += (
				pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
			) * pixel.a
			alpha_sum += pixel.a
	return 0.0 if alpha_sum <= 0.0 else weighted_luma * 255.0 / alpha_sum


func _alpha_coverage(image: Image) -> float:
	var alpha_sum: float = 0.0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			alpha_sum += image.get_pixel(x, y).a
	return alpha_sum / float(image.get_width() * image.get_height())


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
	push_error("POLY HAVEN DISTRICT ATLAS FAILED | %s" % message)
	quit(1)
