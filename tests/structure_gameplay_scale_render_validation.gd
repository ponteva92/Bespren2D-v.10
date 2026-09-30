extends Node2D
## Mobile/Vulkan evidence for the *actual* defense read through the live 0.38
## camera contract.  The existing library contact sheet deliberately enlarges
## its actors for inspection; this scene keeps PlacedStructure2D's authored
## child scales unchanged and therefore must not be used as a replacement for
## a device capture.

const PRE_MIPMAPS_OUTPUT_PATH: String = "res://artifacts/structure_visual_gameplay_scale_pre_mipmaps.png"
const POST_MIPMAPS_OUTPUT_PATH: String = "res://artifacts/structure_visual_gameplay_scale.png"
const PRE_MIPMAPS_METADATA_PATH: String = "res://artifacts/structure_visual_gameplay_scale_pre_mipmaps_validation.json"
const POST_MIPMAPS_METADATA_PATH: String = "res://artifacts/structure_visual_gameplay_scale_validation.json"
const CAMERA_ZOOM: float = 0.38
const WORLD_POSITIONS: Array[Vector2] = [
	Vector2(-420.0, -130.0),
	Vector2(-140.0, -130.0),
	Vector2(140.0, -130.0),
	Vector2(420.0, -130.0),
	Vector2(-420.0, 140.0),
	Vector2(-140.0, 140.0),
	Vector2(140.0, 140.0),
	Vector2(420.0, 140.0),
]

@onready var overlay: CanvasLayer = get_node_or_null("Overlay") as CanvasLayer


func _ready() -> void:
	var definitions: Array[StructureDefinition] = StructureCatalog.get_all()
	if definitions.size() != WORLD_POSITIONS.size():
		push_error("STRUCTURE GAMEPLAY SCALE RENDER FAILED: catalog size mismatch")
		get_tree().quit(1)
		return
	var all_source_mipmaps_enabled: bool = _all_source_mipmaps_enabled(definitions)
	var output_path: String = (
		POST_MIPMAPS_OUTPUT_PATH if all_source_mipmaps_enabled else PRE_MIPMAPS_OUTPUT_PATH
	)
	var metadata_path: String = (
		POST_MIPMAPS_METADATA_PATH if all_source_mipmaps_enabled else PRE_MIPMAPS_METADATA_PATH
	)
	var camera: Camera2D = Camera2D.new()
	camera.name = &"GameplayScaleCamera"
	camera.position = Vector2.ZERO
	camera.zoom = Vector2.ONE * CAMERA_ZOOM
	add_child(camera)
	camera.make_current()
	var runtime_scales: Array[float] = []
	for index: int in range(definitions.size()):
		var definition: StructureDefinition = definitions[index]
		var structure: PlacedStructure2D = PlacedStructure2D.new()
		structure.configure(index + 1, definition, 1, WORLD_POSITIONS[index])
		add_child(structure)
		var visual: Sprite2D = structure.get_structure_visual()
		if visual == null or visual.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS:
			push_error("STRUCTURE GAMEPLAY SCALE RENDER FAILED: visual contract missing")
			get_tree().quit(1)
			return
		runtime_scales.append(visual.scale.x)
		_add_world_label(definition.display_name, _world_to_screen(WORLD_POSITIONS[index]))
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("STRUCTURE GAMEPLAY SCALE RENDER FAILED: empty viewport")
		get_tree().quit(1)
		return
	if image.get_size() != Vector2i(480, 270):
		image.resize(480, 270, Image.INTERPOLATE_LANCZOS)
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		push_error("STRUCTURE GAMEPLAY SCALE RENDER FAILED: %s" % error_string(save_error))
		get_tree().quit(1)
		return
	var metadata: Dictionary = {
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"logical_size": [480, 270],
		"camera_zoom": [CAMERA_ZOOM, CAMERA_ZOOM],
		"structure_count": definitions.size(),
		"runtime_child_scales": runtime_scales,
		"all_source_mipmaps_enabled": all_source_mipmaps_enabled,
		"structure_ids": _get_structure_ids(definitions),
		"output": output_path,
	}
	var metadata_file: FileAccess = FileAccess.open(metadata_path, FileAccess.WRITE)
	if metadata_file == null:
		push_error("STRUCTURE GAMEPLAY SCALE RENDER FAILED: could not write metadata")
		get_tree().quit(1)
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()
	print("STRUCTURE GAMEPLAY SCALE RENDER OK | method=%s | driver=%s | zoom=%.2f" % [
		RenderingServer.get_current_rendering_method(),
		RenderingServer.get_current_rendering_driver_name(),
		CAMERA_ZOOM,
	])
	get_tree().quit(0)


func _draw() -> void:
	draw_rect(Rect2(-680.0, -390.0, 1360.0, 780.0), Color("101911"), true)
	for column: int in range(-8, 9):
		var x: float = float(column) * 80.0
		draw_line(Vector2(x, -390.0), Vector2(x, 390.0), Color(0.18, 0.27, 0.2, 0.18), 1.0)
	for row: int in range(-4, 5):
		var y: float = float(row) * 80.0
		draw_line(Vector2(-680.0, y), Vector2(680.0, y), Color(0.18, 0.27, 0.2, 0.18), 1.0)
	draw_line(Vector2(-680.0, 0.0), Vector2(680.0, 0.0), Color(0.48, 0.33, 0.16, 0.42), 3.0)


func _world_to_screen(world_position: Vector2) -> Vector2:
	return Vector2(240.0, 135.0) + world_position * CAMERA_ZOOM


func _add_world_label(label_text: String, screen_position: Vector2) -> void:
	var label: Label = Label.new()
	label.position = screen_position + Vector2(-38.0, 28.0)
	label.size = Vector2(76.0, 12.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = label_text.to_upper()
	label.add_theme_font_size_override(&"font_size", 6)
	label.add_theme_color_override(&"font_color", Color("c8d5c4"))
	label.add_theme_color_override(&"font_outline_color", Color("071009"))
	label.add_theme_constant_override(&"outline_size", 1)
	overlay.add_child(label)


func _get_structure_ids(definitions: Array[StructureDefinition]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for definition: StructureDefinition in definitions:
		result.append(String(definition.structure_id))
	return result


func _all_source_mipmaps_enabled(definitions: Array[StructureDefinition]) -> bool:
	for definition: StructureDefinition in definitions:
		var source_path: String = definition.visual_texture_path + ".import"
		if not FileAccess.file_exists(source_path):
			return false
		var import_text: String = FileAccess.get_file_as_string(source_path)
		if not import_text.contains("mipmaps/generate=true"):
			return false
	return true
