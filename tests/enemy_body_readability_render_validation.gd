extends Node2D
## GPU/mobile-renderer evidence for the boss body-first presentation layer.
##
## This is deliberately artifact-only: it creates non-authoritative enemy shells
## against the actual WorldMap at the production 0.38 camera, never starts a
## horde, combat, or session, and does not add any resource to runtime export
## closure. It is a human-veto review aid, not a claim of device certification.

const OUTPUT_DIRECTORY: String = "res://artifacts/enemy_body_readability_validation"
const CONTROL_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/boss_bodies_control_without_rim.png"
const IDLE_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/boss_bodies_idle.png"
const ACTIVE_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/boss_bodies_active_cue.png"
const CONTROL_GRAYSCALE_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/boss_bodies_control_without_rim_grayscale.png"
const IDLE_GRAYSCALE_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/boss_bodies_idle_grayscale.png"
const ACTIVE_GRAYSCALE_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/boss_bodies_active_cue_grayscale.png"
const METADATA_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/enemy_body_readability_validation.json"

const LOGICAL_CAPTURE_SIZE: Vector2i = Vector2i(480, 270)
const GAMEPLAY_CAMERA_ZOOM: float = 0.38
const REVIEW_ANCHOR: Vector2 = Vector2(-5200.0, 1800.0)
const BOSS_VARIANTS: Array[int] = [
	EnemyAgent2D.Variant.GOLIATH,
	EnemyAgent2D.Variant.CARRIER,
	EnemyAgent2D.Variant.SPLITTER,
	EnemyAgent2D.Variant.OVERLORD,
]
const BOSS_OFFSETS: Array[Vector2] = [
	Vector2(-260.0, -140.0),
	Vector2(170.0, -140.0),
	Vector2(-230.0, 190.0),
	Vector2(180.0, 190.0),
]

@onready var world_map: BesprenWorldMap2D = %WorldMap2D as BesprenWorldMap2D
@onready var y_sort_world: Node2D = %YSortWorld
@onready var camera: Camera2D = %ValidationCamera
@onready var state_label: Label = %StateLabel as Label

var _subjects: Array[EnemyAgent2D] = []
var _native_capture_size: Vector2i = Vector2i.ZERO
var _native_capture_scale: int = 0


func _ready() -> void:
	if not _prepare_output_directory():
		return
	if world_map == null or y_sort_world == null or camera == null or state_label == null:
		_fail("fixture is missing the live WorldMap, Y-sort root, camera, or artifact label")
		return
	if not is_equal_approx(camera.zoom.x, GAMEPLAY_CAMERA_ZOOM) or not is_equal_approx(camera.zoom.y, GAMEPLAY_CAMERA_ZOOM):
		_fail("fixture camera must retain the 0.38 gameplay zoom")
		return
	camera.make_current()
	await get_tree().process_frame
	if not world_map.is_position_walkable(REVIEW_ANCHOR, 0.0):
		_fail("review anchor must remain inside the playable WorldMap")
		return
	if not _spawn_boss_subjects() or not _verify_subject_contracts():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not _set_body_silhouette_visible(false):
		return
	_set_idle_review_state()
	state_label.text = "ARTIFACT CONTROL // SAME BODIES // RIM DISABLED"
	if not await _capture(CONTROL_OUTPUT_PATH, CONTROL_GRAYSCALE_OUTPUT_PATH):
		return
	if not _set_body_silhouette_visible(true):
		return
	_set_idle_review_state()
	if not await _capture(IDLE_OUTPUT_PATH, IDLE_GRAYSCALE_OUTPUT_PATH):
		return
	_set_active_review_state()
	if not await _capture(ACTIVE_OUTPUT_PATH, ACTIVE_GRAYSCALE_OUTPUT_PATH):
		return
	_write_metadata()
	print(
		"ENEMY BODY READABILITY CAPTURE COMPLETE | method=%s | driver=%s | zoom=%.2f | review_required=true"
		% [
			RenderingServer.get_current_rendering_method(),
			RenderingServer.get_current_rendering_driver_name(),
			GAMEPLAY_CAMERA_ZOOM,
		]
	)
	get_tree().quit(0)


func _prepare_output_directory() -> bool:
	var make_directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	if make_directory_error != OK:
		_fail("could not create artifact directory: %s" % error_string(make_directory_error))
		return false
	return true


func _spawn_boss_subjects() -> bool:
	if BOSS_VARIANTS.size() != BOSS_OFFSETS.size():
		_fail("boss variant and position inventory mismatch")
		return false
	for subject_index: int in range(BOSS_VARIANTS.size()):
		var variant: int = BOSS_VARIANTS[subject_index]
		var subject: EnemyAgent2D = EnemyAgent2D.new()
		var world_position: Vector2 = REVIEW_ANCHOR + BOSS_OFFSETS[subject_index]
		## These are remote visual shells. They cannot publish a horde action,
		## damage a base, or create a network/snapshot side effect.
		subject.configure(
			6000 + subject_index,
			variant,
			world_position,
			1800,
			24,
			54.0,
			REVIEW_ANCHOR,
			null,
			null,
			false
		)
		y_sort_world.add_child(subject)
		_subjects.append(subject)
	return true


func _verify_subject_contracts() -> bool:
	if _subjects.size() != BOSS_VARIANTS.size():
		_fail("fixture did not create every requested boss body")
		return false
	for subject_index: int in range(_subjects.size()):
		var subject: EnemyAgent2D = _subjects[subject_index]
		var view: EnemyPresentation2D = subject.get_presentation_view()
		if (
			subject.variant != BOSS_VARIANTS[subject_index]
			or view == null
			or not view.has_loaded_visual()
			or view.get_visual_copy_count() != 1
			or view.get_body_silhouette_copy_count() != 1
			or not view.body_silhouette_uses_primary_frames()
			or not view.is_body_silhouette_synchronized()
			or not view.find_children("*", "PointLight2D", true, false).is_empty()
			or not view.find_children("*", "GPUParticles2D", true, false).is_empty()
			or not view.find_children("*", "CPUParticles2D", true, false).is_empty()
		):
			_fail("boss %d did not retain the bounded body-first presentation contract" % subject_index)
			return false
	return true


func _set_idle_review_state() -> void:
	state_label.text = "ARTIFACT REVIEW // BOSS BODIES FIRST // IDLE"
	for subject: EnemyAgent2D in _subjects:
		var view: EnemyPresentation2D = subject.get_presentation_view()
		view.play_local_event(EnemyPresentation2D.PresentationEvent.NONE)
		view.update_motion(0.0, false, 1.0)


func _set_body_silhouette_visible(visible: bool) -> bool:
	for subject: EnemyAgent2D in _subjects:
		var view: EnemyPresentation2D = subject.get_presentation_view()
		var silhouette: AnimatedSprite2D = view.get_node_or_null(
			^"PresentationContent/BodySilhouette"
		) as AnimatedSprite2D
		if silhouette == null:
			_fail("a boss presentation is missing its named body silhouette layer")
			return false
		silhouette.visible = visible
	return true


func _set_active_review_state() -> void:
	state_label.text = "ARTIFACT REVIEW // BODY RIM + ACTIVE THREAT CUE"
	for subject_index: int in range(_subjects.size()):
		var view: EnemyPresentation2D = _subjects[subject_index].get_presentation_view()
		if not view.play_local_event(
			EnemyPresentation2D.PresentationEvent.TAUNT,
			(subject_index + 2) % ActorFacing.ROW_COUNT
		):
			_fail("boss %d could not enter its already-authored taunt clip" % subject_index)
			return
		view.update_motion(0.0, false, 1.0)


func _capture(output_path: String, grayscale_output_path: String) -> bool:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return _fail_bool("empty viewport for %s" % output_path)
	_native_capture_size = image.get_size()
	if (
		_native_capture_size.x <= 0
		or _native_capture_size.y <= 0
		or _native_capture_size.x % LOGICAL_CAPTURE_SIZE.x != 0
		or _native_capture_size.y % LOGICAL_CAPTURE_SIZE.y != 0
	):
		return _fail_bool(
			"native viewport for %s is %s; expected an integer scale of %s"
			% [output_path, _native_capture_size, LOGICAL_CAPTURE_SIZE]
		)
	var horizontal_scale: int = int(float(_native_capture_size.x) / float(LOGICAL_CAPTURE_SIZE.x))
	var vertical_scale: int = int(float(_native_capture_size.y) / float(LOGICAL_CAPTURE_SIZE.y))
	if horizontal_scale != vertical_scale:
		return _fail_bool("native viewport scale is non-uniform for %s" % output_path)
	_native_capture_scale = horizontal_scale
	if image.get_size() != LOGICAL_CAPTURE_SIZE:
		image.resize(LOGICAL_CAPTURE_SIZE.x, LOGICAL_CAPTURE_SIZE.y, Image.INTERPOLATE_LANCZOS)
	if image.get_size() != LOGICAL_CAPTURE_SIZE:
		return _fail_bool("logical capture did not resolve to 480x270 for %s" % output_path)
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		return _fail_bool("could not save %s (%s)" % [output_path, error_string(save_error)])
	return _save_grayscale(image, grayscale_output_path)


func _save_grayscale(source: Image, output_path: String) -> bool:
	var grayscale: Image = source.duplicate()
	grayscale.convert(Image.FORMAT_RGBA8)
	for pixel_y: int in range(grayscale.get_height()):
		for pixel_x: int in range(grayscale.get_width()):
			var color: Color = grayscale.get_pixel(pixel_x, pixel_y)
			var luma: float = color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			grayscale.set_pixel(pixel_x, pixel_y, Color(luma, luma, luma, color.a))
	var save_error: Error = grayscale.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		return _fail_bool("could not save grayscale capture %s (%s)" % [output_path, error_string(save_error)])
	return true


func _write_metadata() -> void:
	var metadata: Dictionary = {
		"artifact_only": true,
		"runtime_promotion": "test-only evidence; no production scene or export closure change",
		"capture_scope": "direct non-authoritative EnemyAgent2D presentation shells; no CoopSession, HordeDirector, base damage, combat simulation, collision mutation, or network traffic",
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"logical_size": [LOGICAL_CAPTURE_SIZE.x, LOGICAL_CAPTURE_SIZE.y],
		"native_capture_size": [_native_capture_size.x, _native_capture_size.y],
		"native_capture_scale": _native_capture_scale,
		"camera_zoom": GAMEPLAY_CAMERA_ZOOM,
		"world_anchor": [REVIEW_ANCHOR.x, REVIEW_ANCHOR.y],
		"variants": [&"goliath", &"carrier", &"splitter", &"overlord"],
		"body_first_treatment": {
			"scope": "boss_presentation only",
			"source": "same baked SpriteFrames and frame as the foreground body",
			"outline_scale": EnemyPresentation2D.BOSS_BODY_SILHOUETTE_SCALE,
			"outline_alpha": EnemyPresentation2D.BOSS_BODY_SILHOUETTE_ALPHA,
			"marker_policy": "existing boss-idle cue stays subdued; active cue remains event/status-only",
			"forbidden": ["raw Addons promotion", "new body texture", "PointLight2D", "particles", "RPC", "snapshot schema change"],
		},
		"outputs": {
			"control_without_rim": CONTROL_OUTPUT_PATH,
			"control_without_rim_grayscale": CONTROL_GRAYSCALE_OUTPUT_PATH,
			"idle": IDLE_OUTPUT_PATH,
			"active_cue": ACTIVE_OUTPUT_PATH,
			"idle_grayscale": IDLE_GRAYSCALE_OUTPUT_PATH,
			"active_cue_grayscale": ACTIVE_GRAYSCALE_OUTPUT_PATH,
		},
		"review_requirement": "Human visual veto is required. A successful desktop Mobile/Vulkan capture does not certify Android thermal/performance, touch ergonomics, LAN, audio, or AAA readiness.",
	}
	var metadata_file: FileAccess = FileAccess.open(
		ProjectSettings.globalize_path(METADATA_OUTPUT_PATH),
		FileAccess.WRITE
	)
	if metadata_file == null:
		_fail("could not write artifact metadata")
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()


func _fail_bool(message: String) -> bool:
	_fail(message)
	return false


func _fail(message: String) -> void:
	push_error("ENEMY BODY READABILITY RENDER FAILED: %s" % message)
	get_tree().quit(1)
