class_name WeatherOverlay
extends ColorRect
## Full-screen atmospheric pass designed for a single Mobile canvas draw.
##
## It also carries the damage response, because the mobile budget in CLAUDE.md 10
## allows one full-screen custom pass and says to combine atmosphere into this
## shader rather than stack a second. A survivor being hit therefore raises a
## uniform here instead of instantiating an overlay of his own, which also means
## weather and damage composite once instead of blending over each other.

## Peak strength of the hit wash. Short of 1.0 deliberately: the frame edge
## going fully opaque red would hide the horde closing in from off-centre, which
## is the information a hit is supposed to make the player go looking for.
const DAMAGE_PEAK: float = 0.82
## Fractions per second. About half a second from a full hit back to clear -
## long enough to register, short enough that a second hit lands on a clean
## frame rather than compounding into a permanent red screen.
const DAMAGE_DECAY_PER_SECOND: float = 1.9

enum WeatherPreset {
	DRY_ASH,
	ACID_DRIZZLE,
	DUST_FRONT,
}

@export var preset: WeatherPreset = WeatherPreset.ACID_DRIZZLE
@export_range(0.0, 1.0, 0.01) var intensity: float = 0.62
## The off switch CLAUDE.md 11 requires before this can be locked into content
## production. A full-screen red pulse is the kind of effect a photosensitive
## player has to be able to remove outright, so zero here means absent rather
## than merely dimmer - the uniform is never written above zero at all.
@export_range(0.0, 1.0, 0.01) var damage_intensity_scale: float = 1.0

var _shader_material: ShaderMaterial
var _damage: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_preset()
	# Nothing to animate until something is hit, and the wash switches the
	# callback back off the moment it clears.
	set_process(false)


## Raise the hit wash. [param amount] is the fraction of maximum health the blow
## took, so a graze reads as a graze; the strongest pending flash wins rather
## than the sum, because two hits in one frame are still one thing happening.
func flash(amount: float) -> void:
	if not is_finite(amount) or amount <= 0.0:
		return
	var scale: float = clampf(damage_intensity_scale, 0.0, 1.0)
	if is_zero_approx(scale):
		return
	_damage = maxf(_damage, clampf(amount, 0.0, 1.0) * DAMAGE_PEAK * scale)
	_write_damage()
	set_process(true)


func get_damage_wash() -> float:
	return _damage


## Clear immediately, for a respawn or a session teardown, where leaving a red
## frame behind would attach the last hit to a survivor who is already back up.
func clear_damage() -> void:
	_damage = 0.0
	_write_damage()
	set_process(false)


func _process(delta: float) -> void:
	_damage = maxf(_damage - DAMAGE_DECAY_PER_SECOND * maxf(delta, 0.0), 0.0)
	_write_damage()
	if is_zero_approx(_damage):
		set_process(false)


func _write_damage() -> void:
	if _shader_material != null:
		_shader_material.set_shader_parameter(&"damage", _damage)


func _apply_preset() -> void:
	if not material is ShaderMaterial:
		return
	var unique_material := material.duplicate() as ShaderMaterial
	var tint := Color("103134")
	var wind := 0.46
	match preset:
		WeatherPreset.DRY_ASH:
			tint = Color("6a5847")
			wind = 0.28
		WeatherPreset.ACID_DRIZZLE:
			tint = Color("103134")
			wind = 0.46
		WeatherPreset.DUST_FRONT:
			tint = Color("704526")
			wind = 0.88
	unique_material.set_shader_parameter(&"storm_tint", tint)
	unique_material.set_shader_parameter(&"intensity", intensity)
	unique_material.set_shader_parameter(&"wind", wind)
	unique_material.set_shader_parameter(&"damage", _damage)
	material = unique_material
	# Kept, because the damage uniform is written every frame while a wash is
	# decaying and re-resolving the material through the property each time
	# would be a cast per frame for a reference that never changes.
	_shader_material = unique_material

