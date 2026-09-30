extends SceneTree

## Focused gate for weight: the shove a landed hit imparts, and the bar it moves.
##
## Both exist so a hit is felt rather than merely accounted for, and both are the
## kind of thing that looks correct in a screenshot and is broken in motion. The
## contracts held here are the ones a play session would take a long time to
## expose.
##
## The first is that the shove is integrated in the attack branch at all. That
## branch used to zero the velocity and skip move_and_slide entirely, so the one
## body a hit could not move was a body already chewing on the player - which is
## exactly where impact has to read. A test that only shoved an enemy standing in
## open ground would have passed against the broken version.
##
## The second is that a rooted body does not slide. Damage is applied before the
## status in the trap path, so the impulse is always banked before the root
## exists; only suppression at integration keeps a Razor Snare from flinging its
## own victim out of its trigger radius and never rearming.
##
## The third is that the bar reaches clients. Host and client write health
## through entirely separate paths - the simulation on one, the replicated
## snapshot on the other - and a bar wired to only one of them is invisible on
## half the screens in the session.

## Long enough for a shove at the damage cap to travel and still be fully spent.
## Physics deltas are fixed at the tick rate, so this is a duration, not a race.
const IMPACT_FRAMES: int = 40
## A blow at the authored reference, so weight is exactly 1.0 and the arithmetic
## under test is the mass table rather than the damage curve.
const REFERENCE_DAMAGE: int = 12

var _failures: PackedStringArray = PackedStringArray()
var _checks: int = 0


func _initialize() -> void:
	# The root window is not tree-attached during _initialize, so an agent added
	# before this yields never receives _ready and never builds its bar.
	await process_frame
	# The authority guards ask multiplayer.is_server(), which is false with no
	# peer at all. This is the same offline peer a Solo session runs on, so the
	# host path under test is the shipping host path.
	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	_validate_mass_table()
	await _validate_impulse()
	await _validate_integration()
	await _validate_health_bar()
	await _validate_client_projectile_query()
	_report()


## Read as a set rather than value by value. The numbers themselves are a tuning
## judgement, but the ordering is the design claim - that the eight variants are
## meant to differ in the hand and not only on a health bar - and that is
## checkable.
func _validate_mass_table() -> void:
	var mass: Array[float] = EnemyAgent2D.KNOCKBACK_MASS
	_check(mass.size() == 8, "every variant has an authored mass (found %d)" % mass.size())
	if mass.size() != 8:
		return
	var immovable: int = 0
	for value: float in mass:
		if value <= 0.0:
			immovable += 1
	# A body that cannot be moved at all reads as level geometry rather than as
	# something heavy. The small give is what sells the mass.
	_check(immovable == 0, "no variant is perfectly immovable (%d are)" % immovable)
	var walker: float = mass[EnemyAgent2D.Variant.WALKER]
	var crawlers: float = mass[EnemyAgent2D.Variant.RAT_SWARM]
	var shield: float = mass[EnemyAgent2D.Variant.SCRAP_SHIELD]
	var goliath: float = mass[EnemyAgent2D.Variant.GOLIATH]
	var overlord: float = mass[EnemyAgent2D.Variant.OVERLORD]
	_check(crawlers > walker, "a crawler pack scatters further than a walker")
	_check(shield < walker, "a shield braced behind its plate gives less than a walker")
	_check(goliath < shield and overlord < shield,
		"bosses hold ground the rank and file cannot")
	_check(overlord <= goliath, "the overlord is the heaviest body in the game")


func _validate_impulse() -> void:
	var agent: EnemyAgent2D = await _spawn(EnemyAgent2D.Variant.WALKER, Vector2.ZERO, 400, true)
	_check(agent.get_knockback_velocity() == Vector2.ZERO, "a fresh body carries no shove")

	# --- hostile input -----------------------------------------------------
	# The direction arrives from the network fire path, and a NaN reaching a
	# CharacterBody2D velocity corrupts the position for the rest of the session.
	var rejected: int = 0
	for bad: Vector2 in [Vector2(NAN, 0.0), Vector2(INF, 1.0), Vector2(0.0, -INF), Vector2.ZERO]:
		if not agent.apply_knockback(bad, REFERENCE_DAMAGE):
			rejected += 1
	_check(rejected == 4,
		"non-finite and zero directions are all rejected (%d of 4)" % rejected)
	for bad_damage: int in [0, -1, -9999]:
		_check(not agent.apply_knockback(Vector2.RIGHT, bad_damage),
			"a non-positive blow of %d banks no shove" % bad_damage)
	_check(agent.get_knockback_velocity() == Vector2.ZERO,
		"hostile input left the body at exact rest")

	# --- a hit shoves the way the shot was travelling ----------------------
	_check(agent.apply_knockback(Vector2.RIGHT, REFERENCE_DAMAGE), "a valid hit banks a shove")
	var shove: Vector2 = agent.get_knockback_velocity()
	_check(shove.dot(Vector2.RIGHT) > 0.0 and is_zero_approx(shove.y),
		"the shove runs along the shot rather than away from the shooter")
	var expected: float = EnemyAgent2D.KNOCKBACK_IMPULSE_SPEED * agent.get_knockback_mass()
	_check(is_equal_approx(shove.length(), expected),
		"the reference blow shoves at the authored speed times mass (%.2f vs %.2f)"
		% [shove.length(), expected])

	# --- the blow is sized, and the sizing is capped -----------------------
	var graze: EnemyAgent2D = await _spawn(EnemyAgent2D.Variant.WALKER, Vector2.ZERO, 400, true)
	graze.apply_knockback(Vector2.RIGHT, 1)
	_check(graze.get_knockback_velocity().length() < shove.length(),
		"a grazing round shoves less than a full blow")
	var absurd: EnemyAgent2D = await _spawn(EnemyAgent2D.Variant.WALKER, Vector2.ZERO, 400, true)
	absurd.apply_knockback(Vector2.RIGHT, 100000)
	var cap: float = (
		EnemyAgent2D.KNOCKBACK_IMPULSE_SPEED
		* EnemyAgent2D.KNOCKBACK_DAMAGE_CAP
		* absurd.get_knockback_mass()
	)
	_check(absurd.get_knockback_velocity().length() <= cap + 0.001,
		"damage scaling caps, so a late-run weapon cannot launch a body off the map")

	# --- sustained fire does not add up into a launch ----------------------
	# A horde dying inside one volley is an ordinary event, not an edge case.
	var sprayed: EnemyAgent2D = await _spawn(
		EnemyAgent2D.Variant.RAT_SWARM, Vector2.ZERO, 400, true
	)
	for _shot: int in 40:
		sprayed.apply_knockback(Vector2.RIGHT, 100)
	_check(
		sprayed.get_knockback_velocity().length() <= EnemyAgent2D.KNOCKBACK_MAX_SPEED + 0.001,
		"forty rounds inside one frame clamp at the authored ceiling (found %.1f)"
		% sprayed.get_knockback_velocity().length()
	)

	# --- clients bank nothing ---------------------------------------------
	# Two peers each simulating their own shove would disagree about where a body
	# is, and only the host is entitled to an opinion about that.
	var client: EnemyAgent2D = await _spawn(
		EnemyAgent2D.Variant.WALKER, Vector2.ZERO, 400, false
	)
	_check(
		not client.apply_knockback(Vector2.RIGHT, REFERENCE_DAMAGE)
		and client.get_knockback_velocity() == Vector2.ZERO,
		"a non-authority body refuses to simulate its own knockback"
	)

	for node: Node in [agent, graze, absurd, sprayed, client]:
		node.queue_free()


func _validate_integration() -> void:
	# Its own position as the base target, so the body is inside attack range and
	# chooses to stand still. Whatever motion the test then measures is the shove
	# and nothing else - and standing still is the branch that used to drop it.
	var origin: Vector2 = Vector2(2048.0, 2048.0)
	var agent: EnemyAgent2D = await _spawn(EnemyAgent2D.Variant.WALKER, origin, 400, true)
	await physics_frame
	_check(agent.global_position.is_equal_approx(origin),
		"a body at its target holds position while nothing is shoving it")

	agent.apply_knockback(Vector2.RIGHT, 40)
	for _frame: int in IMPACT_FRAMES:
		await physics_frame
	var travel: Vector2 = agent.global_position - origin
	_check(travel.x > 1.0,
		"a body already in melee is still moved by a hit (travelled %.2f)" % travel.x)
	_check(absf(travel.y) < 0.5, "the shove stayed on the axis of the shot")
	_check(agent.get_knockback_velocity() == Vector2.ZERO,
		"the shove decays to exact rest rather than creeping for the session")
	var settled: Vector2 = agent.global_position
	for _frame: int in 10:
		await physics_frame
	_check(agent.global_position.is_equal_approx(settled),
		"a spent shove leaves the body where it stopped")

	# --- a rooted body does not slide -------------------------------------
	var rooted: EnemyAgent2D = await _spawn(EnemyAgent2D.Variant.WALKER, origin, 400, true)
	await physics_frame
	# The trap order reproduced exactly: damage first, status second. If the
	# impulse were suppressed only at bank time, this would still fling the body.
	rooted.apply_knockback(Vector2.RIGHT, 40)
	_check(rooted.apply_movement_slow(0.0, 2.0), "the root applies")
	for _frame: int in IMPACT_FRAMES:
		await physics_frame
	var drift: float = rooted.global_position.distance_to(origin)
	_check(drift < 1.0, "a rooted body is pinned through the stagger (drifted %.3f)" % drift)
	_check(rooted.get_knockback_velocity() == Vector2.ZERO,
		"the suppressed shove still decays, so it is not owed back when the root expires")

	agent.queue_free()
	rooted.queue_free()


func _validate_health_bar() -> void:
	var walker: EnemyAgent2D = await _spawn(EnemyAgent2D.Variant.WALKER, Vector2.ZERO, 100, true)
	var bar: HealthBar2D = walker.get_health_bar()
	_check(bar != null, "a body carries a health bar")
	if bar == null:
		return
	# Parented to the body, not to the presentation view: that view mirrors
	# itself by flipping its own scale.x and bobs its content root, so a bar hung
	# there would flip its ticks with the walk cycle and bounce with the stride.
	_check(bar.get_parent() == walker,
		"the bar hangs off the body rather than off the mirroring presentation view")
	_check(bar.hide_when_full,
		"an untouched body shows no bar, so a fresh wave is not a wall of full bars")
	_check(bar.position.y < 0.0, "the bar sits above the body (y %.2f)" % bar.position.y)
	_check(bar.segments == 1, "rank and file carry no tick clutter")

	var radius: float = EnemyPresentationCatalog.get_definition(
		EnemyAgent2D.Variant.WALKER
	).marker_radius
	_check(is_equal_approx(bar.bar_size.x, radius * EnemyAgent2D.HEALTH_BAR_WIDTH_SCALE),
		"bar width rides the same authored radius as the ground shadow")
	_check(is_equal_approx(bar.position.y, -radius * EnemyAgent2D.HEALTH_BAR_LIFT_SCALE),
		"bar lift rides that radius too, so a resized variant moves both together")

	# --- the boss reads differently ---------------------------------------
	var overlord: EnemyAgent2D = await _spawn(
		EnemyAgent2D.Variant.OVERLORD, Vector2.ZERO, 4000, true
	)
	var boss_bar: HealthBar2D = overlord.get_health_bar()
	_check(boss_bar != null and boss_bar.segments == EnemyAgent2D.BOSS_HEALTH_BAR_SEGMENTS,
		"a boss is subdivided, because pacing a long fight is what the ticks are for")
	_check(
		boss_bar != null
		and boss_bar.bar_size.x > bar.bar_size.x
		and boss_bar.bar_size.y > bar.bar_size.y,
		"the boss bar is the larger readout of the two"
	)

	# --- the host path ----------------------------------------------------
	walker.take_damage(40)
	_check(is_equal_approx(bar.get_ratio(), 0.6),
		"host damage moves the bar (found %.3f)" % bar.get_ratio())
	_check(bar.get_chip_ratio() > bar.get_ratio(),
		"the bite is left standing as a chip rather than vanishing instantly")
	_check(bar.is_active(), "a wounded body still shows its bar")

	# --- and the client path, through the snapshot that already existed ----
	var client: EnemyAgent2D = await _spawn(
		EnemyAgent2D.Variant.WALKER, Vector2.ZERO, 100, false
	)
	var client_bar: HealthBar2D = client.get_health_bar()
	client.apply_network_snapshot(Vector2(64.0, 0.0), 25)
	_check(client_bar != null and is_equal_approx(client_bar.get_ratio(), 0.25),
		"a replicated health value moves the bar with no protocol of its own")

	# --- and it leaves with the body --------------------------------------
	walker.take_damage(1000)
	_check(not bar.is_active(),
		"a corpse shows nothing rather than an empty frame for the whole despawn")
	_check(walker.get_knockback_velocity() == Vector2.ZERO,
		"death releases any shove still on the body")

	for node: Node in [walker, overlord, client]:
		node.queue_free()


func _validate_client_projectile_query() -> void:
	var client: EnemyAgent2D = await _spawn(
		EnemyAgent2D.Variant.WALKER, Vector2(80.0, 0.0), 100, false
	)
	await physics_frame
	_check(
		client.collision_layer == EnemyAgent2D.ENEMY_LAYER
		and client.collision_mask == 0,
		"a client body stays on the enemy layer and does not slide"
	)
	var health_before: int = client.current_health
	var applied: int = client.take_projectile_damage(12, Vector2.RIGHT, 2)
	_check(
		applied == 0 and client.current_health == health_before,
		"a client body refuses projectile damage"
	)
	var projectile_scene: PackedScene = load("res://scenes/combat/player_projectile.tscn") as PackedScene
	var projectile: PlayerProjectile = projectile_scene.instantiate() as PlayerProjectile
	root.add_child(projectile)
	var impacted: Array[Node] = []
	projectile.impacted.connect(func(collider: Node) -> void:
		impacted.append(collider)
	)
	var space_state: PhysicsDirectSpaceState2D = client.get_world_2d().direct_space_state
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		Vector2(-40.0, 0.0),
		Vector2(160.0, 0.0),
		projectile.collision_mask
	)
	ray.collide_with_bodies = true
	var ray_hit: Dictionary = space_state.intersect_ray(ray)
	_check(ray_hit.get(&"collider") == client, "the enemy layer is visible to a projectile ray")
	projectile.initialize(Vector2(-40.0, 0.0), Vector2.RIGHT, 2)
	for _frame: int in 24:
		if not is_instance_valid(projectile) or not projectile.is_active():
			break
		await physics_frame
	_check(
		impacted.size() == 1 and impacted[0] is EnemyAgent2D,
		"a Join tracer stops on the client body"
	)
	_check(client.current_health == health_before, "the stopped tracer still applied no health")
	var host: EnemyAgent2D = await _spawn(
		EnemyAgent2D.Variant.WALKER, Vector2(28.0, 400.0), 100, true
	)
	await physics_frame
	var host_before: int = host.current_health
	var host_applied: int = host.take_projectile_damage(12, Vector2.RIGHT, 1)
	_check(
		host_applied == 12 and host.current_health == host_before - 12,
		"the host path still applies the same projectile damage"
	)
	if is_instance_valid(projectile):
		projectile.queue_free()
	client.queue_free()
	host.queue_free()


## Spawned with its own position as the base target unless a caller wants
## otherwise, so an agent under test stands still and measures only what the
## test did to it.
func _spawn(
	variant: int,
	world_position: Vector2,
	health_value: int,
	authority: bool
) -> EnemyAgent2D:
	var agent: EnemyAgent2D = EnemyAgent2D.new()
	agent.configure(
		1000 + _checks,
		variant,
		world_position,
		health_value,
		1,
		60.0,
		world_position,
		null,
		null,
		authority
	)
	root.add_child(agent)
	await process_frame
	return agent


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)


func _fail(description: String) -> void:
	_checks += 1
	_failures.append(description)


func _report() -> void:
	if _failures.is_empty():
		print("ENEMY IMPACT OK (%d checks)" % _checks)
		quit(0)
		return
	for failure: String in _failures:
		print("FAIL: %s" % failure)
	print("ENEMY IMPACT FAILED (%d of %d checks)" % [_failures.size(), _checks])
	quit(1)
