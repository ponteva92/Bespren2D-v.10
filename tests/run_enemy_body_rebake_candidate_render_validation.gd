extends SceneTree
## Headless-script entry point for the GPU-driven Loop F boss candidate scene.

const TEST_SCENE: PackedScene = preload("res://tests/enemy_body_rebake_candidate_render_validation.tscn")


func _initialize() -> void:
	print("ENEMY BODY REBAKE CANDIDATE RENDER LAUNCHER")
	call_deferred(&"_run")


func _run() -> void:
	var fixture: Node = TEST_SCENE.instantiate()
	if fixture == null:
		push_error("ENEMY BODY REBAKE CANDIDATE RENDER FAILED: fixture did not instantiate")
		quit(1)
		return
	root.add_child(fixture)
