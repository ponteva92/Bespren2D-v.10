class_name WorldBackgroundDecorChunk2D
extends Node2D
## Regional custom-draw batch for non-colliding decor on the background pass.

## Moss is a stain on the ground, so it is built the way [GroundShadow] builds a
## contact: overlapping lobes of low-alpha steps whose union has no edge, rather
## than one shape at one opacity.
##
## It used to be `draw_circle` at 0.42 plus a `draw_arc` rim, and in
## `artifacts/world_forest_density_validation.png` that read as exactly what it
## was - a flat translucent disc with a lighter lip, the most geometric shape in a
## naturalistic frame. The rim was the worse half: a 12 segment arc is a visible
## dodecagon, and drawing it *lighter* than the fill turned a ground stain into a
## raised pad.
##
## Alpha is per step. Six steps overlap to about 0.45 at the core, which holds the
## value the old flat fill had, and fall to a single 0.096 step at the fringe,
## which is what removes the edge.
##
## The steps used to be circles, and the claim above them - that rotating three
## lobes stops 220 patches sharing one silhouette - was true about the rotation
## and false about the silhouette, because a rotated circle is the same circle.
## The lobe centres sat within 0.22 of the patch centre with radii of 0.62 to
## 0.74, so their union's radial extent ran from 0.84 to 0.92 of the radius: a
## five percent departure from a disc, in a frame where the disc was the only
## geometric shape. `draw_circle` cannot express a moss patch for the same reason
## `draw_polyline` could not express a decade of road erosion - the primitive has
## no way to say where the growth stopped. Each step is now a thirteen-point
## polygon whose radius carries three broad lobes and five finer ones at
## independent phases, so its outline runs from 0.69 to 1.31 of nominal and no two
## steps break in the same places. `draw_colored_polygon` takes concave outlines
## in Godot 4, which is the whole reason the shape can now have notches.
## Held at the forest floor's own value on purpose, so moss reads as a hue shift
## rather than a bright patch.
##
## The value was retuned here too, on a measurement that turned out to be of
## something else. A luma 88.7 blob in that capture was read as the moss and the
## fill was darkened to chase it; the next capture moved it by 0.13 L, which is
## the proof it was never moss. It was [constant PROP_FOLIAGE] below, whose
## `lightened(0.08)` lobe composites to 84 on the same ground. The darker fill is
## kept anyway, on its own merit rather than the borrowed one: a stain that sits
## at the floor's own 0.208 relative luma reads as a hue shift in the dirt, which
## is what moss is, and that is the correction [constant FOLIAGE_COOL] already
## took - differ by hue, stay inside the world's value band.
const MOSS_FILL: Color = Color(0.15, 0.23, 0.16, 0.096)
## A smaller, off-centre lobe about 8 L above the fill, so the patch has some form
## without becoming an island. This is the variation the deleted rim was reaching
## for in the wrong place.
const MOSS_HIGHLIGHT: Color = Color(0.19, 0.26, 0.16, 0.085)
## Nominal radius of each step as a fraction of the patch radius. Six of them, so
## the core still accumulates the 0.45 the flat fill used to carry.
const MOSS_RING_SCALES: Array[float] = [1.0, 0.88, 0.75, 0.62, 0.5, 0.38]
## Odd on purpose: thirteen points cannot align with the three-lobe or five-lobe
## term, so the outline never resolves into a polygon the eye can count.
const ORGANIC_OUTLINE_VERTICES: int = 13
const CRACK_COLOR: Color = Color(0.025, 0.035, 0.033, 0.72)
const CRACK_BRANCH_COLOR: Color = Color(0.025, 0.035, 0.033, 0.62)
const RUBBLE_WOOD_COLOR: Color = Color(0.28, 0.22, 0.17, 0.7)
const RUBBLE_METAL_COLOR: Color = Color(0.24, 0.28, 0.27, 0.68)
## Background decor holds a 55-70 composite luma band over the world's own ~53
## floor: present as texture, never as a destination.
##
## All four flat prop colours below broke it. [constant PROP_FOLIAGE] is the
## measured one - its `lightened(0.08)` lobe composited to 84 in
## `artifacts/world_forest_density_validation.png`, the brightest blob in the
## wilderness view, out-valuing the dirt road at 86.9 and only 5 L under the whole
## frame's p99. The other three were computed from the same arithmetic against the
## same ground rather than caught on camera, and the arithmetic is not in doubt:
## bones reached 106, mushroom caps 97, barrel steel 78. A player scanning for the
## refuge or for salvage should not be pulled to litter, which is what CLAUDE.md 8
## means by reserving the high-value islands.
##
## Hue and shape still carry each identity, per CLAUDE.md 11: bone stays the
## palest and the only warm one, growth stays the only yellow-green and keeps its
## three-cap cluster, steel stays cool-neutral under its rust ring.
const PROP_TIMBER: Color = Color(0.29, 0.19, 0.11, 0.78)
const PROP_STEEL: Color = Color(0.26, 0.30, 0.28, 0.74)
const PROP_FOLIAGE: Color = Color(0.16, 0.28, 0.19, 0.62)
const PROP_BONE: Color = Color(0.37, 0.35, 0.29, 0.66)

## Contact footprint per prop kind: half-width and downward centre offset as
## multiples of the prop's own size, then the flatten. Indices are the kind IDs
## the scatter assigns. A zero width says the kind lies on the world floor and
## owes no contact, because its own dark pixels already are one - the fallen
## branch, the flat tyre, and the bleached bones. The three atlas kinds are absent
## from this table on purpose; their footprint is derived from the frame they
## draw, in [method _draw_atlas_contact].
const PROP_CONTACTS: Array[Vector3] = [
	Vector3(1.02, 0.46, 0.40),
	Vector3.ZERO,
	Vector3.ZERO,
	Vector3(0.78, 0.34, 0.36),
	Vector3.ZERO,
	Vector3(0.68, 0.30, 0.34),
]
const SLEEK_CANVAS_SHADER: Shader = preload("res://shaders/sleek_canvas_grade.gdshader")
const POLYHAVEN_ATLAS: Texture2D = preload(
	"res://assets/2d/environment/polyhaven/polyhaven_environment_atlas.png"
)
const POLYHAVEN_TYRE_REGION: Rect2 = Rect2(1232.0, 837.0, 223.0, 220.0)
const POLYHAVEN_DISTRICT_ATLAS: Texture2D = preload(
	"res://assets/2d/environment/polyhaven_district/polyhaven_district_atlas.png"
)
const DISTRICT_BENCH_REGION: Rect2 = Rect2(417.0, 436.0, 317.0, 265.0)
const DISTRICT_HYDRANT_REGION: Rect2 = Rect2(887.0, 467.0, 136.0, 241.0)
const DISTRICT_BARREL_STOVE_REGION: Rect2 = Rect2(1260.0, 442.0, 168.0, 267.0)

static var _shared_sleek_material: ShaderMaterial

var _rubble_positions: PackedVector2Array = PackedVector2Array()
var _rubble_sizes: PackedFloat32Array = PackedFloat32Array()
var _rubble_rotations: PackedFloat32Array = PackedFloat32Array()
var _rubble_indices: PackedInt32Array = PackedInt32Array()
var _crack_starts: PackedVector2Array = PackedVector2Array()
var _crack_ends: PackedVector2Array = PackedVector2Array()
var _moss_positions: PackedVector2Array = PackedVector2Array()
var _moss_sizes: PackedFloat32Array = PackedFloat32Array()
var _prop_positions: PackedVector2Array = PackedVector2Array()
var _prop_sizes: PackedFloat32Array = PackedFloat32Array()
var _prop_rotations: PackedFloat32Array = PackedFloat32Array()
var _prop_kinds: PackedInt32Array = PackedInt32Array()
var _world_render_bounds: Rect2 = Rect2()
var _has_bounds: bool = false


func _ready() -> void:
	z_index = -5
	z_as_relative = false
	material = _get_sleek_material()


static func _get_sleek_material() -> ShaderMaterial:
	if _shared_sleek_material == null:
		_shared_sleek_material = ShaderMaterial.new()
		_shared_sleek_material.shader = SLEEK_CANVAS_SHADER
	return _shared_sleek_material


func configure_origin(world_origin: Vector2) -> void:
	position = world_origin
	z_index = -5
	z_as_relative = false


func add_rubble(world_position: Vector2, size: float, rotation: float, source_index: int) -> void:
	_rubble_positions.append(world_position - position)
	_rubble_sizes.append(size)
	_rubble_rotations.append(rotation)
	_rubble_indices.append(source_index)
	_include_world_area(world_position, size * 1.2 + 2.0)


func add_crack(world_start: Vector2, world_end: Vector2) -> void:
	_crack_starts.append(world_start - position)
	_crack_ends.append(world_end - position)
	_include_world_point(world_start, 12.0)
	_include_world_point(world_end, 12.0)
	var branch_point: Vector2 = world_start.lerp(world_end, 0.56)
	var displacement: Vector2 = world_end - world_start
	if not displacement.is_zero_approx():
		var branch_end: Vector2 = branch_point + displacement.normalized().orthogonal() * 85.0
		_include_world_point(branch_end, 12.0)


func add_moss(world_position: Vector2, size: float) -> void:
	_moss_positions.append(world_position - position)
	_moss_sizes.append(size)
	_include_world_area(world_position, size + 6.0)


func add_prop(world_position: Vector2, size: float, rotation: float, kind: int) -> void:
	_prop_positions.append(world_position - position)
	_prop_sizes.append(size)
	_prop_rotations.append(rotation)
	_prop_kinds.append(kind)
	_include_world_area(world_position, size * 1.8 + 8.0)


func seal() -> void:
	queue_redraw()


## Deterministic per-patch variation with no stored state and no RNG: the patch's
## own position is already unique and already deterministic, so hashing it keeps
## the scatter reproducible for the gate that compares two builds.
static func _patch_noise(source: Vector2, salt: float) -> float:
	return fposmod(sin(source.x * 12.9898 + source.y * 78.233 + salt) * 43758.5453, 1.0)


## A closed outline whose radius is modulated rather than constant: three broad
## lobes and five finer ones at independent phases, so growth reached further in
## some directions than others and no two outlines break in the same places.
## `seed_source` is separate from `center` because a prop draws under
## [method CanvasItem.draw_set_transform] and its geometry is therefore local,
## while its randomness still has to come from where it stands in the world.
static func _organic_outline(
	seed_source: Vector2,
	center: Vector2,
	radius: float,
	spin: float,
	squash: float,
	salt: float,
	lobe_amount: float,
	fine_amount: float
) -> PackedVector2Array:
	var lobe_phase: float = _patch_noise(seed_source, salt + 1.0) * TAU
	var fine_phase: float = _patch_noise(seed_source, salt + 2.0) * TAU
	var points: PackedVector2Array = PackedVector2Array()
	points.resize(ORGANIC_OUTLINE_VERTICES)
	for vertex: int in range(ORGANIC_OUTLINE_VERTICES):
		var angle: float = spin + TAU * float(vertex) / float(ORGANIC_OUTLINE_VERTICES)
		var wobble: float = (
			1.0
			+ lobe_amount * sin(angle * 3.0 + lobe_phase)
			+ fine_amount * sin(angle * 5.0 + fine_phase)
		)
		var reach: float = radius * wobble
		points[vertex] = center + Vector2(cos(angle) * reach, sin(angle) * reach * squash)
	return points


func _draw_moss_patch(center: Vector2, radius: float) -> void:
	# Rotating the pattern is what stops 220 patches from sharing one silhouette.
	# It costs a sin/cos pair per patch and no extra draw call. Hashed off the
	# world position for the reason given on `_draw_shrub`: a patch's shape should
	# outlive a change to the chunk grid it happens to be drawn in.
	var seed_source: Vector2 = center + position
	var spin: float = _patch_noise(seed_source, 0.0) * TAU
	var squash: float = 0.86 + _patch_noise(seed_source, 4.7) * 0.24
	for ring: int in range(MOSS_RING_SCALES.size()):
		var scale: float = MOSS_RING_SCALES[ring]
		# Inner steps drift off the shared centre, so the patch has no axis. The
		# drift is scaled by how far in the step is, which keeps the outermost
		# outline anchored to the position the scatter actually chose.
		var salt: float = 11.0 + float(ring) * 7.3
		var drift: Vector2 = Vector2(
			_patch_noise(seed_source, salt + 4.0) - 0.5,
			_patch_noise(seed_source, salt + 5.0) - 0.5
		) * radius * 0.22 * (1.0 - scale)
		draw_colored_polygon(
			_organic_outline(
				seed_source, center + drift, radius * scale, spin, squash, salt, 0.2, 0.11
			),
			MOSS_FILL
		)
	draw_colored_polygon(
		_organic_outline(
			seed_source,
			center + Vector2(radius * 0.16, -radius * 0.14).rotated(spin),
			radius * 0.34,
			spin,
			squash,
			83.0,
			0.2,
			0.11
		),
		MOSS_HIGHLIGHT
	)


## The shrub was three near-concentric [method CanvasItem.draw_circle] calls -
## a full-radius mass with two lobes at 0.42 and 0.38 of the radius carrying
## radii of 0.58 and 0.52. Their union reaches 1.0 in every direction, so the
## whole prop was a disc with a light side and a dark side, and it is the
## largest of the 420 because its outer circle uses the full authored size.
## That is the same defect [method _draw_moss_patch] carried, in the same file,
## measured in the same capture: a smooth circle 21 pixels across sitting in a
## forest frame where nothing else is round.
##
## A shrub seen from above is a clump, so the three masses stay - they are what
## gives it a lit side - but each is now an outline that reached further in some
## directions than others, at its own phase and its own spin, so the union has
## notches instead of a rim. `seed_source` is the prop's world position rather
## than the chunk-local one the draw uses: local offsets are measured from a
## chunk origin derived from `RENDER_CHUNK_SIZE` and the playable half extent, so
## hashing them would re-roll every silhouette in the map the day either of those
## constants moves. The world position is the one thing about a shrub that a
## re-chunk cannot change.
func _draw_shrub(seed_source: Vector2, radius: float) -> void:
	var squash: float = 0.84 + _patch_noise(seed_source, 2.1) * 0.26
	draw_colored_polygon(
		_organic_outline(
			seed_source,
			Vector2.ZERO,
			radius,
			_patch_noise(seed_source, 3.3) * TAU,
			squash,
			17.0,
			0.24,
			0.13
		),
		PROP_FOLIAGE
	)
	draw_colored_polygon(
		_organic_outline(
			seed_source,
			Vector2(-radius * 0.42, radius * 0.08),
			radius * 0.58,
			_patch_noise(seed_source, 5.9) * TAU,
			squash,
			41.0,
			0.28,
			0.15
		),
		PROP_FOLIAGE.lightened(0.08)
	)
	draw_colored_polygon(
		_organic_outline(
			seed_source,
			Vector2(radius * 0.38, -radius * 0.12),
			radius * 0.52,
			_patch_noise(seed_source, 8.7) * TAU,
			squash,
			67.0,
			0.28,
			0.15
		),
		PROP_FOLIAGE.darkened(0.08)
	)


func get_decoration_count() -> int:
	return (
		_rubble_positions.size()
		+ _crack_starts.size()
		+ _moss_positions.size()
		+ _prop_positions.size()
	)


func get_world_render_bounds() -> Rect2:
	return _world_render_bounds


func _draw() -> void:
	for moss_index: int in range(_moss_positions.size()):
		_draw_moss_patch(_moss_positions[moss_index], _moss_sizes[moss_index])

	for crack_index: int in range(_crack_starts.size()):
		var crack_start: Vector2 = _crack_starts[crack_index]
		var crack_end: Vector2 = _crack_ends[crack_index]
		draw_line(crack_start, crack_end, CRACK_COLOR, 18.0)
		var displacement: Vector2 = crack_end - crack_start
		if displacement.is_zero_approx():
			continue
		var branch_point: Vector2 = crack_start.lerp(crack_end, 0.56)
		var branch_direction: Vector2 = displacement.normalized().orthogonal()
		draw_line(
			branch_point,
			branch_point + branch_direction * 85.0,
			CRACK_BRANCH_COLOR,
			11.0
		)

	for rubble_index: int in range(_rubble_positions.size()):
		var rubble_position: Vector2 = _rubble_positions[rubble_index]
		var rubble_size: float = _rubble_sizes[rubble_index]
		var rubble_rotation: float = _rubble_rotations[rubble_index]
		var rubble_points: PackedVector2Array = PackedVector2Array([
			rubble_position + Vector2(-rubble_size, rubble_size * 0.48).rotated(rubble_rotation),
			rubble_position + Vector2(rubble_size * 0.82, rubble_size * 0.32).rotated(rubble_rotation),
			rubble_position + Vector2(rubble_size * 0.18, -rubble_size * 0.76).rotated(rubble_rotation),
		])
		var rubble_color: Color = (
			RUBBLE_WOOD_COLOR if _rubble_indices[rubble_index] % 3 == 0 else RUBBLE_METAL_COLOR
		)
		draw_colored_polygon(rubble_points, rubble_color)

	# Contacts are one pass ahead of the props rather than one call inside each.
	# `GroundShadow.draw_ellipse` sets and clears the canvas transform, so it
	# cannot run inside the per-prop `draw_set_transform` the loop below holds -
	# and drawing them together means a hydrant standing beside a bench sits on
	# top of the bench's pool rather than inside it.
	for prop_index: int in range(_prop_positions.size()):
		_draw_prop_contact(
			_prop_positions[prop_index], _prop_sizes[prop_index], _prop_kinds[prop_index]
		)

	for prop_index: int in range(_prop_positions.size()):
		var prop_position: Vector2 = _prop_positions[prop_index]
		var prop_size: float = _prop_sizes[prop_index]
		var prop_rotation: float = _prop_rotations[prop_index]
		var prop_kind: int = _prop_kinds[prop_index]
		draw_set_transform(prop_position, prop_rotation, Vector2.ONE)
		match prop_kind:
			0: # leafy shrub with a dark center
				_draw_shrub(prop_position + position, prop_size)
			1: # broken root or small fallen branch
				draw_line(Vector2(-prop_size * 1.4, 0.0), Vector2(prop_size * 1.4, 0.0), PROP_TIMBER, maxf(prop_size * 0.42, 6.0))
				draw_line(Vector2(-prop_size * 0.25, 0.0), Vector2(-prop_size * 0.7, -prop_size * 0.8), PROP_TIMBER.darkened(0.12), maxf(prop_size * 0.22, 4.0))
			2: # flat abandoned tyre from the shared Poly Haven atlas
				var tyre_half_span: float = prop_size * 1.25
				draw_texture_rect_region(
					POLYHAVEN_ATLAS,
					Rect2(
						Vector2(-tyre_half_span, -tyre_half_span),
						Vector2.ONE * tyre_half_span * 2.0
					),
					POLYHAVEN_TYRE_REGION,
					Color(0.82, 0.86, 0.83, 0.92),
					false,
					true
				)
			3: # abandoned barrel top
				draw_circle(Vector2.ZERO, prop_size * 0.7, PROP_STEEL)
				draw_arc(Vector2.ZERO, prop_size * 0.48, 0.0, TAU, 14, Color("60402e"), maxf(prop_size * 0.15, 3.0))
			4: # pale bones/antlers
				draw_line(Vector2(-prop_size, 0.0), Vector2(prop_size, 0.0), PROP_BONE, maxf(prop_size * 0.16, 3.0))
				draw_line(Vector2(-prop_size * 0.3, 0.0), Vector2(-prop_size * 0.72, -prop_size * 0.58), PROP_BONE, maxf(prop_size * 0.1, 2.0))
				draw_line(Vector2(prop_size * 0.25, 0.0), Vector2(prop_size * 0.64, prop_size * 0.54), PROP_BONE, maxf(prop_size * 0.1, 2.0))
			5: # mushroom/toxic growth cluster
				for cap_index: int in range(3):
					var cap_position: Vector2 = Vector2(-prop_size * 0.5 + cap_index * prop_size * 0.5, absf(1.0 - cap_index) * prop_size * 0.24)
					draw_circle(cap_position, prop_size * (0.28 + cap_index * 0.04), Color(0.27, 0.32, 0.17, 0.62))
			6: # Poly Haven street bench
				_draw_district_prop(
					DISTRICT_BENCH_REGION,
					prop_size * 3.0,
					Color(0.88, 0.91, 0.87, 0.94)
				)
			7: # Poly Haven fire hydrant
				_draw_district_prop(
					DISTRICT_HYDRANT_REGION,
					prop_size * 2.25,
					Color(0.95, 0.88, 0.82, 0.96)
				)
			8: # Poly Haven barrel stove
				_draw_district_prop(
					DISTRICT_BARREL_STOVE_REGION,
					prop_size * 2.4,
					Color(0.91, 0.88, 0.83, 0.95)
				)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Every prop in this class stood on nothing. [GroundShadow]'s own docstring names
## the gap - nine obstacle kinds "and every background decoration, drew nothing" -
## and this is the background-decoration half of it: 420 props, among them the 75
## benches, 46 hydrants and 34 stoves the district gate counts here, all of them
## floating a shade above a floor they are supposed to be standing on.
##
## Rotation is dropped deliberately. The ellipse is a horizontal footprint under a
## vertical object, so it turns mostly in the axis the flatten has already
## collapsed; and the three kinds whose silhouette is genuinely directional lie
## flat on the ground and are given no contact at all.
func _draw_prop_contact(center: Vector2, size: float, kind: int) -> void:
	match kind:
		6:
			_draw_atlas_contact(center, DISTRICT_BENCH_REGION, size * 3.0)
		7:
			_draw_atlas_contact(center, DISTRICT_HYDRANT_REGION, size * 2.25)
		8:
			_draw_atlas_contact(center, DISTRICT_BARREL_STOVE_REGION, size * 2.4)
		_:
			if kind < 0 or kind >= PROP_CONTACTS.size():
				return
			var contact: Vector3 = PROP_CONTACTS[kind]
			if contact.x <= 0.0:
				return
			var radius_x: float = size * contact.x
			GroundShadow.draw_ellipse(
				self,
				center + Vector2(0.0, size * contact.y),
				Vector2(radius_x, minf(radius_x * contact.z, GroundShadow.MAX_CONTACT_DEPTH)),
				GroundShadow.PROP_STRENGTH
			)


## The atlas kinds size their footprint from the frame they actually draw, so a
## region or span edit moves the contact with the sprite instead of leaving it
## behind - which is the exact failure [GroundShadow] records for twenty of the
## twenty-one imported visual families.
func _draw_atlas_contact(center: Vector2, region: Rect2, target_span: float) -> void:
	var source_span: float = maxf(region.size.x, region.size.y)
	var destination_size: Vector2 = region.size * target_span / maxf(source_span, 1.0)
	var radius_x: float = destination_size.x * 0.5 * 0.86
	GroundShadow.draw_ellipse(
		self,
		center + Vector2(0.0, destination_size.y * 0.5),
		Vector2(radius_x, minf(radius_x * 0.34, GroundShadow.MAX_CONTACT_DEPTH)),
		GroundShadow.PROP_STRENGTH
	)


func _draw_district_prop(region: Rect2, target_span: float, tint: Color) -> void:
	var source_span: float = maxf(region.size.x, region.size.y)
	var destination_size: Vector2 = region.size * target_span / maxf(source_span, 1.0)
	draw_texture_rect_region(
		POLYHAVEN_DISTRICT_ATLAS,
		Rect2(destination_size * -0.5, destination_size),
		region,
		tint,
		false,
		true
	)


func _include_world_area(center: Vector2, radius: float) -> void:
	var area: Rect2 = Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
	_include_world_rect(area)


func _include_world_point(point: Vector2, padding: float) -> void:
	_include_world_area(point, padding)


func _include_world_rect(area: Rect2) -> void:
	if not _has_bounds:
		_world_render_bounds = area
		_has_bounds = true
		return
	_world_render_bounds = _world_render_bounds.merge(area)
