extends SceneTree
## Focused provenance, atlas, shader, and collision gate for Poly Haven environment sprites.

const WORLD_MAP_SCENE: PackedScene = preload("res://scenes/world/world_map_2d.tscn")
const MANIFEST_PATH: String = (
	"res://assets/2d/environment/polyhaven/polyhaven_asset_manifest.json"
)
const ATLAS_PATH: String = (
	"res://assets/2d/environment/polyhaven/polyhaven_environment_atlas.png"
)
const LICENSE_EVIDENCE_PATH: String = "res://assets/licenses/polyhaven_cc0.md"
const SLEEK_SHADER_PATH: String = "res://shaders/sleek_sprite_finish.gdshader"
const EXPECTED_ATLAS_SIZE: Vector2i = Vector2i(1536, 1152)
const EXPECTED_SOURCE_IDS: Array[String] = [
	"tree_stump_01",
	"dead_tree_trunk",
	"rock_moss_set_01",
	"metal_trash_can",
	"concrete_road_barrier",
	"old_tyre",
]
const EXPECTED_SOURCE_COUNT: int = 6
const EXPECTED_FRAME_COUNT: int = 12

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
	_validate_atlas_resource()

	var world_map: BesprenWorldMap2D = WORLD_MAP_SCENE.instantiate() as BesprenWorldMap2D
	_check(world_map != null, "World map scene instantiates for Poly Haven validation")
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
	_check(FileAccess.file_exists(MANIFEST_PATH), "Poly Haven provenance manifest exists")
	var manifest_file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	_check(manifest_file != null, "Poly Haven provenance manifest opens for reading")
	if manifest_file == null:
		return {}
	var parsed: Variant = JSON.parse_string(manifest_file.get_as_text())
	_check(parsed is Dictionary, "Poly Haven provenance manifest parses as a JSON object")
	if not (parsed is Dictionary):
		return {}
	return parsed as Dictionary


func _validate_manifest(manifest: Dictionary) -> void:
	_check(manifest.get("schema_version", 0) == 1, "Manifest uses schema version 1")
	_check(manifest.get("license", "") == "CC0-1.0", "Manifest declares the Poly Haven assets as CC0-1.0")
	_check(
		manifest.get("license_url", "") == "https://polyhaven.com/license",
		"Manifest records the canonical Poly Haven license URL"
	)
	_check(
		manifest.get("license_evidence", "") == LICENSE_EVIDENCE_PATH
		and FileAccess.file_exists(LICENSE_EVIDENCE_PATH),
		"Manifest links to local CC0 license evidence"
	)

	var sources_variant: Variant = manifest.get("source_assets", [])
	var sources: Array = sources_variant as Array if sources_variant is Array else []
	_check(sources.size() == EXPECTED_SOURCE_COUNT, "Manifest records exactly six Poly Haven source models")
	var found_source_ids: Dictionary = {}
	var every_source_is_valid: bool = sources.size() == EXPECTED_SOURCE_COUNT
	for source_variant: Variant in sources:
		if not (source_variant is Dictionary):
			every_source_is_valid = false
			continue
		var source: Dictionary = source_variant as Dictionary
		var source_id: String = String(source.get("id", ""))
		found_source_ids[source_id] = true
		if (
			source_id.is_empty()
			or source.get("license", "") != "CC0-1.0"
			or source.get("format", "") != "gltf"
			or source.get("resolution", "") != "1k"
			or source.get("type", "") != "model"
			or source.get("url", "") != "https://polyhaven.com/a/%s" % source_id
		):
			every_source_is_valid = false
	_check(every_source_is_valid, "Every source records its CC0, 1k GLTF model provenance")
	var source_set_is_exact: bool = found_source_ids.size() == EXPECTED_SOURCE_IDS.size()
	for expected_source_id: String in EXPECTED_SOURCE_IDS:
		if not found_source_ids.has(expected_source_id):
			source_set_is_exact = false
	_check(source_set_is_exact, "Manifest source IDs match the six reviewed Poly Haven models")

	var derived_variant: Variant = manifest.get("derived_assets", [])
	var derived_assets: Array = derived_variant as Array if derived_variant is Array else []
	_check(derived_assets.size() == EXPECTED_FRAME_COUNT, "Manifest records all twelve rendered atlas frames")
	var frame_keys: Dictionary = {}
	var every_frame_is_valid: bool = derived_assets.size() == EXPECTED_FRAME_COUNT
	for frame_variant: Variant in derived_assets:
		if not (frame_variant is Dictionary):
			every_frame_is_valid = false
			continue
		var frame: Dictionary = frame_variant as Dictionary
		var frame_key: String = String(frame.get("key", ""))
		var frame_path: String = String(frame.get("path", ""))
		var frame_hash: String = String(frame.get("sha256", ""))
		var source_id: String = String(frame.get("source_id", ""))
		frame_keys[frame_key] = true
		if (
			frame_key.is_empty()
			or not FileAccess.file_exists(frame_path)
			or frame_hash.length() != 64
			or not found_source_ids.has(source_id)
			or not _is_valid_region(frame.get("padded_atlas_region", []), EXPECTED_ATLAS_SIZE)
		):
			every_frame_is_valid = false
	_check(frame_keys.size() == EXPECTED_FRAME_COUNT, "All twelve derived frame keys are unique")
	_check(every_frame_is_valid, "Every derived frame has source linkage, SHA-256, file, and bounded atlas region")

	var atlas_variant: Variant = manifest.get("atlas", {})
	var atlas: Dictionary = atlas_variant as Dictionary if atlas_variant is Dictionary else {}
	var atlas_size_variant: Variant = atlas.get("size", [])
	var atlas_size: Array = atlas_size_variant as Array if atlas_size_variant is Array else []
	var manifest_atlas_size_matches: bool = (
		atlas_size.size() == 2
		and int(atlas_size[0]) == EXPECTED_ATLAS_SIZE.x
		and int(atlas_size[1]) == EXPECTED_ATLAS_SIZE.y
	)
	_check(
		atlas.get("path", "") == ATLAS_PATH
		and manifest_atlas_size_matches
		and String(atlas.get("sha256", "")).length() == 64,
		"Manifest identifies the 1536x1152 atlas and its SHA-256"
	)


func _validate_atlas_resource() -> void:
	_check(FileAccess.file_exists(ATLAS_PATH), "Poly Haven environment atlas exists")
	var atlas: Texture2D = load(ATLAS_PATH) as Texture2D
	_check(atlas != null, "Poly Haven environment atlas imports as Texture2D")
	if atlas == null:
		return
	_check(atlas.resource_path == ATLAS_PATH, "Imported atlas retains its canonical resource path")
	_check(
		Vector2i(atlas.get_width(), atlas.get_height()) == EXPECTED_ATLAS_SIZE,
		"Imported Poly Haven atlas is exactly 1536x1152"
	)


func _validate_world_integration(world_map: BesprenWorldMap2D) -> void:
	var obstacles: Array[WorldObstacle2D] = world_map.get_obstacle_nodes()
	_check(not obstacles.is_empty(), "World exposes authored obstacle records")
	_check(not _contains_node_3d(world_map), "Poly Haven integration remains exclusively 2D")

	var relevant_kind_counts: Dictionary[int, int] = {
		WorldObstacle2D.VisualKind.MOSSY_ROCK: 0,
		WorldObstacle2D.VisualKind.FALLEN_LOG: 0,
		WorldObstacle2D.VisualKind.SCRAP_PILE: 0,
	}
	var every_relevant_count_matches: bool = true
	var every_relevant_collision_is_active: bool = true
	var every_imported_texture_is_atlased: bool = true
	var every_region_is_bounded: bool = true
	var every_sprite_uses_mipmapped_linear_filter: bool = true
	var every_sprite_uses_sleek_shader: bool = true
	var every_adjusted_prop_scale_is_exact: bool = true
	var every_palette_grade_is_bounded: bool = true
	var forest_material: Material = null
	var urban_material: Material = null
	var forest_material_is_shared: bool = true
	var urban_material_is_shared: bool = true
	var imported_sprite_count: int = 0
	var barrier_count: int = 0

	for obstacle: WorldObstacle2D in obstacles:
		var visual_kind: int = obstacle.get_visual_kind()
		var expected_visual_count: int = 0
		var relevant: bool = relevant_kind_counts.has(visual_kind)
		if relevant:
			relevant_kind_counts[visual_kind] = relevant_kind_counts[visual_kind] + 1
			expected_visual_count = 2 if visual_kind == WorldObstacle2D.VisualKind.SCRAP_PILE else 1
		var imported_sprites: Array[Sprite2D] = _get_polyhaven_sprites(obstacle)
		var is_barrier_variant: bool = obstacle.has_node("ImportedConcreteBarrierVisual")
		if is_barrier_variant:
			barrier_count += 1
			expected_visual_count = 1
			relevant = true
		if not relevant:
			continue
		if (
			imported_sprites.size() != expected_visual_count
			or obstacle.get_imported_visual_count() != expected_visual_count
		):
			every_relevant_count_matches = false
		var collision: CollisionShape2D = obstacle.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision == null or collision.shape == null or collision.disabled:
			every_relevant_collision_is_active = false
		for sprite: Sprite2D in imported_sprites:
			imported_sprite_count += 1
			var atlas_frame: AtlasTexture = sprite.texture as AtlasTexture
			if (
				atlas_frame == null
				or atlas_frame.atlas == null
				or atlas_frame.atlas.resource_path != ATLAS_PATH
			):
				every_imported_texture_is_atlased = false
			else:
				var region: Rect2 = atlas_frame.region
				if (
					region.size.x <= 0.0
					or region.size.y <= 0.0
					or region.position.x < 0.0
					or region.position.y < 0.0
					or region.end.x > EXPECTED_ATLAS_SIZE.x
					or region.end.y > EXPECTED_ATLAS_SIZE.y
				):
					every_region_is_bounded = false
			if sprite.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS:
				every_sprite_uses_mipmapped_linear_filter = false
			var shader_material: ShaderMaterial = sprite.material as ShaderMaterial
			if (
				shader_material == null
				or shader_material.shader == null
				or shader_material.shader.resource_path != SLEEK_SHADER_PATH
			):
				every_sprite_uses_sleek_shader = false
			var forest_sprite: bool = (
				visual_kind == WorldObstacle2D.VisualKind.MOSSY_ROCK
				or visual_kind == WorldObstacle2D.VisualKind.FALLEN_LOG
			)
			var expected_cohesion: float = 0.10 if forest_sprite else 0.12
			if (
				shader_material == null
				or not is_equal_approx(
					float(shader_material.get_shader_parameter(&"palette_cohesion")),
					expected_cohesion
				)
			):
				every_palette_grade_is_bounded = false
			var rendered_span: float = maxf(
				float(sprite.texture.get_width()) * absf(sprite.scale.x),
				float(sprite.texture.get_height()) * absf(sprite.scale.y)
			)
			if visual_kind == WorldObstacle2D.VisualKind.MOSSY_ROCK:
				if not is_equal_approx(
					rendered_span,
					obstacle.collision_radius * WorldObstacle2D.MOSSY_ROCK_VISUAL_SPAN_FACTOR
				):
					every_adjusted_prop_scale_is_exact = false
			elif is_barrier_variant:
				var collision_span: float = maxf(
					obstacle.half_size.x * 2.0,
					obstacle.half_size.y * 2.0
				)
				if not is_equal_approx(
					rendered_span,
					collision_span * WorldObstacle2D.CONCRETE_BARRIER_VISUAL_SPAN_FACTOR
				):
					every_adjusted_prop_scale_is_exact = false
			if forest_sprite:
				if forest_material == null:
					forest_material = sprite.material
				elif sprite.material != forest_material:
					forest_material_is_shared = false
			else:
				if urban_material == null:
					urban_material = sprite.material
				elif sprite.material != urban_material:
					urban_material_is_shared = false

	_check(relevant_kind_counts[WorldObstacle2D.VisualKind.MOSSY_ROCK] > 0, "World contains imported moss-rock or stump obstacles")
	_check(relevant_kind_counts[WorldObstacle2D.VisualKind.FALLEN_LOG] > 0, "World contains imported fallen-log obstacles")
	_check(relevant_kind_counts[WorldObstacle2D.VisualKind.SCRAP_PILE] > 0, "World contains imported scrap clusters")
	_check(barrier_count > 0, "At least one vehicle-wreck footprint uses the concrete barrier variant")
	_check(imported_sprite_count > 0, "World instantiates Poly Haven Sprite2D visuals")
	_check(every_relevant_count_matches, "Every rock, log, scrap, and barrier owns its complete imported visual set")
	_check(every_relevant_collision_is_active, "Every Poly Haven obstacle retains an active CollisionShape2D")
	_check(every_imported_texture_is_atlased, "Every Poly Haven visual is an AtlasTexture backed by the single environment atlas")
	_check(every_region_is_bounded, "Every runtime AtlasTexture region remains within the atlas")
	_check(every_sprite_uses_mipmapped_linear_filter, "Every Poly Haven sprite uses LINEAR_WITH_MIPMAPS filtering")
	_check(every_sprite_uses_sleek_shader, "Every Poly Haven sprite uses sleek_sprite_finish.gdshader")
	_check(every_adjusted_prop_scale_is_exact, "Rock and concrete-barrier sprites use the reviewed collision-relative scale constants")
	_check(every_palette_grade_is_bounded, "Every Poly Haven sprite uses the bounded forest or urban palette-cohesion grade")
	_check(forest_material != null and forest_material_is_shared, "Forest sprites share one sleek finish material")
	_check(urban_material != null and urban_material_is_shared, "Urban sprites share one sleek finish material")


func _get_polyhaven_sprites(obstacle: WorldObstacle2D) -> Array[Sprite2D]:
	var sprites: Array[Sprite2D] = []
	for child: Node in obstacle.get_children():
		var sprite: Sprite2D = child as Sprite2D
		if sprite == null or not String(sprite.name).begins_with("Imported"):
			continue
		# ImportedTreeVisual uses the separate licensed tree atlas and is outside this gate.
		if sprite.name == &"ImportedTreeVisual":
			continue
		sprites.append(sprite)
	return sprites


func _contains_node_3d(node: Node) -> bool:
	if node is Node3D:
		return true
	for child: Node in node.get_children():
		if _contains_node_3d(child):
			return true
	return false


func _is_valid_region(region_variant: Variant, atlas_size: Vector2i) -> bool:
	if not (region_variant is Array):
		return false
	var region: Array = region_variant as Array
	if region.size() != 4:
		return false
	var position: Vector2 = Vector2(float(region[0]), float(region[1]))
	var size: Vector2 = Vector2(float(region[2]), float(region[3]))
	return (
		position.x >= 0.0
		and position.y >= 0.0
		and size.x > 0.0
		and size.y > 0.0
		and position.x + size.x <= atlas_size.x
		and position.y + size.y <= atlas_size.y
	)


func _finish() -> void:
	if _failures == 0:
		print("POLY HAVEN ENVIRONMENT VALIDATION OK (%d checks)" % _checks)
		quit(0)
		return
	push_error(
		"POLY HAVEN ENVIRONMENT VALIDATION FAILED (%d/%d checks failed)"
		% [_failures, _checks]
	)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS | %s" % message)
		return
	_failures += 1
	push_error("FAIL | %s" % message)
