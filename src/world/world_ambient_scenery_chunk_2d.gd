class_name WorldAmbientSceneryChunk2D
extends Node2D
## Chunked visual-only scenery batch for large readable world silhouettes.

const SLEEK_CANVAS_SHADER: Shader = preload("res://shaders/sleek_canvas_grade.gdshader")
const WILD_ATLAS: Texture2D = preload(
	"res://assets/2d/environment/polyhaven_wild/polyhaven_wild_atlas.png"
)
const POLYHAVEN_ATLAS: Texture2D = preload(
	"res://assets/2d/environment/polyhaven/polyhaven_environment_atlas.png"
)
const LOCAL_ENVIRONMENT_ATLAS: Texture2D = preload(
	"res://assets/2d/environment/local_baked/local_environment_atlas.png"
)
const DISTRICT_ATLAS: Texture2D = preload(
	"res://assets/2d/environment/polyhaven_district/polyhaven_district_atlas.png"
)

## The same three firs and two broadleaves [WorldObstacle2D] plants as colliding
## trees, so a distant canopy and the trunk the player walks into are the same
## species rather than two different art languages sharing a name.
const WILD_TREE_REGIONS: Array[Rect2] = [
	Rect2(76.0, 54.0, 104.0, 136.0),
	Rect2(314.0, 49.0, 137.0, 141.0),
	Rect2(574.0, 45.0, 131.0, 139.0),
	Rect2(839.0, 41.0, 132.0, 133.0),
	Rect2(1065.0, 44.0, 170.0, 161.0),
]
## One tint, not four. The retired array ranged over hue to break up a pixel
## sheet whose four frames repeated every fourth tree; five baked frames carry
## their own variation, so all this has left to do is the job every other baked
## frame in this file asks of its tint - sit background scenery back in value
## and pull it toward the palette. It is therefore the family value, in band
## with the Poly Haven, local, and district frames drawn beside it.
## Times the hue correction the colliding tree owns. WorldObstacle2D.WILD_TREE_TINT
## records why the five baked frames arrive straw-yellow and what the multiply
## does about it; this file draws the same five frames through a different
## grade under a different value tint, and a per-channel multiply commutes with
## everything scalar in both, so folding the correction into this constant is
## the one way a distant canopy and the trunk the player walks into keep being
## one species. Godot multiplies Colors per component.
const WILD_TREE_TINT: Color = WorldObstacle2D.WILD_TREE_TINT * Color(0.78, 0.83, 0.74, 0.88)
const POLYHAVEN_STUMP_REGION: Rect2 = Rect2(36.0, 104.0, 309.0, 230.0)
const POLYHAVEN_DEAD_TRUNK_REGION: Rect2 = Rect2(435.0, 115.0, 284.0, 150.0)
const POLYHAVEN_MOSS_ROCK_REGIONS: Array[Rect2] = [
	Rect2(856.0, 72.0, 207.0, 251.0),
	Rect2(1257.0, 89.0, 144.0, 249.0),
	Rect2(9.0, 469.0, 318.0, 243.0),
	Rect2(449.0, 439.0, 269.0, 244.0),
	Rect2(844.0, 459.0, 256.0, 207.0),
	Rect2(1240.0, 461.0, 234.0, 237.0),
]
const POLYHAVEN_TRASH_CLEAN_REGION: Rect2 = Rect2(80.0, 811.0, 225.0, 290.0)
const POLYHAVEN_TRASH_RUST_REGION: Rect2 = Rect2(464.0, 810.0, 226.0, 292.0)
const POLYHAVEN_CONCRETE_BARRIER_REGION: Rect2 = Rect2(790.0, 819.0, 344.0, 289.0)
const POLYHAVEN_TYRE_REGION: Rect2 = Rect2(1232.0, 837.0, 223.0, 220.0)
const LOCAL_CITY_REGIONS: Array[Rect2] = [
	Rect2(33.0, 10.0, 318.0, 359.0),
	Rect2(455.0, 43.0, 242.0, 316.0),
	Rect2(848.0, 11.0, 224.0, 346.0),
	Rect2(1198.0, 24.0, 298.0, 332.0),
]
const LOCAL_VILLAGE_WEST_REGION: Rect2 = Rect2(832.0, 431.0, 256.0, 312.0)
const LOCAL_VILLAGE_EAST_REGION: Rect2 = Rect2(1226.0, 398.0, 212.0, 330.0)
const LOCAL_VEHICLE_REGION: Rect2 = Rect2(23.0, 837.0, 290.0, 232.0)
const LOCAL_WOOD_BARRICADE_REGION: Rect2 = Rect2(425.0, 784.0, 282.0, 321.0)
const LOCAL_ROADSIDE_SALVAGE_REGION: Rect2 = Rect2(1188.0, 785.0, 327.0, 352.0)
const DISTRICT_FACTORY_REGION: Rect2 = Rect2(413.0, 24.0, 326.0, 336.0)
const DISTRICT_URBAN_REGION: Rect2 = Rect2(26.0, 24.0, 332.0, 336.0)
const DISTRICT_CHAINLINK_REGION: Rect2 = Rect2(810.0, 46.0, 300.0, 296.0)
const AMBIENT_SCENERY_Z: int = -4

enum SceneryKind {
	RUIN_FACADE,
	VILLAGE_SHACK,
	TREE_CLUSTER,
	FOLIAGE_CLUSTER,
	ROCK_CLUSTER,
	FALLEN_LOG,
	SCRAP_CLUSTER,
	ROAD_BARRIER,
	WRECK,
	FENCE,
}

static var _shared_sleek_material: ShaderMaterial

var _positions: PackedVector2Array = PackedVector2Array()
var _sizes: PackedFloat32Array = PackedFloat32Array()
var _rotations: PackedFloat32Array = PackedFloat32Array()
var _kinds: PackedInt32Array = PackedInt32Array()
var _variants: PackedInt32Array = PackedInt32Array()
var _world_render_bounds: Rect2 = Rect2()
var _has_bounds: bool = false


func _ready() -> void:
	z_index = AMBIENT_SCENERY_Z
	z_as_relative = false
	material = _get_sleek_material()


static func _get_sleek_material() -> ShaderMaterial:
	if _shared_sleek_material == null:
		_shared_sleek_material = ShaderMaterial.new()
		_shared_sleek_material.shader = SLEEK_CANVAS_SHADER
	return _shared_sleek_material


func configure_origin(world_origin: Vector2) -> void:
	position = world_origin
	z_index = AMBIENT_SCENERY_Z
	z_as_relative = false
	material = _get_sleek_material()


func add_scenery(
	world_position: Vector2,
	size: float,
	rotation: float,
	kind: int,
	variant: int
) -> void:
	_positions.append(world_position - position)
	_sizes.append(size)
	_rotations.append(rotation)
	_kinds.append(kind)
	_variants.append(variant)
	_include_world_area(world_position, size * 0.78 + 72.0)


func seal() -> void:
	queue_redraw()


func get_scenery_count() -> int:
	return _positions.size()


func get_world_render_bounds() -> Rect2:
	return _world_render_bounds


func _draw() -> void:
	for scenery_index: int in range(_positions.size()):
		var scenery_position: Vector2 = _positions[scenery_index]
		var scenery_size: float = _sizes[scenery_index]
		var scenery_kind: int = _kinds[scenery_index]
		var scenery_variant: int = _variants[scenery_index]
		# Grounding is drawn by `_draw_atlas_frame`, one contact per frame, because
		# only that function knows where a given frame's pixels actually end. The
		# lift below is the reason a per-kind table cannot: it moves the art but
		# not the ground, so a contact authored in kind space is always guessing.
		var vertical_offset: float = -scenery_size * 0.10
		if scenery_kind == SceneryKind.RUIN_FACADE:
			vertical_offset = -scenery_size * 0.24
		elif scenery_kind == SceneryKind.VILLAGE_SHACK:
			vertical_offset = -scenery_size * 0.18
		elif scenery_kind == SceneryKind.TREE_CLUSTER:
			vertical_offset = -scenery_size * 0.22
		draw_set_transform(
			scenery_position + Vector2(0.0, vertical_offset),
			_rotations[scenery_index],
			Vector2.ONE
		)
		match scenery_kind:
			SceneryKind.RUIN_FACADE:
				_draw_ruin_facade(scenery_size, scenery_variant)
			SceneryKind.VILLAGE_SHACK:
				_draw_village_shack(scenery_size, scenery_variant)
			SceneryKind.TREE_CLUSTER:
				_draw_tree_cluster(scenery_size, scenery_variant)
			SceneryKind.FOLIAGE_CLUSTER:
				_draw_foliage_cluster(scenery_size, scenery_variant)
			SceneryKind.ROCK_CLUSTER:
				_draw_rock_cluster(scenery_size, scenery_variant)
			SceneryKind.FALLEN_LOG:
				_draw_atlas_frame(
					POLYHAVEN_ATLAS,
					POLYHAVEN_DEAD_TRUNK_REGION,
					scenery_size,
					Color(0.77, 0.83, 0.72, 0.92),
					Vector2.ZERO,
					0.88,
					0.30
				)
			SceneryKind.SCRAP_CLUSTER:
				_draw_scrap_cluster(scenery_size, scenery_variant)
			SceneryKind.ROAD_BARRIER:
				_draw_road_barrier(scenery_size, scenery_variant)
			SceneryKind.WRECK:
				_draw_atlas_frame(
					LOCAL_ENVIRONMENT_ATLAS,
					LOCAL_VEHICLE_REGION,
					scenery_size,
					Color(0.82, 0.86, 0.78, 0.94)
				)
			SceneryKind.FENCE:
				_draw_fence(scenery_size, scenery_variant)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_ruin_facade(target_span: float, variant: int) -> void:
	var use_district: bool = variant % 3 == 2
	if use_district:
		_draw_atlas_frame(
			DISTRICT_ATLAS,
			DISTRICT_URBAN_REGION if variant % 2 == 0 else DISTRICT_FACTORY_REGION,
			target_span,
			Color(0.76, 0.82, 0.77, 0.82),
			Vector2.ZERO,
			0.92,
			0.24
		)
		return
	_draw_atlas_frame(
		LOCAL_ENVIRONMENT_ATLAS,
		LOCAL_CITY_REGIONS[posmod(variant, LOCAL_CITY_REGIONS.size())],
		target_span,
		Color(0.74, 0.80, 0.75, 0.82),
		Vector2.ZERO,
		0.92,
		0.24
	)


func _draw_village_shack(target_span: float, variant: int) -> void:
	_draw_atlas_frame(
		LOCAL_ENVIRONMENT_ATLAS,
		LOCAL_VILLAGE_WEST_REGION if variant % 2 == 0 else LOCAL_VILLAGE_EAST_REGION,
		target_span,
		Color(0.80, 0.84, 0.74, 0.88),
		Vector2.ZERO,
		0.92,
		0.24
	)


func _draw_tree_cluster(target_span: float, variant: int) -> void:
	for tree_index: int in range(3):
		var tree_span: float = target_span * (0.54 + float((variant + tree_index) % 3) * 0.08)
		var tree_offset: Vector2 = Vector2(
			(-0.32 + float(tree_index) * 0.32) * target_span,
			(-0.07 if tree_index == 1 else 0.10) * target_span
		)
		_draw_atlas_frame(
			WILD_ATLAS,
			WILD_TREE_REGIONS[posmod(variant + tree_index, WILD_TREE_REGIONS.size())],
			tree_span,
			WILD_TREE_TINT,
			tree_offset,
			0.40,
			0.52
		)


## Ambient undergrowth. It is the same idea as the canopy [WorldObstacle2D] draws
## for a real tree, and it used to be drawn without any of that node's language:
## no contact shadow, no rim, and a value that put it at the top of the frame.
##
## Measured off a Mobile/Vulkan city capture, the old #536d47 fill resolved to a
## luma of 110.7 while the whole frame's 99th percentile was 92.8 - a background
## shrub was the brightest large shape on screen, brighter than the buildings, the
## salvage and the road. CLAUDE.md 8 reserves the high-value islands for the
## refuge and for the things a player can pick up, so the two variants now differ
## by hue rather than by value and both sit inside the world's band.
const FOLIAGE_COOL: Color = Color("28442e")
const FOLIAGE_DRY: Color = Color("384628")
## The canopy rim from [WorldObstacle2D], reused verbatim. Undergrowth that holds
## its silhouette over a black rooftop the same way a tree does is the difference
## between scenery and a smudge.
const FOLIAGE_RIM: Color = Color("0b1710")
## How far the rim stands proud of each lobe, as a fraction of the cluster span.
const FOLIAGE_RIM_WIDTH: float = 0.028

## Lobe centres and radii as fractions of the cluster span, shared by the rim pass
## and the fill pass so the two can never disagree about where the clump is.
const FOLIAGE_LOBES: Array[Vector3] = [
	Vector3(-0.20, 0.0, 0.26),
	Vector3(0.16, 0.04, 0.31),
	Vector3(0.0, -0.20, 0.28),
]


func _draw_foliage_cluster(target_span: float, variant: int) -> void:
	_draw_foliage_contact(target_span)
	var foliage_color: Color = FOLIAGE_COOL if variant % 2 == 0 else FOLIAGE_DRY
	# The contact above replaces the one this used to draw for itself: a flat disc
	# at 0.44 in a hue no other shadow used, offset down and to the right "matching
	# the offset every other grounded thing in the world uses" - which was not
	# true, since every obstacle ellipse is centred on x. Centring it is what makes
	# that sentence true.
	# The rim is one oversized dark circle per lobe rather than a single arc around
	# the clump. An arc has to pick one radius, and at three offset lobes any radius
	# it picks cuts across two of them - which drew a ring through the middle of the
	# shrub and turned it into a donut. Overlapping circles union themselves, so the
	# fills painted on top leave exactly the outer edge showing.
	for lobe: Vector3 in FOLIAGE_LOBES:
		draw_circle(
			Vector2(lobe.x, lobe.y) * target_span,
			target_span * (lobe.z + FOLIAGE_RIM_WIDTH),
			FOLIAGE_RIM
		)
	# Three shades across the lobes so the clump turns rather than reading flat.
	var lobe_shades: Array[Color] = [
		foliage_color,
		foliage_color.darkened(0.10),
		foliage_color.lightened(0.08),
	]
	for lobe_index: int in FOLIAGE_LOBES.size():
		var lobe: Vector3 = FOLIAGE_LOBES[lobe_index]
		draw_circle(
			Vector2(lobe.x, lobe.y) * target_span,
			target_span * lobe.z,
			lobe_shades[lobe_index]
		)
	draw_circle(Vector2(0.0, target_span * 0.18), target_span * 0.15, Color("32240f"))


func _draw_foliage_contact(target_span: float) -> void:
	# The one kind with no atlas frame to anchor to, so its footprint is derived
	# from the lobe table instead: the lowest lobe's bottom is where the clump
	# meets the ground.
	var lowest: float = 0.0
	for lobe: Vector3 in FOLIAGE_LOBES:
		lowest = maxf(lowest, lobe.y + lobe.z)
	var radius_x: float = target_span * 0.34
	GroundShadow.draw_ellipse(
		self,
		Vector2(0.0, target_span * lowest),
		Vector2(radius_x, minf(radius_x * 0.55, GroundShadow.MAX_CONTACT_DEPTH)),
		GroundShadow.PROP_STRENGTH
	)


func _draw_rock_cluster(target_span: float, variant: int) -> void:
	_draw_atlas_frame(
		POLYHAVEN_ATLAS,
		POLYHAVEN_STUMP_REGION if variant % 6 == 5 else POLYHAVEN_MOSS_ROCK_REGIONS[posmod(variant, POLYHAVEN_MOSS_ROCK_REGIONS.size())],
		target_span * 0.74,
		Color(0.76, 0.83, 0.72, 0.90),
		Vector2(-target_span * 0.16, target_span * 0.05),
		0.85,
		0.55
	)
	_draw_atlas_frame(
		POLYHAVEN_ATLAS,
		POLYHAVEN_MOSS_ROCK_REGIONS[posmod(variant + 2, POLYHAVEN_MOSS_ROCK_REGIONS.size())],
		target_span * 0.52,
		Color(0.70, 0.78, 0.68, 0.80),
		Vector2(target_span * 0.25, target_span * 0.18),
		0.85,
		0.55
	)


func _draw_scrap_cluster(target_span: float, variant: int) -> void:
	_draw_atlas_frame(
		POLYHAVEN_ATLAS,
		POLYHAVEN_TRASH_RUST_REGION if variant % 2 == 0 else POLYHAVEN_TRASH_CLEAN_REGION,
		target_span * 0.64,
		Color(0.83, 0.80, 0.70, 0.84),
		Vector2(-target_span * 0.20, -target_span * 0.02),
		0.80,
		0.55
	)
	_draw_atlas_frame(
		POLYHAVEN_ATLAS,
		POLYHAVEN_TYRE_REGION,
		target_span * 0.38,
		Color(0.82, 0.86, 0.80, 0.90),
		Vector2(target_span * 0.22, target_span * 0.18),
		0.80,
		0.55
	)


func _draw_road_barrier(target_span: float, variant: int) -> void:
	_draw_atlas_frame(
		POLYHAVEN_ATLAS,
		POLYHAVEN_CONCRETE_BARRIER_REGION,
		target_span,
		Color(0.86, 0.87, 0.79, 0.84)
	)
	if variant % 2 == 0:
		draw_line(
			Vector2(-target_span * 0.26, -target_span * 0.09),
			Vector2(target_span * 0.26, target_span * 0.09),
			Color(0.45, 0.30, 0.14, 0.76),
			maxf(8.0, target_span * 0.04)
		)


func _draw_fence(target_span: float, variant: int) -> void:
	if variant % 2 == 0:
		_draw_atlas_frame(
			DISTRICT_ATLAS,
			DISTRICT_CHAINLINK_REGION,
			target_span,
			Color(0.77, 0.82, 0.74, 0.84),
			Vector2.ZERO,
			0.80,
			0.26
		)
		return
	_draw_atlas_frame(
		LOCAL_ENVIRONMENT_ATLAS,
		LOCAL_WOOD_BARRICADE_REGION,
		target_span,
		Color(0.77, 0.82, 0.74, 0.84),
		Vector2.ZERO,
		0.80,
		0.26
	)


## Draws one atlas frame and the ground contact that belongs to it.
##
## The contact lives here rather than in the dispatch because this is the only
## place that knows the frame's drawn rect. Nine of the ten [enum SceneryKind]
## values reach the screen through this function, several of them more than once
## per prop, so a clump of rocks or a stand of trees gets a footprint per frame
## instead of one ellipse spanning the clump.
##
## `contact_width` is the ellipse x radius as a fraction of the frame's half
## width and `contact_flatten` its y radius as a fraction of that; zero suppresses
## the contact. The defaults suit a mid-sized ground prop. Because this runs
## inside the dispatch's `draw_set_transform`, the contact inherits the same lift
## and rotation as the art it grounds, which is what makes anchoring it to
## `destination_size` exact rather than approximate.
func _draw_atlas_frame(
	texture: Texture2D,
	region: Rect2,
	target_span: float,
	tint: Color,
	local_offset: Vector2 = Vector2.ZERO,
	contact_width: float = 0.86,
	contact_flatten: float = 0.34
) -> void:
	var source_span: float = maxf(region.size.x, region.size.y)
	var destination_size: Vector2 = region.size * target_span / maxf(source_span, 1.0)
	if contact_width > 0.0:
		var radius_x: float = destination_size.x * 0.5 * contact_width
		GroundShadow.draw_ellipse(
			self,
			local_offset + Vector2(0.0, destination_size.y * 0.5),
			Vector2(radius_x, minf(radius_x * contact_flatten, GroundShadow.MAX_CONTACT_DEPTH)),
			GroundShadow.PROP_STRENGTH
		)
	draw_texture_rect_region(
		texture,
		Rect2(local_offset - destination_size * 0.5, destination_size),
		region,
		tint,
		false,
		true
	)


func _include_world_area(center: Vector2, radius: float) -> void:
	var area: Rect2 = Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	if not _has_bounds:
		_world_render_bounds = area
		_has_bounds = true
		return
	_world_render_bounds = _world_render_bounds.merge(area)
