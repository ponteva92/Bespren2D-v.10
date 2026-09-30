extends SceneTree

## Focused contract for the survivor's gameplay-scale silhouette treatment.
##
## This is deliberately a structural and state gate, not a claim that an
## off-screen headless run can certify premium art.  It proves that the new
## visible contour follows the *same* eight-way baked alpha frames as the live
## body, stays behind it in tree draw order, differentiates the two survivors
## through source silhouettes and contour geometry, and does not smuggle a
## light, collision body, action state, or authority path into presentation.

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/network_player.tscn")
const GAMEPLAY_ZOOM: float = 0.38
const MIN_EDGE_SCREEN_PX: float = 1.0
const MAX_EDGE_SCREEN_PX: float = 4.0

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	var presentation_root: Node2D = Node2D.new()
	presentation_root.name = &"PlayerAvatarReadabilityValidationRoot"
	root.add_child(presentation_root)
	var heikki: PlayerAvatar = _spawn_player(
		presentation_root,
		1,
		&"heikki",
		Vector2(-120.0, 0.0)
	)
	var shane: PlayerAvatar = _spawn_player(
		presentation_root,
		2,
		&"shane",
		Vector2(120.0, 0.0)
	)
	if heikki == null or shane == null:
		_fail("could not instantiate both live PlayerAvatar presentation subjects")
		_finish(presentation_root)
		return
	await process_frame
	await physics_frame

	_validate_subject(heikki, &"heikki")
	_validate_subject(shane, &"shane")
	_validate_identity_without_hue(heikki, shane)
	await _validate_direction_and_action_following(heikki)
	await _validate_downed_visibility(heikki)
	_finish(presentation_root)


func _spawn_player(
	presentation_root: Node2D,
	peer_id: int,
	character_id: StringName,
	spawn_position: Vector2
) -> PlayerAvatar:
	var player: PlayerAvatar = PLAYER_SCENE.instantiate() as PlayerAvatar
	if player == null:
		return null
	## This is a remote subject on purpose: it proves the treatment is not a
	## local-camera effect and cannot be a source of local authority state.
	player.configure(peer_id, character_id, spawn_position, false)
	presentation_root.add_child(player)
	return player


func _validate_subject(player: PlayerAvatar, character_id: StringName) -> void:
	var body: AnimatedSprite2D = player.get_presentation_sprite()
	var keyline: AnimatedSprite2D = player.get_readability_keyline()
	var rim: AnimatedSprite2D = player.get_identity_rim()
	var collision: CollisionShape2D = player.get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	var expected_keyline_multiplier: Vector2 = (
		PlayerAvatar.SHANE_KEYLINE_SCALE
		if character_id == &"shane"
		else PlayerAvatar.HEIKKI_KEYLINE_SCALE
	)
	var expected_rim_multiplier: Vector2 = (
		PlayerAvatar.SHANE_IDENTITY_RIM_SCALE
		if character_id == &"shane"
		else PlayerAvatar.HEIKKI_IDENTITY_RIM_SCALE
	)
	_check(
		player.uses_baked_actor_presentation()
		and player.has_gameplay_readability_treatment()
		and body != null
		and keyline != null
		and rim != null,
		"%s binds the live baked body plus both presentation-only followers" % character_id
	)
	if body == null or keyline == null or rim == null:
		return
	_check(
		keyline.sprite_frames == body.sprite_frames
		and rim.sprite_frames == body.sprite_frames
		and keyline.offset.is_equal_approx(body.offset)
		and rim.offset.is_equal_approx(body.offset),
		"%s followers reuse the exact source frame alpha and pivot" % character_id
	)
	_check(
		keyline.get_index() < rim.get_index()
		and rim.get_index() < body.get_index(),
		"%s keyline and rim stay behind the unmodified body in draw order" % character_id
	)
	_check(
		keyline.scale.is_equal_approx(body.scale * expected_keyline_multiplier)
		and rim.scale.is_equal_approx(body.scale * expected_rim_multiplier),
		"%s contour retains its authored gameplay-scale expansion" % character_id
	)
	var outline_extent: Vector2 = _screen_outline_extent(body, keyline)
	_check(
		outline_extent.x >= MIN_EDGE_SCREEN_PX
		and outline_extent.y >= MIN_EDGE_SCREEN_PX
		and outline_extent.x <= MAX_EDGE_SCREEN_PX
		and outline_extent.y <= MAX_EDGE_SCREEN_PX,
		"%s keyline contributes a %.2fx%.2f px contour at the 0.38 gameplay camera"
		% [character_id, outline_extent.x, outline_extent.y]
	)
	_check(
		player.get_node_or_null(^"VisualAnchor/MotionBob/ReadabilityKeyline") == keyline
		and player.get_node_or_null(^"VisualAnchor/MotionBob/IdentityRim") == rim
		and player.get_node_or_null(^"VisualAnchor/MotionBob/PointLight2D") == null
		and player.get_node_or_null(^"VisualAnchor/MotionBob/CollisionShape2D") == null,
		"%s treatment adds no light, collision, or HUD node to the animation branch" % character_id
	)
	_check(
		collision != null
		and collision.shape is CircleShape2D
		and player.collision_layer == 1
		and player.collision_mask == 2
		and not player.is_local_player
		and not player.get_node_or_null(^"Camera2D").enabled,
		"%s treatment preserves CharacterBody2D collision and remote-camera contracts" % character_id
	)


func _validate_identity_without_hue(heikki: PlayerAvatar, shane: PlayerAvatar) -> void:
	var heikki_body: AnimatedSprite2D = heikki.get_presentation_sprite()
	var shane_body: AnimatedSprite2D = shane.get_presentation_sprite()
	var heikki_keyline: AnimatedSprite2D = heikki.get_readability_keyline()
	var shane_keyline: AnimatedSprite2D = shane.get_readability_keyline()
	if heikki_body == null or shane_body == null or heikki_keyline == null or shane_keyline == null:
		_fail("could not resolve both survivor silhouettes for identity validation")
		return
	_check(
		heikki_body.sprite_frames.resource_path != shane_body.sprite_frames.resource_path,
		"Heikki and Shane retain distinct authored baked silhouette sources"
	)
	var heikki_multiplier: Vector2 = heikki_keyline.scale / heikki_body.scale
	var shane_multiplier: Vector2 = shane_keyline.scale / shane_body.scale
	_check(
		heikki_multiplier.x > heikki_multiplier.y
		and shane_multiplier.y > shane_multiplier.x,
		"the survivor treatment carries broad-versus-tall contour identity without relying on color"
	)
	_check(
		not heikki_keyline.self_modulate.is_equal_approx(heikki.get_identity_rim().self_modulate)
		and not shane_keyline.self_modulate.is_equal_approx(shane.get_identity_rim().self_modulate),
		"identity tint remains a secondary rim over the neutral silhouette keyline"
	)


func _validate_direction_and_action_following(player: PlayerAvatar) -> void:
	var keyline: AnimatedSprite2D = player.get_readability_keyline()
	var rim: AnimatedSprite2D = player.get_identity_rim()
	if keyline == null or rim == null:
		_fail("could not resolve followers for directional action validation")
		return
	for row: int in range(ActorFacing.ROW_COUNT):
		player.set_aim_direction(ActorFacing.ROW_HEADINGS[row], true)
		await process_frame
		var expected_idle: StringName = ActorFacing.animation_name(&"idle", row)
		_check(
			player.get_presentation_animation() == expected_idle
			and keyline.animation == expected_idle
			and rim.animation == expected_idle
			and _followers_match_body_frame(player, keyline, rim),
			"row %d keeps body, keyline, and rim on one idle heading/frame" % row
		)
	player.play_interaction_feedback(&"fire")
	await process_frame
	var expected_shoot: StringName = ActorFacing.animation_name(
		&"shoot",
		player.get_presentation_facing_row()
	)
	_check(
		player.get_presentation_animation() == expected_shoot
		and keyline.animation == expected_shoot
		and rim.animation == expected_shoot
		and _followers_match_body_frame(player, keyline, rim),
		"the existing fire action synchronizes both silhouette followers without a new action path"
	)
	player.set_combat_state(99, true)
	await process_frame
	var expected_hit: StringName = ActorFacing.animation_name(
		&"hit",
		player.get_presentation_facing_row()
	)
	_check(
		player.get_presentation_animation() == expected_hit
		and keyline.animation == expected_hit
		and rim.animation == expected_hit
		and _followers_match_body_frame(player, keyline, rim),
		"the existing hit action synchronizes both silhouette followers without combat mutation"
	)


func _validate_downed_visibility(player: PlayerAvatar) -> void:
	var keyline: AnimatedSprite2D = player.get_readability_keyline()
	var rim: AnimatedSprite2D = player.get_identity_rim()
	var collision: CollisionShape2D = player.get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if keyline == null or rim == null or collision == null:
		_fail("could not resolve downed-state presentation nodes")
		return
	player.set_combat_state(0, false)
	await physics_frame
	_check(
		not keyline.visible
		and not rim.visible
		and player.get_presentation_animation() == ActorFacing.animation_name(
			&"death",
			player.get_presentation_facing_row()
		)
		and collision.disabled,
		"downed state retires the persistent rim/keyline for the existing red rescue treatment"
	)
	player.set_combat_state(100, true)
	await process_frame
	_check(
		keyline.visible
		and rim.visible
		and player.is_combat_alive(),
		"respawn restores the same presentation-only treatment without re-instancing it"
	)


func _screen_outline_extent(body: AnimatedSprite2D, keyline: AnimatedSprite2D) -> Vector2:
	var body_texture: Texture2D = body.sprite_frames.get_frame_texture(body.animation, body.frame)
	if body_texture == null:
		return Vector2.ZERO
	var frame_size: Vector2 = body_texture.get_size()
	var scale_delta: Vector2 = (keyline.scale.abs() - body.scale.abs()).abs()
	return frame_size * scale_delta * GAMEPLAY_ZOOM * 0.5


func _followers_match_body_frame(
	player: PlayerAvatar,
	keyline: AnimatedSprite2D,
	rim: AnimatedSprite2D
) -> bool:
	var body: AnimatedSprite2D = player.get_presentation_sprite()
	return (
		body != null
		and keyline.frame == body.frame
		and rim.frame == body.frame
	)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS | %s" % message)
		return
	_fail(message)


func _fail(message: String) -> void:
	_failures += 1
	push_error("PLAYER AVATAR READABILITY FAILED: %s" % message)


func _finish(presentation_root: Node2D) -> void:
	if is_instance_valid(presentation_root):
		presentation_root.queue_free()
	if _failures == 0:
		print("PLAYER AVATAR READABILITY OK (%d checks)" % _checks)
		quit(0)
		return
	push_error("PLAYER AVATAR READABILITY FAILED (%d/%d checks failed)" % [_failures, _checks])
	quit(1)
