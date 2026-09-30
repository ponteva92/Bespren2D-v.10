extends SceneTree
## Two-process probe. Run one --role=host and one --role=client.

const PROBE_TIMEOUT_MSEC: int = 8000

var _session: CoopSession
var _role: String = ""
var _local_peer_id: int = 0
var _remote_peer_id: int = 0
var _remote_spawn_position: Vector2 = Vector2.ZERO
var _client_ready: bool = false
var _client_registered: bool = false
var _movement_broadcast_seen: bool = false
var _interaction_broadcast_seen: bool = false
var _authoritative_auto_aim_seen: bool = false
var _aim_state_broadcast_seen: bool = false


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_role = _read_role()
	if _role != "host" and _role != "client":
		push_error("ENET PROBE FAILED | expected --role=host or --role=client")
		quit(2)
		return
	_session = CoopSession.new()
	_session.name = "CoopSession"
	root.add_child(_session)
	_session.session_ready.connect(_on_session_ready)
	_session.peer_registered.connect(_on_peer_registered)
	_session.authoritative_state_received.connect(_on_authoritative_state_received)
	_session.authoritative_aim_received.connect(_on_authoritative_aim_received)
	_session.interaction_received.connect(_on_interaction_received)
	_session.projectile_fired.connect(_on_projectile_fired)
	if _role == "host":
		_session.set_fire_direction_resolver(_resolve_host_auto_aim_direction)
		_session.start_host(&"heikki")
		await _run_host_probe()
	else:
		_session.start_client("127.0.0.1", &"shane")
		await _run_client_probe()


func _run_host_probe() -> void:
	var deadline: int = Time.get_ticks_msec() + PROBE_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		if (
			_remote_peer_id > CoopSession.AUTHORITY_PEER_ID
			and _movement_broadcast_seen
			and _interaction_broadcast_seen
			and _authoritative_auto_aim_seen
			and _aim_state_broadcast_seen
		):
			print(
				"ENET HOST OK | peer=%d | movement=%s | authoritative auto aim received"
				% [_remote_peer_id, _session.get_authoritative_position(_remote_peer_id)]
			)
			await create_timer(0.35).timeout
			quit(0)
			return
		await physics_frame
	push_error(
		"ENET HOST FAILED | peer=%d movement=%s interaction=%s auto_aim=%s aim_state=%s"
		% [
			_remote_peer_id,
			_movement_broadcast_seen,
			_interaction_broadcast_seen,
			_authoritative_auto_aim_seen,
			_aim_state_broadcast_seen,
		]
	)
	quit(1)


func _run_client_probe() -> void:
	var deadline: int = Time.get_ticks_msec() + PROBE_TIMEOUT_MSEC
	var fire_submitted: bool = false
	while Time.get_ticks_msec() < deadline:
		if _client_ready and _client_registered:
			_session.submit_movement(Vector2.RIGHT)
			if not fire_submitted:
				_session.submit_interaction(&"fire")
				fire_submitted = true
		if (
			_movement_broadcast_seen
			and _interaction_broadcast_seen
			and _authoritative_auto_aim_seen
			and _aim_state_broadcast_seen
		):
			print(
				"ENET CLIENT OK | peer=%d | authoritative movement and auto-aim fire received"
				% _local_peer_id
			)
			quit(0)
			return
		await physics_frame
	push_error(
		"ENET CLIENT FAILED | ready=%s registered=%s movement=%s interaction=%s auto_aim=%s aim_state=%s"
		% [
			_client_ready,
			_client_registered,
			_movement_broadcast_seen,
			_interaction_broadcast_seen,
			_authoritative_auto_aim_seen,
			_aim_state_broadcast_seen,
		]
	)
	quit(1)


func _on_session_ready(mode_value: int, local_peer_id: int) -> void:
	_local_peer_id = local_peer_id
	if _role == "client" and mode_value == CoopSession.SessionMode.CLIENT:
		_client_ready = true


func _on_peer_registered(
	peer_id: int,
	_character_id: StringName,
	spawn_position: Vector2
) -> void:
	if _role == "host" and peer_id > CoopSession.AUTHORITY_PEER_ID:
		_remote_peer_id = peer_id
		_remote_spawn_position = spawn_position
	elif _role == "client" and peer_id == _local_peer_id:
		_client_registered = true
		_remote_spawn_position = spawn_position


func _on_authoritative_state_received(
	peer_id: int,
	position: Vector2,
	movement: Vector2
) -> void:
	var expected_peer_id: int = _remote_peer_id if _role == "host" else _local_peer_id
	if (
		peer_id == expected_peer_id
		and movement.x > 0.9
		and position.x > _remote_spawn_position.x
	):
		_movement_broadcast_seen = true


func _on_authoritative_aim_received(
	peer_id: int,
	direction: Vector2,
	target_id: int,
	assisted: bool
) -> void:
	var expected_peer_id: int = _remote_peer_id if _role == "host" else _local_peer_id
	if (
		peer_id == expected_peer_id
		and direction.dot(Vector2.DOWN) > 0.99
		and target_id == 77
		and assisted
	):
		_aim_state_broadcast_seen = true


func _on_interaction_received(
	peer_id: int,
	interaction: StringName,
	_position: Vector2
) -> void:
	var expected_peer_id: int = _remote_peer_id if _role == "host" else _local_peer_id
	if peer_id == expected_peer_id and interaction == &"fire":
		_interaction_broadcast_seen = true


func _on_projectile_fired(
	peer_id: int,
	_position: Vector2,
	direction: Vector2
) -> void:
	var expected_peer_id: int = _remote_peer_id if _role == "host" else _local_peer_id
	if peer_id == expected_peer_id and direction.dot(Vector2.DOWN) > 0.99:
		_authoritative_auto_aim_seen = true


func _resolve_host_auto_aim_direction(
	peer_id: int,
	_position: Vector2,
	_fallback_direction: Vector2
) -> Vector2:
	_session.set_peer_aim_state_authoritative(peer_id, Vector2.DOWN, 77, true)
	return Vector2.DOWN


func _read_role() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			return argument.trim_prefix("--role=").to_lower()
	return ""
