class_name TowerCombatProfile
extends RefCounted
## Immutable combat data shared by the catalog, placement preview, and runtime tower controller.
## Strongest/weakest use current health; first uses the flow-field cost toward the active Base.

enum AttackKind {
	NONE,
	KINETIC,
	CHEMICAL,
	ELECTRIC,
	LANDMINE,
	SLOWING_PIT,
	RAZOR_SNARE,
}

enum TargetingMode {
	NEAREST,
	STRONGEST,
	WEAKEST,
	FIRST,
}

var attack_kind: int = AttackKind.NONE
var targeting_mode: int = TargetingMode.NEAREST
var detection_range: float = 0.0
var damage: int = 0
var cooldown_seconds: float = 0.0
var impact_radius: float = 0.0
var chain_radius: float = 0.0
var maximum_chain_targets: int = 1
var consumed_on_attack: bool = false
var movement_multiplier: float = 1.0
var status_duration_seconds: float = 0.0


func configure(
	new_attack_kind: int,
	new_targeting_mode: int,
	new_detection_range: float,
	new_damage: int,
	new_cooldown_seconds: float,
	new_impact_radius: float = 0.0,
	new_chain_radius: float = 0.0,
	new_maximum_chain_targets: int = 1,
	new_consumed_on_attack: bool = false,
	new_movement_multiplier: float = 1.0,
	new_status_duration_seconds: float = 0.0
) -> TowerCombatProfile:
	attack_kind = clampi(new_attack_kind, AttackKind.NONE, AttackKind.RAZOR_SNARE)
	targeting_mode = clampi(
		new_targeting_mode,
		TargetingMode.NEAREST,
		TargetingMode.FIRST
	)
	detection_range = maxf(new_detection_range, 0.0)
	damage = maxi(new_damage, 0)
	cooldown_seconds = maxf(new_cooldown_seconds, 0.0)
	impact_radius = maxf(new_impact_radius, 0.0)
	chain_radius = maxf(new_chain_radius, 0.0)
	maximum_chain_targets = maxi(new_maximum_chain_targets, 1)
	consumed_on_attack = new_consumed_on_attack
	movement_multiplier = clampf(new_movement_multiplier, 0.0, 1.0)
	status_duration_seconds = maxf(new_status_duration_seconds, 0.0)
	return self


func is_offensive() -> bool:
	return (
		attack_kind != AttackKind.NONE
		and detection_range > 0.0
		and (damage > 0 or has_movement_effect())
	)


func has_movement_effect() -> bool:
	return movement_multiplier < 0.9999 and status_duration_seconds > 0.0


func get_range_visualization_radius() -> float:
	return maxf(detection_range, impact_radius)


func has_distinct_impact_radius() -> bool:
	return impact_radius > detection_range + 0.01


func get_targeting_mode_name() -> StringName:
	match targeting_mode:
		TargetingMode.STRONGEST:
			return &"strongest"
		TargetingMode.WEAKEST:
			return &"weakest"
		TargetingMode.FIRST:
			return &"first"
		_:
			return &"nearest"
