extends SceneTree

## Focused gate for the shared health readout.
##
## Both readouts this replaces were technically functional and neither was
## usable: the survivors carried a font-7 Label spelling "HP 087", and the Base
## carried two flat rectangles that changed colour once at thirty percent. The
## gate therefore checks two different kinds of thing. The first is behaviour a
## headless run can hold exactly - that the chip lags a hit and then lands on the
## real value, that healing does not animate a bite that is no longer missing,
## and that an idle bar costs no frame.
##
## The second is the reason the first version of this bar was wrong, and it is
## the check that matters most here. Everything is drawn in world space and then
## divided by the 0.38 camera zoom, so dimensions chosen by eye in world units
## silently become fractions of a pixel: a one-unit outline lands at 0.38 px and
## is simply not there. Every thickness and both authored sizes are therefore
## converted back to screen pixels and required to survive the trip.

const BAR_SCRIPT_PATH: String = "res://src/visual/health_bar_2d.gd"
const AVATAR_SCRIPT_PATH: String = "res://src/game/player_avatar.gd"
const CORE_SCRIPT_PATH: String = "res://src/visual/core_pulse_driver.gd"
const PLAYER_SCENE_PATH: String = "res://scenes/characters/network_player.tscn"
const BASE_CORE_SCENE_PATH: String = "res://scenes/world/base_core.tscn"
const WORLD_SCENE_PATH: String = "res://scenes/game/game_world.tscn"
const CAMP_TEXTURE_PATH: String = "res://assets/2d/structures/base_camp_topdown.png"
## The share of its own subject a bar is allowed to span. A readout as wide as
## the thing it describes stops reading as that thing's readout and starts
## reading as a widget parked on the ground beside it.
const MAX_SUBJECT_WIDTH_FRACTION: float = 0.85
## How far below the lowest pixel of its subject the bar may hang, in world
## units. At the 0.38 gameplay zoom six units is a little over two screen pixels,
## which is the width of the gap that still reads as attached.
const MAX_DETACH_UNITS: float = 6.0
const CAMERA_ZOOM: float = 0.38
const FRAME_DELTA: float = 1.0 / 60.0
## A shape has to clear this on screen to be a bar rather than a smudge. One
## pixel is the floor for a line; a fill under two reads as a scratch.
const MIN_LINE_PX: float = 1.0
const MIN_FILL_PX: float = 2.0
const MIN_BAR_WIDTH_PX: float = 12.0
## The logical canvas. A readout past these fractions of it has stopped being a
## readout and become the interface.
const CANVAS: Vector2 = Vector2(480.0, 270.0)
const MAX_WIDTH_FRACTION: float = 0.30
const MAX_HEIGHT_FRACTION: float = 0.06

var _failures: PackedStringArray = PackedStringArray()
var _checks: int = 0


func _initialize() -> void:
	await process_frame
	var script: GDScript = load(BAR_SCRIPT_PATH)
	if script == null:
		_fail("health_bar_2d.gd failed to load")
		_report()
		return

	var bar: Node2D = script.new()
	root.add_child(bar)
	await process_frame

	# --- the camera divide -------------------------------------------------
	var to_world: float = float(script.SCREEN_TO_WORLD)
	_check(is_equal_approx(to_world * CAMERA_ZOOM, 1.0),
		"the world-per-pixel constant matches the gameplay camera zoom")
	for part: Array in [
		["outline", float(script.OUTLINE_SCREEN_PX)],
		["bevel", float(script.BEVEL_SCREEN_PX)],
		["tick", float(script.TICK_SCREEN_PX)],
	]:
		var px: float = float(part[1]) * to_world * CAMERA_ZOOM
		_check(px >= MIN_LINE_PX,
			"the %s survives the camera divide at %.2f screen px" % [part[0], px])

	# --- both owners authored a legible bar --------------------------------
	# Not the defaults of the node: the sizes that actually ship, read off the
	# two scripts that set them, so a later tuning pass cannot quietly shrink
	# one of them back under the divide.
	var avatar_script: GDScript = load(AVATAR_SCRIPT_PATH)
	var core_script: GDScript = load(CORE_SCRIPT_PATH)
	if avatar_script == null or core_script == null:
		_fail("the two bar owners failed to load")
		_report()
		return
	var outline_world: float = float(script.OUTLINE_SCREEN_PX) * to_world
	# Every number below is a screen measurement, so the owner's own scale has to
	# be in it. game_world.tscn instances the Base Core at Vector2(2, 2), and
	# without that factor this loop was quietly checking the refuge bar at half
	# its real size - passing bounds it had never actually been measured against.
	var refuge_scale: float = _instance_scale_x(WORLD_SCENE_PATH, "BaseCore")
	for owner: Array in [
		["survivor", avatar_script.HEALTH_BAR_SIZE,
			int(avatar_script.HEALTH_BAR_SEGMENTS), 1.0],
		["base core", core_script.HEALTH_BAR_SIZE,
			int(core_script.HEALTH_BAR_SEGMENTS), refuge_scale],
	]:
		var label: String = String(owner[0])
		var size: Vector2 = (owner[1] as Vector2) * float(owner[3])
		# The hairlines do not take the owner scale: HealthBar2D divides it back
		# out, so an outline is one screen pixel on each side whoever wears the
		# bar, and it is added in screen pixels rather than converted twice.
		var edge: float = float(script.OUTLINE_SCREEN_PX) * 2.0
		var drawn: Vector2 = size * CAMERA_ZOOM + Vector2(edge, edge)
		_check(size.y * CAMERA_ZOOM >= MIN_FILL_PX,
			"%s fill is %.2f screen px tall" % [label, size.y * CAMERA_ZOOM])
		_check(drawn.x >= MIN_BAR_WIDTH_PX,
			"%s bar is %.2f screen px wide" % [label, drawn.x])
		_check(drawn.x <= CANVAS.x * MAX_WIDTH_FRACTION,
			"%s bar stays under %d%% of the canvas width (%.2f px)"
			% [label, int(MAX_WIDTH_FRACTION * 100.0), drawn.x])
		_check(drawn.y <= CANVAS.y * MAX_HEIGHT_FRACTION,
			"%s bar stays under %d%% of the canvas height (%.2f px)"
			% [label, int(MAX_HEIGHT_FRACTION * 100.0), drawn.y])
		# A divider must be narrower than what it divides. Three ticks across a
		# fourteen-pixel bar make a striped block, not a segmented one.
		var tick_px: float = float(script.TICK_SCREEN_PX)
		var ink: float = tick_px * float(maxi(int(owner[2]) - 1, 0))
		_check(ink <= drawn.x * 0.25,
			"%s ticks take %.2f of %.2f screen px, under a quarter of the bar"
			% [label, ink, drawn.x])

	# --- the chip is the whole point ---------------------------------------
	bar.setup(avatar_script.HEALTH_BAR_SIZE, int(avatar_script.HEALTH_BAR_SEGMENTS), true)
	bar.reset_to(1.0)
	_check(is_equal_approx(bar.get_chip_ratio(), 1.0) and not bar.is_processing(),
		"a bar reset to full carries no chip and costs no frame")
	bar.set_ratio(0.7)
	_check(is_equal_approx(bar.get_ratio(), 0.7),
		"a hit moves the real bar immediately")
	_check(bar.get_chip_ratio() > bar.get_ratio(),
		"a hit leaves the chip behind to show the bite")
	_check(bar.is_processing(),
		"a draining chip asks for the frame it needs")
	# During the hold the chip must not move at all - that pause is what gives
	# the eye time to find the bite before it starts closing.
	var held: float = bar.get_chip_ratio()
	bar._process(float(script.CHIP_HOLD_SECONDS) * 0.5)
	_check(is_equal_approx(bar.get_chip_ratio(), held),
		"the chip holds still for the authored pause")
	for _frame: int in 240:
		bar._process(FRAME_DELTA)
	_check(is_equal_approx(bar.get_chip_ratio(), 0.7),
		"the chip lands exactly on the real value (found %.4f)" % bar.get_chip_ratio())
	_check(not bar.is_processing(),
		"a settled chip stops processing rather than ticking forever")

	# A second hit mid-drain has to re-arm the pause, or a burst of fire reads
	# as one long slide instead of as separate hits.
	bar.set_ratio(0.5)
	bar._process(FRAME_DELTA)
	bar.set_ratio(0.4)
	var mid: float = bar.get_chip_ratio()
	bar._process(float(script.CHIP_HOLD_SECONDS) * 0.5)
	_check(is_equal_approx(bar.get_chip_ratio(), mid),
		"a second hit re-arms the hold instead of continuing the drain")

	bar.set_ratio(0.95)
	_check(is_equal_approx(bar.get_chip_ratio(), 0.95),
		"healing snaps the chip up rather than drawing a bite that already closed")

	# --- bands, and urgency that survives without hue ----------------------
	bar.reset_to(0.9)
	_check(bar._band_color() == script.COLOR_HEALTHY, "a full bar reads healthy")
	bar.reset_to(float(script.HURT_RATIO))
	_check(bar._band_color() == script.COLOR_HURT, "the hurt band starts at its stop")
	bar.reset_to(float(script.CRITICAL_RATIO))
	_check(bar._band_color() == script.COLOR_CRITICAL, "the critical band starts at its stop")
	_check(bar.is_processing(),
		"a critical bar pulses, so state carries without depending on hue")
	bar.reset_to(0.9)
	_check(not bar.is_processing(), "a healthy bar at rest costs no frame")

	# --- the palette contract ----------------------------------------------
	# CLAUDE.md 8 makes the Base Core the only dominant Amber Gold on screen, so
	# a damaged body must not light a second focal warmth, and a dying bar must
	# not land on the rust of the world and read as more corrosion.
	var hurt: Color = script.COLOR_HURT
	var critical: Color = script.COLOR_CRITICAL
	_check(_distance(hurt, Color("ffb52e")) > 0.2,
		"the hurt band is clear of the Base Core amber")
	_check(_distance(hurt, Color("ffd45a")) > 0.2,
		"the hurt band is clear of the Heikki gold identity accent")
	_check(_distance(critical, Color("bc431a")) > 0.2,
		"the critical band is clear of the palette rust bloom")
	_check(script.COLOR_OUTLINE == Color("060909"),
		"the outline is the palette void charcoal")

	# --- hiding ------------------------------------------------------------
	bar.setup(avatar_script.HEALTH_BAR_SIZE, 2, true)
	bar.reset_to(1.0)
	_check(not bar._is_visible_now(), "a survivor at full health carries no clutter")
	bar.setup(core_script.HEALTH_BAR_SIZE, 4, false)
	_check(bar._is_visible_now(),
		"the Base stays readable at full because it is the objective")
	bar.set_active(false)
	_check(not bar._is_visible_now() and not bar.is_processing(),
		"a dead subject shows nothing rather than an empty frame")
	bar.set_active(true)

	# --- hostile input -----------------------------------------------------
	for bad: float in [NAN, INF, -INF]:
		bar.set_ratio(bad)
		_check(is_finite(bar.get_ratio()) and bar.get_ratio() >= 0.0,
			"a non-finite ratio is refused rather than drawn")
	bar.set_ratio(4.0)
	_check(is_equal_approx(bar.get_ratio(), 1.0), "a ratio above one clamps to full")
	bar.setup(Vector2(-8.0, 0.0), 0, true)
	_check(bar.bar_size.x > 0.0 and bar.bar_size.y > 0.0 and bar.segments >= 1,
		"a degenerate setup is clamped to something drawable")
	bar.queue_free()

	# --- the two owners actually adopted it --------------------------------
	var core_source: String = FileAccess.get_file_as_string(CORE_SCRIPT_PATH)
	_check(not core_source.contains("func _draw()"),
		"the Base Core no longer hand-draws its own pair of rectangles")
	_check(core_source.contains("HealthBar2D.new()"),
		"the Base Core builds the shared bar in code, so its setter cannot be orphaned")
	var avatar_source: String = FileAccess.get_file_as_string(AVATAR_SCRIPT_PATH)
	_check(not avatar_source.contains("HP %"),
		"the survivor readout is no longer three digits at seven pixels")
	_check(avatar_source.contains("health_bar.reset_to("),
		"a respawn snaps the bar instead of animating a recovery that never happened")

	# --- where the survivor bar hangs --------------------------------------
	# Read out of the scene text rather than by instancing the avatar, which
	# needs a session and a roster this gate has no business standing up.
	var scene_source: String = FileAccess.get_file_as_string(PLAYER_SCENE_PATH)
	var bar_y: float = _node_position_y(scene_source, "HealthBar")
	var name_bottom: float = _property_after(scene_source, "NameLabel", "offset_bottom")
	var bar_top: float = bar_y - outline_world
	var bar_bottom: float = bar_y + (avatar_script.HEALTH_BAR_SIZE as Vector2).y + outline_world
	_check(bar_y < 0.0, "the bar hangs above the survivor rather than under his feet")
	_check(bar_bottom < -40.0,
		"the bar clears the head at %.1f rather than sitting on the chest" % bar_bottom)
	_check(name_bottom <= bar_top + 1.0,
		"the name sits above the bar (%.1f) instead of over the body (%.1f)"
		% [name_bottom, bar_top])

	_validate_refuge_proportion(core_script, avatar_script)
	_validate_rest_treatment(script, core_script, avatar_script, refuge_scale)
	await _validate_core_health_tiers(core_script)
	_report()


## The Base bar is the only one on screen the whole match, and the loudest thing
## in the frame is not what a permanently visible readout should be. Measured off
## the camp capture it ran at mean luma 202 and 0.84 saturation against a frame
## mean of 57. What is checked here is the shape of the rule rather than the
## number: at rest the fill has to be substantially quieter than the same bar
## carrying information, the first point of damage has to restore it in full, and
## a bar that hides at full - every survivor and every zombie - must never enter
## the resting state at all, because for them full health is simply invisible.
func _validate_rest_treatment(script: GDScript, core_script: GDScript,
		avatar_script: GDScript, refuge_scale: float) -> void:
	var refuge: Node2D = script.new()
	refuge.setup(core_script.HEALTH_BAR_SIZE, int(core_script.HEALTH_BAR_SEGMENTS), false)
	refuge.reset_to(1.0)
	root.add_child(refuge)
	_check(refuge.is_resting(), "the refuge bar rests while the Base is untouched")
	var rest: Color = refuge.fill_color()
	var rest_bevel: Color = refuge.bevel_color()
	_check(not refuge.is_processing(), "a resting bar still costs no frame callback")

	# One point of damage out of the Base's sixteen hundred, which is the smallest
	# thing that can happen to it. It has to be enough to wake the readout.
	refuge.set_ratio(1.0 - 1.0 / 1600.0)
	_check(not refuge.is_resting(), "the first point of damage takes the bar off rest")
	var alert: Color = refuge.fill_color()
	var alert_bevel: Color = refuge.bevel_color()
	_check(is_equal_approx(alert.r, script.COLOR_HEALTHY.r)
			and is_equal_approx(alert.g, script.COLOR_HEALTHY.g)
			and is_equal_approx(alert.b, script.COLOR_HEALTHY.b),
		"a damaged bar draws the full band colour rather than a dimmed one")
	_check(_luma(rest) < _luma(alert) * 0.6,
		"the resting bar is well under the alerted one (%.0f against %.0f)"
		% [_luma(rest), _luma(alert)])
	# Quieter, not gone. It is still a readout and still has to be findable.
	_check(_luma(rest) > _luma(script.COLOR_BACKING) + 30.0,
		"the resting bar still separates from its own backing (%.0f)" % _luma(rest))
	_check(rest.a >= 1.0,
		"the rest treatment darkens rather than fading, so the terrain behind it "
		+ "cannot tint the bar")

	# Healing back to full returns it to rest rather than leaving it lit forever.
	refuge.reset_to(1.0)
	_check(refuge.is_resting(), "a repaired Base settles back to rest")

	# --- the bevel obeys the rest treatment as well as the fill ---------------
	# The bevel is the brightest thing the bar draws, so it is the element the
	# rest treatment most has to reach - and it was the one element the rest
	# treatment did not reach. Color.lightened is affine toward white, so
	# lifting an already darkened fill re-inflates it: REST_DARKEN's 0.45
	# arrived as 0.72 and the resting bevel sat at 1.85x its own fill against
	# the 1.15x every other state ships, which measured 210.7 luma on the camp
	# capture where the fill it sits on measured 110.0. Asserting on
	# fill_color() alone could never have caught it, because a gate that tests
	# the input to a compressive operator does not test its output.
	var rest_lift: float = _luma(rest_bevel) / maxf(_luma(rest), 1.0)
	var alert_lift: float = _luma(alert_bevel) / maxf(_luma(alert), 1.0)
	_check(absf(rest_lift - alert_lift) < 0.05,
		"the bevel lifts off a resting fill by the same ratio as an alerted one "
		+ "(%.2fx against %.2fx)" % [rest_lift, alert_lift])
	_check(rest_lift > 1.05,
		"the resting bevel is still a visible lift rather than flat (%.2fx)"
		% rest_lift)
	_check(_luma(rest_bevel) < _luma(alert_bevel) * 0.6,
		"the resting bevel is quieted as far as the resting fill is "
		+ "(%.0f against %.0f)" % [_luma(rest_bevel), _luma(alert_bevel)])
	_check(rest_bevel.a >= 1.0,
		"the bevel darkens rather than fading, exactly like the fill under it")

	# --- one outline weight, which is the whole reason this is one class -----
	# The bar body is allowed to differ between owners; the hairlines are not.
	# game_world.tscn places the Base Core at Vector2(2, 2), so before the class
	# divided its own scale back out, the refuge drew every outline, bevel and
	# tick at two screen pixels against the survivors' one.
	var scaled: Node2D = script.new()
	scaled.setup(core_script.HEALTH_BAR_SIZE, int(core_script.HEALTH_BAR_SEGMENTS), false)
	root.add_child(scaled)
	var unit_pixel: float = refuge.call("_pixel")
	scaled.scale = Vector2(refuge_scale, refuge_scale)
	_check(is_equal_approx(scaled.call("_pixel") * refuge_scale, unit_pixel),
		"a bar worn at %.1fx still draws a one-pixel outline" % refuge_scale)
	scaled.scale = Vector2.ONE
	_check(is_equal_approx(scaled.call("_pixel"), unit_pixel),
		"an unscaled bar is unchanged by the compensation")
	scaled.queue_free()

	var survivor: Node2D = script.new()
	survivor.setup(avatar_script.HEALTH_BAR_SIZE, int(avatar_script.HEALTH_BAR_SEGMENTS), true)
	survivor.reset_to(1.0)
	root.add_child(survivor)
	_check(not survivor.is_resting(),
		"a bar that hides at full never rests, because it is not on screen to rest")
	survivor.set_ratio(0.9)
	_check(is_equal_approx(_luma(survivor.fill_color()), _luma(script.COLOR_HEALTHY)),
		"a lightly hurt survivor still draws at full strength")
	refuge.queue_free()
	survivor.queue_free()


## The Base Core tier is derived from the exact same stops as [HealthBar2D],
## but must remain a presentation-only change. This gate instances the real
## BaseCore scene so it observes the owned materials and light rather than a
## duplicate palette in test code, then verifies every threshold and the fact
## that collision/transform geometry remains untouched through the transitions.
func _validate_core_health_tiers(_core_script: GDScript) -> void:
	var core_scene: PackedScene = load(BASE_CORE_SCENE_PATH) as PackedScene
	if core_scene == null:
		_fail("the Base Core scene failed to load for health-tier validation")
		return
	var core: CorePulseDriver = core_scene.instantiate() as CorePulseDriver
	if core == null:
		_fail("the Base Core scene did not instantiate as CorePulseDriver")
		return
	root.add_child(core)
	await process_frame

	var health_bar: HealthBar2D = core.get_health_bar()
	var core_sprite: Sprite2D = core.get_core_sprite()
	var aura: Sprite2D = core.get_node_or_null("Aura") as Sprite2D
	var glow: Sprite2D = core.get_node_or_null("GlowSilhouette") as Sprite2D
	var light: PointLight2D = core.get_node_or_null("AmberLight") as PointLight2D
	var static_body: StaticBody2D = core.get_node_or_null("StaticBody2D") as StaticBody2D
	var collision: CollisionShape2D = core.get_node_or_null(
		"StaticBody2D/CollisionShape2D"
	) as CollisionShape2D
	var core_material: ShaderMaterial = core_sprite.material as ShaderMaterial if core_sprite != null else null
	var aura_material: ShaderMaterial = aura.material as ShaderMaterial if aura != null else null
	var glow_material: ShaderMaterial = glow.material as ShaderMaterial if glow != null else null
	if (
		health_bar == null or core_sprite == null or aura == null or glow == null
		or light == null or static_body == null or collision == null
		or core_material == null or aura_material == null or glow_material == null
	):
		_fail("the Base Core tier gate could not resolve its existing visual nodes and materials")
		core.queue_free()
		await process_frame
		return

	var core_position: Vector2 = core_sprite.position
	var core_scale: Vector2 = core_sprite.scale
	var aura_position: Vector2 = aura.position
	var aura_scale: Vector2 = aura.scale
	var glow_position: Vector2 = glow.position
	var glow_scale: Vector2 = glow.scale
	var light_position: Vector2 = light.position
	var collision_layer: int = static_body.collision_layer
	var collision_mask: int = static_body.collision_mask
	var collision_shape: Shape2D = collision.shape
	var bar_position: Vector2 = health_bar.position
	var bar_size: Vector2 = health_bar.bar_size

	_check(
		core.get_health_visual_tier() == CorePulseDriver.HealthVisualTier.HEALTHY
		and health_bar.is_active(),
		"a full Base Core begins in the healthy tier with its objective bar active"
	)
	var healthy_emission: float = float(core_material.get_shader_parameter(&"emission_strength"))
	var healthy_aura_intensity: float = float(aura_material.get_shader_parameter(&"intensity"))
	var healthy_aura_edge_power: float = float(aura_material.get_shader_parameter(&"edge_power"))
	var healthy_glow_strength: float = float(glow_material.get_shader_parameter(&"glow_strength"))
	var healthy_glow_scale_amount: float = float(glow_material.get_shader_parameter(&"scale_amount"))
	var healthy_light_energy: float = light.energy

	core.set_health_ratio(HealthBar2D.HURT_RATIO)
	await process_frame
	_check(
		core.get_health_visual_tier() == CorePulseDriver.HealthVisualTier.DAMAGED
		and health_bar.is_active(),
		"the HealthBar hurt stop enters the damaged Core tier without hiding the bar"
	)
	_check(
		float(core_material.get_shader_parameter(&"emission_strength")) < healthy_emission
		and float(aura_material.get_shader_parameter(&"intensity")) < healthy_aura_intensity
		and float(glow_material.get_shader_parameter(&"glow_strength")) < healthy_glow_strength
		and light.energy < healthy_light_energy,
		"the damaged tier subdues the existing materials and amber light"
	)

	core.set_health_ratio(HealthBar2D.CRITICAL_RATIO)
	await process_frame
	_check(
		core.get_health_visual_tier() == CorePulseDriver.HealthVisualTier.CRITICAL
		and health_bar.is_active(),
		"the HealthBar critical stop enters the critical Core tier while the bar stays active"
	)
	_check(
		float(core_material.get_shader_parameter(&"emission_strength")) > healthy_emission
		and float(aura_material.get_shader_parameter(&"intensity")) > healthy_aura_intensity
		and float(aura_material.get_shader_parameter(&"edge_power")) < healthy_aura_edge_power
		and float(glow_material.get_shader_parameter(&"glow_strength")) > healthy_glow_strength
		and float(glow_material.get_shader_parameter(&"scale_amount")) > healthy_glow_scale_amount
		and float(core_material.get_shader_parameter(&"pulse_speed")) > 0.0,
		"the critical tier restores a brighter, wider material-only warning without changing geometry"
	)

	core.set_health_ratio(0.0)
	await process_frame
	_check(
		core.get_health_visual_tier() == CorePulseDriver.HealthVisualTier.DESTROYED
		and not health_bar.is_active(),
		"only a zero-health Base Core enters destroyed and deactivates its bar"
	)
	_check(
		is_zero_approx(float(core_material.get_shader_parameter(&"emission_strength")))
		and is_zero_approx(float(aura_material.get_shader_parameter(&"intensity")))
		and is_zero_approx(float(glow_material.get_shader_parameter(&"glow_strength")))
		and is_zero_approx(light.energy),
		"the destroyed tier extinguishes only existing material and light energy"
	)

	core.set_health_ratio(0.01)
	await process_frame
	_check(
		core.get_health_visual_tier() == CorePulseDriver.HealthVisualTier.CRITICAL
		and health_bar.is_active()
		and is_equal_approx(health_bar.get_ratio(), 0.01),
		"a non-zero recovery restores the critical tier and reactivates the bar"
	)
	_check(
		core_sprite.position.is_equal_approx(core_position)
		and core_sprite.scale.is_equal_approx(core_scale)
		and aura.position.is_equal_approx(aura_position)
		and aura.scale.is_equal_approx(aura_scale)
		and glow.position.is_equal_approx(glow_position)
		and glow.scale.is_equal_approx(glow_scale)
		and light.position.is_equal_approx(light_position)
		and static_body.collision_layer == collision_layer
		and static_body.collision_mask == collision_mask
		and collision.shape == collision_shape
		and health_bar.position.is_equal_approx(bar_position)
		and health_bar.bar_size.is_equal_approx(bar_size),
		"Core health tiers leave sprite silhouette, collision, and bar layout unchanged"
	)
	core.queue_free()
	await process_frame


## A bar has to belong to its subject, and the only way to check that is to
## measure the subject. Every bound above is absolute or canvas-relative, and a
## Base bar of 108 world units passed all of them happily - it is well inside 30
## percent of the canvas and far over every minimum - while the camp it hangs
## under is 92 units across. The readout was drawing at 117 percent of the thing
## it described with 24 units of bare ground between the two, which is a green
## widget lying on the terrain rather than the refuge's own state, and it pulled
## focus CLAUDE.md 8 reserves for the Base Core alone.
##
## Nothing here is authored twice. The width comes from the shipped texture's own
## alpha bounds through the Core node's scale, so a rebake that changes the
## camp's footprint moves this bound with it instead of going quietly stale.
func _validate_refuge_proportion(core_script: GDScript, avatar_script: GDScript) -> void:
	var scene_source: String = FileAccess.get_file_as_string(BASE_CORE_SCENE_PATH)
	var texture: Texture2D = load(CAMP_TEXTURE_PATH)
	if scene_source.is_empty() or texture == null:
		_fail("the base core scene or its camp texture could not be read")
		return
	var image: Image = texture.get_image()
	if image == null:
		_fail("the camp texture carries no image to measure")
		return
	if image.is_compressed():
		image.decompress()
	var used: Rect2i = image.get_used_rect()
	var core_scale: float = _scale_x(scene_source, "Core")
	var refuge_width: float = float(used.size.x) * core_scale
	# The sprite is centred on its node, so the content bottom is measured from
	# the middle of the texture rather than from its top edge.
	var refuge_bottom: float = _node_position_y(scene_source, "Core") + core_scale * (
		float(used.position.y + used.size.y) - float(image.get_height()) * 0.5
	)

	var size: Vector2 = core_script.HEALTH_BAR_SIZE as Vector2
	var offset: Vector2 = core_script.HEALTH_BAR_OFFSET as Vector2
	_check(refuge_width > 1.0,
		"the camp measures %.1f world units across its own alpha" % refuge_width)
	_check(size.x <= refuge_width * MAX_SUBJECT_WIDTH_FRACTION,
		"the refuge bar spans %.0f%% of the camp, within %.0f%%"
		% [100.0 * size.x / maxf(refuge_width, 1.0), 100.0 * MAX_SUBJECT_WIDTH_FRACTION])
	var detach: float = offset.y - refuge_bottom
	_check(detach >= 0.0 and detach <= MAX_DETACH_UNITS,
		"the refuge bar hangs %.1f units under the camp, inside 0 to %.1f"
		% [detach, MAX_DETACH_UNITS])
	# Narrower than the camp, but still wider than a survivor, or the hierarchy
	# inverts and the objective reads as the least important thing on screen.
	_check(size.x > (avatar_script.HEALTH_BAR_SIZE as Vector2).x,
		"the refuge bar stays wider than a survivor's (%.0f against %.0f)"
		% [size.x, (avatar_script.HEALTH_BAR_SIZE as Vector2).x])


## The scale an instanced sub-scene is placed at by its parent scene. Separate
## from [method _scale_x] because an instance block carries no type= field and
## the property may sit several lines below the header.
func _instance_scale_x(scene_path: String, node_name: String) -> float:
	var source: String = FileAccess.get_file_as_string(scene_path)
	var at: int = source.find("[node name=\"%s\"" % node_name)
	if at < 0:
		_fail("%s is not instanced in %s" % [node_name, scene_path])
		return 1.0
	var block: String = source.substr(at)
	var end: int = block.find("
[node ")
	if end > 0:
		block = block.substr(0, end)
	var key: int = block.find("scale = Vector2(")
	if key < 0:
		# No scale line means the instance sits at one, which is legitimate.
		return 1.0
	var open: int = key + "scale = Vector2(".length()
	return float(block.substr(open, block.find(",", open) - open).strip_edges())


## The uniform scale off one node in a scene file. Vector2(0.42, 0.42) in
## practice, but read rather than assumed so a rescale is picked up here too.
func _scale_x(source: String, node_name: String) -> float:
	var at: int = source.find("[node name=\"%s\"" % node_name)
	if at < 0:
		_fail("%s is missing from the scene" % node_name)
		return 0.0
	var tail: String = source.substr(at)
	var key: int = tail.find("scale = Vector2(")
	if key < 0:
		_fail("%s has no authored scale" % node_name)
		return 0.0
	var open: int = key + "scale = Vector2(".length()
	return float(tail.substr(open, tail.find(",", open) - open).strip_edges())


## Rec. 709 luma, on the 0..255 scale the capture measurements are quoted in.
func _luma(c: Color) -> float:
	return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0


## Straight RGB distance. Crude on purpose - the question is only whether two
## authored constants are the same colour, not how a person perceives them.
func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _node_position_y(source: String, node_name: String) -> float:
	var at: int = source.find("[node name=\"%s\"" % node_name)
	if at < 0:
		_fail("%s is missing from the scene" % node_name)
		return 0.0
	var tail: String = source.substr(at)
	var key: int = tail.find("position = Vector2(")
	if key < 0:
		_fail("%s has no position in the player scene" % node_name)
		return 0.0
	var open: int = key + "position = Vector2(".length()
	var parts: PackedStringArray = tail.substr(open, tail.find(")", open) - open).split(",")
	return float(parts[1].strip_edges()) if parts.size() > 1 else 0.0


func _property_after(source: String, node_name: String, property: String) -> float:
	var at: int = source.find("[node name=\"%s\"" % node_name)
	if at < 0:
		_fail("%s is missing from the scene" % node_name)
		return 0.0
	var tail: String = source.substr(at)
	var key: int = tail.find("%s = " % property)
	if key < 0:
		_fail("%s has no %s in the player scene" % [node_name, property])
		return 0.0
	var open: int = key + ("%s = " % property).length()
	return float(tail.substr(open, tail.find("\n", open) - open).strip_edges())


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)


func _fail(description: String) -> void:
	_checks += 1
	_failures.append(description)


func _report() -> void:
	if _failures.is_empty():
		print("HEALTH READABILITY OK (%d checks)" % _checks)
		quit(0)
		return
	for failure: String in _failures:
		print("FAIL: %s" % failure)
	print("HEALTH READABILITY FAILED (%d of %d checks)" % [_failures.size(), _checks])
	quit(1)
