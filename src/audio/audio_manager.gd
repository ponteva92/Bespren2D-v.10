class_name AudioManager
extends Node2D
## Fixed mobile-safe world and mono UI voice pools with deterministic pitch variation.

signal cue_started(cue: StringName, world_position: Vector2)

const CUE_SHOOT: StringName = &"shoot"
const CUE_TOWER_SHOT: StringName = &"tower_shot"
const CUE_BUILD: StringName = &"build"
const CUE_HARVEST: StringName = &"harvest"
const CUE_UI: StringName = &"ui"
const CUE_METAL_THUD: StringName = &"metal_thud"
const CUE_ALERT: StringName = &"alert"

const LEGACY_SHOOT_STREAM: AudioStream = preload("res://assets/audio/shoot_laser.wav")
const BUILD_STREAM: AudioStream = preload("res://assets/audio/build_placement.ogg")
const HARVEST_STREAM: AudioStream = preload("res://assets/audio/harvest_collect.wav")
const UI_STREAM: AudioStream = preload("res://assets/audio/ui_click.ogg")
const MONO_POOL_SIZE: int = 8
const FIREARM_SAMPLE_RATE: int = 22050
const FIREARM_DURATION_SECONDS: float = 0.18
const PITCH_SEQUENCE: Array[float] = [
	0.92, 1.04, 0.97, 1.08, 0.95, 1.02, 0.90, 1.06,
]

@export_range(2, 12, 1) var world_pool_size: int = 6
@export_range(128.0, 4096.0, 1.0) var max_distance: float = 1800.0

@onready var world_players_root: Node2D = %WorldPlayers
@onready var mono_players_root: Node = %MonoPlayers
@onready var compatibility_ui_player: AudioStreamPlayer = %UIPlayer

var _world_players: Array[AudioStreamPlayer2D] = []
var _mono_players: Array[AudioStreamPlayer] = []
var _next_world_player_index: int = 0
var _next_mono_player_index: int = 0
var _pitch_index: int = 0
var _last_cue: StringName = &""
var _shoot_stream: AudioStream = LEGACY_SHOOT_STREAM


func _ready() -> void:
	_shoot_stream = _build_firearm_shot_stream()
	for player_index: int in range(world_pool_size):
		var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		player.name = "WorldSfx_%02d" % player_index
		player.max_distance = max_distance
		player.attenuation = 1.0
		world_players_root.add_child(player)
		_world_players.append(player)
	for player_index: int in range(MONO_POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "MonoSfx_%02d" % player_index
		mono_players_root.add_child(player)
		_mono_players.append(player)


func play_world_cue(cue: StringName, world_position: Vector2) -> bool:
	if _world_players.is_empty() or not world_position.is_finite():
		return false
	var stream: AudioStream = get_stream_for_cue(cue)
	if stream == null or cue == CUE_UI or cue == CUE_METAL_THUD or cue == CUE_ALERT:
		return false
	var player: AudioStreamPlayer2D = _world_players[_next_world_player_index]
	_next_world_player_index = (_next_world_player_index + 1) % _world_players.size()
	player.stop()
	player.stream = stream
	player.global_position = world_position
	player.volume_db = _volume_for_cue(cue)
	player.pitch_scale = _next_pitch(0.04)
	player.play()
	_last_cue = cue
	cue_started.emit(cue, world_position)
	return true


func play_ui_click() -> bool:
	return _play_mono(CUE_UI, UI_STREAM, -9.0, 0.035)


func play_ui_thud() -> bool:
	return _play_mono(CUE_METAL_THUD, BUILD_STREAM, -11.0, 0.08)


func play_alert() -> bool:
	return _play_mono(CUE_ALERT, BUILD_STREAM, -8.0, 0.06, 1.16)


func get_stream_for_cue(cue: StringName) -> AudioStream:
	match cue:
		CUE_SHOOT, CUE_TOWER_SHOT:
			return _shoot_stream
		CUE_BUILD, CUE_METAL_THUD, CUE_ALERT:
			return BUILD_STREAM
		CUE_HARVEST:
			return HARVEST_STREAM
		CUE_UI:
			return UI_STREAM
		_:
			return null


func has_cue(cue: StringName) -> bool:
	return get_stream_for_cue(cue) != null


func get_last_cue() -> StringName:
	return _last_cue


func get_world_player_count() -> int:
	return _world_players.size()


func get_mono_player_count() -> int:
	return _mono_players.size()


func stop_all() -> void:
	for player: AudioStreamPlayer2D in _world_players:
		player.stop()
		player.stream = null
	for player: AudioStreamPlayer in _mono_players:
		player.stop()
		player.stream = null
	compatibility_ui_player.stop()
	compatibility_ui_player.stream = null


func _exit_tree() -> void:
	stop_all()
	_world_players.clear()
	_mono_players.clear()


func _play_mono(
	cue: StringName,
	stream: AudioStream,
	volume_db: float,
	pitch_variation: float,
	base_pitch: float = 1.0
) -> bool:
	if stream == null or _mono_players.is_empty():
		return false
	var player: AudioStreamPlayer = _mono_players[_next_mono_player_index]
	_next_mono_player_index = (_next_mono_player_index + 1) % _mono_players.size()
	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = base_pitch * _next_pitch(pitch_variation)
	player.play()
	_last_cue = cue
	cue_started.emit(cue, Vector2.ZERO)
	return true


func _next_pitch(variation: float) -> float:
	var normalized: float = (PITCH_SEQUENCE[_pitch_index] - 1.0) / 0.10
	_pitch_index = (_pitch_index + 1) % PITCH_SEQUENCE.size()
	return 1.0 + normalized * variation


func _volume_for_cue(cue: StringName) -> float:
	match cue:
		CUE_SHOOT:
			return -4.0
		CUE_TOWER_SHOT:
			return -10.0
		CUE_BUILD:
			return -7.0
		CUE_HARVEST:
			return -6.0
		_:
			return -8.0


func _build_firearm_shot_stream() -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.resource_name = "kinetic_firearm_shot"
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = FIREARM_SAMPLE_RATE
	stream.stereo = false
	var frame_count: int = roundi(FIREARM_SAMPLE_RATE * FIREARM_DURATION_SECONDS)
	var pcm_data: PackedByteArray = PackedByteArray()
	pcm_data.resize(frame_count * 2)
	var noise_state: int = 0x1A2B3C4D
	for frame_index: int in range(frame_count):
		var time_seconds: float = float(frame_index) / float(FIREARM_SAMPLE_RATE)
		noise_state = (noise_state * 1103515245 + 12345) & 0x7fffffff
		var noise: float = float(noise_state) / 1073741823.5 - 1.0
		var muzzle_crack: float = noise * exp(-time_seconds * 360.0)
		var powder_burst: float = noise * exp(-time_seconds * 118.0)
		var low_body: float = sin(TAU * 118.0 * time_seconds) * exp(-time_seconds * 42.0)
		var mechanical_tail: float = noise * exp(-time_seconds * 24.0)
		var sample: float = clampf(
			muzzle_crack * 0.78
			+ powder_burst * 0.32
			+ low_body * 0.36
			+ mechanical_tail * 0.08,
			-1.0,
			1.0
		)
		var encoded_sample: int = clampi(roundi(sample * 32767.0), -32768, 32767)
		var byte_offset: int = frame_index * 2
		pcm_data[byte_offset] = encoded_sample & 0xff
		pcm_data[byte_offset + 1] = (encoded_sample >> 8) & 0xff
	stream.data = pcm_data
	return stream
