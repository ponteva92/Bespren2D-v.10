class_name GameWorld
extends Node2D
## Runtime composition for one host-authoritative 2D LAN arena.

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/network_player.tscn")
const AutoAimController = preload(
	"res://src/combat/auto_aim_controller_2d.gd"
)
const INPUT_HEARTBEAT_SECONDS: float = 0.1

## World units within which an impact still reaches the local camera. The view
## is roughly 1,263 world units wide at the 0.38 gameplay zoom, so half a screen:
## something the player cannot see does not get to shake their screen.
const SHAKE_RADIUS: float = 640.0
## Trauma per event, as fractions of the full shake. Gathered here rather than
## written at the call sites so the whole feel of the camera is one readable
## table - the ordering between a round landing, a goliath coming apart and the
## base being lost is the thing that matters, and it is only legible together.
const SHAKE_PROJECTILE_IMPACT: float = 0.10
const SHAKE_ENEMY_DEATH_LIGHT: float = 0.13
const SHAKE_ENEMY_DEATH_HEAVY: float = 0.40
## The authored marker radii run 20 to 38, so a crawler sits at the light end of
## the death jolt and an overlord at the heavy one, with the rest interpolating.
const SHAKE_MASS_MIN_RADIUS: float = 20.0
const SHAKE_MASS_MAX_RADIUS: float = 38.0
const SHAKE_STRUCTURE_PLACED: float = 0.17
const SHAKE_NIGHT_STARTED: float = 0.30
const SHAKE_BASE_RELOCATED: float = 0.34
## Taking a hit. Scaled by the fraction of maximum health the blow removed, so
## a graze from a walker and a goliath connecting are not the same event, and
## kept under the death jolt so the escalation still has somewhere to go.
const SHAKE_LOCAL_DAMAGE_MIN: float = 0.14
const SHAKE_LOCAL_DAMAGE_MAX: float = 0.46
## The refuge being chewed on. Placed in the world rather than sent to the local
## camera whole, so it fades with distance: a player out on a salvage run feels
## nothing, and a player standing in the camp feels the horde on the walls.
const SHAKE_BASE_DAMAGE: float = 0.24
## The Base takes a hit per zombie per swing, and one jolt each would be a
## permanent rumble rather than information. Damage is accumulated across this
## window and answered once, which also means a wall of attackers reads as one
## heavy blow instead of many small ones cancelling into noise.
const BASE_DAMAGE_WINDOW_SECONDS: float = 0.4
## Below this the accumulated bite is not worth interrupting the frame for.
const BASE_DAMAGE_MIN_FRACTION: float = 0.006
const SHAKE_LOCAL_DEATH: float = 0.60
const SHAKE_GAME_OVER: float = 0.85

@export var auto_aim_debug_visualization: bool = false

@onready var session: CoopSession = %CoopSession
@onready var world_map: BesprenWorldMap2D = %WorldMap2D
@onready var resource_scatter: BesprenResourceScatter2D = %ResourceScatter2D
@onready var players_root: Node2D = %Players
@onready var projectiles_root: ProjectilePool2D = %Projectiles
@onready var enemies_root: Node2D = %Enemies
@onready var flow_field: FlowFieldNavigation2D = %FlowFieldNavigation2D
@onready var combat_state: CombatStateCoordinator = %CombatStateCoordinator
@onready var horde_director: HordeDirector = %HordeDirector
@onready var atmosphere: NightAtmosphere2D = %NightAtmosphere2D
@onready var blood_canvas: BloodCanvas = %BloodCanvas
@onready var loot_boxes: LootBoxManager2D = %LootBoxes
@onready var base_core: CorePulseDriver = %BaseCore
@onready var controls: MobileControls = %MobileControls
@onready var hud: GameHUD = %GameHUD
@onready var audio: GameAudioController = %GameAudio
@onready var back_button: Button = %BackButton
@onready var day_night: DayNightCycle = %DayNightCycle
@onready var build_system: TacticalBuildSystem = %TacticalBuildSystem
@onready var placement: GridPlacementController2D = %GridPlacementController2D
@onready var juice_rig: JuiceRig = %JuiceRig
@onready var vfx: VfxDirector = %Vfx
@onready var screen_effects: WeatherOverlay = %WeatherOverlay

var requested_mode: int = CoopSession.SessionMode.SOLO
var selected_character: StringName = &"heikki"
var host_address: String = "127.0.0.1"

var _players: Dictionary[int, PlayerAvatar] = {}
var _auto_aim_controllers: Dictionary[int, AutoAimController] = {}
var _session_active: bool = false
var _last_sent_movement: Vector2 = Vector2.ZERO
var _input_heartbeat: float = INPUT_HEARTBEAT_SECONDS
var _local_peer_id: int = CoopSession.AUTHORITY_PEER_ID
var _minimap_refresh_accumulator: float = 0.0
## Last reported health per peer, so a health signal can be read as damage. The
## coordinator broadcasts the value rather than the delta, and a bar can live
## with that where a screen response cannot.
var _last_player_health: Dictionary[int, int] = {}
## Negative until the first report, which is how the opening broadcast of a full
## Base is told apart from the refuge actually losing that much in one frame.
var _last_base_health: int = -1
var _pending_base_damage: float = 0.0
var _last_base_damage_at: float = -999.0


func configure_launch(mode_value: int, character_id: StringName, address: String) -> void:
	requested_mode = mode_value
	selected_character = character_id
	host_address = address


func _ready() -> void:
	world_map.ensure_built()
	resource_scatter.configure_world_map(world_map)
	resource_scatter.ensure_scattered()
	session.set_motion_resolver(_resolve_authoritative_motion)
	session.set_fire_direction_resolver(_resolve_authoritative_fire_direction)
	placement.set_preview_query(_query_placement_preview)
	hud.set_minimap_roads(world_map.get_road_routes(), world_map.get_road_dirt_flags())
	session.session_ready.connect(_on_session_ready)
	session.session_notice.connect(_on_session_notice)
	session.match_aborted.connect(_on_match_aborted)
	session.roster_reset.connect(_on_roster_reset)
	session.peer_registered.connect(_on_peer_registered)
	session.peer_left.connect(_on_peer_left)
	session.authoritative_state_received.connect(_on_authoritative_state_received)
	session.authoritative_aim_received.connect(_on_authoritative_aim_received)
	session.interaction_received.connect(_on_interaction_received)
	session.projectile_fired.connect(_on_projectile_fired)
	resource_scatter.resource_gathered.connect(_on_resource_gathered)
	resource_scatter.resource_snapshot_applied.connect(_on_resource_snapshot_applied)
	controls.action_pressed.connect(_on_touch_action_pressed)
	hud.command_requested.connect(_on_hud_command_requested)
	hud.structure_armed.connect(_on_structure_armed)
	hud.minimap_ping_requested.connect(_on_minimap_ping_requested)
	hud.build_deck_visibility_changed.connect(_on_build_deck_visibility_changed)
	day_night.clock_changed.connect(_on_clock_changed)
	day_night.warning_requested.connect(_on_warning_requested)
	day_night.night_started.connect(_on_night_started)
	day_night.day_started.connect(_on_day_started)
	build_system.resource_pool_changed.connect(_on_shared_pool_changed)
	build_system.structure_placed.connect(_on_structure_placed)
	build_system.structure_removed.connect(_on_structure_removed)
	build_system.placement_rejected.connect(_on_placement_rejected)
	build_system.base_relocated.connect(_on_base_relocated)
	horde_director.wave_clock_changed.connect(_on_wave_clock_changed)
	horde_director.boss_gate_changed.connect(_on_boss_gate_changed)
	horde_director.wave_completed.connect(_on_wave_completed)
	combat_state.player_health_changed.connect(_on_player_health_changed)
	combat_state.base_health_changed.connect(_on_base_health_changed)
	combat_state.respawn_started.connect(_on_respawn_started)
	combat_state.player_respawned.connect(_on_player_respawned)
	combat_state.game_over.connect(_on_game_over)
	loot_boxes.loot_opened.connect(_on_loot_opened)
	projectiles_root.projectile_impacted.connect(_on_projectile_impacted)
	horde_director.enemy_death_presented.connect(_on_enemy_death_presented)
	placement.placement_confirmed.connect(_on_placement_confirmed)
	hud.configure_feedback(juice_rig, audio, controls)
	juice_rig.bind_button(back_button, audio)
	back_button.pressed.connect(_on_back_pressed)
	controls.visible = false
	match requested_mode:
		CoopSession.SessionMode.HOST:
			session.start_host(selected_character)
		CoopSession.SessionMode.CLIENT:
			session.start_client(host_address, selected_character)
		_:
			session.start_solo(selected_character)


func _physics_process(delta: float) -> void:
	if not _session_active:
		return
	_input_heartbeat += delta
	var keyboard_movement: Vector2 = Input.get_vector(
		&"move_left",
		&"move_right",
		&"move_up",
		&"move_down"
	)
	var combined_movement: Vector2 = (
		controls.movement_vector + keyboard_movement
	).limit_length(1.0)
	if (
		not combined_movement.is_equal_approx(_last_sent_movement)
		or _input_heartbeat >= INPUT_HEARTBEAT_SECONDS
	):
		session.submit_movement(combined_movement)
		_last_sent_movement = combined_movement
		_input_heartbeat = 0.0
	if session.multiplayer.is_server():
		for peer_id: int in _auto_aim_controllers:
			var controller: AutoAimController = _auto_aim_controllers[peer_id]
			if is_instance_valid(controller):
				controller.set_authoritative_origin(session.get_authoritative_position(peer_id))
	_minimap_refresh_accumulator += delta
	if _minimap_refresh_accumulator >= 0.10:
		_minimap_refresh_accumulator = 0.0
		_refresh_minimap()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact"):
		session.submit_interaction(&"interact")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"fire"):
		session.submit_interaction(&"fire")
		get_viewport().set_input_as_handled()
	elif _try_select_structure_from_input(event):
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		get_tree().paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		get_tree().paused = false


func _query_placement_preview(structure_id: StringName, world_position: Vector2) -> bool:
	return build_system.preview_rejection_reason(structure_id, world_position).is_empty()


func _resolve_authoritative_motion(
	current_position: Vector2,
	desired_position: Vector2,
	player_radius: float
) -> Vector2:
	return build_system.resolve_player_motion(current_position, desired_position, player_radius)


func _resolve_authoritative_fire_direction(
	peer_id: int,
	world_position: Vector2,
	fallback_direction: Vector2
) -> Vector2:
	var controller: AutoAimController = _auto_aim_controllers.get(peer_id)
	if not is_instance_valid(controller):
		return fallback_direction
	controller.set_authoritative_origin(world_position)
	var resolved_direction: Vector2 = controller.get_firing_direction(fallback_direction)
	var player: PlayerAvatar = _players.get(peer_id)
	if is_instance_valid(player):
		player.set_aim_direction(resolved_direction, controller.is_assisting())
	session.set_peer_aim_state_authoritative(
		peer_id,
		resolved_direction,
		controller.get_current_target_id(),
		controller.is_assisting()
	)
	return resolved_direction


func _on_session_ready(mode_value: int, local_peer_id: int) -> void:
	_session_active = true
	_local_peer_id = local_peer_id
	controls.visible = true
	var mode_name: String = CoopSession.SessionMode.keys()[mode_value].capitalize()
	hud.set_status("%s // PEER %d // UDP %d" % [
		mode_name,
		local_peer_id,
		CoopSession.PORT,
	])
	_refresh_session_line()
	build_system.initialize_for_session()
	horde_director.reset_for_session()
	combat_state.initialize_for_session()
	loot_boxes.reset_for_session()
	horde_director.handle_navigation_changed()
	day_night.initialize_for_session()
	_refresh_resource_hud()
	_refresh_minimap()


func _on_session_notice(message: String) -> void:
	hud.set_status(message)
	_refresh_session_line()


func _on_match_aborted(message: String) -> void:
	_session_active = false
	controls.reset_touches()
	controls.visible = false
	StartMenu.queue_session_notice(message)
	get_tree().change_scene_to_file("res://scenes/ui/StartMenu.tscn")


func _refresh_session_line() -> void:
	var peer_count: int = session.get_registered_peer_ids().size()
	var line: String = "SOLO"
	match session.mode:
		CoopSession.SessionMode.HOST:
			line = "HOSTING // %d/2" % peer_count
		CoopSession.SessionMode.CLIENT:
			line = "JOINED" if session.is_connection_established() else "CONNECTING"
		_:
			line = "SOLO"
	hud.set_session_line(line)


func _on_peer_registered(
	peer_id: int,
	character_id: StringName,
	spawn_position: Vector2
) -> void:
	if _players.has(peer_id):
		return
	var player: PlayerAvatar = PLAYER_SCENE.instantiate() as PlayerAvatar
	player.name = "Player_%d" % peer_id
	player.configure(
		peer_id,
		character_id,
		spawn_position,
		peer_id == session.multiplayer.get_unique_id()
	)
	players_root.add_child(player)
	_players[peer_id] = player
	_install_auto_aim_controller(player)
	player.footfall.connect(_on_player_footfall)
	combat_state.register_player(player)
	atmosphere.register_player(player)
	if (
		session.mode == CoopSession.SessionMode.HOST
		and session.multiplayer.is_server()
		and peer_id > CoopSession.AUTHORITY_PEER_ID
	):
		resource_scatter.sync_state_to_peer(peer_id)
		build_system.sync_state_to_peer(peer_id)
		day_night.sync_state_to_peer(peer_id)
		combat_state.sync_state_to_peer(peer_id)
		horde_director.sync_state_to_peer(peer_id)
		loot_boxes.sync_state_to_peer(peer_id)
	_refresh_session_line()


func _on_peer_left(peer_id: int) -> void:
	resource_scatter.clear_peer_focus(peer_id)
	var player: PlayerAvatar = _players.get(peer_id)
	var controller: AutoAimController = _auto_aim_controllers.get(peer_id)
	_auto_aim_controllers.erase(peer_id)
	if is_instance_valid(controller):
		controller.queue_free()
	if player == null:
		_refresh_session_line()
		return
	_players.erase(peer_id)
	combat_state.unregister_player(peer_id)
	if player.get_parent() != null:
		player.get_parent().remove_child(player)
	player.queue_free()
	_refresh_session_line()


func _on_roster_reset() -> void:
	_session_active = false
	hud.close_build_deck_immediately()
	controls.reset_touches()
	controls.visible = false
	_last_sent_movement = Vector2.ZERO
	_input_heartbeat = INPUT_HEARTBEAT_SECONDS
	_clear_projectiles()
	# World bursts outlive the thing that raised them by design, so a reset that
	# clears the projectiles but not these leaves sparks hanging over an empty
	# map until they time out.
	vfx.stop_all()
	hud.set_resource_amounts(0, 0, 0)
	placement.cancel()
	day_night.reset_for_session()
	build_system.reset_for_session()
	horde_director.reset_for_session()
	combat_state.reset_for_session()
	loot_boxes.reset_for_session()
	_auto_aim_controllers.clear()
	atmosphere.set_night_active(false, true)
	var peer_ids: Array[int] = []
	for peer_id: int in _players:
		peer_ids.append(peer_id)
	for peer_id: int in peer_ids:
		_on_peer_left(peer_id)


func _on_authoritative_state_received(
	peer_id: int,
	position: Vector2,
	movement: Vector2
) -> void:
	var player: PlayerAvatar = _players.get(peer_id)
	if player != null:
		player.apply_authoritative_state(position, movement)
	var controller: AutoAimController = _auto_aim_controllers.get(peer_id)
	if is_instance_valid(controller):
		controller.set_authoritative_origin(position)


func _on_authoritative_aim_received(
	peer_id: int,
	direction: Vector2,
	_target_id: int,
	assisted: bool
) -> void:
	var player: PlayerAvatar = _players.get(peer_id)
	if is_instance_valid(player):
		player.set_aim_direction(direction, assisted)


func _on_interaction_received(
	peer_id: int,
	interaction: StringName,
	position: Vector2
) -> void:
	var player: PlayerAvatar = _players.get(peer_id)
	if player != null:
		player.apply_authoritative_state(position, Vector2.ZERO)
		player.play_interaction_feedback(interaction)
	if interaction == &"interact" and session.multiplayer.is_server():
		if not loot_boxes.try_open_authoritative(peer_id, position):
			resource_scatter.try_gather_authoritative(peer_id, position)


func _on_projectile_fired(peer_id: int, position: Vector2, direction: Vector2) -> void:
	var projectile: PlayerProjectile = projectiles_root.checkout(
		position + direction.normalized() * 24.0,
		direction,
		peer_id
	)
	if projectile == null:
		return
	var player: PlayerAvatar = _players.get(peer_id)
	if is_instance_valid(player):
		player.set_aim_direction(direction, session.is_peer_aim_assisted(peer_id))
	audio.play_world_cue(GameAudioController.CUE_SHOOT, position)
	# At the muzzle rather than at the body, so the flash reads as leaving
	# the weapon. This runs on every peer because the fire commit is
	# broadcast, which is what keeps the two screens showing the same shot.
	vfx.play(
		VfxDirector.Effect.MUZZLE_FLASH,
		position + direction.normalized() * 18.0,
		direction
	)


func _install_auto_aim_controller(player: PlayerAvatar) -> void:
	if (
		not is_instance_valid(player)
		or not session.multiplayer.is_server()
		or _auto_aim_controllers.has(player.peer_id)
	):
		return
	var controller: AutoAimController = AutoAimController.new()
	controller.name = "AutoAim_%d" % player.peer_id
	controller.debug_visualization = auto_aim_debug_visualization
	controller.configure(player)
	controller.aim_state_changed.connect(_on_auto_aim_state_changed)
	player.add_child(controller)
	controller.set_authoritative_origin(session.get_authoritative_position(player.peer_id))
	_auto_aim_controllers[player.peer_id] = controller


func _on_auto_aim_state_changed(
	peer_id: int,
	direction: Vector2,
	target_id: int,
	assisted: bool
) -> void:
	if not session.multiplayer.is_server():
		return
	var player: PlayerAvatar = _players.get(peer_id)
	if is_instance_valid(player):
		player.set_aim_direction(direction, assisted)
	session.set_peer_aim_state_authoritative(peer_id, direction, target_id, assisted)


func get_auto_aim_controller(peer_id: int) -> AutoAimController:
	return _auto_aim_controllers.get(peer_id)


func _on_resource_gathered(
	peer_id: int,
	resource_kind: int,
	amount: int,
	_resource_id: int,
	_world_position: Vector2
) -> void:
	if peer_id == _local_peer_id:
		hud.show_resource_pickup(_world_position, resource_kind, amount)
		audio.play_world_cue(GameAudioController.CUE_HARVEST, _world_position)
	# Not gated on the local peer. The pool is shared, so both survivors
	# should see which node just gave up its unit and in which colour.
	vfx.play(
		VfxDirector.Effect.GATHER_BURST,
		_world_position,
		Vector2.UP,
		ResourceNodeView.signal_color(resource_kind)
	)
	# The other half of the same beat: the node gives the unit up, the survivor
	# who earned it takes it. Also ungated, so each player can see which of them
	# the shared pool just grew from.
	var gatherer: PlayerAvatar = _players.get(peer_id)
	if is_instance_valid(gatherer):
		vfx.play(
			VfxDirector.Effect.PICKUP_SPARKLE,
			gatherer.global_position,
			Vector2.UP,
			ResourceNodeView.signal_color(resource_kind)
		)
	if session.multiplayer.is_server():
		build_system.credit_shared_resource_authoritative(resource_kind, amount)
	_refresh_minimap()


## The pool re-emits this for every projectile it owns, and hands back a
## spray vector already pointing out of the surface that was struck.
func _on_projectile_impacted(world_position: Vector2, spray: Vector2) -> void:
	vfx.play(VfxDirector.Effect.IMPACT_SPARK, world_position, spray)
	# Along the spray, so a round striking off to the left throws the frame that
	# way. Small enough that sustained fire is a rumble under the action rather
	# than a camera the player has to fight.
	_shake_at(world_position, SHAKE_PROJECTILE_IMPACT, spray)


## Radial, so no aim vector: a body coming apart has no direction the way a
## muzzle or a ricochet does.
func _on_enemy_death_presented(
	world_position: Vector2,
	tint: Color,
	body_radius: float
) -> void:
	vfx.play(VfxDirector.Effect.DEATH_BURST, world_position, Vector2.ZERO, tint)
	# Radial again, and scaled by the body that came apart: a crawler popping is
	# not the same event as an overlord going down, and a camera that answered
	# both identically would flatten the whole roster into one enemy.
	var mass: float = clampf(
		inverse_lerp(SHAKE_MASS_MIN_RADIUS, SHAKE_MASS_MAX_RADIUS, body_radius),
		0.0,
		1.0
	)
	_shake_at(
		world_position,
		lerpf(SHAKE_ENEMY_DEATH_LIGHT, SHAKE_ENEMY_DEATH_HEAVY, mass)
	)


func _on_resource_snapshot_applied(_state_revision: int) -> void:
	_refresh_resource_hud()
	_refresh_minimap()


func _on_touch_action_pressed(action: StringName) -> void:
	if _session_active:
		session.submit_interaction(action)


func _on_hud_command_requested(command: StringName) -> void:
	match command:
		GameHUD.COMMAND_MAKE_BASE:
			base_core.play_command_feedback()
			hud.close_build_deck_immediately()
			placement.arm_base_relocation()
			hud.set_status("BASE RELOCATION // TAP A CLEAR 64PX CELL")
		GameHUD.COMMAND_BUILD:
			placement.cancel()
			hud.toggle_build_deck()
			back_button.visible = not hud.is_build_deck_open()
			hud.set_status("TIER-1 DECK // SELECT A DEFENSE")
		GameHUD.COMMAND_START_NIGHT:
			day_night.request_start_night()
			hud.set_status("NIGHT COMMAND // HOST REQUEST SENT")


func _on_back_pressed() -> void:
	audio.play_ui_click()
	controls.reset_touches()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().change_scene_to_file("res://scenes/ui/StartMenu.tscn")


func _refresh_resource_hud() -> void:
	hud.set_resource_amounts(
		build_system.get_resource_amount(ResourceNodeView.ResourceKind.WOOD),
		build_system.get_resource_amount(ResourceNodeView.ResourceKind.METAL),
		build_system.get_resource_amount(ResourceNodeView.ResourceKind.TECH)
	)


func _on_structure_armed(structure_id: StringName) -> void:
	placement.arm_structure(structure_id)
	hud.set_status("%s // TAP TO PLACE" % String(structure_id).to_upper())


func _on_placement_confirmed(
	mode: int,
	structure_id: StringName,
	world_position: Vector2
) -> void:
	if mode == GridPlacementController2D.PlacementMode.BASE:
		build_system.request_base_relocation(world_position)
	elif mode == GridPlacementController2D.PlacementMode.STRUCTURE:
		build_system.request_structure_placement(structure_id, world_position)


func _on_shared_pool_changed(wood: int, metal: int, tech: int) -> void:
	hud.set_resource_amounts(wood, metal, tech)


func _on_structure_placed(structure: PlacedStructure2D) -> void:
	hud.set_status("%s // GRID %s" % [
		String(structure.structure_id).to_upper(),
		structure.global_position.round(),
	])
	atmosphere.register_structure(structure)
	# Under the actors, so the dust settles around the footprint instead of
	# painting over the survivor who raised it.
	vfx.play(VfxDirector.Effect.BUILD_POOF, structure.global_position)
	_shake_at(structure.global_position, SHAKE_STRUCTURE_PLACED)
	horde_director.handle_navigation_changed()
	_refresh_minimap()


func _on_structure_removed(_instance_id: int, _reason: StringName) -> void:
	horde_director.handle_navigation_changed()
	_refresh_minimap()


func _on_placement_rejected(reason: StringName) -> void:
	audio.play_alert()
	hud.set_status(GameHUD.placement_reason_text(reason))


func _try_select_structure_from_input(event: InputEvent) -> bool:
	if not _session_active or placement.is_armed():
		return false
	var world_position: Vector2 = Vector2.INF
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			world_position = get_global_mouse_position()
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			world_position = get_canvas_transform().affine_inverse() * touch.position
	if not world_position.is_finite():
		return false
	var had_selection: bool = build_system.get_selected_structure() != null
	var selected: PlacedStructure2D = build_system.select_structure_at(world_position)
	return selected != null or had_selection


func _on_base_relocated(
	world_position: Vector2,
	refund: PackedInt32Array,
	destroyed_count: int
) -> void:
	hud.set_status("BASE %s // %d CLEARED // REFUND %dW %dM %dT" % [
		world_position.round(),
		destroyed_count,
		refund[0],
		refund[1],
		refund[2],
	])
	horde_director.handle_navigation_changed()
	_shake_at(world_position, SHAKE_BASE_RELOCATED)
	_refresh_minimap()


func _on_clock_changed(seconds_remaining: int, night_number: int, is_night: bool) -> void:
	hud.set_day_night_state(seconds_remaining, night_number, is_night)


func _on_warning_requested(seconds_remaining: int) -> void:
	hud.show_warning(seconds_remaining)


func _on_night_started(night_number: int) -> void:
	build_system.set_daytime_building_enabled(false)
	placement.cancel()
	hud.close_build_deck_immediately()
	atmosphere.set_night_active(true)
	horde_director.begin_night_authoritative(night_number)
	hud.set_status("NIGHT %02d // COMBAT WAVE LIVE // ZOMBIES +35%%" % night_number)
	# Positionless: the night falling is not somewhere, it is everywhere, so
	# this is the one class of jolt that ignores the distance falloff.
	_shake_local(SHAKE_NIGHT_STARTED)


func _on_day_started(night_number: int) -> void:
	build_system.set_daytime_building_enabled(true)
	atmosphere.set_night_active(false)
	hud.set_status("DAYLIGHT // PREPARE FOR NIGHT %02d // ZOMBIES -65%%" % night_number)


func _on_minimap_ping_requested(world_position: Vector2) -> void:
	var local_player: PlayerAvatar = _players.get(_local_peer_id)
	if local_player != null:
		local_player.focus_camera_at(world_position)
	hud.set_status("TACTICAL PING // %s" % world_position.round())


func _on_build_deck_visibility_changed(open: bool) -> void:
	back_button.visible = not open


func _refresh_minimap() -> void:
	var positions: PackedVector2Array = PackedVector2Array()
	var peer_ids: Array[int] = _players.keys()
	peer_ids.sort()
	if peer_ids.has(_local_peer_id):
		peer_ids.erase(_local_peer_id)
		peer_ids.push_front(_local_peer_id)
	for peer_id: int in peer_ids:
		var player: PlayerAvatar = _players.get(peer_id)
		if player != null:
			positions.append(player.global_position)
	hud.set_minimap_state(
		build_system.get_base_position(),
		positions,
		build_system.get_structure_positions(),
		resource_scatter.get_available_resource_positions(),
		resource_scatter.get_available_resource_kinds()
	)


func _clear_projectiles() -> void:
	projectiles_root.release_all()


func _on_wave_clock_changed(seconds_remaining: int, frozen: bool) -> void:
	hud.set_wave_pacing(seconds_remaining, frozen)


func _on_boss_gate_changed(
	active: bool,
	boss_name: StringName,
	bosses_remaining: int
) -> void:
	hud.set_boss_gate(active, boss_name, bosses_remaining)
	if active:
		audio.play_alert()


func _on_wave_completed(_night_number: int) -> void:
	day_night.begin_next_day_authoritative()


## The coordinator reports health, not damage, so the drop has to be derived
## here. Both readouts already track the value itself - this exists only for the
## part a bar cannot say, which is that the hit happened to you.
func _on_player_health_changed(peer_id: int, current_health: int, maximum_health: int) -> void:
	var previous: int = _last_player_health.get(peer_id, maximum_health)
	_last_player_health[peer_id] = current_health
	if peer_id != _local_peer_id or maximum_health <= 0:
		return
	var lost: float = float(previous - current_health) / float(maximum_health)
	if lost <= 0.0:
		return
	# Radial rather than directional: the coordinator does not report who landed
	# the blow, and inventing an axis would point the player at the wrong threat.
	_shake_local(lerpf(SHAKE_LOCAL_DAMAGE_MIN, SHAKE_LOCAL_DAMAGE_MAX, minf(lost * 4.0, 1.0)))
	if is_instance_valid(screen_effects):
		screen_effects.flash(minf(lost * 3.2, 1.0))


## Accumulated over a short window rather than answered per hit, because the
## horde lands many small blows at once and a jolt for each would saturate the
## camera into a constant rumble that says nothing about any of them.
func _on_base_health_changed(current_health: int, maximum_health: int) -> void:
	var previous: int = _last_base_health if _last_base_health >= 0 else maximum_health
	_last_base_health = current_health
	if maximum_health <= 0 or current_health >= previous:
		return
	_pending_base_damage += float(previous - current_health) / float(maximum_health)
	var now: float = float(Time.get_ticks_msec()) * 0.001
	if now - _last_base_damage_at < BASE_DAMAGE_WINDOW_SECONDS:
		return
	_last_base_damage_at = now
	var bite: float = _pending_base_damage
	_pending_base_damage = 0.0
	if bite < BASE_DAMAGE_MIN_FRACTION or not is_instance_valid(base_core):
		return
	_shake_at(base_core.global_position, SHAKE_BASE_DAMAGE * minf(bite * 12.0, 1.0))


func _on_respawn_started(peer_id: int, seconds_remaining: float) -> void:
	var player: PlayerAvatar = _players.get(peer_id)
	var character_name: String = String(player.character_id) if is_instance_valid(player) else "PLAYER"
	hud.show_respawn_countdown(character_name, seconds_remaining)
	# Only for the survivor who actually went down. Watching a co-op partner
	# fall across the map should not take the camera away from the player who
	# is still alive and still being chased.
	if peer_id == _local_peer_id:
		_shake_local(SHAKE_LOCAL_DEATH)


func _on_player_respawned(peer_id: int, world_position: Vector2) -> void:
	var player: PlayerAvatar = _players.get(peer_id)
	var character_name: String = String(player.character_id) if is_instance_valid(player) else "PLAYER"
	hud.set_status("%s RESPAWNED // BASE %s" % [
		character_name.to_upper(),
		world_position.round(),
	])
	atmosphere.register_player(player)
	if peer_id == _local_peer_id and is_instance_valid(screen_effects):
		# Otherwise the last hit he took stays painted around a survivor who is
		# already back on his feet somewhere else.
		screen_effects.clear_damage()


func _on_game_over(reason: StringName) -> void:
	controls.reset_touches()
	controls.visible = false
	horde_director.stop_for_game_over()
	hud.show_game_over(reason)
	_shake_local(SHAKE_GAME_OVER)


func _on_loot_opened(
	peer_id: int,
	_loot_id: int,
	grant: PackedInt32Array
) -> void:
	hud.set_status("PEER %d // LOOT +%dW +%dM +%dT" % [
		peer_id,
		grant[0],
		grant[1],
		grant[2],
	])


## Ambient, so [VfxDirector] is free to drop it when the pool is busy telling
## the player about something that matters more.
func _on_player_footfall(world_position: Vector2) -> void:
	vfx.play(VfxDirector.Effect.FOOTSTEP_DUST, world_position)


## Impacts fall off with distance from the survivor holding the camera, squared
## so the effect stays concentrated where the player is actually fighting rather
## than turning the whole night into one continuous rumble.
func _shake_at(
	world_position: Vector2,
	trauma: float,
	direction: Vector2 = Vector2.ZERO
) -> void:
	var local_player: PlayerAvatar = _players.get(_local_peer_id)
	if not is_instance_valid(local_player) or not world_position.is_finite():
		return
	var falloff: float = 1.0 - clampf(
		local_player.global_position.distance_to(world_position) / SHAKE_RADIUS,
		0.0,
		1.0
	)
	if falloff <= 0.0:
		return
	local_player.add_camera_impact(trauma * falloff * falloff, direction)


## For events with no place in the world - the night falling, the run ending -
## which reach the player at full strength wherever they happen to be standing.
func _shake_local(trauma: float) -> void:
	var local_player: PlayerAvatar = _players.get(_local_peer_id)
	if is_instance_valid(local_player):
		local_player.add_camera_impact(trauma)
