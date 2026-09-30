extends SceneTree
## Entry point for the Node2D wilderness microprop review fixture.

const TEST_SCENE: PackedScene = preload("res://tests/wilderness_microprop_diversity_validation.tscn")


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var fixture: Node = TEST_SCENE.instantiate()
	if fixture == null:
		push_error("WILDERNESS MICROPROP DIVERSITY FAILED: fixture did not instantiate")
		quit(1)
		return
	root.add_child(fixture)
