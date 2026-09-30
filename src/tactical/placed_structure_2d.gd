class_name PlacedStructure2D
extends StaticBody2D
## Authoritative defense shell with category-driven collision, combat, and mobile-readable VFX.

signal damaged(structure: PlacedStructure2D, amount: int)
signal depleted(structure: PlacedStructure2D)
signal consumed(structure: PlacedStructure2D)
signal runtime_state_changed(structure: PlacedStructure2D)
signal combat_fired(
	structure: PlacedStructure2D,
	aim_direction: Vector2,
	attack_kind: int,
	target_positions: PackedVector2Array
)

const GRID_SIZE: float = 64.0
const WORLD_STATIC_LAYER: int = 2
const SECURITY_LIGHT_TEXTURE: Texture2D = preload(
	"res://assets/2d/effects/radial_light_neutral.svg"
)
const SLEEK_SPRITE_SHADER: Shader = preload("res://shaders/sleek_sprite_finish.gdshader")
const KINETIC_TEXTURE: Texture2D = preload("res://assets/2d/structures/structure_t1_kinetic.png")
const ATTACK_TRACE_SECONDS: float = 0.45

## A small world-space signature is the only persistent readiness language for
## defenses.  The signature deliberately occupies less than a third of a 64px
## build cell: it must survive the shipped 0.38 camera without becoming a
## second HUD above every placed object.
enum ReadabilityState {
	INERT,
	READY,
	TRACKING,
	REARMING,
	DISABLED,
	DESTROYED,
}

enum ReadabilitySignature {
	NONE,
	TOWER_AIM,
	LANDMINE,
	SLOWING_PIT,
	RAZOR_SNARE,
}

const READABILITY_EPSILON: float = 0.0001
const READABILITY_READY_ALPHA: float = 0.68
const READABILITY_TRACKING_ALPHA: float = 0.96
const READABILITY_REARMING_ALPHA: float = 0.42
const READABILITY_DISABLED_ALPHA: float = 0.82
const READABILITY_TOWER_IDLE_LENGTH: float = 15.0
const READABILITY_TOWER_LOCK_LENGTH: float = 24.0
const READABILITY_TOWER_LINE_WIDTH: float = 2.7
const READABILITY_TRAP_RADIUS: float = 18.0
const READABILITY_TRAP_LINE_WIDTH: float = 3.0

## Health readout geometry. CLAUDE.md 7 makes [HealthBar2D] the one drawn bar
## shared by the survivors, the Base Core and the horde, and this file used to
## draw its own: a flat three-unit rect in a hardcoded #72b49a with no outline,
## no chip drain, no threat band and no critical cadence, so a defense reported
## its state in a language nothing else on screen spoke. Measured off
## `artifacts/structure_visual_gameplay_scale.png` at the shipped 0.38 zoom it
## also out-shouted the thing it described - 1.55x to 4.33x the mean luma of its
## own structure, worst on Electric at 150.2 against a body at 34.7 - and it was
## drawn unconditionally, so every untouched tower carried a permanent bright
## mint block. That is the same defect CLAUDE.md 7 records for the Base bar,
## committed a second time in a second file. The width is 70 percent of the
## footprint, the proportion section 7 derives for the refuge bar against the
## camp's own alpha bounds.
const HEALTH_BAR_WIDTH_RATIO: float = 0.7
const HEALTH_BAR_MAX_WIDTH: float = 84.0
const HEALTH_BAR_HEIGHT: float = 6.0
## Two ticks, like a survivor. Four is the Base Core's, and a defense is not the
## objective.
const HEALTH_BAR_SEGMENTS: int = 2
## Clear of the footprint's lower edge, where the contact ellipse is faintest.
const HEALTH_BAR_GAP: float = 6.0
const HEALTH_BAR_Z: int = 1

var instance_id: int = 0
var owner_peer_id: int = 0
var structure_id: StringName = &""
var invested_cost: PackedInt32Array = PackedInt32Array([0, 0, 0])
var current_health: int = 1
var max_health: int = 1
var accent: Color = Color.WHITE
var footprint_cells: Vector2i = Vector2i.ONE
var _security_light: PointLight2D
var _structure_visual: Sprite2D
var _health_bar: HealthBar2D
var _definition: StructureDefinition
var _combat_controller: TowerTargetingController2D
var _authority_enabled: bool = true
var _night_lighting_enabled: bool = false
var _emp_remaining: float = 0.0
var _range_visualization_visible: bool = false
var _combat_aim_direction: Vector2 = Vector2.RIGHT
var _snapshot_cooldown_remaining: float = 0.0
var _snapshot_target_id: int = -1
var _attack_trace_remaining: float = 0.0
var _attack_trace_kind: int = TowerCombatProfile.AttackKind.NONE
var _attack_trace_targets: PackedVector2Array = PackedVector2Array()


func configure(
	new_instance_id: int,
	definition: StructureDefinition,
	new_owner_peer_id: int,
	world_position: Vector2,
	authority_enabled: bool = true
) -> void:
	_definition = definition
	_authority_enabled = authority_enabled
	instance_id = new_instance_id
	owner_peer_id = new_owner_peer_id
	structure_id = definition.structure_id
	invested_cost = definition.get_cost_copy()
	max_health = definition.max_health
	current_health = max_health
	accent = definition.accent
	footprint_cells = definition.footprint_cells
	name = "Structure_%04d_%s" % [instance_id, structure_id]
	global_position = world_position
	collision_layer = WORLD_STATIC_LAYER if definition.blocks_navigation else 0
	collision_mask = 0
	if definition.blocks_navigation:
		_build_collision()
	_build_structure_visual()
	_build_security_light()
	_build_health_bar()
	add_to_group(&"tower_security_lights")
	set_process(true)
	queue_redraw()


func get_invested_cost() -> PackedInt32Array:
	return invested_cost.duplicate()


func blocks_navigation() -> bool:
	return _definition != null and _definition.blocks_navigation


func is_authority_enabled() -> bool:
	return _authority_enabled


func configure_combat_runtime(
	flow_field: FlowFieldNavigation2D,
	authority_enabled: bool
) -> void:
	if (
		not authority_enabled
		or _definition == null
		or not _definition.has_automatic_attack()
		or is_instance_valid(_combat_controller)
	):
		return
	_combat_controller = TowerTargetingController2D.new()
	_combat_controller.name = &"TowerTargeting"
	_combat_controller.configure(self, _definition.combat_profile, flow_field, true)
	_combat_controller.aim_direction_changed.connect(_on_combat_aim_direction_changed)
	_combat_controller.target_changed.connect(_on_combat_target_changed)
	_combat_controller.attack_executed.connect(_on_combat_attack_executed)
	_combat_controller.consume_requested.connect(_on_combat_consume_requested)
	add_child(_combat_controller)


func stop_tower_combat() -> void:
	if is_instance_valid(_combat_controller):
		_combat_controller.shutdown()


func get_tower_combat_controller() -> TowerTargetingController2D:
	return _combat_controller if is_instance_valid(_combat_controller) else null


func get_combat_cooldown_remaining() -> float:
	if is_instance_valid(_combat_controller):
		return _combat_controller.get_cooldown_remaining()
	return _snapshot_cooldown_remaining


func get_combat_target_id() -> int:
	if is_instance_valid(_combat_controller):
		return _combat_controller.get_current_target_id()
	return _snapshot_target_id


func get_combat_aim_direction() -> Vector2:
	return _combat_aim_direction


func has_automatic_attack() -> bool:
	return _definition != null and _definition.has_automatic_attack()


func get_effective_range() -> float:
	return _definition.get_effective_range() if _definition != null else 0.0


func get_range_visualization_radius() -> float:
	return _definition.get_range_visualization_radius() if _definition != null else 0.0


func get_impact_radius() -> float:
	return _definition.get_impact_radius() if _definition != null else 0.0


func has_distinct_impact_radius() -> bool:
	return _definition != null and _definition.has_distinct_impact_radius()


func is_consumed_on_attack() -> bool:
	return (
		_definition != null
		and _definition.combat_profile != null
		and _definition.combat_profile.consumed_on_attack
	)


func set_range_visualization_visible(visible: bool) -> void:
	var should_show: bool = visible and get_range_visualization_radius() > 0.0
	if _range_visualization_visible == should_show:
		return
	_range_visualization_visible = should_show
	queue_redraw()


func is_range_visualization_visible() -> bool:
	return _range_visualization_visible


func contains_world_position(world_position: Vector2) -> bool:
	if not world_position.is_finite():
		return false
	var half_size: Vector2 = get_footprint_world_size() * 0.5 + Vector2.ONE * 8.0
	var local_position: Vector2 = world_position - global_position
	return (
		absf(local_position.x) <= half_size.x
		and absf(local_position.y) <= half_size.y
	)


func present_combat_attack(
	aim_direction: Vector2,
	attack_kind: int,
	target_positions: PackedVector2Array
) -> void:
	if aim_direction.is_finite() and aim_direction.length_squared() > 0.0001:
		_combat_aim_direction = aim_direction.normalized()
	_attack_trace_kind = clampi(
		attack_kind,
		TowerCombatProfile.AttackKind.NONE,
		TowerCombatProfile.AttackKind.RAZOR_SNARE
	)
	_attack_trace_targets = target_positions.duplicate()
	_attack_trace_remaining = ATTACK_TRACE_SECONDS
	queue_redraw()


func retire_after_attack_trace() -> void:
	stop_tower_combat()
	collision_layer = 0
	collision_mask = 0
	var retirement_tween: Tween = create_tween()
	retirement_tween.tween_interval(ATTACK_TRACE_SECONDS)
	retirement_tween.finished.connect(queue_free)


func get_footprint_world_size() -> Vector2:
	return Vector2(footprint_cells) * GRID_SIZE


func get_clearance_radius() -> float:
	return get_footprint_world_size().length() * 0.5


func take_damage(amount: int) -> int:
	if not _authority_enabled or amount <= 0 or current_health <= 0:
		return 0
	var applied: int = mini(amount, current_health)
	current_health -= applied
	damaged.emit(self, applied)
	runtime_state_changed.emit(self)
	if current_health == 0:
		stop_tower_combat()
		depleted.emit(self)
	_refresh_health_bar()
	queue_redraw()
	return applied


func set_security_light_enabled(enabled: bool) -> void:
	_night_lighting_enabled = enabled
	_refresh_security_light()


func apply_micro_emp(duration_seconds: float) -> void:
	if not _authority_enabled or not is_finite(duration_seconds) or duration_seconds <= 0.0:
		return
	var previous_remaining: float = _emp_remaining
	_emp_remaining = maxf(_emp_remaining, duration_seconds)
	if is_equal_approx(previous_remaining, _emp_remaining):
		return
	if is_instance_valid(_combat_controller):
		_combat_controller.release_target(&"emp_disabled")
	_refresh_security_light()
	runtime_state_changed.emit(self)
	queue_redraw()


func is_emp_disabled() -> bool:
	return _emp_remaining > 0.0


func get_emp_remaining() -> float:
	return _emp_remaining


func apply_runtime_snapshot(
	health_value: int,
	emp_remaining: float,
	aim_direction: Vector2,
	cooldown_remaining: float,
	target_id: int
) -> bool:
	if (
		_authority_enabled
		or health_value < 0
		or health_value > max_health
		or not is_finite(emp_remaining)
		or emp_remaining < 0.0
		or not aim_direction.is_finite()
		or not is_finite(cooldown_remaining)
		or cooldown_remaining < 0.0
		or target_id < -1
	):
		return false
	current_health = health_value
	_emp_remaining = emp_remaining
	_snapshot_cooldown_remaining = cooldown_remaining
	_snapshot_target_id = target_id
	if aim_direction.length_squared() > 0.0001:
		_combat_aim_direction = aim_direction.normalized()
	_refresh_security_light()
	_refresh_health_bar()
	queue_redraw()
	return true


func has_security_light() -> bool:
	return is_instance_valid(_security_light)


func get_structure_visual() -> Sprite2D:
	return _structure_visual


func get_visual_texture_path() -> String:
	return _definition.visual_texture_path if _definition != null else ""


## Presentation-only state derived from values already replicated for the
## defense shell.  It does not start/stop combat, mutate a cooldown, or change
## collision; it only decides how the existing local drawing should read.
func get_readability_state() -> int:
	if current_health <= 0:
		return ReadabilityState.DESTROYED
	if _definition == null or not _definition.has_automatic_attack():
		return ReadabilityState.INERT
	if is_emp_disabled():
		return ReadabilityState.DISABLED
	if get_combat_cooldown_remaining() > READABILITY_EPSILON:
		return ReadabilityState.REARMING
	if get_combat_target_id() > 0:
		return ReadabilityState.TRACKING
	return ReadabilityState.READY


func get_readability_state_name() -> StringName:
	match get_readability_state():
		ReadabilityState.READY:
			return &"ready"
		ReadabilityState.TRACKING:
			return &"tracking"
		ReadabilityState.REARMING:
			return &"rearming"
		ReadabilityState.DISABLED:
			return &"disabled"
		ReadabilityState.DESTROYED:
			return &"destroyed"
		_:
			return &"inert"


func get_readability_signature() -> int:
	if _definition == null or current_health <= 0:
		return ReadabilitySignature.NONE
	if _definition.is_tower():
		return ReadabilitySignature.TOWER_AIM
	if not _definition.is_trap():
		return ReadabilitySignature.NONE
	match structure_id:
		StructureCatalog.T1_LANDMINE:
			return ReadabilitySignature.LANDMINE
		StructureCatalog.T1_SLOWING_PIT:
			return ReadabilitySignature.SLOWING_PIT
		StructureCatalog.T1_RAZOR_SNARE:
			return ReadabilitySignature.RAZOR_SNARE
		_:
			return ReadabilitySignature.NONE


func _process(delta: float) -> void:
	var should_redraw: bool = false
	if _emp_remaining > 0.0:
		_emp_remaining = maxf(_emp_remaining - maxf(delta, 0.0), 0.0)
		if _emp_remaining <= 0.0:
			_refresh_security_light()
			should_redraw = true
	if _snapshot_cooldown_remaining > 0.0:
		_snapshot_cooldown_remaining = maxf(
			_snapshot_cooldown_remaining - maxf(delta, 0.0),
			0.0
		)
		if _snapshot_cooldown_remaining <= 0.0:
			should_redraw = true
	if _attack_trace_remaining > 0.0:
		_attack_trace_remaining = maxf(_attack_trace_remaining - maxf(delta, 0.0), 0.0)
		should_redraw = true
		if _attack_trace_remaining <= 0.0:
			_attack_trace_targets.clear()
			_attack_trace_kind = TowerCombatProfile.AttackKind.NONE
	if should_redraw:
		queue_redraw()


func _exit_tree() -> void:
	stop_tower_combat()


func _on_combat_aim_direction_changed(direction: Vector2) -> void:
	if not direction.is_finite() or direction.length_squared() <= 0.0001:
		return
	_combat_aim_direction = direction.normalized()
	queue_redraw()


func _on_combat_target_changed(_previous_target_id: int, _current_target_id: int) -> void:
	queue_redraw()


func _on_combat_attack_executed(
	direction: Vector2,
	attack_kind: int,
	target_positions: PackedVector2Array
) -> void:
	present_combat_attack(direction, attack_kind, target_positions)
	combat_fired.emit(self, direction, attack_kind, target_positions)


func _on_combat_consume_requested() -> void:
	consumed.emit(self)


func _build_collision() -> void:
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = get_footprint_world_size() - Vector2.ONE * 8.0
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = &"CollisionShape2D"
	collision.shape = shape
	add_child(collision)


func _build_structure_visual() -> void:
	_structure_visual = Sprite2D.new()
	_structure_visual.name = &"StructureVisual"
	_structure_visual.texture = _texture_for_structure()
	_structure_visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var sleek_material: ShaderMaterial = ShaderMaterial.new()
	sleek_material.shader = SLEEK_SPRITE_SHADER
	sleek_material.set_shader_parameter(&"accent_color", accent.lightened(0.12))
	sleek_material.set_shader_parameter(&"accent_strength", 0.09)
	sleek_material.set_shader_parameter(&"sheen_strength", 0.045)
	sleek_material.set_shader_parameter(&"outline_width", 1.6)
	_structure_visual.material = sleek_material
	_structure_visual.position = Vector2(0.0, -8.0)
	_structure_visual.scale = Vector2.ONE * 0.32
	if structure_id == StructureCatalog.T1_BARRICADE:
		_structure_visual.scale = Vector2.ONE * 0.44
		_structure_visual.position.y = -5.0
	elif (
		structure_id == StructureCatalog.T1_LANDMINE
		or structure_id == StructureCatalog.T1_SLOWING_PIT
		or structure_id == StructureCatalog.T1_RAZOR_SNARE
	):
		_structure_visual.scale = Vector2.ONE * 0.30
		_structure_visual.position.y = 0.0
	add_child(_structure_visual)


func _texture_for_structure() -> Texture2D:
	if _definition != null:
		var configured_texture: Texture2D = _definition.get_visual_texture()
		if configured_texture != null:
			return configured_texture
	return KINETIC_TEXTURE


func _build_security_light() -> void:
	if structure_id == StructureCatalog.T1_BARRICADE or (_definition != null and _definition.is_trap()):
		return
	_security_light = PointLight2D.new()
	_security_light.name = &"SecurityLight"
	_security_light.color = accent.lightened(0.22)
	_security_light.energy = 0.72
	_security_light.texture = SECURITY_LIGHT_TEXTURE
	_security_light.texture_scale = 0.58
	_security_light.enabled = false
	# -20 is the ground floor from CLAUDE.md 16, not a round number. A light
	# that stops at -10 reaches the props and the actors but not the terrain
	# underneath them, so it lights everything except the thing a pool of
	# light is actually made of.
	_security_light.range_z_min = -20
	_security_light.range_z_max = 20
	add_child(_security_light)


func _refresh_security_light() -> void:
	if is_instance_valid(_security_light):
		_security_light.enabled = _night_lighting_enabled and _emp_remaining <= 0.0


## Hidden at full health, which is the survivors' and the horde's contract rather
## than the Base Core's. A defended base is a dozen placed structures and a bar
## over every undamaged one is clutter that hides the one the horde is actually
## chewing through - the same argument [EnemyAgent2D] records for a forty-body
## wave.
func _build_health_bar() -> void:
	var footprint: Vector2 = get_footprint_world_size()
	_health_bar = HealthBar2D.new()
	_health_bar.name = &"HealthBar"
	_health_bar.position = Vector2(0.0, footprint.y * 0.5 + HEALTH_BAR_GAP)
	_health_bar.z_index = HEALTH_BAR_Z
	_health_bar.setup(
		Vector2(
			minf(footprint.x * HEALTH_BAR_WIDTH_RATIO, HEALTH_BAR_MAX_WIDTH),
			HEALTH_BAR_HEIGHT
		),
		HEALTH_BAR_SEGMENTS,
		true
	)
	_health_bar.reset_to(float(current_health) / float(maxi(max_health, 1)))
	add_child(_health_bar)


func _refresh_health_bar() -> void:
	if not is_instance_valid(_health_bar):
		return
	_health_bar.set_active(current_health > 0)
	_health_bar.set_ratio(float(current_health) / float(maxi(max_health, 1)))


func _draw() -> void:
	if _range_visualization_visible:
		var range_radius: float = get_range_visualization_radius()
		if range_radius > 0.0:
			draw_arc(
				Vector2.ZERO,
				range_radius,
				0.0,
				TAU,
				64,
				Color(accent, 0.38),
				1.5,
				true
			)
			draw_circle(Vector2.ZERO, range_radius, Color(accent, 0.045), true)
		if has_distinct_impact_radius():
			var targeting_radius: float = get_effective_range()
			draw_arc(
				Vector2.ZERO,
				targeting_radius,
				0.0,
				TAU,
				40,
				Color("ffe18a"),
				2.0,
				true
			)
	var footprint: Vector2 = get_footprint_world_size()
	var bounds: Rect2 = Rect2(-footprint * 0.5, footprint)
	draw_ellipse_shadow(bounds)
	draw_rect(bounds.grow(-2.0), Color(accent, 0.18), false, 1.0)
	_draw_readability_signature()
	if _attack_trace_remaining > 0.0:
		var trace_alpha: float = clampf(_attack_trace_remaining / ATTACK_TRACE_SECONDS, 0.0, 1.0)
		_draw_attack_presentation(trace_alpha)


func _draw_readability_signature() -> void:
	var signature: int = get_readability_signature()
	var state: int = get_readability_state()
	if signature == ReadabilitySignature.NONE or state == ReadabilityState.DESTROYED:
		return
	var state_color: Color = _get_readability_state_color(state)
	match signature:
		ReadabilitySignature.TOWER_AIM:
			_draw_tower_readability_signature(state, state_color)
		ReadabilitySignature.LANDMINE:
			_draw_landmine_readability_signature(state, state_color)
		ReadabilitySignature.SLOWING_PIT:
			_draw_slowing_pit_readability_signature(state, state_color)
		ReadabilitySignature.RAZOR_SNARE:
			_draw_razor_snare_readability_signature(state, state_color)
	if state == ReadabilityState.DISABLED:
		_draw_disabled_readability_cross()


func _get_readability_state_color(state: int) -> Color:
	var base_color: Color = accent.lightened(0.16)
	match state:
		ReadabilityState.TRACKING:
			return Color(base_color.lightened(0.24), READABILITY_TRACKING_ALPHA)
		ReadabilityState.REARMING:
			var muted: Color = base_color.lerp(Color("80909a"), 0.62)
			return Color(muted, READABILITY_REARMING_ALPHA)
		ReadabilityState.DISABLED:
			return Color("8ca5af", READABILITY_DISABLED_ALPHA)
		_:
			return Color(base_color, READABILITY_READY_ALPHA)


func _draw_tower_readability_signature(state: int, state_color: Color) -> void:
	var aim_start: Vector2 = Vector2(0.0, -6.0)
	var direction: Vector2 = _combat_aim_direction
	if not direction.is_finite() or direction.length_squared() <= READABILITY_EPSILON:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	if state == ReadabilityState.REARMING:
		var rearm_angle: float = direction.angle()
		draw_arc(
			aim_start,
			10.0,
			rearm_angle - 0.92,
			rearm_angle + 0.92,
			10,
			state_color,
			READABILITY_TOWER_LINE_WIDTH,
			true
		)
		return
	var length: float = (
		READABILITY_TOWER_LOCK_LENGTH
		if state == ReadabilityState.TRACKING
		else READABILITY_TOWER_IDLE_LENGTH
	)
	var line_width: float = (
		READABILITY_TOWER_LINE_WIDTH + 0.55
		if state == ReadabilityState.TRACKING
		else READABILITY_TOWER_LINE_WIDTH
	)
	var aim_end: Vector2 = aim_start + direction * length
	draw_line(aim_start, aim_end, state_color, line_width, true)
	if state == ReadabilityState.TRACKING:
		var wing: Vector2 = direction.rotated(2.52) * 5.5
		draw_line(aim_end, aim_end + wing, state_color, line_width, true)
		draw_line(aim_end, aim_end + wing.rotated(1.24), state_color, line_width, true)
	if state == ReadabilityState.DISABLED:
		draw_line(aim_start, aim_start + direction * 9.0, state_color, READABILITY_TOWER_LINE_WIDTH, true)


func _draw_landmine_readability_signature(state: int, state_color: Color) -> void:
	var radius: float = READABILITY_TRAP_RADIUS
	if state == ReadabilityState.REARMING:
		draw_arc(Vector2.ZERO, radius, 0.36, 2.78, 12, state_color, READABILITY_TRAP_LINE_WIDTH, true)
		return
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, state_color, READABILITY_TRAP_LINE_WIDTH, true)
	for angle: float in [0.0, TAU * 0.25, TAU * 0.5, TAU * 0.75]:
		var ray: Vector2 = Vector2.from_angle(angle)
		draw_line(ray * (radius + 2.0), ray * (radius + 6.0), state_color, 2.0, true)


func _draw_slowing_pit_readability_signature(state: int, state_color: Color) -> void:
	var outer_radius: float = READABILITY_TRAP_RADIUS + 2.0
	var inner_radius: float = READABILITY_TRAP_RADIUS - 5.0
	if state == ReadabilityState.REARMING:
		draw_arc(Vector2.ZERO, outer_radius, -2.35, -0.78, 10, state_color, READABILITY_TRAP_LINE_WIDTH, true)
		return
	draw_arc(Vector2.ZERO, outer_radius, -2.45, -0.70, 12, state_color, READABILITY_TRAP_LINE_WIDTH, true)
	draw_arc(Vector2.ZERO, outer_radius, 0.70, 2.45, 12, state_color, READABILITY_TRAP_LINE_WIDTH, true)
	draw_arc(Vector2.ZERO, inner_radius, -0.94, 0.94, 12, state_color, 2.0, true)


func _draw_razor_snare_readability_signature(state: int, state_color: Color) -> void:
	var extent: float = READABILITY_TRAP_RADIUS - 2.0
	if state == ReadabilityState.REARMING:
		draw_line(
			Vector2(-extent, -extent * 0.44),
			Vector2(0.0, 0.0),
			state_color,
			READABILITY_TRAP_LINE_WIDTH,
			true
		)
		return
	draw_line(
		Vector2(-extent, -extent * 0.62),
		Vector2(extent, extent * 0.62),
		state_color,
		READABILITY_TRAP_LINE_WIDTH,
		true
	)
	draw_line(
		Vector2(-extent, extent * 0.62),
		Vector2(extent, -extent * 0.62),
		state_color,
		READABILITY_TRAP_LINE_WIDTH,
		true
	)


func _draw_disabled_readability_cross() -> void:
	var extent: float = READABILITY_TRAP_RADIUS - 1.0
	var disabled_color: Color = Color("d1dbe0", 0.62)
	draw_line(Vector2(-extent, -extent), Vector2(extent, extent), disabled_color, 2.7, true)
	draw_line(Vector2(-extent, extent), Vector2(extent, -extent), disabled_color, 2.7, true)


func _draw_attack_presentation(trace_alpha: float) -> void:
	var progress: float = 1.0 - trace_alpha
	match _attack_trace_kind:
		TowerCombatProfile.AttackKind.CHEMICAL:
			for target_position: Vector2 in _attack_trace_targets:
				if not target_position.is_finite():
					continue
				var local_target: Vector2 = to_local(target_position)
				draw_line(Vector2(0.0, -8.0), local_target, Color("9cce67", trace_alpha * 0.55), 2.0, true)
				draw_circle(local_target, 12.0 + progress * 26.0, Color("b9df68", trace_alpha * 0.72), false, 3.5, true)
		TowerCombatProfile.AttackKind.ELECTRIC:
			for target_position: Vector2 in _attack_trace_targets:
				if target_position.is_finite():
					_draw_electric_arc(to_local(target_position), trace_alpha)
		TowerCombatProfile.AttackKind.LANDMINE:
			draw_circle(Vector2.ZERO, 22.0 + progress * 94.0, Color("ff7b55", trace_alpha * 0.82), false, 5.0, true)
			draw_circle(Vector2.ZERO, 12.0 + progress * 54.0, Color("ffd27a", trace_alpha * 0.32), true)
		TowerCombatProfile.AttackKind.SLOWING_PIT:
			draw_arc(Vector2.ZERO, 38.0 + progress * 34.0, 0.0, TAU, 32, Color("8fb9cf", trace_alpha * 0.74), 3.0, true)
			draw_arc(Vector2.ZERO, 24.0 + progress * 22.0, 0.0, TAU, 24, Color("d8eef2", trace_alpha * 0.52), 2.0, true)
		TowerCombatProfile.AttackKind.RAZOR_SNARE:
			for target_position: Vector2 in _attack_trace_targets:
				if not target_position.is_finite():
					continue
				var local_target: Vector2 = to_local(target_position)
				var slash_extent: float = 14.0 + progress * 12.0
				draw_line(local_target - Vector2.ONE * slash_extent, local_target + Vector2.ONE * slash_extent, Color("ff8ec1", trace_alpha), 5.0, true)
				draw_line(local_target + Vector2(-slash_extent, slash_extent), local_target + Vector2(slash_extent, -slash_extent), Color("f4efe7", trace_alpha), 4.0, true)
				draw_arc(local_target, 18.0 + progress * 10.0, 0.0, TAU, 18, Color(accent, trace_alpha), 3.0, true)
		_:
			for target_position: Vector2 in _attack_trace_targets:
				if not target_position.is_finite():
					continue
				var local_target: Vector2 = to_local(target_position)
				var start: Vector2 = Vector2(0.0, -6.0)
				draw_line(start, local_target, Color("ffd88a", trace_alpha), 8.0, true)
				draw_circle(start.lerp(local_target, progress), 7.0, Color("fff3c2", trace_alpha), true)


func _draw_electric_arc(local_target: Vector2, trace_alpha: float) -> void:
	var start: Vector2 = Vector2(0.0, -6.0)
	var delta: Vector2 = local_target - start
	if delta.length_squared() <= 0.0001:
		return
	var perpendicular: Vector2 = delta.normalized().orthogonal()
	var points: PackedVector2Array = PackedVector2Array([start])
	for segment_index: int in range(1, 6):
		var ratio: float = float(segment_index) / 6.0
		var zigzag: float = 7.0 if segment_index % 2 == 0 else -7.0
		points.append(start.lerp(local_target, ratio) + perpendicular * zigzag)
	points.append(local_target)
	draw_polyline(points, Color("7ce9ff", trace_alpha), 3.2, true)
	draw_polyline(points, Color("e7fbff", trace_alpha * 0.68), 1.2, true)


## [GroundShadow] is the one contact language for everything standing on the
## world floor, and its own docstring names the three divergent implementations
## it replaced. This was a fourth it missed: a single flat disc of near-black at
## a flat 0.42, 84 percent of the footprint wide, which is precisely the "flat
## disc at any single opacity" that class exists to retire. Measured at the
## shipped zoom it removed 33 percent of the ground's value under a hard circular
## edge, so a tower read as an object sitting in a hole rather than on a floor.
## The ladder replaces it at [constant GroundShadow.PROP_STRENGTH], which lands
## the core at 0.248 with a wide faint halo above it, and the depth is capped by
## [constant GroundShadow.MAX_CONTACT_DEPTH] so a wide shell gets the shallow
## footprint a three-quarter top-down camera actually sees.
func draw_ellipse_shadow(bounds: Rect2) -> void:
	GroundShadow.draw_ellipse(
		self,
		Vector2(0.0, bounds.size.y * 0.16),
		Vector2(
			bounds.size.x * 0.42,
			minf(bounds.size.y * 0.42, GroundShadow.MAX_CONTACT_DEPTH)
		),
		GroundShadow.PROP_STRENGTH
	)
