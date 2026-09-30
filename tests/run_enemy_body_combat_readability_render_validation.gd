extends SceneTree
## GPU runner for the live boss-body readability fixture.

const TEST_SCENE: PackedScene = preload("res://tests/enemy_body_combat_readability_render_validation.tscn")


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var fixture: Node = TEST_SCENE.instantiate()
	if fixture == null:
		push_error("ENEMY BODY COMBAT READABILITY RENDER FAILED: fixture did not instantiate")
		quit(1)
		return
	root.add_child(fixture)
