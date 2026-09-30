extends SceneTree
## Two-process ENet probe for fixed-path, host-authoritative resource gathering.
## Run one --role=host process before starting one --role=client process.

const WORLD_MAP_SCENE: PackedScene = preload("res://scenes/world/world_map_2d.tscn")
const RESOURCE_SCATTER_SCENE: PackedScene = preload("res://scenes/world/resource_scatter_2d.tscn")
const PROBE_TIMEOUT_MSEC: int = 12000
const TARGET_RESOURCE_ID: int = 0
const APPROACH_DISTANCE: float = 120.0
const STATIONARY_EPSILON_SQUARED: float = 0.0001
const NEXT_INTERACTION_DELAY_MSEC: int = 180

var _role: String = ""
var _probe_world: Node2D
var _world_map: BesprenWorldMap2D
var _scatter: BesprenResourceScatter2D
var _session: CoopSession

var _local_peer_id: int = 0
var _client_peer_id: int = 0
var _client_ready: bool = false
var _client_registered: bool = false
var _client_state_seen: bool = false
var _client_position: Vector2 = Vector2.INF
var _client_movement: Vector2 = Vector2.ZERO
var _interaction_broadcast_count: int = 0
var _submitted_interactions: int = 0
var _last_submit_msec: int = 0
var _host_gather_invocation_count: int = 0
var _host_selected_resource_id: int = -1

var _target_position: Vector2 = Vector2.INF
var _target_kind: int = -1
var _target_required_interactions: int = 0
var _initial_available_count: int = 0
var _progress_result_count: int = 0
var _last_progress_completed: int = 0
var _last_progress_required: int = 0
var _resource_result_seen: bool = false
var _gathered_peer_id: int = -1
var _gathered_resource_id: int = -1
var _gathered_resource_kind: int = -1
var _gathered_amount: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_role = _read_role()
	if _role != "host" and _role != "client":
		_fail("expected --role=host or --role=client", 2)
		return
	if not _build_fixed_probe_tree():
		_fail("could not build the fixed probe node tree")
		return

	_session.session_ready.connect(_on_session_ready)
	_session.peer_registered.connect(_on_peer_registered)
	_session.authoritative_state_received.connect(_on_authoritative_state_received)
	_session.interaction_received.connect(_on_interaction_received)
	_scatter.resource_progressed.connect(_on_resource_progressed)
	_scatter.resource_gathered.connect(_on_resource_gathered)

	if _role == "host":
		_session.set_motion_resolver(_world_map.resolve_player_motion)
		_session.start_host(&"heikki")
		await _run_host_probe()
	else:
		_session.start_client("127.0.0.1", &"shane")
		await _run_client_probe()


func _build_fixed_probe_tree() -> bool:
	_probe_world = Node2D.new()
	_probe_world.name = &"ResourceEnetProbe"
	root.add_child(_probe_world)

	var y_sort_world: Node2D = Node2D.new()
	y_sort_world.name = &"YSortWorld"
	y_sort_world.z_index = 5
	y_sort_world.z_as_relative = false
	y_sort_world.y_sort_enabled = true
	_probe_world.add_child(y_sort_world)

	_world_map = WORLD_MAP_SCENE.instantiate() as BesprenWorldMap2D
	if _world_map == null:
		return false
	_world_map.name = &"WorldMap2D"
	y_sort_world.add_child(_world_map)
	_world_map.ensure_built()

	_scatter = RESOURCE_SCATTER_SCENE.instantiate() as BesprenResourceScatter2D
	if _scatter == null:
		return false
	_scatter.name = &"ResourceScatter2D"
	_scatter.world_map_path = NodePath("../WorldMap2D")
	y_sort_world.add_child(_scatter)
	_scatter.ensure_scattered()

	_session = CoopSession.new()
	_session.name = &"CoopSession"
	_probe_world.add_child(_session)

	if _world_map.get_path() != NodePath("/root/ResourceEnetProbe/YSortWorld/WorldMap2D"):
		return false
	if _scatter.get_path() != NodePath("/root/ResourceEnetProbe/YSortWorld/ResourceScatter2D"):
		return false
	if _session.get_path() != NodePath("/root/ResourceEnetProbe/CoopSession"):
		return false
	if _scatter.get_resource_count() <= TARGET_RESOURCE_ID:
		return false

	_target_position = _scatter.get_resource_position(TARGET_RESOURCE_ID)
	_target_kind = _scatter.get_resource_kind(TARGET_RESOURCE_ID)
	_target_required_interactions = _scatter.get_required_interactions(TARGET_RESOURCE_ID)
	_initial_available_count = _scatter.get_available_resource_count()
	return (
		_target_position.is_finite()
		and _target_kind >= 0
		and _target_required_interactions >= BesprenResourceScatter2D.MIN_GATHER_INTERACTIONS
		and _target_required_interactions <= BesprenResourceScatter2D.MAX_GATHER_INTERACTIONS
		and _world_map.is_position_walkable(
			_target_position,
			BesprenResourceScatter2D.RESOURCE_CLEARANCE
		)
	)


func _run_host_probe() -> void:
	var deadline: int = Time.get_ticks_msec() + PROBE_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		if _resource_state_matches():
			print(
				"RESOURCE ENET HOST OK | client=%d | resource=%d | inventory=%d"
				% [
					_client_peer_id,
					_gathered_resource_id,
					_scatter.get_inventory_amount(_client_peer_id, _target_kind),
				]
			)
			# Keep polling briefly so the reliable gather RPC reaches the client.
			await create_timer(0.75).timeout
			quit(0)
			return
		await physics_frame
	_fail(
		"host timeout | client=%d state=%s interacts=%d invoked=%d progress=%d/%d result=%d"
		% [
			_client_peer_id,
			_client_state_seen,
			_interaction_broadcast_count,
			_host_gather_invocation_count,
			_last_progress_completed,
			_target_required_interactions,
			_gathered_resource_id,
		]
	)


func _run_client_probe() -> void:
	var deadline: int = Time.get_ticks_msec() + PROBE_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		if _client_ready and _client_registered and _client_state_seen:
			_drive_client_to_anchor_and_interact()
		if _resource_state_matches():
			print(
				"RESOURCE ENET CLIENT OK | client=%d | resource=%d | inventory=%d"
				% [
					_local_peer_id,
					_gathered_resource_id,
					_scatter.get_inventory_amount(_local_peer_id, _target_kind),
				]
			)
			quit(0)
			return
		await physics_frame
	_fail(
		"client timeout | ready=%s registered=%s state=%s position=%s interacts=%d progress=%d/%d result=%d"
		% [
			_client_ready,
			_client_registered,
			_client_state_seen,
			_client_position,
			_interaction_broadcast_count,
			_last_progress_completed,
			_target_required_interactions,
			_gathered_resource_id,
		]
	)


func _drive_client_to_anchor_and_interact() -> void:
	if _last_progress_completed >= _target_required_interactions:
		return
	var offset_to_anchor: Vector2 = _target_position - _client_position
	var distance_to_anchor: float = offset_to_anchor.length()
	if distance_to_anchor > APPROACH_DISTANCE:
		_session.submit_movement(offset_to_anchor.normalized())
		return

	_session.submit_movement(Vector2.ZERO)
	if (
		distance_to_anchor <= BesprenResourceScatter2D.GATHER_RANGE
		and _client_movement.length_squared() <= STATIONARY_EPSILON_SQUARED
		and _submitted_interactions <= _last_progress_completed
		and Time.get_ticks_msec() - _last_submit_msec >= NEXT_INTERACTION_DELAY_MSEC
	):
		# The request contains only the validated action. The host supplies position,
		# resource ID, progress step, kind, and amount from authoritative state.
		_session.submit_interaction(&"interact")
		_submitted_interactions += 1
		_last_submit_msec = Time.get_ticks_msec()


func _on_session_ready(mode_value: int, local_peer_id: int) -> void:
	_local_peer_id = local_peer_id
	if _role == "client" and mode_value == CoopSession.SessionMode.CLIENT:
		_client_ready = true


func _on_peer_registered(
	peer_id: int,
	_character_id: StringName,
	_spawn_position: Vector2
) -> void:
	if _role == "host" and peer_id > CoopSession.AUTHORITY_PEER_ID:
		_client_peer_id = peer_id
	elif _role == "client" and peer_id == _local_peer_id:
		_client_peer_id = peer_id
		_client_registered = true


func _on_authoritative_state_received(
	peer_id: int,
	position: Vector2,
	movement: Vector2
) -> void:
	var expected_peer_id: int = _expected_client_peer_id()
	if expected_peer_id <= CoopSession.AUTHORITY_PEER_ID or peer_id != expected_peer_id:
		return
	_client_state_seen = true
	_client_position = position
	_client_movement = movement


func _on_interaction_received(
	peer_id: int,
	interaction: StringName,
	position: Vector2
) -> void:
	var expected_peer_id: int = _expected_client_peer_id()
	if (
		expected_peer_id <= CoopSession.AUTHORITY_PEER_ID
		or peer_id != expected_peer_id
		or interaction != &"interact"
		or not position.is_finite()
	):
		return
	_interaction_broadcast_count += 1
	_client_position = position
	if _role == "host":
		_host_gather_invocation_count += 1
		_host_selected_resource_id = _scatter.try_gather_authoritative(peer_id, position)


func _on_resource_progressed(
	peer_id: int,
	resource_kind: int,
	completed_interactions: int,
	required_interactions: int,
	_granted_amount: int,
	resource_id: int,
	_world_position: Vector2
) -> void:
	var expected_peer_id: int = _expected_client_peer_id()
	if (
		expected_peer_id <= CoopSession.AUTHORITY_PEER_ID
		or peer_id != expected_peer_id
		or resource_id != TARGET_RESOURCE_ID
		or resource_kind != _target_kind
	):
		return
	_progress_result_count += 1
	_last_progress_completed = completed_interactions
	_last_progress_required = required_interactions


func _on_resource_gathered(
	peer_id: int,
	resource_kind: int,
	amount: int,
	resource_id: int,
	_world_position: Vector2
) -> void:
	var expected_peer_id: int = _expected_client_peer_id()
	if expected_peer_id <= CoopSession.AUTHORITY_PEER_ID or peer_id != expected_peer_id:
		return
	_resource_result_seen = true
	_gathered_peer_id = peer_id
	_gathered_resource_id = resource_id
	_gathered_resource_kind = resource_kind
	_gathered_amount = amount


func _resource_state_matches() -> bool:
	var expected_peer_id: int = _expected_client_peer_id()
	var inventory_amount: int = _scatter.get_inventory_amount(expected_peer_id, _target_kind)
	if expected_peer_id <= CoopSession.AUTHORITY_PEER_ID:
		return false
	if (
		_interaction_broadcast_count != _target_required_interactions
		or _progress_result_count != _target_required_interactions
		or _last_progress_completed != _target_required_interactions
		or _last_progress_required != _target_required_interactions
		or not _resource_result_seen
		or _gathered_peer_id != expected_peer_id
		or _gathered_resource_id != TARGET_RESOURCE_ID
		or _gathered_resource_kind != _target_kind
		or _gathered_amount != BesprenResourceScatter2D.HARVEST_AMOUNT
		or _scatter.is_resource_available(TARGET_RESOURCE_ID)
		or _scatter.get_available_resource_count() != _initial_available_count - 1
		or inventory_amount != BesprenResourceScatter2D.HARVEST_AMOUNT
	):
		return false
	if _role == "host":
		if (
			_local_peer_id != CoopSession.AUTHORITY_PEER_ID
			or not _session.multiplayer.is_server()
			or _host_gather_invocation_count != _target_required_interactions
			or _host_selected_resource_id != TARGET_RESOURCE_ID
		):
			return false
	elif _session.multiplayer.is_server():
		return false
	return true


func _expected_client_peer_id() -> int:
	if _role == "host":
		return _client_peer_id
	return _local_peer_id


func _read_role() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			return argument.trim_prefix("--role=").to_lower()
	return ""


func _fail(message: String, exit_code: int = 1) -> void:
	push_error("RESOURCE ENET %s FAILED | %s" % [_role.to_upper(), message])
	quit(exit_code)
