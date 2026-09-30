class_name TowerTargetingController2D
extends Node2D
## Host-only radial tower targeting. The sensor owns a local enemy set; selection never scans groups.

signal target_changed(previous_target_id: int, current_target_id: int)
signal target_released(target_id: int, reason: StringName)
signal aim_direction_changed(direction: Vector2)
signal attack_executed(
	direction: Vector2,
	attack_kind: int,
	target_positions: PackedVector2Array
)
signal consume_requested

const ENEMY_LAYER: int = 4
const INVALID_TARGET_ID: int = -1
const MIN_DIRECTION_LENGTH_SQUARED: float = 0.0001
const DEFAULT_SELECTION_REFRESH_SECONDS: float = 0.12
const MAX_PRESENTATION_TARGETS: int = 8

var selection_refresh_seconds: float = DEFAULT_SELECTION_REFRESH_SECONDS

var _structure: PlacedStructure2D
var _profile: TowerCombatProfile
var _flow_field: FlowFieldNavigation2D
var _authority_enabled: bool = false
var _sensor: Area2D
var _sensor_shape: CircleShape2D
var _candidates: Dictionary[int, EnemyAgent2D] = {}
var _stale_candidate_ids: Array[int] = []
var _current_target_id: int = INVALID_TARGET_ID
var _cooldown_remaining: float = 0.0
var _selection_accumulator: float = 0.0
var _aim_direction: Vector2 = Vector2.RIGHT
var _targeting_mode: int = TowerCombatProfile.TargetingMode.NEAREST
var _consumed: bool = false
var _selection_pass_count: int = 0
var _candidate_evaluation_count: int = 0
var _detector_enter_count: int = 0
var _detector_exit_count: int = 0
var _shot_count: int = 0
var _target_switch_count: int = 0


func configure(
	structure: PlacedStructure2D,
	profile: TowerCombatProfile,
	flow_field: FlowFieldNavigation2D,
	authority_enabled: bool
) -> void:
	_structure = structure
	_profile = profile
	_flow_field = flow_field
	_authority_enabled = authority_enabled
	_targeting_mode = (
		_profile.targeting_mode
		if _profile != null
		else TowerCombatProfile.TargetingMode.NEAREST
	)
	if is_instance_valid(_structure):
		_selection_accumulator = fmod(
			float(_structure.instance_id) * 0.037,
			selection_refresh_seconds
		)


func _ready() -> void:
	if not _authority_enabled or not _has_valid_profile():
		set_physics_process(false)
		return
	_install_detection_sensor()
	set_physics_process(true)
	call_deferred(&"_register_existing_overlaps")


func _exit_tree() -> void:
	set_physics_process(false)
	if is_instance_valid(_sensor):
		_sensor.monitoring = false
		_sensor.set_deferred(&"monitoring", false)
	_clear_candidates(&"tower_removed")


func _physics_process(delta: float) -> void:
	if not _is_combat_active():
		if _current_target_id != INVALID_TARGET_ID:
			_release_current_target(&"tower_inactive")
		return
	var safe_delta: float = maxf(delta, 0.0)
	_cooldown_remaining = maxf(_cooldown_remaining - safe_delta, 0.0)
	var current_target: EnemyAgent2D = _get_current_target()
	if current_target != null and not _is_candidate_valid(current_target):
		_release_current_target(&"invalid")
	current_target = _get_current_target()
	_selection_accumulator += safe_delta
	if _selection_accumulator >= selection_refresh_seconds:
		_selection_accumulator = fmod(_selection_accumulator, selection_refresh_seconds)
		_refresh_target()
	if _cooldown_remaining > 0.0:
		return
	current_target = _get_current_target()
	if current_target == null or not _is_candidate_valid(current_target):
		return
	_execute_attack(current_target)


func force_refresh() -> void:
	if not _is_combat_active():
		return
	_selection_accumulator = 0.0
	_refresh_target()


func release_target(reason: StringName = &"released") -> void:
	_release_current_target(reason)


func shutdown() -> void:
	_consumed = true
	set_physics_process(false)
	if is_instance_valid(_sensor):
		_sensor.monitoring = false
		_sensor.set_deferred(&"monitoring", false)
	_clear_candidates(&"tower_removed")


func set_targeting_mode(targeting_mode: int) -> void:
	_targeting_mode = clampi(
		targeting_mode,
		TowerCombatProfile.TargetingMode.NEAREST,
		TowerCombatProfile.TargetingMode.FIRST
	)
	force_refresh()


func get_current_target_id() -> int:
	return _current_target_id


func get_current_target() -> EnemyAgent2D:
	return _get_current_target()


func get_candidate_count() -> int:
	return _candidates.size()


func get_selection_pass_count() -> int:
	return _selection_pass_count


func get_candidate_evaluation_count() -> int:
	return _candidate_evaluation_count


func get_detector_enter_count() -> int:
	return _detector_enter_count


func get_detector_exit_count() -> int:
	return _detector_exit_count


func get_shot_count() -> int:
	return _shot_count


func get_target_switch_count() -> int:
	return _target_switch_count


func get_aim_direction() -> Vector2:
	return _aim_direction


func get_cooldown_remaining() -> float:
	return _cooldown_remaining


func get_effective_range() -> float:
	return _profile.detection_range if _profile != null else 0.0


func get_targeting_mode() -> int:
	return _targeting_mode


func _install_detection_sensor() -> void:
	if is_instance_valid(_sensor) or _profile == null:
		return
	_sensor = Area2D.new()
	_sensor.name = &"TowerEnemyDetection"
	_sensor.collision_layer = 0
	_sensor.collision_mask = ENEMY_LAYER
	_sensor.monitoring = true
	_sensor.monitorable = false
	_sensor.body_entered.connect(_on_detection_body_entered)
	_sensor.body_exited.connect(_on_detection_body_exited)
	_sensor_shape = CircleShape2D.new()
	_sensor_shape.radius = _profile.get_range_visualization_radius()
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = &"DetectionRadius"
	collision.shape = _sensor_shape
	_sensor.add_child(collision)
	add_child(_sensor)


func _collect_enemies_in_range() -> void:
	var sensor_range: float = _profile.get_range_visualization_radius() if _profile != null else 0.0
	if sensor_range <= 0.0:
		return
	var range_squared: float = sensor_range * sensor_range
	for node: Node in get_tree().get_nodes_in_group(&"zombies"):
		var enemy: EnemyAgent2D = node as EnemyAgent2D
		if enemy == null or not enemy.is_alive():
			continue
		if enemy.global_position.distance_squared_to(global_position) > range_squared:
			continue
		if _candidates.has(enemy.enemy_id):
			continue
		_register_candidate(enemy)


func _register_existing_overlaps() -> void:
	if not _is_combat_active() or not is_instance_valid(_sensor):
		return
	for body: Node2D in _sensor.get_overlapping_bodies():
		var enemy: EnemyAgent2D = body as EnemyAgent2D
		if enemy != null:
			_register_candidate(enemy)


func _on_detection_body_entered(body: Node2D) -> void:
	var enemy: EnemyAgent2D = body as EnemyAgent2D
	if enemy != null:
		_register_candidate(enemy)


func _on_detection_body_exited(body: Node2D) -> void:
	var enemy: EnemyAgent2D = body as EnemyAgent2D
	if enemy != null:
		_unregister_candidate(enemy.enemy_id, &"left_detection_area")


func _register_candidate(enemy: EnemyAgent2D) -> void:
	if not is_instance_valid(enemy) or enemy.enemy_id <= 0:
		return
	var was_registered: bool = _candidates.has(enemy.enemy_id)
	_candidates[enemy.enemy_id] = enemy
	if not enemy.died.is_connected(_on_candidate_died):
		enemy.died.connect(_on_candidate_died)
	var exit_callback: Callable = _on_candidate_tree_exiting.bind(enemy.enemy_id)
	if not enemy.tree_exiting.is_connected(exit_callback):
		enemy.tree_exiting.connect(exit_callback)
	if not was_registered:
		_detector_enter_count += 1
	_selection_accumulator = selection_refresh_seconds


func _unregister_candidate(enemy_id: int, reason: StringName) -> void:
	if enemy_id <= 0 or not _candidates.has(enemy_id):
		return
	var enemy: EnemyAgent2D = _candidates.get(enemy_id)
	_disconnect_candidate(enemy)
	_candidates.erase(enemy_id)
	_detector_exit_count += 1
	if enemy_id == _current_target_id:
		_release_current_target(reason)
	_selection_accumulator = selection_refresh_seconds


func _on_candidate_died(enemy_id: int, _is_boss: bool, _world_position: Vector2) -> void:
	_unregister_candidate(enemy_id, &"dead")


func _on_candidate_tree_exiting(enemy_id: int) -> void:
	_unregister_candidate(enemy_id, &"freed")


func _refresh_target() -> void:
	_selection_pass_count += 1
	_collect_enemies_in_range()
	_stale_candidate_ids.clear()
	var best_target: EnemyAgent2D
	for enemy_id: int in _candidates:
		var enemy: EnemyAgent2D = _candidates[enemy_id]
		_candidate_evaluation_count += 1
		if not _is_tracked_candidate_valid(enemy):
			_stale_candidate_ids.append(enemy_id)
			continue
		if not _is_candidate_valid(enemy):
			continue
		if best_target == null or _is_better_target(enemy, best_target):
			best_target = enemy
	for enemy_id: int in _stale_candidate_ids:
		_unregister_candidate(enemy_id, &"invalid")
	if best_target == null:
		if _current_target_id != INVALID_TARGET_ID:
			_release_current_target(&"no_valid_candidates")
		return
	_select_target(best_target)


func _is_better_target(candidate: EnemyAgent2D, current_best: EnemyAgent2D) -> bool:
	if candidate == current_best:
		return false
	match get_targeting_mode():
		TowerCombatProfile.TargetingMode.STRONGEST:
			if candidate.current_health != current_best.current_health:
				return candidate.current_health > current_best.current_health
		TowerCombatProfile.TargetingMode.WEAKEST:
			if candidate.current_health != current_best.current_health:
				return candidate.current_health < current_best.current_health
		TowerCombatProfile.TargetingMode.FIRST:
			var candidate_cost: int = _get_first_priority_cost(candidate)
			var best_cost: int = _get_first_priority_cost(current_best)
			if candidate_cost != best_cost:
				return candidate_cost < best_cost
			var candidate_base_distance: float = _get_base_distance_squared(candidate)
			var best_base_distance: float = _get_base_distance_squared(current_best)
			if not is_equal_approx(candidate_base_distance, best_base_distance):
				return candidate_base_distance < best_base_distance
		_:
			var candidate_distance: float = _get_distance_squared(candidate)
			var best_distance: float = _get_distance_squared(current_best)
			if not is_equal_approx(candidate_distance, best_distance):
				return candidate_distance < best_distance
	return candidate.enemy_id < current_best.enemy_id


func _get_first_priority_cost(enemy: EnemyAgent2D) -> int:
	if is_instance_valid(_flow_field):
		return _flow_field.get_integration_cost(enemy.global_position)
	return roundi(_get_base_distance_squared(enemy))


func _get_base_distance_squared(enemy: EnemyAgent2D) -> float:
	if is_instance_valid(_flow_field):
		return enemy.global_position.distance_squared_to(_flow_field.get_target_position())
	return _get_distance_squared(enemy)


func _select_target(target: EnemyAgent2D) -> void:
	if not is_instance_valid(target):
		return
	var previous_target_id: int = _current_target_id
	_current_target_id = target.enemy_id
	_update_aim_direction(target)
	if previous_target_id != _current_target_id:
		_target_switch_count += 1
		target_changed.emit(previous_target_id, _current_target_id)


func _release_current_target(reason: StringName) -> void:
	if _current_target_id == INVALID_TARGET_ID:
		return
	var released_target_id: int = _current_target_id
	_current_target_id = INVALID_TARGET_ID
	_selection_accumulator = selection_refresh_seconds
	target_released.emit(released_target_id, reason)
	target_changed.emit(released_target_id, INVALID_TARGET_ID)


func _execute_attack(primary_target: EnemyAgent2D) -> void:
	if _profile == null:
		return
	var direction: Vector2 = _get_direction_to(primary_target)
	var targets: Array[EnemyAgent2D] = _get_attack_targets(primary_target)
	if targets.is_empty():
		_release_current_target(&"invalid")
		return
	var hit_positions: PackedVector2Array = PackedVector2Array()
	for target: EnemyAgent2D in targets:
		if not _is_tracked_candidate_valid(target):
			continue
		if hit_positions.size() < MAX_PRESENTATION_TARGETS:
			hit_positions.append(target.global_position)
		_apply_damage_to_target(target, direction)
	if hit_positions.is_empty():
		_release_current_target(&"invalid")
		return
	_cooldown_remaining = _profile.cooldown_seconds
	_shot_count += 1
	aim_direction_changed.emit(direction)
	attack_executed.emit(direction, _profile.attack_kind, hit_positions)
	if _profile.consumed_on_attack:
		_consumed = true
		set_physics_process(false)
		_clear_candidates(&"consumed")
		consume_requested.emit()


func _get_attack_targets(primary_target: EnemyAgent2D) -> Array[EnemyAgent2D]:
	var targets: Array[EnemyAgent2D] = []
	if _profile == null or not _is_candidate_valid(primary_target):
		return targets
	match _profile.attack_kind:
		TowerCombatProfile.AttackKind.CHEMICAL:
			targets = _get_local_targets_within_radius(
				primary_target.global_position,
				_profile.impact_radius
			)
		TowerCombatProfile.AttackKind.ELECTRIC:
			targets = _get_electric_chain_targets(primary_target)
		TowerCombatProfile.AttackKind.LANDMINE:
			targets = _get_local_targets_within_radius(global_position, _profile.impact_radius)
		TowerCombatProfile.AttackKind.SLOWING_PIT:
			targets = _get_local_targets_within_radius(global_position, _profile.detection_range)
		_:
			targets.append(primary_target)
	return targets


func _get_electric_chain_targets(primary_target: EnemyAgent2D) -> Array[EnemyAgent2D]:
	var targets: Array[EnemyAgent2D] = [primary_target]
	var previous_target: EnemyAgent2D = primary_target
	while targets.size() < _profile.maximum_chain_targets:
		var next_target: EnemyAgent2D = _get_nearest_chain_candidate(
			previous_target.global_position,
			targets,
			_profile.chain_radius
		)
		if next_target == null:
			break
		targets.append(next_target)
		previous_target = next_target
	return targets


func _get_local_targets_within_radius(origin: Vector2, radius: float) -> Array[EnemyAgent2D]:
	var result: Array[EnemyAgent2D] = []
	var radius_squared: float = maxf(radius, 0.0) * maxf(radius, 0.0)
	for enemy_id: int in _candidates:
		var enemy: EnemyAgent2D = _candidates[enemy_id]
		if (
			_is_tracked_candidate_valid(enemy)
			and enemy.global_position.distance_squared_to(origin) <= radius_squared
		):
			result.append(enemy)
	return result


func _get_nearest_chain_candidate(
	origin: Vector2,
	excluded_targets: Array[EnemyAgent2D],
	radius: float
) -> EnemyAgent2D:
	var nearest: EnemyAgent2D
	var nearest_distance_squared: float = INF
	var radius_squared: float = maxf(radius, 0.0) * maxf(radius, 0.0)
	for enemy_id: int in _candidates:
		var candidate: EnemyAgent2D = _candidates[enemy_id]
		if not _is_tracked_candidate_valid(candidate) or excluded_targets.has(candidate):
			continue
		var distance_squared: float = candidate.global_position.distance_squared_to(origin)
		if distance_squared > radius_squared:
			continue
		if (
			distance_squared < nearest_distance_squared
			or (
				is_equal_approx(distance_squared, nearest_distance_squared)
				and (nearest == null or candidate.enemy_id < nearest.enemy_id)
			)
		):
			nearest = candidate
			nearest_distance_squared = distance_squared
	return nearest


func _apply_damage_to_target(target: EnemyAgent2D, direction: Vector2) -> void:
	if _profile == null or not is_instance_valid(target):
		return
	if _profile.damage > 0:
		target.take_projectile_damage(_profile.damage, direction, 0)
	if _profile.has_movement_effect() and target.is_alive():
		target.apply_movement_slow(
			_profile.movement_multiplier,
			_profile.status_duration_seconds
		)


func _update_aim_direction(target: EnemyAgent2D) -> void:
	var direction: Vector2 = _get_direction_to(target)
	if _aim_direction.dot(direction) >= 0.9999:
		return
	_aim_direction = direction
	aim_direction_changed.emit(_aim_direction)


func _get_direction_to(target: EnemyAgent2D) -> Vector2:
	if not is_instance_valid(target):
		return _aim_direction
	var direction: Vector2 = target.global_position - global_position
	if not direction.is_finite() or direction.length_squared() <= MIN_DIRECTION_LENGTH_SQUARED:
		return Vector2.RIGHT
	return direction.normalized()


func _get_current_target() -> EnemyAgent2D:
	if _current_target_id == INVALID_TARGET_ID:
		return null
	var target: EnemyAgent2D = _candidates.get(_current_target_id)
	return target if is_instance_valid(target) else null


func _is_candidate_valid(enemy: EnemyAgent2D) -> bool:
	if not _is_tracked_candidate_valid(enemy) or not _is_combat_active():
		return false
	var range: float = get_effective_range()
	return _get_distance_squared(enemy) <= range * range


func _is_tracked_candidate_valid(enemy: EnemyAgent2D) -> bool:
	if not is_instance_valid(enemy) or not enemy.is_alive() or not enemy.global_position.is_finite():
		return false
	if not is_instance_valid(_structure) or _profile == null:
		return false
	var sensor_range: float = _profile.get_range_visualization_radius()
	return _get_distance_squared(enemy) <= sensor_range * sensor_range


func _get_distance_squared(enemy: EnemyAgent2D) -> float:
	return enemy.global_position.distance_squared_to(global_position)


func _is_combat_active() -> bool:
	return (
		_authority_enabled
		and not _consumed
		and _has_valid_profile()
		and is_instance_valid(_structure)
		and _structure.current_health > 0
		and not _structure.is_emp_disabled()
	)


func _has_valid_profile() -> bool:
	return _profile != null and _profile.is_offensive()


func _clear_candidates(reason: StringName) -> void:
	if _current_target_id != INVALID_TARGET_ID:
		_release_current_target(reason)
	var candidate_ids: Array[int] = _candidates.keys()
	for enemy_id: int in candidate_ids:
		var enemy: EnemyAgent2D = _candidates.get(enemy_id)
		_disconnect_candidate(enemy)
	_candidates.clear()


func _disconnect_candidate(enemy: EnemyAgent2D) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.died.is_connected(_on_candidate_died):
		enemy.died.disconnect(_on_candidate_died)
	var exit_callback: Callable = _on_candidate_tree_exiting.bind(enemy.enemy_id)
	if enemy.tree_exiting.is_connected(exit_callback):
		enemy.tree_exiting.disconnect(exit_callback)
