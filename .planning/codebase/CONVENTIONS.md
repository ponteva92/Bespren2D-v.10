# Coding Conventions

**Analysis Date:** 2026-09-18

## Naming

**Files:**
- GDScript: `snake_case.gd` with a matching `class_name` in PascalCase. Example: `src/world/world_map_2d.gd` → `BesprenWorldMap2D`; `src/visual/health_bar_2d.gd` → `HealthBar2D`.
- World/tactical systems that own a domain use a `Bespren` prefix on the class only when they are the canonical map/scatter authority: `BesprenWorldMap2D`, `BesprenResourceScatter2D`. Other classes drop the product prefix (`CoopSession`, `TacticalBuildSystem`, `WorldObstacle2D`).
- Scenes: gameplay/world scenes are `snake_case.tscn` (`scenes/game/game_world.tscn`, `scenes/world/base_core.tscn`). Boot/UI exceptions keep PascalCase (`scenes/ui/StartMenu.tscn`, `scenes/ui/MobileControls.tscn`).
- Shaders: `snake_case.gdshader` under `shaders/` (`toon_emissive_outline.gdshader`, `sleek_sprite_finish.gdshader`, `terrain_material_blend.gdshader`).
- Assets: `type_subject_variant_state` under `assets/2d/`. Examples: `heikki_topdown.png`, `structure_t1_kinetic.png`, `polyhaven_environment_atlas.png`, `resource_wood.svg`.
- Tests: `*_validation.gd` for headless contract gates, `*_validation.tscn` plus matching `.gd` for GPU capture scenes, `*_enet_probe.gd` for two-process LAN probes, `smoke_test.gd` as the umbrella gate.

**Functions/methods:**
- Public API: `snake_case` verbs (`ensure_built`, `apply_harvest_progress`, `resolve_player_motion`, `is_position_walkable`).
- Private helpers and mutable fields: leading underscore (`_apply_progress_visual`, `_unit_noise`, `_resource_pool`, `_broadcast_accumulator`).
- RPC request/commit pairs: `_request_*` is `any_peer` inbound; `_commit_*` / `_broadcast_*` is `authority` outbound. Example: `_request_structure_placement` / `_commit_structure_placement` in `src/tactical/tactical_build_system.gd`.
- Signal handlers: `_on_*` (`_on_connected_to_server` in `src/coop/coop_session.gd`).

**Classes:**
- Always declare `class_name` on production scripts. Do not introduce autoloads; `project.godot` has no `[autoload]` section.
- Prefer explicit Godot types (`Node2D`, `CharacterBody2D`, `StaticBody2D`, `Resource`) over untyped `Node` unless the contract is genuinely polymorphic.
- Seat/catalog data lives in typed Resources (`PlayerSlotDefinition`, `StructureDefinition`, `EnemyPresentationDefinition`), not dictionaries of strings.

**Constants:**
- `SCREAMING_SNAKE_CASE` with explicit types. Domain numbers that gates pin live as named constants, never magic literals at call sites (`STARTING_CAMP_POSITION`, `WORLD_BUILD_SEED`, `STATE_BROADCAST_HZ`, `GRID_SIZE`).
- Semantic colors live as hex `Color("ffd700")` next to the locked palette, not as anonymous `Color(r, g, b)`.
- StringNames use `&"heikki"` / `&"interact"` literals, not plain `String`.

**Scenes/assets/shaders:**
- Unique-name `%Node` lookups for composition children (`%CoopSession`, `%WorldMap2D`, `%Icon`) in `src/game/game_world.gd` and presentation scenes.
- Cross-domain wiring uses `@export_node_path("Type")` plus `get_node_or_null(...) as Type` (`src/tactical/tactical_build_system.gd`). Do not walk unrelated scene branches.
- Atlas region literals are `Rect2` constants derived as `cell_region.xy + padded_atlas_region.xy` from the packer manifest. Copying `padded_atlas_region` verbatim samples the wrong cell.

## Code Style

**Formatting:**
- Tabs, typed signatures with `-> void` / concrete return types, trailing commas on multi-line arrays.
- Keep a blank line between `class_name`/`extends`, the `##` class docstring, enums, constants, exports, then methods.
- Wrap long conditions rather than compressing them; host validation branches stay early-return.

**Typing:**
- `debug/gdscript/warnings/untyped_declaration=2` in `project.godot` — untyped declarations are errors. `tests/smoke_test.gd` asserts this setting.
- Typed arrays and dictionaries everywhere: `Array[Color]`, `Array[WorldObstacle2D]`, `Dictionary[int, StringName]`, `PackedInt32Array`, `PackedVector2Array`, `PackedStringArray`.
- Loop variables are typed (`for peer_id: int in _registered_characters`).
- `Variant` is allowed only at RPC/`Callable` boundaries, then immediately narrowed (`resolved_position is Vector2 and resolved_position.is_finite()` in `src/coop/coop_session.gd`).

## Patterns

**Presentation vs authority:**
- When: any node under `src/visual/` or `src/feedback/`, plus visual drivers on gameplay scenes (`CorePulseDriver`, `ResourceNodeView`, `CharacterPresentation`, `EnemyPresentation2D`, `WeatherOverlay`, `HealthBar2D`, `CameraShake2D`, `VfxDirector`, `ActorGroundShadow2D`).
- How: report the simulation; never decide health totals, gather yield, placement, or authoritative position. `ResourceNodeView` docstring: "harvesting and depletion are intentionally absent." `CorePulseDriver` owns the 1.15× command punch and pulse only. `CameraShake2D` writes `Camera2D.offset` only — never the focus `position` that `PlayerAvatar` owns.
- Example: `src/visual/resource_node_view.gd`, `src/visual/core_pulse_driver.gd`, `src/feedback/camera_shake_2d.gd`.

**Composed child systems:**
- When: a new gameplay domain (day/night, build, horde, scatter, audio, juice).
- How: add a named child of `GameWorld` (`src/game/game_world.gd`) or a typed Resource. Communicate through typed signals and validated commands. Do not fold rules into `StartMenu` or bootstrap. Do not add an autoload.
- Example: `TacticalBuildSystem`, `BesprenResourceScatter2D`, `DayNightCycle`, `HordeDirector` composed in `scenes/game/game_world.tscn`.

**Host-authoritative RPC:**
- When: movement, interact/fire, gather, build, relocate, horde snapshots.
- How: clients call `rpc_id(1, ...)`. Host methods start with `if not multiplayer.is_server(): return`, sanitize (`is_finite()`, `limit_length(1.0)`, allowed character/action IDs), then rebroadcast. Movement/aim use `unreliable_ordered`; registration, interact, fire, gather, and build use `reliable`. Failed clients swap to `OfflineMultiplayerPeer` and keep the same peer-one path.
- Example: `src/coop/coop_session.gd` (`_request_movement`, `_request_registration`); `src/tactical/tactical_build_system.gd` (`_request_structure_placement`); `src/world/resource_scatter_2d.gd`.

**Shared visual primitives:**
- When: health readout, contact shadow, outline weight, identity accent.
- How: one class, not a per-family copy. Grep for the primitive a shared class replaced (`draw_rect` health bars, `draw_circle` contact discs) rather than trusting the class claim. Screen-space quantities convert through one constant (`HealthBar2D._pixel()`, shader `fwidth(UV) * width * stretch`).
- Example: `src/visual/health_bar_2d.gd`, `src/visual/ground_shadow.gd`, `src/visual/actor_ground_shadow_2d.gd`.

## Error Handling

- Host RPCs fail closed and silent: invalid peer, non-finite vector, unknown character, or cooldown miss returns without throwing. Emit a typed rejection signal when the player needs feedback (`placement_rejected`, `gather_rejected`).
- Node wiring uses `get_node_or_null(...) as Type` plus `is_instance_valid(...)` before use. Do not assume exported paths are set.
- Tests print `PASS | ...` / `push_error("FAIL | ...")` and `quit(0|1)`. Production gameplay does not `push_error` for expected client rejects.
- Motion resolver results that are not a finite `Vector2` keep the previous authoritative position (`src/coop/coop_session.gd`).

## Comments

- Every `class_name` file starts with a one-line `##` contract stating what it owns and what it does **not** own.
- Comment measured constraints, not narration: why a number exists, what it was measured against, and which gate pins it. See `BesprenWorldMap2D.OBSTACLE_BROADPHASE_CELL` and shader headers in `shaders/sleek_sprite_finish.gdshader`.
- Keep the old wrong shader idiom in a comment so it is not reintroduced (`vec4 source = COLOR;` with a note that `texture(TEXTURE, UV) * COLOR` squares the texel).
- Do not leave placeholders for unrelated work. A `ponytail:` comment is only for a known ceiling with an upgrade path.

## Graphics / Map Layout Conventions

**Shaders (`shaders/`):**
- `render_mode blend_mix`, never `unshaded`. Unshaded CanvasItems ignore `CanvasModulate` and `PointLight2D`, so they hold daylight through dusk.
- Entry color is already textured+modulated: write `vec4 source = COLOR;`. Never `texture(TEXTURE, UV) * COLOR` — that squares every channel.
- Outlines are screen-space: `fwidth(UV) * outline_width * stretch` with `stretch = (1.0 / SCREEN_PIXEL_SIZE.x) / 480.0`. Do not step by `TEXTURE_PIXEL_SIZE`.
- No dynamic loops. Bounded hash/value-noise only (`surface_weathering.gdshader`).
- One full-screen custom pass: `weather_overlay.gdshader`. Damage wash composites into that pass. `WeatherOverlay` forces `MOUSE_FILTER_IGNORE`.
- Additive glow (`blend_add` aura) is the only family allowed to hold night value; everything else must respond to night atmosphere.

**Lights:**
- Every world `PointLight2D` sets `range_z_min = -20` so it reaches terrain at `z_index = -20`. Sites: `scenes/characters/network_player.tscn`, `scenes/world/base_core.tscn`, `src/tactical/placed_structure_2d.gd`. Default −10 lights actors and leaves the ground dark.

**Z-index matrix (absolute, `z_as_relative = false`):**
- Ground `TileMapLayer`s and roads: `-20` (`src/world/world_map_2d.gd`, `src/world/world_road_network_2d.gd`).
- Non-colliding rubble/moss/decor: `-5`. Ambient scenery: `-4`.
- Gameplay/static occlusion (`WorldObstacle2D`, players, projectiles): `5` under Y-sort roots.
- HUD: CanvasLayer 100.

**Atlas sprites are presentation-only:**
- `WorldObstacle2D` may swap a cropped `AtlasTexture` and a shared `sleek_sprite_finish.gdshader` material. Collision, flow mask, `stable_seed`, obstacle ordering, and peer-one movement stay canonical.
- No runtime `Node3D`, mesh, PBR graph, or GLTF. Workshops under `tools/art/blender/` stay behind `.gdignore`.
- Wild canopy hue correction is `WorldObstacle2D.WILD_TREE_TINT = Color(0.60, 1.0, 0.70)` folded into entry `COLOR` before the grade. A runtime multiply cannot fix a baked value defect.

**Deterministic map layout:**
- World layout seed: `BesprenWorldMap2D.WORLD_BUILD_SEED = 0xB35E7E`. Resource scatter: `BesprenResourceScatter2D.DEFAULT_SCATTER_SEED = 0x5CA77E2`, `LAYOUT_VERSION = 2`.
- Variation goes through `_unit_noise(stable_seed + index)`, never `randf()`. Fence flips use one seeded phase per fence, not a per-segment coin.
- Camp is secluded at `Vector2(9950, 2400)` with 1,600-unit road-edge clearance. Playable extents ±14,336 on a 14×14 × 2,048-unit grid.
- `is_position_walkable` uses the 512-unit obstacle broadphase, not a linear scan. Query pad is `clearance * sqrt(2)` because rotated rects expand on local axes.
- New obstacles stamp zero-clearance world bounds into the grid. Presentation changes must not move collision footprints.

**New art:**
- Inspect at 1× logical (480×270). Judge a bake at the size it delivers (`scale * camera zoom 0.38`), not at PNG resolution.
- Rebake unmodified source must match shipped pixels (survivor/camp family: max per-channel delta 0; EEVEE wild/salvage family: ≤1 unit on ≲0.1% of pixels).
- After a rebake, regenerate the family manifest (`tools/art/write_generated_asset_manifest.py` for camp/structure/character; packer-written JSON for Poly Haven atlases). Pin SHA-256 of the shipped file.
- Identity stays redundant across hue, silhouette, iconography, and placement. Do not rely on hue alone at ~33 delivered pixels.
- Accessibility scales on shake, weather, and pulse: `0.0` means the effect is absent, not dim (`CameraShake2D.intensity_scale`).

**Materials and uniqueness:**
- Duplicate a `ShaderMaterial` before writing per-instance uniforms (`CharacterPresentation`) unless the scene owns one immutable shared variant on purpose (`ResourceNodeView` keeps the packed-scene material to avoid 87 copies).

---

*Conventions analysis: 2026-09-18*
