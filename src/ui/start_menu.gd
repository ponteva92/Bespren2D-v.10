class_name StartMenu
extends Control
## Character-first boot menu. Every launch path keeps the selected identity.

signal character_selected(character_id: StringName)

const GAME_SCENE: PackedScene = preload("res://scenes/game/game_world.tscn")
const MIN_TOUCH_TARGET: float = 44.0
const INTERIOR_HORIZONTAL_MARGIN: float = 8.0
const INTERIOR_VERTICAL_MARGIN: float = 4.0
const CARD_GAP: float = 14.0
const VERTICAL_GAP: float = 4.0

@onready var heikki_card: Button = %HeikkiCard
@onready var shane_card: Button = %ShaneCard
@onready var solo_button: Button = %SoloButton
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var address_edit: LineEdit = %AddressEdit
@onready var selection_label: Label = %SelectionLabel
@onready var heikki_selection_frame: Panel = get_node("HeikkiCard/SelectionFrame") as Panel
@onready var shane_selection_frame: Panel = get_node("ShaneCard/SelectionFrame") as Panel
@onready var heikki_active_chip: Panel = get_node("HeikkiCard/ActiveChip") as Panel
@onready var shane_active_chip: Panel = get_node("ShaneCard/ActiveChip") as Panel
@onready var heikki_signal_field: Control = get_node("HeikkiCard/SignalField") as Control
@onready var shane_signal_field: Control = get_node("ShaneCard/SignalField") as Control
@onready var header: Panel = get_node("Header") as Panel
@onready var header_kicker: Label = get_node("Header/Kicker") as Label
@onready var signal_state: Label = get_node("Header/SignalState") as Label
@onready var title_label: Label = get_node("Header/Title") as Label
@onready var subtitle_label: Label = get_node("Header/Subtitle") as Label
@onready var session_panel: Panel = get_node("SessionPanel") as Panel
@onready var session_label: Label = get_node("SessionPanel/Label") as Label
@onready var footer: Label = get_node("Footer") as Label
@onready var refuge_beam_left: Polygon2D = get_node("RefugeBeamLeft") as Polygon2D
@onready var refuge_beam_right: Polygon2D = get_node("RefugeBeamRight") as Polygon2D

static var _pending_session_notice: String = ""

var selected_character: StringName = &"heikki"
var _bounce_tween: Tween
var _signal_phase: float = 0.0
var _validation_safe_area_override: Rect2 = Rect2()
var _layout_safe_rect: Rect2 = Rect2()
var _layout_content_rect: Rect2 = Rect2()
var _header_rect: Rect2 = Rect2()
var _signal_center: Vector2 = Vector2.ZERO


func _ready() -> void:
	heikki_card.pressed.connect(select_character.bind(&"heikki"))
	shane_card.pressed.connect(select_character.bind(&"shane"))
	solo_button.pressed.connect(_launch.bind(CoopSession.SessionMode.SOLO))
	host_button.pressed.connect(_launch.bind(CoopSession.SessionMode.HOST))
	join_button.pressed.connect(_launch.bind(CoopSession.SessionMode.CLIENT))
	resized.connect(_on_menu_resized)
	await get_tree().process_frame
	_apply_responsive_layout()
	_show_pending_session_notice()
	select_character(selected_character)
	# Keyboard users begin on the survivor decision rather than a decorative node.
	heikki_card.grab_focus()


## Test-only override used by the focused layout gate to model a landscape
## camera/notch inset without changing the device's real safe-area settings.
static func queue_session_notice(message: String) -> void:
	_pending_session_notice = message


func get_session_notice_text() -> String:
	if not is_instance_valid(session_label):
		return ""
	return session_label.text


func _show_pending_session_notice() -> void:
	if _pending_session_notice.is_empty() or not is_instance_valid(session_label):
		return
	session_label.text = _pending_session_notice
	session_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pending_session_notice = ""


func set_safe_area_override_for_validation(safe_rect: Rect2) -> void:
	_validation_safe_area_override = safe_rect
	if is_node_ready():
		_apply_responsive_layout()


func clear_safe_area_override_for_validation() -> void:
	_validation_safe_area_override = Rect2()
	if is_node_ready():
		_apply_responsive_layout()


func get_layout_safe_rect() -> Rect2:
	return _layout_safe_rect


func get_layout_content_rect() -> Rect2:
	return _layout_content_rect


## These are deliberately untransformed layout rectangles: a selected card can
## be bouncing, but its touch ownership and safe-area placement must not shift.
func get_interactive_layout_rects() -> Dictionary:
	return {
		&"heikki_card": Rect2(heikki_card.position, heikki_card.size),
		&"shane_card": Rect2(shane_card.position, shane_card.size),
		&"address_edit": Rect2(address_edit.position, address_edit.size),
		&"solo_button": Rect2(solo_button.position, solo_button.size),
		&"host_button": Rect2(host_button.position, host_button.size),
		&"join_button": Rect2(join_button.position, join_button.size),
	}


func _on_menu_resized() -> void:
	if is_node_ready():
		_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	_layout_safe_rect = _resolve_safe_layout_rect()
	var horizontal_margin: float = minf(
		INTERIOR_HORIZONTAL_MARGIN,
		_layout_safe_rect.size.x * 0.025
	)
	var vertical_margin: float = minf(
		INTERIOR_VERTICAL_MARGIN,
		_layout_safe_rect.size.y * 0.02
	)
	_layout_content_rect = Rect2(
		_layout_safe_rect.position + Vector2(horizontal_margin, vertical_margin),
		_layout_safe_rect.size - Vector2(horizontal_margin * 2.0, vertical_margin * 2.0)
	)
	if _layout_content_rect.size.x <= 0.0 or _layout_content_rect.size.y <= 0.0:
		return

	var content_bottom: float = _layout_content_rect.position.y + _layout_content_rect.size.y
	var header_height: float = clampf(_layout_content_rect.size.y * 0.16, 37.0, 42.0)
	var footer_height: float = clampf(_layout_content_rect.size.y * 0.065, 16.0, 18.0)
	var session_height: float = clampf(_layout_content_rect.size.y * 0.215, 54.0, 56.0)
	var selection_height: float = clampf(_layout_content_rect.size.y * 0.07, 16.0, 18.0)

	_header_rect = Rect2(
		_layout_content_rect.position,
		Vector2(_layout_content_rect.size.x, header_height)
	)
	_set_control_rect(header, _header_rect)
	_layout_header_children()

	var footer_rect := Rect2(
		Vector2(_layout_content_rect.position.x, content_bottom - footer_height),
		Vector2(_layout_content_rect.size.x, footer_height)
	)
	_set_control_rect(footer, footer_rect)

	var session_rect := Rect2(
		Vector2(
			_layout_content_rect.position.x,
			footer_rect.position.y - VERTICAL_GAP - session_height
		),
		Vector2(_layout_content_rect.size.x, session_height)
	)
	_set_control_rect(session_panel, session_rect)
	_layout_session_controls(session_rect)

	var selection_rect := Rect2(
		Vector2(
			_layout_content_rect.position.x,
			session_rect.position.y - VERTICAL_GAP - selection_height
		),
		Vector2(_layout_content_rect.size.x, selection_height)
	)
	_set_control_rect(selection_label, selection_rect)

	var card_top: float = _header_rect.position.y + _header_rect.size.y + 6.0
	var card_bottom: float = selection_rect.position.y - VERTICAL_GAP
	var card_width: float = maxf(
		0.0,
		(_layout_content_rect.size.x - CARD_GAP) * 0.5
	)
	var card_height: float = maxf(0.0, card_bottom - card_top)
	var heikki_rect := Rect2(
		Vector2(_layout_content_rect.position.x, card_top),
		Vector2(card_width, card_height)
	)
	var shane_rect := Rect2(
		Vector2(_layout_content_rect.position.x + card_width + CARD_GAP, card_top),
		Vector2(card_width, card_height)
	)
	_set_control_rect(heikki_card, heikki_rect)
	_set_control_rect(shane_card, shane_rect)
	_layout_survivor_card(heikki_card)
	_layout_survivor_card(shane_card)

	_signal_center = Vector2(
		_layout_content_rect.get_center().x,
		card_top + card_height * 0.5
	)
	_layout_refuge_beams()
	queue_redraw()


func _resolve_safe_layout_rect() -> Rect2:
	var full_rect := Rect2(Vector2.ZERO, size)
	if (
		_validation_safe_area_override.size.x > 0.0
		and _validation_safe_area_override.size.y > 0.0
	):
		return full_rect.intersection(_validation_safe_area_override)

	var native_window_size: Vector2i = DisplayServer.window_get_size()
	var display_safe_area: Rect2i = DisplayServer.get_display_safe_area()
	var native_window_rect := Rect2i(Vector2i.ZERO, native_window_size)
	if (
		native_window_size.x <= 0
		or native_window_size.y <= 0
		or display_safe_area.size.x <= 0
		or display_safe_area.size.y <= 0
		or not native_window_rect.encloses(display_safe_area)
	):
		return full_rect

	var logical_per_native := Vector2(
		size.x / float(native_window_size.x),
		size.y / float(native_window_size.y)
	)
	var logical_safe_area := Rect2(
		Vector2(display_safe_area.position) * logical_per_native,
		Vector2(display_safe_area.size) * logical_per_native
	)
	var clipped_safe_area: Rect2 = full_rect.intersection(logical_safe_area)
	return clipped_safe_area if clipped_safe_area.has_area() else full_rect


func _layout_header_children() -> void:
	var inner_margin: float = 8.0
	var signal_width: float = minf(118.0, _header_rect.size.x * 0.28)
	var kicker_width: float = maxf(
		0.0,
		_header_rect.size.x - inner_margin * 2.0 - signal_width - 8.0
	)
	var subtitle_width: float = minf(180.0, _header_rect.size.x * 0.4)
	var title_width: float = maxf(
		0.0,
		_header_rect.size.x - inner_margin * 2.0 - subtitle_width - 8.0
	)
	_set_control_rect(header_kicker, Rect2(Vector2(inner_margin, 5.0), Vector2(kicker_width, 10.0)))
	_set_control_rect(
		signal_state,
		Rect2(
			Vector2(_header_rect.size.x - inner_margin - signal_width, 6.0),
			Vector2(signal_width, 10.0)
		)
	)
	_set_control_rect(title_label, Rect2(Vector2(inner_margin, 15.0), Vector2(title_width, 23.0)))
	_set_control_rect(
		subtitle_label,
		Rect2(
			Vector2(_header_rect.size.x - inner_margin - subtitle_width, 22.0),
			Vector2(subtitle_width, 13.0)
		)
	)


func _layout_survivor_card(card: Button) -> void:
	card.pivot_offset = card.size * 0.5
	var inner_margin: float = minf(8.0, card.size.x * 0.04)
	var portrait_height: float = minf(
		76.0,
		maxf(0.0, card.size.y - 31.0)
	)
	var portrait_width: float = minf(
		76.0,
		maxf(0.0, card.size.x * 0.36)
	)
	var portrait_rect := Rect2(
		Vector2(inner_margin, 23.0),
		Vector2(portrait_width, portrait_height)
	)
	var portrait_plate: Control = card.get_node("PortraitPlate") as Control
	var portrait: Control = card.get_node("Portrait") as Control
	var kicker: Label = card.get_node("Kicker") as Label
	var name_label: Label = card.get_node("Name") as Label
	var role: Label = card.get_node("Role") as Label
	var trait_label: Label = card.get_node("Trait") as Label
	var selection_frame: Control = card.get_node("SelectionFrame") as Control
	var active_chip: Control = card.get_node("ActiveChip") as Control
	var active_chip_text: Label = card.get_node("ActiveChip/Text") as Label
	var text_left: float = portrait_rect.position.x + portrait_rect.size.x + 10.0
	var text_width: float = maxf(0.0, card.size.x - text_left - inner_margin)

	_set_control_rect(portrait_plate, portrait_rect)
	_set_control_rect(
		portrait,
		Rect2(
			portrait_rect.position + Vector2(3.0, 3.0),
			Vector2(
				maxf(0.0, portrait_rect.size.x - 6.0),
				maxf(0.0, portrait_rect.size.y - 6.0)
			)
		)
	)
	_set_control_rect(kicker, Rect2(Vector2(text_left, 16.0), Vector2(text_width, 11.0)))
	_set_control_rect(name_label, Rect2(Vector2(text_left, 31.0), Vector2(text_width, 20.0)))
	_set_control_rect(role, Rect2(Vector2(text_left, 53.0), Vector2(text_width, 22.0)))
	_set_control_rect(
		trait_label,
		Rect2(Vector2(text_left, maxf(76.0, card.size.y - 30.0)), Vector2(text_width, 14.0))
	)
	_set_control_rect(selection_frame, Rect2(Vector2.ZERO, card.size))
	_set_control_rect(active_chip, Rect2(Vector2(inner_margin, 7.0), Vector2(55.0, 14.0)))
	_set_control_rect(active_chip_text, Rect2(Vector2.ZERO, active_chip.size))


func _layout_session_controls(session_rect: Rect2) -> void:
	_set_control_rect(
		session_label,
		Rect2(Vector2(8.0, 1.0), Vector2(maxf(0.0, session_rect.size.x - 16.0), 10.0))
	)
	var inner_margin: float = 6.0
	var control_gap: float = 8.0
	var controls_width: float = maxf(0.0, session_rect.size.x - inner_margin * 2.0)
	var widest_address: float = maxf(
		MIN_TOUCH_TARGET,
		controls_width - MIN_TOUCH_TARGET * 3.0 - control_gap * 3.0
	)
	var address_width: float = minf(
		clampf(controls_width * 0.33, 132.0, 154.0),
		widest_address
	)
	var action_width: float = maxf(
		0.0,
		(controls_width - address_width - control_gap * 3.0) / 3.0
	)
	var control_y: float = session_rect.position.y + session_rect.size.y - MIN_TOUCH_TARGET - 1.0
	var address_x: float = session_rect.position.x + inner_margin
	var solo_x: float = address_x + address_width + control_gap
	var host_x: float = solo_x + action_width + control_gap
	var join_x: float = host_x + action_width + control_gap
	_set_control_rect(address_edit, Rect2(Vector2(address_x, control_y), Vector2(address_width, MIN_TOUCH_TARGET)))
	_set_control_rect(solo_button, Rect2(Vector2(solo_x, control_y), Vector2(action_width, MIN_TOUCH_TARGET)))
	_set_control_rect(host_button, Rect2(Vector2(host_x, control_y), Vector2(action_width, MIN_TOUCH_TARGET)))
	_set_control_rect(join_button, Rect2(Vector2(join_x, control_y), Vector2(action_width, MIN_TOUCH_TARGET)))


func _layout_refuge_beams() -> void:
	var header_bottom: float = _header_rect.position.y + _header_rect.size.y
	refuge_beam_left.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x * 0.42, header_bottom + 2.0),
		Vector2(size.x * 0.17, size.y),
		Vector2(0.0, size.y),
	])
	refuge_beam_right.polygon = PackedVector2Array([
		Vector2(size.x, header_bottom + 2.0),
		Vector2(size.x * 0.58, header_bottom + 2.0),
		Vector2(size.x * 0.83, size.y),
		Vector2(size.x, size.y),
	])


func _set_control_rect(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size


func select_character(character_id: StringName) -> void:
	selected_character = &"shane" if character_id == &"shane" else &"heikki"
	var selected_card: Button = shane_card if selected_character == &"shane" else heikki_card
	heikki_card.modulate = Color.WHITE if selected_character == &"heikki" else Color(0.48, 0.54, 0.52, 1.0)
	shane_card.modulate = Color.WHITE if selected_character == &"shane" else Color(0.48, 0.54, 0.52, 1.0)
	heikki_selection_frame.visible = selected_character == &"heikki"
	shane_selection_frame.visible = selected_character == &"shane"
	heikki_active_chip.visible = selected_character == &"heikki"
	shane_active_chip.visible = selected_character == &"shane"
	# Kept as a narrow presentation call: the signal control is intentionally
	# not a gameplay or input type and never owns selection state itself.
	heikki_signal_field.call(&"set_active", selected_character == &"heikki")
	shane_signal_field.call(&"set_active", selected_character == &"shane")
	selection_label.text = "%s ACTIVE — SELECT A DEPLOYMENT CHANNEL" % String(selected_character).to_upper()
	_bounce_card(selected_card)
	character_selected.emit(selected_character)


func is_bounce_active() -> bool:
	return _bounce_tween != null and _bounce_tween.is_valid() and _bounce_tween.is_running()


func _bounce_card(card: Control) -> void:
	if _bounce_tween != null and _bounce_tween.is_valid():
		_bounce_tween.kill()
	heikki_card.scale = Vector2.ONE
	shane_card.scale = Vector2.ONE
	card.scale = Vector2(0.94, 0.94)
	_bounce_tween = create_tween()
	_bounce_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(card, "scale", Vector2(1.04, 1.04), 0.12)
	_bounce_tween.tween_property(card, "scale", Vector2.ONE, 0.16)


func _process(delta: float) -> void:
	# This remains deliberately restrained: one low-cost pulse gives the refuge
	# signal a living quality without competing with the launch controls.
	_signal_phase = fmod(_signal_phase + delta * 0.85, TAU)
	queue_redraw()


func _draw() -> void:
	var canvas_size: Vector2 = size
	if canvas_size.x <= 0.0 or canvas_size.y <= 0.0:
		return

	# Deep wilderness/navy base, then quiet terrain-grid marks. The high-contrast
	# amber is held for the player's chosen route and signal lock.
	draw_rect(Rect2(Vector2.ZERO, canvas_size), Color(0.008, 0.024, 0.025, 1.0), true)
	var grid_start_y: float = (
		_header_rect.position.y + _header_rect.size.y
		if _header_rect.has_area()
		else canvas_size.y * 0.16
	)
	draw_rect(
		Rect2(
			Vector2(0.0, grid_start_y),
			Vector2(canvas_size.x, maxf(0.0, canvas_size.y - grid_start_y))
		),
		Color(0.012, 0.044, 0.041, 0.92),
		true
	)

	var grid_color: Color = Color(0.15, 0.38, 0.33, 0.16)
	for x in range(0, int(canvas_size.x) + 1, 24):
		draw_line(Vector2(float(x), grid_start_y), Vector2(float(x), canvas_size.y), grid_color, 0.5, true)
	for y in range(int(grid_start_y + 13.0), int(canvas_size.y) + 1, 18):
		draw_line(Vector2(0.0, float(y)), Vector2(canvas_size.x, float(y)), grid_color, 0.5, true)

	var signal_center: Vector2 = (
		_signal_center
		if _signal_center != Vector2.ZERO
		else Vector2(canvas_size.x * 0.5, canvas_size.y * 0.41)
	)
	var pulse: float = 0.5 + 0.5 * sin(_signal_phase)
	for ring_index in range(3):
		var radius: float = 32.0 + float(ring_index) * 20.0 + pulse * 1.5
		var alpha: float = 0.12 - float(ring_index) * 0.025
		draw_arc(
			signal_center,
			radius,
			0.16,
			PI - 0.16,
			28,
			Color(0.88, 0.47, 0.12, alpha),
			0.7,
			true
		)

	draw_line(
		Vector2(signal_center.x - 22.0, signal_center.y),
		Vector2(signal_center.x + 22.0, signal_center.y),
		Color(0.4, 0.9, 0.71, 0.2 + pulse * 0.08),
		0.7,
		true
	)
	draw_circle(signal_center, 2.0 + pulse * 0.6, Color(1.0, 0.68, 0.23, 0.34))


func _launch(mode_value: int) -> void:
	var game_world: GameWorld = GAME_SCENE.instantiate() as GameWorld
	game_world.configure_launch(mode_value, selected_character, address_edit.text)
	var previous_scene: Node = get_tree().current_scene
	get_tree().root.add_child(game_world)
	get_tree().current_scene = game_world
	if previous_scene != null:
		previous_scene.queue_free()
