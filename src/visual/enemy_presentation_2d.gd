class_name EnemyPresentation2D
extends Node2D
## Allocation-free runtime animation and shape-coded readability for one enemy.

const MIN_MULTIPLIER_DELTA: float = 0.0001
const ROOT_THRESHOLD: float = 0.01
const SLOW_STATUS_COLOR: Color = Color("58d8ff")
const ROOT_STATUS_COLOR: Color = Color("eafcff")

## This is deliberately a presentation-only event vocabulary.  Gameplay owns
## attack, damage, spawn, and death timing; the view only chooses a baked clip
## after it receives that already-authoritative result.
enum PresentationEvent {
	NONE,
	SPAWN,
	ATTACK,
	HIT,
	TAUNT,
	DEATH,
}

## The silhouette marker is intentionally not a permanent HUD outline. Normal
## traffic stays quiet, while a boss at rest retains a faint identity cue and
## combat/status states receive the full readable treatment.
enum ReadabilityMarkerState {
	HIDDEN,
	BOSS_IDLE,
	ACTIVE_CUE,
}

## A compact event token is carried alongside the existing ordered horde
## snapshots.  Three bits name the event, three bits lock the heading that was
## true at the authoritative moment, and the upper bits reject stale packets.
const EVENT_BITS: int = 3
const FACING_ROW_BITS: int = 3
const EVENT_MASK: int = (1 << EVENT_BITS) - 1
const FACING_ROW_MASK: int = (1 << FACING_ROW_BITS) - 1
const FACING_ROW_SHIFT: int = EVENT_BITS
const REVISION_SHIFT: int = EVENT_BITS + FACING_ROW_BITS

signal presentation_action_finished(event_id: int)

## How long a struck body stays blown out, and how hard. Short enough that a
## burst of fire reads as several distinct hits rather than one long glare, and
## long enough to survive a dropped frame at 30 FPS.
const HIT_FLASH_SECONDS: float = 0.085
## A multiplier on the body tint rather than a colour to blend toward, because
## [member CanvasItem.modulate] multiplies: lerping it to white only cancels the
## tint, it cannot brighten past the texture. Driving the channels above 1.0 lets
## the LDR framebuffer clamp them, which blows the lit surfaces out to white
## while the near-black outline stays dark and holds the silhouette.
const HIT_FLASH_BOOST: float = 2.75
const IDLE_MARKER_ACCENT_ALPHA: float = 0.38
const IDLE_MARKER_SECONDARY_ALPHA: float = 0.24
const ACTIVE_CUE_MARKER_ACCENT_ALPHA: float = 0.84
const ACTIVE_CUE_MARKER_SECONDARY_ALPHA: float = 0.74
## A boss at rest keeps only 55% of the old idle marker alpha. It identifies
## the encounter without turning every frame of navigation into an alert.
const BOSS_IDLE_MARKER_ALPHA_MULTIPLIER: float = 0.55
## Boss identity has to survive without a permanent threat ring.  This is a
## strictly body-shaped underlay made from the same baked frame as the actor,
## not a new marker or an imported texture.  At the 0.38 gameplay camera it
## leaves a roughly one-logical-pixel semantic rim around horns, shoulders, and
## carapace edges while the original sprite remains the foreground read.
const BOSS_BODY_SILHOUETTE_SCALE: float = 1.12
const BOSS_BODY_SILHOUETTE_ALPHA: float = 0.72

var _definition: EnemyPresentationDefinition
var _shadow_root: Node2D
var _ground_shadows: Array[ActorGroundShadow2D] = []
var _content_root: Node2D
var _visual_roots: Array[Node2D] = []
var _animated_sprites: Array[AnimatedSprite2D] = []
## One stopped, frame-synchronised copy per boss body.  It intentionally stays
## out of _animated_sprites: only the authored foreground body owns playback,
## action timing, directional-frame discovery, and completion signals.
var _body_silhouette_sprites: Array[AnimatedSprite2D] = []
var _movement_status_multiplier: float = 1.0
var _moving: bool = false
var _phase: float = 0.0
var _has_visual: bool = false
var _facing_row: int = ActorFacing.CAMERA_FACING_ROW
var _directional: bool = false
var _active_event: int = PresentationEvent.NONE
var _active_action: StringName = &""
var _active_action_facing_row: int = ActorFacing.CAMERA_FACING_ROW
var _restart_action_requested: bool = false
var _last_token_revision: int = -1
var _readability_marker_visible: bool = true
## Seconds of blow-out left. Driven from the already-replicated HIT event, so
## every peer flashes the same body on the same frame without a second RPC.
var _hit_flash_remaining: float = 0.0
## Whether the tint currently on the copies is a boosted one. Lets the decay
## write the exact authored tint back once and then leave the copies alone,
## rather than re-assigning an unchanged Color every frame for every enemy.
var _hit_flash_applied: bool = false


func configure(definition: EnemyPresentationDefinition, stable_enemy_id: int) -> void:
	_definition = definition
	_phase = fmod(float(maxi(stable_enemy_id, 0)) * 0.731, TAU)
	# Added before the content, and never reparented into it. Draw order under a
	# Node2D is tree order, so this is what puts the shadow beneath the body; and
	# keeping it out of _content_root is what stops the bob tween from carrying
	# the shadow up with the actor, which is the difference between a figure
	# standing on the ground and a decal stuck to its feet.
	_shadow_root = Node2D.new()
	_shadow_root.name = &"GroundShadows"
	add_child(_shadow_root)
	_content_root = Node2D.new()
	_content_root.name = &"PresentationContent"
	add_child(_content_root)
	if _definition == null:
		push_error("EnemyPresentation2D requires a typed presentation definition")
		queue_redraw()
		return
	name = "Presentation_%s" % _definition.presentation_id
	_build_visual_copies()
	_update_animation_state()
	queue_redraw()


func update_motion(delta: float, moving: bool, movement_multiplier: float) -> void:
	if _definition == null or not is_instance_valid(_content_root):
		return
	var safe_delta: float = maxf(delta, 0.0)
	var safe_multiplier: float = _sanitize_multiplier(movement_multiplier)
	if absf(safe_multiplier - _movement_status_multiplier) > MIN_MULTIPLIER_DELTA:
		_movement_status_multiplier = safe_multiplier
		queue_redraw()
	if _moving != moving:
		_moving = moving
		_update_animation_state()
	var phase_scale: float = safe_multiplier if safe_multiplier > ROOT_THRESHOLD else 0.0
	_phase = fmod(
		_phase + safe_delta * _definition.bob_frequency * phase_scale,
		TAU
	)
	var bob_scale: float = 1.0 if _moving else 0.32
	var bob: float = sin(_phase) * _definition.bob_amplitude * bob_scale
	_content_root.position.y = bob
	# A bob that only moves the body reads as a sprite sliding on a rail. Feeding
	# the same height to the shadow makes the step land: the ellipse tightens and
	# darkens as the foot comes down and opens up as the body lifts.
	for shadow: ActorGroundShadow2D in _ground_shadows:
		shadow.set_lift(minf(bob, 0.0))
	# Attack/hit/spawn/death sheets are authored one-shot beats.  Slowing the
	# simulation must not freeze them halfway through their readable impact.
	var animation_speed: float = _definition.animation_speed_scale * (
		1.0 if not _active_action.is_empty() else safe_multiplier
	)
	for sprite: AnimatedSprite2D in _animated_sprites:
		if not is_equal_approx(sprite.speed_scale, animation_speed):
			sprite.speed_scale = animation_speed
	# Real time, not simulation time: a slowed or rooted enemy still has to
	# acknowledge the shot that hit it, and scaling the flash by the status
	# multiplier would stretch it to nothing at the moment it matters most.
	_advance_hit_flash(safe_delta)


## Two kinds of visual answer to this. A sheet baked at eight headings turns by
## selecting the row that was rendered for the direction; a legacy single-heading
## scene has only a left and a right, so it mirrors. Mirroring a directional sheet
## would undo the heading it was baked with, and selecting a row on a scene that
## has none would silently fall through to a default clip - so the two must not
## be mixed, and which one applies is read off the frames rather than configured.
func set_facing_direction(direction: Vector2) -> void:
	if _directional:
		var row: int = ActorFacing.row_for_direction(direction, _facing_row)
		if row != _facing_row:
			_facing_row = row
			if _active_action.is_empty():
				_update_animation_state()
		return
	if absf(direction.x) <= 0.01:
		return
	scale.x = absf(scale.x) * signf(direction.x)


func set_facing_row(row: int) -> void:
	if not _directional:
		return
	var safe_row: int = clampi(row, 0, ActorFacing.ROW_COUNT - 1)
	if safe_row == _facing_row:
		return
	_facing_row = safe_row
	if _active_action.is_empty():
		_update_animation_state()


static func pack_presentation_token(revision: int, facing_row: int, event_id: int) -> int:
	return (
		maxi(revision, 0) << REVISION_SHIFT
		| (clampi(facing_row, 0, ActorFacing.ROW_COUNT - 1) << FACING_ROW_SHIFT)
		| clampi(event_id, PresentationEvent.NONE, PresentationEvent.DEATH)
	)


static func get_token_revision(token: int) -> int:
	return token >> REVISION_SHIFT


static func get_token_facing_row(token: int) -> int:
	return (token >> FACING_ROW_SHIFT) & FACING_ROW_MASK


static func get_token_event(token: int) -> int:
	return token & EVENT_MASK


static func is_valid_presentation_token(token: int) -> bool:
	if token < 0:
		return false
	var event_id: int = get_token_event(token)
	var facing_row: int = get_token_facing_row(token)
	return (
		event_id >= PresentationEvent.NONE
		and event_id <= PresentationEvent.DEATH
		and facing_row >= 0
		and facing_row < ActorFacing.ROW_COUNT
	)


func apply_presentation_token(token: int) -> bool:
	if not is_valid_presentation_token(token):
		return false
	var revision: int = get_token_revision(token)
	if revision <= _last_token_revision:
		return false
	_last_token_revision = revision
	var facing_row: int = get_token_facing_row(token)
	set_facing_row(facing_row)
	return play_local_event(get_token_event(token), facing_row)


func play_local_event(event_id: int, facing_row: int = _facing_row) -> bool:
	if event_id < PresentationEvent.NONE or event_id > PresentationEvent.DEATH:
		return false
	set_facing_row(facing_row)
	# Ahead of the clip lookup on purpose. A hit landing while an attack or a
	# death is already mid-swing is refused a clip below, and that refusal must
	# not also swallow the flash - being shot during a wind-up is exactly when
	# the player most needs to see that the round connected.
	if event_id == PresentationEvent.HIT:
		_hit_flash_remaining = HIT_FLASH_SECONDS
	if event_id == PresentationEvent.NONE:
		_active_event = PresentationEvent.NONE
		_active_action = &""
		_restart_action_requested = false
		# Clearing an active cue changes the marker hierarchy even if the next
		# process tick has not advanced motion yet.
		queue_redraw()
		_update_animation_state()
		return true
	var action_clip: StringName = _get_event_clip(event_id)
	if action_clip.is_empty() or not _can_play_action(action_clip):
		return false
	_active_event = event_id
	_active_action = action_clip
	_active_action_facing_row = _facing_row
	_restart_action_requested = true
	_update_animation_state()
	queue_redraw()
	return true


func set_readability_marker_visible(visible: bool) -> void:
	if _readability_marker_visible == visible:
		return
	_readability_marker_visible = visible
	queue_redraw()


func get_definition() -> EnemyPresentationDefinition:
	return _definition


func get_visual_copy_count() -> int:
	return _visual_roots.size()


func get_animated_sprite_count() -> int:
	return _animated_sprites.size()


func get_body_silhouette_copy_count() -> int:
	return _body_silhouette_sprites.size()


func has_body_silhouette_layer() -> bool:
	return not _body_silhouette_sprites.is_empty()


func body_silhouette_uses_primary_frames() -> bool:
	if _body_silhouette_sprites.is_empty():
		return _definition != null and not _definition.boss_presentation
	if _body_silhouette_sprites.size() != _animated_sprites.size():
		return false
	for copy_index: int in range(_body_silhouette_sprites.size()):
		var silhouette: AnimatedSprite2D = _body_silhouette_sprites[copy_index]
		var foreground: AnimatedSprite2D = _animated_sprites[copy_index]
		if (
			not is_instance_valid(silhouette)
			or not is_instance_valid(foreground)
			or silhouette.sprite_frames != foreground.sprite_frames
		):
			return false
	return true


func is_body_silhouette_synchronized() -> bool:
	if _body_silhouette_sprites.is_empty():
		return _definition != null and not _definition.boss_presentation
	if _body_silhouette_sprites.size() != _animated_sprites.size():
		return false
	for copy_index: int in range(_body_silhouette_sprites.size()):
		var silhouette: AnimatedSprite2D = _body_silhouette_sprites[copy_index]
		var foreground: AnimatedSprite2D = _animated_sprites[copy_index]
		if (
			not is_instance_valid(silhouette)
			or not is_instance_valid(foreground)
			or silhouette.animation != foreground.animation
			or silhouette.frame != foreground.frame
		):
			return false
	return true


func get_facing_row() -> int:
	return _facing_row


func uses_directional_frames() -> bool:
	return _directional


func has_directional_clip(clip: StringName) -> bool:
	if _animated_sprites.is_empty():
		return false
	for sprite: AnimatedSprite2D in _animated_sprites:
		if not ActorFacing.has_directional_clip(sprite.sprite_frames, clip):
			return false
	return true


func get_active_animation() -> StringName:
	if _animated_sprites.is_empty():
		return &""
	return _animated_sprites[0].animation


func get_active_presentation_event() -> int:
	return _active_event


func get_active_action_facing_row() -> int:
	return _active_action_facing_row


func get_primary_animation_speed_scale() -> float:
	return _animated_sprites[0].speed_scale if not _animated_sprites.is_empty() else 0.0


func get_last_token_revision() -> int:
	return _last_token_revision


func get_movement_status_multiplier() -> float:
	return _movement_status_multiplier


func get_readability_marker_state() -> int:
	return _get_readability_marker_state()


func get_readability_marker_alpha_multiplier() -> float:
	return (
		BOSS_IDLE_MARKER_ALPHA_MULTIPLIER
		if _get_readability_marker_state() == ReadabilityMarkerState.BOSS_IDLE
		else 1.0
	)


func has_loaded_visual() -> bool:
	return _has_visual


## Linear, not eased. The flash is under a tenth of a second; a curve on top of
## it costs a call per copy per frame and is not something the eye resolves at
## that length.
func _advance_hit_flash(delta: float) -> void:
	if _hit_flash_remaining <= 0.0:
		if _hit_flash_applied:
			_apply_body_tint(1.0)
			_hit_flash_applied = false
		return
	_hit_flash_remaining = maxf(_hit_flash_remaining - delta, 0.0)
	_apply_body_tint(
		1.0 + (HIT_FLASH_BOOST - 1.0) * (_hit_flash_remaining / HIT_FLASH_SECONDS)
	)
	_hit_flash_applied = true


## [param boost] scales the colour channels and leaves alpha alone, so a variant
## authored translucent does not turn solid for the length of the flash.
func _apply_body_tint(boost: float) -> void:
	var tint: Color = _definition.body_tint
	var lit: Color = Color(tint.r * boost, tint.g * boost, tint.b * boost, tint.a)
	for visual: Node2D in _visual_roots:
		visual.modulate = lit


func _build_visual_copies() -> void:
	if _definition.visual_scene == null:
		push_error(
			"Enemy presentation '%s' has no visual scene; using marker fallback"
			% _definition.presentation_id
		)
		return
	for copy_index: int in range(_definition.copy_offsets.size()):
		if _definition.boss_presentation:
			_build_boss_body_silhouette_copy(copy_index)
		var instance: Node = _definition.visual_scene.instantiate()
		var visual: Node2D = instance as Node2D
		if visual == null:
			push_error(
				"Enemy presentation '%s' instantiated a non-Node2D root"
				% _definition.presentation_id
			)
			instance.free()
			continue
		visual.name = &"VariantVisual" if copy_index == 0 else "VariantVisual_%d" % copy_index
		visual.position = _definition.visual_offset + _definition.copy_offsets[copy_index]
		# One shadow per copy, not one for the group. A crawler pack is several
		# bodies fanning out around an anchor, and a single ellipse under the
		# middle of them would ground none of the three.
		var shadow: ActorGroundShadow2D = ActorGroundShadow2D.new()
		shadow.name = &"GroundShadow" if copy_index == 0 else "GroundShadow_%d" % copy_index
		# Down by contact_offset, because the baked sprite is pinned to the
		# projected world origin and the feet project below it. The copies scale
		# at exactly ACTOR_SCALE, so this local unit is the sheet pixel the
		# offset was measured in.
		shadow.position = _definition.copy_offsets[copy_index] + Vector2(
			0.0, _definition.contact_offset
		)
		# Authored per variant rather than scaled off marker_radius. The ring is a
		# readability affordance drawn in the marker language each variant owns,
		# and deriving a footprint from it made the goliath's contact narrower
		# than its own stance while the crawler wore one 2.7x its lower body -
		# three times over, one per copy. contact_radius is measured off the
		# silhouette instead, in the same sheet pixel the offset above uses.
		shadow.base_radius = _definition.contact_radius
		_shadow_root.add_child(shadow)
		_ground_shadows.append(shadow)
		visual.scale = _definition.visual_scale
		visual.modulate = _definition.body_tint
		_content_root.add_child(visual)
		_visual_roots.append(visual)
		_collect_animated_sprites(visual)
	for sprite: AnimatedSprite2D in _animated_sprites:
		sprite.animation_finished.connect(_on_animated_sprite_animation_finished.bind(sprite))
		if not _body_silhouette_sprites.is_empty():
			sprite.frame_changed.connect(_sync_body_silhouettes)
	_has_visual = not _visual_roots.is_empty()
	_directional = _detect_directional_frames()
	_sync_body_silhouettes()
	if not _has_visual:
		push_error(
			"Enemy presentation '%s' could not build any visual copy"
			% _definition.presentation_id
		)


func _build_boss_body_silhouette_copy(copy_index: int) -> void:
	## The duplicate is deliberately placed before the original in the same
	## content root.  Tree draw order keeps the actual baked body on top while
	## its own alpha defines the rim; no circle, arc, label, light, or secondary
	## gameplay node is introduced.
	var instance: Node = _definition.visual_scene.instantiate()
	var silhouette: AnimatedSprite2D = instance as AnimatedSprite2D
	if silhouette == null:
		push_error(
			"Enemy boss presentation '%s' requires an AnimatedSprite2D root for its body silhouette"
			% _definition.presentation_id
		)
		instance.free()
		return
	silhouette.name = &"BodySilhouette" if copy_index == 0 else "BodySilhouette_%d" % copy_index
	silhouette.position = _definition.visual_offset + _definition.copy_offsets[copy_index]
	silhouette.scale = _definition.visual_scale * BOSS_BODY_SILHOUETTE_SCALE
	var silhouette_tint: Color = _definition.accent_color.lightened(0.10)
	silhouette_tint.a = BOSS_BODY_SILHOUETTE_ALPHA
	silhouette.modulate = silhouette_tint
	_content_root.add_child(silhouette)
	## Autoplay belongs only to the foreground body.  The duplicate copies the
	## finished frame from the foreground, avoiding a fractional-frame drift that
	## would turn a true silhouette rim into flickering doubled animation.
	silhouette.stop()
	_body_silhouette_sprites.append(silhouette)


func _sync_body_silhouettes() -> void:
	if _body_silhouette_sprites.is_empty():
		return
	var paired_count: int = mini(_body_silhouette_sprites.size(), _animated_sprites.size())
	for copy_index: int in range(paired_count):
		var silhouette: AnimatedSprite2D = _body_silhouette_sprites[copy_index]
		var foreground: AnimatedSprite2D = _animated_sprites[copy_index]
		if not is_instance_valid(silhouette) or not is_instance_valid(foreground):
			continue
		if silhouette.sprite_frames != foreground.sprite_frames:
			silhouette.sprite_frames = foreground.sprite_frames
		if silhouette.animation != foreground.animation:
			silhouette.animation = foreground.animation
		silhouette.set_frame_and_progress(foreground.frame, foreground.frame_progress)
		if silhouette.is_playing():
			silhouette.stop()


func _collect_animated_sprites(visual: Node2D) -> void:
	# A baked actor scene is an AnimatedSprite2D at its own root, because the
	# sheet is the whole visual and a wrapper node would only add a transform to
	# keep in step with it. The older hand-built scenes wrap theirs in a Node2D,
	# so both shapes have to be recognised - and the root has to be checked
	# first, since find_children never returns the node it was called on.
	var root_sprite: AnimatedSprite2D = visual as AnimatedSprite2D
	if root_sprite != null:
		_animated_sprites.append(root_sprite)
		return
	var primary_sprite: AnimatedSprite2D = visual.get_node_or_null(^"WeatheredSprite") as AnimatedSprite2D
	if primary_sprite != null:
		_animated_sprites.append(primary_sprite)
		return
	for child: Node in visual.find_children("*", "AnimatedSprite2D", true, false):
		var sprite: AnimatedSprite2D = child as AnimatedSprite2D
		if sprite != null:
			_animated_sprites.append(sprite)


## Directional only if every collected sprite carries the eight-row form of both
## clips. A partial answer is worse than a negative one: an actor whose idle turns
## but whose walk does not would snap back to one heading the moment it moved.
func _detect_directional_frames() -> bool:
	if _definition == null or _animated_sprites.is_empty():
		return false
	for sprite: AnimatedSprite2D in _animated_sprites:
		var frames: SpriteFrames = sprite.sprite_frames
		if not ActorFacing.has_directional_clip(frames, _definition.idle_animation):
			return false
		if not ActorFacing.has_directional_clip(frames, _definition.move_animation):
			return false
	return true


func _update_animation_state() -> void:
	if _definition == null:
		return
	var desired_clip: StringName = (
		_active_action if not _active_action.is_empty() else (
			_definition.move_animation if _moving else _definition.idle_animation
		)
	)
	var animation_facing_row: int = (
		_active_action_facing_row if not _active_action.is_empty() else _facing_row
	)
	var desired_animation: StringName = (
		ActorFacing.animation_name(desired_clip, animation_facing_row) if _directional else desired_clip
	)
	for sprite: AnimatedSprite2D in _animated_sprites:
		var frames: SpriteFrames = sprite.sprite_frames
		if frames == null:
			continue
		var selected_animation: StringName = desired_animation
		if not frames.has_animation(selected_animation):
			selected_animation = (
				ActorFacing.animation_name(_definition.idle_animation, _facing_row)
				if _directional
				else _definition.idle_animation
			)
		if not frames.has_animation(selected_animation):
			selected_animation = frames.get_animation_names()[0] if not frames.get_animation_names().is_empty() else &""
		if selected_animation.is_empty():
			continue
		if _active_action.is_empty() and (
			sprite.animation != selected_animation or not sprite.is_playing()
		):
			sprite.play(selected_animation)
		elif not _active_action.is_empty() and (
			_restart_action_requested or sprite.animation != selected_animation
		):
			sprite.play(selected_animation)
	_restart_action_requested = false
	_sync_body_silhouettes()


func _get_event_clip(event_id: int) -> StringName:
	match event_id:
		PresentationEvent.SPAWN:
			return &"spawn"
		PresentationEvent.ATTACK:
			return &"attack"
		PresentationEvent.HIT:
			return &"hit"
		PresentationEvent.TAUNT:
			return &"taunt"
		PresentationEvent.DEATH:
			return &"death"
	return &""


func _can_play_action(action_clip: StringName) -> bool:
	if action_clip.is_empty() or _animated_sprites.is_empty():
		return false
	for sprite: AnimatedSprite2D in _animated_sprites:
		var frames: SpriteFrames = sprite.sprite_frames
		var animation_name: StringName = (
			ActorFacing.animation_name(action_clip, _facing_row)
			if _directional
			else action_clip
		)
		if frames == null or not frames.has_animation(animation_name):
			return false
	return true


func _on_animated_sprite_animation_finished(sprite: AnimatedSprite2D) -> void:
	if _active_action.is_empty() or _active_event == PresentationEvent.DEATH:
		return
	var completed_animation: StringName = (
		ActorFacing.animation_name(_active_action, _active_action_facing_row)
		if _directional
		else _active_action
	)
	if sprite.animation != completed_animation:
		return
	var finished_event: int = _active_event
	_active_event = PresentationEvent.NONE
	_active_action = &""
	_restart_action_requested = false
	_update_animation_state()
	queue_redraw()
	presentation_action_finished.emit(finished_event)


func _sanitize_multiplier(value: float) -> float:
	if not is_finite(value):
		return 1.0
	return clampf(value, 0.0, 1.0)


func _get_readability_marker_state() -> int:
	# The explicit opt-out is used by the ephemeral death-view wrapper. It hides
	# only the base marker; _draw_movement_status remains outside this hierarchy.
	if _definition == null or not _readability_marker_visible:
		return ReadabilityMarkerState.HIDDEN
	if _active_event != PresentationEvent.NONE:
		return ReadabilityMarkerState.ACTIVE_CUE
	if _movement_status_multiplier < 0.999:
		return ReadabilityMarkerState.ACTIVE_CUE
	if _definition.boss_presentation and not _moving:
		return ReadabilityMarkerState.BOSS_IDLE
	return ReadabilityMarkerState.HIDDEN


func _draw() -> void:
	if _definition == null:
		_draw_missing_visual_marker()
		return
	var radius: float = _definition.marker_radius
	var accent: Color = _definition.accent_color
	var secondary: Color = _definition.secondary_color
	var marker_state: int = _get_readability_marker_state()
	if marker_state == ReadabilityMarkerState.ACTIVE_CUE:
		accent.a = ACTIVE_CUE_MARKER_ACCENT_ALPHA
		secondary.a = ACTIVE_CUE_MARKER_SECONDARY_ALPHA
	elif marker_state == ReadabilityMarkerState.BOSS_IDLE:
		accent.a = IDLE_MARKER_ACCENT_ALPHA * BOSS_IDLE_MARKER_ALPHA_MULTIPLIER
		secondary.a = IDLE_MARKER_SECONDARY_ALPHA * BOSS_IDLE_MARKER_ALPHA_MULTIPLIER
	if marker_state != ReadabilityMarkerState.HIDDEN:
		draw_arc(Vector2(0.0, 3.0), radius, 0.08, PI - 0.08, 20, secondary, 1.5, true)
		match _definition.marker_kind:
			EnemyPresentationDefinition.MarkerKind.WALKER_BARS:
				_draw_walker_bars(accent, secondary)
			EnemyPresentationDefinition.MarkerKind.CRAWLER_PACK:
				_draw_crawler_pack(accent, secondary)
			EnemyPresentationDefinition.MarkerKind.STATIC_PRONGS:
				_draw_static_prongs(accent, secondary, radius)
			EnemyPresentationDefinition.MarkerKind.SHIELD_ARC:
				_draw_shield_arc(accent, secondary, radius)
			EnemyPresentationDefinition.MarkerKind.GOLIATH_RUNES:
				_draw_goliath_runes(accent, secondary, radius)
			EnemyPresentationDefinition.MarkerKind.CARRIER_ORBITS:
				_draw_carrier_orbits(accent, secondary, radius)
			EnemyPresentationDefinition.MarkerKind.SPLITTER_TWINS:
				_draw_splitter_twins(accent, secondary, radius)
			EnemyPresentationDefinition.MarkerKind.OVERLORD_CROWN:
				_draw_overlord_crown(accent, secondary, radius)
	if not _has_visual:
		_draw_missing_visual_marker()
	_draw_movement_status(radius)


func _draw_walker_bars(accent: Color, secondary: Color) -> void:
	draw_rect(Rect2(Vector2(-20.0, -31.0), Vector2(5.0, 18.0)), secondary, true)
	draw_rect(Rect2(Vector2(15.0, -31.0), Vector2(5.0, 18.0)), secondary, true)
	draw_line(Vector2(-18.0, -31.0), Vector2(-18.0, -13.0), accent, 1.5, true)
	draw_line(Vector2(18.0, -31.0), Vector2(18.0, -13.0), accent, 1.5, true)


func _draw_crawler_pack(accent: Color, secondary: Color) -> void:
	draw_circle(Vector2(-13.0, 0.0), 5.5, secondary)
	draw_circle(Vector2(13.0, 1.0), 5.5, secondary)
	draw_circle(Vector2(0.0, -7.0), 5.5, secondary)
	draw_line(Vector2(-17.0, 6.0), Vector2(-9.0, 6.0), accent, 2.0, true)
	draw_line(Vector2(9.0, 7.0), Vector2(17.0, 7.0), accent, 2.0, true)


func _draw_static_prongs(accent: Color, secondary: Color, radius: float) -> void:
	draw_arc(Vector2.ZERO, radius - 3.0, 0.0, TAU, 24, secondary, 1.5, true)
	draw_line(Vector2(-12.0, -16.0), Vector2(-20.0, -29.0), accent, 2.0, true)
	draw_line(Vector2(-20.0, -29.0), Vector2(-12.0, -26.0), accent, 2.0, true)
	draw_line(Vector2(12.0, -16.0), Vector2(20.0, -29.0), accent, 2.0, true)
	draw_line(Vector2(20.0, -29.0), Vector2(12.0, -26.0), accent, 2.0, true)


func _draw_shield_arc(accent: Color, secondary: Color, radius: float) -> void:
	draw_set_transform(
		Vector2.ZERO,
		ActorFacing.ROW_HEADINGS[clampi(_facing_row, 0, ActorFacing.ROW_COUNT - 1)].angle(),
		Vector2.ONE
	)
	draw_arc(Vector2.ZERO, radius - 1.0, -1.05, 1.05, 18, secondary, 7.0, true)
	draw_arc(Vector2.ZERO, radius + 2.0, -1.05, 1.05, 18, accent, 2.0, true)
	draw_line(Vector2(radius - 1.0, -15.0), Vector2(radius + 5.0, 0.0), accent, 2.0, true)
	draw_line(Vector2(radius + 5.0, 0.0), Vector2(radius - 1.0, 15.0), accent, 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_goliath_runes(accent: Color, secondary: Color, radius: float) -> void:
	draw_arc(Vector2.ZERO, radius, PI + 0.2, TAU - 0.2, 20, secondary, 4.0, true)
	draw_line(Vector2(-radius + 7.0, -8.0), Vector2(-radius - 2.0, -28.0), accent, 3.0, true)
	draw_line(Vector2(radius - 7.0, -8.0), Vector2(radius + 2.0, -28.0), accent, 3.0, true)
	draw_line(Vector2(-13.0, 8.0), Vector2.ZERO, accent, 2.0, true)
	draw_line(Vector2.ZERO, Vector2(13.0, 8.0), accent, 2.0, true)


func _draw_carrier_orbits(accent: Color, secondary: Color, radius: float) -> void:
	draw_arc(Vector2.ZERO, radius, -0.75, 0.75, 18, accent, 2.0, true)
	draw_arc(Vector2.ZERO, radius, PI - 0.75, PI + 0.75, 18, accent, 2.0, true)
	draw_arc(Vector2.ZERO, radius - 8.0, 0.0, TAU, 24, secondary, 1.5, true)
	draw_circle(Vector2(-radius, 0.0), 3.5, accent)
	draw_circle(Vector2(radius, 0.0), 3.5, accent)


func _draw_splitter_twins(accent: Color, secondary: Color, radius: float) -> void:
	draw_arc(Vector2(-9.0, 0.0), radius - 8.0, 0.0, TAU, 20, secondary, 2.0, true)
	draw_arc(Vector2(9.0, 0.0), radius - 8.0, 0.0, TAU, 20, secondary, 2.0, true)
	draw_line(Vector2(-radius, -9.0), Vector2(-radius + 8.0, 0.0), accent, 2.0, true)
	draw_line(Vector2(-radius + 8.0, 0.0), Vector2(-radius, 9.0), accent, 2.0, true)
	draw_line(Vector2(radius, -9.0), Vector2(radius - 8.0, 0.0), accent, 2.0, true)
	draw_line(Vector2(radius - 8.0, 0.0), Vector2(radius, 9.0), accent, 2.0, true)


func _draw_overlord_crown(accent: Color, secondary: Color, radius: float) -> void:
	var crown_y: float = -radius - 18.0
	draw_line(Vector2(-17.0, crown_y + 12.0), Vector2(-17.0, crown_y), accent, 2.5, true)
	draw_line(Vector2(-17.0, crown_y), Vector2(-6.0, crown_y + 8.0), accent, 2.5, true)
	draw_line(Vector2(-6.0, crown_y + 8.0), Vector2.ZERO + Vector2(0.0, crown_y - 4.0), accent, 2.5, true)
	draw_line(Vector2(0.0, crown_y - 4.0), Vector2(6.0, crown_y + 8.0), accent, 2.5, true)
	draw_line(Vector2(6.0, crown_y + 8.0), Vector2(17.0, crown_y), accent, 2.5, true)
	draw_line(Vector2(17.0, crown_y), Vector2(17.0, crown_y + 12.0), accent, 2.5, true)
	draw_line(Vector2(-17.0, crown_y + 12.0), Vector2(17.0, crown_y + 12.0), secondary, 4.0, true)


func _draw_movement_status(radius: float) -> void:
	if _movement_status_multiplier >= 0.999:
		return
	var status_radius: float = radius + 5.0
	var status_color: Color = (
		ROOT_STATUS_COLOR
		if _movement_status_multiplier <= ROOT_THRESHOLD
		else SLOW_STATUS_COLOR
	)
	status_color.a = 0.88
	draw_arc(Vector2.ZERO, status_radius, 0.0, TAU, 28, status_color, 2.0, true)
	if _movement_status_multiplier <= ROOT_THRESHOLD:
		draw_line(Vector2(-8.0, 7.0), Vector2(8.0, -7.0), status_color, 2.0, true)
		draw_line(Vector2(-8.0, -7.0), Vector2(8.0, 7.0), status_color, 2.0, true)
	else:
		draw_arc(
			Vector2.ZERO,
			status_radius - 4.0,
			-PI * 0.5,
			-PI * 0.5 + TAU * _movement_status_multiplier,
			18,
			status_color,
			1.5,
			true
		)


func _draw_missing_visual_marker() -> void:
	var fallback: Color = Color("ff3fa4")
	draw_line(Vector2(0.0, -18.0), Vector2(14.0, 0.0), fallback, 3.0, true)
	draw_line(Vector2(14.0, 0.0), Vector2(0.0, 18.0), fallback, 3.0, true)
	draw_line(Vector2(0.0, 18.0), Vector2(-14.0, 0.0), fallback, 3.0, true)
	draw_line(Vector2(-14.0, 0.0), Vector2(0.0, -18.0), fallback, 3.0, true)
