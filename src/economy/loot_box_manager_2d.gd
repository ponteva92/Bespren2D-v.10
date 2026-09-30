class_name LootBoxManager2D
extends Node2D
## Host validates proximity, atomically credits the shared team pool, and replicates opens.

signal loot_opened(peer_id: int, loot_id: int, grant: PackedInt32Array)

const USE_RADIUS: float = 112.0
const LOOT_POSITIONS: Array[Vector2] = [
	Vector2(-520.0, 360.0),
	Vector2(520.0, 360.0),
	Vector2(-720.0, -420.0),
	Vector2(720.0, -420.0),
	Vector2(-1280.0, 120.0),
	Vector2(1280.0, 120.0),
]
const LOOT_GRANTS: Array[Vector3i] = [
	Vector3i(18, 8, 2),
	Vector3i(12, 12, 4),
	Vector3i(22, 4, 3),
	Vector3i(8, 14, 8),
	Vector3i(16, 10, 5),
	Vector3i(10, 8, 12),
]

@export_node_path("TacticalBuildSystem") var build_system_path: NodePath
@export_node_path("CoopSession") var session_path: NodePath

var _build_system: TacticalBuildSystem
var _session: CoopSession
var _boxes: Dictionary[int, LootBox2D] = {}
var _opened: Dictionary[int, bool] = {}
var _revision: int = 0


func _ready() -> void:
	_build_system = get_node_or_null(build_system_path) as TacticalBuildSystem
	_session = get_node_or_null(session_path) as CoopSession
	_build_boxes()


func reset_for_session() -> void:
	_revision = 0
	_opened.clear()
	for box: LootBox2D in _boxes.values():
		if is_instance_valid(box):
			box.set_opened(false)


func try_open_authoritative(peer_id: int, player_position: Vector2) -> bool:
	if (
		not multiplayer.is_server()
		or peer_id <= 0
		or not player_position.is_finite()
		or not is_instance_valid(_session)
		or not _session.is_peer_registered(peer_id)
	):
		return false
	var selected: LootBox2D
	var best_distance_squared: float = USE_RADIUS * USE_RADIUS
	var loot_ids: Array[int] = _boxes.keys()
	loot_ids.sort()
	for loot_id: int in loot_ids:
		if _opened.has(loot_id):
			continue
		var candidate: LootBox2D = _boxes[loot_id]
		var distance_squared: float = player_position.distance_squared_to(
			candidate.global_position
		)
		if distance_squared <= best_distance_squared:
			selected = candidate
			best_distance_squared = distance_squared
	if not is_instance_valid(selected):
		return false
	_revision += 1
	_commit_loot_opened.rpc(
		_revision,
		peer_id,
		selected.loot_id,
		selected.resource_grant
	)
	return true


func sync_state_to_peer(peer_id: int) -> void:
	if not multiplayer.is_server() or peer_id <= CoopSession.AUTHORITY_PEER_ID:
		return
	var opened_ids: PackedInt32Array = PackedInt32Array()
	var sorted_ids: Array[int] = _opened.keys()
	sorted_ids.sort()
	for loot_id: int in sorted_ids:
		opened_ids.append(loot_id)
	_receive_loot_snapshot.rpc_id(peer_id, _revision, opened_ids)


func get_box_count() -> int:
	return _boxes.size()


func get_opened_count() -> int:
	return _opened.size()


func get_box(loot_id: int) -> LootBox2D:
	return _boxes.get(loot_id)


@rpc("authority", "call_local", "reliable")
func _commit_loot_opened(
	revision: int,
	peer_id: int,
	loot_id: int,
	grant: PackedInt32Array
) -> void:
	if (
		revision <= _revision and _opened.has(loot_id)
		or peer_id <= 0
		or not _boxes.has(loot_id)
		or grant.size() != TacticalBuildSystem.RESOURCE_KIND_COUNT
	):
		return
	_revision = maxi(_revision, revision)
	_opened[loot_id] = true
	_boxes[loot_id].set_opened(true)
	if multiplayer.is_server() and is_instance_valid(_build_system):
		_build_system.credit_shared_bundle_authoritative(grant)
	loot_opened.emit(peer_id, loot_id, grant.duplicate())


@rpc("authority", "call_remote", "reliable")
func _receive_loot_snapshot(revision: int, opened_ids: PackedInt32Array) -> void:
	if revision < _revision:
		return
	for loot_id: int in opened_ids:
		if not _boxes.has(loot_id):
			return
	_revision = revision
	_opened.clear()
	for box: LootBox2D in _boxes.values():
		box.set_opened(false)
	for loot_id: int in opened_ids:
		_opened[loot_id] = true
		_boxes[loot_id].set_opened(true)


func _build_boxes() -> void:
	for index: int in range(LOOT_POSITIONS.size()):
		var loot_id: int = index + 1
		var box: LootBox2D = LootBox2D.new()
		var grant_vector: Vector3i = LOOT_GRANTS[index]
		var grant: PackedInt32Array = PackedInt32Array([
			grant_vector.x,
			grant_vector.y,
			grant_vector.z,
		])
		box.configure(loot_id, LOOT_POSITIONS[index], grant)
		add_child(box)
		_boxes[loot_id] = box
