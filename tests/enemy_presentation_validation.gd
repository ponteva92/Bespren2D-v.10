extends SceneTree
## Typed catalog, runtime presentation, authority, and movement-status regression gate.

const EXPECTED_SIMULATION_NAMES: Array[StringName] = [
	&"walker",
	&"rat_swarm",
	&"static_walker",
	&"scrap_shield",
	&"goliath",
	&"carrier",
	&"splitter",
	&"overlord",
]
const HOST_ORIGIN: Vector2 = Vector2(1800.0, 1800.0)
const EnemyDeathPresentationView: Script = preload(
	"res://src/visual/enemy_death_presentation_2d.gd"
)

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_validate_stable_variant_ids()
	_validate_typed_catalog()
	var actors_root: Node2D = Node2D.new()
	actors_root.name = &"EnemyPresentationValidationActors"
	root.add_child(actors_root)
	var host_enemies: Array[EnemyAgent2D] = await _spawn_all_host_variants(actors_root)
	_validate_runtime_presentations(host_enemies)
	await _validate_boss_body_silhouette_sync(host_enemies)
	_validate_readability_marker_hierarchy(host_enemies)
	await _validate_host_presentation_events(actors_root, host_enemies[EnemyAgent2D.Variant.WALKER])
	await _validate_host_movement_status(host_enemies[EnemyAgent2D.Variant.WALKER])
	await _validate_client_snapshot_status(actors_root)
	await _validate_death_presentation_lifecycle(actors_root)
	_validate_horde_snapshot_schema()
	actors_root.queue_free()
	await process_frame
	await process_frame
	_finish()


func _validate_stable_variant_ids() -> void:
	_check(
		EnemyAgent2D.Variant.WALKER == 0
		and EnemyAgent2D.Variant.RAT_SWARM == 1
		and EnemyAgent2D.Variant.STATIC_WALKER == 2
		and EnemyAgent2D.Variant.SCRAP_SHIELD == 3
		and EnemyAgent2D.Variant.GOLIATH == 4
		and EnemyAgent2D.Variant.CARRIER == 5
		and EnemyAgent2D.Variant.SPLITTER == 6
		and EnemyAgent2D.Variant.OVERLORD == 7,
		"All eight simulation variant integer IDs remain stable"
	)


func _validate_typed_catalog() -> void:
	var definitions: Array[EnemyPresentationDefinition] = EnemyPresentationCatalog.get_all()
	var catalog_errors: PackedStringArray = EnemyPresentationCatalog.get_catalog_errors()
	_check(
		definitions.size() == EnemyPresentationCatalog.VARIANT_COUNT
		and definitions.size() == EXPECTED_SIMULATION_NAMES.size(),
		"Typed presentation catalog has exactly eight entries"
	)
	_check(catalog_errors.is_empty(), "Every typed catalog entry passes structural validation")
	var presentation_ids: Dictionary[StringName, bool] = {}
	var silhouette_tags: Dictionary[StringName, bool] = {}
	var marker_kinds: Dictionary[int, bool] = {}
	var accent_colors: Dictionary[int, bool] = {}
	var scene_paths: Dictionary[String, bool] = {}
	var identities_valid: bool = true
	var bosses_valid: bool = true
	for variant_id: int in range(definitions.size()):
		var definition: EnemyPresentationDefinition = definitions[variant_id]
		identities_valid = identities_valid and (
			definition.variant_id == variant_id
			and definition.simulation_name == StringName(EXPECTED_SIMULATION_NAMES[variant_id])
			and EnemyPresentationCatalog.get_definition(variant_id) == definition
		)
		bosses_valid = bosses_valid and definition.boss_presentation == (variant_id >= 4)
		presentation_ids[definition.presentation_id] = true
		silhouette_tags[definition.silhouette_tag] = true
		marker_kinds[int(definition.marker_kind)] = true
		accent_colors[int(definition.accent_color.to_rgba32())] = true
		scene_paths[definition.visual_scene.resource_path] = true
	_check(identities_valid, "Catalog preserves every simulation name and one-to-one variant mapping")
	_check(bosses_valid, "Boss presentation flags match the unchanged gameplay boss boundary")
	_check(presentation_ids.size() == 8, "Every gameplay variant has a unique presentation ID")
	_check(silhouette_tags.size() == 8, "Every gameplay variant has a unique silhouette contract")
	_check(marker_kinds.size() == 8, "Every gameplay variant has a unique silhouette marker kind")
	_check(accent_colors.size() == 8, "Redundant accent colors distinguish all eight variants")
	_check(scene_paths.size() == 8, "Every variant resolves to a distinct local visual scene")
	var crawler_pack: EnemyPresentationDefinition = definitions[EnemyAgent2D.Variant.RAT_SWARM]
	_check(
		crawler_pack.visual_scene.resource_path.ends_with("enemy_rat_swarm.tscn")
		and crawler_pack.copy_offsets.size() == 3,
		"RAT_SWARM uses the baked crawler actor as a three-crawler pack"
	)
	var scales_uniform: bool = true
	var offsets_zero: bool = true
	for definition: EnemyPresentationDefinition in definitions:
		scales_uniform = scales_uniform and definition.visual_scale == EnemyPresentationCatalog.ACTOR_SCALE
		offsets_zero = offsets_zero and definition.visual_offset == Vector2.ZERO
	_check(
		scales_uniform and offsets_zero,
		"One bake sizes the roster: uniform runtime scale and no per-variant pivot nudge"
	)
	_check(
		EnemyPresentationCatalog.get_definition(-1) == null
		and EnemyPresentationCatalog.get_definition(8) == null,
		"Out-of-range presentation lookups fail safely"
	)


func _spawn_all_host_variants(parent: Node2D) -> Array[EnemyAgent2D]:
	var result: Array[EnemyAgent2D] = []
	for variant_id: int in range(EnemyPresentationCatalog.VARIANT_COUNT):
		var enemy: EnemyAgent2D = EnemyAgent2D.new()
		var spawn_position: Vector2 = HOST_ORIGIN + Vector2(float(variant_id) * 96.0, 0.0)
		enemy.configure(
			100 + variant_id,
			variant_id,
			spawn_position,
			120,
			12,
			100.0,
			spawn_position,
			null,
			null,
			true
		)
		parent.add_child(enemy)
		result.append(enemy)
	await physics_frame
	await process_frame
	return result


func _validate_runtime_presentations(enemies: Array[EnemyAgent2D]) -> void:
	var runtime_valid: bool = enemies.size() == EnemyPresentationCatalog.VARIANT_COUNT
	var collision_valid: bool = runtime_valid
	var visual_copy_contract_valid: bool = runtime_valid
	var allocation_contract_valid: bool = runtime_valid
	var moving_animation_valid: bool = runtime_valid
	var facing_valid: bool = runtime_valid
	var action_inventory_valid: bool = runtime_valid
	var spawn_token_valid: bool = runtime_valid
	var flash_saturation_valid: bool = runtime_valid
	var body_silhouette_contract_valid: bool = runtime_valid
	for variant_id: int in range(enemies.size()):
		var enemy: EnemyAgent2D = enemies[variant_id]
		var definition: EnemyPresentationDefinition = enemy.get_presentation_definition()
		var view: EnemyPresentation2D = enemy.get_presentation_view()
		runtime_valid = runtime_valid and (
			is_instance_valid(enemy)
			and enemy.variant == variant_id
			and definition != null
			and definition.variant_id == variant_id
			and view != null
			and view.get_definition() == definition
			and view.has_loaded_visual()
		)
		collision_valid = collision_valid and (
			enemy.collision_layer == EnemyAgent2D.ENEMY_LAYER
			and enemy.collision_mask == EnemyAgent2D.WORLD_AND_PLAYER_MASK
		)
		var expected_copy_count: int = 3 if variant_id == EnemyAgent2D.Variant.RAT_SWARM else 1
		visual_copy_contract_valid = visual_copy_contract_valid and (
			view.get_visual_copy_count() == expected_copy_count
		)
		allocation_contract_valid = allocation_contract_valid and (
			view.find_children("*", "PointLight2D", true, false).is_empty()
			and view.find_children("*", "GPUParticles2D", true, false).is_empty()
			and view.find_children("*", "CPUParticles2D", true, false).is_empty()
		)
		var expected_body_silhouette_count: int = 1 if definition.boss_presentation else 0
		body_silhouette_contract_valid = body_silhouette_contract_valid and (
			view.get_body_silhouette_copy_count() == expected_body_silhouette_count
			and view.has_body_silhouette_layer() == definition.boss_presentation
			and view.body_silhouette_uses_primary_frames()
			and view.is_body_silhouette_synchronized()
		)
		var required_action_clips: Array[StringName] = [
			&"spawn", &"attack", &"hit", &"death",
		]
		if definition.boss_presentation:
			required_action_clips.append(&"taunt")
		for action_clip: StringName in required_action_clips:
			action_inventory_valid = action_inventory_valid and view.has_directional_clip(action_clip)
		# The hit flash is one multiplier applied to whatever tint the variant
		# was authored with, so a variant darkened later would quietly stop
		# saturating and lose the cue entirely rather than fail anywhere. The
		# invariant is that the *darkest* channel on the roster still clears
		# 1.0 once boosted, which is what makes the flash a white-out on all
		# eight rather than a recolour on some of them.
		var tint: Color = definition.body_tint
		var darkest: float = minf(minf(tint.r, tint.g), tint.b)
		flash_saturation_valid = flash_saturation_valid and (
			darkest * EnemyPresentation2D.HIT_FLASH_BOOST > 1.0
		)
		spawn_token_valid = spawn_token_valid and (
			EnemyPresentation2D.get_token_event(enemy.get_presentation_token())
			== EnemyPresentation2D.PresentationEvent.SPAWN
			and EnemyPresentation2D.get_token_facing_row(enemy.get_presentation_token())
			== ActorFacing.CAMERA_FACING_ROW
			and enemy.get_presentation_revision() == 1
		)
		view.play_local_event(EnemyPresentation2D.PresentationEvent.NONE)
		view.update_motion(1.0 / 60.0, true, 1.0)
		# The whole roster now comes from one baked actor family, so every
		# variant - not only the two that used to be animated - has to reach its
		# move clip, and reach it through the eight-row directional naming.
		moving_animation_valid = moving_animation_valid and (
			view.get_animated_sprite_count() >= expected_copy_count
			and view.uses_directional_frames()
			and view.get_active_animation() == ActorFacing.animation_name(
				definition.move_animation, view.get_facing_row()
			)
		)
		# Turning has to change the row while the actor keeps walking. A
		# presentation that answered a new heading by restarting the same row
		# would pass every check above and still face the wrong way on screen.
		view.set_facing_direction(Vector2.DOWN)
		var camera_row: int = view.get_facing_row()
		var camera_animation: StringName = view.get_active_animation()
		view.set_facing_direction(Vector2.UP)
		facing_valid = facing_valid and (
			camera_row == ActorFacing.CAMERA_FACING_ROW
			and camera_animation == ActorFacing.animation_name(definition.move_animation, camera_row)
			and view.get_facing_row() != camera_row
			and view.get_active_animation() == ActorFacing.animation_name(
				definition.move_animation, view.get_facing_row()
			)
		)
	_check(runtime_valid, "All eight EnemyAgent2D variants instantiate their typed runtime presentation")
	_check(collision_valid, "Presentation changes preserve the shared host enemy collision contract")
	_check(visual_copy_contract_valid, "Runtime visual-copy counts preserve seven singles and one crawler pack")
	_check(
		allocation_contract_valid,
		"Enemy presentations contain no per-enemy lights or particle emitters"
	)
	_check(
		body_silhouette_contract_valid,
		"Boss-only body-shaped silhouette layers reuse the foreground frames without adding marker, light, or particle nodes"
	)
	_check(moving_animation_valid, "Every variant enters the directional form of its own move clip")
	_check(facing_valid, "Eight-way facing selects the baked row that matches the heading")
	_check(action_inventory_valid, "Every horde sheet exposes its full directional event inventory and every boss adds taunt")
	_check(spawn_token_valid, "Every host enemy begins with one authoritative spawn presentation token")
	_check(
		flash_saturation_valid,
		"Every variant's darkest body channel still clamps to white under the hit flash"
	)


func _validate_boss_body_silhouette_sync(enemies: Array[EnemyAgent2D]) -> void:
	var initial_contract_valid: bool = true
	var action_contract_valid: bool = true
	for variant_id: int in range(enemies.size()):
		var enemy: EnemyAgent2D = enemies[variant_id]
		var definition: EnemyPresentationDefinition = enemy.get_presentation_definition()
		var view: EnemyPresentation2D = enemy.get_presentation_view()
		if definition == null or view == null or not definition.boss_presentation:
			continue
		view.play_local_event(EnemyPresentation2D.PresentationEvent.NONE)
		view.update_motion(0.0, false, 1.0)
		await process_frame
		initial_contract_valid = initial_contract_valid and (
			view.get_body_silhouette_copy_count() == 1
			and view.body_silhouette_uses_primary_frames()
			and view.is_body_silhouette_synchronized()
		)
		action_contract_valid = action_contract_valid and view.play_local_event(
			EnemyPresentation2D.PresentationEvent.TAUNT,
			(variant_id + 3) % ActorFacing.ROW_COUNT
		)
		await create_timer(0.14).timeout
		action_contract_valid = action_contract_valid and (
			view.get_active_presentation_event() == EnemyPresentation2D.PresentationEvent.TAUNT
			and view.body_silhouette_uses_primary_frames()
			and view.is_body_silhouette_synchronized()
		)
		view.play_local_event(EnemyPresentation2D.PresentationEvent.NONE)
	_check(
		initial_contract_valid,
		"Every boss starts with one body-shaped outline using its own foreground SpriteFrames"
	)
	_check(
		action_contract_valid,
		"Boss silhouette underlays remain frame-synchronised through their authoritative taunt clip"
	)


func _validate_readability_marker_hierarchy(enemies: Array[EnemyAgent2D]) -> void:
	var walker: EnemyPresentation2D = enemies[EnemyAgent2D.Variant.WALKER].get_presentation_view()
	var boss: EnemyPresentation2D = enemies[EnemyAgent2D.Variant.GOLIATH].get_presentation_view()
	walker.play_local_event(EnemyPresentation2D.PresentationEvent.NONE)
	boss.play_local_event(EnemyPresentation2D.PresentationEvent.NONE)
	walker.update_motion(0.0, false, 1.0)
	boss.update_motion(0.0, false, 1.0)
	_check(
		walker.get_readability_marker_state() == EnemyPresentation2D.ReadabilityMarkerState.HIDDEN,
		"Ordinary enemy idle marker is hidden outside a gameplay cue"
	)
	walker.update_motion(0.0, true, 1.0)
	_check(
		walker.get_readability_marker_state() == EnemyPresentation2D.ReadabilityMarkerState.HIDDEN,
		"Ordinary enemy movement marker stays hidden outside a gameplay cue"
	)
	_check(
		boss.get_readability_marker_state() == EnemyPresentation2D.ReadabilityMarkerState.BOSS_IDLE
		and is_equal_approx(
			boss.get_readability_marker_alpha_multiplier(),
			EnemyPresentation2D.BOSS_IDLE_MARKER_ALPHA_MULTIPLIER
		),
		"Boss idle retains only the specified subdued 55 percent marker cue"
	)
	boss.update_motion(0.0, true, 1.0)
	_check(
		boss.get_readability_marker_state() == EnemyPresentation2D.ReadabilityMarkerState.HIDDEN,
		"Boss movement does not retain the idle marker"
	)
	_check(
		walker.play_local_event(EnemyPresentation2D.PresentationEvent.ATTACK)
		and walker.get_readability_marker_state()
		== EnemyPresentation2D.ReadabilityMarkerState.ACTIVE_CUE
		and is_equal_approx(walker.get_readability_marker_alpha_multiplier(), 1.0),
		"An active one-shot restores full marker readability"
	)
	walker.play_local_event(EnemyPresentation2D.PresentationEvent.NONE)
	_check(
		walker.get_readability_marker_state() == EnemyPresentation2D.ReadabilityMarkerState.HIDDEN,
		"Clearing a one-shot returns an ordinary moving enemy to the hidden marker state"
	)
	walker.update_motion(0.0, true, 0.62)
	_check(
		walker.get_readability_marker_state() == EnemyPresentation2D.ReadabilityMarkerState.ACTIVE_CUE,
		"Slow status preserves the full readability marker state"
	)
	walker.update_motion(0.0, true, 0.0)
	_check(
		walker.get_readability_marker_state() == EnemyPresentation2D.ReadabilityMarkerState.ACTIVE_CUE,
		"Root status preserves the full readability marker state"
	)
	walker.update_motion(0.0, true, 1.0)


func _validate_host_presentation_events(parent: Node2D, enemy: EnemyAgent2D) -> void:
	var view: EnemyPresentation2D = enemy.get_presentation_view()
	var revision_before_hit: int = enemy.get_presentation_revision()
	var health_before_hit: int = enemy.current_health
	var applied_hit: int = enemy.take_damage(1)
	_check(
		applied_hit == 1
		and enemy.current_health == health_before_hit - 1
		and enemy.get_presentation_revision() == revision_before_hit + 1
		and EnemyPresentation2D.get_token_event(enemy.get_presentation_token())
		== EnemyPresentation2D.PresentationEvent.HIT
		and view.get_active_presentation_event() == EnemyPresentation2D.PresentationEvent.HIT,
		"Host damage commit advances one visual-only hit token without changing enemy collision"
	)
	view.update_motion(0.0, true, 0.0)
	_check(
		is_equal_approx(view.get_primary_animation_speed_scale(), enemy.get_presentation_definition().animation_speed_scale),
		"Root and slow status never freeze an in-flight baked hit one-shot"
	)
	# The flash is the only acknowledgement a body too heavy to stagger gives,
	# so it has to survive the same rooted, fully slowed state the check above
	# covers, and then clear itself back to the authored tint exactly.
	var body_tint: Color = enemy.get_presentation_definition().body_tint
	var lit: Color = _first_visual_copy_modulate(view)
	_check(
		lit.r >= body_tint.r and lit.g >= body_tint.g and lit.b >= body_tint.b
		and is_equal_approx(lit.a, body_tint.a),
		"A struck body brightens on every channel while keeping its authored alpha"
	)
	# Past 1.0, not merely toward white: modulate multiplies, so a value inside
	# the texture's own range would recolour the enemy rather than blow it out.
	_check(
		maxf(maxf(lit.r, lit.g), lit.b) > 1.0,
		"The hit flash drives a channel past 1.0 so lit surfaces clamp to white"
	)
	view.update_motion(EnemyPresentation2D.HIT_FLASH_SECONDS * 1.5, true, 0.0)
	_check(
		_first_visual_copy_modulate(view).is_equal_approx(body_tint),
		"An expired hit flash restores the exact authored body tint"
	)

	var combat_state: CombatStateCoordinator = CombatStateCoordinator.new()
	combat_state.name = &"EnemyPresentationCombatState"
	parent.add_child(combat_state)
	var attacker: EnemyAgent2D = EnemyAgent2D.new()
	attacker.configure(
		901,
		EnemyAgent2D.Variant.WALKER,
		HOST_ORIGIN + Vector2(0.0, 430.0),
		100,
		9,
		80.0,
		HOST_ORIGIN + Vector2(0.0, 430.0),
		null,
		combat_state,
		true
	)
	parent.add_child(attacker)
	await physics_frame
	var base_health_before_attack: int = combat_state.get_base_health()
	attacker._try_attack(false)
	_check(
		combat_state.get_base_health() < base_health_before_attack
		and EnemyPresentation2D.get_token_event(attacker.get_presentation_token())
		== EnemyPresentation2D.PresentationEvent.ATTACK
		and attacker.get_presentation_view().get_active_presentation_event()
		== EnemyPresentation2D.PresentationEvent.ATTACK,
		"Only an applied host combat commit publishes the baked attack event"
	)

	var boss: EnemyAgent2D = EnemyAgent2D.new()
	boss.configure(
		902,
		EnemyAgent2D.Variant.GOLIATH,
		HOST_ORIGIN + Vector2(0.0, 650.0),
		500,
		24,
		72.0,
		HOST_ORIGIN + Vector2(0.0, 650.0),
		null,
		null,
		true
	)
	parent.add_child(boss)
	await physics_frame
	boss._advance_boss_taunt(EnemyAgent2D.BOSS_TAUNT_DELAY_SECONDS + 0.01)
	_check(
		EnemyPresentation2D.get_token_event(boss.get_presentation_token())
		== EnemyPresentation2D.PresentationEvent.TAUNT
		and boss.get_presentation_view().get_active_presentation_event()
		== EnemyPresentation2D.PresentationEvent.TAUNT,
		"Boss entrance receives its one authoritative taunt beat after spawn"
	)
	attacker.queue_free()
	boss.queue_free()
	combat_state.queue_free()
	await process_frame


func _validate_host_movement_status(enemy: EnemyAgent2D) -> void:
	var view: EnemyPresentation2D = enemy.get_presentation_view()
	_check(
		enemy.apply_movement_slow(0.62, 0.20)
		and is_equal_approx(enemy.get_movement_speed_multiplier(), 0.62)
		and is_equal_approx(enemy.get_effective_movement_speed(), enemy.movement_speed * 0.62),
		"Host authority applies Slowing Pit speed to effective movement"
	)
	_check(
		not enemy.apply_movement_slow(0.80, 0.40)
		and is_equal_approx(enemy.get_movement_speed_multiplier(), 0.62),
		"A weaker slow cannot replace an active stronger host status"
	)
	_check(
		enemy.apply_movement_slow(0.0, 0.05)
		and is_zero_approx(enemy.get_movement_speed_multiplier())
		and is_zero_approx(view.get_movement_status_multiplier()),
		"Razor Snare root overrides slow and updates typed status presentation"
	)
	for _frame_index: int in range(8):
		await physics_frame
	_check(
		is_equal_approx(enemy.get_movement_speed_multiplier(), 1.0)
		and is_equal_approx(enemy.get_effective_movement_speed(), enemy.movement_speed),
		"Timed movement status expires back to the unmodified simulation speed"
	)


func _validate_client_snapshot_status(parent: Node2D) -> void:
	var client_enemy: EnemyAgent2D = EnemyAgent2D.new()
	client_enemy.configure(
		777,
		EnemyAgent2D.Variant.STATIC_WALKER,
		HOST_ORIGIN + Vector2(0.0, 220.0),
		100,
		10,
		90.0,
		HOST_ORIGIN,
		null,
		null,
		false
	)
	parent.add_child(client_enemy)
	await physics_frame
	_check(
		not client_enemy.apply_movement_slow(0.62, 1.0),
		"A presentation-only client cannot author movement status"
	)
	var horde: HordeDirector = HordeDirector.new()
	parent.add_child(horde)
	horde._enemies[client_enemy.enemy_id] = client_enemy
	horde._receive_enemy_positions(
		PackedInt32Array([client_enemy.enemy_id]),
		PackedVector2Array([client_enemy.global_position + Vector2(24.0, 0.0)]),
		PackedInt32Array([75]),
		PackedFloat32Array([0.62]),
		PackedByteArray([4]),
		PackedInt32Array([
			EnemyPresentation2D.pack_presentation_token(
				2,
				4,
				EnemyPresentation2D.PresentationEvent.HIT
			),
		])
	)
	_check(
		is_equal_approx(client_enemy.get_movement_speed_multiplier(), 0.62)
		and is_equal_approx(
			client_enemy.get_presentation_view().get_movement_status_multiplier(),
			0.62
		)
		and client_enemy.get_presentation_view().get_facing_row() == 4
		and client_enemy.get_presentation_view().get_active_presentation_event()
		== EnemyPresentation2D.PresentationEvent.HIT,
		"Ordered Horde snapshot mirrors host slow, facing, and one-shot event into client presentation"
	)
	horde._receive_enemy_positions(
		PackedInt32Array([client_enemy.enemy_id]),
		PackedVector2Array(),
		PackedInt32Array([25]),
		PackedFloat32Array([0.0]),
		PackedByteArray(),
		PackedInt32Array()
	)
	_check(
		is_equal_approx(client_enemy.get_movement_speed_multiplier(), 0.62)
		and client_enemy.current_health == 75,
		"Malformed ordered snapshots are rejected atomically"
	)
	var active_event_before_stale: int = client_enemy.get_presentation_view().get_active_presentation_event()
	horde._receive_enemy_positions(
		PackedInt32Array([client_enemy.enemy_id]),
		PackedVector2Array([client_enemy.global_position]),
		PackedInt32Array([75]),
		PackedFloat32Array([0.62]),
		PackedByteArray([0]),
		PackedInt32Array([
			EnemyPresentation2D.pack_presentation_token(
				1,
				0,
				EnemyPresentation2D.PresentationEvent.ATTACK
			),
		])
	)
	_check(
		client_enemy.get_presentation_view().get_last_token_revision() == 2
		and client_enemy.get_presentation_view().get_active_presentation_event() == active_event_before_stale,
		"A stale ordered token cannot restart or replace a newer client one-shot"
	)
	horde._receive_enemy_positions(
		PackedInt32Array([client_enemy.enemy_id]),
		PackedVector2Array([client_enemy.global_position]),
		PackedInt32Array([25]),
		PackedFloat32Array([0.62]),
		PackedByteArray([1]),
		PackedInt32Array([
			EnemyPresentation2D.pack_presentation_token(
				3,
				2,
				EnemyPresentation2D.PresentationEvent.ATTACK
			),
		])
	)
	_check(
		client_enemy.current_health == 75
		and client_enemy.get_presentation_view().get_last_token_revision() == 2,
		"Token row mismatch rejects the complete ordered client snapshot before any state mutates"
	)
	horde._receive_enemy_positions(
		PackedInt32Array([client_enemy.enemy_id]),
		PackedVector2Array([client_enemy.global_position]),
		PackedInt32Array([75]),
		PackedFloat32Array([1.0]),
		PackedByteArray([4]),
		PackedInt32Array([
			EnemyPresentation2D.pack_presentation_token(
				3,
				4,
				EnemyPresentation2D.PresentationEvent.NONE
			),
		])
	)
	_check(
		is_equal_approx(client_enemy.get_movement_speed_multiplier(), 1.0)
		and client_enemy.get_presentation_view().get_active_presentation_event()
		== EnemyPresentation2D.PresentationEvent.NONE,
		"Ordered snapshot status and completed action state clear only from a newer host token"
	)
	var client_revision_before_publish: int = client_enemy.get_presentation_revision()
	client_enemy._publish_presentation_event(EnemyPresentation2D.PresentationEvent.ATTACK)
	_check(
		client_enemy.get_presentation_revision() == client_revision_before_publish,
		"A presentation-only client cannot mint an authoritative action token"
	)


func _validate_death_presentation_lifecycle(parent: Node2D) -> void:
	var enemies_root: Node2D = Node2D.new()
	enemies_root.name = &"EnemyDeathPresentationRoot"
	parent.add_child(enemies_root)
	var horde: HordeDirector = HordeDirector.new()
	parent.add_child(horde)
	horde._enemies_root = enemies_root
	var enemy: EnemyAgent2D = EnemyAgent2D.new()
	enemy.configure(
		991,
		EnemyAgent2D.Variant.SPLITTER,
		HOST_ORIGIN + Vector2(330.0, 330.0),
		80,
		10,
		70.0,
		HOST_ORIGIN,
		null,
		null,
		true
	)
	enemies_root.add_child(enemy)
	horde._enemies[enemy.enemy_id] = enemy
	enemy.died.connect(horde._on_enemy_died)
	await physics_frame
	enemy.take_damage(enemy.current_health)
	await process_frame
	var death_view: Node2D = null
	for child: Node in enemies_root.get_children():
		if child.get_script() == EnemyDeathPresentationView:
			death_view = child as Node2D
			break
	var death_presentation: EnemyPresentation2D = (
		death_view.call(&"get_presentation") as EnemyPresentation2D
		if death_view != null
		else null
	)
	_check(
		horde.get_enemy(991) == null
		and horde.get_alive_count() == 0
		and death_view != null
		and bool(death_view.call(&"is_visual_only"))
		and death_presentation != null
		and death_presentation.get_active_presentation_event()
		== EnemyPresentation2D.PresentationEvent.DEATH,
		"Death art survives immediate horde despawn as a collision-free non-zombie presentation view"
	)
	await create_timer(1.20).timeout
	_check(
		enemies_root.get_child_count() == 0,
		"Ephemeral death view frees itself after its baked death clip without retaining a gameplay shell"
	)
	horde.queue_free()
	enemies_root.queue_free()
	await process_frame


func _validate_horde_snapshot_schema() -> void:
	var horde: HordeDirector = HordeDirector.new()
	_check(
		_get_method_argument_count(horde, &"_receive_enemy_positions") == 6
		and _get_last_method_argument_name(horde, &"_receive_enemy_positions")
		== &"presentation_tokens",
		"Ordered Horde snapshot schema carries typed facing rows and presentation tokens"
	)
	_check(
		_get_method_argument_count(horde, &"_receive_horde_snapshot") == 18
		and _get_last_method_argument_name(horde, &"_receive_horde_snapshot")
		== &"presentation_tokens",
		"Reliable late-join Horde snapshot schema carries typed facing rows and presentation tokens"
	)
	horde.free()


func _get_method_argument_count(instance: Object, method_name: StringName) -> int:
	for method_data: Dictionary in instance.get_method_list():
		if StringName(method_data.get("name", "")) != method_name:
			continue
		var arguments: Array = method_data.get("args", [])
		return arguments.size()
	return -1


func _get_last_method_argument_name(instance: Object, method_name: StringName) -> StringName:
	for method_data: Dictionary in instance.get_method_list():
		if StringName(method_data.get("name", "")) != method_name:
			continue
		var arguments: Array = method_data.get("args", [])
		if arguments.is_empty():
			return &""
		var argument_data: Dictionary = arguments[arguments.size() - 1]
		return StringName(argument_data.get("name", ""))
	return &""


## Read through the scene rather than the view's private array, so this gate
## fails if the copies stop being Node2D children of the named content root -
## which is the structure the bob, the shadow split and the flash all assume.
func _first_visual_copy_modulate(view: EnemyPresentation2D) -> Color:
	var content: Node = view.get_node_or_null(^"PresentationContent")
	if content == null:
		return Color(0.0, 0.0, 0.0, 0.0)
	for child: Node in content.get_children():
		var visual: Node2D = child as Node2D
		if visual != null:
			return visual.modulate
	return Color(0.0, 0.0, 0.0, 0.0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS | %s" % message)
		return
	_failures += 1
	push_error("FAIL | %s" % message)


func _finish() -> void:
	if _failures == 0:
		print("ENEMY PRESENTATION OK (%d checks)" % _checks)
		quit(0)
		return
	push_error(
		"ENEMY PRESENTATION FAILED (%d/%d checks failed)" % [_failures, _checks]
	)
	quit(1)
