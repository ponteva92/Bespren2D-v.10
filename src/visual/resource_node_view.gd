class_name ResourceNodeView
extends Node2D
## Shader-driven presentation shell; harvesting and depletion are intentionally absent.

enum ResourceKind {
	WOOD,
	METAL,
	TECH,
}

## The design document's locked resource anchors, in enum order. Each packed
## scene carries its own `glow_color`, which meant nothing in code could ask
## what colour a kind is without instancing a scene - so anything tinting by
## resource, such as a salvage burst, had no source for the answer. These are
## the same three values the scenes set, kept here as the single definition.
const SIGNAL_COLORS: Array[Color] = [
	Color("ffd700"),
	Color("e0e0e0"),
	Color("00ffff"),
]

@export var kind: ResourceKind = ResourceKind.WOOD
@export var glow_color: Color = Color("ffd700")

@onready var icon: Sprite2D = %Icon
@onready var glow: PointLight2D = %Glow
@onready var visibility_notifier: VisibleOnScreenNotifier2D = %VisibilityNotifier

var _completed_interactions: int = 0
var _required_interactions: int = 1
var _base_icon_scale: Vector2 = Vector2.ONE
var _base_glow_energy: float = 0.0
var _hit_tween: Tween


func _ready() -> void:
	# The packed resource scenes each own one immutable ShaderMaterial variant.
	# Keeping that scene resource shared avoids 87 per-instance material copies.
	glow.color = glow_color
	_base_icon_scale = icon.scale
	_base_glow_energy = glow.energy
	visibility_notifier.screen_entered.connect(_on_screen_entered)
	visibility_notifier.screen_exited.connect(_on_screen_exited)
	glow.enabled = visibility_notifier.is_on_screen()
	_apply_progress_visual(false)


func apply_harvest_progress(
	completed_interactions: int,
	required_interactions: int,
	animate_hit: bool = true
) -> void:
	_required_interactions = maxi(required_interactions, 1)
	_completed_interactions = clampi(
		completed_interactions,
		0,
		_required_interactions
	)
	if not is_node_ready():
		return
	_apply_progress_visual(animate_hit)


func get_completed_interactions() -> int:
	return _completed_interactions


func get_required_interactions() -> int:
	return _required_interactions


func _apply_progress_visual(animate_hit: bool) -> void:
	if not is_instance_valid(icon) or not is_instance_valid(glow):
		return
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	var progress_ratio: float = clampf(
		float(_completed_interactions) / float(maxi(_required_interactions, 1)),
		0.0,
		1.0
	)
	var target_scale: Vector2 = _base_icon_scale * lerpf(1.0, 0.84, progress_ratio)
	icon.modulate = Color(1.0, 1.0, 1.0, lerpf(1.0, 0.64, progress_ratio))
	glow.energy = _base_glow_energy * lerpf(1.0, 0.46, progress_ratio)
	if animate_hit and _completed_interactions > 0:
		icon.scale = target_scale * 1.12
		_hit_tween = create_tween()
		_hit_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_hit_tween.tween_property(icon, "scale", target_scale, 0.14)
	else:
		icon.scale = target_scale
	queue_redraw()


func _draw() -> void:
	if _completed_interactions <= 0 or _completed_interactions >= _required_interactions:
		return
	var center: Vector2 = Vector2(0.0, -34.0)
	var radius: float = 8.0
	draw_arc(center, radius, -PI * 0.5, PI * 1.5, 20, Color(0.01, 0.02, 0.02, 0.88), 3.0, true)
	var progress_end: float = -PI * 0.5 + TAU * (
		float(_completed_interactions) / float(_required_interactions)
	)
	draw_arc(center, radius, -PI * 0.5, progress_end, 20, glow_color, 2.0, true)


func _on_screen_entered() -> void:
	glow.enabled = true


func _on_screen_exited() -> void:
	glow.enabled = false


## Out-of-range kinds return white rather than asserting: the value arrives
## from a replicated gather commit, and a burst in the wrong colour is a far
## better failure than a crash on a peer receiving a malformed packet.
static func signal_color(resource_kind: int) -> Color:
	if resource_kind < 0 or resource_kind >= SIGNAL_COLORS.size():
		return Color.WHITE
	return SIGNAL_COLORS[resource_kind]
