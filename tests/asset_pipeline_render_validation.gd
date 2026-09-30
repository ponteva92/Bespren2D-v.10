extends Node2D
## GPU render probe attached to the generated asset gallery scene.

const OUTPUT_PATH: String = "res://artifacts/asset_pipeline_validation.png"
const METADATA_PATH: String = "res://artifacts/asset_pipeline_validation.json"


func _ready() -> void:
	for _frame in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("viewport image is empty")
		return
	var logical_size := Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")),
		int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	)
	if image.get_size() != logical_size:
		image.resize(logical_size.x, logical_size.y, Image.INTERPOLATE_NEAREST)
	var artifacts_path := ProjectSettings.globalize_path("res://artifacts")
	var directory_error := DirAccess.make_dir_recursive_absolute(artifacts_path)
	if directory_error != OK:
		_fail("could not create artifacts directory: %s" % error_string(directory_error))
		return
	var save_error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if save_error != OK:
		_fail("could not save validation frame: %s" % error_string(save_error))
		return
	var metadata := {
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"width": image.get_width(),
		"height": image.get_height(),
		"gallery": scene_file_path,
		"output": OUTPUT_PATH,
	}
	var metadata_file := FileAccess.open(METADATA_PATH, FileAccess.WRITE)
	if metadata_file == null:
		_fail("could not save validation metadata")
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()
	print(
		"ASSET PIPELINE RENDER OK | method=%s | driver=%s | size=%s"
		% [
			RenderingServer.get_current_rendering_method(),
			RenderingServer.get_current_rendering_driver_name(),
			image.get_size(),
		]
	)
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("ASSET PIPELINE RENDER FAILED | %s" % message)
	get_tree().quit(1)
