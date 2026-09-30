extends SceneTree

const FLOW_WALK_STEP_LENGTH: float = 16.0
const FLOW_WALK_STEP_LIMIT: int = 1200
const FLOW_ARRIVAL_DISTANCE: float = 120.0
## Headless integration smoke gate for Bespren's gameplay and rendering patch pass.

const EXPECTED_STARTING_CAMP_POSITION: Vector2 = Vector2(9950.0, 2400.0)
const EXPECTED_STARTER_RESOURCE_OFFSETS: Array[Vector2] = [
	Vector2(390.0, 120.0),
	Vector2(-410.0, 150.0),
	Vector2(130.0, -430.0),
]

const REQUIRED_SCENES: PackedStringArray = [
	"res://scenes/world/base_core.tscn",
	"res://scenes/world/world_map_2d.tscn",
	"res://scenes/world/resource_scatter_2d.tscn",
	"res://scenes/resources/resource_node_wood.tscn",
	"res://scenes/resources/resource_node_metal.tscn",
	"res://scenes/resources/resource_node_tech.tscn",
	"res://scenes/characters/heikki.tscn",
	"res://scenes/characters/shane.tscn",
	"res://scenes/characters/network_player.tscn",
	"res://assets/2d/actors/scenes/hero_heikki.tscn",
	"res://assets/2d/actors/scenes/hero_shane.tscn",
	"res://scenes/combat/player_projectile.tscn",
	"res://scenes/ui/game_hud.tscn",
	"res://scenes/ui/MobileControls.tscn",
	"res://scenes/ui/StartMenu.tscn",
	"res://scenes/game/game_world.tscn",
	"res://scenes/showcase/visual_validation.tscn",
	"res://scenes/main/bespren_foundation.tscn",
]

const REQUIRED_SHADERS: PackedStringArray = [
	"res://shaders/volumetric_aura.gdshader",
	"res://shaders/toon_emissive_outline.gdshader",
	"res://shaders/surface_weathering.gdshader",
	"res://shaders/sleek_sprite_finish.gdshader",
	"res://shaders/sleek_canvas_grade.gdshader",
	"res://shaders/weather_overlay.gdshader",
	"res://shaders/base_scale_glow.gdshader",
	"res://shaders/projectile_glow.gdshader",
	"res://shaders/terrain_material_blend.gdshader",
]

const REQUIRED_RESOURCES: PackedStringArray = [
	"res://assets/2d/characters/heikki_topdown.png",
	"res://assets/2d/characters/shane_topdown.png",
	"res://assets/2d/actors/frames/hero_heikki_frames.tres",
	"res://assets/2d/actors/frames/hero_shane_frames.tres",
	"res://assets/2d/effects/radial_light.svg",
	"res://assets/2d/effects/radial_light_neutral.svg",
	"res://assets/2d/environment/polyhaven/polyhaven_environment_atlas.png",
	"res://assets/2d/environment/polyhaven_district/polyhaven_district_atlas.png",
	"res://assets/2d/environment/local_baked/local_environment_atlas.png",
	"res://assets/2d/environment/terrain/polyhaven_terrain_atlas.png",
	"res://assets/2d/environment/terrain/bespren_biome_blend_mask.png",
	"res://assets/2d/environment/tiles/bespren_ground_atlas.svg",
	"res://assets/2d/resources/resource_wood.svg",
	"res://assets/2d/resources/resource_metal.svg",
	"res://assets/2d/resources/resource_tech.svg",
	"res://assets/2d/structures/base_camp_topdown.png",
	"res://assets/2d/structures/structure_t1_kinetic.png",
	"res://assets/2d/structures/structure_t1_chemical.png",
	"res://assets/2d/structures/structure_t1_electric.png",
	"res://assets/2d/structures/structure_t1_support.png",
	"res://assets/2d/structures/structure_t1_barricade.png",
	"res://assets/2d/structures/structure_t1_landmine.png",
	"res://assets/2d/structures/structure_t1_razor_snare.png",
	"res://assets/2d/structures/structure_t1_slowing_pit.png",
	"res://assets/sprites/projectile_bullet_strip.png",
	"res://assets/sprites/projectile_tracer.svg",
	"res://assets/tiles/claw_forest_ground.png",
	"res://assets/tiles/claw_forest_trees.png",
	"res://assets/audio/shoot_laser.wav",
	"res://assets/audio/build_placement.ogg",
	"res://assets/audio/harvest_collect.wav",
	"res://assets/audio/ui_click.ogg",
]

const REQUIRED_FILES: PackedStringArray = [
	"res://assets/runtime_asset_manifest.json",
	"res://assets/2d/structures/generated_asset_manifest.json",
	"res://assets/2d/characters/generated_asset_manifest.json",
	"res://assets/licenses/spirit_claw_license.txt",
	"res://assets/licenses/game_component_bundle_mit.txt",
	"res://assets/licenses/kenney_city_builder_mit.md",
	"res://assets/licenses/kenney_city_builder_readme.md",
	"res://assets/licenses/polyhaven_cc0.md",
	"res://assets/licenses/local_baked_environment_sources.md",
	"res://assets/licenses/tower_defense_template_mit.txt",
	"res://assets/2d/environment/polyhaven/polyhaven_asset_manifest.json",
	"res://assets/2d/environment/polyhaven_district/polyhaven_district_manifest.json",
	"res://assets/2d/environment/local_baked/local_environment_manifest.json",
	"res://assets/2d/environment/terrain/polyhaven_terrain_manifest.json",
	"res://tools/art/bake_polyhaven_terrain_materials.py",
	"res://tools/art/render_polyhaven_environment_sprites.py",
	"res://tools/art/render_polyhaven_district_sprites.py",
	"res://tools/art/render_local_environment_sprites.py",
	"res://tools/asset_pipeline/build_polyhaven_environment_atlas.gd",
	"res://tools/asset_pipeline/build_polyhaven_district_atlas.gd",
	"res://tools/asset_pipeline/build_local_environment_atlas.gd",
]

const MANIFEST_PATH: String = "res://assets/runtime_asset_manifest.json"
const DISTRICT_ATLAS_PATH: String = (
	"res://assets/2d/environment/polyhaven_district/polyhaven_district_atlas.png"
)
const PLAYER_TEST_ORIGIN: Vector2 = Vector2(30000.0, 30000.0)
const PLAYER_TEST_TARGET: Vector2 = PLAYER_TEST_ORIGIN + Vector2(50.0, 0.0)
const WORLD_STATIC_LAYER: int = 2
const ENEMY_LAYER: int = 4
const EXPECTED_PLAYER_RADIUS: float = 9.0
const MINIMUM_TOUCH_SIZE: Vector2 = Vector2(44.0, 44.0)

var _checks: int = 0
var _failures: int = 0
var _projectile_impacts: int = 0
var _last_projectile_collider: Node


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_validate_project_configuration()
	_validate_roster()
	_validate_required_resources()
	_validate_runtime_asset_manifest()
	await _validate_physics_player_and_animation()
	_validate_structure_visual_library()
	await _validate_integrated_game_world()
	_finish()


func _validate_project_configuration() -> void:
	_check(
		ProjectSettings.get_setting("rendering/renderer/rendering_method") == "mobile",
		"Mobile renderer is configured"
	)
	_check(
		ProjectSettings.get_setting("display/window/size/viewport_width") == 480,
		"Logical viewport width is 480"
	)
	_check(
		ProjectSettings.get_setting("display/window/size/viewport_height") == 270,
		"Logical viewport height is 270"
	)
	_check(
		ProjectSettings.get_setting("display/window/handheld/orientation") == 0,
		"Android orientation is landscape"
	)
	_check(
		ProjectSettings.get_setting("debug/gdscript/warnings/untyped_declaration") == 2,
		"Untyped declarations are errors"
	)
	_check(
		ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/ui/StartMenu.tscn",
		"Project boots into StartMenu"
	)
	_check(CoopSession.PORT == 8791, "ENet LAN port is fixed at 8791")
	_check(
		CoopSession.PLAYER_COLLISION_RADIUS == EXPECTED_PLAYER_RADIUS,
		"Authority and presentation share the precise radius-9 player collision"
	)
	_check(
		ProjectSettings.get_setting("layer_names/2d_physics/layer_1") == "Players"
		and ProjectSettings.get_setting("layer_names/2d_physics/layer_2") == "WorldStatic"
		and ProjectSettings.get_setting("layer_names/2d_physics/layer_3") == "Enemies",
		"Players, WorldStatic, and Enemies physics layers are named"
	)


func _validate_roster() -> void:
	var roster: LocalCoopRoster = LocalCoopRoster.create_default()
	_check(roster.size() == 2, "Default roster contains two local seats")
	var first_slot: PlayerSlotDefinition = roster.get_slot(1)
	var second_slot: PlayerSlotDefinition = roster.get_slot(2)
	_check(
		first_slot != null and first_slot.display_name == &"Heikki",
		"Seat one is Heikki"
	)
	_check(
		second_slot != null and second_slot.display_name == &"Shane",
		"Seat two is Shane"
	)
	var joy_event: InputEventJoypadButton = InputEventJoypadButton.new()
	joy_event.device = 1
	_check(
		second_slot != null and roster.find_slot_for_event(joy_event) == second_slot,
		"Joypad device one routes only to Shane"
	)


func _validate_required_resources() -> void:
	for resource_path: String in REQUIRED_RESOURCES:
		_check(
			ResourceLoader.exists(resource_path),
			"Runtime resource imports: %s" % resource_path
		)
	for file_path: String in REQUIRED_FILES:
		_check(FileAccess.file_exists(file_path), "Runtime file exists: %s" % file_path)
	for shader_path: String in REQUIRED_SHADERS:
		var shader: Shader = load(shader_path) as Shader
		_check(
			shader != null and not shader.code.is_empty(),
			"Shader loads and compiles: %s" % shader_path
		)
	for scene_path: String in REQUIRED_SCENES:
		var packed_scene: PackedScene = load(scene_path) as PackedScene
		_check(
			packed_scene != null,
			"Scene and dependency graph load: %s" % scene_path
		)


func _validate_runtime_asset_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		_check(false, "Runtime asset manifest can be parsed")
		return
	var parsed_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	_check(parsed_value is Dictionary, "Runtime asset manifest can be parsed")
	if not (parsed_value is Dictionary):
		return
	var manifest: Dictionary = parsed_value as Dictionary
	var summary_value: Variant = manifest.get("summary")
	var entries_value: Variant = manifest.get("runtime_assets")
	_check(
		manifest.get("schema_version") == 1,
		"Runtime asset manifest uses schema version one"
	)
	_check(summary_value is Dictionary, "Runtime asset manifest contains audit totals")
	if summary_value is Dictionary:
		var summary: Dictionary = summary_value as Dictionary
		_check(
			int(summary.get("files_audited", 0)) > 30000
			and int(summary.get("archives_audited", 0)) > 0
			and int(summary.get("archive_members_audited", 0)) > 0,
			"Manifest records the recursive Addons and ZIP audit"
		)
	_check(entries_value is Array, "Runtime asset manifest contains selected assets")
	if not (entries_value is Array):
		return
	var entries: Array = entries_value as Array
	_check(entries.size() == 12, "Manifest records the complete curated runtime set without the retired castle")
	var every_destination_exists: bool = not entries.is_empty()
	var destination_paths: Dictionary[String, bool] = {}
	for entry_value: Variant in entries:
		if not (entry_value is Dictionary):
			every_destination_exists = false
			continue
		var entry: Dictionary = entry_value as Dictionary
		var destination: String = String(entry.get("destination", ""))
		if destination.is_empty() or not FileAccess.file_exists(destination):
			every_destination_exists = false
		destination_paths[destination] = true
	_check(every_destination_exists, "Every manifest destination exists under res://assets")
	_check(
		destination_paths.has("res://assets/tiles/claw_forest_ground.png")
		and destination_paths.has("res://assets/tiles/claw_forest_trees.png")
		and destination_paths.has("res://assets/sprites/projectile_bullet_strip.png")
		and destination_paths.has("res://assets/audio/shoot_laser.wav")
		and destination_paths.has("res://assets/audio/build_placement.ogg")
		and destination_paths.has("res://assets/audio/harvest_collect.wav")
		and destination_paths.has("res://assets/audio/ui_click.ogg"),
		"Manifest covers forest, projectile, and all four audio cues without the retired castle"
	)


func _validate_physics_player_and_animation() -> void:
	var player_scene: PackedScene = load("res://scenes/characters/network_player.tscn") as PackedScene
	_check(player_scene != null, "Physics player scene is available for runtime validation")
	if player_scene == null:
		return
	var player: PlayerAvatar = player_scene.instantiate() as PlayerAvatar
	_check(player != null, "Network player instantiates as PlayerAvatar")
	if player == null:
		return

	var test_wall: StaticBody2D = _create_test_wall(
		PLAYER_TEST_ORIGIN + Vector2(25.0, 0.0),
		Vector2(4.0, 100.0)
	)
	player.configure(99, &"heikki", PLAYER_TEST_ORIGIN, false)
	root.add_child(test_wall)
	root.add_child(player)
	await process_frame
	await physics_frame

	_check(player is CharacterBody2D, "PlayerAvatar is backed by CharacterBody2D physics")
	var collision: CollisionShape2D = player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var circle: CircleShape2D = null
	if collision != null:
		circle = collision.shape as CircleShape2D
	_check(
		collision != null and not collision.disabled and circle != null,
		"Player owns one active CircleShape2D"
	)
	_check(
		circle != null and is_equal_approx(circle.radius, EXPECTED_PLAYER_RADIUS),
		"Player collision radius is exactly nine world units"
	)
	_check(
		player.collision_layer == 1 and player.collision_mask == WORLD_STATIC_LAYER,
		"Player collides from Players layer into WorldStatic"
	)

	var animator: AnimationPlayer = player.get_node_or_null("AnimationPlayer") as AnimationPlayer
	_check(
		animator != null
		and animator.has_animation(PlayerAvatar.IDLE_ANIMATION)
		and animator.has_animation(PlayerAvatar.RUN_ANIMATION),
		"Player animation state machine installs looping Idle and Run clips"
	)
	_check(
		player.get_locomotion_animation() == PlayerAvatar.IDLE_ANIMATION,
		"Stationary player starts in Idle"
	)
	var baked_sprite: AnimatedSprite2D = player.get_presentation_sprite()
	_check(
		player.uses_baked_actor_presentation()
		and baked_sprite != null
		and baked_sprite.sprite_frames != null
		and baked_sprite.scale.is_equal_approx(
			Vector2.ONE * PlayerAvatar.BAKED_ACTOR_VISUAL_SCALE
		)
		and ActorFacing.has_directional_clip(baked_sprite.sprite_frames, &"idle")
		and ActorFacing.has_directional_clip(baked_sprite.sprite_frames, &"run")
		and ActorFacing.has_directional_clip(baked_sprite.sprite_frames, &"shoot")
		and ActorFacing.has_directional_clip(baked_sprite.sprite_frames, &"gather")
		and ActorFacing.has_directional_clip(baked_sprite.sprite_frames, &"hit")
		and ActorFacing.has_directional_clip(baked_sprite.sprite_frames, &"death"),
		"Live player binds the complete eight-direction baked hero presentation"
	)
	_check(
		player.get_presentation_animation()
		== ActorFacing.animation_name(&"idle", ActorFacing.CAMERA_FACING_ROW),
		"Stationary player starts on the camera-facing baked idle row"
	)

	player.apply_authoritative_state(PLAYER_TEST_TARGET, Vector2.RIGHT)
	await physics_frame
	_check(
		player.get_presentation_velocity().length() > 0.0
		and player.get_locomotion_animation() == PlayerAvatar.RUN_ANIMATION,
		"Non-zero authoritative movement switches the player to Run"
	)
	_check(
		player.get_presentation_facing_row() == ActorFacing.row_for_direction(Vector2.RIGHT)
		and player.get_presentation_animation()
		== ActorFacing.animation_name(&"run", player.get_presentation_facing_row()),
		"Authoritative movement selects the matching directional baked run row"
	)
	for _physics_index: int in range(8):
		await physics_frame
	_check(
		player.global_position.x > PLAYER_TEST_ORIGIN.x
		and player.global_position.x < PLAYER_TEST_TARGET.x - 20.0,
		"CharacterBody2D stops at an active StaticBody2D instead of crossing it"
	)
	player.apply_authoritative_state(player.global_position, Vector2.ZERO)
	await physics_frame
	_check(
		player.velocity.is_zero_approx()
		and player.get_locomotion_animation() == PlayerAvatar.IDLE_ANIMATION,
		"Zero movement returns the player to Idle"
	)
	player.set_aim_direction(Vector2.UP, true)
	_check(
		player.get_presentation_facing_row() == ActorFacing.row_for_direction(Vector2.UP)
		and player.get_presentation_animation()
		== ActorFacing.animation_name(&"idle", player.get_presentation_facing_row()),
		"Authoritative assisted aim rotates the baked idle row without changing physics"
	)
	player.play_interaction_feedback(&"fire")
	_check(
		player.get_presentation_animation()
		== ActorFacing.animation_name(&"shoot", player.get_presentation_facing_row()),
		"Authoritative fire feedback uses the matching baked shooting row"
	)
	player.set_combat_state(0, false)
	await physics_frame
	_check(
		not player.is_combat_alive()
		and player.get_presentation_animation()
		== ActorFacing.animation_name(&"death", player.get_presentation_facing_row()),
		"Authoritative death state reaches the baked death row without changing collision ownership"
	)
	var legacy_fallback: PlayerAvatar = player_scene.instantiate() as PlayerAvatar
	if legacy_fallback != null:
		legacy_fallback.force_legacy_presentation = true
		legacy_fallback.configure(100, &"shane", PLAYER_TEST_ORIGIN + Vector2(0.0, 160.0), false)
		root.add_child(legacy_fallback)
		await process_frame
	_check(
		legacy_fallback != null
		and not legacy_fallback.uses_baked_actor_presentation()
		and legacy_fallback.get_presentation_sprite() == null,
		"Malformed-bake recovery retains an explicit local legacy player presentation"
	)

	player.queue_free()
	if legacy_fallback != null:
		legacy_fallback.queue_free()
	test_wall.queue_free()
	await process_frame


func _validate_structure_visual_library() -> void:
	var unique_texture_paths: Dictionary[String, bool] = {}
	var every_structure_matches_navigation_collision: bool = true
	var every_structure_has_sleek_shader: bool = true
	var every_structure_requests_mipmapped_filtering: bool = true
	var every_active_structure_import_generates_mipmaps: bool = true
	var active_structure_texture_paths: PackedStringArray = PackedStringArray([
		"res://assets/2d/structures/base_camp_topdown.png",
		"res://assets/2d/structures/structure_t1_kinetic.png",
		"res://assets/2d/structures/structure_t1_chemical.png",
		"res://assets/2d/structures/structure_t1_electric.png",
		"res://assets/2d/structures/structure_t1_support.png",
		"res://assets/2d/structures/structure_t1_barricade.png",
		"res://assets/2d/structures/structure_t1_landmine.png",
		"res://assets/2d/structures/structure_t1_razor_snare.png",
		"res://assets/2d/structures/structure_t1_slowing_pit.png",
	])
	for texture_path: String in active_structure_texture_paths:
		var import_path: String = texture_path + ".import"
		if (
			not FileAccess.file_exists(import_path)
			or not FileAccess.get_file_as_string(import_path).contains("mipmaps/generate=true")
		):
			every_active_structure_import_generates_mipmaps = false
	var definitions: Array[StructureDefinition] = StructureCatalog.get_all()
	for structure_index: int in range(definitions.size()):
		var structure: PlacedStructure2D = PlacedStructure2D.new()
		root.add_child(structure)
		structure.configure(structure_index + 1, definitions[structure_index], 1, Vector2.ZERO)
		var texture_path: String = structure.get_visual_texture_path()
		if not texture_path.is_empty():
			unique_texture_paths[texture_path] = true
		var collision: CollisionShape2D = structure.get_node_or_null("CollisionShape2D") as CollisionShape2D
		var has_world_collision: bool = (
			collision != null
			and collision.shape is RectangleShape2D
			and structure.collision_layer == PlacedStructure2D.WORLD_STATIC_LAYER
		)
		if has_world_collision != definitions[structure_index].blocks_navigation:
			every_structure_matches_navigation_collision = false
		var visual: Sprite2D = structure.get_structure_visual()
		var sleek_material: ShaderMaterial
		if visual != null:
			sleek_material = visual.material as ShaderMaterial
		if (
			sleek_material == null
			or sleek_material.shader == null
			or sleek_material.shader.resource_path != "res://shaders/sleek_sprite_finish.gdshader"
		):
			every_structure_has_sleek_shader = false
		if visual == null or visual.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS:
			every_structure_requests_mipmapped_filtering = false
		root.remove_child(structure)
		structure.free()
	_check(
		definitions.size() == 8 and unique_texture_paths.size() == 8,
		"All eight defenses use distinct Blender-authored silhouettes"
	)
	_check(
		every_structure_matches_navigation_collision,
		"Blocking defenses own WorldStatic footprints while ground traps remain traversable"
	)
	_check(every_structure_has_sleek_shader, "Every defense uses the sleek mobile sprite finish shader")
	_check(
		every_structure_requests_mipmapped_filtering,
		"Every defense requests linear mipmapped runtime filtering"
	)
	_check(
		every_active_structure_import_generates_mipmaps,
		"Active Base and all eight defense textures generate the mip chain their runtime filter requests"
	)


func _validate_integrated_game_world() -> void:
	var game_world_scene: PackedScene = load("res://scenes/game/game_world.tscn") as PackedScene
	_check(game_world_scene != null, "Integrated GameWorld scene is available")
	if game_world_scene == null:
		return
	var game_world: GameWorld = game_world_scene.instantiate() as GameWorld
	_check(game_world != null, "Integrated GameWorld instantiates once")
	if game_world == null:
		return
	game_world.configure_launch(CoopSession.SessionMode.SOLO, &"heikki", "127.0.0.1")
	root.add_child(game_world)
	for _frame_index: int in range(4):
		await process_frame

	var world_map: BesprenWorldMap2D = game_world.get_node_or_null(
		"YSortWorld/WorldMap2D"
	) as BesprenWorldMap2D
	var base_core: CorePulseDriver = game_world.get_node_or_null(
		"YSortWorld/BaseCore"
	) as CorePulseDriver
	var hud: GameHUD = game_world.get_node_or_null("GameHUD") as GameHUD
	var audio: GameAudioController = game_world.get_node_or_null(
		"GameAudio"
	) as GameAudioController
	var session: CoopSession = game_world.get_node_or_null("CoopSession") as CoopSession
	var players_root: Node2D = game_world.get_node_or_null("YSortWorld/Players") as Node2D
	var resource_scatter: BesprenResourceScatter2D = game_world.get_node_or_null(
		"YSortWorld/ResourceScatter2D"
	) as BesprenResourceScatter2D
	var projectiles_root: ProjectilePool2D = game_world.get_node_or_null(
		"YSortWorld/Projectiles"
	) as ProjectilePool2D
	_check(
		world_map != null
		and base_core != null
		and hud != null
		and audio != null
		and session != null
		and players_root != null
		and projectiles_root != null,
		"GameWorld composes map, Base, HUD, audio, authority, players, and projectiles"
	)

	if world_map != null:
		_validate_world_environment(world_map)
		_check(
			BesprenWorldMap2D.STARTING_CAMP_POSITION.is_equal_approx(
				EXPECTED_STARTING_CAMP_POSITION
			),
			"Runtime camp uses the exact deep east-forest position (9950, 2400)"
		)
		_check(
			world_map.get_minimum_asphalt_edge_distance(
				BesprenWorldMap2D.STARTING_CAMP_POSITION
			) - BesprenWorldMap2D.CORE_COLLISION_RADIUS
			>= BesprenWorldMap2D.STARTING_CAMP_REQUIRED_ROAD_EDGE_CLEARANCE,
			"Runtime Base footprint stays at least 1600 units from every asphalt edge"
		)
		var camp_cell: Vector2i = Vector2i(
			floori((BesprenWorldMap2D.STARTING_CAMP_POSITION.x + BesprenWorldMap2D.PLAYABLE_HALF_EXTENT) / BesprenWorldMap2D.CELL_SIZE),
			floori((BesprenWorldMap2D.STARTING_CAMP_POSITION.y + BesprenWorldMap2D.PLAYABLE_HALF_EXTENT) / BesprenWorldMap2D.CELL_SIZE)
		)
		_check(
			world_map.get_biome_at_cell(camp_cell) == BesprenWorldMap2D.Biome.FOREST,
			"Initial refuge is authored inside a secluded forest macro-cell"
		)
	if base_core != null:
		_check(
			base_core.global_position.is_equal_approx(BesprenWorldMap2D.STARTING_CAMP_POSITION),
			"Camp refuge begins at the forest clearing instead of the central crossroads"
		)
		await _validate_base_core(base_core, hud)
	if players_root != null and players_root.get_child_count() > 0:
		var spawned_player: PlayerAvatar = players_root.get_child(0) as PlayerAvatar
		_check(
			spawned_player != null
			and spawned_player.global_position.distance_to(BesprenWorldMap2D.STARTING_CAMP_POSITION) < 520.0,
			"Players spawn beside the forest camp in the middle of nowhere"
		)
	if resource_scatter != null and world_map != null:
		var starter_resources_match: bool = true
		var starter_resource_approaches_are_deep: bool = true
		for resource_id: int in range(EXPECTED_STARTER_RESOURCE_OFFSETS.size()):
			var resource_position: Vector2 = resource_scatter.get_resource_position(resource_id)
			if not resource_position.is_equal_approx(
				BesprenWorldMap2D.STARTING_CAMP_POSITION
				+ EXPECTED_STARTER_RESOURCE_OFFSETS[resource_id]
			):
				starter_resources_match = false
			if (
				world_map.get_minimum_asphalt_edge_distance(resource_position) - 34.0
				< BesprenWorldMap2D.STARTING_CAMP_REQUIRED_ROAD_EDGE_CLEARANCE
			):
				starter_resource_approaches_are_deep = false
		_check(starter_resources_match, "All three starter resources follow the relocated forest camp exactly")
		_check(
			starter_resource_approaches_are_deep,
			"Starter-resource approach lanes preserve at least 1600 units from every asphalt edge"
		)
	if hud != null:
		_validate_hud(hud)
	if audio != null:
		_validate_audio(audio)
	if (
		session != null
		and players_root != null
		and projectiles_root != null
		and audio != null
	):
		await _validate_integrated_projectile(
			session,
			players_root,
			projectiles_root,
			audio
		)
	await _validate_combat_ai_systems(game_world)

	if audio != null:
		audio.stop_all()
		await process_frame
		await create_timer(0.5).timeout
	game_world.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.1).timeout


func _validate_world_environment(world_map: BesprenWorldMap2D) -> void:
	_check(world_map.get_nature_tile_count() > 0, "Metsa and wilderness contain nature detail tiles")
	_check(
		world_map.get_nature_variant_count() >= 5,
		"Nature coverage uses at least five rich ClawAndBlade variants"
	)
	var terrain_tiles: TileMapLayer = world_map.get_node_or_null(
		"TerrainDetails/TerrainTiles"
	) as TileMapLayer
	var nature_atlas_is_imported: bool = false
	if terrain_tiles != null and terrain_tiles.tile_set != null:
		var used_cells: Array[Vector2i] = terrain_tiles.get_used_cells()
		if not used_cells.is_empty():
			var source_id: int = terrain_tiles.get_cell_source_id(used_cells[0])
			var atlas_source: TileSetAtlasSource = terrain_tiles.tile_set.get_source(
				source_id
			) as TileSetAtlasSource
			nature_atlas_is_imported = (
				atlas_source != null
				and atlas_source.texture != null
				and atlas_source.texture.resource_path
				== "res://assets/tiles/claw_forest_ground.png"
			)
	_check(nature_atlas_is_imported, "Nature TileMapLayer renders the imported forest atlas")
	var terrain_overlay: Sprite2D = world_map.get_node_or_null("TerrainMaterialOverlay") as Sprite2D
	var terrain_finish: ShaderMaterial = terrain_overlay.material as ShaderMaterial if terrain_overlay != null else null
	_check(
		terrain_overlay != null
		and terrain_overlay.texture != null
		and terrain_overlay.texture.resource_path == "res://assets/2d/environment/terrain/polyhaven_terrain_atlas.png"
		and terrain_overlay.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		and terrain_finish != null
		and terrain_finish.shader != null
		and terrain_finish.shader.resource_path == "res://shaders/terrain_material_blend.gdshader",
		"World uses the mipmapped Poly Haven terrain blend overlay"
	)

	var obstacles: Array[WorldObstacle2D] = world_map.get_obstacle_nodes()
	var every_obstacle_is_solid: bool = not obstacles.is_empty()
	var imported_tree_count: int = 0
	var polyhaven_sprite_count: int = 0
	var imported_rock_or_stump_count: int = 0
	var imported_log_count: int = 0
	var imported_scrap_count: int = 0
	var imported_barrier_count: int = 0
	var local_city_count: int = 0
	var local_mall_count: int = 0
	var local_village_count: int = 0
	var local_vehicle_count: int = 0
	var local_fence_count: int = 0
	var local_pole_count: int = 0
	var district_sprite_count: int = 0
	var district_urban_count: int = 0
	var district_factory_count: int = 0
	var district_chainlink_count: int = 0
	var district_covered_car_count: int = 0
	var district_aircon_count: int = 0
	var district_bench_count: int = 0
	var district_stove_count: int = 0
	var every_polyhaven_sprite_is_finished: bool = true
	for obstacle: WorldObstacle2D in obstacles:
		var collision: CollisionShape2D = obstacle.get_node_or_null(
			"CollisionShape2D"
		) as CollisionShape2D
		if (
			not (obstacle is StaticBody2D)
			or obstacle.collision_layer != WORLD_STATIC_LAYER
			or collision == null
			or collision.shape == null
			or collision.disabled
		):
			every_obstacle_is_solid = false
		var imported_tree: Sprite2D = obstacle.get_node_or_null(
			"ImportedTreeVisual"
		) as Sprite2D
		if imported_tree != null and _texture_source_path(imported_tree.texture) == (
			"res://assets/2d/environment/polyhaven_wild/polyhaven_wild_atlas.png"
		):
			imported_tree_count += 1
		for child: Node in obstacle.get_children():
			var imported_prop: Sprite2D = child as Sprite2D
			if imported_prop == null or not String(imported_prop.name).begins_with("Imported"):
				continue
			var imported_source: String = _texture_source_path(imported_prop.texture)
			if imported_source == (
				"res://assets/2d/environment/local_baked/local_environment_atlas.png"
			):
				var local_finish: ShaderMaterial = imported_prop.material as ShaderMaterial
				if (
					imported_prop.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
					or local_finish == null
					or local_finish.shader == null
					or local_finish.shader.resource_path != "res://shaders/sleek_sprite_finish.gdshader"
				):
					every_polyhaven_sprite_is_finished = false
				var local_name: String = String(imported_prop.name)
				if local_name == "ImportedLocalCityVisual":
					local_city_count += 1
				elif local_name.begins_with("ImportedMall") or local_name == "ImportedIndustrialPylonVisual":
					local_mall_count += 1
				elif local_name == "ImportedVillageHouseVisual":
					local_village_count += 1
				elif local_name == "ImportedVehicleWreckVisual" or local_name == "ImportedRoadsideBarrierVisual":
					local_vehicle_count += 1
				elif local_name.begins_with("ImportedBarricadeSegment"):
					local_fence_count += 1
				elif local_name == "ImportedUtilityPoleVisual":
					local_pole_count += 1
				continue
			if imported_source == DISTRICT_ATLAS_PATH:
				district_sprite_count += 1
				var district_finish: ShaderMaterial = imported_prop.material as ShaderMaterial
				if (
					imported_prop.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
					or district_finish == null
					or district_finish.shader == null
					or district_finish.shader.resource_path != "res://shaders/sleek_sprite_finish.gdshader"
				):
					every_polyhaven_sprite_is_finished = false
				var district_name: String = String(imported_prop.name)
				if district_name.begins_with("ImportedDistrictUrbanBlockVisual"):
					district_urban_count += 1
				elif district_name.begins_with("ImportedDistrictFactoryBlockVisual"):
					district_factory_count += 1
				elif district_name.begins_with("ImportedDistrictChainlinkVisual"):
					district_chainlink_count += 1
				elif district_name.begins_with("ImportedDistrictCoveredCarVisual"):
					district_covered_car_count += 1
				elif district_name.begins_with("ImportedDistrictAirconVisual"):
					district_aircon_count += 1
				elif district_name.begins_with("ImportedDistrictBenchVisual"):
					district_bench_count += 1
				elif district_name.begins_with("ImportedDistrictBarrelStoveVisual"):
					district_stove_count += 1
				continue
			if imported_source != (
				"res://assets/2d/environment/polyhaven/polyhaven_environment_atlas.png"
			):
				continue
			polyhaven_sprite_count += 1
			var finish: ShaderMaterial = imported_prop.material as ShaderMaterial
			if (
				imported_prop.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				or finish == null
				or finish.shader == null
				or finish.shader.resource_path != "res://shaders/sleek_sprite_finish.gdshader"
			):
				every_polyhaven_sprite_is_finished = false
			match imported_prop.name:
				&"ImportedRockVisual", &"ImportedStumpVisual":
					imported_rock_or_stump_count += 1
				&"ImportedFallenLogVisual":
					imported_log_count += 1
				&"ImportedScrapCanVisual", &"ImportedScrapTyreVisual":
					imported_scrap_count += 1
				&"ImportedConcreteBarrierVisual":
					imported_barrier_count += 1
	_check(every_obstacle_is_solid, "Every authored obstacle is an active StaticBody2D")
	_check(imported_tree_count > 0, "Forest boundary trees render imported foliage sprites")
	_check(
		polyhaven_sprite_count > 0
		and imported_rock_or_stump_count > 0
		and imported_log_count > 0
		and imported_scrap_count >= 2
		and imported_barrier_count > 0,
		"Forest and urban obstacles use the complete Poly Haven prop families"
	)
	_check(
		every_polyhaven_sprite_is_finished,
		"Every baked environment prop uses mipmapped filtering and the sleek finish shader"
	)
	_check(
		local_city_count > 0
		and local_mall_count > 0
		and local_village_count > 0
		and local_vehicle_count > 0
		and local_fence_count > 0
		and local_pole_count > 0,
		"Local Blender atlas replaces every major city, mall, village, vehicle, fence, and utility family"
	)
	_check(
		district_sprite_count == 16
		and district_urban_count == 3
		and district_factory_count == 3
		and district_chainlink_count == 2
		and district_covered_car_count == 2
		and district_aircon_count == 4
		and district_bench_count == 1
		and district_stove_count == 1,
		"Hidden Alley atlas contributes the exact reviewed 16-sprite district family mix"
	)
	var background_decor: WorldBackgroundDecor2D = world_map.get_node_or_null(
		"BackgroundDecor"
	) as WorldBackgroundDecor2D
	var background_kinds: PackedInt32Array = PackedInt32Array()
	if background_decor != null and background_decor.has_method(&"get_prop_kinds"):
		var kinds_variant: Variant = background_decor.call(&"get_prop_kinds")
		if kinds_variant is PackedInt32Array:
			background_kinds = kinds_variant
	_check(
		background_decor != null
		and background_decor.get_decoration_count() == WorldBackgroundDecor2D.TOTAL_DECORATION_COUNT
		and background_decor.get_decoration_count() == 1100
		and background_kinds.size() == WorldBackgroundDecor2D.PROP_COUNT
		and background_kinds.count(6) == 75
		and background_kinds.count(7) == 46
		and background_kinds.count(8) == 34,
		"Background preserves 1100 marks and batches the expanded street-furniture mix"
	)
	_check(
		world_map.get_world_boundary_count() == 4
		and world_map.get_static_collision_count() == obstacles.size() + 4,
		"World has four solid bounds plus every authored obstacle collision"
	)


func _validate_base_core(base_core: CorePulseDriver, hud: GameHUD) -> void:
	var core_sprite: Sprite2D = base_core.get_node_or_null("Core") as Sprite2D
	var glow_sprite: Sprite2D = base_core.get_node_or_null("GlowSilhouette") as Sprite2D
	var amber_light: PointLight2D = base_core.get_node_or_null("AmberLight") as PointLight2D
	var body: StaticBody2D = base_core.get_node_or_null("StaticBody2D") as StaticBody2D
	var collision: CollisionShape2D = base_core.get_node_or_null(
		"StaticBody2D/CollisionShape2D"
	) as CollisionShape2D
	_check(
		core_sprite != null
		and core_sprite.texture != null
		and core_sprite.texture.resource_path == "res://assets/2d/structures/base_camp_topdown.png",
		"Main Base renders the Blender-authored camp-refuge silhouette"
	)
	var glow_material: ShaderMaterial = null
	if glow_sprite != null:
		glow_material = glow_sprite.material as ShaderMaterial
	_check(
		glow_material != null
		and glow_material.shader != null
		and glow_material.shader.resource_path == "res://shaders/base_scale_glow.gdshader",
		"Main Base owns the warm amber scale-glow shader"
	)
	_check(
		amber_light != null and amber_light.energy > 0.0,
		"Main Base owns an active warm amber PointLight2D"
	)
	_check(
		body != null
		and body.collision_layer == WORLD_STATIC_LAYER
		and collision != null
		and collision.shape != null
		and not collision.disabled,
		"Main Base is backed by an active StaticBody2D collision"
	)
	_check(
		is_equal_approx(CorePulseDriver.COMMAND_PUNCH_SCALE, 1.15),
		"Base command feedback contract is the exact 1.15x scale punch"
	)
	_check(base_core.get_pulse_phase() > 0.0, "Base amber glow advances its pulse phase")

	if core_sprite == null or hud == null:
		return
	var base_scale: Vector2 = core_sprite.scale
	var make_base_button: Button = hud.get_make_base_button()
	make_base_button.pressed.emit()
	# Asked rather than sampled. Headless frame deltas are unbounded, so a single
	# slow frame can advance the whole 0.22-second punch before the test gets to
	# look at the scale - which intermittently failed a feature that was working,
	# first as a fixed 0.09-second read and then as a peak watch. Whether the
	# punch is running is the same fact with none of the race.
	_check(
		base_core.is_command_punch_active(),
		"Make Base visibly drives the Base Core scale punch"
	)
	await create_timer(0.32).timeout
	_check(core_sprite.scale.is_equal_approx(base_scale), "Base Core scale punch settles cleanly")
	_check(
		not base_core.is_command_punch_active(),
		"Base Core punch releases its tween once it has settled"
	)


func _validate_hud(hud: GameHUD) -> void:
	hud.set_resource_amounts(7, 11, 13)
	_check(hud.layer == 100, "Gameplay HUD is pinned to CanvasLayer 100")
	var resource_labels: Array[Label] = hud.get_resource_labels()
	_check(
		resource_labels.size() == 3
		and resource_labels[0].text == "7"
		and resource_labels[1].text == "11"
		and resource_labels[2].text == "13",
		"HUD clearly exposes Wood, Metal, and Tech counters"
	)
	var buttons: Array[Button] = hud.get_command_buttons()
	var expected_text: PackedStringArray = PackedStringArray([
		"Make Base",
		"Build",
		"Start Night",
	])
	var buttons_match: bool = buttons.size() == expected_text.size()
	var buttons_are_touch_sized: bool = buttons_match
	var buttons_do_not_overlap: bool = buttons_match
	for button_index: int in range(buttons.size()):
		var button: Button = buttons[button_index]
		if button_index >= expected_text.size() or button.text != expected_text[button_index]:
			buttons_match = false
		if (
			button.size.x < MINIMUM_TOUCH_SIZE.x
			or button.size.y < MINIMUM_TOUCH_SIZE.y
			or not button.is_visible_in_tree()
		):
			buttons_are_touch_sized = false
	for first_index: int in range(buttons.size()):
		for second_index: int in range(first_index + 1, buttons.size()):
			if buttons[first_index].get_global_rect().intersects(
				buttons[second_index].get_global_rect()
			):
				buttons_do_not_overlap = false
	_check(buttons_match, "HUD exposes Make Base, Build, and Start Night exactly")
	_check(buttons_are_touch_sized, "Every compact command keeps at least a 44x44 touch target")
	_check(buttons_do_not_overlap, "Command buttons are pairwise non-overlapping")

	var resources_do_not_overlap_commands: bool = resource_labels.size() == 3 and buttons.size() == 3
	for label: Label in resource_labels:
		for button: Button in buttons:
			if label.get_global_rect().intersects(button.get_global_rect()):
				resources_do_not_overlap_commands = false
	_check(
		resources_do_not_overlap_commands,
		"Resource counters do not overlap command buttons"
	)
	var panel_rect: Rect2 = hud.get_panel().get_global_rect()
	_check(
		panel_rect.position.x >= 0.0
		and panel_rect.position.y >= 0.0
		and panel_rect.end.x <= 480.0
		and panel_rect.end.y <= GameHUD.RESERVED_CONTROLS_TOP_Y,
		"Top-left HUD stays inside the 480x270 safe gameplay band"
	)


func _validate_audio(audio: GameAudioController) -> void:
	var cues: Array[StringName] = [
		GameAudioController.CUE_SHOOT,
		GameAudioController.CUE_BUILD,
		GameAudioController.CUE_HARVEST,
		GameAudioController.CUE_UI,
	]
	var every_stream_is_valid: bool = true
	for cue: StringName in cues:
		var stream: AudioStream = audio.get_stream_for_cue(cue)
		if stream == null or stream.get_length() <= 0.0:
			every_stream_is_valid = false
	_check(every_stream_is_valid, "Shoot, build, harvest, and UI cues load valid audio streams")
	_check(audio.get_world_player_count() == 6, "Audio controller owns a six-voice 2D SFX pool")
	_check(
		audio.play_world_cue(GameAudioController.CUE_HARVEST, Vector2.ZERO)
		and audio.get_last_cue() == GameAudioController.CUE_HARVEST,
		"Harvest feedback triggers through AudioStreamPlayer2D"
	)
	_check(
		audio.play_ui_click()
		and audio.get_last_cue() == GameAudioController.CUE_UI,
		"UI feedback triggers through non-positional AudioStreamPlayer"
	)


func _validate_integrated_projectile(
	session: CoopSession,
	players_root: Node2D,
	projectiles_root: ProjectilePool2D,
	audio: GameAudioController
) -> void:
	_check(players_root.get_child_count() == 1, "Solo GameWorld spawns one physics-backed player")
	if players_root.get_child_count() != 1:
		return
	var runtime_player: PlayerAvatar = players_root.get_child(0) as PlayerAvatar
	_check(runtime_player != null, "Solo runtime player is PlayerAvatar")
	if runtime_player == null:
		return

	var impact_wall: StaticBody2D = _create_test_wall(
		runtime_player.global_position + Vector2(120.0, 0.0),
		Vector2(8.0, 100.0)
	)
	root.add_child(impact_wall)
	await physics_frame
	_projectile_impacts = 0
	var initial_capacity: int = projectiles_root.get_capacity()
	_check(
		initial_capacity == ProjectilePool2D.DEFAULT_INITIAL_SIZE
		and projectiles_root.get_active_count() == 0,
		"Projectile pool is prewarmed once with no active rounds"
	)
	# Checked synchronously: the emit, the checkout and the cue all happen inside
	# submit_interaction. Awaiting a frame first made this depend on how many
	# physics ticks the headless loop chose to run, and a round travelling at 820
	# px/s clears the 120 px to the wall in seven of them.
	session.submit_interaction(&"fire")
	_check(
		projectiles_root.get_active_count() == 1
		and projectiles_root.get_capacity() == initial_capacity,
		"Fire checks out one visible projectile without instantiation"
	)
	_check(
		audio.get_last_cue() == GameAudioController.CUE_SHOOT,
		"Projectile instantiation triggers the shooting cue"
	)
	if projectiles_root.get_active_count() != 1:
		impact_wall.queue_free()
		await process_frame
		return

	var projectile: PlayerProjectile = projectiles_root.get_active_projectiles()[0]
	_check(projectile != null, "Spawned projectile uses PlayerProjectile behavior")
	if projectile == null:
		impact_wall.queue_free()
		await process_frame
		return
	projectile.impacted.connect(_on_projectile_impacted)
	var tracer: Sprite2D = projectile.get_node_or_null("Tracer") as Sprite2D
	var projectile_head: Sprite2D = projectile.get_node_or_null("ProjectileHead") as Sprite2D
	var collision: CollisionShape2D = projectile.get_node_or_null(
		"CollisionShape2D"
	) as CollisionShape2D
	_check(
		tracer != null and tracer.visible and tracer.texture != null,
		"Projectile owns a visible high-contrast tracer Sprite2D"
	)
	_check(
		projectile_head != null
		and projectile_head.visible
		and projectile_head.texture != null
		and projectile_head.texture.resource_path
		== "res://assets/sprites/projectile_bullet_strip.png"
		and projectile_head.hframes == 6,
		"Projectile renders one frame of the imported six-frame bullet strip"
	)
	_check(
		collision != null
		and collision.shape is RectangleShape2D
		and not collision.disabled
		and projectile.collision_mask == WORLD_STATIC_LAYER + ENEMY_LAYER,
		"Projectile collision covers active WorldStatic and Enemies targets"
	)
	_check(
		projectile.get_direction().is_equal_approx(Vector2.RIGHT),
		"Projectile travels along the authority-approved firing vector"
	)
	var position_before_motion: Vector2 = projectile.global_position
	projectile._physics_process(0.01)
	_check(
		is_instance_valid(projectile)
		and projectile.global_position.x > position_before_motion.x,
		"Visible projectile advances along its firing vector"
	)
	for _physics_index: int in range(12):
		await physics_frame
		if not projectile.is_active():
			break
	_check(
		is_instance_valid(projectile)
		and not projectile.is_active()
		and projectiles_root.get_active_count() == 0
		and projectiles_root.get_available_count() == initial_capacity
		and _projectile_impacts == 1,
		"Projectile returns to the fixed pool immediately after impact"
	)
	impact_wall.queue_free()
	await process_frame
	await _validate_enemy_projectile_cleanup()


func _validate_enemy_projectile_cleanup() -> void:
	var projectile_scene: PackedScene = load(
		"res://scenes/combat/player_projectile.tscn"
	) as PackedScene
	var projectile: PlayerProjectile = projectile_scene.instantiate() as PlayerProjectile
	var enemy_target: Area2D = Area2D.new()
	enemy_target.name = &"SmokeEnemyTarget"
	enemy_target.global_position = PLAYER_TEST_ORIGIN + Vector2(80.0, 500.0)
	enemy_target.collision_layer = ENEMY_LAYER
	enemy_target.collision_mask = 0
	var enemy_shape: RectangleShape2D = RectangleShape2D.new()
	enemy_shape.size = Vector2(8.0, 80.0)
	var enemy_collision: CollisionShape2D = CollisionShape2D.new()
	enemy_collision.shape = enemy_shape
	enemy_target.add_child(enemy_collision)
	root.add_child(enemy_target)
	root.add_child(projectile)
	projectile.initialize(PLAYER_TEST_ORIGIN + Vector2(0.0, 500.0), Vector2.RIGHT, 99)
	projectile.impacted.connect(_on_projectile_impacted)
	var starting_impact_count: int = _projectile_impacts
	var projectile_reference: WeakRef = weakref(projectile)
	await physics_frame
	for _physics_index: int in range(12):
		await physics_frame
		if projectile_reference.get_ref() == null:
			break
	_check(
		projectile_reference.get_ref() == null
		and _projectile_impacts == starting_impact_count + 1
		and _last_projectile_collider == enemy_target,
		"Projectile detects an Enemies-layer Area2D and cleans itself up on impact"
	)
	if projectile_reference.get_ref() != null:
		var remaining_projectile: Node = projectile_reference.get_ref() as Node
		if remaining_projectile != null:
			remaining_projectile.queue_free()
	enemy_target.queue_free()
	await process_frame


func _validate_combat_ai_systems(game_world: GameWorld) -> void:
	var world_map: BesprenWorldMap2D = game_world.get_node_or_null(
		"YSortWorld/WorldMap2D"
	) as BesprenWorldMap2D
	var flow_field: FlowFieldNavigation2D = game_world.get_node_or_null(
		"FlowFieldNavigation2D"
	) as FlowFieldNavigation2D
	var build_system: TacticalBuildSystem = game_world.get_node_or_null(
		"TacticalBuildSystem"
	) as TacticalBuildSystem
	var horde: HordeDirector = game_world.get_node_or_null("HordeDirector") as HordeDirector
	var combat_state: CombatStateCoordinator = game_world.get_node_or_null(
		"CombatStateCoordinator"
	) as CombatStateCoordinator
	var atmosphere: NightAtmosphere2D = game_world.get_node_or_null(
		"NightAtmosphere2D"
	) as NightAtmosphere2D
	var blood_canvas: BloodCanvas = game_world.get_node_or_null(
		"YSortWorld/BloodCanvas"
	) as BloodCanvas
	var loot_boxes: LootBoxManager2D = game_world.get_node_or_null(
		"YSortWorld/LootBoxes"
	) as LootBoxManager2D
	var hud: GameHUD = game_world.get_node_or_null("GameHUD") as GameHUD
	var players_root: Node2D = game_world.get_node_or_null("YSortWorld/Players") as Node2D
	var session: CoopSession = game_world.get_node_or_null("CoopSession") as CoopSession
	_check(
		world_map != null
		and flow_field != null
		and build_system != null
		and horde != null
		and combat_state != null
		and atmosphere != null
		and blood_canvas != null
		and loot_boxes != null
		and hud != null
		and players_root != null
		and session != null,
		"GameWorld composes flow, horde, combat, atmosphere, decals, and shared loot"
	)
	if (
		world_map == null
		or flow_field == null
		or build_system == null
		or horde == null
		or combat_state == null
		or atmosphere == null
		or blood_canvas == null
		or loot_boxes == null
		or hud == null
		or players_root == null
		or session == null
	):
		return

	var initial_base_position: Vector2 = build_system.get_base_position()
	_check(
		flow_field.get_reachable_count() > 0
		and flow_field.get_target_position().is_equal_approx(initial_base_position)
		and _flow_reaches_target(flow_field, initial_base_position + Vector2(1024.0, 0.0),
			initial_base_position)
		and _flow_reaches_target(flow_field, initial_base_position + Vector2(-1024.0, 0.0),
			initial_base_position)
		and _flow_reaches_target(flow_field, initial_base_position + Vector2(0.0, 1024.0),
			initial_base_position),
		"Flow field covers reachable cells and points toward the active Main Base"
	)
	var flow_revision_before_build: int = flow_field.get_revision()
	var tower_position: Vector2 = Vector2(0.0, 640.0)
	build_system.request_structure_placement(StructureCatalog.T1_KINETIC, tower_position)
	await process_frame
	_check(
		build_system.get_structure_count() == 1
		and flow_field.get_revision() > flow_revision_before_build,
		"Accepted structures rebuild the flow field immediately"
	)
	var tower_cell: Vector2i = world_map.world_to_flow_cell(tower_position)
	_check(
		flow_field.is_cell_dynamically_blocked(tower_cell),
		"Placed tower footprint is rasterized as a dynamic flow-field blocker"
	)
	var placed_tower: PlacedStructure2D = build_system.get_structures()[0]
	var tower_motion_start: Vector2 = tower_position + Vector2(-96.0, 0.0)
	var tower_motion_result: Vector2 = build_system.resolve_player_motion(
		tower_motion_start,
		tower_position,
		EXPECTED_PLAYER_RADIUS
	)
	_check(
		not tower_motion_result.is_equal_approx(tower_position),
		"Peer-one motion resolution prevents players from running through placed towers"
	)
	atmosphere.set_night_active(true, true)
	atmosphere.register_structure(placed_tower)
	var security_light: PointLight2D = placed_tower.get_node_or_null(
		"SecurityLight"
	) as PointLight2D
	var runtime_player: PlayerAvatar = players_root.get_child(0) as PlayerAvatar
	_check(
		atmosphere.get_current_color().is_equal_approx(NightAtmosphere2D.SAPPHIRE_NIGHT_COLOR)
		and NightAtmosphere2D.TRANSITION_SECONDS == 3.0
		and runtime_player != null
		and runtime_player.is_flashlight_enabled(),
		"Readable blue-hour night uses #91a3bd over the exact 3.0-second lighting contract"
	)
	_check(
		security_light != null and security_light.enabled,
		"Night transition enables tower security PointLight2D illumination"
	)
	placed_tower.apply_micro_emp(EnemyAgent2D.STATIC_EMP_DURATION_SECONDS)
	_check(
		placed_tower.is_emp_disabled() and security_light != null and not security_light.enabled,
		"Static-Walker micro-EMP disables an in-radius tower security system"
	)
	atmosphere.set_night_active(false, true)

	var relocation_position: Vector2 = Vector2(1024.0, 0.0)
	var flow_revision_before_relocation: int = flow_field.get_revision()
	build_system.request_base_relocation(relocation_position)
	await process_frame
	_check(
		build_system.get_base_position().is_equal_approx(relocation_position)
		and flow_field.get_target_position().is_equal_approx(relocation_position)
		and flow_field.get_revision() > flow_revision_before_relocation
		and build_system.get_structure_count() == 0,
		"Make Base clears defenses and instantly re-points every flow cell"
	)

	var pool_before_loot: PackedInt32Array = build_system.get_resource_pool()
	var first_box: LootBox2D = loot_boxes.get_box(1)
	var opened: bool = first_box != null and loot_boxes.try_open_authoritative(
		CoopSession.AUTHORITY_PEER_ID,
		first_box.global_position
	)
	var pool_after_loot: PackedInt32Array = build_system.get_resource_pool()
	_check(
		opened
		and loot_boxes.get_opened_count() == 1
		and pool_after_loot[0] == pool_before_loot[0] + 18
		and pool_after_loot[1] == pool_before_loot[1] + 8
		and pool_after_loot[2] == pool_before_loot[2] + 2,
		"[USE] opens a host-validated loot box into the shared team pool instantly"
	)

	horde.begin_night_authoritative(1)
	horde.advance_wave_for_test(0.0)
	var aggro_enemy: EnemyAgent2D = horde.get_enemy(1)
	_check(
		aggro_enemy != null
		and aggro_enemy.get_target_peer_id() == EnemyAggroMatrix.BASE_TARGET_PEER_ID,
		"Fresh zombies default to the active Main Base target"
	)
	if aggro_enemy != null:
		runtime_player.global_position = aggro_enemy.global_position + Vector2(100.0, 0.0)
		horde.advance_wave_for_test(HordeDirector.AGGRO_REFRESH_SECONDS)
		_check(
			aggro_enemy.get_target_peer_id() == CoopSession.AUTHORITY_PEER_ID,
			"Host aggro matrix retargets a zombie to a nearby living player"
		)
		runtime_player.global_position = aggro_enemy.global_position + Vector2(
			HordeDirector.AGGRO_PROXIMITY_RADIUS + 200.0,
			0.0
		)
		horde.advance_wave_for_test(HordeDirector.AGGRO_REFRESH_SECONDS)
		_check(
			aggro_enemy.get_target_peer_id() == EnemyAggroMatrix.BASE_TARGET_PEER_ID,
			"Leaving proximity returns zombie priority to the Main Base"
		)
		var active_relocation: Vector2 = Vector2(2048.0, 0.0)
		build_system.request_base_relocation(active_relocation)
		_check(
			aggro_enemy.get_base_target().is_equal_approx(active_relocation)
			and flow_field.get_target_position().is_equal_approx(active_relocation),
			"Active zombies re-path in the same commit that relocates the Base"
		)
	horde.reset_for_session()

	var static_tower_position: Vector2 = Vector2(3520.0, 0.0)
	build_system.request_structure_placement(StructureCatalog.T1_KINETIC, static_tower_position)
	var static_tower: PlacedStructure2D = (
		build_system.get_structures()[0]
		if build_system.get_structure_count() == 1
		else null
	)
	horde.begin_night_authoritative(8)
	horde.advance_wave_for_test(0.0)
	var static_enemy: EnemyAgent2D = horde.get_enemy(1)
	if static_enemy != null:
		static_enemy.take_damage(static_enemy.current_health)
	_check(
		static_tower != null
		and static_enemy != null
		and static_enemy.variant == EnemyAgent2D.Variant.STATIC_WALKER
		and static_tower.is_emp_disabled(),
		"Static-Walker death emits a director-applied micro-EMP pulse"
	)
	horde.reset_for_session()
	blood_canvas.clear_decals()

	_check(
		HordeDirector.MAX_ALIVE_ENEMIES == 110,
		"Horde director hard-caps all concurrent alive enemies at 110"
	)
	_check(
		is_equal_approx(
			HordeDirector.calculate_spawn_interval(2),
			HordeDirector.calculate_spawn_interval(1) * 0.5
		)
		and is_equal_approx(HordeDirector.calculate_co_op_stat_scale(2), 1.25),
		"Two-player co-op doubles spawn cadence and scales HP/damage by 1.25x"
	)
	_check(
		HordeDirector.get_boss_variant_for_night(5) == EnemyAgent2D.Variant.GOLIATH
		and HordeDirector.get_boss_variant_for_night(10) == EnemyAgent2D.Variant.CARRIER
		and HordeDirector.get_boss_variant_for_night(15) == EnemyAgent2D.Variant.SPLITTER
		and HordeDirector.get_boss_variant_for_night(20) == EnemyAgent2D.Variant.OVERLORD
		and HordeDirector.get_boss_variant_for_night(6) == -1,
		"Night 5/10/15/20 map exactly to Goliath/Carrier/Splitter/Overlord"
	)
	var night_twelve_variants: Dictionary[int, bool] = {}
	for rotation_index: int in range(4):
		night_twelve_variants[
			HordeDirector.get_rotation_variant(12, rotation_index)
		] = true
	_check(
		night_twelve_variants.has(EnemyAgent2D.Variant.WALKER)
		and night_twelve_variants.has(EnemyAgent2D.Variant.RAT_SWARM)
		and night_twelve_variants.has(EnemyAgent2D.Variant.STATIC_WALKER)
		and night_twelve_variants.has(EnemyAgent2D.Variant.SCRAP_SHIELD),
		"Night 6/8/12 unlocks rotate Rat, Static, and Scrap-Shield into later waves"
	)
	# Derived from the probe's own facing rather than from a hard-coded axis. The
	# guard is a dot-product rule about the angle between facing and incoming
	# round, and it must keep holding when the spawn heading changes - which it
	# did, to the camera-facing row the actor sheets are baked around.
	var shield_probe: EnemyAgent2D = EnemyAgent2D.new()
	var shield_facing: Vector2 = shield_probe.get_facing_direction()
	_check(
		shield_probe.is_frontal_shield_hit(-shield_facing)
		and not shield_probe.is_frontal_shield_hit(shield_facing)
		and shield_probe.is_frontal_shield_hit(shield_facing.rotated(deg_to_rad(121.0)))
		and not shield_probe.is_frontal_shield_hit(shield_facing.rotated(deg_to_rad(119.0))),
		"Scrap-Shield frontal guard applies the exact u dot v <= -0.5 check"
	)
	shield_probe.free()

	horde.begin_night_authoritative(5)
	var frozen_seconds: float = horde.get_wave_seconds_remaining()
	horde.advance_wave_for_test(5.0)
	_check(
		horde.is_pacing_frozen()
		and horde.get_bosses_remaining() == 1
		and is_equal_approx(horde.get_wave_seconds_remaining(), frozen_seconds)
		and hud.get_clock_label().text == "FROZEN // BOSS"
		and not hud.get_boss_marquee_panel().visible
		and hud.get_threat_chip().visible
		and hud.get_threat_tag().text == "BOSS",
		"Boss gate freezes the HUD wave clock and exposes one non-blocking boss edge chip"
	)
	horde.defeat_bosses_for_test()
	var unfrozen_seconds: float = horde.get_wave_seconds_remaining()
	horde.advance_wave_for_test(1.0)
	_check(
		not horde.is_pacing_frozen()
		and horde.get_bosses_remaining() == 0
		and horde.get_wave_seconds_remaining() < unfrozen_seconds
		and not hud.get_boss_marquee_panel().visible
		and not hud.get_threat_chip().visible,
		"Destroying every boss releases the Frozen Pacing Contract and retires its edge chip"
	)
	_check(
		blood_canvas.get_decal_count() == 1
		and blood_canvas.get_capacity() == BloodCanvas.MAX_DECALS,
		"Boss death stamps one GPU-batched BloodCanvas decal without node churn"
	)
	horde.reset_for_session()

	var dummy_player: PlayerAvatar = PlayerAvatar.new()
	dummy_player.peer_id = 2
	dummy_player.character_id = &"shane"
	combat_state.register_player(dummy_player)
	combat_state.initialize_for_session()
	combat_state.damage_player_authoritative(CoopSession.AUTHORITY_PEER_ID, 100)
	_check(
		is_equal_approx(
			combat_state.get_respawn_remaining(CoopSession.AUTHORITY_PEER_ID),
			CombatStateCoordinator.RESPAWN_DELAY_SECONDS
		)
		and runtime_player != null
		and not runtime_player.is_combat_alive(),
		"A lone co-op death starts an immutable 10.0-second Base respawn"
	)
	combat_state._physics_process(9.99)
	_check(
		combat_state.get_player_health(CoopSession.AUTHORITY_PEER_ID) == 0,
		"Respawn cannot complete before the strict ten-second threshold"
	)
	combat_state._physics_process(0.02)
	await physics_frame
	_check(
		combat_state.get_player_health(CoopSession.AUTHORITY_PEER_ID)
		== CombatStateCoordinator.PLAYER_MAX_HEALTH
		and runtime_player.is_combat_alive()
		and session.get_authoritative_position(
			CoopSession.AUTHORITY_PEER_ID
		).distance_to(build_system.get_base_position()) < 300.0,
		"Single dead player respawns alive at the relocated Base after ten seconds"
	)
	combat_state.damage_player_authoritative(CoopSession.AUTHORITY_PEER_ID, 100)
	combat_state.damage_player_authoritative(2, 100)
	_check(
		combat_state.is_game_over(),
		"Game Over triggers when Heikki and Shane are dead simultaneously"
	)
	combat_state.initialize_for_session()
	combat_state.damage_base_authoritative(CombatStateCoordinator.BASE_MAX_HEALTH)
	_check(
		combat_state.is_game_over()
		and combat_state.get_base_health() == 0,
		"Main Base destruction independently triggers Game Over"
	)
	combat_state.unregister_player(2)
	dummy_player.free()


func _flow_reaches_target(
	flow_field: FlowFieldNavigation2D,
	start_position: Vector2,
	target_position: Vector2
) -> bool:
	# Sampling one cell and asserting it points at the base only holds while the
	# base sits in open ground. The Main Base is a secluded forest clearing walled
	# on three sides, so the cell 1024 units east correctly points south to route
	# around that wall, and a dot-product against Vector2.LEFT reads that correct
	# answer as a failure. What the field actually promises is that a zombie which
	# follows it arrives, so walk it and check exactly that.
	var position: Vector2 = start_position
	var steps: int = 0
	while steps < FLOW_WALK_STEP_LIMIT:
		if position.distance_to(target_position) <= FLOW_ARRIVAL_DISTANCE:
			return true
		var direction: Vector2 = flow_field.get_direction(position)
		if direction == Vector2.ZERO:
			return false
		position += direction * FLOW_WALK_STEP_LENGTH
		steps += 1
	return position.distance_to(target_position) <= FLOW_ARRIVAL_DISTANCE


func _create_test_wall(world_position: Vector2, shape_size: Vector2) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = &"SmokeTestWall"
	body.global_position = world_position
	body.collision_layer = WORLD_STATIC_LAYER
	body.collision_mask = 0
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = shape_size
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = &"CollisionShape2D"
	collision.shape = rectangle
	body.add_child(collision)
	return body


func _texture_source_path(texture: Texture2D) -> String:
	if texture == null:
		return ""
	var atlas_texture: AtlasTexture = texture as AtlasTexture
	if atlas_texture != null:
		if atlas_texture.atlas == null:
			return ""
		return atlas_texture.atlas.resource_path
	return texture.resource_path


func _on_projectile_impacted(collider: Node) -> void:
	_projectile_impacts += 1
	_last_projectile_collider = collider


func _finish() -> void:
	if _failures == 0:
		print("SMOKE OK (%d checks)" % _checks)
		quit(0)
		return
	push_error("SMOKE FAILED (%d/%d checks failed)" % [_failures, _checks])
	quit(1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS | %s" % message)
		return
	_failures += 1
	push_error("FAIL | %s" % message)
