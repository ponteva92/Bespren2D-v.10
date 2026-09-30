class_name GroundShadow
extends RefCounted

## One contact-shadow language for everything that stands on the world floor.
##
## The game drew three of them. [ActorGroundShadow2D] stacked four ellipses to a
## 0.414 core, [WorldObstacle2D] stacked three to 0.152, and
## [WorldAmbientSceneryChunk2D] drew a single flat disc at 0.44 in a different
## hue - for one of its ten kinds. Nine kinds, and every background decoration,
## drew nothing. The actor docstring already claimed a survivor and "the barrier
## beside him agree about where the light is coming from"; they agreed on hue.
##
## What the measurement actually showed is worth keeping, because it corrected
## the guess that started this. Open asphalt in
## `artifacts/world_city_barrier_validation.png` has a mean luma of 62.1 with a
## grain sigma of 4.1 - the 53 to 76 min/max spread that looked alarming is
## outliers, not noise. Against that, the prop ladder's 0.152 core moves the
## ground 8.1 L, which is 2.0 sigma: marginal rather than absent. The actor's
## 0.414 core moves it 21.9 L, or 5.3 sigma.
##
## But a row-averaged profile under the concrete barrier in that same capture -
## 111 columns per row, which cuts the noise to 0.4 L and would make an 8 L dip
## unmissable - is flat from y=192 to y=218. The first reading of that was wrong
## and is worth recording as wrong: the barrier was taken for ambient scenery
## drawing no shadow at all. A runtime probe over the world map found it is a
## [WorldObstacle2D] `VEHICLE_WRECK` variant that draws a shadow every frame. The
## ellipse simply ended 62.6 world units above its own sprite's bottom edge, so
## the sprite covered all of it.
##
## That turned out to be general. Obstacle contacts were sized from the collision
## shape while the sprite is scaled from `max(half_size.x, half_size.y)` and then
## offset - two unrelated numbers - and 20 of the 21 imported visual families had
## their whole contact behind their own pixels. So the ladder's density was never
## the defect, and neither was scenery coverage alone. Contacts have to be
## anchored to the sprite the camera actually sees.
##
## The ladder below is the actor's, kept because it is the one that reads: a wide
## faint halo falling to a tight dark core, which is what a flat disc at any
## single opacity cannot do. Callers scale it with `strength` rather than
## authoring their own steps, so the hierarchy the actor docstring asked for -
## an actor grounded harder than the prop beside it - survives as one number
## instead of two divergent tables. [constant PROP_STRENGTH] puts a prop at
## 3.4 sigma: clear of the grain, clearly under the actor.
##
## Weight sits inward on purpose. A tight core overlaps its neighbour's far less
## often than a broad wash does, which is what keeps a dense treeline from
## compositing into mud.

## The cold near-black every grounded thing shares, so one world light is implied.
const COLOR: Color = Color(0.025, 0.039, 0.035, 1.0)

## Ellipse radii as multiples of the base radius, paired with the alpha each is
## drawn at. Ordered outermost first so the core composites on top. Stacked, they
## reach 0.414 at full strength.
const LAYERS: Array[Vector2] = [
	Vector2(1.35, 0.055),
	Vector2(1.00, 0.105),
	Vector2(0.66, 0.150),
	Vector2(0.38, 0.185),
]

## Props and scenery. Yields a 0.267 core - 14.1 L on the measured asphalt, or
## 3.4 sigma of its grain - against the actor's 0.414. Grounded without pulling
## focus, which is what the old 2.0 sigma treatment was aiming at and missed.
## How deep a contact may get, in world units, however wide the thing above it is.
##
## A ground ellipse scaled purely from sprite width gives a district block a pool
## 249 units deep, which stops reading as contact and starts reading as terrain.
## Capping the depth keeps a big shell's footprint wide and shallow - the shape a
## 3/4 top-down camera actually sees - while a rock keeps its rounder one.
const MAX_CONTACT_DEPTH: float = 64.0

const PROP_STRENGTH: float = 0.60

## Below this a layer is not worth a draw call.
const MIN_ALPHA: float = 0.004


## Draw the ladder into [param canvas] as an ellipse of [param radii] centred on
## [param center], both in the canvas's local space.
##
## Sets and clears the canvas transform, so callers must not be part-way through
## their own [method CanvasItem.draw_set_transform] when they call this.
static func draw_ellipse(
	canvas: CanvasItem,
	center: Vector2,
	radii: Vector2,
	strength: float = 1.0
) -> void:
	if canvas == null or strength <= 0.0:
		return
	# draw_circle is the only filled primitive with a soft enough cost profile at
	# these counts, so the ellipse comes from scaling the canvas rather than from
	# a polygon. Scaling on the shorter axis keeps the radius argument meaningful.
	var base_radius: float = maxf(radii.y, 1.0)
	var stretch: float = maxf(radii.x, 1.0) / base_radius
	canvas.draw_set_transform(center, 0.0, Vector2(stretch, 1.0))
	for layer: Vector2 in LAYERS:
		var alpha: float = layer.y * strength
		if alpha < MIN_ALPHA:
			continue
		canvas.draw_circle(
			Vector2.ZERO,
			base_radius * layer.x,
			Color(COLOR.r, COLOR.g, COLOR.b, alpha)
		)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
