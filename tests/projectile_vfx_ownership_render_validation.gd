extends Node2D
## Artifact-only proof that the fire, projectile, impact, and remote HIT-view
## presentation paths remain legible together at the shipped 0.38 camera.
##
## This deliberately does not start a CoopSession, HordeDirector, or a combat
## authority. The survivor, enemy, and projectile are real runtime scenes; the
## single Area2D is only an invisible Enemies-layer collision proxy so the real
## PlayerProjectile can reach its ordinary physics impact callback without
## mutating a simulated horde. The visible enemy acknowledgement then uses its
## real non-authoritative snapshot/HIT-token path.

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/network_player.tscn")

const OUTPUT_DIRECTORY: String = "res://artifacts/projectile_vfx_ownership_validation"
const METADATA_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/projectile_vfx_ownership_validation.json"
const LOGICAL_CAPTURE_SIZE: Vector2i = Vector2i(480, 270)
const GAMEPLAY_CAMERA_ZOOM: float = 0.38
const REVIEW_ANCHOR: Vector2 = Vector2(-5200.0, 1800.0)
const PLAYER_POSITION: Vector2 = REVIEW_ANCHOR + Vector2(-180.0, 72.0)
const TARGET_POSITION: Vector2 = REVIEW_ANCHOR + Vector2(180.0, 72.0)
const SHOT_DIRECTION: Vector2 = Vector2.RIGHT
const TARGET_HEALTH: int = 100
const SHOT_DAMAGE: int = 10
const MAX_IMPACT_PHYSICS_FRAMES: int = 48
## Past the 0.13s muzzle and 0.085s body flash, but still inside the 0.30s
## impact lifetime, so the late frame proves readable cleanup rather than an
## accidental empty capture.
const LATE_CAPTURE_SECONDS: float = 0.14

@onready var lighting: CanvasModulate = %SapphireCanvasModulate
@onready var y_sort_world: Node2D = %YSortWorld
@onready var world_map: BesprenWorldMap2D = %WorldMap2D as BesprenWorldMap2D
@onready var atmosphere: NightAtmosphere2D = %NightAtmosphere2D as NightAtmosphere2D
@onready var camera: Camera2D = %ValidationCamera

var _player: PlayerAvatar
var _target: EnemyAgent2D
var _impact_proxy: Area2D
var _projectile_pool: ProjectilePool2D
var _vfx: VfxDirector
var _impact_received: bool = false
var _raw_impacted_collider: Node
var _impact_position: Vector2 = Vector2.INF
var _impact_spray: Vector2 = Vector2.INF
var _snapshot_revision: int = 1
var _native_capture_size: Vector2i = Vector2i.ZERO
var _native_capture_scale: int = 0
var _reports: Array[Dictionary] = []


func _ready() -> void:
	if not _prepare_output_directory():
		return
	if world_map == null or atmosphere == null or camera == null:
		_fail("fixture is missing its live WorldMap, atmosphere, or camera")
		return
	if not is_equal_approx(camera.zoom.x, GAMEPLAY_CAMERA_ZOOM) or not is_equal_approx(camera.zoom.y, GAMEPLAY_CAMERA_ZOOM):
		_fail("fixture camera must remain at the shipped 0.38 gameplay zoom")
		return
	camera.make_current()
	await get_tree().process_frame
	if not _spawn_subjects():
		return
	await get_tree().physics_frame
	await get_tree().process_frame
	if not _verify_fixture_contracts():
		return
	var day_report: Dictionary = await _run_phase("day", false)
	if day_report.is_empty():
		return
	_reports.append(day_report)
	var night_report: Dictionary = await _run_phase("night", true)
	if night_report.is_empty():
		return
	_reports.append(night_report)
	_write_metadata()
	print("PROJECTILE VFX OWNERSHIP RENDER OK | method=%s | driver=%s | phases=%d | review_required=true" % [
		RenderingServer.get_current_rendering_method(),
		RenderingServer.get_current_rendering_driver_name(),
		_reports.size(),
	])
	get_tree().quit(0)


func _prepare_output_directory() -> bool:
	var make_directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	)
	if make_directory_error != OK:
		_fail("could not create artifact directory: %s" % error_string(make_directory_error))
		return false
	return true


func _spawn_subjects() -> bool:
	_player = PLAYER_SCENE.instantiate() as PlayerAvatar
	if _player == null:
		_fail("could not instantiate the real PlayerAvatar scene")
		return false
	## The fixture camera owns the view; this presentation subject deliberately
	## has no local camera or network authority.
	_player.configure(1, &"heikki", PLAYER_POSITION, false)
	y_sort_world.add_child(_player)
	_player.set_aim_direction(SHOT_DIRECTION, false)

	_target = EnemyAgent2D.new()
	_target.configure(
		1001,
		EnemyAgent2D.Variant.WALKER,
		TARGET_POSITION,
		TARGET_HEALTH,
		10,
		90.0,
		REVIEW_ANCHOR,
		null,
		null,
		false
	)
	y_sort_world.add_child(_target)

	_impact_proxy = Area2D.new()
	_impact_proxy.name = &"ProjectileImpactProxy"
	_impact_proxy.collision_layer = EnemyAgent2D.ENEMY_LAYER
	_impact_proxy.collision_mask = 0
	var impact_shape: CircleShape2D = CircleShape2D.new()
	impact_shape.radius = 20.0
	var impact_collision: CollisionShape2D = CollisionShape2D.new()
	impact_collision.shape = impact_shape
	_impact_proxy.add_child(impact_collision)
	## It follows the visible target exactly but is never a gameplay target.
	_target.add_child(_impact_proxy)

	_projectile_pool = ProjectilePool2D.new()
	_projectile_pool.name = &"TestProjectilePool"
	_projectile_pool.initial_size = 1
	_projectile_pool.maximum_size = 1
	_projectile_pool.projectile_impacted.connect(_on_projectile_impacted)
	y_sort_world.add_child(_projectile_pool)

	_vfx = VfxDirector.new()
	_vfx.name = &"TestVfxDirector"
	y_sort_world.add_child(_vfx)
	return true


func _verify_fixture_contracts() -> bool:
	if not world_map.is_position_walkable(REVIEW_ANCHOR, 0.0):
		return _fail_bool("review anchor is no longer playable in the live WorldMap")
	if not _player.uses_baked_actor_presentation():
		return _fail_bool("real PlayerAvatar did not bind its baked directional presentation")
	if _target.get_presentation_view() == null:
		return _fail_bool("real EnemyAgent2D did not bind its baked presentation view")
	if _projectile_pool.get_capacity() != 1 or _projectile_pool.get_available_count() != 1:
		return _fail_bool("test projectile pool did not prewarm exactly one real PlayerProjectile")
	if _vfx.get_child_count() != VfxDirector.POOL_SIZE:
		return _fail_bool("real VfxDirector did not create its bounded emitter pool")
	if _impact_proxy.collision_layer != EnemyAgent2D.ENEMY_LAYER:
		return _fail_bool("test-only impact proxy must stay on the real Enemies collision layer")
	return true


func _run_phase(phase: String, is_night: bool) -> Dictionary:
	if not await _configure_phase(is_night):
		return {}
	var launch_paths: Dictionary = _paths_for(phase, "launch_peak")
	var impact_paths: Dictionary = _paths_for(phase, "impact_peak")
	var late_paths: Dictionary = _paths_for(phase, "impact_late")
	var projectile: PlayerProjectile = _fire_real_shot()
	if projectile == null:
		return {}
	if not await _capture(
		String(launch_paths["color"]),
		String(launch_paths["grayscale"])
	):
		return {}
	if not await _await_real_impact():
		return {}
	if _raw_impacted_collider != _impact_proxy:
		return _fail_dictionary("real projectile did not impact the target-aligned Enemies proxy")
	if not _is_hit_view_active():
		return _fail_dictionary("remote EnemyAgent2D HIT token did not activate the real body flash path")
	var hit_event_at_peak: int = _target.get_presentation_view().get_active_presentation_event()
	if not _event_regions_are_label_free():
		return _fail_dictionary("a Label overlaps the actual muzzle or impact event region")
	if not await _capture(
		String(impact_paths["color"]),
		String(impact_paths["grayscale"])
	):
		return {}
	await get_tree().create_timer(LATE_CAPTURE_SECONDS).timeout
	if not await _capture(
		String(late_paths["color"]),
		String(late_paths["grayscale"])
	):
		return {}
	return {
		"phase": phase,
		"night": is_night,
		"launch_peak": launch_paths,
		"impact_peak": impact_paths,
		"impact_late": late_paths,
		"impact_position": [_impact_position.x, _impact_position.y],
		"impact_spray": [_impact_spray.x, _impact_spray.y],
		"projectile_pool_returned": _projectile_pool.get_active_count() == 0
			and _projectile_pool.get_available_count() == 1,
		"hit_event_at_peak": hit_event_at_peak,
		"hit_event_after_late": _target.get_presentation_view().get_active_presentation_event(),
	}


func _configure_phase(is_night: bool) -> bool:
	_vfx.stop_all()
	_projectile_pool.release_all()
	_impact_received = false
	_raw_impacted_collider = null
	_impact_position = Vector2.INF
	_impact_spray = Vector2.INF
	_player.apply_authoritative_state(PLAYER_POSITION, Vector2.ZERO)
	_player.set_aim_direction(SHOT_DIRECTION, false)
	_target.apply_network_snapshot(
		TARGET_POSITION,
		TARGET_HEALTH,
		1.0,
		ActorFacing.CAMERA_FACING_ROW,
		_next_presentation_token(EnemyPresentation2D.PresentationEvent.NONE)
	)
	if is_night:
		atmosphere.register_player(_player)
		atmosphere.set_night_active(true, true)
		if not _player.is_flashlight_enabled():
			return _fail_bool("night phase did not enable the real PlayerAvatar flashlight")
	else:
		atmosphere.set_night_active(false, true)
		if _player.is_flashlight_enabled():
			return _fail_bool("day phase left the real PlayerAvatar flashlight enabled")
	await get_tree().physics_frame
	await get_tree().process_frame
	return true


func _fire_real_shot() -> PlayerProjectile:
	if _projectile_pool.get_active_count() != 0:
		_fail("projectile pool was not quiet before a new review shot")
		return null
	## This is the same presentation handoff GameWorld makes after the accepted
	## fire broadcast: actor shoot beat, muzzle at +18, projectile at +24.
	_player.play_interaction_feedback(&"fire")
	_vfx.play(
		VfxDirector.Effect.MUZZLE_FLASH,
		_player.global_position + SHOT_DIRECTION * 18.0,
		SHOT_DIRECTION,
		Color(1.0, 0.84, 0.28)
	)
	var projectile: PlayerProjectile = _projectile_pool.checkout(
		_player.global_position + SHOT_DIRECTION * 24.0,
		SHOT_DIRECTION,
		_player.peer_id
	)
	if projectile == null:
		_fail("real ProjectilePool2D could not check out its prewarmed PlayerProjectile")
		return null
	## The pool recycles this exact projectile between day and night. Bind the
	## fixture observer once rather than stacking a second listener per checkout.
	if not projectile.has_meta(&"ownership_raw_impact_bound"):
		projectile.impacted.connect(_on_raw_projectile_impacted.bind(projectile))
		projectile.set_meta(&"ownership_raw_impact_bound", true)
	if not projectile.is_active() or projectile.get_direction() != SHOT_DIRECTION:
		_fail("checked-out real PlayerProjectile did not retain the approved shot direction")
		return null
	return projectile


func _await_real_impact() -> bool:
	for _frame_index: int in range(MAX_IMPACT_PHYSICS_FRAMES):
		await get_tree().physics_frame
		if _impact_received:
			await get_tree().process_frame
			return true
	return _fail_bool("real PlayerProjectile did not reach its target-aligned collision proxy")


func _on_raw_projectile_impacted(collider: Node, _projectile: PlayerProjectile) -> void:
	_raw_impacted_collider = collider


func _on_projectile_impacted(world_position: Vector2, spray: Vector2) -> void:
	## ProjectilePool2D emits this same outward spray GameWorld forwards to VFX.
	_impact_received = true
	_impact_position = world_position
	_impact_spray = spray
	_vfx.play(VfxDirector.Effect.IMPACT_SPARK, world_position, spray)
	_target.apply_network_snapshot(
		TARGET_POSITION,
		TARGET_HEALTH - SHOT_DAMAGE,
		1.0,
		ActorFacing.CAMERA_FACING_ROW,
		_next_presentation_token(EnemyPresentation2D.PresentationEvent.HIT)
	)


func _next_presentation_token(event_id: int) -> int:
	_snapshot_revision += 1
	return EnemyPresentation2D.pack_presentation_token(
		_snapshot_revision,
		ActorFacing.CAMERA_FACING_ROW,
		event_id
	)


func _is_hit_view_active() -> bool:
	var view: EnemyPresentation2D = _target.get_presentation_view()
	return view != null and view.get_active_presentation_event() == EnemyPresentation2D.PresentationEvent.HIT


func _event_regions_are_label_free() -> bool:
	## No test captions are injected. Existing world labels must also remain clear
	## of the two short-lived event loci, so a caption cannot grant ownership the
	## projectile, flash, and impact do not visually earn themselves.
	var muzzle_rect: Rect2 = Rect2(
		_world_to_logical(_player.global_position + SHOT_DIRECTION * 18.0) - Vector2(16.0, 16.0),
		Vector2(32.0, 32.0)
	)
	var impact_rect: Rect2 = Rect2(
		_world_to_logical(_impact_position) - Vector2(20.0, 20.0),
		Vector2(40.0, 40.0)
	)
	return not _tree_has_label_overlap(self, muzzle_rect) and not _tree_has_label_overlap(self, impact_rect)


func _tree_has_label_overlap(node: Node, logical_rect: Rect2) -> bool:
	for child: Node in node.get_children():
		var label: Label = child as Label
		if label != null and label.visible and label.get_global_rect().intersects(logical_rect):
			return true
		if _tree_has_label_overlap(child, logical_rect):
			return true
	return false


func _world_to_logical(world_position: Vector2) -> Vector2:
	return Vector2(LOGICAL_CAPTURE_SIZE) * 0.5 + (world_position - camera.global_position) * GAMEPLAY_CAMERA_ZOOM


func _paths_for(phase: String, moment: String) -> Dictionary:
	var stem: String = "%s_%s" % [phase, moment]
	return {
		"color": OUTPUT_DIRECTORY + "/" + stem + ".png",
		"grayscale": OUTPUT_DIRECTORY + "/" + stem + "_grayscale.png",
	}


func _capture(output_path: String, grayscale_output_path: String) -> bool:
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
		return _fail_bool("native viewport for %s is not an integer multiple of 480x270" % output_path)
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
	if not _save_grayscale(image, grayscale_output_path):
		return false
	return true


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
		return _fail_bool("could not save grayscale %s (%s)" % [output_path, error_string(save_error)])
	return true


func _write_metadata() -> void:
	var metadata: Dictionary = {
		"artifact_only": true,
		"runtime_promotion": "forbidden_pending_human_vfx_ownership_review",
		"capture_scope": "real PlayerAvatar shoot presentation, ProjectilePool2D/PlayerProjectile collision, VfxDirector, WorldMap, and non-authoritative EnemyAgent2D snapshot HIT presentation. No CoopSession, HordeDirector, TacticalBuildSystem, host damage, source gameplay, collision, or snapshot change.",
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"logical_size": [LOGICAL_CAPTURE_SIZE.x, LOGICAL_CAPTURE_SIZE.y],
		"native_capture_size": [_native_capture_size.x, _native_capture_size.y],
		"native_capture_scale": _native_capture_scale,
		"camera_zoom": GAMEPLAY_CAMERA_ZOOM,
		"world_anchor": [REVIEW_ANCHOR.x, REVIEW_ANCHOR.y],
		"semantic_ownership_contract": {
			"muzzle": "real PlayerAvatar shoot action plus real VfxDirector MUZZLE_FLASH at GameWorld's +18 source locus",
			"projectile": "prewarmed real PlayerProjectile launched at GameWorld's +24 source locus",
			"impact": "real ProjectilePool2D outward spray forwarded into VfxDirector IMPACT_SPARK at actual collision position",
			"body_acknowledgement": "real non-authoritative EnemyAgent2D apply_network_snapshot HIT token activates the baked hit clip and white body flash",
			"labels": "no test labels are injected; fixture rejects any visible Label overlapping the muzzle or impact locus",
		},
		"review_requirement": "Human visual veto remains required. Desktop GPU capture does not certify Android, touch ergonomics, LAN, audio, authority, or performance.",
		"phases": _reports,
	}
	var metadata_file: FileAccess = FileAccess.open(ProjectSettings.globalize_path(METADATA_OUTPUT_PATH), FileAccess.WRITE)
	if metadata_file == null:
		_fail("could not write ownership metadata")
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()


func _fail_dictionary(message: String) -> Dictionary:
	_fail(message)
	return {}


func _fail_bool(message: String) -> bool:
	_fail(message)
	return false


func _fail(message: String) -> void:
	push_error("PROJECTILE VFX OWNERSHIP RENDER FAILED: %s" % message)
	get_tree().quit(1)
