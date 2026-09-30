extends Node2D
## GPU render probe. Run through Godot MCP without --headless.

const OUTPUT_PATH: String = "res://artifacts/visual_validation.png"
const METADATA_PATH: String = "res://artifacts/visual_validation.json"


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("RENDER FAILED: viewport image is empty")
		get_tree().quit(1)
		return
	var source_size := image.get_size()
	var logical_size := Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")),
		int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	)
	if image.get_size() != logical_size:
		image.resize(logical_size.x, logical_size.y, Image.INTERPOLATE_LANCZOS)
	var save_error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if save_error != OK:
		push_error("RENDER FAILED: could not save validation frame (%s)" % error_string(save_error))
		get_tree().quit(1)
		return
	var metadata: Dictionary = {
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"width": image.get_width(),
		"height": image.get_height(),
		"source_width": source_size.x,
		"source_height": source_size.y,
		"output": OUTPUT_PATH,
	}
	var metadata_file := FileAccess.open(METADATA_PATH, FileAccess.WRITE)
	if metadata_file == null:
		push_error("RENDER FAILED: could not write validation metadata")
		get_tree().quit(1)
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()
	print(
		"RENDER OK | method=%s | driver=%s | size=%s"
		% [
			RenderingServer.get_current_rendering_method(),
			RenderingServer.get_current_rendering_driver_name(),
			image.get_size(),
		]
	)
	get_tree().quit(0)
