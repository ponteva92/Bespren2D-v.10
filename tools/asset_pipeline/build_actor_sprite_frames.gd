extends SceneTree
## Turns the baked actor sheets into per-actor SpriteFrames and presentation scenes.
##
## The bake writes one PNG per actor and clip, laid out rows = eight compass
## headings, columns = animation frames. That layout is self-describing: the
## cell is the height divided by eight, and the column count is the width
## divided by the cell, so nothing here has to be told the geometry and the two
## halves of the pipeline cannot drift apart over a hand-maintained table.
##
## Each heading becomes its own named animation - walk_0 through walk_7 -
## rather than a custom frame driver, because Godot already advances, loops, and
## speed-scales SpriteFrames in C++. Choosing a row is then a play() call, and
## the eight-way facing costs the presentation nothing per frame.
##
## The headings are not evenly spaced on screen and that is deliberate. The bake
## camera sits at 52 degrees, so the vertical axis is foreshortened by sin(52):
## the heading rendered one step off "straight down" arrives on screen at 38.2
## degrees, not 45. Runtime picks a row by dot product against the measured
## vectors in ActorFacing rather than by dividing an angle into eight equal
## slices, which is what keeps a diagonal sprite from reading as a quarter-turn
## off its own movement.

const SHEET_DIRECTORY: String = "res://assets/2d/actors/sheets"
const FRAMES_DIRECTORY: String = "res://assets/2d/actors/frames"
const SCENE_DIRECTORY: String = "res://assets/2d/actors/scenes"
const MANIFEST_PATH: String = "res://assets/2d/actors/actor_frames_manifest.json"
const SHEET_MANIFEST_PATH: String = "res://assets/2d/actors/sheets/sheet_manifest.json"
const GENERATOR_PATH: String = "res://tools/asset_pipeline/build_actor_sprite_frames.gd"
const DIRECTIONS: int = 8

## The ladder of cell sizes the bake may emit, as its rule rather than as a
## list: a clip takes the smallest step that holds its own content at the shared
## density. Stated as bounds and a step because the bake's own ladder is exactly
## that (run_actor_bake.CELL_LADDER), and transcribing twenty-eight literals here
## would guarantee the two drift apart the next time the step is tightened.
## The guard it backs is against a sheet whose height is not a whole number of
## real cells - a mis-stated cell silently shears every frame on the sheet.
const CELL_MIN: int = 40
const CELL_MAX: int = 256
const CELL_STEP: int = 8

## fps and loop per clip. Locomotion loops; everything that resolves - a hit, a
## death, a spawn, a taunt, a shot - plays once and holds its last frame, which
## is what lets the presentation show a corpse instead of a corpse standing back
## up every six frames.
const CLIPS: Dictionary = {
	&"idle": {&"fps": 6.0, &"loop": true},
	&"walk": {&"fps": 10.0, &"loop": true},
	&"run": {&"fps": 14.0, &"loop": true},
	&"gather": {&"fps": 10.0, &"loop": true},
	&"shoot": {&"fps": 14.0, &"loop": false},
	&"attack": {&"fps": 12.0, &"loop": false},
	&"hit": {&"fps": 14.0, &"loop": false},
	&"death": {&"fps": 9.0, &"loop": false},
	&"spawn": {&"fps": 9.0, &"loop": false},
	&"taunt": {&"fps": 9.0, &"loop": false},
}

var _errors: PackedStringArray = PackedStringArray()
var _ground_offsets: Dictionary = {}


func _initialize() -> void:
	var actors: Dictionary = _collect_sheets()
	if actors.is_empty():
		_fail("no actor sheets found under %s" % SHEET_DIRECTORY)
	_ground_offsets = _load_ground_offsets()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAMES_DIRECTORY))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENE_DIRECTORY))

	var entries: Array[Dictionary] = []
	var animation_total: int = 0
	for actor: String in actors.keys():
		var entry: Dictionary = _build_actor(actor, actors[actor])
		if not entry.is_empty():
			entries.append(entry)
			animation_total += int(entry[&"animations"])
	entries.sort_custom(_sort_by_actor)

	_write_manifest(entries)
	for message: String in _errors:
		printerr("ERROR | %s" % message)
	print("ACTOR FRAMES %s (%d actors, %d animations, %d errors)" % [
		"OK" if _errors.is_empty() else "FAILED",
		entries.size(), animation_total, _errors.size(),
	])
	quit(0 if _errors.is_empty() else 1)


func _sort_by_actor(left: Dictionary, right: Dictionary) -> bool:
	return String(left[&"actor"]) < String(right[&"actor"])


## Group <actor>_<clip>.png by actor. The clip is the last underscore field,
## so an actor id may itself contain underscores - and every one of them does.
func _collect_sheets() -> Dictionary:
	var grouped: Dictionary = {}
	var dir: DirAccess = DirAccess.open(SHEET_DIRECTORY)
	if dir == null:
		return grouped
	for file: String in dir.get_files():
		if not file.ends_with(".png"):
			continue
		var stem: String = file.get_basename()
		var split: int = stem.rfind("_")
		if split <= 0:
			_fail("sheet %s has no <actor>_<clip> split" % file)
			continue
		var actor: String = stem.substr(0, split)
		var clip: StringName = StringName(stem.substr(split + 1))
		if not CLIPS.has(clip):
			_fail("sheet %s names clip %s, which has no timing entry" % [file, clip])
			continue
		if not grouped.has(actor):
			grouped[actor] = {}
		grouped[actor][clip] = "%s/%s" % [SHEET_DIRECTORY, file]
	return grouped


func _build_actor(actor: String, clips: Dictionary) -> Dictionary:
	var frames: SpriteFrames = SpriteFrames.new()
	# SpriteFrames is born holding a "default" animation. Leaving it in would
	# make every actor answer has_animation("default") and quietly play an empty
	# clip whenever a name lookup fell through.
	frames.remove_animation(&"default")

	var cell: int = 0
	var built: int = 0
	var clip_names: Array = clips.keys()
	clip_names.sort()
	for clip: StringName in clip_names:
		var sheet: Texture2D = load(clips[clip]) as Texture2D
		if sheet == null:
			_fail("%s: could not load sheet for clip %s" % [actor, clip])
			continue
		var size: Vector2i = sheet.get_size()
		if size.y % DIRECTIONS != 0:
			_fail("%s/%s: height %d is not %d rows" % [actor, clip, size.y, DIRECTIONS])
			continue
		var clip_cell: int = size.y / DIRECTIONS
		if clip_cell <= 0 or size.x % clip_cell != 0:
			_fail("%s/%s: width %d is not a whole number of %d px cells"
				% [actor, clip, size.x, clip_cell])
			continue
		# Clips are allowed different cell sizes. The bake renders every clip of
		# an actor at one shared px-per-unit from one fixed camera position and
		# grows only the ortho extent, so a wider cell is a symmetric expansion
		# around a world point all clips share. That is what lets `death` hold a
		# body lying flat - roughly twice as wide at a diagonal heading - without
		# shrinking the idle the player looks at all match.
		#
		# What must never vary is the density, and the check for that is below
		# rather than here: ground_offset is centre_y * cell / ortho_scale, i.e.
		# centre_y * density, so it is the same number of pixels in every clip
		# only while the density is shared. _load_ground_offsets failing an actor
		# whose clips disagree is precisely the proof that the figure cannot
		# change size mid-animation, and it survives cells that differ.
		if not _is_ladder_cell(clip_cell):
			_fail("%s/%s: cell %d is off the baked ladder (%d..%d step %d)"
				% [actor, clip, clip_cell, CELL_MIN, CELL_MAX, CELL_STEP])
			continue
		cell = maxi(cell, clip_cell)
		var columns: int = size.x / clip_cell
		var timing: Dictionary = CLIPS[clip]
		for row: int in range(DIRECTIONS):
			var animation: StringName = StringName("%s_%d" % [clip, row])
			frames.add_animation(animation)
			frames.set_animation_loop(animation, bool(timing[&"loop"]))
			frames.set_animation_speed(animation, float(timing[&"fps"]))
			for column: int in range(columns):
				var region: AtlasTexture = AtlasTexture.new()
				region.atlas = sheet
				region.region = Rect2(
					float(column * clip_cell), float(row * clip_cell),
					float(clip_cell), float(clip_cell)
				)
				# Without this an AtlasTexture bleeds the neighbouring cell's
				# edge pixels in when the sprite lands on a fractional position,
				# which at this size is a visible seam, not a subtle one.
				region.filter_clip = true
				frames.add_frame(animation, region)
			built += 1

	if built == 0:
		_fail("%s: produced no animations" % actor)
		return {}

	var frames_path: String = "%s/%s_frames.tres" % [FRAMES_DIRECTORY, actor]
	var save_error: int = ResourceSaver.save(frames, frames_path)
	if save_error != OK:
		_fail("%s: saving SpriteFrames failed (%d)" % [actor, save_error])
		return {}

	# Where the actor's feet sit inside the cell is a fact of the bake camera,
	# not a gameplay choice, so it is read from the sheet manifest the packer
	# wrote rather than being supplied by hand, and it re-derives itself the
	# moment a clip is re-baked.
	if not _ground_offsets.has(actor):
		_fail("%s: no ground_offset in %s" % [actor, SHEET_MANIFEST_PATH])
		return {}
	var foot_offset: float = _ground_offsets[actor]

	var scene_path: String = _build_scene(actor, frames_path, clips, foot_offset)
	if scene_path.is_empty():
		return {}

	return {
		&"actor": actor,
		&"cell": cell,
		&"clips": clip_names.size(),
		&"animations": built,
		&"foot_offset": foot_offset,
		&"frames": frames_path,
		&"scene": scene_path,
		&"generator": GENERATOR_PATH,
	}


## Where the ground plane lands inside a cell, per actor, as the packer recorded
## it. Positive values sit below the middle of the cell.
##
## This is deliberately not measured from the pixels. The bake stands each actor
## on z = 0 and aims one orthographic camera at a fixed point above that, so the
## standing point is exactly derivable from the framing; the lowest opaque pixel
## is not the same thing. A death clip lies the actor down and an attack clip
## lunges it forward, which drags the alpha bottom well past the feet, and the
## marker ring, the status arc and the flow field all address the feet.
func _load_ground_offsets() -> Dictionary:
	var file: FileAccess = FileAccess.open(SHEET_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		_fail("could not read %s" % SHEET_MANIFEST_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_ARRAY:
		_fail("%s is not a sheet array" % SHEET_MANIFEST_PATH)
		return {}
	var offsets: Dictionary = {}
	for entry: Variant in parsed:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = entry
		if not record.has("actor") or not record.has("ground_offset"):
			continue
		var actor: String = String(record["actor"])
		var offset: float = float(record["ground_offset"])
		# One camera frames every clip of an actor, so the clips must agree. If
		# they ever stop agreeing the bake changed mid-run and the sheets are
		# not a set any more - say so rather than picking one at random.
		if offsets.has(actor) and not is_equal_approx(offsets[actor], offset):
			_fail("%s: clips disagree on ground_offset (%f vs %f)"
				% [actor, offsets[actor], offset])
			continue
		offsets[actor] = offset
	return offsets


## One scene per actor, so the enemy catalog keeps preloading distinct
## PackedScenes exactly as it does today and nothing downstream learns that the
## visual changed shape.
func _build_scene(
	actor: String, frames_path: String, clips: Dictionary, foot_offset: float
) -> String:
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.name = &"WeatheredSprite"
	sprite.sprite_frames = load(frames_path) as SpriteFrames
	# Lift the cell so the soles land on the node origin. Everything the runtime
	# draws around an actor - the shape-coded marker ring, the status arc, the
	# ground shadow - is authored around the point it stands on, so a sprite
	# centred on its own middle would float every one of them at its waist.
	sprite.offset = Vector2(0.0, -foot_offset)
	# Row 2 is the heading that faces the camera - verified against the baked
	# pixels, not assumed - so an actor that is never told where it is looking
	# still faces the player rather than showing its back.
	sprite.animation = StringName("idle_%d" % ActorFacing.CAMERA_FACING_ROW) if clips.has(&"idle") else StringName("walk_%d" % ActorFacing.CAMERA_FACING_ROW)
	sprite.autoplay = String(sprite.animation)
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var scene: PackedScene = PackedScene.new()
	if scene.pack(sprite) != OK:
		_fail("%s: packing the presentation scene failed" % actor)
		sprite.free()
		return ""
	var scene_path: String = "%s/%s.tscn" % [SCENE_DIRECTORY, actor]
	var error: int = ResourceSaver.save(scene, scene_path)
	sprite.free()
	if error != OK:
		_fail("%s: saving the presentation scene failed (%d)" % [actor, error])
		return ""
	return scene_path


func _write_manifest(entries: Array[Dictionary]) -> void:
	var manifest: Dictionary = {
		&"generator": GENERATOR_PATH,
		&"sheet_directory": SHEET_DIRECTORY,
		&"directions": DIRECTIONS,
		&"clips": CLIPS,
		&"actors": entries,
	}
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		_fail("could not write %s" % MANIFEST_PATH)
		return
	file.store_string(JSON.stringify(manifest, "\t", false))
	file.close()


## A cell is legal when it sits on the ladder exactly. Divisibility alone is not
## enough - 8 and 24 both divide evenly and neither is a cell the bake can emit -
## so the lower bound does real work here rather than being decoration.
func _is_ladder_cell(cell: int) -> bool:
	return (
		cell >= CELL_MIN
		and cell <= CELL_MAX
		and (cell - CELL_MIN) % CELL_STEP == 0
	)


func _fail(message: String) -> void:
	_errors.append(message)
