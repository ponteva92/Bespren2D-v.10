class_name PlayerAvatar
extends CharacterBody2D
## Physics-backed presentation shell driven only by host-authored Vector2 state.

const HEIKKI_SCENE: PackedScene = preload("res://scenes/characters/heikki.tscn")
const SHANE_SCENE: PackedScene = preload("res://scenes/characters/shane.tscn")
## The legacy scenes above remain the explicit compatibility path.  The actor
## bakes are presentation-only: movement, collision, and network state still
## live on this CharacterBody2D.
const BAKED_HEIKKI_SCENE: PackedScene = preload("res://assets/2d/actors/scenes/hero_heikki.tscn")
const BAKED_SHANE_SCENE: PackedScene = preload("res://assets/2d/actors/scenes/hero_shane.tscn")
const SNAP_DISTANCE: float = 72.0
const FOLLOW_RATE: float = 15.0
const STOP_EPSILON: float = 0.05
const IDLE_ANIMATION: StringName = &"Idle"
const RUN_ANIMATION: StringName = &"Run"
const BAKED_IDLE_CLIP: StringName = &"idle"
const BAKED_RUN_CLIP: StringName = &"run"
const BAKED_SHOOT_CLIP: StringName = &"shoot"
const BAKED_GATHER_CLIP: StringName = &"gather"
const BAKED_HIT_CLIP: StringName = &"hit"
const BAKED_DEATH_CLIP: StringName = &"death"
const GATHER_PRESENTATION_SECONDS: float = 0.55
## A baked body now occupies roughly 22x42 authored pixels inside its cell,
## twice what it did while the death pose was sizing the shared frame. At the
## live 0.38 gameplay camera this presentation-only scale halves to match, so
## the survivor keeps the same read on screen and gets it from twice the
## pixels. Collision, targeting, and replicated positions remain unscaled.
const BAKED_ACTOR_VISUAL_SCALE: float = 1.5

## The authored survivor sheets are deliberately the source of the gameplay
## silhouette.  At the live 0.38 camera, however, their painted edge can merge
## into the wild-ground values before a player has time to resolve a heading or
## an action.  These two followers reuse the exact same frame alpha, heading,
## and action as the body: a charcoal keyline holds the figure against bright
## ground, while the smaller identity rim keeps Heikki's broader and Shane's
## taller read visible in low-value night ground.  They are not lights, UI, or
## a new gameplay object -- they are two presentation-only draws behind the
## existing baked sprite and disappear with the normal downed treatment.
const READABILITY_KEYLINE_COLOR: Color = Color(0.015, 0.028, 0.030, 0.92)
const HEIKKI_IDENTITY_RIM_COLOR: Color = Color(0.78, 0.53, 0.23, 0.68)
const SHANE_IDENTITY_RIM_COLOR: Color = Color(0.22, 0.70, 0.73, 0.68)
## These are deliberately anisotropic.  The distinction is carried by the
## baked alpha silhouette and its wide/tall contour, not by the rim hue alone.
const HEIKKI_KEYLINE_SCALE: Vector2 = Vector2(1.17, 1.11)
const SHANE_KEYLINE_SCALE: Vector2 = Vector2(1.10, 1.18)
const HEIKKI_IDENTITY_RIM_SCALE: Vector2 = Vector2(1.095, 1.055)
const SHANE_IDENTITY_RIM_SCALE: Vector2 = Vector2(1.050, 1.105)

## Bar geometry in world units. The survivor is an idle cell of 56 baked pixels
## at [constant BAKED_ACTOR_VISUAL_SCALE], so roughly 84 units tall with its feet
## near the shadow at +12.75 - about 23 screen pixels at the gameplay camera's
## 0.38 zoom. A 37-unit bar is therefore some 14 screen pixels wide over a 23-pixel
## body, which is the proportion the reference games use, and 5 units of height
## survives the same divide at just under two pixels plus its outline. The
## previous readout was a font-7 Label, which resolved to 2.7 screen pixels of
## glyph: it was never legible, and that is the gap this closes.
const HEALTH_BAR_SIZE: Vector2 = Vector2(37.0, 8.0)
## A single midpoint tick. Quarters were the first instinct, but three dividers
## at a screen pixel each would eat a fifth of a fourteen-pixel bar; one tick
## still answers the only question a glance really asks at this size, which is
## whether the survivor is above or below half.
const HEALTH_BAR_SEGMENTS: int = 2

## World units between footfalls, and world units because the gameplay camera
## sits at 0.38 zoom - this is roughly twenty screen pixels of travel, which is
## a stride at the size a survivor actually reads on a 480x270 canvas rather
## than the size he is in the texture.
const FOOTFALL_STRIDE: float = 56.0
## Below this the survivor is settling into a stop, not walking, and a puff
## there reads as the ground moving on its own.
const FOOTFALL_MIN_SPEED: float = 40.0
## Mirrors [constant CombatStateCoordinator.PLAYER_MAX_HEALTH]. Duplicated as a
## constant rather than read across, because the avatar is a presentation node
## and reaching into the authority coordinator to draw a bar would give every
## client a dependency on a system only the host actually runs.
const COMBAT_MAX_HEALTH: float = 100.0

## Raised at the point the survivor is standing on, for anything that wants to
## put something on the ground there. The avatar has no opinion about what.
signal footfall(world_position: Vector2)

@onready var visual_anchor: Node2D = %VisualAnchor
@onready var motion_bob: Node2D = %MotionBob
## Sits on the body rather than under VisualAnchor on purpose. The interaction
## tween squashes and mirrors that anchor, and MotionBob lifts the sprite, so a
## shadow parented to either would stretch and rise with the survivor instead of
## staying on the ground the survivor is standing on.
##
## Being that sibling is also why the scene's +12.75 is a world unit rather than
## a sheet pixel: only the sprite carries [constant BAKED_ACTOR_VISUAL_SCALE], so
## the 8.5 sheet pixels between the baked origin and the feet arrive here already
## multiplied by 1.5. The bake pins the sprite to the projected world origin, and
## in a three-quarter view a planted foot projects below that origin - measured
## over all eight headings and every idle frame the ellipse drawn at +0 covered
## two percent of the survivors' foot pixels. See CLAUDE.md 9.
@onready var ground_shadow: ActorGroundShadow2D = %Shadow
@onready var name_label: Label = %NameLabel
@onready var camera: Camera2D = %Camera2D
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var health_label: Label = %HealthLabel
@onready var health_bar: HealthBar2D = %HealthBar
@onready var flashlight_rig: Node2D = %FlashlightRig
@onready var flashlight: PointLight2D = %Flashlight

var peer_id: int = 0
var character_id: StringName = &"heikki"
var is_local_player: bool = false
## QA and recovery escape hatch.  Shipping defaults to the baked directional
## actor; a malformed bake still has a known-good, local scene fallback.
@export var force_legacy_presentation: bool = false

var _target_position: Vector2 = Vector2.ZERO
var _target_movement: Vector2 = Vector2.ZERO
var _state_initialized: bool = false
var _action_tween: Tween
var _presentation_velocity: Vector2 = Vector2.ZERO
## Distance banked since the last footfall. Carried across frames rather than
## reset on stop, so stopping mid-stride and starting again does not cost the
## step that was almost complete.
var _stride_travelled: float = 0.0
var _movement_facing_direction: Vector2 = Vector2.ZERO
var _aim_direction: Vector2 = Vector2.RIGHT
var _assisted_aim_active: bool = false
var _locomotion_animation: StringName = &""
var _camera_focus_tween: Tween
## Only ever non-null on the local survivor. Remote avatars answer
## [method add_camera_impact] by doing nothing, which is correct: an impact next
## to another player's body is not an impact next to this screen.
var _camera_shake: CameraShake2D
var _combat_alive: bool = true
var _combat_health: int = 100
var _animated_presentation: AnimatedSprite2D
## Kept as followers rather than a shader/material mutation so the authored
## frames, texture import settings, and all eight directional clips remain the
## single source of truth.  Their draw order is established before the body is
## parented into MotionBob in [_ready].
var _readability_keyline: AnimatedSprite2D
var _identity_rim: AnimatedSprite2D
var _uses_baked_actor_presentation: bool = false
var _presentation_facing_row: int = ActorFacing.CAMERA_FACING_ROW
var _active_presentation_action: StringName = &""
var _presentation_action_sequence: int = 0


func configure(
	p_peer_id: int,
	p_character_id: StringName,
	p_spawn_position: Vector2,
	p_is_local_player: bool
) -> void:
	peer_id = p_peer_id
	character_id = p_character_id
	_target_position = p_spawn_position
	is_local_player = p_is_local_player
	global_position = p_spawn_position


func _ready() -> void:
	add_to_group(&"player_avatars")
	camera.enabled = is_local_player
	# Built here rather than placed in the scene so a remote survivor - whose
	# camera is disabled and whose offset nothing will ever read - does not
	# allocate a noise field and a process callback to shake a view nobody has.
	if is_local_player:
		_camera_shake = CameraShake2D.new()
		_camera_shake.name = &"CameraShake"
		camera.add_child(_camera_shake)
	var presentation: Node2D = _instantiate_presentation()
	_install_readability_treatment()
	motion_bob.add_child(presentation)
	if is_instance_valid(_animated_presentation):
		_animated_presentation.animation_finished.connect(_on_baked_presentation_animation_finished)
	# World-space text is drawn through the gameplay camera, so its authored size
	# is not its delivered size: the shipped zoom is 0.38, and the rule that
	# follows from it is font_size * 0.38 = screen pixels. The label used to be
	# font 8, which is 3.0 pixels - measured off the gameplay capture it resolved
	# no glyph at all, just a two-row gold dash at 2.9x the terrain luma sitting
	# over every survivor for the whole match. Font 21 is the HUD's own font 8
	# divided by that zoom, so a name on the world plane and a count on the
	# CanvasLayer now land at the same eight pixels.
	#
	# The suffix went with it rather than being resized. " // YOU" at this size
	# is 54 screen pixels of banner, an eighth of the viewport, to answer a
	# question the camera has already answered by following the body it is
	# attached to.
	name_label.text = String(character_id).capitalize()
	name_label.modulate = Color("ffd45a") if character_id == &"heikki" else Color("31e6e6")
	if is_instance_valid(health_bar):
		# Sized before the first _apply_combat_presentation below, so the bar's very
		# first frame is already at the survivor's proportions rather than at the
		# node's defaults for one frame.
		health_bar.setup(HEALTH_BAR_SIZE, HEALTH_BAR_SEGMENTS, true)
		health_bar.reset_to(float(_combat_health) / COMBAT_MAX_HEALTH)
	_install_locomotion_animations()
	_set_locomotion_animation(IDLE_ANIMATION)
	_apply_combat_presentation()
	_state_initialized = true
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _state_initialized:
		return
	var displacement: Vector2 = _target_position - global_position
	if displacement.length() >= SNAP_DISTANCE:
		global_position = _target_position
		velocity = Vector2.ZERO
		_presentation_velocity = Vector2.ZERO
	else:
		velocity = displacement * FOLLOW_RATE
		if velocity.length() <= STOP_EPSILON:
			velocity = Vector2.ZERO
		move_and_slide()
		_presentation_velocity = velocity
	# The locomotion clips lift MotionBob, and -y is up, so only the negative
	# part of that offset is a survivor leaving the ground.
	if is_instance_valid(ground_shadow):
		ground_shadow.set_lift(minf(motion_bob.position.y, 0.0))
	_accumulate_footfall(delta)
	_update_presentation_facing()
	_update_locomotion_animation()
	if is_instance_valid(flashlight_rig):
		flashlight_rig.rotation = _get_presentation_facing_direction().angle()


func apply_authoritative_state(authoritative_position: Vector2, movement: Vector2) -> void:
	if not authoritative_position.is_finite() or not movement.is_finite():
		return
	_target_position = authoritative_position
	_target_movement = movement.limit_length(1.0) if _combat_alive else Vector2.ZERO
	if not _target_movement.is_zero_approx():
		_movement_facing_direction = _target_movement.normalized()
	if not _state_initialized:
		global_position = authoritative_position


func get_presentation_velocity() -> Vector2:
	return _presentation_velocity


func get_facing_direction() -> Vector2:
	return _get_presentation_facing_direction()


func get_movement_facing_direction() -> Vector2:
	return _movement_facing_direction


func set_aim_direction(direction: Vector2, assisted: bool) -> void:
	if not direction.is_finite() or direction.is_zero_approx():
		return
	_aim_direction = direction.normalized()
	_assisted_aim_active = assisted and _combat_alive
	if _state_initialized:
		_update_presentation_facing()


func is_assisted_aim_active() -> bool:
	return _assisted_aim_active


func get_locomotion_animation() -> StringName:
	return _locomotion_animation


func uses_baked_actor_presentation() -> bool:
	return _uses_baked_actor_presentation and is_instance_valid(_animated_presentation)


func get_presentation_sprite() -> AnimatedSprite2D:
	return _animated_presentation


## The followers use the same SpriteFrames resource as the body and only ever
## exist for a valid baked actor.  Exposing this narrow presentation query lets
## the focused gate prove their resource and draw-order contract without
## reaching into movement, collision, or authority internals.
func has_gameplay_readability_treatment() -> bool:
	return (
		uses_baked_actor_presentation()
		and is_instance_valid(_readability_keyline)
		and is_instance_valid(_identity_rim)
	)


func get_readability_keyline() -> AnimatedSprite2D:
	return _readability_keyline


func get_identity_rim() -> AnimatedSprite2D:
	return _identity_rim


func get_presentation_animation() -> StringName:
	if not uses_baked_actor_presentation():
		return &""
	return _animated_presentation.animation


func get_presentation_facing_row() -> int:
	return _presentation_facing_row


func set_combat_state(health: int, alive: bool) -> void:
	var was_alive: bool = _combat_alive
	var previous_health: int = _combat_health
	_combat_health = maxi(health, 0)
	_combat_alive = alive and _combat_health > 0
	if not _combat_alive:
		_target_movement = Vector2.ZERO
		velocity = Vector2.ZERO
		_assisted_aim_active = false
		_presentation_action_sequence += 1
		if _active_presentation_action != BAKED_DEATH_CLIP:
			_play_directional_action(BAKED_DEATH_CLIP)
	elif not was_alive:
		_presentation_action_sequence += 1
		_active_presentation_action = &""
		_update_locomotion_animation()
		if is_instance_valid(health_bar):
			# Snapped, not set: coming back at full health after ten seconds down is
			# not a heal the player performed, and a chip draining from empty to full
			# would animate a recovery that never happened.
			health_bar.reset_to(float(_combat_health) / COMBAT_MAX_HEALTH)
	elif _combat_health < previous_health:
		_play_directional_action(BAKED_HIT_CLIP)
	_apply_combat_presentation()


func is_combat_alive() -> bool:
	return _combat_alive


func get_combat_health() -> int:
	return _combat_health


func set_flashlight_enabled(enabled: bool) -> void:
	if is_instance_valid(flashlight):
		flashlight.enabled = enabled and _combat_alive


func is_flashlight_enabled() -> bool:
	return is_instance_valid(flashlight) and flashlight.enabled


func play_interaction_feedback(interaction: StringName) -> void:
	if not _combat_alive:
		return
	if _action_tween != null and _action_tween.is_valid():
		_action_tween.kill()
	visual_anchor.scale = Vector2(_presentation_scale_sign(), 1.0)
	_action_tween = create_tween()
	_action_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if interaction == &"fire":
		_action_tween.tween_property(visual_anchor, "scale", Vector2(1.18 * _presentation_scale_sign(), 0.84), 0.09)
		_play_directional_action(BAKED_SHOOT_CLIP)
	else:
		_action_tween.tween_property(visual_anchor, "scale", Vector2(0.88 * _presentation_scale_sign(), 1.16), 0.09)
		_play_directional_action(BAKED_GATHER_CLIP)
	_action_tween.tween_property(visual_anchor, "scale", Vector2(_presentation_scale_sign(), 1.0), 0.16)


## [param trauma] is a fraction of the full shake and [param direction] the axis
## the impact arrived along. Callers do not have to know which avatar is local:
## the ones that are not simply have no shaker to forward to.
func add_camera_impact(trauma: float, direction: Vector2 = Vector2.ZERO) -> void:
	if is_instance_valid(_camera_shake):
		_camera_shake.add_impact(trauma, direction)


func get_camera_shake() -> CameraShake2D:
	return _camera_shake


func focus_camera_at(world_position: Vector2, hold_seconds: float = 1.0) -> void:
	if not is_local_player or not world_position.is_finite() or not is_instance_valid(camera):
		return
	if _camera_focus_tween != null and _camera_focus_tween.is_valid():
		_camera_focus_tween.kill()
	camera.position = Vector2.ZERO
	var local_focus: Vector2 = world_position - global_position
	_camera_focus_tween = create_tween()
	_camera_focus_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_camera_focus_tween.tween_property(camera, "position", local_focus, 0.22)
	_camera_focus_tween.tween_interval(maxf(hold_seconds, 0.0))
	_camera_focus_tween.tween_property(camera, "position", Vector2.ZERO, 0.32)


func _draw() -> void:
	if not _combat_alive:
		# A downed survivor is a mechanic-critical state, so retain a clear
		# crimson silhouette ring instead of fading a small baked death frame
		# into the terrain at the 0.38 gameplay camera.
		draw_arc(
			Vector2(0.0, 2.0),
			22.0,
			0.0,
			TAU,
			24,
			Color("ff6256"),
			2.0,
			true
		)
		draw_line(Vector2(-4.0, -2.0), Vector2(4.0, 6.0), Color("ffd6be"), 1.5, true)
		draw_line(Vector2(4.0, -2.0), Vector2(-4.0, 6.0), Color("ffd6be"), 1.5, true)
	elif is_local_player:
		draw_arc(
			Vector2(0.0, 12.0),
			16.0,
			0.0,
			TAU,
			24,
			Color(1.0, 0.85, 0.35, 0.82),
			1.5,
			true
		)


func _install_locomotion_animations() -> void:
	if animation_player.has_animation(IDLE_ANIMATION) and animation_player.has_animation(RUN_ANIMATION):
		return
	var library: AnimationLibrary = AnimationLibrary.new()
	library.add_animation(IDLE_ANIMATION, _create_bob_animation(1.2, 0.9))
	library.add_animation(RUN_ANIMATION, _create_bob_animation(0.32, 3.2))
	animation_player.add_animation_library(&"", library)


func _create_bob_animation(duration: float, lift: float) -> Animation:
	var animation: Animation = Animation.new()
	animation.length = duration
	animation.loop_mode = Animation.LOOP_LINEAR
	var track_index: int = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, ^"VisualAnchor/MotionBob:position")
	animation.track_insert_key(track_index, 0.0, Vector2.ZERO)
	animation.track_insert_key(track_index, duration * 0.5, Vector2(0.0, -lift))
	animation.track_insert_key(track_index, duration, Vector2.ZERO)
	return animation


func _update_locomotion_animation() -> void:
	var moving: bool = velocity.length() > STOP_EPSILON
	_set_locomotion_animation(RUN_ANIMATION if moving else IDLE_ANIMATION)


func _set_locomotion_animation(animation_name: StringName) -> void:
	if _locomotion_animation != animation_name:
		_locomotion_animation = animation_name
		if is_instance_valid(animation_player):
			animation_player.play(animation_name)
	if uses_baked_actor_presentation() and _active_presentation_action.is_empty():
		_play_directional_clip(_get_directional_locomotion_clip())


func _apply_combat_presentation() -> void:
	if is_instance_valid(collision_shape):
		collision_shape.set_deferred(&"disabled", not _combat_alive)
	if is_instance_valid(visual_anchor):
		visual_anchor.modulate = Color.WHITE if _combat_alive else Color(0.72, 0.38, 0.35, 0.86)
	if is_instance_valid(health_bar):
		# Ratio rather than the raw value, because the bar is a shape and the
		# maximum is the only thing that makes a length mean anything.
		health_bar.set_ratio(float(_combat_health) / float(COMBAT_MAX_HEALTH))
		health_bar.set_active(_combat_alive)
	if is_instance_valid(name_label):
		# The name follows the same rule the number already did. Legible or not,
		# an identity caption over a body is answering a question that hue and
		# silhouette answer first - CLAUDE.md 11 lists identity as redundant
		# across hue, silhouette, iconography and placement, and text is not on
		# that list, so retiring it from normal play costs no named channel.
		# Being downed is the one moment the name is load-bearing, because a
		# partner crossing the map needs to know which survivor is on the floor
		# and where, and that is a question a colour alone answers poorly.
		name_label.visible = not _combat_alive
	if is_instance_valid(health_label):
		# The number is now the downed banner only. A survivor at full health
		# carries no text at all, and a hurt one is read off the bar - a glance
		# during a firefight resolves a length, not three digits at seven pixels.
		#
		# The scene used to author a mint font_color under this red modulate,
		# and a Label multiplies the two: the alarm shipped as (125, 107, 69),
		# a muddy olive at luma 108 rather than the ff6b5f it names here. The
		# override is gone so white * ff6b5f is exactly ff6b5f.
		health_label.visible = not _combat_alive
		health_label.text = "DOWN"
		health_label.modulate = Color("ff6b5f")
	_set_readability_treatment_visible(_combat_alive)
	if not _combat_alive and is_instance_valid(flashlight):
		flashlight.enabled = false
	queue_redraw()


func _get_presentation_facing_direction() -> Vector2:
	if _assisted_aim_active and not _aim_direction.is_zero_approx():
		return _aim_direction
	if not _movement_facing_direction.is_zero_approx():
		return _movement_facing_direction
	return Vector2.ZERO


func _instantiate_presentation() -> Node2D:
	_animated_presentation = null
	_readability_keyline = null
	_identity_rim = null
	_uses_baked_actor_presentation = false
	if not force_legacy_presentation:
		var baked_scene: PackedScene = BAKED_SHANE_SCENE if character_id == &"shane" else BAKED_HEIKKI_SCENE
		var baked_presentation: Node2D = baked_scene.instantiate() as Node2D
		var baked_sprite: AnimatedSprite2D = baked_presentation as AnimatedSprite2D
		if _is_valid_baked_actor_sprite(baked_sprite):
			baked_sprite.scale = Vector2.ONE * BAKED_ACTOR_VISUAL_SCALE
			_animated_presentation = baked_sprite
			_uses_baked_actor_presentation = true
			return baked_presentation
		if baked_presentation != null:
			baked_presentation.free()
	var legacy_scene: PackedScene = SHANE_SCENE if character_id == &"shane" else HEIKKI_SCENE
	var legacy_presentation: Node2D = legacy_scene.instantiate() as Node2D
	if legacy_presentation != null:
		return legacy_presentation
	push_error("PlayerAvatar could not instantiate a presentation scene")
	return Node2D.new()


## Build the two visual followers before the body enters MotionBob.  Child tree
## order is the rendering contract here: the keyline draws first, then the
## identity rim, then the unmodified source sprite on top.  Duplicating the
## AnimatedSprite node rather than sampling pixels from a separate mask keeps
## every idle/run/shoot/gather/hit/death frame and each of the eight headings
## physically matched to the actual survivor silhouette.
func _install_readability_treatment() -> void:
	if not uses_baked_actor_presentation() or not is_instance_valid(motion_bob):
		return
	_readability_keyline = _make_presentation_follower(
		&"ReadabilityKeyline",
		READABILITY_KEYLINE_COLOR,
		_get_readability_keyline_scale()
	)
	_identity_rim = _make_presentation_follower(
		&"IdentityRim",
		_get_identity_rim_color(),
		_get_identity_rim_scale()
	)
	if is_instance_valid(_readability_keyline):
		motion_bob.add_child(_readability_keyline)
	if is_instance_valid(_identity_rim):
		motion_bob.add_child(_identity_rim)


func _make_presentation_follower(
	follower_name: StringName,
	follower_color: Color,
	scale_multiplier: Vector2
) -> AnimatedSprite2D:
	var follower: AnimatedSprite2D = AnimatedSprite2D.new()
	follower.name = follower_name
	follower.sprite_frames = _animated_presentation.sprite_frames
	follower.animation = _animated_presentation.animation
	follower.autoplay = &""
	follower.offset = _animated_presentation.offset
	follower.centered = _animated_presentation.centered
	follower.flip_h = _animated_presentation.flip_h
	follower.flip_v = _animated_presentation.flip_v
	follower.texture_filter = _animated_presentation.texture_filter
	follower.scale = _animated_presentation.scale * scale_multiplier
	follower.self_modulate = follower_color
	return follower


func _get_readability_keyline_scale() -> Vector2:
	return SHANE_KEYLINE_SCALE if character_id == &"shane" else HEIKKI_KEYLINE_SCALE


func _get_identity_rim_scale() -> Vector2:
	return SHANE_IDENTITY_RIM_SCALE if character_id == &"shane" else HEIKKI_IDENTITY_RIM_SCALE


func _get_identity_rim_color() -> Color:
	return SHANE_IDENTITY_RIM_COLOR if character_id == &"shane" else HEIKKI_IDENTITY_RIM_COLOR


func _set_readability_treatment_visible(visible: bool) -> void:
	if is_instance_valid(_readability_keyline):
		_readability_keyline.visible = visible
	if is_instance_valid(_identity_rim):
		_identity_rim.visible = visible


func _is_valid_baked_actor_sprite(candidate: AnimatedSprite2D) -> bool:
	if candidate == null or candidate.sprite_frames == null:
		return false
	return (
		ActorFacing.has_directional_clip(candidate.sprite_frames, BAKED_IDLE_CLIP)
		and ActorFacing.has_directional_clip(candidate.sprite_frames, BAKED_RUN_CLIP)
		and ActorFacing.has_directional_clip(candidate.sprite_frames, BAKED_SHOOT_CLIP)
		and ActorFacing.has_directional_clip(candidate.sprite_frames, BAKED_GATHER_CLIP)
		and ActorFacing.has_directional_clip(candidate.sprite_frames, BAKED_HIT_CLIP)
		and ActorFacing.has_directional_clip(candidate.sprite_frames, BAKED_DEATH_CLIP)
	)


func _update_presentation_facing() -> void:
	var presentation_facing: Vector2 = _get_presentation_facing_direction()
	if uses_baked_actor_presentation():
		_presentation_facing_row = ActorFacing.row_for_direction(
			presentation_facing,
			_presentation_facing_row
		)
		if _active_presentation_action.is_empty():
			_play_directional_clip(_get_directional_locomotion_clip())
		else:
			_play_directional_clip(_active_presentation_action)
		return
	if absf(presentation_facing.x) > 0.01:
		visual_anchor.scale.x = absf(visual_anchor.scale.x) * signf(presentation_facing.x)


func _get_directional_locomotion_clip() -> StringName:
	return BAKED_RUN_CLIP if _locomotion_animation == RUN_ANIMATION else BAKED_IDLE_CLIP


func _play_directional_clip(clip: StringName, restart: bool = false) -> bool:
	if not uses_baked_actor_presentation():
		return false
	var frames: SpriteFrames = _animated_presentation.sprite_frames
	var animation_name: StringName = ActorFacing.animation_name(clip, _presentation_facing_row)
	if frames == null or not frames.has_animation(animation_name):
		return false
	if restart or _animated_presentation.animation != animation_name or not _animated_presentation.is_playing():
		_animated_presentation.play(animation_name)
	_sync_readability_treatment(animation_name, restart)
	return true


## The followers never choose a frame or heading of their own.  They receive
## the already-selected directional clip at the same presentation boundary as
## the body, so this adds no action state, RPC, snapshot field, or local combat
## decision for remote peers to disagree about.
func _sync_readability_treatment(animation_name: StringName, restart: bool) -> void:
	if not uses_baked_actor_presentation():
		return
	for follower: AnimatedSprite2D in [_readability_keyline, _identity_rim]:
		if not is_instance_valid(follower):
			continue
		follower.offset = _animated_presentation.offset
		follower.flip_h = _animated_presentation.flip_h
		follower.flip_v = _animated_presentation.flip_v
		follower.speed_scale = _animated_presentation.speed_scale
		if restart or follower.animation != animation_name or not follower.is_playing():
			follower.play(animation_name)


func _play_directional_action(clip: StringName) -> void:
	if not uses_baked_actor_presentation():
		return
	_presentation_action_sequence += 1
	_active_presentation_action = clip
	if not _play_directional_clip(clip, true):
		_active_presentation_action = &""
		return
	if clip == BAKED_GATHER_CLIP and get_tree() != null:
		var action_sequence: int = _presentation_action_sequence
		get_tree().create_timer(GATHER_PRESENTATION_SECONDS).timeout.connect(
			_finish_timed_presentation_action.bind(action_sequence),
			CONNECT_ONE_SHOT
		)


func _finish_timed_presentation_action(action_sequence: int) -> void:
	if action_sequence != _presentation_action_sequence:
		return
	if _active_presentation_action != BAKED_GATHER_CLIP or not _combat_alive:
		return
	_active_presentation_action = &""
	_update_locomotion_animation()


func _on_baked_presentation_animation_finished() -> void:
	if not uses_baked_actor_presentation() or _active_presentation_action.is_empty():
		return
	if _active_presentation_action == BAKED_DEATH_CLIP:
		return
	var completed_animation: StringName = ActorFacing.animation_name(
		_active_presentation_action,
		_presentation_facing_row
	)
	if _animated_presentation.animation != completed_animation:
		return
	_active_presentation_action = &""
	_update_locomotion_animation()


func _presentation_scale_sign() -> float:
	return -1.0 if visual_anchor.scale.x < 0.0 else 1.0


## Cadence from distance rather than from the animation, because the locomotion
## clips are baked and their contact frames are not exposed anywhere the runtime
## can read. Distance also stays honest when the follow rate stretches a stride:
## a survivor covering more ground puts down more feet.
func _accumulate_footfall(delta: float) -> void:
	var speed: float = _presentation_velocity.length()
	if speed < FOOTFALL_MIN_SPEED:
		return
	_stride_travelled += speed * delta
	if _stride_travelled < FOOTFALL_STRIDE:
		return
	# Subtract rather than zero, so a frame that overshoots the stride does not
	# throw the remainder away and drift the cadence slow.
	_stride_travelled -= FOOTFALL_STRIDE
	footfall.emit(global_position)
