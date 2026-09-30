class_name CoopSession
extends Node
## Host-authoritative ENet session with an OfflineMultiplayerPeer solo fallback.

enum SessionMode {
	SOLO,
	HOST,
	CLIENT,
}

signal session_ready(mode_value: int, local_peer_id: int)
signal session_notice(message: String)
signal match_aborted(message: String)
signal roster_reset
signal peer_registered(peer_id: int, character_id: StringName, spawn_position: Vector2)
signal peer_left(peer_id: int)
signal authoritative_state_received(peer_id: int, position: Vector2, movement: Vector2)
signal authoritative_aim_received(
	peer_id: int,
	direction: Vector2,
	target_id: int,
	assisted: bool
)
signal interaction_received(peer_id: int, interaction: StringName, position: Vector2)
signal projectile_fired(peer_id: int, position: Vector2, direction: Vector2)

const AUTHORITY_PEER_ID: int = MultiplayerPeer.TARGET_PEER_SERVER
const PORT: int = 8791
## One Join beside the host. A third device is refused by ENet, which matches
## the horde scale clamp of two peers.
const MAX_CLIENTS: int = 1
const CLIENT_CONNECT_TIMEOUT_SECONDS: float = 2.5
const MOVEMENT_SPEED: float = 420.0
const STATE_BROADCAST_HZ: float = 20.0
const INTERACTION_COOLDOWN_SECONDS: float = 0.15
const PLAYER_COLLISION_RADIUS: float = 9.0
const VALID_CHARACTERS: Array[StringName] = [&"heikki", &"shane"]
const ALLOWED_INTERACTIONS: Array[StringName] = [&"interact", &"fire"]
const WORLD_MIN: Vector2 = Vector2(-14327.0, -14327.0)
const WORLD_MAX: Vector2 = Vector2(14327.0, 14327.0)

var mode: SessionMode = SessionMode.SOLO
var local_character_id: StringName = &"heikki"

var _registered_characters: Dictionary[int, StringName] = {}
var _authoritative_positions: Dictionary[int, Vector2] = {}
var _movement_intents: Dictionary[int, Vector2] = {}
var _facing_directions: Dictionary[int, Vector2] = {}
var _aim_directions: Dictionary[int, Vector2] = {}
var _aim_target_ids: Dictionary[int, int] = {}
var _aim_assisted: Dictionary[int, bool] = {}
var _connection_attempt: int = 0
var _connection_established: bool = false
var _broadcast_accumulator: float = 0.0
var _session_elapsed_seconds: float = 0.0
var _interaction_ready_at: Dictionary[int, float] = {}
var _motion_resolver: Callable = Callable()
var _fire_direction_resolver: Callable = Callable()
var _combat_active: Dictionary[int, bool] = {}
var _match_abort_sent: bool = false


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _physics_process(delta: float) -> void:
	_session_elapsed_seconds += maxf(delta, 0.0)
	if not multiplayer.is_server() or _registered_characters.is_empty():
		return
	for peer_id: int in _registered_characters:
		var movement: Vector2 = (
			_movement_intents.get(peer_id, Vector2.ZERO)
			if _combat_active.get(peer_id, true)
			else Vector2.ZERO
		)
		var current_position: Vector2 = _authoritative_positions.get(
			peer_id,
			_spawn_position_for(peer_id)
		)
		var next_position: Vector2 = current_position + movement * MOVEMENT_SPEED * delta
		if _motion_resolver.is_valid():
			var resolved_position: Variant = _motion_resolver.call(
				current_position,
				next_position,
				PLAYER_COLLISION_RADIUS
			)
			if resolved_position is Vector2 and resolved_position.is_finite():
				next_position = resolved_position
			else:
				next_position = current_position
		else:
			next_position.x = clampf(next_position.x, WORLD_MIN.x, WORLD_MAX.x)
			next_position.y = clampf(next_position.y, WORLD_MIN.y, WORLD_MAX.y)
		_authoritative_positions[peer_id] = next_position

	_broadcast_accumulator += delta
	var interval: float = 1.0 / STATE_BROADCAST_HZ
	if _broadcast_accumulator < interval:
		return
	_broadcast_accumulator = fmod(_broadcast_accumulator, interval)
	for peer_id: int in _registered_characters:
		_broadcast_authoritative_state.rpc(
			peer_id,
			_authoritative_positions[peer_id],
			_movement_intents.get(peer_id, Vector2.ZERO)
		)
		_broadcast_authoritative_aim.rpc(
			peer_id,
			_aim_directions.get(peer_id, _facing_directions.get(peer_id, Vector2.RIGHT)),
			_aim_target_ids.get(peer_id, -1),
			_aim_assisted.get(peer_id, false)
		)


func start_solo(character_id: StringName) -> void:
	_prepare_session(character_id)
	mode = SessionMode.SOLO
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_register_authoritative_peer(
		AUTHORITY_PEER_ID,
		local_character_id,
		_spawn_position_for(AUTHORITY_PEER_ID)
	)
	session_ready.emit(mode, multiplayer.get_unique_id())
	session_notice.emit("Solo authority ready")


func start_host(character_id: StringName) -> void:
	_prepare_session(character_id)
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var create_error: Error = peer.create_server(PORT, MAX_CLIENTS)
	if create_error != OK:
		_fallback_to_solo("Port %d unavailable; continuing in Solo mode" % PORT)
		return
	mode = SessionMode.HOST
	multiplayer.multiplayer_peer = peer
	_register_authoritative_peer(
		AUTHORITY_PEER_ID,
		local_character_id,
		_spawn_position_for(AUTHORITY_PEER_ID)
	)
	session_ready.emit(mode, multiplayer.get_unique_id())
	session_notice.emit("Hosting ENet LAN on port %d" % PORT)


func start_client(address: String, character_id: StringName) -> void:
	_prepare_session(character_id)
	var sanitized_address: String = address.strip_edges()
	if sanitized_address.is_empty():
		sanitized_address = "127.0.0.1"
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var create_error: Error = peer.create_client(sanitized_address, PORT)
	if create_error != OK:
		_fallback_to_solo("Could not start LAN client; continuing in Solo mode")
		return
	mode = SessionMode.CLIENT
	multiplayer.multiplayer_peer = peer
	_connection_established = false
	_connection_attempt += 1
	var attempt_id: int = _connection_attempt
	session_notice.emit("Connecting to %s:%d..." % [sanitized_address, PORT])
	_wait_for_client_timeout(attempt_id)


func submit_movement(movement: Vector2) -> void:
	if not movement.is_finite():
		return
	var sanitized: Vector2 = movement.limit_length(1.0)
	if multiplayer.is_server():
		_request_movement(sanitized)
	else:
		_request_movement.rpc_id(AUTHORITY_PEER_ID, sanitized)


func submit_interaction(interaction: StringName) -> void:
	if not ALLOWED_INTERACTIONS.has(interaction):
		return
	if multiplayer.is_server():
		_request_interaction(interaction)
	else:
		_request_interaction.rpc_id(AUTHORITY_PEER_ID, interaction)


func set_motion_resolver(resolver: Callable) -> void:
	_motion_resolver = resolver


func set_fire_direction_resolver(resolver: Callable) -> void:
	_fire_direction_resolver = resolver


func has_motion_resolver() -> bool:
	return _motion_resolver.is_valid()


func has_fire_direction_resolver() -> bool:
	return _fire_direction_resolver.is_valid()


func set_peer_aim_state_authoritative(
	peer_id: int,
	direction: Vector2,
	target_id: int,
	assisted: bool
) -> void:
	if (
		not multiplayer.is_server()
		or not _registered_characters.has(peer_id)
		or not direction.is_finite()
		or direction.is_zero_approx()
	):
		return
	_aim_directions[peer_id] = direction.normalized()
	_aim_target_ids[peer_id] = maxi(target_id, -1)
	_aim_assisted[peer_id] = assisted and target_id >= 0


func get_peer_aim_direction(peer_id: int) -> Vector2:
	var direction: Vector2 = _aim_directions.get(
		peer_id,
		_facing_directions.get(peer_id, Vector2.RIGHT)
	)
	if not direction.is_finite() or direction.is_zero_approx():
		return Vector2.RIGHT
	return direction.normalized()


func get_peer_aim_target_id(peer_id: int) -> int:
	return _aim_target_ids.get(peer_id, -1)


func is_peer_aim_assisted(peer_id: int) -> bool:
	return _aim_assisted.get(peer_id, false)


func get_authoritative_position(peer_id: int) -> Vector2:
	return _authoritative_positions.get(peer_id, Vector2.ZERO)


func is_connection_established() -> bool:
	return _connection_established


func is_peer_registered(peer_id: int) -> bool:
	return _registered_characters.has(peer_id)


func set_peer_combat_active_authoritative(peer_id: int, active: bool) -> void:
	if not multiplayer.is_server() or not _registered_characters.has(peer_id):
		return
	_combat_active[peer_id] = active
	if not active:
		_movement_intents[peer_id] = Vector2.ZERO
		_broadcast_authoritative_state.rpc(
			peer_id,
			_authoritative_positions[peer_id],
			Vector2.ZERO
		)


func teleport_peer_authoritative(peer_id: int, world_position: Vector2) -> void:
	if (
		not multiplayer.is_server()
		or not _registered_characters.has(peer_id)
		or not world_position.is_finite()
	):
		return
	_authoritative_positions[peer_id] = world_position
	_movement_intents[peer_id] = Vector2.ZERO
	_broadcast_authoritative_state.rpc(peer_id, world_position, Vector2.ZERO)


func is_peer_combat_active(peer_id: int) -> bool:
	return _combat_active.get(peer_id, false)


func get_registered_peer_ids() -> Array[int]:
	var peer_ids: Array[int] = []
	for peer_id: int in _registered_characters:
		peer_ids.append(peer_id)
	peer_ids.sort()
	return peer_ids


func is_interaction_ready(peer_id: int) -> bool:
	if not multiplayer.is_server() or not _registered_characters.has(peer_id):
		return false
	var ready_at: float = _interaction_ready_at.get(peer_id, 0.0)
	return _session_elapsed_seconds >= ready_at


func get_interaction_cooldown_remaining(peer_id: int) -> float:
	if not _registered_characters.has(peer_id):
		return 0.0
	var ready_at: float = _interaction_ready_at.get(peer_id, 0.0)
	return maxf(ready_at - _session_elapsed_seconds, 0.0)


@rpc("any_peer", "call_local", "reliable")
func _request_registration(character_id: StringName) -> void:
	if not multiplayer.is_server():
		return
	var source_peer_id: int = multiplayer.get_remote_sender_id()
	if source_peer_id <= 0:
		source_peer_id = multiplayer.get_unique_id()
	var sanitized_character: StringName = _sanitize_character(character_id)
	if _registered_characters.has(source_peer_id):
		return
	if not _register_if_character_free(source_peer_id, sanitized_character):
		if source_peer_id != multiplayer.get_unique_id():
			_reject_registration.rpc_id(
				source_peer_id,
				"That scavenger is already in the match."
			)
			var enet_peer: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
			if enet_peer != null:
				enet_peer.disconnect_peer(source_peer_id)
		else:
			session_notice.emit("That scavenger is already in the match.")


@rpc("any_peer", "call_local", "unreliable_ordered")
func _request_movement(movement: Vector2) -> void:
	if not multiplayer.is_server() or not movement.is_finite():
		return
	var source_peer_id: int = multiplayer.get_remote_sender_id()
	if source_peer_id <= 0:
		source_peer_id = multiplayer.get_unique_id()
	if (
		not _registered_characters.has(source_peer_id)
		or not _combat_active.get(source_peer_id, true)
	):
		return
	var sanitized_movement: Vector2 = movement.limit_length(1.0)
	_movement_intents[source_peer_id] = sanitized_movement
	if not sanitized_movement.is_zero_approx():
		_facing_directions[source_peer_id] = sanitized_movement.normalized()


@rpc("any_peer", "call_local", "reliable")
func _request_interaction(interaction: StringName) -> void:
	if not multiplayer.is_server() or not ALLOWED_INTERACTIONS.has(interaction):
		return
	var source_peer_id: int = multiplayer.get_remote_sender_id()
	if source_peer_id <= 0:
		source_peer_id = multiplayer.get_unique_id()
	if (
		not _registered_characters.has(source_peer_id)
		or not _combat_active.get(source_peer_id, true)
	):
		return
	if not is_interaction_ready(source_peer_id):
		return
	_interaction_ready_at[source_peer_id] = (
		_session_elapsed_seconds + INTERACTION_COOLDOWN_SECONDS
	)
	var facing_direction: Vector2 = _facing_directions.get(source_peer_id, Vector2.RIGHT)
	if not facing_direction.is_finite() or facing_direction.is_zero_approx():
		facing_direction = Vector2.RIGHT
	else:
		facing_direction = facing_direction.normalized()
	if interaction == &"fire" and _fire_direction_resolver.is_valid():
		var resolved_value: Variant = _fire_direction_resolver.call(
			source_peer_id,
			_authoritative_positions[source_peer_id],
			facing_direction
		)
		if resolved_value is Vector2:
			var resolved_direction: Vector2 = resolved_value as Vector2
			if resolved_direction.is_finite() and not resolved_direction.is_zero_approx():
				facing_direction = resolved_direction.normalized()
	_broadcast_interaction.rpc(
		source_peer_id,
		interaction,
		_authoritative_positions[source_peer_id],
		facing_direction
	)


@rpc("authority", "call_local", "reliable")
func _announce_registration(
	peer_id: int,
	character_id: StringName,
	spawn_position: Vector2
) -> void:
	if peer_id <= 0 or not spawn_position.is_finite():
		return
	var sanitized_character: StringName = _sanitize_character(character_id)
	_registered_characters[peer_id] = sanitized_character
	_authoritative_positions[peer_id] = spawn_position
	if not _movement_intents.has(peer_id):
		_movement_intents[peer_id] = Vector2.ZERO
	if not _facing_directions.has(peer_id):
		_facing_directions[peer_id] = Vector2.RIGHT
	if not _aim_directions.has(peer_id):
		_aim_directions[peer_id] = _facing_directions[peer_id]
	if not _aim_target_ids.has(peer_id):
		_aim_target_ids[peer_id] = -1
	if not _aim_assisted.has(peer_id):
		_aim_assisted[peer_id] = false
	if not _interaction_ready_at.has(peer_id):
		_interaction_ready_at[peer_id] = 0.0
	peer_registered.emit(peer_id, sanitized_character, spawn_position)


@rpc("authority", "call_local", "reliable")
func _announce_peer_left(peer_id: int) -> void:
	_registered_characters.erase(peer_id)
	_authoritative_positions.erase(peer_id)
	_movement_intents.erase(peer_id)
	_facing_directions.erase(peer_id)
	_aim_directions.erase(peer_id)
	_aim_target_ids.erase(peer_id)
	_aim_assisted.erase(peer_id)
	_interaction_ready_at.erase(peer_id)
	peer_left.emit(peer_id)


@rpc("authority", "call_local", "unreliable_ordered")
func _broadcast_authoritative_state(
	peer_id: int,
	position: Vector2,
	movement: Vector2
) -> void:
	if (
		not _registered_characters.has(peer_id)
		or not position.is_finite()
		or not movement.is_finite()
	):
		return
	_authoritative_positions[peer_id] = position
	_movement_intents[peer_id] = movement.limit_length(1.0)
	authoritative_state_received.emit(peer_id, position, movement)


@rpc("authority", "call_local", "unreliable_ordered")
func _broadcast_authoritative_aim(
	peer_id: int,
	direction: Vector2,
	target_id: int,
	assisted: bool
) -> void:
	if (
		not _registered_characters.has(peer_id)
		or not direction.is_finite()
		or direction.is_zero_approx()
	):
		return
	_aim_directions[peer_id] = direction.normalized()
	_aim_target_ids[peer_id] = maxi(target_id, -1)
	_aim_assisted[peer_id] = assisted and target_id >= 0
	authoritative_aim_received.emit(
		peer_id,
		_aim_directions[peer_id],
		_aim_target_ids[peer_id],
		_aim_assisted[peer_id]
	)


@rpc("authority", "call_local", "reliable")
func _broadcast_interaction(
	peer_id: int,
	interaction: StringName,
	position: Vector2,
	direction: Vector2
) -> void:
	if not direction.is_finite() or direction.is_zero_approx():
		return
	var normalized_direction: Vector2 = direction.normalized()
	interaction_received.emit(peer_id, interaction, position)
	if interaction == &"fire":
		projectile_fired.emit(peer_id, position, normalized_direction)


func _prepare_session(character_id: StringName) -> void:
	_connection_attempt += 1
	_connection_established = false
	_match_abort_sent = false
	_broadcast_accumulator = 0.0
	_session_elapsed_seconds = 0.0
	local_character_id = _sanitize_character(character_id)
	var previous_peer_ids: Array[int] = get_registered_peer_ids()
	roster_reset.emit()
	for peer_id: int in previous_peer_ids:
		peer_left.emit(peer_id)
	_registered_characters.clear()
	_authoritative_positions.clear()
	_movement_intents.clear()
	_facing_directions.clear()
	_aim_directions.clear()
	_aim_target_ids.clear()
	_aim_assisted.clear()
	_interaction_ready_at.clear()
	_combat_active.clear()


func _register_authoritative_peer(
	peer_id: int,
	character_id: StringName,
	spawn_position: Vector2
) -> void:
	_registered_characters[peer_id] = character_id
	_authoritative_positions[peer_id] = spawn_position
	_movement_intents[peer_id] = Vector2.ZERO
	_facing_directions[peer_id] = Vector2.RIGHT
	_aim_directions[peer_id] = Vector2.RIGHT
	_aim_target_ids[peer_id] = -1
	_aim_assisted[peer_id] = false
	_interaction_ready_at[peer_id] = 0.0
	_combat_active[peer_id] = true
	if mode == SessionMode.SOLO:
		_announce_registration(peer_id, character_id, spawn_position)
	else:
		_announce_registration.rpc(peer_id, character_id, spawn_position)


func _on_connected_to_server() -> void:
	if mode != SessionMode.CLIENT:
		return
	_connection_established = true
	session_ready.emit(mode, multiplayer.get_unique_id())
	session_notice.emit("Connected to LAN host on port %d" % PORT)
	_request_registration.rpc_id(AUTHORITY_PEER_ID, local_character_id)


func _on_connection_failed() -> void:
	if mode == SessionMode.CLIENT and not _connection_established:
		_fallback_to_solo("LAN host unavailable; continuing in Solo mode")


func _on_server_disconnected() -> void:
	if mode != SessionMode.CLIENT or _match_abort_sent:
		return
	if _connection_established:
		abort_established_match("Host left. The match is over.")
		return
	_fallback_to_solo("LAN host disconnected; continuing in Solo mode")


func abort_established_match(message: String) -> void:
	if _match_abort_sent:
		return
	_match_abort_sent = true
	_connection_attempt += 1
	_connection_established = false
	var active_peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if active_peer != null:
		active_peer.close()
	match_aborted.emit(message)
	if is_instance_valid(self) and multiplayer.multiplayer_peer == active_peer:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	for existing_peer_id: int in _registered_characters:
		_announce_registration.rpc_id(
			peer_id,
			existing_peer_id,
			_registered_characters[existing_peer_id],
			_authoritative_positions[existing_peer_id]
		)


func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server() or not _registered_characters.has(peer_id):
		return
	_registered_characters.erase(peer_id)
	_authoritative_positions.erase(peer_id)
	_movement_intents.erase(peer_id)
	_facing_directions.erase(peer_id)
	_aim_directions.erase(peer_id)
	_aim_target_ids.erase(peer_id)
	_aim_assisted.erase(peer_id)
	_interaction_ready_at.erase(peer_id)
	_combat_active.erase(peer_id)
	_announce_peer_left.rpc(peer_id)


func _wait_for_client_timeout(attempt_id: int) -> void:
	await get_tree().create_timer(CLIENT_CONNECT_TIMEOUT_SECONDS).timeout
	if (
		attempt_id == _connection_attempt
		and mode == SessionMode.CLIENT
		and not _connection_established
	):
		_fallback_to_solo("LAN connection timed out; continuing in Solo mode")


func _fallback_to_solo(message: String) -> void:
	var character_id: StringName = local_character_id
	start_solo(character_id)
	session_notice.emit(message)


func _register_if_character_free(source_peer_id: int, character_id: StringName) -> bool:
	if _registered_characters.has(source_peer_id) or _character_is_taken(character_id):
		return false
	_register_authoritative_peer(
		source_peer_id,
		character_id,
		_spawn_position_for(source_peer_id)
	)
	return true


func _character_is_taken(character_id: StringName) -> bool:
	for registered_character: StringName in _registered_characters.values():
		if registered_character == character_id:
			return true
	return false


@rpc("authority", "call_remote", "reliable")
func _reject_registration(message: String) -> void:
	session_notice.emit(message)


func _sanitize_character(character_id: StringName) -> StringName:
	var normalized: StringName = StringName(String(character_id).to_lower())
	if VALID_CHARACTERS.has(normalized):
		return normalized
	return &"heikki"


func _spawn_position_for(peer_id: int) -> Vector2:
	var column: int = (peer_id - 1) % 4
	return BesprenWorldMap2D.STARTING_CAMP_POSITION + Vector2(
		-220.0 + float(column) * 145.0,
		285.0 + float(column % 2) * 95.0
	)
