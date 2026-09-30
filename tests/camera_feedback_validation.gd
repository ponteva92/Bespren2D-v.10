extends SceneTree

## Focused gate for the impact camera.
##
## How a shake feels is a judgement only pixels settle, but the properties that
## make it shippable are contracts a headless run can hold. The one this exists
## for above all is the off switch: CLAUDE.md 11 will not accept camera shake in
## content production without an accessibility control, so
## [member CameraShake2D.intensity_scale] at zero has to leave the view
## completely untouched rather than merely quieter. The rest are the ways a
## shake goes wrong in practice - a camera left a pixel off centre after the
## last impact, an amplitude that grows without bound, or a NaN arriving from
## the network fire path and poisoning the transform.

const SHAKE_SCRIPT_PATH: String = "res://src/feedback/camera_shake_2d.gd"
## Enough frames at 60 Hz to cover the full decay from saturated trauma with
## room to spare, so "returns to rest" is measured rather than assumed.
const DECAY_FRAMES: int = 240
const FRAME_DELTA: float = 1.0 / 60.0

var _failures: PackedStringArray = PackedStringArray()
var _checks: int = 0


func _initialize() -> void:
	# The root window is not tree-attached during _initialize, so a node added
	# before this yields never receives _ready and never resolves its camera.
	await process_frame
	var script: GDScript = load(SHAKE_SCRIPT_PATH)
	if script == null:
		_fail("camera_shake_2d.gd failed to load")
		_report()
		return

	var camera: Camera2D = Camera2D.new()
	camera.zoom = Vector2(0.38, 0.38)
	root.add_child(camera)
	var shaker: Node = script.new()
	camera.add_child(shaker)
	await process_frame

	var max_offset: float = float(script.MAX_OFFSET_SCREEN_PX) * float(script.SCREEN_TO_WORLD)
	_check(is_equal_approx(shaker.get_trauma(), 0.0),
		"a fresh shaker starts at rest")
	_check(camera.offset == Vector2.ZERO,
		"a fresh shaker leaves the camera offset untouched")
	_check(not shaker.is_processing(),
		"an idle shaker costs no frame callback")

	# --- the accessibility contract ---------------------------------------
	# Zero intensity has to mean absent, not reduced. A shake that still moved
	# the view by a fraction of a pixel would defeat the entire point of the
	# control for the player who needed to turn it off.
	shaker.intensity_scale = 0.0
	var moved_while_off: int = 0
	for _frame: int in 30:
		shaker.add_impact(1.0, Vector2.RIGHT)
		shaker._process(FRAME_DELTA)
		if camera.offset != Vector2.ZERO:
			moved_while_off += 1
	_check(moved_while_off == 0,
		"intensity 0 moved the camera on %d of 30 saturating impacts" % moved_while_off)
	_check(is_equal_approx(shaker.get_trauma(), 0.0),
		"intensity 0 banks no trauma to release later")

	shaker.intensity_scale = 1.0
	_check(is_equal_approx(shaker.intensity_scale, 1.0),
		"intensity restores to full")
	shaker.intensity_scale = 4.0
	_check(is_equal_approx(shaker.intensity_scale, 1.0),
		"intensity clamps above 1.0 rather than amplifying past the authored max")

	# --- bounded amplitude -------------------------------------------------
	# Trauma accumulates from many sources at once - a horde dying inside one
	# volley - so the ceiling has to hold under repeated saturation, not just
	# after a single impact.
	var peak: float = 0.0
	for _burst: int in 12:
		shaker.add_impact(1.0)
	_check(shaker.get_trauma() <= 1.0 + 0.0001,
		"twelve full impacts clamp trauma at 1.0 (found %.3f)" % shaker.get_trauma())
	for _frame: int in DECAY_FRAMES:
		shaker._process(FRAME_DELTA)
		peak = maxf(peak, camera.offset.length())
	_check(peak <= max_offset + 0.001,
		"peak offset %.2f stays inside the %.2f world-unit ceiling" % [peak, max_offset])
	_check(peak > 0.0, "a saturated shake actually moved the camera")

	# --- returns exactly to rest ------------------------------------------
	# Not close to zero: a camera left a fraction off centre stays there for the
	# rest of the session, and every later shake starts from that error.
	_check(is_equal_approx(shaker.get_trauma(), 0.0),
		"trauma decays to zero within %.1f seconds" % (DECAY_FRAMES * FRAME_DELTA))
	_check(camera.offset == Vector2.ZERO,
		"a spent shake restores the offset to exactly zero (found %s)" % camera.offset)
	_check(not shaker.is_processing(),
		"a spent shake stops processing instead of ticking a zero offset forever")

	# --- the focus tween's property is untouched --------------------------
	# PlayerAvatar.focus_camera_at owns Camera2D.position. If the shake wrote
	# there too, a minimap ping arriving mid-shake would fight the jolt and one
	# of the two would be lost.
	camera.position = Vector2(37.0, -19.0)
	shaker.add_impact(1.0, Vector2.UP)
	for _frame: int in 20:
		shaker._process(FRAME_DELTA)
	_check(camera.position == Vector2(37.0, -19.0),
		"the shake writes offset only and leaves the focus position alone")
	shaker.stop()
	_check(camera.offset == Vector2.ZERO and is_equal_approx(shaker.get_trauma(), 0.0),
		"stop() releases both the trauma and the offset")

	# --- a directional impact is a shove, not a rattle --------------------
	var along: float = 0.0
	var across: float = 0.0
	var axis: Vector2 = Vector2(0.6, -0.8).normalized()
	for _burst: int in 40:
		shaker.add_impact(1.0, axis)
		shaker._process(FRAME_DELTA)
		along += absf(camera.offset.dot(axis))
		across += absf(camera.offset.dot(axis.orthogonal()))
	_check(along > across,
		"a directional impact throws the frame along its axis (%.2f vs %.2f across)"
		% [along, across])
	shaker.stop()

	# --- hostile input -----------------------------------------------------
	# The fire path feeds impact directions that came off the network, and a
	# single NaN reaching Camera2D.offset corrupts the view permanently.
	for bad_trauma: float in [NAN, INF, -1.0, 0.0]:
		shaker.add_impact(bad_trauma, Vector2.RIGHT)
	_check(is_equal_approx(shaker.get_trauma(), 0.0),
		"non-finite and non-positive trauma is rejected before it banks")
	shaker.add_impact(0.5, Vector2(NAN, 1.0))
	_check(is_equal_approx(shaker.get_trauma(), 0.0),
		"a non-finite direction is rejected rather than normalized into a NaN axis")
	for _frame: int in 8:
		shaker._process(FRAME_DELTA)
	_check(camera.offset.is_finite() and camera.offset == Vector2.ZERO,
		"the camera offset survives hostile input finite and at rest")

	# --- a zero-length direction still rattles ----------------------------
	# A body coming apart has no axis, and passing Vector2.ZERO must mean
	# omnidirectional rather than no shake at all.
	shaker.add_impact(1.0, Vector2.ZERO)
	var radial_peak: float = 0.0
	for _frame: int in 30:
		shaker._process(FRAME_DELTA)
		radial_peak = maxf(radial_peak, camera.offset.length())
	_check(radial_peak > 0.0, "a radial impact with no axis still moves the camera")
	shaker.stop()

	# --- a shaker with no camera refuses to run ---------------------------
	var orphan: Node = script.new()
	root.add_child(orphan)
	await process_frame
	orphan.add_impact(1.0, Vector2.RIGHT)
	_check(is_equal_approx(orphan.get_trauma(), 0.0) and not orphan.is_processing(),
		"a shaker with no Camera2D parent banks nothing and never processes")
	orphan.queue_free()

	_report()


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)


func _fail(description: String) -> void:
	_checks += 1
	_failures.append(description)


func _report() -> void:
	if _failures.is_empty():
		print("CAMERA FEEDBACK OK (%d checks)" % _checks)
		quit(0)
		return
	for failure: String in _failures:
		print("FAIL: %s" % failure)
	print("CAMERA FEEDBACK FAILED (%d of %d checks)" % [_failures.size(), _checks])
	quit(1)
