extends SceneTree
## GameWorld integration gate for authoritative Android-style auto aim.

const GAME_WORLD_SCENE: PackedScene = preload("res://scenes/game/game_world.tscn")
const AutoAimController = preload("res://src/combat/auto_aim_controller_2d.gd")
const TEST_ORIGIN: Vector2 = Vector2(30000.0, 30000.0)
const TEST_PEER_ID: int = CoopSession.AUTHORITY_PEER_ID
const FRAME_RATE: float = 60.0

var _checks: int = 0
var _failures: int = 0
var _next_enemy_id: int = 1
var _last_projectile_direction: Vector2 = Vector2.ZERO
var _projectile_fire_count: int = 0
var _target_history: Array[int] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var world: GameWorld = await _create_world()
	if world == null:
		_finish()
		return
	var controller: AutoAimController = world.get_auto_aim_controller(TEST_PEER_ID)
	var player: PlayerAvatar = _get_player(world)
	_check(controller != null, "GameWorld installs a host-only auto-aim controller")
	_check(player != null, "GameWorld retains its authoritative player avatar")
	if controller == null or player == null:
		world.queue_free()
		await process_frame
		_finish()
		return
	controller.maximum_targeting_angle_degrees = 180.0
	controller.require_line_of_sight = true
	controller.debug_visualization = false
	controller.target_changed.connect(_on_target_changed)
	world.session.projectile_fired.connect(_on_projectile_fired)

	await _validate_single_target_smooth_fire(world, controller, player)
	await _clear_spawned_enemies(world)
	await _validate_weighted_score_and_hysteresis(world, controller)
	await _clear_spawned_enemies(world)
	await _validate_many_candidates_and_movement(world, controller)
	await _clear_spawned_enemies(world)
	await _validate_motion_prediction(world, controller)
	await _clear_spawned_enemies(world)
	await _validate_radius_death_and_reacquire(world, controller)
	await _clear_spawned_enemies(world)
	await _validate_visibility_and_weapon_range(world, controller)
	await _clear_spawned_enemies(world)
	await _validate_equal_score_stability(world, controller)
	await _clear_spawned_enemies(world)
	await _validate_default_dead_zone(world, controller, player)
	await _clear_spawned_enemies(world)
	await _validate_all_enemy_variants(world, controller)
	await _clear_spawned_enemies(world)
	await _validate_fire_rechecks_line_of_sight(world, controller, player)

	world.queue_free()
	await process_frame
	await process_frame
	_finish()


func _create_world() -> GameWorld:
	var world: GameWorld = GAME_WORLD_SCENE.instantiate() as GameWorld
	if world == null:
		_check(false, "GameWorld scene instantiates for auto-aim integration")
		return null
	world.configure_launch(CoopSession.SessionMode.SOLO, &"heikki", "127.0.0.1")
	root.add_child(world)
	for _frame_index: int in range(4):
		await process_frame
		await physics_frame
	world.session.teleport_peer_authoritative(TEST_PEER_ID, TEST_ORIGIN)
	for _frame_index: int in range(3):
		await physics_frame
	return world


func _validate_single_target_smooth_fire(
	world: GameWorld,
	controller: AutoAimController,
	player: PlayerAvatar
) -> void:
	var target: EnemyAgent2D = await _spawn_enemy(
		world,
		TEST_ORIGIN + Vector2(0.0, 320.0),
		12,
		1.0
	)
	await _advance_physics_frames(20)
	controller.force_refresh()
	_check(
		controller.get_current_target_id() == target.enemy_id,
		"One valid zombie is acquired inside the configured radius"
	)
	var initial_error: float = absf(Vector2.RIGHT.angle_to(Vector2.DOWN))
	var final_error: float = absf(controller.get_aim_direction().angle_to(Vector2.DOWN))
	_check(
		final_error < initial_error and final_error < deg_to_rad(8.0),
		"Aim rotates smoothly toward a stationary off-axis zombie"
	)
	_check(
		player.is_assisted_aim_active(),
		"Auto aim drives presentation aim without changing movement authority"
	)
	player.apply_authoritative_state(player.global_position, Vector2.LEFT)
	await physics_frame
	await process_frame
	_check(
		player.get_movement_facing_direction().dot(Vector2.LEFT) > 0.99
		and player.get_facing_direction().dot(controller.get_aim_direction()) > 0.98,
		"Movement-facing changes do not fight the locked combat aim presentation"
	)
	player.apply_authoritative_state(player.global_position, Vector2.RIGHT)
	_projectile_fire_count = 0
	_last_projectile_direction = Vector2.ZERO
	world._on_touch_action_pressed(&"fire")
	_check(_projectile_fire_count == 1, "Mobile Fire input still routes through the existing host cooldown")
	_check(
		_last_projectile_direction.dot(Vector2.DOWN) > 0.98,
		"Stationary fire uses the host-selected auto-aim direction"
	)
	await _advance_physics_frames(34)
	_check(
		world.projectiles_root.get_active_count() == 0,
		"EnemyAgent2D projectile impacts return projectiles to the fixed pool"
	)


func _validate_weighted_score_and_hysteresis(
	world: GameWorld,
	controller: AutoAimController
) -> void:
	controller.maximum_targeting_angle_degrees = 180.0
	controller.current_target_bias = 0.20
	controller.switching_threshold = 0.18
	controller.minimum_lock_duration_seconds = 0.35
	var forward_target: EnemyAgent2D = await _spawn_enemy(
		world,
		TEST_ORIGIN + Vector2(420.0, 0.0),
		12,
		104.0
	)
	var nearer_rear_target: EnemyAgent2D = await _spawn_enemy(
		world,
		TEST_ORIGIN + Vector2(-250.0, 0.0),
		12,
		104.0
	)
	var side_target: EnemyAgent2D = await _spawn_enemy(
		world,
		TEST_ORIGIN + Vector2(0.0, 300.0),
		12,
		104.0
	)
	var outer_left_target: EnemyAgent2D = await _spawn_enemy(
		world,
		TEST_ORIGIN + Vector2(-420.0, 120.0),
		12,
		104.0
	)
	var outer_right_target: EnemyAgent2D = await _spawn_enemy(
		world,
		TEST_ORIGIN + Vector2(520.0, -160.0),
		12,
		104.0
	)
	await _advance_physics_frames(12)
	controller.force_refresh()
	_check(
		is_instance_valid(outer_left_target)
		and is_instance_valid(outer_right_target)
		and controller.get_candidate_count() >= 5,
		"Five simultaneous zombies are scored from the maintained detector set"
	)
	_check(
		controller.get_current_target_id() == forward_target.enemy_id,
		"Weighted alignment selects a useful forward zombie over the nearest rear zombie"
	)
	nearer_rear_target.global_position = TEST_ORIGIN + Vector2(400.0, 0.0)
	await _advance_physics_frames(4)
	controller.force_refresh()
	_check(
		controller.get_current_target_id() == forward_target.enemy_id,
		"Minimum lock duration prevents immediate target churn"
	)
	await _advance_physics_frames(28)
	controller.force_refresh()
	_check(
		controller.get_current_target_id() == forward_target.enemy_id,
		"Current-target bias and threshold reject marginally better candidates"
	)
	forward_target.global_position = TEST_ORIGIN + Vector2(-700.0, 0.0)
	nearer_rear_target.global_position = TEST_ORIGIN + Vector2(110.0, 0.0)
	side_target.global_position = TEST_ORIGIN + Vector2(0.0, 560.0)
	await _advance_physics_frames(4)
	controller.force_refresh()
	_check(
		controller.get_current_target_id() == nearer_rear_target.enemy_id,
		"Target switches only when another zombie is significantly better"
	)


func _validate_many_candidates_and_movement(
	world: GameWorld,
	controller: AutoAimController
) -> void:
	controller.maximum_targeting_angle_degrees = 180.0
	var ids: Array[int] = []
	for index: int in range(12):
		var angle: float = TAU * float(index) / 12.0
		var enemy: EnemyAgent2D = await _spawn_enemy(
			world,
			TEST_ORIGIN + Vector2.from_angle(angle) * (360.0 + float(index % 3) * 40.0),
			12 + index,
			96.0 + float(index)
		)
		ids.append(enemy.enemy_id)
	await _advance_physics_frames(16)
	var refresh_before: int = controller.get_selection_refresh_count()
	controller.force_refresh()
	_check(
		controller.get_candidate_count() >= 10,
		"Ten-plus simultaneous zombies are maintained as local detector candidates"
	)
	_check(
		controller.get_current_target_id() in ids,
		"A scored target is selected from the multi-zombie candidate set"
	)
	var tracked: EnemyAgent2D = _get_enemy(world, controller.get_current_target_id())
	var maximum_step: float = deg_to_rad(controller.aim_rotation_speed_degrees_per_second) / FRAME_RATE
	var previous_direction: Vector2 = controller.get_aim_direction()
	var smooth: bool = tracked != null
	if tracked != null:
		for step: int in range(10):
			tracked.global_position = TEST_ORIGIN + Vector2.from_angle(
				deg_to_rad(20.0 + float(step) * 7.0)
			) * 360.0
			await physics_frame
			var next_direction: Vector2 = controller.get_aim_direction()
			if absf(previous_direction.angle_to(next_direction)) > maximum_step + deg_to_rad(1.0):
				smooth = false
			previous_direction = next_direction
	_check(smooth, "Moving zombies produce bounded, mobile-friendly aim rotation")
	var refresh_after: int = controller.get_selection_refresh_count()
	_check(
		refresh_after - refresh_before < 16,
		"Selection refreshes at a bounded cadence rather than scanning every frame"
	)


func _validate_radius_death_and_reacquire(
	world: GameWorld,
	controller: AutoAimController
) -> void:
	controller.maximum_targeting_angle_degrees = 180.0
	var candidate: EnemyAgent2D = await _spawn_enemy(
		world,
		TEST_ORIGIN + Vector2(980.0, 0.0),
		16,
		110.0
	)
	await _advance_physics_frames(4)
	_check(
		controller.get_current_target_id() == -1,
		"Zombies outside the detection radius are not locked"
	)
	candidate.global_position = TEST_ORIGIN + Vector2(240.0, 0.0)
	await _advance_physics_frames(8)
	controller.force_refresh()
	_check(
		controller.get_current_target_id() == candidate.enemy_id,
		"Zombie entry into the radius acquires reliably"
	)
	candidate.global_position = TEST_ORIGIN + Vector2(900.0, 0.0)
	await physics_frame
	_check(
		controller.get_current_target_id() == -1,
		"Leaving the allowed targeting area releases the lock immediately"
	)
	candidate.global_position = TEST_ORIGIN + Vector2(220.0, 0.0)
	await _advance_physics_frames(8)
	controller.force_refresh()
	_check(
		controller.get_current_target_id() == candidate.enemy_id,
		"Re-entering the radius reacquires a valid zombie"
	)
	candidate.take_damage(candidate.current_health)
	await physics_frame
	_check(
		controller.get_current_target_id() == -1,
		"Zombie death clears the lock before an invalid reference can persist"
	)


func _validate_motion_prediction(
	world: GameWorld,
	controller: AutoAimController
) -> void:
	controller.maximum_targeting_angle_degrees = 180.0
	var previous_smoothing: float = controller.aim_smoothing
	var previous_turn_speed: float = controller.aim_rotation_speed_degrees_per_second
	controller.aim_smoothing = 0.0
	controller.aim_rotation_speed_degrees_per_second = 1440.0
	var target: EnemyAgent2D = await _spawn_enemy(
		world,
		TEST_ORIGIN + Vector2(400.0, 0.0),
		12,
		1.0
	)
	await _advance_physics_frames(10)
	controller.force_refresh()
	await process_frame
	_check(
		controller.get_current_target_id() == target.enemy_id,
		"A moving target remains a valid auto-aim candidate"
	)
	target.global_position += Vector2(0.0, 10.0)
	await physics_frame
	await process_frame
	_check(
		controller.get_aim_direction().y > 0.05,
		"Target lead samples the real physics delta for consistent mobile movement"
	)
	controller.aim_smoothing = previous_smoothing
	controller.aim_rotation_speed_degrees_per_second = previous_turn_speed


func _validate_visibility_and_weapon_range(
	world: GameWorld,
	controller: AutoAimController
) -> void:
	controller.maximum_targeting_angle_degrees = 180.0
	controller.weapon_effective_range = 1240.0
	var blocked: EnemyAgent2D = await _spawn_enemy(
		world,
		TEST_ORIGIN + Vector2(0.0, 360.0),
		18,
		100.0
	)
	var obstacle: StaticBody2D = _create_visibility_obstacle(TEST_ORIGIN + Vector2(0.0, 180.0))
	world.add_child(obstacle)
	await _advance_physics_frames(5)
	controller.force_refresh()
	_check(
		controller.get_current_target_id() == -1,
		"WorldStatic visibility blocks unreachable zombie locks"
	)
	obstacle.queue_free()
	await _advance_physics_frames(4)
	controller.force_refresh()
	_check(
		controller.get_current_target_id() == blocked.enemy_id,
		"Removing the obstruction makes the visible zombie acquirable"
	)
	blocked.take_damage(blocked.current_health)
	await physics_frame
	controller.weapon_effective_range = 300.0
	var too_far: EnemyAgent2D = await _spawn_enemy(
		world,
		TEST_ORIGIN + Vector2(520.0, 0.0),
		12,
		96.0
	)
	await _advance_physics_frames(6)
	controller.force_refresh()
	_check(
		controller.get_current_target_id() == -1,
		"Weapon range rejects a detector candidate outside the usable firing range"
	)
	controller.weapon_effective_range = 1240.0
	controller.force_refresh()
	_check(
		controller.get_current_target_id() == too_far.enemy_id,
		"Restoring weapon range reacquires the same valid candidate"
	)


func _validate_equal_score_stability(
	world: GameWorld,
	controller: AutoAimController
) -> void:
	controller.maximum_targeting_angle_degrees = 180.0
	var first: EnemyAgent2D = await _spawn_enemy(
		world,
		TEST_ORIGIN + Vector2(300.0, 180.0),
		12,
		100.0
	)
	var second: EnemyAgent2D = await _spawn_enemy(
		world,
		TEST_ORIGIN + Vector2(300.0, -180.0),
		12,
		100.0
	)
	await _advance_physics_frames(10)
	controller.force_refresh()
	var expected_target_id: int = mini(first.enemy_id, second.enemy_id)
	_check(
		controller.get_current_target_id() == expected_target_id,
		"Equal-score targets use a deterministic lowest-ID tiebreaker"
	)
	_target_history.clear()
	for _refresh_index: int in range(8):
		await _advance_physics_frames(6)
		controller.force_refresh()
		_target_history.append(controller.get_current_target_id())
	var stable: bool = true
	for target_id: int in _target_history:
		if target_id != expected_target_id:
			stable = false
	_check(stable, "Equally close zombies do not cause target-switch jitter")


func _validate_default_dead_zone(
	world: GameWorld,
	controller: AutoAimController,
	player: PlayerAvatar
) -> void:
	controller.maximum_targeting_angle_degrees = 150.0
	player.apply_authoritative_state(player.global_position, Vector2.RIGHT)
	var target: EnemyAgent2D = await _spawn_enemy(
		world,
		TEST_ORIGIN + Vector2.from_angle(deg_to_rad(160.0)) * 260.0,
		12,
		1.0
	)
	await _advance_physics_frames(8)
	controller.force_refresh()
	_check(
		controller.get_current_target_id() == -1,
		"The default 150-degree cone keeps a 30-degree rear dead zone"
	)
	target.global_position = TEST_ORIGIN + Vector2.from_angle(deg_to_rad(140.0)) * 260.0
	await _advance_physics_frames(8)
	controller.force_refresh()
	_check(
		controller.get_current_target_id() == target.enemy_id,
		"A zombie just inside the default 150-degree cone remains targetable"
	)
	controller.maximum_targeting_angle_degrees = 180.0


func _validate_all_enemy_variants(
	world: GameWorld,
	controller: AutoAimController
) -> void:
	controller.maximum_targeting_angle_degrees = 180.0
	for variant_id: int in range(EnemyPresentationCatalog.VARIANT_COUNT):
		var target: EnemyAgent2D = await _spawn_enemy(
			world,
			TEST_ORIGIN + Vector2(240.0, 0.0),
			12 + variant_id,
			1.0,
			variant_id
		)
		await _advance_physics_frames(8)
		controller.force_refresh()
		_check(
			controller.get_current_target_id() == target.enemy_id,
			"Auto aim acquires gameplay variant %d through the shared enemy collision contract"
			% variant_id
		)
		await _clear_spawned_enemies(world)


func _validate_fire_rechecks_line_of_sight(
	world: GameWorld,
	controller: AutoAimController,
	player: PlayerAvatar
) -> void:
	controller.maximum_targeting_angle_degrees = 180.0
	controller.selection_refresh_seconds = 0.5
	controller.require_line_of_sight = true
	player.apply_authoritative_state(player.global_position, Vector2.RIGHT)
	var target: EnemyAgent2D = await _spawn_enemy(
		world,
		TEST_ORIGIN + Vector2(0.0, 320.0),
		12,
		1.0
	)
	await _advance_physics_frames(20)
	controller.force_refresh()
	_check(
		controller.get_current_target_id() == target.enemy_id,
		"A visible zombie is locked before the fire-time LOS regression setup"
	)
	var firing_origin: Vector2 = controller._get_targeting_origin()
	var obstacle: StaticBody2D = _create_visibility_obstacle(
		(firing_origin + target.global_position) * 0.5
	)
	world.add_child(obstacle)
	await _advance_physics_frames(3)
	world.session._interaction_ready_at[TEST_PEER_ID] = 0.0
	_check(
		not controller._has_line_of_sight(target),
		"The newly inserted WorldStatic obstacle intersects the locked firing ray"
	)
	_check(
		world.session.is_interaction_ready(TEST_PEER_ID),
		"Fire-time LOS regression runs with the host interaction cooldown ready"
	)
	_projectile_fire_count = 0
	_last_projectile_direction = Vector2.ZERO
	world._on_touch_action_pressed(&"fire")
	_check(
		controller.get_current_target_id() == -1,
		"Fire synchronously releases a lock blocked after the last selection refresh"
	)
	_check(
		_projectile_fire_count == 1
		and _last_projectile_direction.dot(Vector2.RIGHT) > 0.99,
		"A newly blocked shot immediately falls back to authoritative manual facing"
	)
	obstacle.queue_free()
	await physics_frame
	controller.selection_refresh_seconds = 0.08


func _spawn_enemy(
	world: GameWorld,
	world_position: Vector2,
	damage: int,
	speed: float,
	spawn_variant: int = EnemyAgent2D.Variant.WALKER
) -> EnemyAgent2D:
	var enemy_id: int = _next_enemy_id
	_next_enemy_id += 1
	world.horde_director._commit_enemy_spawn(
		enemy_id,
		spawn_variant,
		world_position,
		90,
		damage,
		speed
	)
	await physics_frame
	return _get_enemy(world, enemy_id)


func _get_enemy(world: GameWorld, enemy_id: int) -> EnemyAgent2D:
	return world.horde_director.get_enemy(enemy_id)


func _clear_spawned_enemies(world: GameWorld) -> void:
	for enemy_id: int in range(1, _next_enemy_id):
		var enemy: EnemyAgent2D = _get_enemy(world, enemy_id)
		if is_instance_valid(enemy) and enemy.is_alive():
			enemy.take_damage(enemy.current_health)
	await physics_frame
	await physics_frame


func _create_visibility_obstacle(world_position: Vector2) -> StaticBody2D:
	var obstacle: StaticBody2D = StaticBody2D.new()
	obstacle.collision_layer = 2
	obstacle.collision_mask = 0
	obstacle.global_position = world_position
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(120.0, 44.0)
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	obstacle.add_child(collision)
	return obstacle


func _get_player(world: GameWorld) -> PlayerAvatar:
	var player: PlayerAvatar = world._players.get(TEST_PEER_ID)
	return player


func _advance_physics_frames(frame_count: int) -> void:
	for _frame_index: int in range(frame_count):
		await physics_frame


func _on_projectile_fired(
	_peer_id: int,
	_position: Vector2,
	direction: Vector2
) -> void:
	_projectile_fire_count += 1
	_last_projectile_direction = direction


func _on_target_changed(
	_peer_id: int,
	_previous_target_id: int,
	current_target_id: int
) -> void:
	_target_history.append(current_target_id)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS | %s" % message)
		return
	_failures += 1
	push_error("FAIL | %s" % message)


func _finish() -> void:
	if _failures == 0:
		print("AUTO AIM OK (%d checks)" % _checks)
		quit(0)
		return
	push_error("AUTO AIM FAILED (%d/%d checks failed)" % [_failures, _checks])
	quit(1)
