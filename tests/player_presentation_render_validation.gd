extends Node2D
## GPU 480x270 review capture for the live, authority-driven survivor adapter.
##
## This is intentionally not a promotional sheet of raw source PNGs.  It
## instantiates the same NetworkPlayer/PlayerAvatar path used by GameWorld and
## presents it at the 0.38 gameplay-camera scale, so a review can catch a
## binding, pivot, heading, or value-readability regression before a hero bake
## is treated as production ready. A physical window may use an integer multiple
## of the logical canvas; native dimensions are validated and recorded first.

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/network_player.tscn")
const DAY_OUTPUT_PATH: String = "res://artifacts/player_presentation_live_day.png"
const NIGHT_OUTPUT_PATH: String = "res://artifacts/player_presentation_live_night.png"
const METADATA_PATH: String = "res://artifacts/player_presentation_render_validation.json"
const GAMEPLAY_PRESENTATION_SCALE: float = 0.38
const LOGICAL_CAPTURE_SIZE: Vector2i = Vector2i(480, 270)

@onready var lighting: CanvasModulate = %Lighting

var _players: Array[PlayerAvatar] = []
var _native_capture_size: Vector2i = Vector2i.ZERO
var _native_capture_scale: int = 0


func _ready() -> void:
	var idle_player: PlayerAvatar = _spawn_player(&"heikki", Vector2(72.0, 111.0))
	var running_player: PlayerAvatar = _spawn_player(&"heikki", Vector2(192.0, 111.0))
	var firing_player: PlayerAvatar = _spawn_player(&"shane", Vector2(312.0, 111.0))
	var downed_player: PlayerAvatar = _spawn_player(&"shane", Vector2(432.0, 111.0))
	if idle_player == null or running_player == null or firing_player == null or downed_player == null:
		_fail("could not instantiate all four PlayerAvatar review subjects")
		return
	await get_tree().process_frame
	idle_player.apply_authoritative_state(idle_player.global_position, Vector2.ZERO)
	running_player.apply_authoritative_state(running_player.global_position + Vector2(48.0, 0.0), Vector2.RIGHT)
	firing_player.set_aim_direction(Vector2.UP, true)
	firing_player.play_interaction_feedback(&"fire")
	downed_player.set_aim_direction(Vector2.LEFT, true)
	downed_player.set_combat_state(0, false)
	await get_tree().physics_frame
	await get_tree().process_frame
	if not _validate_live_states(idle_player, running_player, firing_player, downed_player):
		return
	var day_captured: bool = await _capture(DAY_OUTPUT_PATH)
	if not day_captured:
		return
	lighting.color = NightAtmosphere2D.SAPPHIRE_NIGHT_COLOR
	await get_tree().process_frame
	var night_captured: bool = await _capture(NIGHT_OUTPUT_PATH)
	if not night_captured:
		return
	lighting.color = Color.WHITE
	_store_metadata()
	print(
		"PLAYER PRESENTATION RENDER OK | method=%s | driver=%s | subjects=%d"
		% [
			RenderingServer.get_current_rendering_method(),
			RenderingServer.get_current_rendering_driver_name(),
			_players.size(),
		]
	)
	get_tree().quit(0)


func _spawn_player(character_id: StringName, spawn_position: Vector2) -> PlayerAvatar:
	var player: PlayerAvatar = PLAYER_SCENE.instantiate() as PlayerAvatar
	if player == null:
		return null
	player.configure(_players.size() + 1, character_id, spawn_position, false)
	player.scale = Vector2.ONE * GAMEPLAY_PRESENTATION_SCALE
	add_child(player)
	var name_label: Label = player.get_node_or_null(^"NameLabel") as Label
	var health_label: Label = player.get_node_or_null(^"HealthLabel") as Label
	if name_label != null:
		name_label.visible = false
	if health_label != null:
		health_label.visible = false
	_players.append(player)
	return player


func _validate_live_states(
	idle_player: PlayerAvatar,
	running_player: PlayerAvatar,
	firing_player: PlayerAvatar,
	downed_player: PlayerAvatar
) -> bool:
	var all_baked: bool = true
	for player: PlayerAvatar in _players:
		all_baked = all_baked and player.uses_baked_actor_presentation()
	if not all_baked:
		_fail("live review subjects did not bind baked actor presentations")
		return false
	var correct_clips: bool = (
		idle_player.get_presentation_animation()
		== ActorFacing.animation_name(&"idle", idle_player.get_presentation_facing_row())
		and running_player.get_presentation_animation()
		== ActorFacing.animation_name(&"run", running_player.get_presentation_facing_row())
		and firing_player.get_presentation_animation()
		== ActorFacing.animation_name(&"shoot", firing_player.get_presentation_facing_row())
		and downed_player.get_presentation_animation()
		== ActorFacing.animation_name(&"death", downed_player.get_presentation_facing_row())
	)
	if not correct_clips:
		_fail("live review subjects did not reach idle/run/shoot/death clips")
		return false
	return true


func _capture(output_path: String) -> bool:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return _fail("empty viewport for %s" % output_path)
	_native_capture_size = image.get_size()
	if (
		_native_capture_size.x <= 0
		or _native_capture_size.y <= 0
		or _native_capture_size.x % LOGICAL_CAPTURE_SIZE.x != 0
		or _native_capture_size.y % LOGICAL_CAPTURE_SIZE.y != 0
	):
		return _fail(
			"native viewport for %s is %s; expected an integer scale of %s"
			% [output_path, _native_capture_size, LOGICAL_CAPTURE_SIZE]
		)
	var horizontal_scale: int = int(
		float(_native_capture_size.x) / float(LOGICAL_CAPTURE_SIZE.x)
	)
	var vertical_scale: int = int(
		float(_native_capture_size.y) / float(LOGICAL_CAPTURE_SIZE.y)
	)
	if horizontal_scale != vertical_scale:
		return _fail(
			"native viewport for %s is non-uniform (%dx%d) over %s"
			% [output_path, horizontal_scale, vertical_scale, LOGICAL_CAPTURE_SIZE]
		)
	_native_capture_scale = horizontal_scale
	if _native_capture_size != LOGICAL_CAPTURE_SIZE:
		image.resize(LOGICAL_CAPTURE_SIZE.x, LOGICAL_CAPTURE_SIZE.y, Image.INTERPOLATE_LANCZOS)
	if image.get_size() != LOGICAL_CAPTURE_SIZE:
		return _fail("logical review image for %s is not %s" % [output_path, LOGICAL_CAPTURE_SIZE])
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		return _fail("could not save %s (%s)" % [output_path, error_string(save_error)])
	return true


func _store_metadata() -> void:
	var metadata: Dictionary = {
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"logical_size": [480, 270],
		"native_capture_size": [_native_capture_size.x, _native_capture_size.y],
		"native_capture_scale": _native_capture_scale,
		"gameplay_presentation_scale": GAMEPLAY_PRESENTATION_SCALE,
		"subjects": [
			{"character": "heikki", "state": "idle", "output": DAY_OUTPUT_PATH},
			{"character": "heikki", "state": "run_right", "output": DAY_OUTPUT_PATH},
			{"character": "shane", "state": "shoot_up", "output": DAY_OUTPUT_PATH},
			{"character": "shane", "state": "death_left", "output": DAY_OUTPUT_PATH},
		],
		"outputs": [DAY_OUTPUT_PATH, NIGHT_OUTPUT_PATH],
	}
	var metadata_file: FileAccess = FileAccess.open(METADATA_PATH, FileAccess.WRITE)
	if metadata_file == null:
		_fail("could not write metadata")
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()


func _fail(reason: String) -> bool:
	push_error("PLAYER PRESENTATION RENDER FAILED: %s" % reason)
	get_tree().quit(1)
	return false
