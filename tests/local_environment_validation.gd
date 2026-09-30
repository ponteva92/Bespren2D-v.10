extends SceneTree
## Focused provenance and runtime gate for the locally baked environment atlas.

const WORLD_MAP_SCENE: PackedScene = preload("res://scenes/world/world_map_2d.tscn")
const WORLD_MAP_SCENE_PATH: String = "res://scenes/world/world_map_2d.tscn"
const MANIFEST_PATH: String = (
	"res://assets/2d/environment/local_baked/local_environment_manifest.json"
)
const ATLAS_PATH: String = (
	"res://assets/2d/environment/local_baked/local_environment_atlas.png"
)
const POLYHAVEN_ATLAS_PATH: String = (
	"res://assets/2d/environment/polyhaven/polyhaven_environment_atlas.png"
)
const LICENSE_EVIDENCE_PATH: String = "res://assets/licenses/local_baked_environment_sources.md"
const SLEEK_SHADER_PATH: String = "res://shaders/sleek_sprite_finish.gdshader"
const EXPECTED_ATLAS_SIZE: Vector2i = Vector2i(1536, 1536)
const EXPECTED_SOURCE_COUNT: int = 29
const EXPECTED_FRAME_COUNT: int = 16
const EXPECTED_LICENSE_SOURCE_COUNT: int = 6
const EXPECTED_FRAME_SIZE: Vector2i = Vector2i(384, 384)

const CITY_REGIONS: Array[Rect2] = [
	Rect2(33.0, 10.0, 318.0, 359.0),
	Rect2(455.0, 43.0, 242.0, 316.0),
	Rect2(848.0, 11.0, 224.0, 346.0),
	Rect2(1198.0, 24.0, 298.0, 332.0),
]
const MALL_REGION: Rect2 = Rect2(21.0, 419.0, 342.0, 318.0)
const INDUSTRIAL_REGION: Rect2 = Rect2(400.0, 416.0, 352.0, 324.0)
const VILLAGE_WEST_REGION: Rect2 = Rect2(832.0, 431.0, 256.0, 312.0)
const VILLAGE_EAST_REGION: Rect2 = Rect2(1226.0, 398.0, 212.0, 330.0)
const VEHICLE_REGION: Rect2 = Rect2(23.0, 837.0, 290.0, 232.0)
const WOOD_BARRICADE_REGION: Rect2 = Rect2(425.0, 784.0, 282.0, 321.0)
const UTILITY_POLE_REGION: Rect2 = Rect2(891.0, 807.0, 153.0, 283.0)
const ROADSIDE_SALVAGE_REGION: Rect2 = Rect2(1188.0, 785.0, 327.0, 352.0)
const ROADSIDE_BARRIER_REGION: Rect2 = Rect2(47.0, 1152.0, 287.0, 374.0)
const CAMP_BEDDING_REGION: Rect2 = Rect2(467.0, 1227.0, 254.0, 246.0)
const CAMP_SUPPLY_REGION: Rect2 = Rect2(810.0, 1229.0, 300.0, 260.0)
const CAMP_MEDICAL_REGION: Rect2 = Rect2(1153.0, 1199.0, 365.0, 292.0)

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
	_validate_atlas_resource(manifest)
	_validate_runtime_dependency_graph()

	var world_map: BesprenWorldMap2D = WORLD_MAP_SCENE.instantiate() as BesprenWorldMap2D
	_check(world_map != null, "World map scene instantiates for local environment validation")
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
	_check(FileAccess.file_exists(MANIFEST_PATH), "Local baked environment manifest exists")
	var manifest_file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	_check(manifest_file != null, "Local baked environment manifest opens for reading")
	if manifest_file == null:
		return {}
	var parsed: Variant = JSON.parse_string(manifest_file.get_as_text())
	_check(parsed is Dictionary, "Local baked environment manifest parses as a JSON object")
	return parsed as Dictionary if parsed is Dictionary else {}


func _validate_manifest(manifest: Dictionary) -> void:
	_check(manifest.get("schema_version", 0) == 1, "Manifest uses schema version 1")
	_check(
		manifest.get("license_evidence", "") == LICENSE_EVIDENCE_PATH
		and FileAccess.file_exists(LICENSE_EVIDENCE_PATH),
		"Manifest links to the local source-license evidence"
	)
	var evidence_text: String = _read_text_file(LICENSE_EVIDENCE_PATH).to_lower()
	_check(
		"cc0" in evidence_text and "mit" in evidence_text,
		"License evidence records the Kenney CC0 and package MIT terms"
	)
	_check(
		"commercial" in evidence_text
		and "forbids repackaging" in evidence_text
		and "do not publish" in evidence_text
		and "never redistribute" in String(manifest.get("usage", "")).to_lower()
		and "as an asset pack" in String(manifest.get("usage", "")).to_lower(),
		"Atomic Realm use and no-repackaging restrictions are explicit"
	)
	_check(
		manifest.get("render_policy", "")
		== "orthographic_rgba_freestyle_agx_mobile_midtones_runtime_grounding",
		"Manifest records the reviewed orthographic RGBA render policy"
	)

	var license_sources: Array = _as_array(manifest.get("license_sources", []))
	var license_records_valid: bool = license_sources.size() == EXPECTED_LICENSE_SOURCE_COUNT
	for record_variant: Variant in license_sources:
		if not (record_variant is Dictionary):
			license_records_valid = false
			continue
		var record: Dictionary = record_variant as Dictionary
		if not _file_record_matches(record):
			license_records_valid = false
	_check(
		license_records_valid,
		"All six upstream license-evidence files match their SHA-256 records"
	)

	var sources: Array = _as_array(manifest.get("source_assets", []))
	var source_paths: Dictionary = {}
	var source_records_valid: bool = sources.size() == EXPECTED_SOURCE_COUNT
	for source_variant: Variant in sources:
		if not (source_variant is Dictionary):
			source_records_valid = false
			continue
		var source: Dictionary = source_variant as Dictionary
		var source_path: String = String(source.get("path", ""))
		source_paths[source_path] = true
		if (
			not source_path.to_lower().ends_with(".glb")
			or String(source.get("license_family", "")) not in [
				"kenney_city_builder_models",
				"atomic_realm_post_apocalyptic",
				"atomic_realm_into_the_wild",
				"atomic_realm_gas_station",
				"atomic_realm_pharmacy",
			]
			or not _file_record_matches(source)
		):
			source_records_valid = false
	_check(sources.size() == EXPECTED_SOURCE_COUNT, "Manifest records exactly 29 reviewed source models")
	_check(source_paths.size() == EXPECTED_SOURCE_COUNT, "All 29 source-model paths are unique")
	_check(source_records_valid, "All 29 source GLBs match their recorded SHA-256 hashes and license families")

	var derived_assets: Array = _as_array(manifest.get("derived_assets", []))
	var derived_keys: Dictionary = {}
	var derived_records_valid: bool = derived_assets.size() == EXPECTED_FRAME_COUNT
	var every_frame_is_rgba: bool = derived_assets.size() == EXPECTED_FRAME_COUNT
	var every_frame_is_readable: bool = derived_assets.size() == EXPECTED_FRAME_COUNT
	for frame_variant: Variant in derived_assets:
		if not (frame_variant is Dictionary):
			derived_records_valid = false
			every_frame_is_rgba = false
			every_frame_is_readable = false
			continue
		var frame: Dictionary = frame_variant as Dictionary
		var frame_key: String = String(frame.get("key", ""))
		var frame_path: String = String(frame.get("path", ""))
		derived_keys[frame_key] = true
		if (
			frame_key.is_empty()
			or not frame_path.to_lower().ends_with(".png")
			or not _file_record_matches(frame)
			or not _is_valid_region(frame.get("padded_atlas_region", []), EXPECTED_ATLAS_SIZE)
		):
			derived_records_valid = false
		if float(frame.get("alpha_weighted_luma", 0.0)) < 50.0:
			every_frame_is_readable = false
		var frame_texture: Texture2D = load(frame_path) as Texture2D
		var image: Image = frame_texture.get_image() if frame_texture != null else null
		if (
			image == null
			or Vector2i(image.get_width(), image.get_height()) != EXPECTED_FRAME_SIZE
			or image.get_format() != Image.FORMAT_RGBA8
		):
			every_frame_is_rgba = false
	_check(derived_assets.size() == EXPECTED_FRAME_COUNT, "Manifest records exactly 16 derived environment frames")
	_check(derived_keys.size() == EXPECTED_FRAME_COUNT, "All 16 derived frame keys are unique")
	_check(
		derived_keys.has_all(["camp_bedding", "camp_supply_cache", "camp_medical_cache"]),
		"The three free atlas cells contain the reviewed camp-satellite composites"
	)
	_check(derived_records_valid, "Every derived frame has a matching hash and bounded atlas region")
	_check(every_frame_is_rgba, "Every derived frame is a 384x384 RGBA8 PNG")
	_check(every_frame_is_readable, "Every derived frame records alpha-weighted luma of at least 50")


func _validate_atlas_resource(manifest: Dictionary) -> void:
	var atlas_record_variant: Variant = manifest.get("atlas", {})
	var atlas_record: Dictionary = (
		atlas_record_variant as Dictionary if atlas_record_variant is Dictionary else {}
	)
	var size: Array = _as_array(atlas_record.get("size", []))
	var manifest_size_matches: bool = (
		size.size() == 2
		and int(size[0]) == EXPECTED_ATLAS_SIZE.x
		and int(size[1]) == EXPECTED_ATLAS_SIZE.y
	)
	_check(
		atlas_record.get("path", "") == ATLAS_PATH
		and manifest_size_matches
		and _file_record_matches(atlas_record),
		"Manifest identifies the exact 1536x1536 atlas path and SHA-256"
	)
	var atlas: Texture2D = load(ATLAS_PATH) as Texture2D
	_check(atlas != null, "Local environment atlas imports as Texture2D")
	if atlas != null:
		_check(atlas.resource_path == ATLAS_PATH, "Imported atlas retains its canonical resource path")
		_check(
			Vector2i(atlas.get_width(), atlas.get_height()) == EXPECTED_ATLAS_SIZE,
			"Imported local environment atlas is exactly 1536x1536"
		)


func _validate_runtime_dependency_graph() -> void:
	var pending: Array[String] = [WORLD_MAP_SCENE_PATH]
	var visited: Dictionary = {}
	var contains_glb: bool = false
	while not pending.is_empty():
		var resource_path: String = pending.pop_back()
		if visited.has(resource_path):
			continue
		visited[resource_path] = true
		for dependency_record: String in ResourceLoader.get_dependencies(resource_path):
			var dependency_path: String = dependency_record.get_slice("::", dependency_record.get_slice_count("::") - 1)
			if dependency_path.to_lower().ends_with(".glb") or ".glb::" in dependency_record.to_lower():
				contains_glb = true
			if dependency_path.begins_with("res://") and not visited.has(dependency_path):
				pending.append(dependency_path)
	_check(not contains_glb, "World-map runtime dependency graph contains no source GLB")


func _validate_world_integration(world_map: BesprenWorldMap2D) -> void:
	var obstacles: Array[WorldObstacle2D] = world_map.get_obstacle_nodes()
	_check(not obstacles.is_empty(), "World exposes authored obstacle records")
	_check(not _contains_node_3d(world_map), "Local baked integration instantiates no Node3D")

	# Counted by authored name, not by visual kind. The districts later grew a
	# "Dense..." filler family that reuses CITY_BUILDING and VILLAGE_HOUSE, so a
	# raw kind tally now says 19 and 12 and would move again with the next block
	# of dressing. The named set is what this gate is actually about; the filler
	# is still held to the region, scale, shader and collision checks below.
	var city_count: int = 0
	var mall_count: int = 0
	var village_west_count: int = 0
	var village_east_count: int = 0
	var fence_count: int = 0
	var utility_count: int = 0
	var local_car_count: int = 0
	var local_barrier_count: int = 0
	var poly_barrier_count: int = 0
	var camp_bedding_count: int = 0
	var camp_supply_count: int = 0
	var camp_medical_count: int = 0
	var city_regions_found: Dictionary = {}
	var every_category_visual_is_complete: bool = true
	var every_local_region_is_correct: bool = true
	var every_local_sprite_is_styled: bool = true
	var every_adjusted_local_scale_is_exact: bool = true
	var every_palette_grade_is_bounded: bool = true
	var every_target_collision_is_active: bool = true
	var local_sprite_count: int = 0
	var forest_material: Material = null
	var urban_material: Material = null
	var forest_material_is_shared: bool = true
	var urban_material_is_shared: bool = true

	for obstacle: WorldObstacle2D in obstacles:
		var kind: int = obstacle.get_visual_kind()
		var targeted: bool = kind in [
			WorldObstacle2D.VisualKind.CITY_BUILDING,
			WorldObstacle2D.VisualKind.MALL_SHELL,
			WorldObstacle2D.VisualKind.VILLAGE_HOUSE,
			WorldObstacle2D.VisualKind.VEHICLE_WRECK,
			WorldObstacle2D.VisualKind.WOODEN_FENCE,
			WorldObstacle2D.VisualKind.UTILITY_POLE,
			WorldObstacle2D.VisualKind.CAMP_BEDDING,
			WorldObstacle2D.VisualKind.CAMP_SUPPLY_CACHE,
			WorldObstacle2D.VisualKind.CAMP_MEDICAL_CACHE,
		]
		if not targeted:
			continue
		var collision: CollisionShape2D = obstacle.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if (
			collision == null or collision.shape == null or collision.disabled
			or obstacle.collision_layer != 2
		):
			every_target_collision_is_active = false

		var local_sprites: Array[Sprite2D] = _get_sprites_from_atlas(obstacle, ATLAS_PATH)
		var poly_sprites: Array[Sprite2D] = _get_sprites_from_atlas(obstacle, POLYHAVEN_ATLAS_PATH)
		for sprite: Sprite2D in local_sprites:
			local_sprite_count += 1
			if not _sprite_has_local_render_contract(sprite):
				every_local_sprite_is_styled = false
			var forest_finish: bool = (
				kind == WorldObstacle2D.VisualKind.WOODEN_FENCE
				or kind == WorldObstacle2D.VisualKind.UTILITY_POLE
				or kind == WorldObstacle2D.VisualKind.CAMP_BEDDING
				or kind == WorldObstacle2D.VisualKind.CAMP_SUPPLY_CACHE
				or kind == WorldObstacle2D.VisualKind.CAMP_MEDICAL_CACHE
				or (kind == WorldObstacle2D.VisualKind.VILLAGE_HOUSE and String(obstacle.name).begins_with("West"))
			)
			if forest_finish:
				if forest_material == null:
					forest_material = sprite.material
				elif sprite.material != forest_material:
					forest_material_is_shared = false
			else:
				if urban_material == null:
					urban_material = sprite.material
				elif sprite.material != urban_material:
					urban_material_is_shared = false
			var finish: ShaderMaterial = sprite.material as ShaderMaterial
			var expected_cohesion: float = 0.10 if forest_finish else 0.12
			if (
				finish == null
				or not is_equal_approx(
					float(finish.get_shader_parameter(&"palette_cohesion")),
					expected_cohesion
				)
			):
				every_palette_grade_is_bounded = false

		match kind:
			WorldObstacle2D.VisualKind.CITY_BUILDING:
				city_count += 1 if String(obstacle.name).begins_with("CityBuilding_") else 0
				var district_replacement: bool = String(obstacle.name) in [
					"CityBuilding_04", "CityBuilding_05"
				]
				if district_replacement:
					if not local_sprites.is_empty():
						every_category_visual_is_complete = false
						every_local_region_is_correct = false
				elif local_sprites.size() != 1 or local_sprites[0].name != &"ImportedLocalCityVisual":
					every_category_visual_is_complete = false
				elif _region_in(local_sprites[0], CITY_REGIONS):
					city_regions_found[_region_key(_get_region(local_sprites[0]))] = true
				else:
					every_local_region_is_correct = false
			WorldObstacle2D.VisualKind.MALL_SHELL:
				mall_count += 1
				if not _validate_mall_visuals(obstacle, local_sprites):
					every_category_visual_is_complete = false
					every_local_region_is_correct = false
			WorldObstacle2D.VisualKind.VILLAGE_HOUSE:
				var west: bool = String(obstacle.name).begins_with("West")
				var authored_house: bool = String(obstacle.name).contains("VillageHouse_")
				village_west_count += 1 if west and authored_house else 0
				village_east_count += 1 if not west and authored_house else 0
				var village_region: Rect2 = VILLAGE_WEST_REGION if west else VILLAGE_EAST_REGION
				if (
					local_sprites.size() != 1
					or local_sprites[0].name != &"ImportedVillageHouseVisual"
					or _get_region(local_sprites[0]) != village_region
				):
					every_category_visual_is_complete = false
					every_local_region_is_correct = false
			WorldObstacle2D.VisualKind.VEHICLE_WRECK:
				if obstacle.has_node("ImportedVehicleWreckVisual"):
					local_car_count += 1
					if local_sprites.size() != 1 or _get_region(local_sprites[0]) != VEHICLE_REGION:
						every_local_region_is_correct = false
					elif not is_equal_approx(
						float(local_sprites[0].texture.get_width()) * local_sprites[0].scale.x,
						obstacle.half_size.x * WorldObstacle2D.VEHICLE_WRECK_VISUAL_WIDTH_FACTOR
					):
						every_adjusted_local_scale_is_exact = false
				elif obstacle.has_node("ImportedRoadsideBarrierVisual"):
					local_barrier_count += 1
					if local_sprites.size() != 1 or _get_region(local_sprites[0]) != ROADSIDE_BARRIER_REGION:
						every_local_region_is_correct = false
					elif not is_equal_approx(
						float(local_sprites[0].texture.get_width()) * local_sprites[0].scale.x,
						obstacle.half_size.x * WorldObstacle2D.ROADSIDE_BARRIER_VISUAL_WIDTH_FACTOR
					):
						every_adjusted_local_scale_is_exact = false
				elif obstacle.has_node("ImportedConcreteBarrierVisual"):
					poly_barrier_count += 1
					if not local_sprites.is_empty() or poly_sprites.size() != 1:
						every_local_region_is_correct = false
				elif obstacle.has_node("ImportedDistrictCoveredCarVisual"):
					# The district-focused validator owns this reviewed replacement;
					# this local-atlas gate only proves it did not masquerade as a
					# local or first-generation Poly Haven frame.
					if not local_sprites.is_empty() or not poly_sprites.is_empty():
						every_local_region_is_correct = false
				else:
					every_category_visual_is_complete = false
			WorldObstacle2D.VisualKind.WOODEN_FENCE:
				fence_count += 1
				if local_sprites.size() < 2:
					every_category_visual_is_complete = false
				for sprite: Sprite2D in local_sprites:
					if (
						not String(sprite.name).begins_with("ImportedBarricadeSegment_")
						or _get_region(sprite) != WOOD_BARRICADE_REGION
					):
						every_local_region_is_correct = false
					if not is_equal_approx(
						sprite.scale.y / maxf(sprite.scale.x, 0.0001),
						WorldObstacle2D.FENCE_SEGMENT_VISUAL_HEIGHT_FACTOR
					):
						every_adjusted_local_scale_is_exact = false
			WorldObstacle2D.VisualKind.UTILITY_POLE:
				utility_count += 1
				if (
					local_sprites.size() != 1
					or local_sprites[0].name != &"ImportedUtilityPoleVisual"
					or _get_region(local_sprites[0]) != UTILITY_POLE_REGION
				):
					every_category_visual_is_complete = false
					every_local_region_is_correct = false
				elif not is_equal_approx(
					float(local_sprites[0].texture.get_width()) * local_sprites[0].scale.x,
					obstacle.collision_radius * WorldObstacle2D.UTILITY_POLE_VISUAL_WIDTH_FACTOR
				):
					every_adjusted_local_scale_is_exact = false
			WorldObstacle2D.VisualKind.CAMP_BEDDING:
				camp_bedding_count += 1
				if not _validate_single_camp_visual(
					obstacle,
					local_sprites,
					&"ImportedCampBeddingVisual",
					CAMP_BEDDING_REGION,
					WorldObstacle2D.CAMP_BEDDING_VISUAL_WIDTH_FACTOR
				):
					every_category_visual_is_complete = false
					every_local_region_is_correct = false
					every_adjusted_local_scale_is_exact = false
			WorldObstacle2D.VisualKind.CAMP_SUPPLY_CACHE:
				camp_supply_count += 1
				if not _validate_single_camp_visual(
					obstacle,
					local_sprites,
					&"ImportedCampSupplyVisual",
					CAMP_SUPPLY_REGION,
					WorldObstacle2D.CAMP_SUPPLY_VISUAL_WIDTH_FACTOR
				):
					every_category_visual_is_complete = false
					every_local_region_is_correct = false
					every_adjusted_local_scale_is_exact = false
			WorldObstacle2D.VisualKind.CAMP_MEDICAL_CACHE:
				camp_medical_count += 1
				if not _validate_single_camp_visual(
					obstacle,
					local_sprites,
					&"ImportedCampMedicalVisual",
					CAMP_MEDICAL_REGION,
					WorldObstacle2D.CAMP_MEDICAL_VISUAL_WIDTH_FACTOR
				):
					every_category_visual_is_complete = false
					every_local_region_is_correct = false
					every_adjusted_local_scale_is_exact = false

	_check(city_count == 6, "All six authored city buildings are present")
	_check(city_regions_found.size() == 4, "The four legacy city buildings retain all four local ruin regions")
	_check(mall_count == 4, "All four mall shell and pylon obstacles are present")
	_check(
		village_west_count == 4 and village_east_count == 4,
		"West and east villages each contain four distinct authored local houses"
	)
	_check(fence_count == 12, "Both villages contain all twelve authored fence obstacles")
	_check(utility_count == 10, "Both villages contain all ten authored utility poles")
	_check(local_car_count > 0, "At least one vehicle footprint uses the local car wreck")
	_check(local_barrier_count > 0, "At least one vehicle footprint uses the local roadside barrier")
	_check(poly_barrier_count > 0, "Poly Haven concrete-barrier variants remain present and separate")
	_check(
		camp_bedding_count == 1 and camp_supply_count == 1 and camp_medical_count == 1,
		"The forest clearing contains exactly one bedding, supply, and medical satellite"
	)
	_check(local_sprite_count > 0, "World instantiates locally baked Sprite2D visuals")
	_check(every_category_visual_is_complete, "Every targeted obstacle owns its complete named local visual set")
	_check(every_local_region_is_correct, "Every local visual uses the exact reviewed atlas region; Poly Haven variants are excluded")
	_check(every_local_sprite_is_styled, "Every local visual uses AtlasTexture, LINEAR_WITH_MIPMAPS, and the sleek shader")
	_check(every_adjusted_local_scale_is_exact, "Vehicles, fences, poles, and camp satellites use the reviewed scale constants")
	_check(every_palette_grade_is_bounded, "Every local sprite uses the bounded forest or urban palette-cohesion grade")
	_check(
		WorldObstacle2D.MALL_FOUNDATION_SHADOW_ALPHA <= 0.15
		and WorldObstacle2D.MALL_FOUNDATION_SHADOW_OFFSET.length() < Vector2(42.0, 58.0).length(),
		"Mall foundation shadow uses the compact low-alpha runtime treatment"
	)
	_check(every_target_collision_is_active, "Every targeted obstacle retains active world-static collision")
	_check(forest_material != null and forest_material_is_shared, "All forest-finish local sprites share one ShaderMaterial")
	_check(urban_material != null and urban_material_is_shared, "All urban-finish local sprites share one ShaderMaterial")
	_check(forest_material != urban_material, "Forest and urban local sprite finishes remain distinct")


func _validate_mall_visuals(obstacle: WorldObstacle2D, sprites: Array[Sprite2D]) -> bool:
	var long_shell: bool = String(obstacle.name) in ["OstariNorthShell", "OstariSouthShell"]
	if not long_shell:
		return (
			sprites.size() == 1
			and sprites[0].name == &"ImportedIndustrialPylonVisual"
			and _get_region(sprites[0]) in [MALL_REGION, INDUSTRIAL_REGION]
		)
	# Each long shell now mixes one local mall module, one local industrial
	# module, one district urban module, and one district factory module. The
	# district validator owns the latter pair and aircon; this gate proves the
	# local half plus salvage remain exact.
	if sprites.size() != 3 or not obstacle.has_node("ImportedMallSalvageVisual"):
		return false
	var local_module_regions: Dictionary = {}
	var local_module_count: int = 0
	for sprite: Sprite2D in sprites:
		if not String(sprite.name).begins_with("ImportedMallModule_"):
			continue
		var region: Rect2 = _get_region(sprite)
		if region not in [MALL_REGION, INDUSTRIAL_REGION]:
			return false
		local_module_count += 1
		local_module_regions[_region_key(region)] = true
	var salvage: Sprite2D = obstacle.get_node("ImportedMallSalvageVisual") as Sprite2D
	return (
		local_module_count == 2
		and local_module_regions.size() == 2
		and salvage != null
		and _get_region(salvage) == ROADSIDE_SALVAGE_REGION
	)


func _validate_single_camp_visual(
	obstacle: WorldObstacle2D,
	sprites: Array[Sprite2D],
	visual_name: StringName,
	region: Rect2,
	width_factor: float
) -> bool:
	if sprites.size() != 1 or sprites[0].name != visual_name:
		return false
	return (
		_get_region(sprites[0]) == region
		and is_equal_approx(
			float(sprites[0].texture.get_width()) * sprites[0].scale.x,
			obstacle.half_size.x * 2.0 * width_factor
		)
	)


func _get_sprites_from_atlas(obstacle: WorldObstacle2D, atlas_path: String) -> Array[Sprite2D]:
	var sprites: Array[Sprite2D] = []
	for child: Node in obstacle.get_children():
		var sprite: Sprite2D = child as Sprite2D
		if sprite == null:
			continue
		var frame: AtlasTexture = sprite.texture as AtlasTexture
		if frame != null and frame.atlas != null and frame.atlas.resource_path == atlas_path:
			sprites.append(sprite)
	return sprites


func _sprite_has_local_render_contract(sprite: Sprite2D) -> bool:
	var frame: AtlasTexture = sprite.texture as AtlasTexture
	var finish: ShaderMaterial = sprite.material as ShaderMaterial
	return (
		frame != null
		and frame.atlas != null
		and frame.atlas.resource_path == ATLAS_PATH
		and frame.region.position.x >= 0.0
		and frame.region.position.y >= 0.0
		and frame.region.end.x <= EXPECTED_ATLAS_SIZE.x
		and frame.region.end.y <= EXPECTED_ATLAS_SIZE.y
		and sprite.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		and finish != null
		and finish.shader != null
		and finish.shader.resource_path == SLEEK_SHADER_PATH
	)


func _get_region(sprite: Sprite2D) -> Rect2:
	var frame: AtlasTexture = sprite.texture as AtlasTexture
	return frame.region if frame != null else Rect2()


func _region_in(sprite: Sprite2D, regions: Array[Rect2]) -> bool:
	return _get_region(sprite) in regions


func _region_key(region: Rect2) -> String:
	return "%d,%d,%d,%d" % [region.position.x, region.position.y, region.size.x, region.size.y]


func _file_record_matches(record: Dictionary) -> bool:
	var path: String = String(record.get("path", ""))
	var expected_hash: String = String(record.get("sha256", "")).to_lower()
	return (
		not path.is_empty()
		and FileAccess.file_exists(path)
		and expected_hash.length() == 64
		and FileAccess.get_sha256(path).to_lower() == expected_hash
	)


func _read_text_file(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


func _as_array(value: Variant) -> Array:
	return value as Array if value is Array else []


func _is_valid_region(region_variant: Variant, atlas_size: Vector2i) -> bool:
	var region: Array = _as_array(region_variant)
	if region.size() != 4:
		return false
	var rect: Rect2 = Rect2(float(region[0]), float(region[1]), float(region[2]), float(region[3]))
	return (
		rect.position.x >= 0.0
		and rect.position.y >= 0.0
		and rect.size.x > 0.0
		and rect.size.y > 0.0
		and rect.end.x <= atlas_size.x
		and rect.end.y <= atlas_size.y
	)


func _contains_node_3d(node: Node) -> bool:
	if node is Node3D:
		return true
	for child: Node in node.get_children():
		if _contains_node_3d(child):
			return true
	return false


func _finish() -> void:
	if _failures == 0:
		print("LOCAL ENVIRONMENT VALIDATION OK (%d checks)" % _checks)
		quit(0)
		return
	push_error(
		"LOCAL ENVIRONMENT VALIDATION FAILED (%d/%d checks failed)"
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
