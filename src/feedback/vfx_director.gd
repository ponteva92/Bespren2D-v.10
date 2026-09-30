class_name VfxDirector
extends Node2D

## Pooled one-shot world particle bursts.
##
## The project had no particle system at all, so every violent or productive
## moment - a shot leaving a barrel, a round striking concrete, a node giving up
## its last unit, a zombie coming apart - happened with nothing but a transform
## tween to sell it. [JuiceRig] covers the other half of that problem, but it is
## a plain [Node] that scales and flashes existing [CanvasItem]s; it has no world
## position and nothing to emit. This owns the world-space half.
##
## Emitters are [CPUParticles2D] rather than [GPUParticles2D] on purpose. The
## project ships Vulkan with an OpenGL fallback for unsupported devices, and the
## CPU path behaves identically on both, where the GPU path's behaviour on the
## compatibility renderer is not something a desktop gate can prove. At these
## counts - at most [constant MAX_PARTICLES] live per burst across
## [constant POOL_SIZE] emitters - the simulation cost is not what a mid-range
## Android device will struggle with.

## Effects that read as dust sit under the actors; effects that read as light or
## debris sit over them. One director, two absolute depths, so a build cloud does
## not paint over the survivor who raised the structure.
const GROUND_Z: int = 4
const AIR_Z: int = 6

## Bounded by design. A burst asked for while every emitter is busy recycles the
## oldest instead of allocating, so a horde death cascade cannot grow the pool.
const POOL_SIZE: int = 20
const MAX_PARTICLES: int = 24

## World units, not screen pixels. The gameplay camera is at 0.38 zoom, so a
## burst has to be roughly two and a half times its intended on-screen size.
const SCREEN_TO_WORLD: float = 1.0 / 0.38

enum Effect {
	MUZZLE_FLASH,
	IMPACT_SPARK,
	GATHER_BURST,
	BUILD_POOF,
	DEATH_BURST,
	FOOTSTEP_DUST,
	PICKUP_SPARKLE,
}

## Effects that report nothing the player has to act on. Two survivors running
## ask for a puff several times a second each, which is enough to hold the whole
## pool and push a muzzle flash or an impact out of it. Ambient bursts are
## therefore allowed to fail: when every emitter is busy they are dropped rather
## than granted by evicting something that was telling the player about damage.
const AMBIENT_EFFECTS: Array[Effect] = [Effect.FOOTSTEP_DUST]

var _pool: Array[CPUParticles2D] = []
var _claimed_at: PackedFloat32Array = PackedFloat32Array()
var _soft_dot: Texture2D
var _hard_chip: Texture2D


func _ready() -> void:
	# Both textures are generated rather than imported. A soft radial falloff and
	# a hard-edged one are the entire vocabulary these bursts need, and generating
	# them keeps the export closure and the asset manifest from growing two files
	# no artist would ever open.
	# A very small solid centre keeps a burst readable as debris/energy at the
	# 0.38 gameplay camera instead of as a wide, anonymous translucent bubble.
	# It remains a soft falloff, just with enough semantic edge to survive busy
	# ground texture and a nearby sprite silhouette.
	_soft_dot = _radial_texture(0.16)
	_hard_chip = _radial_texture(0.72)
	for index: int in POOL_SIZE:
		var emitter: CPUParticles2D = CPUParticles2D.new()
		emitter.name = "Burst_%d" % index
		emitter.emitting = false
		emitter.one_shot = true
		# Particles live in world space and are left behind by a moving emitter,
		# which is what a burst is; following the emitter would read as a trail.
		emitter.local_coords = false
		emitter.z_as_relative = false
		add_child(emitter)
		_pool.append(emitter)
		_claimed_at.append(-1.0)


## Fire one burst. [param direction] is ignored by the radial effects, and
## [param tint] carries the semantic colour where an effect has one - the locked
## Wood, Metal and Tech anchors for salvage, the enemy's own family for a death.
func play(
	effect: Effect,
	at: Vector2,
	direction: Vector2 = Vector2.ZERO,
	tint: Color = Color.WHITE,
) -> void:
	var emitter: CPUParticles2D = _claim(not AMBIENT_EFFECTS.has(effect))
	if emitter == null:
		return
	emitter.global_position = at
	var aim: Vector2 = direction if direction.is_finite() else Vector2.ZERO
	emitter.direction = aim.normalized() if aim.length() > 0.001 else Vector2.UP
	_apply_preset(emitter, effect, tint)
	emitter.restart()


func stop_all() -> void:
	for emitter: CPUParticles2D in _pool:
		emitter.emitting = false
	for index: int in _claimed_at.size():
		_claimed_at[index] = -1.0


## [param may_steal] decides what happens once every emitter is busy: a burst
## that carries information takes the oldest, and an ambient one gives up.
func _claim(may_steal: bool = true) -> CPUParticles2D:
	var now: float = float(Time.get_ticks_msec()) * 0.001
	var oldest_index: int = -1
	var oldest_time: float = INF
	for index: int in _pool.size():
		var candidate: CPUParticles2D = _pool[index]
		if not candidate.emitting:
			_claimed_at[index] = now
			return candidate
		if _claimed_at[index] < oldest_time:
			oldest_time = _claimed_at[index]
			oldest_index = index
	if oldest_index < 0 or not may_steal:
		return null
	# Every emitter is still running. Stealing the one that started earliest is
	# the least visible interruption available, and it is what keeps a wave of
	# simultaneous deaths from allocating.
	_claimed_at[oldest_index] = now
	return _pool[oldest_index]


func _apply_preset(emitter: CPUParticles2D, effect: Effect, tint: Color) -> void:
	emitter.texture = _soft_dot
	emitter.gravity = Vector2.ZERO
	emitter.spread = 30.0
	emitter.explosiveness = 1.0
	emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	emitter.z_index = AIR_Z
	_damping(emitter, 0.0)
	match effect:
		Effect.MUZZLE_FLASH:
			# A muzzle is a compact source cue, not a spray travelling farther than
			# the weapon. Hard chips keep a sharp hot core over the ground texture.
			emitter.texture = _hard_chip
			emitter.amount = 4
			emitter.lifetime = 0.13
			emitter.spread = 9.0
			emitter.initial_velocity_min = 42.0 * SCREEN_TO_WORLD
			emitter.initial_velocity_max = 96.0 * SCREEN_TO_WORLD
			emitter.scale_amount_min = 1.35
			emitter.scale_amount_max = 2.50
			_damping(emitter, 280.0)
			_ramp(emitter, Color(1.0, 0.98, 0.86), Color(1.0, 0.66, 0.14), 0.0)
		Effect.IMPACT_SPARK:
			emitter.texture = _hard_chip
			emitter.amount = 9
			emitter.lifetime = 0.30
			# Keep a readable outward surface cue at the 0.38 gameplay camera.
			# A wide neutral fan resolved as falling/loot-like dots instead of an impact.
			emitter.spread = 42.0
			emitter.initial_velocity_min = 90.0 * SCREEN_TO_WORLD
			emitter.initial_velocity_max = 230.0 * SCREEN_TO_WORLD
			emitter.gravity = Vector2(0.0, 420.0)
			emitter.scale_amount_min = 0.65
			emitter.scale_amount_max = 1.45
			_damping(emitter, 90.0)
			_ramp(emitter, Color(1.0, 0.96, 0.78), Color(0.78, 0.29, 0.09), 0.0)
		Effect.GATHER_BURST:
			emitter.amount = 10
			emitter.lifetime = 0.52
			emitter.spread = 46.0
			emitter.initial_velocity_min = 55.0 * SCREEN_TO_WORLD
			emitter.initial_velocity_max = 120.0 * SCREEN_TO_WORLD
			# Salvage rises. Negative y is up, so the yield drifts toward the
			# survivor who earned it rather than falling back to the ground.
			emitter.gravity = Vector2(0.0, -95.0)
			emitter.scale_amount_min = 1.20
			emitter.scale_amount_max = 2.30
			_ramp(emitter, tint, tint.darkened(0.42), 0.12)
		Effect.BUILD_POOF:
			emitter.z_index = GROUND_Z
			emitter.amount = 13
			emitter.lifetime = 0.54
			emitter.spread = 180.0
			emitter.initial_velocity_min = 70.0 * SCREEN_TO_WORLD
			emitter.initial_velocity_max = 165.0 * SCREEN_TO_WORLD
			emitter.gravity = Vector2(0.0, 26.0)
			emitter.scale_amount_min = 1.90
			emitter.scale_amount_max = 3.60
			_damping(emitter, 210.0)
			_ramp(emitter, Color(0.72, 0.71, 0.66), Color(0.38, 0.40, 0.38), 0.16)
		Effect.DEATH_BURST:
			# Death feedback is material debris, not a reward pulse. The old soft
			# bright cloud became the highest-value object in a 0.38 combat frame;
			# hard, dark fragments keep the enemy body and its death sheet primary.
			emitter.texture = _hard_chip
			emitter.amount = 12
			emitter.lifetime = 0.42
			emitter.spread = 180.0
			emitter.initial_velocity_min = 60.0 * SCREEN_TO_WORLD
			emitter.initial_velocity_max = 165.0 * SCREEN_TO_WORLD
			emitter.gravity = Vector2(0.0, 420.0)
			emitter.scale_amount_min = 0.60
			emitter.scale_amount_max = 1.25
			_damping(emitter, 175.0)
			var debris_head: Color = _material_debris_tint(tint)
			_ramp(emitter, debris_head, debris_head.darkened(0.58), 0.04)
		Effect.FOOTSTEP_DUST:
			emitter.z_index = GROUND_Z
			emitter.amount = 4
			emitter.lifetime = 0.34
			emitter.spread = 120.0
			emitter.initial_velocity_min = 18.0 * SCREEN_TO_WORLD
			emitter.initial_velocity_max = 46.0 * SCREEN_TO_WORLD
			emitter.scale_amount_min = 1.05
			emitter.scale_amount_max = 1.90
			_damping(emitter, 150.0)
			_ramp(emitter, Color(0.66, 0.65, 0.60), Color(0.34, 0.36, 0.34), 0.22)
		Effect.PICKUP_SPARKLE:
			emitter.amount = 7
			emitter.lifetime = 0.46
			emitter.spread = 34.0
			emitter.direction = Vector2.UP
			emitter.initial_velocity_min = 70.0 * SCREEN_TO_WORLD
			emitter.initial_velocity_max = 145.0 * SCREEN_TO_WORLD
			emitter.gravity = Vector2(0.0, -60.0)
			emitter.scale_amount_min = 0.95
			emitter.scale_amount_max = 1.75
			_ramp(emitter, Color.WHITE, tint, 0.0)


## [CPUParticles2D] has no scalar damping, only the pair, and leaving the two
## apart would randomise drag per particle on top of the velocity spread that is
## already doing that job.
func _damping(emitter: CPUParticles2D, amount: float) -> void:
	emitter.damping_min = amount
	emitter.damping_max = amount


## Every burst fades to zero alpha at its own pace instead of vanishing, and
## [param hold] keeps the head colour for the first part of the life so dust
## reads as a puff rather than a flash.
func _ramp(emitter: CPUParticles2D, head: Color, tail: Color, hold: float) -> void:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, clampf(hold, 0.0, 0.5) + 0.001, 1.0])
	gradient.colors = PackedColorArray([
		Color(head.r, head.g, head.b, 1.0),
		Color(head.r, head.g, head.b, 0.92),
		Color(tail.r, tail.g, tail.b, 0.0),
	])
	# Unlike the GPU path's ParticleProcessMaterial, this takes the Gradient
	# itself rather than a GradientTexture1D wrapping it.
	emitter.color_ramp = gradient


## Enemy accents make excellent identification marks on a body, but a saturated
## green or cyan cloud reads like health/pickup feedback once the body is gone.
## Collapse the hue toward a warm, low-value material colour while retaining a
## trace of the authored family, so a death reads as physical fragments rather
## than a reward, poison field, or ability effect.
func _material_debris_tint(tint: Color) -> Color:
	var luminance: float = tint.r * 0.2126 + tint.g * 0.7152 + tint.b * 0.0722
	var earth: Color = Color(luminance * 0.72, luminance * 0.45, luminance * 0.28, tint.a)
	return tint.lerp(earth, 0.78).darkened(0.20)


## A radial white falloff. [param core] is the fraction of the radius held at
## full opacity before the falloff starts, so 0.0 is a soft dot and 0.72 is a
## hard chip suitable for spark debris.
func _radial_texture(core: float) -> Texture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, clampf(core, 0.0, 0.95), 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 16
	texture.height = 16
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture
