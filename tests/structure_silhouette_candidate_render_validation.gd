extends Node2D
## Runtime-context gate for the isolated Loop H structure candidates.
##
## This fixture loads the source-only PNGs from build/ through ImageTexture,
## swaps them only into locally constructed PlacedStructure2D nodes, and never
## changes StructureCatalog, its preloads, or an exported dependency closure.

const OUTPUT_PATH: String = "res://artifacts/structure_silhouette_loop_h_gameplay_proxy.png"
const METADATA_PATH: String = "res://artifacts/structure_silhouette_loop_h_gameplay_proxy.json"
const STAGING_ROOT: String = "res://build/structure_silhouette_loop_h_20260917"
const CAMERA_ZOOM: float = 0.38
const CANDIDATES: Array[Dictionary] = [
	{"id": StructureCatalog.T1_KINETIC, "file": "structure_t1_kinetic.png", "position": Vector2(-300.0, -115.0)},
	{"id": StructureCatalog.T1_CHEMICAL, "file": "structure_t1_chemical.png", "position": Vector2(0.0, -115.0)},
	{"id": StructureCatalog.T1_ELECTRIC, "file": "structure_t1_electric.png", "position": Vector2(300.0, -115.0)},
	{"id": StructureCatalog.T1_LANDMINE, "file": "structure_t1_landmine.png", "position": Vector2(-160.0, 125.0)},
	{"id": StructureCatalog.T1_SLOWING_PIT, "file": "structure_t1_slowing_pit.png", "position": Vector2(160.0, 125.0)},
]

@onready var overlay: CanvasLayer = get_node_or_null("Overlay") as CanvasLayer

var _candidate_textures: Array[Texture2D] = []
var _metadata_assets: Array[Dictionary] = []


func _ready() -> void:
	var camera: Camera2D = Camera2D.new()
	camera.name = &"CandidateGameplayScaleCamera"
	camera.zoom = Vector2.ONE * CAMERA_ZOOM
	add_child(camera)
	camera.make_current()
	for index: int in range(CANDIDATES.size()):
		if not _spawn_candidate(index):
			return
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("empty viewport")
		return
	if image.get_size() != Vector2i(480, 270):
		image.resize(480, 270, Image.INTERPOLATE_LANCZOS)
	if image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH)) != OK:
		_fail("could not save runtime-context capture")
		return
	var metadata_file: FileAccess = FileAccess.open(METADATA_PATH, FileAccess.WRITE)
	if metadata_file == null:
		_fail("could not save runtime-context metadata")
		return
	metadata_file.store_string(JSON.stringify({
		"scope": "test-only staging texture substitution; live StructureCatalog remains unchanged",
		"camera_zoom": CAMERA_ZOOM,
		"candidate_root": STAGING_ROOT,
		"candidate_count": _metadata_assets.size(),
		"assets": _metadata_assets,
		"output": OUTPUT_PATH,
	}, "\t"))
	metadata_file.close()
	print("STRUCTURE SILHOUETTE CANDIDATE RENDER OK | zoom=%.2f | candidates=%d" % [
		CAMERA_ZOOM,
		_metadata_assets.size(),
	])
	get_tree().quit(0)


func _spawn_candidate(index: int) -> bool:
	var entry: Dictionary = CANDIDATES[index]
	var structure_id: StringName = entry["id"] as StringName
	var filename: String = entry["file"] as String
	var world_position: Vector2 = entry["position"] as Vector2
	var definition: StructureDefinition = StructureCatalog.get_definition(structure_id)
	if definition == null:
		_fail("missing structure definition %s" % structure_id)
		return false
	var staging_path: String = STAGING_ROOT.path_join(filename)
	if not FileAccess.file_exists(staging_path):
		_fail("staging texture is missing: %s" % staging_path)
		return false
	var source: Image = Image.load_from_file(ProjectSettings.globalize_path(staging_path))
	if source == null or source.is_empty() or source.get_size() != Vector2i(320, 320):
		_fail("staging texture is not a 320x320 PNG: %s" % staging_path)
		return false
	var mipmap_error: Error = source.generate_mipmaps()
	if mipmap_error != OK:
		_fail("could not generate candidate mipmaps for %s" % filename)
		return false
	var candidate_texture: ImageTexture = ImageTexture.create_from_image(source)
	if candidate_texture == null:
		_fail("could not construct candidate texture for %s" % filename)
		return false
	_candidate_textures.append(candidate_texture)
	var structure: PlacedStructure2D = PlacedStructure2D.new()
	structure.name = StringName("Candidate_%s" % structure_id)
	structure.configure(index + 1, definition, 1, world_position)
	add_child(structure)
	var visual: Sprite2D = structure.get_structure_visual()
	if visual == null:
		_fail("candidate %s has no structure visual" % structure_id)
		return false
	visual.texture = candidate_texture
	if visual.texture != candidate_texture or visual.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS:
		_fail("candidate %s lost its local texture or mipmap filter" % structure_id)
		return false
	var expected_scale: float = 0.30 if definition.is_trap() else 0.32
	if not is_equal_approx(visual.scale.x, expected_scale):
		_fail("candidate %s changed the live scale contract" % structure_id)
		return false
	_metadata_assets.append({
		"id": structure_id,
		"staging_file": staging_path,
		"source_size": [source.get_width(), source.get_height()],
		"runtime_visual_scale": visual.scale.x,
		"texture_resource_path": visual.texture.resource_path,
	})
	_add_label(definition.display_name, _world_to_screen(world_position))
	return true


func _draw() -> void:
	draw_rect(Rect2(-680.0, -390.0, 1360.0, 780.0), Color("101911"), true)
	for column: int in range(-8, 9):
		var x: float = float(column) * 80.0
		draw_line(Vector2(x, -390.0), Vector2(x, 390.0), Color(0.18, 0.27, 0.20, 0.18), 1.0)
	for row: int in range(-4, 5):
		var y: float = float(row) * 80.0
		draw_line(Vector2(-680.0, y), Vector2(680.0, y), Color(0.18, 0.27, 0.20, 0.18), 1.0)
	draw_line(Vector2(-680.0, 0.0), Vector2(680.0, 0.0), Color(0.48, 0.33, 0.16, 0.42), 3.0)


func _world_to_screen(world_position: Vector2) -> Vector2:
	return Vector2(240.0, 135.0) + world_position * CAMERA_ZOOM


func _add_label(label_text: String, screen_position: Vector2) -> void:
	if overlay == null:
		_fail("missing overlay")
		return
	var label: Label = Label.new()
	label.position = screen_position + Vector2(-48.0, 28.0)
	label.size = Vector2(96.0, 12.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = label_text.to_upper()
	label.add_theme_font_size_override(&"font_size", 6)
	label.add_theme_color_override(&"font_color", Color("c8d5c4"))
	label.add_theme_color_override(&"font_outline_color", Color("071009"))
	label.add_theme_constant_override(&"outline_size", 1)
	overlay.add_child(label)


func _fail(reason: String) -> void:
	push_error("STRUCTURE SILHOUETTE CANDIDATE RENDER FAILED: %s" % reason)
	get_tree().quit(1)
