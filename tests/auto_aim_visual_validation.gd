extends SceneTree
## Short non-headless GameWorld demo for visually inspecting the default-off auto-aim overlay.

const GAME_WORLD_SCENE: PackedScene = preload("res://scenes/game/game_world.tscn")
const AutoAimController = preload("res://src/combat/auto_aim_controller_2d.gd")
const VISUAL_TEST_ORIGIN: Vector2 = Vector2(9730.0, 2685.0)

var _next_enemy_id: int = 1001


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var world: GameWorld = GAME_WORLD_SCENE.instantiate() as GameWorld
	if world == null:
		push_error("AUTO AIM VISUAL FAILED | GameWorld could not instantiate")
		quit(1)
		return
	world.auto_aim_debug_visualization = true
	world.configure_launch(CoopSession.SessionMode.SOLO, &"heikki", "127.0.0.1")
	root.add_child(world)
	for _frame_index: int in range(4):
		await physics_frame
	world.session.teleport_peer_authoritative(CoopSession.AUTHORITY_PEER_ID, VISUAL_TEST_ORIGIN)
	for _frame_index: int in range(3):
		await physics_frame
	var controller: AutoAimController = world.get_auto_aim_controller(
		CoopSession.AUTHORITY_PEER_ID
	)
	if controller == null:
		push_error("AUTO AIM VISUAL FAILED | controller missing")
		world.queue_free()
		quit(1)
		return
	controller.maximum_targeting_angle_degrees = 180.0
	controller.require_line_of_sight = false
	controller.debug_show_scores = true
	for index: int in range(10):
		var angle: float = TAU * float(index) / 10.0
		_spawn_enemy(
			world,
			VISUAL_TEST_ORIGIN + Vector2.from_angle(angle) * (250.0 + float(index % 3) * 75.0)
		)
	for _frame_index: int in range(18):
		await physics_frame
	controller.force_refresh()
	print(
		"AUTO AIM VISUAL READY | candidates=%d target=%d"
		% [controller.get_candidate_count(), controller.get_current_target_id()]
	)
	await create_timer(45.0).timeout
	world.queue_free()
	await process_frame
	quit(0)


func _spawn_enemy(world: GameWorld, world_position: Vector2) -> void:
	world.horde_director._commit_enemy_spawn(
		_next_enemy_id,
		EnemyAgent2D.Variant.WALKER,
		world_position,
		90,
		12,
		1.0
	)
	_next_enemy_id += 1
