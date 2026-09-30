class_name WorldGroundCoverChunk2D
extends Node2D
## Bounded custom-draw batches of authored ground cover for natural terrain.
##
## Every cluster costs exactly two canvas commands - one wide dark contact
## multiline and one narrow body multiline - so a whole tuft group is issued as
## a single stroke list instead of one primitive per blade.
##
## This layer deliberately ships with no ShaderMaterial. `sleek_canvas_grade`
## is `render_mode unshaded`, and CLAUDE.md 8 records what that costs: an
## unshaded CanvasItem receives neither `CanvasModulate` nor any
## `PointLight2D`, so it would hold full daylight value while the terrain
## underneath it falls to the blue hour. A sparse accent can absorb that; a
## layer that covers every natural square of the map cannot. The colours below
## are therefore authored pre-graded and the cover is lit like the ground it
## sits on.

const GROUND_COVER_Z: int = -5
const BLADE_WIDTH: float = 3.6
const CONTACT_WIDTH: float = 7.4

enum CoverKind {
	GRASS_TUFT,
	LEAF_LITTER,
	PEBBLE_SCATTER,
	TWIG_FALL,
}

## Authored against the measured ground rather than by eye. The forest floor
## composites to rgb(43, 45, 35), luma 43.9, in the gameplay capture, and each
## colour below was solved backwards from a target composited luma delta so that
## every kind presents a value *pair* - a lit face at least +18 and a shaded face
## at most -8 - instead of a tint that vanishes into the terrain. The first pass
## failed that test everywhere except grass: leaf litter spanned only 12 luma
## straddling the ground (+7.6 / -4.3) and the dark pebble face sat at +3.4, so
## three of the four kinds were invisible at the shipped zoom while the placement
## data said they were there.
const GRASS_BASE: Color = Color(0.085, 0.125, 0.078, 0.62)
const GRASS_TIP: Color = Color(0.285, 0.375, 0.205, 0.66)
const GRASS_TIP_DRY: Color = Color(0.355, 0.330, 0.170, 0.60)
const LITTER_LIGHT: Color = Color(0.435, 0.314, 0.177, 0.55)
const LITTER_DARK: Color = Color(0.149, 0.105, 0.062, 0.58)
const PEBBLE_LIGHT: Color = Color(0.315, 0.340, 0.315, 0.60)
const PEBBLE_DARK: Color = Color(0.110, 0.122, 0.112, 0.58)
const TWIG_COLOR: Color = Color(0.105, 0.079, 0.054, 0.66)
const CONTACT_COLOR: Color = Color(0.028, 0.045, 0.038, 0.34)

var _positions: PackedVector2Array = PackedVector2Array()
var _radii: PackedFloat32Array = PackedFloat32Array()
var _kinds: PackedInt32Array = PackedInt32Array()
var _counts: PackedInt32Array = PackedInt32Array()
var _seeds: PackedInt32Array = PackedInt32Array()
var _world_render_bounds: Rect2 = Rect2()
var _has_bounds: bool = false


func _ready() -> void:
	z_index = GROUND_COVER_Z
	z_as_relative = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func configure_origin(world_origin: Vector2) -> void:
	position = world_origin
	z_index = GROUND_COVER_Z
	z_as_relative = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func add_cluster(
	world_position: Vector2,
	radius: float,
	kind: int,
	element_count: int,
	cluster_seed: int
) -> void:
	_positions.append(world_position - position)
	_radii.append(radius)
	_kinds.append(kind)
	_counts.append(element_count)
	_seeds.append(cluster_seed)
	_include_world_area(world_position, radius + 48.0)


func seal() -> void:
	queue_redraw()


func get_cluster_count() -> int:
	return _positions.size()


func get_element_count() -> int:
	var total: int = 0
	for count: int in _counts:
		total += count
	return total


func get_command_count() -> int:
	var total: int = 0
	for kind: int in _kinds:
		total += 2 if _kind_has_contact(kind) else 1
	return total


func get_world_render_bounds() -> Rect2:
	return _world_render_bounds


## Draw scratch. Packed arrays are value types in GDScript, so a builder cannot
## append into an array it received as an argument; these buffers are the
## shared destination instead. They hold nothing between `_draw` calls.
var _body_points: PackedVector2Array = PackedVector2Array()
var _body_colors: PackedColorArray = PackedColorArray()
var _contact_points: PackedVector2Array = PackedVector2Array()
var _contact_colors: PackedColorArray = PackedColorArray()


func _draw() -> void:
	for cluster_index: int in range(_positions.size()):
		var kind: int = _kinds[cluster_index]
		var origin: Vector2 = _positions[cluster_index]
		var radius: float = _radii[cluster_index]
		var cluster_seed: int = _seeds[cluster_index]
		_body_points.clear()
		_body_colors.clear()
		_contact_points.clear()
		_contact_colors.clear()
		for element_index: int in range(_counts[cluster_index]):
			var element_seed: int = cluster_seed * 733 + element_index * 97
			var angle: float = hash_unit(element_seed) * TAU
			var spread: float = sqrt(hash_unit(element_seed + 11))
			## The camera is an elevated three-quarter view, so a circular
			## ground footprint reads as an ellipse squashed in Y.
			var anchor: Vector2 = origin + Vector2(
				cos(angle) * radius * spread,
				sin(angle) * radius * spread * 0.72
			)
			match kind:
				CoverKind.GRASS_TUFT:
					_build_grass(anchor, element_seed)
				CoverKind.LEAF_LITTER:
					_build_litter(anchor, element_seed)
				CoverKind.PEBBLE_SCATTER:
					_build_pebble(anchor, element_seed)
				CoverKind.TWIG_FALL:
					_build_twig(anchor, element_seed)
		if not _contact_points.is_empty():
			draw_multiline(_contact_points, CONTACT_COLOR, CONTACT_WIDTH, true)
		if not _body_points.is_empty():
			draw_multiline_colors(_body_points, _body_colors, BLADE_WIDTH, true)


func _build_grass(anchor: Vector2, seed_source: int) -> void:
	var height: float = 17.0 + hash_unit(seed_source + 3) * 22.0
	var blade_count: int = 3 + int(hash_unit(seed_source + 5) * 3.0)
	var half_base: float = height * 0.20
	var tip_color: Color = (
		GRASS_TIP_DRY if hash_unit(seed_source + 7) > 0.74 else GRASS_TIP
	)
	_contact_points.append(anchor + Vector2(-half_base, 1.6))
	_contact_points.append(anchor + Vector2(half_base, 1.6))
	for blade_index: int in range(blade_count):
		var blade_seed: int = seed_source + blade_index * 131
		var lean: float = (hash_unit(blade_seed) - 0.5) * 1.35
		var length: float = height * (0.62 + hash_unit(blade_seed + 1) * 0.44)
		var root: Vector2 = anchor + Vector2(
			(hash_unit(blade_seed + 2) - 0.5) * half_base * 1.6,
			0.0
		)
		var mid: Vector2 = root + Vector2(
			sin(lean) * length * 0.42,
			-cos(lean) * length * 0.52
		)
		var tip: Vector2 = mid + Vector2(
			sin(lean * 1.7) * length * 0.46,
			-cos(lean * 1.7) * length * 0.40
		)
		_body_points.append(root)
		_body_points.append(mid)
		_body_colors.append(GRASS_BASE)
		_body_points.append(mid)
		_body_points.append(tip)
		_body_colors.append(tip_color)


func _build_litter(anchor: Vector2, seed_source: int) -> void:
	var leaf_count: int = 2 + int(hash_unit(seed_source + 3) * 3.0)
	for leaf_index: int in range(leaf_count):
		var leaf_seed: int = seed_source + leaf_index * 149
		var angle: float = hash_unit(leaf_seed) * PI
		var length: float = 7.0 + hash_unit(leaf_seed + 1) * 9.0
		var offset: Vector2 = Vector2(
			(hash_unit(leaf_seed + 2) - 0.5) * 26.0,
			(hash_unit(leaf_seed + 3) - 0.5) * 18.0
		)
		var direction: Vector2 = Vector2(
			cos(angle) * length * 0.5,
			sin(angle) * length * 0.33
		)
		_contact_points.append(anchor + offset - direction * 0.85 + Vector2(0.0, 1.4))
		_contact_points.append(anchor + offset + direction * 0.85 + Vector2(0.0, 1.4))
		_body_points.append(anchor + offset - direction)
		_body_points.append(anchor + offset + direction)
		_body_colors.append(
			LITTER_DARK if hash_unit(leaf_seed + 4) > 0.55 else LITTER_LIGHT
		)


func _build_pebble(anchor: Vector2, seed_source: int) -> void:
	var pebble_count: int = 2 + int(hash_unit(seed_source + 3) * 3.0)
	for pebble_index: int in range(pebble_count):
		var pebble_seed: int = seed_source + pebble_index * 167
		var angle: float = hash_unit(pebble_seed) * PI
		var length: float = 4.0 + hash_unit(pebble_seed + 1) * 6.0
		var offset: Vector2 = Vector2(
			(hash_unit(pebble_seed + 2) - 0.5) * 30.0,
			(hash_unit(pebble_seed + 3) - 0.5) * 20.0
		)
		var direction: Vector2 = Vector2(
			cos(angle) * length * 0.5,
			sin(angle) * length * 0.30
		)
		_contact_points.append(anchor + offset - direction * 0.9 + Vector2(0.0, 2.2))
		_contact_points.append(anchor + offset + direction * 0.9 + Vector2(0.0, 2.2))
		_body_points.append(anchor + offset - direction)
		_body_points.append(anchor + offset + direction)
		_body_colors.append(
			PEBBLE_DARK if hash_unit(pebble_seed + 4) > 0.62 else PEBBLE_LIGHT
		)


func _build_twig(anchor: Vector2, seed_source: int) -> void:
	var twig_count: int = 1 + int(hash_unit(seed_source + 3) * 2.0)
	for twig_index: int in range(twig_count):
		var twig_seed: int = seed_source + twig_index * 181
		var angle: float = hash_unit(twig_seed) * PI
		var length: float = 18.0 + hash_unit(twig_seed + 1) * 24.0
		var offset: Vector2 = Vector2(
			(hash_unit(twig_seed + 2) - 0.5) * 34.0,
			(hash_unit(twig_seed + 3) - 0.5) * 22.0
		)
		var direction: Vector2 = Vector2(
			cos(angle) * length * 0.5,
			sin(angle) * length * 0.29
		)
		var elbow: Vector2 = anchor + offset + Vector2(
			(hash_unit(twig_seed + 4) - 0.5) * 7.0,
			(hash_unit(twig_seed + 5) - 0.5) * 5.0
		)
		_contact_points.append(anchor + offset - direction + Vector2(0.0, 1.8))
		_contact_points.append(elbow + Vector2(0.0, 1.8))
		_contact_points.append(elbow + Vector2(0.0, 1.8))
		_contact_points.append(anchor + offset + direction + Vector2(0.0, 1.8))
		_body_points.append(anchor + offset - direction)
		_body_points.append(elbow)
		_body_colors.append(TWIG_COLOR)
		_body_points.append(elbow)
		_body_points.append(anchor + offset + direction)
		_body_colors.append(TWIG_COLOR)


## Every kind now grounds itself. Litter and twigs shipped without a contact on
## the argument that flat debris casts none, and the capture disproved it: with
## no dark line beneath them they read as terrain-texture scratches rather than
## as objects lying on the terrain.
static func _kind_has_contact(_kind: int) -> bool:
	return true


## Deterministic unit sample. Hashing the owner's world-cell seed rather than
## anything derived from the chunk keeps a cluster's shape identical no matter
## which render chunk it lands in.
static func hash_unit(source: int) -> float:
	var value: int = absi(source) & 0x7FFFFFFF
	value = ((value ^ (value >> 15)) * 0x2C1B3C6D) & 0x7FFFFFFF
	value = ((value ^ (value >> 12)) * 0x297A2D39) & 0x7FFFFFFF
	value = value ^ (value >> 15)
	return float(value & 0xFFFFFF) / 16777215.0


func _include_world_area(center: Vector2, radius: float) -> void:
	var area: Rect2 = Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	if not _has_bounds:
		_world_render_bounds = area
		_has_bounds = true
		return
	_world_render_bounds = _world_render_bounds.merge(area)
