class_name TacticalBuildSystem
extends Node
## Reliable host authority for the team pool, Tier-1 placements, and Base relocation.

signal resource_pool_changed(wood: int, metal: int, tech: int)
signal structure_placed(structure: PlacedStructure2D)
signal structure_removed(structure_id: int, reason: StringName)
signal placement_rejected(reason: StringName)
signal base_relocated(world_position: Vector2, refund: PackedInt32Array, destroyed_count: int)
signal zombies_retarget_requested(world_position: Vector2)

const GRID_SIZE: float = 64.0
const REFUND_RATE: float = 0.35
const RESOURCE_KIND_COUNT: int = 3
const INITIAL_RESOURCE_POOL: Array[int] = [120, 100, 80]
const BASE_CLEARANCE: float = 132.0
const STRUCTURE_GAP: float = 10.0
const MAX_SNAPSHOT_STRUCTURES: int = 512
const MAX_RUNTIME_SECONDS: float = 3600.0

@export_node_path("CoopSession") var session_path: NodePath
@export_node_path("BesprenWorldMap2D") var world_map_path: NodePath
@export_node_path("FlowFieldNavigation2D") var flow_field_path: NodePath
@export_node_path("CorePulseDriver") var base_core_path: NodePath
@export_node_path("Node2D") var structures_root_path: NodePath
@export_node_path("JuiceRig") var juice_rig_path: NodePath
@export_node_path("AudioManager") var audio_manager_path: NodePath

var _session: CoopSession
var _world_map: BesprenWorldMap2D
var _flow_field: FlowFieldNavigation2D
var _base_core: CorePulseDriver
var _structures_root: Node2D
var _juice_rig: JuiceRig
var _audio_manager: AudioManager
var _resource_pool: PackedInt32Array = PackedInt32Array(INITIAL_RESOURCE_POOL)
var _structures: Dictionary[int, PlacedStructure2D] = {}
var _runtime_revisions: Dictionary[int, int] = {}
var _next_instance_id: int = 1
var _state_revision: int = 0
var _daytime_building_enabled: bool = true
var _selected_structure_id: int = -1


func _ready() -> void:
	_session = get_node_or_null(session_path) as CoopSession
	_world_map = get_node_or_null(world_map_path) as BesprenWorldMap2D
	_flow_field = get_node_or_null(flow_field_path) as FlowFieldNavigation2D
	_base_core = get_node_or_null(base_core_path) as CorePulseDriver
	_structures_root = get_node_or_null(structures_root_path) as Node2D
	_juice_rig = get_node_or_null(juice_rig_path) as JuiceRig
	_audio_manager = get_node_or_null(audio_manager_path) as AudioManager
	if is_instance_valid(_base_core):
		_base_core.global_position = BesprenWorldMap2D.STARTING_CAMP_POSITION
	if is_instance_valid(_world_map):
		_world_map.set_core_position(BesprenWorldMap2D.STARTING_CAMP_POSITION)
	_emit_resource_pool()


func initialize_for_session() -> void:
	if multiplayer.is_server():
		_commit_resource_pool.rpc(_state_revision, _resource_pool)


func reset_for_session() -> void:
	_destroy_all_structures()
	_runtime_revisions.clear()
	_resource_pool = PackedInt32Array(INITIAL_RESOURCE_POOL)
	_next_instance_id = 1
	_state_revision = 0
	_daytime_building_enabled = true
	if is_instance_valid(_base_core):
		_base_core.global_position = BesprenWorldMap2D.STARTING_CAMP_POSITION
	if is_instance_valid(_world_map):
		_world_map.set_core_position(BesprenWorldMap2D.STARTING_CAMP_POSITION)
	_emit_resource_pool()


func set_daytime_building_enabled(enabled: bool) -> void:
	_daytime_building_enabled = enabled


func request_structure_placement(structure_id: StringName, world_position: Vector2) -> void:
	if multiplayer.is_server():
		_request_structure_placement(structure_id, world_position)
	else:
		_request_structure_placement.rpc_id(
			CoopSession.AUTHORITY_PEER_ID,
			structure_id,
			world_position
		)


func request_base_relocation(world_position: Vector2) -> void:
	if multiplayer.is_server():
		_request_base_relocation(world_position)
	else:
		_request_base_relocation.rpc_id(
			CoopSession.AUTHORITY_PEER_ID,
			world_position
		)


func credit_shared_resource_authoritative(resource_kind: int, amount: int) -> void:
	if (
		not multiplayer.is_server()
		or resource_kind < 0
		or resource_kind >= RESOURCE_KIND_COUNT
		or amount <= 0
	):
		return
	var next_pool: PackedInt32Array = _resource_pool.duplicate()
	next_pool[resource_kind] += amount
	_commit_resource_pool.rpc(_state_revision + 1, next_pool)


func credit_shared_bundle_authoritative(grant: PackedInt32Array) -> void:
	if not multiplayer.is_server() or grant.size() != RESOURCE_KIND_COUNT:
		return
	var next_pool: PackedInt32Array = _resource_pool.duplicate()
	for resource_kind: int in range(RESOURCE_KIND_COUNT):
		if grant[resource_kind] < 0:
			return
		next_pool[resource_kind] += grant[resource_kind]
	_commit_resource_pool.rpc(_state_revision + 1, next_pool)


func sync_state_to_peer(peer_id: int) -> void:
	if not multiplayer.is_server() or peer_id <= CoopSession.AUTHORITY_PEER_ID:
		return
	var instance_ids: PackedInt32Array = PackedInt32Array()
	var structure_ids: PackedStringArray = PackedStringArray()
	var owner_peer_ids: PackedInt32Array = PackedInt32Array()
	var positions: PackedVector2Array = PackedVector2Array()
	var runtime_revisions: PackedInt32Array = PackedInt32Array()
	var health_values: PackedInt32Array = PackedInt32Array()
	var emp_remaining_values: PackedFloat32Array = PackedFloat32Array()
	var aim_directions: PackedVector2Array = PackedVector2Array()
	var cooldown_remaining_values: PackedFloat32Array = PackedFloat32Array()
	var target_ids: PackedInt32Array = PackedInt32Array()
	var sorted_ids: Array[int] = _structures.keys()
	sorted_ids.sort()
	for instance_id: int in sorted_ids:
		var structure: PlacedStructure2D = _structures[instance_id]
		instance_ids.append(instance_id)
		structure_ids.append(String(structure.structure_id))
		owner_peer_ids.append(structure.owner_peer_id)
		positions.append(structure.global_position)
		runtime_revisions.append(_runtime_revisions.get(instance_id, 0))
		health_values.append(structure.current_health)
		emp_remaining_values.append(structure.get_emp_remaining())
		aim_directions.append(structure.get_combat_aim_direction())
		cooldown_remaining_values.append(structure.get_combat_cooldown_remaining())
		target_ids.append(structure.get_combat_target_id())
	_receive_build_snapshot.rpc_id(
		peer_id,
		_state_revision,
		_resource_pool,
		_base_core.global_position,
		_next_instance_id,
		instance_ids,
		structure_ids,
		owner_peer_ids,
		positions,
		runtime_revisions,
		health_values,
		emp_remaining_values,
		aim_directions,
		cooldown_remaining_values,
		target_ids
	)


func get_resource_amount(resource_kind: int) -> int:
	if resource_kind < 0 or resource_kind >= _resource_pool.size():
		return 0
	return _resource_pool[resource_kind]


func get_resource_pool() -> PackedInt32Array:
	return _resource_pool.duplicate()


func get_structure_count() -> int:
	return _structures.size()


func get_structures() -> Array[PlacedStructure2D]:
	var result: Array[PlacedStructure2D] = []
	var sorted_ids: Array[int] = _structures.keys()
	sorted_ids.sort()
	for instance_id: int in sorted_ids:
		result.append(_structures[instance_id])
	return result


func get_structure_positions() -> PackedVector2Array:
	var positions: PackedVector2Array = PackedVector2Array()
	for structure: PlacedStructure2D in get_structures():
		positions.append(structure.global_position)
	return positions


func get_structure(instance_id: int) -> PlacedStructure2D:
	var structure: PlacedStructure2D = _structures.get(instance_id)
	return structure if is_instance_valid(structure) else null


func get_selected_structure() -> PlacedStructure2D:
	return get_structure(_selected_structure_id)


func select_structure_at(world_position: Vector2) -> PlacedStructure2D:
	if not world_position.is_finite():
		clear_structure_selection()
		return null
	var selected: PlacedStructure2D
	var best_distance_squared: float = INF
	for structure: PlacedStructure2D in _structures.values():
		if not is_instance_valid(structure) or not structure.contains_world_position(world_position):
			continue
		var distance_squared: float = structure.global_position.distance_squared_to(world_position)
		if distance_squared < best_distance_squared:
			selected = structure
			best_distance_squared = distance_squared
	_set_selected_structure(selected)
	return selected


func clear_structure_selection() -> void:
	_set_selected_structure(null)


func remove_structure_authoritative(
	instance_id: int,
	reason: StringName = &"removed"
) -> bool:
	if not multiplayer.is_server() or not _structures.has(instance_id):
		return false
	_commit_structure_removal.rpc(_state_revision + 1, instance_id, reason)
	return not _structures.has(instance_id)


func damage_structure_authoritative(instance_id: int, amount: int) -> int:
	if not multiplayer.is_server() or amount <= 0:
		return 0
	var structure: PlacedStructure2D = get_structure(instance_id)
	if structure == null:
		return 0
	return structure.take_damage(amount)


func apply_structure_emp_authoritative(instance_id: int, duration_seconds: float) -> bool:
	if (
		not multiplayer.is_server()
		or not is_finite(duration_seconds)
		or duration_seconds <= 0.0
	):
		return false
	var structure: PlacedStructure2D = get_structure(instance_id)
	if structure == null:
		return false
	structure.apply_micro_emp(duration_seconds)
	return true


func get_total_invested_cost() -> PackedInt32Array:
	var total: PackedInt32Array = PackedInt32Array([0, 0, 0])
	for structure: PlacedStructure2D in _structures.values():
		var cost: PackedInt32Array = structure.get_invested_cost()
		for resource_kind: int in range(RESOURCE_KIND_COUNT):
			total[resource_kind] += cost[resource_kind]
	return total


func get_base_position() -> Vector2:
	if is_instance_valid(_base_core):
		return _base_core.global_position
	return Vector2.ZERO


func get_state_revision() -> int:
	return _state_revision


## Host-side player motion resolves canonical terrain first, then every live defense footprint.
func resolve_player_motion(
	current_position: Vector2,
	desired_position: Vector2,
	player_radius: float
) -> Vector2:
	if not current_position.is_finite() or not desired_position.is_finite() or player_radius < 0.0:
		return current_position
	var resolved: Vector2 = desired_position
	if is_instance_valid(_world_map):
		resolved = _world_map.resolve_player_motion(current_position, desired_position, player_radius)
	if not _intersects_structure(resolved, player_radius):
		return resolved
	var horizontal_slide: Vector2 = Vector2(resolved.x, current_position.y)
	if not _intersects_structure(horizontal_slide, player_radius):
		current_position = horizontal_slide
	var vertical_slide: Vector2 = Vector2(current_position.x, resolved.y)
	if not _intersects_structure(vertical_slide, player_radius):
		current_position = vertical_slide
	return current_position


func _intersects_structure(world_position: Vector2, clearance: float) -> bool:
	for structure: PlacedStructure2D in _structures.values():
		if not is_instance_valid(structure) or not structure.blocks_navigation():
			continue
		var half_size: Vector2 = structure.get_footprint_world_size() * 0.5
		var local_position: Vector2 = world_position - structure.global_position
		if (
			absf(local_position.x) <= half_size.x + clearance
			and absf(local_position.y) <= half_size.y + clearance
		):
			return true
	return false


@rpc("any_peer", "call_local", "reliable")
func _request_structure_placement(structure_id: StringName, world_position: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var source_peer_id: int = _get_requesting_peer_id()
	var rejection: StringName = _validate_structure_request(
		source_peer_id,
		structure_id,
		world_position
	)
	if not rejection.is_empty():
		_send_rejection(source_peer_id, rejection)
		return
	var definition: StructureDefinition = StructureCatalog.get_definition(structure_id)
	var next_pool: PackedInt32Array = _resource_pool.duplicate()
	for resource_kind: int in range(RESOURCE_KIND_COUNT):
		next_pool[resource_kind] -= definition.get_cost(resource_kind)
	var assigned_id: int = _next_instance_id
	_commit_structure_placement.rpc(
		_state_revision + 1,
		assigned_id,
		structure_id,
		world_position,
		source_peer_id,
		next_pool
	)


@rpc("any_peer", "call_local", "reliable")
func _request_base_relocation(world_position: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var source_peer_id: int = _get_requesting_peer_id()
	var rejection: StringName = _validate_base_request(source_peer_id, world_position)
	if not rejection.is_empty():
		_send_rejection(source_peer_id, rejection)
		return
	var invested_total: PackedInt32Array = get_total_invested_cost()
	var refund: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var next_pool: PackedInt32Array = _resource_pool.duplicate()
	for resource_kind: int in range(RESOURCE_KIND_COUNT):
		refund[resource_kind] = floori(float(invested_total[resource_kind]) * REFUND_RATE)
		next_pool[resource_kind] += refund[resource_kind]
	_commit_base_relocation.rpc(
		_state_revision + 1,
		world_position,
		refund,
		next_pool,
		_structures.size()
	)


@rpc("authority", "call_local", "reliable")
func _commit_resource_pool(revision: int, pool_snapshot: PackedInt32Array) -> void:
	if revision < _state_revision or not _is_valid_pool(pool_snapshot):
		return
	_state_revision = revision
	_resource_pool = pool_snapshot.duplicate()
	_emit_resource_pool()


@rpc("authority", "call_local", "reliable")
func _commit_structure_placement(
	revision: int,
	new_instance_id: int,
	structure_id: StringName,
	world_position: Vector2,
	owner_peer_id: int,
	pool_snapshot: PackedInt32Array
) -> void:
	if (
		revision <= _state_revision
		or new_instance_id <= 0
		or _structures.has(new_instance_id)
		or not StructureCatalog.has_structure(structure_id)
		or not world_position.is_finite()
		or owner_peer_id <= 0
		or not _is_valid_pool(pool_snapshot)
	):
		return
	_state_revision = revision
	_resource_pool = pool_snapshot.duplicate()
	_next_instance_id = maxi(_next_instance_id, new_instance_id + 1)
	_spawn_structure(new_instance_id, structure_id, owner_peer_id, world_position, true)
	_emit_resource_pool()


@rpc("authority", "call_local", "reliable")
func _commit_structure_removal(
	revision: int,
	instance_id: int,
	reason: StringName
) -> void:
	if revision <= _state_revision or instance_id <= 0 or not _structures.has(instance_id):
		return
	_state_revision = revision
	_remove_structure_local(instance_id, reason, true)


@rpc("authority", "call_remote", "reliable")
func _commit_structure_runtime_state(
	instance_id: int,
	runtime_revision: int,
	health_value: int,
	emp_remaining: float,
	aim_direction: Vector2,
	cooldown_remaining: float,
	target_id: int
) -> void:
	var structure: PlacedStructure2D = get_structure(instance_id)
	if (
		structure == null
		or runtime_revision <= _runtime_revisions.get(instance_id, -1)
		or not _is_valid_structure_runtime_state(
			structure,
			health_value,
			emp_remaining,
			aim_direction,
			cooldown_remaining,
			target_id
		)
	):
		return
	if not structure.apply_runtime_snapshot(
		health_value,
		emp_remaining,
		aim_direction,
		cooldown_remaining,
		target_id
	):
		return
	_runtime_revisions[instance_id] = runtime_revision


@rpc("authority", "call_local", "unreliable_ordered")
func _present_structure_attack(
	instance_id: int,
	aim_direction: Vector2,
	attack_kind: int,
	target_positions: PackedVector2Array
) -> void:
	_apply_structure_attack_presentation(
		instance_id,
		aim_direction,
		attack_kind,
		target_positions
	)


@rpc("authority", "call_local", "reliable")
func _present_consumed_structure_attack(
	instance_id: int,
	aim_direction: Vector2,
	attack_kind: int,
	target_positions: PackedVector2Array
) -> void:
	_apply_structure_attack_presentation(
		instance_id,
		aim_direction,
		attack_kind,
		target_positions
	)


func _apply_structure_attack_presentation(
	instance_id: int,
	aim_direction: Vector2,
	attack_kind: int,
	target_positions: PackedVector2Array
) -> void:
	if (
		instance_id <= 0
		or not aim_direction.is_finite()
		or aim_direction.length_squared() <= 0.0001
		or attack_kind <= TowerCombatProfile.AttackKind.NONE
		or attack_kind > TowerCombatProfile.AttackKind.RAZOR_SNARE
		or target_positions.size() > 8
	):
		return
	for target_position: Vector2 in target_positions:
		if not target_position.is_finite():
			return
	var structure: PlacedStructure2D = get_structure(instance_id)
	if structure != null:
		structure.present_combat_attack(aim_direction, attack_kind, target_positions)


@rpc("authority", "call_local", "reliable")
func _commit_base_relocation(
	revision: int,
	world_position: Vector2,
	refund: PackedInt32Array,
	pool_snapshot: PackedInt32Array,
	destroyed_count: int
) -> void:
	if (
		revision <= _state_revision
		or not world_position.is_finite()
		or refund.size() != RESOURCE_KIND_COUNT
		or not _is_valid_pool(pool_snapshot)
		or destroyed_count < 0
	):
		return
	_state_revision = revision
	_resource_pool = pool_snapshot.duplicate()
	_destroy_all_structures()
	_base_core.global_position = world_position
	_world_map.set_core_position(world_position)
	_retarget_zombies(world_position)
	if is_instance_valid(_juice_rig):
		_juice_rig.pop(_base_core)
		var core_sprite: Sprite2D = _base_core.get_core_sprite()
		if core_sprite != null:
			_juice_rig.flash_white(core_sprite)
	if is_instance_valid(_audio_manager):
		_audio_manager.play_world_cue(AudioManager.CUE_BUILD, world_position)
	_emit_resource_pool()
	base_relocated.emit(world_position, refund.duplicate(), destroyed_count)
	zombies_retarget_requested.emit(world_position)


@rpc("authority", "call_remote", "reliable")
func _receive_build_snapshot(
	revision: int,
	pool_snapshot: PackedInt32Array,
	base_position: Vector2,
	next_instance_id: int,
	instance_ids: PackedInt32Array,
	structure_ids: PackedStringArray,
	owner_peer_ids: PackedInt32Array,
	positions: PackedVector2Array,
	runtime_revisions: PackedInt32Array,
	health_values: PackedInt32Array,
	emp_remaining_values: PackedFloat32Array,
	aim_directions: PackedVector2Array,
	cooldown_remaining_values: PackedFloat32Array,
	target_ids: PackedInt32Array
) -> void:
	if (
		revision < _state_revision
		or not _is_valid_pool(pool_snapshot)
		or not base_position.is_finite()
		or next_instance_id <= 0
		or instance_ids.size() > MAX_SNAPSHOT_STRUCTURES
		or instance_ids.size() != structure_ids.size()
		or instance_ids.size() != owner_peer_ids.size()
		or instance_ids.size() != positions.size()
		or instance_ids.size() != runtime_revisions.size()
		or instance_ids.size() != health_values.size()
		or instance_ids.size() != emp_remaining_values.size()
		or instance_ids.size() != aim_directions.size()
		or instance_ids.size() != cooldown_remaining_values.size()
		or instance_ids.size() != target_ids.size()
	):
		return
	var seen_instance_ids: Dictionary[int, bool] = {}
	var highest_instance_id: int = 0
	for structure_index: int in range(instance_ids.size()):
		var snapshot_instance_id: int = instance_ids[structure_index]
		var definition: StructureDefinition = StructureCatalog.get_definition(
			StringName(structure_ids[structure_index])
		)
		if (
			snapshot_instance_id <= 0
			or seen_instance_ids.has(snapshot_instance_id)
			or definition == null
			or owner_peer_ids[structure_index] <= 0
			or not positions[structure_index].is_finite()
			or runtime_revisions[structure_index] < 0
			or health_values[structure_index] < 0
			or health_values[structure_index] > definition.max_health
			or not is_finite(emp_remaining_values[structure_index])
			or emp_remaining_values[structure_index] < 0.0
			or emp_remaining_values[structure_index] > MAX_RUNTIME_SECONDS
			or not aim_directions[structure_index].is_finite()
			or not is_finite(cooldown_remaining_values[structure_index])
			or cooldown_remaining_values[structure_index] < 0.0
			or cooldown_remaining_values[structure_index] > MAX_RUNTIME_SECONDS
			or target_ids[structure_index] < -1
		):
			return
		seen_instance_ids[snapshot_instance_id] = true
		highest_instance_id = maxi(highest_instance_id, snapshot_instance_id)
	if next_instance_id <= highest_instance_id:
		return
	_destroy_all_structures()
	_state_revision = revision
	_resource_pool = pool_snapshot.duplicate()
	_next_instance_id = maxi(next_instance_id, 1)
	_base_core.global_position = base_position
	_world_map.set_core_position(base_position)
	for structure_index: int in range(instance_ids.size()):
		_spawn_structure(
			instance_ids[structure_index],
			StringName(structure_ids[structure_index]),
			owner_peer_ids[structure_index],
			positions[structure_index],
			false
		)
		var structure: PlacedStructure2D = get_structure(instance_ids[structure_index])
		if structure == null or not structure.apply_runtime_snapshot(
			health_values[structure_index],
			emp_remaining_values[structure_index],
			aim_directions[structure_index],
			cooldown_remaining_values[structure_index],
			target_ids[structure_index]
		):
			_destroy_all_structures()
			return
		_runtime_revisions[instance_ids[structure_index]] = runtime_revisions[structure_index]
	_emit_resource_pool()


@rpc("authority", "call_local", "reliable")
func _receive_placement_rejection(reason: StringName) -> void:
	placement_rejected.emit(reason)


func preview_rejection_reason(structure_id: StringName, world_position: Vector2) -> StringName:
	var peer_id: int = CoopSession.AUTHORITY_PEER_ID
	if _session != null and _session.multiplayer.get_unique_id() > 0:
		peer_id = _session.multiplayer.get_unique_id()
	if structure_id.is_empty():
		return _validate_base_request(peer_id, world_position)
	return _validate_structure_request(peer_id, structure_id, world_position)


func _validate_structure_request(
	peer_id: int,
	structure_id: StringName,
	world_position: Vector2
) -> StringName:
	if _session == null or not _session.is_peer_registered(peer_id):
		return &"unregistered_peer"
	if not _daytime_building_enabled:
		return &"night_build_locked"
	var definition: StructureDefinition = StructureCatalog.get_definition(structure_id)
	if definition == null:
		return &"unknown_structure"
	if not _is_precise_grid_position(world_position):
		return &"off_grid"
	var clearance: float = Vector2(definition.footprint_cells).length() * GRID_SIZE * 0.5
	if not _world_map.is_position_walkable(world_position, clearance):
		return &"blocked_cell"
	if _overlaps_existing(world_position, clearance):
		return &"occupied_cell"
	for resource_kind: int in range(RESOURCE_KIND_COUNT):
		if _resource_pool[resource_kind] < definition.get_cost(resource_kind):
			return &"insufficient_resources"
	return &""


func _validate_base_request(peer_id: int, world_position: Vector2) -> StringName:
	if _session == null or not _session.is_peer_registered(peer_id):
		return &"unregistered_peer"
	if not _is_precise_grid_position(world_position):
		return &"off_grid"
	if not _world_map.is_position_walkable(world_position, BASE_CLEARANCE):
		return &"blocked_cell"
	if _overlaps_existing(world_position, BASE_CLEARANCE):
		return &"occupied_cell"
	return &""


func _is_precise_grid_position(world_position: Vector2) -> bool:
	if not world_position.is_finite():
		return false
	var snapped: Vector2 = Vector2(
		snappedf(world_position.x, GRID_SIZE),
		snappedf(world_position.y, GRID_SIZE)
	)
	return snapped.is_equal_approx(world_position)


func _overlaps_existing(world_position: Vector2, clearance: float) -> bool:
	for structure: PlacedStructure2D in _structures.values():
		var minimum_distance: float = clearance + structure.get_clearance_radius() + STRUCTURE_GAP
		if structure.global_position.distance_squared_to(world_position) < minimum_distance * minimum_distance:
			return true
	return false


func _spawn_structure(
	new_instance_id: int,
	structure_id: StringName,
	owner_peer_id: int,
	world_position: Vector2,
	with_feedback: bool
) -> void:
	var definition: StructureDefinition = StructureCatalog.get_definition(structure_id)
	if (
		definition == null
		or not is_instance_valid(_structures_root)
		or new_instance_id <= 0
		or _structures.has(new_instance_id)
		or owner_peer_id <= 0
		or not world_position.is_finite()
	):
		return
	var structure: PlacedStructure2D = PlacedStructure2D.new()
	structure.configure(
		new_instance_id,
		definition,
		owner_peer_id,
		world_position,
		multiplayer.is_server()
	)
	_structures_root.add_child(structure)
	_structures[new_instance_id] = structure
	_runtime_revisions[new_instance_id] = 0
	structure.depleted.connect(_on_structure_depleted)
	structure.consumed.connect(_on_structure_consumed)
	structure.runtime_state_changed.connect(_on_structure_runtime_state_changed)
	structure.combat_fired.connect(_on_structure_combat_fired)
	structure.tree_exiting.connect(_on_structure_tree_exiting.bind(new_instance_id))
	structure.configure_combat_runtime(_flow_field, multiplayer.is_server())
	if with_feedback:
		if is_instance_valid(_juice_rig):
			_juice_rig.pop(structure)
		if is_instance_valid(_audio_manager):
			_audio_manager.play_world_cue(AudioManager.CUE_BUILD, world_position)
	structure_placed.emit(structure)


func _destroy_all_structures() -> void:
	clear_structure_selection()
	var structure_ids: Array[int] = _structures.keys()
	for instance_id: int in structure_ids:
		_remove_structure_local(instance_id, &"cleared", false)


func _retarget_zombies(world_position: Vector2) -> void:
	for zombie: Node in get_tree().get_nodes_in_group(&"zombies"):
		if is_instance_valid(zombie) and zombie.has_method(&"set_base_target"):
			zombie.call(&"set_base_target", world_position)


func _set_selected_structure(structure: PlacedStructure2D) -> void:
	if _selected_structure_id > 0:
		var previous: PlacedStructure2D = get_structure(_selected_structure_id)
		if previous != null:
			previous.set_range_visualization_visible(false)
	_selected_structure_id = structure.instance_id if is_instance_valid(structure) else -1
	if is_instance_valid(structure):
		structure.set_range_visualization_visible(true)


func _remove_structure_local(
	instance_id: int,
	reason: StringName,
	emit_removed: bool
) -> void:
	var structure: PlacedStructure2D = _structures.get(instance_id)
	_structures.erase(instance_id)
	_runtime_revisions.erase(instance_id)
	if _selected_structure_id == instance_id:
		_selected_structure_id = -1
	if is_instance_valid(structure):
		structure.set_range_visualization_visible(false)
		structure.stop_tower_combat()
		if reason == &"consumed":
			structure.retire_after_attack_trace()
		else:
			if structure.get_parent() != null:
				structure.get_parent().remove_child(structure)
			structure.queue_free()
	if emit_removed:
		structure_removed.emit(instance_id, reason)


func _on_structure_depleted(structure: PlacedStructure2D) -> void:
	if not multiplayer.is_server() or not is_instance_valid(structure):
		return
	remove_structure_authoritative(structure.instance_id, &"destroyed")


func _on_structure_consumed(structure: PlacedStructure2D) -> void:
	if not multiplayer.is_server() or not is_instance_valid(structure):
		return
	remove_structure_authoritative(structure.instance_id, &"consumed")


func _on_structure_runtime_state_changed(structure: PlacedStructure2D) -> void:
	if not multiplayer.is_server() or not is_instance_valid(structure):
		return
	var runtime_revision: int = _runtime_revisions.get(structure.instance_id, 0) + 1
	_runtime_revisions[structure.instance_id] = runtime_revision
	_commit_structure_runtime_state.rpc(
		structure.instance_id,
		runtime_revision,
		structure.current_health,
		structure.get_emp_remaining(),
		structure.get_combat_aim_direction(),
		structure.get_combat_cooldown_remaining(),
		structure.get_combat_target_id()
	)


func _on_structure_combat_fired(
	structure: PlacedStructure2D,
	aim_direction: Vector2,
	attack_kind: int,
	target_positions: PackedVector2Array
) -> void:
	if not multiplayer.is_server() or not is_instance_valid(structure):
		return
	if (
		attack_kind >= TowerCombatProfile.AttackKind.KINETIC
		and attack_kind <= TowerCombatProfile.AttackKind.ELECTRIC
		and is_instance_valid(_audio_manager)
	):
		_audio_manager.play_world_cue(AudioManager.CUE_TOWER_SHOT, structure.global_position)
	if structure.is_consumed_on_attack():
		_present_consumed_structure_attack.rpc(
			structure.instance_id,
			aim_direction,
			attack_kind,
			target_positions
		)
	else:
		_present_structure_attack.rpc(
			structure.instance_id,
			aim_direction,
			attack_kind,
			target_positions
		)


func _on_structure_tree_exiting(instance_id: int) -> void:
	if not _structures.has(instance_id):
		return
	_structures.erase(instance_id)
	_runtime_revisions.erase(instance_id)
	if _selected_structure_id == instance_id:
		_selected_structure_id = -1


func _get_requesting_peer_id() -> int:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if peer_id <= 0:
		peer_id = multiplayer.get_unique_id()
	return peer_id


func _send_rejection(peer_id: int, reason: StringName) -> void:
	if peer_id == multiplayer.get_unique_id():
		_receive_placement_rejection(reason)
	else:
		_receive_placement_rejection.rpc_id(peer_id, reason)


func _is_valid_pool(pool_snapshot: PackedInt32Array) -> bool:
	if pool_snapshot.size() != RESOURCE_KIND_COUNT:
		return false
	for amount: int in pool_snapshot:
		if amount < 0:
			return false
	return true


func _is_valid_structure_runtime_state(
	structure: PlacedStructure2D,
	health_value: int,
	emp_remaining: float,
	aim_direction: Vector2,
	cooldown_remaining: float,
	target_id: int
) -> bool:
	return (
		is_instance_valid(structure)
		and health_value >= 0
		and health_value <= structure.max_health
		and is_finite(emp_remaining)
		and emp_remaining >= 0.0
		and emp_remaining <= MAX_RUNTIME_SECONDS
		and aim_direction.is_finite()
		and is_finite(cooldown_remaining)
		and cooldown_remaining >= 0.0
		and cooldown_remaining <= MAX_RUNTIME_SECONDS
		and target_id >= -1
	)


func _emit_resource_pool() -> void:
	resource_pool_changed.emit(
		_resource_pool[0],
		_resource_pool[1],
		_resource_pool[2]
	)
