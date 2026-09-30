class_name HealthBar2D
extends Node2D

## One drawn health bar, shared by the survivors and the Base Core.
##
## Both already had a readout before this existed and neither was legible in
## combat: the survivors carried a seven-pixel [Label] spelling "HP 087", which
## asks the player to read a number during a firefight, and the Base carried two
## flat rectangles that changed colour once at thirty percent. Neither showed how
## much a hit took, which is the only thing a health bar is really for.
##
## It is one node used in both places on purpose. A bar over a survivor and a bar
## under the refuge that share an outline weight, a chip colour and a critical
## cadence read as one authored language; two separately tuned widgets read as
## two programmers. Everything is drawn rather than textured - at this size a
## texture would cost an import, an atlas slot and a filtering decision to
## reproduce shapes that are four [method CanvasItem.draw_rect] calls.

## The trailing bar. It holds the previous value and drains toward the real one,
## so a hit reads as a visible bite out of the bar rather than as a length the
## player would have had to be watching to notice. This is the whole reason the
## node has a process callback at all.
const CHIP_DRAIN_PER_SECOND: float = 0.85
## How long the chip sits still before it starts draining. Without the pause the
## bite is gone before the eye finds it; with it, a burst of fire still reads as
## separate hits because each one restarts the wait.
const CHIP_HOLD_SECONDS: float = 0.18

## Thresholds for the three threat bands. Colour alone does not carry these -
## the bar also shortens, and the critical band pulses - because CLAUDE.md 11
## requires state to survive without hue.
const HURT_RATIO: float = 0.6
const CRITICAL_RATIO: float = 0.28

## Deliberately not amber. CLAUDE.md 8 makes the Base Core the only dominant
## Amber Gold source on screen, so a mid-band that rang like #FFB52E would put a
## second focal warmth on every damaged body in the horde. The hurt stop is a
## muted ochre instead: it still reads as a warning between the green and the
## red without competing with the refuge for attention.
const COLOR_HEALTHY: Color = Color("5be07a")
const COLOR_HURT: Color = Color("c8b14a")
## Brighter and pinker than the palette's Rust bloom #BC431A, so a bar at deaths
## door never reads as one more corroded surface in a world built out of them.
const COLOR_CRITICAL: Color = Color("e8483c")

## Void charcoal from the palette. The outline is what lets the bar sit over a
## bright muzzle flash or a black rooftop and keep the same shape either way.
const COLOR_OUTLINE: Color = Color("060909")
const COLOR_BACKING: Color = Color(0.05, 0.06, 0.07, 0.88)
## The chip is the fills own band, lightened and translucent, so the lost slice
## still belongs to the bar rather than looking like a second bar behind it.
const CHIP_LIGHTEN: float = 0.45
const CHIP_ALPHA: float = 0.70

## How far the fill drops while the bar is at rest - full health, no chip left to
## drain, and an owner that is not allowed to hide. Only the Base Core is in that
## position: the survivors and every zombie vanish at full instead, so nothing
## about their bars changes here.
##
## It exists because a readout that is always on screen spends most of the match
## saying nothing, and this one was saying it very loudly. Measured off the camp
## capture the full-health bar ran at a mean luma of 202 with 0.84 saturation in a
## frame whose mean is 57 and whose refuge sits at 71 - a 58 by 5 block of the
## brightest, most saturated pixels in the shot, permanently, while CLAUDE.md 8
## reserves that pull for the Base Core itself. Darkening rather than fading:
## alpha would let the terrain behind it change the bar's colour, which is the
## exact property the outline exists to prevent. At 0.55 the fill lands near 85,
## in among the camp instead of on top of it, and the first point of damage
## restores it to full strength - so a hit now wakes the readout up rather than
## merely shortening something that was already shouting.
const REST_DARKEN: float = 0.55

## Hz of the critical pulse. Fast enough to read as an alarm, slow enough not to
## strobe - the bar is small and a higher rate turns into a shimmer.
const CRITICAL_PULSE_HZ: float = 2.6
## How far the critical bands value swings. Value, not alpha: a bar that faded
## out at its lowest point would be least visible exactly when it matters most.
const CRITICAL_PULSE_DEPTH: float = 0.30

## World units per screen pixel at the gameplay camera zoom of 0.38, shared with
## [constant VfxDirector.SCREEN_TO_WORLD] and [constant CameraShake2D.SCREEN_TO_WORLD].
## Every dimension here is drawn in world space and then scaled down by the
## camera, so a one-unit outline resolves to roughly a third of a pixel and
## disappears. The thin parts of the bar are therefore authored in screen pixels
## and converted, while the bar body stays in world units because it has to sit
## in proportion to a body that is measured there too.
const SCREEN_TO_WORLD: float = 1.0 / 0.38

## One pixel each on screen. The outline is what holds the shape over a muzzle
## flash or a black rooftop, the bevel is the only lift a bar three pixels tall
## can carry, and the ticks have to survive the same divide or they smear.
const OUTLINE_SCREEN_PX: float = 1.0
const BEVEL_SCREEN_PX: float = 1.0
const TICK_SCREEN_PX: float = 1.0
## A short bar must not become all bevel. At the survivor size the lift is the
## top third of the fill; on a taller bar the pixel width wins.
const BEVEL_MAX_FRACTION: float = 0.34

## How far the bevel lifts off the fill, and a sibling of [constant
## CHIP_LIGHTEN] rather than the bare literal it used to be. It is named
## because the operator behind it is compressive: [method Color.lightened]
## is affine toward white, mapping 0 to 0.42 and 1 to 1, so a colour that
## has already been darkened comes back up disproportionately. Lightening a
## resting fill turned REST_DARKEN's 0.45 multiplier into 0.72 and left the
## bevel at 1.85x its own fill, against the 1.15x every other state ships.
const BEVEL_LIGHTEN: float = 0.42

## Bar geometry in world units at the owners scale. Set through [method setup].
var bar_size: Vector2 = Vector2(37.0, 8.0)
## Ticks drawn across the fill. A glance then gives a fraction rather than a
## length the player has to compare against a remembered full bar.
var segments: int = 4
## Survivors hide at full health so a quiet moment carries no clutter; the Base
## stays up because it is the objective and its state is always relevant.
var hide_when_full: bool = true

var _ratio: float = 1.0
var _chip: float = 1.0
var _chip_hold: float = 0.0
var _pulse_time: float = 0.0
## Whether the owner considers this bars subject alive at all. A dead survivor
## shows nothing rather than an empty frame, which would otherwise sit over the
## corpse for the whole ten-second respawn.
var _active: bool = true


## Local units per screen pixel for this particular bar, which is [constant
## SCREEN_TO_WORLD] divided back out by whatever scale the owner is drawn at.
##
## Without it the hairlines are not shared at all, which is the one thing this
## class claims. Everything thin here is authored in screen pixels and converted
## once through a constant, and that conversion silently assumed every owner sits
## at scale one - but game_world.tscn instances the Base Core at Vector2(2, 2),
## so the refuge's outline, bevel and ticks all drew at two screen pixels against
## the survivors' one. The bar body is deliberately left alone: the Base being
## physically larger than a survivor is the design, and only the hairlines were
## ever meant to be constant.
func _pixel() -> float:
	var scale_x: float = absf(global_scale.x) if is_inside_tree() else 1.0
	return SCREEN_TO_WORLD / maxf(scale_x, 0.001)


func _ready() -> void:
	# Idle bars cost nothing. Only a draining chip or a pulsing critical band
	# needs a frame, and both switch the callback back off when they finish.
	set_process(false)
	_refresh_process()


## [param size] is the drawn rectangle and [param tick_count] the number of
## segments across it. Call before the first [method set_ratio] so the first
## draw is already at the owners proportions.
func setup(size: Vector2, tick_count: int, hide_at_full: bool) -> void:
	bar_size = Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	segments = maxi(tick_count, 1)
	hide_when_full = hide_at_full
	queue_redraw()


## [param ratio] is clamped rather than trusted: it arrives from a replicated
## health value, and a bar is not the place to discover that a division produced
## a NaN.
func set_ratio(ratio: float) -> void:
	var safe: float = clampf(ratio, 0.0, 1.0) if is_finite(ratio) else 0.0
	if is_equal_approx(safe, _ratio):
		return
	if safe > _ratio:
		# Healing catches the chip up immediately. A chip left behind a rising
		# bar would draw a bite that is no longer missing.
		_chip = safe
		_chip_hold = 0.0
	else:
		_chip_hold = CHIP_HOLD_SECONDS
	_ratio = safe
	_refresh_process()
	queue_redraw()


func get_ratio() -> float:
	return _ratio


func get_chip_ratio() -> float:
	return _chip


## [param alive] false hides the bar entirely. Kept separate from a zero ratio
## because a survivor at zero who is about to respawn and a survivor at zero who
## is still standing are different states, and only the owner knows which.
func set_active(alive: bool) -> void:
	if _active == alive:
		return
	_active = alive
	_refresh_process()
	queue_redraw()


func is_active() -> bool:
	return _active


## Snap both bars to [param ratio] with no chip and no drain. For a respawn or a
## session reset, where the previous value is not something the player lost.
func reset_to(ratio: float) -> void:
	_ratio = clampf(ratio, 0.0, 1.0) if is_finite(ratio) else 0.0
	_chip = _ratio
	_chip_hold = 0.0
	_pulse_time = 0.0
	_refresh_process()
	queue_redraw()


func _process(delta: float) -> void:
	var step: float = maxf(delta, 0.0)
	if _chip > _ratio:
		if _chip_hold > 0.0:
			_chip_hold = maxf(_chip_hold - step, 0.0)
		else:
			_chip = maxf(_chip - CHIP_DRAIN_PER_SECOND * step, _ratio)
		queue_redraw()
	if _is_critical():
		_pulse_time += step
		queue_redraw()
	else:
		_pulse_time = 0.0
	_refresh_process()


## The bar is only allowed to tick while it has something to animate, which is a
## draining chip or a critical pulse. Everything else - including a bar sitting
## at half health - is a static drawing.
func _refresh_process() -> void:
	var needs_frame: bool = _is_visible_now() and (_chip > _ratio or _is_critical())
	if needs_frame != is_processing():
		set_process(needs_frame)


func _is_critical() -> bool:
	return _active and _ratio > 0.0 and _ratio <= CRITICAL_RATIO


## Full and hidden still means the chip may be mid-drain, so a bar healed to full
## finishes its animation rather than vanishing mid-bite.
func _is_visible_now() -> bool:
	if not _active:
		return false
	if not hide_when_full:
		return true
	return _ratio < 1.0 or _chip < 1.0


## The band the current ratio falls in. Two hard stops rather than a continuous
## lerp: a bar that changes colour by one imperceptible step per point of damage
## communicates nothing, where a bar that crosses into a new band announces it.
func _band_color() -> Color:
	if _ratio <= CRITICAL_RATIO:
		return COLOR_CRITICAL
	if _ratio <= HURT_RATIO:
		return COLOR_HURT
	return COLOR_HEALTHY


## The colour the fill is actually drawn in - the band, plus the critical alarm,
## plus the rest treatment. Public because the readability gate has to test the
## colour that reaches the screen rather than a second copy of this arithmetic
## that could drift away from it.
func fill_color() -> Color:
	var fill: Color = _band_color()
	if _is_critical():
		# Value swing on a sine, so the alarm has a cadence a player who cannot
		# separate the red from the ochre still reads.
		var wave: float = 0.5 + 0.5 * sin(_pulse_time * TAU * CRITICAL_PULSE_HZ)
		return fill.lightened(CRITICAL_PULSE_DEPTH * wave)
	if is_resting():
		return fill.darkened(REST_DARKEN)
	return fill

## The colour the bevel is actually drawn in. Public for the same reason
## [method fill_color] is: the gate has to read what reaches the screen, and
## a gate that tests only the input to a compressive operator does not test
## its output - which is precisely how a resting bevel shipped at 1.85x its
## own fill while the rest treatment was being asserted on the fill alone.
##
## Order is the whole fix. At rest the band is lifted first and the result
## darkened, so the lift survives as a ratio instead of being re-inflated by
## the lift. Every other state is the fill lifted, byte for byte as before.
func bevel_color() -> Color:
	if is_resting():
		return _band_color().lightened(BEVEL_LIGHTEN).darkened(REST_DARKEN)
	return fill_color().lightened(BEVEL_LIGHTEN)


## Whether the bar is currently saying nothing. Full, nothing left to drain, and
## owned by something that keeps its readout up regardless.
func is_resting() -> bool:
	return _active and not hide_when_full and _ratio >= 1.0 and _chip >= 1.0


func _draw() -> void:
	if not _is_visible_now():
		return
	var half: float = bar_size.x * 0.5
	var pixel: float = _pixel()
	var outline: float = OUTLINE_SCREEN_PX * pixel
	var frame: Rect2 = Rect2(
		Vector2(-half - outline, -outline),
		bar_size + Vector2(outline, outline) * 2.0
	)
	draw_rect(frame, COLOR_OUTLINE, true)
	draw_rect(Rect2(Vector2(-half, 0.0), bar_size), COLOR_BACKING, true)

	var fill: Color = fill_color()

	if _chip > _ratio:
		var chip_color: Color = fill.lightened(CHIP_LIGHTEN)
		chip_color.a = CHIP_ALPHA
		draw_rect(
			Rect2(
				Vector2(-half + bar_size.x * _ratio, 0.0),
				Vector2(bar_size.x * (_chip - _ratio), bar_size.y)
			),
			chip_color,
			true
		)
	if _ratio > 0.0:
		draw_rect(
			Rect2(Vector2(-half, 0.0), Vector2(bar_size.x * _ratio, bar_size.y)),
			fill,
			true
		)
		# One bright band along the top of the fill. It is the whole bevel: at
		# three screen pixels tall a gradient is invisible, but a single lifted
		# row is what stops the bar reading as flat vector art.
		draw_rect(
			Rect2(
				Vector2(-half, 0.0),
				Vector2(
					bar_size.x * _ratio,
					minf(
						BEVEL_SCREEN_PX * pixel,
						bar_size.y * BEVEL_MAX_FRACTION
					)
				)
			),
			bevel_color(),
			true
		)

	# Ticks last, over the fill, so they subdivide the bar rather than being
	# swallowed by it.
	var tick: float = TICK_SCREEN_PX * pixel
	for index: int in range(1, segments):
		var x: float = -half + bar_size.x * (float(index) / float(segments))
		draw_rect(
			Rect2(Vector2(x - tick * 0.5, 0.0), Vector2(tick, bar_size.y)),
			COLOR_OUTLINE,
			true
		)
