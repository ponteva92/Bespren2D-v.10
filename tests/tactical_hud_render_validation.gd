extends Node2D
## Mobile-renderer capture gate for the 480x270 dashboard and interactive build deck.

const DASHBOARD_PATH: String = "res://artifacts/tactical_hud_dashboard.png"
const DASHBOARD_HELD_PATH: String = "res://artifacts/tactical_hud_dashboard_held.png"
const WARNING_PATH: String = "res://artifacts/tactical_hud_warning.png"
const BOSS_PATH: String = "res://artifacts/tactical_hud_boss_gate.png"
const TOWER_DECK_PATH: String = "res://artifacts/tactical_build_towers.png"
const TRAP_DECK_PATH: String = "res://artifacts/tactical_build_traps.png"
const UTILITY_DECK_PATH: String = "res://artifacts/tactical_build_utilities.png"
const METADATA_PATH: String = "res://artifacts/tactical_hud_render_validation.json"

@onready var hud: GameHUD = %GameHUD


func _ready() -> void:
	hud.set_resource_amounts(120, 100, 80)
	hud.set_day_night_state(367, 1, false)
	hud.set_status("SOLO // PEER 1 // TACTICAL LINK NOMINAL")
	hud.set_minimap_state(
		Vector2.ZERO,
		PackedVector2Array([Vector2(560.0, -320.0), Vector2(-1024.0, 768.0)]),
		PackedVector2Array([
			Vector2(1600.0, -640.0),
			Vector2(1792.0, -640.0),
			Vector2(-2048.0, 1280.0),
		]),
		PackedVector2Array([
			Vector2(256.0, -128.0),
			Vector2(768.0, -512.0),
			Vector2(-896.0, 640.0),
		]),
		PackedInt32Array([0, 1, 2])
	)
	await _capture(DASHBOARD_PATH)
	# A command under the finger. The pressed plate is otherwise only visible
	# while a player is touching it, which is exactly when nobody is looking at
	# a screenshot, so it never got checked before this frame existed.
	hud.get_build_button().button_down.emit()
	await _capture(DASHBOARD_HELD_PATH)
	hud.get_build_button().button_up.emit()
	hud.show_warning(60)
	await _capture(WARNING_PATH)
	hud.set_boss_gate(true, &"goliath", 1)
	await _capture(BOSS_PATH)
	hud.open_build_deck()
	var deck: TacticalBuildDeck = hud.get_build_deck()
	var cards: Array[Button] = deck.get_card_buttons()
	if cards.size() != 8:
		push_error("TACTICAL HUD RENDER FAILED: expected eight cards")
		get_tree().quit(1)
		return
	cards[2].pressed.emit()
	await _capture(TOWER_DECK_PATH)
	deck.select_category_for_test(TacticalBuildDeck.DeckCategory.TRAPS)
	await _capture(TRAP_DECK_PATH)
	deck.select_category_for_test(TacticalBuildDeck.DeckCategory.UTILITIES)
	await _capture(UTILITY_DECK_PATH)
	var metadata: Dictionary = {
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"logical_size": [480, 270],
		"outputs": [
			DASHBOARD_PATH,
			DASHBOARD_HELD_PATH,
			WARNING_PATH,
			BOSS_PATH,
			TOWER_DECK_PATH,
			TRAP_DECK_PATH,
			UTILITY_DECK_PATH,
		],
	}
	var metadata_file: FileAccess = FileAccess.open(METADATA_PATH, FileAccess.WRITE)
	if metadata_file == null:
		push_error("TACTICAL HUD RENDER FAILED: could not write metadata")
		get_tree().quit(1)
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()
	print("TACTICAL HUD RENDER OK | method=%s | driver=%s | captures=7" % [
		RenderingServer.get_current_rendering_method(),
		RenderingServer.get_current_rendering_driver_name(),
	])
	get_tree().quit(0)


func _capture(output_path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("TACTICAL HUD RENDER FAILED: empty viewport")
		get_tree().quit(1)
		return
	if image.get_size() != Vector2i(480, 270):
		image.resize(480, 270, Image.INTERPOLATE_LANCZOS)
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		push_error("TACTICAL HUD RENDER FAILED: %s" % error_string(save_error))
		get_tree().quit(1)
