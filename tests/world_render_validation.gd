extends Node2D
## GPU capture gate for tactical overview plus city and Ostari gameplay-scale details.

const NETWORK_PLAYER_SCENE: PackedScene = preload("res://scenes/characters/network_player.tscn")
const OVERVIEW_PATH: String = "res://artifacts/world_overview_validation.png"
const CITY_PATH: String = "res://artifacts/world_city_validation.png"
const MALL_PATH: String = "res://artifacts/world_mall_validation.png"
const CAMP_PATH: String = "res://artifacts/world_forest_camp_validation.png"
const NIGHT_CAMP_PATH: String = "res://artifacts/world_forest_camp_night_validation.png"
const CAMP_COMPOSITION_PATH: String = (
	"res://artifacts/world_forest_camp_composition_validation.png"
)
const NIGHT_CAMP_COMPOSITION_PATH: String = (
	"res://artifacts/world_forest_camp_composition_night_validation.png"
)
const CITY_SALVAGE_PATH: String = "res://artifacts/world_city_salvage_validation.png"
const CITY_BARRIER_PATH: String = "res://artifacts/world_city_barrier_validation.png"
const FOREST_ROCK_PATH: String = "res://artifacts/world_forest_rock_validation.png"
const FOREST_LOG_PATH: String = "res://artifacts/world_forest_log_validation.png"
const NIGHT_CITY_BARRIER_PATH: String = "res://artifacts/world_city_barrier_night_validation.png"
const CITY_BUILDING_DETAIL_PATH: String = (
	"res://artifacts/world_city_building_detail_validation.png"
)
const MALL_LONG_SHELL_PATH: String = "res://artifacts/world_mall_long_shell_validation.png"
const WEST_VILLAGE_PATH: String = "res://artifacts/world_west_village_validation.png"
const EAST_VILLAGE_PATH: String = "res://artifacts/world_east_village_validation.png"
const LOCAL_CAR_WRECK_PATH: String = "res://artifacts/world_local_car_wreck_validation.png"
const NIGHT_WEST_VILLAGE_PATH: String = (
	"res://artifacts/world_west_village_night_validation.png"
)
const CITY_FOREST_TRANSITION_PATH: String = (
	"res://artifacts/world_city_forest_transition_validation.png"
)
const CENTRAL_ROAD_SHOULDER_PATH: String = (
	"res://artifacts/world_central_road_shoulder_validation.png"
)
const CITY_DENSITY_PATH: String = "res://artifacts/world_city_density_validation.png"
const FOREST_DENSITY_PATH: String = "res://artifacts/world_forest_density_validation.png"
const WILDERNESS_DENSITY_PATH: String = "res://artifacts/world_wilderness_density_validation.png"
const WILDERNESS_ECOLOGY_GAMEPLAY_PATH: String = (
	"res://artifacts/world_wilderness_ecology_gameplay_validation.png"
)
const NIGHT_WILDERNESS_ECOLOGY_GAMEPLAY_PATH: String = (
	"res://artifacts/world_wilderness_ecology_gameplay_night_validation.png"
)
const METADATA_PATH: String = "res://artifacts/world_render_validation.json"

const CITY_SALVAGE_POSITION: Vector2 = Vector2(-9800.0, -9000.0) # CityScrapPile_00
const CITY_BARRIER_POSITION: Vector2 = Vector2(-8650.0, -3900.0) # CityVehicleWreck_02
const FOREST_ROCK_POSITION: Vector2 = Vector2(-11900.0, 6200.0) # MossyRock_01
const FOREST_LOG_POSITION: Vector2 = Vector2(-11600.0, 5300.0) # FallenLog_05
const CITY_BUILDING_DETAIL_POSITION: Vector2 = Vector2(-11000.0, -7900.0) # CityBuilding_02
const MALL_LONG_SHELL_POSITION: Vector2 = Vector2(4850.0, -7900.0) # OstariNorthShell
const WEST_VILLAGE_POSITION: Vector2 = Vector2(-9600.0, 6700.0)
const EAST_VILLAGE_POSITION: Vector2 = Vector2(6450.0, 6700.0)
const LOCAL_CAR_WRECK_POSITION: Vector2 = Vector2(-7700.0, -6900.0) # CityVehicleWreck_01
const CITY_FOREST_TRANSITION_POSITION: Vector2 = Vector2(-6000.0, -2100.0)
const CENTRAL_ROAD_SHOULDER_POSITION: Vector2 = Vector2(2100.0, 0.0)
const CITY_DENSITY_POSITION: Vector2 = Vector2(-9200.0, -6000.0)
const FOREST_DENSITY_POSITION: Vector2 = Vector2(-12600.0, 2600.0)
const WILDERNESS_DENSITY_POSITION: Vector2 = Vector2(-5200.0, 1800.0)
const WILDERNESS_ECOLOGY_GAMEPLAY_POSITION: Vector2 = Vector2(-5200.0, 1800.0)
const GAMEPLAY_CAMERA_ZOOM: float = 0.38

@onready var camera: Camera2D = %ValidationCamera
@onready var validation_lighting: CanvasModulate = %ValidationLighting
@onready var y_sort_world: Node2D = $YSortWorld
@onready var world_map: BesprenWorldMap2D = $YSortWorld/WorldMap2D as BesprenWorldMap2D


func _ready() -> void:
	_spawn_wilderness_scale_references()
	await get_tree().process_frame
	await _capture_view(Vector2.ZERO, Vector2.ONE * 0.00915, OVERVIEW_PATH)
	await _capture_view(Vector2(-8150.0, -7900.0), Vector2.ONE * 0.055, CITY_PATH)
	await _capture_view(Vector2(4850.0, -5500.0), Vector2.ONE * 0.18, MALL_PATH)
	await _capture_view(BesprenWorldMap2D.STARTING_CAMP_POSITION, Vector2.ONE * 0.45, CAMP_PATH)
	await _capture_view(
		BesprenWorldMap2D.STARTING_CAMP_POSITION,
		Vector2.ONE * 0.22,
		CAMP_COMPOSITION_PATH
	)
	await _capture_view(CITY_SALVAGE_POSITION, Vector2.ONE * 0.45, CITY_SALVAGE_PATH)
	await _capture_view(CITY_BARRIER_POSITION, Vector2.ONE * 0.35, CITY_BARRIER_PATH)
	await _capture_view(FOREST_ROCK_POSITION, Vector2.ONE * 0.35, FOREST_ROCK_PATH)
	await _capture_view(FOREST_LOG_POSITION, Vector2.ONE * 0.35, FOREST_LOG_PATH)
	await _capture_view(
		CITY_BUILDING_DETAIL_POSITION,
		Vector2.ONE * 0.12,
		CITY_BUILDING_DETAIL_PATH
	)
	await _capture_view(MALL_LONG_SHELL_POSITION, Vector2.ONE * 0.065, MALL_LONG_SHELL_PATH)
	await _capture_view(WEST_VILLAGE_POSITION, Vector2.ONE * 0.14, WEST_VILLAGE_PATH)
	await _capture_view(EAST_VILLAGE_POSITION, Vector2.ONE * 0.14, EAST_VILLAGE_PATH)
	await _capture_view(LOCAL_CAR_WRECK_POSITION, Vector2.ONE * 0.45, LOCAL_CAR_WRECK_PATH)
	await _capture_view(
		CITY_FOREST_TRANSITION_POSITION,
		Vector2.ONE * 0.18,
		CITY_FOREST_TRANSITION_PATH
	)
	await _capture_view(
		CENTRAL_ROAD_SHOULDER_POSITION,
		Vector2.ONE * 0.18,
		CENTRAL_ROAD_SHOULDER_PATH
	)
	await _capture_view(CITY_DENSITY_POSITION, Vector2.ONE * 0.18, CITY_DENSITY_PATH)
	await _capture_view(FOREST_DENSITY_POSITION, Vector2.ONE * 0.18, FOREST_DENSITY_PATH)
	await _capture_view(WILDERNESS_DENSITY_POSITION, Vector2.ONE * 0.18, WILDERNESS_DENSITY_PATH)
	await _capture_view(
		WILDERNESS_ECOLOGY_GAMEPLAY_POSITION,
		Vector2.ONE * GAMEPLAY_CAMERA_ZOOM,
		WILDERNESS_ECOLOGY_GAMEPLAY_PATH
	)
	validation_lighting.color = NightAtmosphere2D.SAPPHIRE_NIGHT_COLOR
	await _capture_view(BesprenWorldMap2D.STARTING_CAMP_POSITION, Vector2.ONE * 0.45, NIGHT_CAMP_PATH)
	await _capture_view(
		BesprenWorldMap2D.STARTING_CAMP_POSITION,
		Vector2.ONE * 0.22,
		NIGHT_CAMP_COMPOSITION_PATH
	)
	await _capture_view(CITY_BARRIER_POSITION, Vector2.ONE * 0.35, NIGHT_CITY_BARRIER_PATH)
	await _capture_view(WEST_VILLAGE_POSITION, Vector2.ONE * 0.14, NIGHT_WEST_VILLAGE_PATH)
	await _capture_view(
		WILDERNESS_ECOLOGY_GAMEPLAY_POSITION,
		Vector2.ONE * GAMEPLAY_CAMERA_ZOOM,
		NIGHT_WILDERNESS_ECOLOGY_GAMEPLAY_PATH
	)
	validation_lighting.color = Color.WHITE
	var metadata: Dictionary = {
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"logical_size": [
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"),
		],
		"world_size": [BesprenWorldMap2D.WORLD_SIZE, BesprenWorldMap2D.WORLD_SIZE],
		"wilderness_accent_evidence": _get_wilderness_accent_evidence(),
		"capture_count": 25,
		"outputs": [
			OVERVIEW_PATH,
			CITY_PATH,
			MALL_PATH,
			CAMP_PATH,
			CAMP_COMPOSITION_PATH,
			CITY_SALVAGE_PATH,
			CITY_BARRIER_PATH,
			FOREST_ROCK_PATH,
			FOREST_LOG_PATH,
			CITY_BUILDING_DETAIL_PATH,
			MALL_LONG_SHELL_PATH,
			WEST_VILLAGE_PATH,
			EAST_VILLAGE_PATH,
			LOCAL_CAR_WRECK_PATH,
			CITY_FOREST_TRANSITION_PATH,
			CENTRAL_ROAD_SHOULDER_PATH,
			CITY_DENSITY_PATH,
			FOREST_DENSITY_PATH,
			WILDERNESS_DENSITY_PATH,
			WILDERNESS_ECOLOGY_GAMEPLAY_PATH,
			NIGHT_CAMP_PATH,
			NIGHT_CAMP_COMPOSITION_PATH,
			NIGHT_CITY_BARRIER_PATH,
			NIGHT_WEST_VILLAGE_PATH,
			NIGHT_WILDERNESS_ECOLOGY_GAMEPLAY_PATH,
		],
		"focused_prop_views": {
			"city_salvage": {
				"camera_position": [CITY_SALVAGE_POSITION.x, CITY_SALVAGE_POSITION.y],
				"zoom": 0.45,
				"authored_obstacles": ["CityScrapPile_00"],
				"lighting": "day",
				"output": CITY_SALVAGE_PATH,
			},
			"city_barrier": {
				"camera_position": [CITY_BARRIER_POSITION.x, CITY_BARRIER_POSITION.y],
				"zoom": 0.35,
				"authored_obstacles": ["CityVehicleWreck_02"],
				"lighting": "day",
				"output": CITY_BARRIER_PATH,
			},
			"forest_rock": {
				"camera_position": [FOREST_ROCK_POSITION.x, FOREST_ROCK_POSITION.y],
				"zoom": 0.35,
				"authored_obstacles": ["MossyRock_01"],
				"lighting": "day",
				"output": FOREST_ROCK_PATH,
			},
			"forest_log": {
				"camera_position": [FOREST_LOG_POSITION.x, FOREST_LOG_POSITION.y],
				"zoom": 0.35,
				"authored_obstacles": ["FallenLog_05"],
				"lighting": "day",
				"output": FOREST_LOG_PATH,
			},
			"night_city_barrier": {
				"camera_position": [CITY_BARRIER_POSITION.x, CITY_BARRIER_POSITION.y],
				"zoom": 0.35,
				"authored_obstacles": ["CityVehicleWreck_02"],
				"lighting": "sapphire_night",
				"output": NIGHT_CITY_BARRIER_PATH,
			},
			"city_building_detail": {
				"camera_position": [
					CITY_BUILDING_DETAIL_POSITION.x,
					CITY_BUILDING_DETAIL_POSITION.y,
				],
				"zoom": 0.12,
				"authored_obstacles": ["CityBuilding_02"],
				"authored_obstacle_positions": {"CityBuilding_02": [-11000.0, -7900.0]},
				"lighting": "day",
				"output": CITY_BUILDING_DETAIL_PATH,
			},
			"mall_long_shell": {
				"camera_position": [MALL_LONG_SHELL_POSITION.x, MALL_LONG_SHELL_POSITION.y],
				"zoom": 0.065,
				"authored_obstacles": ["OstariNorthShell"],
				"authored_obstacle_positions": {"OstariNorthShell": [4850.0, -7900.0]},
				"expected_imported_children": [
					"ImportedMallModule_00",
					"ImportedMallModule_01",
					"ImportedMallModule_02",
					"ImportedMallModule_03",
					"ImportedMallSalvageVisual",
				],
				"lighting": "day",
				"output": MALL_LONG_SHELL_PATH,
			},
			"west_village_composition": {
				"camera_position": [WEST_VILLAGE_POSITION.x, WEST_VILLAGE_POSITION.y],
				"zoom": 0.14,
				"authored_obstacles": [
					"WestVillageHouse_00",
					"WestVillageFence_01",
					"WestUtilityPole_00",
				],
				"authored_obstacle_positions": {
					"WestVillageHouse_00": [-10800.0, 6900.0],
					"WestVillageFence_01": [-9900.0, 7000.0],
					"WestUtilityPole_00": [-8470.0, 6400.0],
				},
				"lighting": "day",
				"output": WEST_VILLAGE_PATH,
			},
			"east_village_composition": {
				"camera_position": [EAST_VILLAGE_POSITION.x, EAST_VILLAGE_POSITION.y],
				"zoom": 0.14,
				"authored_obstacles": [
					"EastVillageHouse_00",
					"EastVillageFence_00",
					"EastUtilityPole_00",
				],
				"authored_obstacle_positions": {
					"EastVillageHouse_00": [5300.0, 6900.0],
					"EastVillageFence_00": [6200.0, 7000.0],
					"EastUtilityPole_00": [7630.0, 6400.0],
				},
				"lighting": "day",
				"output": EAST_VILLAGE_PATH,
			},
			"local_car_wreck": {
				"camera_position": [LOCAL_CAR_WRECK_POSITION.x, LOCAL_CAR_WRECK_POSITION.y],
				"zoom": 0.45,
				"authored_obstacles": ["CityVehicleWreck_01"],
				"authored_obstacle_positions": {"CityVehicleWreck_01": [-7700.0, -6900.0]},
				"expected_imported_children": ["ImportedVehicleWreckVisual"],
				"lighting": "day",
				"output": LOCAL_CAR_WRECK_PATH,
			},
			"night_west_village_composition": {
				"camera_position": [WEST_VILLAGE_POSITION.x, WEST_VILLAGE_POSITION.y],
				"zoom": 0.14,
				"authored_obstacles": [
					"WestVillageHouse_00",
					"WestVillageFence_01",
					"WestUtilityPole_00",
				],
				"authored_obstacle_positions": {
					"WestVillageHouse_00": [-10800.0, 6900.0],
					"WestVillageFence_01": [-9900.0, 7000.0],
					"WestUtilityPole_00": [-8470.0, 6400.0],
				},
				"lighting": "sapphire_night",
				"output": NIGHT_WEST_VILLAGE_PATH,
			},
			"camp_satellite_composition": {
				"camera_position": [
					BesprenWorldMap2D.STARTING_CAMP_POSITION.x,
					BesprenWorldMap2D.STARTING_CAMP_POSITION.y,
				],
				"zoom": 0.22,
				"authored_obstacles": [
					"StartingCampBedding",
					"StartingCampSupplyCache",
					"StartingCampMedicalCache",
				],
				"lighting": "day",
				"output": CAMP_COMPOSITION_PATH,
			},
			"night_camp_satellite_composition": {
				"camera_position": [
					BesprenWorldMap2D.STARTING_CAMP_POSITION.x,
					BesprenWorldMap2D.STARTING_CAMP_POSITION.y,
				],
				"zoom": 0.22,
				"authored_obstacles": [
					"StartingCampBedding",
					"StartingCampSupplyCache",
					"StartingCampMedicalCache",
				],
				"lighting": "sapphire_night",
				"output": NIGHT_CAMP_COMPOSITION_PATH,
			},
		},
		"focused_terrain_views": {
			"city_forest_transition": {
				"camera_position": [
					CITY_FOREST_TRANSITION_POSITION.x,
					CITY_FOREST_TRANSITION_POSITION.y,
				],
				"zoom": 0.18,
				"lighting": "day",
				"intent": "organic city-to-wilderness material blend",
				"output": CITY_FOREST_TRANSITION_PATH,
			},
			"central_road_shoulder": {
				"camera_position": [
					CENTRAL_ROAD_SHOULDER_POSITION.x,
					CENTRAL_ROAD_SHOULDER_POSITION.y,
				],
				"zoom": 0.18,
				"lighting": "day",
				"intent": "asphalt shoulder frequency and terrain readability",
				"output": CENTRAL_ROAD_SHOULDER_PATH,
			},
		},
		"density_views": {
			"city_ruin_density": {
				"camera_position": [CITY_DENSITY_POSITION.x, CITY_DENSITY_POSITION.y],
				"zoom": 0.18,
				"intent": "layered non-colliding ruin and prop silhouettes",
				"output": CITY_DENSITY_PATH,
			},
			"forest_density": {
				"camera_position": [FOREST_DENSITY_POSITION.x, FOREST_DENSITY_POSITION.y],
				"zoom": 0.18,
				"intent": "dense visual canopy groups beyond the road shoulder",
				"output": FOREST_DENSITY_PATH,
			},
			"wilderness_density": {
				"camera_position": [WILDERNESS_DENSITY_POSITION.x, WILDERNESS_DENSITY_POSITION.y],
				"zoom": 0.18,
				"intent": "open-world props without blocking the central route",
				"output": WILDERNESS_DENSITY_PATH,
			},
			"wilderness_ecology_gameplay_scale": {
				"camera_position": [
					WILDERNESS_ECOLOGY_GAMEPLAY_POSITION.x,
					WILDERNESS_ECOLOGY_GAMEPLAY_POSITION.y,
				],
				"zoom": GAMEPLAY_CAMERA_ZOOM,
				"lighting": "day",
				"intent": "WildernessAccent low-profile CC0 moss-rock strata at live player camera scale",
				"scale_references": ["baked_heikki", "t1_kinetic"],
				"output": WILDERNESS_ECOLOGY_GAMEPLAY_PATH,
			},
			"wilderness_ecology_gameplay_scale_night": {
				"camera_position": [
					WILDERNESS_ECOLOGY_GAMEPLAY_POSITION.x,
					WILDERNESS_ECOLOGY_GAMEPLAY_POSITION.y,
				],
				"zoom": GAMEPLAY_CAMERA_ZOOM,
				"lighting": "sapphire_night",
				"intent": "WildernessAccent readability beneath the night grade at live player camera scale",
				"scale_references": ["baked_heikki", "t1_kinetic"],
				"output": NIGHT_WILDERNESS_ECOLOGY_GAMEPLAY_PATH,
			},
		},
	}
	var metadata_file: FileAccess = FileAccess.open(METADATA_PATH, FileAccess.WRITE)
	if metadata_file == null:
		push_error("WORLD RENDER FAILED: could not write metadata")
		get_tree().quit(1)
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()
	print(
		"WORLD RENDER OK | method=%s | driver=%s | captures=25"
		% [
			RenderingServer.get_current_rendering_method(),
			RenderingServer.get_current_rendering_driver_name(),
		]
	)
	get_tree().quit(0)


func _spawn_wilderness_scale_references() -> void:
	var player: Node2D = NETWORK_PLAYER_SCENE.instantiate() as Node2D
	if player == null:
		push_error("WORLD RENDER FAILED: could not instantiate validation player")
		get_tree().quit(1)
		return
	player.call(
		&"configure",
		1,
		&"heikki",
		WILDERNESS_ECOLOGY_GAMEPLAY_POSITION + Vector2(-108.0, 42.0),
		false
	)
	y_sort_world.add_child(player)
	player.call(&"set_aim_direction", Vector2.RIGHT, false)
	var kinetic_definition: StructureDefinition = StructureCatalog.get_definition(StructureCatalog.T1_KINETIC)
	if kinetic_definition == null:
		push_error("WORLD RENDER FAILED: missing T1 Kinetic definition")
		get_tree().quit(1)
		return
	var structure: PlacedStructure2D = PlacedStructure2D.new()
	structure.configure(
		9001,
		kinetic_definition,
		1,
		WILDERNESS_ECOLOGY_GAMEPLAY_POSITION + Vector2(108.0, 42.0),
		false
	)
	y_sort_world.add_child(structure)


func _get_wilderness_accent_evidence() -> Dictionary:
	if world_map == null:
		return {"available": false}
	var accent: Node2D = world_map.get_node_or_null("WildernessAccent") as Node2D
	if accent == null:
		return {"available": false}
	var positions_variant: Variant = accent.call(&"get_anchor_positions")
	var spans_variant: Variant = accent.call(&"get_anchor_spans")
	var radii_variant: Variant = accent.call(&"get_anchor_visual_radii")
	var positions: PackedVector2Array = PackedVector2Array()
	var spans: PackedFloat32Array = PackedFloat32Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	if positions_variant is PackedVector2Array:
		positions = positions_variant
	if spans_variant is PackedFloat32Array:
		spans = spans_variant
	if radii_variant is PackedFloat32Array:
		radii = radii_variant
	if positions.size() != spans.size() or positions.size() != radii.size():
		return {"available": false, "reason": "accent_arrays_mismatch"}
	var anchors: Array[Dictionary] = []
	for anchor_index: int in range(positions.size()):
		anchors.append({
			"position": [positions[anchor_index].x, positions[anchor_index].y],
			"span": spans[anchor_index],
			"visual_radius": radii[anchor_index],
		})
	return {
		"available": true,
		"anchor_count": positions.size(),
		"anchors": anchors,
		"z_index": accent.z_index,
		"texture_filter": "linear_mipmaps",
	}


func _capture_view(camera_position: Vector2, camera_zoom: Vector2, output_path: String) -> void:
	camera.position = camera_position
	camera.zoom = camera_zoom
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("WORLD RENDER FAILED: empty viewport for %s" % output_path)
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
		push_error("WORLD RENDER FAILED: %s (%s)" % [output_path, error_string(save_error)])
		get_tree().quit(1)
