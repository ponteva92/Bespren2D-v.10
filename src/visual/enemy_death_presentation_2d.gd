class_name EnemyDeathPresentation2D
extends Node2D
## Ephemeral, collision-free owner for a baked enemy death clip.
##
## Horde gameplay removes a dead enemy from its registry immediately.  Keeping
## that gameplay shell around just to finish a visual would let it leak into
## targeting, flow, or snapshot paths.  This small view intentionally carries
## none of those contracts: it is not a zombie, has no physics node, and frees
## itself after the longest authored death clip has had time to settle.

const PresentationCatalog = preload("res://src/ai/enemy_presentation_catalog.gd")
const PresentationView = preload("res://src/visual/enemy_presentation_2d.gd")
const DEATH_PRESENTATION_SECONDS: float = 1.05

var _remaining_seconds: float = DEATH_PRESENTATION_SECONDS
var _presentation: EnemyPresentation2D


func configure(variant_id: int, enemy_id: int, facing_row: int, presentation_seed: int) -> bool:
	if variant_id < EnemyAgent2D.Variant.WALKER or variant_id > EnemyAgent2D.Variant.OVERLORD:
		return false
	var definition: EnemyPresentationDefinition = PresentationCatalog.get_definition(variant_id)
	if definition == null:
		return false
	name = "EnemyDeath_%04d" % maxi(enemy_id, 0)
	add_to_group(&"enemy_death_presentations")
	z_index = 5
	z_as_relative = false
	_remaining_seconds = DEATH_PRESENTATION_SECONDS
	_presentation = PresentationView.new()
	add_child(_presentation)
	_presentation.configure(definition, maxi(enemy_id, 0) ^ presentation_seed)
	_presentation.set_readability_marker_visible(false)
	if not _presentation.play_local_event(EnemyPresentation2D.PresentationEvent.DEATH, facing_row):
		_presentation.queue_free()
		_presentation = null
		return false
	set_process(true)
	return true


func is_visual_only() -> bool:
	return (
		not is_in_group(&"zombies")
		and find_children("*", "CollisionObject2D", true, false).is_empty()
		and is_instance_valid(_presentation)
	)


func get_presentation() -> EnemyPresentation2D:
	return _presentation if is_instance_valid(_presentation) else null


func _process(delta: float) -> void:
	_remaining_seconds = maxf(_remaining_seconds - maxf(delta, 0.0), 0.0)
	if _remaining_seconds <= 0.0:
		queue_free()
