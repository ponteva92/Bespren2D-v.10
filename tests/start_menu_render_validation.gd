extends Control
## GPU review gate for the live 480x270 StartMenu scene.
##
## Captures the actual boot-menu hierarchy twice so visual review covers both
## survivor selections and the same touch targets players receive at launch.
## A physical window may use an integer multiple of the logical canvas; that
## native size is validated and recorded before the review image is downsampled.

const HEIKKI_OUTPUT_PATH: String = "res://artifacts/start_menu_heikki_validation.png"
const SHANE_OUTPUT_PATH: String = "res://artifacts/start_menu_shane_validation.png"
const SAFE_INSET_OUTPUT_PATH: String = "res://artifacts/start_menu_safe_inset_validation.png"
const METADATA_PATH: String = "res://artifacts/start_menu_render_validation.json"
const LOGICAL_CAPTURE_SIZE: Vector2i = Vector2i(480, 270)
const SYNTHETIC_SAFE_RECT: Rect2 = Rect2(16.0, 8.0, 448.0, 254.0)

@onready var menu: StartMenu = %StartMenu

var _native_capture_size: Vector2i = Vector2i.ZERO
var _native_capture_scale: int = 0


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var default_safe_rect: Rect2 = menu.get_layout_safe_rect()
	if not _validate_layout(default_safe_rect, "device safe area"):
		return
	var heikki_captured: bool = await _capture(HEIKKI_OUTPUT_PATH)
	if not heikki_captured:
		return
	menu.select_character(&"shane")
	await get_tree().process_frame
	var shane_captured: bool = await _capture(SHANE_OUTPUT_PATH)
	if not shane_captured:
		return
	menu.set_safe_area_override_for_validation(SYNTHETIC_SAFE_RECT)
	await get_tree().process_frame
	if not _validate_layout(SYNTHETIC_SAFE_RECT, "synthetic landscape inset"):
		return
	var safe_inset_captured: bool = await _capture(SAFE_INSET_OUTPUT_PATH)
	if not safe_inset_captured:
		return
	_store_metadata(default_safe_rect)
	print(
		"START MENU RENDER OK | method=%s | driver=%s | captures=3"
		% [
			RenderingServer.get_current_rendering_method(),
			RenderingServer.get_current_rendering_driver_name(),
		]
	)
	get_tree().quit(0)


func _validate_layout(safe_rect: Rect2, context: String) -> bool:
	if menu.size != Vector2(480.0, 270.0):
		return _fail("menu did not resolve to the 480x270 logical viewport")
	if not safe_rect.has_area():
		return _fail("%s has an empty safe rectangle" % context)
	if not safe_rect.encloses(menu.get_layout_content_rect()):
		return _fail("%s does not contain the menu content inset" % context)
	var controls: Array[Control] = [
		menu.get_node("HeikkiCard") as Control,
		menu.get_node("ShaneCard") as Control,
		menu.get_node("AddressEdit") as Control,
		menu.get_node("SoloButton") as Control,
		menu.get_node("HostButton") as Control,
		menu.get_node("JoinButton") as Control,
	]
	for control: Control in controls:
		if control.size.x < 44.0 or control.size.y < 44.0:
			return _fail("%s violates the 44px touch contract" % control.name)
		if not safe_rect.encloses(Rect2(control.position, control.size)):
			return _fail("%s escapes the %s" % [control.name, context])
		if control.focus_mode != Control.FOCUS_ALL:
			return _fail("%s lost keyboard focus support" % control.name)
	var interactive_rects: Dictionary = menu.get_interactive_layout_rects()
	var interactive_names: Array = interactive_rects.keys()
	for first_index: int in range(interactive_names.size()):
		var first_name: StringName = interactive_names[first_index] as StringName
		var first_rect: Rect2 = interactive_rects[first_name]
		for second_index: int in range(first_index + 1, interactive_names.size()):
			var second_name: StringName = interactive_names[second_index] as StringName
			var second_rect: Rect2 = interactive_rects[second_name]
			if first_rect.intersects(second_rect):
				return _fail("%s overlaps %s in %s" % [first_name, second_name, context])
	var active_card_path: String = "ShaneCard/ActiveChip" if menu.selected_character == &"shane" else "HeikkiCard/ActiveChip"
	if not (menu.get_node(active_card_path) as Control).visible:
		return _fail("%s state has no explicit active marker" % menu.selected_character)
	var selected_signal_path: String = "ShaneCard/SignalField" if menu.selected_character == &"shane" else "HeikkiCard/SignalField"
	var selected_signal: Control = menu.get_node(selected_signal_path) as Control
	if selected_signal == null or not bool(selected_signal.call(&"is_active")):
		return _fail("%s state has no active original identity signal field" % menu.selected_character)
	if selected_signal.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return _fail("%s identity signal field can capture input" % menu.selected_character)
	return true


func _capture(output_path: String) -> bool:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return _fail("empty viewport for %s" % output_path)
	_native_capture_size = image.get_size()
	if (
		_native_capture_size.x <= 0
		or _native_capture_size.y <= 0
		or _native_capture_size.x % LOGICAL_CAPTURE_SIZE.x != 0
		or _native_capture_size.y % LOGICAL_CAPTURE_SIZE.y != 0
	):
		return _fail(
			"native viewport for %s is %s; expected an integer scale of %s"
			% [output_path, _native_capture_size, LOGICAL_CAPTURE_SIZE]
		)
	var horizontal_scale: int = int(
		float(_native_capture_size.x) / float(LOGICAL_CAPTURE_SIZE.x)
	)
	var vertical_scale: int = int(
		float(_native_capture_size.y) / float(LOGICAL_CAPTURE_SIZE.y)
	)
	if horizontal_scale != vertical_scale:
		return _fail(
			"native viewport for %s is non-uniform (%dx%d) over %s"
			% [output_path, horizontal_scale, vertical_scale, LOGICAL_CAPTURE_SIZE]
		)
	_native_capture_scale = horizontal_scale
	if _native_capture_size != LOGICAL_CAPTURE_SIZE:
		image.resize(LOGICAL_CAPTURE_SIZE.x, LOGICAL_CAPTURE_SIZE.y, Image.INTERPOLATE_LANCZOS)
	if image.get_size() != LOGICAL_CAPTURE_SIZE:
		return _fail("logical review image for %s is not %s" % [output_path, LOGICAL_CAPTURE_SIZE])
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		return _fail("could not save %s (%s)" % [output_path, error_string(save_error)])
	return true


func _store_metadata(default_safe_rect: Rect2) -> void:
	var metadata: Dictionary = {
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"logical_size": [480, 270],
		"native_capture_size": [_native_capture_size.x, _native_capture_size.y],
		"native_capture_scale": _native_capture_scale,
		"outputs": [HEIKKI_OUTPUT_PATH, SHANE_OUTPUT_PATH, SAFE_INSET_OUTPUT_PATH],
		"review_states": ["heikki_selected", "shane_selected", "shane_selected_safe_inset"],
		"art_direction": "original vector survivor identity fields; no raw Addons UI or portrait asset promoted",
		"device_safe_rect": _rect_to_array(default_safe_rect),
		"synthetic_safe_rect": _rect_to_array(SYNTHETIC_SAFE_RECT),
		"safe_inset_capture": "artifact-only landscape notch/camera-inset review",
	}
	var metadata_file: FileAccess = FileAccess.open(METADATA_PATH, FileAccess.WRITE)
	if metadata_file == null:
		_fail("could not write render metadata")
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()


func _rect_to_array(rect: Rect2) -> Array[float]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _fail(reason: String) -> bool:
	push_error("START MENU RENDER FAILED: %s" % reason)
	get_tree().quit(1)
	return false
