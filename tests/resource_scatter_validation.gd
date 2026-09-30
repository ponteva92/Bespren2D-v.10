extends SceneTree
## Headless deterministic-scatter, presentation, and solo-authority gather gate.

const WORLD_MAP_SCENE: PackedScene = preload("res://scenes/world/world_map_2d.tscn")
const RESOURCE_SCATTER_SCENE: PackedScene = preload("res://scenes/world/resource_scatter_2d.tscn")
const EXPECTED_RESOURCE_COUNT: int = 87
const EXPECTED_KIND_COUNT: int = 3
const EXPECTED_ENTITY_Z: int = 5
const COLOR_TOLERANCE: float = 0.001
const TOON_SHADER_PATH: String = "res://shaders/toon_emissive_outline.gdshader"
const EXPECTED_GLOW_COLORS: Array[Color] = [
	Color("ffd700"),
	Color("e0e0e0"),
	Color("00ffff"),
]

var _checks: int = 0
var _failures: int = 0
var _gathered_count: int = 0
var _progress_count: int = 0
var _rejected_count: int = 0
var _last_gathered_peer_id: int = -1
var _last_gathered_kind: int = -1
var _last_gathered_amount: int = 0
var _last_gathered_resource_id: int = -1
var _last_progress_completed: int = 0
var _last_progress_required: int = 0
var _last_progress_grant: int = -1
var _snapshot_applied_count: int = 0
var _snapshot_rejected_count: int = 0
var _last_snapshot_revision: int = -1


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var offline_peer: OfflineMultiplayerPeer = OfflineMultiplayerPeer.new()
	root.multiplayer.multiplayer_peer = offline_peer
	var world_map: BesprenWorldMap2D = WORLD_MAP_SCENE.instantiate() as BesprenWorldMap2D
	_check(world_map != null, "World map scene instantiates for resource validation")
	if world_map == null:
		_finish()
		return
	root.add_child(world_map)
	await process_frame
	world_map.ensure_built()

	var baseline: BesprenResourceScatter2D = _create_scatter(
		world_map,
		BesprenResourceScatter2D.DEFAULT_SCATTER_SEED,
		&"BaselineScatter"
	)
	var matching: BesprenResourceScatter2D = _create_scatter(
		world_map,
		BesprenResourceScatter2D.DEFAULT_SCATTER_SEED,
		&"MatchingScatter"
	)
	var different: BesprenResourceScatter2D = _create_scatter(
		world_map,
		BesprenResourceScatter2D.DEFAULT_SCATTER_SEED + 1,
		&"DifferentScatter"
	)
	_check(baseline != null and matching != null and different != null, "Three resource scatter instances initialize through public configuration APIs")
	if baseline == null or matching == null or different == null:
		_free_if_valid(baseline)
		_free_if_valid(matching)
		_free_if_valid(different)
		world_map.queue_free()
		await process_frame
		_finish()
		return
	await process_frame

	_validate_determinism(baseline, matching, different)
	_validate_distribution(baseline, world_map)
	_validate_visual_contract(baseline)
	await _validate_solo_gather(baseline, world_map)
	_validate_snapshot_replacement(baseline)

	baseline.queue_free()
	matching.queue_free()
	different.queue_free()
	world_map.queue_free()
	await process_frame
	_finish()


func _create_scatter(
	world_map: BesprenWorldMap2D,
	seed_value: int,
	scatter_name: StringName
) -> BesprenResourceScatter2D:
	var scatter: BesprenResourceScatter2D = RESOURCE_SCATTER_SCENE.instantiate() as BesprenResourceScatter2D
	if scatter == null:
		return null
	scatter.name = scatter_name
	scatter.configure_world_map(world_map)
	scatter.configure_seed(seed_value)
	root.add_child(scatter)
	scatter.ensure_scattered()
	return scatter


func _validate_determinism(
	baseline: BesprenResourceScatter2D,
	matching: BesprenResourceScatter2D,
	different: BesprenResourceScatter2D
) -> void:
	var baseline_signature: PackedStringArray = baseline.get_spawn_signature()
	var matching_signature: PackedStringArray = matching.get_spawn_signature()
	var different_signature: PackedStringArray = different.get_spawn_signature()
	_check(
		_signatures_equal(baseline_signature, matching_signature),
		"Identical seeds produce identical resource IDs, kinds, and positions"
	)
	_check(
		not _signatures_equal(baseline_signature, different_signature),
		"Different seeds produce a different global resource layout"
	)
	_check(
		baseline.get_layout_version() == BesprenResourceScatter2D.LAYOUT_VERSION,
		"Scatter publishes its explicit numeric layout version"
	)
	_check(
		baseline.get_layout_identity().length() == 64
		and baseline.get_layout_identity() == matching.get_layout_identity(),
		"Matching deterministic layouts publish the same compact SHA-256 identity"
	)
	_check(
		baseline.get_layout_identity() != different.get_layout_identity(),
		"Scatter seed and spawn signature participate in authoritative layout identity"
	)
	var required_counts_match: bool = true
	var required_counts_in_range: bool = true
	var different_seed_changes_progression: bool = false
	for resource_id: int in range(baseline.get_resource_count()):
		var baseline_required: int = baseline.get_required_interactions(resource_id)
		if baseline_required != matching.get_required_interactions(resource_id):
			required_counts_match = false
		if (
			baseline_required < BesprenResourceScatter2D.MIN_GATHER_INTERACTIONS
			or baseline_required > BesprenResourceScatter2D.MAX_GATHER_INTERACTIONS
		):
			required_counts_in_range = false
		if baseline_required != different.get_required_interactions(resource_id):
			different_seed_changes_progression = true
	_check(required_counts_match, "Matching seeds produce identical gather interaction counts")
	_check(required_counts_in_range, "Every resource deterministically requires three to five interactions")
	_check(different_seed_changes_progression, "Scatter seed participates in deterministic gather durability")


func _validate_distribution(
	scatter: BesprenResourceScatter2D,
	world_map: BesprenWorldMap2D
) -> void:
	var resource_count: int = scatter.get_resource_count()
	_check(resource_count == EXPECTED_RESOURCE_COUNT, "Scatter produces exactly 87 resource nodes")
	_check(scatter.get_available_resource_count() == EXPECTED_RESOURCE_COUNT, "All 87 resources begin available")
	_check(scatter.get_child_count() == EXPECTED_RESOURCE_COUNT, "Scatter scene owns exactly 87 resource views")
	_check(scatter.z_index == EXPECTED_ENTITY_Z and not scatter.z_as_relative, "Resource container uses absolute entity z=5")
	_check(scatter.y_sort_enabled, "Resource container explicitly enables Y-sort")
	if resource_count <= 0:
		return

	var kind_counts: PackedInt32Array = PackedInt32Array()
	kind_counts.resize(EXPECTED_KIND_COUNT)
	kind_counts.fill(0)
	var all_positions_finite: bool = true
	var all_positions_inside_world: bool = true
	var all_positions_walkable: bool = true
	var minimum_position: Vector2 = scatter.get_resource_position(0)
	var maximum_position: Vector2 = minimum_position
	var quadrant_counts: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	for resource_id: int in range(resource_count):
		var resource_position: Vector2 = scatter.get_resource_position(resource_id)
		var resource_kind: int = scatter.get_resource_kind(resource_id)
		if not resource_position.is_finite():
			all_positions_finite = false
			continue
		if not world_map.get_playable_rect().has_point(resource_position):
			all_positions_inside_world = false
		if not world_map.is_position_walkable(resource_position, BesprenResourceScatter2D.RESOURCE_CLEARANCE):
			all_positions_walkable = false
		minimum_position.x = minf(minimum_position.x, resource_position.x)
		minimum_position.y = minf(minimum_position.y, resource_position.y)
		maximum_position.x = maxf(maximum_position.x, resource_position.x)
		maximum_position.y = maxf(maximum_position.y, resource_position.y)
		if resource_kind >= 0 and resource_kind < kind_counts.size():
			kind_counts[resource_kind] += 1
		var quadrant_index: int = 0
		if resource_position.x >= 0.0:
			quadrant_index += 1
		if resource_position.y >= 0.0:
			quadrant_index += 2
		quadrant_counts[quadrant_index] += 1
	_check(all_positions_finite, "Every resource position is finite")
	_check(all_positions_inside_world, "Every resource lies inside the complete playable X/Y plane")
	_check(all_positions_walkable, "Every resource respects world collision clearance")
	var every_kind_balanced: bool = true
	for kind_count: int in kind_counts:
		if kind_count != EXPECTED_RESOURCE_COUNT / EXPECTED_KIND_COUNT:
			every_kind_balanced = false
	_check(every_kind_balanced, "Wood, Metal, and Tech each receive exactly 29 nodes")
	var all_quadrants_covered: bool = true
	for quadrant_count: int in quadrant_counts:
		if quadrant_count <= 0:
			all_quadrants_covered = false
	_check(all_quadrants_covered, "Resource scatter covers all four world quadrants")
	var span_threshold: float = BesprenWorldMap2D.PLAYABLE_HALF_EXTENT * 0.75
	_check(
		minimum_position.x < -span_threshold
		and minimum_position.y < -span_threshold
		and maximum_position.x > span_threshold
		and maximum_position.y > span_threshold,
		"Resource scatter reaches the global north, south, east, and west extents"
	)

	var minimum_spacing_squared: float = INF
	for first_id: int in range(resource_count):
		var first_position: Vector2 = scatter.get_resource_position(first_id)
		for second_id: int in range(first_id + 1, resource_count):
			var distance_squared: float = first_position.distance_squared_to(
				scatter.get_resource_position(second_id)
			)
			minimum_spacing_squared = minf(minimum_spacing_squared, distance_squared)
	_check(
		minimum_spacing_squared >= pow(BesprenResourceScatter2D.MIN_RESOURCE_SPACING, 2.0),
		"Every resource pair respects the 300-unit minimum spacing"
	)


func _validate_visual_contract(scatter: BesprenResourceScatter2D) -> void:
	var all_views_are_typed: bool = true
	var all_views_use_entity_z: bool = true
	var all_kinds_match: bool = true
	var all_glows_are_valid: bool = true
	var all_icons_use_toon_shader: bool = true
	var every_kind_shares_one_material: bool = true
	var material_ids_by_kind: PackedInt64Array = PackedInt64Array()
	material_ids_by_kind.resize(EXPECTED_KIND_COUNT)
	material_ids_by_kind.fill(0)
	for resource_id: int in range(scatter.get_resource_count()):
		var view_node: Node2D = scatter.get_resource_view(resource_id)
		var resource_view: ResourceNodeView = view_node as ResourceNodeView
		var resource_kind: int = scatter.get_resource_kind(resource_id)
		if resource_view == null:
			all_views_are_typed = false
			continue
		if resource_view.z_index != EXPECTED_ENTITY_Z or resource_view.z_as_relative:
			all_views_use_entity_z = false
		if resource_kind < 0 or resource_kind >= EXPECTED_GLOW_COLORS.size():
			all_kinds_match = false
			continue
		if resource_view.kind != resource_kind:
			all_kinds_match = false
		var expected_color: Color = EXPECTED_GLOW_COLORS[resource_kind]
		if not _colors_match(resource_view.glow_color, expected_color):
			all_kinds_match = false
		var glow: PointLight2D = resource_view.get_node_or_null("Glow") as PointLight2D
		if (
			glow == null
			or glow.z_index != EXPECTED_ENTITY_Z
			or glow.z_as_relative
			or glow.texture == null
			or glow.energy <= 0.0
			or not _colors_match(glow.color, expected_color)
		):
			all_glows_are_valid = false
		var icon: Sprite2D = resource_view.get_node_or_null("Icon") as Sprite2D
		if icon == null or icon.z_index != EXPECTED_ENTITY_Z or icon.z_as_relative:
			all_icons_use_toon_shader = false
			continue
		var shader_material: ShaderMaterial = icon.material as ShaderMaterial
		if shader_material == null or shader_material.shader == null:
			all_icons_use_toon_shader = false
			continue
		var material_id: int = shader_material.get_instance_id()
		if material_ids_by_kind[resource_kind] == 0:
			material_ids_by_kind[resource_kind] = material_id
		elif material_ids_by_kind[resource_kind] != material_id:
			every_kind_shares_one_material = false
		var shader_glow_variant: Variant = shader_material.get_shader_parameter(&"glow_color")
		var shader_glow_matches: bool = (
			shader_glow_variant is Color
			and _colors_match(shader_glow_variant as Color, expected_color)
		)
		if (
			shader_material.shader.resource_path != TOON_SHADER_PATH
			or not shader_glow_matches
			or float(shader_material.get_shader_parameter(&"outline_width")) <= 0.0
			or float(shader_material.get_shader_parameter(&"emission_strength")) <= 0.0
			or float(shader_material.get_shader_parameter(&"pulse_speed")) <= 0.0
		):
			all_icons_use_toon_shader = false
	_check(all_views_are_typed, "Every resource view uses ResourceNodeView")
	_check(all_views_use_entity_z, "Every resource view resides on absolute entity z=5")
	_check(all_kinds_match, "Wood, Metal, and Tech views use their authored semantic glow colors")
	_check(all_glows_are_valid, "Every resource owns a configured PointLight2D glow")
	_check(all_icons_use_toon_shader, "Every resource icon uses the pulsing emissive toon-outline shader")
	_check(
		every_kind_shares_one_material and not material_ids_by_kind.has(0),
		"All 87 resource views share exactly one immutable ShaderMaterial per kind"
	)


func _validate_solo_gather(
	scatter: BesprenResourceScatter2D,
	world_map: BesprenWorldMap2D
) -> void:
	_check(scatter.multiplayer.is_server(), "Offline solo peer owns resource authority")
	_check(scatter.multiplayer.get_unique_id() == MultiplayerPeer.TARGET_PEER_SERVER, "Solo resource authority is peer one")
	scatter.resource_gathered.connect(_on_resource_gathered)
	scatter.resource_progressed.connect(_on_resource_progressed)
	scatter.gather_rejected.connect(_on_gather_rejected)
	var peer_id: int = scatter.multiplayer.get_unique_id()
	var out_of_range_position: Vector2 = _find_out_of_range_position(scatter, world_map)
	_check(out_of_range_position.is_finite(), "Validation locates a walkable out-of-range gather position")
	if not out_of_range_position.is_finite():
		return
	var available_before: int = scatter.get_available_resource_count()
	var rejected_resource_id: int = scatter.try_gather_authoritative(peer_id, out_of_range_position)
	await process_frame
	_check(rejected_resource_id == -1, "Out-of-range authoritative gather is rejected")
	_check(_rejected_count == 1, "Out-of-range gather emits one rejection signal")
	_check(scatter.get_available_resource_count() == available_before, "Rejected gather does not deplete a resource")

	var target_resource_id: int = 0
	var target_kind: int = scatter.get_resource_kind(target_resource_id)
	var target_position: Vector2 = scatter.get_resource_position(target_resource_id)
	var required_interactions: int = scatter.get_required_interactions(target_resource_id)
	_check(
		required_interactions >= BesprenResourceScatter2D.MIN_GATHER_INTERACTIONS
		and required_interactions <= BesprenResourceScatter2D.MAX_GATHER_INTERACTIONS,
		"Target node publishes deterministic three-to-five interaction durability"
	)
	for interaction_index: int in range(1, required_interactions + 1):
		var gathered_resource_id: int = scatter.try_gather_authoritative(peer_id, target_position)
		await process_frame
		_check(
			gathered_resource_id == target_resource_id,
			"Accepted interaction %d remains focused on the intended node" % interaction_index
		)
		_check(
			scatter.get_completed_interactions(target_resource_id) == interaction_index,
			"Accepted interaction %d advances exactly one authoritative progress step" % interaction_index
		)
		if interaction_index < required_interactions:
			_check(
				scatter.is_resource_available(target_resource_id)
				and scatter.get_available_resource_count() == available_before,
				"Intermediate interaction keeps the resource available"
			)
			_check(
				scatter.get_inventory_amount(peer_id, target_kind) == 0
				and _gathered_count == 0,
				"Intermediate interaction cannot grant or emit final resources"
			)
	_check(not scatter.is_resource_available(target_resource_id), "Final interaction depletes the resource exactly once")
	_check(scatter.get_available_resource_count() == available_before - 1, "Final interaction removes one available resource")
	_check(scatter.get_inventory_amount(peer_id, target_kind) == BesprenResourceScatter2D.HARVEST_AMOUNT, "All progress steps preserve the original one-unit total yield")
	_check(_progress_count == required_interactions, "Every accepted interaction emits one reliable progress result")
	_check(_gathered_count == 1, "Only the final interaction emits one authoritative gather result")
	_check(
		_last_gathered_peer_id == peer_id
		and _last_gathered_kind == target_kind
		and _last_gathered_amount == BesprenResourceScatter2D.HARVEST_AMOUNT
		and _last_gathered_resource_id == target_resource_id
		and _last_progress_completed == required_interactions
		and _last_progress_required == required_interactions
		and _last_progress_grant == BesprenResourceScatter2D.HARVEST_AMOUNT,
		"Final signals carry authoritative peer, progress, kind, amount, and resource ID"
	)
	var depleted_view: Node2D = scatter.get_resource_view(target_resource_id)
	_check(
		depleted_view != null
		and not depleted_view.visible
		and depleted_view.process_mode == Node.PROCESS_MODE_DISABLED,
		"Depleted resource view is hidden and stops processing"
	)

	var duplicate_resource_id: int = scatter.try_gather_authoritative(peer_id, target_position)
	await process_frame
	_check(duplicate_resource_id == -1, "Duplicate gather against a depleted node is rejected")
	_check(_gathered_count == 1, "Duplicate gather cannot emit a second gather result")
	_check(_progress_count == required_interactions, "Duplicate gather cannot emit a progress result")
	_check(_rejected_count == 2, "Duplicate gather emits a rejection signal")
	_check(
		scatter.get_inventory_amount(peer_id, target_kind) == BesprenResourceScatter2D.HARVEST_AMOUNT,
		"Duplicate gather cannot duplicate inventory"
	)


func _validate_snapshot_replacement(scatter: BesprenResourceScatter2D) -> void:
	scatter.resource_snapshot_applied.connect(_on_resource_snapshot_applied)
	scatter.resource_snapshot_rejected.connect(_on_resource_snapshot_rejected)
	var layout_identity: String = scatter.get_layout_identity()
	var revision_before: int = scatter.get_state_revision()
	var available_before: int = scatter.get_available_resource_count()
	var authority_peer_id: int = MultiplayerPeer.TARGET_PEER_SERVER
	var empty_progress: PackedByteArray = PackedByteArray()
	empty_progress.resize(EXPECTED_RESOURCE_COUNT)
	empty_progress.fill(0)

	var kind_mismatch_resource_id: int = 1
	var canonical_kind: int = scatter.get_resource_kind(kind_mismatch_resource_id)
	var mismatched_kind: int = (canonical_kind + 1) % EXPECTED_KIND_COUNT
	var mismatch_required: int = scatter.get_required_interactions(kind_mismatch_resource_id)
	scatter._apply_gather_progress(
		BesprenResourceScatter2D.LAYOUT_VERSION,
		scatter.scatter_seed,
		layout_identity,
		revision_before + 1,
		kind_mismatch_resource_id,
		authority_peer_id,
		mismatched_kind,
		1,
		mismatch_required,
		0
	)
	_check(
		scatter.is_resource_available(kind_mismatch_resource_id)
		and scatter.get_state_revision() == revision_before
		and scatter.get_completed_interactions(kind_mismatch_resource_id) == 0
		and scatter.get_inventory_amount(authority_peer_id, mismatched_kind) == 0,
		"Progress commits reject a kind that does not match the authoritative resource ID"
	)

	scatter._receive_resource_snapshot(
		BesprenResourceScatter2D.LAYOUT_VERSION,
		scatter.scatter_seed + 1,
		layout_identity,
		revision_before + 1,
		empty_progress,
		{}
	)
	_check(
		_snapshot_rejected_count == 1
		and scatter.get_available_resource_count() == available_before
		and scatter.get_state_revision() == revision_before,
		"Snapshot validates layout version, seed, and spawn identity before applying progress"
	)
	var invalid_size: PackedByteArray = PackedByteArray([0])
	scatter._receive_resource_snapshot(
		BesprenResourceScatter2D.LAYOUT_VERSION,
		scatter.scatter_seed,
		layout_identity,
		revision_before + 1,
		invalid_size,
		{}
	)
	_check(
		_snapshot_rejected_count == 2
		and scatter.get_state_revision() == revision_before,
		"Snapshot rejects incomplete progress arrays instead of partially applying them"
	)

	var first_revision: int = revision_before + 1
	var first_inventory: Dictionary = {
		77: PackedInt32Array([3, 4, 5]),
	}
	var first_progress: PackedByteArray = empty_progress.duplicate()
	first_progress[1] = 1
	first_progress[2] = scatter.get_required_interactions(2)
	scatter._receive_resource_snapshot(
		BesprenResourceScatter2D.LAYOUT_VERSION,
		scatter.scatter_seed,
		layout_identity,
		first_revision,
		first_progress,
		first_inventory
	)
	var resurrected_view: Node2D = scatter.get_resource_view(0)
	var partial_view: ResourceNodeView = scatter.get_resource_view(1) as ResourceNodeView
	_check(
		_snapshot_applied_count == 1
		and _last_snapshot_revision == first_revision
		and scatter.get_state_revision() == first_revision,
		"A valid late-join snapshot records the authoritative state revision"
	)
	_check(
		scatter.is_resource_available(0)
		and scatter.is_resource_available(1)
		and not scatter.is_resource_available(2)
		and scatter.get_available_resource_count() == EXPECTED_RESOURCE_COUNT - 1
		and scatter.get_completed_interactions(1) == 1,
		"Snapshot replaces complete partial progress and resurrects stale local depletion"
	)
	_check(
		resurrected_view != null
		and resurrected_view.visible
		and resurrected_view.process_mode == Node.PROCESS_MODE_INHERIT
		and partial_view != null
		and partial_view.get_completed_interactions() == 1,
		"Snapshot restoration re-enables depleted views and restores partial presentation"
	)
	_check(
		scatter.get_inventory_amount(authority_peer_id, 0) == 0
		and scatter.get_inventory_amount(77, 0) == 3
		and scatter.get_inventory_amount(77, 1) == 4
		and scatter.get_inventory_amount(77, 2) == 5,
		"Snapshot clears stale inventory and replaces it with the authoritative inventory set"
	)
	var invalid_progress: PackedByteArray = first_progress.duplicate()
	invalid_progress[3] = scatter.get_required_interactions(3) + 1
	scatter._receive_resource_snapshot(
		BesprenResourceScatter2D.LAYOUT_VERSION,
		scatter.scatter_seed,
		layout_identity,
		first_revision + 1,
		invalid_progress,
		{}
	)
	_check(
		_snapshot_rejected_count == 3
		and scatter.get_state_revision() == first_revision,
		"Snapshot rejects progress beyond deterministic node durability"
	)

	var second_revision: int = first_revision + 1
	var second_progress: PackedByteArray = empty_progress.duplicate()
	second_progress[3] = scatter.get_required_interactions(3)
	scatter._receive_resource_snapshot(
		BesprenResourceScatter2D.LAYOUT_VERSION,
		scatter.scatter_seed,
		layout_identity,
		second_revision,
		second_progress,
		{}
	)
	_check(
		_snapshot_applied_count == 2
		and _last_snapshot_revision == second_revision
		and scatter.is_resource_available(1)
		and scatter.is_resource_available(2)
		and not scatter.is_resource_available(3)
		and scatter.get_available_resource_count() == EXPECTED_RESOURCE_COUNT - 1,
		"A fresher reconnect snapshot clears partial state and resurrects stale depletion"
	)
	_check(
		scatter.get_inventory_amount(77, 0) == 0
		and scatter.get_inventory_amount(77, 1) == 0
		and scatter.get_inventory_amount(77, 2) == 0,
		"A fresher authoritative snapshot also removes inventory entries absent from the payload"
	)

	scatter._receive_resource_snapshot(
		BesprenResourceScatter2D.LAYOUT_VERSION,
		scatter.scatter_seed,
		layout_identity,
		first_revision,
		first_progress,
		{}
	)
	_check(
		_snapshot_rejected_count == 4
		and scatter.get_state_revision() == second_revision
		and not scatter.is_resource_available(3)
		and scatter.is_resource_available(2),
		"An older delayed snapshot cannot roll back a fresher authoritative replacement"
	)


func _find_out_of_range_position(
	scatter: BesprenResourceScatter2D,
	world_map: BesprenWorldMap2D
) -> Vector2:
	var range_squared: float = pow(BesprenResourceScatter2D.GATHER_RANGE, 2.0)
	for row: int in range(BesprenWorldMap2D.GRID_SIZE):
		for column: int in range(BesprenWorldMap2D.GRID_SIZE):
			var candidate: Vector2 = world_map.get_cell_center(Vector2i(column, row))
			if not world_map.is_position_walkable(candidate):
				continue
			var outside_every_resource: bool = true
			for resource_id: int in range(scatter.get_resource_count()):
				if candidate.distance_squared_to(scatter.get_resource_position(resource_id)) <= range_squared:
					outside_every_resource = false
					break
			if outside_every_resource:
				return candidate
	return Vector2.INF


func _signatures_equal(left: PackedStringArray, right: PackedStringArray) -> bool:
	if left.size() != right.size():
		return false
	for index: int in range(left.size()):
		if left[index] != right[index]:
			return false
	return true


func _colors_match(left: Color, right: Color) -> bool:
	return (
		absf(left.r - right.r) <= COLOR_TOLERANCE
		and absf(left.g - right.g) <= COLOR_TOLERANCE
		and absf(left.b - right.b) <= COLOR_TOLERANCE
		and absf(left.a - right.a) <= COLOR_TOLERANCE
	)


func _free_if_valid(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()


func _on_resource_gathered(
	peer_id: int,
	resource_kind: int,
	amount: int,
	resource_id: int,
	_world_position: Vector2
) -> void:
	_gathered_count += 1
	_last_gathered_peer_id = peer_id
	_last_gathered_kind = resource_kind
	_last_gathered_amount = amount
	_last_gathered_resource_id = resource_id


func _on_resource_progressed(
	_peer_id: int,
	_resource_kind: int,
	completed_interactions: int,
	required_interactions: int,
	granted_amount: int,
	_resource_id: int,
	_world_position: Vector2
) -> void:
	_progress_count += 1
	_last_progress_completed = completed_interactions
	_last_progress_required = required_interactions
	_last_progress_grant = granted_amount


func _on_gather_rejected(_peer_id: int, _world_position: Vector2) -> void:
	_rejected_count += 1


func _on_resource_snapshot_applied(state_revision: int) -> void:
	_snapshot_applied_count += 1
	_last_snapshot_revision = state_revision


func _on_resource_snapshot_rejected(_reason: StringName) -> void:
	_snapshot_rejected_count += 1


func _finish() -> void:
	if _failures == 0:
		print("RESOURCE SCATTER VALIDATION OK (%d checks)" % _checks)
		quit(0)
		return
	push_error("RESOURCE SCATTER VALIDATION FAILED (%d/%d checks failed)" % [_failures, _checks])
	quit(1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS | %s" % message)
		return
	_failures += 1
	push_error("FAIL | %s" % message)
