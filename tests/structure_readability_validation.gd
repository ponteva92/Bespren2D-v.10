extends SceneTree
## Focused contract gate for the low-profile tower/trap readability language.
##
## The contact sheet can prove that eight source textures exist; it cannot prove
## that a player can distinguish a rearming ground trap from an armed one at the
## 0.38 gameplay camera.  These checks keep the new language world-space,
## derived only from the existing replicated presentation fields, and bounded to
## a few logical pixels instead of adding a permanent text HUD.

const STRUCTURE_SCRIPT_PATH: String = "res://src/tactical/placed_structure_2d.gd"
const CAMERA_ZOOM: float = 0.38
const MIN_SIGNATURE_RADIUS_PX: float = 6.0
const MAX_SIGNATURE_RADIUS_PX: float = 8.0
const MIN_SIGNATURE_LINE_PX: float = 1.0

var _checks: int = 0
var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	await process_frame
	_validate_catalog_identity_and_default_signatures()
	await _validate_snapshot_readability_states()
	_validate_screen_and_source_budget()
	await process_frame
	_report()


func _validate_catalog_identity_and_default_signatures() -> void:
	var expected_signatures: Dictionary = {
		StructureCatalog.T1_KINETIC: PlacedStructure2D.ReadabilitySignature.TOWER_AIM,
		StructureCatalog.T1_CHEMICAL: PlacedStructure2D.ReadabilitySignature.TOWER_AIM,
		StructureCatalog.T1_ELECTRIC: PlacedStructure2D.ReadabilitySignature.TOWER_AIM,
		StructureCatalog.T1_SUPPORT: PlacedStructure2D.ReadabilitySignature.NONE,
		StructureCatalog.T1_BARRICADE: PlacedStructure2D.ReadabilitySignature.NONE,
		StructureCatalog.T1_LANDMINE: PlacedStructure2D.ReadabilitySignature.LANDMINE,
		StructureCatalog.T1_SLOWING_PIT: PlacedStructure2D.ReadabilitySignature.SLOWING_PIT,
		StructureCatalog.T1_RAZOR_SNARE: PlacedStructure2D.ReadabilitySignature.RAZOR_SNARE,
	}
	var original_ids: Array[StringName] = [
		StructureCatalog.T1_KINETIC,
		StructureCatalog.T1_CHEMICAL,
		StructureCatalog.T1_ELECTRIC,
		StructureCatalog.T1_SUPPORT,
		StructureCatalog.T1_BARRICADE,
		StructureCatalog.T1_LANDMINE,
		StructureCatalog.T1_SLOWING_PIT,
		StructureCatalog.T1_RAZOR_SNARE,
	]
	var definitions: Array[StructureDefinition] = StructureCatalog.get_all()
	_check(
		StructureCatalog.CARD_IDS == original_ids and definitions.size() == original_ids.size(),
		"the eight existing catalog IDs remain unchanged"
	)
	var seen_signatures: Dictionary = {}
	for index: int in range(definitions.size()):
		var definition: StructureDefinition = definitions[index]
		var structure: PlacedStructure2D = _make_client_shell(index + 1, definition)
		var expected_signature: int = int(expected_signatures.get(
			definition.structure_id,
			PlacedStructure2D.ReadabilitySignature.NONE
		))
		_check(
			structure.get_readability_signature() == expected_signature,
			"%s resolves its intended local signature" % definition.display_name
		)
		_check(
			structure.get_visual_texture_path() == definition.visual_texture_path
			and structure.get_structure_visual() != null,
			"%s keeps its catalog-owned visual texture" % definition.display_name
		)
		if definition.has_automatic_attack():
			_check(
				structure.get_readability_state() == PlacedStructure2D.ReadabilityState.READY
				and structure.get_readability_state_name() == &"ready",
				"%s starts armed/ready without a HUD label" % definition.display_name
			)
		else:
			_check(
				structure.get_readability_state() == PlacedStructure2D.ReadabilityState.INERT
				and structure.get_readability_state_name() == &"inert",
				"%s stays visually inert because it has no automatic attack" % definition.display_name
			)
		if definition.is_trap():
			seen_signatures[structure.get_readability_signature()] = true
			_check(
				structure.collision_layer == 0
				and structure.get_node_or_null(NodePath("CollisionShape2D")) == null,
				"%s keeps its nonblocking trap collision contract" % definition.display_name
			)
		structure.queue_free()
	_check(
		seen_signatures.size() == 3,
		"the three traps retain three distinguishable world-space signatures"
	)


func _validate_snapshot_readability_states() -> void:
	var kinetic: StructureDefinition = StructureCatalog.get_definition(StructureCatalog.T1_KINETIC)
	var pit: StructureDefinition = StructureCatalog.get_definition(StructureCatalog.T1_SLOWING_PIT)
	if kinetic == null or pit == null:
		_fail("could not resolve existing catalog definitions for snapshot validation")
		return
	var tower: PlacedStructure2D = _make_client_shell(1001, kinetic)
	_check(
		tower.apply_runtime_snapshot(tower.max_health, 0.0, Vector2.UP, 0.0, 73),
		"a client presentation shell accepts a valid existing runtime snapshot"
	)
	_check(
		tower.get_readability_state() == PlacedStructure2D.ReadabilityState.TRACKING
		and tower.get_readability_state_name() == &"tracking",
		"a locked ready tower reads as tracking"
	)
	_check(
		tower.apply_runtime_snapshot(tower.max_health, 0.0, Vector2.UP, 0.4, 73)
		and tower.get_readability_state() == PlacedStructure2D.ReadabilityState.REARMING,
		"a replicated cooldown takes precedence over a target lock"
	)
	_check(
		tower.apply_runtime_snapshot(tower.max_health, 1.0, Vector2.UP, 0.0, 73)
		and tower.get_readability_state() == PlacedStructure2D.ReadabilityState.DISABLED,
		"an existing EMP snapshot reads as disabled without a new network field"
	)
	tower.queue_free()

	var trap: PlacedStructure2D = _make_client_shell(1002, pit)
	_check(
		trap.apply_runtime_snapshot(trap.max_health, 0.0, Vector2.RIGHT, 0.75, 12)
		and trap.get_readability_state() == PlacedStructure2D.ReadabilityState.REARMING,
		"a reusable trap exposes its replicated rearm cooldown"
	)
	_check(
		trap.apply_runtime_snapshot(0, 0.0, Vector2.RIGHT, 0.0, -1)
		and trap.get_readability_state() == PlacedStructure2D.ReadabilityState.DESTROYED
		and trap.get_readability_signature() == PlacedStructure2D.ReadabilitySignature.NONE,
		"a destroyed trap has no lingering armed signature"
	)
	trap.queue_free()


func _validate_screen_and_source_budget() -> void:
	var radius_px: float = PlacedStructure2D.READABILITY_TRAP_RADIUS * CAMERA_ZOOM
	var line_px: float = PlacedStructure2D.READABILITY_TRAP_LINE_WIDTH * CAMERA_ZOOM
	_check(
		radius_px >= MIN_SIGNATURE_RADIUS_PX and radius_px <= MAX_SIGNATURE_RADIUS_PX,
		"the trap signature radius is %.2f logical pixels at the shipped camera" % radius_px
	)
	_check(
		line_px >= MIN_SIGNATURE_LINE_PX,
		"the trap signature line survives the camera divide at %.2f logical pixels" % line_px
	)
	var source: String = FileAccess.get_file_as_string(STRUCTURE_SCRIPT_PATH)
	_check(
		source.contains("target_changed.connect(_on_combat_target_changed)")
		and source.contains("func _on_combat_target_changed"),
		"the existing target signal redraws only the presentation signature"
	)
	_check(
		not source.contains("Label.new()") and not source.contains("CanvasLayer.new()"),
		"readiness stays in the world and adds no persistent HUD node"
	)
	_check(
		not source.contains("@rpc") and not source.contains("rpc_id("),
		"the readability layer adds no authority or RPC pathway"
	)


func _make_client_shell(instance_id: int, definition: StructureDefinition) -> PlacedStructure2D:
	var structure: PlacedStructure2D = PlacedStructure2D.new()
	structure.configure(
		instance_id,
		definition,
		2,
		Vector2(float(instance_id) * 128.0, 0.0),
		false
	)
	root.add_child(structure)
	return structure


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _fail(message: String) -> void:
	_checks += 1
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print("STRUCTURE READABILITY OK (%d checks)" % _checks)
		quit(0)
		return
	for failure: String in _failures:
		print("FAIL: %s" % failure)
	print("STRUCTURE READABILITY FAILED (%d of %d checks)" % [_failures.size(), _checks])
	quit(1)
