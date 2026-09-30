class_name WorldWildernessAccentChunk2D
extends Node2D
## Bounded custom-draw batches for low-profile wilderness rock strata.

const WILDERNESS_ACCENT_Z: int = -5
const SLEEK_CANVAS_SHADER: Shader = preload("res://shaders/sleek_canvas_grade.gdshader")
const POLYHAVEN_ATLAS: Texture2D = preload(
	"res://assets/2d/environment/polyhaven/polyhaven_environment_atlas.png"
)
const POLYHAVEN_MOSS_ROCK_REGIONS: Array[Rect2] = [
	Rect2(856.0, 72.0, 207.0, 251.0),
	Rect2(1257.0, 89.0, 144.0, 249.0),
	Rect2(9.0, 469.0, 318.0, 243.0),
	Rect2(449.0, 439.0, 269.0, 244.0),
	Rect2(844.0, 459.0, 256.0, 207.0),
	Rect2(1240.0, 461.0, 234.0, 237.0),
]

enum AccentRecipe {
	MOSS_NEST,
	LOW_OUTCROP,
	STONE_RIBBON,
	LICHEN_SCATTER,
}

static var _shared_sleek_material: ShaderMaterial

var _positions: PackedVector2Array = PackedVector2Array()
var _spans: PackedFloat32Array = PackedFloat32Array()
var _rotations: PackedFloat32Array = PackedFloat32Array()
var _recipes: PackedInt32Array = PackedInt32Array()
var _variants: PackedInt32Array = PackedInt32Array()
var _world_render_bounds: Rect2 = Rect2()
var _has_bounds: bool = false


func _ready() -> void:
	z_index = WILDERNESS_ACCENT_Z
	z_as_relative = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material = _get_sleek_material()


static func _get_sleek_material() -> ShaderMaterial:
	if _shared_sleek_material == null:
		_shared_sleek_material = ShaderMaterial.new()
		_shared_sleek_material.shader = SLEEK_CANVAS_SHADER
	return _shared_sleek_material


func configure_origin(world_origin: Vector2) -> void:
	position = world_origin
	z_index = WILDERNESS_ACCENT_Z
	z_as_relative = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material = _get_sleek_material()


func add_anchor(
	world_position: Vector2,
	span: float,
	anchor_rotation: float,
	recipe: int,
	variant: int
) -> void:
	_positions.append(world_position - position)
	_spans.append(span)
	_rotations.append(anchor_rotation)
	_recipes.append(recipe)
	_variants.append(variant)
	_include_world_area(world_position, span * 0.90 + 38.0)


func seal() -> void:
	queue_redraw()


func get_anchor_count() -> int:
	return _positions.size()


func get_frame_count() -> int:
	var count: int = 0
	for recipe: int in _recipes:
		match recipe:
			AccentRecipe.LOW_OUTCROP:
				count += 4
			AccentRecipe.LICHEN_SCATTER:
				count += 2
			_:
				count += 3
	return count


func get_world_render_bounds() -> Rect2:
	return _world_render_bounds


func get_source_texture() -> Texture2D:
	return POLYHAVEN_ATLAS


func _draw() -> void:
	for anchor_index: int in range(_positions.size()):
		draw_set_transform(
			_positions[anchor_index],
			_rotations[anchor_index],
			Vector2.ONE
		)
		match _recipes[anchor_index]:
			AccentRecipe.MOSS_NEST:
				_draw_moss_nest(_spans[anchor_index], _variants[anchor_index])
			AccentRecipe.LOW_OUTCROP:
				_draw_low_outcrop(_spans[anchor_index], _variants[anchor_index])
			AccentRecipe.STONE_RIBBON:
				_draw_stone_ribbon(_spans[anchor_index], _variants[anchor_index])
			AccentRecipe.LICHEN_SCATTER:
				_draw_lichen_scatter(_spans[anchor_index], _variants[anchor_index])
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_moss_nest(target_span: float, variant: int) -> void:
	_draw_rock(
		target_span * 0.76,
		variant,
		Vector2(-target_span * 0.13, target_span * 0.04),
		Color(0.63, 0.76, 0.60, 0.72)
	)
	_draw_rock(
		target_span * 0.46,
		variant + 2,
		Vector2(target_span * 0.24, target_span * 0.17),
		Color(0.50, 0.66, 0.48, 0.66)
	)
	_draw_rock(
		target_span * 0.34,
		variant + 4,
		Vector2(-target_span * 0.31, target_span * 0.23),
		Color(0.68, 0.77, 0.61, 0.58)
	)


func _draw_low_outcrop(target_span: float, variant: int) -> void:
	_draw_rock(
		target_span * 0.82,
		variant,
		Vector2(-target_span * 0.13, target_span * 0.02),
		Color(0.68, 0.75, 0.64, 0.74)
	)
	_draw_rock(
		target_span * 0.48,
		variant + 1,
		Vector2(target_span * 0.25, target_span * 0.20),
		Color(0.54, 0.64, 0.55, 0.66)
	)
	_draw_rock(
		target_span * 0.36,
		variant + 3,
		Vector2(-target_span * 0.34, target_span * 0.24),
		Color(0.61, 0.71, 0.56, 0.58)
	)
	_draw_rock(
		target_span * 0.24,
		variant + 5,
		Vector2(target_span * 0.38, target_span * 0.28),
		Color(0.72, 0.79, 0.65, 0.50)
	)


func _draw_stone_ribbon(target_span: float, variant: int) -> void:
	_draw_rock(
		target_span * 0.50,
		variant,
		Vector2(-target_span * 0.34, target_span * 0.05),
		Color(0.58, 0.69, 0.54, 0.62)
	)
	_draw_rock(
		target_span * 0.68,
		variant + 2,
		Vector2(0.0, -target_span * 0.06),
		Color(0.69, 0.77, 0.63, 0.73)
	)
	_draw_rock(
		target_span * 0.42,
		variant + 4,
		Vector2(target_span * 0.36, target_span * 0.16),
		Color(0.50, 0.62, 0.48, 0.60)
	)


func _draw_lichen_scatter(target_span: float, variant: int) -> void:
	_draw_rock(
		target_span * 0.58,
		variant + 1,
		Vector2(-target_span * 0.18, target_span * 0.02),
		Color(0.73, 0.80, 0.65, 0.58)
	)
	_draw_rock(
		target_span * 0.36,
		variant + 4,
		Vector2(target_span * 0.28, target_span * 0.17),
		Color(0.54, 0.68, 0.50, 0.52)
	)


func _draw_rock(target_span: float, variant: int, local_offset: Vector2, tint: Color) -> void:
	var region: Rect2 = POLYHAVEN_MOSS_ROCK_REGIONS[
		posmod(variant, POLYHAVEN_MOSS_ROCK_REGIONS.size())
	]
	var source_span: float = maxf(region.size.x, region.size.y)
	var destination_size: Vector2 = region.size * target_span / maxf(source_span, 1.0)
	draw_texture_rect_region(
		POLYHAVEN_ATLAS,
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
