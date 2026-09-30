class_name MobileControls
extends Control
## One index owner per touch: movement, Interact, and Fire never steal each other.

signal movement_changed(movement: Vector2)
signal action_pressed(action: StringName)

const NO_TOUCH: int = -1
const MOUSE_TOUCH: int = -2
const JOYSTICK_RADIUS: float = 38.0
const JOYSTICK_CAPTURE_RADIUS: float = 52.0
const JOYSTICK_DEADZONE: float = 8.0
const ACTION_TARGET_SIZE: float = 44.0
const ACTION_RADIUS: float = ACTION_TARGET_SIZE * 0.5

var movement_vector: Vector2 = Vector2.ZERO

var _movement_touch_index: int = NO_TOUCH
var _interact_touch_index: int = NO_TOUCH
var _fire_touch_index: int = NO_TOUCH
var _joystick_center: Vector2 = Vector2(58.0, 214.0)
var _joystick_knob: Vector2 = Vector2(58.0, 214.0)
var _interact_center: Vector2 = Vector2(398.0, 214.0)
var _fire_center: Vector2 = Vector2(452.0, 214.0)
var _gameplay_input_enabled: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)
	get_viewport().size_changed.connect(_update_layout)
	visibility_changed.connect(_on_visibility_changed)
	_update_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_update_layout()


func _input(event: InputEvent) -> void:
	if not visible or not _gameplay_input_enabled:
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		_handle_touch(touch.index, touch.pressed, touch.position)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		_handle_drag(drag.index, drag.position)
	elif event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_handle_touch(MOUSE_TOUCH, mouse_button.pressed, mouse_button.position)
	elif event is InputEventMouseMotion and _movement_touch_index == MOUSE_TOUCH:
		var mouse_motion: InputEventMouseMotion = event
		_handle_drag(MOUSE_TOUCH, mouse_motion.position)


func reset_touches() -> void:
	_movement_touch_index = NO_TOUCH
	_interact_touch_index = NO_TOUCH
	_fire_touch_index = NO_TOUCH
	_joystick_knob = _joystick_center
	_set_movement(Vector2.ZERO)
	queue_redraw()


func get_movement_touch_index() -> int:
	return _movement_touch_index


func get_interact_touch_index() -> int:
	return _interact_touch_index


func get_fire_touch_index() -> int:
	return _fire_touch_index


func get_joystick_center() -> Vector2:
	return _joystick_center


func get_action_center(action: StringName) -> Vector2:
	if action == &"interact":
		return _interact_center
	if action == &"fire":
		return _fire_center
	return Vector2.ZERO


func get_action_target_size() -> Vector2:
	return Vector2(ACTION_TARGET_SIZE, ACTION_TARGET_SIZE)


func set_gameplay_input_enabled(enabled: bool) -> void:
	if _gameplay_input_enabled == enabled:
		return
	_gameplay_input_enabled = enabled
	reset_touches()
	visible = enabled
	set_process_input(enabled)


func is_gameplay_input_enabled() -> bool:
	return _gameplay_input_enabled


func is_point_in_control_zone(screen_position: Vector2) -> bool:
	return (
		screen_position.distance_to(_joystick_center) <= JOYSTICK_CAPTURE_RADIUS
		or _action_rect(_interact_center).has_point(screen_position)
		or _action_rect(_fire_center).has_point(screen_position)
	)


func inject_touch_for_test(index: int, pressed: bool, position: Vector2) -> void:
	_handle_touch(index, pressed, position)


func inject_drag_for_test(index: int, position: Vector2) -> void:
	_handle_drag(index, position)


func _handle_touch(index: int, pressed: bool, position: Vector2) -> void:
	if pressed:
		if _try_claim_action(index, position):
			_mark_input_handled()
			return
		if (
			_movement_touch_index == NO_TOUCH
			and position.distance_to(_joystick_center) <= JOYSTICK_CAPTURE_RADIUS
		):
			_movement_touch_index = index
			_update_joystick(position)
			_mark_input_handled()
		return

	var released_owned_touch: bool = false
	if index == _movement_touch_index:
		_movement_touch_index = NO_TOUCH
		_joystick_knob = _joystick_center
		_set_movement(Vector2.ZERO)
		released_owned_touch = true
	if index == _interact_touch_index:
		_interact_touch_index = NO_TOUCH
		released_owned_touch = true
	if index == _fire_touch_index:
		_fire_touch_index = NO_TOUCH
		released_owned_touch = true
	if released_owned_touch:
		queue_redraw()
		_mark_input_handled()


func _handle_drag(index: int, position: Vector2) -> void:
	if index == _movement_touch_index:
		_update_joystick(position)
		_mark_input_handled()
	elif index == _interact_touch_index or index == _fire_touch_index:
		_mark_input_handled()


func _try_claim_action(index: int, position: Vector2) -> bool:
	if (
		_interact_touch_index == NO_TOUCH
		and _action_rect(_interact_center).has_point(position)
	):
		_interact_touch_index = index
		action_pressed.emit(&"interact")
		queue_redraw()
		return true
	if _fire_touch_index == NO_TOUCH and _action_rect(_fire_center).has_point(position):
		_fire_touch_index = index
		action_pressed.emit(&"fire")
		queue_redraw()
		return true
	return false


func _update_joystick(position: Vector2) -> void:
	var raw_offset: Vector2 = position - _joystick_center
	var clamped_offset: Vector2 = raw_offset.limit_length(JOYSTICK_RADIUS)
	_joystick_knob = _joystick_center + clamped_offset
	if raw_offset.length() <= JOYSTICK_DEADZONE:
		_set_movement(Vector2.ZERO)
	else:
		_set_movement(_quantize_eight_way(raw_offset))
	queue_redraw()


func _quantize_eight_way(raw_direction: Vector2) -> Vector2:
	if raw_direction.is_zero_approx():
		return Vector2.ZERO
	var sector_size: float = PI * 0.25
	var snapped_angle: float = roundf(raw_direction.angle() / sector_size) * sector_size
	return Vector2.from_angle(snapped_angle)


func _set_movement(value: Vector2) -> void:
	if movement_vector.is_equal_approx(value):
		return
	movement_vector = value
	movement_changed.emit(movement_vector)


func _update_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var safe_insets: Rect2 = _logical_safe_insets(viewport_size)
	var left_inset: float = safe_insets.position.x
	var top_inset: float = safe_insets.position.y
	var right_inset: float = safe_insets.size.x
	var bottom_inset: float = safe_insets.size.y
	var joystick_x: float = left_inset + JOYSTICK_RADIUS + 20.0
	_joystick_center = Vector2(joystick_x, viewport_size.y - bottom_inset - 54.0)
	_fire_center = Vector2(viewport_size.x - right_inset - 28.0, viewport_size.y - bottom_inset - 54.0)
	_interact_center = Vector2(_fire_center.x - 54.0, _fire_center.y)
	_joystick_center.y = maxf(_joystick_center.y, top_inset + JOYSTICK_CAPTURE_RADIUS)
	_fire_center.y = maxf(_fire_center.y, top_inset + ACTION_RADIUS)
	_interact_center.y = _fire_center.y
	if _movement_touch_index == NO_TOUCH:
		_joystick_knob = _joystick_center
	queue_redraw()


func _logical_safe_insets(viewport_size: Vector2) -> Rect2:
	var screen_size_i: Vector2i = DisplayServer.screen_get_size()
	var safe_area_i: Rect2i = DisplayServer.get_display_safe_area()
	if (
		screen_size_i.x <= 0
		or screen_size_i.y <= 0
		or safe_area_i.size.x <= 0
		or safe_area_i.size.y <= 0
	):
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var scale_factor: Vector2 = Vector2(
		viewport_size.x / float(screen_size_i.x),
		viewport_size.y / float(screen_size_i.y)
	)
	var right_pixels: int = maxi(
		screen_size_i.x - safe_area_i.position.x - safe_area_i.size.x,
		0
	)
	var bottom_pixels: int = maxi(
		screen_size_i.y - safe_area_i.position.y - safe_area_i.size.y,
		0
	)
	return Rect2(
		Vector2(
			float(safe_area_i.position.x) * scale_factor.x,
			float(safe_area_i.position.y) * scale_factor.y
		),
		Vector2(float(right_pixels) * scale_factor.x, float(bottom_pixels) * scale_factor.y)
	)


func _action_rect(center: Vector2) -> Rect2:
	return Rect2(
		center - Vector2(ACTION_RADIUS, ACTION_RADIUS),
		Vector2(ACTION_TARGET_SIZE, ACTION_TARGET_SIZE)
	)


func _mark_input_handled() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _on_visibility_changed() -> void:
	if not visible:
		reset_touches()


func _draw() -> void:
	draw_circle(_joystick_center, JOYSTICK_RADIUS, Color(0.02, 0.04, 0.04, 0.68))
	draw_arc(
		_joystick_center,
		JOYSTICK_RADIUS,
		0.0,
		TAU,
		32,
		Color(1.0, 0.72, 0.2, 0.85),
		2.0,
		true
	)
	draw_circle(_joystick_knob, 16.0, Color(1.0, 0.78, 0.3, 0.82))
	_draw_action_button(
		_interact_center,
		"USE",
		Color(0.15, 0.74, 0.67, 0.88),
		_interact_touch_index != NO_TOUCH
	)
	_draw_action_button(
		_fire_center,
		"FIRE",
		Color(0.94, 0.32, 0.12, 0.9),
		_fire_touch_index != NO_TOUCH
	)


func _draw_action_button(center: Vector2, label: String, color: Color, pressed: bool) -> void:
	var draw_color: Color = color.lightened(0.18) if pressed else color
	draw_circle(center, ACTION_RADIUS, Color(0.01, 0.02, 0.02, 0.78))
	draw_circle(center, ACTION_RADIUS - 2.0, draw_color)
	var text_width: float = ACTION_TARGET_SIZE
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-ACTION_RADIUS, 4.0),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		text_width,
		9,
		Color(0.02, 0.03, 0.03, 1.0)
	)
