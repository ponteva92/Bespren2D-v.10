extends SceneTree
## Focused provenance, mobile-rendering, and authored-biome gate.

const WORLD_MAP_SCENE: PackedScene = preload("res://scenes/world/world_map_2d.tscn")
const MANIFEST_PATH: String = "res://assets/2d/environment/terrain/polyhaven_terrain_manifest.json"
const ATLAS_PATH: String = "res://assets/2d/environment/terrain/polyhaven_terrain_atlas.png"
const MASK_PATH: String = "res://assets/2d/environment/terrain/bespren_biome_blend_mask.png"
const SHADER_PATH: String = "res://shaders/terrain_material_blend.gdshader"
const WORKSHOP_PATH: String = "res://tools/art/blender/bespren_terrain_material_workshop.blend"
const GENERATOR_PATH: String = "res://tools/art/bake_polyhaven_terrain_materials.py"
const LICENSE_PATH: String = "res://assets/licenses/polyhaven_cc0.md"
const EXPECTED_IDS: PackedStringArray = [
	"aerial_asphalt_01",
	"muddy_tracks",
	"forest_leaves_02",
	"concrete_pavement_03",
]

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var manifest: Dictionary = _load_manifest()
	if manifest.is_empty():
		_finish()
		return
	_validate_manifest(manifest)
	_validate_images(manifest)
	var world_map: BesprenWorldMap2D = WORLD_MAP_SCENE.instantiate() as BesprenWorldMap2D
	_check(world_map != null, "World map instantiates with the terrain material overlay")
	if world_map != null:
		root.add_child(world_map)
		await process_frame
		world_map.ensure_built()
		_validate_runtime(world_map)
		world_map.queue_free()
		await process_frame
	_finish()


func _load_manifest() -> Dictionary:
	_check(FileAccess.file_exists(MANIFEST_PATH), "Poly Haven terrain manifest exists")
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	_check(file != null, "Poly Haven terrain manifest opens")
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_check(parsed is Dictionary, "Poly Haven terrain manifest parses as JSON")
	return parsed as Dictionary if parsed is Dictionary else {}


func _validate_manifest(manifest: Dictionary) -> void:
	_check(int(manifest.get("schema_version", 0)) == 1, "Terrain manifest uses schema version one")
	_check(
		manifest.get("license", "") == "CC0"
		and manifest.get("license_evidence", "") == LICENSE_PATH
		and FileAccess.file_exists(LICENSE_PATH)
		and manifest.get("license_evidence_sha256", "") == _sha256(LICENSE_PATH),
		"Terrain manifest records exact Poly Haven CC0 evidence"
	)
	var policy: String = String(manifest.get("runtime_policy", "")).to_lower()
	_check(
		"2d atlas" in policy and "no pbr source maps" in policy and "node3d" in policy,
		"Runtime policy allows only the derived 2D terrain outputs"
	)
	_check(_record_matches(manifest, "workshop", "workshop_bytes", "workshop_sha256", WORKSHOP_PATH), "Dedicated Blender workshop hash matches")
	_check(_record_matches(manifest, "generator", "generator_bytes", "generator_sha256", GENERATOR_PATH), "Deterministic Blender generator hash matches")

	var sources: Array = manifest.get("sources", []) as Array
	var ids: PackedStringArray = []
	var unique_ids: Dictionary = {}
	var records_valid: bool = sources.size() == EXPECTED_IDS.size()
	for value: Variant in sources:
		if not value is Dictionary:
			records_valid = false
			continue
		var source: Dictionary = value as Dictionary
		var asset_id: String = String(source.get("asset_id", ""))
		ids.append(asset_id)
		unique_ids[asset_id] = true
		var cell: Array = source.get("atlas_cell", []) as Array
		var sample: Array = source.get("sample_region", []) as Array
		if (
			source.get("asset_type", "") != "textures"
			or source.get("resolution", "") != "1k"
			or source.get("license", "") != "CC0"
			or not String(source.get("url", "")).begins_with("https://polyhaven.com/a/")
			or String(source.get("packed_pixel_sha256", "")).length() != 64
			or cell.size() != 4
			or sample.size() != 4
			or int(sample[2]) != 496
			or int(sample[3]) != 496
		):
			records_valid = false
	ids.sort()
	var expected_sorted: PackedStringArray = EXPECTED_IDS.duplicate()
	expected_sorted.sort()
	_check(ids == expected_sorted and unique_ids.size() == 4, "Exactly four reviewed Poly Haven terrain IDs are recorded")
	_check(records_valid, "Every terrain source records CC0 URL, 1k review hash, cell, and wrapped sample region")


func _validate_images(manifest: Dictionary) -> void:
	var atlas_record: Dictionary = manifest.get("atlas", {}) as Dictionary
	var mask_record: Dictionary = manifest.get("blend_mask", {}) as Dictionary
	_check(_image_record_matches(atlas_record, ATLAS_PATH, Vector2i(1024, 1024)), "Terrain atlas is the exact hashed 1024x1024 output")
	_check(_image_record_matches(mask_record, MASK_PATH, Vector2i(224, 224)), "Biome mask is the exact hashed 224x224 output")
	var import_text: String = _read_text(ATLAS_PATH + ".import")
	_check("mipmaps/generate=true" in import_text, "Terrain atlas imports with mobile mipmaps")
	var mask_texture: Texture2D = load(MASK_PATH) as Texture2D
	var mask: Image = mask_texture.get_image() if mask_texture != null else null
	_check(mask != null, "Biome blend mask loads as an image")
	if mask == null:
		return
	var forest: Color = mask.get_pixel(12 * 16 + 8, 3 * 16 + 8)
	var city: Color = mask.get_pixel(3 * 16 + 8, 3 * 16 + 8)
	var mall: Color = mask.get_pixel(8 * 16 + 8, 3 * 16 + 8)
	var village: Color = mask.get_pixel(2 * 16 + 8, 10 * 16 + 8)
	_check(forest.r > 0.65, "Forest macro-cell center favors leaf-litter terrain")
	_check(city.g > 0.55, "Kaupunki macro-cell center favors asphalt terrain")
	_check(mall.b > 0.55, "Ostari macro-cell center favors concrete terrain")
	_check(1.0 - village.r - village.g - village.b > 0.45, "Village macro-cell center favors mud-track terrain")
	var transition: Color = mask.get_pixel(6 * 16, 3 * 16 + 8)
	_check(transition.r > 0.05 and transition.g > 0.05, "City-to-wilderness edge contains a real blended transition")


func _validate_runtime(world_map: BesprenWorldMap2D) -> void:
	var overlay: Sprite2D = world_map.get_node_or_null("TerrainMaterialOverlay") as Sprite2D
	_check(overlay != null, "World owns one batched terrain material overlay")
	if overlay == null:
		return
	_check(
		overlay.texture != null
		and overlay.texture.resource_path == ATLAS_PATH
		and Vector2i(overlay.texture.get_width(), overlay.texture.get_height()) == Vector2i(1024, 1024),
		"Overlay renders the reviewed terrain atlas"
	)
	_check(overlay.scale == Vector2(28.0, 28.0), "1024 atlas covers the exact 28672-unit world")
	_check(overlay.z_index == -20 and not overlay.z_as_relative, "Terrain overlay remains in the background layer")
	_check(overlay.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "Terrain overlay uses linear mipmapped filtering")
	var shader_source: String = _read_text("res://shaders/terrain_material_blend.gdshader")
	_check(
		"sample_seamless_cell" in shader_source and "shifted_uv" in shader_source,
		"Terrain shader cross-fades source tile edges without another CanvasItem"
	)
	_check(
		"render_mode unshaded" not in shader_source,
		"Terrain remains responsive to CanvasModulate and local camp lights"
	)
	var material: ShaderMaterial = overlay.material as ShaderMaterial
	_check(
		material != null and material.shader != null and material.shader.resource_path == SHADER_PATH,
		"Overlay uses the dedicated organic biome-blend shader"
	)
	if material != null:
		var mask: Texture2D = material.get_shader_parameter(&"biome_mask") as Texture2D
		_check(mask != null and mask.resource_path == MASK_PATH, "Shader samples the authored 14x14 biome blend mask")
		var atlas: Texture2D = material.get_shader_parameter(&"terrain_atlas") as Texture2D
		_check(atlas != null and atlas.resource_path == ATLAS_PATH, "Seam cross-fade reuses the single reviewed terrain atlas")
		_check(is_equal_approx(float(material.get_shader_parameter(&"texture_repeats")), 28.0), "Terrain texture frequency is fixed for mobile readability")
		_check(is_equal_approx(float(material.get_shader_parameter(&"overlay_opacity")), 1.0), "Terrain blend fully replaces legacy macro-cell color blocks")
		_check(
			float(material.get_shader_parameter(&"exposure")) >= 1.20
			and float(material.get_shader_parameter(&"black_lift")) >= 0.03,
			"Terrain midtones remain readable through the sapphire-night modulation"
		)
	var terrain_tiles: TileMapLayer = world_map.get_node_or_null(
		"TerrainDetails/TerrainTiles"
	) as TileMapLayer
	_check(
		terrain_tiles != null and is_zero_approx(terrain_tiles.modulate.a),
		"Legacy square nature tiles remain available but visually yield to the seamless terrain"
	)
	_check(not _contains_node_3d(world_map), "Terrain material integration instantiates no Node3D")


func _image_record_matches(record: Dictionary, path: String, size: Vector2i) -> bool:
	var listed_size: Array = record.get("size", []) as Array
	if (
		record.get("path", "") != path
		or listed_size.size() != 2
		or int(listed_size[0]) != size.x
		or int(listed_size[1]) != size.y
		or int(record.get("bytes", -1)) != _file_size(path)
		or record.get("sha256", "") != _sha256(path)
	):
		return false
	var texture: Texture2D = load(path) as Texture2D
	return texture != null and Vector2i(texture.get_width(), texture.get_height()) == size


func _record_matches(record: Dictionary, path_key: String, bytes_key: String, hash_key: String, expected_path: String) -> bool:
	return (
		record.get(path_key, "") == expected_path
		and int(record.get(bytes_key, -1)) == _file_size(expected_path)
		and record.get(hash_key, "") == _sha256(expected_path)
	)


func _contains_node_3d(node: Node) -> bool:
	if node is Node3D:
		return true
	for child: Node in node.get_children():
		if _contains_node_3d(child):
			return true
	return false


func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


func _file_size(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	return file.get_length() if file != null else -1


func _sha256(path: String) -> String:
	return FileAccess.get_sha256(ProjectSettings.globalize_path(path))


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS | %s" % message)
	else:
		_failures += 1
		push_error("FAIL | %s" % message)


func _finish() -> void:
	if _failures == 0:
		print("TERRAIN MATERIAL VALIDATION OK (%d checks)" % _checks)
		quit(0)
		return
	print("TERRAIN MATERIAL VALIDATION FAILED (%d/%d)" % [_failures, _checks])
	quit(1)
