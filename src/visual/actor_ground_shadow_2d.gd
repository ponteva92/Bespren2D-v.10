class_name ActorGroundShadow2D
extends Node2D

## The contact shadow every actor stands on.
##
## Nothing in the roster had one. Structures and world obstacles each drew their
## own grounding ellipse, so a wreck and a fence sat in the world while the
## survivors and the entire horde floated over it - the single loudest reason
## the game read as sprites on a texture rather than as figures in a place.
##
## The treatment is deliberately heavier than a prop's. An actor is the thing the
## player is tracking, and a contact shadow is what tells them where it is
## standing: a tight dark core where the feet meet the ground plus a wide soft
## falloff around it, which is the read a flat ellipse never achieves at any
## single opacity. The ladder reaches roughly 0.41 at the core and fades to
## nothing by the rim.
##
## That hierarchy is now one number rather than two tables. The ladder moved to
## [GroundShadow], where a prop draws the same steps at
## [constant GroundShadow.PROP_STRENGTH]; this node passes full strength. The
## previous arrangement let the two drift, and it had: the prop side peaked at
## 0.152 with its darkest step spread over 0.72 of the radius, and ambient
## scenery drew a flat disc in a different hue for one kind out of ten.
##
## Drawn as a sibling ahead of the sprite rather than as a shader on it. The
## sprite is an AnimatedSprite2D swapping AtlasTexture regions eight ways per
## clip, so anything painted into its material would have to track the frame;
## an ellipse under it is correct for every frame by construction, costs four
## draw_circle calls, and stays put while the body above it animates.
##
## The colour and the ladder both come from [GroundShadow], so a survivor and the
## barrier beside him agree about where the light is coming from - which is what
## the sentence here used to claim while the two sides disagreed by a factor of
## 2.7 on how hard it was shining.

## How flat the ellipse is, and it is an authored value rather than a derived one.
## This comment used to say the number came from the bake camera's 52 degree
## elevation, and that claim is arithmetically false: a unit ground circle under
## [code]tools/art/aaa_bake_rig.py[/code]'s [code]CAM_ELEVATION_DEG = 52.0[/code]
## projects to 1.0 horizontal by sin(52) = 0.788 vertical, not 0.46. What 0.46
## actually corresponds to is an elevation of 27.4 degrees - a view about half as
## steep as the one the sprites standing on this ellipse were baked from.
##
## The value stays because nothing has measured which of the two reads better on
## a delivered frame, and a docstring that states a derivation is a claim that can
## be checked arithmetically - so the claim is retracted here rather than the
## constant being changed to satisfy it. If this is ever revisited it needs the
## same treatment [code]base_radius[/code] got in CLAUDE.md 7: a rendered sweep
## through the real Mobile/Vulkan path bracketing the candidates, not a second
## number matched to a first one nobody re-derived.
const GROUND_FLATTEN: float = 0.46

var base_radius: float = 6.0:
	set(value):
		base_radius = maxf(value, 0.5)
		queue_redraw()

## 1.0 on the ground, falling to 0 as the actor is lifted. A shadow that stays
## the same while its owner is knocked back reads as painted on.
var contact: float = 1.0:
	set(value):
		contact = clampf(value, 0.0, 1.0)
		queue_redraw()

## Scales the whole treatment without touching per-layer balance, for variants
## that need a heavier or lighter footprint than their sprite width implies.
var opacity: float = 1.0:
	set(value):
		opacity = clampf(value, 0.0, 2.0)
		queue_redraw()


func _ready() -> void:
	# The shadow belongs to the ground, not to the body, so it must not inherit
	# the squash, flip or recoil tweens the presentation runs on the sprite.
	top_level = false
	z_as_relative = true
	z_index = -1


## Lift the shadow's owner off the floor. `height` is in the same logical pixels
## the sprite moves in; the shadow tightens and fades the way a real one does
## rather than simply disappearing.
## Owns its own invalidation. Callers drive this every frame from a bob curve,
## and a redraw there would either be forgotten - leaving the shadow frozen at
## whatever it drew first - or issued unconditionally for a value that usually
## has not changed. Comparing first costs one float and does both jobs.
func set_lift(height: float) -> void:
	var updated: float = 1.0 - clampf(absf(height) / 24.0, 0.0, 1.0)
	if absf(updated - contact) < 0.002:
		return
	contact = updated
	queue_redraw()


func _draw() -> void:
	if contact <= 0.0 or opacity <= 0.0:
		return
	# A lifted actor casts a smaller, fainter, softer shadow. Both curves are
	# deliberately gentle: the shadow has to stay legible as a position marker
	# during a knockback, which is exactly when the player most needs it.
	var spread: float = lerpf(0.74, 1.0, contact)
	var strength: float = opacity * lerpf(0.34, 1.0, contact)
	var radius: float = maxf(base_radius * spread, 0.5)
	GroundShadow.draw_ellipse(
		self, Vector2.ZERO, Vector2(radius, radius * GROUND_FLATTEN), strength
	)
