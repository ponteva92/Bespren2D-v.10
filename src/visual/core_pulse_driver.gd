class_name CorePulseDriver
extends Node2D
## Drives only presentation state for the Base Core.

const COMMAND_PUNCH_SCALE: float = 1.15

## The refuge health bar, in world units, sitting below the camp where the
## previous hand-drawn pair of rectangles sat. Wider and taller than a survivor
## bar because the Base is the objective and is read from further out, and
## because at 0.38 zoom the old seven-unit height was under three screen pixels
## including its own backing.
##
## Wider than a survivor bar, but NOT wider than the refuge, which is what the
## first pass at these numbers got wrong. The camp texture measures 92.0 world
## units across its own alpha bounds at the Core node's 0.42 scale, and a
## 108-unit bar therefore drew at 117 percent of the thing it belongs to,
## floating over 23.9 units of bare ground below it. On screen that is a green
## widget lying on the terrain rather than the refuge's own readout, and it
## fought the Base Core for the focus CLAUDE.md 8 reserves for the refuge alone.
## Sixty-four units is 70 percent of the camp - still comfortably larger than
## the survivors' 37 - and an offset of 30 leaves about four units of ground
## between the camp's lowest pixel and the bar, which resolves to the one or two
## screen pixels that read as attached rather than as dropped nearby.
const HEALTH_BAR_SIZE: Vector2 = Vector2(64.0, 9.0)
const HEALTH_BAR_OFFSET: Vector2 = Vector2(0.0, 30.0)
## Quarters of sixteen hundred. The bar is wide enough here that three dividers
## cost little and buy a reading in four hundred point steps.
const HEALTH_BAR_SEGMENTS: int = 4

## Presentation-only health states for the refuge. These deliberately mirror
## [HealthBar2D]'s authored stops instead of introducing a second set of health
## semantics: a player who sees the bar enter its damaged or critical band must
## see the refuge enter that same visual state.
enum HealthVisualTier {
	HEALTHY,
	DAMAGED,
	CRITICAL,
	DESTROYED,
}

const DAMAGED_RATIO: float = HealthBar2D.HURT_RATIO
const CRITICAL_RATIO: float = HealthBar2D.CRITICAL_RATIO

## The healthy values match the existing BaseCore scene material values. Tier
## changes are deliberately limited to shader uniforms and the existing amber
## light; the camp sprite, its silhouette, transform, collision, and health
## data are never swapped or mutated here.
const HEALTHY_LIGHT_COLOR: Color = Color(1.0, 0.55, 0.14, 1.0)
const HEALTHY_CORE_GLOW_COLOR: Color = Color(0.91, 0.58, 0.20, 1.0)
const HEALTHY_AURA_COLOR: Color = Color(1.0, 0.48, 0.035, 1.0)
const HEALTHY_CORE_EMISSION: float = 0.10
const HEALTHY_AURA_INTENSITY: float = 0.85
const HEALTHY_AURA_EDGE_POWER: float = 2.35
const HEALTHY_GLOW_STRENGTH: float = 0.40
const HEALTHY_GLOW_SCALE_AMOUNT: float = 0.045
const HEALTHY_CORE_PULSE_SPEED: float = 1.75

const DAMAGED_LIGHT_COLOR: Color = Color(0.75, 0.42, 0.12, 1.0)
const DAMAGED_CORE_GLOW_COLOR: Color = Color(0.72, 0.38, 0.12, 1.0)
const DAMAGED_AURA_COLOR: Color = Color(0.72, 0.31, 0.055, 1.0)
const DAMAGED_CORE_EMISSION: float = 0.055
const DAMAGED_AURA_INTENSITY: float = 0.50
const DAMAGED_AURA_EDGE_POWER: float = 2.70
const DAMAGED_GLOW_STRENGTH: float = 0.22
const DAMAGED_GLOW_SCALE_AMOUNT: float = 0.025
const DAMAGED_CORE_PULSE_SPEED: float = 1.25

## Critical is deliberately a hot, high-luminance warning instead of a dark
## pure red. At 0.38 gameplay zoom the player must recognize the emergency in
## grayscale too: the bar/light retain the danger hue while the stronger,
## wider existing aura and rim supply a non-colour urgency cue.
const CRITICAL_LIGHT_COLOR: Color = Color(1.0, 0.36, 0.11, 1.0)
const CRITICAL_CORE_GLOW_COLOR: Color = Color(1.0, 0.68, 0.32, 1.0)
const CRITICAL_AURA_COLOR: Color = Color(1.0, 0.72, 0.24, 1.0)
const CRITICAL_CORE_EMISSION: float = 0.32
const CRITICAL_AURA_INTENSITY: float = 1.35
const CRITICAL_AURA_EDGE_POWER: float = 1.55
const CRITICAL_GLOW_STRENGTH: float = 1.35
## A critical core gets a temporarily wider shader-only silhouette flare. This
## changes neither the Sprite2D transform nor collision; it provides the
## surviving grayscale emergency cue at actual gameplay scale.
const CRITICAL_GLOW_SCALE_AMOUNT: float = 0.10
const CRITICAL_CORE_PULSE_SPEED: float = 3.20

const DESTROYED_LIGHT_COLOR: Color = Color(0.16, 0.17, 0.17, 1.0)
const DESTROYED_CORE_GLOW_COLOR: Color = Color(0.17, 0.10, 0.07, 1.0)
const DESTROYED_AURA_COLOR: Color = Color(0.12, 0.10, 0.09, 1.0)
const DESTROYED_AURA_EDGE_POWER: float = 2.35
const DESTROYED_GLOW_SCALE_AMOUNT: float = 0.045

@export_node_path("PointLight2D") var light_path: NodePath = ^"AmberLight"
@export_node_path("Sprite2D") var aura_path: NodePath = ^"Aura"
@export_node_path("Sprite2D") var glow_path: NodePath = ^"GlowSilhouette"
@export_node_path("Sprite2D") var core_path: NodePath = ^"Core"
@export_range(0.2, 6.0, 0.1) var pulse_speed: float = 1.75
@export_range(0.0, 3.0, 0.05) var base_energy: float = 1.05
@export_range(0.0, 2.0, 0.05) var pulse_energy: float = 0.34

var _phase: float = 0.0
var _light: PointLight2D
var _aura: Sprite2D
var _glow: Sprite2D
var _core: Sprite2D
var _core_base_scale: Vector2 = Vector2.ONE
var _glow_base_scale: Vector2 = Vector2.ONE
var _command_tween: Tween
var _health_ratio: float = 1.0
var _health_bar: HealthBar2D
var _health_visual_tier: int = HealthVisualTier.HEALTHY
## Kept separate from [member base_energy], which remains the scene's authored
## healthy pulse. A tier can therefore mute the light without changing the
## export a designer tunes in the inspector.
var _tier_light_energy_scale: float = 1.0


func _ready() -> void:
	_light = get_node_or_null(light_path) as PointLight2D
	_aura = get_node_or_null(aura_path) as Sprite2D
	_glow = get_node_or_null(glow_path) as Sprite2D
	_core = get_node_or_null(core_path) as Sprite2D
	if _glow != null:
		_glow_base_scale = _glow.scale
	if _core != null:
		_core_base_scale = _core.scale
	_apply_health_visual_tier(_tier_for_ratio(_health_ratio))

	# Built here rather than declared in base_core.tscn because the bar existing at
	# all is this node's contract - set_health_ratio is a method on the driver, and
	# a scene-declared node could be deleted in the editor leaving a setter that
	# silently updated nothing. It replaces the two flat rectangles this class used
	# to draw by hand, so the refuge and the survivors now share one outline
	# weight, one chip cadence and one critical pulse instead of each having been
	# tuned on its own.
	_health_bar = HealthBar2D.new()
	_health_bar.name = &"HealthBar"
	_health_bar.position = HEALTH_BAR_OFFSET
	# The Base never hides at full: it is the thing being defended, so its state
	# is relevant even during the quiet half of the day cycle.
	_health_bar.setup(HEALTH_BAR_SIZE, HEALTH_BAR_SEGMENTS, false)
	_health_bar.reset_to(_health_ratio)
	# An empty objective readout is noise. Only a literal zero is destroyed;
	# recovering to even one point must restore the bar and its critical state.
	_health_bar.set_active(_health_visual_tier != HealthVisualTier.DESTROYED)
	add_child(_health_bar)


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * pulse_speed, TAU)
	_refresh_light_energy()
	if _aura != null and _aura.material is ShaderMaterial:
		(_aura.material as ShaderMaterial).set_shader_parameter(&"pulse_phase", _phase)
	if _glow != null and _glow.material is ShaderMaterial:
		(_glow.material as ShaderMaterial).set_shader_parameter(&"pulse_phase", _phase)
	if _core != null:
		var warmth: float = sin(_phase) * 0.5 + 0.5
		_core.modulate = Color(1.0, 0.88 + warmth * 0.12, 0.72 + warmth * 0.18, 1.0)


func get_pulse_phase() -> float:
	return _phase


func get_core_sprite() -> Sprite2D:
	return _core


func set_health_ratio(value: float) -> void:
	_health_ratio = clampf(value, 0.0, 1.0)
	_apply_health_visual_tier(_tier_for_ratio(_health_ratio))
	if is_instance_valid(_health_bar):
		_health_bar.set_active(_health_visual_tier != HealthVisualTier.DESTROYED)
		_health_bar.set_ratio(_health_ratio)


func get_health_ratio() -> float:
	return _health_ratio


## The presentation tier is public specifically so visual/capture gates can
## assert a health transition without sampling a pulse frame or interpreting a
## colour. It is not gameplay state and is derived solely from [member
## _health_ratio].
func get_health_visual_tier() -> int:
	return _health_visual_tier


func _tier_for_ratio(ratio: float) -> int:
	if ratio <= 0.0:
		return HealthVisualTier.DESTROYED
	if ratio <= CRITICAL_RATIO:
		return HealthVisualTier.CRITICAL
	if ratio <= DAMAGED_RATIO:
		return HealthVisualTier.DAMAGED
	return HealthVisualTier.HEALTHY


## Applies strictly visual state to the nodes already present in base_core.tscn.
## No node is added, removed, hidden, repositioned, re-scaled, re-textured, or
## re-parented here. The one non-material visual control is the existing
## AmberLight itself. HealthBar activation is handled by the caller and is the
## explicit zero-health exception documented above.
func _apply_health_visual_tier(tier: int) -> void:
	_health_visual_tier = tier

	var light_color: Color = HEALTHY_LIGHT_COLOR
	var core_glow_color: Color = HEALTHY_CORE_GLOW_COLOR
	var aura_color: Color = HEALTHY_AURA_COLOR
	var core_emission: float = HEALTHY_CORE_EMISSION
	var aura_intensity: float = HEALTHY_AURA_INTENSITY
	var aura_edge_power: float = HEALTHY_AURA_EDGE_POWER
	var glow_strength: float = HEALTHY_GLOW_STRENGTH
	var glow_scale_amount: float = HEALTHY_GLOW_SCALE_AMOUNT
	var core_pulse_speed: float = HEALTHY_CORE_PULSE_SPEED
	_tier_light_energy_scale = 1.0

	match tier:
		HealthVisualTier.DAMAGED:
			light_color = DAMAGED_LIGHT_COLOR
			core_glow_color = DAMAGED_CORE_GLOW_COLOR
			aura_color = DAMAGED_AURA_COLOR
			core_emission = DAMAGED_CORE_EMISSION
			aura_intensity = DAMAGED_AURA_INTENSITY
			aura_edge_power = DAMAGED_AURA_EDGE_POWER
			glow_strength = DAMAGED_GLOW_STRENGTH
			glow_scale_amount = DAMAGED_GLOW_SCALE_AMOUNT
			core_pulse_speed = DAMAGED_CORE_PULSE_SPEED
			_tier_light_energy_scale = 0.65
		HealthVisualTier.CRITICAL:
			light_color = CRITICAL_LIGHT_COLOR
			core_glow_color = CRITICAL_CORE_GLOW_COLOR
			aura_color = CRITICAL_AURA_COLOR
			core_emission = CRITICAL_CORE_EMISSION
			aura_intensity = CRITICAL_AURA_INTENSITY
			aura_edge_power = CRITICAL_AURA_EDGE_POWER
			glow_strength = CRITICAL_GLOW_STRENGTH
			glow_scale_amount = CRITICAL_GLOW_SCALE_AMOUNT
			core_pulse_speed = CRITICAL_CORE_PULSE_SPEED
			_tier_light_energy_scale = 1.15
		HealthVisualTier.DESTROYED:
			light_color = DESTROYED_LIGHT_COLOR
			core_glow_color = DESTROYED_CORE_GLOW_COLOR
			aura_color = DESTROYED_AURA_COLOR
			core_emission = 0.0
			aura_intensity = 0.0
			aura_edge_power = DESTROYED_AURA_EDGE_POWER
			glow_strength = 0.0
			glow_scale_amount = DESTROYED_GLOW_SCALE_AMOUNT
			core_pulse_speed = 0.0
			_tier_light_energy_scale = 0.0

	if _light != null:
		_light.color = light_color
	_set_shader_parameter(_core, &"glow_color", core_glow_color)
	_set_shader_parameter(_core, &"emission_strength", core_emission)
	_set_shader_parameter(_core, &"pulse_speed", core_pulse_speed)
	_set_shader_parameter(_aura, &"aura_color", aura_color)
	_set_shader_parameter(_aura, &"intensity", aura_intensity)
	_set_shader_parameter(_aura, &"edge_power", aura_edge_power)
	_set_shader_parameter(_glow, &"glow_color", core_glow_color)
	_set_shader_parameter(_glow, &"glow_strength", glow_strength)
	_set_shader_parameter(_glow, &"scale_amount", glow_scale_amount)
	_refresh_light_energy()


func _set_shader_parameter(sprite: Sprite2D, parameter: StringName, value: Variant) -> void:
	if sprite != null and sprite.material is ShaderMaterial:
		(sprite.material as ShaderMaterial).set_shader_parameter(parameter, value)


func _refresh_light_energy() -> void:
	if _light != null:
		_light.energy = (
			base_energy + (sin(_phase) * 0.5 + 0.5) * pulse_energy
		) * _tier_light_energy_scale


func play_command_feedback() -> void:
	if _command_tween != null and _command_tween.is_valid():
		_command_tween.kill()
	if _core == null or _glow == null:
		return
	_core.scale = _core_base_scale
	_glow.scale = _glow_base_scale
	_command_tween = create_tween()
	_command_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_command_tween.tween_property(
		_core,
		"scale",
		_core_base_scale * COMMAND_PUNCH_SCALE,
		0.08
	)
	_command_tween.parallel().tween_property(
		_glow,
		"scale",
		_glow_base_scale * COMMAND_PUNCH_SCALE,
		0.08
	)
	_command_tween.tween_property(_core, "scale", _core_base_scale, 0.14)
	_command_tween.parallel().tween_property(_glow, "scale", _glow_base_scale, 0.14)


## Whether a command punch is animating right now.
##
## The punch is a 0.22-second [Tween], so its scale at any given instant is a
## function of frame pacing. Anything that needs to know a command was felt has
## to ask this rather than sample [member Sprite2D.scale] and hope it looked on
## the right frame - which is what the headless gate used to do, and why it
## intermittently failed a feature that was working.
func is_command_punch_active() -> bool:
	return _command_tween != null and _command_tween.is_valid() and _command_tween.is_running()


func get_health_bar() -> HealthBar2D:
	return _health_bar
