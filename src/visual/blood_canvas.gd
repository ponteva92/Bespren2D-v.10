class_name BloodCanvas
extends MultiMeshInstance2D
## One GPU-batched decal canvas; stamping never allocates scene nodes.

const MAX_DECALS: int = 160
const DECAL_TEXTURE: Texture2D = preload("res://assets/2d/effects/radial_light_neutral.svg")

var _next_decal_index: int = 0
var _decal_count: int = 0


func _ready() -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(38.0, 24.0)
	var instances: MultiMesh = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_2D
	instances.use_colors = true
	instances.instance_count = MAX_DECALS
	instances.visible_instance_count = 0
	instances.mesh = quad
	multimesh = instances
	texture = DECAL_TEXTURE
	z_index = 1
	z_as_relative = false


func stamp(world_position: Vector2, size: float = 1.0, seed: int = 0) -> void:
	if multimesh == null or not world_position.is_finite():
		return
	var safe_size: float = clampf(size, 0.45, 3.2)
	var rotation_radians: float = float(posmod(seed * 37, 360)) * PI / 180.0
	var transform: Transform2D = Transform2D(
		rotation_radians,
		Vector2(safe_size, safe_size * 0.72),
		0.0,
		world_position
	)
	multimesh.set_instance_transform_2d(_next_decal_index, transform)
	multimesh.set_instance_color(
		_next_decal_index,
		Color(0.25 + float(posmod(seed, 5)) * 0.025, 0.012, 0.025, 0.78)
	)
	_next_decal_index = (_next_decal_index + 1) % MAX_DECALS
	_decal_count = mini(_decal_count + 1, MAX_DECALS)
	multimesh.visible_instance_count = _decal_count


func clear_decals() -> void:
	_next_decal_index = 0
	_decal_count = 0
	if multimesh != null:
		multimesh.visible_instance_count = 0


func get_decal_count() -> int:
	return _decal_count


func get_capacity() -> int:
	return MAX_DECALS
