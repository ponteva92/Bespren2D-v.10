extends SceneTree
## Deterministic mobile-layout gate for StartMenu.
##
## This runs headlessly: it validates the same live scene at the project
## 480x270 logical resolution and again with a representative landscape
## camera/notch inset. GPU image review remains in start_menu_render_validation.

const LOGICAL_VIEWPORT: Vector2 = Vector2(480.0, 270.0)
const SYNTHETIC_SAFE_RECT: Rect2 = Rect2(16.0, 8.0, 448.0, 254.0)
const MIN_TOUCH_TARGET: float = 44.0

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var menu_scene: PackedScene = load("res://scenes/ui/StartMenu.tscn") as PackedScene
	_check(menu_scene != null, "StartMenu scene loads")
	if menu_scene == null:
		_finish()
		return
	var menu: StartMenu = menu_scene.instantiate() as StartMenu
	_check(menu != null, "StartMenu scene instantiates as StartMenu")
	if menu == null:
		_finish()
		return
	root.add_child(menu)
	await process_frame
	await process_frame

	_check(menu.size.is_equal_approx(LOGICAL_VIEWPORT), "menu resolves to the 480x270 logical viewport")
	_validate_signal_fields(menu)
	var device_safe_rect: Rect2 = menu.get_layout_safe_rect()
	_validate_layout(menu, device_safe_rect, "device safe area")
	var preserved_address: String = menu.address_edit.text

	menu.set_safe_area_override_for_validation(SYNTHETIC_SAFE_RECT)
	await process_frame
	_check(
		_rect_is_equal(menu.get_layout_safe_rect(), SYNTHETIC_SAFE_RECT),
		"synthetic landscape safe-area override resolves exactly"
	)
	_validate_layout(menu, SYNTHETIC_SAFE_RECT, "synthetic landscape inset")
	_check(menu.address_edit.text == preserved_address, "safe-area relayout preserves the entered LAN address")

	menu.select_character(&"shane")
	_check(menu.selected_character == &"shane", "safe-area relayout preserves survivor selection behavior")
	_check(
		(menu.get_node("ShaneCard/SelectionFrame") as Control).visible,
		"Shane retains the explicit selected-frame marker after relayout"
	)
	_check(
		(menu.get_node("ShaneCard/ActiveChip") as Control).visible,
		"Shane retains the non-colour active marker after relayout"
	)
	_check(
		bool((menu.get_node("ShaneCard/SignalField") as Control).call(&"is_active")),
		"Shane retains the original identity signal field after relayout"
	)
	_check(
		not bool((menu.get_node("HeikkiCard/SignalField") as Control).call(&"is_active")),
		"Heikki signal field yields when Shane is selected"
	)

	menu.clear_safe_area_override_for_validation()
	await process_frame
	_check(
		_rect_is_equal(menu.get_layout_safe_rect(), device_safe_rect),
		"clearing the synthetic inset restores the device safe-area geometry"
	)
	_validate_layout(menu, device_safe_rect, "restored device safe area")
	menu.queue_free()
	await process_frame
	_finish()


func _validate_signal_fields(menu: StartMenu) -> void:
	for card_name: StringName in [&"HeikkiCard", &"ShaneCard"]:
		var card: Control = menu.get_node(NodePath(String(card_name))) as Control
		var field: Control = menu.get_node(
			NodePath("%s/SignalField" % String(card_name))
		) as Control
		_check(field != null, "%s has an original identity signal field" % card_name)
		if field == null:
			continue
		_check(field.has_method(&"set_active") and field.has_method(&"is_active"), "%s signal field exposes only its presentation state contract" % card_name)
		_check(
			field.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"%s signal field cannot capture touch or keyboard interaction" % card_name
		)
		_check(
			field.size.is_equal_approx(card.size),
			"%s signal field follows its responsive card bounds" % card_name
		)
	_check(
		bool((menu.get_node("HeikkiCard/SignalField") as Control).call(&"is_active")),
		"Heikki starts with the selected identity signal field"
	)


func _validate_layout(menu: StartMenu, safe_rect: Rect2, label: String) -> void:
	_check(safe_rect.has_area(), "%s has a non-empty safe rectangle" % label)
	_check(
		safe_rect.encloses(menu.get_layout_content_rect()),
		"%s contains its content inset" % label
	)
	var interactive_rects: Dictionary = menu.get_interactive_layout_rects()
	var interactive_names: Array = interactive_rects.keys()
	for interactive_name_variant: Variant in interactive_names:
		var interactive_name: StringName = interactive_name_variant as StringName
		var interactive_rect: Rect2 = interactive_rects[interactive_name]
		_check(
			interactive_rect.size.x >= MIN_TOUCH_TARGET
			and interactive_rect.size.y >= MIN_TOUCH_TARGET,
			"%s keeps the 44px touch contract in %s" % [interactive_name, label]
		)
		_check(
			safe_rect.encloses(interactive_rect),
			"%s stays inside %s" % [interactive_name, label]
		)

	for first_index: int in range(interactive_names.size()):
		var first_name: StringName = interactive_names[first_index] as StringName
		var first_rect: Rect2 = interactive_rects[first_name]
		for second_index: int in range(first_index + 1, interactive_names.size()):
			var second_name: StringName = interactive_names[second_index] as StringName
			var second_rect: Rect2 = interactive_rects[second_name]
			_check(
				not first_rect.intersects(second_rect),
				"%s and %s do not overlap in %s" % [first_name, second_name, label]
			)

	var structural_rects: Dictionary = {
		&"header": _rect_for(menu.get_node("Header") as Control),
		&"heikki_card": _rect_for(menu.get_node("HeikkiCard") as Control),
		&"shane_card": _rect_for(menu.get_node("ShaneCard") as Control),
		&"selection_label": _rect_for(menu.get_node("SelectionLabel") as Control),
		&"session_panel": _rect_for(menu.get_node("SessionPanel") as Control),
		&"footer": _rect_for(menu.get_node("Footer") as Control),
	}
	var structural_names: Array = structural_rects.keys()
	for structural_name_variant: Variant in structural_names:
		var structural_name: StringName = structural_name_variant as StringName
		var structural_rect: Rect2 = structural_rects[structural_name]
		_check(
			safe_rect.encloses(structural_rect),
			"%s structural region stays inside %s" % [structural_name, label]
		)
	for first_index: int in range(structural_names.size()):
		var first_name: StringName = structural_names[first_index] as StringName
		var first_rect: Rect2 = structural_rects[first_name]
		for second_index: int in range(first_index + 1, structural_names.size()):
			var second_name: StringName = structural_names[second_index] as StringName
			var second_rect: Rect2 = structural_rects[second_name]
			_check(
				not first_rect.intersects(second_rect),
				"%s and %s structural regions do not overlap in %s"
				% [first_name, second_name, label]
			)

	for focus_control: Control in [
		menu.get_node("HeikkiCard") as Control,
		menu.get_node("ShaneCard") as Control,
		menu.get_node("AddressEdit") as Control,
		menu.get_node("SoloButton") as Control,
		menu.get_node("HostButton") as Control,
		menu.get_node("JoinButton") as Control,
	]:
		_check(
			focus_control.focus_mode == Control.FOCUS_ALL,
			"%s remains keyboard-focusable in %s" % [focus_control.name, label]
		)


func _rect_for(control: Control) -> Rect2:
	return Rect2(control.position, control.size)


func _rect_is_equal(first: Rect2, second: Rect2) -> bool:
	return (
		first.position.is_equal_approx(second.position)
		and first.size.is_equal_approx(second.size)
	)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("START MENU LAYOUT FAILED: %s" % message)


func _finish() -> void:
	if _failures == 0:
		print("START MENU LAYOUT OK (%d checks)" % _checks)
		quit(0)
		return
	push_error("START MENU LAYOUT FAILED (%d/%d checks failed)" % [_failures, _checks])
	quit(_failures)
