extends Node2D
## GPU contact-sheet gate for all eight authored defense silhouettes.

const OUTPUT_PATH: String = "res://artifacts/structure_visual_library.png"
const METADATA_PATH: String = "res://artifacts/structure_visual_render_validation.json"

const POSITIONS: Array[Vector2] = [
	Vector2(62.0, 78.0),
	Vector2(180.0, 78.0),
	Vector2(300.0, 78.0),
	Vector2(418.0, 78.0),
	Vector2(62.0, 196.0),
	Vector2(180.0, 196.0),
	Vector2(300.0, 196.0),
	Vector2(418.0, 196.0),
]


func _ready() -> void:
	var definitions: Array[StructureDefinition] = StructureCatalog.get_all()
	if definitions.size() != POSITIONS.size():
		push_error("STRUCTURE VISUAL RENDER FAILED: catalog size mismatch")
		get_tree().quit(1)
		return
	for index: int in definitions.size():
		var definition: StructureDefinition = definitions[index]
		var structure: PlacedStructure2D = PlacedStructure2D.new()
		structure.configure(index + 1, definition, 1, POSITIONS[index])
		structure.scale = Vector2.ONE * 0.56
		add_child(structure)
		_add_label(definition.display_name, POSITIONS[index] + Vector2(-55.0, 42.0))
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("STRUCTURE VISUAL RENDER FAILED: empty viewport")
		get_tree().quit(1)
		return
	if image.get_size() != Vector2i(480, 270):
		image.resize(480, 270, Image.INTERPOLATE_LANCZOS)
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if save_error != OK:
		push_error("STRUCTURE VISUAL RENDER FAILED: %s" % error_string(save_error))
		get_tree().quit(1)
		return
	var metadata: Dictionary = {
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"logical_size": [480, 270],
		"structure_count": definitions.size(),
		"output": OUTPUT_PATH,
	}
	var metadata_file: FileAccess = FileAccess.open(METADATA_PATH, FileAccess.WRITE)
	if metadata_file == null:
		push_error("STRUCTURE VISUAL RENDER FAILED: could not write metadata")
		get_tree().quit(1)
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()
	print("STRUCTURE VISUAL RENDER OK | method=%s | driver=%s | structures=8" % [
		RenderingServer.get_current_rendering_method(),
		RenderingServer.get_current_rendering_driver_name(),
	])
	get_tree().quit(0)


func _add_label(label_text: String, label_position: Vector2) -> void:
	var label: Label = Label.new()
	label.position = label_position
	label.size = Vector2(110.0, 16.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = label_text.to_upper()
	label.add_theme_font_size_override(&"font_size", 8)
	label.add_theme_color_override(&"font_color", Color("d8c9ad"))
	label.add_theme_color_override(&"font_shadow_color", Color(0.02, 0.025, 0.02, 0.9))
	label.add_theme_constant_override(&"shadow_offset_x", 1)
	label.add_theme_constant_override(&"shadow_offset_y", 1)
	add_child(label)
