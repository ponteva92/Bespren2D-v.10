extends Node2D
## Artifact-only review of the non-promoted Carrier/Splitter body-rebake sheets.
##
## It reads PNGs directly from the ignored build staging directory, constructs
## transient SpriteFrames in memory, and swaps only the two remote evidence
## subjects.  The production frames, scenes, collision, snapshot, host, and
## export closure remain untouched.

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/network_player.tscn")

const OUTPUT_DIRECTORY: String = "res://artifacts/enemy_body_rebake_candidate_validation"
const METADATA_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/enemy_body_rebake_candidate_validation.json"
const STAGING_DIRECTORY: String = "res://build/boss_body_rebake_loop_f_20260916"
const BASELINE_SHEET_DIRECTORY: String = "res://assets/2d/actors/sheets"
const LOGICAL_CAPTURE_SIZE: Vector2i = Vector2i(480, 270)
const GAMEPLAY_CAMERA_ZOOM: float = 0.38
const REVIEW_ANCHOR: Vector2 = Vector2(-5200.0, 1800.0)
const HERO_OFFSET: Vector2 = Vector2(-156.0, 88.0)
const BOSS_OFFSET: Vector2 = Vector2(172.0, -42.0)
const BOSS_REVIEW_ROI: Rect2i = Rect2i(255, 64, 101, 111)
const LUMA_DELTA_THRESHOLD: float = 0.015
## A non-zero pixel delta only proves that the staging body is different; the
## captures, including grayscale, remain the semantic/human review gate.
const CANDIDATE_DELTA_FLOOR: float = 0.005
const DIRECTIONS: int = 8

const CLIP_LAYOUT: Dictionary = {
	&"attack": {&"cols": 4, &"fps": 12.0, &"loop": false},
	&"death": {&"cols": 6, &"fps": 9.0, &"loop": false},
	&"hit": {&"cols": 4, &"fps": 14.0, &"loop": false},
	&"idle": {&"cols": 4, &"fps": 6.0, &"loop": true},
	&"spawn": {&"cols": 6, &"fps": 9.0, &"loop": false},
	&"taunt": {&"cols": 6, &"fps": 9.0, &"loop": false},
	&"walk": {&"cols": 6, &"fps": 10.0, &"loop": true},
}

const SUBJECTS: Array[Dictionary] = [
	{
		&"id": &"carrier",
		&"variant": EnemyAgent2D.Variant.CARRIER,
		&"candidate_directory": STAGING_DIRECTORY + "/carrier_sheets",
	},
	{
		&"id": &"splitter",
		&"variant": EnemyAgent2D.Variant.SPLITTER,
		&"candidate_directory": STAGING_DIRECTORY + "/splitter_sheets",
	},
]

@onready var neutral_canvas_modulate: CanvasModulate = %NeutralCanvasModulate
@onready var world_map: BesprenWorldMap2D = %WorldMap2D as BesprenWorldMap2D
@onready var y_sort_world: Node2D = %YSortWorld
@onready var camera: Camera2D = %ValidationCamera

var _hero: PlayerAvatar
var _subjects: Array[EnemyAgent2D] = []
var _candidate_frames: Dictionary = {}
var _baseline_frames: Dictionary = {}
var _sheet_contract: Dictionary = {}
var _outputs: Dictionary = {}
var _native_capture_size: Vector2i = Vector2i.ZERO
var _native_capture_scale: int = 0


func _ready() -> void:
	if not _prepare_output_directory():
		return
	if neutral_canvas_modulate == null or world_map == null or y_sort_world == null or camera == null:
		_fail("fixture is missing neutral grading, WorldMap, Y-sort, or camera")
		return
	if not is_equal_approx(camera.zoom.x, GAMEPLAY_CAMERA_ZOOM) or not is_equal_approx(camera.zoom.y, GAMEPLAY_CAMERA_ZOOM):
		_fail("fixture camera must retain the 0.38 gameplay zoom")
		return
	if not _build_all_candidate_frames():
		return
	camera.make_current()
	await get_tree().process_frame
	if not world_map.is_position_walkable(REVIEW_ANCHOR, 0.0):
		_fail("review anchor must remain inside the playable WorldMap")
		return
	if not _spawn_subjects():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not _verify_subject_contracts():
		return
	if not await _capture_reviews():
		return
	var comparison_metrics: Dictionary = _calculate_candidate_deltas()
	if not _require_material_candidate_deltas(comparison_metrics):
		return
	_write_metadata(comparison_metrics)
	print(
		"ENEMY BODY REBAKE CANDIDATE CAPTURE COMPLETE | method=%s | driver=%s | subjects=%d | captures=%d"
		% [
			RenderingServer.get_current_rendering_method(),
			RenderingServer.get_current_rendering_driver_name(),
			_subjects.size(),
			_outputs.size(),
		]
	)
	get_tree().quit(0)


func _prepare_output_directory() -> bool:
	var make_directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	if make_directory_error != OK:
		return _fail_bool("could not create artifact directory: %s" % error_string(make_directory_error))
	return true


func _build_all_candidate_frames() -> bool:
	for subject_info: Dictionary in SUBJECTS:
		var subject_id: StringName = subject_info[&"id"] as StringName
		var candidate_directory: String = String(subject_info[&"candidate_directory"])
		var frames: SpriteFrames = _build_candidate_frames(subject_id, candidate_directory)
		if frames == null:
			return false
		_candidate_frames[subject_id] = frames
	return true


func _build_candidate_frames(subject_id: StringName, candidate_directory: String) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	var actor_id: String = "enemy_%s" % subject_id
	var subject_contract: Dictionary = {}
	for clip_variant: Variant in CLIP_LAYOUT.keys():
		var clip: StringName = clip_variant as StringName
		var clip_info: Dictionary = CLIP_LAYOUT[clip]
		var candidate_path: String = "%s/%s_%s.png" % [candidate_directory, actor_id, clip]
		var baseline_path: String = "%s/%s_%s.png" % [BASELINE_SHEET_DIRECTORY, actor_id, clip]
		var candidate_image: Image = Image.load_from_file(ProjectSettings.globalize_path(candidate_path))
		var baseline_image: Image = Image.load_from_file(ProjectSettings.globalize_path(baseline_path))
		if (
			candidate_image == null
			or candidate_image.is_empty()
			or baseline_image == null
			or baseline_image.is_empty()
		):
			_fail("candidate or baseline source sheet is unavailable for %s/%s" % [subject_id, clip])
			return null
		if candidate_image.get_size() != baseline_image.get_size():
			_fail(
				"candidate sheet dimensions drifted for %s/%s: %s versus %s"
				% [subject_id, clip, candidate_image.get_size(), baseline_image.get_size()]
			)
			return null
		if candidate_image.get_height() % DIRECTIONS != 0:
			_fail("candidate sheet does not contain eight rows for %s/%s" % [subject_id, clip])
			return null
		var cell: int = candidate_image.get_height() / DIRECTIONS
		var columns: int = candidate_image.get_width() / cell
		if candidate_image.get_width() % cell != 0 or columns != int(clip_info[&"cols"]):
			_fail("candidate sheet columns drifted for %s/%s" % [subject_id, clip])
			return null
		var texture: ImageTexture = ImageTexture.create_from_image(candidate_image)
		for row: int in range(DIRECTIONS):
			var animation: StringName = StringName("%s_%d" % [clip, row])
			frames.add_animation(animation)
			frames.set_animation_loop(animation, bool(clip_info[&"loop"]))
			frames.set_animation_speed(animation, float(clip_info[&"fps"]))
			for column: int in range(columns):
				var atlas: AtlasTexture = AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2i(column * cell, row * cell, cell, cell)
				frames.add_frame(animation, atlas)
			subject_contract[clip] = {
				"candidate_size": [candidate_image.get_width(), candidate_image.get_height()],
				"baseline_size": [baseline_image.get_width(), baseline_image.get_height()],
				"cell": cell,
				"rows": DIRECTIONS,
				"cols": columns,
			}
	_sheet_contract[subject_id] = subject_contract
	if frames.get_animation_names().size() != CLIP_LAYOUT.size() * DIRECTIONS:
		_fail("candidate SpriteFrames did not build all 56 named animations for %s" % subject_id)
		return null
	return frames


func _spawn_subjects() -> bool:
	_hero = PLAYER_SCENE.instantiate() as PlayerAvatar
	if _hero == null:
		return _fail_bool("could not instantiate the live survivor presentation scene")
	_hero.configure(1, &"heikki", REVIEW_ANCHOR + HERO_OFFSET, false)
	y_sort_world.add_child(_hero)
	_hero.set_aim_direction(Vector2.RIGHT, false)
	for subject_index: int in range(SUBJECTS.size()):
		var subject_info: Dictionary = SUBJECTS[subject_index]
		var subject: EnemyAgent2D = EnemyAgent2D.new()
		subject.configure(
			8000 + subject_index,
			int(subject_info[&"variant"]),
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
		subject.set_physics_process(false)
		y_sort_world.add_child(subject)
		_subjects.append(subject)
	return true


func _verify_subject_contracts() -> bool:
	if _hero == null or not _hero.uses_baked_actor_presentation():
		return _fail_bool("review hero did not bind the live baked actor presentation")
	if _subjects.size() != SUBJECTS.size():
		return _fail_bool("candidate subject inventory is inconsistent")
	for subject_index: int in range(_subjects.size()):
		var subject: EnemyAgent2D = _subjects[subject_index]
		var subject_info: Dictionary = SUBJECTS[subject_index]
		var subject_id: StringName = subject_info[&"id"] as StringName
		var view: EnemyPresentation2D = subject.get_presentation_view()
		var foreground: AnimatedSprite2D = _foreground_for(view)
		var silhouette: AnimatedSprite2D = _silhouette_for(view)
		if (
			view == null
			or foreground == null
			or silhouette == null
			or not view.has_loaded_visual()
			or view.get_visual_copy_count() != 1
			or view.get_body_silhouette_copy_count() != 1
			or not view.body_silhouette_uses_primary_frames()
			or not view.is_body_silhouette_synchronized()
			or not view.find_children("*", "PointLight2D", true, false).is_empty()
			or not view.find_children("*", "GPUParticles2D", true, false).is_empty()
			or not view.find_children("*", "CPUParticles2D", true, false).is_empty()
		):
			return _fail_bool("candidate subject %s broke the bounded presentation contract" % subject_id)
		if foreground.sprite_frames == null or foreground.sprite_frames.get_animation_names().size() != 56:
			return _fail_bool("baseline SpriteFrames contract changed for %s" % subject_id)
		_baseline_frames[subject_id] = foreground.sprite_frames
		## Body-only evidence: neither the marker nor the existing rim can be the
		## thing a reviewer recognises.  This only changes the transient fixture.
		view.set_readability_marker_visible(false)
		silhouette.visible = false
	return true


func _capture_reviews() -> bool:
	for subject_index: int in range(_subjects.size()):
		if not _select_subject(subject_index):
			return false
		var subject_id: StringName = SUBJECTS[subject_index][&"id"] as StringName
		for night_review: bool in [false, true]:
			_set_neutral_time_of_day(night_review)
			if not _apply_frames(subject_index, false):
				return false
			if not await _capture_review(subject_id, night_review, "baseline_body_only"):
				return false
			if not _apply_frames(subject_index, true):
				return false
			if not await _capture_review(subject_id, night_review, "candidate_body_only"):
				return false
	return true


func _select_subject(selected_index: int) -> bool:
	if selected_index < 0 or selected_index >= _subjects.size():
		return _fail_bool("selected candidate subject is outside the capture inventory")
	for subject_index: int in range(_subjects.size()):
		_subjects[subject_index].visible = subject_index == selected_index
	return true


func _set_neutral_time_of_day(night_review: bool) -> void:
	neutral_canvas_modulate.color = (
		NightAtmosphere2D.SAPPHIRE_NIGHT_COLOR
		if night_review
		else NightAtmosphere2D.DAY_COLOR
	)


func _apply_frames(subject_index: int, use_candidate: bool) -> bool:
	var subject_id: StringName = SUBJECTS[subject_index][&"id"] as StringName
	var frames: SpriteFrames = (
		_candidate_frames.get(subject_id, null) as SpriteFrames
		if use_candidate
		else _baseline_frames.get(subject_id, null) as SpriteFrames
	)
	if frames == null:
		return _fail_bool("%s frames are unavailable for %s" % ["candidate" if use_candidate else "baseline", subject_id])
	var view: EnemyPresentation2D = _subjects[subject_index].get_presentation_view()
	var foreground: AnimatedSprite2D = _foreground_for(view)
	var silhouette: AnimatedSprite2D = _silhouette_for(view)
	if foreground == null or silhouette == null:
		return _fail_bool("candidate subject lacks a body sprite")
	foreground.sprite_frames = frames
	silhouette.sprite_frames = frames
	foreground.animation = &"idle_2"
	silhouette.animation = &"idle_2"
	foreground.stop()
	silhouette.stop()
	foreground.set_frame_and_progress(0, 0.0)
	silhouette.set_frame_and_progress(0, 0.0)
	view.set_readability_marker_visible(false)
	silhouette.visible = false
	if foreground.get_frame() != 0 or foreground.animation != &"idle_2":
		return _fail_bool("candidate body could not freeze the requested idle frame")
	return true


func _foreground_for(view: EnemyPresentation2D) -> AnimatedSprite2D:
	return (
		view.get_node_or_null(^"PresentationContent/VariantVisual") as AnimatedSprite2D
		if view != null
		else null
	)


func _silhouette_for(view: EnemyPresentation2D) -> AnimatedSprite2D:
	return (
		view.get_node_or_null(^"PresentationContent/BodySilhouette") as AnimatedSprite2D
		if view != null
		else null
	)


func _capture_review(subject_id: StringName, night_review: bool, state: String) -> bool:
	var time_id: String = "night" if night_review else "day"
	var output_stem: String = "%s_%s_%s" % [subject_id, time_id, state]
	var color_path: String = OUTPUT_DIRECTORY + "/%s.png" % output_stem
	var grayscale_path: String = OUTPUT_DIRECTORY + "/%s_grayscale.png" % output_stem
	if not await _capture(color_path, grayscale_path):
		return false
	_outputs[output_stem] = {"color": color_path, "grayscale": grayscale_path}
	return true


func _capture(color_path: String, grayscale_path: String) -> bool:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return _fail_bool("empty viewport for %s" % color_path)
	_native_capture_size = image.get_size()
	if (
		_native_capture_size.x <= 0
		or _native_capture_size.y <= 0
		or _native_capture_size.x % LOGICAL_CAPTURE_SIZE.x != 0
		or _native_capture_size.y % LOGICAL_CAPTURE_SIZE.y != 0
	):
		return _fail_bool("native viewport is not an integer 480x270 scale for %s" % color_path)
	var horizontal_scale: int = int(float(_native_capture_size.x) / float(LOGICAL_CAPTURE_SIZE.x))
	var vertical_scale: int = int(float(_native_capture_size.y) / float(LOGICAL_CAPTURE_SIZE.y))
	if horizontal_scale != vertical_scale:
		return _fail_bool("native viewport scale is non-uniform for %s" % color_path)
	_native_capture_scale = horizontal_scale
	if image.get_size() != LOGICAL_CAPTURE_SIZE:
		image.resize(LOGICAL_CAPTURE_SIZE.x, LOGICAL_CAPTURE_SIZE.y, Image.INTERPOLATE_LANCZOS)
	if image.get_size() != LOGICAL_CAPTURE_SIZE:
		return _fail_bool("logical capture did not resolve to 480x270 for %s" % color_path)
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(color_path))
	if save_error != OK:
		return _fail_bool("could not save %s (%s)" % [color_path, error_string(save_error)])
	return _save_grayscale(image, grayscale_path)


func _save_grayscale(source: Image, path: String) -> bool:
	var grayscale: Image = source.duplicate()
	grayscale.convert(Image.FORMAT_RGBA8)
	for pixel_y: int in range(grayscale.get_height()):
		for pixel_x: int in range(grayscale.get_width()):
			var color: Color = grayscale.get_pixel(pixel_x, pixel_y)
			var luma: float = color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			grayscale.set_pixel(pixel_x, pixel_y, Color(luma, luma, luma, color.a))
	var save_error: Error = grayscale.save_png(ProjectSettings.globalize_path(path))
	if save_error != OK:
		return _fail_bool("could not save grayscale capture %s (%s)" % [path, error_string(save_error)])
	return true


func _calculate_candidate_deltas() -> Dictionary:
	var metrics: Dictionary = {}
	for subject_info: Dictionary in SUBJECTS:
		var subject_id: StringName = subject_info[&"id"] as StringName
		var subject_metrics: Dictionary = {}
		for time_id: String in ["day", "night"]:
			var baseline_path: String = OUTPUT_DIRECTORY + "/%s_%s_baseline_body_only.png" % [subject_id, time_id]
			var candidate_path: String = OUTPUT_DIRECTORY + "/%s_%s_candidate_body_only.png" % [subject_id, time_id]
			var baseline: Image = Image.load_from_file(ProjectSettings.globalize_path(baseline_path))
			var candidate: Image = Image.load_from_file(ProjectSettings.globalize_path(candidate_path))
			if baseline == null or candidate == null or baseline.is_empty() or candidate.is_empty() or baseline.get_size() != candidate.get_size():
				subject_metrics[time_id] = {"error": "paired candidate capture unavailable or size mismatch"}
				continue
			var roi: Rect2i = BOSS_REVIEW_ROI.intersection(Rect2i(Vector2i.ZERO, baseline.get_size()))
			var changed_pixels: int = 0
			var reviewed_pixels: int = 0
			var peak_luma_delta: float = 0.0
			for pixel_y: int in range(roi.position.y, roi.end.y):
				for pixel_x: int in range(roi.position.x, roi.end.x):
					var baseline_color: Color = baseline.get_pixel(pixel_x, pixel_y)
					var candidate_color: Color = candidate.get_pixel(pixel_x, pixel_y)
					var baseline_luma: float = baseline_color.r * 0.2126 + baseline_color.g * 0.7152 + baseline_color.b * 0.0722
					var candidate_luma: float = candidate_color.r * 0.2126 + candidate_color.g * 0.7152 + candidate_color.b * 0.0722
					var delta: float = absf(candidate_luma - baseline_luma)
					if delta > LUMA_DELTA_THRESHOLD:
						changed_pixels += 1
					peak_luma_delta = maxf(peak_luma_delta, delta)
					reviewed_pixels += 1
			subject_metrics[time_id] = {
				"roi_pixels": reviewed_pixels,
				"changed_pixels_over_luma_delta_threshold": changed_pixels,
				"changed_fraction": snappedf(float(changed_pixels) / float(maxi(reviewed_pixels, 1)), 0.000001),
				"peak_luma_delta": snappedf(peak_luma_delta, 0.000001),
			}
		metrics[String(subject_id)] = subject_metrics
	return metrics


func _require_material_candidate_deltas(metrics: Dictionary) -> bool:
	for subject_info: Dictionary in SUBJECTS:
		var subject_id: String = String(subject_info[&"id"])
		var subject_metrics: Dictionary = metrics.get(subject_id, {}) as Dictionary
		for time_id: String in ["day", "night"]:
			var metric: Dictionary = subject_metrics.get(time_id, {}) as Dictionary
			if metric.has("error") or float(metric.get("changed_fraction", 0.0)) < CANDIDATE_DELTA_FLOOR:
				return _fail_bool("candidate body did not materially differ for %s/%s" % [subject_id, time_id])
	return true


func _write_metadata(comparison_metrics: Dictionary) -> void:
	var metadata: Dictionary = {
		"artifact_only": true,
		"runtime_promotion": "staging-only CC0 KayKit action bake; production sheets/scenes/export closure unchanged",
		"candidate_source": "original Bespren geometry in tools/art/build_actor_body.py on existing CC0 KayKit Rig_Medium actions",
		"staging_directory": STAGING_DIRECTORY,
		"baseline_contract": STAGING_DIRECTORY + "/../actor_bake/actor_bake_report.json",
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"logical_size": [LOGICAL_CAPTURE_SIZE.x, LOGICAL_CAPTURE_SIZE.y],
		"native_capture_size": [_native_capture_size.x, _native_capture_size.y],
		"native_capture_scale": _native_capture_scale,
		"camera_zoom": GAMEPLAY_CAMERA_ZOOM,
		"composition": "one remote Heikki, one remote boss, fixed terrain, no CoopSession/HordeDirector/combat/collision/RPC/snapshot traffic",
		"body_only_control": "marker and BodySilhouette hidden only in this fixture; baseline and candidate are frozen on idle_2 frame 0",
		"grade": {"day": "CanvasModulate only", "night": "CanvasModulate only", "test_lights": false, "labels_over_bodies": false},
		"sheet_contract": _sheet_contract,
		"candidate_delta_floor": CANDIDATE_DELTA_FLOOR,
		"candidate_deltas": comparison_metrics,
		"outputs": _outputs,
		"review_requirement": "Human visual veto remains required for two-pod Carrier and spaced-lobe Splitter in colour and grayscale; this cannot certify Android thermal/performance, touch, LAN, or AAA readiness.",
	}
	var metadata_file: FileAccess = FileAccess.open(ProjectSettings.globalize_path(METADATA_OUTPUT_PATH), FileAccess.WRITE)
	if metadata_file == null:
		_fail("could not write artifact metadata")
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()


func _fail_bool(message: String) -> bool:
	_fail(message)
	return false


func _fail(message: String) -> void:
	push_error("ENEMY BODY REBAKE CANDIDATE RENDER FAILED: %s" % message)
	get_tree().quit(1)
