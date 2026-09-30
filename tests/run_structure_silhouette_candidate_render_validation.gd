extends SceneTree
## Headless entry point for the Node2D candidate-render fixture.
## Godot's --script mode owns a SceneTree, so the visual test scene must be
## instantiated beneath that tree rather than passed as an editor --scene.

const TEST_SCENE: PackedScene = preload("res://tests/structure_silhouette_candidate_render_validation.tscn")


func _initialize() -> void:
	print("STRUCTURE SILHOUETTE CANDIDATE RENDER LAUNCHER")
	call_deferred(&"_run")


func _run() -> void:
	var fixture: Node = TEST_SCENE.instantiate()
	if fixture == null:
		push_error("STRUCTURE SILHOUETTE CANDIDATE RENDER FAILED: fixture did not instantiate")
		quit(1)
		return
	root.add_child(fixture)
	print("STRUCTURE SILHOUETTE CANDIDATE RENDER FIXTURE ATTACHED")
