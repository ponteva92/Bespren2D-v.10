class_name FlowFieldNavigation2D
extends Node
## Deterministic mobile flow field targeting the active Main Base.

signal field_rebuilt(revision: int, target_position: Vector2)

const UNREACHABLE_COST: int = 0x3FFFFFFF
const BASE_APPROACH_RADIUS: float = 420.0
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.UP,
]
const ALL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i(1, 1),
	Vector2i.DOWN,
	Vector2i(-1, 1),
	Vector2i.LEFT,
	Vector2i(-1, -1),
	Vector2i.UP,
	Vector2i(1, -1),
]

@export_node_path("BesprenWorldMap2D") var world_map_path: NodePath

var _world_map: BesprenWorldMap2D
var _target_position: Vector2 = Vector2.ZERO
var _integration: PackedInt32Array = PackedInt32Array()
var _directions: PackedVector2Array = PackedVector2Array()
var _dynamic_blocked: PackedByteArray = PackedByteArray()
var _revision: int = 0
var _reachable_count: int = 0


func _ready() -> void:
	_world_map = get_node_or_null(world_map_path) as BesprenWorldMap2D
	if is_instance_valid(_world_map):
		_world_map.ensure_built()
		rebuild(_world_map.get_core_position(), [])


func rebuild(
	target_position: Vector2,
	structures: Array[PlacedStructure2D]
) -> void:
	if not is_instance_valid(_world_map) or not target_position.is_finite():
		return
	_target_position = target_position
	var dimensions: Vector2i = _world_map.get_flow_field_dimensions()
	var cell_count: int = dimensions.x * dimensions.y
	_integration.resize(cell_count)
	_integration.fill(UNREACHABLE_COST)
	_directions.resize(cell_count)
	_directions.fill(Vector2.ZERO)
	_dynamic_blocked.resize(cell_count)
	_dynamic_blocked.fill(0)
	_rasterize_dynamic_structures(structures, dimensions)
	var goals: Array[Vector2i] = _find_goal_cells(dimensions)
	_build_integration(goals, dimensions)
	_build_directions(dimensions)
	_revision += 1
	field_rebuilt.emit(_revision, _target_position)


func get_direction(world_position: Vector2) -> Vector2:
	if not is_instance_valid(_world_map) or not world_position.is_finite():
		return Vector2.ZERO
	var to_target: Vector2 = _target_position - world_position
	if to_target.length_squared() <= BASE_APPROACH_RADIUS * BASE_APPROACH_RADIUS:
		return to_target.normalized() if not to_target.is_zero_approx() else Vector2.ZERO
	var cell: Vector2i = _world_map.world_to_flow_cell(world_position)
	var dimensions: Vector2i = _world_map.get_flow_field_dimensions()
	if not _is_valid_cell(cell, dimensions):
		return to_target.normalized() if not to_target.is_zero_approx() else Vector2.ZERO
	var direction: Vector2 = _directions[_cell_index(cell, dimensions)]
	if direction.is_zero_approx() and not to_target.is_zero_approx():
		return to_target.normalized()
	return direction


func get_integration_cost(world_position: Vector2) -> int:
	if not is_instance_valid(_world_map):
		return UNREACHABLE_COST
	var dimensions: Vector2i = _world_map.get_flow_field_dimensions()
	var cell: Vector2i = _world_map.world_to_flow_cell(world_position)
	if not _is_valid_cell(cell, dimensions):
		return UNREACHABLE_COST
	return _integration[_cell_index(cell, dimensions)]


func get_target_position() -> Vector2:
	return _target_position


func get_revision() -> int:
	return _revision


func get_reachable_count() -> int:
	return _reachable_count


func is_cell_dynamically_blocked(cell: Vector2i) -> bool:
	if not is_instance_valid(_world_map):
		return true
	var dimensions: Vector2i = _world_map.get_flow_field_dimensions()
	if not _is_valid_cell(cell, dimensions):
		return true
	return _dynamic_blocked[_cell_index(cell, dimensions)] != 0


func _rasterize_dynamic_structures(
	structures: Array[PlacedStructure2D],
	dimensions: Vector2i
) -> void:
	for structure: PlacedStructure2D in structures:
		if not is_instance_valid(structure) or not structure.blocks_navigation():
			continue
		var radius: float = (
			structure.get_clearance_radius()
			+ BesprenWorldMap2D.FLOW_FIELD_RASTER_CLEARANCE
		)
		var minimum: Vector2i = _world_map.world_to_flow_cell(
			structure.global_position - Vector2.ONE * radius
		)
		var maximum: Vector2i = _world_map.world_to_flow_cell(
			structure.global_position + Vector2.ONE * radius
		)
		for cell_y: int in range(
			clampi(minimum.y, 0, dimensions.y - 1),
			clampi(maximum.y, 0, dimensions.y - 1) + 1
		):
			for cell_x: int in range(
				clampi(minimum.x, 0, dimensions.x - 1),
				clampi(maximum.x, 0, dimensions.x - 1) + 1
			):
				var cell: Vector2i = Vector2i(cell_x, cell_y)
				if _world_map.flow_cell_to_world(cell).distance_squared_to(
					structure.global_position
				) <= radius * radius:
					_dynamic_blocked[_cell_index(cell, dimensions)] = 1


func _find_goal_cells(dimensions: Vector2i) -> Array[Vector2i]:
	var target_cell: Vector2i = _world_map.world_to_flow_cell(_target_position)
	target_cell.x = clampi(target_cell.x, 0, dimensions.x - 1)
	target_cell.y = clampi(target_cell.y, 0, dimensions.y - 1)
	for radius: int in range(0, 7):
		var candidates: Array[Vector2i] = []
		for offset_y: int in range(-radius, radius + 1):
			for offset_x: int in range(-radius, radius + 1):
				if maxi(absi(offset_x), absi(offset_y)) != radius:
					continue
				var cell: Vector2i = target_cell + Vector2i(offset_x, offset_y)
				if _is_walkable_cell(cell, dimensions):
					candidates.append(cell)
		if not candidates.is_empty():
			return candidates
	return [target_cell]


func _build_integration(goals: Array[Vector2i], dimensions: Vector2i) -> void:
	var frontier: Array[Vector2i] = []
	for goal: Vector2i in goals:
		var goal_index: int = _cell_index(goal, dimensions)
		_integration[goal_index] = 0
		frontier.append(goal)
	var head: int = 0
	while head < frontier.size():
		var current: Vector2i = frontier[head]
		head += 1
		var current_cost: int = _integration[_cell_index(current, dimensions)]
		for offset: Vector2i in CARDINAL_DIRECTIONS:
			var neighbor: Vector2i = current + offset
			if not _is_walkable_cell(neighbor, dimensions):
				continue
			var neighbor_index: int = _cell_index(neighbor, dimensions)
			if _integration[neighbor_index] <= current_cost + 1:
				continue
			_integration[neighbor_index] = current_cost + 1
			frontier.append(neighbor)
	_reachable_count = frontier.size()


func _build_directions(dimensions: Vector2i) -> void:
	for cell_y: int in range(dimensions.y):
		for cell_x: int in range(dimensions.x):
			var cell: Vector2i = Vector2i(cell_x, cell_y)
			var index: int = _cell_index(cell, dimensions)
			if _integration[index] == UNREACHABLE_COST:
				continue
			var best_cost: int = _integration[index]
			var best_direction: Vector2 = Vector2.ZERO
			for offset: Vector2i in ALL_DIRECTIONS:
				var neighbor: Vector2i = cell + offset
				if not _is_walkable_cell(neighbor, dimensions):
					continue
				if offset.x != 0 and offset.y != 0:
					if (
						not _is_walkable_cell(cell + Vector2i(offset.x, 0), dimensions)
						or not _is_walkable_cell(cell + Vector2i(0, offset.y), dimensions)
					):
						continue
				var neighbor_cost: int = _integration[_cell_index(neighbor, dimensions)]
				if neighbor_cost < best_cost:
					best_cost = neighbor_cost
					best_direction = Vector2(offset).normalized()
			_directions[index] = best_direction


func _is_walkable_cell(cell: Vector2i, dimensions: Vector2i) -> bool:
	if not _is_valid_cell(cell, dimensions):
		return false
	var index: int = _cell_index(cell, dimensions)
	return not _world_map.is_flow_cell_blocked(cell) and _dynamic_blocked[index] == 0


func _is_valid_cell(cell: Vector2i, dimensions: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < dimensions.x and cell.y < dimensions.y


func _cell_index(cell: Vector2i, dimensions: Vector2i) -> int:
	return cell.y * dimensions.x + cell.x
