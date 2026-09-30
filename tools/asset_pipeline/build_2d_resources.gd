extends SceneTree
## Native Godot builder for the deterministic manifest emitted by the Python stage.

const MANIFEST_PATH: String = "res://assets/2d/catalog/source_manifest.json"
const OUTPUT_ROOT: String = "res://assets/2d"
const MATERIAL_ROOT: String = "res://assets/2d/materials"
const CATALOG_ROOT: String = "res://assets/2d/catalog"
const SHADER_PATH: String = "res://assets/2d/materials/post_apocalyptic_weathering.gdshader"
const GALLERY_PATH: String = "res://assets/2d/catalog/asset_pipeline_gallery.tscn"
const GALLERY_SCRIPT_PATH: String = "res://tests/asset_pipeline_render_validation.gd"

const MATERIAL_PROFILES: Dictionary = {
	"wood_spore": {
		"treatment": 1,
		"weathering": 0.86,
		"structural_damage": 0.08,
		"rust_streaks": 0.30,
		"toxic_intensity": 0.18,
		"glow_color": Color("ffd700"),
		"emission_strength": 0.58,
		"pattern_scale": 31.0,
		"damage_seed": 11.0,
	},
	"tech_cyan": {
		"treatment": 2,
		"weathering": 0.74,
		"structural_damage": 0.12,
		"rust_streaks": 0.28,
		"toxic_intensity": 0.34,
		"glow_color": Color("00ffff"),
		"emission_strength": 0.92,
		"pattern_scale": 35.0,
		"damage_seed": 23.0,
	},
	"ruined_structure": {
		"treatment": 0,
		"weathering": 0.91,
		"structural_damage": 0.46,
		"rust_streaks": 0.88,
		"toxic_intensity": 0.12,
		"glow_color": Color("ffb000"),
		"emission_strength": 0.18,
		"pattern_scale": 24.0,
		"damage_seed": 37.0,
	},
	"oxidized_copper": {
		"treatment": 2,
		"weathering": 0.84,
		"structural_damage": 0.12,
		"rust_streaks": 0.48,
		"toxic_intensity": 0.08,
		"glow_color": Color("00ffff"),
		"emission_strength": 0.28,
		"pattern_scale": 29.0,
		"damage_seed": 43.0,
	},
	"mutant_toxic": {
		"treatment": 3,
		"weathering": 0.72,
		"structural_damage": 0.04,
		"rust_streaks": 0.16,
		"toxic_intensity": 0.72,
		"glow_color": Color("9dff00"),
		"emission_strength": 0.64,
		"pattern_scale": 33.0,
		"damage_seed": 51.0,
	},
	"boss_toxic": {
		"treatment": 3,
		"weathering": 0.80,
		"structural_damage": 0.07,
		"rust_streaks": 0.22,
		"toxic_intensity": 0.94,
		"glow_color": Color("b6ff00"),
		"emission_strength": 0.88,
		"pattern_scale": 38.0,
		"damage_seed": 59.0,
	},
	"rusted_prop": {
		"treatment": 0,
		"weathering": 0.78,
		"structural_damage": 0.10,
		"rust_streaks": 0.61,
		"toxic_intensity": 0.10,
		"glow_color": Color("ffb000"),
		"emission_strength": 0.20,
		"pattern_scale": 27.0,
		"damage_seed": 17.0,
	},
}

var _errors: PackedStringArray = []
var _materials: Dictionary = {}
var _generated_entries: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var manifest := _load_json_dictionary(MANIFEST_PATH)
	if manifest.is_empty():
		_fail("Source manifest is missing or invalid: %s" % MANIFEST_PATH)
		_finish()
		return
	if int(manifest.get("schema_version", 0)) != 1:
		_fail("Unsupported source manifest schema")
		_finish()
		return
	var shader := load(SHADER_PATH) as Shader
	if shader == null or shader.code.is_empty():
		_fail("Weathering shader failed to load: %s" % SHADER_PATH)
		_finish()
		return

	_create_materials(shader)
	var assets_variant: Variant = manifest.get("assets", [])
	if not assets_variant is Array:
		_fail("Manifest assets field is not an Array")
		_finish()
		return
	var assets: Array = assets_variant as Array
	var total := assets.size()
	for index in total:
		var asset_variant: Variant = assets[index]
		if not asset_variant is Dictionary:
			_fail("Manifest asset %d is not a Dictionary" % index)
			continue
		_build_asset(asset_variant as Dictionary)
		if (index + 1) % 100 == 0 or index + 1 == total:
			print("ASSET RESOURCE PROGRESS | %d/%d" % [index + 1, total])

	var gallery_error := _build_gallery()
	if gallery_error != OK:
		_fail("Could not save gallery scene: %s" % error_string(gallery_error))
	_write_catalog(manifest)
	_finish()


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func _ensure_directory(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	var error := DirAccess.make_dir_recursive_absolute(absolute)
	if error != OK:
		_fail("Could not create directory %s: %s" % [path, error_string(error)])
		return false
	return true


func _create_materials(shader: Shader) -> void:
	_ensure_directory(MATERIAL_ROOT)
	for profile_name_variant: Variant in MATERIAL_PROFILES.keys():
		var profile_name := String(profile_name_variant)
		var profile: Dictionary = MATERIAL_PROFILES[profile_name]
		var material := ShaderMaterial.new()
		material.resource_name = "Bespren %s weathering" % profile_name.replace("_", " ").capitalize()
		material.shader = shader
		for parameter_variant: Variant in profile.keys():
			var parameter := StringName(String(parameter_variant))
			material.set_shader_parameter(parameter, profile[parameter_variant])
		var path := "%s/%s.tres" % [MATERIAL_ROOT, profile_name]
		var error := ResourceSaver.save(material, path)
		if error != OK:
			_fail("Could not save material %s: %s" % [path, error_string(error)])
			continue
		_ensure_uid(path)
		_materials[profile_name] = material


func _category_directory(category: String, child: String) -> String:
	var path := "%s/%s/%s" % [OUTPUT_ROOT, category, child]
	_ensure_directory(path)
	return path


func _atlas_from_frame(frame: Dictionary) -> AtlasTexture:
	var texture_path := String(frame.get("texture", ""))
	var texture := load(texture_path) as Texture2D
	if texture == null:
		_fail("Texture failed to load: %s" % texture_path)
		return null
	var width := int(frame.get("w", 0))
	var height := int(frame.get("h", 0))
	var x := int(frame.get("x", 0))
	var y := int(frame.get("y", 0))
	if width <= 0 or height <= 0:
		_fail("Invalid frame bounds for %s" % texture_path)
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(float(x), float(y), float(width), float(height))
	atlas.resource_name = String(frame.get("name", "atlas_frame"))
	return atlas


func _build_sprite_frames(asset: Dictionary) -> Dictionary:
	var sprite_frames := SpriteFrames.new()
	if sprite_frames.has_animation(&"default"):
		sprite_frames.remove_animation(&"default")
	var first_atlas: AtlasTexture = null
	var maximum_size := Vector2.ZERO
	var frame_total := 0
	var animations_variant: Variant = asset.get("animations", [])
	if not animations_variant is Array:
		_fail("Asset animations are invalid: %s" % String(asset.get("id", "unknown")))
		return {}
	for animation_variant: Variant in animations_variant as Array:
		if not animation_variant is Dictionary:
			continue
		var animation: Dictionary = animation_variant
		var animation_name := StringName(String(animation.get("name", "default")))
		if not sprite_frames.has_animation(animation_name):
			sprite_frames.add_animation(animation_name)
		sprite_frames.set_animation_speed(animation_name, float(animation.get("fps", 8.0)))
		sprite_frames.set_animation_loop(animation_name, bool(animation.get("loop", true)))
		var frames_variant: Variant = animation.get("frames", [])
		if not frames_variant is Array:
			continue
		for frame_variant: Variant in frames_variant as Array:
			if not frame_variant is Dictionary:
				continue
			var frame: Dictionary = frame_variant
			var atlas := _atlas_from_frame(frame)
			if atlas == null:
				continue
			if first_atlas == null:
				first_atlas = atlas
			maximum_size.x = maxf(maximum_size.x, atlas.get_width())
			maximum_size.y = maxf(maximum_size.y, atlas.get_height())
			var duration := maxf(float(frame.get("duration", 1.0)), 0.01)
			sprite_frames.add_frame(animation_name, atlas, duration)
			frame_total += 1
	return {
		"resource": sprite_frames,
		"first_atlas": first_atlas,
		"maximum_size": maximum_size,
		"frame_total": frame_total,
	}


func _build_tileset(asset: Dictionary, path: String) -> TileSet:
	var tileset_variant: Variant = asset.get("tileset")
	if not tileset_variant is Dictionary:
		return null
	var specification: Dictionary = tileset_variant
	var texture := load(String(specification.get("texture", ""))) as Texture2D
	if texture == null:
		_fail("Tileset texture failed to load for %s" % String(asset.get("id", "unknown")))
		return null
	var region_array: Array = specification.get("region_size", []) as Array
	var tile_array: Array = specification.get("tile_size", []) as Array
	if region_array.size() != 2 or tile_array.size() != 2:
		_fail("Tileset sizes are invalid for %s" % String(asset.get("id", "unknown")))
		return null
	var region_size := Vector2i(int(region_array[0]), int(region_array[1]))
	var tile_size := Vector2i(int(tile_array[0]), int(tile_array[1]))
	var tileset := TileSet.new()
	tileset.resource_name = "%s weathered tileset" % String(asset.get("display_name", "Bespren"))
	tileset.tile_size = tile_size
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = region_size
	var cells_variant: Variant = specification.get("cells", [])
	if cells_variant is Array:
		for cell_variant: Variant in cells_variant as Array:
			if not cell_variant is Dictionary:
				continue
			var cell: Dictionary = cell_variant
			var coordinates := Vector2i(int(cell.get("column", 0)), int(cell.get("row", 0)))
			if source.has_tile(coordinates):
				continue
			source.create_tile(coordinates)
			var tile_data := source.get_tile_data(coordinates, 0)
			if tile_data != null:
				tile_data.y_sort_origin = maxi(0, region_size.y / 2)
	tileset.add_source(source, 0)
	var error := ResourceSaver.save(tileset, path)
	if error != OK:
		_fail("Could not save TileSet %s: %s" % [path, error_string(error)])
		return null
	return tileset


func _build_scene(asset: Dictionary, frames: SpriteFrames, maximum_size: Vector2, material: ShaderMaterial, tileset: TileSet, path: String) -> Error:
	var root_node := Node2D.new()
	root_node.name = String(asset.get("display_name", "WeatheredAsset")).replace(" ", "")
	root_node.y_sort_enabled = true
	root_node.set_meta(&"bespren_asset_id", String(asset.get("id", "")))
	root_node.set_meta(&"pivot", "bottom_center")
	root_node.set_meta(&"weathered", true)
	root_node.set_meta(&"source_kind", String(asset.get("source_kind", "")))
	root_node.add_to_group(&"weathered_2d_asset", true)

	var sprite := AnimatedSprite2D.new()
	sprite.name = "WeatheredSprite"
	sprite.sprite_frames = frames
	var animation_names := frames.get_animation_names()
	if not animation_names.is_empty():
		sprite.animation = animation_names[0]
		if frames.get_frame_count(sprite.animation) > 1:
			sprite.autoplay = String(sprite.animation)
	sprite.centered = true
	sprite.offset = Vector2(0.0, -maximum_size.y * 0.5)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = material
	sprite.z_as_relative = true
	root_node.add_child(sprite)
	sprite.owner = root_node

	if tileset != null:
		var tile_layer := TileMapLayer.new()
		tile_layer.name = "WeatheredTileLayer"
		tile_layer.tile_set = tileset
		tile_layer.y_sort_enabled = true
		tile_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tile_layer.material = material
		root_node.add_child(tile_layer)
		tile_layer.owner = root_node

	var packed := PackedScene.new()
	var pack_error := packed.pack(root_node)
	if pack_error != OK:
		root_node.free()
		return pack_error
	var save_error := ResourceSaver.save(packed, path)
	root_node.free()
	return save_error


func _build_asset(asset: Dictionary) -> void:
	var asset_id := String(asset.get("id", ""))
	var category := String(asset.get("category", "props"))
	var material_name := String(asset.get("material", "rusted_prop"))
	if asset_id.is_empty() or not _materials.has(material_name):
		_fail("Asset identity or material is invalid: %s" % asset_id)
		return
	var built := _build_sprite_frames(asset)
	if built.is_empty() or int(built.get("frame_total", 0)) <= 0:
		_fail("Asset has no valid frames: %s" % asset_id)
		return
	var sprite_frames := built["resource"] as SpriteFrames
	var first_atlas := built["first_atlas"] as AtlasTexture
	var maximum_size := built["maximum_size"] as Vector2

	var atlas_path := "%s/%s_atlas.tres" % [_category_directory(category, "atlases"), asset_id]
	var frames_path := "%s/%s_frames.tres" % [_category_directory(category, "animations"), asset_id]
	var scene_path := "%s/%s.tscn" % [_category_directory(category, "scenes"), asset_id]
	var tileset_path := ""
	var atlas_error := ResourceSaver.save(first_atlas, atlas_path)
	if atlas_error != OK:
		_fail("Could not save AtlasTexture %s: %s" % [atlas_path, error_string(atlas_error)])
	var frames_error := ResourceSaver.save(sprite_frames, frames_path)
	if frames_error != OK:
		_fail("Could not save SpriteFrames %s: %s" % [frames_path, error_string(frames_error)])

	var tileset: TileSet = null
	if asset.get("tileset") is Dictionary:
		tileset_path = "%s/%s_tileset.tres" % [_category_directory(category, "tilesets"), asset_id]
		tileset = _build_tileset(asset, tileset_path)

	var scene_saved := false
	if String(asset.get("source_kind", "")) != "atlas_parts":
		var scene_error := _build_scene(
			asset,
			sprite_frames,
			maximum_size,
			_materials[material_name] as ShaderMaterial,
			tileset,
			scene_path
		)
		if scene_error != OK:
			_fail("Could not save scene %s: %s" % [scene_path, error_string(scene_error)])
		else:
			scene_saved = true

	var generated_paths: PackedStringArray = [atlas_path, frames_path]
	if not tileset_path.is_empty():
		generated_paths.append(tileset_path)
	if scene_saved:
		generated_paths.append(scene_path)
	var uids: Dictionary = {}
	for generated_path: String in generated_paths:
		var uid := _ensure_uid(generated_path)
		uids[generated_path] = uid

	_generated_entries.append(
		{
			"id": asset_id,
			"display_name": String(asset.get("display_name", asset_id)),
			"category": category,
			"material": material_name,
			"source_kind": String(asset.get("source_kind", "")),
			"source_aliases": asset.get("source_aliases", []),
			"primary_texture": String(asset.get("primary_texture", "")),
			"atlas": atlas_path,
			"sprite_frames": frames_path,
			"tileset": tileset_path,
			"scene": scene_path if scene_saved else "",
			"frame_count": int(built.get("frame_total", 0)),
			"maximum_frame_size": [int(maximum_size.x), int(maximum_size.y)],
			"uids": uids,
		}
	)


func _gallery_candidates() -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	for category in ["environment", "enemies", "bosses", "props"]:
		var category_entries: Array[Dictionary] = []
		for entry: Dictionary in _generated_entries:
			if String(entry.get("category", "")) != category or String(entry.get("scene", "")).is_empty():
				continue
			var size_array: Array = entry.get("maximum_frame_size", []) as Array
			if size_array.size() != 2:
				continue
			var longest := maxi(int(size_array[0]), int(size_array[1]))
			if longest <= 512:
				category_entries.append(entry)
		category_entries.sort_custom(
			func(left: Dictionary, right: Dictionary) -> bool:
				return int((left.get("maximum_frame_size", [9999, 9999]) as Array)[1]) < int((right.get("maximum_frame_size", [9999, 9999]) as Array)[1])
		)
		for index in mini(2, category_entries.size()):
			selected.append(category_entries[index])
	return selected


func _build_gallery() -> Error:
	var gallery := Node2D.new()
	gallery.name = "BesprenAssetPipelineGallery"
	var gallery_script := load(GALLERY_SCRIPT_PATH) as Script
	if gallery_script != null:
		gallery.set_script(gallery_script)

	var background := ColorRect.new()
	background.name = "Background"
	background.position = Vector2.ZERO
	background.size = Vector2(480.0, 270.0)
	background.color = Color("071011")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.z_index = -100
	gallery.add_child(background)
	background.owner = gallery

	var title := Label.new()
	title.name = "Title"
	title.text = "BESPREN // WEATHERED ASSET PIPELINE"
	title.position = Vector2(14.0, 7.0)
	title.add_theme_color_override(&"font_color", Color("ffd700"))
	title.add_theme_font_size_override(&"font_size", 11)
	gallery.add_child(title)
	title.owner = gallery

	var candidates := _gallery_candidates()
	for index in candidates.size():
		var entry: Dictionary = candidates[index]
		var packed := load(String(entry.get("scene", ""))) as PackedScene
		if packed == null:
			continue
		var instance := packed.instantiate() as Node2D
		if instance == null:
			continue
		var column := index % 4
		var row := index / 4
		var baseline_y := 132.0 + float(row) * 118.0
		instance.position = Vector2(60.0 + float(column) * 120.0, baseline_y)
		var size_array: Array = entry.get("maximum_frame_size", [64, 64]) as Array
		var width := maxf(float(size_array[0]), 1.0)
		var height := maxf(float(size_array[1]), 1.0)
		var scale_factor := minf(1.0, minf(94.0 / width, 82.0 / height))
		instance.scale = Vector2.ONE * scale_factor
		instance.name = "Sample%02d_%s" % [index, String(entry.get("category", "asset")).capitalize()]
		gallery.add_child(instance)
		instance.owner = gallery

		var baseline := Line2D.new()
		baseline.name = "Baseline%02d" % index
		baseline.points = PackedVector2Array(
			[
				Vector2(instance.position.x - 42.0, baseline_y + 1.0),
				Vector2(instance.position.x + 42.0, baseline_y + 1.0),
			]
		)
		baseline.width = 1.0
		baseline.default_color = Color(0.0, 1.0, 1.0, 0.34)
		baseline.z_index = -1
		gallery.add_child(baseline)
		baseline.owner = gallery

		var label := Label.new()
		label.name = "Label%02d" % index
		label.text = String(entry.get("category", "asset")).to_upper()
		label.position = Vector2(instance.position.x - 42.0, baseline_y + 4.0)
		label.add_theme_color_override(&"font_color", Color(0.45, 0.86, 0.88, 0.92))
		label.add_theme_font_size_override(&"font_size", 8)
		gallery.add_child(label)
		label.owner = gallery

	var packed_gallery := PackedScene.new()
	var pack_error := packed_gallery.pack(gallery)
	if pack_error != OK:
		gallery.free()
		return pack_error
	var save_error := ResourceSaver.save(packed_gallery, GALLERY_PATH)
	gallery.free()
	if save_error == OK:
		_ensure_uid(GALLERY_PATH)
	return save_error


func _write_catalog(source_manifest: Dictionary) -> void:
	_ensure_directory(CATALOG_ROOT)
	var category_counts: Dictionary = {}
	var total_frames := 0
	for entry: Dictionary in _generated_entries:
		var category := String(entry.get("category", "unknown"))
		category_counts[category] = int(category_counts.get(category, 0)) + 1
		total_frames += int(entry.get("frame_count", 0))
	var summary := {
		"source_summary": source_manifest.get("summary", {}),
		"generated_assets": _generated_entries.size(),
		"generated_frames": total_frames,
		"categories": category_counts,
		"materials": MATERIAL_PROFILES.keys(),
		"shader": SHADER_PATH,
		"gallery_scene": GALLERY_PATH,
		"builder_errors": _errors.size(),
	}
	var catalog := {
		"schema_version": 1,
		"summary": summary,
		"assets": _generated_entries,
	}
	var json_path := "%s/production_catalog.json" % CATALOG_ROOT
	var json_file := FileAccess.open(json_path, FileAccess.WRITE)
	if json_file == null:
		_fail("Could not open production catalog for writing")
	else:
		json_file.store_string(JSON.stringify(catalog, "\t"))
		json_file.close()
	var catalog_resource := Resource.new()
	catalog_resource.resource_name = "Bespren 2D Production Catalog"
	catalog_resource.set_meta(&"schema_version", 1)
	catalog_resource.set_meta(&"summary", summary)
	catalog_resource.set_meta(&"assets", _generated_entries)
	var tres_path := "%s/production_catalog.tres" % CATALOG_ROOT
	var save_error := ResourceSaver.save(catalog_resource, tres_path)
	if save_error != OK:
		_fail("Could not save production catalog resource: %s" % error_string(save_error))
	else:
		_ensure_uid(tres_path)


func _ensure_uid(path: String) -> int:
	var uid := ResourceLoader.get_resource_uid(path)
	if uid <= 0:
		uid = ResourceUID.create_id()
	var error := ResourceSaver.set_uid(path, uid)
	if error != OK:
		_fail("Could not assign UID to %s: %s" % [path, error_string(error)])
		return -1
	if not ResourceUID.has_id(uid):
		ResourceUID.add_id(uid, path)
	return uid


func _fail(message: String) -> void:
	_errors.append(message)
	push_error("ASSET PIPELINE | %s" % message)


func _finish() -> void:
	if _errors.is_empty():
		print("ASSET RESOURCE BUILD OK | assets=%d materials=%d" % [_generated_entries.size(), _materials.size()])
		quit(0)
		return
	push_error("ASSET RESOURCE BUILD FAILED | errors=%d" % _errors.size())
	for message: String in _errors:
		print("PIPELINE ERROR | %s" % message)
	quit(1)
