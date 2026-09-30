extends SceneTree
## Focused provenance, bake-quality, runtime, and export gate for the Hidden Alley district family.

const WORLD_MAP_SCENE: PackedScene = preload("res://scenes/world/world_map_2d.tscn")
const WORLD_MAP_SCENE_PATH: String = "res://scenes/world/world_map_2d.tscn"
const BACKGROUND_CHUNK_SCRIPT_PATH: String = (
	"res://src/world/world_background_decor_chunk_2d.gd"
)
const WORLD_OBSTACLE_SCRIPT_PATH: String = "res://src/world/world_obstacle_2d.gd"
const MANIFEST_PATH: String = (
	"res://assets/2d/environment/polyhaven_district/polyhaven_district_manifest.json"
)
const ATLAS_PATH: String = (
	"res://assets/2d/environment/polyhaven_district/polyhaven_district_atlas.png"
)
const LICENSE_EVIDENCE_PATH: String = "res://assets/licenses/polyhaven_cc0.md"
const SLEEK_SPRITE_SHADER_PATH: String = "res://shaders/sleek_sprite_finish.gdshader"
const SLEEK_CANVAS_SHADER_PATH: String = "res://shaders/sleek_canvas_grade.gdshader"
const EXPORT_CLOSURE_PATH: String = "res://data/runtime_export_closure.json"
const EXPORT_DEPENDENCY_SCENE_PATH: String = (
	"res://scenes/build/runtime_export_dependencies.tscn"
)
const EXPECTED_ATLAS_SIZE: Vector2i = Vector2i(1536, 768)
const EXPECTED_FRAME_SIZE: Vector2i = Vector2i(384, 384)
const EXPECTED_SOURCE_COUNT: int = 8
const EXPECTED_FRAME_COUNT: int = 8
## The authored size of the runtime export closure. It is pinned rather than
## counted so a stray asset cannot enter the shipped package unnoticed, which
## means it has to be raised deliberately whenever the runtime gains a
## resource - it sat at 194 while the closure held 198 for the whole time the
## feedback stack was shipping, because that pass updated the closure and
## CLAUDE.md but not the gate reading them. Raised to 202 for
## `src/visual/ground_shadow.gd`, which is the same trap again: a static-only
## `class_name` reached by `GroundShadow.draw_ellipse` and never by a node
## reference, so nothing in a scene-graph walk would have found it. Raised to
## 204 for two shaders the closure had never named. `weather_overlay.gdshader`
## is the milder case: it is an `ext_resource` of `game_world.tscn`, so the
## packer was always going to find it and only the declaration was wrong.
## `road_surface_detail.gdshader` is the trap - `world_road_segment_chunk_2d.gd`
## reaches it through a `String` constant and nothing else in the project
## mentions it, so it was named in neither the closure nor the dependency
## scene and had no path into the package that did not depend on the exporter
## resolving a string. Every entry this constant has ever gained is the same
## shape: a resource reached by name rather than by reference.
const EXPECTED_EXPORT_RESOURCE_COUNT: int = 204
## Derived rather than authored beside it. The dependency scene retains every
## resource in the closure plus the closure manifest itself, so a second hand
## written number here could only ever drift away from the first one.
const EXPECTED_EXPORT_DEPENDENCY_COUNT: int = EXPECTED_EXPORT_RESOURCE_COUNT + 1
const EXPECTED_BACKGROUND_DECOR_COUNT: int = 1100
const EXPECTED_BACKGROUND_PROP_COUNT: int = 420
const EXPECTED_STREET_SEATING_COUNT: int = 75
const EXPECTED_FIRE_HYDRANT_COUNT: int = 46
const EXPECTED_BARREL_STOVE_COUNT: int = 34
const STREET_SEATING_KIND: int = 6
const FIRE_HYDRANT_KIND: int = 7
const BARREL_STOVE_KIND: int = 8

const EXPECTED_SOURCE_IDS: Array[String] = [
	"modular_urban_apartments_facade",
	"modular_factory_facade",
	"modular_chainlink_fence",
	"covered_car",
	"exterior_aircon_unit",
	"modular_street_seating",
	"fire_hydrant",
	"barrel_stove",
]
const EXPECTED_FRAME_KEYS: Array[String] = [
	"urban_apartment_block",
	"factory_block",
	"chainlink_gate",
	"covered_car",
	"aircon_cluster",
	"street_bench",
	"aged_fire_hydrant",
	"barrel_stove",
]
const EXPECTED_FRAME_PATHS: Array[String] = [
	"res://assets/2d/environment/polyhaven_district/polyhaven_district_urban_apartment_block.png",
	"res://assets/2d/environment/polyhaven_district/polyhaven_district_factory_block.png",
	"res://assets/2d/environment/polyhaven_district/polyhaven_district_chainlink_gate.png",
	"res://assets/2d/environment/polyhaven_district/polyhaven_district_covered_car.png",
	"res://assets/2d/environment/polyhaven_district/polyhaven_district_aircon_cluster.png",
	"res://assets/2d/environment/polyhaven_district/polyhaven_district_street_bench.png",
	"res://assets/2d/environment/polyhaven_district/polyhaven_district_aged_fire_hydrant.png",
	"res://assets/2d/environment/polyhaven_district/polyhaven_district_barrel_stove.png",
]
const EXPECTED_DISTRICT_FAMILY_COUNTS: Dictionary = {
	"urban": 3,
	"factory": 3,
	"chainlink": 2,
	"covered_car": 2,
	"aircon": 4,
	"bench": 1,
	"barrel_stove": 1,
}
const EXPECTED_DISTRICT_PARENTS: Dictionary = {
	"urban": ["CityBuilding_05", "OstariNorthShell", "OstariSouthShell"],
	"factory": ["CityBuilding_04", "OstariNorthShell", "OstariSouthShell"],
	"chainlink": ["EastVillageFence_00", "EastVillageFence_03"],
	"covered_car": ["CityVehicleWreck_03", "EastVillageVehicleWreck"],
	"aircon": ["CityBuilding_04", "CityBuilding_05", "OstariNorthShell", "OstariSouthShell"],
	"bench": ["StartingCampBedding"],
	"barrel_stove": ["StartingCampSupplyCache"],
}

var _checks: int = 0
var _failures: int = 0
var _manifest_regions: Array[Rect2] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var manifest: Dictionary = _load_manifest()
	if manifest.is_empty():
		_finish()
		return
	_validate_manifest(manifest)
	_validate_atlas_resource(manifest)
	_validate_runtime_dependency_graph()
	_validate_export_closure()

	var world_map: BesprenWorldMap2D = WORLD_MAP_SCENE.instantiate() as BesprenWorldMap2D
	_check(world_map != null, "World map scene instantiates for district validation")
	if world_map == null:
		_finish()
		return
	root.add_child(world_map)
	await process_frame
	world_map.ensure_built()
	_validate_world_integration(world_map)
	world_map.queue_free()
	await process_frame
	_finish()


func _load_manifest() -> Dictionary:
	_check(FileAccess.file_exists(MANIFEST_PATH), "District provenance manifest exists")
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	_check(file != null, "District provenance manifest opens for reading")
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_check(parsed is Dictionary, "District provenance manifest parses as a JSON object")
	return parsed as Dictionary if parsed is Dictionary else {}


func _validate_manifest(manifest: Dictionary) -> void:
	_check(manifest.get("schema_version", 0) == 1, "Manifest uses schema version 1")
	_check(
		manifest.get("license", "") == "CC0-1.0"
		and manifest.get("license_url", "") == "https://polyhaven.com/license",
		"Manifest declares canonical Poly Haven CC0-1.0 licensing"
	)
	var evidence_text: String = _read_text_file(LICENSE_EVIDENCE_PATH).to_lower()
	_check(
		manifest.get("license_evidence", "") == LICENSE_EVIDENCE_PATH
		and not evidence_text.is_empty()
		and "cc0" in evidence_text
		and "poly haven" in evidence_text,
		"Manifest links to local Poly Haven CC0 evidence"
	)
	var render_policy: String = String(manifest.get("render_policy", "")).to_lower()
	_check(
		"orthographic" in render_policy
		and ("rgba" in render_policy or "transparent" in render_policy)
		and "agx" in render_policy
		and "mobile" in render_policy,
		"Manifest records the orthographic RGBA AgX mobile render policy"
	)
	_check(
		String(manifest.get("blender_version", "")).begins_with("5."),
		"District family records the reviewed Blender 5 renderer"
	)
	var quality_variant: Variant = manifest.get("quality_gates", {})
	var quality_gates: Dictionary = quality_variant as Dictionary if quality_variant is Dictionary else {}
	_check(
		int(quality_gates.get("minimum_frame_margin", 0)) == 8
		and float(quality_gates.get("minimum_alpha_weighted_luma_255", 0.0)) == 50.0
		and "no_runtime_mesh" in String(manifest.get("runtime_policy", "")).to_lower()
		and "node3d" in String(manifest.get("runtime_policy", "")).to_lower(),
		"Manifest fixes the eight-pixel, luma-50, atlas-only runtime quality gates"
	)
	_check(
		_file_record_matches(manifest, "blender_renderer")
		and String(manifest.get("blender_renderer", ""))
		== "res://tools/art/render_polyhaven_district_sprites.py",
		"Blender renderer path, bytes, and SHA-256 match the manifest"
	)
	_check(
		_file_record_matches(manifest, "workshop")
		and String(manifest.get("workshop", ""))
		== "res://tools/art/blender/bespren_polyhaven_district_workshop.blend",
		"Dedicated Blender workshop path, bytes, and SHA-256 match the manifest"
	)
	_check(
		_file_record_matches(manifest, "atlas_generator")
		and String(manifest.get("atlas_generator", ""))
		== "res://tools/asset_pipeline/build_polyhaven_district_atlas.gd",
		"Deterministic atlas generator path, bytes, and SHA-256 match the manifest"
	)

	var sources: Array = _as_array(manifest.get("source_assets", []))
	var source_order_is_exact: bool = sources.size() == EXPECTED_SOURCE_COUNT
	var source_records_are_valid: bool = sources.size() == EXPECTED_SOURCE_COUNT
	for source_index: int in range(sources.size()):
		var source_variant: Variant = sources[source_index]
		if not (source_variant is Dictionary):
			source_order_is_exact = false
			source_records_are_valid = false
			continue
		var source: Dictionary = source_variant as Dictionary
		var source_id: String = String(source.get("id", ""))
		if source_index >= EXPECTED_SOURCE_IDS.size() or source_id != EXPECTED_SOURCE_IDS[source_index]:
			source_order_is_exact = false
		if (
			source.get("type", "") != "model"
			or source.get("resolution", "") != "1k"
			or source.get("format", "") != "gltf"
			or source.get("license", "") != "CC0-1.0"
			or source.get("url", "") != "https://polyhaven.com/a/%s" % source_id
		):
			source_records_are_valid = false
	_check(sources.size() == EXPECTED_SOURCE_COUNT, "Manifest records exactly eight Poly Haven source models")
	_check(source_order_is_exact, "Source-model IDs retain the reviewed deterministic order")
	_check(source_records_are_valid, "Every source records its exact CC0, 1k GLTF Poly Haven provenance")

	_manifest_regions.clear()
	var frames: Array = _as_array(manifest.get("derived_assets", []))
	var frame_order_is_exact: bool = frames.size() == EXPECTED_FRAME_COUNT
	var frame_records_are_valid: bool = frames.size() == EXPECTED_FRAME_COUNT
	var every_frame_is_rgba: bool = frames.size() == EXPECTED_FRAME_COUNT
	var every_frame_has_margin: bool = frames.size() == EXPECTED_FRAME_COUNT
	var every_frame_is_readable: bool = frames.size() == EXPECTED_FRAME_COUNT
	var actual_metrics_match: bool = frames.size() == EXPECTED_FRAME_COUNT
	for frame_index: int in range(frames.size()):
		var frame_variant: Variant = frames[frame_index]
		if not (frame_variant is Dictionary):
			frame_order_is_exact = false
			frame_records_are_valid = false
			every_frame_is_rgba = false
			every_frame_has_margin = false
			every_frame_is_readable = false
			actual_metrics_match = false
			continue
		var frame: Dictionary = frame_variant as Dictionary
		var frame_key: String = String(frame.get("key", ""))
		var source_id: String = String(frame.get("source_id", ""))
		var frame_path: String = String(frame.get("path", ""))
		if (
			frame_index >= EXPECTED_FRAME_KEYS.size()
			or frame_key != EXPECTED_FRAME_KEYS[frame_index]
			or source_id != EXPECTED_SOURCE_IDS[frame_index]
			or frame_path != EXPECTED_FRAME_PATHS[frame_index]
		):
			frame_order_is_exact = false
		var expected_cell: Rect2i = Rect2i(
			Vector2i(frame_index % 4, frame_index / 4) * EXPECTED_FRAME_SIZE,
			EXPECTED_FRAME_SIZE
		)
		var content_bounds: Rect2i = _array_to_rect2i(frame.get("content_bounds", []))
		var cell_region: Rect2i = _array_to_rect2i(frame.get("cell_region", []))
		var padded_region: Rect2 = _array_to_rect2(frame.get("padded_atlas_region", []))
		if (
			not _file_record_matches(frame)
			or cell_region != expected_cell
			or content_bounds.size.x <= 0
			or content_bounds.size.y <= 0
			or not Rect2i(Vector2i.ZERO, EXPECTED_FRAME_SIZE).encloses(content_bounds)
			or not _is_valid_region(frame.get("padded_atlas_region", []), EXPECTED_ATLAS_SIZE)
		):
			frame_records_are_valid = false
		if int(frame.get("edge_margin_px", -1)) < 8 or _minimum_edge_margin(content_bounds) < 8:
			every_frame_has_margin = false
		if (
			float(frame.get("alpha_coverage", 0.0)) <= 0.0
			or float(frame.get("alpha_coverage", 0.0)) > 1.0
			or float(frame.get("alpha_weighted_luma", 0.0)) < 50.0
		):
			every_frame_is_readable = false
		# Measure the authored PNG bytes just as the atlas generator does. Reading
		# an imported Texture2D here would compare color-space-converted CTEX pixels
		# against raw PNG metrics and report a false luma mismatch.
		var image: Image = Image.new()
		var image_error: Error = image.load(ProjectSettings.globalize_path(frame_path))
		if (
			image_error != OK
			or image.get_size() != EXPECTED_FRAME_SIZE
			or image.get_format() != Image.FORMAT_RGBA8
		):
			every_frame_is_rgba = false
			actual_metrics_match = false
		else:
			var actual_metrics: Dictionary = _measure_frame(image)
			if (
				actual_metrics.get("content_bounds", Rect2i()) != content_bounds
				or int(actual_metrics.get("visible_pixel_count", -1)) != int(frame.get("visible_pixel_count", -2))
				or int(frame.get("edge_margin_px", -1)) != _minimum_edge_margin(content_bounds)
				or absf(float(actual_metrics.get("alpha_coverage", 0.0)) - float(frame.get("alpha_coverage", -1.0))) > 0.000002
				or absf(float(actual_metrics.get("alpha_weighted_luma", 0.0)) - float(frame.get("alpha_weighted_luma", -1.0))) > 0.002
			):
				actual_metrics_match = false
		_manifest_regions.append(padded_region)
	_check(frames.size() == EXPECTED_FRAME_COUNT, "Manifest records exactly eight derived district frames")
	_check(frame_order_is_exact, "Frame keys, source links, paths, and 4x2 cells retain exact deterministic order")
	_check(frame_records_are_valid, "Every frame has current hashes and bounded deterministic atlas regions")
	_check(every_frame_is_rgba, "Every district source frame is a 384x384 RGBA8 PNG")
	_check(every_frame_has_margin, "Every visible silhouette retains at least an eight-pixel transparent edge margin")
	_check(every_frame_is_readable, "Every frame is non-empty and records alpha-weighted luma of at least 50")
	_check(actual_metrics_match, "Actual frame alpha bounds, coverage, and luma match the manifest")


func _validate_atlas_resource(manifest: Dictionary) -> void:
	var atlas_variant: Variant = manifest.get("atlas", {})
	var atlas_record: Dictionary = atlas_variant as Dictionary if atlas_variant is Dictionary else {}
	var atlas_size: Array = _as_array(atlas_record.get("size", []))
	_check(
		atlas_record.get("path", "") == ATLAS_PATH
		and atlas_size.size() == 2
		and int(atlas_size[0]) == EXPECTED_ATLAS_SIZE.x
		and int(atlas_size[1]) == EXPECTED_ATLAS_SIZE.y
		and atlas_record.get("layout", "") == "4x2 deterministic frame order; 8 occupied cells"
		and _file_record_matches(atlas_record),
		"Manifest identifies the exact deterministic 1536x768 district atlas"
	)
	var atlas: Texture2D = load(ATLAS_PATH) as Texture2D
	_check(atlas != null, "District atlas imports as Texture2D")
	if atlas == null:
		return
	_check(atlas.resource_path == ATLAS_PATH, "Imported district atlas retains its canonical resource path")
	_check(atlas.get_size() == Vector2(EXPECTED_ATLAS_SIZE), "Imported district atlas is exactly 1536x768")
	var atlas_image: Image = atlas.get_image()
	_check(
		atlas_image != null and atlas_image.get_mipmap_count() > 0,
		"Imported district atlas contains generated mipmaps for the mobile linear filter"
	)


func _validate_runtime_dependency_graph() -> void:
	var pending: Array[String] = [WORLD_MAP_SCENE_PATH]
	var visited: Dictionary = {}
	var forbidden_source_dependency: bool = false
	while not pending.is_empty():
		var resource_path: String = pending.pop_back()
		if visited.has(resource_path):
			continue
		visited[resource_path] = true
		for dependency_record: String in ResourceLoader.get_dependencies(resource_path):
			var dependency_path: String = dependency_record.get_slice(
				"::", dependency_record.get_slice_count("::") - 1
			)
			var lower_path: String = dependency_path.to_lower()
			if lower_path.ends_with(".glb") or lower_path.ends_with(".gltf") or lower_path.ends_with(".blend"):
				forbidden_source_dependency = true
			if dependency_path.begins_with("res://") and not visited.has(dependency_path):
				pending.append(dependency_path)
	var obstacle_source: String = _read_text_file(WORLD_OBSTACLE_SCRIPT_PATH)
	_check(
		ATLAS_PATH in obstacle_source,
		"Obstacle runtime explicitly owns the packed district-atlas dependency"
	)
	_check(not forbidden_source_dependency, "World runtime graph contains no GLTF, GLB, or Blender source dependency")
	var individual_frames_are_runtime_dependencies: bool = false
	for frame_path: String in EXPECTED_FRAME_PATHS:
		if visited.has(frame_path):
			individual_frames_are_runtime_dependencies = true
	_check(not individual_frames_are_runtime_dependencies, "Runtime uses the packed atlas instead of eight loose source frames")
	# Godot 4.7 does not report preloads inside .gd files through
	# ResourceLoader.get_dependencies(). Verify the actual source dependency;
	# the world-instantiation gate below separately proves the atlas loads.
	var chunk_source: String = _read_text_file(BACKGROUND_CHUNK_SCRIPT_PATH)
	_check(
		ATLAS_PATH in chunk_source and "preload" in chunk_source,
		"Background custom-draw chunk directly preloads the district atlas"
	)


func _validate_export_closure() -> void:
	var parsed: Variant = JSON.parse_string(_read_text_file(EXPORT_CLOSURE_PATH))
	_check(parsed is Dictionary, "Runtime export closure parses as JSON")
	if not (parsed is Dictionary):
		return
	var resources: Array = _as_array((parsed as Dictionary).get("resources", []))
	var paths: Dictionary = {}
	var atlas_entries: int = 0
	var forbidden_source_entry: bool = false
	for resource_variant: Variant in resources:
		if not (resource_variant is Dictionary):
			continue
		var path: String = String((resource_variant as Dictionary).get("path", ""))
		paths[path] = true
		atlas_entries += 1 if path == ATLAS_PATH else 0
		var lower_path: String = path.to_lower()
		if lower_path.ends_with(".glb") or lower_path.ends_with(".gltf") or lower_path.ends_with(".blend"):
			forbidden_source_entry = true
	_check(
		resources.size() == EXPECTED_EXPORT_RESOURCE_COUNT,
		"Export closure contains exactly %d runtime resources" % EXPECTED_EXPORT_RESOURCE_COUNT
	)
	_check(paths.size() == resources.size(), "Export closure contains no duplicate resource paths")
	_check(atlas_entries == 1, "Export closure contains the district atlas exactly once")
	_check(not forbidden_source_entry, "Export closure excludes all source meshes and Blender workshops")

	var packed_scene: PackedScene = load(EXPORT_DEPENDENCY_SCENE_PATH) as PackedScene
	_check(packed_scene != null, "Runtime export dependency scene loads")
	if packed_scene == null:
		return
	var dependency_root: Node = packed_scene.instantiate()
	var dependencies_variant: Variant = dependency_root.get_meta("export_dependencies", [])
	var dependencies: Array = _as_array(dependencies_variant)
	var dependency_has_atlas: bool = false
	for resource_variant: Variant in dependencies:
		var resource: Resource = resource_variant as Resource
		if resource != null and resource.resource_path == ATLAS_PATH:
			dependency_has_atlas = true
	_check(
		int(dependency_root.get_meta("export_dependency_count", -1)) == EXPECTED_EXPORT_DEPENDENCY_COUNT
		and dependencies.size() == EXPECTED_EXPORT_DEPENDENCY_COUNT,
		"Export dependency scene metadata and resource array both contain %d entries"
		% EXPECTED_EXPORT_DEPENDENCY_COUNT
	)
	_check(dependency_has_atlas, "Export dependency scene strongly references the district atlas")
	dependency_root.free()


func _validate_world_integration(world_map: BesprenWorldMap2D) -> void:
	_check(not _contains_node_3d(world_map), "District integration remains exclusively 2D")
	var family_counts: Dictionary = {}
	var family_parents: Dictionary = {}
	for family: String in EXPECTED_DISTRICT_FAMILY_COUNTS:
		family_counts[family] = 0
		family_parents[family] = {}
	var district_sprite_count: int = 0
	var named_district_sprite_count: int = 0
	var every_sprite_is_styled: bool = true
	var every_sprite_region_is_manifested: bool = true
	var every_parent_collision_is_active: bool = true
	var material_ids: Dictionary = {}
	for obstacle: WorldObstacle2D in world_map.get_obstacle_nodes():
		for child: Node in obstacle.get_children():
			var sprite: Sprite2D = child as Sprite2D
			if sprite == null:
				continue
			var child_name: String = String(sprite.name)
			if child_name.begins_with("ImportedDistrict"):
				named_district_sprite_count += 1
			if _texture_source_path(sprite.texture) != ATLAS_PATH:
				continue
			district_sprite_count += 1
			var family: String = _district_family(child_name)
			if family.is_empty() or not family_counts.has(family):
				every_sprite_is_styled = false
			else:
				family_counts[family] = int(family_counts[family]) + 1
				(family_parents[family] as Dictionary)[String(obstacle.name)] = true
			var frame: AtlasTexture = sprite.texture as AtlasTexture
			if frame == null or not _manifest_regions.has(frame.region):
				every_sprite_region_is_manifested = false
			var finish: ShaderMaterial = sprite.material as ShaderMaterial
			if (
				sprite.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				or finish == null
				or finish.shader == null
				or finish.shader.resource_path != SLEEK_SPRITE_SHADER_PATH
			):
				every_sprite_is_styled = false
			else:
				material_ids[finish.get_instance_id()] = true
			var collision: CollisionShape2D = obstacle.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if (
				not (obstacle is StaticBody2D)
				or obstacle.collision_layer != 2
				or collision == null
				or collision.shape == null
				or collision.disabled
			):
				every_parent_collision_is_active = false
	_check(district_sprite_count == 16, "Exactly 16 colliding-obstacle district sprites are integrated")
	_check(named_district_sprite_count == district_sprite_count, "Every ImportedDistrict child is backed by the packed district atlas")
	var family_counts_are_exact: bool = true
	var family_parents_are_exact: bool = true
	for family: String in EXPECTED_DISTRICT_FAMILY_COUNTS:
		if int(family_counts.get(family, 0)) != int(EXPECTED_DISTRICT_FAMILY_COUNTS[family]):
			family_counts_are_exact = false
		var found_parents: Dictionary = family_parents.get(family, {}) as Dictionary
		var expected_parents: Array = EXPECTED_DISTRICT_PARENTS[family] as Array
		if found_parents.size() != expected_parents.size():
			family_parents_are_exact = false
		for expected_parent: String in expected_parents:
			if not found_parents.has(expected_parent):
				family_parents_are_exact = false
	_check(family_counts_are_exact, "District facade, gate, vehicle, aircon, bench, and stove family counts are exact")
	_check(family_parents_are_exact, "District sprites occupy only the reviewed city, mall, village, vehicle, and camp footprints")
	_check(every_sprite_region_is_manifested, "Every runtime AtlasTexture region matches a manifest frame")
	_check(every_sprite_is_styled, "Every district sprite uses mipmapped filtering and the sleek sprite shader")
	_check(material_ids.size() >= 1 and material_ids.size() <= 2, "District sprites reuse at most the shared urban and forest finish materials")
	_check(every_parent_collision_is_active, "Every colliding district sprite retains its parent WorldStatic collision")
	_validate_background_furniture(world_map)


func _validate_background_furniture(world_map: BesprenWorldMap2D) -> void:
	var decor: WorldBackgroundDecor2D = world_map.get_node_or_null("BackgroundDecor") as WorldBackgroundDecor2D
	_check(decor != null, "World exposes the deterministic background decor layer")
	if decor == null:
		return
	_check(
		decor.get_decoration_count() == EXPECTED_BACKGROUND_DECOR_COUNT
		and decor.get_chunked_decoration_count() == EXPECTED_BACKGROUND_DECOR_COUNT,
		"Background decoration remains exactly 1100 authored and chunked marks"
	)
	_check(decor.has_method(&"get_prop_kinds"), "Background decor exposes read-only deterministic prop kinds")
	var prop_kinds_variant: Variant = decor.call(&"get_prop_kinds") if decor.has_method(&"get_prop_kinds") else PackedInt32Array()
	var prop_kinds: PackedInt32Array = PackedInt32Array()
	if prop_kinds_variant is PackedInt32Array:
		prop_kinds = prop_kinds_variant
	var seating_count: int = prop_kinds.count(STREET_SEATING_KIND)
	var hydrant_count: int = prop_kinds.count(FIRE_HYDRANT_KIND)
	var stove_count: int = prop_kinds.count(BARREL_STOVE_KIND)
	_check(prop_kinds.size() == EXPECTED_BACKGROUND_PROP_COUNT, "Background retains exactly 420 deterministic props")
	_check(seating_count == EXPECTED_STREET_SEATING_COUNT, "Background contains exactly 75 Poly Haven street benches")
	_check(hydrant_count == EXPECTED_FIRE_HYDRANT_COUNT, "Background contains exactly 46 Poly Haven fire hydrants")
	_check(stove_count == EXPECTED_BARREL_STOVE_COUNT, "Background contains exactly 34 Poly Haven barrel stoves")

	var shared_material: Material = null
	var chunks_are_sleek_and_shared: bool = not decor.get_render_chunks().is_empty()
	for chunk: WorldBackgroundDecorChunk2D in decor.get_render_chunks():
		var finish: ShaderMaterial = chunk.material as ShaderMaterial
		if (
			finish == null
			or finish.shader == null
			or finish.shader.resource_path != SLEEK_CANVAS_SHADER_PATH
		):
			chunks_are_sleek_and_shared = false
		elif shared_material == null:
			shared_material = finish
		elif finish != shared_material:
			chunks_are_sleek_and_shared = false
	_check(chunks_are_sleek_and_shared, "All custom-draw chunks share the sleek canvas-grade material")
	_check(not _contains_sprite_2d(decor), "Hydrants, benches, and stoves remain batched custom-draw furniture")


func _district_family(node_name: String) -> String:
	if node_name.begins_with("ImportedDistrictUrbanBlockVisual"):
		return "urban"
	if node_name.begins_with("ImportedDistrictFactoryBlockVisual"):
		return "factory"
	if node_name.begins_with("ImportedDistrictChainlinkVisual"):
		return "chainlink"
	if node_name.begins_with("ImportedDistrictCoveredCarVisual"):
		return "covered_car"
	if node_name.begins_with("ImportedDistrictAirconVisual"):
		return "aircon"
	if node_name.begins_with("ImportedDistrictBenchVisual"):
		return "bench"
	if node_name.begins_with("ImportedDistrictBarrelStoveVisual"):
		return "barrel_stove"
	return ""


func _measure_frame(image: Image) -> Dictionary:
	var minimum: Vector2i = image.get_size()
	var maximum: Vector2i = Vector2i(-1, -1)
	var visible: int = 0
	var weighted_luma: float = 0.0
	var visible_alpha_sum: float = 0.0
	var total_alpha_sum: float = 0.0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			total_alpha_sum += pixel.a
			if pixel.a > 0.003:
				visible += 1
				minimum.x = mini(minimum.x, x)
				minimum.y = mini(minimum.y, y)
				maximum.x = maxi(maximum.x, x)
				maximum.y = maxi(maximum.y, y)
				weighted_luma += (pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722) * pixel.a
				visible_alpha_sum += pixel.a
	var bounds: Rect2i = Rect2i()
	if maximum.x >= minimum.x:
		bounds = Rect2i(minimum, maximum - minimum + Vector2i.ONE)
	return {
		"content_bounds": bounds,
		"visible_pixel_count": visible,
		"alpha_coverage": total_alpha_sum / float(image.get_width() * image.get_height()),
		"alpha_weighted_luma": weighted_luma / maxf(visible_alpha_sum, 0.0001) * 255.0,
	}


func _minimum_edge_margin(bounds: Rect2i) -> int:
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return -1
	return mini(
		mini(bounds.position.x, bounds.position.y),
		mini(EXPECTED_FRAME_SIZE.x - bounds.end.x, EXPECTED_FRAME_SIZE.y - bounds.end.y)
	)


func _file_record_matches(record: Dictionary, path_key: String = "path") -> bool:
	var path: String = String(record.get(path_key, ""))
	var expected_bytes: int = int(record.get("%s_bytes" % path_key, record.get("bytes", -1)))
	var expected_hash: String = String(record.get("%s_sha256" % path_key, record.get("sha256", ""))).to_lower()
	if path.is_empty() or not FileAccess.file_exists(path) or expected_bytes <= 0 or expected_hash.length() != 64:
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	return (
		file != null
		and file.get_length() == expected_bytes
		and FileAccess.get_sha256(ProjectSettings.globalize_path(path)).to_lower() == expected_hash
	)


func _texture_source_path(texture: Texture2D) -> String:
	if texture == null:
		return ""
	var atlas_texture: AtlasTexture = texture as AtlasTexture
	if atlas_texture != null:
		return atlas_texture.atlas.resource_path if atlas_texture.atlas != null else ""
	return texture.resource_path


func _contains_node_3d(node: Node) -> bool:
	if node is Node3D:
		return true
	for child: Node in node.get_children():
		if _contains_node_3d(child):
			return true
	return false


func _contains_sprite_2d(node: Node) -> bool:
	for child: Node in node.get_children():
		if child is Sprite2D or _contains_sprite_2d(child):
			return true
	return false


func _array_to_rect2(value: Variant) -> Rect2:
	var entries: Array = _as_array(value)
	if entries.size() != 4:
		return Rect2()
	return Rect2(float(entries[0]), float(entries[1]), float(entries[2]), float(entries[3]))


func _array_to_rect2i(value: Variant) -> Rect2i:
	var entries: Array = _as_array(value)
	if entries.size() != 4:
		return Rect2i()
	return Rect2i(int(entries[0]), int(entries[1]), int(entries[2]), int(entries[3]))


func _is_valid_region(value: Variant, atlas_size: Vector2i) -> bool:
	var rect: Rect2 = _array_to_rect2(value)
	return (
		rect.size.x > 0.0
		and rect.size.y > 0.0
		and rect.position.x >= 0.0
		and rect.position.y >= 0.0
		and rect.end.x <= atlas_size.x
		and rect.end.y <= atlas_size.y
	)


func _read_text_file(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


func _as_array(value: Variant) -> Array:
	return value as Array if value is Array else []


func _finish() -> void:
	if _failures == 0:
		print("POLY HAVEN DISTRICT VALIDATION OK (%d checks)" % _checks)
		quit(0)
		return
	push_error("POLY HAVEN DISTRICT VALIDATION FAILED (%d/%d checks failed)" % [_failures, _checks])
	quit(1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS | %s" % message)
		return
	_failures += 1
	push_error("FAIL | %s" % message)
