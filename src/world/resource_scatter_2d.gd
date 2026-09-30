class_name BesprenResourceScatter2D
extends Node2D
## Deterministic visuals on every peer; only peer one mutates availability and inventory.

signal resource_gathered(
	peer_id: int,
	resource_kind: int,
	amount: int,
	resource_id: int,
	world_position: Vector2
)
signal resource_progressed(
	peer_id: int,
	resource_kind: int,
	completed_interactions: int,
	required_interactions: int,
	granted_amount: int,
	resource_id: int,
	world_position: Vector2
)
signal gather_rejected(peer_id: int, world_position: Vector2)
signal resource_snapshot_applied(state_revision: int)
signal resource_snapshot_rejected(reason: StringName)

const RESOURCE_SCENES: Array[PackedScene] = [
	preload("res://scenes/resources/resource_node_wood.tscn"),
	preload("res://scenes/resources/resource_node_metal.tscn"),
	preload("res://scenes/resources/resource_node_tech.tscn"),
]
const DEFAULT_SCATTER_SEED: int = 0x5CA77E2
## Increment when resource ID ordering, kind assignment, or placement semantics change.
const LAYOUT_VERSION: int = 2
const RESOURCE_COUNT: int = 87
const GLOBAL_SECTOR_COLUMNS: int = 12
const GLOBAL_SECTOR_ROWS: int = 7
const RESOURCE_CLEARANCE: float = 96.0
const MIN_RESOURCE_SPACING: float = 300.0
const GATHER_RANGE: float = 260.0
const HARVEST_AMOUNT: int = 1
const MIN_GATHER_INTERACTIONS: int = 3
const MAX_GATHER_INTERACTIONS: int = 5
const KIND_COUNT: int = 3
const PLACEMENT_ATTEMPTS: int = 36

@export var scatter_seed: int = DEFAULT_SCATTER_SEED
@export var world_map_path: NodePath

var _world_map: BesprenWorldMap2D
var _scattered: bool = false
var _positions: PackedVector2Array = PackedVector2Array()
var _kinds: PackedInt32Array = PackedInt32Array()
var _available: PackedByteArray = PackedByteArray()
var _completed_interactions: PackedByteArray = PackedByteArray()
var _required_interactions: PackedByteArray = PackedByteArray()
var _views: Array[Node2D] = []
var _inventory_by_peer: Dictionary[int, PackedInt32Array] = {}
var _focused_resource_by_peer: Dictionary[int, int] = {}
var _state_revision: int = 0


func _ready() -> void:
	z_index = 5
	z_as_relative = false
	y_sort_enabled = true
	call_deferred(&"ensure_scattered")


func configure_world_map(world_map: BesprenWorldMap2D) -> void:
	_world_map = world_map


func configure_seed(seed_value: int) -> void:
	scatter_seed = seed_value
	if _scattered:
		scatter_now()


func ensure_scattered() -> void:
	if _scattered:
		return
	_resolve_world_map()
	if _world_map == null:
		push_error("ResourceScatter2D requires a BesprenWorldMap2D")
		return
	_world_map.ensure_built()
	_build_scatter()


func scatter_now() -> void:
	_clear_scatter()
	_resolve_world_map()
	if _world_map == null:
		push_error("ResourceScatter2D cannot scatter without its world map")
		return
	_world_map.ensure_built()
	_build_scatter()


func get_resource_count() -> int:
	return _positions.size()


func get_available_resource_count() -> int:
	var count: int = 0
	for state: int in _available:
		if state != 0:
			count += 1
	return count


func is_resource_available(resource_id: int) -> bool:
	return resource_id >= 0 and resource_id < _available.size() and _available[resource_id] != 0


func get_available_resource_positions() -> PackedVector2Array:
	var positions: PackedVector2Array = PackedVector2Array()
	for resource_id: int in range(_positions.size()):
		if is_resource_available(resource_id):
			positions.append(_positions[resource_id])
	return positions


func get_available_resource_kinds() -> PackedInt32Array:
	var kinds: PackedInt32Array = PackedInt32Array()
	for resource_id: int in range(_kinds.size()):
		if is_resource_available(resource_id):
			kinds.append(_kinds[resource_id])
	return kinds


func get_resource_position(resource_id: int) -> Vector2:
	if resource_id < 0 or resource_id >= _positions.size():
		return Vector2.INF
	return _positions[resource_id]


func get_resource_kind(resource_id: int) -> int:
	if resource_id < 0 or resource_id >= _kinds.size():
		return -1
	return _kinds[resource_id]


func get_resource_view(resource_id: int) -> Node2D:
	if resource_id < 0 or resource_id >= _views.size():
		return null
	return _views[resource_id]


func get_completed_interactions(resource_id: int) -> int:
	if resource_id < 0 or resource_id >= _completed_interactions.size():
		return 0
	return int(_completed_interactions[resource_id])


func get_required_interactions(resource_id: int) -> int:
	if resource_id < 0 or resource_id >= _required_interactions.size():
		return 0
	return int(_required_interactions[resource_id])


func get_progress_snapshot() -> PackedByteArray:
	return _completed_interactions.duplicate()


func clear_peer_focus(peer_id: int) -> void:
	_focused_resource_by_peer.erase(peer_id)


func get_spawn_signature() -> PackedStringArray:
	var signature: PackedStringArray = PackedStringArray()
	for resource_id: int in range(_positions.size()):
		var resource_position: Vector2 = _positions[resource_id]
		signature.append(
			"%03d|%d|%.2f|%.2f" % [
				resource_id,
				_kinds[resource_id],
				resource_position.x,
				resource_position.y,
			]
		)
	return signature


func get_layout_version() -> int:
	return LAYOUT_VERSION


func get_layout_identity() -> String:
	var signature_lines: PackedStringArray = get_spawn_signature()
	var identity_payload: String = "%d\n%d\n%s" % [
		LAYOUT_VERSION,
		scatter_seed,
		"\n".join(signature_lines),
	]
	return identity_payload.sha256_text()


func get_state_revision() -> int:
	return _state_revision


func get_inventory_amount(peer_id: int, resource_kind: int) -> int:
	if resource_kind < 0 or resource_kind >= KIND_COUNT:
		return 0
	var inventory: PackedInt32Array = _inventory_by_peer.get(peer_id, PackedInt32Array())
	if inventory.size() != KIND_COUNT:
		return 0
	return inventory[resource_kind]


func try_gather_authoritative(peer_id: int, actor_position: Vector2) -> int:
	if not multiplayer.is_server() or peer_id <= 0 or not actor_position.is_finite():
		return -1
	ensure_scattered()
	var nearest_resource_id: int = _resolve_focused_resource(peer_id, actor_position)
	if nearest_resource_id < 0:
		_focused_resource_by_peer.erase(peer_id)
		gather_rejected.emit(peer_id, actor_position)
		return -1
	_focused_resource_by_peer[peer_id] = nearest_resource_id
	var completed_before: int = int(_completed_interactions[nearest_resource_id])
	var completed_after: int = completed_before + 1
	var required: int = int(_required_interactions[nearest_resource_id])
	var granted_amount: int = _grant_for_step(completed_before, completed_after, required)
	_apply_gather_progress.rpc(
		LAYOUT_VERSION,
		scatter_seed,
		get_layout_identity(),
		_state_revision + 1,
		nearest_resource_id,
		peer_id,
		_kinds[nearest_resource_id],
		completed_after,
		required,
		granted_amount
	)
	return nearest_resource_id


func sync_state_to_peer(peer_id: int) -> void:
	if not multiplayer.is_server() or peer_id <= MultiplayerPeer.TARGET_PEER_SERVER:
		return
	ensure_scattered()
	var inventory_snapshot: Dictionary[int, PackedInt32Array] = {}
	for inventory_peer_id: int in _inventory_by_peer:
		inventory_snapshot[inventory_peer_id] = _inventory_by_peer[inventory_peer_id].duplicate()
	_receive_resource_snapshot.rpc_id(
		peer_id,
		LAYOUT_VERSION,
		scatter_seed,
		get_layout_identity(),
		_state_revision,
		_completed_interactions,
		inventory_snapshot
	)


@rpc("authority", "call_local", "reliable")
func _apply_gather_progress(
	layout_version: int,
	authoritative_seed: int,
	layout_identity: String,
	state_revision: int,
	resource_id: int,
	peer_id: int,
	resource_kind: int,
	completed_interactions: int,
	required_interactions: int,
	amount: int
) -> void:
	ensure_scattered()
	if (
		not _layout_identity_matches(layout_version, authoritative_seed, layout_identity)
		or state_revision != _state_revision + 1
		or resource_id < 0
		or resource_id >= _available.size()
		or _available[resource_id] == 0
		or peer_id <= 0
		or resource_kind < 0
		or resource_kind >= KIND_COUNT
		or resource_kind != _kinds[resource_id]
		or required_interactions != int(_required_interactions[resource_id])
		or completed_interactions != int(_completed_interactions[resource_id]) + 1
		or completed_interactions > required_interactions
		or amount != _grant_for_step(
			int(_completed_interactions[resource_id]),
			completed_interactions,
			required_interactions
		)
	):
		return
	_state_revision = state_revision
	_completed_interactions[resource_id] = completed_interactions
	var view: Node2D = _views[resource_id]
	var resource_view: ResourceNodeView = view as ResourceNodeView
	if resource_view != null:
		resource_view.apply_harvest_progress(
			completed_interactions,
			required_interactions,
			true
		)
	var inventory: PackedInt32Array = _inventory_by_peer.get(peer_id, PackedInt32Array())
	if inventory.size() != KIND_COUNT:
		inventory.resize(KIND_COUNT)
		inventory.fill(0)
	if amount > 0:
		inventory[resource_kind] += amount
	_inventory_by_peer[peer_id] = inventory
	resource_progressed.emit(
		peer_id,
		resource_kind,
		completed_interactions,
		required_interactions,
		amount,
		resource_id,
		_positions[resource_id]
	)
	if completed_interactions < required_interactions:
		return
	_available[resource_id] = 0
	view.visible = false
	view.process_mode = Node.PROCESS_MODE_DISABLED
	_clear_focus_for_resource(resource_id)
	resource_gathered.emit(
		peer_id,
		resource_kind,
		amount,
		resource_id,
		_positions[resource_id]
	)


@rpc("authority", "call_remote", "reliable")
func _receive_resource_snapshot(
	layout_version: int,
	authoritative_seed: int,
	layout_identity: String,
	state_revision: int,
	completed_interactions: PackedByteArray,
	inventory_snapshot: Dictionary
) -> void:
	ensure_scattered()
	var rejection_reason: StringName = _validate_snapshot(
		layout_version,
		authoritative_seed,
		layout_identity,
		state_revision,
		completed_interactions,
		inventory_snapshot
	)
	if not rejection_reason.is_empty():
		resource_snapshot_rejected.emit(rejection_reason)
		return

	# A snapshot is a complete authoritative replacement, not a delta. It restores
	# partial progress as well as depleted nodes after late join or reconnect.
	for resource_id: int in range(_available.size()):
		var completed: int = int(completed_interactions[resource_id])
		var required: int = int(_required_interactions[resource_id])
		_completed_interactions[resource_id] = completed
		var available: bool = completed < required
		_available[resource_id] = 1 if available else 0
		_views[resource_id].visible = available
		_views[resource_id].process_mode = (
			Node.PROCESS_MODE_INHERIT if available else Node.PROCESS_MODE_DISABLED
		)
		var resource_view: ResourceNodeView = _views[resource_id] as ResourceNodeView
		if resource_view != null:
			resource_view.apply_harvest_progress(completed, required, false)
	_focused_resource_by_peer.clear()
	_inventory_by_peer.clear()
	for peer_key: Variant in inventory_snapshot:
		var peer_id: int = int(peer_key)
		var inventory: PackedInt32Array = inventory_snapshot[peer_key]
		_inventory_by_peer[peer_id] = inventory.duplicate()
	_state_revision = state_revision
	resource_snapshot_applied.emit(state_revision)


func _validate_snapshot(
	layout_version: int,
	authoritative_seed: int,
	layout_identity: String,
	state_revision: int,
	completed_interactions: PackedByteArray,
	inventory_snapshot: Dictionary
) -> StringName:
	if not _layout_identity_matches(layout_version, authoritative_seed, layout_identity):
		return &"layout_mismatch"
	if state_revision < _state_revision:
		return &"stale_revision"
	if completed_interactions.size() != _available.size():
		return &"invalid_progress_size"
	for resource_id: int in range(completed_interactions.size()):
		if int(completed_interactions[resource_id]) > int(_required_interactions[resource_id]):
			return &"invalid_progress_amount"
	for peer_key: Variant in inventory_snapshot:
		if not peer_key is int or int(peer_key) <= 0:
			return &"invalid_inventory_peer"
		var inventory_variant: Variant = inventory_snapshot[peer_key]
		if not inventory_variant is PackedInt32Array:
			return &"invalid_inventory_type"
		var inventory: PackedInt32Array = inventory_variant
		if inventory.size() != KIND_COUNT:
			return &"invalid_inventory_size"
		for amount: int in inventory:
			if amount < 0:
				return &"invalid_inventory_amount"
	return &""


func _layout_identity_matches(
	layout_version: int,
	authoritative_seed: int,
	layout_identity: String
) -> bool:
	return (
		layout_version == LAYOUT_VERSION
		and authoritative_seed == scatter_seed
		and not layout_identity.is_empty()
		and layout_identity == get_layout_identity()
	)


func _resolve_world_map() -> void:
	if _world_map != null and is_instance_valid(_world_map):
		return
	if world_map_path.is_empty():
		return
	_world_map = get_node_or_null(world_map_path) as BesprenWorldMap2D


func _build_scatter() -> void:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = scatter_seed
	_positions.resize(0)
	_kinds.resize(0)
	_available.resize(0)
	_completed_interactions.resize(0)
	_required_interactions.resize(0)
	_views.clear()
	_inventory_by_peer.clear()
	_focused_resource_by_peer.clear()
	_state_revision = 0
	for resource_id: int in range(RESOURCE_COUNT):
		var resource_kind: int = resource_id % KIND_COUNT
		var resource_position: Vector2 = _placement_for(resource_id, random)
		if not resource_position.is_finite():
			push_error("Could not place deterministic resource %d" % resource_id)
			continue
		_positions.append(resource_position)
		_kinds.append(resource_kind)
		_available.append(1)
		_completed_interactions.append(0)
		_required_interactions.append(_required_interactions_for(resource_id))
		var view: Node2D = RESOURCE_SCENES[resource_kind].instantiate() as Node2D
		view.name = StringName("Resource_%03d" % resource_id)
		view.position = resource_position
		view.z_index = 5
		view.z_as_relative = false
		view.set_meta(&"resource_id", resource_id)
		view.set_meta(&"resource_kind", resource_kind)
		add_child(view)
		var resource_view: ResourceNodeView = view as ResourceNodeView
		if resource_view != null:
			resource_view.apply_harvest_progress(
				0,
				int(_required_interactions[resource_id]),
				false
			)
		_views.append(view)
	_scattered = true


func _placement_for(resource_id: int, random: RandomNumberGenerator) -> Vector2:
	var anchors: PackedVector2Array = PackedVector2Array([
		BesprenWorldMap2D.STARTING_CAMP_POSITION + Vector2(390.0, 120.0),
		BesprenWorldMap2D.STARTING_CAMP_POSITION + Vector2(-410.0, 150.0),
		BesprenWorldMap2D.STARTING_CAMP_POSITION + Vector2(130.0, -430.0),
	])
	if resource_id < anchors.size():
		return anchors[resource_id]

	var sector_index: int = resource_id - anchors.size()
	var sector_column: int = sector_index % GLOBAL_SECTOR_COLUMNS
	var sector_row: int = floori(float(sector_index) / float(GLOBAL_SECTOR_COLUMNS))
	var sector_size: Vector2 = Vector2(
		BesprenWorldMap2D.WORLD_SIZE / float(GLOBAL_SECTOR_COLUMNS),
		BesprenWorldMap2D.WORLD_SIZE / float(GLOBAL_SECTOR_ROWS)
	)
	var sector_minimum: Vector2 = Vector2(
		-BesprenWorldMap2D.PLAYABLE_HALF_EXTENT + float(sector_column) * sector_size.x,
		-BesprenWorldMap2D.PLAYABLE_HALF_EXTENT + float(sector_row) * sector_size.y
	)
	for _attempt: int in range(PLACEMENT_ATTEMPTS):
		var candidate: Vector2 = Vector2(
			random.randf_range(sector_minimum.x + sector_size.x * 0.14, sector_minimum.x + sector_size.x * 0.86),
			random.randf_range(sector_minimum.y + sector_size.y * 0.14, sector_minimum.y + sector_size.y * 0.86)
		)
		if _is_valid_candidate(candidate):
			return candidate
	for _global_attempt: int in range(PLACEMENT_ATTEMPTS * 2):
		var global_candidate: Vector2 = Vector2(
			random.randf_range(-BesprenWorldMap2D.PLAYABLE_HALF_EXTENT + 300.0, BesprenWorldMap2D.PLAYABLE_HALF_EXTENT - 300.0),
			random.randf_range(-BesprenWorldMap2D.PLAYABLE_HALF_EXTENT + 300.0, BesprenWorldMap2D.PLAYABLE_HALF_EXTENT - 300.0)
		)
		if _is_valid_candidate(global_candidate):
			return global_candidate
	return Vector2.INF


func _is_valid_candidate(candidate: Vector2) -> bool:
	if not _world_map.is_position_walkable(candidate, RESOURCE_CLEARANCE):
		return false
	var minimum_distance_squared: float = MIN_RESOURCE_SPACING * MIN_RESOURCE_SPACING
	for existing_position: Vector2 in _positions:
		if candidate.distance_squared_to(existing_position) < minimum_distance_squared:
			return false
	return true


func _resolve_focused_resource(peer_id: int, actor_position: Vector2) -> int:
	var focused_id: int = _focused_resource_by_peer.get(peer_id, -1)
	var range_squared: float = GATHER_RANGE * GATHER_RANGE
	if (
		focused_id >= 0
		and focused_id < _available.size()
		and _available[focused_id] != 0
		and actor_position.distance_squared_to(_positions[focused_id]) <= range_squared
	):
		return focused_id
	var nearest_resource_id: int = -1
	var nearest_distance_squared: float = range_squared
	for resource_id: int in range(_positions.size()):
		if _available[resource_id] == 0:
			continue
		var distance_squared: float = actor_position.distance_squared_to(_positions[resource_id])
		if (
			distance_squared < nearest_distance_squared
			or (
				is_equal_approx(distance_squared, nearest_distance_squared)
				and (nearest_resource_id < 0 or resource_id < nearest_resource_id)
			)
		):
			nearest_distance_squared = distance_squared
			nearest_resource_id = resource_id
	return nearest_resource_id


func _required_interactions_for(resource_id: int) -> int:
	var digest: PackedByteArray = ("%d|%d" % [scatter_seed, resource_id]).sha256_buffer()
	if digest.is_empty():
		return MIN_GATHER_INTERACTIONS
	return MIN_GATHER_INTERACTIONS + int(digest[0]) % (
		MAX_GATHER_INTERACTIONS - MIN_GATHER_INTERACTIONS + 1
	)


func _grant_for_step(completed_before: int, completed_after: int, required: int) -> int:
	if required <= 0 or completed_before < 0 or completed_after <= completed_before:
		return -1
	return (
		floori(float(completed_after * HARVEST_AMOUNT) / float(required))
		- floori(float(completed_before * HARVEST_AMOUNT) / float(required))
	)


func _clear_focus_for_resource(resource_id: int) -> void:
	var peer_ids: Array[int] = _focused_resource_by_peer.keys()
	for peer_id: int in peer_ids:
		if _focused_resource_by_peer.get(peer_id, -1) == resource_id:
			_focused_resource_by_peer.erase(peer_id)


func _clear_scatter() -> void:
	for view: Node2D in _views:
		if is_instance_valid(view):
			remove_child(view)
			view.queue_free()
	_positions.clear()
	_kinds.clear()
	_available.clear()
	_completed_interactions.clear()
	_required_interactions.clear()
	_views.clear()
	_inventory_by_peer.clear()
	_focused_resource_by_peer.clear()
	_state_revision = 0
	_scattered = false
