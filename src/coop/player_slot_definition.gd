class_name PlayerSlotDefinition
extends Resource
## Immutable-in-practice description of one local co-op input seat.

enum ControlScheme {
	TOUCH_AND_KEYBOARD,
	JOYPAD,
}

@export_range(1, 2, 1) var slot_id: int = 1
@export var display_name: StringName = &"Heikki"
@export var control_scheme: ControlScheme = ControlScheme.TOUCH_AND_KEYBOARD
@export var device_id: int = InputEvent.DEVICE_ID_KEYBOARD
@export var accent_color: Color = Color("ffd45a")


func _init(
	p_slot_id: int = 1,
	p_display_name: StringName = &"Heikki",
	p_control_scheme: ControlScheme = ControlScheme.TOUCH_AND_KEYBOARD,
	p_device_id: int = InputEvent.DEVICE_ID_KEYBOARD,
	p_accent_color: Color = Color("ffd45a")
) -> void:
	slot_id = p_slot_id
	display_name = p_display_name
	control_scheme = p_control_scheme
	device_id = p_device_id
	accent_color = p_accent_color


func is_valid() -> bool:
	if slot_id < 1 or slot_id > 2 or display_name.is_empty():
		return false
	if control_scheme == ControlScheme.JOYPAD and device_id < 0:
		return false
	return true


func accepts_event(event: InputEvent) -> bool:
	match control_scheme:
		ControlScheme.TOUCH_AND_KEYBOARD:
			return (
				event is InputEventScreenTouch
				or event is InputEventScreenDrag
				or event is InputEventKey
				or event is InputEventMouseButton
				or event is InputEventMouseMotion
			)
		ControlScheme.JOYPAD:
			return (
				(event is InputEventJoypadButton or event is InputEventJoypadMotion)
				and event.device == device_id
			)
	return false

