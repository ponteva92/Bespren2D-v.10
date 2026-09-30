class_name TacticalMinimap
extends Control
## Interactive shared-exploration overview with Base, players, defenses, and resource markers.

signal world_ping_requested(world_position: Vector2)

const DEFAULT_WORLD_RECT: Rect2 = Rect2(Vector2(-14336.0, -14336.0), Vector2(28672.0, 28672.0))
const REVEAL_COLUMNS: int = 14
const REVEAL_ROWS: int = 14
const REVEAL_RADIUS_CELLS: int = 1
const RESOURCE_MARKER_RADIUS: float = 1.25

var _world_rect: Rect2 = DEFAULT_WORLD_RECT
var _base_position: Vector2 = Vector2.ZERO
var _player_positions: PackedVector2Array = PackedVector2Array()
var _structure_positions: PackedVector2Array = PackedVector2Array()
var _resource_positions: PackedVector2Array = PackedVector2Array()
var _resource_kinds: PackedInt32Array = PackedInt32Array()
var _revealed_cells: PackedByteArray = PackedByteArray()
var _ping_position: Vector2 = Vector2.ZERO
var _has_ping: bool = false
var _ping_phase: float = 0.0
var _road_routes: Array[PackedVector2Array] = []
var _road_dirt: PackedByteArray = PackedByteArray()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	gui_input.connect(_on_gui_input)
	_ensure_reveal_storage()
	queue_redraw()
	set_process(true)


func _process(delta: float) -> void:
	if not _has_ping:
		return
	_ping_phase = fmod(_ping_phase + maxf(delta, 0.0) * 1.8, 1.0)
	queue_redraw()


func configure_world_rect(world_rect: Rect2) -> void:
	if world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
		return
	_world_rect = world_rect
	reset_exploration()


func reset_exploration() -> void:
	_ensure_reveal_storage()
	_revealed_cells.fill(0)
	_reveal_player_positions()
	queue_redraw()


func set_road_network(
	routes: Array[PackedVector2Array],
	dirt_flags: PackedByteArray
) -> void:
	_road_routes.clear()
	for route: PackedVector2Array in routes:
		_road_routes.append(route.duplicate())
	_road_dirt = dirt_flags.duplicate()
	queue_redraw()


func get_road_route_count() -> int:
	return _road_routes.size()


func set_tactical_state(
	base_position: Vector2,
	player_positions: PackedVector2Array,
	structure_positions: PackedVector2Array,
	resource_positions: PackedVector2Array,
	resource_kinds: PackedInt32Array
) -> void:
	_base_position = base_position
	_player_positions = player_positions.duplicate()
	_structure_positions = structure_positions.duplicate()
	_resource_positions = resource_positions.duplicate()
	_resource_kinds = resource_kinds.duplicate()
	_reveal_player_positions()
	queue_redraw()


func get_last_ping_position() -> Vector2:
	return _ping_position


func get_revealed_cell_count() -> int:
	var count: int = 0
	for revealed: int in _revealed_cells:
		if revealed != 0:
			count += 1
	return count


func is_world_position_revealed(world_position: Vector2) -> bool:
	var cell: Vector2i = _world_to_reveal_cell(world_position)
	return _is_cell_revealed(cell)


func get_visible_resource_marker_count() -> int:
	var visible_count: int = 0
	var marker_count: int = mini(_resource_positions.size(), _resource_kinds.size())
	for resource_index: int in range(marker_count):
		if is_world_position_revealed(_resource_positions[resource_index]):
			visible_count += 1
	return visible_count


func world_to_minimap(world_position: Vector2) -> Vector2:
	var normalized: Vector2 = Vector2(
		inverse_lerp(_world_rect.position.x, _world_rect.end.x, world_position.x),
		inverse_lerp(_world_rect.position.y, _world_rect.end.y, world_position.y)
	)
	return Vector2(normalized.x * size.x, normalized.y * size.y)


func minimap_to_world(local_position: Vector2) -> Vector2:
	var normalized: Vector2 = Vector2(
		clampf(local_position.x / maxf(size.x, 1.0), 0.0, 1.0),
		clampf(local_position.y / maxf(size.y, 1.0), 0.0, 1.0)
	)
	return Vector2(
		lerpf(_world_rect.position.x, _world_rect.end.x, normalized.x),
		lerpf(_world_rect.position.y, _world_rect.end.y, normalized.y)
	)


func _on_gui_input(event: InputEvent) -> void:
	var activated: bool = false
	var local_position: Vector2 = Vector2.ZERO
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			local_position = get_global_transform_with_canvas().affine_inverse() * mouse_button.position
			activated = true
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			local_position = get_global_transform_with_canvas().affine_inverse() * touch.position
			activated = true
	if not activated:
		return
	var requested_ping: Vector2 = minimap_to_world(local_position)
	if not is_world_position_revealed(requested_ping):
		accept_event()
		return
	_ping_position = requested_ping
	_has_ping = true
	_ping_phase = 0.0
	queue_redraw()
	world_ping_requested.emit(_ping_position)
	accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.038, 0.034, 0.94), true)
	_draw_world_topology()
	_draw_exploration_fog()
	draw_rect(Rect2(Vector2.ZERO, size), Color("a9793f"), false, 1.0)
	for structure_position: Vector2 in _structure_positions:
		if is_world_position_revealed(structure_position):
			draw_rect(
				Rect2(world_to_minimap(structure_position) - Vector2.ONE, Vector2.ONE * 2.0),
				Color("72a996"),
				true
			)
	_draw_resource_markers()
	if is_world_position_revealed(_base_position):
		var base_local: Vector2 = world_to_minimap(_base_position)
		draw_circle(base_local, 2.7, Color("d89b4d"))
		draw_circle(base_local, 4.1, Color("d89b4d"), false, 1.0, true)
	for player_index: int in range(_player_positions.size()):
		var player_position: Vector2 = _player_positions[player_index]
		if not is_world_position_revealed(player_position):
			continue
		var player_color: Color = Color("d9b55e") if player_index == 0 else Color("67aeb0")
		draw_circle(world_to_minimap(player_position), 2.2, player_color)
	if _has_ping and is_world_position_revealed(_ping_position):
		var ping_local: Vector2 = world_to_minimap(_ping_position)
		var ping_radius: float = lerpf(2.0, 7.0, _ping_phase)
		draw_circle(ping_local, ping_radius, Color(0.88, 0.84, 0.68, 1.0 - _ping_phase), false, 1.0, true)


func _draw_world_topology() -> void:
	if _road_routes.is_empty():
		return
	for route_index: int in range(_road_routes.size()):
		var route: PackedVector2Array = _road_routes[route_index]
		var is_dirt: bool = route_index < _road_dirt.size() and _road_dirt[route_index] == 1
		var road_color: Color = Color("8a6240") if is_dirt else Color("6e736c")
		for point_index: int in range(route.size() - 1):
			draw_line(
				world_to_minimap(route[point_index]),
				world_to_minimap(route[point_index + 1]),
				road_color,
				1.6 if is_dirt else 2.0
			)


func _draw_exploration_fog() -> void:
	var cell_size: Vector2 = _get_reveal_cell_size()
	for cell_y: int in range(REVEAL_ROWS):
		for cell_x: int in range(REVEAL_COLUMNS):
			var cell: Vector2i = Vector2i(cell_x, cell_y)
			var cell_rect: Rect2 = Rect2(Vector2(cell) * cell_size, cell_size)
			if _is_cell_revealed(cell):
				draw_rect(cell_rect.grow(-0.35), Color(0.45, 0.72, 0.59, 0.12), false, 0.7)
			else:
				draw_rect(cell_rect.grow(-0.15), Color(0.008, 0.016, 0.013, 0.96), true)


func _draw_resource_markers() -> void:
	var marker_count: int = mini(_resource_positions.size(), _resource_kinds.size())
	for resource_index: int in range(marker_count):
		var resource_position: Vector2 = _resource_positions[resource_index]
		if not is_world_position_revealed(resource_position):
			continue
		var marker_position: Vector2 = world_to_minimap(resource_position)
		var marker_color: Color = _resource_color(_resource_kinds[resource_index])
		draw_circle(marker_position, RESOURCE_MARKER_RADIUS + 0.55, Color(0.01, 0.02, 0.018, 0.9))
		draw_circle(marker_position, RESOURCE_MARKER_RADIUS, marker_color)


func _resource_color(resource_kind: int) -> Color:
	match resource_kind:
		0:
			return Color("d9b55e")
		1:
			return Color("b9c4c5")
		2:
			return Color("5ed5bc")
		_:
			return Color("d5ded7")


func _reveal_player_positions() -> void:
	for player_position: Vector2 in _player_positions:
		_reveal_world_position(player_position)


func _reveal_world_position(world_position: Vector2) -> void:
	var center_cell: Vector2i = _world_to_reveal_cell(world_position)
	if center_cell.x < 0 or center_cell.y < 0:
		return
	_ensure_reveal_storage()
	for offset_y: int in range(-REVEAL_RADIUS_CELLS, REVEAL_RADIUS_CELLS + 1):
		for offset_x: int in range(-REVEAL_RADIUS_CELLS, REVEAL_RADIUS_CELLS + 1):
			var reveal_cell: Vector2i = center_cell + Vector2i(offset_x, offset_y)
			if (
				reveal_cell.x < 0
				or reveal_cell.x >= REVEAL_COLUMNS
				or reveal_cell.y < 0
				or reveal_cell.y >= REVEAL_ROWS
			):
				continue
			_revealed_cells[_reveal_index(reveal_cell)] = 1


func _world_to_reveal_cell(world_position: Vector2) -> Vector2i:
	if not world_position.is_finite() or not _world_rect.has_point(world_position):
		return Vector2i(-1, -1)
	var normalized_x: float = inverse_lerp(
		_world_rect.position.x,
		_world_rect.end.x,
		world_position.x
	)
	var normalized_y: float = inverse_lerp(
		_world_rect.position.y,
		_world_rect.end.y,
		world_position.y
	)
	return Vector2i(
		clampi(floori(normalized_x * float(REVEAL_COLUMNS)), 0, REVEAL_COLUMNS - 1),
		clampi(floori(normalized_y * float(REVEAL_ROWS)), 0, REVEAL_ROWS - 1)
	)


func _is_cell_revealed(cell: Vector2i) -> bool:
	if (
		cell.x < 0
		or cell.x >= REVEAL_COLUMNS
		or cell.y < 0
		or cell.y >= REVEAL_ROWS
	):
		return false
	_ensure_reveal_storage()
	return _revealed_cells[_reveal_index(cell)] != 0


func _reveal_index(cell: Vector2i) -> int:
	return cell.y * REVEAL_COLUMNS + cell.x


func _ensure_reveal_storage() -> void:
	var required_size: int = REVEAL_COLUMNS * REVEAL_ROWS
	if _revealed_cells.size() == required_size:
		return
	_revealed_cells.resize(required_size)
	_revealed_cells.fill(0)


func _get_reveal_cell_size() -> Vector2:
	return Vector2(
		size.x / float(REVEAL_COLUMNS),
		size.y / float(REVEAL_ROWS)
	)
