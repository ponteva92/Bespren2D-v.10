extends Node2D
## Artifact-only Mobile/Vulkan composition gate for the shipped world VFX.
##
## The focused VFX contract test proves pooling and bounds; this fixture instead
## makes the pixel hierarchy reviewable at the actual 0.38 match camera.  It
## deliberately starts no session, combat, player authority, or export path.

const OUTPUT_DIRECTORY: String = "res://artifacts/vfx_gameplay_scale_validation"
const LOGICAL_CAPTURE_SIZE: Vector2i = Vector2i(480, 270)
const GAMEPLAY_CAMERA_ZOOM: float = 0.38
const REVIEW_ANCHOR: Vector2 = Vector2(-5210.0, 1650.0)

const COMBAT_CASES: Array[Dictionary] = [
	{
		"name": "MUZZLE",
		"effect": VfxDirector.Effect.MUZZLE_FLASH,
		"world_position": Vector2(-5480.0, 1510.0),
		"direction": Vector2.RIGHT,
		"tint": Color(1.0, 0.84, 0.28),
	},
	{
		"name": "IMPACT",
		"effect": VfxDirector.Effect.IMPACT_SPARK,
		"world_position": Vector2(-5150.0, 1690.0),
		"direction": Vector2(0.5, -0.4),
		"tint": Color(1.0, 0.84, 0.28),
	},
	{
		"name": "DEATH",
		"effect": VfxDirector.Effect.DEATH_BURST,
		"world_position": Vector2(-4850.0, 1510.0),
		"direction": Vector2.ZERO,
		"tint": Color(0.56, 0.82, 0.46),
	},
]

const PRODUCTION_CASES: Array[Dictionary] = [
	{
		"name": "GATHER",
		"effect": VfxDirector.Effect.GATHER_BURST,
		"world_position": Vector2(-5480.0, 1510.0),
		"direction": Vector2.UP,
		"tint": Color(0.87, 0.67, 0.30),
	},
	{
		"name": "BUILD",
		"effect": VfxDirector.Effect.BUILD_POOF,
		"world_position": Vector2(-5150.0, 1690.0),
		"direction": Vector2.ZERO,
		"tint": Color.WHITE,
	},
	{
		"name": "PICKUP",
		"effect": VfxDirector.Effect.PICKUP_SPARKLE,
		"world_position": Vector2(-4850.0, 1510.0),
		"direction": Vector2.UP,
		"tint": Color(0.33, 0.81, 0.88),
	},
	{
		"name": "FOOTSTEP",
		"effect": VfxDirector.Effect.FOOTSTEP_DUST,
		"world_position": Vector2(-4850.0, 1830.0),
		"direction": Vector2.RIGHT,
		"tint": Color.WHITE,
	},
]

@onready var camera: Camera2D = %ValidationCamera as Camera2D
@onready var overlay: CanvasLayer = get_node_or_null(^"Overlay") as CanvasLayer

var _director: VfxDirector
var _native_capture_size: Vector2i = Vector2i.ZERO


func _ready() -> void:
	if not _prepare_output_directory():
		return
	if camera == null:
		_fail("fixture is missing its validation camera")
		return
	if not camera.position.is_equal_approx(REVIEW_ANCHOR):
		_fail("camera drifted from the deterministic review anchor")
		return
	if not is_equal_approx(camera.zoom.x, GAMEPLAY_CAMERA_ZOOM) or not is_equal_approx(camera.zoom.y, GAMEPLAY_CAMERA_ZOOM):
		_fail("camera must use the shipped 0.38 gameplay zoom")
		return
	camera.make_current()
	_director = VfxDirector.new()
	_director.name = &"VfxReviewDirector"
	add_child(_director)
	await get_tree().process_frame
	await get_tree().process_frame
	if _director.get_child_count() != VfxDirector.POOL_SIZE:
		_fail("VFX director did not construct its bounded emitter pool")
		return
	var reports: Array[Dictionary] = []
	var combat_report: Dictionary = await _play_and_capture("combat", COMBAT_CASES)
	if combat_report.is_empty():
		return
	reports.append(combat_report)
	_director.stop_all()
	await get_tree().process_frame
	var production_report: Dictionary = await _play_and_capture("production", PRODUCTION_CASES)
	if production_report.is_empty():
		return
	reports.append(production_report)
	_write_metadata(reports)
	print("VFX GAMEPLAY-SCALE RENDER OK | method=%s | driver=%s | cases=%d | review_required=true" % [
		RenderingServer.get_current_rendering_method(),
		RenderingServer.get_current_rendering_driver_name(),
		reports.size(),
	])
	get_tree().quit(0)


func _prepare_output_directory() -> bool:
	var result: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	if result != OK:
		_fail("could not create VFX artifact directory: %s" % error_string(result))
		return false
	return true


func _play_and_capture(case_id: String, effect_cases: Array[Dictionary]) -> Dictionary:
	for effect_case: Dictionary in effect_cases:
		var world_position: Vector2 = effect_case["world_position"] as Vector2
		var direction: Vector2 = effect_case["direction"] as Vector2
		var effect: VfxDirector.Effect = effect_case["effect"] as VfxDirector.Effect
		var tint: Color = effect_case["tint"] as Color
		_director.play(effect, world_position, direction, tint)
		_add_label(String(effect_case["name"]), _world_to_screen(world_position) + Vector2(-28.0, 27.0))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("empty viewport for %s" % case_id)
		return {}
	if not _normalise_to_logical_size(image, case_id):
		return {}
	var color_path: String = "%s/%s.png" % [OUTPUT_DIRECTORY, case_id]
	var grayscale_path: String = "%s/%s_grayscale.png" % [OUTPUT_DIRECTORY, case_id]
	if image.save_png(ProjectSettings.globalize_path(color_path)) != OK:
		_fail("could not write %s" % color_path)
		return {}
	if not _save_grayscale(image, grayscale_path):
		return {}
	for label: Node in overlay.get_children():
		if label.name.begins_with("ReviewLabel_"):
			label.queue_free()
	return {
		"id": case_id,
		"effects": _case_names(effect_cases),
		"color": color_path,
		"grayscale": grayscale_path,
	}


func _normalise_to_logical_size(image: Image, case_id: String) -> bool:
	_native_capture_size = image.get_size()
	if _native_capture_size.x <= 0 or _native_capture_size.y <= 0:
		_fail("invalid native viewport for %s" % case_id)
		return false
	if _native_capture_size.x % LOGICAL_CAPTURE_SIZE.x != 0 or _native_capture_size.y % LOGICAL_CAPTURE_SIZE.y != 0:
		_fail("native viewport for %s is not an integer multiple of 480x270" % case_id)
		return false
	var horizontal_scale: int = int(float(_native_capture_size.x) / float(LOGICAL_CAPTURE_SIZE.x))
	var vertical_scale: int = int(float(_native_capture_size.y) / float(LOGICAL_CAPTURE_SIZE.y))
	if horizontal_scale != vertical_scale:
		_fail("native viewport for %s has non-uniform scale" % case_id)
		return false
	if image.get_size() != LOGICAL_CAPTURE_SIZE:
		image.resize(LOGICAL_CAPTURE_SIZE.x, LOGICAL_CAPTURE_SIZE.y, Image.INTERPOLATE_LANCZOS)
	if image.get_size() != LOGICAL_CAPTURE_SIZE:
		_fail("logical output for %s is not 480x270" % case_id)
		return false
	return true


func _world_to_screen(world_position: Vector2) -> Vector2:
	return Vector2(240.0, 135.0) + (world_position - REVIEW_ANCHOR) * GAMEPLAY_CAMERA_ZOOM


func _case_names(effect_cases: Array[Dictionary]) -> Array[String]:
	var names: Array[String] = []
	for effect_case: Dictionary in effect_cases:
		names.append(String(effect_case["name"]))
	return names


func _add_label(label_text: String, position: Vector2) -> void:
	if overlay == null:
		return
	var label: Label = Label.new()
	label.name = &"ReviewLabel_%d" % overlay.get_child_count()
	label.position = position
	label.size = Vector2(56.0, 10.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = label_text
	label.add_theme_font_size_override(&"font_size", 6)
	label.add_theme_color_override(&"font_color", Color("c8d5c4"))
	label.add_theme_color_override(&"font_outline_color", Color("071009"))
	label.add_theme_constant_override(&"outline_size", 1)
	overlay.add_child(label)


func _save_grayscale(source: Image, output_path: String) -> bool:
	var grayscale: Image = source.duplicate()
	for pixel_y: int in range(grayscale.get_height()):
		for pixel_x: int in range(grayscale.get_width()):
			var color: Color = grayscale.get_pixel(pixel_x, pixel_y)
			var luma: float = color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			grayscale.set_pixel(pixel_x, pixel_y, Color(luma, luma, luma, color.a))
	if grayscale.save_png(ProjectSettings.globalize_path(output_path)) != OK:
		_fail("could not write %s" % output_path)
		return false
	return true


func _write_metadata(reports: Array[Dictionary]) -> void:
	var metadata: Dictionary = {
		"artifact_only": true,
		"runtime_promotion": "forbidden_pending_human_visual_veto",
		"capture_scope": "real WorldMap plus VfxDirector at gameplay scale; no session, player, authority, combat, or export mutation",
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"logical_size": [LOGICAL_CAPTURE_SIZE.x, LOGICAL_CAPTURE_SIZE.y],
		"native_capture_size": [_native_capture_size.x, _native_capture_size.y],
		"camera_zoom": GAMEPLAY_CAMERA_ZOOM,
		"world_anchor": [REVIEW_ANCHOR.x, REVIEW_ANCHOR.y],
		"cases": reports,
		"review_requirement": "Human visual veto remains required; desktop GPU capture does not certify Android, touch, LAN, audio, or performance.",
	}
	var file: FileAccess = FileAccess.open(ProjectSettings.globalize_path(OUTPUT_DIRECTORY + "/vfx_gameplay_scale_validation.json"), FileAccess.WRITE)
	if file == null:
		_fail("could not write VFX review metadata")
		return
	file.store_string(JSON.stringify(metadata, "\t"))
	file.close()


func _fail(message: String) -> void:
	push_error("VFX GAMEPLAY-SCALE RENDER FAILED: %s" % message)
	get_tree().quit(1)
