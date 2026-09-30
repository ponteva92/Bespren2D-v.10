extends SceneTree
## Deterministically packs local Blender bakes and records exact provenance.

const FRAME_SIZE := Vector2i(384, 384)
const ATLAS_COLUMNS := 4
const ATLAS_ROWS := 4
const REGION_PADDING := 6
const OUTPUT_DIRECTORY := "res://assets/2d/environment/local_baked"
const ATLAS_PATH := OUTPUT_DIRECTORY + "/local_environment_atlas.png"
const MANIFEST_PATH := OUTPUT_DIRECTORY + "/local_environment_manifest.json"
const GENERATOR_PATH := "res://tools/asset_pipeline/build_local_environment_atlas.gd"
const BLENDER_RENDERER_PATH := "res://tools/art/render_local_environment_sprites.py"
const WORKSHOP_PATH := "res://tools/art/blender/bespren_local_environment_workshop.blend"
const LICENSE_PATH := "res://assets/licenses/local_baked_environment_sources.md"
const LICENSE_SOURCES: Array[Dictionary] = [
	{"family": "kenney_city_builder_models", "path": "res://Addons/Starter-Kit-City-Builder-main/Starter-Kit-City-Builder-main/LICENSE.md", "terms": "package MIT; models explicitly CC0 in README"},
	{"family": "kenney_city_builder_models", "path": "res://Addons/Starter-Kit-City-Builder-main/Starter-Kit-City-Builder-main/README.md", "terms": "included 3D models marked CC0"},
	{"family": "atomic_realm_post_apocalyptic", "path": "res://Addons/[AR] Post-Apocalyptic - Starter Pack/2. License.png", "terms": "commercial editing/use allowed; repackaging, resale and redistribution forbidden"},
	{"family": "atomic_realm_into_the_wild", "path": "res://Addons/[FREE] Into The Wild/2. License.png", "terms": "commercial editing/use allowed; repackaging, resale and redistribution forbidden"},
	{"family": "atomic_realm_gas_station", "path": "res://Addons/[FREE] Gas Station/2. License.png", "terms": "commercial editing/use allowed; repackaging, resale and redistribution forbidden"},
	{"family": "atomic_realm_pharmacy", "path": "res://Addons/[FREE] Pharmacy/2. License.png", "terms": "commercial editing/use allowed; repackaging, resale and redistribution forbidden"},
]

const FRAMES: Array[Dictionary] = [
	{&"key": "city_ruin_a", &"file": "local_city_ruin_a.png", &"family": "kenney_cc0+atomic_restricted"},
	{&"key": "city_ruin_b", &"file": "local_city_ruin_b.png", &"family": "kenney_cc0+atomic_restricted"},
	{&"key": "city_ruin_c", &"file": "local_city_ruin_c.png", &"family": "kenney_cc0+atomic_restricted"},
	{&"key": "city_ruin_d", &"file": "local_city_ruin_d.png", &"family": "kenney_cc0+atomic_restricted"},
	{&"key": "mall_shell", &"file": "local_mall_shell.png", &"family": "kenney_cc0+atomic_restricted"},
	{&"key": "industrial_shell", &"file": "local_industrial_shell.png", &"family": "kenney_cc0+atomic_restricted"},
	{&"key": "village_west_house", &"file": "local_village_west_house.png", &"family": "kenney_cc0+atomic_restricted"},
	{&"key": "village_east_house", &"file": "local_village_east_house.png", &"family": "kenney_cc0+atomic_restricted"},
	{&"key": "vehicle_wreck", &"file": "local_vehicle_wreck.png", &"family": "atomic_restricted"},
	{&"key": "wood_barricade", &"file": "local_wood_barricade.png", &"family": "atomic_restricted"},
	{&"key": "utility_pole", &"file": "local_utility_pole.png", &"family": "atomic_restricted"},
	{&"key": "roadside_salvage", &"file": "local_roadside_salvage.png", &"family": "atomic_restricted"},
	{&"key": "roadside_barrier", &"file": "local_roadside_barrier.png", &"family": "atomic_restricted"},
	{&"key": "camp_bedding", &"file": "local_camp_bedding.png", &"family": "atomic_into_the_wild_restricted"},
	{&"key": "camp_supply_cache", &"file": "local_camp_supply_cache.png", &"family": "atomic_gas_station_restricted"},
	{&"key": "camp_medical_cache", &"file": "local_camp_medical_cache.png", &"family": "atomic_pharmacy+into_the_wild_restricted"},
]

const SOURCE_FILES: Array[String] = [
	"res://Addons/Starter-Kit-City-Builder-main/Starter-Kit-City-Builder-main/models/building-small-a.glb",
	"res://Addons/Starter-Kit-City-Builder-main/Starter-Kit-City-Builder-main/models/building-small-b.glb",
	"res://Addons/Starter-Kit-City-Builder-main/Starter-Kit-City-Builder-main/models/building-small-c.glb",
	"res://Addons/Starter-Kit-City-Builder-main/Starter-Kit-City-Builder-main/models/building-small-d.glb",
	"res://Addons/Starter-Kit-City-Builder-main/Starter-Kit-City-Builder-main/models/building-garage.glb",
	"res://Addons/[AR] Post-Apocalyptic - Starter Pack/3. Models/gltf/metal_board_1.glb",
	"res://Addons/[AR] Post-Apocalyptic - Starter Pack/3. Models/gltf/metal_board_2.glb",
	"res://Addons/[AR] Post-Apocalyptic - Starter Pack/3. Models/gltf/metal_board_3.glb",
	"res://Addons/[AR] Post-Apocalyptic - Starter Pack/3. Models/gltf/wall_1_hole.glb",
	"res://Addons/[AR] Post-Apocalyptic - Starter Pack/3. Models/gltf/wall_1_door_boarded.glb",
	"res://Addons/[AR] Post-Apocalyptic - Starter Pack/3. Models/gltf/wall_1_window_2.glb",
	"res://Addons/[AR] Post-Apocalyptic - Starter Pack/3. Models/gltf/wall_1_brick.glb",
	"res://Addons/[AR] Post-Apocalyptic - Starter Pack/3. Models/gltf/wall_concrete_metal.glb",
	"res://Addons/[AR] Post-Apocalyptic - Starter Pack/3. Models/gltf/wall_spiked.glb",
	"res://Addons/[AR] Post-Apocalyptic - Starter Pack/3. Models/gltf/wall_metal_1.glb",
	"res://Addons/[AR] Post-Apocalyptic - Starter Pack/3. Models/gltf/wooden_wall.glb",
	"res://Addons/[AR] Post-Apocalyptic - Starter Pack/3. Models/gltf/wooden_spike_barricade.glb",
	"res://Addons/[AR] Post-Apocalyptic - Starter Pack/3. Models/gltf/car.glb",
	"res://Addons/[AR] Post-Apocalyptic - Starter Pack/3. Models/gltf/tire.glb",
	"res://Addons/[AR] Post-Apocalyptic - Starter Pack/3. Models/gltf/electric_pole_1.glb",
	"res://Addons/[AR] Post-Apocalyptic - Starter Pack/3. Models/gltf/barrel.glb",
	"res://Addons/[AR] Post-Apocalyptic - Starter Pack/3. Models/gltf/box_1.glb",
	"res://Addons/[AR] Post-Apocalyptic - Starter Pack/3. Models/gltf/wheel.glb",
	"res://Addons/[FREE] Into The Wild/FREE/gltf/sleeping_bag.glb",
	"res://Addons/[FREE] Into The Wild/FREE/gltf/sharpened_stick.glb",
	"res://Addons/[FREE] Into The Wild/FREE/gltf/bush_1.glb",
	"res://Addons/[FREE] Gas Station/FREE/gltf/pallet_cluster_1.glb",
	"res://Addons/[FREE] Gas Station/FREE/gltf/jerry_can_with_nozzle.glb",
	"res://Addons/[FREE] Pharmacy/FREE/gltf/medpack_1.glb",
]


func _initialize() -> void:
	call_deferred(&"_build")


func _build() -> void:
	var atlas := Image.create(FRAME_SIZE.x * ATLAS_COLUMNS, FRAME_SIZE.y * ATLAS_ROWS, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var derived_assets: Array[Dictionary] = []
	for frame_index: int in range(FRAMES.size()):
		var definition := FRAMES[frame_index]
		var source_path: String = "%s/%s" % [OUTPUT_DIRECTORY, definition[&"file"]]
		var image := Image.new()
		var error := image.load(ProjectSettings.globalize_path(source_path))
		if error != OK:
			_fail("Cannot load %s: %s" % [source_path, error_string(error)])
			return
		if image.get_size() != FRAME_SIZE:
			_fail("%s must be exactly %s" % [source_path, FRAME_SIZE])
			return
		if image.get_format() != Image.FORMAT_RGBA8:
			image.convert(Image.FORMAT_RGBA8)
		var cell := Vector2i(frame_index % ATLAS_COLUMNS, frame_index / ATLAS_COLUMNS)
		var origin := cell * FRAME_SIZE
		atlas.blit_rect(image, Rect2i(Vector2i.ZERO, FRAME_SIZE), origin)
		var content_bounds := _alpha_content_bounds(image)
		if content_bounds.size == Vector2i.ZERO:
			_fail("%s contains no visible pixels" % source_path)
			return
		var padded_bounds := _grow_and_clamp(content_bounds, REGION_PADDING, FRAME_SIZE)
		derived_assets.append({
			"key": definition[&"key"],
			"license_family": definition[&"family"],
			"path": source_path,
			"bytes": _file_size(source_path),
			"sha256": _sha256(source_path),
			"cell_region": _rect_array(Rect2i(origin, FRAME_SIZE)),
			"content_bounds": _rect_array(content_bounds),
			"padded_atlas_region": _rect_array(Rect2i(origin + padded_bounds.position, padded_bounds.size)),
			"alpha_coverage": _alpha_coverage(image),
			"alpha_weighted_luma": _alpha_weighted_luma(image),
		})
	var save_error := atlas.save_png(ProjectSettings.globalize_path(ATLAS_PATH))
	if save_error != OK:
		_fail("Cannot save atlas: %s" % error_string(save_error))
		return
	var source_assets: Array[Dictionary] = []
	for source_path: String in SOURCE_FILES:
		if not FileAccess.file_exists(source_path):
			_fail("Missing declared source: %s" % source_path)
			return
		var family := _license_family_for_source(source_path)
		source_assets.append({"path": source_path, "license_family": family, "bytes": _file_size(source_path), "sha256": _sha256(source_path)})
	var license_sources: Array[Dictionary] = []
	for definition: Dictionary in LICENSE_SOURCES:
		var evidence_path: String = definition["path"]
		if not FileAccess.file_exists(evidence_path):
			_fail("Missing license evidence: %s" % evidence_path)
			return
		license_sources.append({
			"family": definition["family"],
			"path": evidence_path,
			"terms": definition["terms"],
			"bytes": _file_size(evidence_path),
			"sha256": _sha256(evidence_path),
		})
	var manifest := {
		"schema_version": 1,
		"usage": "derived sprites embedded in Bespren; never redistribute source GLBs or derived Atomic Realm assets as an asset pack",
		"license_evidence": LICENSE_PATH,
		"license_sources": license_sources,
		"source_assets": source_assets,
		"blender_version": "5.0.0",
		"render_policy": "orthographic_rgba_freestyle_agx_mobile_midtones_runtime_grounding",
		"blender_renderer": BLENDER_RENDERER_PATH,
		"blender_renderer_sha256": _sha256(BLENDER_RENDERER_PATH),
		"workshop": WORKSHOP_PATH,
		"workshop_bytes": _file_size(WORKSHOP_PATH),
		"workshop_sha256": _sha256(WORKSHOP_PATH),
		"atlas_generator": GENERATOR_PATH,
		"atlas_generator_sha256": _sha256(GENERATOR_PATH),
		"atlas": {"path": ATLAS_PATH, "size": [atlas.get_width(), atlas.get_height()], "bytes": _file_size(ATLAS_PATH), "sha256": _sha256(ATLAS_PATH), "layout": "4x4 deterministic frame order; 16 occupied cells"},
		"derived_assets": derived_assets,
	}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		_fail("Cannot write %s" % MANIFEST_PATH)
		return
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file.close()
	print("LOCAL ENVIRONMENT ATLAS OK | frames=%d | atlas=%dx%d" % [derived_assets.size(), atlas.get_width(), atlas.get_height()])
	quit(0)


func _license_family_for_source(source_path: String) -> String:
	if "/[AR] Post-Apocalyptic" in source_path:
		return "atomic_realm_post_apocalyptic"
	if "/[FREE] Into The Wild" in source_path:
		return "atomic_realm_into_the_wild"
	if "/[FREE] Gas Station" in source_path:
		return "atomic_realm_gas_station"
	if "/[FREE] Pharmacy" in source_path:
		return "atomic_realm_pharmacy"
	return "kenney_city_builder_models"


func _alpha_content_bounds(image: Image) -> Rect2i:
	var minimum := image.get_size()
	var maximum := Vector2i(-1, -1)
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.003:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _grow_and_clamp(bounds: Rect2i, padding: int, frame_size: Vector2i) -> Rect2i:
	var position := Vector2i(maxi(bounds.position.x - padding, 0), maxi(bounds.position.y - padding, 0))
	var end := Vector2i(mini(bounds.end.x + padding, frame_size.x), mini(bounds.end.y + padding, frame_size.y))
	return Rect2i(position, end - position)


func _alpha_coverage(image: Image) -> float:
	var visible := 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.003:
				visible += 1
	return float(visible) / float(image.get_width() * image.get_height())


func _alpha_weighted_luma(image: Image) -> float:
	var weighted := 0.0
	var alpha_sum := 0.0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			weighted += (pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722) * pixel.a
			alpha_sum += pixel.a
	return weighted / maxf(alpha_sum, 0.0001) * 255.0


func _rect_array(rectangle: Rect2i) -> Array[int]:
	return [rectangle.position.x, rectangle.position.y, rectangle.size.x, rectangle.size.y]


func _sha256(resource_path: String) -> String:
	return FileAccess.get_sha256(ProjectSettings.globalize_path(resource_path))


func _file_size(resource_path: String) -> int:
	var file := FileAccess.open(resource_path, FileAccess.READ)
	if file == null:
		return -1
	var length := file.get_length()
	file.close()
	return length


func _fail(message: String) -> void:
	push_error("LOCAL ENVIRONMENT ATLAS FAILED | %s" % message)
	quit(1)
