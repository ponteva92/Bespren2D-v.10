extends Node2D
## Artifact-only 480x270 composition evidence for the live 2D presentation paths.
##
## This fixture intentionally assembles the real WorldMap, HUD, mobile controls,
## survivor adapters, structures, enemies and night-light hooks without opening a
## Co-op session or starting horde/build timers.  It is a review gate, not a
## gameplay simulation and never contributes a resource to runtime export closure.

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/network_player.tscn")

const OUTPUT_DIRECTORY: String = "res://artifacts/combat_composite_validation"
const DAY_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/combat_composite_day.png"
const NIGHT_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/combat_composite_night.png"
const DAY_GRAYSCALE_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/combat_composite_day_grayscale.png"
const NIGHT_GRAYSCALE_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/combat_composite_night_grayscale.png"
const DAY_VFX_PEAK_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/combat_composite_day_vfx_peak.png"
const DAY_VFX_LATE_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/combat_composite_day_vfx_late.png"
const NIGHT_VFX_PEAK_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/combat_composite_night_vfx_peak.png"
const NIGHT_VFX_LATE_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/combat_composite_night_vfx_late.png"
const DAY_VFX_PEAK_GRAYSCALE_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/combat_composite_day_vfx_peak_grayscale.png"
const DAY_VFX_LATE_GRAYSCALE_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/combat_composite_day_vfx_late_grayscale.png"
const NIGHT_VFX_PEAK_GRAYSCALE_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/combat_composite_night_vfx_peak_grayscale.png"
const NIGHT_VFX_LATE_GRAYSCALE_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/combat_composite_night_vfx_late_grayscale.png"
const METADATA_OUTPUT_PATH: String = OUTPUT_DIRECTORY + "/combat_composite_validation.json"

const LOGICAL_CAPTURE_SIZE: Vector2i = Vector2i(480, 270)
const GAMEPLAY_CAMERA_ZOOM: float = 0.38
const REVIEW_ANCHOR: Vector2 = Vector2(-5200.0, 1800.0)
const SYNTHETIC_NOTCH_INSETS: Rect2 = Rect2(18.0, 10.0, 16.0, 12.0)

@onready var lighting: CanvasModulate = %SapphireCanvasModulate
@onready var y_sort_world: Node2D = %YSortWorld
@onready var world_map: BesprenWorldMap2D = %WorldMap2D as BesprenWorldMap2D
@onready var atmosphere: NightAtmosphere2D = %NightAtmosphere2D as NightAtmosphere2D
@onready var camera: Camera2D = %ValidationCamera
@onready var hud: GameHUD = %GameHUD as GameHUD
@onready var mobile_controls: MobileControls = %MobileControls as MobileControls

var _native_capture_size: Vector2i = Vector2i.ZERO
var _native_capture_scale: int = 0
var _heikki: PlayerAvatar
var _shane: PlayerAvatar
var _tower: PlacedStructure2D
var _trap: PlacedStructure2D
var _walker: EnemyAgent2D
var _boss: EnemyAgent2D
var _vfx: VfxDirector


func _ready() -> void:
	if not _prepare_output_directory():
		return
	if world_map == null or atmosphere == null or camera == null or hud == null or mobile_controls == null:
		_fail("fixture is missing a required world, lighting, camera, HUD, or touch-control node")
		return
	if not is_equal_approx(camera.zoom.x, GAMEPLAY_CAMERA_ZOOM) or not is_equal_approx(camera.zoom.y, GAMEPLAY_CAMERA_ZOOM):
		_fail("fixture camera must retain the 0.38 gameplay zoom")
		return
	camera.make_current()
	await get_tree().process_frame
	if not _spawn_review_subjects():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not _verify_review_contracts():
		return
	_configure_day_review_state()
	if not await _capture(DAY_OUTPUT_PATH, DAY_GRAYSCALE_OUTPUT_PATH):
		return
	if not await _capture_composed_vfx_review(false):
		return
	_configure_night_review_state()
	if not await _capture(NIGHT_OUTPUT_PATH, NIGHT_GRAYSCALE_OUTPUT_PATH):
		return
	if not await _capture_composed_vfx_review(true):
		return
	_write_metadata()
	print(
		"COMBAT COMPOSITE CAPTURE COMPLETE | method=%s | driver=%s | zoom=%.2f | review_required=true"
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
		_fail("could not create composite artifact directory: %s" % error_string(make_directory_error))
		return false
	return true


func _spawn_review_subjects() -> bool:
	_heikki = _spawn_player(1, &"heikki", REVIEW_ANCHOR + Vector2(-182.0, 56.0))
	_shane = _spawn_player(2, &"shane", REVIEW_ANCHOR + Vector2(-48.0, 108.0))
	_tower = _spawn_structure(9001, StructureCatalog.T1_KINETIC, REVIEW_ANCHOR + Vector2(92.0, 64.0))
	_trap = _spawn_structure(9002, StructureCatalog.T1_LANDMINE, REVIEW_ANCHOR + Vector2(194.0, 112.0))
	_walker = _spawn_enemy(
		1001,
		EnemyAgent2D.Variant.WALKER,
		REVIEW_ANCHOR + Vector2(236.0, -16.0),
		100,
		10,
		90.0
	)
	_boss = _spawn_enemy(
		1002,
		EnemyAgent2D.Variant.GOLIATH,
		REVIEW_ANCHOR + Vector2(118.0, -156.0),
		1800,
		24,
		54.0
	)
	_vfx = VfxDirector.new()
	_vfx.name = &"ReviewVfxDirector"
	add_child(_vfx)
	if _heikki == null or _shane == null or _tower == null or _trap == null or _walker == null or _boss == null or _vfx == null:
		_fail("could not assemble all presentation-only review subjects")
		return false
	return true


func _spawn_player(
	peer_id: int,
	character_id: StringName,
	world_position: Vector2
) -> PlayerAvatar:
	var player: PlayerAvatar = PLAYER_SCENE.instantiate() as PlayerAvatar
	if player == null:
		return null
	## These are deliberately remote visual subjects: their scene cameras remain
	## disabled and cannot displace the fixture's gameplay-scale camera.
	player.configure(peer_id, character_id, world_position, false)
	y_sort_world.add_child(player)
	return player


func _spawn_structure(
	instance_id: int,
	structure_id: StringName,
	world_position: Vector2
) -> PlacedStructure2D:
	var definition: StructureDefinition = StructureCatalog.get_definition(structure_id)
	if definition == null:
		return null
	var structure: PlacedStructure2D = PlacedStructure2D.new()
	## No combat runtime is configured.  This preserves the production body path
	## without adding target acquisition, projectiles, or authority mutations.
	structure.configure(instance_id, definition, 1, world_position, false)
	y_sort_world.add_child(structure)
	return structure


func _spawn_enemy(
	enemy_id: int,
	variant: int,
	world_position: Vector2,
	health: int,
	damage: int,
	speed: float
) -> EnemyAgent2D:
	var enemy: EnemyAgent2D = EnemyAgent2D.new()
	## A non-authoritative presentation subject owns no collision or combat path.
	enemy.configure(
		enemy_id,
		variant,
		world_position,
		health,
		damage,
		speed,
		REVIEW_ANCHOR,
		null,
		null,
		false
	)
	y_sort_world.add_child(enemy)
	return enemy


func _verify_review_contracts() -> bool:
	if not world_map.is_position_walkable(REVIEW_ANCHOR, 0.0):
		_fail("review anchor must remain in the playable WorldMap")
		return false
	if not _heikki.uses_baked_actor_presentation() or not _shane.uses_baked_actor_presentation():
		_fail("review survivors did not bind the live baked actor presentation path")
		return false
	if _tower.get_structure_visual() == null or _trap.get_structure_visual() == null:
		_fail("review structures did not construct their runtime visual bodies")
		return false
	if _walker.get_presentation_view() == null or _boss.get_presentation_view() == null:
		_fail("review enemies did not construct their runtime presentation views")
		return false
	if _vfx.get_child_count() != VfxDirector.POOL_SIZE:
		_fail("review fixture did not construct the bounded real VFX pool")
		return false
	if mobile_controls.get_action_target_size() != Vector2.ONE * MobileControls.ACTION_TARGET_SIZE:
		_fail("mobile action target contract is not the required 44 logical pixels")
		return false
	if not mobile_controls.is_point_in_control_zone(mobile_controls.get_action_center(&"fire")):
		_fail("live mobile fire control no longer owns its rendered center")
		return false
	return true


func _configure_day_review_state() -> void:
	lighting.color = NightAtmosphere2D.DAY_COLOR
	atmosphere.set_night_active(false, true)
	if not _tower.apply_runtime_snapshot(_tower.max_health, 0.0, Vector2.RIGHT, 0.0, -1):
		_fail("day review could not clear the presentation-only tower target state")
		return
	if not _trap.apply_runtime_snapshot(_trap.max_health, 0.0, Vector2.RIGHT, 0.0, -1):
		_fail("day review could not clear the presentation-only trap cooldown state")
		return
	_heikki.set_aim_direction(Vector2.RIGHT, false)
	_shane.set_aim_direction(Vector2.UP, true)
	_shane.play_interaction_feedback(&"fire")
	_walker.get_presentation_view().play_local_event(EnemyPresentation2D.PresentationEvent.NONE)
	_boss.get_presentation_view().play_local_event(EnemyPresentation2D.PresentationEvent.NONE)
	hud.set_resource_amounts(460, 275, 150)
	hud.set_status("VISUAL REVIEW // DAYLIGHT")
	hud.set_day_night_state(196, 2, false)
	hud.set_boss_gate(true, &"goliath", 1)


func _configure_night_review_state() -> void:
	_heikki.set_aim_direction(Vector2.UP, true)
	_shane.set_aim_direction(Vector2.RIGHT, true)
	# These are presentation snapshots on deliberately non-authoritative shells.
	# They visualize the same target/cooldown fields a remote client receives;
	# no tower decision, damage, timing, or snapshot schema is started here.
	if not _tower.apply_runtime_snapshot(_tower.max_health, 0.0, Vector2.UP, 0.0, 1001):
		_fail("night review could not apply the tower tracking presentation state")
		return
	if not _trap.apply_runtime_snapshot(_trap.max_health, 0.0, Vector2.RIGHT, 0.70, 1001):
		_fail("night review could not apply the trap rearming presentation state")
		return
	if _tower.get_readability_state() != PlacedStructure2D.ReadabilityState.TRACKING:
		_fail("night review tower did not resolve the existing target snapshot as tracking")
		return
	if _trap.get_readability_state() != PlacedStructure2D.ReadabilityState.REARMING:
		_fail("night review trap did not resolve the existing cooldown snapshot as rearming")
		return
	_walker.get_presentation_view().play_local_event(EnemyPresentation2D.PresentationEvent.ATTACK)
	_boss.get_presentation_view().play_local_event(EnemyPresentation2D.PresentationEvent.TAUNT)
	atmosphere.register_player(_heikki)
	atmosphere.register_player(_shane)
	atmosphere.register_structure(_tower)
	atmosphere.set_night_active(true, true)
	hud.set_status("VISUAL REVIEW // NIGHT THREAT")
	hud.set_day_night_state(74, 2, true)
	if not _heikki.is_flashlight_enabled() or not _shane.is_flashlight_enabled():
		_fail("night review did not enable the real survivor flashlight path")
		return
	var security_light: PointLight2D = _tower.get_node_or_null(^"SecurityLight") as PointLight2D
	if not _tower.has_security_light() or security_light == null or not security_light.enabled:
		_fail("night review did not enable the real tower security-light path")


## This remains presentation-only, but unlike the isolated VFX sheet it binds
## every burst to a visible survivor or enemy body in the same 0.38 gameplay
## composition.  The samples deliberately carry no labels: semantic ownership
## must read from the scene itself, not from an artifact caption.
func _capture_composed_vfx_review(is_night: bool) -> bool:
	if _vfx == null:
		return _fail_bool("composed VFX review is missing its real VfxDirector")
	_vfx.stop_all()
	var player: PlayerAvatar = _shane if is_night else _heikki
	var impact_owner: EnemyAgent2D = _boss if is_night else _walker
	var death_owner: EnemyAgent2D = _walker if is_night else _boss
	var impact_view: EnemyPresentation2D = impact_owner.get_presentation_view()
	var death_view: EnemyPresentation2D = death_owner.get_presentation_view()
	if impact_view == null or death_view == null:
		return _fail_bool("composed VFX review lost an enemy presentation owner")
	death_view.play_local_event(EnemyPresentation2D.PresentationEvent.DEATH)
	_vfx.play(
		VfxDirector.Effect.MUZZLE_FLASH,
		player.global_position + Vector2(28.0, -12.0),
		## The review states above deliberately put the active survivor on the
		## right-facing fire lane. PlayerAvatar exposes a setter only, so keep the
		## fixture's known presentation direction explicit rather than reading a
		## gameplay-private field.
		Vector2.RIGHT,
		Color(1.0, 0.84, 0.28)
	)
	_vfx.play(
		VfxDirector.Effect.IMPACT_SPARK,
		impact_owner.global_position,
		(player.global_position - impact_owner.global_position).normalized(),
		Color(1.0, 0.82, 0.26)
	)
	_vfx.play(
		VfxDirector.Effect.DEATH_BURST,
		death_owner.global_position,
		Vector2.ZERO,
		death_owner.get_presentation_definition().accent_color
	)
	var peak_path: String = NIGHT_VFX_PEAK_OUTPUT_PATH if is_night else DAY_VFX_PEAK_OUTPUT_PATH
	var peak_grayscale_path: String = (
		NIGHT_VFX_PEAK_GRAYSCALE_OUTPUT_PATH if is_night else DAY_VFX_PEAK_GRAYSCALE_OUTPUT_PATH
	)
	if not await _capture(peak_path, peak_grayscale_path):
		return false
	## 0.26 seconds is deliberately after the muzzle's 0.11-second flash but
	## within the death/build-family burst life. It checks that a remaining
	## envelope keeps the body owner readable instead of becoming a static blob.
	await get_tree().create_timer(0.26).timeout
	var late_path: String = NIGHT_VFX_LATE_OUTPUT_PATH if is_night else DAY_VFX_LATE_OUTPUT_PATH
	var late_grayscale_path: String = (
		NIGHT_VFX_LATE_GRAYSCALE_OUTPUT_PATH if is_night else DAY_VFX_LATE_GRAYSCALE_OUTPUT_PATH
	)
	if not await _capture(late_path, late_grayscale_path):
		return false
	_vfx.stop_all()
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
		return _fail_bool("could not save grayscale capture %s (%s)" % [output_path, error_string(save_error)])
	return true


func _write_metadata() -> void:
	var synthetic_panel: Rect2 = GameHUD.calculate_panel_rect(
		Vector2(LOGICAL_CAPTURE_SIZE),
		SYNTHETIC_NOTCH_INSETS
	)
	var synthetic_minimap: Rect2 = GameHUD.calculate_minimap_rect(
		Vector2(LOGICAL_CAPTURE_SIZE),
		SYNTHETIC_NOTCH_INSETS
	)
	var metadata: Dictionary = {
		"artifact_only": true,
		"runtime_promotion": "forbidden_pending_human_composition_review",
		"capture_scope": "presentation-only direct fixture; no CoopSession, HordeDirector, TacticalBuildSystem, collision authority, or combat simulation. VFX samples invoke the real VfxDirector directly on visible non-authoritative owners; they do not claim an authoritative combat event.",
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"logical_size": [LOGICAL_CAPTURE_SIZE.x, LOGICAL_CAPTURE_SIZE.y],
		"native_capture_size": [_native_capture_size.x, _native_capture_size.y],
		"native_capture_scale": _native_capture_scale,
		"camera_zoom": GAMEPLAY_CAMERA_ZOOM,
		"world_anchor": [REVIEW_ANCHOR.x, REVIEW_ANCHOR.y],
		"outputs": {
			"day": DAY_OUTPUT_PATH,
			"night": NIGHT_OUTPUT_PATH,
			"day_grayscale": DAY_GRAYSCALE_OUTPUT_PATH,
			"night_grayscale": NIGHT_GRAYSCALE_OUTPUT_PATH,
			"day_vfx_peak": DAY_VFX_PEAK_OUTPUT_PATH,
			"day_vfx_late": DAY_VFX_LATE_OUTPUT_PATH,
			"night_vfx_peak": NIGHT_VFX_PEAK_OUTPUT_PATH,
			"night_vfx_late": NIGHT_VFX_LATE_OUTPUT_PATH,
			"day_vfx_peak_grayscale": DAY_VFX_PEAK_GRAYSCALE_OUTPUT_PATH,
			"day_vfx_late_grayscale": DAY_VFX_LATE_GRAYSCALE_OUTPUT_PATH,
			"night_vfx_peak_grayscale": NIGHT_VFX_PEAK_GRAYSCALE_OUTPUT_PATH,
			"night_vfx_late_grayscale": NIGHT_VFX_LATE_GRAYSCALE_OUTPUT_PATH,
		},
		"subjects": {
			"players": [&"heikki", &"shane"],
			"structures": [StructureCatalog.T1_KINETIC, StructureCatalog.T1_LANDMINE],
			"enemies": [&"walker", &"goliath"],
			"core": true,
		},
		"day_marker_state": "ordinary idle markers hidden; boss idle cue is subdued by the presentation policy",
		"night_marker_state": "walker attack and boss taunt intentionally use the full active-cue policy",
		"day_structure_state": "T1 Kinetic ready and T1 Landmine armed; no simulated combat or authority mutation",
		"night_structure_state": "T1 Kinetic tracking and T1 Landmine rearming from existing client snapshot fields only",
		"night_lighting": "NightAtmosphere2D enabled real survivor flashlights and T1 Kinetic security light",
		"vfx_review": "label-free real VfxDirector samples use visible body owners: muzzle on survivor aim, impact on a live enemy body, and death burst on an enemy in its local baked death presentation. Peak and 0.26-second late captures exist in both day and night; no authoritative combat event is asserted.",
		"mobile_control_action_target_logical_px": MobileControls.ACTION_TARGET_SIZE,
		"safe_area_capture_limit": "Headless/Desktop DisplayServer safe area is rendered as supplied by the host. The synthetic notch values below validate layout geometry only and are not a visual notch capture.",
		"synthetic_notch_insets": [
			SYNTHETIC_NOTCH_INSETS.position.x,
			SYNTHETIC_NOTCH_INSETS.position.y,
			SYNTHETIC_NOTCH_INSETS.size.x,
			SYNTHETIC_NOTCH_INSETS.size.y,
		],
		"synthetic_notch_panel_rect": [synthetic_panel.position.x, synthetic_panel.position.y, synthetic_panel.size.x, synthetic_panel.size.y],
		"synthetic_notch_minimap_rect": [synthetic_minimap.position.x, synthetic_minimap.position.y, synthetic_minimap.size.x, synthetic_minimap.size.y],
		"review_requirement": "Human visual veto is required. Green capture only proves fixture contracts and does not certify Android, touch ergonomics, LAN, audio, performance, or premium art quality.",
	}
	var metadata_file: FileAccess = FileAccess.open(ProjectSettings.globalize_path(METADATA_OUTPUT_PATH), FileAccess.WRITE)
	if metadata_file == null:
		_fail("could not write composite metadata")
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()


func _fail_bool(message: String) -> bool:
	_fail(message)
	return false


func _fail(message: String) -> void:
	push_error("COMBAT COMPOSITE RENDER FAILED: %s" % message)
	get_tree().quit(1)
