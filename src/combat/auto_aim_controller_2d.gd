class_name AutoAimController2D
extends Node2D
## Host-owned mobile aim assist. Candidates are maintained by an Area2D broad phase,
## while weighted selection runs at a bounded cadence instead of scene-tree scans.

signal target_changed(peer_id: int, previous_target_id: int, current_target_id: int)
signal target_released(peer_id: int, target_id: int, reason: StringName)
signal aim_state_changed(peer_id: int, direction: Vector2, target_id: int, assisted: bool)

const ENEMY_LAYER: int = 4
const WORLD_STATIC_LAYER: int = 2
const INVALID_TARGET_ID: int = -1
const MIN_DIRECTION_LENGTH_SQUARED: float = 0.0001

@export_group("Detection")
@export_range(96.0, 1600.0, 1.0) var target_detection_radius: float = 720.0
@export_range(10.0, 180.0, 1.0) var maximum_targeting_angle_degrees: float = 150.0
@export_range(0.03, 0.5, 0.01) var selection_refresh_seconds: float = 0.08
@export var respect_weapon_range: bool = true
@export_range(64.0, 1600.0, 1.0) var weapon_effective_range: float = 1240.0
@export var require_line_of_sight: bool = true
@export_range(1, 32, 1) var visibility_ray_budget: int = 12
@export var visibility_collision_mask: int = WORLD_STATIC_LAYER

@export_group("Aim Response")
@export_range(30.0, 1440.0, 1.0) var aim_rotation_speed_degrees_per_second: float = 720.0
@export_range(0.0, 40.0, 0.1) var aim_smoothing: float = 18.0
@export_range(0.0, 0.35, 0.01) var target_lead_seconds: float = 0.08

@export_group("Weighted Selection")
@export_range(0.0, 2.0, 0.01) var switching_threshold: float = 0.18
@export_range(0.0, 2.0, 0.01) var current_target_bias: float = 0.20
@export_range(0.0, 2.0, 0.01) var minimum_lock_duration_seconds: float = 0.35
@export_range(0.0, 2.0, 0.01) var distance_weight: float = 0.34
@export_range(0.0, 2.0, 0.01) var angle_weight: float = 0.26
@export_range(0.0, 2.0, 0.01) var visibility_weight: float = 0.20
@export_range(0.0, 2.0, 0.01) var weapon_range_weight: float = 0.06
@export_range(0.0, 2.0, 0.01) var threat_weight: float = 0.14

@export_group("Debug")
@export var debug_visualization: bool = false
@export var debug_show_scores: bool = true

var _player: PlayerAvatar
var _sensor: Area2D
var _sensor_shape: CircleShape2D
var _candidates: Dictionary[int, EnemyAgent2D] = {}
var _candidate_ids: Array[int] = []
var _stale_candidate_ids: Array[int] = []
var _pre_visibility_scores: Dictionary[int, float] = {}
var _candidate_scores: Dictionary[int, float] = {}
var _current_target_id: int = INVALID_TARGET_ID
var _current_target_score: float = -INF
var _selection_accumulator: float = 0.0
var _lock_elapsed_seconds: float = 0.0
var _smoothed_aim_direction: Vector2 = Vector2.RIGHT
var _authoritative_origin: Vector2 = Vector2.INF
var _last_target_position: Vector2 = Vector2.INF
var _last_target_velocity: Vector2 = Vector2.ZERO
var _last_emitted_direction: Vector2 = Vector2.RIGHT
var _last_emitted_target_id: int = INVALID_TARGET_ID
var _last_emitted_assisted: bool = false
var _has_emitted_aim_state: bool = false
var _selection_refresh_count: int = 0
var _visibility_scan_offset: int = 0


func configure(player: PlayerAvatar) -> void:
	_player = player
	if is_instance_valid(_player):
		_smoothed_aim_direction = _get_manual_direction()


func _ready() -> void:
	_install_detection_sensor()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not _is_player_valid():
		_release_current_target(&"player_invalid")
		_update_smoothed_aim(maxf(delta, 0.0))
		return
	_sync_detection_sensor_radius()
	_align_to_authoritative_origin()
	var current_target: EnemyAgent2D = _get_current_target()
	if current_target != null and not _is_candidate_valid_basic(current_target):
		_release_current_target(&"invalid")
	if _current_target_id != INVALID_TARGET_ID:
		_lock_elapsed_seconds += maxf(delta, 0.0)
	_selection_accumulator += maxf(delta, 0.0)
	if _selection_accumulator >= selection_refresh_seconds:
		_selection_accumulator = fmod(_selection_accumulator, selection_refresh_seconds)
		_evaluate_target_selection()
	_update_smoothed_aim(maxf(delta, 0.0))
	if debug_visualization:
		queue_redraw()


func set_authoritative_origin(world_position: Vector2) -> void:
	if world_position.is_finite():
		_authoritative_origin = world_position


func register_candidate(enemy: EnemyAgent2D) -> void:
	if not is_instance_valid(enemy) or enemy.enemy_id <= 0:
		return
	_candidates[enemy.enemy_id] = enemy
	if not enemy.died.is_connected(_on_candidate_died):
		enemy.died.connect(_on_candidate_died)
	var tree_exit_callback: Callable = _on_candidate_tree_exiting.bind(enemy.enemy_id)
	if not enemy.tree_exiting.is_connected(tree_exit_callback):
		enemy.tree_exiting.connect(tree_exit_callback)
	_selection_accumulator = selection_refresh_seconds
	if debug_visualization:
		queue_redraw()


func unregister_candidate(enemy_id: int) -> void:
	if enemy_id <= 0:
		return
	_candidates.erase(enemy_id)
	if enemy_id == _current_target_id:
		_release_current_target(&"left_detection_area")
	_selection_accumulator = selection_refresh_seconds
	if debug_visualization:
		queue_redraw()


func force_refresh() -> void:
	_selection_accumulator = 0.0
	_evaluate_target_selection()
	if debug_visualization:
		queue_redraw()


func get_firing_direction(fallback_direction: Vector2) -> Vector2:
	if not _is_player_valid():
		return _sanitize_direction(fallback_direction)
	var current_target: EnemyAgent2D = _get_current_target()
	if current_target == null or not _is_candidate_valid_basic(current_target):
		_evaluate_target_selection()
		current_target = _get_current_target()
	# Selection runs on a bounded cadence, but the host fire decision must never
	# reuse an LOS result that may be one cadence old. Recheck the locked target
	# synchronously so a newly introduced wall invalidates assistance immediately.
	if (
		current_target != null
		and _is_candidate_valid_basic(current_target)
		and require_line_of_sight
		and not _has_line_of_sight(current_target)
	):
		_release_current_target(&"line_of_sight")
		_evaluate_target_selection()
		current_target = _get_current_target()
	if current_target != null and _is_candidate_valid_basic(current_target):
		if require_line_of_sight and not _has_line_of_sight(current_target):
			_release_current_target(&"line_of_sight")
			return _sanitize_direction(fallback_direction)
		return _sanitize_direction(_smoothed_aim_direction)
	return _sanitize_direction(fallback_direction)


func get_current_target_id() -> int:
	return _current_target_id


func get_current_target_score() -> float:
	return _current_target_score


func get_candidate_count() -> int:
	return _candidates.size()


func get_selection_refresh_count() -> int:
	return _selection_refresh_count


func get_aim_direction() -> Vector2:
	return _sanitize_direction(_smoothed_aim_direction)


func get_candidate_scores() -> Dictionary[int, float]:
	return _candidate_scores.duplicate()


func is_assisting() -> bool:
	return _current_target_id != INVALID_TARGET_ID and _get_current_target() != null


func _install_detection_sensor() -> void:
	if is_instance_valid(_sensor):
		return
	_sensor = Area2D.new()
	_sensor.name = &"AutoAimDetection"
	_sensor.collision_layer = 0
	_sensor.collision_mask = ENEMY_LAYER
	_sensor.monitoring = true
	_sensor.monitorable = false
	_sensor.body_entered.connect(_on_detection_body_entered)
	_sensor.body_exited.connect(_on_detection_body_exited)
	_sensor_shape = CircleShape2D.new()
	_sensor_shape.radius = target_detection_radius
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = &"DetectionRadius"
	collision.shape = _sensor_shape
	_sensor.add_child(collision)
	add_child(_sensor)


func _sync_detection_sensor_radius() -> void:
	if (
		_sensor_shape != null
		and not is_equal_approx(_sensor_shape.radius, target_detection_radius)
	):
		_sensor_shape.radius = target_detection_radius


func _on_detection_body_entered(body: Node2D) -> void:
	var enemy: EnemyAgent2D = body as EnemyAgent2D
	if enemy != null:
		register_candidate(enemy)


func _on_detection_body_exited(body: Node2D) -> void:
	var enemy: EnemyAgent2D = body as EnemyAgent2D
	if enemy != null:
		unregister_candidate(enemy.enemy_id)


func _on_candidate_died(enemy_id: int, _is_boss: bool, _world_position: Vector2) -> void:
	_candidates.erase(enemy_id)
	if enemy_id == _current_target_id:
		_release_current_target(&"dead")
	_selection_accumulator = selection_refresh_seconds


func _on_candidate_tree_exiting(enemy_id: int) -> void:
	_candidates.erase(enemy_id)
	if enemy_id == _current_target_id:
		_release_current_target(&"freed")
	_selection_accumulator = selection_refresh_seconds


func _evaluate_target_selection() -> void:
	_selection_refresh_count += 1
	_candidate_scores.clear()
	_pre_visibility_scores.clear()
	_candidate_ids.clear()
	_stale_candidate_ids.clear()
	if not _is_player_valid():
		_release_current_target(&"player_invalid")
		return
	var current_target: EnemyAgent2D = _get_current_target()
	if current_target != null and not _is_candidate_valid_basic(current_target):
		_release_current_target(&"invalid")
		current_target = null
	for enemy_id: int in _candidates:
		var enemy: EnemyAgent2D = _candidates[enemy_id]
		if not is_instance_valid(enemy) or not _is_candidate_valid_basic(enemy):
			if not is_instance_valid(enemy) or not enemy.is_alive():
				_stale_candidate_ids.append(enemy_id)
			continue
		_pre_visibility_scores[enemy_id] = _score_candidate_without_visibility(enemy)
		_candidate_ids.append(enemy_id)
	for enemy_id: int in _stale_candidate_ids:
		_candidates.erase(enemy_id)
		if enemy_id == _current_target_id:
			_release_current_target(&"invalid")
	_candidate_ids.sort_custom(_sort_candidates_by_pre_visibility_score)
	var candidate_count: int = _candidate_ids.size()
	var visibility_start_index: int = (
		posmod(_visibility_scan_offset, candidate_count)
		if candidate_count > 0
		else 0
	)
	for candidate_index: int in range(candidate_count):
		var enemy_id: int = _candidate_ids[candidate_index]
		var enemy: EnemyAgent2D = _candidates.get(enemy_id)
		if not is_instance_valid(enemy):
			continue
		var is_current: bool = enemy_id == _current_target_id
		var relative_visibility_index: int = candidate_index - visibility_start_index
		if relative_visibility_index < 0:
			relative_visibility_index += candidate_count
		var check_visibility: bool = (
			is_current or relative_visibility_index < visibility_ray_budget
		)
		var visible: bool = true
		if check_visibility:
			visible = _has_line_of_sight(enemy)
		elif require_line_of_sight:
			continue
		if require_line_of_sight and not visible:
			if is_current:
				_release_current_target(&"unreachable")
			continue
		var score: float = _pre_visibility_scores.get(enemy_id, -INF)
		score += visibility_weight * (1.0 if visible else 0.0)
		if is_current:
			score += current_target_bias
		_candidate_scores[enemy_id] = score
	if candidate_count > 0:
		_visibility_scan_offset = (
			visibility_start_index + mini(visibility_ray_budget, candidate_count)
		) % candidate_count
	else:
		_visibility_scan_offset = 0
	var best_target_id: int = INVALID_TARGET_ID
	var best_score: float = -INF
	for enemy_id: int in _candidate_ids:
		if not _candidate_scores.has(enemy_id):
			continue
		var score: float = _candidate_scores[enemy_id]
		if (
			score > best_score
			or (is_equal_approx(score, best_score) and (best_target_id < 0 or enemy_id < best_target_id))
		):
			best_target_id = enemy_id
			best_score = score
	var current_score_value: Variant = _candidate_scores.get(_current_target_id)
	var current_score: float = current_score_value if current_score_value is float else -INF
	if _current_target_id == INVALID_TARGET_ID:
		if best_target_id != INVALID_TARGET_ID:
			_select_target(best_target_id, best_score)
		return
	if current_score == -INF:
		_release_current_target(&"invalid")
		if best_target_id != INVALID_TARGET_ID:
			_select_target(best_target_id, best_score)
		return
	_current_target_score = current_score
	if best_target_id == _current_target_id:
		return
	if _lock_elapsed_seconds < minimum_lock_duration_seconds:
		return
	if best_target_id != INVALID_TARGET_ID and best_score > current_score + switching_threshold:
		_select_target(best_target_id, best_score)


func _sort_candidates_by_pre_visibility_score(left_id: int, right_id: int) -> bool:
	var left_score: float = _pre_visibility_scores.get(left_id, -INF)
	var right_score: float = _pre_visibility_scores.get(right_id, -INF)
	if is_equal_approx(left_score, right_score):
		return left_id < right_id
	return left_score > right_score


func _score_candidate_without_visibility(enemy: EnemyAgent2D) -> float:
	var origin: Vector2 = _get_targeting_origin()
	var to_enemy: Vector2 = enemy.global_position - origin
	var distance: float = to_enemy.length()
	var usable_range: float = _get_usable_range()
	var distance_score: float = 1.0 - clampf(distance / usable_range, 0.0, 1.0)
	var manual_direction: Vector2 = _get_manual_direction()
	var target_direction: Vector2 = to_enemy.normalized()
	var maximum_angle: float = deg_to_rad(maximum_targeting_angle_degrees)
	var angular_difference: float = absf(manual_direction.angle_to(target_direction))
	var angle_score: float = 1.0 - clampf(angular_difference / maximum_angle, 0.0, 1.0)
	var range_score: float = 1.0 - clampf(distance / maxf(weapon_effective_range, 1.0), 0.0, 1.0)
	return (
		distance_weight * distance_score
		+ angle_weight * angle_score
		+ weapon_range_weight * range_score
		+ threat_weight * _get_threat_score(enemy)
	)


func _get_threat_score(enemy: EnemyAgent2D) -> float:
	var damage_score: float = clampf(float(enemy.attack_damage) / 48.0, 0.0, 1.0)
	var speed_score: float = clampf(enemy.movement_speed / 220.0, 0.0, 1.0)
	var aggro_score: float = (
		1.0
		if is_instance_valid(_player) and enemy.get_target_peer_id() == _player.peer_id
		else 0.0
	)
	var boss_score: float = 1.0 if enemy.is_boss() else 0.0
	return clampf(
		damage_score * 0.40 + speed_score * 0.15 + aggro_score * 0.25 + boss_score * 0.20,
		0.0,
		1.0
	)


func _has_line_of_sight(enemy: EnemyAgent2D) -> bool:
	if visibility_collision_mask == 0:
		return true
	var origin: Vector2 = _get_targeting_origin()
	var target_position: Vector2 = enemy.global_position
	if not origin.is_finite() or not target_position.is_finite():
		return false
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		origin,
		target_position,
		visibility_collision_mask
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty()


func _is_candidate_valid_basic(enemy: EnemyAgent2D) -> bool:
	if (
		not is_instance_valid(enemy)
		or not enemy.is_alive()
		or not enemy.global_position.is_finite()
		or not _is_player_valid()
	):
		return false
	var to_enemy: Vector2 = enemy.global_position - _get_targeting_origin()
	var distance_squared: float = to_enemy.length_squared()
	var usable_range: float = _get_usable_range()
	if distance_squared <= MIN_DIRECTION_LENGTH_SQUARED or distance_squared > usable_range * usable_range:
		return false
	if respect_weapon_range and distance_squared > weapon_effective_range * weapon_effective_range:
		return false
	var maximum_angle: float = deg_to_rad(maximum_targeting_angle_degrees)
	if maximum_angle < PI:
		var angle: float = absf(_get_manual_direction().angle_to(to_enemy.normalized()))
		if angle > maximum_angle:
			return false
	return true


func _get_usable_range() -> float:
	var range_limit: float = target_detection_radius
	if respect_weapon_range:
		range_limit = minf(range_limit, weapon_effective_range)
	return maxf(range_limit, 1.0)


func _select_target(target_id: int, score: float) -> void:
	if target_id == _current_target_id:
		_current_target_score = score
		return
	var previous_target_id: int = _current_target_id
	_current_target_id = target_id
	_current_target_score = score
	_lock_elapsed_seconds = 0.0
	_last_target_position = Vector2.INF
	_last_target_velocity = Vector2.ZERO
	if is_instance_valid(_player):
		target_changed.emit(_player.peer_id, previous_target_id, target_id)


func _release_current_target(reason: StringName) -> void:
	if _current_target_id == INVALID_TARGET_ID:
		return
	var released_target_id: int = _current_target_id
	_current_target_id = INVALID_TARGET_ID
	_current_target_score = -INF
	_lock_elapsed_seconds = 0.0
	_last_target_position = Vector2.INF
	_last_target_velocity = Vector2.ZERO
	if is_instance_valid(_player):
		target_released.emit(_player.peer_id, released_target_id, reason)
		target_changed.emit(_player.peer_id, released_target_id, INVALID_TARGET_ID)


func _get_current_target() -> EnemyAgent2D:
	if _current_target_id == INVALID_TARGET_ID:
		return null
	var target: EnemyAgent2D = _candidates.get(_current_target_id)
	if not is_instance_valid(target):
		return null
	return target


func _update_smoothed_aim(delta: float) -> void:
	var target: EnemyAgent2D = _get_current_target()
	var assisted: bool = target != null and _is_candidate_valid_basic(target)
	var desired_direction: Vector2 = _get_manual_direction()
	if assisted:
		desired_direction = _get_predicted_target_direction(target, delta)
	if desired_direction.length_squared() <= MIN_DIRECTION_LENGTH_SQUARED:
		desired_direction = Vector2.RIGHT
	var current_direction: Vector2 = _sanitize_direction(_smoothed_aim_direction)
	var smoothing_factor: float = (
		1.0
		if aim_smoothing <= 0.0
		else 1.0 - exp(-aim_smoothing * maxf(delta, 0.0))
	)
	var current_angle: float = current_direction.angle()
	var smoothed_target_angle: float = lerp_angle(
		current_angle,
		desired_direction.angle(),
		clampf(smoothing_factor, 0.0, 1.0)
	)
	var requested_turn: float = wrapf(smoothed_target_angle - current_angle, -PI, PI)
	var maximum_turn: float = deg_to_rad(aim_rotation_speed_degrees_per_second) * maxf(delta, 0.0)
	_smoothed_aim_direction = Vector2.from_angle(
		current_angle + clampf(requested_turn, -maximum_turn, maximum_turn)
	).normalized()
	_emit_aim_state_if_changed(assisted)


func _get_predicted_target_direction(target: EnemyAgent2D, sample_delta: float) -> Vector2:
	var target_position: Vector2 = target.global_position
	if _last_target_position.is_finite():
		_last_target_velocity = (target_position - _last_target_position) / maxf(sample_delta, 0.001)
	_last_target_position = target_position
	var predicted_position: Vector2 = target_position + _last_target_velocity * target_lead_seconds
	var direction: Vector2 = predicted_position - _get_targeting_origin()
	return _sanitize_direction(direction)


func _emit_aim_state_if_changed(assisted: bool) -> void:
	if not is_instance_valid(_player):
		return
	var target_id: int = _current_target_id if assisted else INVALID_TARGET_ID
	var direction_changed: bool = (
		absf(_last_emitted_direction.angle_to(_smoothed_aim_direction))
		>= deg_to_rad(0.5)
	)
	if (
		not _has_emitted_aim_state
		or direction_changed
		or _last_emitted_target_id != target_id
		or _last_emitted_assisted != assisted
	):
		_has_emitted_aim_state = true
		_last_emitted_direction = _smoothed_aim_direction
		_last_emitted_target_id = target_id
		_last_emitted_assisted = assisted
		aim_state_changed.emit(_player.peer_id, _smoothed_aim_direction, target_id, assisted)


func _get_targeting_origin() -> Vector2:
	if _authoritative_origin.is_finite():
		return _authoritative_origin
	if is_instance_valid(_player):
		return _player.global_position
	return global_position


func _align_to_authoritative_origin() -> void:
	var origin: Vector2 = _get_targeting_origin()
	if origin.is_finite():
		global_position = origin


func _get_manual_direction() -> Vector2:
	if is_instance_valid(_player):
		return _sanitize_direction(_player.get_movement_facing_direction())
	return Vector2.RIGHT


func _sanitize_direction(direction: Vector2) -> Vector2:
	if not direction.is_finite() or direction.length_squared() <= MIN_DIRECTION_LENGTH_SQUARED:
		return Vector2.RIGHT
	return direction.normalized()


func _is_player_valid() -> bool:
	return is_instance_valid(_player) and _player.is_combat_alive()


func _draw() -> void:
	if not debug_visualization:
		return
	var cone_half_angle: float = deg_to_rad(maximum_targeting_angle_degrees)
	var manual_direction: Vector2 = _get_manual_direction()
	draw_arc(
		Vector2.ZERO,
		target_detection_radius,
		0.0,
		TAU,
		64,
		Color(0.24, 0.84, 1.0, 0.12),
		1.0,
		true
	)
	draw_arc(
		Vector2.ZERO,
		target_detection_radius,
		manual_direction.angle() - cone_half_angle,
		manual_direction.angle() + cone_half_angle,
		40,
		Color(0.24, 0.84, 1.0, 0.24),
		1.5,
		true
	)
	draw_circle(Vector2.ZERO, 3.5, Color(0.98, 0.72, 0.2, 0.95))
	draw_line(
		Vector2.ZERO,
		_smoothed_aim_direction * 58.0,
		Color(1.0, 0.82, 0.28, 0.95),
		2.0,
		true
	)
	for enemy_id: int in _candidate_ids:
		var enemy: EnemyAgent2D = _candidates.get(enemy_id)
		if not is_instance_valid(enemy):
			continue
		var local_position: Vector2 = to_local(enemy.global_position)
		var selected: bool = enemy_id == _current_target_id
		var color: Color = Color(1.0, 0.76, 0.22, 0.95) if selected else Color(0.32, 0.88, 1.0, 0.78)
		draw_circle(local_position, 7.0 if selected else 4.0, color, false, 1.5, true)
		if selected:
			draw_line(Vector2.ZERO, local_position, color, 1.5, true)
		if debug_show_scores and _candidate_scores.has(enemy_id):
			draw_string(
				ThemeDB.fallback_font,
				local_position + Vector2(6.0, -7.0),
				"%.2f" % _candidate_scores[enemy_id],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				8,
				color
			)
