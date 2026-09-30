extends SceneTree
## Two-process ENet proof for client requests and host-authored tactical commits.

const PROBE_TIMEOUT_MSEC: int = 20000

var _role: String = ""
var _world: GameWorld
var _session: CoopSession
var _manager: TacticalBuildSystem
var _cycle: DayNightCycle
var _local_peer_id: int = 0
var _remote_peer_id: int = 0
var _client_registered: bool = false
var _structure_position: Vector2 = Vector2.INF
var _base_position: Vector2 = Vector2.INF
var _saw_structure: bool = false
var _saw_nonblocking_trap: bool = false
var _saw_relocation: bool = false
var _client_requested_build: bool = false
var _client_requested_relocation: bool = false
var _client_requested_night: bool = false


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_role = _read_role()
	if _role != "host" and _role != "client":
		_fail("expected --role=host or --role=client", 2)
		return
	var world_scene: PackedScene = load("res://scenes/game/game_world.tscn") as PackedScene
	_world = world_scene.instantiate() as GameWorld
	if _world == null:
		_fail("GameWorld did not instantiate")
		return
	_world.configure_launch(
		CoopSession.SessionMode.HOST if _role == "host" else CoopSession.SessionMode.CLIENT,
		&"heikki" if _role == "host" else &"shane",
		"127.0.0.1"
	)
	root.add_child(_world)
	await process_frame
	_session = _world.session
	_manager = _world.build_system
	_cycle = _world.day_night
	_session.session_ready.connect(_on_session_ready)
	_session.peer_registered.connect(_on_peer_registered)
	_manager.structure_placed.connect(_on_structure_placed)
	_manager.base_relocated.connect(_on_base_relocated)
	_structure_position = _find_clear_grid_position(_world.world_map, [], 82.0)
	_base_position = _find_clear_grid_position(
		_world.world_map,
		[_structure_position],
		TacticalBuildSystem.BASE_CLEARANCE + 8.0
	)
	if not _structure_position.is_finite() or not _base_position.is_finite():
		_fail("could not find deterministic grid targets")
		return
	if _role == "host":
		await _run_host_probe()
	else:
		await _run_client_probe()


func _run_host_probe() -> void:
	var deadline: int = Time.get_ticks_msec() + PROBE_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		if _host_state_matches():
			print("TACTICAL ENET HOST OK | peer=%d | base=%s | pool=%s | night=%d" % [
				_remote_peer_id,
				_manager.get_base_position(),
				_manager.get_resource_pool(),
				_cycle.get_night_number(),
			])
			await create_timer(1.0).timeout
			_cleanup_and_quit(0)
			return
		await process_frame
	_fail("host timeout | peer=%d structure=%s relocation=%s night=%s" % [
		_remote_peer_id,
		_saw_structure,
		_saw_relocation,
		_cycle.is_night(),
	])


func _run_client_probe() -> void:
	var deadline: int = Time.get_ticks_msec() + PROBE_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		if _client_registered and not _client_requested_build:
			_manager.request_structure_placement(StructureCatalog.T1_RAZOR_SNARE, _structure_position)
			_client_requested_build = true
		if _client_requested_build and _manager.get_structure_count() == 1 and not _client_requested_relocation:
			_manager.request_base_relocation(_base_position)
			_client_requested_relocation = true
		if _client_requested_relocation and _client_relocation_matches() and not _client_requested_night:
			_cycle.request_start_night()
			_client_requested_night = true
		if _client_state_matches():
			print("TACTICAL ENET CLIENT OK | peer=%d | base=%s | pool=%s | night=%d" % [
				_local_peer_id,
				_manager.get_base_position(),
				_manager.get_resource_pool(),
				_cycle.get_night_number(),
			])
			_cleanup_and_quit(0)
			return
		await process_frame
	_fail("client timeout | registered=%s build=%s relocation=%s night=%s pool=%s" % [
		_client_registered,
		_client_requested_build,
		_client_requested_relocation,
		_cycle.is_night(),
		_manager.get_resource_pool(),
	])


func _host_state_matches() -> bool:
	return (
		_remote_peer_id > CoopSession.AUTHORITY_PEER_ID
		and _saw_structure
		and _saw_nonblocking_trap
		and _saw_relocation
		and _client_relocation_matches()
		and _cycle.is_night()
	)


func _client_state_matches() -> bool:
	return _client_requested_night and _client_relocation_matches() and _cycle.is_night()


func _client_relocation_matches() -> bool:
	return (
		_saw_relocation
		and _manager.get_structure_count() == 0
		and _manager.get_base_position() == _base_position
		and _manager.get_resource_pool() == PackedInt32Array([112, 88, 74])
	)


func _on_session_ready(_mode_value: int, local_peer_id: int) -> void:
	_local_peer_id = local_peer_id


func _on_peer_registered(
	peer_id: int,
	_character_id: StringName,
	_spawn_position: Vector2
) -> void:
	if _role == "host" and peer_id > CoopSession.AUTHORITY_PEER_ID:
		_remote_peer_id = peer_id
	elif _role == "client" and peer_id == _local_peer_id:
		_client_registered = true


func _on_structure_placed(structure: PlacedStructure2D) -> void:
	if structure.structure_id == StructureCatalog.T1_RAZOR_SNARE:
		_saw_structure = true
		_saw_nonblocking_trap = (
			not structure.blocks_navigation()
			and structure.collision_layer == 0
			and structure.get_node_or_null(NodePath("CollisionShape2D")) == null
		)


func _on_base_relocated(
	world_position: Vector2,
	refund: PackedInt32Array,
	destroyed_count: int
) -> void:
	_saw_relocation = (
		world_position == _base_position
		and refund == PackedInt32Array([4, 6, 2])
		and destroyed_count == 1
	)


func _find_clear_grid_position(
	world_map: BesprenWorldMap2D,
	excluded_positions: Array[Vector2],
	clearance: float
) -> Vector2:
	for cell_y: int in range(-48, 49):
		for cell_x: int in range(-48, 49):
			var candidate: Vector2 = Vector2(float(cell_x) * 64.0, float(cell_y) * 64.0)
			if not world_map.is_position_walkable(candidate, clearance):
				continue
			var separated: bool = true
			for excluded: Vector2 in excluded_positions:
				if candidate.distance_to(excluded) < clearance * 2.5:
					separated = false
					break
			if separated:
				return candidate
	return Vector2.INF


func _read_role() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			return argument.trim_prefix("--role=").to_lower()
	return ""


func _cleanup_and_quit(exit_code: int) -> void:
	if is_instance_valid(_world):
		_world.process_mode = Node.PROCESS_MODE_DISABLED
		_world.audio.stop_all()
		_world.juice_rig.stop_all()
		var active_peer: MultiplayerPeer = _session.multiplayer.multiplayer_peer
		_session.mode = CoopSession.SessionMode.SOLO
		if active_peer is ENetMultiplayerPeer:
			(active_peer as ENetMultiplayerPeer).close()
		_session.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		_world.queue_free()
		await process_frame
		await process_frame
		await create_timer(0.1).timeout
	quit(exit_code)


func _fail(message: String, exit_code: int = 1) -> void:
	push_error("TACTICAL ENET %s FAILED | %s" % [_role.to_upper(), message])
	_cleanup_and_quit(exit_code)
