class_name EnemyAggroMatrix
extends RefCounted
## Deterministic host-side Base/player target selection for every alive enemy.

const BASE_TARGET_PEER_ID: int = 0

var _target_peer_by_enemy: Dictionary[int, int] = {}


func evaluate(
	enemy_id: int,
	enemy_position: Vector2,
	players: Array[PlayerAvatar],
	proximity_radius: float
) -> int:
	var selected_peer_id: int = BASE_TARGET_PEER_ID
	var best_distance_squared: float = proximity_radius * proximity_radius
	for player: PlayerAvatar in players:
		if not is_instance_valid(player) or not player.is_combat_alive():
			continue
		var distance_squared: float = enemy_position.distance_squared_to(player.global_position)
		if (
			distance_squared < best_distance_squared
			or (
				is_equal_approx(distance_squared, best_distance_squared)
				and (selected_peer_id == BASE_TARGET_PEER_ID or player.peer_id < selected_peer_id)
			)
		):
			best_distance_squared = distance_squared
			selected_peer_id = player.peer_id
	_target_peer_by_enemy[enemy_id] = selected_peer_id
	return selected_peer_id


func remove_enemy(enemy_id: int) -> void:
	_target_peer_by_enemy.erase(enemy_id)


func clear() -> void:
	_target_peer_by_enemy.clear()


func get_target_peer_id(enemy_id: int) -> int:
	return _target_peer_by_enemy.get(enemy_id, BASE_TARGET_PEER_ID)


func get_target_count() -> int:
	return _target_peer_by_enemy.size()
