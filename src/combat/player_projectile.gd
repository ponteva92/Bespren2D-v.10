class_name PlayerProjectile
extends Area2D
## Host-approved projectile visual with continuous world collision and bounded lifetime.

signal impacted(collider: Node)
signal expired
signal released(projectile: PlayerProjectile)

@export_range(1.0, 2000.0, 1.0) var speed: float = 820.0
@export_range(0.05, 5.0, 0.05) var lifetime_seconds: float = 1.6
@export_range(1, 1000, 1) var damage: int = 10

var source_peer_id: int = 0
var _direction: Vector2 = Vector2.RIGHT
var _remaining_lifetime: float = 0.0
var _active: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	deactivate_for_pool()


func initialize(spawn_position: Vector2, firing_direction: Vector2, peer_id: int) -> void:
	global_position = spawn_position
	_direction = firing_direction.normalized() if not firing_direction.is_zero_approx() else Vector2.RIGHT
	rotation = _direction.angle()
	source_peer_id = maxi(peer_id, 0)
	_remaining_lifetime = lifetime_seconds
	_active = true
	visible = true
	set_physics_process(true)
	set_deferred(&"monitoring", true)
	set_deferred(&"monitorable", true)


func deactivate_for_pool() -> void:
	_active = false
	_direction = Vector2.RIGHT
	source_peer_id = 0
	_remaining_lifetime = 0.0
	visible = false
	set_physics_process(false)
	set_deferred(&"monitoring", false)
	set_deferred(&"monitorable", false)


func is_active() -> bool:
	return _active


func get_direction() -> Vector2:
	return _direction


func get_remaining_lifetime() -> float:
	return _remaining_lifetime


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_remaining_lifetime -= maxf(delta, 0.0)
	if _remaining_lifetime <= 0.0:
		_expire()
		return
	var next_position: Vector2 = global_position + _direction * speed * delta
	var excluded_rids: Array[RID] = [get_rid()]
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		global_position,
		next_position,
		collision_mask,
		excluded_rids
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = next_position
		return
	var hit_position: Variant = hit.get(&"position", next_position)
	if hit_position is Vector2:
		global_position = hit_position
	var collider_value: Variant = hit.get(&"collider")
	if collider_value is Node:
		_impact(collider_value as Node)
	else:
		_expire()


func _on_body_entered(body: Node2D) -> void:
	_impact(body)


func _on_area_entered(area: Area2D) -> void:
	if area == self:
		return
	_impact(area)


func _impact(collider: Node) -> void:
	if not _active:
		return
	_active = false
	if collider.has_method(&"take_projectile_damage"):
		collider.call(&"take_projectile_damage", damage, _direction, source_peer_id)
	# Player rounds stop against WorldStatic, but only an explicitly opted-in
	# projectile target may mutate gameplay health. This keeps replicated
	# presentation rounds from damaging friendly structures on either peer.
	impacted.emit(collider)
	_release_or_free()


func _expire() -> void:
	if not _active:
		return
	_active = false
	expired.emit()
	_release_or_free()


func _release_or_free() -> void:
	if released.get_connections().is_empty():
		queue_free()
		return
	released.emit(self)
