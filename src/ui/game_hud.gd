class_name GameHUD
extends CanvasLayer
## Layer-100 safe-area HUD, exploration minimap, and Tier-1 deck host.

signal command_requested(command: StringName)
signal minimap_ping_requested(world_position: Vector2)
signal structure_armed(structure_id: StringName)
signal build_deck_visibility_changed(open: bool)

const COMMAND_MAKE_BASE: StringName = &"make_base"
const COMMAND_BUILD: StringName = &"build"
const COMMAND_START_NIGHT: StringName = &"start_night"

const PANEL_SIZE: Vector2 = Vector2(148.0, 58.0)
const PANEL_MARGIN: Vector2 = Vector2(6.0, 6.0)
const MINIMAP_SIZE: Vector2 = Vector2(96.0, 72.0)
const WAVE_CHIP_SIZE: Vector2 = Vector2(208.0, 14.0)
const EVENT_CHIP_SIZE: Vector2 = Vector2(208.0, 14.0)
const EVENT_CHIP_GAP: float = 3.0
const WARNING_CHIP_DURATION_SECONDS: float = 2.4
const STATUS_SIZE: Vector2 = Vector2(236.0, 14.0)
const STATUS_HEIGHT: float = 14.0
const STATUS_GAP: float = 6.0
const STATUS_VISIBLE_SECONDS: float = 2.2
const CONTROL_BAND_HEIGHT: float = 106.0
const RESERVED_CONTROLS_TOP_Y: float = 164.0
const LEGACY_TOP_LEFT_AREA: float = 208.0 * 84.0
const RESOURCE_PICKUP_SIZE: Vector2 = Vector2(88.0, 16.0)
const RESOURCE_PICKUP_RISE: float = 16.0
const RESOURCE_PICKUP_DURATION: float = 0.74

@onready var command_panel: PanelContainer = %CommandPanel
@onready var wave_chip: PanelContainer = %WaveChip
@onready var wood_slot: PanelContainer = %WoodSlot
@onready var metal_slot: PanelContainer = %MetalSlot
@onready var tech_slot: PanelContainer = %TechSlot
@onready var wood_value: Label = %WoodValue
@onready var metal_value: Label = %MetalValue
@onready var tech_value: Label = %TechValue
@onready var night_indicator: Label = %NightIndicator
@onready var modifier_label: Label = %ModifierLabel
@onready var clock_label: Label = %ClockLabel
@onready var threat_chip: PanelContainer = %ThreatChip
@onready var threat_tag: Label = %ThreatTag
@onready var threat_label: Label = %ThreatLabel
@onready var start_night_button: Button = %StartNightButton
@onready var make_base_button: Button = %MakeBaseButton
@onready var build_button: Button = %BuildButton
@onready var status_panel: PanelContainer = %StatusPanel
@onready var status_label: Label = %StatusLabel
@onready var warning_panel: PanelContainer = %WarningPanel
@onready var boss_marquee_panel: PanelContainer = %BossMarqueePanel
@onready var boss_marquee_label: Label = %BossMarqueeLabel
@onready var minimap: TacticalMinimap = %TacticalMinimap
@onready var build_deck: TacticalBuildDeck = %TacticalBuildDeck
@onready var resource_pickup_layer: Control = %ResourcePickupLayer

var _wood_amount: int = 0
var _metal_amount: int = 0
var _tech_amount: int = 0
var _status_message: String = "Ready"
var _juice_rig: JuiceRig
var _audio_manager: AudioManager
var _mobile_controls: MobileControls
var _boss_marquee_tween: Tween
var _status_tween: Tween
var _event_chip_tween: Tween
var _boss_gate_active: bool = false
var _boss_chip_message: String = ""
var _warning_chip_active: bool = false
var _session_line: Label


func _ready() -> void:
	start_night_button.pressed.connect(_on_start_night_pressed)
	make_base_button.pressed.connect(_on_make_base_pressed)
	build_button.pressed.connect(_on_build_pressed)
	minimap.world_ping_requested.connect(_on_minimap_ping_requested)
	build_deck.structure_armed.connect(_on_structure_armed)
	build_deck.deck_closed.connect(_on_build_deck_closed)
	get_viewport().size_changed.connect(_update_layout)
	_session_line = Label.new()
	_session_line.name = &"SessionLine"
	_session_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_session_line.add_theme_font_size_override(&"font_size", 8)
	_session_line.add_theme_color_override(&"font_color", Color("c8d4cc"))
	_session_line.text = "SOLO"
	add_child(_session_line)
	for button: Button in get_command_buttons():
		_bind_command_plate(button)
	_apply_resource_amounts()
	_apply_status()
	warning_panel.visible = false
	boss_marquee_panel.visible = false
	threat_chip.visible = false
	set_day_night_state(450, 1, false)
	_update_layout()


func configure_feedback(
	juice_rig: JuiceRig,
	audio_manager: AudioManager,
	mobile_controls: MobileControls
) -> void:
	_juice_rig = juice_rig
	_audio_manager = audio_manager
	_mobile_controls = mobile_controls
	if is_instance_valid(_juice_rig) and is_instance_valid(_audio_manager):
		for button: Button in get_command_buttons():
			_juice_rig.bind_button(button, _audio_manager)
	build_deck.configure_feedback(_juice_rig, _audio_manager)
	build_deck.configure_touch_passthrough(_mobile_controls)


func set_resource_amounts(wood: int, metal: int, tech: int) -> void:
	var gained: Array[bool] = [
		wood > _wood_amount,
		metal > _metal_amount,
		tech > _tech_amount,
	]
	_wood_amount = maxi(wood, 0)
	_metal_amount = maxi(metal, 0)
	_tech_amount = maxi(tech, 0)
	if is_instance_valid(wood_value):
		_apply_resource_amounts()
		_pop_gained_slots(gained)
	if is_instance_valid(build_deck):
		build_deck.set_resource_pool(PackedInt32Array([
			_wood_amount,
			_metal_amount,
			_tech_amount,
		]))


func set_status(message: String) -> void:
	_status_message = message
	if is_instance_valid(status_label):
		_apply_status()


func set_session_line(text: String) -> void:
	if not is_instance_valid(_session_line):
		return
	_session_line.text = text


func get_session_line() -> String:
	if not is_instance_valid(_session_line):
		return ""
	return _session_line.text


static func placement_reason_text(reason: StringName) -> String:
	match reason:
		&"night_build_locked":
			return "NIGHT // BUILDING IS LOCKED"
		&"blocked_cell":
			return "BLOCKED GROUND"
		&"occupied_cell":
			return "ALREADY OCCUPIED"
		&"insufficient_resources":
			return "NOT ENOUGH RESOURCES"
		_:
			return "PLACEMENT REJECTED // %s" % String(reason).to_upper()


func show_resource_pickup(world_position: Vector2, resource_kind: int, amount: int) -> void:
	if (
		amount <= 0
		or not world_position.is_finite()
		or not is_instance_valid(resource_pickup_layer)
	):
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var screen_position: Vector2 = get_viewport().get_canvas_transform() * world_position
	if not screen_position.is_finite():
		return
	var pickup_label: Label = Label.new()
	pickup_label.name = &"ResourcePickup"
	pickup_label.text = "+ %d %s" % [amount, _resource_pickup_name(resource_kind)]
	pickup_label.custom_minimum_size = RESOURCE_PICKUP_SIZE
	pickup_label.size = RESOURCE_PICKUP_SIZE
	pickup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pickup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pickup_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pickup_label.add_theme_font_size_override(&"font_size", 9)
	pickup_label.add_theme_color_override(&"font_color", Color("f3e5bd"))
	pickup_label.add_theme_color_override(&"font_outline_color", Color("10130f"))
	pickup_label.add_theme_constant_override(&"outline_size", 2)
	var origin: Vector2 = screen_position - Vector2(RESOURCE_PICKUP_SIZE.x * 0.5, 34.0)
	pickup_label.position = Vector2(
		clampf(origin.x, 4.0, maxf(viewport_size.x - RESOURCE_PICKUP_SIZE.x - 4.0, 4.0)),
		clampf(origin.y, 4.0, maxf(viewport_size.y - RESOURCE_PICKUP_SIZE.y - 4.0, 4.0))
	)
	resource_pickup_layer.add_child(pickup_label)
	var pickup_tween: Tween = pickup_label.create_tween()
	pickup_tween.set_parallel(true)
	pickup_tween.tween_property(
		pickup_label,
		"position:y",
		pickup_label.position.y - RESOURCE_PICKUP_RISE,
		RESOURCE_PICKUP_DURATION
	)
	pickup_tween.tween_property(
		pickup_label,
		"modulate:a",
		0.0,
		RESOURCE_PICKUP_DURATION * 0.68
	).set_delay(RESOURCE_PICKUP_DURATION * 0.32)
	pickup_tween.chain().tween_callback(pickup_label.queue_free)


func set_day_night_state(seconds_remaining: int, night_number: int, is_night: bool) -> void:
	if not is_instance_valid(clock_label):
		return
	var safe_seconds: int = maxi(seconds_remaining, 0)
	var minutes: int = safe_seconds / 60
	var seconds: int = safe_seconds % 60
	night_indicator.text = "NIGHT %02d // %s" % [
		maxi(night_number, 1),
		"ACTIVE" if is_night else "DAYLIGHT",
	]
	modifier_label.text = "ZOMBIES +35%" if is_night else "ZOMBIES -65%"
	modifier_label.add_theme_color_override(
		&"font_color",
		Color("ff6b45") if is_night else Color("66e6ac")
	)
	clock_label.text = "WAVE LIVE" if is_night else "%02d:%02d TO NIGHT" % [minutes, seconds]
	start_night_button.disabled = is_night
	build_button.disabled = is_night
	_refresh_command_visual_state(start_night_button)
	_refresh_command_visual_state(build_button)


func set_wave_pacing(seconds_remaining: int, frozen: bool) -> void:
	if not is_instance_valid(clock_label):
		return
	if frozen:
		clock_label.text = "FROZEN // BOSS"
		clock_label.add_theme_color_override(&"font_color", Color("ff5b4d"))
		return
	var safe_seconds: int = maxi(seconds_remaining, 0)
	clock_label.text = "WAVE %02d:%02d" % [safe_seconds / 60, safe_seconds % 60]
	clock_label.add_theme_color_override(&"font_color", Color("eaf5f1"))


func set_boss_gate(active: bool, boss_name: StringName, bosses_remaining: int) -> void:
	if _boss_marquee_tween != null and _boss_marquee_tween.is_valid():
		_boss_marquee_tween.kill()
	boss_marquee_panel.visible = false
	boss_marquee_panel.scale = Vector2.ONE
	_boss_gate_active = active
	if not active:
		_boss_chip_message = ""
		if not _warning_chip_active:
			_hide_event_chip()
		return
	var readable_boss_name: String = String(boss_name).replace("_", " ").to_upper()
	_boss_chip_message = "%s // %d REMAIN" % [
		readable_boss_name,
		maxi(bosses_remaining, 1),
	]
	_warning_chip_active = false
	_present_event_chip(&"BOSS", _boss_chip_message, Color("ff6b58"), true)


func show_respawn_countdown(character_name: String, seconds_remaining: float) -> void:
	set_status("%s DOWN // BASE RESPAWN %.1fs" % [
		character_name.to_upper(),
		maxf(seconds_remaining, 0.0),
	])


func show_game_over(reason: StringName) -> void:
	if _boss_marquee_tween != null and _boss_marquee_tween.is_valid():
		_boss_marquee_tween.kill()
	boss_marquee_panel.visible = true
	boss_marquee_panel.scale = Vector2.ONE
	boss_marquee_label.text = "GAME OVER // %s" % String(reason).replace("_", " ").to_upper()
	_boss_gate_active = false
	_warning_chip_active = false
	_hide_event_chip()
	start_night_button.disabled = true
	make_base_button.disabled = true
	build_button.disabled = true
	for button: Button in get_command_buttons():
		_refresh_command_visual_state(button)


func show_warning(seconds_remaining: int) -> void:
	if seconds_remaining < 0:
		return
	warning_panel.visible = false
	if is_instance_valid(_audio_manager):
		_audio_manager.play_alert()
	if _boss_gate_active or build_deck.is_open():
		return
	_warning_chip_active = true
	_present_event_chip(
		&"ALERT",
		"NIGHTFALL // %02ds" % maxi(seconds_remaining, 0),
		Color("ffbd67"),
		false
	)


func open_build_deck() -> void:
	command_panel.visible = false
	minimap.visible = false
	wave_chip.visible = false
	status_panel.visible = false
	_suspend_event_chip_for_deck()
	if is_instance_valid(_mobile_controls):
		_mobile_controls.set_gameplay_input_enabled(false)
	build_deck.show_deck(PackedInt32Array([
		_wood_amount,
		_metal_amount,
		_tech_amount,
	]))
	build_deck_visibility_changed.emit(true)


func close_build_deck_immediately() -> void:
	if build_deck.is_open():
		build_deck.hide_immediately()
	else:
		_restore_dashboard()


func toggle_build_deck() -> void:
	if build_deck.is_open():
		close_build_deck_immediately()
	else:
		open_build_deck()


func is_build_deck_open() -> bool:
	return build_deck.is_open()


func set_minimap_roads(
	routes: Array[PackedVector2Array],
	dirt_flags: PackedByteArray
) -> void:
	minimap.set_road_network(routes, dirt_flags)


func set_minimap_state(
	base_position: Vector2,
	player_positions: PackedVector2Array,
	structure_positions: PackedVector2Array,
	resource_positions: PackedVector2Array,
	resource_kinds: PackedInt32Array
) -> void:
	minimap.set_tactical_state(
		base_position,
		player_positions,
		structure_positions,
		resource_positions,
		resource_kinds
	)


## `logical_insets` stores left/top in `position` and right/bottom in `size`.
static func calculate_panel_rect(viewport_size: Vector2, logical_insets: Rect2) -> Rect2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2()
	var left_inset: float = clampf(logical_insets.position.x, 0.0, viewport_size.x)
	var top_inset: float = clampf(logical_insets.position.y, 0.0, viewport_size.y)
	var right_inset: float = clampf(logical_insets.size.x, 0.0, viewport_size.x)
	var bottom_inset: float = clampf(logical_insets.size.y, 0.0, viewport_size.y)
	var position: Vector2 = Vector2(left_inset, top_inset) + PANEL_MARGIN
	var safe_end: Vector2 = viewport_size - Vector2(right_inset, bottom_inset) - PANEL_MARGIN
	return Rect2(position, Vector2(
		minf(PANEL_SIZE.x, maxf(safe_end.x - position.x, 0.0)),
		minf(PANEL_SIZE.y, maxf(safe_end.y - position.y, 0.0))
	))


static func calculate_minimap_rect(viewport_size: Vector2, logical_insets: Rect2) -> Rect2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2()
	var right_inset: float = clampf(logical_insets.size.x, 0.0, viewport_size.x)
	var top_inset: float = clampf(logical_insets.position.y, 0.0, viewport_size.y)
	var position: Vector2 = Vector2(
		viewport_size.x - right_inset - PANEL_MARGIN.x - MINIMAP_SIZE.x,
		top_inset + PANEL_MARGIN.y
	)
	return Rect2(position, MINIMAP_SIZE)


static func calculate_wave_chip_rect(
	viewport_size: Vector2,
	logical_insets: Rect2,
	panel_rect: Rect2,
	minimap_rect: Rect2
) -> Rect2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2()
	var left_bound: float = panel_rect.end.x + 4.0
	var right_bound: float = minimap_rect.position.x - 4.0
	var available_width: float = maxf(right_bound - left_bound, 0.0)
	var width: float = minf(WAVE_CHIP_SIZE.x, available_width)
	var centered_x: float = (viewport_size.x - width) * 0.5
	var position_x: float = clampf(centered_x, left_bound, maxf(right_bound - width, left_bound))
	return Rect2(
		Vector2(position_x, logical_insets.position.y + PANEL_MARGIN.y),
		Vector2(width, WAVE_CHIP_SIZE.y)
	)


static func calculate_status_rect(viewport_size: Vector2, logical_insets: Rect2) -> Rect2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2()
	var left_inset: float = clampf(logical_insets.position.x, 0.0, viewport_size.x)
	var right_inset: float = clampf(logical_insets.size.x, 0.0, viewport_size.x)
	var bottom_inset: float = clampf(logical_insets.size.y, 0.0, viewport_size.y)
	var safe_width: float = maxf(viewport_size.x - left_inset - right_inset, 0.0)
	var width: float = minf(STATUS_SIZE.x, safe_width)
	var control_band_top: float = viewport_size.y - bottom_inset - CONTROL_BAND_HEIGHT
	return Rect2(
		Vector2(
			left_inset + (safe_width - width) * 0.5,
			maxf(logical_insets.position.y + PANEL_MARGIN.y, control_band_top - STATUS_GAP - STATUS_HEIGHT)
		),
		Vector2(width, STATUS_HEIGHT)
	)


func get_panel() -> PanelContainer:
	return command_panel


func get_make_base_button() -> Button:
	return make_base_button


func get_build_button() -> Button:
	return build_button


func get_start_night_button() -> Button:
	return start_night_button


func get_wood_value_label() -> Label:
	return wood_value


func get_metal_value_label() -> Label:
	return metal_value


func get_tech_value_label() -> Label:
	return tech_value


func get_status_label() -> Label:
	return status_label


func get_status_panel() -> PanelContainer:
	return status_panel


func get_wave_chip() -> PanelContainer:
	return wave_chip


func get_threat_chip() -> PanelContainer:
	return threat_chip


func get_threat_tag() -> Label:
	return threat_tag


func get_threat_label() -> Label:
	return threat_label


func get_night_indicator() -> Label:
	return night_indicator


func get_modifier_label() -> Label:
	return modifier_label


func get_clock_label() -> Label:
	return clock_label


func get_boss_marquee_panel() -> PanelContainer:
	return boss_marquee_panel


func get_warning_panel() -> PanelContainer:
	return warning_panel


func get_boss_marquee_label() -> Label:
	return boss_marquee_label


func get_minimap() -> TacticalMinimap:
	return minimap


func get_build_deck() -> TacticalBuildDeck:
	return build_deck


func get_command_buttons() -> Array[Button]:
	return [make_base_button, build_button, start_night_button]


func get_resource_labels() -> Array[Label]:
	return [wood_value, metal_value, tech_value]


func get_resource_pickup_labels() -> Array[Label]:
	var labels: Array[Label] = []
	if not is_instance_valid(resource_pickup_layer):
		return labels
	for child: Node in resource_pickup_layer.get_children():
		var pickup_label: Label = child as Label
		if pickup_label != null:
			labels.append(pickup_label)
	return labels


func get_panel_for_test() -> PanelContainer:
	return get_panel()


func get_buttons_for_test() -> Array[Button]:
	return get_command_buttons()


func get_resource_labels_for_test() -> Array[Label]:
	return get_resource_labels()


func _update_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var logical_insets: Rect2 = _get_logical_safe_insets(viewport_size)
	var panel_rect: Rect2 = calculate_panel_rect(viewport_size, logical_insets)
	command_panel.position = panel_rect.position
	command_panel.size = panel_rect.size
	var minimap_rect: Rect2 = calculate_minimap_rect(viewport_size, logical_insets)
	minimap.position = minimap_rect.position
	minimap.size = minimap_rect.size
	var wave_rect: Rect2 = calculate_wave_chip_rect(
		viewport_size,
		logical_insets,
		panel_rect,
		minimap_rect
	)
	wave_chip.position = wave_rect.position
	wave_chip.size = wave_rect.size
	var event_rect: Rect2 = calculate_event_chip_rect(
		viewport_size,
		logical_insets,
		panel_rect,
		minimap_rect
	)
	threat_chip.position = event_rect.position
	threat_chip.size = event_rect.size
	var status_rect: Rect2 = calculate_status_rect(viewport_size, logical_insets)
	status_panel.position = status_rect.position
	status_panel.size = status_rect.size
	if is_instance_valid(_session_line):
		_session_line.position = Vector2(panel_rect.position.x, panel_rect.end.y + 1.0)
		_session_line.size = Vector2(maxf(panel_rect.size.x, 96.0), 12.0)


func _get_logical_safe_insets(viewport_size: Vector2) -> Rect2:
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	if (
		screen_size.x <= 0
		or screen_size.y <= 0
		or safe_area.size.x <= 0
		or safe_area.size.y <= 0
	):
		return Rect2()
	var scale_factor: Vector2 = Vector2(
		viewport_size.x / float(screen_size.x),
		viewport_size.y / float(screen_size.y)
	)
	var right_pixels: int = maxi(screen_size.x - safe_area.position.x - safe_area.size.x, 0)
	var bottom_pixels: int = maxi(screen_size.y - safe_area.position.y - safe_area.size.y, 0)
	return Rect2(
		Vector2(
			float(safe_area.position.x) * scale_factor.x,
			float(safe_area.position.y) * scale_factor.y
		),
		Vector2(float(right_pixels) * scale_factor.x, float(bottom_pixels) * scale_factor.y)
	)


## The dashboard carries the bare number. The word that used to sit beside it
## cost 42 of a 46 pixel slot at font 8, so an icon could not be added without
## dropping something: "WOOD 000" plus a 12 pixel icon needs 55 pixels in a 46
## pixel slot. The word is what goes, because it is the part that repeats
## information the icon and the hue already carry, and because CLAUDE.md 11
## asks for redundancy across surfaces rather than three times in one strip -
## the spelled-out word survives on the pickup toast, which is where a player
## learns which resource is which in the first place.
##
## The glyph itself stays at font 8. There is no room for a larger one: 44 of
## the panel's 58 pixels belong to the touch row, a font 8 line is exactly 12
## tall, and font 9 is 13. What the slot buys instead is a plate, right
## alignment and an icon, which is where the legibility actually comes from at
## this size.
func _apply_resource_amounts() -> void:
	wood_value.text = "%d" % _wood_amount
	metal_value.text = "%d" % _metal_amount
	tech_value.text = "%d" % _tech_amount


## Only the slot that actually went up. Popping all three on every commit
## would tell the player nothing about which resource he just picked up,
## which is the one thing this beat exists to say. Spending is deliberately
## silent here: the build deck already answers a purchase.
func _pop_gained_slots(gained: Array[bool]) -> void:
	if not is_instance_valid(_juice_rig):
		return
	var slots: Array[Control] = [wood_slot, metal_slot, tech_slot]
	for index: int in mini(gained.size(), slots.size()):
		if gained[index] and is_instance_valid(slots[index]):
			_juice_rig.pop(slots[index])


func _apply_status() -> void:
	status_label.text = _status_message
	if _status_tween != null and _status_tween.is_valid():
		_status_tween.kill()
	if _status_message.is_empty():
		status_panel.visible = false
		status_panel.modulate = Color.WHITE
		return
	status_panel.visible = true
	status_panel.modulate = Color.WHITE
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_tween = create_tween()
	_status_tween.tween_interval(STATUS_VISIBLE_SECONDS)
	_status_tween.tween_property(status_panel, "modulate:a", 0.0, 0.18)
	_status_tween.tween_callback(_hide_status_panel)


func _hide_status_panel() -> void:
	if not is_instance_valid(status_panel):
		return
	status_panel.visible = false
	status_panel.modulate = Color.WHITE


static func calculate_event_chip_rect(
	viewport_size: Vector2,
	logical_insets: Rect2,
	panel_rect: Rect2,
	minimap_rect: Rect2
) -> Rect2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2()
	var left_bound: float = panel_rect.end.x + 4.0
	var right_bound: float = minimap_rect.position.x - 4.0
	var available_width: float = maxf(right_bound - left_bound, 0.0)
	var width: float = minf(EVENT_CHIP_SIZE.x, available_width)
	var centered_x: float = (viewport_size.x - width) * 0.5
	var position_x: float = clampf(centered_x, left_bound, maxf(right_bound - width, left_bound))
	return Rect2(
		Vector2(
			position_x,
			logical_insets.position.y + PANEL_MARGIN.y + WAVE_CHIP_SIZE.y + EVENT_CHIP_GAP
		),
		Vector2(width, EVENT_CHIP_SIZE.y)
	)


func _present_event_chip(
	tag: StringName,
	message: String,
	accent_color: Color,
	persistent: bool
) -> void:
	if not is_instance_valid(threat_chip) or build_deck.is_open():
		return
	if _event_chip_tween != null and _event_chip_tween.is_valid():
		_event_chip_tween.kill()
	threat_tag.text = String(tag)
	threat_tag.add_theme_color_override(&"font_color", accent_color)
	threat_label.text = message
	threat_chip.visible = true
	threat_chip.modulate = Color(1.0, 1.0, 1.0, 0.0)
	threat_chip.scale = Vector2(0.96, 0.96)
	_event_chip_tween = threat_chip.create_tween()
	_event_chip_tween.set_parallel(true)
	_event_chip_tween.tween_property(threat_chip, "modulate:a", 1.0, 0.12)
	_event_chip_tween.tween_property(threat_chip, "scale", Vector2.ONE, 0.12)
	if persistent:
		return
	_event_chip_tween.chain().tween_interval(WARNING_CHIP_DURATION_SECONDS)
	_event_chip_tween.chain().tween_property(threat_chip, "modulate:a", 0.0, 0.16)
	_event_chip_tween.chain().tween_callback(_dismiss_warning_chip)


func _dismiss_warning_chip() -> void:
	if _boss_gate_active or not _warning_chip_active:
		return
	_warning_chip_active = false
	_hide_event_chip()


func _hide_event_chip() -> void:
	if _event_chip_tween != null and _event_chip_tween.is_valid():
		_event_chip_tween.kill()
	if not is_instance_valid(threat_chip):
		return
	threat_chip.visible = false
	threat_chip.modulate = Color.WHITE
	threat_chip.scale = Vector2.ONE


func _suspend_event_chip_for_deck() -> void:
	if _event_chip_tween != null and _event_chip_tween.is_valid():
		_event_chip_tween.kill()
	_warning_chip_active = false
	if is_instance_valid(threat_chip):
		threat_chip.visible = false
		threat_chip.modulate = Color.WHITE
		threat_chip.scale = Vector2.ONE


## How far the plate sinks in value while a command is held. JuiceRig owns the
## scale punch on the same event, so this is deliberately only a value change:
## two separate motions on one press read as a glitch rather than as weight.
const PRESSED_PLATE_DARKEN: float = 0.42


## The pressed plate is derived from the raised one rather than authored beside
## it, so the two can never drift apart when the dashboard is restyled - which
## is exactly what happened to the hand-written pressed style this replaced, an
## orange left in the scene that no node had referenced in a long time.
func _bind_command_plate(button: Button) -> void:
	var visual: Panel = button.get_node_or_null("Visual") as Panel
	if visual == null:
		return
	var raised: StyleBoxFlat = visual.get_theme_stylebox(&"panel") as StyleBoxFlat
	if raised == null:
		return
	var pressed: StyleBoxFlat = raised.duplicate() as StyleBoxFlat
	pressed.bg_color = raised.bg_color.darkened(PRESSED_PLATE_DARKEN)
	pressed.border_color = raised.border_color.darkened(PRESSED_PLATE_DARKEN * 0.5)
	# A held plate is not floating any more, so it gives up the shadow it casts
	# and the heavier bottom lip that made it look raised in the first place.
	pressed.shadow_size = 0
	pressed.border_width_bottom = raised.border_width_top
	var bevel: ColorRect = visual.get_node_or_null("Bevel") as ColorRect
	button.button_down.connect(_set_command_plate.bind(visual, bevel, pressed, false))
	button.button_up.connect(_set_command_plate.bind(visual, bevel, raised, true))


func _set_command_plate(
	visual: Panel,
	bevel: ColorRect,
	plate: StyleBoxFlat,
	lit: bool
) -> void:
	if not is_instance_valid(visual):
		return
	visual.add_theme_stylebox_override(&"panel", plate)
	if is_instance_valid(bevel):
		bevel.visible = lit


func _refresh_command_visual_state(button: Button) -> void:
	var visual: Control = button.get_node_or_null("Visual") as Control
	if visual == null:
		return
	visual.modulate = Color(0.48, 0.52, 0.5, 0.58) if button.disabled else Color.WHITE


func _restore_dashboard() -> void:
	command_panel.visible = true
	minimap.visible = true
	wave_chip.visible = true
	if _boss_gate_active and not _boss_chip_message.is_empty():
		_present_event_chip(&"BOSS", _boss_chip_message, Color("ff6b58"), true)
	if is_instance_valid(_mobile_controls):
		_mobile_controls.set_gameplay_input_enabled(true)
	_apply_status()
	build_deck_visibility_changed.emit(false)


func _resource_pickup_name(resource_kind: int) -> String:
	match resource_kind:
		0:
			return "WOOD"
		1:
			return "METAL"
		2:
			return "TECH"
		_:
			return "RESOURCE"


func _on_start_night_pressed() -> void:
	command_requested.emit(COMMAND_START_NIGHT)


func _on_make_base_pressed() -> void:
	command_requested.emit(COMMAND_MAKE_BASE)


func _on_build_pressed() -> void:
	command_requested.emit(COMMAND_BUILD)


func _on_minimap_ping_requested(world_position: Vector2) -> void:
	if is_instance_valid(_audio_manager):
		_audio_manager.play_ui_click()
	if is_instance_valid(_juice_rig):
		_juice_rig.pop(minimap)
	minimap_ping_requested.emit(world_position)


func _on_structure_armed(structure_id: StringName) -> void:
	structure_armed.emit(structure_id)


func _on_build_deck_closed() -> void:
	_restore_dashboard()
