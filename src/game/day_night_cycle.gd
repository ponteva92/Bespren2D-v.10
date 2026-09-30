class_name DayNightCycle
extends Node
## Host-owned 450-second daytime clock and reliable warning/night commits.

signal clock_changed(seconds_remaining: int, night_number: int, is_night: bool)
signal warning_requested(seconds_remaining: int)
signal night_started(night_number: int)
signal day_started(night_number: int)

const DAY_DURATION_SECONDS: float = 450.0
const DAY_SPAWN_MODIFIER: float = 0.35
const NIGHT_SPAWN_MODIFIER: float = 1.35
const WARNING_SECONDS: Array[int] = [60, 45, 30, 15, 10, 5]
const CLOCK_BROADCAST_INTERVAL: float = 0.25

@export_node_path("CoopSession") var session_path: NodePath

var _session: CoopSession
var _seconds_remaining: float = DAY_DURATION_SECONDS
var _night_number: int = 1
var _is_night: bool = false
var _active: bool = false
var _clock_accumulator: float = 0.0
var _last_display_second: int = -1
var _warned: Dictionary[int, bool] = {}


func _ready() -> void:
	_session = get_node_or_null(session_path) as CoopSession
	set_process(true)


func _process(delta: float) -> void:
	if not _active or _is_night or not multiplayer.is_server():
		return
	_advance_daytime(maxf(delta, 0.0))


func initialize_for_session() -> void:
	if not multiplayer.is_server():
		return
	_seconds_remaining = DAY_DURATION_SECONDS
	_night_number = 1
	_is_night = false
	_active = true
	_clock_accumulator = 0.0
	_last_display_second = ceili(_seconds_remaining)
	_warned.clear()
	_commit_day_state.rpc(_last_display_second, _night_number)


func reset_for_session() -> void:
	_active = false
	_seconds_remaining = DAY_DURATION_SECONDS
	_night_number = 1
	_is_night = false
	_clock_accumulator = 0.0
	_last_display_second = -1
	_warned.clear()


func request_start_night() -> void:
	if multiplayer.is_server():
		_request_start_night()
	else:
		_request_start_night.rpc_id(CoopSession.AUTHORITY_PEER_ID)


func begin_next_day_authoritative() -> void:
	if not multiplayer.is_server():
		return
	_seconds_remaining = DAY_DURATION_SECONDS
	_night_number += 1
	_is_night = false
	_active = true
	_clock_accumulator = 0.0
	_last_display_second = ceili(_seconds_remaining)
	_warned.clear()
	_commit_day_state.rpc(_last_display_second, _night_number)


func sync_state_to_peer(peer_id: int) -> void:
	if not multiplayer.is_server() or peer_id <= CoopSession.AUTHORITY_PEER_ID:
		return
	_receive_cycle_snapshot.rpc_id(
		peer_id,
		ceili(_seconds_remaining),
		_night_number,
		_is_night
	)


func get_seconds_remaining() -> int:
	return maxi(ceili(_seconds_remaining), 0)


func get_night_number() -> int:
	return _night_number


func is_night() -> bool:
	return _is_night


func get_enemy_spawn_modifier() -> float:
	return NIGHT_SPAWN_MODIFIER if _is_night else DAY_SPAWN_MODIFIER


func advance_for_test(seconds: float) -> void:
	if multiplayer.is_server():
		_advance_daytime(maxf(seconds, 0.0))


@rpc("any_peer", "call_local", "reliable")
func _request_start_night() -> void:
	if not multiplayer.is_server() or _is_night:
		return
	var source_peer_id: int = multiplayer.get_remote_sender_id()
	if source_peer_id <= 0:
		source_peer_id = multiplayer.get_unique_id()
	if _session != null and not _session.is_peer_registered(source_peer_id):
		return
	_start_night_authoritative()


@rpc("authority", "call_local", "reliable")
func _commit_day_state(seconds_remaining: int, night_number: int) -> void:
	_seconds_remaining = clampf(float(seconds_remaining), 0.0, DAY_DURATION_SECONDS)
	_night_number = maxi(night_number, 1)
	_is_night = false
	_active = true
	_last_display_second = seconds_remaining
	clock_changed.emit(seconds_remaining, _night_number, false)
	day_started.emit(_night_number)


@rpc("authority", "call_local", "unreliable_ordered")
func _commit_clock(seconds_remaining: int, night_number: int) -> void:
	if _is_night or seconds_remaining < 0 or seconds_remaining > int(DAY_DURATION_SECONDS):
		return
	_seconds_remaining = float(seconds_remaining)
	_night_number = maxi(night_number, 1)
	_last_display_second = seconds_remaining
	clock_changed.emit(seconds_remaining, _night_number, false)


@rpc("authority", "call_local", "reliable")
func _commit_warning(seconds_remaining: int) -> void:
	if not WARNING_SECONDS.has(seconds_remaining) or _warned.has(seconds_remaining):
		return
	_warned[seconds_remaining] = true
	warning_requested.emit(seconds_remaining)


@rpc("authority", "call_local", "reliable")
func _commit_night(night_number: int) -> void:
	_night_number = maxi(night_number, 1)
	_seconds_remaining = 0.0
	_is_night = true
	_active = true
	clock_changed.emit(0, _night_number, true)
	night_started.emit(_night_number)


@rpc("authority", "call_remote", "reliable")
func _receive_cycle_snapshot(
	seconds_remaining: int,
	night_number: int,
	night_active: bool
) -> void:
	_night_number = maxi(night_number, 1)
	_is_night = night_active
	_active = true
	_seconds_remaining = 0.0 if night_active else clampf(
		float(seconds_remaining),
		0.0,
		DAY_DURATION_SECONDS
	)
	clock_changed.emit(get_seconds_remaining(), _night_number, _is_night)
	if _is_night:
		night_started.emit(_night_number)


func _advance_daytime(delta: float) -> void:
	if delta <= 0.0 or _is_night:
		return
	var previous_seconds: float = _seconds_remaining
	_seconds_remaining = maxf(_seconds_remaining - delta, 0.0)
	for warning_second: int in WARNING_SECONDS:
		if (
			previous_seconds > float(warning_second)
			and _seconds_remaining <= float(warning_second)
			and not _warned.has(warning_second)
		):
			_commit_warning.rpc(warning_second)
	_clock_accumulator += delta
	var display_second: int = ceili(_seconds_remaining)
	if (
		display_second != _last_display_second
		and _clock_accumulator >= CLOCK_BROADCAST_INTERVAL
	):
		_clock_accumulator = 0.0
		_commit_clock.rpc(display_second, _night_number)
	if _seconds_remaining <= 0.0:
		_start_night_authoritative()


func _start_night_authoritative() -> void:
	if _is_night:
		return
	_commit_night.rpc(_night_number)
