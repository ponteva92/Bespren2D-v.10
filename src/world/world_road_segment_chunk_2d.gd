class_name WorldRoadSegmentChunk2D
extends Node2D
## One spatially bounded road draw item. Long authored segments are split by the
## network so the mobile renderer never has to retain a world-sized CanvasItem.

const ASPHALT_OUTER_COLOR: Color = Color("1d2523")
const ASPHALT_INNER_COLOR: Color = Color("363d3b")
const ASPHALT_EDGE_COLOR: Color = Color(0.48, 0.52, 0.48, 0.26)
const ASPHALT_CRACK_COLOR: Color = Color(0.055, 0.075, 0.070, 0.72)
const ASPHALT_WHEEL_PATH_COLOR: Color = Color(0.300, 0.335, 0.325, 0.30)
const ASPHALT_AGGREGATE_LIGHT_COLOR: Color = Color(0.315, 0.345, 0.335, 0.34)
const ASPHALT_AGGREGATE_DARK_COLOR: Color = Color(0.125, 0.150, 0.145, 0.34)
const ASPHALT_PATCH_COLOR: Color = Color(0.150, 0.170, 0.164, 0.62)
## The dirt family is the asphalt family's warm counterpart, scaled to sit where
## a worn path belongs in the value hierarchy rather than where it was authored.
## `65533f` measured luma 86.0 against a forest floor of 50.7 - 1.7 times the
## ground - and in `world_forest_rock_validation.png` the path was the brightest
## large mass in the frame, pulling harder than the rock it ran past. A landmark
## the player navigates by has to out-read the background it sits on, and
## CLAUDE.md 8 reserves the dominant warm mass for the Base Core. Every dirt
## constant below is the authored colour times 0.77, which puts the bed at luma
## 65.9: still thirty percent brighter than the forest floor, so it reads as a
## cleared track, but no longer the loudest thing in the wilderness.
const DIRT_OUTER_COLOR: Color = Color("302820")
const DIRT_INNER_COLOR: Color = Color("4e4031")
const DIRT_GRAIN_COLOR: Color = Color(0.416, 0.354, 0.270, 0.22)
const DIRT_AGGREGATE_LIGHT_COLOR: Color = Color(0.431, 0.375, 0.297, 0.30)
const DIRT_AGGREGATE_DARK_COLOR: Color = Color(0.187, 0.153, 0.116, 0.30)
const DIRT_PUDDLE_COLOR: Color = Color(0.151, 0.139, 0.114, 0.50)
const SHOULDER_GRIT_COLOR: Color = Color(0.430, 0.386, 0.300, 0.30)
## One value between each family's shoulder and its bed, carried at an alpha high
## enough to dominate whichever of the two it lands on. Dirt spans luma 41.1 to
## 65.9 and this composites to 50.3 and 55.7 across that step; asphalt spans 35.2
## to 59.4 and this composites to 44.6 and 49.9.
const DIRT_VERGE_BREAK_COLOR: Color = Color(0.245, 0.201, 0.154, 0.78)
const ASPHALT_VERGE_BREAK_COLOR: Color = Color(0.169, 0.190, 0.184, 0.78)
const DASH_COLOR: Color = Color(0.69, 0.65, 0.48, 0.48)
const RUT_COLOR: Color = Color(0.131, 0.108, 0.081, 0.52)

## Surface-detail cadence, in world units along and across the carriageway. The
## road bed used to be a single `draw_polyline` in one flat colour, and measured
## off the capture set that made it the largest dead area in the game: row y=105
## of `world_mall_validation.png` was 480 identical pixels, and `363d3b` alone
## covered 20 to 27 percent of five city frames while `65533f` covered 19 percent
## of `world_forest_rock_validation.png`. Those captures sit at zoom 0.176, so at
## the 0.38 gameplay zoom the 420-unit bed is 160 of the screen's 270 rows and a
## player standing on a road saw well over half the frame under three flat fills.
## The spacings below are chosen against that zoom rather than against the
## capture: 52 units is about 20 screen pixels, so the aggregate lands inside the
## 7-pixel window the local-contrast metric samples with, and the marks stay in
## the 2-to-100-cycles-per-frame band that survives to the display at all.
## Rut geometry. The two dark tracks used to be a pair of `draw_line` calls at a
## fixed offset in one colour, which drew them as two dead-straight full-length
## lines of constant depth - measured off the forest-density capture they were
## the most geometric thing in the frame, more so than the road boundary the
## verge pass had just been rewritten for. A wheel track wanders, deepens where
## the ground is soft and fades where it is hard, so it is now sampled along the
## road and given a smooth lateral wander and a smooth depth. The wander period
## is long against the sample spacing so the track curves rather than zigzags,
## and the depth period is shorter so it breaks more often than it turns.
const RUT_OFFSET: float = 88.0
const RUT_WIDTH: float = 24.0
const RUT_CREST_OFFSET: float = 49.3
const RUT_CREST_WIDTH: float = 7.0
const RUT_SAMPLE_SPACING: float = 96.0
const RUT_WANDER_PERIOD: float = 620.0
const RUT_WANDER_AMPLITUDE: float = 27.0
const RUT_DEPTH_PERIOD: float = 340.0
## How far a wear patch outline may leave the quadrilateral it is built from.
## The quad is the point - CLAUDE.md 2 asks decay to tell history and a patch is
## the only mark in this file that implies a hand - but drawn with four vertices
## it has four exactly straight edges, two of them square to the road, and on the
## capture it reads as a rectangle laid on the surface rather than as a repair
## poured into it. Dirt takes the larger share because a puddle has no hand
## behind it at all.
## The road bed and its shoulder used to be two `draw_polyline` calls, which is
## the reason nine perfectly parallel lines showed up in the asphalt capture: two
## shoulder rails, two painted edges, four wheel bands and the dash row, every one
## of them at a constant offset for the whole length of the frame. A polyline is
## the wrong primitive for a surface that has been eroding for a decade. Both
## bands are polygons now, sampled every `BAND_SAMPLE_SPACING` units, with each
## side of each band carrying its own smooth noise so the four boundaries never
## move together. The outer edge is given the larger amplitude and the longer
## period because it is the one that meets untended ground; the inner edge is the
## drier crown of a maintained surface and wanders less.
## The wheel bands and the painted edges drift with the carriageway rather than
## with the noise the band edges use, so a lane never crosses the line beside it.
## The paint is given the inner band own period for its lateral wander, because a
## line painted along a road follows that road edge; only its wear is its own.
const WHEEL_PATH_WANDER: float = 34.0
const WHEEL_PATH_WANDER_PERIOD: float = 880.0
const WHEEL_PATH_DEPTH_PERIOD: float = 520.0
const EDGE_PAINT_WANDER: float = 14.0
const EDGE_PAINT_WEAR_PERIOD: float = 250.0
## How much of an authored dash actually survives. A dash row that is identical in
## length, value and spacing for the whole route is a metronome, and it was the
## loudest thing left on the asphalt frame once the rails stopped being rails.
const DASH_SKIP_SHARE: float = 0.14
const DASH_LENGTH_LOSS: float = 0.34
const DASH_LATERAL_JITTER: float = 9.0
const BAND_SAMPLE_SPACING: float = 112.0
const OUTER_EDGE_WANDER: float = 30.0
const INNER_EDGE_WANDER: float = 18.0
const OUTER_EDGE_PERIOD: float = 760.0
const INNER_EDGE_PERIOD: float = 430.0
const OUTER_EDGE_KEY: int = 61
const INNER_EDGE_KEY: int = 89
const DIRT_PATCH_RAGGEDNESS: float = 0.34
const ASPHALT_PATCH_RAGGEDNESS: float = 0.17
const PATCH_EDGE_SAMPLES: int = 4
const AGGREGATE_SPACING: float = 52.0
const AGGREGATE_COLUMNS: int = 8
const AGGREGATE_WIDTH: float = 7.5
const PATCH_SPACING: float = 1180.0
const LONGITUDINAL_CRACK_SPACING: float = 940.0
const SHOULDER_GRIT_SPACING: float = 36.0
## How the grit is split between breaking the two boundaries and dressing the
## shoulder. The bed edge takes the larger share because it is the only one with
## nothing else working on it: measured on the forest-density capture, the two
## road-to-forest edges are already interrupted on a sixth of their rows by the
## scatter standing on them, while the shoulder-to-bed edge held its full
## authored 23.9-luma step on 96.3 percent of rows with an even split.
const VERGE_BREAK_INNER_SHARE: float = 0.44
const VERGE_BREAK_OUTER_SHARE: float = 0.28
const SHOULDER_GRIT_WIDTH: float = 6.0
## A break mark is a different object from a speck of dust and is drawn in its
## own batch. It is wider, because what has to cover the boundary is the stroke's
## width rather than its length, and it is steered to within a third of a radian
## of the road so that its length is spent running along the edge it is eating
## into. A round of uniformly angled six-unit strokes covered 15 percent of the
## bed edge; these cover roughly half of it for the same number of marks.
const VERGE_BREAK_WIDTH: float = 13.0
const VERGE_BREAK_ANGLE_SPREAD: float = 1.2
## How far past the carriageway edge a verge mark may reach. A mark that stops
## short of the boundary cannot break it, so this is the budget that has to exist
## in the culling rectangle before the clamp in `_draw_shoulder_grit` is worth
## anything. It also has to cover the outer band own wander, which reaches half
## of `OUTER_EDGE_WANDER` past the nominal edge on its own: the marks now target
## the boundary where it actually is rather than where the width says it is, so a
## budget sized for the nominal edge would have spent itself on the wander and
## left the clamp pulling every mark back off the boundary it was aimed at.
const VERGE_BREAK_REACH: float = 40.0
## Padding along the road axis. Every pass but the aggregate and the verge grit
## clamps its own placement inside the chunk, and those two overshoot the end by
## at most `AGGREGATE_SPACING * 0.5 + AGGREGATE_WIDTH * 0.5`, which is 30, and by
## half a grit spacing plus a break mark's own half length plus half its width,
## which is 18 + 30 + 6.5. Steering the break strokes along the road is what put
## that second figure up: a mark that runs across the edge spends its length on
## the padding across the road instead, so the budget had to move with it.
const ALONG_PADDING: float = 60.0

## The grain material. One `ShaderMaterial` per road type is shared by every
## chunk of that type, so adding surface detail costs two material switches for
## the whole road graph rather than one per chunk, and the renderer can still
## batch the chunks behind each. The cell means are measured off the shipped
## atlas - asphalt (45.84, 46.24, 46.90) and mud (51.36, 33.06, 26.13) in 0-255,
## with per-cell luma sigmas of 7.30 and 8.35 - so the shader subtracts the exact
## mean of the tile it samples and leaves only the deviation.
const DETAIL_SHADER_PATH: String = "res://shaders/road_surface_detail.gdshader"
const TERRAIN_ATLAS_PATH: String = (
	"res://assets/2d/environment/terrain/polyhaven_terrain_atlas.png"
)
const ASPHALT_ATLAS_CELL: Vector2 = Vector2(0.0, 0.0)
const DIRT_ATLAS_CELL: Vector2 = Vector2(1.0, 0.0)
const ASPHALT_CELL_MEAN: Vector3 = Vector3(0.1797, 0.1813, 0.1839)
const DIRT_CELL_MEAN: Vector3 = Vector3(0.2014, 0.1297, 0.1025)
## The terrain repeats its atlas 28 times across 28,672 world units, so one tile
## is 1,024 units wide. Matching it keeps a grain fleck the same physical size on
## the road as on the ground beside it.
const DETAIL_WORLD_PERIOD: float = 1024.0
## The terrain grades its samples by exposure 1.24 and contrast 1.04, which lifts
## its 7.30 sigma to about 9.4 luma on screen. 1.25 puts the road within a few
## percent of that, biased a hair low so the carriageway never out-textures the
## ground it sits in.
const DETAIL_STRENGTH: float = 1.25

static var _asphalt_detail_material: ShaderMaterial = null
static var _dirt_detail_material: ShaderMaterial = null

var _start: Vector2 = Vector2.ZERO
var _finish: Vector2 = Vector2.ZERO
var _is_dirt: bool = false
var _outer_width: float = 0.0
var _inner_width: float = 0.0
var _dash_length: float = 0.0
var _dash_gap: float = 0.0
var _authored_segment_distance: float = 0.0
var _world_render_bounds: Rect2 = Rect2()


func configure(
	world_start: Vector2,
	world_finish: Vector2,
	is_dirt: bool,
	outer_width: float,
	inner_width: float,
	dash_length: float,
	dash_gap: float,
	authored_segment_distance: float
) -> void:
	position = (world_start + world_finish) * 0.5
	_start = world_start - position
	_finish = world_finish - position
	_is_dirt = is_dirt
	_outer_width = outer_width
	_inner_width = inner_width
	_dash_length = dash_length
	_dash_gap = dash_gap
	_authored_segment_distance = authored_segment_distance
	z_index = -20
	z_as_relative = false
	material = _get_detail_material(is_dirt)

	## The culling rectangle is built along the road's own axes rather than from a
	## single padding applied to both. A road needs half its outer width plus the
	## verge reach *across* the carriageway and only a stroke's worth *along* it,
	## and collapsing those two into one number charged the across-figure to the
	## long axis: a 4096-unit asphalt chunk carried 272 units of padding at each
	## end for marks that are never drawn there, giving a span of exactly 4640
	## against a `MAX_ROAD_CHUNK_SPAN` of 4640. Sitting on the limit is what made
	## the verge reach unaffordable, and the reach is the whole point of the pass.
	##
	## With the perpendicular being the direction rotated a quarter turn,
	## `absf(perpendicular.x)` is `absf(direction.y)`, so the axis-aligned half
	## extent is the two authored paddings mixed by the road's own heading. This is
	## tighter than the old rectangle for every direction, not just the axis-aligned
	## ones - the same asphalt chunk now spans 4192 by 576.
	var across_padding: float = outer_width * 0.5 + VERGE_BREAK_REACH
	var span: Vector2 = world_finish - world_start
	var run: float = span.length()
	var center: Vector2 = (world_start + world_finish) * 0.5
	var half_extent: Vector2 = Vector2(across_padding, across_padding)
	if run > 0.0:
		var heading: Vector2 = (span / run).abs()
		var half_run: float = run * 0.5 + ALONG_PADDING
		half_extent = Vector2(
			heading.x * half_run + heading.y * across_padding,
			heading.y * half_run + heading.x * across_padding
		)
	_world_render_bounds = Rect2(center - half_extent, half_extent * 2.0)
	queue_redraw()


func get_world_render_bounds() -> Rect2:
	return _world_render_bounds


func _draw() -> void:
	## Surface detail is layered under the markings that carry the road's meaning:
	## wear first, then the authored edge lines and dashes, so enriching the bed
	## never competes with the cues that say "this is a road". That ordering also
	## matters because the bed and the city terrain are nearly the same value -
	## `363d3b` measures luma 59.4 and the city biome blend predicts 61.8 - so the
	## carriageway has always been read from its dark shoulder and its dashes
	## rather than from its fill, and it still is.
	if _is_dirt:
		_draw_wandering_band(_outer_width * 0.5, DIRT_OUTER_COLOR, true)
		_draw_wandering_band(_inner_width * 0.5, DIRT_INNER_COLOR, false)
		_draw_wear_patches(true)
		_draw_surface_aggregate(true)
		_draw_dirt_ruts()
		_draw_shoulder_grit(true)
		_draw_surface_breaks(true)
		return
	_draw_wandering_band(_outer_width * 0.5, ASPHALT_OUTER_COLOR, true)
	_draw_wandering_band(_inner_width * 0.5, ASPHALT_INNER_COLOR, false)
	_draw_wheel_paths()
	_draw_wear_patches(false)
	_draw_surface_aggregate(false)
	_draw_longitudinal_cracks()
	_draw_shoulder_grit(false)
	_draw_asphalt_edges()
	_draw_asphalt_dashes()
	_draw_surface_breaks(false)


func _draw_asphalt_edges() -> void:
	## Painted edge lines, and the only marks here that were ever meant to be
	## straight - which is exactly why they read as the most artificial thing on
	## the carriageway. On the shoulder capture each one composited to luma 77.7
	## against a 59-luma bed and held that value for the full 480 pixels: a bright
	## pinstripe with no chip, no fade and no gap on a road nobody has maintained
	## since the collapse. They keep their straight intent and lose their
	## permanence. The alpha floor is negative on purpose: `clampf` turns the
	## bottom of the noise into genuinely bare asphalt rather than faint paint, so
	## roughly a quarter of each line is simply gone.
	var edge_offset: float = maxf(_inner_width * 0.5 - 22.0, 0.0)
	for side: int in [-1, 1]:
		_draw_wandering_stripe(
			float(side) * edge_offset,
			7.0,
			ASPHALT_EDGE_COLOR,
			EDGE_PAINT_WANDER,
			EDGE_PAINT_WEAR_PERIOD,
			307 + side * 11,
			INNER_EDGE_PERIOD,
			-0.55,
			1.60
		)


func _draw_asphalt_dashes() -> void:
	var displacement: Vector2 = _finish - _start
	var length: float = displacement.length()
	if length <= 0.0:
		return
	var direction: Vector2 = displacement / length
	var cycle: float = _dash_length + _dash_gap
	var first_authored_dash: float = _dash_gap * 0.35
	var chunk_start_distance: float = _authored_segment_distance
	var dash_index: int = floori((chunk_start_distance - first_authored_dash) / cycle)
	var dash_start_distance: float = first_authored_dash + float(dash_index) * cycle
	while dash_start_distance + _dash_length <= chunk_start_distance:
		dash_start_distance += cycle

	var chunk_finish_distance: float = chunk_start_distance + length
	while dash_start_distance < chunk_finish_distance:
		var index: int = roundi((dash_start_distance - first_authored_dash) / cycle)
		var skip_seed: float = _stable_scalar(index, 331)
		var head_seed: float = _stable_scalar(index, 347)
		var tail_seed: float = _stable_scalar(index, 359)
		var lateral_seed: float = _stable_scalar(index, 373)
		var eaten: float = _dash_length * DASH_LENGTH_LOSS * 0.5
		var clipped_start: float = maxf(
			dash_start_distance + head_seed * eaten, chunk_start_distance
		) - chunk_start_distance
		var clipped_finish: float = minf(
			dash_start_distance + _dash_length - tail_seed * eaten,
			chunk_finish_distance
		) - chunk_start_distance
		if skip_seed < DASH_SKIP_SHARE:
			clipped_finish = clipped_start
		if clipped_finish > clipped_start:
			var lateral: Vector2 = (
				direction.orthogonal() * (lateral_seed - 0.5) * DASH_LATERAL_JITTER
			)
			draw_line(
				_start + direction * clipped_start + lateral,
				_start + direction * clipped_finish + lateral,
				Color(
					DASH_COLOR.r, DASH_COLOR.g, DASH_COLOR.b,
					DASH_COLOR.a * lerpf(0.45, 1.0, skip_seed)
				),
				18.0,
				false
			)
		dash_start_distance += cycle


func _draw_dirt_ruts() -> void:
	## Two tracks, plus the crest of drier ground between each track and the
	## centre. All four are sampled rather than drawn as single lines, because the
	## thing that gave this road away on the capture was not its boundary but
	## these: a straight line of constant width and constant value running the
	## whole visible height of the frame is a drawn shape that no amount of grain
	## on either side of it can rescue.
	for side: int in [-1, 1]:
		_draw_wandering_stripe(
			float(side) * RUT_OFFSET, RUT_WIDTH, RUT_COLOR,
			RUT_WANDER_AMPLITUDE, RUT_DEPTH_PERIOD, 17 + side * 5
		)
		_draw_wandering_stripe(
			float(side) * RUT_CREST_OFFSET, RUT_CREST_WIDTH, DIRT_GRAIN_COLOR,
			RUT_WANDER_AMPLITUDE * 0.55, RUT_DEPTH_PERIOD * 1.7, 43 + side * 5
		)


func _draw_wandering_stripe(
	offset: float,
	width: float,
	tint: Color,
	wander: float,
	depth_period: float,
	key: int,
	wander_period: float = RUT_WANDER_PERIOD,
	alpha_low: float = 0.16,
	alpha_high: float = 1.34
) -> void:
	## One track: a chain of short segments whose lateral offset follows a smooth
	## noise and whose alpha follows another. The noise is keyed off the authored
	## distance along the whole route rather than off this chunk, so a track does
	## not kink where one chunk hands over to the next, and it deliberately does
	## not go through `_stable_pair`, whose hash mixes in the chunk own position
	## and would therefore restart the pattern at every boundary.
	var displacement: Vector2 = _finish - _start
	var length: float = displacement.length()
	if length <= 0.0:
		return
	var direction: Vector2 = displacement / length
	var perpendicular: Vector2 = direction.orthogonal()
	var steps: int = maxi(1, ceili(length / RUT_SAMPLE_SPACING))
	var points: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var previous: Vector2 = Vector2.ZERO
	for step: int in range(steps + 1):
		var along: float = length * float(step) / float(steps)
		var distance: float = _authored_segment_distance + along
		var lateral: float = offset + (
			_smooth_noise(distance, wander_period, key) - 0.5
		) * wander
		var point: Vector2 = _start + direction * along + perpendicular * lateral
		if step > 0:
			var depth: float = _smooth_noise(
				distance - RUT_SAMPLE_SPACING * 0.5, depth_period, key + 1
			)
			points.push_back(previous)
			points.push_back(point)
			colors.push_back(Color(
				tint.r, tint.g, tint.b,
				tint.a * clampf(lerpf(alpha_low, alpha_high, depth), 0.0, 1.0)
			))
		previous = point
	if not points.is_empty():
		draw_multiline_colors(points, colors, width, false)


func _edge_offset(base: float, side: int, distance: float, is_outer: bool) -> float:
	## Where one side of one band actually sits at this point along the route.
	## `_draw_shoulder_grit` calls this too, so a break mark still straddles the
	## boundary it is meant to be eating into rather than the nominal one.
	var wander: float = OUTER_EDGE_WANDER if is_outer else INNER_EDGE_WANDER
	var period: float = OUTER_EDGE_PERIOD if is_outer else INNER_EDGE_PERIOD
	var key: int = (OUTER_EDGE_KEY if is_outer else INNER_EDGE_KEY) + side * 7
	return base + (_smooth_noise(distance, period, key) - 0.5) * wander


func _draw_wandering_band(half_width: float, tint: Color, is_outer: bool) -> void:
	var displacement: Vector2 = _finish - _start
	var length: float = displacement.length()
	if length <= 0.0:
		return
	var direction: Vector2 = displacement / length
	var perpendicular: Vector2 = direction.orthogonal()
	var steps: int = maxi(1, ceili(length / BAND_SAMPLE_SPACING))
	var outline: PackedVector2Array = PackedVector2Array()
	var back: PackedVector2Array = PackedVector2Array()
	for step: int in range(steps + 1):
		var along: float = length * float(step) / float(steps)
		var distance: float = _authored_segment_distance + along
		var spine: Vector2 = _start + direction * along
		outline.push_back(
			spine + perpendicular * _edge_offset(half_width, 1, distance, is_outer)
		)
		back.push_back(
			spine - perpendicular * _edge_offset(half_width, -1, distance, is_outer)
		)
	back.reverse()
	outline.append_array(back)
	draw_colored_polygon(outline, tint)


func _smooth_noise(distance: float, period: float, key: int) -> float:
	## Value noise with cubic interpolation between integer nodes, in [0, 1].
	var node: float = distance / period
	var index: int = floori(node)
	return lerpf(
		_stable_scalar(index, key),
		_stable_scalar(index + 1, key),
		smoothstep(0.0, 1.0, node - float(index))
	)


func _stable_scalar(node: int, key: int) -> float:
	var value: float = sin(float(node) * 12.9898 + float(key) * 78.233) * 43758.5453
	return value - floorf(value)


func _draw_surface_breaks(is_dirt: bool) -> void:
	var displacement: Vector2 = _finish - _start
	var length: float = displacement.length()
	if length <= 0.0:
		return
	var direction: Vector2 = displacement / length
	var perpendicular: Vector2 = direction.orthogonal()
	var spacing: float = 760.0 if is_dirt else 690.0
	var chunk_start: float = _authored_segment_distance
	var mark_index: int = floori(chunk_start / spacing)
	var mark_distance: float = (float(mark_index) + 0.58) * spacing
	while mark_distance < chunk_start:
		mark_index += 1
		mark_distance = (float(mark_index) + 0.58) * spacing
	var chunk_finish: float = chunk_start + length
	while mark_distance < chunk_finish:
		var local_distance: float = mark_distance - chunk_start
		var variation: float = _stable_unit(mark_index * 13 + 5)
		var lateral: float = lerpf(-0.24, 0.24, _stable_unit(mark_index * 17 + 9))
		var center: Vector2 = (
			_start
			+ direction * local_distance
			+ perpendicular * lateral * _inner_width
		)
		var half_span: float = lerpf(26.0, 74.0, variation)
		var surface_color: Color = RUT_COLOR if is_dirt else ASPHALT_CRACK_COLOR
		draw_line(
			center - perpendicular * half_span,
			center + perpendicular * half_span,
			surface_color,
			7.0 if is_dirt else 5.0,
			false
		)
		var branch_direction: Vector2 = (perpendicular + direction * 0.52).normalized()
		draw_line(
			center,
			center + branch_direction * half_span * 0.66,
			surface_color,
			5.0 if is_dirt else 3.5,
			false
		)
		mark_index += 1
		mark_distance = (float(mark_index) + 0.58) * spacing


static func _get_detail_material(is_dirt: bool) -> ShaderMaterial:
	if is_dirt and _dirt_detail_material != null:
		return _dirt_detail_material
	if not is_dirt and _asphalt_detail_material != null:
		return _asphalt_detail_material
	var shader: Shader = load(DETAIL_SHADER_PATH) as Shader
	var atlas: Texture2D = load(TERRAIN_ATLAS_PATH) as Texture2D
	if shader == null or atlas == null:
		return null
	var built: ShaderMaterial = ShaderMaterial.new()
	built.shader = shader
	built.set_shader_parameter("detail_atlas", atlas)
	built.set_shader_parameter("world_period", DETAIL_WORLD_PERIOD)
	built.set_shader_parameter("detail_strength", DETAIL_STRENGTH)
	if is_dirt:
		built.set_shader_parameter("atlas_cell", DIRT_ATLAS_CELL)
		built.set_shader_parameter("cell_mean", DIRT_CELL_MEAN)
		_dirt_detail_material = built
	else:
		built.set_shader_parameter("atlas_cell", ASPHALT_ATLAS_CELL)
		built.set_shader_parameter("cell_mean", ASPHALT_CELL_MEAN)
		_asphalt_detail_material = built
	return built


func _stable_unit(index: int) -> float:
	var value: float = sin(float(index) * 12.9898 + position.x * 0.0017 + position.y * 0.0023)
	return value - floorf(value)


func _draw_wheel_paths() -> void:
	## Two lanes, two tyre tracks each, polished slightly brighter than the bed.
	## These do the work a flat fill cannot: they are the only detail in this pass
	## that is oriented, so they carry the carriageway direction even where the
	## dashes fall in a gap, and they break the 420-unit bed into bands before any
	## stochastic mark is laid over it.
	## Polished by tyres rather than painted, so they are sampled chains like the
	## dirt ruts: four straight constant-value bands were four more of the nine
	## parallel lines the asphalt capture was made of, and a tyre track that never
	## drifts is the one thing a tyre track never does.
	var lane_center: float = _inner_width * 0.25
	var track_offset: float = _inner_width * 0.105
	var wheel_width: float = _inner_width * 0.13
	for lane: int in [-1, 1]:
		for track: int in [-1, 1]:
			var lateral: float = float(lane) * lane_center + float(track) * track_offset
			_draw_wandering_stripe(
				lateral,
				wheel_width,
				ASPHALT_WHEEL_PATH_COLOR,
				WHEEL_PATH_WANDER,
				WHEEL_PATH_DEPTH_PERIOD,
				211 + lane * 13 + track * 5,
				WHEEL_PATH_WANDER_PERIOD,
				0.24,
				1.30
			)


func _draw_surface_aggregate(is_dirt: bool) -> void:
	## The pass that actually kills the dead area. Every mark is accumulated into
	## one of two arrays and issued as a single `draw_multiline`, so a 4096-unit
	## chunk carries some six hundred marks for exactly two draw commands where a
	## `draw_line` per mark would have cost six hundred. Marks are indexed by
	## distance along the authored segment rather than by position inside the
	## chunk, so the pattern runs continuously across a chunk seam instead of
	## restarting every 4096 units - the same reason `_draw_asphalt_dashes`
	## already indexes off `_authored_segment_distance`.
	var displacement: Vector2 = _finish - _start
	var length: float = displacement.length()
	if length <= 0.0:
		return
	var direction: Vector2 = displacement / length
	var perpendicular: Vector2 = direction.orthogonal()
	var lateral_span: float = maxf(_inner_width * 0.5 - AGGREGATE_WIDTH, 0.0)
	var chunk_start: float = _authored_segment_distance
	var chunk_finish: float = chunk_start + length
	var row_index: int = floori(chunk_start / AGGREGATE_SPACING)
	var light_marks: PackedVector2Array = PackedVector2Array()
	var dark_marks: PackedVector2Array = PackedVector2Array()
	while float(row_index) * AGGREGATE_SPACING < chunk_finish:
		var row_distance: float = float(row_index) * AGGREGATE_SPACING
		if row_distance >= chunk_start:
			for column: int in range(AGGREGATE_COLUMNS):
				var lane_seed: float = _stable_pair(row_index, column * 7 + 3)
				var along_seed: float = _stable_pair(row_index, column * 7 + 11)
				var angle_seed: float = _stable_pair(row_index, column * 7 + 19)
				var size_seed: float = _stable_pair(row_index, column * 7 + 29)
				var lateral_unit: float = (
					(float(column) + 0.5) / float(AGGREGATE_COLUMNS) * 2.0 - 1.0
				)
				var lateral: float = clampf(
					lateral_unit * lateral_span + (lane_seed - 0.5) * AGGREGATE_SPACING * 0.9,
					-lateral_span,
					lateral_span
				)
				var along: float = (
					row_distance - chunk_start + (along_seed - 0.5) * AGGREGATE_SPACING
				)
				var center: Vector2 = _start + direction * along + perpendicular * lateral
				var stroke: Vector2 = (
					Vector2.from_angle(angle_seed * TAU) * lerpf(7.0, 17.0, size_seed)
				)
				if size_seed < 0.5:
					light_marks.push_back(center - stroke)
					light_marks.push_back(center + stroke)
				else:
					dark_marks.push_back(center - stroke)
					dark_marks.push_back(center + stroke)
		row_index += 1
	var light_color: Color = (
		DIRT_AGGREGATE_LIGHT_COLOR if is_dirt else ASPHALT_AGGREGATE_LIGHT_COLOR
	)
	var dark_color: Color = (
		DIRT_AGGREGATE_DARK_COLOR if is_dirt else ASPHALT_AGGREGATE_DARK_COLOR
	)
	if not light_marks.is_empty():
		draw_multiline(light_marks, light_color, AGGREGATE_WIDTH, false)
	if not dark_marks.is_empty():
		draw_multiline(dark_marks, dark_color, AGGREGATE_WIDTH, false)


func _draw_wear_patches(is_dirt: bool) -> void:
	## Tar repairs on asphalt, standing water on dirt. Deliberately quadrilateral
	## and deliberately asymmetric across the road so they read as something that
	## was done to the surface rather than as a decorative blob - CLAUDE.md 2 asks
	## decay to tell history, and a patch is the only mark in this file that
	## implies a hand. The along-road placement is clamped inside the chunk
	## because `_world_render_bounds` is the culling rectangle the world-map gate
	## checks, and a patch reaching past it would pop at the chunk edge.
	##
	## The quadrilateral is the skeleton rather than the outline. Drawn with its
	## four vertices it has four exactly straight edges and, on a road running
	## north to south, two of them are exactly vertical and two exactly horizontal
	## - which is how a repair ends up reading as a rectangle pasted onto the
	## surface, and it is what the forest-density capture showed. `_ragged_outline`
	## walks the same quad and pushes intermediate points off it, so the patch
	## keeps its authored proportions and loses its authored edges.
	var displacement: Vector2 = _finish - _start
	var length: float = displacement.length()
	if length <= 0.0:
		return
	var direction: Vector2 = displacement / length
	var perpendicular: Vector2 = direction.orthogonal()
	var fill: Color = DIRT_PUDDLE_COLOR if is_dirt else ASPHALT_PATCH_COLOR
	var chunk_start: float = _authored_segment_distance
	var chunk_finish: float = chunk_start + length
	var patch_index: int = floori(chunk_start / PATCH_SPACING)
	while float(patch_index) * PATCH_SPACING < chunk_finish:
		var patch_distance: float = float(patch_index) * PATCH_SPACING
		if patch_distance >= chunk_start:
			var length_seed: float = _stable_pair(patch_index, 41)
			var width_seed: float = _stable_pair(patch_index, 67)
			var lateral_seed: float = _stable_pair(patch_index, 89)
			var along_seed: float = _stable_pair(patch_index, 113)
			var half_length: float = lerpf(70.0, 190.0, length_seed)
			var half_width: float = lerpf(46.0, 128.0, width_seed)
			var lateral: float = (
				(lateral_seed - 0.5) * maxf(_inner_width - half_width * 2.0, 0.0)
			)
			var along: float = clampf(
				patch_distance - chunk_start + (along_seed - 0.5) * PATCH_SPACING * 0.5,
				half_length,
				maxf(half_length, length - half_length)
			)
			var center: Vector2 = _start + direction * along + perpendicular * lateral
			var corners: PackedVector2Array = PackedVector2Array([
				-direction * half_length - perpendicular * half_width,
				direction * half_length - perpendicular * half_width * 0.78,
				direction * half_length + perpendicular * half_width,
				-direction * half_length + perpendicular * half_width * 0.86,
			])
			var raggedness: float = (
				DIRT_PATCH_RAGGEDNESS if is_dirt else ASPHALT_PATCH_RAGGEDNESS
			)
			draw_colored_polygon(
				_ragged_outline(
					center,
					corners,
					minf(half_length, half_width) * raggedness,
					patch_index
				),
				fill
			)
		patch_index += 1


func _draw_longitudinal_cracks() -> void:
	## `_draw_surface_breaks` already fractures the road across its width; nothing
	## ran along it. Asphalt fails both ways, and a crack that follows the traffic
	## direction is what reads as fatigue rather than as frost heave.
	var displacement: Vector2 = _finish - _start
	var length: float = displacement.length()
	if length <= 0.0:
		return
	var direction: Vector2 = displacement / length
	var perpendicular: Vector2 = direction.orthogonal()
	var chunk_start: float = _authored_segment_distance
	var chunk_finish: float = chunk_start + length
	var crack_index: int = floori(chunk_start / LONGITUDINAL_CRACK_SPACING)
	var strokes: PackedVector2Array = PackedVector2Array()
	while float(crack_index) * LONGITUDINAL_CRACK_SPACING < chunk_finish:
		var crack_distance: float = float(crack_index) * LONGITUDINAL_CRACK_SPACING
		if crack_distance >= chunk_start:
			var lateral: float = (
				(_stable_pair(crack_index, 23) - 0.5) * _inner_width * 0.82
			)
			var run: float = lerpf(220.0, 560.0, _stable_pair(crack_index, 47))
			var along: float = clampf(
				crack_distance - chunk_start, 0.0, maxf(0.0, length - run)
			)
			var previous: Vector2 = _start + direction * along + perpendicular * lateral
			for step: int in range(1, 5):
				var wander: float = (_stable_pair(crack_index, 59 + step) - 0.5) * 46.0
				var next_point: Vector2 = (
					_start
					+ direction * (along + run * float(step) * 0.25)
					+ perpendicular * (lateral + wander)
				)
				strokes.push_back(previous)
				strokes.push_back(next_point)
				previous = next_point
		crack_index += 1
	if not strokes.is_empty():
		draw_multiline(strokes, ASPHALT_CRACK_COLOR, 4.0, false)


func _draw_shoulder_grit(is_dirt: bool) -> void:
	## Dust drifted onto the carriageway from the verge, and the marks that break
	## the carriageway's own edge. Both boundaries come from `draw_polyline` and are
	## therefore exact straight lines, and in a world whose art direction is
	## granular decay a perfectly clean boundary was the tell that the road was a
	## drawn shape rather than a surface.
	##
	## Softening them was already the intent here, and measured off
	## `world_forest_density_validation.png` it was doing 0.4 percent of the job:
	## the dirt outer-to-inner boundary still stepped by more than six luma on 269
	## of 270 rows, and the column of maximum gradient held a standard deviation of
	## 0.468 pixels over the whole frame height - a ruler. Two causes compound.
	##
	## Placement: `lateral` ranged over world 159 to 216 while the outer boundary
	## sits at 240, so that edge received no mark at all, and the marks that did
	## land sat beside the inner edge rather than across it. A mark that does not
	## cross a line cannot break it, so each mark now picks one of the two
	## boundaries and straddles it.
	##
	## Value: `SHOULDER_GRIT_COLOR` measures luma 99 and composites to 58.5 over the
	## shoulder and 75.9 over the bed - brighter than both sides of every step it was
	## asked to hide. A mark brighter than the two values it spans adds a third value
	## instead of blending them, which is why it read as sprinkles lying on a clean
	## line rather than as a worn edge. The verge colours sit between each family's
	## own two values, so a straddling mark lands near their midpoint from either
	## side and one 25-luma cliff becomes two 12-luma steps with a ragged seam
	## between them. The bright dust is kept for the marks that stay inside the
	## shoulder, where being the brightest thing present is what it is for.
	##
	## Reach: the first version of this rewrite still could not touch the outer
	## boundary, and for a reason worth stating rather than quietly fixing. It
	## clamped the mark centre to `outer_edge + 2 - half_stroke - width * 0.5`,
	## which puts the mark's outermost pixel one unit *inside* the edge it was
	## aimed at - the placement bug rewritten as an arithmetic one. That two came
	## from the culling rectangle, which had no room to give, so `configure` now
	## pads along and across the road separately and `VERGE_BREAK_REACH` is real
	## budget the clamp can spend.
	##
	## Coverage: straddling every boundary still left the bed edge holding its
	## full authored 23.9-luma step on 96.3 percent of rows, because a mark can be
	## in the right place and still be too small to matter. An even three-way role
	## split put one mark per 108 world units on the inner edge, each of them six
	## units wide - about one screen pixel at the shipped zoom - and two to five
	## long. Interrupting a line is a question of what fraction of its length is
	## covered, not of whether anything sits on it anywhere.
	##
	## So a break mark is now a different object from a speck of dust and is drawn
	## in its own batch with its own width. It is more than twice as wide, because
	## what has to reach across the boundary is the stroke's width; it is steered
	## to within a third of a radian of the road, so its length runs along the edge
	## it is eating into rather than sticking out into the bed; it is longer; and
	## the inner boundary takes the larger share of the roles, since the two
	## road-to-forest edges already have the scatter standing on them and this one
	## has nothing else working on it.
	##
	## Jitter is scaled to the stroke rather than to the shoulder. A break mark
	## offset by up to half the shoulder can miss its boundary entirely; offset by
	## no more than half its own width it always spans it, and the variety comes
	## from length, angle and along-road position instead. The clamp is computed
	## from the stroke's actual lateral extent rather than from its length, so a
	## mark lying along the edge is not dragged inward for reach it never asked
	## for, and where the clamp does bind it pulls the mark back onto the boundary
	## rather than off it.
	var displacement: Vector2 = _finish - _start
	var length: float = displacement.length()
	if length <= 0.0:
		return
	var direction: Vector2 = displacement / length
	var perpendicular: Vector2 = direction.orthogonal()
	var inner_edge: float = _inner_width * 0.5
	var outer_edge: float = _outer_width * 0.5
	var shoulder: float = maxf(_outer_width - _inner_width, 0.0) * 0.5
	var break_color: Color = (
		DIRT_VERGE_BREAK_COLOR if is_dirt else ASPHALT_VERGE_BREAK_COLOR
	)
	var chunk_start: float = _authored_segment_distance
	var chunk_finish: float = chunk_start + length
	var grit_index: int = floori(chunk_start / SHOULDER_GRIT_SPACING)
	var break_marks: PackedVector2Array = PackedVector2Array()
	var dust_marks: PackedVector2Array = PackedVector2Array()
	while float(grit_index) * SHOULDER_GRIT_SPACING < chunk_finish:
		var grit_distance: float = float(grit_index) * SHOULDER_GRIT_SPACING
		if grit_distance >= chunk_start:
			for side: int in [-1, 1]:
				var lateral_seed: float = _stable_pair(grit_index, 131 + side * 3)
				var along_seed: float = _stable_pair(grit_index, 151 + side * 3)
				var angle_seed: float = _stable_pair(grit_index, 173 + side * 3)
				var role_seed: float = _stable_pair(grit_index, 197 + side * 3)
				var size_seed: float = _stable_pair(grit_index, 211 + side * 3)
				var breaks_a_boundary: bool = (
					role_seed < VERGE_BREAK_INNER_SHARE + VERGE_BREAK_OUTER_SHARE
				)
				var along: float = (
					grit_distance - chunk_start
					+ (along_seed - 0.5) * SHOULDER_GRIT_SPACING
				)
				var stroke: Vector2 = Vector2.ZERO
				var magnitude: float = 0.0
				if breaks_a_boundary:
					var is_outer: bool = role_seed >= VERGE_BREAK_INNER_SHARE
					var boundary: float = _edge_offset(
						outer_edge if is_outer else inner_edge,
						side,
						grit_distance,
						is_outer
					)
					var half_stroke: float = lerpf(10.0, 30.0, size_seed)
					var tilt: float = (angle_seed - 0.5) * VERGE_BREAK_ANGLE_SPREAD
					stroke = direction.rotated(tilt) * half_stroke
					## How far the mark actually reaches across the road, which is
					## the stroke's own lateral component rather than its length.
					## Clamping against the length would drag a mark that runs along
					## the edge inward for reach it never asked for.
					var spread: float = (
						absf(half_stroke * sin(tilt)) + VERGE_BREAK_WIDTH * 0.5
					)
					## The offset never exceeds the spread, so the mark covers the
					## boundary from both sides whether or not the clamp binds.
					magnitude = minf(
						boundary + (lateral_seed - 0.5) * VERGE_BREAK_WIDTH,
						outer_edge + VERGE_BREAK_REACH - 2.0 - spread
					)
				else:
					var half_stroke: float = lerpf(6.0, 15.0, size_seed)
					stroke = Vector2.from_angle(angle_seed * TAU) * half_stroke
					magnitude = minf(
						inner_edge - shoulder * 0.35 + lateral_seed * shoulder * 0.95,
						outer_edge + VERGE_BREAK_REACH - 2.0
						- half_stroke - SHOULDER_GRIT_WIDTH * 0.5
					)
				var lateral: float = float(side) * maxf(magnitude, 0.0)
				var center: Vector2 = _start + direction * along + perpendicular * lateral
				if breaks_a_boundary:
					break_marks.push_back(center - stroke)
					break_marks.push_back(center + stroke)
				else:
					dust_marks.push_back(center - stroke)
					dust_marks.push_back(center + stroke)
		grit_index += 1
	if not break_marks.is_empty():
		draw_multiline(break_marks, break_color, VERGE_BREAK_WIDTH, false)
	if not dust_marks.is_empty():
		draw_multiline(dust_marks, SHOULDER_GRIT_COLOR, SHOULDER_GRIT_WIDTH, false)

func _stable_pair(first: int, second: int) -> float:
	## `_stable_unit` takes the fraction of a raw sine, which is a smooth function
	## of its index: consecutive values come out correlated, which is tolerable for
	## surface breaks 690 units apart and useless for aggregate laid every 52.
	## Scaling before the fraction is what decorrelates neighbours, and the second
	## index gives each mark independent streams for lane, offset, angle and size
	## instead of four successive draws from one sequence.
	var value: float = sin(
		float(first) * 12.9898
		+ float(second) * 78.233
		+ position.x * 0.0017
		+ position.y * 0.0023
	) * 43758.5453
	return value - floorf(value)


func _ragged_outline(
	center: Vector2,
	corners: PackedVector2Array,
	amplitude: float,
	seed_index: int
) -> PackedVector2Array:
	## Subdivides a polygon offered in local space and displaces every point along
	## its own outward direction, returning world-space vertices. The corners move
	## too, because a corner left exactly where it was authored is the one place a
	## viewer can still read the shape underneath. The amplitude stays a fraction
	## of the smaller half extent so the outline cannot fold through itself.
	var outline: PackedVector2Array = PackedVector2Array()
	var count: int = corners.size()
	var vertex: int = 0
	for index: int in range(count):
		var from: Vector2 = corners[index]
		var to: Vector2 = corners[(index + 1) % count]
		for sample: int in range(PATCH_EDGE_SAMPLES + 1):
			var point: Vector2 = from.lerp(
				to, float(sample) / float(PATCH_EDGE_SAMPLES + 1)
			)
			var outward: Vector2 = (
				point.normalized() if not point.is_zero_approx() else Vector2.RIGHT
			)
			var push: float = (
				_stable_pair(seed_index * 64 + vertex, 127) - 0.5
			) * 2.0 * amplitude
			outline.push_back(center + point + outward * push)
			vertex += 1
	return outline
