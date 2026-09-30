extends Node2D
## Label-free, artifact-only body-first A/B review at the real 0.38 gameplay camera.
##
## Each capture contains one remote survivor and one boss in a stable WorldMap
## position. The control hides only BodySilhouette; all baked foreground art,
## boss-idle marker policy, terrain, camera, and canvas grade remain identical.
## It intentionally uses a neutral CanvasModulate day/night grade rather than
## enabling a flashlight or adding a test light, so light direction cannot mask
## the body rim being reviewed.

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/network_player.tscn")

const OUTPUT_DIRECTORY: String = "res://artifacts/enemy_body_combat_readability_validation"
const METADATA_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/enemy_body_combat_readability_validation.json"
const LOGICAL_CAPTURE_SIZE: Vector2i = Vector2i(480, 270)
const GAMEPLAY_CAMERA_ZOOM: float = 0.38
const REVIEW_ANCHOR: Vector2 = Vector2(-5200.0, 1800.0)
const HERO_OFFSET: Vector2 = Vector2(-156.0, 88.0)
const BOSS_OFFSET: Vector2 = Vector2(172.0, -42.0)
## Derived from the fixed 0.38 camera and BOSS_OFFSET. This is intentionally
## wider than every body, so the numeric delta describes the gameplay-scale
## body neighborhood without relying on a fragile per-frame alpha bound.
const BOSS_REVIEW_ROI: Rect2i = Rect2i(255, 64, 101, 111)
const LUMA_DELTA_THRESHOLD: float = 0.015

const BOSS_VARIANTS: Array[int] = [
	EnemyAgent2D.Variant.GOLIATH,
	EnemyAgent2D.Variant.CARRIER,
	EnemyAgent2D.Variant.SPLITTER,
	EnemyAgent2D.Variant.OVERLORD,
]
const BOSS_IDS: Array[StringName] = [
	&"goliath",
	&"carrier",
	&"splitter",
	&"overlord",
]

@onready var neutral_canvas_modulate: CanvasModulate = %NeutralCanvasModulate
@onready var world_map: BesprenWorldMap2D = %WorldMap2D as BesprenWorldMap2D
@onready var y_sort_world: Node2D = %YSortWorld
@onready var camera: Camera2D = %ValidationCamera

var _hero: PlayerAvatar
var _subjects: Array[EnemyAgent2D] = []
var _native_capture_size: Vector2i = Vector2i.ZERO
var _native_capture_scale: int = 0
var _outputs: Dictionary = {}


func _ready() -> void:
	if not _prepare_output_directory():
		return
	if neutral_canvas_modulate == null or world_map == null or y_sort_world == null or camera == null:
		_fail("fixture is missing neutral grading, WorldMap, Y-sort, or camera")
		return
	if not is_equal_approx(camera.zoom.x, GAMEPLAY_CAMERA_ZOOM) or not is_equal_approx(camera.zoom.y, GAMEPLAY_CAMERA_ZOOM):
		_fail("fixture camera must retain the 0.38 gameplay zoom")
		return
	camera.make_current()
	await get_tree().process_frame
	if not world_map.is_position_walkable(REVIEW_ANCHOR, 0.0):
		_fail("review anchor must remain inside the playable WorldMap")
		return
	if not _spawn_character_relative_subjects():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not _verify_subject_contracts():
		return
	if not await _capture_all_boss_reviews():
		return
	_write_metadata()
	print(
		"ENEMY BODY COMBAT READABILITY CAPTURE COMPLETE | method=%s | driver=%s | bosses=%d | captures=%d"
		% [
			RenderingServer.get_current_rendering_method(),
			RenderingServer.get_current_rendering_driver_name(),
			BOSS_VARIANTS.size(),
			_outputs.size(),
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


func _spawn_character_relative_subjects() -> bool:
	_hero = PLAYER_SCENE.instantiate() as PlayerAvatar
	if _hero == null:
		_fail("could not instantiate the live survivor presentation scene")
		return false
	## A remote visual subject has no local camera/input authority and cannot
	## publish gameplay state. It supplies the player-scale reference only.
	_hero.configure(1, &"heikki", REVIEW_ANCHOR + HERO_OFFSET, false)
	y_sort_world.add_child(_hero)
	_hero.set_aim_direction(Vector2.RIGHT, false)
	for subject_index: int in range(BOSS_VARIANTS.size()):
		var subject: EnemyAgent2D = EnemyAgent2D.new()
		subject.configure(
			7000 + subject_index,
			BOSS_VARIANTS[subject_index],
			REVIEW_ANCHOR + BOSS_OFFSET,
			1800,
			24,
			54.0,
			REVIEW_ANCHOR,
			null,
			null,
			false
		)
		subject.visible = false
		y_sort_world.add_child(subject)
		## Hold these evidence subjects in one exact idle frame. That isolates the
		## only A/B difference to BodySilhouette rather than allowing an animated
		## limb to advance between the control and rim captures.
		subject.set_physics_process(false)
		_subjects.append(subject)
	return true


func _verify_subject_contracts() -> bool:
	if _hero == null or not _hero.uses_baked_actor_presentation():
		_fail("review hero did not bind the live baked actor presentation")
		return false
	if _subjects.size() != BOSS_VARIANTS.size() or BOSS_IDS.size() != BOSS_VARIANTS.size():
		_fail("boss capture inventory is inconsistent")
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
			_fail("boss %s broke the bounded body-first contract" % BOSS_IDS[subject_index])
			return false
	return true


func _capture_all_boss_reviews() -> bool:
	for subject_index: int in range(_subjects.size()):
		if not _select_subject(subject_index):
			return false
		var boss_id: String = String(BOSS_IDS[subject_index])
		for night_review: bool in [false, true]:
			_set_neutral_time_of_day(night_review)
			if not _set_body_silhouette_visible(subject_index, false):
				return false
			if not _set_idle_pose(subject_index):
				return false
			if not await _capture_review(boss_id, night_review, "control_without_rim"):
				return false
			if not _set_body_silhouette_visible(subject_index, true):
				return false
			if not _set_idle_pose(subject_index):
				return false
			if not await _capture_review(boss_id, night_review, "idle_with_rim"):
				return false
	return true


func _select_subject(selected_index: int) -> bool:
	if selected_index < 0 or selected_index >= _subjects.size():
		_fail("selected boss subject is outside the capture inventory")
		return false
	for subject_index: int in range(_subjects.size()):
		_subjects[subject_index].visible = subject_index == selected_index
	return true


func _set_neutral_time_of_day(night_review: bool) -> void:
	neutral_canvas_modulate.color = (
		NightAtmosphere2D.SAPPHIRE_NIGHT_COLOR
		if night_review
		else NightAtmosphere2D.DAY_COLOR
	)


func _set_idle_pose(subject_index: int) -> bool:
	var view: EnemyPresentation2D = _subjects[subject_index].get_presentation_view()
	if not view.play_local_event(EnemyPresentation2D.PresentationEvent.NONE):
		_fail("boss %s could not enter its idle presentation" % BOSS_IDS[subject_index])
		return false
	view.update_motion(0.0, false, 1.0)
	var foreground: AnimatedSprite2D = view.get_node_or_null(
		^"PresentationContent/VariantVisual"
	) as AnimatedSprite2D
	if foreground == null:
		_fail("boss %s is missing its foreground body sprite" % BOSS_IDS[subject_index])
		return false
	foreground.stop()
	foreground.set_frame_and_progress(0, 0.0)
	if not view.is_body_silhouette_synchronized():
		_fail("boss %s body silhouette drifted from its frozen foreground frame" % BOSS_IDS[subject_index])
		return false
	return true


func _set_body_silhouette_visible(subject_index: int, visible: bool) -> bool:
	var view: EnemyPresentation2D = _subjects[subject_index].get_presentation_view()
	var silhouette: AnimatedSprite2D = view.get_node_or_null(
		^"PresentationContent/BodySilhouette"
	) as AnimatedSprite2D
	if silhouette == null:
		_fail("boss %s is missing its named body silhouette layer" % BOSS_IDS[subject_index])
		return false
	silhouette.visible = visible
	return true


func _capture_review(boss_id: String, night_review: bool, state: String) -> bool:
	var time_id: String = "night" if night_review else "day"
	var output_stem: String = "%s_%s_%s" % [boss_id, time_id, state]
	var color_output_path: String = OUTPUT_DIRECTORY + "/%s.png" % output_stem
	var grayscale_output_path: String = OUTPUT_DIRECTORY + "/%s_grayscale.png" % output_stem
	if not await _capture(color_output_path, grayscale_output_path):
		return false
	_outputs[output_stem] = {
		"color": color_output_path,
		"grayscale": grayscale_output_path,
	}
	return true


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
	var ab_metrics: Dictionary = _calculate_ab_metrics()
	var metadata: Dictionary = {
		"artifact_only": true,
		"runtime_promotion": "test-only evidence; no production scene or export closure change",
		"capture_scope": "one remote hero plus one remote boss at a time; no CoopSession, HordeDirector, base damage, combat simulation, collision mutation, RPC, or snapshot traffic",
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"logical_size": [LOGICAL_CAPTURE_SIZE.x, LOGICAL_CAPTURE_SIZE.y],
		"native_capture_size": [_native_capture_size.x, _native_capture_size.y],
		"native_capture_scale": _native_capture_scale,
		"camera_zoom": GAMEPLAY_CAMERA_ZOOM,
		"world_anchor": [REVIEW_ANCHOR.x, REVIEW_ANCHOR.y],
		"hero": &"heikki",
		"hero_offset": [HERO_OFFSET.x, HERO_OFFSET.y],
		"boss_offset": [BOSS_OFFSET.x, BOSS_OFFSET.y],
		"bosses": BOSS_IDS,
		"grade": {
			"day": "NightAtmosphere2D.DAY_COLOR through CanvasModulate only",
			"night": "NightAtmosphere2D.SAPPHIRE_NIGHT_COLOR through CanvasModulate only",
			"flashlights_or_test_lights": false,
			"labels_over_bodies": false,
		},
		"control_difference": "control hides only PresentationContent/BodySilhouette; all other boss pixels, subdued idle marker policy, actor frame, terrain, hero, camera, and CanvasModulate state match its paired idle capture",
		"paired_frame_policy": "each boss is frozen on its first selected idle frame before both control and rim capture; enemy physics is disabled only inside this artifact fixture",
		"ab_metric_scope": {
			"roi": [BOSS_REVIEW_ROI.position.x, BOSS_REVIEW_ROI.position.y, BOSS_REVIEW_ROI.size.x, BOSS_REVIEW_ROI.size.y],
			"luma_delta_threshold": LUMA_DELTA_THRESHOLD,
			"meaning": "pixel delta proves the rim was isolated; it is not a substitute for semantic silhouette review",
		},
		"ab_metrics": ab_metrics,
		"body_first_treatment": {
			"scope": "boss_presentation only",
			"source": "same baked SpriteFrames and frame as the foreground body",
			"outline_scale": EnemyPresentation2D.BOSS_BODY_SILHOUETTE_SCALE,
			"outline_alpha": EnemyPresentation2D.BOSS_BODY_SILHOUETTE_ALPHA,
			"forbidden": ["raw Addons promotion", "new body texture", "PointLight2D", "particles", "collision change", "RPC", "snapshot schema change"],
		},
		"outputs": _outputs,
		"review_requirement": "Human visual veto is required. The capture isolates body-rim readability but does not certify Android thermal/performance, touch occlusion, LAN, audio, or AAA readiness.",
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


func _calculate_ab_metrics() -> Dictionary:
	var metrics: Dictionary = {}
	for boss_id: StringName in BOSS_IDS:
		var boss_metrics: Dictionary = {}
		for time_id: String in ["day", "night"]:
			var control_path: String = OUTPUT_DIRECTORY + "/%s_%s_control_without_rim.png" % [
				boss_id,
				time_id,
			]
			var rim_path: String = OUTPUT_DIRECTORY + "/%s_%s_idle_with_rim.png" % [
				boss_id,
				time_id,
			]
			var control_image: Image = Image.load_from_file(ProjectSettings.globalize_path(control_path))
			var rim_image: Image = Image.load_from_file(ProjectSettings.globalize_path(rim_path))
			if (
				control_image == null
				or rim_image == null
				or control_image.is_empty()
				or rim_image.is_empty()
				or control_image.get_size() != rim_image.get_size()
			):
				boss_metrics[time_id] = {"error": "paired capture unavailable or size mismatch"}
				continue
			var image_bounds: Rect2i = Rect2i(Vector2i.ZERO, control_image.get_size())
			var roi: Rect2i = BOSS_REVIEW_ROI.intersection(image_bounds)
			if roi.size.x <= 0 or roi.size.y <= 0:
				boss_metrics[time_id] = {"error": "body review ROI is outside the capture"}
				continue
			var changed_pixel_count: int = 0
			var luma_delta_sum: float = 0.0
			var peak_luma_delta: float = 0.0
			var reviewed_pixel_count: int = 0
			for pixel_y: int in range(roi.position.y, roi.end.y):
				for pixel_x: int in range(roi.position.x, roi.end.x):
					var control_color: Color = control_image.get_pixel(pixel_x, pixel_y)
					var rim_color: Color = rim_image.get_pixel(pixel_x, pixel_y)
					var control_luma: float = (
						control_color.r * 0.2126
						+ control_color.g * 0.7152
						+ control_color.b * 0.0722
					)
					var rim_luma: float = (
						rim_color.r * 0.2126
						+ rim_color.g * 0.7152
						+ rim_color.b * 0.0722
					)
					var luma_delta: float = absf(rim_luma - control_luma)
					if luma_delta > LUMA_DELTA_THRESHOLD:
						changed_pixel_count += 1
					luma_delta_sum += luma_delta
					peak_luma_delta = maxf(peak_luma_delta, luma_delta)
					reviewed_pixel_count += 1
			boss_metrics[time_id] = {
				"roi_pixels": reviewed_pixel_count,
				"changed_pixels_over_luma_delta_threshold": changed_pixel_count,
				"changed_fraction": snappedf(
					float(changed_pixel_count) / float(maxi(reviewed_pixel_count, 1)),
					0.000001
				),
				"mean_luma_delta": snappedf(
					luma_delta_sum / float(maxi(reviewed_pixel_count, 1)),
					0.000001
				),
				"peak_luma_delta": snappedf(peak_luma_delta, 0.000001),
			}
		metrics[String(boss_id)] = boss_metrics
	return metrics


func _fail_bool(message: String) -> bool:
	_fail(message)
	return false


func _fail(message: String) -> void:
	push_error("ENEMY BODY COMBAT READABILITY RENDER FAILED: %s" % message)
	get_tree().quit(1)
