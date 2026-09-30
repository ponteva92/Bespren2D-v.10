extends SceneTree
## Deterministic touch ownership, menu tween, solo authority, and 2D scene gate.

const EXPECTED_STARTING_CAMP_POSITION: Vector2 = Vector2(9950.0, 2400.0)
const EXPECTED_SOLO_SPAWN_POSITION: Vector2 = Vector2(9730.0, 2685.0)

var _checks: int = 0
var _failures: int = 0
var _actions: Array[StringName] = []
var _hud_commands: Array[StringName] = []
var _state_updates: int = 0
var _interactions: int = 0
var _fallback_ready: bool = false


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _validate_start_menu()
	await _validate_multitouch()
	await _validate_game_hud()
	await _validate_solo_authority()
	await _validate_client_fallback()
	await _validate_game_world()
	if _failures == 0:
		print("MOBILE SYSTEMS OK (%d checks)" % _checks)
	else:
		push_error("MOBILE SYSTEMS FAILED (%d/%d checks failed)" % [_failures, _checks])
	quit(_failures)


func _validate_start_menu() -> void:
	var menu_scene: PackedScene = load("res://scenes/ui/StartMenu.tscn") as PackedScene
	var menu: StartMenu = menu_scene.instantiate() as StartMenu
	root.add_child(menu)
	await process_frame
	await process_frame
	_check(menu.selected_character == &"heikki", "StartMenu defaults to Heikki")
	menu.select_character(&"shane")
	_check(menu.selected_character == &"shane", "StartMenu selects Shane")
	_check(menu.is_bounce_active(), "Character selection starts a bounce tween")
	var heikki_card: Button = menu.get_node("HeikkiCard") as Button
	var shane_card: Button = menu.get_node("ShaneCard") as Button
	_check(heikki_card.size.x >= 44.0 and heikki_card.size.y >= 44.0, "Heikki card is touch-sized")
	_check(shane_card.size.x >= 44.0 and shane_card.size.y >= 44.0, "Shane card is touch-sized")
	_check(
		not (menu.get_node("HeikkiCard/SelectionFrame") as Control).visible
		and (menu.get_node("ShaneCard/SelectionFrame") as Control).visible,
		"StartMenu moves the explicit selected-frame state with the survivor"
	)
	_check(
		not (menu.get_node("HeikkiCard/ActiveChip") as Control).visible
		and (menu.get_node("ShaneCard/ActiveChip") as Control).visible,
		"StartMenu exposes a non-colour-only active survivor marker"
	)
	var session_controls: Array[Control] = [
		menu.get_node("AddressEdit") as Control,
		menu.get_node("SoloButton") as Control,
		menu.get_node("HostButton") as Control,
		menu.get_node("JoinButton") as Control,
	]
	var session_controls_touch_sized: bool = true
	for control: Control in session_controls:
		session_controls_touch_sized = session_controls_touch_sized and control.size.x >= 44.0 and control.size.y >= 44.0
	_check(session_controls_touch_sized, "Every StartMenu launch control retains a 44px touch target")
	menu.queue_free()
	await process_frame


func _validate_multitouch() -> void:
	var controls_scene: PackedScene = load("res://scenes/ui/MobileControls.tscn") as PackedScene
	var controls: MobileControls = controls_scene.instantiate() as MobileControls
	root.add_child(controls)
	controls.action_pressed.connect(_on_action_pressed)
	await process_frame
	_check(
		controls.get_action_target_size() == Vector2(44.0, 44.0),
		"Interact and Fire expose 44x44 logical targets"
	)
	var joystick_center: Vector2 = controls.get_joystick_center()
	controls.inject_touch_for_test(0, true, joystick_center + Vector2(30.0, 0.0))
	_check(controls.get_movement_touch_index() == 0, "Finger zero owns movement")
	_check(controls.movement_vector.is_equal_approx(Vector2.RIGHT), "Joystick resolves an eight-way right vector")
	controls.inject_touch_for_test(1, true, controls.get_action_center(&"interact"))
	controls.inject_touch_for_test(2, true, controls.get_action_center(&"fire"))
	_check(controls.get_movement_touch_index() == 0, "Action fingers do not replace the movement index")
	_check(controls.get_interact_touch_index() == 1, "Interact retains its own finger index")
	_check(controls.get_fire_touch_index() == 2, "Fire retains its own finger index")
	_check(_actions == [&"interact", &"fire"], "Simultaneous action touches emit distinct triggers")
	controls.inject_touch_for_test(1, false, controls.get_action_center(&"interact"))
	_check(controls.get_movement_touch_index() == 0, "Releasing Interact preserves movement ownership")
	controls.inject_drag_for_test(0, joystick_center + Vector2(24.0, -24.0))
	_check(
		controls.movement_vector.is_equal_approx(Vector2(1.0, -1.0).normalized()),
		"Joystick diagonal is quantized to an eight-way vector"
	)
	controls.inject_touch_for_test(0, false, joystick_center)
	controls.inject_touch_for_test(2, false, controls.get_action_center(&"fire"))
	_check(controls.movement_vector == Vector2.ZERO, "Movement release returns the joystick to zero")
	controls.queue_free()
	await process_frame


func _validate_game_hud() -> void:
	var hud_scene: PackedScene = load("res://scenes/ui/game_hud.tscn") as PackedScene
	_check(hud_scene != null, "GameHUD scene loads")
	if hud_scene == null:
		return
	var hud: GameHUD = hud_scene.instantiate() as GameHUD
	_check(hud != null, "GameHUD scene instantiates as GameHUD")
	if hud == null:
		return
	_hud_commands.clear()
	hud.command_requested.connect(_on_hud_command_requested)
	root.add_child(hud)
	await process_frame
	hud.set_resource_amounts(7, 11, 13)
	hud.set_status("Systems nominal")
	_check(hud.layer == 100, "GameHUD renders on CanvasLayer 100")

	var resource_labels: Array[Label] = hud.get_resource_labels_for_test()
	_check(resource_labels.size() == 3, "GameHUD exposes exactly three resource labels")
	if resource_labels.size() == 3:
		_check(
			resource_labels[0].name == &"WoodValue"
			and resource_labels[0].text == "7",
			"GameHUD exposes the exact WoodValue resource"
		)
		_check(
			resource_labels[1].name == &"MetalValue"
			and resource_labels[1].text == "11",
			"GameHUD exposes the exact MetalValue resource"
		)
		_check(
			resource_labels[2].name == &"TechValue"
			and resource_labels[2].text == "13",
			"GameHUD exposes the exact TechValue resource"
		)
		var resources_are_horizontal_and_readable: bool = true
		for resource_index: int in range(resource_labels.size()):
			if resource_labels[resource_index].get_theme_font_size(&"font_size") < 8:
				resources_are_horizontal_and_readable = false
			if resource_index > 0:
				var previous_rect: Rect2 = resource_labels[resource_index - 1].get_global_rect()
				var current_rect: Rect2 = resource_labels[resource_index].get_global_rect()
				if (
					current_rect.position.x <= previous_rect.position.x
					or not is_equal_approx(current_rect.position.y, previous_rect.position.y)
				):
					resources_are_horizontal_and_readable = false
		_check(
			resources_are_horizontal_and_readable,
			"Resource counters form one readable compact horizontal strip"
		)
	_check(
		hud.get_status_label().text == "Systems nominal"
		and hud.get_status_panel().visible,
		"GameHUD shows the status toast for the message it was given"
	)

	var buttons: Array[Button] = hud.get_buttons_for_test()
	var expected_button_names: Array[StringName] = [
		&"MakeBaseButton",
		&"BuildButton",
		&"StartNightButton",
	]
	var expected_button_texts: PackedStringArray = PackedStringArray([
		"Make Base",
		"Build",
		"Start Night",
	])
	_check(buttons.size() == 3, "GameHUD exposes exactly three command buttons")
	var buttons_match_contract: bool = buttons.size() == 3
	var buttons_are_touch_sized: bool = buttons.size() == 3
	var visible_chrome_is_compact: bool = buttons.size() == 3
	var visible_labels_are_readable: bool = buttons.size() == 3
	var buttons_do_not_overlap: bool = buttons.size() == 3
	for button_index: int in range(buttons.size()):
		var button: Button = buttons[button_index]
		if (
			button_index >= expected_button_names.size()
			or button.name != expected_button_names[button_index]
			or button.text != expected_button_texts[button_index]
		):
			buttons_match_contract = false
		if button.size.x < 44.0 or button.size.y < 44.0:
			buttons_are_touch_sized = false
		var visual: Control = button.get_node_or_null("Visual") as Control
		if visual == null or visual.size.x * visual.size.y > 1200.0:
			visible_chrome_is_compact = false
		var visible_label: Label = button.get_node_or_null("Visual/Label") as Label
		if visible_label == null or visible_label.get_theme_font_size(&"font_size") < 8:
			visible_labels_are_readable = false
	for first_index: int in range(buttons.size()):
		for second_index: int in range(first_index + 1, buttons.size()):
			if buttons[first_index].get_global_rect().intersects(
				buttons[second_index].get_global_rect()
			):
				buttons_do_not_overlap = false
	_check(buttons_match_contract, "GameHUD command nodes and visible texts match exactly")
	_check(buttons_are_touch_sized, "Every GameHUD command keeps at least a 44x44 touch target")
	_check(visible_chrome_is_compact, "Visible command chrome is roughly 75 percent smaller by area")
	_check(visible_labels_are_readable, "Compact command chrome keeps readable 8px labels")
	_check(buttons_do_not_overlap, "GameHUD command buttons are pairwise non-overlapping")

	var panel_rect: Rect2 = hud.get_panel_for_test().get_global_rect()
	var wave_rect: Rect2 = hud.get_wave_chip().get_global_rect()
	var panel_area: float = panel_rect.size.x * panel_rect.size.y
	_check(
		panel_rect.size.is_equal_approx(Vector2(148.0, 58.0))
		and panel_area <= GameHUD.LEGACY_TOP_LEFT_AREA * 0.5,
		"GameHUD cuts the former 208x84 top-left footprint by at least 50 percent (%s)"
		% panel_rect.size
	)
	_check(panel_rect.end.y <= 270.0, "GameHUD panel stays inside the logical viewport")
	_check(
		not wave_rect.intersects(panel_rect)
		and wave_rect.end.y <= GameHUD.RESERVED_CONTROLS_TOP_Y,
		"Wave chip is separate from the compact top-left dashboard and controls"
	)
	var notch_insets: Rect2 = Rect2(
		Vector2(18.0, 10.0),
		Vector2(16.0, 8.0)
	)
	var notch_safe_rect: Rect2 = Rect2(
		notch_insets.position,
		Vector2(
			480.0 - notch_insets.position.x - notch_insets.size.x,
			270.0 - notch_insets.position.y - notch_insets.size.y
		)
	)
	var calculated_panel: Rect2 = GameHUD.calculate_panel_rect(
		Vector2(480.0, 270.0),
		notch_insets
	)
	_check(
		notch_safe_rect.encloses(calculated_panel),
		"GameHUD panel calculation stays inside a synthetic notch safe area"
	)
	var calculated_minimap: Rect2 = GameHUD.calculate_minimap_rect(
		Vector2(480.0, 270.0),
		notch_insets
	)
	var calculated_wave: Rect2 = GameHUD.calculate_wave_chip_rect(
		Vector2(480.0, 270.0),
		notch_insets,
		calculated_panel,
		calculated_minimap
	)
	var calculated_status: Rect2 = GameHUD.calculate_status_rect(
		Vector2(480.0, 270.0),
		notch_insets
	)
	_check(
		notch_safe_rect.encloses(calculated_wave)
		and notch_safe_rect.encloses(calculated_status)
		and not calculated_wave.intersects(calculated_panel)
		and not calculated_wave.intersects(calculated_minimap),
		"Synthetic-notch wave and reserved HUD geometry preserve safe-area separation"
	)

	if buttons.size() == 3:
		buttons[0].pressed.emit()
		buttons[1].pressed.emit()
		buttons[2].pressed.emit()
	_check(
		_hud_commands == [
			GameHUD.COMMAND_MAKE_BASE,
			GameHUD.COMMAND_BUILD,
			GameHUD.COMMAND_START_NIGHT,
		],
		"GameHUD command signals emit make_base, build, and start_night in exact order"
	)
	hud.queue_free()
	await process_frame


func _validate_solo_authority() -> void:
	var session: CoopSession = CoopSession.new()
	session.name = "CoopSession"
	root.add_child(session)
	session.authoritative_state_received.connect(_on_state_received)
	session.interaction_received.connect(_on_interaction_received)
	session.start_solo(&"shane")
	_check(session.mode == CoopSession.SessionMode.SOLO, "Solo mode installs the fallback session")
	_check(session.multiplayer.is_server(), "Solo fallback retains server authority")
	_check(session.is_peer_registered(CoopSession.AUTHORITY_PEER_ID), "Solo player registers at authority peer one")
	var starting_position: Vector2 = session.get_authoritative_position(CoopSession.AUTHORITY_PEER_ID)
	_check(
		BesprenWorldMap2D.STARTING_CAMP_POSITION.is_equal_approx(
			EXPECTED_STARTING_CAMP_POSITION
		)
		and starting_position.is_equal_approx(EXPECTED_SOLO_SPAWN_POSITION),
		"Solo authority spawns at the exact relocated east-forest camp lane"
	)
	session.submit_movement(Vector2.RIGHT)
	for _frame_index: int in range(8):
		await physics_frame
	_check(
		session.get_authoritative_position(CoopSession.AUTHORITY_PEER_ID).x > starting_position.x,
		"Host physics integrates the validated Vector2 movement"
	)
	_check(_state_updates > 0, "Solo authority publishes ordered replaceable state snapshots")
	session.submit_interaction(&"interact")
	await process_frame
	_check(_interactions == 1, "Solo interaction uses the reliable broadcast path")
	session.queue_free()
	await process_frame


func _validate_client_fallback() -> void:
	var session: CoopSession = CoopSession.new()
	session.name = "FallbackSession"
	root.add_child(session)
	session.session_ready.connect(_on_fallback_session_ready)
	session.start_client("127.0.0.1", &"heikki")
	await create_timer(CoopSession.CLIENT_CONNECT_TIMEOUT_SECONDS + 0.4).timeout
	_check(_fallback_ready, "Unavailable LAN host automatically resolves to Solo mode")
	_check(session.mode == CoopSession.SessionMode.SOLO, "Fallback session reports Solo mode")
	_check(session.multiplayer.is_server(), "Automatic fallback restores peer-one authority")
	session.queue_free()
	await process_frame


func _validate_game_world() -> void:
	var world_scene: PackedScene = load("res://scenes/game/game_world.tscn") as PackedScene
	var world: GameWorld = world_scene.instantiate() as GameWorld
	world.configure_launch(CoopSession.SessionMode.SOLO, &"heikki", "127.0.0.1")
	root.add_child(world)
	for _frame_index: int in range(4):
		await process_frame
	var players_root: Node2D = world.get_node("YSortWorld/Players") as Node2D
	var world_map: BesprenWorldMap2D = world.get_node(
		"YSortWorld/WorldMap2D"
	) as BesprenWorldMap2D
	var base_core: CorePulseDriver = world.get_node("YSortWorld/BaseCore") as CorePulseDriver
	_check(players_root.y_sort_enabled, "Player state uses Y-sort pseudo-depth")
	_check(players_root.get_child_count() == 1, "Solo world spawns exactly one network player")
	var runtime_body: CharacterBody2D = players_root.get_child(0) as CharacterBody2D
	_check(
		players_root.get_child(0) is PlayerAvatar
		and runtime_body != null,
		"Runtime player is a host-authored CharacterBody2D"
	)
	var player_collision: CollisionShape2D = null
	if runtime_body != null:
		player_collision = runtime_body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_check(
		player_collision != null and not player_collision.disabled,
		"Runtime player owns an enabled CollisionShape2D"
	)
	var player_shape: CircleShape2D = null
	if player_collision != null:
		player_shape = player_collision.shape as CircleShape2D
	_check(
		player_shape != null and is_equal_approx(player_shape.radius, 9.0),
		"Runtime player collision is a precise radius-9 CircleShape2D"
	)
	_check(
		runtime_body != null
		and runtime_body.collision_layer == 1
		and runtime_body.collision_mask == 2,
		"Runtime player uses Players layer 1 and WorldStatic mask 2"
	)
	_check(
		base_core.global_position.is_equal_approx(EXPECTED_STARTING_CAMP_POSITION),
		"Mobile composition relocates the Base to exact position (9950, 2400)"
	)
	_check(
		world_map.get_minimum_asphalt_edge_distance(base_core.global_position)
		- BesprenWorldMap2D.CORE_COLLISION_RADIUS
		>= BesprenWorldMap2D.STARTING_CAMP_REQUIRED_ROAD_EDGE_CLEARANCE,
		"Mobile Base footprint preserves at least 1600 units from every asphalt edge"
	)
	_check(not _tree_contains_3d_node(world), "Gameplay scene contains no 3D nodes")
	world.queue_free()
	await process_frame


func _tree_contains_3d_node(node: Node) -> bool:
	if node is Node3D:
		return true
	for child: Node in node.get_children():
		if _tree_contains_3d_node(child):
			return true
	return false


func _on_action_pressed(action: StringName) -> void:
	_actions.append(action)


func _on_hud_command_requested(command: StringName) -> void:
	_hud_commands.append(command)


func _on_state_received(_peer_id: int, _position: Vector2, _movement: Vector2) -> void:
	_state_updates += 1


func _on_interaction_received(
	_peer_id: int,
	_interaction: StringName,
	_position: Vector2
) -> void:
	_interactions += 1


func _on_fallback_session_ready(mode_value: int, _local_peer_id: int) -> void:
	if mode_value == CoopSession.SessionMode.SOLO:
		_fallback_ready = true


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS | %s" % message)
		return
	_failures += 1
	push_error("FAIL | %s" % message)
