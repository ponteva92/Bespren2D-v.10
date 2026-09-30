extends SceneTree
## Packs the Poly Haven wild and salvage sprite families into runtime atlases.
##
## Three things differ from the three sibling packers, and each is a
## consequence of what this family is for rather than a style choice.
##
## The frame list is read from the renderer's report instead of being repeated
## here. Its siblings each carry a hand-kept FRAMES constant, which is
## auditable precisely because it is short. These families bake several yaw
## variants per source, so the same list would run to seventy-odd entries and
## its only possible failure is drifting from what was actually rendered. The
## report is written by the renderer in the same pass that writes the PNGs, so
## it cannot describe a frame that does not exist; this packer still proves
## every entry loads, is the right size, clears the margin, and clears the
## luma floor, so nothing is taken on trust that was not verified before.
##
## The grid is computed rather than declared. Adding a source or a heading
## should not require editing a constant here, and ceil(sqrt(n)) is as
## deterministic as a literal while surviving that edit.
##
## And each frame records the metric height of its subject. The other families
## are buildings placed at authored scales; these are props that have to sit
## beside each other, and a pine that renders the same size as a jerrycan is
## the specific failure this field exists to prevent. Poly Haven models are
## metrically accurate, so the number is real.

const FRAME_SIZE: Vector2i = Vector2i(256, 256)
const REGION_PADDING: int = 4
## Scaled from the 384 px families' 8 px, which is 2.08% of the frame.
const MINIMUM_FRAME_MARGIN: int = 5
## Lower than the district family's 50.0 on purpose: wet bark, dark moss, and
## a black trashbag are legitimately darker subjects than a lit facade, and a
## floor tuned for architecture would reject correct nature renders.
const MINIMUM_ALPHA_WEIGHTED_LUMA: float = 34.0
const MAXIMUM_ATLAS_EDGE: int = 2048

const ENVIRONMENT_ROOT: String = "res://assets/2d/environment"
const RENDER_REPORT_PATH: String = ENVIRONMENT_ROOT + "/polyhaven_wild_render_report.json"
const RENDERER_PATH: String = "res://tools/art/render_polyhaven_wild_sprites.py"
const FETCHER_PATH: String = "res://tools/asset_pipeline/fetch_polyhaven_models.py"
const GENERATOR_PATH: String = "res://tools/asset_pipeline/build_polyhaven_wild_atlas.gd"
const LICENSE_PATH: String = "res://assets/licenses/polyhaven_cc0.md"

const FAMILY_ORDER: Array[String] = ["polyhaven_wild", "polyhaven_salvage"]


func _initialize() -> void:
	call_deferred(&"_build")


func _build() -> void:
	var report: Dictionary = _read_json(RENDER_REPORT_PATH)
	if report.is_empty():
		_fail("Cannot read %s - run the Blender renderer first" % RENDER_REPORT_PATH)
		return
	var render_errors: Array = report.get("errors", [])
	if not render_errors.is_empty():
		_fail("Renderer reported %d error(s); refusing to pack a partial family" % render_errors.size())
		return
	var families: Dictionary = report.get("families", {})

	var summary: PackedStringArray = PackedStringArray()
	for family: String in FAMILY_ORDER:
		if not families.has(family):
			_fail("Render report has no family '%s'" % family)
			return
		var line: String = _pack_family(family, families[family])
		if line.is_empty():
			return
		summary.append(line)

	print("POLY HAVEN WILD ATLAS OK | %s" % " | ".join(summary))
	quit(0)


func _pack_family(family: String, entry: Dictionary) -> String:
	var frames: Array = entry.get("frame_list", [])
	if frames.is_empty():
		_fail("Family '%s' rendered no frames" % family)
		return ""

	var columns: int = int(ceil(sqrt(float(frames.size()))))
	var rows: int = int(ceil(float(frames.size()) / float(columns)))
	if columns * FRAME_SIZE.x > MAXIMUM_ATLAS_EDGE or rows * FRAME_SIZE.y > MAXIMUM_ATLAS_EDGE:
		_fail("Family '%s' needs %dx%d cells, which exceeds the %d px atlas edge" % [
			family, columns, rows, MAXIMUM_ATLAS_EDGE
		])
		return ""

	var directory: String = "%s/%s" % [ENVIRONMENT_ROOT, family]
	var atlas: Image = Image.create(
		FRAME_SIZE.x * columns, FRAME_SIZE.y * rows, false, Image.FORMAT_RGBA8
	)
	atlas.fill(Color(0.0, 0.0, 0.0, 0.0))

	var derived_assets: Array[Dictionary] = []
	var source_ids: Dictionary = {}
	var lowest_luma: float = 1000.0
	var smallest_margin: int = FRAME_SIZE.x
	var tallest: float = 0.0
	var shortest: float = 1000.0

	for index: int in range(frames.size()):
		var frame: Dictionary = frames[index]
		var source_path: String = "%s/%s" % [directory, frame.get("file", "")]
		var image: Image = Image.new()
		var load_error: Error = image.load(ProjectSettings.globalize_path(source_path))
		if load_error != OK:
			_fail("Cannot load %s: %s" % [source_path, error_string(load_error)])
			return ""
		if image.get_size() != FRAME_SIZE:
			_fail("%s is %s, expected %s" % [source_path, image.get_size(), FRAME_SIZE])
			return ""
		if image.get_format() != Image.FORMAT_RGBA8:
			image.convert(Image.FORMAT_RGBA8)

		var bounds: Rect2i = _alpha_content_bounds(image)
		if bounds.size == Vector2i.ZERO:
			_fail("%s contains no visible pixels" % source_path)
			return ""
		var margin: int = _edge_margin(bounds)
		if margin < MINIMUM_FRAME_MARGIN:
			_fail("%s touches the protected %d px margin (margin=%d, bounds=%s)" % [
				source_path, MINIMUM_FRAME_MARGIN, margin, bounds
			])
			return ""
		var luma: float = _alpha_weighted_luma(image)
		if luma < MINIMUM_ALPHA_WEIGHTED_LUMA:
			_fail("%s alpha-weighted luma %.2f is below %.2f" % [
				source_path, luma, MINIMUM_ALPHA_WEIGHTED_LUMA
			])
			return ""

		var cell: Vector2i = Vector2i(index % columns, index / columns)
		var origin: Vector2i = cell * FRAME_SIZE
		atlas.blit_rect(image, Rect2i(Vector2i.ZERO, FRAME_SIZE), origin)
		var padded: Rect2i = _grow_and_clamp(bounds, REGION_PADDING, FRAME_SIZE)

		var height_m: float = float(frame.get("world_height_m", 0.0))
		lowest_luma = minf(lowest_luma, luma)
		smallest_margin = mini(smallest_margin, margin)
		tallest = maxf(tallest, height_m)
		shortest = minf(shortest, height_m)
		source_ids[frame.get("source_id", "")] = frame

		derived_assets.append({
			"key": frame.get("key", ""),
			"variant": int(frame.get("variant", 0)),
			"yaw_deg": float(frame.get("yaw_deg", 0.0)),
			"source_id": frame.get("source_id", ""),
			"path": source_path,
			"bytes": _file_size(source_path),
			"sha256": _sha256(source_path),
			"cell_region": _rect_array(Rect2i(origin, FRAME_SIZE)),
			"content_bounds": _rect_array(bounds),
			"padded_atlas_region": _rect_array(padded),
			"edge_margin_px": margin,
			"visible_pixel_count": _visible_pixel_count(image),
			"alpha_coverage": snappedf(_alpha_coverage(image), 0.000001),
			"alpha_weighted_luma_255": snappedf(luma, 0.001),
			# What the subject actually measures, so the runtime can scale a
			# pine and a jerrycan against one another instead of by eye.
			"world_height_m": snappedf(height_m, 0.0001),
			"world_size_m": frame.get("world_size_m", []),
		})

	var atlas_path: String = "%s/%s_atlas.png" % [directory, family]
	var save_error: Error = atlas.save_png(ProjectSettings.globalize_path(atlas_path))
	if save_error != OK:
		_fail("Cannot save %s: %s" % [atlas_path, error_string(save_error)])
		return ""

	var source_assets: Array[Dictionary] = []
	for source_id: String in source_ids:
		var frame: Dictionary = source_ids[source_id]
		source_assets.append({
			"id": source_id,
			"name": frame.get("source_name", source_id),
			"type": "model",
			"resolution": "1k",
			"format": "gltf",
			"url": frame.get("source_url", "https://polyhaven.com/a/%s" % source_id),
			"authors": frame.get("authors", []),
			"license": "CC0-1.0",
		})
	source_assets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["id"]) < String(b["id"]))

	var manifest: Dictionary = {
		"schema_version": 1,
		"family": family,
		"license": "CC0-1.0",
		"license_url": "https://polyhaven.com/license",
		"license_evidence": LICENSE_PATH,
		"source_assets": source_assets,
		"blender_version": "5.0.0",
		"render_policy": "orthographic_transparent_freestyle_agx_shared_district_rig",
		"runtime_policy": "offline_baked_2d_atlas_only_no_runtime_mesh_or_node3d",
		# These families were fetched through the documented public API, so the
		# provenance chain is the fetch manifest's per-file SHA-256 plus the
		# asset page - there is no workshop .blend to hash.
		"source_contract": "tools/art/blender/vault/%s/_fetch_manifest.json" % family,
		"source_fetcher": FETCHER_PATH,
		"source_fetcher_sha256": _sha256(FETCHER_PATH),
		"blender_renderer": RENDERER_PATH,
		"blender_renderer_bytes": _file_size(RENDERER_PATH),
		"blender_renderer_sha256": _sha256(RENDERER_PATH),
		"atlas_generator": GENERATOR_PATH,
		"atlas_generator_bytes": _file_size(GENERATOR_PATH),
		"atlas_generator_sha256": _sha256(GENERATOR_PATH),
		"quality_gates": {
			"minimum_frame_margin": MINIMUM_FRAME_MARGIN,
			"minimum_alpha_weighted_luma_255": MINIMUM_ALPHA_WEIGHTED_LUMA,
			"observed_minimum_margin_px": smallest_margin,
			"observed_minimum_luma_255": snappedf(lowest_luma, 0.001),
		},
		"scale_range_m": {
			"shortest": snappedf(shortest, 0.0001),
			"tallest": snappedf(tallest, 0.0001),
		},
		"atlas": {
			"path": atlas_path,
			"size": [atlas.get_width(), atlas.get_height()],
			"bytes": _file_size(atlas_path),
			"sha256": _sha256(atlas_path),
			"frame_size": [FRAME_SIZE.x, FRAME_SIZE.y],
			"layout": "%dx%d deterministic frame order; %d occupied cells" % [
				columns, rows, derived_assets.size()
			],
		},
		"derived_assets": derived_assets,
	}
	var manifest_path: String = "%s/%s_manifest.json" % [directory, family]
	var manifest_file: FileAccess = FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file == null:
		_fail("Cannot write %s" % manifest_path)
		return ""
	manifest_file.store_string(JSON.stringify(manifest, "\t") + "\n")
	manifest_file.close()

	return "%s %d frames/%d sources %dx%d luma>=%.1f margin>=%d %.2f-%.2fm" % [
		family, derived_assets.size(), source_assets.size(),
		atlas.get_width(), atlas.get_height(), lowest_luma, smallest_margin,
		shortest, tallest
	]


func _read_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _alpha_content_bounds(image: Image) -> Rect2i:
	var minimum: Vector2i = image.get_size()
	var maximum: Vector2i = Vector2i(-1, -1)
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.003:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _edge_margin(bounds: Rect2i) -> int:
	return mini(
		mini(bounds.position.x, bounds.position.y),
		mini(FRAME_SIZE.x - bounds.end.x, FRAME_SIZE.y - bounds.end.y)
	)


func _grow_and_clamp(bounds: Rect2i, padding: int, limit: Vector2i) -> Rect2i:
	var position: Vector2i = Vector2i(
		maxi(bounds.position.x - padding, 0), maxi(bounds.position.y - padding, 0)
	)
	var end: Vector2i = Vector2i(
		mini(bounds.end.x + padding, limit.x), mini(bounds.end.y + padding, limit.y)
	)
	return Rect2i(position, end - position)


func _visible_pixel_count(image: Image) -> int:
	var count: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.003:
				count += 1
	return count


func _alpha_coverage(image: Image) -> float:
	var total: int = image.get_width() * image.get_height()
	if total <= 0:
		return 0.0
	return float(_visible_pixel_count(image)) / float(total)


func _alpha_weighted_luma(image: Image) -> float:
	var weighted: float = 0.0
	var weight: float = 0.0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a <= 0.003:
				continue
			var luma: float = 0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b
			weighted += luma * pixel.a
			weight += pixel.a
	if weight <= 0.0:
		return 0.0
	return (weighted / weight) * 255.0


func _rect_array(rect: Rect2i) -> Array[int]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y] as Array[int]


func _file_size(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var size: int = int(file.get_length())
	file.close()
	return size


func _sha256(path: String) -> String:
	return FileAccess.get_sha256(path)


func _fail(message: String) -> void:
	printerr("POLY HAVEN WILD ATLAS FAILED | %s" % message)
	quit(1)
