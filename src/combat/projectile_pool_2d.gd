class_name ProjectilePool2D
extends Node2D
## Fixed-capacity projectile pool that eliminates combat-time scene churn.

## Re-emitted from every pooled projectile so one listener covers all of
## them. Connecting per checkout would stack a fresh connection on each
## flight of the same reused node; connecting at creation happens once.
## [param spray] already points back out of the surface that was struck.
signal projectile_impacted(world_position: Vector2, spray: Vector2)

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/combat/player_projectile.tscn")
const DEFAULT_INITIAL_SIZE: int = 40
const DEFAULT_MAX_SIZE: int = 80

@export_range(1, 80, 1) var initial_size: int = DEFAULT_INITIAL_SIZE
@export_range(1, 120, 1) var maximum_size: int = DEFAULT_MAX_SIZE

var _available: Array[PlayerProjectile] = []
var _active: Array[PlayerProjectile] = []


func _ready() -> void:
	maximum_size = maxi(maximum_size, initial_size)
	for _pool_index: int in range(initial_size):
		_create_projectile()


func checkout(
	spawn_position: Vector2,
	firing_direction: Vector2,
	peer_id: int
) -> PlayerProjectile:
	var projectile: PlayerProjectile
	if _available.is_empty():
		if get_capacity() >= maximum_size:
			return null
		projectile = _create_projectile()
	else:
		projectile = _available.pop_back()
	if projectile == null:
		return null
	_active.append(projectile)
	projectile.initialize(spawn_position, firing_direction, peer_id)
	return projectile


func release_all() -> void:
	var active_copy: Array[PlayerProjectile] = _active.duplicate()
	for projectile: PlayerProjectile in active_copy:
		_return_projectile(projectile)


func get_active_count() -> int:
	return _active.size()


func get_available_count() -> int:
	return _available.size()


func get_capacity() -> int:
	return _available.size() + _active.size()


func get_active_projectiles() -> Array[PlayerProjectile]:
	return _active.duplicate()


func _create_projectile() -> PlayerProjectile:
	var projectile: PlayerProjectile = PROJECTILE_SCENE.instantiate() as PlayerProjectile
	if projectile == null:
		return null
	projectile.name = "PooledProjectile_%03d" % get_capacity()
	add_child(projectile)
	projectile.released.connect(_return_projectile)
	projectile.impacted.connect(_on_projectile_impacted.bind(projectile))
	projectile.deactivate_for_pool()
	_available.append(projectile)
	return projectile


## The projectile has already moved itself to the ray hit position by the
## time it emits, so its transform is the contact point rather than the
## step it was travelling toward.
func _on_projectile_impacted(
	_collider: Node,
	projectile: PlayerProjectile
) -> void:
	if not is_instance_valid(projectile):
		return
	projectile_impacted.emit(
		projectile.global_position, -projectile.get_direction())


func _return_projectile(projectile: PlayerProjectile) -> void:
	if projectile == null or not _active.has(projectile):
		return
	_active.erase(projectile)
	projectile.deactivate_for_pool()
	_available.append(projectile)
