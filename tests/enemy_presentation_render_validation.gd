extends Node2D
## GPU 480x270 contact-sheet gate for all eight zombie presentation profiles.
##
## Three deliberate states are saved: locomotion (the ordinary gameplay read),
## a representative authority-approved one-shot per actor, and death.  This is
## not a gameplay simulation; the horde lifecycle validator remains the source
## of truth for authority and despawn timing.

const OUTPUT_PATH: String = "res://artifacts/enemy_presentation_library.png"
const ACTION_OUTPUT_PATH: String = "res://artifacts/enemy_presentation_actions_validation.png"
const DEATH_OUTPUT_PATH: String = "res://artifacts/enemy_presentation_deaths_validation.png"
const METADATA_PATH: String = "res://artifacts/enemy_presentation_render_validation.json"

const POSITIONS: Array[Vector2] = [
	Vector2(60.0, 79.0),
	Vector2(180.0, 79.0),
	Vector2(300.0, 79.0),
	Vector2(420.0, 79.0),
	Vector2(60.0, 194.0),
	Vector2(180.0, 194.0),
	Vector2(300.0, 194.0),
	Vector2(420.0, 194.0),
]


func _ready() -> void:
	var definitions: Array[EnemyPresentationDefinition] = EnemyPresentationCatalog.get_all()
	var enemies: Array[EnemyAgent2D] = []
	var labels: Array[Label] = []
	if definitions.size() != POSITIONS.size():
		push_error("ENEMY PRESENTATION RENDER FAILED: catalog size mismatch")
		get_tree().quit(1)
		return
	for variant_id: int in range(definitions.size()):
		var definition: EnemyPresentationDefinition = definitions[variant_id]
		var enemy: EnemyAgent2D = EnemyAgent2D.new()
		enemy.configure(
			variant_id + 1,
			variant_id,
			POSITIONS[variant_id],
			100,
			10,
			90.0,
			POSITIONS[variant_id],
			null,
			null,
			false
		)
		add_child(enemy)
		var presentation: EnemyPresentation2D = enemy.get_presentation_view()
		presentation.play_local_event(EnemyPresentation2D.PresentationEvent.NONE)
		presentation.update_motion(1.0 / 60.0, true, 1.0)
		enemies.append(enemy)
		labels.append(_add_label(
			_get_display_label(definition),
			POSITIONS[variant_id] + Vector2(-55.0, 38.0),
			definition.accent_color
		))
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not _save_capture(OUTPUT_PATH):
		get_tree().quit(1)
		return
	for variant_id: int in range(definitions.size()):
		var action_event: int = _get_review_action_event(variant_id)
		var action_name: String = _get_event_name(action_event)
		var action_presentation: EnemyPresentation2D = enemies[variant_id].get_presentation_view()
		action_presentation.play_local_event(action_event, (variant_id + 2) % ActorFacing.ROW_COUNT)
		labels[variant_id].text = "%s\n%s" % [_get_display_label(definitions[variant_id]), action_name]
	await get_tree().create_timer(0.16).timeout
	await RenderingServer.frame_post_draw
	if not _save_capture(ACTION_OUTPUT_PATH):
		get_tree().quit(1)
		return
	for variant_id: int in range(enemies.size()):
		var death_presentation: EnemyPresentation2D = enemies[variant_id].get_presentation_view()
		death_presentation.play_local_event(EnemyPresentation2D.PresentationEvent.DEATH, (variant_id + 5) % ActorFacing.ROW_COUNT)
		labels[variant_id].text = "%s\nDEATH" % _get_display_label(definitions[variant_id])
	await get_tree().create_timer(0.16).timeout
	await RenderingServer.frame_post_draw
	if not _save_capture(DEATH_OUTPUT_PATH):
		get_tree().quit(1)
		return
	var metadata: Dictionary = {
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"logical_size": [480, 270],
		"variant_count": definitions.size(),
		"presentation_ids": _get_presentation_ids(definitions),
		"output": OUTPUT_PATH,
		"outputs": {
			"locomotion": OUTPUT_PATH,
			"authority_actions": ACTION_OUTPUT_PATH,
			"death": DEATH_OUTPUT_PATH,
		},
		"action_events": _get_action_event_names(),
	}
	var metadata_file: FileAccess = FileAccess.open(METADATA_PATH, FileAccess.WRITE)
	if metadata_file == null:
		push_error("ENEMY PRESENTATION RENDER FAILED: could not write metadata")
		get_tree().quit(1)
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()
	print("ENEMY PRESENTATION RENDER OK | method=%s | driver=%s | variants=8 | captures=3" % [
		RenderingServer.get_current_rendering_method(),
		RenderingServer.get_current_rendering_driver_name(),
	])
	get_tree().quit(0)


func _get_presentation_ids(
	definitions: Array[EnemyPresentationDefinition]
) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for definition: EnemyPresentationDefinition in definitions:
		result.append(String(definition.presentation_id))
	return result


func _get_display_label(definition: EnemyPresentationDefinition) -> String:
	if definition.presentation_id == &"infected_crawler_pack":
		return "CRAWLER PACK"
	return String(definition.presentation_id).replace("_", " ").to_upper()


func _get_review_action_event(variant_id: int) -> int:
	match variant_id:
		EnemyAgent2D.Variant.WALKER:
			return EnemyPresentation2D.PresentationEvent.ATTACK
		EnemyAgent2D.Variant.RAT_SWARM:
			return EnemyPresentation2D.PresentationEvent.HIT
		EnemyAgent2D.Variant.STATIC_WALKER:
			return EnemyPresentation2D.PresentationEvent.ATTACK
		EnemyAgent2D.Variant.SCRAP_SHIELD:
			return EnemyPresentation2D.PresentationEvent.HIT
		EnemyAgent2D.Variant.GOLIATH:
			return EnemyPresentation2D.PresentationEvent.TAUNT
		EnemyAgent2D.Variant.CARRIER:
			return EnemyPresentation2D.PresentationEvent.ATTACK
		EnemyAgent2D.Variant.SPLITTER:
			return EnemyPresentation2D.PresentationEvent.TAUNT
		EnemyAgent2D.Variant.OVERLORD:
			return EnemyPresentation2D.PresentationEvent.TAUNT
	return EnemyPresentation2D.PresentationEvent.ATTACK


func _get_event_name(event_id: int) -> String:
	match event_id:
		EnemyPresentation2D.PresentationEvent.ATTACK:
			return "ATTACK"
		EnemyPresentation2D.PresentationEvent.HIT:
			return "HIT"
		EnemyPresentation2D.PresentationEvent.TAUNT:
			return "TAUNT"
		EnemyPresentation2D.PresentationEvent.DEATH:
			return "DEATH"
		EnemyPresentation2D.PresentationEvent.SPAWN:
			return "SPAWN"
	return "NONE"


func _get_action_event_names() -> PackedStringArray:
	var event_names: PackedStringArray = PackedStringArray()
	for variant_id: int in range(POSITIONS.size()):
		event_names.append(_get_event_name(_get_review_action_event(variant_id)))
	return event_names


func _save_capture(output_path: String) -> bool:
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("ENEMY PRESENTATION RENDER FAILED: empty viewport")
		return false
	if image.get_size() != Vector2i(480, 270):
		image.resize(480, 270, Image.INTERPOLATE_LANCZOS)
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		push_error("ENEMY PRESENTATION RENDER FAILED: %s" % error_string(save_error))
		return false
	return true


func _add_label(label_text: String, label_position: Vector2, accent_color: Color) -> Label:
	var label: Label = Label.new()
	label.position = label_position
	label.size = Vector2(110.0, 24.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = label_text
	label.add_theme_font_size_override(&"font_size", 7)
	label.add_theme_color_override(&"font_color", accent_color.lightened(0.12))
	label.add_theme_color_override(&"font_shadow_color", Color(0.01, 0.015, 0.02, 0.95))
	label.add_theme_constant_override(&"shadow_offset_x", 1)
	label.add_theme_constant_override(&"shadow_offset_y", 1)
	add_child(label)
	return label
