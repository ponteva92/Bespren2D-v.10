extends SceneTree
## Focused runtime proof for the mobile HUD, tactical deck, authority, and juice slice.

class MockZombie:
	extends Node
	var base_target: Vector2 = Vector2.INF

	func set_base_target(world_position: Vector2) -> void:
		base_target = world_position


var _checks: int = 0
var _failures: int = 0
var _armed_structure_id: StringName = &""
var _placement_mode: int = -1
var _placement_structure_id: StringName = &""
var _placement_position: Vector2 = Vector2.INF
var _minimap_ping: Vector2 = Vector2.INF
var _warnings: Array[int] = []
var _rejections: Array[StringName] = []
var _relocation_position: Vector2 = Vector2.INF
var _relocation_refund: PackedInt32Array = PackedInt32Array()
var _relocation_destroyed_count: int = -1


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _validate_hud_deck_and_projection()
	await _validate_integrated_authority_and_feedback()
	if _failures == 0:
		print("TACTICAL HUD OK (%d checks)" % _checks)
		quit(0)
		return
	push_error("TACTICAL HUD FAILED (%d/%d checks failed)" % [_failures, _checks])
	quit(1)


func _validate_hud_deck_and_projection() -> void:
	var hud_scene: PackedScene = load("res://scenes/ui/game_hud.tscn") as PackedScene
	var hud: GameHUD = hud_scene.instantiate() as GameHUD
	root.add_child(hud)
	await process_frame
	_check(hud.layer == 100, "HUD remains pinned to CanvasLayer 100")
	var buttons: Array[Button] = hud.get_command_buttons()
	_check(buttons.size() == 3, "Command array contains exactly three buttons")
	_check(
		buttons.size() == 3
		and buttons[0].text == "Make Base"
		and buttons[1].text == "Build"
		and buttons[2].text == "Start Night",
		"Command order is Make Base, Build, Start Night"
	)
	var horizontal_order: bool = buttons.size() == 3
	for button_index: int in range(1, buttons.size()):
		var previous_rect: Rect2 = buttons[button_index - 1].get_global_rect()
		var current_rect: Rect2 = buttons[button_index].get_global_rect()
		if current_rect.position.x <= previous_rect.position.x or not is_equal_approx(current_rect.position.y, previous_rect.position.y):
			horizontal_order = false
	_check(horizontal_order, "Command buttons form one compact horizontal action row")
	_check(
		hud.get_night_indicator().text == "NIGHT 01 // DAYLIGHT"
		and hud.get_modifier_label().text == "ZOMBIES -65%"
		and hud.get_clock_label().text == "07:30 TO NIGHT",
		"HUD exposes night, daytime modifier, and 450-second clock state"
	)
	hud.set_status("HUD state remains available to systems")
	hud.show_resource_pickup(Vector2.ZERO, 0, 3)
	hud.show_resource_pickup(Vector2.ZERO, 1, 2)
	await process_frame
	var pickup_labels: Array[Label] = hud.get_resource_pickup_labels()
	hud.show_warning(60)
	await process_frame
	var warning_chip: PanelContainer = hud.get_threat_chip()
	_check(
		warning_chip.visible
		and warning_chip.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and hud.get_threat_tag().text == "ALERT"
		and hud.get_threat_label().text == "NIGHTFALL // 60s"
		and warning_chip.size.y <= 16.0
		and warning_chip.get_global_rect().position.y >= 0.0
		and warning_chip.get_global_rect().end.y <= 270.0,
		"Nightfall warning uses one non-blocking 14px top-safe event chip"
	)
	hud.set_boss_gate(true, &"goliath", 1)
	await process_frame
	_check(
		hud.get_status_label().text == "HUD state remains available to systems"
		and hud.get_status_panel().visible
		and not hud.get_warning_panel().visible
		and not hud.get_boss_marquee_panel().visible
		and hud.get_threat_chip().visible
		and hud.get_threat_tag().text == "BOSS"
		and hud.get_threat_label().text == "GOLIATH // 1 REMAIN"
		and pickup_labels.size() == 2
		and pickup_labels[0].text == "+ 3 WOOD"
		and pickup_labels[1].text == "+ 2 METAL",
		"Status toast is visible and boss state stays in the top-safe event chip"
	)

	hud.set_resource_amounts(999, 999, 999)
	hud.open_build_deck()
	await process_frame
	var deck: TacticalBuildDeck = hud.get_build_deck()
	_check(
		deck.is_open()
		and not hud.get_panel().visible
		and not hud.get_threat_chip().visible,
		"Build opens the deck and suppresses all dashboard event chrome in the same frame"
	)
	hud.close_build_deck_immediately()
	await process_frame
	_check(
		not deck.is_open()
		and hud.get_threat_chip().visible
		and hud.get_threat_tag().text == "BOSS",
		"Closing the deck restores the persistent authority-fed boss event chip"
	)
	hud.open_build_deck()
	await process_frame
	var cards: Array[Button] = deck.get_card_buttons()
	var definitions: Array[StructureDefinition] = StructureCatalog.get_all()
	_check(cards.size() == 8 and definitions.size() == 8, "Build deck contains all eight Tier-1 definitions and cards")
	var cards_match: bool = cards.size() == definitions.size()
	var cards_are_touch_sized_and_readable: bool = cards.size() == definitions.size()
	for card_index: int in range(cards.size()):
		if String(cards[card_index].get_meta(&"display_name", "")) != definitions[card_index].display_name:
			cards_match = false
		var title: Label = cards[card_index].get_node_or_null("Content/Title") as Label
		var cost: Label = cards[card_index].get_node_or_null("Content/Cost") as Label
		var thumbnail: TextureRect = cards[card_index].get_node_or_null("Content/Thumbnail") as TextureRect
		if (
			cards[card_index].size.x < 44.0
			or cards[card_index].size.y < 44.0
			or title == null
			or title.get_theme_font_size(&"font_size") < 7
			or cost == null
			or cost.get_theme_font_size(&"font_size") < 7
			or cost.get_theme_constant(&"outline_size") < 1
			or thumbnail == null
			or thumbnail.texture == null
		):
			cards_are_touch_sized_and_readable = false
	_check(cards_match, "All eight thumbnail cards retain canonical Tier-1 identity metadata")
	_check(
	cards_are_touch_sized_and_readable,
		"Every defense card keeps a 44px touch target, outlined decision type, and local thumbnail"
	)
	var visible_towers: int = 0
	for card: Button in cards:
		if card.visible:
			visible_towers += 1
	_check(
		deck.get_cards_grid().columns == 3
		and deck.get_cards_per_page() == 3
		and visible_towers == 3
		and deck.get_category_card_count(TacticalBuildDeck.DeckCategory.TOWERS) == 3
		and deck.get_category_card_count(TacticalBuildDeck.DeckCategory.TRAPS) == 3
		and deck.get_category_card_count(TacticalBuildDeck.DeckCategory.UTILITIES) == 2,
		"Build sheet groups three towers, three traps, and two utilities"
	)
	_check(
		TacticalBuildDeck.calculate_page_count(3) == 1
		and TacticalBuildDeck.calculate_page_count(4) == 2
		and TacticalBuildDeck.calculate_page_count(8) == 3,
		"Category pager remains overflow-safe beyond three cards"
	)
	var tabs_are_touch_sized: bool = true
	for tab: Button in deck.get_category_tabs():
		if tab.size.x < 44.0 or tab.size.y < 44.0:
			tabs_are_touch_sized = false
	_check(tabs_are_touch_sized, "Tower, Trap, and Utility tabs retain 44px touch targets")
	var chips: Array[Label] = deck.get_resource_chip_labels()
	_check(
		chips.size() == 3
		and chips[0].text == "W999"
		and chips[1].text == "M999"
		and chips[2].text == "T999",
		"Build sheet mirrors the live shared resource pool"
	)
	var sheet_rect: Rect2 = deck.get_menu_canvas().get_global_rect()
	var layout_sheet_rect: Rect2 = deck.get_current_sheet_rect()
	_check(
		sheet_rect.position.x >= 0.0
		and sheet_rect.position.y >= 0.0
		and sheet_rect.end.x <= 480.0
		and sheet_rect.end.y <= 270.0
		and layout_sheet_rect.position.x >= 0.0
		and layout_sheet_rect.position.y >= 0.0
		and layout_sheet_rect.end.x <= 480.0
		and layout_sheet_rect.end.y <= 270.0
		and layout_sheet_rect.get_center().distance_to(Vector2(240.0, 135.0)) < 1.0,
		"Build sheet layout is a floating popup centered in the gameplay viewport"
	)
	var notch_insets: Rect2 = Rect2(Vector2(18.0, 10.0), Vector2(16.0, 8.0))
	var notch_safe_rect: Rect2 = Rect2(
		notch_insets.position,
		Vector2(
			480.0 - notch_insets.position.x - notch_insets.size.x,
			270.0 - notch_insets.position.y - notch_insets.size.y
		)
	)
	var notch_sheet: Rect2 = TacticalBuildDeck.calculate_sheet_rect(
		Vector2(480.0, 270.0),
		notch_insets,
		156.0
	)
	_check(
		notch_safe_rect.encloses(notch_sheet)
		and notch_sheet.get_center().distance_to(notch_safe_rect.get_center()) < 1.0,
		"Centered build popup honors synthetic cutouts"
	)

	deck.select_category_for_test(TacticalBuildDeck.DeckCategory.TRAPS)
	var visible_traps: int = 0
	for card: Button in cards:
		if card.visible:
			visible_traps += 1
	_check(
		deck.get_current_category() == TacticalBuildDeck.DeckCategory.TRAPS
		and visible_traps == 3,
		"Trap tab presents exactly the three trap silhouettes"
	)
	for card: Button in cards:
		if card.get_meta(&"structure_id", &"") == StructureCatalog.T1_RAZOR_SNARE:
			card.pressed.emit()
			break
	deck.hide_immediately()
	hud.open_build_deck()
	await process_frame
	_check(
		deck.get_current_category() == TacticalBuildDeck.DeckCategory.TRAPS
		and deck.get_selected_structure_id() == StructureCatalog.T1_RAZOR_SNARE,
		"Build sheet remembers category and selected card across reopen"
	)
	deck.select_category_for_test(TacticalBuildDeck.DeckCategory.TOWERS)

	cards[0].pressed.emit()
	var info_role: Label = deck.get_node("MenuCanvas/Margins/DeckStack/Body/InfoPanel/InfoMargins/InfoBody/InfoStack/InfoRole") as Label
	var info_mechanics: Label = deck.get_node("MenuCanvas/Margins/DeckStack/Body/InfoPanel/InfoMargins/InfoBody/InfoStack/InfoMechanics") as Label
	var info_stats: Label = deck.get_node("MenuCanvas/Margins/DeckStack/Body/InfoPanel/InfoMargins/InfoBody/InfoStack/InfoStats") as Label
	var info_cost: Label = deck.get_node("MenuCanvas/Margins/DeckStack/Body/InfoPanel/InfoMargins/InfoBody/InfoStack/InfoCost") as Label
	_check(
		deck.get_info_panel().visible
		and deck.get_selected_structure_id() == StructureCatalog.T1_KINETIC
		and info_role.visible
		and info_role.text == definitions[0].role.to_upper()
		and info_mechanics.text == definitions[0].mechanics
		and info_mechanics.max_lines_visible >= 2,
		"Tapping a card opens full role and wrapped mechanics without duplicated copy"
	)
	_check(
		info_role.get_theme_font_size(&"font_size") >= 7
		and info_stats.get_theme_font_size(&"font_size") >= 7
		and info_cost.get_theme_font_size(&"font_size") >= 7
		and info_role.get_theme_constant(&"outline_size") >= 1
		and info_stats.get_theme_constant(&"outline_size") >= 1
		and info_cost.get_theme_constant(&"outline_size") >= 1
		and info_mechanics.get_theme_constant(&"outline_size") >= 1,
		"Build decision data uses a stronger outlined hierarchy than supporting mechanics copy"
	)
	var info_rect: Rect2 = deck.get_info_panel().get_global_rect()
	var cards_rect: Rect2 = deck.get_cards_grid().get_global_rect()
	var arm_button: Button = deck.get_arm_button()
	_check(
		info_rect.position.x >= 0.0
		and info_rect.position.y >= 0.0
		and info_rect.end.x <= 480.0
		and info_rect.end.y <= 270.0
		and info_rect.position.y >= cards_rect.end.y,
		"Build details render directly below the card menu"
	)
	_check(
		arm_button.size.x >= 44.0
		and arm_button.size.y >= 44.0
		and arm_button.text == "PLACE"
		and not arm_button.text.contains("64PX"),
		"Placement uses a touch-safe player-facing action instead of developer copy"
	)
	_armed_structure_id = &""
	deck.structure_armed.connect(_on_structure_armed)
	arm_button.pressed.emit()
	_check(
		_armed_structure_id == StructureCatalog.T1_KINETIC and not deck.is_open(),
		"Info-card confirmation arms placement and releases menu input immediately"
	)

	hud.open_build_deck()
	await process_frame
	var outside_touch: InputEventScreenTouch = InputEventScreenTouch.new()
	outside_touch.index = 9
	outside_touch.pressed = true
	outside_touch.position = Vector2(470.0, 250.0)
	deck._input(outside_touch)
	_check(not deck.is_open() and hud.get_panel().visible, "An outside touch closes both deck and info presentation")

	hud.open_build_deck()
	await process_frame
	var close_button: Button = deck.get_node("MenuCanvas/Margins/DeckStack/Header/DeckCloseButton") as Button
	_check(close_button.size.x >= 44.0 and close_button.size.y >= 44.0, "Deck close control remains touch-safe")
	close_button.pressed.emit()
	_check(not deck.is_open(), "Tapping the close control releases the deck immediately")

	var minimap: TacticalMinimap = hud.get_minimap()
	var sample_world_position: Vector2 = Vector2(4096.0, -2048.0)
	var round_trip: Vector2 = minimap.minimap_to_world(minimap.world_to_minimap(sample_world_position))
	_check(round_trip.distance_to(sample_world_position) < 1.0, "Minimap performs reversible 2D world mapping")
	minimap.reset_exploration()
	minimap.set_tactical_state(
		Vector2.ZERO,
		PackedVector2Array([Vector2.ZERO]),
		PackedVector2Array(),
		PackedVector2Array([Vector2(512.0, 0.0)]),
		PackedInt32Array([0])
	)
	var revealed_after_spawn: int = minimap.get_revealed_cell_count()
	minimap.set_tactical_state(
		Vector2.ZERO,
		PackedVector2Array([Vector2.ZERO, Vector2(9600.0, 9600.0)]),
		PackedVector2Array(),
		PackedVector2Array([Vector2(512.0, 0.0), Vector2(9600.0, 9600.0)]),
		PackedInt32Array([0, 2])
	)
	_check(
		revealed_after_spawn > 0
		and minimap.get_revealed_cell_count() > revealed_after_spawn
		and minimap.get_visible_resource_marker_count() == 2,
		"Shared player travel reveals new minimap sectors and their resource nodes"
	)
	minimap.world_ping_requested.connect(_on_minimap_ping)
	var ping_mouse: InputEventMouseButton = InputEventMouseButton.new()
	ping_mouse.button_index = MOUSE_BUTTON_LEFT
	ping_mouse.pressed = true
	ping_mouse.position = minimap.get_global_rect().get_center()
	minimap._on_gui_input(ping_mouse)
	_check(_minimap_ping.is_finite(), "Interactive minimap emits a finite 2D world ping")
	minimap.set_road_network(
		[PackedVector2Array([Vector2(-100.0, 0.0), Vector2(100.0, 0.0)])],
		PackedByteArray([0])
	)
	_check(minimap.get_road_route_count() == 1, "Minimap stores the live road graph")
	hud.set_session_line("SOLO")
	_check(hud.get_session_line() == "SOLO", "HUD session line reports Solo")
	_check(
		GameHUD.placement_reason_text(&"blocked_cell") == "BLOCKED GROUND"
		and GameHUD.placement_reason_text(&"insufficient_resources") == "NOT ENOUGH RESOURCES",
		"Placement rejects use short player copy"
	)

	var placement_root: Node2D = Node2D.new()
	var placement: GridPlacementController2D = GridPlacementController2D.new()
	placement_root.add_child(placement)
	root.add_child(placement_root)
	placement.placement_confirmed.connect(_on_placement_confirmed)
	await process_frame
	placement.arm_structure(StructureCatalog.T1_LANDMINE)
	var placement_touch: InputEventScreenTouch = InputEventScreenTouch.new()
	placement_touch.index = 4
	placement_touch.pressed = true
	placement_touch.position = Vector2(141.0, 93.0)
	placement._unhandled_input(placement_touch)
	_check(
		_placement_mode == GridPlacementController2D.PlacementMode.STRUCTURE
		and _placement_structure_id == StructureCatalog.T1_LANDMINE
		and _placement_position == Vector2(128.0, 64.0)
		and not placement.is_armed(),
		"Touch projection confirms instantly on the precise 64px X/Y grid"
	)
	_check(
		GridPlacementController2D.snap_world_position(Vector2(-95.0, 97.0)) == Vector2(-64.0, 128.0),
		"Grid snapping is symmetric for negative and positive 2D coordinates"
	)
	placement.arm_structure(StructureCatalog.T1_BARRICADE)
	_check(
		placement.get_preview_footprint() == Vector2(128.0, 64.0),
		"Barricade preview uses the 2x1 footprint"
	)
	placement.set_preview_query(func(_structure_id: StringName, _world_position: Vector2) -> bool:
		return false
	)
	placement._draw()
	_check(not placement.is_preview_valid(), "A failing preview query tints the ghost invalid")
	placement_root.queue_free()
	hud.queue_free()
	await process_frame


func _validate_integrated_authority_and_feedback() -> void:
	var world_scene: PackedScene = load("res://scenes/game/game_world.tscn") as PackedScene
	var world: GameWorld = world_scene.instantiate() as GameWorld
	world.configure_launch(CoopSession.SessionMode.SOLO, &"heikki", "127.0.0.1")
	root.add_child(world)
	for _frame_index: int in range(6):
		await process_frame
	var manager: TacticalBuildSystem = world.build_system
	var cycle: DayNightCycle = world.day_night
	var world_map: BesprenWorldMap2D = world.world_map
	var audio: GameAudioController = world.audio
	var juice: JuiceRig = world.juice_rig
	_check(world.session.multiplayer.is_server(), "Solo fallback is the tactical host authority")
	_check(
		manager.get_resource_pool() == PackedInt32Array([120, 100, 80]),
		"All players begin from one replicated shared resource pool"
	)
	_check(
		audio.get_world_player_count() == 6
		and audio.get_mono_player_count() == AudioManager.MONO_POOL_SIZE,
		"AudioManager preallocates fixed world and mono voice pools"
	)
	_check(
		is_equal_approx(JuiceRig.POP_SCALE, 1.15)
		and is_equal_approx(JuiceRig.POP_DURATION_SECONDS, 0.25),
		"JuiceRig owns the exact 1.15x, 0.25-second pop contract"
	)

	var feedback_button: Button = world.hud.get_make_base_button()
	var base_button_scale: Vector2 = feedback_button.scale
	juice.pop(feedback_button)
	await create_timer(0.09).timeout
	_check(feedback_button.scale.length() > base_button_scale.length() * 1.04, "Juice pop reaches a visibly enlarged interaction state")
	await create_timer(0.20).timeout
	_check(feedback_button.scale.is_equal_approx(base_button_scale), "Juice pop returns to its exact base scale")
	var core_sprite: Sprite2D = world.base_core.get_core_sprite()
	var original_material: Material = core_sprite.material
	juice.flash_white(core_sprite)
	_check(
		core_sprite.material is ShaderMaterial
		and (core_sprite.material as ShaderMaterial).shader.resource_path == "res://shaders/solid_white_flash.gdshader",
		"Damage and alert feedback installs the solid-white flash shader"
	)
	await create_timer(JuiceRig.WHITE_FLASH_SECONDS + 0.04).timeout
	_check(core_sprite.material == original_material, "White flash restores the authored material after its bounded pulse")

	var first_position: Vector2 = _find_clear_grid_position(world_map, [], 82.0)
	_check(first_position.is_finite(), "Validation finds a clear first 64px construction cell")
	var initial_pool: PackedInt32Array = manager.get_resource_pool()
	manager.request_structure_placement(StructureCatalog.T1_BARRICADE, first_position)
	await process_frame
	_check(manager.get_structure_count() == 1, "Host validates and commits the first Tier-1 structure")
	var second_position: Vector2 = _find_clear_grid_position(world_map, [first_position], 82.0)
	manager.request_structure_placement(StructureCatalog.T1_LANDMINE, second_position)
	await process_frame
	_check(manager.get_structure_count() == 2, "Host commits a second trap without client-side authority")
	var barricade: StructureDefinition = StructureCatalog.get_definition(StructureCatalog.T1_BARRICADE)
	var landmine: StructureDefinition = StructureCatalog.get_definition(StructureCatalog.T1_LANDMINE)
	var expected_after_spend: PackedInt32Array = initial_pool.duplicate()
	for resource_kind: int in range(StructureDefinition.RESOURCE_KIND_COUNT):
		expected_after_spend[resource_kind] -= barricade.get_cost(resource_kind)
		expected_after_spend[resource_kind] -= landmine.get_cost(resource_kind)
	_check(manager.get_resource_pool() == expected_after_spend, "Placement cost is deducted atomically from the shared pool")

	var invested: PackedInt32Array = manager.get_total_invested_cost()
	var expected_refund: PackedInt32Array = PackedInt32Array([0, 0, 0])
	for resource_kind: int in range(StructureDefinition.RESOURCE_KIND_COUNT):
		expected_refund[resource_kind] = floori(float(invested[resource_kind]) * 0.35)
	var zombie: MockZombie = MockZombie.new()
	zombie.add_to_group(&"zombies")
	root.add_child(zombie)
	manager.base_relocated.connect(_on_base_relocated)
	var base_position: Vector2 = _find_clear_grid_position(
		world_map,
		[first_position, second_position],
		TacticalBuildSystem.BASE_CLEARANCE + 8.0
	)
	manager.request_base_relocation(base_position)
	await process_frame
	var expected_after_refund: PackedInt32Array = expected_after_spend.duplicate()
	for resource_kind: int in range(StructureDefinition.RESOURCE_KIND_COUNT):
		expected_after_refund[resource_kind] += expected_refund[resource_kind]
	_check(
		manager.get_structure_count() == 0 and _relocation_destroyed_count == 2,
		"Make Base destroys every existing player tower and trap"
	)
	_check(
		_relocation_refund == expected_refund
		and manager.get_resource_pool() == expected_after_refund,
		"Make Base refunds exactly floor(35%) of each total invested resource"
	)
	_check(
		_relocation_position == base_position
		and manager.get_base_position() == base_position
		and world_map.get_core_position() == base_position,
		"Base Core and canonical 2D navigation origin relocate atomically"
	)
	_check(zombie.base_target == base_position, "Every zombie receives the new X/Y Base target immediately")

	cycle.warning_requested.connect(_on_warning_requested)
	cycle.advance_for_test(400.0)
	cycle.advance_for_test(5.0)
	cycle.advance_for_test(15.0)
	cycle.advance_for_test(15.0)
	cycle.advance_for_test(5.0)
	cycle.advance_for_test(5.0)
	_check(
		_warnings == [60, 45, 30, 15, 10, 5],
		"450-second day emits asynchronous warnings at 60, 45, 30, 15, 10, and 5"
	)
	world.hud.get_start_night_button().pressed.emit()
	await process_frame
	_check(
		cycle.is_night()
		and is_equal_approx(cycle.get_enemy_spawn_modifier(), 1.35)
		and world.hud.get_modifier_label().text == "ZOMBIES +35%",
		"Start Night routes through the host and commits the +35% zombie state"
	)
	manager.placement_rejected.connect(_on_placement_rejected)
	manager.request_structure_placement(StructureCatalog.T1_SUPPORT, first_position)
	await process_frame
	_check(
		_rejections.has(&"night_build_locked") and manager.get_structure_count() == 0,
		"Host rejects construction after the combat wave starts"
	)
	cycle.begin_next_day_authoritative()
	cycle.advance_for_test(DayNightCycle.DAY_DURATION_SECONDS + 0.1)
	await process_frame
	_check(cycle.is_night() and cycle.get_night_number() == 2, "A full 450-second day automatically begins the next night")

	zombie.queue_free()
	audio.stop_all()
	juice.stop_all()
	await create_timer(0.5).timeout
	world.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.1).timeout


func _find_clear_grid_position(
	world_map: BesprenWorldMap2D,
	excluded_positions: Array[Vector2],
	clearance: float
) -> Vector2:
	for cell_y: int in range(-48, 49):
		for cell_x: int in range(-48, 49):
			var candidate: Vector2 = Vector2(float(cell_x) * 64.0, float(cell_y) * 64.0)
			if not world_map.is_position_walkable(candidate, clearance):
				continue
			var separated: bool = true
			for excluded: Vector2 in excluded_positions:
				if candidate.distance_to(excluded) < clearance * 2.5:
					separated = false
					break
			if separated:
				return candidate
	return Vector2.INF


func _on_structure_armed(structure_id: StringName) -> void:
	_armed_structure_id = structure_id


func _on_placement_confirmed(mode: int, structure_id: StringName, world_position: Vector2) -> void:
	_placement_mode = mode
	_placement_structure_id = structure_id
	_placement_position = world_position


func _on_minimap_ping(world_position: Vector2) -> void:
	_minimap_ping = world_position


func _on_warning_requested(seconds_remaining: int) -> void:
	_warnings.append(seconds_remaining)


func _on_placement_rejected(reason: StringName) -> void:
	_rejections.append(reason)


func _on_base_relocated(
	world_position: Vector2,
	refund: PackedInt32Array,
	destroyed_count: int
) -> void:
	_relocation_position = world_position
	_relocation_refund = refund.duplicate()
	_relocation_destroyed_count = destroyed_count


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS | %s" % message)
		return
	_failures += 1
	push_error("FAIL | %s" % message)
