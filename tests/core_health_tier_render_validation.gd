extends Node2D
## Artifact-only gameplay-scale review for the Base Core health presentation.
##
## It deliberately uses the shipped WorldMap and BaseCore scene at the same
## 0.38 gameplay camera zoom as a match.  It does not start a Co-op session,
## mutate health simulation, or make any resource eligible for export.

const OUTPUT_DIRECTORY: String = "res://artifacts/core_health_tier_validation"
const LOGICAL_CAPTURE_SIZE: Vector2i = Vector2i(480, 270)
const GAMEPLAY_CAMERA_ZOOM: float = 0.38
const REVIEW_ANCHOR: Vector2 = Vector2(-5210.0, 1650.0)

const TIER_CASES: Array[Dictionary] = [
	{
		"id": "healthy",
		"ratio": 1.0,
		"tier": CorePulseDriver.HealthVisualTier.HEALTHY,
	},
	{
		"id": "damaged",
		"ratio": HealthBar2D.HURT_RATIO,
		"tier": CorePulseDriver.HealthVisualTier.DAMAGED,
	},
	{
		"id": "critical",
		"ratio": HealthBar2D.CRITICAL_RATIO,
		"tier": CorePulseDriver.HealthVisualTier.CRITICAL,
	},
	{
		"id": "destroyed",
		"ratio": 0.0,
		"tier": CorePulseDriver.HealthVisualTier.DESTROYED,
	},
]

@onready var core: CorePulseDriver = %BaseCore as CorePulseDriver
@onready var camera: Camera2D = %ValidationCamera as Camera2D

var _native_capture_size: Vector2i = Vector2i.ZERO
var _native_capture_scale: int = 0


func _ready() -> void:
	if not _prepare_output_directory():
		return
	if core == null or camera == null:
		_fail("fixture is missing BaseCore or ValidationCamera")
		return
	if not camera.position.is_equal_approx(REVIEW_ANCHOR):
		_fail("camera must remain at the deterministic wilderness review anchor")
		return
	if not is_equal_approx(camera.zoom.x, GAMEPLAY_CAMERA_ZOOM) or not is_equal_approx(camera.zoom.y, GAMEPLAY_CAMERA_ZOOM):
		_fail("camera must preserve the shipped 0.38 gameplay zoom")
		return
	camera.make_current()
	await get_tree().process_frame
	await get_tree().process_frame
	if not _validate_fixture():
		return
	var reports: Array[Dictionary] = []
	var core_sprite: Sprite2D = core.get_core_sprite()
	var original_sprite_scale: Vector2 = core_sprite.scale
	var collision: CollisionShape2D = core.get_node_or_null(^"StaticBody2D/CollisionShape2D") as CollisionShape2D
	var original_collision_disabled: bool = collision.disabled
	for tier_case: Dictionary in TIER_CASES:
		var case_id: String = String(tier_case["id"])
		var ratio: float = float(tier_case["ratio"])
		var expected_tier: int = int(tier_case["tier"])
		core.set_health_ratio(ratio)
		await get_tree().process_frame
		await get_tree().process_frame
		if not _validate_case(case_id, expected_tier, original_sprite_scale, collision, original_collision_disabled):
			return
		var capture_report: Dictionary = await _capture_case(case_id)
		if capture_report.is_empty():
			return
		capture_report["ratio"] = ratio
		capture_report["tier"] = expected_tier
		reports.append(capture_report)
	_write_metadata(reports)
	print(
		"CORE HEALTH TIER RENDER OK | method=%s | driver=%s | cases=%d | review_required=true"
		% [
			RenderingServer.get_current_rendering_method(),
			RenderingServer.get_current_rendering_driver_name(),
			reports.size(),
		]
	)
	get_tree().quit(0)


func _prepare_output_directory() -> bool:
	var make_directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	if make_directory_error != OK:
		_fail("could not create core-tier artifact directory: %s" % error_string(make_directory_error))
		return false
	return true


func _validate_fixture() -> bool:
	if not core.global_position.is_equal_approx(REVIEW_ANCHOR):
		return _fail_bool("BaseCore drifted from the review anchor")
	if core.get_core_sprite() == null or core.get_health_bar() == null:
		return _fail_bool("BaseCore did not construct its sprite and health readout")
	if core.get_node_or_null(^"AmberLight") as PointLight2D == null:
		return _fail_bool("BaseCore is missing its authored amber light")
	if core.get_node_or_null(^"StaticBody2D/CollisionShape2D") as CollisionShape2D == null:
		return _fail_bool("BaseCore is missing its collision contract")
	return true


func _validate_case(
	case_id: String,
	expected_tier: int,
	original_sprite_scale: Vector2,
	collision: CollisionShape2D,
	original_collision_disabled: bool
) -> bool:
	if core.get_health_visual_tier() != expected_tier:
		return _fail_bool("%s resolved to the wrong visual tier" % case_id)
	var health_bar: HealthBar2D = core.get_health_bar()
	var should_show_bar: bool = expected_tier != CorePulseDriver.HealthVisualTier.DESTROYED
	if health_bar.is_active() != should_show_bar:
		return _fail_bool("%s did not preserve the zero-only objective-bar policy" % case_id)
	if not core.get_core_sprite().scale.is_equal_approx(original_sprite_scale):
		return _fail_bool("%s changed the Core sprite transform" % case_id)
	if collision.disabled != original_collision_disabled:
		return _fail_bool("%s changed the Core collision contract" % case_id)
	var light: PointLight2D = core.get_node_or_null(^"AmberLight") as PointLight2D
	if expected_tier == CorePulseDriver.HealthVisualTier.DESTROYED and not is_zero_approx(light.energy):
		return _fail_bool("destroyed Core retained amber-light energy")
	if expected_tier != CorePulseDriver.HealthVisualTier.DESTROYED and light.energy <= 0.0:
		return _fail_bool("%s Core lost its non-zero amber-light cue" % case_id)
	return true


func _capture_case(case_id: String) -> Dictionary:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("empty viewport for %s" % case_id)
		return {}
	_native_capture_size = image.get_size()
	if (
		_native_capture_size.x <= 0
		or _native_capture_size.y <= 0
		or _native_capture_size.x % LOGICAL_CAPTURE_SIZE.x != 0
		or _native_capture_size.y % LOGICAL_CAPTURE_SIZE.y != 0
	):
		_fail("native viewport for %s is not an integer multiple of 480x270" % case_id)
		return {}
	var horizontal_scale: int = int(float(_native_capture_size.x) / float(LOGICAL_CAPTURE_SIZE.x))
	var vertical_scale: int = int(float(_native_capture_size.y) / float(LOGICAL_CAPTURE_SIZE.y))
	if horizontal_scale != vertical_scale:
		_fail("native viewport scale is non-uniform for %s" % case_id)
		return {}
	_native_capture_scale = horizontal_scale
	if image.get_size() != LOGICAL_CAPTURE_SIZE:
		image.resize(LOGICAL_CAPTURE_SIZE.x, LOGICAL_CAPTURE_SIZE.y, Image.INTERPOLATE_LANCZOS)
	if image.get_size() != LOGICAL_CAPTURE_SIZE:
		_fail("logical capture for %s did not resolve to 480x270" % case_id)
		return {}
	var color_output_path: String = "%s/core_%s.png" % [OUTPUT_DIRECTORY, case_id]
	var grayscale_output_path: String = "%s/core_%s_grayscale.png" % [OUTPUT_DIRECTORY, case_id]
	if image.save_png(ProjectSettings.globalize_path(color_output_path)) != OK:
		_fail("could not save %s" % color_output_path)
		return {}
	if not _save_grayscale(image, grayscale_output_path):
		return {}
	var light: PointLight2D = core.get_node_or_null(^"AmberLight") as PointLight2D
	var core_material: ShaderMaterial = core.get_core_sprite().material as ShaderMaterial
	return {
		"id": case_id,
		"color": color_output_path,
		"grayscale": grayscale_output_path,
		"light_energy": light.energy,
		"core_emission_strength": float(core_material.get_shader_parameter(&"emission_strength")),
	}


func _save_grayscale(source: Image, output_path: String) -> bool:
	var grayscale: Image = source.duplicate()
	for pixel_y: int in range(grayscale.get_height()):
		for pixel_x: int in range(grayscale.get_width()):
			var color: Color = grayscale.get_pixel(pixel_x, pixel_y)
			var luma: float = color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			grayscale.set_pixel(pixel_x, pixel_y, Color(luma, luma, luma, color.a))
	if grayscale.save_png(ProjectSettings.globalize_path(output_path)) != OK:
		_fail("could not save grayscale %s" % output_path)
		return false
	return true


func _write_metadata(reports: Array[Dictionary]) -> void:
	var metadata: Dictionary = {
		"artifact_only": true,
		"runtime_promotion": "forbidden_pending_human_composition_review",
		"capture_scope": "real BaseCore plus WorldMap at gameplay scale; no Co-op session, combat mutation, or export registration",
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"logical_size": [LOGICAL_CAPTURE_SIZE.x, LOGICAL_CAPTURE_SIZE.y],
		"native_capture_size": [_native_capture_size.x, _native_capture_size.y],
		"native_capture_scale": _native_capture_scale,
		"camera_zoom": GAMEPLAY_CAMERA_ZOOM,
		"world_anchor": [REVIEW_ANCHOR.x, REVIEW_ANCHOR.y],
		"cases": reports,
		"review_requirement": "Human visual veto remains required; GPU capture does not certify Android, touch ergonomics, LAN, audio, or performance.",
	}
	var metadata_file: FileAccess = FileAccess.open(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY + "/core_health_tier_validation.json"),
		FileAccess.WRITE
	)
	if metadata_file == null:
		_fail("could not write core-tier metadata")
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()


func _fail_bool(message: String) -> bool:
	_fail(message)
	return false


func _fail(message: String) -> void:
	push_error("CORE HEALTH TIER RENDER FAILED: %s" % message)
	get_tree().quit(1)
