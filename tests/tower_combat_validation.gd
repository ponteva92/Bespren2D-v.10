extends SceneTree
## Focused GameWorld integration gate for host-authoritative automatic tower combat.
## Exercises lifecycle, targeting modes, radial attacks, and a 16-tower/110-zombie wave.

const GAME_WORLD_SCENE: PackedScene = preload("res://scenes/game/game_world.tscn")
const PLAYER_PROJECTILE_SCENE: PackedScene = preload("res://scenes/combat/player_projectile.tscn")
const TEST_PEER_ID: int = CoopSession.AUTHORITY_PEER_ID
const TEST_ORIGIN: Vector2 = Vector2(30000.0, 30000.0)
const STRESS_TOWER_COUNT: int = 16
const STRESS_ZOMBIE_COUNT: int = 110
const STRESS_FRAMES: int = 180

var _checks: int = 0
var _failures: int = 0
var _next_enemy_id: int = 1
var _next_structure_id: int = 1


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_validate_catalog_contracts()
	var world: GameWorld = await _create_world()
	if world == null:
		_finish()
		return
	await _validate_kinetic_lifecycle(world)
	await _reset_combat_space(world)
	await _validate_targeting_modes(world)
	await _reset_combat_space(world)
	await _validate_chemical_burst(world)
	await _reset_combat_space(world)
	await _validate_electric_chain(world)
	await _reset_combat_space(world)
	await _validate_landmine_consume(world)
	await _reset_combat_space(world)
	await _validate_slowing_pit(world)
	await _reset_combat_space(world)
	await _validate_razor_snare(world)
	await _reset_combat_space(world)
	await _validate_trap_navigation_and_client_authority(world)
	await _reset_combat_space(world)
	await _validate_player_projectile_friendly_fire(world)
	await _reset_combat_space(world)
	await _validate_multiple_towers(world)
	await _reset_combat_space(world)
	await _validate_wave_scaling(world)
	await _reset_combat_space(world)

	# A freed first world must not leave detector callbacks or target references behind.
	var stale_tower: PlacedStructure2D = await _spawn_tower(
		world,
		StructureCatalog.T1_KINETIC,
		_scenario_origin(7)
	)
	var stale_enemy: EnemyAgent2D = _spawn_enemy(
		world,
		_scenario_origin(7) + Vector2(160.0, 0.0),
		1000
	)
	await _advance_physics_frames(8)
	var stale_controller: TowerTargetingController2D = (
		stale_tower.get_tower_combat_controller()
		if stale_tower != null
		else null
	)
	_check(
		stale_controller != null and stale_controller.get_current_target_id() == stale_enemy.enemy_id,
		"Pre-reload tower owns a live local target before world teardown"
	)
	await _dispose_world(world)
	_check(
		not is_instance_valid(stale_tower)
		and not is_instance_valid(stale_enemy)
		and not is_instance_valid(stale_controller),
		"Scene teardown frees tower, detector, and zombie without retained references"
	)

	var reloaded_world: GameWorld = await _create_world()
	if reloaded_world != null:
		await _validate_reloaded_world_combat(reloaded_world)
		await _dispose_world(reloaded_world)
	_finish()


func _validate_catalog_contracts() -> void:
	var kinetic: StructureDefinition = StructureCatalog.get_definition(StructureCatalog.T1_KINETIC)
	var chemical: StructureDefinition = StructureCatalog.get_definition(StructureCatalog.T1_CHEMICAL)
	var electric: StructureDefinition = StructureCatalog.get_definition(StructureCatalog.T1_ELECTRIC)
	var landmine: StructureDefinition = StructureCatalog.get_definition(StructureCatalog.T1_LANDMINE)
	var support: StructureDefinition = StructureCatalog.get_definition(StructureCatalog.T1_SUPPORT)
	var barricade: StructureDefinition = StructureCatalog.get_definition(StructureCatalog.T1_BARRICADE)
	var slowing_pit: StructureDefinition = StructureCatalog.get_definition(StructureCatalog.T1_SLOWING_PIT)
	var razor_snare: StructureDefinition = StructureCatalog.get_definition(StructureCatalog.T1_RAZOR_SNARE)
	_check(
		StructureCatalog.CARD_IDS.size() == 8
		and StructureCatalog.CARD_IDS[7] == StructureCatalog.T1_RAZOR_SNARE,
		"Tier-1 catalog keeps eight stable cards and appends Razor Snare after the existing IDs"
	)
	_check(
		kinetic != null
		and chemical != null
		and electric != null
		and landmine != null
		and slowing_pit != null
		and razor_snare != null
		and kinetic.has_automatic_attack()
		and chemical.has_automatic_attack()
		and electric.has_automatic_attack()
		and landmine.has_automatic_attack()
		and slowing_pit.has_automatic_attack()
		and razor_snare.has_automatic_attack(),
		"All three towers and all three traps have typed host runtime data"
	)
	_check(
		support != null
		and barricade != null
		and not support.has_automatic_attack()
		and not barricade.has_automatic_attack(),
		"Support and Barricade stay outside the automatic defense controller"
	)
	_check(
		kinetic.is_tower()
		and chemical.is_tower()
		and electric.is_tower()
		and support.is_utility()
		and barricade.is_utility()
		and landmine.is_trap()
		and slowing_pit.is_trap()
		and razor_snare.is_trap(),
		"Catalog categories distinguish three towers, three traps, and two utilities"
	)
	_check(
		kinetic.blocks_navigation
		and barricade.blocks_navigation
		and not landmine.blocks_navigation
		and not slowing_pit.blocks_navigation
		and not razor_snare.blocks_navigation,
		"Ground traps are nonblocking while towers and the Barricade remain path blockers"
	)
	var visual_paths: Dictionary[String, bool] = {}
	for definition: StructureDefinition in StructureCatalog.get_all():
		if not definition.visual_texture_path.is_empty() and definition.get_visual_texture() != null:
			visual_paths[definition.visual_texture_path] = true
	_check(visual_paths.size() == 8, "Every build card resolves a distinct catalog-owned visual texture")
	_check(
		kinetic.get_effective_range() == 360.0
		and chemical.get_effective_range() == 300.0
		and electric.get_effective_range() == 280.0
		and landmine.get_effective_range() == 56.0
		and slowing_pit.get_effective_range() == 72.0
		and razor_snare.get_effective_range() == 64.0,
		"Typed catalog ranges drive every tower and trap acquisition distance"
	)
	_check(
		landmine.get_range_visualization_radius() == 112.0
		and landmine.get_impact_radius() == 112.0
		and landmine.has_distinct_impact_radius(),
		"Landmine exposes separate trigger and blast radii for range visualization"
	)
	_check(
		kinetic.combat_profile.cooldown_seconds > 0.0
		and chemical.combat_profile.cooldown_seconds > 0.0
		and electric.combat_profile.cooldown_seconds > 0.0
		and landmine.combat_profile.consumed_on_attack
		and slowing_pit.combat_profile.movement_multiplier == 0.62
		and razor_snare.combat_profile.movement_multiplier == 0.0
		and razor_snare.combat_profile.cooldown_seconds > razor_snare.combat_profile.status_duration_seconds,
		"Trap profiles distinguish one-shot blast, persistent 38-percent slow, and reusable short root"
	)


func _validate_kinetic_lifecycle(world: GameWorld) -> void:
	var origin: Vector2 = _scenario_origin(0)
	var tower: PlacedStructure2D = await _spawn_tower(world, StructureCatalog.T1_KINETIC, origin)
	var tower_id: int = tower.instance_id if tower != null else -1
	var target: EnemyAgent2D = _spawn_enemy(world, origin + Vector2(220.0, 0.0), 1000)
	await _advance_physics_frames(8)
	var controller: TowerTargetingController2D = _get_controller(tower)
	_check(controller != null, "Kinetic structure installs a host-authoritative targeting controller")
	if controller == null:
		return
	var detector: Area2D = controller.get_node_or_null(NodePath("TowerEnemyDetection")) as Area2D
	_check(
		detector != null and detector.collision_layer == 0 and detector.collision_mask == 4,
		"Tower detection uses a clean enemy-only Area2D collision mask"
	)
	_check(
		await _wait_for_target(controller, target.enemy_id, 20),
		"One tower acquires one zombie inside its own effective range"
	)
	_check(
		controller.get_aim_direction().dot(Vector2.RIGHT) > 0.98,
		"Kinetic tower rotates its aim toward the selected zombie"
	)
	var shots_before: int = controller.get_shot_count()
	await _advance_physics_frames(48)
	var shots_after: int = controller.get_shot_count()
	_check(
		shots_after > shots_before and shots_after - shots_before <= 3,
		"Kinetic fire is automatic but remains bounded by its attack cooldown"
	)
	var firearm_stream: AudioStream = world.audio.get_stream_for_cue(AudioManager.CUE_TOWER_SHOT)
	_check(
		world.audio.get_last_cue() == AudioManager.CUE_TOWER_SHOT
		and firearm_stream is AudioStreamWAV
		and firearm_stream.resource_name == "kinetic_firearm_shot",
		"Automatic tower fire emits the positional firearm shot instead of the legacy laser cue"
	)

	world.build_system.select_structure_at(origin)
	_check(
		tower.is_range_visualization_visible()
		and tower.get_effective_range() == 360.0
		and tower.get_range_visualization_radius() == 360.0,
		"Selecting a tower exposes the same effective range used by targeting"
	)
	world.build_system.clear_structure_selection()
	_check(not tower.is_range_visualization_visible(), "Clearing selection hides the tower range ring")

	target.global_position = origin + Vector2(460.0, 0.0)
	_check(
		await _wait_for_target(controller, -1, 12),
		"Leaving the Area2D range releases a tower target immediately"
	)
	target.global_position = origin + Vector2(180.0, 0.0)
	_check(
		await _wait_for_target(controller, target.enemy_id, 16),
		"A zombie re-entering range is reacquired without a scene-wide query"
	)
	target.take_damage(target.current_health)
	_check(
		await _wait_for_target(controller, -1, 8) and controller.get_candidate_count() == 0,
		"Zombie death clears target and detector membership before a stale reference remains"
	)
	var replacement: EnemyAgent2D = _spawn_enemy(world, origin + Vector2(160.0, 0.0), 1000)
	_check(
		await _wait_for_target(controller, replacement.enemy_id, 16),
		"A tower reacquires a fresh target after the previous zombie despawns"
	)
	var shots_before_destroy: int = controller.get_shot_count()
	tower.take_damage(tower.current_health)
	await _advance_physics_frames(8)
	_check(
		world.build_system.get_structure(tower_id) == null,
		"Destroyed towers are removed from the managed structure list"
	)
	_check(
		not is_instance_valid(controller) or controller.get_shot_count() == shots_before_destroy,
		"Destroyed towers stop firing and cannot retain an active combat loop"
	)
	var sold_position: Vector2 = origin + Vector2(0.0, 620.0)
	var sold_tower: PlacedStructure2D = await _spawn_tower(
		world,
		StructureCatalog.T1_KINETIC,
		sold_position
	)
	var sold_id: int = sold_tower.instance_id if sold_tower != null else -1
	var sold_controller: TowerTargetingController2D = _get_controller(sold_tower)
	var sold_target: EnemyAgent2D = _spawn_enemy(world, sold_position + Vector2(160.0, 0.0), 1000)
	_check(
		sold_controller != null and await _wait_for_target(sold_controller, sold_target.enemy_id, 16),
		"A removable tower owns a valid target before the authoritative sell/removal path"
	)
	var removed: bool = world.build_system.remove_structure_authoritative(sold_id, &"sold")
	await _advance_physics_frames(4)
	_check(
		removed and world.build_system.get_structure(sold_id) == null,
		"Authoritative sell/removal unregisters the tower from combat state"
	)
	_check(
		not is_instance_valid(sold_controller) or sold_controller.get_current_target_id() == -1,
		"Sold towers release their targets and detector state immediately"
	)


func _validate_targeting_modes(world: GameWorld) -> void:
	var origin: Vector2 = _scenario_origin(1)
	var tower: PlacedStructure2D = await _spawn_tower(world, StructureCatalog.T1_KINETIC, origin)
	var controller: TowerTargetingController2D = _get_controller(tower)
	var nearest: EnemyAgent2D = _spawn_enemy(world, origin + Vector2(90.0, 0.0), 700)
	var strongest: EnemyAgent2D = _spawn_enemy(world, origin + Vector2(180.0, 0.0), 1000)
	var weakest: EnemyAgent2D = _spawn_enemy(world, origin + Vector2(240.0, 0.0), 200)
	var first: EnemyAgent2D = _spawn_enemy(world, origin + Vector2(-320.0, 0.0), 800)
	await _advance_physics_frames(10)
	_check(controller != null and controller.get_candidate_count() == 4, "Target modes operate on one managed local candidate list")
	if controller == null:
		return
	controller.set_targeting_mode(TowerCombatProfile.TargetingMode.NEAREST)
	_check(
		controller.get_current_target_id() == nearest.enemy_id,
		"Nearest targeting picks the closest valid zombie"
	)
	controller.set_targeting_mode(TowerCombatProfile.TargetingMode.STRONGEST)
	_check(
		controller.get_current_target_id() == strongest.enemy_id,
		"Strongest targeting picks the highest-current-health zombie"
	)
	controller.set_targeting_mode(TowerCombatProfile.TargetingMode.WEAKEST)
	_check(
		controller.get_current_target_id() == weakest.enemy_id,
		"Weakest targeting picks the lowest-current-health zombie"
	)
	controller.set_targeting_mode(TowerCombatProfile.TargetingMode.FIRST)
	_check(
		controller.get_current_target_id() == first.enemy_id,
		"First targeting prioritizes the zombie closest to the objective path"
	)


func _validate_chemical_burst(world: GameWorld) -> void:
	var origin: Vector2 = _scenario_origin(2)
	var tower: PlacedStructure2D = await _spawn_tower(world, StructureCatalog.T1_CHEMICAL, origin)
	var controller: TowerTargetingController2D = _get_controller(tower)
	var primary: EnemyAgent2D = _spawn_enemy(world, origin + Vector2(150.0, 0.0), 1000)
	var nearby: EnemyAgent2D = _spawn_enemy(world, origin + Vector2(220.0, 0.0), 1000)
	var outside_burst: EnemyAgent2D = _spawn_enemy(world, origin + Vector2(290.0, 0.0), 1000)
	await _advance_physics_frames(8)
	_check(
		controller != null and await _wait_for_shots(controller, 1, 24),
		"Chemical tower automatically fires after acquiring a clustered target"
	)
	_check(
		primary.current_health < primary.max_health and nearby.current_health < nearby.max_health,
		"Chemical burst damages the primary zombie and valid local splash targets"
	)
	_check(
		outside_burst.current_health == outside_burst.max_health,
		"Chemical burst respects its own impact radius inside the larger target range"
	)


func _validate_electric_chain(world: GameWorld) -> void:
	var origin: Vector2 = _scenario_origin(3)
	var tower: PlacedStructure2D = await _spawn_tower(world, StructureCatalog.T1_ELECTRIC, origin)
	var controller: TowerTargetingController2D = _get_controller(tower)
	var primary: EnemyAgent2D = _spawn_enemy(world, origin + Vector2(90.0, 0.0), 1000)
	var chained_one: EnemyAgent2D = _spawn_enemy(world, origin + Vector2(180.0, 0.0), 1000)
	var chained_two: EnemyAgent2D = _spawn_enemy(world, origin + Vector2(260.0, 0.0), 1000)
	var unchained: EnemyAgent2D = _spawn_enemy(world, origin + Vector2(100.0, 230.0), 1000)
	await _advance_physics_frames(8)
	_check(
		controller != null and await _wait_for_shots(controller, 1, 24),
		"Electric tower automatically attacks its selected target"
	)
	_check(
		primary.current_health < primary.max_health
		and chained_one.current_health < chained_one.max_health
		and chained_two.current_health < chained_two.max_health,
		"Electric tower chains through up to three local zombies"
	)
	_check(
		unchained.current_health == unchained.max_health,
		"Electric chain range prevents damage to a valid but non-adjacent candidate"
	)


func _validate_landmine_consume(world: GameWorld) -> void:
	var origin: Vector2 = _scenario_origin(4)
	var mine: PlacedStructure2D = await _spawn_tower(world, StructureCatalog.T1_LANDMINE, origin)
	var mine_id: int = mine.instance_id if mine != null else -1
	var controller: TowerTargetingController2D = _get_controller(mine)
	world.build_system.select_structure_at(origin)
	_check(
		mine != null
		and mine.is_range_visualization_visible()
		and mine.get_effective_range() == 56.0
		and mine.get_range_visualization_radius() == 112.0,
		"Selected landmine distinguishes its trigger radius from its blast radius"
	)
	var trigger: EnemyAgent2D = _spawn_enemy(world, origin + Vector2(40.0, 0.0), 200)
	var blast_target: EnemyAgent2D = _spawn_enemy(world, origin + Vector2(100.0, 0.0), 200)
	var outside_blast: EnemyAgent2D = _spawn_enemy(world, origin + Vector2(128.0, 0.0), 200)
	await _advance_physics_frames(6)
	_check(
		controller != null and await _wait_for_shots(controller, 1, 16),
		"Landmine triggers only after a zombie enters its short trigger radius"
	)
	_check(
		trigger.current_health < trigger.max_health and blast_target.current_health < blast_target.max_health,
		"Landmine applies radial damage to every tracked zombie in its blast radius"
	)
	_check(
		outside_blast.current_health == outside_blast.max_health,
		"Landmine blast does not damage zombies outside its effective impact radius"
	)
	await _advance_physics_frames(3)
	_check(
		world.build_system.get_structure(mine_id) == null,
		"Consumed landmine removes itself from tower targeting and placement state"
	)


func _validate_slowing_pit(world: GameWorld) -> void:
	var origin: Vector2 = _scenario_origin(9)
	var pit: PlacedStructure2D = await _spawn_tower(
		world,
		StructureCatalog.T1_SLOWING_PIT,
		origin
	)
	var controller: TowerTargetingController2D = _get_controller(pit)
	var first: EnemyAgent2D = _spawn_enemy(world, origin + Vector2(34.0, 0.0), 500)
	var second: EnemyAgent2D = _spawn_enemy(world, origin + Vector2(-42.0, 0.0), 500)
	await _advance_physics_frames(6)
	_check(
		pit != null
		and not pit.blocks_navigation()
		and pit.collision_layer == 0
		and pit.get_node_or_null(NodePath("CollisionShape2D")) == null,
		"Slowing Pit is a selectable defense without solid world/player collision"
	)
	_check(
		controller != null and await _wait_for_shots(controller, 1, 20),
		"Persistent Slowing Pit activates from its host-only enemy Area2D"
	)
	_check(
		is_equal_approx(first.get_movement_speed_multiplier(), 0.62)
		and is_equal_approx(second.get_movement_speed_multiplier(), 0.62),
		"Slowing Pit applies the configured 38-percent slow to every occupant"
	)
	var first_health: int = first.current_health
	await _advance_physics_frames(28)
	_check(
		is_equal_approx(first.get_movement_speed_multiplier(), 0.62)
		and first.current_health == first_health,
		"Pit refreshes its slow while occupied without dealing hidden damage"
	)
	first.global_position = origin + Vector2(180.0, 0.0)
	second.global_position = origin + Vector2(-180.0, 0.0)
	await _advance_physics_frames(30)
	_check(
		is_equal_approx(first.get_movement_speed_multiplier(), 1.0)
		and is_equal_approx(second.get_movement_speed_multiplier(), 1.0),
		"Persistent slow expires cleanly after zombies leave the pit"
	)


func _validate_razor_snare(world: GameWorld) -> void:
	var origin: Vector2 = _scenario_origin(10)
	var snare: PlacedStructure2D = await _spawn_tower(
		world,
		StructureCatalog.T1_RAZOR_SNARE,
		origin
	)
	var snare_id: int = snare.instance_id if snare != null else -1
	var controller: TowerTargetingController2D = _get_controller(snare)
	var target: EnemyAgent2D = _spawn_enemy(world, origin + Vector2(38.0, 0.0), 500)
	await _advance_physics_frames(6)
	_check(
		snare != null
		and not snare.blocks_navigation()
		and snare.collision_layer == 0
		and snare.get_visual_texture_path() != StructureCatalog.get_definition(
			StructureCatalog.T1_SLOWING_PIT
		).visual_texture_path,
		"Razor Snare is nonblocking and owns a silhouette distinct from the Slowing Pit"
	)
	_check(
		controller != null and await _wait_for_shots(controller, 1, 20),
		"Razor Snare triggers on a zombie inside its short host-owned radius"
	)
	var health_after_first_trigger: int = target.current_health
	_check(
		health_after_first_trigger == target.max_health - 34
		and is_equal_approx(target.get_movement_speed_multiplier(), 0.0),
		"Razor Snare deals configured damage and applies a short complete root"
	)
	await _advance_physics_frames(35)
	_check(
		is_equal_approx(target.get_movement_speed_multiplier(), 1.0)
		and world.build_system.get_structure(snare_id) == snare,
		"Razor root expires before the reusable trap rearms, without consuming the structure"
	)
	_check(
		controller != null and await _wait_for_shots(controller, 2, 70)
		and target.current_health < health_after_first_trigger,
		"Razor Snare rearms on cooldown and can damage the same surviving zombie again"
	)


func _validate_trap_navigation_and_client_authority(world: GameWorld) -> void:
	var blocker_position: Vector2 = _find_clear_grid_position(world.world_map, [])
	var trap_position: Vector2 = _find_clear_grid_position(
		world.world_map,
		[blocker_position]
	)
	_check(
		blocker_position.is_finite() and trap_position.is_finite(),
		"Navigation test finds deterministic walkable cells for a tower and trap"
	)
	if not blocker_position.is_finite() or not trap_position.is_finite():
		return
	var blocker: PlacedStructure2D = await _spawn_tower(
		world,
		StructureCatalog.T1_KINETIC,
		blocker_position
	)
	var trap: PlacedStructure2D = await _spawn_tower(
		world,
		StructureCatalog.T1_SLOWING_PIT,
		trap_position
	)
	world.flow_field.rebuild(world.build_system.get_base_position(), world.build_system.get_structures())
	var blocker_cell: Vector2i = world.world_map.world_to_flow_cell(blocker_position)
	var trap_cell: Vector2i = world.world_map.world_to_flow_cell(trap_position)
	_check(
		world.flow_field.is_cell_dynamically_blocked(blocker_cell)
		and not world.flow_field.is_cell_dynamically_blocked(trap_cell),
		"Flow raster blocks towers but keeps the zombie route through ground traps"
	)
	var trap_motion: Vector2 = world.build_system.resolve_player_motion(
		trap_position - Vector2(80.0, 0.0),
		trap_position,
		9.0
	)
	var blocker_motion: Vector2 = world.build_system.resolve_player_motion(
		blocker_position - Vector2(80.0, 0.0),
		blocker_position,
		9.0
	)
	_check(
		trap_motion.is_equal_approx(trap_position)
		and not blocker_motion.is_equal_approx(blocker_position),
		"Host player-motion resolution passes over traps but still respects tower footprints"
	)
	_check(
		world.build_system._overlaps_existing(
			trap.global_position,
			trap.get_clearance_radius()
		),
		"Nonblocking traps still participate in placement-overlap validation"
	)
	var client_shell: PlacedStructure2D = PlacedStructure2D.new()
	client_shell.configure(
		99999,
		StructureCatalog.get_definition(StructureCatalog.T1_KINETIC),
		2,
		Vector2.ZERO,
		false
	)
	root.add_child(client_shell)
	var client_starting_health: int = client_shell.current_health
	var client_damage: int = client_shell.take_damage(50)
	client_shell.apply_micro_emp(4.0)
	_check(
		client_damage == 0
		and client_shell.current_health == client_starting_health
		and not client_shell.is_emp_disabled(),
		"A client presentation shell cannot author structure damage or EMP state"
	)
	var snapshot_applied: bool = client_shell.apply_runtime_snapshot(
		120,
		2.5,
		Vector2.UP,
		0.4,
		33
	)
	_check(
		snapshot_applied
		and client_shell.current_health == 120
		and client_shell.is_emp_disabled()
		and client_shell.get_combat_aim_direction().is_equal_approx(Vector2.UP)
		and is_equal_approx(client_shell.get_combat_cooldown_remaining(), 0.4)
		and client_shell.get_combat_target_id() == 33,
		"Late-join runtime snapshot applies health, EMP, aim, cooldown, and target presentation fields"
	)
	client_shell.queue_free()
	await process_frame
	_check(blocker != null and trap != null, "Navigation fixtures remain managed until authoritative reset")


func _validate_player_projectile_friendly_fire(world: GameWorld) -> void:
	var structure: PlacedStructure2D = await _spawn_tower(
		world,
		StructureCatalog.T1_BARRICADE,
		_scenario_origin(8)
	)
	if structure == null:
		_check(false, "Friendly-fire validation can place a blocking friendly structure")
		return
	var health_before: int = structure.current_health
	var projectile: PlayerProjectile = PLAYER_PROJECTILE_SCENE.instantiate() as PlayerProjectile
	world.add_child(projectile)
	projectile.initialize(
		structure.global_position - Vector2(32.0, 0.0),
		Vector2.RIGHT,
		TEST_PEER_ID
	)
	projectile._impact(structure)
	await process_frame
	_check(
		structure.current_health == health_before,
		"Player projectiles stop on friendly WorldStatic structures without mutating their health"
	)


func _validate_multiple_towers(world: GameWorld) -> void:
	var origin: Vector2 = _scenario_origin(5)
	var first_tower: PlacedStructure2D = await _spawn_tower(world, StructureCatalog.T1_KINETIC, origin)
	var second_tower: PlacedStructure2D = await _spawn_tower(
		world,
		StructureCatalog.T1_KINETIC,
		origin + Vector2(0.0, 140.0)
	)
	var target: EnemyAgent2D = _spawn_enemy(world, origin + Vector2(180.0, 70.0), 3000)
	await _advance_physics_frames(10)
	var first_controller: TowerTargetingController2D = _get_controller(first_tower)
	var second_controller: TowerTargetingController2D = _get_controller(second_tower)
	_check(
		first_controller != null
		and second_controller != null
		and first_controller.get_current_target_id() == target.enemy_id
		and second_controller.get_current_target_id() == target.enemy_id,
		"Multiple towers can independently target the same valid zombie"
	)
	_check(
		first_controller != null
		and second_controller != null
		and await _wait_for_shots(first_controller, 1, 24)
		and await _wait_for_shots(second_controller, 1, 24),
		"Multiple towers fire independently while sharing a target"
	)
	target.take_damage(target.current_health)
	await _advance_physics_frames(4)
	_check(
		first_controller != null
		and second_controller != null
		and first_controller.get_current_target_id() == -1
		and second_controller.get_current_target_id() == -1,
		"Shared-target death releases all tower locks without stuck references"
	)


func _validate_wave_scaling(world: GameWorld) -> void:
	var origin: Vector2 = _scenario_origin(6)
	var controllers: Array[TowerTargetingController2D] = []
	for tower_index: int in range(STRESS_TOWER_COUNT):
		var column: int = tower_index % 4
		var row: int = tower_index / 4
		var tower: PlacedStructure2D = await _spawn_tower(
			world,
			StructureCatalog.T1_KINETIC,
			origin + Vector2(float(column - 1) * 38.0, float(row - 1) * 38.0)
		)
		var controller: TowerTargetingController2D = _get_controller(tower)
		if controller != null:
			controllers.append(controller)
	for enemy_index: int in range(STRESS_ZOMBIE_COUNT):
		var angle: float = TAU * float(enemy_index) / float(STRESS_ZOMBIE_COUNT)
		var radius: float = 160.0 + float(enemy_index % 5) * 22.0
		_spawn_enemy(
			world,
			origin + Vector2.from_angle(angle) * radius,
			500000
		)
	await _advance_physics_frames(12)
	var initial_candidates: int = 0
	for controller: TowerTargetingController2D in controllers:
		initial_candidates += controller.get_candidate_count()
	_check(
		controllers.size() == STRESS_TOWER_COUNT
		and initial_candidates >= STRESS_TOWER_COUNT * (STRESS_ZOMBIE_COUNT - 2),
		"Many towers maintain broad-phase-local candidate sets during a 110-zombie wave"
	)
	var passes_before: int = 0
	var evaluations_before: int = 0
	var shots_before: int = 0
	for controller: TowerTargetingController2D in controllers:
		passes_before += controller.get_selection_pass_count()
		evaluations_before += controller.get_candidate_evaluation_count()
		shots_before += controller.get_shot_count()
	var started_usec: int = Time.get_ticks_usec()
	await _advance_physics_frames(STRESS_FRAMES)
	var elapsed_ms: float = float(Time.get_ticks_usec() - started_usec) / 1000.0
	var selection_passes: int = 0
	var candidate_evaluations: int = 0
	var shots: int = 0
	var valid_target_count: int = 0
	for controller: TowerTargetingController2D in controllers:
		selection_passes += controller.get_selection_pass_count()
		candidate_evaluations += controller.get_candidate_evaluation_count()
		shots += controller.get_shot_count()
		if controller.get_current_target_id() > 0:
			var current: EnemyAgent2D = world.horde_director.get_enemy(controller.get_current_target_id())
			if is_instance_valid(current) and current.is_alive():
				valid_target_count += 1
	selection_passes -= passes_before
	candidate_evaluations -= evaluations_before
	shots -= shots_before
	print(
		"TOWER PROFILE | towers=%d zombies=%d candidates=%d selections=%d candidate_evaluations=%d shots=%d elapsed_ms=%.2f" % [
			controllers.size(),
			world.horde_director.get_alive_count(),
			initial_candidates,
			selection_passes,
			candidate_evaluations,
			shots,
			elapsed_ms,
		]
	)
	_check(
		selection_passes <= STRESS_TOWER_COUNT * 30
		and candidate_evaluations <= STRESS_TOWER_COUNT * STRESS_ZOMBIE_COUNT * 30,
		"Wave selection remains cadence-bounded instead of rescanning per tower every frame"
	)
	_check(
		shots > 0 and valid_target_count == controllers.size(),
		"Many towers continue firing and retain only valid targets during a dense wave"
	)


func _validate_reloaded_world_combat(world: GameWorld) -> void:
	var origin: Vector2 = _scenario_origin(8)
	var tower: PlacedStructure2D = await _spawn_tower(world, StructureCatalog.T1_ELECTRIC, origin)
	var target: EnemyAgent2D = _spawn_enemy(world, origin + Vector2(140.0, 0.0), 1000)
	var controller: TowerTargetingController2D = _get_controller(tower)
	_check(
		controller != null and await _wait_for_target(controller, target.enemy_id, 20),
		"Fresh GameWorld rebuilds a new tower detector after scene reload"
	)
	_check(
		controller != null and await _wait_for_shots(controller, 1, 24),
		"Reloaded world resumes host-authoritative automatic tower fire"
	)


func _create_world() -> GameWorld:
	var world: GameWorld = GAME_WORLD_SCENE.instantiate() as GameWorld
	if world == null:
		_check(false, "GameWorld scene instantiates for tower combat validation")
		return null
	world.configure_launch(CoopSession.SessionMode.SOLO, &"heikki", "127.0.0.1")
	root.add_child(world)
	for _frame_index: int in range(4):
		await process_frame
		await physics_frame
	return world


func _dispose_world(world: GameWorld) -> void:
	if not is_instance_valid(world):
		return
	world.horde_director.reset_for_session()
	world.build_system.reset_for_session()
	if is_instance_valid(world.audio):
		world.audio.stop_all()
	if is_instance_valid(world.juice_rig):
		world.juice_rig.stop_all()
	await process_frame
	await create_timer(0.12).timeout
	world.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.1).timeout


func _reset_combat_space(world: GameWorld) -> void:
	world.horde_director.reset_for_session()
	world.build_system.reset_for_session()
	await process_frame
	await _advance_physics_frames(3)


func _spawn_tower(
	world: GameWorld,
	structure_id: StringName,
	world_position: Vector2
) -> PlacedStructure2D:
	var instance_id: int = _next_structure_id
	_next_structure_id += 1
	world.build_system._spawn_structure(
		instance_id,
		structure_id,
		TEST_PEER_ID,
		world_position,
		false
	)
	await process_frame
	await physics_frame
	return world.build_system.get_structure(instance_id)


func _spawn_enemy(
	world: GameWorld,
	world_position: Vector2,
	health: int,
	damage: int = 1,
	speed: float = 1.0
) -> EnemyAgent2D:
	var enemy_id: int = _next_enemy_id
	_next_enemy_id += 1
	world.horde_director._commit_enemy_spawn(
		enemy_id,
		EnemyAgent2D.Variant.WALKER,
		world_position,
		health,
		damage,
		speed
	)
	return world.horde_director.get_enemy(enemy_id)


func _get_controller(tower: PlacedStructure2D) -> TowerTargetingController2D:
	if not is_instance_valid(tower):
		return null
	return tower.get_tower_combat_controller()


func _scenario_origin(index: int) -> Vector2:
	return TEST_ORIGIN + Vector2(float(index) * 1200.0, 0.0)


func _find_clear_grid_position(
	world_map: BesprenWorldMap2D,
	excluded_positions: Array[Vector2]
) -> Vector2:
	for cell_y: int in range(-48, 49):
		for cell_x: int in range(-48, 49):
			var candidate: Vector2 = Vector2(float(cell_x) * 64.0, float(cell_y) * 64.0)
			if not world_map.is_position_walkable(candidate, 96.0):
				continue
			var separated: bool = true
			for excluded_position: Vector2 in excluded_positions:
				if candidate.distance_squared_to(excluded_position) < 512.0 * 512.0:
					separated = false
					break
			if separated:
				return candidate
	return Vector2.INF


func _wait_for_target(
	controller: TowerTargetingController2D,
	target_id: int,
	maximum_frames: int
) -> bool:
	if not is_instance_valid(controller):
		return false
	for _frame_index: int in range(maximum_frames):
		if controller.get_current_target_id() == target_id:
			return true
		await physics_frame
	return is_instance_valid(controller) and controller.get_current_target_id() == target_id


func _wait_for_shots(
	controller: TowerTargetingController2D,
	minimum_shots: int,
	maximum_frames: int
) -> bool:
	if not is_instance_valid(controller):
		return false
	for _frame_index: int in range(maximum_frames):
		if controller.get_shot_count() >= minimum_shots:
			return true
		await physics_frame
	return is_instance_valid(controller) and controller.get_shot_count() >= minimum_shots


func _advance_physics_frames(frame_count: int) -> void:
	for _frame_index: int in range(frame_count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS | %s" % message)
		return
	_failures += 1
	push_error("FAIL | %s" % message)


func _finish() -> void:
	if _failures == 0:
		print("TOWER COMBAT OK (%d checks)" % _checks)
		quit(0)
		return
	push_error("TOWER COMBAT FAILED (%d/%d checks failed)" % [_failures, _checks])
	quit(1)
