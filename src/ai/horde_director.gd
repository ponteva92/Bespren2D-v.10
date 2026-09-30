class_name HordeDirector
extends Node
## Replicated peer-one wave authority with a hard 110-alive hardware ceiling.

signal wave_clock_changed(seconds_remaining: int, frozen: bool)
signal boss_gate_changed(active: bool, boss_name: StringName, bosses_remaining: int)
signal alive_count_changed(alive_count: int, maximum_alive: int)
signal wave_completed(night_number: int)
## Raised on every peer as a corpse is presented, carrying the variant's own
## body tint so debris is the colour of the thing that came apart. The director
## owns when an enemy dies; it deliberately does not own what that looks like,
## so the burst is left to whatever is listening.
signal enemy_death_presented(world_position: Vector2, tint: Color, body_radius: float)

const MAX_ALIVE_ENEMIES: int = 110
const NIGHT_WAVE_DURATION_SECONDS: float = 90.0
const BASE_SPAWN_INTERVAL_SECONDS: float = 1.4
const TWO_PLAYER_STAT_SCALE: float = 1.25
const AGGRO_PROXIMITY_RADIUS: float = 440.0
const AGGRO_REFRESH_SECONDS: float = 0.10
const SNAPSHOT_INTERVAL_SECONDS: float = 0.10
const CLOCK_BROADCAST_INTERVAL_SECONDS: float = 0.25
const DEATH_PRESENTATION_SEED_SALT: int = 2411
const BOSS_NIGHTS: Dictionary[int, int] = {
	5: EnemyAgent2D.Variant.GOLIATH,
	10: EnemyAgent2D.Variant.CARRIER,
	15: EnemyAgent2D.Variant.SPLITTER,
	20: EnemyAgent2D.Variant.OVERLORD,
}
const EnemyDeathPresentationView = preload("res://src/visual/enemy_death_presentation_2d.gd")

@export_node_path("CoopSession") var session_path: NodePath
@export_node_path("BesprenWorldMap2D") var world_map_path: NodePath
@export_node_path("FlowFieldNavigation2D") var flow_field_path: NodePath
@export_node_path("CombatStateCoordinator") var combat_state_path: NodePath
@export_node_path("TacticalBuildSystem") var build_system_path: NodePath
@export_node_path("Node2D") var enemies_root_path: NodePath
@export_node_path("BloodCanvas") var blood_canvas_path: NodePath

var _session: CoopSession
var _world_map: BesprenWorldMap2D
var _flow_field: FlowFieldNavigation2D
var _combat_state: CombatStateCoordinator
var _build_system: TacticalBuildSystem
var _enemies_root: Node2D
var _blood_canvas: BloodCanvas
var _aggro_matrix: EnemyAggroMatrix = EnemyAggroMatrix.new()
var _enemies: Dictionary[int, EnemyAgent2D] = {}
var _next_enemy_id: int = 1
var _night_number: int = 1
var _wave_active: bool = false
var _wave_seconds_remaining: float = NIGHT_WAVE_DURATION_SECONDS
var _spawn_accumulator: float = 0.0
var _spawn_sequence: int = 0
var _normal_spawn_quota: int = 0
var _normal_spawned: int = 0
var _bosses_remaining: int = 0
var _boss_name: StringName = &""
var _co_op_player_count: int = 1
var _aggro_accumulator: float = 0.0
var _snapshot_accumulator: float = 0.0
var _clock_accumulator: float = 0.0


func _ready() -> void:
	_session = get_node_or_null(session_path) as CoopSession
	_world_map = get_node_or_null(world_map_path) as BesprenWorldMap2D
	_flow_field = get_node_or_null(flow_field_path) as FlowFieldNavigation2D
	_combat_state = get_node_or_null(combat_state_path) as CombatStateCoordinator
	_build_system = get_node_or_null(build_system_path) as TacticalBuildSystem
	_enemies_root = get_node_or_null(enemies_root_path) as Node2D
	_blood_canvas = get_node_or_null(blood_canvas_path) as BloodCanvas
	set_process(true)


func _process(delta: float) -> void:
	if not multiplayer.is_server() or not _wave_active:
		return
	if is_instance_valid(_combat_state) and _combat_state.is_game_over():
		return
	_advance_host(maxf(delta, 0.0))


func begin_night_authoritative(night_number: int) -> void:
	if not multiplayer.is_server() or _wave_active:
		return
	_night_number = maxi(night_number, 1)
	_co_op_player_count = 1
	if is_instance_valid(_session):
		_co_op_player_count = clampi(_session.get_registered_peer_ids().size(), 1, 2)
	_normal_spawn_quota = mini(24 + _night_number * 4, MAX_ALIVE_ENEMIES - 1)
	_normal_spawned = 0
	_spawn_sequence = 0
	_spawn_accumulator = get_spawn_interval()
	_wave_seconds_remaining = NIGHT_WAVE_DURATION_SECONDS
	_wave_active = true
	_bosses_remaining = 0
	_boss_name = &""
	_commit_wave_started.rpc(
		_night_number,
		ceili(_wave_seconds_remaining),
		_normal_spawn_quota,
		_co_op_player_count
	)
	var boss_variant: int = get_boss_variant_for_night(_night_number)
	if boss_variant >= 0:
		_bosses_remaining = 1
		_boss_name = EnemyPresentationCatalog.get_variant_name(boss_variant)
		_commit_boss_gate.rpc(true, _boss_name, _bosses_remaining)
		_spawn_variant_authoritative(boss_variant, true)


func stop_for_game_over() -> void:
	if not multiplayer.is_server():
		return
	_wave_active = false
	_commit_wave_stopped.rpc()


func reset_for_session() -> void:
	_clear_death_presentations()
	_clear_all_enemies()
	_aggro_matrix.clear()
	_next_enemy_id = 1
	_night_number = 1
	_wave_active = false
	_wave_seconds_remaining = NIGHT_WAVE_DURATION_SECONDS
	_spawn_accumulator = 0.0
	_spawn_sequence = 0
	_normal_spawn_quota = 0
	_normal_spawned = 0
	_bosses_remaining = 0
	_boss_name = &""
	if is_instance_valid(_blood_canvas):
		_blood_canvas.clear_decals()


func handle_navigation_changed() -> void:
	if not is_instance_valid(_flow_field) or not is_instance_valid(_build_system):
		return
	_flow_field.rebuild(_build_system.get_base_position(), _build_system.get_structures())
	for enemy: EnemyAgent2D in _enemies.values():
		if is_instance_valid(enemy):
			enemy.set_base_target(_build_system.get_base_position())


func sync_state_to_peer(peer_id: int) -> void:
	if not multiplayer.is_server() or peer_id <= CoopSession.AUTHORITY_PEER_ID:
		return
	var enemy_ids: PackedInt32Array = PackedInt32Array()
	var variants: PackedInt32Array = PackedInt32Array()
	var positions: PackedVector2Array = PackedVector2Array()
	var health_values: PackedInt32Array = PackedInt32Array()
	var maximum_health_values: PackedInt32Array = PackedInt32Array()
	var damage_values: PackedInt32Array = PackedInt32Array()
	var speed_values: PackedFloat32Array = PackedFloat32Array()
	var movement_multipliers: PackedFloat32Array = PackedFloat32Array()
	var facing_rows: PackedByteArray = PackedByteArray()
	var presentation_tokens: PackedInt32Array = PackedInt32Array()
	var sorted_ids: Array[int] = _enemies.keys()
	sorted_ids.sort()
	for enemy_id: int in sorted_ids:
		var enemy: EnemyAgent2D = _enemies[enemy_id]
		enemy_ids.append(enemy_id)
		variants.append(enemy.variant)
		positions.append(enemy.global_position)
		health_values.append(enemy.current_health)
		maximum_health_values.append(enemy.max_health)
		damage_values.append(enemy.attack_damage)
		speed_values.append(enemy.movement_speed)
		movement_multipliers.append(enemy.get_movement_speed_multiplier())
		facing_rows.append(enemy.get_presentation_facing_row())
		presentation_tokens.append(enemy.get_presentation_token())
	_receive_horde_snapshot.rpc_id(
		peer_id,
		_night_number,
		_wave_active,
		ceili(_wave_seconds_remaining),
		_normal_spawn_quota,
		_normal_spawned,
		_co_op_player_count,
		_bosses_remaining,
		String(_boss_name),
		enemy_ids,
		variants,
		positions,
		health_values,
		maximum_health_values,
		damage_values,
		speed_values,
		movement_multipliers,
		facing_rows,
		presentation_tokens
	)


func get_alive_count() -> int:
	return _enemies.size()


func get_bosses_remaining() -> int:
	return _bosses_remaining


func is_pacing_frozen() -> bool:
	return _wave_active and _bosses_remaining > 0


func is_wave_active() -> bool:
	return _wave_active


func get_wave_seconds_remaining() -> float:
	return _wave_seconds_remaining


func get_spawn_interval() -> float:
	return calculate_spawn_interval(_co_op_player_count)


func get_enemy(enemy_id: int) -> EnemyAgent2D:
	return _enemies.get(enemy_id)


func get_alive_variants() -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	var sorted_ids: Array[int] = _enemies.keys()
	sorted_ids.sort()
	for enemy_id: int in sorted_ids:
		result.append(_enemies[enemy_id].variant)
	return result


func advance_wave_for_test(delta: float) -> void:
	if multiplayer.is_server() and _wave_active:
		_advance_host(maxf(delta, 0.0))


func defeat_bosses_for_test() -> void:
	if not multiplayer.is_server():
		return
	var boss_ids: Array[int] = []
	for enemy_id: int in _enemies:
		if _enemies[enemy_id].is_boss():
			boss_ids.append(enemy_id)
	for enemy_id: int in boss_ids:
		var boss: EnemyAgent2D = _enemies.get(enemy_id)
		if is_instance_valid(boss):
			boss.take_damage(boss.current_health)


static func get_boss_variant_for_night(night_number: int) -> int:
	return BOSS_NIGHTS.get(night_number, -1)


static func get_rotation_variant(night_number: int, sequence: int) -> int:
	var candidates: Array[int] = [EnemyAgent2D.Variant.WALKER]
	if night_number >= 6:
		candidates.append(EnemyAgent2D.Variant.RAT_SWARM)
	if night_number >= 8:
		candidates.append(EnemyAgent2D.Variant.STATIC_WALKER)
	if night_number >= 12:
		candidates.append(EnemyAgent2D.Variant.SCRAP_SHIELD)
	return candidates[posmod(sequence + night_number, candidates.size())]


static func calculate_spawn_interval(player_count: int) -> float:
	return BASE_SPAWN_INTERVAL_SECONDS * (0.5 if player_count >= 2 else 1.0)


static func calculate_co_op_stat_scale(player_count: int) -> float:
	return TWO_PLAYER_STAT_SCALE if player_count >= 2 else 1.0


@rpc("authority", "call_local", "reliable")
func _commit_wave_started(
	night_number: int,
	seconds_remaining: int,
	spawn_quota: int,
	player_count: int
) -> void:
	_night_number = maxi(night_number, 1)
	_wave_seconds_remaining = clampf(
		float(seconds_remaining),
		0.0,
		NIGHT_WAVE_DURATION_SECONDS
	)
	_normal_spawn_quota = maxi(spawn_quota, 0)
	_co_op_player_count = clampi(player_count, 1, 2)
	_wave_active = true
	wave_clock_changed.emit(ceili(_wave_seconds_remaining), is_pacing_frozen())


@rpc("authority", "call_local", "reliable")
func _commit_wave_stopped() -> void:
	_wave_active = false
	wave_clock_changed.emit(0, false)


@rpc("authority", "call_local", "unreliable_ordered")
func _commit_wave_clock(seconds_remaining: int, frozen: bool) -> void:
	if not _wave_active:
		return
	_wave_seconds_remaining = clampf(
		float(seconds_remaining),
		0.0,
		NIGHT_WAVE_DURATION_SECONDS
	)
	wave_clock_changed.emit(seconds_remaining, frozen)


@rpc("authority", "call_local", "reliable")
func _commit_boss_gate(active: bool, boss_name: StringName, remaining: int) -> void:
	_bosses_remaining = maxi(remaining, 0) if active else 0
	_boss_name = boss_name if active else &""
	boss_gate_changed.emit(active, boss_name, _bosses_remaining)
	wave_clock_changed.emit(ceili(_wave_seconds_remaining), active)


@rpc("authority", "call_local", "reliable")
func _commit_enemy_spawn(
	new_enemy_id: int,
	spawn_variant: int,
	spawn_position: Vector2,
	health_value: int,
	damage_value: int,
	speed_value: float
) -> void:
	if (
		new_enemy_id <= 0
		or _enemies.has(new_enemy_id)
		or _enemies.size() >= MAX_ALIVE_ENEMIES
		or spawn_variant < EnemyAgent2D.Variant.WALKER
		or spawn_variant > EnemyAgent2D.Variant.OVERLORD
		or not spawn_position.is_finite()
	):
		return
	var enemy: EnemyAgent2D = EnemyAgent2D.new()
	enemy.configure(
		new_enemy_id,
		spawn_variant,
		spawn_position,
		health_value,
		damage_value,
		speed_value,
		_flow_field.get_target_position() if is_instance_valid(_flow_field) else Vector2.ZERO,
		_flow_field,
		_combat_state,
		multiplayer.is_server()
	)
	_enemies_root.add_child(enemy)
	_enemies[new_enemy_id] = enemy
	_next_enemy_id = maxi(_next_enemy_id, new_enemy_id + 1)
	if multiplayer.is_server():
		enemy.died.connect(_on_enemy_died)
		enemy.micro_emp_released.connect(_on_micro_emp_released)
		enemy.split_requested.connect(_on_split_requested)
	alive_count_changed.emit(_enemies.size(), MAX_ALIVE_ENEMIES)


@rpc("authority", "call_local", "reliable")
func _commit_enemy_despawn(enemy_id: int, world_position: Vector2, decal_size: float) -> void:
	var enemy: EnemyAgent2D = _enemies.get(enemy_id)
	if not is_instance_valid(enemy):
		return
	_enemies.erase(enemy_id)
	_aggro_matrix.remove_enemy(enemy_id)
	if is_instance_valid(_blood_canvas):
		_blood_canvas.stamp(world_position, decal_size, enemy_id)
	if enemy.get_parent() != null:
		enemy.get_parent().remove_child(enemy)
	enemy.queue_free()
	alive_count_changed.emit(_enemies.size(), MAX_ALIVE_ENEMIES)


## Death art is intentionally independent of the immediately-despawned
## gameplay shell.  This RPC is sent before _commit_enemy_despawn on the same
## reliable authority stream, so all peers see the one-shot without allowing a
## dead agent to remain targetable, registered, collidable, or flow-relevant.
@rpc("authority", "call_local", "reliable")
func _commit_enemy_death_presentation(
	enemy_id: int,
	variant_id: int,
	world_position: Vector2,
	facing_row: int,
	presentation_seed: int
) -> void:
	if (
		not is_instance_valid(_enemies_root)
		or not world_position.is_finite()
		or variant_id < EnemyAgent2D.Variant.WALKER
		or variant_id > EnemyAgent2D.Variant.OVERLORD
		or facing_row < 0
		or facing_row >= ActorFacing.ROW_COUNT
	):
		return
	var death_view: Node2D = EnemyDeathPresentationView.new() as Node2D
	if death_view == null:
		return
	var configured: Variant = death_view.call(
		&"configure",
		variant_id,
		enemy_id,
		facing_row,
		presentation_seed
	)
	if not (configured is bool) or not bool(configured):
		death_view.free()
		return
	death_view.global_position = world_position
	_enemies_root.add_child(death_view)
	var definition: EnemyPresentationDefinition = (
		EnemyPresentationCatalog.get_definition(variant_id))
	# The authored marker radius comes along as the variant's mass. It is the
	# footprint the silhouette was drawn to stand on, so it is already the one
	# number that says whether this was a crawler or a goliath, and a listener
	# that wants to scale a burst or a jolt by that does not need the variant
	# table to find out.
	enemy_death_presented.emit(
		world_position,
		definition.body_tint if definition != null else Color.WHITE,
		definition.marker_radius if definition != null else 0.0
	)


@rpc("authority", "call_remote", "unreliable_ordered")
func _receive_enemy_positions(
	enemy_ids: PackedInt32Array,
	positions: PackedVector2Array,
	health_values: PackedInt32Array,
	movement_multipliers: PackedFloat32Array,
	facing_rows: PackedByteArray,
	presentation_tokens: PackedInt32Array
) -> void:
	if (
		enemy_ids.size() != positions.size()
		or enemy_ids.size() != health_values.size()
		or enemy_ids.size() != movement_multipliers.size()
		or enemy_ids.size() != facing_rows.size()
		or enemy_ids.size() != presentation_tokens.size()
	):
		return
	for index: int in range(enemy_ids.size()):
		if (
			not is_finite(movement_multipliers[index])
			or movement_multipliers[index] < 0.0
			or movement_multipliers[index] > 1.0
			or facing_rows[index] >= ActorFacing.ROW_COUNT
			or not EnemyPresentation2D.is_valid_presentation_token(presentation_tokens[index])
			or EnemyPresentation2D.get_token_facing_row(presentation_tokens[index]) != facing_rows[index]
		):
			return
		var enemy: EnemyAgent2D = _enemies.get(enemy_ids[index])
		if is_instance_valid(enemy):
			enemy.apply_network_snapshot(
				positions[index],
				health_values[index],
				movement_multipliers[index],
				facing_rows[index],
				presentation_tokens[index]
			)


@rpc("authority", "call_remote", "reliable")
func _receive_horde_snapshot(
	night_number: int,
	wave_active: bool,
	seconds_remaining: int,
	spawn_quota: int,
	spawned_count: int,
	player_count: int,
	bosses_remaining: int,
	boss_name: String,
	enemy_ids: PackedInt32Array,
	variants: PackedInt32Array,
	positions: PackedVector2Array,
	health_values: PackedInt32Array,
	maximum_health_values: PackedInt32Array,
	damage_values: PackedInt32Array,
	speed_values: PackedFloat32Array,
	movement_multipliers: PackedFloat32Array,
	facing_rows: PackedByteArray,
	presentation_tokens: PackedInt32Array
) -> void:
	var size: int = enemy_ids.size()
	if (
		variants.size() != size
		or positions.size() != size
		or health_values.size() != size
		or maximum_health_values.size() != size
		or damage_values.size() != size
		or speed_values.size() != size
		or movement_multipliers.size() != size
		or facing_rows.size() != size
		or presentation_tokens.size() != size
		or size > MAX_ALIVE_ENEMIES
	):
		return
	for index: int in range(size):
		var movement_multiplier: float = movement_multipliers[index]
		if (
			not is_finite(movement_multiplier)
			or movement_multiplier < 0.0
			or movement_multiplier > 1.0
			or facing_rows[index] >= ActorFacing.ROW_COUNT
			or not EnemyPresentation2D.is_valid_presentation_token(presentation_tokens[index])
			or EnemyPresentation2D.get_token_facing_row(presentation_tokens[index]) != facing_rows[index]
		):
			return
	_clear_all_enemies()
	_night_number = maxi(night_number, 1)
	_wave_active = wave_active
	_wave_seconds_remaining = clampf(float(seconds_remaining), 0.0, NIGHT_WAVE_DURATION_SECONDS)
	_normal_spawn_quota = maxi(spawn_quota, 0)
	_normal_spawned = maxi(spawned_count, 0)
	_co_op_player_count = clampi(player_count, 1, 2)
	_bosses_remaining = maxi(bosses_remaining, 0)
	_boss_name = StringName(boss_name)
	for index: int in range(size):
		_commit_enemy_spawn(
			enemy_ids[index],
			variants[index],
			positions[index],
			maximum_health_values[index],
			damage_values[index],
			speed_values[index]
		)
		var enemy: EnemyAgent2D = _enemies.get(enemy_ids[index])
		if is_instance_valid(enemy):
			enemy.apply_network_snapshot(
				positions[index],
				health_values[index],
				movement_multipliers[index],
				facing_rows[index],
				presentation_tokens[index]
			)
	wave_clock_changed.emit(ceili(_wave_seconds_remaining), is_pacing_frozen())
	if _bosses_remaining > 0:
		boss_gate_changed.emit(true, _boss_name, _bosses_remaining)


func _advance_host(delta: float) -> void:
	_aggro_accumulator += delta
	_snapshot_accumulator += delta
	_clock_accumulator += delta
	_spawn_accumulator += delta
	if _aggro_accumulator >= AGGRO_REFRESH_SECONDS:
		_aggro_accumulator = fmod(_aggro_accumulator, AGGRO_REFRESH_SECONDS)
		_refresh_aggro_matrix()
	var spawn_interval: float = get_spawn_interval()
	while (
		_spawn_accumulator >= spawn_interval
		and _normal_spawned < _normal_spawn_quota
		and _enemies.size() < MAX_ALIVE_ENEMIES
	):
		_spawn_accumulator -= spawn_interval
		var spawn_variant: int = get_rotation_variant(_night_number, _spawn_sequence)
		_spawn_variant_authoritative(spawn_variant, false)
		_spawn_sequence += 1
		_normal_spawned += 1
	if not is_pacing_frozen():
		_wave_seconds_remaining = maxf(_wave_seconds_remaining - delta, 0.0)
	if _snapshot_accumulator >= SNAPSHOT_INTERVAL_SECONDS:
		_snapshot_accumulator = fmod(_snapshot_accumulator, SNAPSHOT_INTERVAL_SECONDS)
		_broadcast_enemy_positions()
	if _clock_accumulator >= CLOCK_BROADCAST_INTERVAL_SECONDS:
		_clock_accumulator = fmod(_clock_accumulator, CLOCK_BROADCAST_INTERVAL_SECONDS)
		_commit_wave_clock.rpc(ceili(_wave_seconds_remaining), is_pacing_frozen())
	if (
		_wave_seconds_remaining <= 0.0
		and _normal_spawned >= _normal_spawn_quota
		and _enemies.is_empty()
	):
		_wave_active = false
		_commit_wave_stopped.rpc()
		wave_completed.emit(_night_number)


func _spawn_variant_authoritative(spawn_variant: int, boss: bool) -> void:
	if not multiplayer.is_server() or _enemies.size() >= MAX_ALIVE_ENEMIES:
		return
	var spawn_position: Vector2 = _find_spawn_position(_spawn_sequence + (700 if boss else 0))
	var stats: Dictionary[StringName, float] = _get_scaled_stats(spawn_variant)
	_commit_enemy_spawn.rpc(
		_next_enemy_id,
		spawn_variant,
		spawn_position,
		roundi(stats[&"health"]),
		roundi(stats[&"damage"]),
		stats[&"speed"]
	)


func _get_scaled_stats(spawn_variant: int) -> Dictionary[StringName, float]:
	var health: float = 90.0
	var damage: float = 12.0
	var speed: float = 112.0
	match spawn_variant:
		EnemyAgent2D.Variant.RAT_SWARM:
			health = 34.0
			damage = 7.0
			speed = 220.0
		EnemyAgent2D.Variant.STATIC_WALKER:
			health = 105.0
			damage = 13.0
			speed = 104.0
		EnemyAgent2D.Variant.SCRAP_SHIELD:
			health = 165.0
			damage = 16.0
			speed = 82.0
		EnemyAgent2D.Variant.GOLIATH:
			health = 1700.0
			damage = 34.0
			speed = 62.0
		EnemyAgent2D.Variant.CARRIER:
			health = 2100.0
			damage = 29.0
			speed = 68.0
		EnemyAgent2D.Variant.SPLITTER:
			health = 2500.0
			damage = 36.0
			speed = 76.0
		EnemyAgent2D.Variant.OVERLORD:
			health = 3400.0
			damage = 48.0
			speed = 70.0
	var night_scale: float = 1.0 + float(_night_number - 1) * 0.06
	var co_op_scale: float = calculate_co_op_stat_scale(_co_op_player_count)
	return {
		&"health": health * night_scale * co_op_scale,
		&"damage": damage * night_scale * co_op_scale,
		&"speed": speed,
	}


func _find_spawn_position(sequence: int) -> Vector2:
	var base_position: Vector2 = (
		_build_system.get_base_position()
		if is_instance_valid(_build_system)
		else Vector2.ZERO
	)
	for attempt: int in range(16):
		var angle: float = fmod(float(sequence * 137 + attempt * 53), 360.0) * PI / 180.0
		var radius: float = 1500.0 + float((sequence + attempt) % 5) * 180.0
		var candidate: Vector2 = base_position + Vector2.from_angle(angle) * radius
		if not is_instance_valid(_world_map) or _world_map.is_position_walkable(candidate, 40.0):
			return candidate
	return base_position + Vector2(0.0, -1800.0)


func _refresh_aggro_matrix() -> void:
	if not is_instance_valid(_combat_state):
		return
	var players: Array[PlayerAvatar] = _combat_state.get_living_players()
	for enemy_id: int in _enemies:
		var enemy: EnemyAgent2D = _enemies[enemy_id]
		var target_peer_id: int = _aggro_matrix.evaluate(
			enemy_id,
			enemy.global_position,
			players,
			AGGRO_PROXIMITY_RADIUS
		)
		if target_peer_id == EnemyAggroMatrix.BASE_TARGET_PEER_ID:
			enemy.clear_player_target()
		else:
			enemy.set_player_target(_combat_state.get_player(target_peer_id))


func _broadcast_enemy_positions() -> void:
	var enemy_ids: PackedInt32Array = PackedInt32Array()
	var positions: PackedVector2Array = PackedVector2Array()
	var health_values: PackedInt32Array = PackedInt32Array()
	var movement_multipliers: PackedFloat32Array = PackedFloat32Array()
	var facing_rows: PackedByteArray = PackedByteArray()
	var presentation_tokens: PackedInt32Array = PackedInt32Array()
	var sorted_ids: Array[int] = _enemies.keys()
	sorted_ids.sort()
	for enemy_id: int in sorted_ids:
		var enemy: EnemyAgent2D = _enemies[enemy_id]
		enemy_ids.append(enemy_id)
		positions.append(enemy.global_position)
		health_values.append(enemy.current_health)
		movement_multipliers.append(enemy.get_movement_speed_multiplier())
		facing_rows.append(enemy.get_presentation_facing_row())
		presentation_tokens.append(enemy.get_presentation_token())
	_receive_enemy_positions.rpc(
		enemy_ids,
		positions,
		health_values,
		movement_multipliers,
		facing_rows,
		presentation_tokens
	)


func _on_enemy_died(enemy_id: int, boss: bool, world_position: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var enemy: EnemyAgent2D = _enemies.get(enemy_id)
	if is_instance_valid(enemy):
		_commit_enemy_death_presentation.rpc(
			enemy_id,
			enemy.variant,
			world_position,
			enemy.get_presentation_facing_row(),
			DEATH_PRESENTATION_SEED_SALT + enemy_id * 31 + enemy.variant * 101
		)
	if boss:
		_bosses_remaining = maxi(_bosses_remaining - 1, 0)
		if _bosses_remaining == 0:
			_commit_boss_gate.rpc(false, _boss_name, 0)
	_commit_enemy_despawn.rpc(enemy_id, world_position, 2.2 if boss else 1.0)


func _on_micro_emp_released(
	world_position: Vector2,
	radius: float,
	duration_seconds: float
) -> void:
	if not multiplayer.is_server() or not is_instance_valid(_build_system):
		return
	var radius_squared: float = radius * radius
	for structure: PlacedStructure2D in _build_system.get_structures():
		if structure.global_position.distance_squared_to(world_position) <= radius_squared:
			structure.apply_micro_emp(duration_seconds)


func _on_split_requested(world_position: Vector2) -> void:
	if not multiplayer.is_server():
		return
	for split_index: int in range(2):
		if _enemies.size() >= MAX_ALIVE_ENEMIES:
			return
		var stats: Dictionary[StringName, float] = _get_scaled_stats(EnemyAgent2D.Variant.WALKER)
		var offset: Vector2 = Vector2(-48.0 if split_index == 0 else 48.0, 20.0)
		_commit_enemy_spawn.rpc(
			_next_enemy_id,
			EnemyAgent2D.Variant.WALKER,
			world_position + offset,
			roundi(stats[&"health"] * 0.7),
			roundi(stats[&"damage"]),
			stats[&"speed"] * 1.1
		)


func _clear_all_enemies() -> void:
	for enemy: EnemyAgent2D in _enemies.values():
		if is_instance_valid(enemy):
			if enemy.get_parent() != null:
				enemy.get_parent().remove_child(enemy)
			enemy.queue_free()
	_enemies.clear()
	alive_count_changed.emit(0, MAX_ALIVE_ENEMIES)


func _clear_death_presentations() -> void:
	if not is_instance_valid(_enemies_root):
		return
	for child: Node in _enemies_root.get_children():
		if child.is_in_group(&"enemy_death_presentations"):
			child.queue_free()
