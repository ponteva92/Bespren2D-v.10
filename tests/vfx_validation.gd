extends SceneTree

## Focused gate for the world VFX director.
##
## The bursts themselves are a judgement call that only pixels can settle, but
## three things about them are contracts a headless run can hold: the pool is
## bounded and recycles rather than allocating, every effect actually starts an
## emitter, and no caller can push a non-finite direction into the particle
## system. The last one matters because the fire path feeds this an aim vector
## that came off the network.

var _failures: PackedStringArray = PackedStringArray()
var _checks: int = 0

## Particle textures are 16×16 source pixels and the shipping combat camera is
## 0.38.  These scale ceilings keep feedback subordinate to a player, enemy, or
## placement silhouette instead of allowing an anonymous soft blob to cover it.
const GAMEPLAY_CAMERA_ZOOM: float = 0.38
const PARTICLE_TEXTURE_SIZE: float = 16.0
const MAX_SCALE_BY_EFFECT: Dictionary = {
	VfxDirector.Effect.MUZZLE_FLASH: 2.50,
	VfxDirector.Effect.IMPACT_SPARK: 1.45,
	VfxDirector.Effect.GATHER_BURST: 2.30,
	VfxDirector.Effect.BUILD_POOF: 3.60,
	VfxDirector.Effect.DEATH_BURST: 1.25,
	VfxDirector.Effect.FOOTSTEP_DUST: 1.90,
	VfxDirector.Effect.PICKUP_SPARKLE: 1.75,
}
const MAX_LOGICAL_DIAMETER: float = 22.0


func _initialize() -> void:
	# The root window is not tree-attached during _initialize, so a node added
	# before this yields never receives _ready and never builds its pool.
	await process_frame
	var script: GDScript = load("res://src/feedback/vfx_director.gd")
	if script == null:
		_fail("vfx_director.gd failed to load")
		_report()
		return
	var director: Node2D = script.new()
	root.add_child(director)
	await process_frame

	var pool_size: int = int(script.POOL_SIZE)
	var max_particles: int = int(script.MAX_PARTICLES)
	_check(director.get_child_count() == pool_size,
		"pool builds %d emitters (found %d)" % [
			pool_size, director.get_child_count()])
	_check(pool_size <= 32, "pool stays bounded at %d emitters" % pool_size)

	var ground: int = 0
	var air: int = 0
	for child: Node in director.get_children():
		var emitter: CPUParticles2D = child as CPUParticles2D
		_check(emitter != null, "pool member %s is a CPUParticles2D" % child.name)
		if emitter == null:
			continue
		_check(emitter.one_shot, "%s is one-shot" % emitter.name)
		_check(not emitter.local_coords,
			"%s emits into world space" % emitter.name)
		_check(not emitter.emitting, "%s starts idle" % emitter.name)
		_check(not emitter.z_as_relative,
			"%s owns an absolute depth" % emitter.name)

	# Every effect must claim a distinct emitter and start it.
	var effects: Array = script.Effect.values()
	_check(effects.size() >= 7,
		"director exposes %d effects" % effects.size())
	for effect: int in effects:
		director.play(effect, Vector2(320.0, 180.0), Vector2(1.0, 0.0),
			Color(1.0, 0.843, 0.0))
	var live: int = 0
	for child: Node in director.get_children():
		var emitter: CPUParticles2D = child as CPUParticles2D
		if emitter == null:
			continue
		if emitter.emitting:
			live += 1
			_check(emitter.amount <= max_particles,
				"%s stays within the %d particle cap (%d)" % [
					emitter.name, max_particles, emitter.amount])
			_check(emitter.color_ramp is Gradient,
				"%s carries a Gradient ramp" % emitter.name)
			_check(emitter.texture != null,
				"%s has a generated texture" % emitter.name)
			if emitter.z_index == int(script.GROUND_Z):
				ground += 1
			elif emitter.z_index == int(script.AIR_Z):
				air += 1
	_check(live == effects.size(),
		"%d effects started %d emitters" % [effects.size(), live])
	_check(ground >= 2, "%d dust effects draw beneath the actors" % ground)
	_check(air >= 4, "%d light effects draw above the actors" % air)

	# Review every preset in isolation as well.  This preserves the pixel-space
	# hierarchy found by the 0.38 gameplay-scale render gate: a VFX particle may
	# signal an event, but it may not become a larger hero than the event owner.
	for effect: int in effects:
		director.stop_all()
		director.play(effect, Vector2.ZERO, Vector2.RIGHT, Color.WHITE)
		var preset_emitter: CPUParticles2D = _first_live_emitter(director)
		_check(preset_emitter != null, "effect %d starts an isolated emitter" % effect)
		if preset_emitter == null:
			continue
		var expected_max: float = float(MAX_SCALE_BY_EFFECT.get(effect, 0.0))
		_check(is_equal_approx(preset_emitter.scale_amount_max, expected_max),
			"effect %d uses its reviewed maximum scale %.2f (found %.2f)" % [
				effect, expected_max, preset_emitter.scale_amount_max])
		var logical_diameter: float = PARTICLE_TEXTURE_SIZE * preset_emitter.scale_amount_max * GAMEPLAY_CAMERA_ZOOM
		_check(logical_diameter <= MAX_LOGICAL_DIAMETER,
			"effect %d logical particle diameter %.2f px stays <= %.2f px" % [
				effect, logical_diameter, MAX_LOGICAL_DIAMETER])
	director.stop_all()

	# Overflow must recycle rather than grow the pool.
	for _burst: int in pool_size * 3:
		director.play(0, Vector2.ZERO, Vector2.UP, Color.WHITE)
	_check(director.get_child_count() == pool_size,
		"overflow recycled instead of allocating (%d children)" % (
			director.get_child_count()))

	# Ambient bursts must give up the pool rather than take it. The pool is
	# saturated by the overflow above, so a footstep asked for here has to be
	# dropped, leaving the emitter that was carrying combat feedback alone.
	var ambient: Array = script.AMBIENT_EFFECTS
	_check(not ambient.is_empty(), "%d effects are declared ambient" % ambient.size())
	var before: Array[Vector2] = []
	for child: Node in director.get_children():
		var emitter: CPUParticles2D = child as CPUParticles2D
		if emitter != null:
			before.append(emitter.global_position)
	for _burst: int in pool_size * 2:
		director.play(ambient[0], Vector2(999.0, 999.0), Vector2.UP, Color.WHITE)
	var stolen: int = 0
	var index: int = 0
	for child: Node in director.get_children():
		var emitter: CPUParticles2D = child as CPUParticles2D
		if emitter != null:
			if emitter.global_position != before[index]:
				stolen += 1
			index += 1
	_check(stolen == 0,
		"ambient bursts evicted %d emitters from a saturated pool" % stolen)
	# And the yield must be the pool being full, not the effect being broken:
	# on a quiet pool the same call has to produce a burst.
	director.stop_all()
	director.play(ambient[0], Vector2(500.0, 500.0), Vector2.UP, Color.WHITE)
	var ambient_live: int = 0
	for child: Node in director.get_children():
		var emitter: CPUParticles2D = child as CPUParticles2D
		if emitter != null and emitter.emitting:
			ambient_live += 1
	_check(ambient_live == 1,
		"an ambient burst starts %d emitters on an idle pool" % ambient_live)

	# A non-finite aim vector must never reach the particle system.
	director.play(1, Vector2.ZERO, Vector2(NAN, INF), Color.WHITE)
	director.play(1, Vector2.ZERO, Vector2(INF, 0.0), Color.WHITE)
	var finite: bool = true
	for child: Node in director.get_children():
		var emitter: CPUParticles2D = child as CPUParticles2D
		if emitter != null and not emitter.direction.is_finite():
			finite = false
	_check(finite, "non-finite aim vectors are rejected at the boundary")

	director.stop_all()
	var running: int = 0
	for child: Node in director.get_children():
		var emitter: CPUParticles2D = child as CPUParticles2D
		if emitter != null and emitter.emitting:
			running += 1
	_check(running == 0, "stop_all silenced every emitter (%d left)" % running)

	_report()


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)


func _fail(description: String) -> void:
	_checks += 1
	_failures.append(description)


func _first_live_emitter(director: Node2D) -> CPUParticles2D:
	for child: Node in director.get_children():
		var emitter: CPUParticles2D = child as CPUParticles2D
		if emitter != null and emitter.emitting:
			return emitter
	return null


func _report() -> void:
	if _failures.is_empty():
		print("VFX DIRECTOR OK (%d checks)" % _checks)
		quit(0)
		return
	for failure: String in _failures:
		print("FAIL: %s" % failure)
	print("VFX DIRECTOR FAILED (%d of %d checks)" % [
		_failures.size(), _checks])
	quit(1)
