class_name ActorFacing
extends RefCounted
## Maps a screen-space heading onto one of the eight rows of a baked actor sheet.
##
## The bake turns an actor once around its own vertical axis in eight equal
## world-space steps and renders each step as a sheet row. Those steps are equal
## in the world; they are not equal on screen. The stage camera sits at 52
## degrees of elevation, which compresses the screen-vertical axis by sin(52) =
## 0.788, so the heading one step off "straight down" lands at 38.24 degrees from
## the horizontal rather than at 45.
##
## Picking a row by slicing an angle into eight equal wedges would therefore hand
## a diagonal sprite to a heading up to seven degrees away from the one it was
## rendered for, and an actor moving along a shallow diagonal would visibly point
## somewhere other than where it is going. Scoring against the measured headings
## instead makes the row selection agree with the projection the renderer
## actually used.
##
## The vectors below are screen directions for the eight table slots, not the
## sheet row that wears that direction. Godot 2D screen space, so +Y is down.
## The sheet itself is rotated half a turn from these slots; see
## `row_for_direction`.

## The sheet row whose pixels face the camera. Row 6 is that face. The bake
## stored the opposite compass from the heading table below: the art in row 0
## walks screen-right, and the art in row 2 shows a back. `row_for_direction`
## adds half a turn so a survivor running left wears the left-facing row.
const CAMERA_FACING_ROW: int = 6

## sin(52 degrees): how much of a world-vertical step survives the camera tilt.
const VERTICAL_FORESHORTENING: float = 0.788010753606722

const ROW_COUNT: int = 8

const ROW_HEADINGS: Array[Vector2] = [
	Vector2(-1.0, 0.0),
	Vector2(-0.785436, 0.618943),
	Vector2(0.0, 1.0),
	Vector2(0.785436, 0.618943),
	Vector2(1.0, 0.0),
	Vector2(0.785436, -0.618943),
	Vector2(0.0, -1.0),
	Vector2(-0.785436, -0.618943),
]

## Below this the direction is noise - a stopped actor, or a replicated vector
## that has decayed to nothing - and the caller's current row is kept rather than
## letting rounding error spin the sprite.
const MIN_DIRECTION_LENGTH: float = 0.01


## The row whose baked heading best matches `direction`. Falls back to
## `current_row` for a direction too short to carry a heading, so a stopping
## actor holds the way it was last facing instead of snapping to a default.
static func row_for_direction(direction: Vector2, current_row: int = CAMERA_FACING_ROW) -> int:
	var safe_row: int = clampi(current_row, 0, ROW_COUNT - 1)
	if not is_finite(direction.x) or not is_finite(direction.y):
		return safe_row
	if direction.length_squared() < MIN_DIRECTION_LENGTH * MIN_DIRECTION_LENGTH:
		return safe_row
	var heading: Vector2 = direction.normalized()
	# The dot product against unit headings is the cosine of the angle between
	# them, so the largest one is the nearest row. Eight comparisons with no
	# trigonometry and no allocation, on a path that runs per enemy per frame.
	var best_row: int = safe_row
	var best_score: float = -2.0
	for row: int in range(ROW_COUNT):
		var score: float = heading.dot(ROW_HEADINGS[row])
		if score > best_score:
			best_score = score
			best_row = row
	# The baked sheet is half a turn from this table. Measured on
	# hero_heikki_walk.png: row 0 faces screen-right, row 4 faces screen-left,
	# row 6 faces the camera, row 2 shows the back.
	return (best_row + 4) % ROW_COUNT


## The animation name the frame builder wrote for one clip and one row.
static func animation_name(clip: StringName, row: int) -> StringName:
	return StringName("%s_%d" % [clip, clampi(row, 0, ROW_COUNT - 1)])


## Whether a SpriteFrames carries the eight-row form of `clip`. Presentations use
## this to tell a directional sheet from a legacy single-heading scene rather
## than being told which kind they were handed.
static func has_directional_clip(frames: SpriteFrames, clip: StringName) -> bool:
	if frames == null:
		return false
	for row: int in range(ROW_COUNT):
		if not frames.has_animation(animation_name(clip, row)):
			return false
	return true
