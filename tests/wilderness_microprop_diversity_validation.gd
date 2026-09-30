extends Node2D
## Artifact-only contract and visual evidence for a deliberately small wilderness
## microprop alternative.  This fixture samples the already approved/baked wild
## atlas directly, never writes a world-decor value, and never promotes itself
## into the exported runtime closure.
##
## Recipe B remains exclusively in existing_wild_atlas_context_validation and is
## intentionally untouched/rejected.  This is a separate candidate: two mossy
## stone silhouettes plus one small neutral stone, kept under a survivor's body
## scale at the live 480x270 / 0.38 gameplay camera.

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/network_player.tscn")
const WILD_ATLAS: Texture2D = preload(
	"res://assets/2d/environment/polyhaven_wild/polyhaven_wild_atlas.png"
)
const SLEEK_SPRITE_SHADER: Shader = preload("res://shaders/sleek_sprite_finish.gdshader")

const V2_OUTPUT_DIRECTORY: String = "res://artifacts/wilderness_microprop_diversity_validation"
const V3_OUTPUT_DIRECTORY: String = "res://build/wilderness_microprop_diversity_v3_20260917"

const LOGICAL_CAPTURE_SIZE: Vector2i = Vector2i(480, 270)
const GAMEPLAY_CAMERA_ZOOM: float = 0.38
## Derived against the transformed review sprites, rather than a guessed atlas
## frame size.  The small margin is an occlusion envelope, not physics.
const CARD_OCCLUSION_MARGIN: float = 16.0
const REQUIRED_ROAD_CARD_CLEARANCE: float = 480.0
const PLAYER_CARD_CLEARANCE: float = 12.0
const PLAYER_ROAD_RADIUS: float = 24.0
const REQUIRED_PLAYER_ROAD_CLEARANCE: float = 72.0
## Material-envelope intersections need meaningful slack, not merely a nonzero
## floating-point gap; this survives later capture rounding or placement jitter.
const REQUIRED_ENVIRONMENT_CLEARANCE: float = 64.0
## The scale reference deliberately approaches from three directions.  A card
## centered in every capture is useful for visual review, but one repeated
## player-to-card diagonal made the first review look like a waypoint marker.
const PLAYER_REFERENCE_OFFSETS: Array[Vector2] = [
	Vector2(-144.0, 50.0),
	Vector2(-128.0, -86.0),
	Vector2(142.0, 64.0),
]
const SAMPLE_RING_COUNT: int = 19
const SAMPLE_SPOKE_COUNT: int = 40
const GRAYSCALE_SHEET_COLUMNS: int = 5
const GRAYSCALE_TILE_SIZE: Vector2i = Vector2i(240, 135)

## Atlas regions are the padded, transparent-safe regions from the installed
## deterministic manifest.  They are not raw files from Addons/Poly Haven.
const MOSSY_STONE_A_REGION: Rect2 = Rect2(1048.0, 820.0, 183.0, 152.0)
const MOSSY_STONE_B_REGION: Rect2 = Rect2(42.0, 1085.0, 176.0, 117.0)
const NEUTRAL_STONE_REGION: Rect2 = Rect2(587.0, 1122.0, 106.0, 61.0)
const MAX_MICROPROP_FRAME_SPAN: float = 48.0
## Exact source regions used only by the old rejected candidate.  Keeping this
## check here stops a future edit from silently turning this separate probe into
## Recipe B under a new test name.
const REJECTED_RECIPE_B_REGIONS: Array[Rect2] = [
	Rect2(34.0, 578.0, 188.0, 146.0),
	Rect2(295.0, 570.0, 164.0, 155.0),
	Rect2(796.0, 1086.0, 205.0, 153.0),
	Rect2(1038.0, 1117.0, 226.0, 100.0),
	Rect2(805.0, 578.0, 183.0, 119.0),
]

@onready var lighting: CanvasModulate = %ValidationCanvasModulate
@onready var y_sort_world: Node2D = %YSortWorld
@onready var world_map: BesprenWorldMap2D = %WorldMap2D as BesprenWorldMap2D
@onready var atmosphere: NightAtmosphere2D = %NightAtmosphere2D as NightAtmosphere2D
@onready var camera: Camera2D = %ValidationCamera

var _arrangements: Array[MicropropReviewArrangement] = []
var _player: PlayerAvatar
var _player_local_visual_bounds: Rect2 = Rect2()
var _native_capture_size: Vector2i = Vector2i.ZERO
var _native_capture_scale: int = 0

var _ambient_positions: PackedVector2Array = PackedVector2Array()
var _ambient_radii: PackedFloat32Array = PackedFloat32Array()
var _accent_positions: PackedVector2Array = PackedVector2Array()
var _accent_radii: PackedFloat32Array = PackedFloat32Array()
var _rubble_positions: PackedVector2Array = PackedVector2Array()
var _rubble_radii: PackedFloat32Array = PackedFloat32Array()
var _moss_positions: PackedVector2Array = PackedVector2Array()
var _moss_radii: PackedFloat32Array = PackedFloat32Array()
var _prop_positions: PackedVector2Array = PackedVector2Array()
var _prop_radii: PackedFloat32Array = PackedFloat32Array()
var _crack_envelopes: Array[Rect2] = []
var _recipe_id: StringName = &"v2"
var _output_directory: String = V2_OUTPUT_DIRECTORY
var _metadata_output_path: String = V2_OUTPUT_DIRECTORY + "/wilderness_microprop_diversity_validation.json"
var _day_grayscale_sheet_output_path: String = V2_OUTPUT_DIRECTORY + "/day_grayscale_sheet.png"
var _night_grayscale_sheet_output_path: String = V2_OUTPUT_DIRECTORY + "/night_grayscale_sheet.png"


class MicropropReviewArrangement extends Node2D:
	const MOSSY_STONE_A_REGION: Rect2 = Rect2(1048.0, 820.0, 183.0, 152.0)
	const MOSSY_STONE_B_REGION: Rect2 = Rect2(42.0, 1085.0, 176.0, 117.0)
	const NEUTRAL_STONE_REGION: Rect2 = Rect2(587.0, 1122.0, 106.0, 61.0)
	## V3 intentionally avoids every rejected Recipe B root/branch region.  These
	## values are padded regions from the existing CC0 Poly Haven wild atlas.
	const V3_STUMP_A_REGION: Rect2 = Rect2(550.0, 339.0, 180.0, 126.0)
	const V3_STUMP_B_REGION: Rect2 = Rect2(805.0, 336.0, 178.0, 136.0)
	const V3_FERN_A_REGION: Rect2 = Rect2(1330.0, 593.0, 182.0, 127.0)
	const V3_FERN_B_REGION: Rect2 = Rect2(51.0, 851.0, 182.0, 126.0)
	const V3_BARE_PEBBLE_REGION: Rect2 = Rect2(340.0, 1109.0, 89.0, 94.0)
	var _visual_bounds: Rect2 = Rect2()
	var _base_radius: float = 0.0
	var _card_radius: float = 0.0
	var _frame_records: Array[Dictionary] = []

	func configure(variant_index: int, occlusion_margin: float, recipe_id: StringName) -> bool:
		if WILD_ATLAS == null or occlusion_margin < 0.0:
			return false
		z_index = -5
		z_as_relative = false
		if recipe_id == &"v3":
			if not _configure_v3_frames(variant_index):
				return false
			_measure_transformed_child_bounds(occlusion_margin)
			return _card_radius > 0.0 and _visual_bounds.size.x > 0.0 and _visual_bounds.size.y > 0.0
		if recipe_id != &"v2":
			return false
		## No root, branch, shrub, grass, or prior Recipe B region appears here.
		## The deterministic 2/3/4-frame family breaks the recurring token-like
		## silhouette while retaining the mobile 2-4 frame ecology budget.
		match variant_index:
			0:
				if not _add_frame(
					&"MossySlatePair", MOSSY_STONE_A_REGION, 43.0, Vector2(-13.0, 1.0), -0.18,
					Color("9caab1"), &"slate_pair"
				):
					return false
				if not _add_frame(
					&"NeutralPebblePair", NEUTRAL_STONE_REGION, 23.0, Vector2(18.0, 14.0), 0.31,
					Color("a9afb0"), &"slate_pair"
				):
					return false
			1:
				if not _add_frame(
					&"MossySlateArcA", MOSSY_STONE_B_REGION, 39.0, Vector2(-20.0, 7.0), 0.22,
					Color("9ba9a1"), &"broken_arc"
				):
					return false
				if not _add_frame(
					&"MossySlateArcB", MOSSY_STONE_A_REGION, 31.0, Vector2(16.0, -12.0), -0.13,
					Color("9ba7ae"), &"broken_arc"
				):
					return false
				if not _add_frame(
					&"NeutralPebbleArc", NEUTRAL_STONE_REGION, 20.0, Vector2(8.0, 20.0), 0.48,
					Color("a4aeab"), &"broken_arc"
				):
					return false
			2:
				if not _add_frame(
					&"MossySlateTriadA", MOSSY_STONE_A_REGION, 36.0, Vector2(-23.0, -6.0), -0.34,
					Color("9aa8ae"), &"mossy_triad"
				):
					return false
				if not _add_frame(
					&"MossySlateTriadB", MOSSY_STONE_B_REGION, 28.0, Vector2(13.0, 12.0), 0.16,
					Color("95a49d"), &"mossy_triad"
				):
					return false
				if not _add_frame(
					&"NeutralPebbleTriadA", NEUTRAL_STONE_REGION, 18.0, Vector2(26.0, -4.0), -0.22,
					Color("a5acad"), &"mossy_triad"
				):
					return false
				if not _add_frame(
					&"NeutralPebbleTriadB", NEUTRAL_STONE_REGION, 15.0, Vector2(-5.0, 23.0), 0.37,
					Color("9fa8aa"), &"mossy_triad"
				):
					return false
			_:
				return false
		_measure_transformed_child_bounds(occlusion_margin)
		return _card_radius > 0.0 and _visual_bounds.size.x > 0.0 and _visual_bounds.size.y > 0.0


	func _configure_v3_frames(variant_index: int) -> bool:
		## V3 rejects V2's recurring triangular stone token.  It uses low organic
		## litter with a clearly different 2/3/4-frame cadence: stump + fern,
		## then an uneven fall, then a loose floor scatter.  No grass macro or
		## rejected Recipe B branch/root silhouette is permitted here.
		match variant_index:
			0:
				if not _add_frame(
					&"StumpFernDuetStump", V3_STUMP_A_REGION, 30.0, Vector2(-12.0, 5.0), -0.22,
					Color("888276"), &"stump_fern_duet"
				):
					return false
				if not _add_frame(
					&"StumpFernDuetFern", V3_FERN_A_REGION, 26.0, Vector2(12.0, -9.0), 0.19,
					Color("6e846f"), &"stump_fern_duet"
				):
					return false
			1:
				if not _add_frame(
					&"UnevenFallStump", V3_STUMP_B_REGION, 28.0, Vector2(-16.0, 6.0), 0.29,
					Color("847b6c"), &"uneven_fall"
				):
					return false
				if not _add_frame(
					&"UnevenFallFern", V3_FERN_B_REGION, 27.0, Vector2(9.0, -11.0), -0.14,
					Color("6b8270"), &"uneven_fall"
				):
					return false
				if not _add_frame(
					&"UnevenFallPebble", NEUTRAL_STONE_REGION, 15.0, Vector2(18.0, 14.0), 0.36,
					Color("9a9d96"), &"uneven_fall"
				):
					return false
			2:
				if not _add_frame(
					&"LooseLitterFernA", V3_FERN_A_REGION, 23.0, Vector2(-18.0, -8.0), -0.28,
					Color("6c816f"), &"loose_litter"
				):
					return false
				if not _add_frame(
					&"LooseLitterStump", V3_STUMP_A_REGION, 24.0, Vector2(4.0, 10.0), 0.17,
					Color("888171"), &"loose_litter"
				):
					return false
				if not _add_frame(
					&"LooseLitterPebble", V3_BARE_PEBBLE_REGION, 15.0, Vector2(20.0, 14.0), -0.31,
					Color("999a93"), &"loose_litter"
				):
					return false
				if not _add_frame(
					&"LooseLitterFernB", V3_FERN_B_REGION, 18.0, Vector2(-6.0, 20.0), 0.44,
					Color("6b7d6c"), &"loose_litter"
				):
					return false
			_:
				return false
		return true

	func get_card_radius() -> float:
		return _card_radius

	func get_base_radius() -> float:
		return _base_radius

	func get_visual_bounds() -> Rect2:
		return _visual_bounds

	func get_frame_records() -> Array[Dictionary]:
		return _frame_records.duplicate(true)

	func _add_frame(
		frame_name: StringName,
		region: Rect2,
		target_span: float,
		local_position: Vector2,
		local_rotation: float,
		albedo_modulate: Color,
		family: StringName
	) -> bool:
		if region.size.x <= 0.0 or region.size.y <= 0.0 or target_span <= 0.0:
			return false
		var frame: AtlasTexture = AtlasTexture.new()
		frame.atlas = WILD_ATLAS
		frame.region = region
		frame.filter_clip = true
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = frame_name
		sprite.texture = frame
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.position = local_position
		sprite.rotation = local_rotation
		sprite.scale = Vector2.ONE * target_span / maxf(region.size.x, region.size.y)
		## The atlas's photographed limestone highlights were visibly brighter than
		## the survivor body in the first grayscale review.  This source-level
		## cool/neutral modulate preserves alpha and material policy while removing
		## the accidental marker hierarchy.
		sprite.self_modulate = albedo_modulate
		sprite.material = _make_cool_neutral_finish()
		add_child(sprite)
		_frame_records.append({
			"name": String(frame_name),
			"region": [region.position.x, region.position.y, region.size.x, region.size.y],
			"target_span": target_span,
			"position": [local_position.x, local_position.y],
			"rotation": local_rotation,
			"albedo_modulate": albedo_modulate.to_html(false),
			"family": String(family),
		})
		return true

	func _measure_transformed_child_bounds(occlusion_margin: float) -> void:
		var has_bounds: bool = false
		var maximum_radius: float = 0.0
		for child: Node in get_children():
			var sprite: Sprite2D = child as Sprite2D
			if sprite == null or sprite.texture == null:
				continue
			var rect: Rect2 = sprite.get_rect()
			var corners: Array[Vector2] = [
				rect.position,
				Vector2(rect.end.x, rect.position.y),
				rect.end,
				Vector2(rect.position.x, rect.end.y),
			]
			for corner: Vector2 in corners:
				var transformed: Vector2 = sprite.transform * corner
				if not has_bounds:
					_visual_bounds = Rect2(transformed, Vector2.ZERO)
					has_bounds = true
				else:
					_visual_bounds = _visual_bounds.expand(transformed)
				maximum_radius = maxf(maximum_radius, transformed.length())
		_base_radius = maximum_radius
		_card_radius = maximum_radius + occlusion_margin

	func _make_cool_neutral_finish() -> ShaderMaterial:
		var finish: ShaderMaterial = ShaderMaterial.new()
		finish.shader = SLEEK_SPRITE_SHADER
		## Cool/neutral grading is deliberately restrained: it breaks warm ground
		## repetition without turning this low-profile set into a quest marker.
		finish.set_shader_parameter(&"accent_color", Color("71838a"))
		finish.set_shader_parameter(&"saturation", 0.68)
		finish.set_shader_parameter(&"contrast", 1.16)
		finish.set_shader_parameter(&"shadow_lift", 0.008)
		finish.set_shader_parameter(&"shadow_tint", 0.16)
		finish.set_shader_parameter(&"accent_strength", 0.024)
		finish.set_shader_parameter(&"sheen_strength", 0.010)
		finish.set_shader_parameter(&"outline_width", 0.8)
		finish.set_shader_parameter(&"palette_cohesion", 0.12)
		return finish


func _ready() -> void:
	if not _configure_recipe():
		return
	if not _prepare_output_directory():
		return
	if world_map == null or atmosphere == null or camera == null or lighting == null:
		_fail("fixture is missing WorldMap2D, NightAtmosphere2D, camera, or CanvasModulate")
		return
	if not is_equal_approx(camera.zoom.x, GAMEPLAY_CAMERA_ZOOM) or not is_equal_approx(camera.zoom.y, GAMEPLAY_CAMERA_ZOOM):
		_fail("fixture camera must retain the 0.38 gameplay zoom")
		return
	camera.make_current()
	if not _load_existing_world_envelopes() or not _build_arrangements() or not _spawn_player_reference():
		return
	## The player presentation is built synchronously during configure; avoiding an
	## awaited frame keeps the static all-ten-pocket contract usable in headless.
	if not _cache_player_visual_bounds():
		return
	var patches: Array[Dictionary] = _find_all_clear_pockets()
	if patches.size() != WorldAmbientScenery2D.WILDERNESS_POCKETS.size():
		_fail("expected one clear candidate in each wilderness pocket; found %d/%d" % [
			patches.size(), WorldAmbientScenery2D.WILDERNESS_POCKETS.size(),
		])
		return
	if not _verify_static_contracts(patches):
		return
	if DisplayServer.get_name() == "headless" or OS.has_feature("headless"):
		print("WILDERNESS MICROPROP DIVERSITY CONTRACT OK | pockets=%d | max_card_radius=%.3f | GPU capture intentionally skipped" % [
			patches.size(), _get_max_arrangement_card_radius(),
		])
		get_tree().quit(0)
		return
	await get_tree().process_frame
	var captures: Array[Dictionary] = []
	var day_grayscale_tiles: Array[Image] = []
	var night_grayscale_tiles: Array[Image] = []
	for patch_index: int in range(patches.size()):
		var patch: Dictionary = patches[patch_index]
		if not await _capture_phase(patch_index, patch, "day", captures, day_grayscale_tiles):
			return
		if not await _capture_phase(patch_index, patch, "night", captures, night_grayscale_tiles):
			return
	if day_grayscale_tiles.size() != patches.size() or night_grayscale_tiles.size() != patches.size():
		_fail("every pocket must produce both day and night grayscale evidence")
		return
	if not _save_grayscale_sheet(day_grayscale_tiles, _day_grayscale_sheet_output_path):
		return
	if not _save_grayscale_sheet(night_grayscale_tiles, _night_grayscale_sheet_output_path):
		return
	_write_metadata(patches, captures)
	print("WILDERNESS MICROPROP DIVERSITY CAPTURE OK | pockets=%d | captures=%d | max_card_radius=%.3f | human_veto=pending" % [
		patches.size(), captures.size(), _get_max_arrangement_card_radius(),
	])
	get_tree().quit(0)


func _prepare_output_directory() -> bool:
	var make_directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(_output_directory)
	)
	if make_directory_error != OK:
		return _fail_bool("could not create microprop artifact directory: %s" % error_string(make_directory_error))
	return true


func _configure_recipe() -> bool:
	var requested_recipe: String = OS.get_environment("BESPREN_MICROPROP_RECIPE").strip_edges().to_lower()
	if requested_recipe.is_empty() or requested_recipe == "v2":
		_recipe_id = &"v2"
		_output_directory = V2_OUTPUT_DIRECTORY
		_metadata_output_path = _output_directory + "/wilderness_microprop_diversity_validation.json"
	elif requested_recipe == "v3":
		_recipe_id = &"v3"
		_output_directory = V3_OUTPUT_DIRECTORY
		_metadata_output_path = _output_directory + "/wilderness_microprop_diversity_v3_validation.json"
	else:
		return _fail_bool("unknown BESPREN_MICROPROP_RECIPE '%s'" % requested_recipe)
	_day_grayscale_sheet_output_path = _output_directory + "/day_grayscale_sheet.png"
	_night_grayscale_sheet_output_path = _output_directory + "/night_grayscale_sheet.png"
	return true


func _load_existing_world_envelopes() -> bool:
	var ambient: Node2D = world_map.get_node_or_null(^"AmbientScenery") as Node2D
	var accent: Node2D = world_map.get_node_or_null(^"WildernessAccent") as Node2D
	var background: WorldBackgroundDecor2D = (
		world_map.get_node_or_null(^"BackgroundDecor") as WorldBackgroundDecor2D
	)
	var ground_cover: Node2D = world_map.get_node_or_null(^"GroundCover") as Node2D
	if ambient == null or accent == null or background == null or ground_cover == null:
		return _fail_bool("WorldMap2D is missing AmbientScenery, WildernessAccent, BackgroundDecor, or GroundCover")
	var ambient_positions_variant: Variant = ambient.call(&"get_scenery_positions")
	var ambient_radii_variant: Variant = ambient.call(&"get_scenery_visual_radii")
	var accent_positions_variant: Variant = accent.call(&"get_anchor_positions")
	var accent_radii_variant: Variant = accent.call(&"get_anchor_visual_radii")
	if (
		not ambient_positions_variant is PackedVector2Array
		or not ambient_radii_variant is PackedFloat32Array
		or not accent_positions_variant is PackedVector2Array
		or not accent_radii_variant is PackedFloat32Array
	):
		return _fail_bool("ambient or wilderness-accent envelope API returned an unexpected type")
	_ambient_positions = ambient_positions_variant
	_ambient_radii = ambient_radii_variant
	_accent_positions = accent_positions_variant
	_accent_radii = accent_radii_variant
	_rubble_positions = background.get_rubble_positions()
	_rubble_radii = background.get_rubble_visual_radii()
	_moss_positions = background.get_moss_positions()
	_moss_radii = background.get_moss_visual_radii()
	_prop_positions = background.get_prop_positions()
	_prop_radii = background.get_prop_visual_radii()
	var crack_envelopes_variant: Variant = background.get_crack_visual_envelopes()
	if not crack_envelopes_variant is Array:
		return _fail_bool("background crack envelope API returned an unexpected type")
	_crack_envelopes.clear()
	for crack_envelope_variant: Variant in crack_envelopes_variant:
		if not crack_envelope_variant is Rect2:
			return _fail_bool("background crack envelope API returned a non-Rect2 entry")
		_crack_envelopes.append(crack_envelope_variant)
	if (
		_ambient_positions.size() != _ambient_radii.size()
		or _accent_positions.size() != _accent_radii.size()
		or _rubble_positions.size() != _rubble_radii.size()
		or _moss_positions.size() != _moss_radii.size()
		or _prop_positions.size() != _prop_radii.size()
	):
		return _fail_bool("one or more existing visual-envelope position/radius pairs are mismatched")
	if _ambient_positions.is_empty() or _accent_positions.is_empty() or _crack_envelopes.is_empty():
		return _fail_bool("existing world visual-envelope evidence was unexpectedly empty")
	return true


func _build_arrangements() -> bool:
	_arrangements.clear()
	for variant_index: int in range(PLAYER_REFERENCE_OFFSETS.size()):
		var arrangement: MicropropReviewArrangement = MicropropReviewArrangement.new()
		arrangement.name = StringName("%sMicropropProbe_%d" % [_recipe_id, variant_index])
		if not arrangement.configure(variant_index, CARD_OCCLUSION_MARGIN, _recipe_id):
			return _fail_bool("could not construct cool/neutral microprop variant %d" % variant_index)
		world_map.add_child(arrangement)
		arrangement.visible = false
		_arrangements.append(arrangement)
	if _arrangements.size() != PLAYER_REFERENCE_OFFSETS.size():
		return _fail_bool("microprop variant family does not match its player-reference directions")
	return true


func _spawn_player_reference() -> bool:
	_player = PLAYER_SCENE.instantiate() as PlayerAvatar
	if _player == null:
		return _fail_bool("could not instantiate baked player scale reference")
	_player.configure(1, &"heikki", world_map.get_playable_rect().get_center(), false)
	y_sort_world.add_child(_player)
	_player.set_aim_direction(Vector2.RIGHT, false)
	return true


func _cache_player_visual_bounds() -> bool:
	if _player == null or not _player.uses_baked_actor_presentation():
		return _fail_bool("player scale reference did not bind the baked actor presentation")
	var presentation: AnimatedSprite2D = _player.get_presentation_sprite()
	if presentation == null or presentation.sprite_frames == null:
		return _fail_bool("player scale reference has no baked AnimatedSprite2D frame")
	var frame_texture: Texture2D = presentation.sprite_frames.get_frame_texture(
		presentation.animation, presentation.frame
	)
	if frame_texture == null:
		return _fail_bool("player scale reference has no readable active baked frame")
	## SpriteFrames stores this actor as AtlasTexture frames.  Their inherited
	## Texture2D dimensions may describe the source sheet, so use the frame region
	## when present; otherwise the measured player-relative envelope becomes the
	## entire sprite sheet rather than the rendered survivor cell.
	var frame_size: Vector2 = frame_texture.get_size()
	var atlas_frame: AtlasTexture = frame_texture as AtlasTexture
	if atlas_frame != null and atlas_frame.region.size.x > 0.0 and atlas_frame.region.size.y > 0.0:
		frame_size = atlas_frame.region.size
	var frame_origin: Vector2 = presentation.offset
	if presentation.centered:
		frame_origin -= frame_size * 0.5
	var presentation_rect: Rect2 = Rect2(frame_origin, frame_size)
	if presentation_rect.size.x <= 0.0 or presentation_rect.size.y <= 0.0:
		return _fail_bool("player scale reference has no measurable presentation rect")
	var has_bounds: bool = false
	for corner: Vector2 in [
		presentation_rect.position,
		Vector2(presentation_rect.end.x, presentation_rect.position.y),
		presentation_rect.end,
		Vector2(presentation_rect.position.x, presentation_rect.end.y),
	]:
		var player_local_corner: Vector2 = _player.to_local(presentation.to_global(corner))
		if not has_bounds:
			_player_local_visual_bounds = Rect2(player_local_corner, Vector2.ZERO)
			has_bounds = true
		else:
			_player_local_visual_bounds = _player_local_visual_bounds.expand(player_local_corner)
	## Include the custom ground shadow/readability followers without pretending
	## that text labels are collision geometry.
	_player_local_visual_bounds = _player_local_visual_bounds.grow(8.0)
	return _player_local_visual_bounds.size.x > 0.0 and _player_local_visual_bounds.size.y > 0.0


func _get_max_arrangement_card_radius() -> float:
	var maximum_radius: float = 0.0
	for arrangement: MicropropReviewArrangement in _arrangements:
		maximum_radius = maxf(maximum_radius, arrangement.get_card_radius())
	return maximum_radius


func _find_all_clear_pockets() -> Array[Dictionary]:
	var patches: Array[Dictionary] = []
	if _arrangements.is_empty():
		_fail("microprop variant family is empty")
		return []
	for pocket_index: int in range(WorldAmbientScenery2D.WILDERNESS_POCKETS.size()):
		var pocket: Vector4 = WorldAmbientScenery2D.WILDERNESS_POCKETS[pocket_index]
		var variant_index: int = pocket_index % _arrangements.size()
		var arrangement: MicropropReviewArrangement = _arrangements[variant_index]
		var player_offset: Vector2 = PLAYER_REFERENCE_OFFSETS[variant_index]
		var candidate: Vector2 = _find_clear_candidate_in_pocket(
			pocket, arrangement, player_offset
		)
		if candidate == Vector2.INF:
			_fail("wilderness pocket %d has no clear candidate for the full %.3f-unit microprop card" % [
				pocket_index, arrangement.get_card_radius(),
			])
			return []
		patches.append(_get_patch_metadata(
			pocket_index, pocket, candidate, arrangement, variant_index, player_offset
		))
	return patches


func _find_clear_candidate_in_pocket(
	pocket: Vector4,
	arrangement: MicropropReviewArrangement,
	player_offset: Vector2
) -> Vector2:
	var card_radius: float = arrangement.get_card_radius()
	var rejection_counts: Dictionary[StringName, int] = {}
	var best_candidate: Vector2 = Vector2.INF
	var best_clearance_score: float = -INF
	for ring_index: int in range(SAMPLE_RING_COUNT):
		var radius_factor: float = 0.04 + float(ring_index) / float(SAMPLE_RING_COUNT - 1) * 0.90
		for spoke_index: int in range(SAMPLE_SPOKE_COUNT):
			var angle: float = fposmod(
				float(spoke_index) * 2.399963 + float(ring_index) * 0.37,
				TAU
			)
			var candidate: Vector2 = Vector2(pocket.x, pocket.y) + Vector2(
				cos(angle) * pocket.z * radius_factor,
				sin(angle) * pocket.w * radius_factor
			)
			var rejection: StringName = _get_candidate_rejection(
				candidate, arrangement, player_offset
			)
			if rejection.is_empty():
				var clearance_score: float = _get_candidate_clearance_score(candidate, arrangement)
				if clearance_score > best_clearance_score:
					best_clearance_score = clearance_score
					best_candidate = candidate
				continue
			rejection_counts[rejection] = rejection_counts.get(rejection, 0) + 1
	if best_candidate.is_finite():
		print("WILDERNESS MICROPROP POCKET SELECTED | center=(%.1f, %.1f) radius=%.3f score=%.3f" % [
			pocket.x, pocket.y, card_radius, best_clearance_score,
		])
		return best_candidate
	print("WILDERNESS MICROPROP POCKET REJECTION | center=(%.1f, %.1f) radius=%.3f reasons=%s" % [
		pocket.x, pocket.y, card_radius, JSON.stringify(rejection_counts),
	])
	return Vector2.INF


func _get_candidate_clearance_score(
	candidate: Vector2,
	arrangement: MicropropReviewArrangement
) -> float:
	var card_radius: float = arrangement.get_card_radius()
	var environmental_minimum: float = minf(
		minf(
			_minimum_circular_clearance(candidate, card_radius, _ambient_positions, _ambient_radii),
			_minimum_circular_clearance(candidate, card_radius, _accent_positions, _accent_radii)
		),
		minf(
			_minimum_circular_clearance(candidate, card_radius, _rubble_positions, _rubble_radii),
			_minimum_circular_clearance(candidate, card_radius, _moss_positions, _moss_radii)
		)
	)
	environmental_minimum = minf(
		environmental_minimum,
		minf(
			_minimum_circular_clearance(candidate, card_radius, _prop_positions, _prop_radii),
			_minimum_rect_clearance(candidate, card_radius, _crack_envelopes)
		)
	)
	## Every non-environmental term has already passed its hard gate before this
	## score is evaluated.  Optimize the scarce resource flagged by review: real
	## visual-envelope slack, not the first technically non-overlapping point.
	return environmental_minimum


func _get_candidate_rejection(
	candidate: Vector2,
	arrangement: MicropropReviewArrangement,
	player_offset: Vector2
) -> StringName:
	var card_radius: float = arrangement.get_card_radius()
	if not candidate.is_finite() or card_radius <= 0.0:
		return &"invalid"
	var playable_rect: Rect2 = world_map.get_playable_rect()
	var card_bounds: Rect2 = _get_card_bounds_at(arrangement, candidate)
	var player_position: Vector2 = candidate + player_offset
	var player_bounds: Rect2 = _get_player_visual_bounds_at(player_position)
	if not playable_rect.grow(-card_radius).has_point(candidate):
		return &"card_playable_bounds"
	if not _rect_inside(playable_rect, player_bounds):
		return &"player_relative_bounds"
	if not world_map.is_position_walkable(candidate, 0.0):
		return &"card_origin_walkability"
	if not world_map.is_position_walkable(player_position, 0.0):
		return &"player_origin_walkability"
	if _rect_clearance(player_bounds, card_bounds) < PLAYER_CARD_CLEARANCE:
		return &"player_card_clearance"
	var road_card_clearance: float = world_map.get_minimum_road_edge_distance(candidate) - card_radius
	if road_card_clearance < REQUIRED_ROAD_CARD_CLEARANCE:
		return &"road_card_clearance"
	var player_road_clearance: float = world_map.get_minimum_road_edge_distance(player_position) - PLAYER_ROAD_RADIUS
	if player_road_clearance < REQUIRED_PLAYER_ROAD_CLEARANCE:
		return &"road_player_clearance"
	if _minimum_circular_clearance(candidate, card_radius, _ambient_positions, _ambient_radii) < REQUIRED_ENVIRONMENT_CLEARANCE:
		return &"ambient_envelope"
	if _minimum_circular_clearance(candidate, card_radius, _accent_positions, _accent_radii) < REQUIRED_ENVIRONMENT_CLEARANCE:
		return &"accent_envelope"
	if _minimum_circular_clearance(candidate, card_radius, _rubble_positions, _rubble_radii) < REQUIRED_ENVIRONMENT_CLEARANCE:
		return &"rubble_envelope"
	if _minimum_circular_clearance(candidate, card_radius, _moss_positions, _moss_radii) < REQUIRED_ENVIRONMENT_CLEARANCE:
		return &"moss_envelope"
	if _minimum_circular_clearance(candidate, card_radius, _prop_positions, _prop_radii) < REQUIRED_ENVIRONMENT_CLEARANCE:
		return &"prop_envelope"
	if _minimum_rect_clearance(candidate, card_radius, _crack_envelopes) < REQUIRED_ENVIRONMENT_CLEARANCE:
		return &"crack_envelope"
	## GroundCover remains the intended substrate; excluding it would invalidate
	## the practical point of a ground-level nature microprop.
	return &""


func _get_patch_metadata(
	pocket_index: int,
	pocket: Vector4,
	candidate: Vector2,
	arrangement: MicropropReviewArrangement,
	variant_index: int,
	player_offset: Vector2
) -> Dictionary:
	var card_radius: float = arrangement.get_card_radius()
	var player_position: Vector2 = candidate + player_offset
	var player_bounds: Rect2 = _get_player_visual_bounds_at(player_position)
	var card_bounds: Rect2 = _get_card_bounds_at(arrangement, candidate)
	var road_edge_distance: float = world_map.get_minimum_road_edge_distance(candidate)
	var player_road_edge_distance: float = world_map.get_minimum_road_edge_distance(player_position)
	var ambient_clearance: float = _minimum_circular_clearance(
		candidate, card_radius, _ambient_positions, _ambient_radii
	)
	var accent_clearance: float = _minimum_circular_clearance(
		candidate, card_radius, _accent_positions, _accent_radii
	)
	var rubble_clearance: float = _minimum_circular_clearance(
		candidate, card_radius, _rubble_positions, _rubble_radii
	)
	var moss_clearance: float = _minimum_circular_clearance(
		candidate, card_radius, _moss_positions, _moss_radii
	)
	var prop_clearance: float = _minimum_circular_clearance(
		candidate, card_radius, _prop_positions, _prop_radii
	)
	var crack_clearance: float = _minimum_rect_clearance(candidate, card_radius, _crack_envelopes)
	return {
		"pocket_index": pocket_index,
		"pocket": [pocket.x, pocket.y, pocket.z, pocket.w],
		"position": [candidate.x, candidate.y],
		"arrangement_variant": variant_index,
		"player_reference_offset": [player_offset.x, player_offset.y],
		"selection_clearance_score": snappedf(
			_get_candidate_clearance_score(candidate, arrangement), 0.001
		),
		"card_radius": snappedf(card_radius, 0.001),
		"card_visual_bounds": _rect_to_array(card_bounds),
		"card_origin_walkable": world_map.is_position_walkable(candidate, 0.0),
		"full_card_inside_playable_rect": world_map.get_playable_rect().grow(-card_radius).has_point(candidate),
		"road_edge_distance": snappedf(road_edge_distance, 0.001),
		"road_card_clearance": snappedf(road_edge_distance - card_radius, 0.001),
		"player_relative_contract": {
			"position": [player_position.x, player_position.y],
			"visual_bounds": _rect_to_array(player_bounds),
			"body_bounds_inside_playable_rect": _rect_inside(world_map.get_playable_rect(), player_bounds),
			"origin_walkable": world_map.is_position_walkable(player_position, 0.0),
			"card_bounds_clearance": snappedf(_rect_clearance(player_bounds, card_bounds), 0.001),
			"required_card_bounds_clearance": PLAYER_CARD_CLEARANCE,
			"road_edge_distance": snappedf(player_road_edge_distance, 0.001),
			"road_clearance": snappedf(player_road_edge_distance - PLAYER_ROAD_RADIUS, 0.001),
			"required_road_clearance": REQUIRED_PLAYER_ROAD_CLEARANCE,
		},
		"environment_envelopes": {
			"required_clearance": REQUIRED_ENVIRONMENT_CLEARANCE,
			"ambient": snappedf(ambient_clearance, 0.001),
			"wilderness_accent": snappedf(accent_clearance, 0.001),
			"background_rubble": snappedf(rubble_clearance, 0.001),
			"background_cracks": snappedf(crack_clearance, 0.001),
			"background_moss": snappedf(moss_clearance, 0.001),
			"background_props": snappedf(prop_clearance, 0.001),
			"no_intersection": (
				ambient_clearance >= REQUIRED_ENVIRONMENT_CLEARANCE
				and accent_clearance >= REQUIRED_ENVIRONMENT_CLEARANCE
				and rubble_clearance >= REQUIRED_ENVIRONMENT_CLEARANCE
				and crack_clearance >= REQUIRED_ENVIRONMENT_CLEARANCE
				and moss_clearance >= REQUIRED_ENVIRONMENT_CLEARANCE
				and prop_clearance >= REQUIRED_ENVIRONMENT_CLEARANCE
			),
		},
		"ground_cover_policy": "retained_as_substrate_not_used_as_an_exclusion_envelope",
	}


func _get_card_bounds_at(arrangement: MicropropReviewArrangement, position: Vector2) -> Rect2:
	var local_bounds: Rect2 = arrangement.get_visual_bounds().grow(CARD_OCCLUSION_MARGIN)
	return Rect2(local_bounds.position + position, local_bounds.size)


func _get_player_visual_bounds_at(position: Vector2) -> Rect2:
	return Rect2(_player_local_visual_bounds.position + position, _player_local_visual_bounds.size)


func _rect_inside(outer: Rect2, inner: Rect2) -> bool:
	return (
		outer.has_point(inner.position)
		and outer.has_point(inner.end - Vector2(0.001, 0.001))
	)


func _rect_clearance(first: Rect2, second: Rect2) -> float:
	if first.intersects(second):
		return -minf(
			minf(first.end.x - second.position.x, second.end.x - first.position.x),
			minf(first.end.y - second.position.y, second.end.y - first.position.y)
		)
	var horizontal_gap: float = maxf(
		maxf(first.position.x - second.end.x, second.position.x - first.end.x), 0.0
	)
	var vertical_gap: float = maxf(
		maxf(first.position.y - second.end.y, second.position.y - first.end.y), 0.0
	)
	return Vector2(horizontal_gap, vertical_gap).length()


func _minimum_circular_clearance(
	candidate: Vector2,
	card_radius: float,
	positions: PackedVector2Array,
	radii: PackedFloat32Array
) -> float:
	var minimum_clearance: float = 1000000.0
	for index: int in range(positions.size()):
		minimum_clearance = minf(
			minimum_clearance,
			candidate.distance_to(positions[index]) - card_radius - radii[index]
		)
	return minimum_clearance


func _minimum_rect_clearance(
	candidate: Vector2,
	card_radius: float,
	envelopes: Array[Rect2]
) -> float:
	var minimum_clearance: float = 1000000.0
	for envelope: Rect2 in envelopes:
		var nearest_point: Vector2 = Vector2(
			clampf(candidate.x, envelope.position.x, envelope.end.x),
			clampf(candidate.y, envelope.position.y, envelope.end.y)
		)
		minimum_clearance = minf(minimum_clearance, candidate.distance_to(nearest_point) - card_radius)
	return minimum_clearance


func _verify_static_contracts(patches: Array[Dictionary]) -> bool:
	if _arrangements.is_empty() or _player == null:
		return _fail_bool("microprop variant family or player scale reference is missing")
	if _arrangements.size() != PLAYER_REFERENCE_OFFSETS.size():
		return _fail_bool("microprop variants and player-reference offsets no longer agree")
	if WILD_ATLAS.get_width() <= 0 or WILD_ATLAS.get_height() <= 0:
		return _fail_bool("installed runtime wild atlas has no renderable dimensions")
	var atlas_bounds: Rect2 = Rect2(
		Vector2.ZERO, Vector2(float(WILD_ATLAS.get_width()), float(WILD_ATLAS.get_height()))
	)
	var player_body_radius: float = maxf(
		maxf(_player_local_visual_bounds.position.length(), _player_local_visual_bounds.end.length()),
		maxf(
			Vector2(_player_local_visual_bounds.position.x, _player_local_visual_bounds.end.y).length(),
			Vector2(_player_local_visual_bounds.end.x, _player_local_visual_bounds.position.y).length()
		)
	)
	var frame_counts: Dictionary[int, bool] = {}
	var families: Dictionary[StringName, bool] = {}
	for arrangement: MicropropReviewArrangement in _arrangements:
		if arrangement.get_base_radius() <= 0.0 or arrangement.get_card_radius() <= 0.0:
			return _fail_bool("transformed child-rect microprop radius was not calculated")
		if arrangement.get_card_radius() <= arrangement.get_base_radius():
			return _fail_bool("occlusion envelope was not applied to microprop radius")
		if arrangement.get_base_radius() >= player_body_radius:
			return _fail_bool("microprop card no longer remains lower-profile than the baked player body")
		var frame_records: Array[Dictionary] = arrangement.get_frame_records()
		if frame_records.size() < 2 or frame_records.size() > 4:
			return _fail_bool("microprop variant escaped the 2-4 frame mobile ecology budget")
		frame_counts[frame_records.size()] = true
		for frame_record: Dictionary in frame_records:
			var region_data: Variant = frame_record.get("region", [])
			if not region_data is Array or region_data.size() != 4:
				return _fail_bool("microprop frame record has malformed atlas region data")
			var region: Rect2 = Rect2(
				Vector2(float(region_data[0]), float(region_data[1])),
				Vector2(float(region_data[2]), float(region_data[3]))
			)
			if not _rect_inside(atlas_bounds, region):
				return _fail_bool("microprop frame reaches outside the installed approved atlas")
			if float(frame_record.get("target_span", 0.0)) > MAX_MICROPROP_FRAME_SPAN:
				return _fail_bool("microprop frame exceeds the low-profile 48-unit span cap")
			var family: StringName = StringName(frame_record.get("family", ""))
			if family.is_empty():
				return _fail_bool("microprop frame has no deterministic scatter-family identity")
			families[family] = true
			for rejected_region: Rect2 in REJECTED_RECIPE_B_REGIONS:
				if region == rejected_region:
					return _fail_bool("microprop frame reuses a rejected Recipe B source region")
	if frame_counts.size() != 3 or families.size() != 3:
		return _fail_bool("microprop family lost its required 2/3/4-frame scatter variation")
	if patches.size() != WorldAmbientScenery2D.WILDERNESS_POCKETS.size():
		return _fail_bool("not every wilderness pocket received an objective placement check")
	for patch: Dictionary in patches:
		var player_contract: Variant = patch.get("player_relative_contract", {})
		var environment: Variant = patch.get("environment_envelopes", {})
		if not player_contract is Dictionary or not environment is Dictionary:
			return _fail_bool("patch metadata is missing player-relative or environmental contract")
		if not bool(player_contract.get("body_bounds_inside_playable_rect", false)):
			return _fail_bool("a player-relative body bound left the playable rectangle")
		if float(player_contract.get("card_bounds_clearance", -1.0)) < PLAYER_CARD_CLEARANCE:
			return _fail_bool("a player-relative body bound reaches the microprop card")
		if float(player_contract.get("road_clearance", -1.0)) < REQUIRED_PLAYER_ROAD_CLEARANCE:
			return _fail_bool("a player-relative reference violates road clearance")
		if float(environment.get("required_clearance", -1.0)) != REQUIRED_ENVIRONMENT_CLEARANCE:
			return _fail_bool("a patch is missing the meaningful environmental clearance floor")
		if not bool(environment.get("no_intersection", false)):
			return _fail_bool("a microprop card fails the meaningful existing render-envelope clearance")
	return true


func _capture_phase(
	patch_index: int,
	patch: Dictionary,
	phase: String,
	captures: Array[Dictionary],
	grayscale_tiles: Array[Image]
) -> bool:
	var patch_position: Vector2 = _dictionary_position(patch, &"position")
	if not patch_position.is_finite():
		return _fail_bool("patch %d has no finite world position" % patch_index)
	var variant_value: Variant = patch.get("arrangement_variant", -1)
	if not (variant_value is int) or int(variant_value) < 0 or int(variant_value) >= _arrangements.size():
		return _fail_bool("patch %d has no valid microprop variant" % patch_index)
	var arrangement: MicropropReviewArrangement = _arrangements[int(variant_value)]
	for other_arrangement: MicropropReviewArrangement in _arrangements:
		other_arrangement.visible = other_arrangement == arrangement
		other_arrangement.position = patch_position
	var player_offset: Vector2 = _dictionary_position(patch, &"player_reference_offset")
	if not player_offset.is_finite():
		return _fail_bool("patch %d has no valid player reference offset" % patch_index)
	var player_position: Vector2 = patch_position + player_offset
	_player.apply_authoritative_state(player_position, Vector2.ZERO)
	_player.global_position = player_position
	camera.position = patch_position
	camera.zoom = Vector2.ONE * GAMEPLAY_CAMERA_ZOOM
	if phase == "day":
		lighting.color = NightAtmosphere2D.DAY_COLOR
		atmosphere.set_night_active(false, true)
		_player.set_aim_direction(Vector2.RIGHT, false)
	else:
		atmosphere.register_player(_player)
		atmosphere.set_night_active(true, true)
		_player.set_aim_direction(Vector2.UP, true)
		if not _player.is_flashlight_enabled():
			return _fail_bool("night capture did not enable the real baked-player flashlight path")
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return _fail_bool("empty viewport for pocket %d %s" % [patch_index, phase])
	if not _normalize_to_logical_capture(image):
		return false
	var output_stem: String = "pocket_%02d_%s" % [patch_index, phase]
	var output_path: String = "%s/%s.png" % [_output_directory, output_stem]
	if not _save_image(image, output_path):
		return false
	var grayscale: Image = _to_grayscale(image)
	var grayscale_path: String = "%s/%s_grayscale.png" % [_output_directory, output_stem]
	if not _save_image(grayscale, grayscale_path):
		return false
	grayscale_tiles.append(grayscale)
	captures.append({
		"pocket_index": patch_index,
		"position": [patch_position.x, patch_position.y],
		"phase": phase,
		"output": output_path,
		"grayscale_output": grayscale_path,
		"arrangement_variant": int(variant_value),
		"player_reference_offset": [player_offset.x, player_offset.y],
		"card_radius": snappedf(arrangement.get_card_radius(), 0.001),
	})
	return true


func _normalize_to_logical_capture(image: Image) -> bool:
	_native_capture_size = image.get_size()
	if (
		_native_capture_size.x <= 0
		or _native_capture_size.y <= 0
		or _native_capture_size.x % LOGICAL_CAPTURE_SIZE.x != 0
		or _native_capture_size.y % LOGICAL_CAPTURE_SIZE.y != 0
	):
		return _fail_bool("native viewport is %s; expected an integer scale of %s" % [
			_native_capture_size, LOGICAL_CAPTURE_SIZE,
		])
	var horizontal_scale: int = int(float(_native_capture_size.x) / float(LOGICAL_CAPTURE_SIZE.x))
	var vertical_scale: int = int(float(_native_capture_size.y) / float(LOGICAL_CAPTURE_SIZE.y))
	if horizontal_scale != vertical_scale:
		return _fail_bool("native viewport scale is non-uniform")
	_native_capture_scale = horizontal_scale
	if image.get_size() != LOGICAL_CAPTURE_SIZE:
		image.resize(LOGICAL_CAPTURE_SIZE.x, LOGICAL_CAPTURE_SIZE.y, Image.INTERPOLATE_LANCZOS)
	if image.get_size() != LOGICAL_CAPTURE_SIZE:
		return _fail_bool("logical capture did not resolve to 480x270")
	image.convert(Image.FORMAT_RGBA8)
	return true


func _to_grayscale(source: Image) -> Image:
	var grayscale: Image = source.duplicate()
	grayscale.convert(Image.FORMAT_RGBA8)
	for pixel_y: int in range(grayscale.get_height()):
		for pixel_x: int in range(grayscale.get_width()):
			var color: Color = grayscale.get_pixel(pixel_x, pixel_y)
			var luma: float = color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			grayscale.set_pixel(pixel_x, pixel_y, Color(luma, luma, luma, color.a))
	return grayscale


func _save_grayscale_sheet(images: Array[Image], output_path: String) -> bool:
	var rows: int = ceili(float(images.size()) / float(GRAYSCALE_SHEET_COLUMNS))
	var sheet_size: Vector2i = Vector2i(
		GRAYSCALE_TILE_SIZE.x * GRAYSCALE_SHEET_COLUMNS,
		GRAYSCALE_TILE_SIZE.y * rows
	)
	var sheet: Image = Image.create(sheet_size.x, sheet_size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("101513"))
	for image_index: int in range(images.size()):
		var tile: Image = images[image_index].duplicate()
		tile.resize(GRAYSCALE_TILE_SIZE.x, GRAYSCALE_TILE_SIZE.y, Image.INTERPOLATE_LANCZOS)
		var destination: Vector2i = Vector2i(
			(image_index % GRAYSCALE_SHEET_COLUMNS) * GRAYSCALE_TILE_SIZE.x,
			(image_index / GRAYSCALE_SHEET_COLUMNS) * GRAYSCALE_TILE_SIZE.y
		)
		sheet.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), destination)
	return _save_image(sheet, output_path)


func _save_image(image: Image, output_path: String) -> bool:
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		return _fail_bool("could not save %s: %s" % [output_path, error_string(save_error)])
	return true


func _write_metadata(patches: Array[Dictionary], captures: Array[Dictionary]) -> void:
	var variant_records: Array[Dictionary] = []
	for variant_index: int in range(_arrangements.size()):
		var arrangement: MicropropReviewArrangement = _arrangements[variant_index]
		var frame_records: Array[Dictionary] = arrangement.get_frame_records()
		variant_records.append({
			"variant_index": variant_index,
			"player_reference_offset": [
				PLAYER_REFERENCE_OFFSETS[variant_index].x,
				PLAYER_REFERENCE_OFFSETS[variant_index].y,
			],
			"frame_count": frame_records.size(),
			"base_radius_from_transformed_child_rects": snappedf(arrangement.get_base_radius(), 0.001),
			"card_radius_with_16px_margin": snappedf(arrangement.get_card_radius(), 0.001),
			"transformed_bounds": _rect_to_array(arrangement.get_visual_bounds()),
			"frames": frame_records,
		})
	var metadata: Dictionary = {
		"artifact_only": true,
		"runtime_promotion": "forbidden_pending_human_visual_veto",
		"recipe": String(_recipe_id),
		"output_directory": _output_directory,
		"human_veto_status": "PENDING: visual direction must accept/reject %s before any independent runtime proposal; objective pass is not approval" % _recipe_id,
		"candidate": (
			"low_profile_stump_fern_pebble_ground_litter" if _recipe_id == &"v3"
			else "cool_neutral_low_profile_mossy_stone_microset"
		),
		"recipe_b_status": "preserved_untouched_and_rejected_in_existing_wild_atlas_context_validation",
		"recipe_b_exclusion_contract": "frame regions are asserted distinct from every rejected Recipe B root/branch/shrub atlas region",
		"source_atlas": "res://assets/2d/environment/polyhaven_wild/polyhaven_wild_atlas.png",
		"source_atlas_sha256": "20497d4d1d2e7560be0b35001f6c6256168c85fd0880d44b42ea9cf7d46d832e",
		"source_policy": "only installed approved baked atlas regions sampled; no raw Addons, Poly Haven, GLTF, Blender scene, mesh, PBR graph, or Node3D dependency enters runtime/export closure",
		"offline_reference": {
			"blender_polyhaven": "read-only Poly Haven nature query considered low-profile rocks and ground-cover families; no download/import executed",
			"addons": "read-only vault discovery noted Pixel Crawler static rocks and Craftpix rocks as diversity references only; neither was copied or loaded",
		},
		"capture_scope": "isolated presentation-only test sibling; no world decor values, map scene, collision, flow field, authority, mobile input, or export dependency changed",
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"logical_size": [LOGICAL_CAPTURE_SIZE.x, LOGICAL_CAPTURE_SIZE.y],
		"native_capture_size": [_native_capture_size.x, _native_capture_size.y],
		"native_capture_scale": _native_capture_scale,
		"camera_zoom": GAMEPLAY_CAMERA_ZOOM,
		"pocket_contract": "all ten WorldAmbientScenery2D.WILDERNESS_POCKETS were assessed; no convenient-subset early exit",
		"pocket_count": patches.size(),
		"patches": patches,
		"iteration_history": {
			"v1": "HOLD: fixed three-stone silhouette and merely-positive material envelope gaps read as a recurring waypoint risk",
			"v2": "HOLD: three deterministic 2/3/4-frame cool-neutral stone variants passed objective clearance but still read as a repeated dark triangular token at gameplay scale",
			"v3": "staging-only stump/fern/pebble ground-litter family; it preserves all v2 clearance and all-ten-pocket gates while forbidding Recipe B roots/branches and the rejected V2 stone-token arrangement",
		},
		"variation_contract": "three deterministic scatter families span 2, 3, and 4 source frames with varied count, spacing, rotation, scale, cool-neutral albedo, and player-reference approach; every frame stays at or under 48 units",
		"arrangement_variants": variant_records,
		"clearance_contract": "full transformed card remains inside the playable rectangle, clears the road edge, and keeps at least 64 world units from every ambient, wilderness-accent, rubble, crack, moss, and prop render envelope; the live baked-player body bound has explicit playable, walkable, road, and card-clearance gates",
		"ground_cover_policy": "GroundCover remains visible substrate and is deliberately not an exclusion envelope",
		"capture_count": captures.size(),
		"captures": captures,
		"grayscale_contract": "every day and night pocket capture has its own 480x270 grayscale output; day and night 5x2 contact sheets cover all ten pockets",
		"day_grayscale_sheet": _day_grayscale_sheet_output_path,
		"night_grayscale_sheet": _night_grayscale_sheet_output_path,
		"night_lighting": "NightAtmosphere2D registered the real baked-player flashlight before every night capture",
		"review_requirement": "Human art-direction veto is mandatory. Green placement/capture contracts do not certify Android performance, touch ergonomics, LAN behavior, animation/motion readability, or premium quality and do not authorize runtime promotion.",
	}
	var metadata_file: FileAccess = FileAccess.open(
		ProjectSettings.globalize_path(_metadata_output_path), FileAccess.WRITE
	)
	if metadata_file == null:
		_fail("could not write wilderness microprop metadata")
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()


func _dictionary_position(source: Dictionary, key: StringName) -> Vector2:
	var value: Variant = source.get(key, [])
	if not value is Array or value.size() != 2:
		return Vector2.INF
	var coordinates: Array = value
	if not (coordinates[0] is float or coordinates[0] is int) or not (coordinates[1] is float or coordinates[1] is int):
		return Vector2.INF
	return Vector2(float(coordinates[0]), float(coordinates[1]))


func _rect_to_array(rect: Rect2) -> Array[float]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _fail_bool(message: String) -> bool:
	_fail(message)
	return false


func _fail(message: String) -> void:
	push_error("WILDERNESS MICROPROP DIVERSITY FAILED: %s" % message)
	get_tree().quit(1)
