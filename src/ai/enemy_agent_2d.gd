class_name EnemyAgent2D
extends CharacterBody2D
## Host-simulated zombie/boss agent driven by the active Base flow field.

signal died(enemy_id: int, is_boss: bool, world_position: Vector2)
signal micro_emp_released(world_position: Vector2, radius: float, duration_seconds: float)
signal split_requested(world_position: Vector2)

const PresentationCatalog = preload("res://src/ai/enemy_presentation_catalog.gd")
const PresentationView = preload("res://src/visual/enemy_presentation_2d.gd")

enum Variant {
	WALKER,
	RAT_SWARM,
	STATIC_WALKER,
	SCRAP_SHIELD,
	GOLIATH,
	CARRIER,
	SPLITTER,
	OVERLORD,
}

const ENEMY_LAYER: int = 4
const WORLD_AND_PLAYER_MASK: int = 3
const PLAYER_ATTACK_RANGE: float = 42.0
const BASE_ATTACK_RANGE: float = 178.0
const ATTACK_COOLDOWN_SECONDS: float = 0.8
const STATIC_EMP_RADIUS: float = 260.0
const STATIC_EMP_DURATION_SECONDS: float = 2.4
const MIN_SLOW_MULTIPLIER_DELTA: float = 0.0001
const BOSS_TAUNT_DELAY_SECONDS: float = 0.52

## A landed hit shoves the body. This changes no health total and no damage
## number - it is the difference between a bullet landing and a bullet being
## deducted. Weight is the part of a hit the player feels rather than reads.
##
## Speed of the shove at the reference blow, before the variant's own mass
## takes its cut. Sized against walker movement speed so a hit reads as a
## stagger and not as the enemy being fired backwards out of the fight.
const KNOCKBACK_IMPULSE_SPEED: float = 190.0
## The blow the impulse is authored against, so a tower slug and a pistol round
## are not the same event. Capped because damage keeps climbing across a run
## and a late weapon must not start launching bodies off the map.
const KNOCKBACK_REFERENCE_DAMAGE: float = 12.0
const KNOCKBACK_DAMAGE_CAP: float = 2.0
## Exponential, and deliberately fast. The shove has to be spent before the
## agent's own movement matters again, or sustained fire becomes a way to walk
## a body backwards indefinitely and the horde stops being able to arrive.
const KNOCKBACK_DAMPING: float = 11.0
## Residue below this is not worth a move_and_slide call, and cutting it here
## is what lets a spent shove settle at exactly zero instead of creeping.
const KNOCKBACK_REST_SPEED: float = 4.0
## Hard ceiling on accumulated shove. Three towers connecting inside one frame
## is an ordinary event and must not add up into a launch.
const KNOCKBACK_MAX_SPEED: float = 420.0

## How far each variant gives when it is hit, indexed by [enum Variant].
##
## Authored per variant rather than derived from health, because the two say
## different things: health is how long a body lasts, this is how heavy it is
## in the hand. A crawler pack scatters off a single round, a shield braces, a
## goliath rocks and keeps coming. That is the eight identities of CLAUDE.md 7
## taught through the trigger in the first magazine rather than through a
## health bar draining at eight different rates.
##
## No entry is zero. A body that cannot be moved at all reads as level geometry
## rather than as something heavy - the small give is what sells the mass.
const KNOCKBACK_MASS: Array[float] = [
	1.00, # WALKER
	1.45, # RAT_SWARM - three light bodies, and the pack scatters
	0.90, # STATIC_WALKER
	0.55, # SCRAP_SHIELD - braced behind the plate
	0.16, # GOLIATH
	0.35, # CARRIER
	0.50, # SPLITTER
	0.10, # OVERLORD
]

## Bar geometry, expressed in multiples of the variant's authored
## [member EnemyPresentationDefinition.marker_radius]. That number already
## drives the ground shadow, so a variant resized later moves its shadow and
## its bar together instead of drifting apart.
const HEALTH_BAR_LIFT_SCALE: float = 1.5
const HEALTH_BAR_WIDTH_SCALE: float = 1.9
const HEALTH_BAR_HEIGHT: float = 6.0
const BOSS_HEALTH_BAR_HEIGHT: float = 9.0
## Ticks on a boss only. Forty walkers each carrying a subdivided bar is a wall
## of noise; on the one body worth pacing a fight against, quarters are the
## whole point of looking at the bar.
const BOSS_HEALTH_BAR_SEGMENTS: int = 4
## Above the bodies. This does break Y-sorting for the bars specifically, which
## is the accepted trade everywhere: a bar occluded by the body in front of it
## is not a readout, and the bars are small enough that floating them all costs
## less clarity than hiding half of them would.
const HEALTH_BAR_Z: int = 1

var enemy_id: int = 0
var variant: int = Variant.WALKER
var max_health: int = 1
var current_health: int = 1
var attack_damage: int = 1
var movement_speed: float = 1.0

var _flow_field: FlowFieldNavigation2D
var _combat_state: CombatStateCoordinator
var _base_target: Vector2 = Vector2.ZERO
var _player_target: PlayerAvatar
var _authority_enabled: bool = false
var _active: bool = true
var _attack_remaining: float = 0.0
# Screen-down is the heading the actor sheets render facing the camera, so an
# enemy that has not chosen a target yet shows the player a face rather than a
# flank. This used to be LEFT, which only ever meant "do not mirror the sprite".
var _facing_direction: Vector2 = Vector2.DOWN
var _snapshot_position: Vector2 = Vector2.ZERO
var _movement_speed_multiplier: float = 1.0
var _movement_slow_remaining: float = 0.0
var _presentation_definition: EnemyPresentationDefinition
var _visual_anchor: PresentationView
var _replicated_facing_row: int = ActorFacing.CAMERA_FACING_ROW
var _presentation_revision: int = 0
var _presentation_token: int = 0
var _boss_taunt_remaining: float = -1.0
## Host-side only. The displacement it produces reaches clients inside the
## position already carried by the snapshot, so a shove needs no protocol.
var _knockback_velocity: Vector2 = Vector2.ZERO
var _health_bar: HealthBar2D


func configure(
	new_enemy_id: int,
	new_variant: int,
	spawn_position: Vector2,
	health_value: int,
	damage_value: int,
	speed_value: float,
	base_position: Vector2,
	flow_field: FlowFieldNavigation2D,
	combat_state: CombatStateCoordinator,
	authority_enabled: bool
) -> void:
	enemy_id = new_enemy_id
	variant = clampi(new_variant, Variant.WALKER, Variant.OVERLORD)
	max_health = maxi(health_value, 1)
	current_health = max_health
	attack_damage = maxi(damage_value, 1)
	movement_speed = maxf(speed_value, 1.0)
	global_position = spawn_position
	_snapshot_position = spawn_position
	_base_target = base_position
	_flow_field = flow_field
	_combat_state = combat_state
	_authority_enabled = authority_enabled
	_active = true
	_attack_remaining = 0.0
	_facing_direction = Vector2.DOWN
	_movement_speed_multiplier = 1.0
	_movement_slow_remaining = 0.0
	_replicated_facing_row = ActorFacing.CAMERA_FACING_ROW
	_presentation_revision = 1
	_presentation_token = PresentationView.pack_presentation_token(
		_presentation_revision,
		_replicated_facing_row,
		PresentationView.PresentationEvent.SPAWN
	)
	_knockback_velocity = Vector2.ZERO
	_boss_taunt_remaining = BOSS_TAUNT_DELAY_SECONDS if is_boss() else -1.0
	name = "Enemy_%04d_%s" % [enemy_id, PresentationCatalog.get_variant_name(variant)]


func _ready() -> void:
	add_to_group(&"zombies")
	z_index = 5
	z_as_relative = false
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	# Join spawns its own tracer. The body has to stay on the enemy layer so
	# that ray can stop, on every peer. Damage and sliding stay authority-only:
	# take_projectile_damage rejects a client, and a zero mask does not
	# move_and_slide into the world. Death clears the layer below.
	collision_layer = ENEMY_LAYER
	collision_mask = WORLD_AND_PLAYER_MASK if _authority_enabled else 0
	_build_collision()
	_build_visual()
	_build_health_bar()
	if is_instance_valid(_visual_anchor):
		_visual_anchor.apply_presentation_token(_presentation_token)
	queue_redraw()


func _physics_process(delta: float) -> void:
	var safe_delta: float = maxf(delta, 0.0)
	if not _active:
		velocity = Vector2.ZERO
		return
	if not _authority_enabled:
		var snapshot_displacement: Vector2 = _snapshot_position - global_position
		if snapshot_displacement.length_squared() > 0.01:
			_facing_direction = snapshot_displacement.normalized()
		global_position = global_position.lerp(
			_snapshot_position,
			1.0 - exp(-12.0 * safe_delta)
		)
		_update_visual_presentation(
			safe_delta,
			snapshot_displacement.length_squared() > 0.25
		)
		return
	_advance_movement_slow(safe_delta)
	_advance_boss_taunt(safe_delta)
	_attack_remaining = maxf(_attack_remaining - safe_delta, 0.0)
	var target_position: Vector2 = _base_target
	var targeting_player: bool = is_instance_valid(_player_target) and _player_target.is_combat_alive()
	if targeting_player:
		target_position = _player_target.global_position
	var to_target: Vector2 = target_position - global_position
	var attack_range: float = PLAYER_ATTACK_RANGE if targeting_player else BASE_ATTACK_RANGE
	var drive: Vector2 = Vector2.ZERO
	if to_target.length_squared() <= attack_range * attack_range:
		_try_attack(targeting_player)
	else:
		var direction: Vector2 = to_target.normalized()
		if not targeting_player and is_instance_valid(_flow_field):
			direction = _flow_field.get_direction(global_position)
		if not direction.is_zero_approx():
			_facing_direction = direction.normalized()
		drive = direction * movement_speed * _movement_speed_multiplier
	# The shove is added to what the agent wanted to do rather than replacing
	# it, and it is integrated in both branches. The attack branch used to zero
	# the velocity and skip move_and_slide entirely, which made a body that had
	# closed to melee the one body a hit could not move - and that is the moment
	# the shove matters most. Sliding rather than teleporting keeps the world's
	# static collision honest, so nothing is ever knocked through a wall.
	# The shove is impeded by the same multiplier the agent's own walk is. That
	# is not a special case for traps, it is what the multiplier means: a body
	# in a Slowing Pit is in mud and slides less, and a body in a Razor Snare is
	# pinned and does not slide at all. Without this the snare would fling its
	# own victim out of its trigger radius and stop being a reusable trap, and a
	# root that launches you is not a root. The impulse is still banked at full
	# strength and still decays on schedule, so being held through a stagger
	# means having been held, not having the stagger owed back afterwards.
	velocity = drive + _knockback_velocity * _movement_speed_multiplier
	if not velocity.is_zero_approx():
		move_and_slide()
	_advance_knockback(safe_delta)
	# Gated on the walk the agent chose, not on total motion. A body sliding
	# backwards out of a hit is not walking, and playing its stride through the
	# stagger would read as the enemy moonwalking away from the shot.
	_update_visual_presentation(safe_delta, drive.length_squared() > 0.25)


func set_base_target(world_position: Vector2) -> void:
	if world_position.is_finite():
		_base_target = world_position


func set_player_target(player: PlayerAvatar) -> void:
	_player_target = player


func clear_player_target() -> void:
	_player_target = null


func get_target_peer_id() -> int:
	if is_instance_valid(_player_target) and _player_target.is_combat_alive():
		return _player_target.peer_id
	return EnemyAggroMatrix.BASE_TARGET_PEER_ID


func get_base_target() -> Vector2:
	return _base_target


func get_variant_name() -> StringName:
	return PresentationCatalog.get_variant_name(variant)


func is_boss() -> bool:
	return variant >= Variant.GOLIATH


func is_alive() -> bool:
	return _active and current_health > 0


func get_facing_direction() -> Vector2:
	return _facing_direction


func apply_movement_slow(multiplier: float, duration_seconds: float) -> bool:
	if (
		not _authority_enabled
		or not is_inside_tree()
		or not multiplayer.is_server()
		or not is_finite(multiplier)
		or not is_finite(duration_seconds)
		or multiplier < 0.0
		or multiplier >= 1.0
		or duration_seconds <= 0.0
	):
		return false
	if (
		_movement_slow_remaining > 0.0
		and multiplier > _movement_speed_multiplier + MIN_SLOW_MULTIPLIER_DELTA
	):
		return false
	if multiplier < _movement_speed_multiplier - MIN_SLOW_MULTIPLIER_DELTA:
		_movement_speed_multiplier = multiplier
		_movement_slow_remaining = duration_seconds
	else:
		_movement_speed_multiplier = multiplier
		_movement_slow_remaining = maxf(_movement_slow_remaining, duration_seconds)
	if is_instance_valid(_visual_anchor):
		_visual_anchor.update_motion(0.0, not velocity.is_zero_approx(), _movement_speed_multiplier)
	return true


func get_movement_speed_multiplier() -> float:
	return _movement_speed_multiplier


func get_effective_movement_speed() -> float:
	return movement_speed * _movement_speed_multiplier


func get_presentation_definition() -> EnemyPresentationDefinition:
	return _presentation_definition


func get_presentation_view() -> PresentationView:
	return _visual_anchor


func get_presentation_facing_row() -> int:
	if _authority_enabled:
		return ActorFacing.row_for_direction(_facing_direction, _replicated_facing_row)
	return _replicated_facing_row


func get_presentation_token() -> int:
	return _presentation_token


func get_presentation_revision() -> int:
	return _presentation_revision


func take_projectile_damage(
	amount: int,
	projectile_direction: Vector2,
	_source_peer_id: int
) -> int:
	if not _authority_enabled or not _active or amount <= 0:
		return 0
	var applied_amount: int = amount
	if variant == Variant.SCRAP_SHIELD and is_frontal_shield_hit(projectile_direction):
		applied_amount = maxi(roundi(float(amount) * 0.2), 1)
	# Before the damage, so the shove is sized by the blow that actually landed:
	# a shield taking a frontal round is both hurt less and moved less, which is
	# one fact told twice rather than two rules that have to be kept in step.
	apply_knockback(projectile_direction, applied_amount)
	return take_damage(applied_amount)


## Shove this body along [param direction], sized by [param damage_amount] and
## by the variant's own mass. Host only, and returns whether anything was
## banked - a rejected direction has to be visible rather than silent, because
## the vector arrives from the network fire path and a NaN reaching a
## CharacterBody2D velocity corrupts the position for the rest of the session.
func apply_knockback(direction: Vector2, damage_amount: int) -> bool:
	if (
		not _authority_enabled
		or not _active
		or damage_amount <= 0
		or not direction.is_finite()
		or direction.is_zero_approx()
	):
		return false
	var weight: float = minf(
		float(damage_amount) / KNOCKBACK_REFERENCE_DAMAGE,
		KNOCKBACK_DAMAGE_CAP
	)
	_knockback_velocity = (
		_knockback_velocity
		+ direction.normalized() * KNOCKBACK_IMPULSE_SPEED * weight * get_knockback_mass()
	).limit_length(KNOCKBACK_MAX_SPEED)
	return true


func get_knockback_mass() -> float:
	var index: int = clampi(variant, 0, KNOCKBACK_MASS.size() - 1)
	return KNOCKBACK_MASS[index]


func get_knockback_velocity() -> Vector2:
	return _knockback_velocity


## Exponential rather than linear, so the stagger is sharpest at the instant of
## the hit and gone by the time the player has read it, and cut to exactly zero
## at the floor so a spent shove stops rather than creeping for the session.
func _advance_knockback(delta: float) -> void:
	if _knockback_velocity == Vector2.ZERO:
		return
	_knockback_velocity *= exp(-KNOCKBACK_DAMPING * maxf(delta, 0.0))
	if _knockback_velocity.length() < KNOCKBACK_REST_SPEED:
		_knockback_velocity = Vector2.ZERO


func take_damage(amount: int) -> int:
	if not _authority_enabled or not _active or amount <= 0:
		return 0
	var applied: int = mini(amount, current_health)
	current_health -= applied
	_refresh_health_bar()
	queue_redraw()
	if current_health <= 0:
		_die()
	else:
		_publish_presentation_event(PresentationView.PresentationEvent.HIT)
	return applied


func is_frontal_shield_hit(projectile_direction: Vector2) -> bool:
	if projectile_direction.is_zero_approx() or _facing_direction.is_zero_approx():
		return false
	var u: Vector2 = _facing_direction.normalized()
	var v: Vector2 = projectile_direction.normalized()
	return u.dot(v) <= -0.5


func apply_network_snapshot(
	world_position: Vector2,
	health_value: int,
	movement_multiplier: float = 1.0,
	facing_row: int = ActorFacing.CAMERA_FACING_ROW,
	presentation_token: int = 0
) -> void:
	if _authority_enabled or not world_position.is_finite():
		return
	_snapshot_position = world_position
	current_health = clampi(health_value, 0, max_health)
	_movement_speed_multiplier = (
		clampf(movement_multiplier, 0.0, 1.0)
		if is_finite(movement_multiplier)
		else 1.0
	)
	_replicated_facing_row = clampi(facing_row, 0, ActorFacing.ROW_COUNT - 1)
	_facing_direction = ActorFacing.ROW_HEADINGS[_replicated_facing_row]
	if is_instance_valid(_visual_anchor):
		_visual_anchor.set_facing_row(_replicated_facing_row)
		_visual_anchor.apply_presentation_token(presentation_token)
		_visual_anchor.update_motion(
			0.0,
			_snapshot_position.distance_squared_to(global_position) > 0.25,
			_movement_speed_multiplier
		)
	_refresh_health_bar()
	queue_redraw()


func _try_attack(targeting_player: bool) -> void:
	if _attack_remaining > 0.0 or not is_instance_valid(_combat_state):
		return
	_attack_remaining = ATTACK_COOLDOWN_SECONDS
	var applied_damage: int = 0
	if targeting_player and is_instance_valid(_player_target):
		applied_damage = _combat_state.damage_player_authoritative(
			_player_target.peer_id,
			attack_damage
		)
	else:
		applied_damage = _combat_state.damage_base_authoritative(attack_damage)
	if applied_damage > 0:
		_publish_presentation_event(PresentationView.PresentationEvent.ATTACK)


func _die() -> void:
	if not _active:
		return
	_active = false
	velocity = Vector2.ZERO
	_knockback_velocity = Vector2.ZERO
	# A corpse showing an empty frame for the length of the despawn reads as a
	# body still standing there at zero health.
	_refresh_health_bar()
	_movement_speed_multiplier = 1.0
	_movement_slow_remaining = 0.0
	_boss_taunt_remaining = -1.0
	collision_layer = 0
	collision_mask = 0
	if variant == Variant.STATIC_WALKER:
		micro_emp_released.emit(global_position, STATIC_EMP_RADIUS, STATIC_EMP_DURATION_SECONDS)
	elif variant == Variant.SPLITTER:
		split_requested.emit(global_position)
	died.emit(enemy_id, is_boss(), global_position)


func _build_collision() -> void:
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 34.0 if is_boss() else 15.0
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = &"CollisionShape2D"
	collision.shape = shape
	add_child(collision)


## Parented to the body rather than to the presentation view on purpose. The
## view mirrors itself by flipping its own scale.x and bobs its content root,
## so a bar hung there would flip its ticks with the walk cycle and bounce.
func _build_health_bar() -> void:
	var radius: float = (
		_presentation_definition.marker_radius
		if _presentation_definition != null
		else 21.0
	)
	_health_bar = HealthBar2D.new()
	_health_bar.name = &"HealthBar"
	_health_bar.position = Vector2(0.0, -radius * HEALTH_BAR_LIFT_SCALE)
	_health_bar.z_index = HEALTH_BAR_Z
	_health_bar.setup(
		Vector2(
			radius * HEALTH_BAR_WIDTH_SCALE,
			BOSS_HEALTH_BAR_HEIGHT if is_boss() else HEALTH_BAR_HEIGHT
		),
		BOSS_HEALTH_BAR_SEGMENTS if is_boss() else 1,
		# Hidden at full health. A wave is forty bodies and a bar over every
		# untouched one is clutter that hides the two the player has hurt.
		true
	)
	add_child(_health_bar)
	# Snapped rather than set, so a body that spawns already damaged - a
	# splitter's halves - opens at its real value with no chip draining in
	# from a full bar it never had.
	_health_bar.reset_to(
		float(current_health) / float(max_health) if max_health > 0 else 0.0
	)
	_health_bar.set_active(_active and current_health > 0)


## The bar is fed from whichever path owns health on this peer: the host writes
## through take_damage, a client through the replicated snapshot. Both land
## here so the chip animation is identical on every screen in the session.
func _refresh_health_bar() -> void:
	if not is_instance_valid(_health_bar):
		return
	_health_bar.set_active(_active and current_health > 0)
	if max_health > 0:
		_health_bar.set_ratio(float(current_health) / float(max_health))


func get_health_bar() -> HealthBar2D:
	return _health_bar


func _build_visual() -> void:
	_presentation_definition = PresentationCatalog.get_definition(variant)
	if _presentation_definition == null:
		push_error(
			"Enemy variant %d is missing a presentation definition; using Walker fallback"
			% variant
		)
		_presentation_definition = PresentationCatalog.get_definition(Variant.WALKER)
	_visual_anchor = PresentationView.new()
	_visual_anchor.configure(_presentation_definition, enemy_id)
	add_child(_visual_anchor)


## The guard is on the vector having a heading at all, not on it having a
## horizontal one. A mirrored visual only ever cared about the sign of x, but an
## eight-row sheet has a row for straight up and a row for straight down, and
## dropping those two headings here would leave an enemy walking at the player
## rendered as whichever way it last happened to move sideways.
func _update_visual_facing() -> void:
	if not is_instance_valid(_visual_anchor):
		return
	# The host ships an exact baked-row index.  A client may interpolate through
	# a short position delta between packets, but that inferred direction must
	# never overwrite the authoritative row captured with an action token.
	if not _authority_enabled:
		_visual_anchor.set_facing_row(_replicated_facing_row)
		return
	if _facing_direction.length_squared() <= 0.0001:
		return
	_visual_anchor.set_facing_direction(_facing_direction)


func _update_visual_presentation(delta: float, moving: bool) -> void:
	if not is_instance_valid(_visual_anchor):
		return
	_update_visual_facing()
	_visual_anchor.update_motion(delta, moving, _movement_speed_multiplier)


func _advance_movement_slow(delta: float) -> void:
	if _movement_slow_remaining <= 0.0:
		return
	_movement_slow_remaining = maxf(_movement_slow_remaining - delta, 0.0)
	if _movement_slow_remaining <= 0.0:
		_movement_speed_multiplier = 1.0


func _advance_boss_taunt(delta: float) -> void:
	if not _authority_enabled or _boss_taunt_remaining < 0.0:
		return
	_boss_taunt_remaining = maxf(_boss_taunt_remaining - maxf(delta, 0.0), 0.0)
	if _boss_taunt_remaining > 0.0:
		return
	_boss_taunt_remaining = -1.0
	_publish_presentation_event(PresentationView.PresentationEvent.TAUNT)


func _publish_presentation_event(event_id: int) -> void:
	if (
		not _authority_enabled
		or event_id <= PresentationView.PresentationEvent.NONE
		or event_id >= PresentationView.PresentationEvent.DEATH
	):
		return
	_presentation_revision += 1
	var facing_row: int = get_presentation_facing_row()
	_presentation_token = PresentationView.pack_presentation_token(
		_presentation_revision,
		facing_row,
		event_id
	)
	if is_instance_valid(_visual_anchor):
		_visual_anchor.apply_presentation_token(_presentation_token)


func _draw() -> void:
	if not is_boss() and current_health >= max_health:
		return
	var bar_width: float = 72.0 if is_boss() else 34.0
	var bar_y: float = -62.0 if is_boss() else -36.0
	var health_ratio: float = float(current_health) / float(max_health)
	draw_rect(Rect2(Vector2(-bar_width * 0.5, bar_y), Vector2(bar_width, 4.0)), Color(0.0, 0.0, 0.0, 0.82), true)
	var health_color: Color = (
		_presentation_definition.accent_color
		if _presentation_definition != null
		else Color("ff3fa4")
	)
	draw_rect(
		Rect2(
			Vector2(-bar_width * 0.5, bar_y),
			Vector2(bar_width * health_ratio, 4.0)
		),
		health_color,
		true
	)
