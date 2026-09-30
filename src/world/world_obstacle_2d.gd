class_name WorldObstacle2D
extends StaticBody2D
## One authored obstacle record drives visuals, 2D physics, and flow-field blocking.

enum ShapeKind {
	RECTANGLE,
	CIRCLE,
}

enum VisualKind {
	CITY_BUILDING,
	MALL_SHELL,
	VILLAGE_HOUSE,
	TREE,
	VEHICLE_WRECK,
	WOODEN_FENCE,
	MOSSY_ROCK,
	FALLEN_LOG,
	SCRAP_PILE,
	UTILITY_POLE,
	CAMP_BEDDING,
	CAMP_SUPPLY_CACHE,
	CAMP_MEDICAL_CACHE,
}

const SURFACE_SHADER: Shader = preload("res://shaders/surface_weathering.gdshader")
const SLEEK_SPRITE_SHADER: Shader = preload("res://shaders/sleek_sprite_finish.gdshader")
const POLYHAVEN_WILD_ATLAS_PATH: String = (
	"res://assets/2d/environment/polyhaven_wild/polyhaven_wild_atlas.png"
)
const POLYHAVEN_ATLAS_PATH: String = (
	"res://assets/2d/environment/polyhaven/polyhaven_environment_atlas.png"
)
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
const POLYHAVEN_OLD_TYRE_REGION: Rect2 = Rect2(1232.0, 837.0, 223.0, 220.0)
const LOCAL_ENVIRONMENT_ATLAS_PATH: String = (
	"res://assets/2d/environment/local_baked/local_environment_atlas.png"
)
const LOCAL_CITY_REGIONS: Array[Rect2] = [
	Rect2(33.0, 10.0, 318.0, 359.0),
	Rect2(455.0, 43.0, 242.0, 316.0),
	Rect2(848.0, 11.0, 224.0, 346.0),
	Rect2(1198.0, 24.0, 298.0, 332.0),
]
const LOCAL_MALL_REGION: Rect2 = Rect2(21.0, 419.0, 342.0, 318.0)
const LOCAL_INDUSTRIAL_REGION: Rect2 = Rect2(400.0, 416.0, 352.0, 324.0)
const LOCAL_VILLAGE_WEST_REGION: Rect2 = Rect2(832.0, 431.0, 256.0, 312.0)
const LOCAL_VILLAGE_EAST_REGION: Rect2 = Rect2(1226.0, 398.0, 212.0, 330.0)
const LOCAL_VEHICLE_REGION: Rect2 = Rect2(23.0, 837.0, 290.0, 232.0)
const LOCAL_WOOD_BARRICADE_REGION: Rect2 = Rect2(425.0, 784.0, 282.0, 321.0)
const LOCAL_UTILITY_POLE_REGION: Rect2 = Rect2(891.0, 807.0, 153.0, 283.0)
const LOCAL_ROADSIDE_SALVAGE_REGION: Rect2 = Rect2(1188.0, 785.0, 327.0, 352.0)
const LOCAL_ROADSIDE_BARRIER_REGION: Rect2 = Rect2(47.0, 1152.0, 287.0, 374.0)
const LOCAL_CAMP_BEDDING_REGION: Rect2 = Rect2(467.0, 1227.0, 254.0, 246.0)
const LOCAL_CAMP_SUPPLY_REGION: Rect2 = Rect2(810.0, 1229.0, 300.0, 260.0)
const LOCAL_CAMP_MEDICAL_REGION: Rect2 = Rect2(1153.0, 1199.0, 365.0, 292.0)
const POLYHAVEN_DISTRICT_ATLAS_PATH: String = (
	"res://assets/2d/environment/polyhaven_district/polyhaven_district_atlas.png"
)
const DISTRICT_URBAN_BLOCK_REGION: Rect2 = Rect2(26.0, 24.0, 332.0, 336.0)
const DISTRICT_FACTORY_BLOCK_REGION: Rect2 = Rect2(413.0, 24.0, 326.0, 336.0)
const DISTRICT_CHAINLINK_REGION: Rect2 = Rect2(810.0, 46.0, 300.0, 296.0)
const DISTRICT_COVERED_CAR_REGION: Rect2 = Rect2(1204.0, 66.0, 283.0, 266.0)
const DISTRICT_AIRCON_REGION: Rect2 = Rect2(45.0, 470.0, 290.0, 187.0)
const DISTRICT_BENCH_REGION: Rect2 = Rect2(417.0, 436.0, 317.0, 265.0)
const DISTRICT_HYDRANT_REGION: Rect2 = Rect2(887.0, 467.0, 136.0, 241.0)
const DISTRICT_BARREL_STOVE_REGION: Rect2 = Rect2(1260.0, 442.0, 168.0, 267.0)
const WORLD_STATIC_LAYER: int = 2
const MOSSY_ROCK_VISUAL_SPAN_FACTOR: float = 2.12
const VEHICLE_WRECK_VISUAL_WIDTH_FACTOR: float = 1.48
const ROADSIDE_BARRIER_VISUAL_WIDTH_FACTOR: float = 1.26
const CONCRETE_BARRIER_VISUAL_SPAN_FACTOR: float = 0.76
const FENCE_SEGMENT_VISUAL_WIDTH_FACTOR: float = 0.76
const FENCE_SEGMENT_VISUAL_HEIGHT_FACTOR: float = 0.68
# Per-segment presentation variation for a barricade run, all derived from
# the obstacle's stable seed. Slip is a fraction of one segment span along the
# fence; wobble is a uniform scale factor. At the shipped 0.76 width factor a
# segment leaves 0.24 of a span of gap, so slip 0.05 and wobble 0.05 keep
# neighbours at least 0.10 of a span apart.
const FENCE_VARIATION_NOISE_BASE: int = 400
const FENCE_SEGMENT_SLIP_FACTOR: float = 0.05
const FENCE_SEGMENT_SIZE_WOBBLE: float = 0.05
const UTILITY_POLE_VISUAL_WIDTH_FACTOR: float = 5.20
const UTILITY_POLE_VISUAL_Y_OFFSET_FACTOR: float = -2.62
const CAMP_BEDDING_VISUAL_WIDTH_FACTOR: float = 1.34
const CAMP_SUPPLY_VISUAL_WIDTH_FACTOR: float = 1.38
const CAMP_MEDICAL_VISUAL_WIDTH_FACTOR: float = 1.52
## Kept as a local name because the mall foundation reads it too, but it is no
## longer a second definition of the same colour - [GroundShadow] owns it.
const GROUND_SHADOW_COLOR: Color = GroundShadow.COLOR
const MALL_FOUNDATION_SHADOW_OFFSET: Vector2 = Vector2(18.0, 24.0)
const MALL_FOUNDATION_SHADOW_ALPHA: float = 0.15
## Three firs and two broadleaves from the baked wild family, as padded atlas
## regions taken from polyhaven_wild_manifest.json rather than retyped by hand.
## The retired sheet these replaced was side-view pixel art with a hard black
## cartoon outline, dropped into a top-down three-quarter world of AgX-graded
## PBR bakes: wrong projection, wrong palette, wrong rendering language, and the
## loudest thing in a forest frame at gameplay zoom. Its six entries also held
## only four distinct regions, so two of every six trees were exact twins.
## The retired tint array spanned hue 30 to 145 degrees to beat a saturated
## pixel source into the palette, and the first pass through these frames
## dropped it, reading the bakes as sitting at 28.9 to 93.1 degrees with the
## shared forest finish carrying cohesion. That reading was taken under the
## squared sleek_sprite_finish fragment CLAUDE.md 8 records - every wearer
## shipped gamma-2.0 darkened - and it did not survive the fix. Measured on the
## five frames over alpha above 128: fir_0 mean rgb (109, 104, 54) at hue 56.0
## and saturation 0.50, fir_1 58.5, fir_2 60.6, broadleaf_small_0 70.2,
## broadleaf_small_1 70.4, and no frame of the 29 in the wild family reaches
## 78 degrees. Delivered, the canopy read at hue 58.7 and luma 109 on a luma-50
## floor: straw-yellow, hue-adjacent to Heikki's #FFD45A and the camp amber,
## and the whole warm high-value population of the forest camp capture outside
## the refuge. The cause is in the bake and is the one
## render_polyhaven_wild_sprites.py names when it rejects the pines - the 70 to
## 108 luma band forces exposure up and AgX desaturates toward warm tan on the
## way - so the durable fix is a rebake, and until then one per-channel tint
## carries the correction. It is folded into entry COLOR ahead of the grade,
## so the finish sees a green source; modelled through that grade it moves the
## firs to hue 111 at saturation 0.61 and the broadleaves to 120 at 0.57,
## inside the 88 to 133 band the drawn FOLIAGE_DRY and FOLIAGE_COOL already
## bracket, at median luma 75 and 59 on the 50 floor. Red is the channel that
## turns hue and 0.60 is where the firs pass 105; green stays at 1.0 because a
## multiply can only lose value and the broadleaves have none to spare; blue at
## 0.70 is the last step before saturation falls under 0.55. The ambient
## scenery chunk draws the same five frames and multiplies this constant into
## its family value, so a distant canopy and a trunk the player walks into stay
## one species after the correction as they did before it.
const WILD_TREE_TINT: Color = Color(0.60, 1.0, 0.70, 1.0)
const WILD_TREE_REGIONS: Array[Rect2] = [
	Rect2(76.0, 54.0, 104.0, 136.0),
	Rect2(314.0, 49.0, 137.0, 141.0),
	Rect2(574.0, 45.0, 131.0, 139.0),
	Rect2(839.0, 41.0, 132.0, 133.0),
	Rect2(1065.0, 44.0, 170.0, 161.0),
]

var shape_kind: int = ShapeKind.RECTANGLE
var visual_kind: int = VisualKind.CITY_BUILDING
var half_size: Vector2 = Vector2.ZERO
var collision_radius: float = 0.0
var stable_seed: int = 1
var _imported_visual: Sprite2D
var _imported_visuals: Array[Sprite2D] = []
var _uses_imported_replacement: bool = false

static var _shared_forest_finish: ShaderMaterial
static var _shared_urban_finish: ShaderMaterial
static var _polyhaven_atlas: Texture2D
static var _polyhaven_frame_cache: Dictionary[String, Texture2D] = {}
static var _local_environment_atlas: Texture2D
static var _local_environment_frame_cache: Dictionary[String, Texture2D] = {}
static var _polyhaven_district_atlas: Texture2D
static var _polyhaven_district_frame_cache: Dictionary[String, Texture2D] = {}
static var _polyhaven_wild_atlas: Texture2D
static var _polyhaven_wild_frame_cache: Dictionary[String, Texture2D] = {}


func configure_rectangle(
	obstacle_name: StringName,
	world_position: Vector2,
	size: Vector2,
	p_visual_kind: int,
	p_rotation: float = 0.0,
	p_stable_seed: int = 1
) -> void:
	name = obstacle_name
	position = world_position
	rotation = p_rotation
	shape_kind = ShapeKind.RECTANGLE
	visual_kind = p_visual_kind
	half_size = size * 0.5
	collision_radius = 0.0
	stable_seed = maxi(p_stable_seed, 1)
	_apply_canvas_contract()
	_install_rectangle_collision(size)
	_install_weathered_material()
	_install_imported_visuals()
	queue_redraw()


func configure_circle(
	obstacle_name: StringName,
	world_position: Vector2,
	radius: float,
	p_visual_kind: int,
	p_stable_seed: int = 1
) -> void:
	name = obstacle_name
	position = world_position
	rotation = 0.0
	shape_kind = ShapeKind.CIRCLE
	visual_kind = p_visual_kind
	half_size = Vector2.ZERO
	collision_radius = radius
	stable_seed = maxi(p_stable_seed, 1)
	_apply_canvas_contract()
	_install_circle_collision(radius)
	_install_weathered_material()
	_install_imported_visuals()
	queue_redraw()


func contains_world_point(world_point: Vector2, clearance: float = 0.0) -> bool:
	var local_point: Vector2 = (world_point - position).rotated(-rotation)
	if shape_kind == ShapeKind.CIRCLE:
		return local_point.length_squared() <= pow(collision_radius + clearance, 2.0)
	var expanded: Vector2 = half_size + Vector2(clearance, clearance)
	return absf(local_point.x) <= expanded.x and absf(local_point.y) <= expanded.y


func get_world_bounds(clearance: float = 0.0) -> Rect2:
	if shape_kind == ShapeKind.CIRCLE:
		var radius_with_clearance: float = collision_radius + clearance
		var diameter: Vector2 = Vector2.ONE * radius_with_clearance * 2.0
		return Rect2(position - diameter * 0.5, diameter)
	var expanded: Vector2 = half_size + Vector2(clearance, clearance)
	var cosine: float = absf(cos(rotation))
	var sine: float = absf(sin(rotation))
	var rotated_half_size: Vector2 = Vector2(
		cosine * expanded.x + sine * expanded.y,
		sine * expanded.x + cosine * expanded.y
	)
	return Rect2(position - rotated_half_size, rotated_half_size * 2.0)


func get_shape_kind() -> int:
	return shape_kind


func get_visual_kind() -> int:
	return visual_kind


func get_imported_visual_count() -> int:
	return _imported_visuals.size()


func _apply_canvas_contract() -> void:
	z_index = 5
	z_as_relative = false
	collision_layer = WORLD_STATIC_LAYER
	collision_mask = 0


func _install_rectangle_collision(size: Vector2) -> void:
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = size
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = &"CollisionShape2D"
	collision.shape = rectangle
	add_child(collision)


func _install_circle_collision(radius: float) -> void:
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = &"CollisionShape2D"
	collision.shape = circle
	add_child(collision)


func _install_weathered_material() -> void:
	var surface_material: ShaderMaterial = ShaderMaterial.new()
	surface_material.shader = SURFACE_SHADER
	var surface_mode: int = 0
	var weathering: float = 0.38
	match visual_kind:
		VisualKind.CITY_BUILDING:
			weathering = 0.34
		VisualKind.MALL_SHELL:
			weathering = 0.30
		VisualKind.VEHICLE_WRECK, VisualKind.SCRAP_PILE:
			weathering = 0.46
		VisualKind.VILLAGE_HOUSE, VisualKind.WOODEN_FENCE, VisualKind.FALLEN_LOG, VisualKind.UTILITY_POLE, VisualKind.CAMP_BEDDING, VisualKind.CAMP_SUPPLY_CACHE, VisualKind.CAMP_MEDICAL_CACHE:
			surface_mode = 1
			weathering = 0.40
		VisualKind.TREE:
			surface_mode = 1
			weathering = 0.26
		VisualKind.MOSSY_ROCK:
			surface_mode = 2
			weathering = 0.30
		_:
			surface_mode = 0
	surface_material.set_shader_parameter(&"surface_mode", surface_mode)
	surface_material.set_shader_parameter(&"weathering", weathering)
	surface_material.set_shader_parameter(&"texture_scale", 18.0 + float(stable_seed % 11))
	material = surface_material


func _draw() -> void:
	if not _imported_visuals.is_empty():
		_draw_imported_grounding_shadow()
	match visual_kind:
		VisualKind.CITY_BUILDING:
			if not _uses_imported_replacement:
				_draw_city_building()
		VisualKind.MALL_SHELL:
			if _uses_imported_replacement:
				_draw_mall_foundation()
			else:
				_draw_mall_shell()
		VisualKind.VILLAGE_HOUSE:
			if not _uses_imported_replacement:
				_draw_village_house()
		VisualKind.TREE:
			if _imported_visual == null:
				_draw_tree()
		VisualKind.VEHICLE_WRECK:
			if not _uses_imported_replacement:
				_draw_vehicle_wreck()
		VisualKind.WOODEN_FENCE:
			if not _uses_imported_replacement:
				_draw_wooden_fence()
		VisualKind.MOSSY_ROCK:
			if not _uses_imported_replacement:
				_draw_mossy_rock()
		VisualKind.FALLEN_LOG:
			if not _uses_imported_replacement:
				_draw_fallen_log()
		VisualKind.SCRAP_PILE:
			if not _uses_imported_replacement:
				_draw_scrap_pile()
		VisualKind.UTILITY_POLE:
			if not _uses_imported_replacement:
				_draw_utility_pole()
		VisualKind.CAMP_BEDDING, VisualKind.CAMP_SUPPLY_CACHE, VisualKind.CAMP_MEDICAL_CACHE:
			if not _uses_imported_replacement:
				_draw_camp_satellite()


func _draw_city_building() -> void:
	var roof_rect: Rect2 = Rect2(-half_size, half_size * 2.0)
	draw_rect(Rect2(roof_rect.position + Vector2(36.0, 54.0), roof_rect.size), Color(0.01, 0.015, 0.014, 0.52))
	var roof_colors: Array[Color] = [
		Color("3f4947"), Color("4c4b43"), Color("3d454b"), Color("4a443f"), Color("394744")
	]
	var roof_color: Color = roof_colors[stable_seed % roof_colors.size()]
	draw_rect(roof_rect, roof_color)
	draw_rect(roof_rect, Color("111716"), false, 22.0)
	var inset: Rect2 = roof_rect.grow(-74.0)
	if inset.size.x > 0.0 and inset.size.y > 0.0:
		draw_rect(inset, Color("343b3a"))
		draw_rect(inset, Color("9a4528"), false, 12.0)
	for detail_index: int in range(9):
		var detail_position: Vector2 = _detail_position(detail_index, half_size * 0.78)
		var detail_size: Vector2 = Vector2(55.0 + _unit_noise(detail_index + 20) * 95.0, 22.0)
		draw_rect(Rect2(detail_position - detail_size * 0.5, detail_size), Color(0.12, 0.07, 0.045, 0.72))
	_draw_city_roof_variant(roof_rect, stable_seed % 5)
	_draw_cracks(7, Color(0.02, 0.028, 0.027, 0.92))


func _draw_mall_foundation() -> void:
	var shell_rect: Rect2 = Rect2(-half_size, half_size * 2.0)
	draw_rect(
		Rect2(shell_rect.position + MALL_FOUNDATION_SHADOW_OFFSET, shell_rect.size),
		Color(
			GROUND_SHADOW_COLOR.r,
			GROUND_SHADOW_COLOR.g,
			GROUND_SHADOW_COLOR.b,
			MALL_FOUNDATION_SHADOW_ALPHA
		)
	)
	draw_rect(shell_rect, Color("263331"))
	draw_rect(shell_rect, Color("101817"), false, 26.0)
	var inset: Rect2 = shell_rect.grow(-68.0)
	if inset.size.x > 0.0 and inset.size.y > 0.0:
		draw_rect(inset, Color("354440"))
		draw_rect(inset, Color(0.36, 0.50, 0.46, 0.48), false, 11.0)
	var canopy_height: float = minf(150.0, half_size.y * 0.28)
	var canopy: Rect2 = Rect2(
		Vector2(-half_size.x + 54.0, half_size.y * 0.38 - canopy_height * 0.5),
		Vector2(half_size.x * 2.0 - 108.0, canopy_height)
	)
	if canopy.size.x > 0.0 and canopy.size.y > 0.0:
		draw_rect(canopy, Color("59615a"))
		draw_rect(canopy, Color("171e1c"), false, 10.0)
		for brace_index: int in range(7):
			var brace_x: float = lerpf(
				canopy.position.x + 34.0,
				canopy.end.x - 34.0,
				float(brace_index) / 6.0
			)
			draw_line(
				Vector2(brace_x, canopy.position.y),
				Vector2(brace_x, canopy.end.y),
				Color(0.15, 0.21, 0.19, 0.70),
				7.0
			)


func _draw_city_roof_variant(roof_rect: Rect2, variant: int) -> void:
	match variant:
		0:
			for offset_x: float in [-0.28, 0.28]:
				var center: Vector2 = Vector2(half_size.x * offset_x, -half_size.y * 0.18)
				draw_rect(Rect2(center - Vector2(80.0, 55.0), Vector2(160.0, 110.0)), Color("252d2c"), true)
				draw_circle(center, 38.0, Color("69716c"))
		1:
			for panel_index: int in range(4):
				var panel_x: float = lerpf(roof_rect.position.x + 120.0, roof_rect.end.x - 260.0, float(panel_index) / 3.0)
				draw_rect(Rect2(Vector2(panel_x, -80.0), Vector2(170.0, 210.0)), Color("1e4145"), true)
				draw_rect(Rect2(Vector2(panel_x, -80.0), Vector2(170.0, 210.0)), Color("6a8b8a"), false, 7.0)
		2:
			for tank_sign: float in [-1.0, 1.0]:
				var tank_position: Vector2 = Vector2(tank_sign * half_size.x * 0.36, 0.0)
				draw_circle(tank_position, 84.0, Color("5c635e"))
				draw_arc(tank_position, 60.0, 0.0, TAU, 24, Color("202827"), 9.0)
		3:
			var collapse: PackedVector2Array = PackedVector2Array([
				Vector2(roof_rect.end.x - 360.0, roof_rect.position.y),
				Vector2(roof_rect.end.x, roof_rect.position.y),
				Vector2(roof_rect.end.x, roof_rect.position.y + 420.0),
				Vector2(roof_rect.end.x - 210.0, roof_rect.position.y + 290.0),
			])
			draw_colored_polygon(collapse, Color("151b1a"))
		4:
			for planter_index: int in range(3):
				var planter_position: Vector2 = Vector2(-half_size.x * 0.45 + float(planter_index) * half_size.x * 0.45, half_size.y * 0.2)
				draw_rect(Rect2(planter_position - Vector2(120.0, 42.0), Vector2(240.0, 84.0)), Color("55412c"))
				for plant_index: int in range(4):
					draw_circle(planter_position + Vector2(-75.0 + plant_index * 50.0, 0.0), 24.0, Color("49634b"))


func _draw_mall_shell() -> void:
	var shell_rect: Rect2 = Rect2(-half_size, half_size * 2.0)
	draw_rect(Rect2(shell_rect.position + Vector2(42.0, 58.0), shell_rect.size), Color(0.0, 0.01, 0.012, 0.55))
	draw_rect(shell_rect, Color("465457"))
	draw_rect(shell_rect, Color("121b1c"), false, 26.0)
	var glass_band: Rect2 = Rect2(
		Vector2(-half_size.x + 82.0, -half_size.y + 96.0),
		Vector2(maxf(half_size.x * 2.0 - 164.0, 1.0), 132.0)
	)
	draw_rect(glass_band, Color(0.16, 0.46, 0.47, 0.52))
	for pane_index: int in range(1, 8):
		var pane_x: float = lerpf(glass_band.position.x, glass_band.end.x, float(pane_index) / 8.0)
		draw_line(Vector2(pane_x, glass_band.position.y), Vector2(pane_x, glass_band.end.y), Color(0.03, 0.1, 0.11, 0.9), 8.0)
	for shard_index: int in range(6):
		var shard_start: Vector2 = _detail_position(shard_index + 40, half_size * 0.72)
		var shard_end: Vector2 = shard_start + Vector2(80.0, -130.0).rotated(_unit_noise(shard_index + 70) * TAU)
		draw_line(shard_start, shard_end, Color(0.43, 0.83, 0.82, 0.48), 7.0)


func _draw_village_house() -> void:
	var house_rect: Rect2 = Rect2(-half_size, half_size * 2.0)
	draw_rect(Rect2(house_rect.position + Vector2(28.0, 44.0), house_rect.size), Color(0.01, 0.012, 0.009, 0.5))
	var timber_colors: Array[Color] = [Color("5a3d25"), Color("62482e"), Color("4f4130"), Color("5c3524")]
	draw_rect(house_rect, timber_colors[stable_seed % timber_colors.size()])
	draw_rect(house_rect, Color("201912"), false, 18.0)
	var ridge_y: float = -half_size.y * 0.15
	draw_line(Vector2(-half_size.x, ridge_y), Vector2(half_size.x, ridge_y), Color("b46b2f"), 18.0)
	for plank_index: int in range(1, 7):
		var plank_x: float = lerpf(-half_size.x, half_size.x, float(plank_index) / 7.0)
		draw_line(Vector2(plank_x, -half_size.y), Vector2(plank_x, half_size.y), Color(0.12, 0.075, 0.035, 0.58), 7.0)
	var chimney_x: float = -half_size.x * 0.48 if stable_seed % 2 == 0 else half_size.x * 0.48
	draw_rect(Rect2(Vector2(chimney_x - 52.0, -half_size.y - 56.0), Vector2(104.0, 150.0)), Color("3a3028"))
	if stable_seed % 3 == 0:
		draw_rect(Rect2(Vector2(-half_size.x * 0.68, half_size.y * 0.38), Vector2(half_size.x * 1.36, 74.0)), Color("92704b"))
	_draw_cracks(5, Color(0.055, 0.035, 0.02, 0.96))


func _draw_tree() -> void:
	var canopy_radius: float = collision_radius * 2.15
	draw_circle(Vector2(34.0, 48.0), canopy_radius * 0.82, Color(0.0, 0.01, 0.0, 0.48))
	draw_circle(Vector2.ZERO, collision_radius * 0.68, Color("4d2e18"))
	draw_circle(Vector2(-canopy_radius * 0.22, -canopy_radius * 0.08), canopy_radius * 0.72, Color("203a28"))
	draw_circle(Vector2(canopy_radius * 0.29, -canopy_radius * 0.16), canopy_radius * 0.64, Color("294830"))
	draw_circle(Vector2(0.0, -canopy_radius * 0.38), canopy_radius * 0.7, Color("31543a"))
	for branch_index: int in range(7):
		var angle: float = _unit_noise(branch_index + 90) * TAU
		var branch_length: float = canopy_radius * (0.48 + _unit_noise(branch_index + 100) * 0.32)
		draw_line(Vector2.ZERO, Vector2.from_angle(angle) * branch_length, Color(0.09, 0.065, 0.035, 0.72), 12.0)
	draw_arc(Vector2.ZERO, canopy_radius * 0.88, 0.0, TAU, 32, Color("0b1710"), 18.0)


func _draw_vehicle_wreck() -> void:
	var wreck_rect: Rect2 = Rect2(-half_size, half_size * 2.0)
	draw_rect(Rect2(wreck_rect.position + Vector2(24.0, 30.0), wreck_rect.size), Color(0.0, 0.0, 0.0, 0.48))
	draw_rect(wreck_rect, Color("6a3a24"))
	draw_rect(wreck_rect.grow(-38.0), Color("292e2d"))
	draw_rect(wreck_rect, Color("161b1a"), false, 16.0)
	var wheel_radius: float = minf(half_size.y * 0.34, 56.0)
	for wheel_sign: float in [-1.0, 1.0]:
		draw_circle(Vector2(half_size.x * 0.56 * wheel_sign, half_size.y), wheel_radius, Color("0b0e0e"))
		draw_circle(Vector2(half_size.x * 0.56 * wheel_sign, -half_size.y), wheel_radius, Color("0b0e0e"))
	_draw_cracks(4, Color(0.04, 0.055, 0.052, 0.95))


func _draw_wooden_fence() -> void:
	var fence_rect: Rect2 = Rect2(-half_size, half_size * 2.0)
	draw_rect(Rect2(fence_rect.position + Vector2(15.0, 22.0), fence_rect.size), Color(0.0, 0.0, 0.0, 0.44))
	draw_rect(fence_rect, Color("70451f"))
	draw_rect(fence_rect, Color("21150c"), false, 10.0)
	var along_x: bool = half_size.x >= half_size.y
	for post_index: int in range(5):
		var weight: float = float(post_index) / 4.0
		var post_position: Vector2 = Vector2(lerpf(-half_size.x, half_size.x, weight), 0.0) if along_x else Vector2(0.0, lerpf(-half_size.y, half_size.y, weight))
		draw_circle(post_position, 22.0, Color("a16a31"))


func _draw_mossy_rock() -> void:
	var radius: float = collision_radius
	var points: PackedVector2Array = PackedVector2Array()
	for point_index: int in range(10):
		var angle: float = TAU * float(point_index) / 10.0
		var variance: float = 0.8 + _unit_noise(point_index + 130) * 0.28
		points.append(Vector2.from_angle(angle) * radius * variance)
	draw_colored_polygon(points, Color("515b53"))
	draw_polyline(points + PackedVector2Array([points[0]]), Color("151c1a"), 16.0)
	for moss_index: int in range(5):
		var moss_position: Vector2 = _detail_position(moss_index + 150, Vector2.ONE * radius * 0.55)
		draw_circle(moss_position, radius * (0.12 + _unit_noise(moss_index + 160) * 0.12), Color(0.25, 0.42, 0.27, 0.72))


func _draw_fallen_log() -> void:
	var log_rect: Rect2 = Rect2(-half_size, half_size * 2.0)
	draw_rect(Rect2(log_rect.position + Vector2(18.0, 24.0), log_rect.size), Color(0.0, 0.0, 0.0, 0.38))
	draw_rect(log_rect, Color("50331f"))
	draw_rect(log_rect.grow(-18.0), Color("654329"))
	for ring_sign: float in [-1.0, 1.0]:
		var end_position: Vector2 = Vector2(half_size.x * ring_sign, 0.0)
		draw_circle(end_position, half_size.y * 0.8, Color("8a6640"))
		draw_arc(end_position, half_size.y * 0.48, 0.0, TAU, 18, Color("3f2a1b"), 8.0)
	for branch_index: int in range(3):
		var branch_x: float = lerpf(-half_size.x * 0.55, half_size.x * 0.55, float(branch_index) / 2.0)
		draw_line(Vector2(branch_x, 0.0), Vector2(branch_x + 62.0, -half_size.y * 1.3), Color("4a301e"), 22.0)


func _draw_scrap_pile() -> void:
	var radius: float = collision_radius
	draw_circle(Vector2(18.0, 24.0), radius * 0.86, Color(0.0, 0.0, 0.0, 0.4))
	for plate_index: int in range(7):
		var center: Vector2 = _detail_position(plate_index + 310, Vector2.ONE * radius * 0.52)
		var plate_size: Vector2 = Vector2(radius * 0.72, radius * 0.3)
		var plate_color: Color = Color("5d4434") if plate_index % 2 == 0 else Color("4d5955")
		draw_set_transform(center, _unit_noise(plate_index + 330) * TAU, Vector2.ONE)
		draw_rect(Rect2(-plate_size * 0.5, plate_size), plate_color)
		draw_rect(Rect2(-plate_size * 0.5, plate_size), Color("171d1c"), false, 5.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(-radius * 0.18, radius * 0.12), radius * 0.24, Color("202725"), false, 11.0)


func _draw_utility_pole() -> void:
	var radius: float = collision_radius
	draw_circle(Vector2(14.0, 18.0), radius, Color(0.0, 0.0, 0.0, 0.34))
	draw_circle(Vector2.ZERO, radius * 0.72, Color("5c3a22"))
	draw_circle(Vector2.ZERO, radius * 0.38, Color("8b6844"))
	draw_line(Vector2(-radius * 1.45, 0.0), Vector2(radius * 1.45, 0.0), Color("3e4542"), 18.0)
	for insulator_x: float in [-radius, 0.0, radius]:
		draw_circle(Vector2(insulator_x, 0.0), 12.0, Color("6f8d89"))


func _draw_camp_satellite() -> void:
	var footprint: Rect2 = Rect2(-half_size, half_size * 2.0)
	draw_rect(footprint, Color("53604b"))
	draw_rect(footprint, Color("17201b"), false, 8.0)


## The ground contact a single sprite of this family gets, as (width, flatten):
## `width` is the ellipse x radius as a fraction of that sprite's own half width,
## `flatten` is its y radius as a fraction of that x radius. Zero means the family
## draws no contact.
##
## The widths are back-derived from the ellipses this replaced, measured against
## the sprite sizes a runtime probe reported, so a reviewed on-screen footprint
## survives the change of anchor. Where the two disagreed the sprite won: a
## roadside barrier's old ellipse was 1.21x its own pixels wide, and a fence
## segment's was 0.35x, because both were sized from a collision box that has
## nothing to do with the art.
func _contact_profile() -> Vector2:
	match visual_kind:
		VisualKind.CITY_BUILDING:
			return Vector2(0.94, 0.24)
		VisualKind.MALL_SHELL:
			return Vector2(0.97, 0.22)
		VisualKind.VILLAGE_HOUSE:
			return Vector2(0.95, 0.28)
		VisualKind.TREE:
			return Vector2(0.40, 0.52)
		VisualKind.VEHICLE_WRECK:
			return Vector2(0.92, 0.40)
		VisualKind.WOODEN_FENCE:
			return Vector2(0.80, 0.26)
		VisualKind.MOSSY_ROCK:
			return Vector2(0.85, 0.55)
		VisualKind.FALLEN_LOG:
			return Vector2(0.85, 0.28)
		VisualKind.SCRAP_PILE:
			return Vector2(0.78, 0.60)
		VisualKind.UTILITY_POLE:
			return Vector2(0.32, 0.55)
		VisualKind.CAMP_BEDDING, VisualKind.CAMP_SUPPLY_CACHE, VisualKind.CAMP_MEDICAL_CACHE:
			return Vector2(0.68, 0.50)
	return Vector2.ZERO


## One contact per imported sprite, anchored to that sprite's own bottom edge.
##
## Imported assets intentionally contain no baked shadows, so this is where every
## source family is grounded to the same world light. It used to draw one ellipse
## per obstacle, sized from the collision shape, and that was measurably wrong: a
## sprite is scaled from `max(half_size.x, half_size.y)` and then offset, so the
## collision box says nothing about where the pixels end. A probe over every
## imported visual in the world map found 20 of 21 families with their entire
## contact hidden behind their own sprite - the concrete barrier's ellipse bottom
## sat 62.6 units above its sprite's base, which is why the luma under it in
## `artifacts/world_city_barrier_validation.png` was flat to within the terrain's
## own rightward falloff.
##
## Centring exactly on the sprite's bottom edge puts half the ellipse - including
## half the dark core - below the pixels. Any upward bias hides that core again
## and leaves only the 0.055 halo showing, which is about 3 L on asphalt: back
## inside the terrain gradient, and back to not reading.
##
## Per sprite rather than per obstacle, so a fence's segments, a mall's modules
## and a factory block's dressing each get a footprint instead of sharing one slab
## across their union. That is 519 contacts against 461 obstacles, a 13% cost, and
## it stays a per-object `draw_circle` rather than anything resembling the
## full-screen pass CLAUDE.md 10 budgets at one.
##
## Sprite rotation is deliberately ignored. The contact stays axis aligned,
## because a footprint on the ground does not bank when the thing standing on it
## is jittered a few degrees.
func _draw_imported_grounding_shadow() -> void:
	var profile: Vector2 = _contact_profile()
	if profile.x <= 0.0:
		return
	for sprite: Sprite2D in _imported_visuals:
		if sprite == null or sprite.texture == null:
			continue
		var drawn: Vector2 = sprite.texture.get_size() * sprite.scale
		if drawn.x <= 0.0 or drawn.y <= 0.0:
			continue
		var radius_x: float = drawn.x * 0.5 * profile.x
		_draw_soft_grounding_ellipse(
			Vector2(sprite.position.x, sprite.position.y + drawn.y * 0.5),
			Vector2(radius_x, minf(radius_x * profile.y, GroundShadow.MAX_CONTACT_DEPTH))
		)


## Delegates to [GroundShadow] so a prop, a survivor and a background barrier
## share one ladder. This used to author its own three steps peaking at 0.152,
## whose darkest covered 0.72 of the base radius - a broad faint wash rather than
## a contact. The shared ladder puts the same intent at 0.267 and concentrates it
## at 0.38 of the radius, which is what makes an edge to read.
func _draw_soft_grounding_ellipse(center: Vector2, radii: Vector2) -> void:
	GroundShadow.draw_ellipse(self, center, radii, GroundShadow.PROP_STRENGTH)


func _draw_cracks(count: int, color: Color) -> void:
	for crack_index: int in range(count):
		var start: Vector2 = _detail_position(crack_index + 180, half_size * 0.78)
		var direction: Vector2 = Vector2.from_angle(_unit_noise(crack_index + 210) * TAU)
		var end: Vector2 = start + direction * (45.0 + _unit_noise(crack_index + 230) * 120.0)
		draw_line(start, end, color, 9.0)


func _install_imported_visuals() -> void:
	_imported_visuals.clear()
	_uses_imported_replacement = false
	match visual_kind:
		VisualKind.CITY_BUILDING:
			_install_local_city_visual()
		VisualKind.MALL_SHELL:
			_install_local_mall_visuals()
		VisualKind.VILLAGE_HOUSE:
			_install_local_village_visual()
		VisualKind.TREE:
			_install_imported_tree_visual()
		VisualKind.MOSSY_ROCK:
			_install_imported_rock_visual()
		VisualKind.FALLEN_LOG:
			_install_imported_fallen_log_visual()
		VisualKind.SCRAP_PILE:
			_install_imported_scrap_cluster()
		VisualKind.VEHICLE_WRECK:
			_install_imported_vehicle_visual()
		VisualKind.WOODEN_FENCE:
			_install_local_fence_visuals()
		VisualKind.UTILITY_POLE:
			_install_local_utility_pole_visual()
		VisualKind.CAMP_BEDDING:
			_install_local_camp_visual(
				"camp_bedding",
				LOCAL_CAMP_BEDDING_REGION,
				&"ImportedCampBeddingVisual",
				CAMP_BEDDING_VISUAL_WIDTH_FACTOR
			)
		VisualKind.CAMP_SUPPLY_CACHE:
			_install_local_camp_visual(
				"camp_supply_cache",
				LOCAL_CAMP_SUPPLY_REGION,
				&"ImportedCampSupplyVisual",
				CAMP_SUPPLY_VISUAL_WIDTH_FACTOR
			)
		VisualKind.CAMP_MEDICAL_CACHE:
			_install_local_camp_visual(
				"camp_medical_cache",
				LOCAL_CAMP_MEDICAL_REGION,
				&"ImportedCampMedicalVisual",
				CAMP_MEDICAL_VISUAL_WIDTH_FACTOR
			)


func _install_local_city_visual() -> void:
	if name == &"CityBuilding_04" or name == &"CityBuilding_05":
		_install_district_city_visual(name == &"CityBuilding_05")
		return
	var region_index: int = posmod(stable_seed, LOCAL_CITY_REGIONS.size())
	var texture: Texture2D = _get_local_environment_frame(
		"city_ruin_%d" % region_index,
		LOCAL_CITY_REGIONS[region_index]
	)
	if texture == null:
		return
	_imported_visual = _add_environment_sprite(
		&"ImportedLocalCityVisual",
		texture,
		Vector2(0.0, -half_size.y * 0.28),
		half_size.x * 1.88,
		0.0,
		false,
		true
	)
	_uses_imported_replacement = true


func _install_district_city_visual(use_urban_block: bool) -> void:
	var facade_texture: Texture2D = _get_polyhaven_district_frame(
		"urban_apartment_block" if use_urban_block else "factory_block",
		DISTRICT_URBAN_BLOCK_REGION if use_urban_block else DISTRICT_FACTORY_BLOCK_REGION
	)
	if facade_texture == null:
		return
	_imported_visual = _add_environment_sprite(
		&"ImportedDistrictUrbanBlockVisual" if use_urban_block else &"ImportedDistrictFactoryBlockVisual",
		facade_texture,
		Vector2(0.0, -half_size.y * 0.28),
		half_size.x * 1.88,
		0.0,
		false,
		true
	)
	_add_district_aircon(
		Vector2(half_size.x * 0.43, half_size.y * 0.17),
		minf(half_size.x * 0.46, half_size.y * 0.72)
	)
	_uses_imported_replacement = true


func _install_local_mall_visuals() -> void:
	var mall_texture: Texture2D = _get_local_environment_frame(
		"mall_shell",
		LOCAL_MALL_REGION
	)
	var industrial_texture: Texture2D = _get_local_environment_frame(
		"industrial_shell",
		LOCAL_INDUSTRIAL_REGION
	)
	if mall_texture == null or industrial_texture == null:
		return
	var long_shell: bool = half_size.x > half_size.y * 2.0
	if long_shell:
		var module_count: int = 4
		var module_span: float = half_size.x * 2.0 / float(module_count)
		for module_index: int in range(module_count):
			var module_selector: int = posmod(module_index + stable_seed, module_count)
			var module_texture: Texture2D = mall_texture
			var module_name: StringName = StringName("ImportedMallModule_%02d" % module_index)
			match module_selector:
				1:
					module_texture = _get_polyhaven_district_frame(
						"urban_apartment_block",
						DISTRICT_URBAN_BLOCK_REGION
					)
					module_name = StringName(
						"ImportedDistrictUrbanBlockVisual_%02d" % module_index
					)
				2:
					module_texture = industrial_texture
				3:
					module_texture = _get_polyhaven_district_frame(
						"factory_block",
						DISTRICT_FACTORY_BLOCK_REGION
					)
					module_name = StringName(
						"ImportedDistrictFactoryBlockVisual_%02d" % module_index
					)
			if module_texture == null:
				continue
			var module_position: Vector2 = Vector2(
				-half_size.x + module_span * (float(module_index) + 0.5),
				-half_size.y * (0.13 + float(module_index % 2) * 0.05)
			)
			var module: Sprite2D = _add_environment_sprite(
				module_name,
				module_texture,
				module_position,
				module_span * 0.94,
				0.0,
				false,
				true
			)
			if _imported_visual == null:
				_imported_visual = module
		_add_district_aircon(
			Vector2(half_size.x * 0.66, half_size.y * 0.23),
			minf(module_span * 0.34, half_size.y * 0.66)
		)
		var salvage_texture: Texture2D = _get_local_environment_frame(
			"roadside_salvage",
			LOCAL_ROADSIDE_SALVAGE_REGION
		)
		if salvage_texture != null:
			_add_environment_sprite(
				&"ImportedMallSalvageVisual",
				salvage_texture,
				Vector2(half_size.x * 0.70, half_size.y * 0.22),
				minf(module_span * 0.42, half_size.y * 0.70),
				-0.12,
				false,
				true
			)
	else:
		_imported_visual = _add_environment_sprite(
			&"ImportedIndustrialPylonVisual",
			industrial_texture if stable_seed % 2 == 0 else mall_texture,
			Vector2(0.0, -half_size.y * 0.14),
			half_size.x * 1.82,
			0.0,
			false,
			true
		)
	_uses_imported_replacement = not _imported_visuals.is_empty()


func _install_local_village_visual() -> void:
	var west_village: bool = String(name).begins_with("West")
	var texture: Texture2D = _get_local_environment_frame(
		"village_west" if west_village else "village_east",
		LOCAL_VILLAGE_WEST_REGION if west_village else LOCAL_VILLAGE_EAST_REGION
	)
	if texture == null:
		return
	_imported_visual = _add_environment_sprite(
		&"ImportedVillageHouseVisual",
		texture,
		Vector2(0.0, -half_size.y * 0.12),
		half_size.x * 1.56,
		0.0,
		west_village,
		true
	)
	_imported_visual.scale.y *= 0.74 if west_village else 0.62
	_uses_imported_replacement = true


func _install_imported_tree_visual() -> void:
	var region_index: int = stable_seed % WILD_TREE_REGIONS.size()
	var region: Rect2 = WILD_TREE_REGIONS[region_index]
	var texture: Texture2D = _get_polyhaven_wild_frame("tree_%02d" % [region_index], region)
	if texture == null:
		return
	# The span stays collision_radius * 4.35 and the lift stays 1.45, so the
	# canopy occupies the same vertical footprint the retired sheet did and the
	# grounding shadow still meets the trunk. What changes is which edge the span
	# governs: the old frames were square, these are not, and _add_environment_sprite
	# fits the longer edge, so a fir stands tall and narrow instead of being
	# stretched to a square canopy.
	_imported_visual = _add_environment_sprite(
		&"ImportedTreeVisual",
		texture,
		Vector2(0.0, -collision_radius * 1.45),
		collision_radius * 4.35,
		0.0,
		true
	)
	# A self_modulate reaches the shader as entry COLOR, ahead of the grade, so
	# this is a change to what the forest finish is given rather than to what it
	# does. The material stays the shared instance.
	_imported_visual.self_modulate = WILD_TREE_TINT


func _install_imported_rock_visual() -> void:
	var use_stump: bool = stable_seed % 7 == 6
	var region_index: int = stable_seed % POLYHAVEN_MOSS_ROCK_REGIONS.size()
	var texture: Texture2D = _get_polyhaven_frame(
		"forest_stump" if use_stump else "moss_rock_%02d" % [region_index + 1],
		POLYHAVEN_STUMP_REGION if use_stump else POLYHAVEN_MOSS_ROCK_REGIONS[region_index]
	)
	if texture == null:
		return
	var visual_name: StringName = &"ImportedStumpVisual" if use_stump else &"ImportedRockVisual"
	_imported_visual = _add_environment_sprite(
		visual_name,
		texture,
		Vector2(0.0, -collision_radius * 0.08),
		collision_radius * MOSSY_ROCK_VISUAL_SPAN_FACTOR,
		0.0,
		true
	)
	_uses_imported_replacement = true


func _install_imported_fallen_log_visual() -> void:
	var texture: Texture2D = _get_polyhaven_frame(
		"forest_dead_trunk",
		POLYHAVEN_DEAD_TRUNK_REGION
	)
	if texture == null:
		return
	_imported_visual = _add_environment_sprite(
		&"ImportedFallenLogVisual",
		texture,
		Vector2(0.0, -half_size.y * 0.12),
		maxf(half_size.x * 2.0, half_size.y * 2.0) * 1.34,
		0.0,
		true
	)
	_uses_imported_replacement = true


func _install_imported_scrap_cluster() -> void:
	var use_rust: bool = stable_seed % 2 == 0
	var can_texture: Texture2D = _get_polyhaven_frame(
		"city_trash_rust" if use_rust else "city_trash_clean",
		POLYHAVEN_TRASH_RUST_REGION if use_rust else POLYHAVEN_TRASH_CLEAN_REGION
	)
	var tyre_texture: Texture2D = _get_polyhaven_frame(
		"city_tyre",
		POLYHAVEN_OLD_TYRE_REGION
	)
	if can_texture == null or tyre_texture == null:
		return
	_imported_visual = _add_environment_sprite(
		&"ImportedScrapCanVisual",
		can_texture,
		Vector2(-collision_radius * 0.24, -collision_radius * 0.10),
		collision_radius * 2.10,
		-0.16 + _unit_noise(410) * 0.32,
		false
	)
	_add_environment_sprite(
		&"ImportedScrapTyreVisual",
		tyre_texture,
		Vector2(collision_radius * 0.34, collision_radius * 0.24),
		collision_radius * 1.82,
		-0.48 + _unit_noise(411) * 0.96,
		false
	)
	_uses_imported_replacement = true


func _install_imported_vehicle_visual() -> void:
	if name == &"CityVehicleWreck_03" or name == &"EastVillageVehicleWreck":
		var covered_car_texture: Texture2D = _get_polyhaven_district_frame(
			"covered_car",
			DISTRICT_COVERED_CAR_REGION
		)
		if covered_car_texture == null:
			return
		_imported_visual = _add_environment_sprite(
			&"ImportedDistrictCoveredCarVisual",
			covered_car_texture,
			Vector2(0.0, -half_size.y * 0.18),
			half_size.x * VEHICLE_WRECK_VISUAL_WIDTH_FACTOR,
			0.0,
			false,
			true
		)
		_uses_imported_replacement = true
		return
	var variant: int = posmod(stable_seed, 3)
	if name == &"OstariCollapsedTruck":
		variant = 2
	if variant == 0:
		_install_imported_barrier_variant()
		return
	var local_region: Rect2 = (
		LOCAL_ROADSIDE_BARRIER_REGION if variant == 1 else LOCAL_VEHICLE_REGION
	)
	var texture: Texture2D = _get_local_environment_frame(
		"roadside_barrier" if variant == 1 else "vehicle_wreck",
		local_region
	)
	if texture == null:
		return
	_imported_visual = _add_environment_sprite(
		&"ImportedRoadsideBarrierVisual" if variant == 1 else &"ImportedVehicleWreckVisual",
		texture,
		Vector2(0.0, -half_size.y * (0.22 if variant == 1 else 0.18)),
		half_size.x * (
			ROADSIDE_BARRIER_VISUAL_WIDTH_FACTOR
			if variant == 1
			else VEHICLE_WRECK_VISUAL_WIDTH_FACTOR
		),
		0.0,
		false,
		true
	)
	_uses_imported_replacement = true


func _install_imported_barrier_variant() -> void:
	# Two of the six authored wreck footprints become high-contrast roadblocks.
	# Collision, flow blocking, creation order, and authoritative motion stay exact.
	if stable_seed % 3 != 0:
		return
	var texture: Texture2D = _get_polyhaven_frame(
		"city_barrier",
		POLYHAVEN_CONCRETE_BARRIER_REGION
	)
	if texture == null:
		return
	_imported_visual = _add_environment_sprite(
		&"ImportedConcreteBarrierVisual",
		texture,
		Vector2(0.0, -half_size.y * 0.05),
		maxf(half_size.x * 2.0, half_size.y * 2.0) * CONCRETE_BARRIER_VISUAL_SPAN_FACTOR,
		0.0,
		false
	)
	_uses_imported_replacement = true


func _install_local_fence_visuals() -> void:
	var texture: Texture2D = _get_local_environment_frame(
		"wood_barricade",
		LOCAL_WOOD_BARRICADE_REGION
	)
	if texture == null:
		return
	var along_x: bool = half_size.x >= half_size.y
	var long_span: float = half_size.x * 2.0 if along_x else half_size.y * 2.0
	var short_span: float = half_size.y * 2.0 if along_x else half_size.x * 2.0
	var segment_count: int = clampi(ceili(long_span / 430.0), 2, 5)
	var segment_span: float = long_span / float(segment_count)
	var district_center_segment: bool = (
		name == &"EastVillageFence_00" or name == &"EastVillageFence_03"
	)
	var center_segment_index: int = segment_count / 2
	# One seeded phase per fence decides which parity of segment is mirrored,
	# so two fences with the same segment count still differ while every
	# adjacent pair inside one fence is guaranteed to differ.
	var fence_flip_phase: bool = _unit_noise(FENCE_VARIATION_NOISE_BASE) < 0.5
	for segment_index: int in range(segment_count):
		var use_chainlink: bool = district_center_segment and segment_index == center_segment_index
		var segment_texture: Texture2D = texture
		var segment_name: StringName = StringName("ImportedBarricadeSegment_%02d" % segment_index)
		if use_chainlink:
			segment_texture = _get_polyhaven_district_frame(
				"chainlink_gate",
				DISTRICT_CHAINLINK_REGION
			)
			segment_name = StringName(
				"ImportedDistrictChainlinkVisual_%02d" % segment_index
			)
		if segment_texture == null:
			continue
		var along_position: float = (
			-long_span * 0.5 + segment_span * (float(segment_index) + 0.5)
		)
		var sprite_position: Vector2 = (
			Vector2(along_position, -short_span * 0.10)
			if along_x
			else Vector2(0.0, along_position)
		)
		var segment: Sprite2D = _add_environment_sprite(
			segment_name,
			segment_texture,
			sprite_position,
			segment_span * FENCE_SEGMENT_VISUAL_WIDTH_FACTOR,
			0.0 if along_x else PI * 0.5,
			true,
			true
		)
		if not use_chainlink:
			# A row of identical baked segments reads as a stamp. The barricade
			# frame is strongly asymmetric - mirror IoU 0.48 over its own alpha -
			# so mirroring gives a segment a genuinely different silhouette. The
			# flip alternates along the run from a seeded phase rather than being
			# drawn per segment: an independent coin flip leaves all four segments
			# identical on one fence in eight and three identical neighbours on
			# half of them, which a probe over the twelve village fences confirmed
			# (two all-same runs), and that is the stamp this exists to remove.
			# A bounded along-axis slip and a mild size wobble then break the
			# equal-gap cadence without letting neighbours touch. Presentation
			# only: collision, flow mask, stable seed and ordering are untouched,
			# and the height factor survives because the wobble is applied uniformly
			# before it.
			var noise_base: int = FENCE_VARIATION_NOISE_BASE + segment_index * 3
			segment.flip_h = fence_flip_phase != (segment_index % 2 == 1)
			var slip: float = lerpf(
				-FENCE_SEGMENT_SLIP_FACTOR,
				FENCE_SEGMENT_SLIP_FACTOR,
				_unit_noise(noise_base + 1)
			) * segment_span
			segment.position += Vector2(slip, 0.0) if along_x else Vector2(0.0, slip)
			segment.scale *= lerpf(
				1.0 - FENCE_SEGMENT_SIZE_WOBBLE,
				1.0 + FENCE_SEGMENT_SIZE_WOBBLE,
				_unit_noise(noise_base + 2)
			)
		segment.scale.y *= FENCE_SEGMENT_VISUAL_HEIGHT_FACTOR
		if _imported_visual == null:
			_imported_visual = segment
	_uses_imported_replacement = not _imported_visuals.is_empty()


func _install_local_utility_pole_visual() -> void:
	var texture: Texture2D = _get_local_environment_frame(
		"utility_pole",
		LOCAL_UTILITY_POLE_REGION
	)
	if texture == null:
		return
	_imported_visual = _add_environment_sprite(
		&"ImportedUtilityPoleVisual",
		texture,
		Vector2(0.0, collision_radius * UTILITY_POLE_VISUAL_Y_OFFSET_FACTOR),
		collision_radius * UTILITY_POLE_VISUAL_WIDTH_FACTOR,
		0.0,
		true,
		true
	)
	_uses_imported_replacement = true


func _install_local_camp_visual(
	frame_key: String,
	region: Rect2,
	visual_name: StringName,
	width_factor: float
) -> void:
	var texture: Texture2D = _get_local_environment_frame(frame_key, region)
	if texture == null:
		return
	_imported_visual = _add_environment_sprite(
		visual_name,
		texture,
		Vector2(0.0, -half_size.y * 0.14),
		half_size.x * 2.0 * width_factor,
		0.0,
		true,
		true
	)
	if visual_kind == VisualKind.CAMP_BEDDING:
		var bench_texture: Texture2D = _get_polyhaven_district_frame(
			"street_bench",
			DISTRICT_BENCH_REGION
		)
		if bench_texture != null:
			_add_environment_sprite(
				&"ImportedDistrictBenchVisual",
				bench_texture,
				Vector2(half_size.x * 0.30, half_size.y * 0.30),
				half_size.x * 1.34,
				0.04,
				true,
				true
			)
	elif visual_kind == VisualKind.CAMP_SUPPLY_CACHE:
		var stove_texture: Texture2D = _get_polyhaven_district_frame(
			"barrel_stove",
			DISTRICT_BARREL_STOVE_REGION
		)
		if stove_texture != null:
			_add_environment_sprite(
				&"ImportedDistrictBarrelStoveVisual",
				stove_texture,
				Vector2(half_size.x * 0.38, half_size.y * 0.16),
				half_size.x * 0.92,
				-0.05,
				true,
				true
			)
	_uses_imported_replacement = true


func _add_district_aircon(local_position: Vector2, target_width: float) -> void:
	var aircon_texture: Texture2D = _get_polyhaven_district_frame(
		"aircon_cluster",
		DISTRICT_AIRCON_REGION
	)
	if aircon_texture == null:
		return
	_add_environment_sprite(
		&"ImportedDistrictAirconVisual",
		aircon_texture,
		local_position,
		target_width,
		0.0,
		false,
		true
	)


func _add_environment_sprite(
	visual_name: StringName,
	texture: Texture2D,
	local_position: Vector2,
	target_span: float,
	local_rotation: float,
	forest_finish: bool,
	scale_from_width: bool = false
) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = visual_name
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.position = local_position
	sprite.rotation = local_rotation
	var source_span: float = (
		float(texture.get_width())
		if scale_from_width
		else maxf(float(texture.get_width()), float(texture.get_height()))
	)
	sprite.scale = Vector2.ONE * target_span / maxf(source_span, 1.0)
	sprite.material = _get_environment_finish(forest_finish)
	add_child(sprite)
	_imported_visuals.append(sprite)
	return sprite


static func _get_environment_finish(forest_finish: bool) -> ShaderMaterial:
	var cached: ShaderMaterial = _shared_forest_finish if forest_finish else _shared_urban_finish
	if cached != null:
		return cached
	var finish: ShaderMaterial = ShaderMaterial.new()
	finish.shader = SLEEK_SPRITE_SHADER
	finish.set_shader_parameter(
		&"accent_color",
		Color("6b8f78") if forest_finish else Color("a16a3f")
	)
	finish.set_shader_parameter(&"saturation", 0.78 if forest_finish else 0.72)
	# Contrast, lift and tint were solved together against the twenty-three
	# shipped bakes rather than tuned by eye. 1.30 is the knee of the separation
	# curve: below it each contrast step buys 3.5 to 4.2 luma of body-to-ground
	# step, above it 1.0 to 1.2, and the uniform hint_range ends at 1.50 with no
	# headroom left for a later correction.
	finish.set_shader_parameter(&"contrast", 1.30)
	# Lift raises the floor rather than holding anything off it, and the two
	# earlier versions of this comment both had that backwards. A pixel that
	# clips to zero exits at cool_shadow * tint, plus the lift direction at full
	# weight because the lift term is scaled by alpha and alpha is 1.0 inside a
	# body, the whole lerped toward cool_shadow by cohesion. That is one fixed
	# value per family and nine of the twenty-three bakes report it as their own
	# body p10, so it is the darkest thing this grade can produce. At lift 0.000
	# it sits at 7.89, under the 8.4 CLAUDE.md 8 reserves for Void charcoal
	# outlines and cavities; 0.025 moves it to 12.74 and those nine bakes move
	# with it. Deriving the floor at lift 0 and reusing it at 0.025 is what hid
	# this: the lift term vanishes from the algebra at one value and dominates
	# it at the other, so a floor has to be re-derived whenever lift moves.
	finish.set_shader_parameter(&"shadow_lift", 0.025)
	# Off the shader 0.12 default because tint is where that floor sits, so it
	# sets the deep end rather than only colouring it.
	finish.set_shader_parameter(&"shadow_tint", 0.24)
	finish.set_shader_parameter(&"accent_strength", 0.065)
	finish.set_shader_parameter(&"sheen_strength", 0.032)
	finish.set_shader_parameter(&"outline_width", 1.6)
	finish.set_shader_parameter(&"palette_cohesion", 0.10 if forest_finish else 0.12)
	if forest_finish:
		_shared_forest_finish = finish
	else:
		_shared_urban_finish = finish
	return finish


static func _get_polyhaven_frame(frame_key: String, region: Rect2) -> Texture2D:
	if _polyhaven_frame_cache.has(frame_key):
		return _polyhaven_frame_cache[frame_key]
	if _polyhaven_atlas == null:
		_polyhaven_atlas = load(POLYHAVEN_ATLAS_PATH) as Texture2D
	if _polyhaven_atlas == null:
		return null
	var frame: AtlasTexture = AtlasTexture.new()
	frame.atlas = _polyhaven_atlas
	frame.region = region
	frame.filter_clip = true
	_polyhaven_frame_cache[frame_key] = frame
	return frame


static func _get_local_environment_frame(frame_key: String, region: Rect2) -> Texture2D:
	if _local_environment_frame_cache.has(frame_key):
		return _local_environment_frame_cache[frame_key]
	if _local_environment_atlas == null:
		_local_environment_atlas = load(LOCAL_ENVIRONMENT_ATLAS_PATH) as Texture2D
	if _local_environment_atlas == null:
		return null
	var frame: AtlasTexture = AtlasTexture.new()
	frame.atlas = _local_environment_atlas
	frame.region = region
	frame.filter_clip = true
	_local_environment_frame_cache[frame_key] = frame
	return frame


static func _get_polyhaven_district_frame(frame_key: String, region: Rect2) -> Texture2D:
	if _polyhaven_district_frame_cache.has(frame_key):
		return _polyhaven_district_frame_cache[frame_key]
	if _polyhaven_district_atlas == null:
		_polyhaven_district_atlas = load(POLYHAVEN_DISTRICT_ATLAS_PATH) as Texture2D
	if _polyhaven_district_atlas == null:
		return null
	var frame: AtlasTexture = AtlasTexture.new()
	frame.atlas = _polyhaven_district_atlas
	frame.region = region
	frame.filter_clip = true
	_polyhaven_district_frame_cache[frame_key] = frame
	return frame


static func _get_polyhaven_wild_frame(frame_key: String, region: Rect2) -> Texture2D:
	if _polyhaven_wild_frame_cache.has(frame_key):
		return _polyhaven_wild_frame_cache[frame_key]
	if _polyhaven_wild_atlas == null:
		_polyhaven_wild_atlas = load(POLYHAVEN_WILD_ATLAS_PATH) as Texture2D
	if _polyhaven_wild_atlas == null:
		return null
	var frame: AtlasTexture = AtlasTexture.new()
	frame.atlas = _polyhaven_wild_atlas
	frame.region = region
	frame.filter_clip = true
	_polyhaven_wild_frame_cache[frame_key] = frame
	return frame


func _detail_position(index: int, extent: Vector2) -> Vector2:
	return Vector2(
		lerpf(-extent.x, extent.x, _unit_noise(index * 2 + 1)),
		lerpf(-extent.y, extent.y, _unit_noise(index * 2 + 2))
	)


func _unit_noise(index: int) -> float:
	var value: float = sin(float(stable_seed * 131 + index * 977) * 0.0174533) * 43758.5453
	return value - floorf(value)
