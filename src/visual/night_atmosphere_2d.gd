class_name NightAtmosphere2D
extends Node
## Three-second readable blue-hour CanvasModulate transition plus local safety lighting.

signal transition_started(night_active: bool)
signal transition_completed(night_active: bool)

## Calibrated above 0.32 value so forest detail remains readable on dim mobile panels.
const SAPPHIRE_NIGHT_COLOR: Color = Color("91a3bd")
const DAY_COLOR: Color = Color.WHITE
const TRANSITION_SECONDS: float = 3.0

@export_node_path("CanvasModulate") var canvas_modulate_path: NodePath

var _canvas_modulate: CanvasModulate
var _night_active: bool = false
var _transition: Tween


func _ready() -> void:
	_canvas_modulate = get_node_or_null(canvas_modulate_path) as CanvasModulate
	if is_instance_valid(_canvas_modulate):
		_canvas_modulate.color = DAY_COLOR


func set_night_active(active: bool, immediate: bool = false) -> void:
	_night_active = active
	if _transition != null and _transition.is_valid():
		_transition.kill()
	_apply_world_lights()
	if not is_instance_valid(_canvas_modulate):
		return
	var target_color: Color = SAPPHIRE_NIGHT_COLOR if active else DAY_COLOR
	transition_started.emit(active)
	if immediate:
		_canvas_modulate.color = target_color
		transition_completed.emit(active)
		return
	_transition = create_tween()
	_transition.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transition.tween_property(_canvas_modulate, "color", target_color, TRANSITION_SECONDS)
	_transition.tween_callback(_on_transition_completed.bind(active))


func register_player(player: PlayerAvatar) -> void:
	if is_instance_valid(player):
		player.set_flashlight_enabled(_night_active)


func register_structure(structure: PlacedStructure2D) -> void:
	if is_instance_valid(structure):
		structure.set_security_light_enabled(_night_active)


func is_night_active() -> bool:
	return _night_active


func get_current_color() -> Color:
	return _canvas_modulate.color if is_instance_valid(_canvas_modulate) else DAY_COLOR


func _apply_world_lights() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"player_avatars"):
		var player: PlayerAvatar = node as PlayerAvatar
		if is_instance_valid(player):
			player.set_flashlight_enabled(_night_active)
	for node: Node in get_tree().get_nodes_in_group(&"tower_security_lights"):
		var structure: PlacedStructure2D = node as PlacedStructure2D
		if is_instance_valid(structure):
			structure.set_security_light_enabled(_night_active)


func _on_transition_completed(active: bool) -> void:
	transition_completed.emit(active)
