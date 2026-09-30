class_name StartMenuCardSignal
extends Control
## Original, vector-drawn identity field behind one survivor card.
##
## It deliberately owns no input, selection, launch, or layout state. The menu
## tells it which survivor is active; the card continues to own every actual
## focus and touch interaction. Keeping this treatment procedural avoids a
## source-vault promotion merely to add decorative UI chrome.

@export var accent_color: Color = Color(0.54, 0.91, 0.76, 1.0)
@export var phase_offset: float = 0.0

var _is_active: bool = false
var _phase: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func set_active(value: bool) -> void:
	if _is_active == value:
		return
	_is_active = value
	queue_redraw()


func is_active() -> bool:
	return _is_active


func _process(delta: float) -> void:
	# Only the selected card redraws. This is presentation-only and stays below
	# the menu's very small mobile UI cost envelope.
	if not _is_active:
		return
	_phase = fposmod(_phase + delta * 1.15, TAU)
	queue_redraw()


func _draw() -> void:
	if size.x < 32.0 or size.y < 32.0:
		return

	var active_weight: float = 1.0 if _is_active else 0.42
	var pulse: float = 0.5 + 0.5 * sin(_phase + phase_offset)
	var field_color := Color(
		accent_color.r,
		accent_color.g,
		accent_color.b,
		(0.11 + pulse * 0.05) * active_weight
	)
	var fine_color := Color(
		accent_color.r,
		accent_color.g,
		accent_color.b,
		(0.07 + pulse * 0.025) * active_weight
	)
	var portrait_center := Vector2(
		minf(46.0, size.x * 0.22),
		clampf(size.y * 0.57, 49.0, 61.0)
	)
	var radius: float = minf(34.0, minf(size.x * 0.16, size.y * 0.31))
	var right_x: float = maxf(portrait_center.x + radius + 5.0, size.x - 13.0)
	var trace_y: float = portrait_center.y + 10.0

	# The split orbital arc and short route trace frame the actual bespoke
	# portraits without imitating a generic fantasy panel or drowning the text.
	draw_arc(portrait_center, radius, -2.56, -0.56, 18, field_color, 0.7, true)
	draw_arc(portrait_center, radius, 0.58, 2.58, 18, field_color, 0.7, true)
	draw_arc(portrait_center, radius - 5.0, -0.25, 0.25, 8, fine_color, 0.55, true)
	draw_line(
		Vector2(portrait_center.x + radius - 1.0, trace_y),
		Vector2(right_x, trace_y),
		field_color,
		0.7,
		true
	)
	for tick_index: int in range(3):
		var tick_x: float = right_x - float(tick_index) * 8.0
		draw_line(
			Vector2(tick_x, trace_y - 2.5),
			Vector2(tick_x, trace_y + 2.5),
			fine_color,
			0.6,
			true
		)

	var marker_x: float = lerpf(portrait_center.x + radius + 5.0, right_x - 3.0, pulse)
	draw_circle(Vector2(marker_x, trace_y), 1.1, field_color)

	var bracket_color := Color(
		accent_color.r,
		accent_color.g,
		accent_color.b,
		0.16 * active_weight
	)
	var bracket: float = 7.0
	var inset: float = 5.0
	draw_line(Vector2(inset, inset + bracket), Vector2(inset, inset), bracket_color, 0.8, true)
	draw_line(Vector2(inset, inset), Vector2(inset + bracket, inset), bracket_color, 0.8, true)
	draw_line(
		Vector2(size.x - inset - bracket, size.y - inset),
		Vector2(size.x - inset, size.y - inset),
		bracket_color,
		0.8,
		true
	)
	draw_line(
		Vector2(size.x - inset, size.y - inset - bracket),
		Vector2(size.x - inset, size.y - inset),
		bracket_color,
		0.8,
		true
	)
