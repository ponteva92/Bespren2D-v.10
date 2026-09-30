extends SceneTree
## Exhaustive structural, UID, pivot, material, and archive coverage gate.

const SOURCE_MANIFEST_PATH: String = "res://assets/2d/catalog/source_manifest.json"
const PRODUCTION_CATALOG_PATH: String = "res://assets/2d/catalog/production_catalog.json"
const PRODUCTION_CATALOG_RESOURCE_PATH: String = "res://assets/2d/catalog/production_catalog.tres"
const GALLERY_PATH: String = "res://assets/2d/catalog/asset_pipeline_gallery.tscn"
const SHADER_PATH: String = "res://assets/2d/materials/post_apocalyptic_weathering.gdshader"

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var source_manifest := _load_json(SOURCE_MANIFEST_PATH)
	var catalog := _load_json(PRODUCTION_CATALOG_PATH)
	_check(not source_manifest.is_empty(), "Source manifest loads")
	_check(not catalog.is_empty(), "Production catalog loads")
	if source_manifest.is_empty() or catalog.is_empty():
		_finish()
		return

	var source_summary: Dictionary = source_manifest.get("summary", {}) as Dictionary
	_check(int(source_summary.get("archives_discovered", 0)) > 0, "Archive inventory is present")
	_check(int(source_summary.get("archives_discovered", 0)) == (source_manifest.get("archives", []) as Array).size(), "Every discovered archive has a manifest status")
	_check(int(source_summary.get("slice_failures", -1)) == 0, "No texture atlas failed standard-grid slicing")
	for archive_variant: Variant in source_manifest.get("archives", []) as Array:
		if not archive_variant is Dictionary:
			_check(false, "Archive record is a Dictionary")
			continue
		var archive: Dictionary = archive_variant
		var status := String(archive.get("status", ""))
		_check(status in ["processed", "duplicate", "skipped_non_2d"], "Archive status is valid: %s" % String(archive.get("path", "unknown")))
		_check(not String(archive.get("sha256", "")).is_empty(), "Archive hash is registered: %s" % String(archive.get("path", "unknown")))

	var shader := load(SHADER_PATH) as Shader
	_check(shader != null and not shader.code.is_empty(), "Post-apocalyptic shader loads")
	_validate_material("wood_spore", Color("ffd700"), 0.0)
	_validate_material("tech_cyan", Color("00ffff"), 0.0)
	_validate_material("ruined_structure", Color("ffb000"), 0.30)
	_validate_material("oxidized_copper", Color("00ffff"), 0.0)
	_validate_material("mutant_toxic", Color("9dff00"), 0.0)
	_validate_material("boss_toxic", Color("b6ff00"), 0.0)
	_validate_material("rusted_prop", Color("ffb000"), 0.0)

	var catalog_summary: Dictionary = catalog.get("summary", {}) as Dictionary
	_check(int(catalog_summary.get("builder_errors", -1)) == 0, "Native resource builder reported zero errors")
	var assets_variant: Variant = catalog.get("assets", [])
	_check(assets_variant is Array, "Catalog assets field is an Array")
	if not assets_variant is Array:
		_finish()
		return
	var assets: Array = assets_variant as Array
	_check(assets.size() == int(source_summary.get("production_bundles", -1)), "Every production bundle was built")
	_check(assets.size() == int(catalog_summary.get("generated_assets", -1)), "Catalog asset total is internally consistent")
	var category_counts: Dictionary = {}
	var validated_frames := 0
	for index in assets.size():
		var entry_variant: Variant = assets[index]
		if not entry_variant is Dictionary:
			_check(false, "Catalog entry %d is a Dictionary" % index)
			continue
		var entry: Dictionary = entry_variant
		var category := String(entry.get("category", ""))
		category_counts[category] = int(category_counts.get(category, 0)) + 1
		validated_frames += _validate_entry(entry)
		if (index + 1) % 100 == 0 or index + 1 == assets.size():
			print("ASSET VALIDATION PROGRESS | %d/%d" % [index + 1, assets.size()])
			await process_frame

	for required_category: String in ["environment", "enemies", "bosses", "props"]:
		_check(int(category_counts.get(required_category, 0)) > 0, "Category is populated: %s" % required_category)
	_check(validated_frames == int(catalog_summary.get("generated_frames", -1)), "Every generated SpriteFrames frame was validated")
	_check(ResourceLoader.exists(PRODUCTION_CATALOG_RESOURCE_PATH), "Production catalog .tres exists")
	_check(ResourceLoader.get_resource_uid(PRODUCTION_CATALOG_RESOURCE_PATH) > 0, "Production catalog .tres has a valid UID")
	_check(load(PRODUCTION_CATALOG_RESOURCE_PATH) is Resource, "Production catalog .tres loads")
	_check(ResourceLoader.exists(GALLERY_PATH), "Asset pipeline gallery exists")
	_check(ResourceLoader.get_resource_uid(GALLERY_PATH) > 0, "Asset pipeline gallery has a valid UID")
	_check(load(GALLERY_PATH) is PackedScene, "Asset pipeline gallery loads")
	_finish()


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func _validate_material(name: String, expected_glow: Color, minimum_structural_damage: float) -> void:
	var path := "res://assets/2d/materials/%s.tres" % name
	var material := load(path) as ShaderMaterial
	_check(material != null, "Material loads: %s" % name)
	if material == null:
		return
	_check(ResourceLoader.get_resource_uid(path) > 0, "Material has valid UID: %s" % name)
	_check(material.shader != null and material.shader.resource_path == SHADER_PATH, "Material uses shared weathering shader: %s" % name)
	var glow: Variant = material.get_shader_parameter(&"glow_color")
	_check(glow is Color and (glow as Color).is_equal_approx(expected_glow), "Material glow color is art-directed: %s" % name)
	_check(float(material.get_shader_parameter(&"weathering")) > 0.0, "Material weathering is enabled: %s" % name)
	_check(float(material.get_shader_parameter(&"structural_damage")) >= minimum_structural_damage, "Material structural damage meets profile: %s" % name)


func _validate_entry(entry: Dictionary) -> int:
	var asset_id := String(entry.get("id", "unknown"))
	var primary_texture := String(entry.get("primary_texture", ""))
	_check(not primary_texture.is_empty() and ResourceLoader.exists(primary_texture), "Managed source texture exists: %s" % asset_id)
	_check(ResourceLoader.get_resource_uid(primary_texture) > 0, "Managed source texture has valid UID: %s" % asset_id)
	var required_paths: PackedStringArray = [
		String(entry.get("atlas", "")),
		String(entry.get("sprite_frames", "")),
	]
	var tileset_path := String(entry.get("tileset", ""))
	var scene_path := String(entry.get("scene", ""))
	if not tileset_path.is_empty():
		required_paths.append(tileset_path)
	if not scene_path.is_empty():
		required_paths.append(scene_path)
	for path: String in required_paths:
		_check(not path.is_empty() and ResourceLoader.exists(path), "Generated resource exists: %s" % path)
		_check(ResourceLoader.get_resource_uid(path) > 0, "Generated resource has valid UID: %s" % path)

	var atlas := load(String(entry.get("atlas", ""))) as AtlasTexture
	_check(atlas != null and atlas.atlas != null, "AtlasTexture loads: %s" % asset_id)
	if atlas != null:
		_check(atlas.region.size.x > 0.0 and atlas.region.size.y > 0.0, "AtlasTexture region is positive: %s" % asset_id)

	var frames := load(String(entry.get("sprite_frames", ""))) as SpriteFrames
	_check(frames != null, "SpriteFrames loads: %s" % asset_id)
	var frame_count := 0
	if frames != null:
		for animation_name: StringName in frames.get_animation_names():
			frame_count += frames.get_frame_count(animation_name)
	_check(frame_count == int(entry.get("frame_count", -1)), "SpriteFrames count matches catalog: %s" % asset_id)

	if not tileset_path.is_empty():
		var tileset := load(tileset_path) as TileSet
		_check(tileset != null, "TileSet loads: %s" % asset_id)
		if tileset != null:
			_check(tileset.get_source_count() > 0, "TileSet owns an atlas source: %s" % asset_id)

	if not scene_path.is_empty():
		var packed := load(scene_path) as PackedScene
		_check(packed != null, "Weathered scene loads: %s" % asset_id)
		if packed != null:
			var instance := packed.instantiate() as Node2D
			_check(instance != null, "Weathered scene instantiates: %s" % asset_id)
			if instance != null:
				root.add_child(instance)
				_check(instance.y_sort_enabled, "Y-sort is enabled: %s" % asset_id)
				_check(String(instance.get_meta(&"pivot", "")) == "bottom_center", "Bottom-center pivot metadata is present: %s" % asset_id)
				_check(bool(instance.get_meta(&"weathered", false)), "Scene is marked weathered: %s" % asset_id)
				var sprite := instance.get_node_or_null("WeatheredSprite") as AnimatedSprite2D
				_check(sprite != null, "Scene owns a weathered sprite: %s" % asset_id)
				if sprite != null:
					var size_array: Array = entry.get("maximum_frame_size", [0, 0]) as Array
					var expected_y := -float(size_array[1]) * 0.5 if size_array.size() == 2 else 0.0
					_check(is_equal_approx(sprite.offset.x, 0.0) and is_equal_approx(sprite.offset.y, expected_y), "Sprite origin is bottom-center: %s" % asset_id)
					var material := sprite.material as ShaderMaterial
					_check(material != null and material.shader != null and material.shader.resource_path == SHADER_PATH, "Sprite uses post-apocalyptic shader: %s" % asset_id)
					if material != null:
						_check(float(material.get_shader_parameter(&"weathering")) > 0.0, "Sprite cannot render as clean fantasy art: %s" % asset_id)
				instance.queue_free()
	return frame_count


func _finish() -> void:
	if _failures == 0:
		print("ASSET PIPELINE VALIDATION OK (%d checks)" % _checks)
		quit(0)
		return
	push_error("ASSET PIPELINE VALIDATION FAILED (%d/%d checks failed)" % [_failures, _checks])
	quit(1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("FAIL | %s" % message)
