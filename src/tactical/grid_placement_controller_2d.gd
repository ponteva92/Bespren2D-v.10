class_name GridPlacementController2D
extends Node2D
## Touch-safe 2D viewport projection with immediate 64px X/Y grid confirmation.

signal placement_confirmed(mode: int, structure_id: StringName, world_position: Vector2)
signal placement_mode_changed(active: bool, mode: int, structure_id: StringName)

enum PlacementMode {
	NONE,
	STRUCTURE,
	BASE,
}

const GRID_SIZE: float = 64.0

var _mode: PlacementMode = PlacementMode.NONE
var _structure_id: StringName = &""
var _candidate_position: Vector2 = Vector2.ZERO
var _preview_query: Callable = Callable()
var _preview_valid: bool = true


func _ready() -> void:
	z_index = 60
	z_as_relative = false
	visible = false
	set_process_unhandled_input(true)


func _process(_delta: float) -> void:
	if _mode == PlacementMode.NONE:
		return
	# Mouse preview uses Godot's native Camera2D-aware 2D projection.
	_candidate_position = snap_world_position(get_global_mouse_position())
	global_position = _candidate_position
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _mode == PlacementMode.NONE:
		return
	var should_confirm: bool = false
	var world_position: Vector2 = Vector2.ZERO
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			world_position = get_global_mouse_position()
			should_confirm = true
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			# Touch coordinates are projected only through the active 2D canvas transform.
			world_position = get_canvas_transform().affine_inverse() * touch.position
			should_confirm = true
	if not should_confirm:
		return
	var confirmed_mode: PlacementMode = _mode
	var confirmed_id: StringName = _structure_id
	var snapped_position: Vector2 = snap_world_position(world_position)
	cancel()
	placement_confirmed.emit(confirmed_mode, confirmed_id, snapped_position)
	get_viewport().set_input_as_handled()


func set_preview_query(query: Callable) -> void:
	_preview_query = query


func get_preview_footprint() -> Vector2:
	if _mode != PlacementMode.STRUCTURE:
		return Vector2(GRID_SIZE, GRID_SIZE)
	var definition: StructureDefinition = StructureCatalog.get_definition(_structure_id)
	if definition == null:
		return Vector2(GRID_SIZE, GRID_SIZE)
	return Vector2(definition.footprint_cells) * GRID_SIZE


func is_preview_valid() -> bool:
	return _preview_valid


func arm_structure(structure_id: StringName) -> void:
	if not StructureCatalog.has_structure(structure_id):
		return
	_mode = PlacementMode.STRUCTURE
	_structure_id = structure_id
	visible = true
	placement_mode_changed.emit(true, _mode, _structure_id)


func arm_base_relocation() -> void:
	_mode = PlacementMode.BASE
	_structure_id = &""
	visible = true
	placement_mode_changed.emit(true, _mode, _structure_id)


func cancel() -> void:
	var previous_mode: PlacementMode = _mode
	_mode = PlacementMode.NONE
	_structure_id = &""
	visible = false
	queue_redraw()
	if previous_mode != PlacementMode.NONE:
		placement_mode_changed.emit(false, previous_mode, &"")


func is_armed() -> bool:
	return _mode != PlacementMode.NONE


func get_mode() -> PlacementMode:
	return _mode


func get_candidate_position() -> Vector2:
	return _candidate_position


static func snap_world_position(world_position: Vector2) -> Vector2:
	if not world_position.is_finite():
		return Vector2.ZERO
	return Vector2(
		snappedf(world_position.x, GRID_SIZE),
		snappedf(world_position.y, GRID_SIZE)
	)


func _draw() -> void:
	if _mode == PlacementMode.NONE:
		return
	var query_id: StringName = _structure_id if _mode == PlacementMode.STRUCTURE else &""
	_preview_valid = true
	if _preview_query.is_valid():
		var query_result: Variant = _preview_query.call(query_id, _candidate_position)
		_preview_valid = query_result == true
	var color: Color = Color("3ddc97") if _preview_valid else Color("e15a4a")
	if _mode == PlacementMode.BASE and _preview_valid:
		color = Color("ffb52e")
	if _mode == PlacementMode.STRUCTURE:
		var definition: StructureDefinition = StructureCatalog.get_definition(_structure_id)
		var range_radius: float = definition.get_range_visualization_radius() if definition != null else 0.0
		if range_radius > 0.0:
			draw_circle(Vector2.ZERO, range_radius, Color(color, 0.045), true)
			draw_arc(
				Vector2.ZERO,
				range_radius,
				0.0,
				TAU,
				64,
				Color(color, 0.48),
				1.5,
				true
			)
			if definition != null and definition.has_distinct_impact_radius():
				draw_arc(
					Vector2.ZERO,
					definition.get_effective_range(),
					0.0,
					TAU,
					40,
					Color("ffe18a"),
					2.0,
					true
				)
	var footprint: Vector2 = get_preview_footprint()
	var bounds: Rect2 = Rect2(-footprint * 0.5, footprint)
	if _mode == PlacementMode.STRUCTURE:
		var ghost_definition: StructureDefinition = StructureCatalog.get_definition(_structure_id)
		var ghost_texture: Texture2D = (
			ghost_definition.get_visual_texture() if ghost_definition != null else null
		)
		if ghost_texture != null:
			draw_texture_rect(ghost_texture, bounds, false, Color(color, 0.72))
	draw_rect(bounds, Color(color, 0.15), true)
	draw_rect(bounds, color, false, 3.0)
	draw_line(Vector2(-12.0, 0.0), Vector2(12.0, 0.0), color, 2.0)
	draw_line(Vector2(0.0, -12.0), Vector2(0.0, 12.0), color, 2.0)
