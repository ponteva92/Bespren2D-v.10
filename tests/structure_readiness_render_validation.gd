extends Node2D
## Mobile/Vulkan artifact-only proof for the structure readiness signatures.
## It deliberately uses client presentation shells and existing snapshot fields:
## no gameplay world, authority path, collision, or catalog definition is
## modified by this capture.

const OUTPUT_PATH: String = "res://artifacts/structure_readiness_gameplay_scale.png"
const METADATA_PATH: String = "res://artifacts/structure_readiness_gameplay_scale.json"
const CAMERA_ZOOM: float = 0.38
const WORLD_POSITIONS: Array[Vector2] = [
	Vector2(-330.0, -110.0),
	Vector2(0.0, -110.0),
	Vector2(330.0, -110.0),
	Vector2(-330.0, 150.0),
	Vector2(0.0, 150.0),
	Vector2(330.0, 150.0),
]
const STRUCTURE_IDS: Array[StringName] = [
	StructureCatalog.T1_KINETIC,
	StructureCatalog.T1_CHEMICAL,
	StructureCatalog.T1_ELECTRIC,
	StructureCatalog.T1_LANDMINE,
	StructureCatalog.T1_SLOWING_PIT,
	StructureCatalog.T1_RAZOR_SNARE,
]
const REVIEW_STATES: Array[StringName] = [
	&"ready",
	&"tracking",
	&"rearming",
	&"ready",
	&"rearming",
	&"disabled",
]

@onready var overlay: CanvasLayer = get_node_or_null("Overlay") as CanvasLayer


func _ready() -> void:
	if STRUCTURE_IDS.size() != WORLD_POSITIONS.size() or STRUCTURE_IDS.size() != REVIEW_STATES.size():
		_fail("fixture array sizes diverged")
		return
	var camera: Camera2D = Camera2D.new()
	camera.name = &"ReadinessGameplayCamera"
	camera.position = Vector2(0.0, 20.0)
	camera.zoom = Vector2.ONE * CAMERA_ZOOM
	add_child(camera)
	camera.make_current()
	var states: Dictionary = {}
	for index: int in range(STRUCTURE_IDS.size()):
		var definition: StructureDefinition = StructureCatalog.get_definition(STRUCTURE_IDS[index])
		if definition == null:
			_fail("could not resolve %s" % STRUCTURE_IDS[index])
			return
		var structure: PlacedStructure2D = PlacedStructure2D.new()
		structure.configure(index + 2001, definition, 2, WORLD_POSITIONS[index], false)
		add_child(structure)
		if not _apply_review_state(structure, REVIEW_STATES[index]):
			_fail("could not apply %s state to %s" % [REVIEW_STATES[index], definition.display_name])
			return
		if structure.get_readability_state_name() != REVIEW_STATES[index]:
			_fail("%s read %s instead of %s" % [
				definition.display_name,
				structure.get_readability_state_name(),
				REVIEW_STATES[index],
			])
			return
		states[String(definition.structure_id)] = {
			"state": String(structure.get_readability_state_name()),
			"signature": structure.get_readability_signature(),
			"world_position": [structure.global_position.x, structure.global_position.y],
		}
		_add_label(
			"%s // %s" % [definition.display_name.to_upper(), REVIEW_STATES[index].to_upper()],
			_world_to_screen(WORLD_POSITIONS[index]) + Vector2(-53.0, 30.0)
		)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("empty viewport")
		return
	if image.get_size() != Vector2i(480, 270):
		image.resize(480, 270, Image.INTERPOLATE_LANCZOS)
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if save_error != OK:
		_fail("could not save image: %s" % error_string(save_error))
		return
	var metadata: Dictionary = {
		"artifact_only": true,
		"runtime_promotion": "forbidden: test-only client presentation shells",
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"logical_size": [480, 270],
		"camera_zoom": CAMERA_ZOOM,
		"signature_radius_logical_px": PlacedStructure2D.READABILITY_TRAP_RADIUS * CAMERA_ZOOM,
		"signature_line_logical_px": PlacedStructure2D.READABILITY_TRAP_LINE_WIDTH * CAMERA_ZOOM,
		"states": states,
		"output": OUTPUT_PATH,
	}
	var metadata_file: FileAccess = FileAccess.open(METADATA_PATH, FileAccess.WRITE)
	if metadata_file == null:
		_fail("could not open metadata output")
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()
	print("STRUCTURE READINESS RENDER OK | method=%s | driver=%s | states=%d" % [
		RenderingServer.get_current_rendering_method(),
		RenderingServer.get_current_rendering_driver_name(),
		states.size(),
	])
	get_tree().quit(0)


func _apply_review_state(structure: PlacedStructure2D, state: StringName) -> bool:
	match state:
		&"ready":
			return true
		&"tracking":
			return structure.apply_runtime_snapshot(
				structure.max_health,
				0.0,
				Vector2.RIGHT,
				0.0,
				71
			)
		&"rearming":
			return structure.apply_runtime_snapshot(
				structure.max_health,
				0.0,
				Vector2.RIGHT,
				0.75,
				71
			)
		&"disabled":
			return structure.apply_runtime_snapshot(
				structure.max_health,
				1.0,
				Vector2.RIGHT,
				0.0,
				-1
			)
		_:
			return false


func _world_to_screen(world_position: Vector2) -> Vector2:
	return Vector2(240.0, 135.0) + (world_position - Vector2(0.0, 20.0)) * CAMERA_ZOOM


func _add_label(label_text: String, label_position: Vector2) -> void:
	if overlay == null:
		return
	var label: Label = Label.new()
	label.position = label_position
	label.size = Vector2(106.0, 12.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = label_text
	label.add_theme_font_size_override(&"font_size", 6)
	label.add_theme_color_override(&"font_color", Color("c8d5c4"))
	label.add_theme_color_override(&"font_outline_color", Color("071009"))
	label.add_theme_constant_override(&"outline_size", 1)
	overlay.add_child(label)


func _fail(message: String) -> void:
	push_error("STRUCTURE READINESS RENDER FAILED: %s" % message)
	get_tree().quit(1)
