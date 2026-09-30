class_name StructureDefinition
extends Resource
## Immutable-at-runtime Tier-1 construction data used by UI and host validation.

const RESOURCE_KIND_COUNT: int = 3

enum Category {
	TOWER,
	TRAP,
	UTILITY,
}

var structure_id: StringName = &""
var display_name: String = ""
var role: String = ""
var mechanics: String = ""
var stats_text: String = ""
var cost: PackedInt32Array = PackedInt32Array()
var footprint_cells: Vector2i = Vector2i.ONE
var accent: Color = Color.WHITE
var max_health: int = 100
var combat_profile: TowerCombatProfile
var category: int = Category.UTILITY
var visual_texture_path: String = ""
var blocks_navigation: bool = true


func configure(
	new_id: StringName,
	new_display_name: String,
	new_role: String,
	new_mechanics: String,
	new_stats_text: String,
	new_cost: PackedInt32Array,
	new_footprint_cells: Vector2i,
	new_accent: Color,
	new_max_health: int,
	new_combat_profile: TowerCombatProfile = null,
	new_category: int = Category.UTILITY,
	new_visual_texture_path: String = "",
	new_blocks_navigation: bool = true
) -> StructureDefinition:
	structure_id = new_id
	display_name = new_display_name
	role = new_role
	mechanics = new_mechanics
	stats_text = new_stats_text
	cost = new_cost.duplicate()
	if cost.size() != RESOURCE_KIND_COUNT:
		cost.resize(RESOURCE_KIND_COUNT)
	footprint_cells = Vector2i(
		maxi(new_footprint_cells.x, 1),
		maxi(new_footprint_cells.y, 1)
	)
	accent = new_accent
	max_health = maxi(new_max_health, 1)
	combat_profile = new_combat_profile
	category = clampi(new_category, Category.TOWER, Category.UTILITY)
	visual_texture_path = new_visual_texture_path.strip_edges()
	blocks_navigation = new_blocks_navigation
	return self


func get_cost(resource_kind: int) -> int:
	if resource_kind < 0 or resource_kind >= cost.size():
		return 0
	return cost[resource_kind]


func get_cost_copy() -> PackedInt32Array:
	return cost.duplicate()


func get_visual_texture() -> Texture2D:
	if visual_texture_path.is_empty() or not ResourceLoader.exists(visual_texture_path, "Texture2D"):
		return null
	return load(visual_texture_path) as Texture2D


func is_tower() -> bool:
	return category == Category.TOWER


func is_trap() -> bool:
	return category == Category.TRAP


func is_utility() -> bool:
	return category == Category.UTILITY


func has_automatic_attack() -> bool:
	return combat_profile != null and combat_profile.is_offensive()


func get_effective_range() -> float:
	return combat_profile.detection_range if combat_profile != null else 0.0


func get_range_visualization_radius() -> float:
	return combat_profile.get_range_visualization_radius() if combat_profile != null else 0.0


func get_impact_radius() -> float:
	return combat_profile.impact_radius if combat_profile != null else 0.0


func has_distinct_impact_radius() -> bool:
	return combat_profile != null and combat_profile.has_distinct_impact_radius()
