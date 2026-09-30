class_name TacticalBuildDeck
extends Control
## Centered mobile build popup grouped by Towers, Traps, and Utilities.

signal structure_armed(structure_id: StringName)
signal deck_closed

enum DeckCategory {
	TOWERS,
	TRAPS,
	UTILITIES,
}

const CARDS_PER_PAGE: int = 3
const SHEET_MAX_SIZE: Vector2 = Vector2(448.0, 204.0)
const SHEET_MARGIN: float = 6.0

@onready var menu_canvas: PanelContainer = %MenuCanvas
@onready var cards_grid: GridContainer = %CardsGrid
@onready var deck_close_button: Button = %DeckCloseButton
@onready var tower_tab: Button = %TowerTab
@onready var trap_tab: Button = %TrapTab
@onready var utility_tab: Button = %UtilityTab
@onready var page_previous: Button = %PagePrevious
@onready var page_indicator: Label = %PageIndicator
@onready var page_next: Button = %PageNext
@onready var wood_chip: Label = %WoodChip
@onready var metal_chip: Label = %MetalChip
@onready var tech_chip: Label = %TechChip
@onready var info_panel: PanelContainer = %InfoPanel
@onready var info_thumbnail: TextureRect = %InfoThumbnail
@onready var info_title: Label = %InfoTitle
@onready var info_role: Label = %InfoRole
@onready var info_mechanics: Label = %InfoMechanics
@onready var info_stats: Label = %InfoStats
@onready var info_cost: Label = %InfoCost
@onready var arm_button: Button = %ArmButton

var _card_buttons: Dictionary[StringName, Button] = {}
var _resource_pool: PackedInt32Array = PackedInt32Array([0, 0, 0])
var _selected_structure_id: StringName = &""
var _selected_by_category: Dictionary[int, StringName] = {}
var _page_by_category: Dictionary[int, int] = {}
var _juice_rig: JuiceRig
var _audio_manager: AudioManager
var _mobile_controls: MobileControls
var _current_category: int = DeckCategory.TOWERS
var _popup_tween: Tween
var _current_sheet_rect: Rect2 = Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck_close_button.pressed.connect(hide_immediately)
	tower_tab.pressed.connect(_on_category_pressed.bind(DeckCategory.TOWERS))
	trap_tab.pressed.connect(_on_category_pressed.bind(DeckCategory.TRAPS))
	utility_tab.pressed.connect(_on_category_pressed.bind(DeckCategory.UTILITIES))
	page_previous.pressed.connect(_change_page.bind(-1))
	page_next.pressed.connect(_change_page.bind(1))
	arm_button.pressed.connect(_on_arm_pressed)
	get_viewport().size_changed.connect(_update_layout)
	_build_cards()
	_update_resource_chips()
	_update_layout()
	hide_immediately(false)


func configure_feedback(juice_rig: JuiceRig, audio_manager: AudioManager) -> void:
	_juice_rig = juice_rig
	_audio_manager = audio_manager
	_bind_feedback_nodes()


func configure_touch_passthrough(mobile_controls: MobileControls) -> void:
	_mobile_controls = mobile_controls
	_update_layout()


func show_deck(pool: PackedInt32Array) -> void:
	set_resource_pool(pool)
	visible = true
	set_process_input(true)
	menu_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_category_has_selection()
	_refresh_page_visibility()
	_refresh_selected_info()
	_refresh_card_selection()
	_update_layout()
	_play_popup_intro()
	_bind_feedback_nodes()


func hide_immediately(emit_signal: bool = true) -> void:
	if _popup_tween != null and _popup_tween.is_valid():
		_popup_tween.kill()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_canvas.scale = Vector2.ONE
	menu_canvas.modulate = Color.WHITE
	info_panel.modulate = Color.WHITE
	set_process_input(false)
	if emit_signal:
		deck_closed.emit()


func set_resource_pool(pool: PackedInt32Array) -> void:
	if pool.size() != StructureDefinition.RESOURCE_KIND_COUNT:
		return
	_resource_pool = pool.duplicate()
	_update_resource_chips()
	_refresh_affordability()
	_refresh_selected_info()


func is_open() -> bool:
	return visible


func get_card_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for definition: StructureDefinition in StructureCatalog.get_all():
		var button: Button = _card_buttons.get(definition.structure_id)
		if button != null:
			buttons.append(button)
	return buttons


func get_selected_structure_id() -> StringName:
	return _selected_structure_id


func get_cards_per_page() -> int:
	return CARDS_PER_PAGE


func get_current_page() -> int:
	return _page_by_category.get(_current_category, 0)


func get_current_category() -> int:
	return _current_category


func get_category_tabs() -> Array[Button]:
	return [tower_tab, trap_tab, utility_tab]


func get_category_card_count(category: int) -> int:
	return _definitions_for_category(category).size()


func get_cards_grid() -> GridContainer:
	return cards_grid


func get_info_panel() -> PanelContainer:
	return info_panel


func get_arm_button() -> Button:
	return arm_button


func get_menu_canvas() -> PanelContainer:
	return menu_canvas


## Exposes the unanimated safe-area placement rect for focused layout gates.
## The visible canvas may be mid-intro-scale when a capture or test observes it.
func get_current_sheet_rect() -> Rect2:
	return _current_sheet_rect


func get_resource_chip_labels() -> Array[Label]:
	return [wood_chip, metal_chip, tech_chip]


func select_category_for_test(category: int) -> void:
	_on_category_pressed(category)


static func calculate_page_count(item_count: int) -> int:
	return maxi(ceili(float(maxi(item_count, 0)) / float(CARDS_PER_PAGE)), 1)


static func calculate_sheet_rect(
	viewport_size: Vector2,
	logical_insets: Rect2,
	_control_band_top: float
) -> Rect2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2()
	var left_inset: float = clampf(logical_insets.position.x, 0.0, viewport_size.x)
	var top_inset: float = clampf(logical_insets.position.y, 0.0, viewport_size.y)
	var right_inset: float = clampf(logical_insets.size.x, 0.0, viewport_size.x)
	var bottom_inset: float = clampf(logical_insets.size.y, 0.0, viewport_size.y)
	var safe_left: float = left_inset + SHEET_MARGIN
	var safe_right: float = viewport_size.x - right_inset - SHEET_MARGIN
	var safe_top: float = top_inset + SHEET_MARGIN
	var safe_bottom: float = viewport_size.y - bottom_inset - SHEET_MARGIN
	var available_size: Vector2 = Vector2(
		maxf(safe_right - safe_left, 0.0),
		maxf(safe_bottom - safe_top, 0.0)
	)
	var sheet_size: Vector2 = Vector2(
		minf(SHEET_MAX_SIZE.x, available_size.x),
		minf(SHEET_MAX_SIZE.y, available_size.y)
	)
	return Rect2(
		Vector2(
			safe_left + (available_size.x - sheet_size.x) * 0.5,
			safe_top + (available_size.y - sheet_size.y) * 0.5
		),
		sheet_size
	)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var pressed: bool = false
	var screen_position: Vector2 = Vector2.ZERO
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		pressed = mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed
		screen_position = mouse_button.position
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		pressed = touch.pressed
		screen_position = touch.position
	if not pressed:
		return
	if (
		is_instance_valid(_mobile_controls)
		and _mobile_controls.is_gameplay_input_enabled()
		and _mobile_controls.is_point_in_control_zone(screen_position)
	):
		return
	if menu_canvas.get_global_rect().has_point(screen_position):
		return
	hide_immediately()
	get_viewport().set_input_as_handled()


func _build_cards() -> void:
	for child: Node in cards_grid.get_children():
		child.queue_free()
	_card_buttons.clear()
	for definition: StructureDefinition in StructureCatalog.get_all():
		var button: Button = Button.new()
		button.name = StringName("Card_%s" % definition.structure_id)
		button.custom_minimum_size = Vector2(74.0, 74.0)
		button.text = ""
		button.tooltip_text = "%s\n%s" % [definition.role, definition.mechanics]
		button.set_meta(&"display_name", definition.display_name)
		button.set_meta(&"structure_id", definition.structure_id)
		button.set_meta(&"category", definition.category)
		button.focus_mode = Control.FOCUS_NONE
		button.clip_contents = true
		button.add_theme_stylebox_override(&"normal", _card_style(definition.accent, false))
		button.add_theme_stylebox_override(&"hover", _card_style(definition.accent.lightened(0.14), false))
		button.add_theme_stylebox_override(&"pressed", _card_style(definition.accent, true))
		button.pressed.connect(_on_card_pressed.bind(definition.structure_id))
		button.mouse_entered.connect(_on_card_focused.bind(definition.structure_id))
		cards_grid.add_child(button)
		_build_card_content(button, definition)
		_card_buttons[definition.structure_id] = button
	_refresh_page_visibility()
	_bind_feedback_nodes()


func _build_card_content(button: Button, definition: StructureDefinition) -> void:
	var content: VBoxContainer = VBoxContainer.new()
	content.name = &"Content"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 3.0
	content.offset_top = 2.0
	content.offset_right = -3.0
	content.offset_bottom = -2.0
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override(&"separation", 0)
	button.add_child(content)

	var thumbnail: TextureRect = TextureRect.new()
	thumbnail.name = &"Thumbnail"
	thumbnail.custom_minimum_size = Vector2(0.0, 46.0)
	thumbnail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	thumbnail.texture = definition.get_visual_texture()
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(thumbnail)

	var title: Label = Label.new()
	title.name = &"Title"
	title.text = _short_card_name(definition)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override(&"font_size", 7)
	title.add_theme_color_override(&"font_color", Color("edf4f0"))
	title.add_theme_color_override(&"font_outline_color", Color("080b09f2"))
	title.add_theme_constant_override(&"outline_size", 1)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)

	var cost: Label = Label.new()
	cost.name = &"Cost"
	cost.text = "%dW %dM %dT" % [
		definition.get_cost(0),
		definition.get_cost(1),
		definition.get_cost(2),
	]
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Cost is the last decision a player makes before committing a placement.
	# Give it the same 7px readable tier as the selected-card stats; the 74px
	# card still retains its 46px silhouette thumbnail and 44px touch target.
	cost.add_theme_font_size_override(&"font_size", 7)
	cost.add_theme_color_override(&"font_color", definition.accent.lightened(0.22))
	cost.add_theme_color_override(&"font_outline_color", Color("080b09f2"))
	cost.add_theme_constant_override(&"outline_size", 1)
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(cost)


func _on_category_pressed(category: int) -> void:
	if category < DeckCategory.TOWERS or category > DeckCategory.UTILITIES:
		return
	if not _selected_structure_id.is_empty():
		_selected_by_category[_current_category] = _selected_structure_id
	_current_category = category
	_ensure_category_has_selection()
	_refresh_page_visibility()
	_refresh_selected_info()
	_refresh_card_selection()


func _change_page(direction: int) -> void:
	var definitions: Array[StructureDefinition] = _definitions_for_category(_current_category)
	var page_count: int = calculate_page_count(definitions.size())
	var current_page: int = _page_by_category.get(_current_category, 0)
	var requested_page: int = clampi(current_page + direction, 0, page_count - 1)
	if requested_page == current_page:
		return
	_page_by_category[_current_category] = requested_page
	var first_index: int = requested_page * CARDS_PER_PAGE
	if first_index < definitions.size():
		_selected_structure_id = definitions[first_index].structure_id
		_selected_by_category[_current_category] = _selected_structure_id
	_refresh_page_visibility()
	_refresh_selected_info()
	_refresh_card_selection()
	_play_popup_intro()


func _refresh_page_visibility() -> void:
	var definitions: Array[StructureDefinition] = _definitions_for_category(_current_category)
	var page_count: int = calculate_page_count(definitions.size())
	var current_page: int = clampi(_page_by_category.get(_current_category, 0), 0, page_count - 1)
	_page_by_category[_current_category] = current_page
	var page_start: int = current_page * CARDS_PER_PAGE
	var page_end: int = mini(page_start + CARDS_PER_PAGE, definitions.size())
	for button: Button in _card_buttons.values():
		button.visible = false
	for index: int in range(page_start, page_end):
		var button: Button = _card_buttons.get(definitions[index].structure_id)
		if button != null:
			button.visible = true
	page_indicator.text = "%d/%d" % [current_page + 1, page_count]
	page_previous.disabled = current_page <= 0
	page_next.disabled = current_page >= page_count - 1
	_refresh_category_tabs()


func _ensure_category_has_selection() -> void:
	var definitions: Array[StructureDefinition] = _definitions_for_category(_current_category)
	if definitions.is_empty():
		_selected_structure_id = &""
		info_panel.visible = false
		return
	var remembered: StringName = _selected_by_category.get(_current_category, &"")
	var remembered_definition: StructureDefinition = StructureCatalog.get_definition(remembered)
	if remembered_definition == null or not _definition_matches_category(
		remembered_definition,
		_current_category
	):
		remembered = definitions[0].structure_id
	_selected_structure_id = remembered
	_selected_by_category[_current_category] = remembered
	var selected_index: int = 0
	for index: int in range(definitions.size()):
		if definitions[index].structure_id == remembered:
			selected_index = index
			break
	_page_by_category[_current_category] = floori(
		float(selected_index) / float(CARDS_PER_PAGE)
	)
	info_panel.visible = true


func _definitions_for_category(category: int) -> Array[StructureDefinition]:
	var grouped: Array[StructureDefinition] = []
	for definition: StructureDefinition in StructureCatalog.get_all():
		if _definition_matches_category(definition, category):
			grouped.append(definition)
	return grouped


func _definition_matches_category(definition: StructureDefinition, category: int) -> bool:
	match category:
		DeckCategory.TOWERS:
			return definition.is_tower()
		DeckCategory.TRAPS:
			return definition.is_trap()
		DeckCategory.UTILITIES:
			return definition.is_utility()
	return false


func _play_popup_intro() -> void:
	if _popup_tween != null and _popup_tween.is_valid():
		_popup_tween.kill()
	menu_canvas.pivot_offset = menu_canvas.size * 0.5
	menu_canvas.scale = Vector2.ONE * 0.94
	menu_canvas.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_popup_tween = create_tween().set_parallel(true)
	_popup_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_popup_tween.tween_property(menu_canvas, "scale", Vector2.ONE, 0.18)
	_popup_tween.tween_property(menu_canvas, "modulate:a", 1.0, 0.12)


func _on_card_pressed(structure_id: StringName) -> void:
	_selected_structure_id = structure_id
	_selected_by_category[_current_category] = structure_id
	info_panel.visible = true
	_refresh_selected_info()
	_refresh_card_selection()


func _on_card_focused(structure_id: StringName) -> void:
	if not visible:
		return
	_on_card_pressed(structure_id)


func _on_arm_pressed() -> void:
	if _selected_structure_id.is_empty():
		return
	var definition: StructureDefinition = StructureCatalog.get_definition(_selected_structure_id)
	if definition == null or not _can_afford(definition):
		return
	var armed_id: StringName = _selected_structure_id
	hide_immediately()
	structure_armed.emit(armed_id)


func _refresh_affordability() -> void:
	for definition: StructureDefinition in StructureCatalog.get_all():
		var button: Button = _card_buttons.get(definition.structure_id)
		if button == null:
			continue
		var affordable: bool = _can_afford(definition)
		button.modulate = Color.WHITE if affordable else Color(0.43, 0.46, 0.45, 0.72)
		button.set_meta(&"affordable", affordable)


func _refresh_selected_info() -> void:
	if not is_instance_valid(info_panel) or _selected_structure_id.is_empty():
		return
	var definition: StructureDefinition = StructureCatalog.get_definition(_selected_structure_id)
	if definition == null:
		info_panel.visible = false
		return
	info_panel.visible = true
	info_thumbnail.texture = definition.get_visual_texture()
	info_title.text = definition.display_name.to_upper()
	info_title.add_theme_color_override(&"font_color", definition.accent.lightened(0.14))
	info_role.text = definition.role.to_upper()
	info_mechanics.text = definition.mechanics
	info_stats.text = definition.stats_text
	info_cost.text = "%dW | %dM | %dT" % [
		definition.get_cost(0),
		definition.get_cost(1),
		definition.get_cost(2),
	]
	var affordable: bool = _can_afford(definition)
	arm_button.disabled = not affordable
	arm_button.text = "PLACE" if affordable else "LOCKED"
	arm_button.tooltip_text = (
		"Choose a clear location for %s." % definition.display_name
		if affordable
		else _missing_resource_tooltip(definition)
	)


func _refresh_card_selection() -> void:
	for definition: StructureDefinition in StructureCatalog.get_all():
		var button: Button = _card_buttons.get(definition.structure_id)
		if button == null:
			continue
		var selected: bool = definition.structure_id == _selected_structure_id
		button.scale = Vector2.ONE * (1.04 if selected else 1.0)
		button.pivot_offset = button.size * 0.5
		button.add_theme_stylebox_override(
			&"normal",
			_card_style(definition.accent.lightened(0.08), selected)
		)
	_refresh_category_tabs()


func _refresh_category_tabs() -> void:
	var tabs: Array[Button] = get_category_tabs()
	for category: int in range(tabs.size()):
		var selected: bool = category == _current_category
		tabs[category].set_pressed_no_signal(selected)
		tabs[category].modulate = Color.WHITE if selected else Color(0.68, 0.72, 0.70, 0.86)


func _update_resource_chips() -> void:
	if not is_instance_valid(wood_chip):
		return
	wood_chip.text = "W%03d" % _resource_pool[0]
	metal_chip.text = "M%03d" % _resource_pool[1]
	tech_chip.text = "T%03d" % _resource_pool[2]


func _can_afford(definition: StructureDefinition) -> bool:
	for resource_kind: int in range(StructureDefinition.RESOURCE_KIND_COUNT):
		if _resource_pool[resource_kind] < definition.get_cost(resource_kind):
			return false
	return true


func _missing_resource_tooltip(definition: StructureDefinition) -> String:
	var deficits: PackedStringArray = PackedStringArray()
	var names: PackedStringArray = PackedStringArray(["Wood", "Metal", "Tech"])
	for resource_kind: int in range(StructureDefinition.RESOURCE_KIND_COUNT):
		var missing: int = maxi(definition.get_cost(resource_kind) - _resource_pool[resource_kind], 0)
		if missing > 0:
			deficits.append("%s +%d" % [names[resource_kind], missing])
	return "Needs %s" % ", ".join(deficits)


func _bind_feedback_nodes() -> void:
	if not is_instance_valid(_juice_rig) or not is_instance_valid(_audio_manager):
		return
	_juice_rig.bind_button(deck_close_button, _audio_manager)
	_juice_rig.bind_button(tower_tab, _audio_manager)
	_juice_rig.bind_button(trap_tab, _audio_manager)
	_juice_rig.bind_button(utility_tab, _audio_manager)
	_juice_rig.bind_button(page_previous, _audio_manager)
	_juice_rig.bind_button(page_next, _audio_manager)
	_juice_rig.bind_button(arm_button, _audio_manager)
	for button: Button in _card_buttons.values():
		_juice_rig.bind_button(button, _audio_manager)


func _card_style(color: Color, pressed: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color.darkened(0.74) if not pressed else color.darkened(0.40)
	style.border_color = color.darkened(0.04) if not pressed else color.lightened(0.22)
	style.set_border_width_all(1 if not pressed else 2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 3.0
	style.content_margin_right = 3.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style


func _short_card_name(definition: StructureDefinition) -> String:
	return definition.display_name.trim_prefix("T1 ").to_upper()


func _update_layout() -> void:
	if not is_instance_valid(menu_canvas):
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var logical_insets: Rect2 = _get_logical_safe_insets(viewport_size)
	var sheet_rect: Rect2 = calculate_sheet_rect(
		viewport_size,
		logical_insets,
		viewport_size.y
	)
	_current_sheet_rect = sheet_rect
	menu_canvas.position = sheet_rect.position
	menu_canvas.size = sheet_rect.size


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
