extends SceneTree

## Focused gate for the hit response.
##
## Two contracts matter more than the look of the wash. The first is the mobile
## budget: CLAUDE.md 10 allows exactly one full-screen custom pass and tells us
## to combine atmosphere into the existing weather shader rather than stack a
## second one, so the damage vignette lives in weather_overlay.gdshader and the
## game scene must still carry only one such pass. The second is the off switch
## CLAUDE.md 11 requires before an effect like this can be locked into content
## production - a full-frame red pulse has to be removable outright by a
## photosensitive player, which means zero has to mean absent rather than dim.
##
## The rest are the ways a decaying screen effect goes wrong in practice: a wash
## that never quite reaches zero and leaves the frame permanently tinted, one
## that keeps a process callback alive forever, or a non-finite health fraction
## arriving from the replicated combat path and poisoning a shader uniform.

const OVERLAY_SCRIPT_PATH: String = "res://src/visual/weather_overlay.gd"
const SHADER_PATH: String = "res://shaders/weather_overlay.gdshader"
const WORLD_SCENE_PATH: String = "res://scenes/game/game_world.tscn"
const WORLD_SCRIPT_PATH: String = "res://src/game/game_world.gd"
## Enough frames at 60 Hz to cover a full decay from peak with room to spare.
const DECAY_FRAMES: int = 90
const FRAME_DELTA: float = 1.0 / 60.0
## The HUD owns CanvasLayer 100. A screen effect above it would paint over the
## dashboard the player reads while he is being hit, which is exactly backwards.
const HUD_LAYER: int = 100

var _failures: PackedStringArray = PackedStringArray()
var _checks: int = 0


func _initialize() -> void:
	await process_frame
	var script: GDScript = load(OVERLAY_SCRIPT_PATH)
	var shader: Shader = load(SHADER_PATH)
	if script == null or shader == null:
		_fail("weather_overlay script or shader failed to load")
		_report()
		return

	_validate_shader(shader)
	_validate_scene()
	_validate_wiring()
	await _validate_runtime(script, shader)
	_report()


## The vignette has to be edge weighted. A wash centred on the canvas would sit
## over the survivor at the moment the player most needs to see where he is
## standing, so the hit reads as a band closing in from the frame instead.
func _validate_shader(shader: Shader) -> void:
	var code: String = shader.code
	_check(code.contains("uniform float damage"),
		"the weather pass exposes a damage uniform")
	_check(code.contains("damage_tint"),
		"the damage colour is authored as a uniform rather than hard coded")
	_check(code.contains("length(UV - 0.5)") and code.contains("smoothstep"),
		"the hit wash is weighted toward the frame edge")
	_check(code.count("void fragment()") == 1,
		"weather and damage composite in one fragment pass")


## The one-pass budget, read off the shipping scene rather than trusted.
func _validate_scene() -> void:
	var text: String = FileAccess.get_file_as_string(WORLD_SCENE_PATH)
	if text.is_empty():
		_fail("game_world.tscn could not be read")
		return
	var full_screen_passes: int = 0
	var overlay_layer: int = -1
	var layer_of_current: int = -1
	for block: String in text.split("[node "):
		# The text before the first node is the ext_resource header, which names
		# the same script and would otherwise be counted as a second pass.
		if not block.begins_with("name="):
			continue
		if block.begins_with("name=\"ScreenEffects\"") and block.contains("CanvasLayer"):
			layer_of_current = _int_after(block, "layer = ")
		if not block.contains("weather_overlay.gd") and not block.contains("22_weather"):
			continue
		full_screen_passes += 1
		overlay_layer = layer_of_current
		_check(block.contains("mouse_filter = 2"),
			"the full-screen pass never intercepts touch input")
		_check(block.contains("anchor_right = 1.0") and block.contains("anchor_bottom = 1.0"),
			"the full-screen pass actually covers the canvas")
		_check(block.contains("intensity = 0.0"),
			"weather ships off, so this slice changes the look of nothing")
	_check(full_screen_passes == 1,
		"the game scene carries exactly one full-screen custom pass (found %d)"
		% full_screen_passes)
	_check(overlay_layer > 0 and overlay_layer < HUD_LAYER,
		"screen effects sit above the world and below the HUD (layer %d)" % overlay_layer)


## Read off the source, because a signal that is emitted and connected nowhere is
## exactly the state this slice existed to fix and is invisible at runtime.
func _validate_wiring() -> void:
	var text: String = FileAccess.get_file_as_string(WORLD_SCRIPT_PATH)
	if text.is_empty():
		_fail("game_world.gd could not be read")
		return
	_check(text.contains("combat_state.player_health_changed.connect("),
		"losing health reaches the screen at all")
	_check(text.contains("combat_state.base_health_changed.connect("),
		"the refuge being chewed on reaches the screen at all")
	_check(text.contains("screen_effects.flash("),
		"a hit raises the wash")
	_check(text.contains("screen_effects.clear_damage()"),
		"respawning clears the wash rather than leaving the last hit painted on")
	_check(text.contains("SHAKE_LOCAL_DAMAGE_MIN") and text.contains("SHAKE_LOCAL_DAMAGE_MAX"),
		"the damage jolt scales with the size of the blow")
	_check(text.contains("BASE_DAMAGE_WINDOW_SECONDS"),
		"base damage is accumulated over a window instead of jolting per zombie hit")
	_check(text.contains("_shake_at(base_core.global_position"),
		"the refuge jolt is placed in the world so it fades with distance")


func _validate_runtime(script: GDScript, shader: Shader) -> void:
	var overlay: ColorRect = ColorRect.new()
	var shader_material: ShaderMaterial = ShaderMaterial.new()
	shader_material.shader = shader
	overlay.material = shader_material
	overlay.set_script(script)
	overlay.intensity = 0.0
	root.add_child(overlay)
	await process_frame

	var peak: float = float(script.DAMAGE_PEAK)
	_check(is_equal_approx(overlay.get_damage_wash(), 0.0),
		"a fresh overlay starts clear")
	_check(not overlay.is_processing(),
		"an idle overlay costs no frame callback")
	_check(_uniform(overlay) == 0.0,
		"the shader uniform starts at exactly zero")

	# --- the accessibility contract ---------------------------------------
	overlay.damage_intensity_scale = 0.0
	for _hit: int in 20:
		overlay.flash(1.0)
	_check(overlay.get_damage_wash() == 0.0 and _uniform(overlay) == 0.0,
		"scale 0 leaves the uniform at exactly zero rather than merely dimmer")
	_check(not overlay.is_processing(),
		"scale 0 never starts a decay there is nothing to decay")

	# --- a hit reads, and reads in proportion -----------------------------
	overlay.damage_intensity_scale = 1.0
	overlay.flash(0.25)
	var graze: float = overlay.get_damage_wash()
	_check(graze > 0.0 and graze < peak,
		"a graze washes the frame less than a full hit (%.3f of %.3f)" % [graze, peak])
	_check(overlay.is_processing(), "a raised wash starts decaying")
	overlay.flash(0.6)
	var solid: float = overlay.get_damage_wash()
	_check(solid > graze, "a heavier blow washes harder")
	# The strongest pending flash wins rather than the sum. Two hits inside one
	# frame are still one thing happening, and summing them would saturate the
	# frame on any burst of contact.
	overlay.flash(0.6)
	_check(is_equal_approx(overlay.get_damage_wash(), solid),
		"simultaneous hits take the strongest rather than adding up")
	overlay.flash(0.1)
	_check(is_equal_approx(overlay.get_damage_wash(), solid),
		"a graze arriving during a heavier wash does not weaken it")
	overlay.flash(9.0)
	_check(overlay.get_damage_wash() <= peak + 0.0001,
		"a fraction above one clamps at the authored peak (found %.3f)"
		% overlay.get_damage_wash())
	_check(is_equal_approx(_uniform(overlay), overlay.get_damage_wash()),
		"the uniform tracks the wash rather than drifting from it")

	# --- returns exactly to clear -----------------------------------------
	# Not close to clear: a frame left faintly red stays that way for the rest of
	# the session, and every later hit starts from that error.
	for _frame: int in DECAY_FRAMES:
		overlay._process(FRAME_DELTA)
	_check(overlay.get_damage_wash() == 0.0,
		"the wash decays to exactly zero within %.2f seconds"
		% (DECAY_FRAMES * FRAME_DELTA))
	_check(_uniform(overlay) == 0.0,
		"a spent wash leaves the uniform at exactly zero")
	_check(not overlay.is_processing(),
		"a spent wash stops processing instead of ticking a zero uniform forever")

	# --- hostile input -----------------------------------------------------
	# The fraction is derived from replicated health values, and a single NAN
	# reaching a shader uniform is not something a frame recovers from.
	for bad: float in [NAN, INF, -INF, 0.0, -0.5]:
		overlay.flash(bad)
	_check(overlay.get_damage_wash() == 0.0 and not overlay.is_processing(),
		"non-finite and non-positive fractions are rejected before they reach the uniform")

	# --- clearing on respawn ----------------------------------------------
	overlay.flash(1.0)
	overlay.clear_damage()
	_check(overlay.get_damage_wash() == 0.0 and _uniform(overlay) == 0.0,
		"clear_damage drops the wash immediately")
	_check(not overlay.is_processing(),
		"clear_damage also releases the frame callback")

	# --- the pass does not eat touches ------------------------------------
	_check(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"the overlay forces itself out of the input path on ready")
	overlay.queue_free()


func _uniform(overlay: ColorRect) -> float:
	var shader_material: ShaderMaterial = overlay.material as ShaderMaterial
	if shader_material == null:
		return -1.0
	var value: Variant = shader_material.get_shader_parameter(&"damage")
	return float(value) if value != null else -1.0


func _int_after(block: String, key: String) -> int:
	var at: int = block.find(key)
	if at < 0:
		return -1
	var tail: String = block.substr(at + key.length())
	var end: int = tail.find("\n")
	return int(tail.substr(0, end) if end >= 0 else tail)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)


func _fail(description: String) -> void:
	_checks += 1
	_failures.append(description)


func _report() -> void:
	if _failures.is_empty():
		print("DAMAGE FEEDBACK OK (%d checks)" % _checks)
		quit(0)
		return
	for failure: String in _failures:
		print("FAIL: %s" % failure)
	print("DAMAGE FEEDBACK FAILED (%d of %d checks)" % [_failures.size(), _checks])
	quit(1)
