class_name CameraShake2D
extends Node

## Trauma-driven impact shake for one [Camera2D].
##
## [JuiceRig] is deliberately no-shake: it scales and flashes [CanvasItem]s and
## never touches the view, because the project would not accept a camera effect
## without a way to turn it off. [member intensity_scale] is that way, and it is
## the reason this exists as a separate node rather than as another JuiceRig
## method - the whole effect is one multiplier away from being absent, and a
## settings screen has exactly one property to bind. Until that screen exists
## the shake ships at full strength, which is a default rather than a lock.
##
## The camera's [member Camera2D.position] is already spoken for by the minimap
## focus tween, so this writes [member Camera2D.offset] instead. The two compose
## additively, and a ping arriving mid-shake reads as both rather than as one
## cancelling the other.

## Trauma, not amplitude. Impacts add to a single reservoir that decays on its
## own, so ten deaths in a second produce one sustained rumble instead of ten
## restarted tweens fighting over the same offset.
const TRAUMA_DECAY_PER_SECOND: float = 2.35
## Shake is trauma squared. The curve is what separates a graze from a boss
## landing: linear trauma spends too long at middling amplitudes, which reads as
## a loose camera rather than as an impact.
const TRAUMA_EXPONENT: float = 2.0

## Screen pixels at full trauma, converted through the gameplay zoom below.
## Three and a half is about as far as a 480x270 canvas can move before the
## static world objects start to read as sliding rather than as being jolted.
const MAX_OFFSET_SCREEN_PX: float = 3.5
## The gameplay camera sits at 0.38 zoom, so a world unit is 0.38 screen pixels
## and an offset authored in screen pixels has to be divided back out.
const SCREEN_TO_WORLD: float = 1.0 / 0.38

## Hz through the noise field. Fast enough to read as a jolt, slow enough that
## the offset is continuous between frames - sampling white noise per frame
## reads as buzz and aliases badly at 30 FPS.
const SHAKE_FREQUENCY: float = 21.0
## How much of a directional impact is thrown along its own axis rather than
## across it. A shove that is purely axial reads as a slide, so a third of the
## motion stays perpendicular.
const LATERAL_FRACTION: float = 0.34

## Multiplied into every impact. 0.0 is the accessibility off switch, and the
## effect must be completely absent at that value rather than merely reduced.
var intensity_scale: float = 1.0:
	set(value):
		intensity_scale = clampf(value, 0.0, 1.0)
		if intensity_scale <= 0.0:
			_release()

var _camera: Camera2D
var _trauma: float = 0.0
var _direction: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _noise: FastNoiseLite
## Whether the camera is currently carrying an offset this node put there. Lets
## an idle shaker leave the property alone entirely, which is what keeps it from
## fighting anything else that might want to write it.
var _holding_offset: bool = false


func _ready() -> void:
	_camera = get_parent() as Camera2D
	if _camera == null:
		push_error("CameraShake2D must be a child of the Camera2D it shakes")
		set_process(false)
		return
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_VALUE
	_noise.frequency = 1.0
	# Nothing to do until something hits. An idle shaker that still ticks would
	# cost a frame callback per player for an offset that is always zero.
	set_process(false)


## [param trauma] is a fraction of the full effect, and [param direction] is the
## axis an impact arrived along - [constant Vector2.ZERO] for anything with no
## direction, such as a body coming apart, which then rattles instead of shoving.
func add_impact(trauma: float, direction: Vector2 = Vector2.ZERO) -> void:
	if _camera == null or intensity_scale <= 0.0:
		return
	if not is_finite(trauma) or trauma <= 0.0 or not direction.is_finite():
		return
	_trauma = clampf(_trauma + trauma * intensity_scale, 0.0, 1.0)
	# The newest impact owns the axis. Averaging directions across overlapping
	# impacts converges on nothing, and the shove the player is meant to feel is
	# always the one that just landed.
	_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.ZERO
	set_process(true)


func get_trauma() -> float:
	return _trauma


func stop() -> void:
	_trauma = 0.0
	_release()


func _process(delta: float) -> void:
	_time += maxf(delta, 0.0)
	_trauma = maxf(_trauma - TRAUMA_DECAY_PER_SECOND * maxf(delta, 0.0), 0.0)
	if _trauma <= 0.0:
		_release()
		return
	var shake: float = pow(_trauma, TRAUMA_EXPONENT)
	# Two decorrelated lines through one field rather than two noise resources.
	# Sampling the same line for both axes would move the camera along a single
	# diagonal and nothing else.
	var wobble: Vector2 = Vector2(
		_noise.get_noise_2d(_time * SHAKE_FREQUENCY, 0.0),
		_noise.get_noise_2d(0.0, _time * SHAKE_FREQUENCY)
	)
	if _direction != Vector2.ZERO:
		wobble = (
			_direction * wobble.x
			+ _direction.orthogonal() * wobble.y * LATERAL_FRACTION
		)
	_camera.offset = wobble * (MAX_OFFSET_SCREEN_PX * SCREEN_TO_WORLD * shake)
	_holding_offset = true


## Returns the camera to exactly zero rather than to whatever the last noise
## sample happened to be, so a shake that ends cannot leave the view a pixel off
## centre for the rest of the session.
func _release() -> void:
	set_process(false)
	if not _holding_offset:
		return
	_holding_offset = false
	if is_instance_valid(_camera):
		_camera.offset = Vector2.ZERO
