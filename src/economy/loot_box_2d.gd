class_name LootBox2D
extends Node2D
## Lightweight deterministic loot-box presentation consumed by the host.

var loot_id: int = 0
var resource_grant: PackedInt32Array = PackedInt32Array([0, 0, 0])
var opened: bool = false


func configure(
	new_loot_id: int,
	world_position: Vector2,
	grant: PackedInt32Array
) -> void:
	loot_id = new_loot_id
	global_position = world_position
	resource_grant = grant.duplicate()
	name = "LootBox_%02d" % loot_id
	z_index = 5
	z_as_relative = false
	queue_redraw()


func set_opened(value: bool) -> void:
	opened = value
	visible = not opened
	queue_redraw()


func _draw() -> void:
	if opened:
		return
	draw_rect(Rect2(Vector2(-24.0, -18.0), Vector2(48.0, 36.0)), Color("151b22"), true)
	draw_rect(Rect2(Vector2(-22.0, -16.0), Vector2(44.0, 32.0)), Color("6d4d29"), true)
	draw_rect(Rect2(Vector2(-22.0, -3.0), Vector2(44.0, 6.0)), Color("e6b23c"), true)
	draw_rect(Rect2(Vector2(-5.0, -8.0), Vector2(10.0, 16.0)), Color("d7e4e8"), true)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-18.0, -25.0),
		"[USE]",
		HORIZONTAL_ALIGNMENT_LEFT,
		36.0,
		8,
		Color("fff0a8")
	)
