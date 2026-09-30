class_name CombatStateCoordinator
extends Node
## Peer-one authority for Base health, player deaths, respawns, and Game Over.

signal base_health_changed(current_health: int, maximum_health: int)
signal player_health_changed(peer_id: int, current_health: int, maximum_health: int)
signal respawn_started(peer_id: int, seconds_remaining: float)
signal player_respawned(peer_id: int, world_position: Vector2)
signal game_over(reason: StringName)

const PLAYER_MAX_HEALTH: int = 100
const BASE_MAX_HEALTH: int = 1600
const RESPAWN_DELAY_SECONDS: float = 10.0
const RESPAWN_OFFSET_DISTANCE: float = 230.0

@export_node_path("CoopSession") var session_path: NodePath
@export_node_path("CorePulseDriver") var base_core_path: NodePath

var _session: CoopSession
var _base_core: CorePulseDriver
var _players: Dictionary[int, PlayerAvatar] = {}
var _health_by_peer: Dictionary[int, int] = {}
var _alive_by_peer: Dictionary[int, bool] = {}
var _respawn_remaining: Dictionary[int, float] = {}
var _base_health: int = BASE_MAX_HEALTH
var _game_over: bool = false


func _ready() -> void:
	_session = get_node_or_null(session_path) as CoopSession
	_base_core = get_node_or_null(base_core_path) as CorePulseDriver
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or _game_over or _respawn_remaining.is_empty():
		return
	var elapsed: float = maxf(delta, 0.0)
	var peer_ids: Array[int] = _respawn_remaining.keys()
	peer_ids.sort()
	for peer_id: int in peer_ids:
		var remaining: float = maxf(_respawn_remaining.get(peer_id, 0.0) - elapsed, 0.0)
		_respawn_remaining[peer_id] = remaining
		if remaining <= 0.0:
			_respawn_player_authoritative(peer_id)


func initialize_for_session() -> void:
	if not multiplayer.is_server():
		return
	_game_over = false
	_base_health = BASE_MAX_HEALTH
	_respawn_remaining.clear()
	for peer_id: int in _players:
		_health_by_peer[peer_id] = PLAYER_MAX_HEALTH
		_alive_by_peer[peer_id] = true
		_commit_player_state.rpc(peer_id, PLAYER_MAX_HEALTH, true, 0.0)
	_commit_base_health.rpc(_base_health)


func reset_for_session() -> void:
	_players.clear()
	_health_by_peer.clear()
	_alive_by_peer.clear()
	_respawn_remaining.clear()
	_base_health = BASE_MAX_HEALTH
	_game_over = false
	if is_instance_valid(_base_core):
		_base_core.set_health_ratio(1.0)


func register_player(player: PlayerAvatar) -> void:
	if not is_instance_valid(player) or player.peer_id <= 0:
		return
	_players[player.peer_id] = player
	if not _health_by_peer.has(player.peer_id):
		_health_by_peer[player.peer_id] = PLAYER_MAX_HEALTH
		_alive_by_peer[player.peer_id] = true
	player.set_combat_state(
		_health_by_peer[player.peer_id],
		_alive_by_peer.get(player.peer_id, true)
	)
	if multiplayer.is_server():
		_commit_player_state.rpc(
			player.peer_id,
			_health_by_peer[player.peer_id],
			_alive_by_peer.get(player.peer_id, true),
			_respawn_remaining.get(player.peer_id, 0.0)
		)


func unregister_player(peer_id: int) -> void:
	_players.erase(peer_id)
	_health_by_peer.erase(peer_id)
	_alive_by_peer.erase(peer_id)
	_respawn_remaining.erase(peer_id)


func damage_player_authoritative(peer_id: int, amount: int) -> int:
	if (
		not multiplayer.is_server()
		or _game_over
		or amount <= 0
		or not _alive_by_peer.get(peer_id, false)
	):
		return 0
	var current_health: int = _health_by_peer.get(peer_id, PLAYER_MAX_HEALTH)
	var applied: int = mini(amount, current_health)
	var next_health: int = current_health - applied
	_health_by_peer[peer_id] = next_health
	if next_health > 0:
		_commit_player_state.rpc(peer_id, next_health, true, 0.0)
		return applied
	_alive_by_peer[peer_id] = false
	if is_instance_valid(_session):
		_session.set_peer_combat_active_authoritative(peer_id, false)
	_commit_player_state.rpc(peer_id, 0, false, RESPAWN_DELAY_SECONDS)
	if _all_registered_players_dead():
		_trigger_game_over_authoritative(&"all_players_dead")
	else:
		_respawn_remaining[peer_id] = RESPAWN_DELAY_SECONDS
		respawn_started.emit(peer_id, RESPAWN_DELAY_SECONDS)
	return applied


func damage_base_authoritative(amount: int) -> int:
	if not multiplayer.is_server() or _game_over or amount <= 0 or _base_health <= 0:
		return 0
	var applied: int = mini(amount, _base_health)
	_base_health -= applied
	_commit_base_health.rpc(_base_health)
	if _base_health <= 0:
		_trigger_game_over_authoritative(&"main_base_destroyed")
	return applied


func sync_state_to_peer(peer_id: int) -> void:
	if not multiplayer.is_server() or peer_id <= CoopSession.AUTHORITY_PEER_ID:
		return
	_receive_combat_snapshot.rpc_id(
		peer_id,
		_base_health,
		PackedInt32Array(_sorted_peer_ids()),
		_pack_player_health(),
		_pack_player_alive(),
		_pack_respawn_remaining(),
		_game_over
	)


func get_living_players() -> Array[PlayerAvatar]:
	var living: Array[PlayerAvatar] = []
	var peer_ids: Array[int] = _players.keys()
	peer_ids.sort()
	for peer_id: int in peer_ids:
		var player: PlayerAvatar = _players.get(peer_id)
		if is_instance_valid(player) and _alive_by_peer.get(peer_id, true):
			living.append(player)
	return living


func get_player(peer_id: int) -> PlayerAvatar:
	return _players.get(peer_id)


func get_base_position() -> Vector2:
	return _base_core.global_position if is_instance_valid(_base_core) else Vector2.ZERO


func get_base_health() -> int:
	return _base_health


func get_player_health(peer_id: int) -> int:
	return _health_by_peer.get(peer_id, 0)


func get_respawn_remaining(peer_id: int) -> float:
	return _respawn_remaining.get(peer_id, 0.0)


func is_game_over() -> bool:
	return _game_over


@rpc("authority", "call_local", "reliable")
func _commit_base_health(current_health: int) -> void:
	_base_health = clampi(current_health, 0, BASE_MAX_HEALTH)
	if is_instance_valid(_base_core):
		_base_core.set_health_ratio(float(_base_health) / float(BASE_MAX_HEALTH))
	base_health_changed.emit(_base_health, BASE_MAX_HEALTH)


@rpc("authority", "call_local", "reliable")
func _commit_player_state(
	peer_id: int,
	current_health: int,
	alive: bool,
	respawn_seconds: float
) -> void:
	if peer_id <= 0:
		return
	var safe_health: int = clampi(current_health, 0, PLAYER_MAX_HEALTH)
	_health_by_peer[peer_id] = safe_health
	_alive_by_peer[peer_id] = alive and safe_health > 0
	if respawn_seconds > 0.0:
		_respawn_remaining[peer_id] = respawn_seconds
	else:
		_respawn_remaining.erase(peer_id)
	var player: PlayerAvatar = _players.get(peer_id)
	if is_instance_valid(player):
		player.set_combat_state(safe_health, _alive_by_peer[peer_id])
	player_health_changed.emit(peer_id, safe_health, PLAYER_MAX_HEALTH)


@rpc("authority", "call_local", "reliable")
func _commit_player_respawn(peer_id: int, world_position: Vector2) -> void:
	if peer_id <= 0 or not world_position.is_finite():
		return
	_health_by_peer[peer_id] = PLAYER_MAX_HEALTH
	_alive_by_peer[peer_id] = true
	_respawn_remaining.erase(peer_id)
	var player: PlayerAvatar = _players.get(peer_id)
	if is_instance_valid(player):
		player.set_combat_state(PLAYER_MAX_HEALTH, true)
		player.apply_authoritative_state(world_position, Vector2.ZERO)
	player_respawned.emit(peer_id, world_position)


@rpc("authority", "call_local", "reliable")
func _commit_game_over(reason: StringName) -> void:
	if _game_over:
		return
	_game_over = true
	_respawn_remaining.clear()
	game_over.emit(reason)


@rpc("authority", "call_remote", "reliable")
func _receive_combat_snapshot(
	base_health: int,
	peer_ids: PackedInt32Array,
	health_values: PackedInt32Array,
	alive_values: PackedByteArray,
	respawn_values: PackedFloat32Array,
	game_over_active: bool
) -> void:
	if (
		peer_ids.size() != health_values.size()
		or peer_ids.size() != alive_values.size()
		or peer_ids.size() != respawn_values.size()
	):
		return
	_commit_base_health(base_health)
	for index: int in range(peer_ids.size()):
		_commit_player_state(
			peer_ids[index],
			health_values[index],
			alive_values[index] != 0,
			respawn_values[index]
		)
	if game_over_active:
		_commit_game_over(&"snapshot_game_over")


func _respawn_player_authoritative(peer_id: int) -> void:
	if _game_over or not _health_by_peer.has(peer_id):
		return
	var world_position: Vector2 = _respawn_position_for(peer_id)
	if is_instance_valid(_session):
		_session.teleport_peer_authoritative(peer_id, world_position)
		_session.set_peer_combat_active_authoritative(peer_id, true)
	_commit_player_respawn.rpc(peer_id, world_position)


func _respawn_position_for(peer_id: int) -> Vector2:
	var side: float = -1.0 if peer_id % 2 == 1 else 1.0
	return get_base_position() + Vector2(side * 92.0, RESPAWN_OFFSET_DISTANCE)


func _all_registered_players_dead() -> bool:
	if _alive_by_peer.is_empty():
		return false
	for alive: bool in _alive_by_peer.values():
		if alive:
			return false
	return true


func _trigger_game_over_authoritative(reason: StringName) -> void:
	if _game_over:
		return
	_commit_game_over.rpc(reason)


func _sorted_peer_ids() -> Array[int]:
	var peer_ids: Array[int] = _health_by_peer.keys()
	peer_ids.sort()
	return peer_ids


func _pack_player_health() -> PackedInt32Array:
	var values: PackedInt32Array = PackedInt32Array()
	for peer_id: int in _sorted_peer_ids():
		values.append(_health_by_peer[peer_id])
	return values


func _pack_player_alive() -> PackedByteArray:
	var values: PackedByteArray = PackedByteArray()
	for peer_id: int in _sorted_peer_ids():
		values.append(1 if _alive_by_peer.get(peer_id, false) else 0)
	return values


func _pack_respawn_remaining() -> PackedFloat32Array:
	var values: PackedFloat32Array = PackedFloat32Array()
	for peer_id: int in _sorted_peer_ids():
		values.append(_respawn_remaining.get(peer_id, 0.0))
	return values
