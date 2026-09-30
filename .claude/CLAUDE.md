<!-- GSD:project-start source:PROJECT.md -->

## Project

**Bespren Visual AAA+ & Map Redesign**

A brownfield visual overhaul of Bespren, the existing Godot 4.7.1 Mobile LAN co-op survival slice. The product stays the same game — two scavengers, Base Core, salvage loop, 480×270 landscape — but every visual surface is lifted to hyper-premium AAA+ authored quality, and the largest piece of work is a full audit, analysis, discussion, plan, then redesign of the 14×14 world map.

Players should always know which district they are in. A 30-second salvage run should read as camp → readable road → named landmark → salvage pocket → threat → back, with each beat a place, not a seed.

**Core Value:** At 480×270, the world reads as authored places with a visible salvage loop — never as generated scatter on a grid.

### Constraints

- **Tech stack**: Godot 4.7.1 Mobile / Vulkan, typed GDScript, no autoloads — existing architecture stays
- **Viewport**: 480×270 logical landscape, `canvas_items` stretch — readability judged at 1×
- **World size**: 14×14 cells, 2,048-unit cells, ±14,336 extents — locked
- **Rendering budget**: one full-screen custom pass, zero shadow-casting 2D lights, zero dynamic shader loops, HDR 2D off
- **Runtime art**: 2D PNG/atlas only; Blender 5 workshops remain offline
- **Authority**: peer-one host path, ENet 8791 / OfflineMultiplayerPeer — presentation must not write simulation
- **Determinism**: world build remains seed-stable; authored composition must still be reproducible
- **Validation**: headless gates + Mobile/Vulkan capture gates remain the proof; a capture gate proves nothing until re-run
- **Addons vault**: no destructive cleanup of `Addons/`

<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->

## Technology Stack

## Languages

- GDScript 2.0 (Godot 4.7 typed) - Runtime game, scenes, validation gates under `src/`, `scenes/`, `tests/`
- Godot Shader Language (`shader_type canvas_item`) - All mobile CanvasItem materials under `shaders/`
- Python 3.11 / 3.12 / 3.14 (host interpreter; `__pycache__` shows all three) - Offline art/asset pipeline under `tools/art/` and `tools/asset_pipeline/`
- Blender Python (`bpy`, `mathutils`) - Headless EEVEE bakes executed inside Blender 5.0, not at game runtime
- PowerShell - Android APK inventory gate in `tests/android_export_validation.ps1`

## Runtime

- Godot `4.7.1.stable.official.a13da4feb` - Validation and shipping runtime
- Features: `PackedStringArray("4.7", "Mobile")` in `project.godot`
- Rendering method: `mobile` (`project.godot` `[rendering] renderer/rendering_method="mobile"`)
- Viewport: 480×270 logical landscape, `canvas_items` stretch, 960×540 window override for desktop
- Physics layers: `Players` (1), `WorldStatic` (2), `Enemies` (3)
- Autoloads: none. Compose systems as scene children or typed Resources.
- None for the game. No `package.json`, `requirements.txt`, `pyproject.toml`, `Cargo.toml`, or `go.mod`
- Lockfile: missing (not applicable)
- Tooling Python uses stdlib plus optional `PIL` / `numpy` imported by bake/pack/audit scripts. Install those on the host interpreter; do not add them as Godot runtime deps

## Frameworks

- Godot 4.7 Mobile 2D - SceneTree, `CharacterBody2D` / `StaticBody2D`, `TileMapLayer`, `Sprite2D` / `AnimatedSprite2D`, `CanvasItem` lights, RPC multiplayer
- `ENetMultiplayerPeer` - LAN host/client on UDP 8791 (`src/coop/coop_session.gd`)
- `OfflineMultiplayerPeer` - Solo fallback with the same peer-one authority path
- Godot `--headless --script` SceneTree gates - Deterministic contracts (`tests/smoke_test.gd`, `tests/world_map_validation.gd`, family validators)
- Godot windowed Mobile/Vulkan scenes - Pixel captures (`tests/world_render_validation.tscn` and sibling `*_render_validation.tscn`)
- Two-process ENet probes - `tests/enet_peer_probe.gd`, `tests/resource_enet_probe.gd`, `tests/tactical_enet_probe.gd`
- Host-interpreter Python validators - `tests/deep_asset_audit_validation.py`, bake-contract scripts under `tools/art/`
- Godot editor import + Android export preset - `export_presets.cfg`
- Blender 5.0.0 EEVEE - Isolated-scene orthographic transparent Freestyle bakes
- BlendMCP (`blendmcp_addon`) - Live workshop control via `tools/art/start_blendmcp_workshop.py`; production bakes use console Blender, not the MCP session
- Godot MCP (optional) - Not on the critical path; gates run from the Godot binary directly

## Key Dependencies

- Godot 4.7.1 Mobile renderer + Vulkan (OpenGL fallback enabled by engine, not a project toggle) - Shipping Android path. Do not enable HDR 2D; it would switch the viewport to RGBA16F
- `ENetMultiplayerPeer` / `OfflineMultiplayerPeer` - Host-authoritative LAN and Solo. Authority is always peer 1
- CanvasItem shader family under `shaders/` - `blend_mix` grading/outline, one full-screen `weather_overlay.gdshader`. Entry `COLOR` is already textured; never `texture(TEXTURE, UV) * COLOR`
- Baked 2D atlases under `assets/2d/` - Runtime art. No GLTF, mesh, PBR graph, or `Node3D` ships
- Poly Haven CC0 1k glTF (offline vault) - Fetched by `tools/asset_pipeline/fetch_polyhaven_models.py`, baked, packed; only PNG atlas + JSON manifest reach `res://`
- KayKit Character Animations 1.1 CC0 - Skeleton + clip vocabulary for actor bake (`Addons/KayKit_Character_Animations_1.1`, license `assets/licenses/kaykit_character_animations_cc0.md`)
- Kenney Starter Kit City Builder MIT/CC0 - Local environment GLB sources (`assets/licenses/local_baked_environment_sources.md`)
- Atomic Realm Post-Apocalyptic pack - Local environment GLBs; derived PNGs may ship in-game, must not be redistributed as an asset pack
- Pillow (`PIL`) - Host-side sheet packing (`tools/art/pack_actor_sheets.py`) and audit imaging
- NumPy - Blender-side pixel math in wild/terrain renderers (`tools/art/render_polyhaven_wild_sprites.py`, `tools/art/bake_polyhaven_terrain_materials.py`)

## Configuration

- Gameplay has no `.env` and no runtime cloud keys. LAN address is typed at Join; default client target is `127.0.0.1`
- Android export editor paths (not gameplay):
- Bake isolation:
- `project.godot` - App name Bespren, main scene `res://scenes/ui/StartMenu.tscn`, Mobile features, viewport, input map, physics layers, mobile renderer, ETC2/ASTC VRAM compression
- `export_presets.cfg` - Single Android preset, `com.bespren.game`, version `0.1.0`, arm64-v8a only, immersive, internet permission, scene-filter export of `StartMenu.tscn` + `game_world.tscn` + `runtime_export_dependencies.tscn`
- Exclude filter: `Addons/*,artifacts/asset_audit/extraction_runs/*,assets/2d/catalog/*,assets/2d/props/*`
- `data/runtime_export_closure.json` + `scenes/build/runtime_export_dependencies.tscn` - Hand-maintained runtime resource pin (201 resources / 202 strong deps)
- `gdscript/warnings/untyped_declaration=2` - Untyped declarations are errors. Keep every new script typed
- Texture import: actor sheets VRAM-compress with `process/fix_alpha_border=true`; resource SVGs generate mipmaps (`assets/2d/resources/*.svg.import`)

## Platform Requirements

- Windows host with Godot 4.7.1 (console binary used for `--headless --script`)
- Blender `C:\Program Files\Blender Foundation\Blender 5.0\blender.exe` for rebakes (`tools/art/run_wild_bake.py`)
- Python 3.11+ with Pillow for sheet packing / audits; NumPy available inside Blender for terrain/wild pixel ops
- Android SDK + JDK only when configuring/exporting APKs
- Do not scan `Addons/` as `res://` content (`Addons/.gdignore`). Promote through `tools/asset_pipeline/audit_and_extract_runtime_assets.py`
- Android arm64-v8a, package `com.bespren.game`, signed debug APK at `build/android/Bespren-debug.apk`
- Logical 480×270 landscape, `canvas_items` stretch, Mobile/Vulkan, 60 FPS preferred / 30 FPS fallback
- Local two-player LAN (one touch player per device) or Solo `OfflineMultiplayerPeer`
- Desktop keyboard remains a development input path, not the shipping control surface

## Graphics And Map Layout Stack

- Author and gate at 1× logical 480×270. Desktop window is 2× (960×540); measure rings/geometry from a `SubViewport` or divide physical pixels
- Gameplay camera zoom is 0.38. Screen-space quantities (outlines, bar weights) must use `fwidth(UV)` × stretch against `LOGICAL_VIEWPORT_WIDTH = 480.0`, never `TEXTURE_PIXEL_SIZE`
- One full-screen custom pass: `shaders/weather_overlay.gdshader` via `src/visual/weather_overlay.gd`. Combine atmosphere and damage wash here
- `terrain_material_blend.gdshader` - World ground overlay; biome mask + 1024 atlas, lighting-responsive, no extra full-screen pass
- `sleek_sprite_finish.gdshader` - Environment props, `WorldObstacle2D`, `PlacedStructure2D`. `render_mode blend_mix`
- `sleek_canvas_grade.gdshader` - Ambient scenery / background decor / wilderness accents. `blend_mix`
- `toon_emissive_outline.gdshader` - Base Core, resource nodes, legacy survivor scenes. Identity rims, `blend_mix`
- `surface_weathering.gdshader` - Rust / decayed wood / oxidized copper; bounded hash, no dynamic loops
- `weather_overlay.gdshader` - Rain/ash/tint/vignette + hit wash
- `volumetric_aura.gdshader`, `base_scale_glow.gdshader` - Base Core presentation only
- `projectile_glow.gdshader`, `solid_white_flash.gdshader`, `road_surface_detail.gdshader` - Combat/road accents
- Lights: set `range_z_min = -20` so they reach terrain at `z_index = -20` (`scenes/world/base_core.tscn`, `scenes/characters/network_player.tscn`, `src/tactical/placed_structure_2d.gd`)
- `BesprenWorldMap2D` in `src/world/world_map_2d.gd` owns the 14×14 macro-grid (2048-unit cells, ±14,336 playable), biome table, obstacle list, 512-unit walkability broadphase, and 112×112 flow-field mask
- Seed: `WORLD_BUILD_SEED = 0xB35E7E`. Keep placement deterministic
- Camp: `STARTING_CAMP_POSITION = Vector2(9950, 2400)` with 1600-unit road-edge clearance
- Regions: Kaupunki (city), Ostari (mall), west/east villages, Metsä/Luonto forest/wilderness — see `docs/WORLD_MAP_FOUNDATION.md`
- Absolute Z matrix: ground/roads `-20`, non-colliding rubble/moss `-5`, ambient silhouettes `-4`, gameplay/static `5` under Y-sort
- `WorldObstacle2D` (`src/world/world_obstacle_2d.gd`) is the single obstacle record: `StaticBody2D` on `WorldStatic`, collision shape, flow footprint, atlas visual
- Visual-only layers must not write collision or flow: `WorldAmbientScenery2D`, `WorldBackgroundDecor2D`, `WorldGroundCover2D`, `WorldWildernessAccent2D`, `WorldRoadNetwork2D`
- Navigation: `FlowFieldNavigation2D` (`src/ai/flow_field_navigation_2d.gd`) reads the map mask; traps do not block flow
- `actors/` - Shipping directional sheets, `SpriteFrames`, scenes, `sheet_manifest.json`, `actor_frames_manifest.json`
- `characters/` - Menu/legacy top-down PNGs + `generated_asset_manifest.json`
- `structures/` - Camp + eight Tier-1 silhouettes + `generated_asset_manifest.json`
- `environment/polyhaven/` - Nature/prop atlas
- `environment/polyhaven_district/` - Hidden Alley district atlas
- `environment/polyhaven_wild/` - Wild canopy (five shipped tree regions)
- `environment/polyhaven_salvage/` - Packed reserve, no runtime consumer
- `environment/local_baked/` - Kenney/Atomic Realm atlas
- `environment/terrain/` - `polyhaven_terrain_atlas.png` + `bespren_biome_blend_mask.png`
- `resources/` - Wood/Metal/Tech SVG masters
- `effects/` - Base Core / radial light SVGs
- Catalog/prop/enemy pixel-art trees under `assets/2d/catalog`, `props`, `enemies`, `bosses` are vault derivatives; Android exclude filter drops catalog/props. Do not add new shipping art there
- Isolated Blender scene policy: never mutate the user's default scene
- Shared rig: `tools/art/aaa_bake_rig.py` — elevation 52°, azimuth −45°, AgX Medium High Contrast, Freestyle, 4× supersample
- Character/camp generators write PNG then `tools/art/write_generated_asset_manifest.py`
- Actor path: `run_actor_bake.py` → `pack_actor_sheets.py` → `tools/asset_pipeline/build_actor_sprite_frames.gd`
- Environment path: fetch → workshop render → Godot atlas builder (`build_polyhaven_*.gd`, `build_local_environment_atlas.gd`)
- Workshops: `tools/art/blender/bespren_map_asset_workshop.blend`, `bespren_polyhaven_district_workshop.blend`, `bespren_local_environment_workshop.blend`, `bespren_terrain_material_workshop.blend`
- New art naming: `type_subject_variant_state`. Inspect at 1× logical size before accepting
- 2D games: atlas over loose textures; simplified collision; 8-direction facing via `ActorFacing` (`src/visual/actor_facing.gd`)
- Game art: identity redundant across hue, silhouette, iconography, placement
- Mobile games: 44×44 touch targets, thermal-aware budgets, no extra full-screen passes
- GDScript patterns: `class_name`, typed arrays/signals/enums, no autoload unless a later milestone truly needs process-global lifetime

<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->

## Conventions

## Naming

- GDScript: `snake_case.gd` with a matching `class_name` in PascalCase. Example: `src/world/world_map_2d.gd` → `BesprenWorldMap2D`; `src/visual/health_bar_2d.gd` → `HealthBar2D`.
- World/tactical systems that own a domain use a `Bespren` prefix on the class only when they are the canonical map/scatter authority: `BesprenWorldMap2D`, `BesprenResourceScatter2D`. Other classes drop the product prefix (`CoopSession`, `TacticalBuildSystem`, `WorldObstacle2D`).
- Scenes: gameplay/world scenes are `snake_case.tscn` (`scenes/game/game_world.tscn`, `scenes/world/base_core.tscn`). Boot/UI exceptions keep PascalCase (`scenes/ui/StartMenu.tscn`, `scenes/ui/MobileControls.tscn`).
- Shaders: `snake_case.gdshader` under `shaders/` (`toon_emissive_outline.gdshader`, `sleek_sprite_finish.gdshader`, `terrain_material_blend.gdshader`).
- Assets: `type_subject_variant_state` under `assets/2d/`. Examples: `heikki_topdown.png`, `structure_t1_kinetic.png`, `polyhaven_environment_atlas.png`, `resource_wood.svg`.
- Tests: `*_validation.gd` for headless contract gates, `*_validation.tscn` plus matching `.gd` for GPU capture scenes, `*_enet_probe.gd` for two-process LAN probes, `smoke_test.gd` as the umbrella gate.
- Public API: `snake_case` verbs (`ensure_built`, `apply_harvest_progress`, `resolve_player_motion`, `is_position_walkable`).
- Private helpers and mutable fields: leading underscore (`_apply_progress_visual`, `_unit_noise`, `_resource_pool`, `_broadcast_accumulator`).
- RPC request/commit pairs: `_request_*` is `any_peer` inbound; `_commit_*` / `_broadcast_*` is `authority` outbound. Example: `_request_structure_placement` / `_commit_structure_placement` in `src/tactical/tactical_build_system.gd`.
- Signal handlers: `_on_*` (`_on_connected_to_server` in `src/coop/coop_session.gd`).
- Always declare `class_name` on production scripts. Do not introduce autoloads; `project.godot` has no `[autoload]` section.
- Prefer explicit Godot types (`Node2D`, `CharacterBody2D`, `StaticBody2D`, `Resource`) over untyped `Node` unless the contract is genuinely polymorphic.
- Seat/catalog data lives in typed Resources (`PlayerSlotDefinition`, `StructureDefinition`, `EnemyPresentationDefinition`), not dictionaries of strings.
- `SCREAMING_SNAKE_CASE` with explicit types. Domain numbers that gates pin live as named constants, never magic literals at call sites (`STARTING_CAMP_POSITION`, `WORLD_BUILD_SEED`, `STATE_BROADCAST_HZ`, `GRID_SIZE`).
- Semantic colors live as hex `Color("ffd700")` next to the locked palette, not as anonymous `Color(r, g, b)`.
- StringNames use `&"heikki"` / `&"interact"` literals, not plain `String`.
- Unique-name `%Node` lookups for composition children (`%CoopSession`, `%WorldMap2D`, `%Icon`) in `src/game/game_world.gd` and presentation scenes.
- Cross-domain wiring uses `@export_node_path("Type")` plus `get_node_or_null(...) as Type` (`src/tactical/tactical_build_system.gd`). Do not walk unrelated scene branches.
- Atlas region literals are `Rect2` constants derived as `cell_region.xy + padded_atlas_region.xy` from the packer manifest. Copying `padded_atlas_region` verbatim samples the wrong cell.

## Code Style

- Tabs, typed signatures with `-> void` / concrete return types, trailing commas on multi-line arrays.
- Keep a blank line between `class_name`/`extends`, the `##` class docstring, enums, constants, exports, then methods.
- Wrap long conditions rather than compressing them; host validation branches stay early-return.
- `debug/gdscript/warnings/untyped_declaration=2` in `project.godot` — untyped declarations are errors. `tests/smoke_test.gd` asserts this setting.
- Typed arrays and dictionaries everywhere: `Array[Color]`, `Array[WorldObstacle2D]`, `Dictionary[int, StringName]`, `PackedInt32Array`, `PackedVector2Array`, `PackedStringArray`.
- Loop variables are typed (`for peer_id: int in _registered_characters`).
- `Variant` is allowed only at RPC/`Callable` boundaries, then immediately narrowed (`resolved_position is Vector2 and resolved_position.is_finite()` in `src/coop/coop_session.gd`).

## Patterns

- When: any node under `src/visual/` or `src/feedback/`, plus visual drivers on gameplay scenes (`CorePulseDriver`, `ResourceNodeView`, `CharacterPresentation`, `EnemyPresentation2D`, `WeatherOverlay`, `HealthBar2D`, `CameraShake2D`, `VfxDirector`, `ActorGroundShadow2D`).
- How: report the simulation; never decide health totals, gather yield, placement, or authoritative position. `ResourceNodeView` docstring: "harvesting and depletion are intentionally absent." `CorePulseDriver` owns the 1.15× command punch and pulse only. `CameraShake2D` writes `Camera2D.offset` only — never the focus `position` that `PlayerAvatar` owns.
- Example: `src/visual/resource_node_view.gd`, `src/visual/core_pulse_driver.gd`, `src/feedback/camera_shake_2d.gd`.
- When: a new gameplay domain (day/night, build, horde, scatter, audio, juice).
- How: add a named child of `GameWorld` (`src/game/game_world.gd`) or a typed Resource. Communicate through typed signals and validated commands. Do not fold rules into `StartMenu` or bootstrap. Do not add an autoload.
- Example: `TacticalBuildSystem`, `BesprenResourceScatter2D`, `DayNightCycle`, `HordeDirector` composed in `scenes/game/game_world.tscn`.
- When: movement, interact/fire, gather, build, relocate, horde snapshots.
- How: clients call `rpc_id(1, ...)`. Host methods start with `if not multiplayer.is_server(): return`, sanitize (`is_finite()`, `limit_length(1.0)`, allowed character/action IDs), then rebroadcast. Movement/aim use `unreliable_ordered`; registration, interact, fire, gather, and build use `reliable`. Failed clients swap to `OfflineMultiplayerPeer` and keep the same peer-one path.
- Example: `src/coop/coop_session.gd` (`_request_movement`, `_request_registration`); `src/tactical/tactical_build_system.gd` (`_request_structure_placement`); `src/world/resource_scatter_2d.gd`.
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

- `render_mode blend_mix`, never `unshaded`. Unshaded CanvasItems ignore `CanvasModulate` and `PointLight2D`, so they hold daylight through dusk.
- Entry color is already textured+modulated: write `vec4 source = COLOR;`. Never `texture(TEXTURE, UV) * COLOR` — that squares every channel.
- Outlines are screen-space: `fwidth(UV) * outline_width * stretch` with `stretch = (1.0 / SCREEN_PIXEL_SIZE.x) / 480.0`. Do not step by `TEXTURE_PIXEL_SIZE`.
- No dynamic loops. Bounded hash/value-noise only (`surface_weathering.gdshader`).
- One full-screen custom pass: `weather_overlay.gdshader`. Damage wash composites into that pass. `WeatherOverlay` forces `MOUSE_FILTER_IGNORE`.
- Additive glow (`blend_add` aura) is the only family allowed to hold night value; everything else must respond to night atmosphere.
- Every world `PointLight2D` sets `range_z_min = -20` so it reaches terrain at `z_index = -20`. Sites: `scenes/characters/network_player.tscn`, `scenes/world/base_core.tscn`, `src/tactical/placed_structure_2d.gd`. Default −10 lights actors and leaves the ground dark.
- Ground `TileMapLayer`s and roads: `-20` (`src/world/world_map_2d.gd`, `src/world/world_road_network_2d.gd`).
- Non-colliding rubble/moss/decor: `-5`. Ambient scenery: `-4`.
- Gameplay/static occlusion (`WorldObstacle2D`, players, projectiles): `5` under Y-sort roots.
- HUD: CanvasLayer 100.
- `WorldObstacle2D` may swap a cropped `AtlasTexture` and a shared `sleek_sprite_finish.gdshader` material. Collision, flow mask, `stable_seed`, obstacle ordering, and peer-one movement stay canonical.
- No runtime `Node3D`, mesh, PBR graph, or GLTF. Workshops under `tools/art/blender/` stay behind `.gdignore`.
- Wild canopy hue correction is `WorldObstacle2D.WILD_TREE_TINT = Color(0.60, 1.0, 0.70)` folded into entry `COLOR` before the grade. A runtime multiply cannot fix a baked value defect.
- World layout seed: `BesprenWorldMap2D.WORLD_BUILD_SEED = 0xB35E7E`. Resource scatter: `BesprenResourceScatter2D.DEFAULT_SCATTER_SEED = 0x5CA77E2`, `LAYOUT_VERSION = 2`.
- Variation goes through `_unit_noise(stable_seed + index)`, never `randf()`. Fence flips use one seeded phase per fence, not a per-segment coin.
- Camp is secluded at `Vector2(9950, 2400)` with 1,600-unit road-edge clearance. Playable extents ±14,336 on a 14×14 × 2,048-unit grid.
- `is_position_walkable` uses the 512-unit obstacle broadphase, not a linear scan. Query pad is `clearance * sqrt(2)` because rotated rects expand on local axes.
- New obstacles stamp zero-clearance world bounds into the grid. Presentation changes must not move collision footprints.
- Inspect at 1× logical (480×270). Judge a bake at the size it delivers (`scale * camera zoom 0.38`), not at PNG resolution.
- Rebake unmodified source must match shipped pixels (survivor/camp family: max per-channel delta 0; EEVEE wild/salvage family: ≤1 unit on ≲0.1% of pixels).
- After a rebake, regenerate the family manifest (`tools/art/write_generated_asset_manifest.py` for camp/structure/character; packer-written JSON for Poly Haven atlases). Pin SHA-256 of the shipped file.
- Identity stays redundant across hue, silhouette, iconography, and placement. Do not rely on hue alone at ~33 delivered pixels.
- Accessibility scales on shake, weather, and pulse: `0.0` means the effect is absent, not dim (`CameraShake2D.intensity_scale`).
- Duplicate a `ShaderMaterial` before writing per-instance uniforms (`CharacterPresentation`) unless the scene owns one immutable shared variant on purpose (`ResourceNodeView` keeps the packed-scene material to avoid 87 copies).

<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->

## Architecture

## System Overview

```text

```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| `StartMenu` | Character-first boot; instantiates `GameWorld` with mode/character/address | `src/ui/start_menu.gd`, `scenes/ui/StartMenu.tscn` |
| `GameWorld` | Runtime composition, signal wiring, motion/fire resolvers, juice dispatch | `src/game/game_world.gd`, `scenes/game/game_world.tscn` |
| `CoopSession` | Host-authoritative ENet / `OfflineMultiplayerPeer`; 20 Hz Vector2; RPC boundary | `src/coop/coop_session.gd` |
| `BesprenWorldMap2D` | 14×14 biome grid, roads, obstacles, walkability, flow-field bake | `src/world/world_map_2d.gd`, `scenes/world/world_map_2d.tscn` |
| `WorldObstacle2D` | One collision + flow footprint; presentation-only atlas sprites | `src/world/world_obstacle_2d.gd` |
| `WorldRoadNetwork2D` | Authored asphalt/dirt graph; edge-distance queries; chunked draw | `src/world/world_road_network_2d.gd` |
| `WorldBackgroundDecor2D` | 1,100 non-colliding rubble/crack/moss/prop marks at z=-5 | `src/world/world_background_decor_2d.gd` |
| `WorldAmbientScenery2D` | 640 collision-free large silhouettes at z=-4 | `src/world/world_ambient_scenery_2d.gd` |
| `WorldWildernessAccent2D` | Independently seeded wilderness ground accents at z=-5 | `src/world/world_wilderness_accent_2d.gd` |
| `WorldGroundCover2D` | Dense material-less ground ecology at z=-5 | `src/world/world_ground_cover_2d.gd` |
| `BesprenResourceScatter2D` | 87 deterministic nodes; 3–5 step harvest; late-join snapshots | `src/world/resource_scatter_2d.gd` |
| `ResourceNodeView` | Wood/Metal/Tech presentation; no quantity or pickup authority | `src/visual/resource_node_view.gd` |
| `CorePulseDriver` | Base Core pulse, aura, health-tier look; no HP / inventory / build radius | `src/visual/core_pulse_driver.gd`, `scenes/world/base_core.tscn` |
| `TacticalBuildSystem` | Shared pool, 64 px snap, towers/traps, Base relocation | `src/tactical/tactical_build_system.gd` |
| `PlacedStructure2D` | Per-card silhouette, WorldStatic footprint (traps nonblocking) | `src/tactical/placed_structure_2d.gd` |
| `StructureCatalog` | Eight Tier-1 card definitions + textures | `src/tactical/structure_catalog.gd` |
| `GridPlacementController2D` | Touch-safe 64 px preview / confirm | `src/tactical/grid_placement_controller_2d.gd` |
| `FlowFieldNavigation2D` | 112×112 integration toward active Base | `src/ai/flow_field_navigation_2d.gd` |
| `HordeDirector` | Night waves, 110-alive ceiling, death presentation signal | `src/ai/horde_director.gd` |
| `EnemyPresentationCatalog` | Eight variant IDs → baked actor scenes, contact_offset/radius | `src/ai/enemy_presentation_catalog.gd` |
| `CombatStateCoordinator` | Player/Base health, respawn, game over | `src/game/combat_state_coordinator.gd` |
| `PlayerAvatar` | Radius-9 `CharacterBody2D` shell; baked actor default | `src/game/player_avatar.gd`, `scenes/characters/network_player.tscn` |
| `AutoAimController2D` | Weighted cone aim; host fire direction stays authoritative | `src/combat/auto_aim_controller_2d.gd` |
| `DayNightCycle` | 450 s clock; host night command | `src/game/day_night_cycle.gd` |
| `NightAtmosphere2D` | CanvasModulate blue-hour; flashlight/security lights | `src/visual/night_atmosphere_2d.gd` |
| `WeatherOverlay` | One full-screen rain/ash/vignette + damage wash; `MOUSE_FILTER_IGNORE` | `src/visual/weather_overlay.gd`, `shaders/weather_overlay.gdshader` |
| `VfxDirector` | Pooled CPUParticles2D bursts; no simulation authority | `src/feedback/vfx_director.gd` |
| `CameraShake2D` | Trauma → `Camera2D.offset` only; never writes `position` | `src/feedback/camera_shake_2d.gd` |
| `HealthBar2D` | One drawn bar language for survivors, Base, horde, structures | `src/visual/health_bar_2d.gd` |
| `GroundShadow` | Shared ellipse ladder; callers pass measured radius/offset | `src/visual/ground_shadow.gd` |
| `BesprenBootstrap` | Foundation showcase composition; no gameplay systems | `src/core/bespren_bootstrap.gd`, `scenes/main/bespren_foundation.tscn` |

## Pattern Overview

- No autoloads. Systems live as unique-name children of `GameWorld` (`scenes/game/game_world.tscn`).
- Peer one owns movement, gather, fire, build, day/night, horde, and health. Clients submit intents (`rpc_id(1)`); they interpolate snapshots.
- Visual drivers (`src/visual/`, `src/feedback/`) report simulation. They never write health, yield, occupancy, or authoritative position.
- World layout is deterministic from `WORLD_BUILD_SEED` (`0xB35E7E` in `src/world/world_map_2d.gd`). Presentation layers seed independently so density retunes do not move collisions.
- Runtime art is 2D only. Blender workshops bake PNG/atlas families; no `Node3D`, GLTF, or PBR graph ships.
- Typed GDScript: `class_name`, typed arrays/signals, `untyped_declaration = 2` in `project.godot`.

## Layers

- Purpose: Pick Heikki or Shane and Solo/Host/Join before `GameWorld` enters the tree.
- Location: `scenes/ui/StartMenu.tscn`, `src/ui/start_menu.gd`
- Contains: Character cards (legacy 320 px portraits), session buttons, safe-area layout.
- Depends on: `CoopSession.SessionMode`, `scenes/game/game_world.tscn`
- Used by: `project.godot` `run/main_scene`
- Purpose: Wire domains through NodePaths and signals; never fold gameplay into the menu.
- Location: `scenes/game/game_world.tscn`, `src/game/game_world.gd`
- Contains: Unique-name children (`%WorldMap2D`, `%CoopSession`, `%TacticalBuildSystem`, …)
- Depends on: every domain below
- Used by: `StartMenu._launch()`
- Purpose: Validate and mutate shared state on peer one.
- Location: `src/coop/`, `src/tactical/`, `src/world/resource_scatter_2d.gd`, `src/game/combat_state_coordinator.gd`, `src/ai/horde_director.gd`, `src/game/day_night_cycle.gd`
- Contains: RPC controllers, catalogs (`StructureCatalog`, `EnemyPresentationCatalog`), flow field
- Depends on: `BesprenWorldMap2D` walkability / obstacles
- Used by: `GameWorld` resolvers and HUD command path
- Purpose: Author the 28,672-unit map: biomes, roads, colliding shells, flow mask.
- Location: `src/world/world_map_2d.gd`, `scenes/world/world_map_2d.tscn`
- Contains: biome table, district builders, `WorldObstacle2D` instances, 512-unit broadphase
- Depends on: atlas textures under `assets/2d/environment/`, `shaders/terrain_material_blend.gdshader`
- Used by: motion resolver, resource scatter, horde navigation, placement overlap
- Purpose: Deliver identity, weather, contact, health language, and juice without deciding rules.
- Location: `src/visual/`, `src/feedback/`, `shaders/`, `scenes/world/base_core.tscn`, `scenes/resources/`, `scenes/characters/`
- Contains: CanvasItem shaders (`blend_mix` for world subjects), `PointLight2D` with `range_z_min = -20`, Y-sorted actors
- Depends on: replicated snapshots and signals from authority
- Used by: `GameWorld` juice/VFX dispatch, `NightAtmosphere2D`
- Purpose: Workshop → PNG frames → atlas packer → runtime consumer. Provenance in JSON manifests.
- Location: `tools/art/`, `tools/asset_pipeline/`, `assets/2d/`
- Contains: Blender 5 workshops, Python renderers, Godot packers
- Depends on: CC0 Poly Haven / Kenney / Atomic Realm sources in workshops or `Addons/` vault
- Used by: `WorldObstacle2D`, ambient scenery, actor scenes, structures, HUD icons

## Data Flow

### Primary Request Path

### World Map Layout Path

| Pass | z | Y-sort | Owners |
|------|--:|--------|--------|
| Ground tiles, terrain overlay, roads | -20 | off | `GroundTiles`, `TerrainMaterialOverlay`, `WorldRoadNetwork2D` |
| Rubble, moss, ground cover, wilderness accent | -5 | off | `WorldBackgroundDecor2D`, `WorldGroundCover2D`, `WorldWildernessAccent2D` |
| Large ambient silhouettes | -4 | off | `WorldAmbientScenery2D` |
| Colliding obstacles, Base, resources, players, towers, horde | 5 | on (parent `YSortWorld`) | `WorldObstacle2D`, `base_core.tscn`, scatter, avatars, `PlacedStructure2D` |
| Projectiles | 20 | off | `ProjectilePool2D` |
| Placement preview | 60 | off | `GridPlacementController2D` |
| Weather / damage wash | CanvasLayer 50 | n/a | `WeatherOverlay` |
| HUD / touch | CanvasLayer 100 | n/a | `GameHUD`, `MobileControls` |

### Asset / Graphics Path

```text

```
| Family | Workshop / generator | Runtime atlas | Consumer |
|--------|----------------------|---------------|----------|
| Poly Haven nature/prop | `bespren_map_asset_workshop.blend`, `render_polyhaven_environment_sprites.py` | `assets/2d/environment/polyhaven/polyhaven_environment_atlas.png` | rocks, stumps, trunks, trash, tyre, barriers |
| Hidden Alley district | `bespren_polyhaven_district_workshop.blend`, `render_polyhaven_district_sprites.py` | `assets/2d/environment/polyhaven_district/polyhaven_district_atlas.png` | city/mall/village fittings, 75/46/34 furniture |
| Local Kenney / Atomic Realm | `bespren_local_environment_workshop.blend`, `render_local_environment_sprites.py` | `assets/2d/environment/local_baked/local_environment_atlas.png` | ruins, houses, wrecks, fences, camp satellites |
| Poly Haven wild | `tools/art/blender/vault/polyhaven_wild/`, `render_polyhaven_wild_sprites.py` | `assets/2d/environment/polyhaven_wild/polyhaven_wild_atlas.png` | five tree yaw frames only (`WILD_TREE_REGIONS`) |
| Poly Haven salvage | same wild runner | `assets/2d/environment/polyhaven_salvage/` | **reserve — no `src/` consumer** |
| Terrain | `bespren_terrain_material_workshop.blend`, `bake_polyhaven_terrain_materials.py` | `assets/2d/environment/terrain/polyhaven_terrain_atlas.png` | one overlay Sprite2D |
| Camp / T1 structures | `generate_camp_and_structure_sprites.py` | `assets/2d/structures/*.png` | `base_core.tscn`, `StructureCatalog` |
| Character portraits | `generate_character_sprites.py` | `assets/2d/characters/*_topdown.png` | `StartMenu.tscn` cards; gameplay uses actor bakes |
| Animated actors | `run_actor_bake.py` → `pack_actor_sheets.py` → `build_actor_sprite_frames.gd` | `assets/2d/actors/` | `PlayerAvatar`, `EnemyPresentationCatalog` |
| Shader | Job | Wearers |
|--------|-----|---------|
| `terrain_material_blend.gdshader` | Seamless biome blend + macro noise | ground overlay |
| `sleek_sprite_finish.gdshader` | Grade + screen-space `fwidth` outline | obstacles, structures, most atlas sprites |
| `sleek_canvas_grade.gdshader` | Scenery/decor grade | ambient / background / wilderness chunks |
| `toon_emissive_outline.gdshader` | Identity rim + pulse emission | Base Core, resource nodes, legacy survivor scenes |
| `surface_weathering.gdshader` | Rust / rot / patina, bounded noise, no loops | obstacle fallback draws |
| `weather_overlay.gdshader` | **Only** full-screen custom pass (rain/ash/vignette **and** damage wash) | `WeatherOverlay` |
| `volumetric_aura.gdshader` / `base_scale_glow.gdshader` | Base Core additive aura / pulse silhouette | `base_core.tscn` |
| `projectile_glow.gdshader` / `solid_white_flash.gdshader` | Tracer / hit flash | combat presentation |
| `road_surface_detail.gdshader` | Road chunk surface | `WorldRoadNetwork2D` chunks |

## Entry Points

- Location: `scenes/ui/StartMenu.tscn` (`project.godot` `run/main_scene`)
- Triggers: engine start
- Responsibilities: identity, session mode, instantiate `GameWorld`
- Location: `scenes/game/game_world.tscn`
- Triggers: `StartMenu._launch()`
- Responsibilities: map build, session start, signal graph
- Location: `scenes/main/bespren_foundation.tscn`, `scenes/showcase/visual_validation.tscn`
- Triggers: editor / validation
- Responsibilities: roster/visual contract without LAN gameplay
- Location: `tests/smoke_test.gd`, `tests/world_map_validation.gd`, `tests/world_render_validation.tscn`
- Triggers: Godot `--headless --script` or windowed scene run
- Responsibilities: contracts and 480×270 Mobile/Vulkan captures
- Location: `tools/art/run_actor_bake.py`, `tools/art/run_wild_bake.py`, `tools/art/generate_*.py`, `tools/asset_pipeline/build_*.gd`
- Triggers: developer machine with Blender 5 / Godot 4.7.1
- Responsibilities: reproducible PNG/atlas/manifest output

## Abstractions

- Location: `src/world/world_obstacle_2d.gd`
- Purpose: Single obstacle definition for physics, flow raster, and host motion. VisualKind selects atlas crop; collision stays rectangle/circle.
- Used by: `BesprenWorldMap2D` builders, walkability, flow bake
- Location: `src/coop/player_slot_definition.gd`, `src/coop/local_coop_roster.gd`
- Purpose: Seat ID, device, identity color. Max two unique seats. Do not infer a second player from two touches.
- Used by: foundation roster; shipping slice uses peer-one via ENet / offline peer
- Location: `src/tactical/structure_definition.gd`, `src/tactical/structure_catalog.gd`
- Purpose: Eight Tier-1 cards (three towers, three traps, barricade, support) with costs and textures.
- Used by: `TacticalBuildSystem`, `TacticalBuildDeck`
- Location: `src/ai/enemy_presentation_definition.gd`, `src/ai/enemy_presentation_catalog.gd`
- Purpose: Map eight simulation variant IDs to one baked actor family. `contact_offset` / `contact_radius` are sheet-pixel contact geometry, not marker-ring copies.
- Used by: `EnemyPresentation2D`, `HordeDirector`
- Location: `src/visual/actor_facing.gd`
- Purpose: Pick bake row by dot product against measured 52° camera headings, not equal 45° wedges.
- Used by: survivor and enemy baked sprites
- Location: `src/visual/ground_shadow.gd`, `src/visual/health_bar_2d.gd`
- Purpose: One contact language and one bar language. Grep for `draw_circle` / `draw_rect` health before adding a fourth copy.
- Used by: avatars, enemies, Base, `PlacedStructure2D`, obstacles, scenery
- Location: `CoopSession.set_motion_resolver()` → `GameWorld._resolve_authoritative_motion`
- Purpose: Keep `CoopSession` ignorant of map/build overlap while still clamping on the host.
- Used by: 20 Hz integration

## Architectural Constraints

- **Threading:** Single-threaded Godot main loop. No worker threads in gameplay. CPUParticles2D chosen so Vulkan and OpenGL fallback match.
- **Global state:** No production autoloads. Shared materials on `WorldObstacle2D` are static class caches (`_shared_forest_finish`, atlas frame caches) — duplicate before mutating per-instance uniforms (`CharacterPresentation` already duplicates).
- **Circular imports:** Avoid. Catalogs are `RefCounted` with lazy `_ensure_*`. Scenes preload PackedScenes; scripts use NodePaths for siblings.
- **Authority:** `CoopSession.AUTHORITY_PEER_ID` is always 1. Failed client swaps to `OfflineMultiplayerPeer` and keeps the same peer-one path.
- **Determinism:** Map seed `0xB35E7E`, scatter seed `0x5CA77E2`. Presentation layers use offset seeds so art density does not move collisions or resource IDs.
- **Mobile renderer:** Logical 480×270, `canvas_items` stretch, one custom full-screen pass, HDR 2D off, no shadow-casting 2D lights in foundation, no dynamic shader loops.
- **3D at runtime:** Forbidden. Workshops stay behind `.gdignore`. Atomic Realm-derived frames may not be redistributed as an asset pack.

## Anti-Patterns

### Game rules inside a visual driver

### `unshaded` world materials

### Linear obstacle scan on the movement tick

### Second full-screen pass for damage or weather

### Authoring outline / bar weight in texels or unscaled world units

### Matching contact radius to `marker_radius`

### Promoting atlas frames without a 1× review

## Error Handling

- Finite-vector / registered-peer / cooldown / allowed-action checks in `CoopSession`.
- Resource scatter rejects out-of-range, busy-focus, and mismatched layout snapshots (`resource_snapshot_rejected`).
- Build system emits `placement_rejected` with a `StringName` reason; HUD toasts, does not place locally.
- Walkability returns false for non-finite positions rather than clamping silently into obstacles.

## Cross-Cutting Concerns

## Where to Add New Code

- New biome / district layout: `src/world/world_map_2d.gd` (`Biome` enum, `_build_biome_cells()`, a `_build_*()` placer). Update `get_biome_regions()`, `docs/WORLD_MAP_FOUNDATION.md`, and `tests/world_map_validation.gd`. Do not move `STARTING_CAMP_POSITION` without re-running `tests/world_render_validation.tscn`.
- New colliding landmark: `_add_rectangle_obstacle` / `_add_circle_obstacle` with a `WorldObstacle2D.VisualKind`. Collision first; then atlas crop in `world_obstacle_2d.gd`.
- New non-colliding density: add to `WorldAmbientScenery2D` / `WorldGroundCover2D` / `WorldWildernessAccent2D` on a **new seed offset**. Never append to an existing sequential RNG stream that a count-asserting gate pins.
- New environment atlas family: renderer in `tools/art/`, workshop under `tools/art/blender/` (`.gdignore`), packer in `tools/asset_pipeline/`, frames + manifest under `assets/2d/environment/<family>/`, consumer Rect2 literals derived from `cell_region + padded_atlas_region`. Add a focused `tests/<family>_validation.gd`.
- New shader: `shaders/<name>.gdshader`. World subjects: `blend_mix`, `vec4 source = COLOR;`, screen-space outlines. Combine atmosphere into `weather_overlay.gdshader` rather than a new full-screen pass.
- New structure visual: `tools/art/generate_camp_and_structure_sprites.py`, PNG in `assets/2d/structures/`, entry in `src/tactical/structure_catalog.gd`, `HealthBar2D` + `GroundShadow` (no hand-rolled bar/disc).
- New actor: `tools/art/run_actor_bake.py` roster, sheets in `assets/2d/actors/`, catalog row with measured `contact_offset` / `contact_radius`. Gameplay collision stays on the simulation node, not the sprite scale.

<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->

## Project Skills

| Skill | Description | Path |
|-------|-------------|------|
| 2d-games | "2D game development principles. Sprites, tilemaps, physics, camera." | `.agents/skills/2d-games/SKILL.md` |
| game-art | "Game art principles. Visual style selection, asset pipeline, animation workflow." | `.agents/skills/game-art/SKILL.md` |
| game-audio | "Game audio principles. Sound design, music integration, adaptive audio systems." | `.agents/skills/game-audio/SKILL.md` |
| game-design | "Game design principles. GDD structure, balancing, player psychology, progression." | `.agents/skills/game-design/SKILL.md` |
| game-development | "Game development orchestrator. Routes to platform-specific skills based on project needs." | `.agents/skills/game-development/SKILL.md` |
| godot-4-migration | "Specialized guide for migrating Godot 3.x projects to Godot 4 (GDScript 2.0), covering syntax changes, Tweens, and exports." | `.agents/skills/godot-4-migration/SKILL.md` |
| godot-gdscript-patterns | "Master Godot 4 GDScript patterns including signals, scenes, state machines, and optimization. Use when building Godot games, implementing game systems, or learning GDScript best practices." | `.agents/skills/godot-gdscript-patterns/SKILL.md` |
| llm-prompt-optimizer | "Use when improving prompts for any LLM. Applies proven prompt engineering techniques to boost output quality, reduce hallucinations, and cut token usage." | `.agents/skills/llm-prompt-optimizer/SKILL.md` |
| mobile-games | "Mobile game development principles. Touch input, battery, performance, app stores." | `.agents/skills/mobile-games/SKILL.md` |
| multiplayer | "Multiplayer game development principles. Architecture, networking, synchronization." | `.agents/skills/multiplayer/SKILL.md` |
| prompt-engineering | "Expert guide on prompt engineering patterns, best practices, and optimization techniques. Use when user wants to improve prompts, learn prompting strategies, or debug agent behavior." | `.agents/skills/prompt-engineering/SKILL.md` |
| prompt-library | "A comprehensive collection of battle-tested prompts inspired by [awesome-chatgpt-prompts](https://github.com/f/awesome-chatgpt-prompts) and community best practices." | `.agents/skills/prompt-library/SKILL.md` |
| threejs-animation | Three.js animation - keyframe animation, skeletal animation, morph targets, animation mixing. Use when animating objects, playing GLTF animations, creating procedural motion, or blending animations. | `.agents/skills/threejs-animation/SKILL.md` |
| threejs-fundamentals | Three.js scene setup, cameras, renderer, Object3D hierarchy, coordinate systems. Use when setting up 3D scenes, creating cameras, configuring renderers, managing object hierarchies, or working with transforms. | `.agents/skills/threejs-fundamentals/SKILL.md` |
| threejs-geometry | Three.js geometry creation - built-in shapes, BufferGeometry, custom geometry, instancing. Use when creating 3D shapes, working with vertices, building custom meshes, or optimizing with instanced rendering. | `.agents/skills/threejs-geometry/SKILL.md` |
| threejs-interaction | Three.js interaction - raycasting, controls, mouse/touch input, object selection. Use when handling user input, implementing click detection, adding camera controls, or creating interactive 3D experiences. | `.agents/skills/threejs-interaction/SKILL.md` |
| threejs-lighting | Three.js lighting - light types, shadows, environment lighting. Use when adding lights, configuring shadows, setting up IBL, or optimizing lighting performance. | `.agents/skills/threejs-lighting/SKILL.md` |
| threejs-loaders | Three.js asset loading - GLTF, textures, images, models, async patterns. Use when loading 3D models, textures, HDR environments, or managing loading progress. | `.agents/skills/threejs-loaders/SKILL.md` |
| threejs-materials | Three.js materials - PBR, basic, phong, shader materials, material properties. Use when styling meshes, working with textures, creating custom shaders, or optimizing material performance. | `.agents/skills/threejs-materials/SKILL.md` |
| threejs-postprocessing | Three.js post-processing - EffectComposer, bloom, DOF, screen effects. Use when adding visual effects, color grading, blur, glow, or creating custom screen-space shaders. | `.agents/skills/threejs-postprocessing/SKILL.md` |
| threejs-shaders | Three.js shaders - GLSL, ShaderMaterial, uniforms, custom effects. Use when creating custom visual effects, modifying vertices, writing fragment shaders, or extending built-in materials. | `.agents/skills/threejs-shaders/SKILL.md` |
| threejs-skills | "Create 3D scenes, interactive experiences, and visual effects using Three.js. Use when user requests 3D graphics, WebGL experiences, 3D visualizations, animations, or interactive 3D elements." | `.agents/skills/threejs-skills/SKILL.md` |
| threejs-textures | Three.js textures - texture types, UV mapping, environment maps, texture settings. Use when working with images, UV coordinates, cubemaps, HDR environments, or texture optimization. | `.agents/skills/threejs-textures/SKILL.md` |
| typescript-advanced-types | "Comprehensive guidance for mastering TypeScript's advanced type system including generics, conditional types, mapped types, template literal types, and utility types for building robust, type-safe applications." | `.agents/skills/typescript-advanced-types/SKILL.md` |
| typescript-expert | TypeScript and JavaScript expert with deep knowledge of type-level programming, performance optimization, monorepo management, migration strategies, and modern tooling. | `.agents/skills/typescript-expert/SKILL.md` |
| typescript-pro | Master TypeScript with advanced types, generics, and strict type safety. Handles complex type systems, decorators, and enterprise-grade patterns. | `.agents/skills/typescript-pro/SKILL.md` |
| ue-actor-component-architecture | "Use this skill when working with Actor and component design in Unreal Engine. Triggers on: Actor, component, BeginPlay, Tick, SpawnActor, lifecycle, CreateDefaultSubobject, composition, EndPlay, PostInitializeComponents, UActorComponent, USceneComponent, UINTERFACE, attachment, spawn, interface. See references/actor-lifecycle.md and references/component-types.md for detailed tables." | `.agents/skills/ue-actor-component-architecture/SKILL.md` |
| ue-ai-navigation | "Use this skill when implementing AI, AIController, behavior tree, blackboard, AI perception, NavMesh, EQS, navigation, pathfinding, State Tree, or Smart Objects in Unreal Engine. See references/behavior-tree-patterns.md for BT patterns and references/eqs-reference.md for EQS configuration. For AI ability use, see ue-gameplay-abilities." | `.agents/skills/ue-ai-navigation/SKILL.md` |
| ue-animation-system | "Use this skill when working with Unreal Engine animation: AnimInstance, montage playback, blend space, state machine, anim notify, IK, AnimGraph, skeletal mesh, or linked anim graphs. See references/anim-notify-reference.md for notify patterns and references/locomotion-setup.md for locomotion setup. For montage integration with GAS, see ue-gameplay-abilities." | `.agents/skills/ue-animation-system/SKILL.md` |
| ue-async-threading | "Use this skill when working with Unreal Engine async operations, threading, parallel execution, or concurrency. Also use when the user mentions 'FRunnable', 'FAsyncTask', 'TaskGraph', 'UE::Tasks', 'ParallelFor', 'TFuture', 'TPromise', 'Async()', 'thread safety', 'FCriticalSection', 'FRWLock', 'background thread', 'game thread dispatch', or 'thread pool'. For networking async (RPCs, replication), see ue-networking-replication. For asset streaming, see ue-data-assets-tables." | `.agents/skills/ue-async-threading/SKILL.md` |
| ue-audio-system | "Use this skill when working with audio, sound, music, UAudioComponent, PlaySoundAtLocation, SoundCue, MetaSound, attenuation, submix, concurrency, SFX, or spatial audio in Unreal Engine. See references/audio-setup-patterns.md for music system and ambient soundscape architectures. For VFX audio synchronization, see ue-niagara-effects." | `.agents/skills/ue-audio-system/SKILL.md` |
| ue-character-movement | "Use this skill when working with character movement, CharacterMovementComponent, CMC, movement modes, walking, falling, swimming, flying, custom movement, network prediction, FSavedMove, root motion, floor detection, step-up, or character physics. Also use for 'PhysWalking', 'PhysCustom', 'LaunchCharacter', 'WalkableFloor', or 'movement replication'. See references/ for CMC extension patterns and movement pipeline details." | `.agents/skills/ue-character-movement/SKILL.md` |
| ue-cpp-foundations | Use when writing Unreal Engine C++ code involving UPROPERTY, UFUNCTION, UCLASS, TArray, TMap, delegates, FString, garbage collection, or smart pointers. Also use when the user asks about "UE C++", USTRUCT, UENUM, FName, FText, TObjectPtr, TWeakObjectPtr, UObject lifetime, UE_LOG, or UE subsystems. For module build configuration, see ue-module-build-system. For Actor/Component architecture, see ue-actor-component-architecture. | `.agents/skills/ue-cpp-foundations/SKILL.md` |
| ue-data-assets-tables | "Use when working with DataAsset, DataTable, soft reference, hard reference, TSoftObjectPtr, async loading, Asset Manager, StreamableManager, or game data structures in Unreal Engine. See references/asset-loading-patterns.md for async loading and StreamableManager patterns. See references/data-driven-design.md for data-driven gameplay architecture. For serialization, see ue-serialization-savegames. For C++ foundations, see ue-cpp-foundations." | `.agents/skills/ue-data-assets-tables/SKILL.md` |
| ue-editor-tools | "Use when extending the Unreal Editor with editor tool, editor utility widget, Blutility, detail customization, property customization, editor mode, asset editor, editor subsystem, editor extension, UToolMenus, or scripted asset operations. For Slate fundamentals, see ue-ui-umg-slate. For module build config, see ue-module-build-system." | `.agents/skills/ue-editor-tools/SKILL.md` |
| ue-game-features | "Use this skill when working with Game Feature plugins, modular gameplay, GameFeatureAction, GameFeatureData, GameFrameworkComponentManager, init state system, experience system, modular components, UPawnComponent, UControllerComponent, UGameStateComponent, UPlayerStateComponent, or Lyra-style modular architecture. See references/ for code templates and experience system patterns." | `.agents/skills/ue-game-features/SKILL.md` |
| ue-gameplay-abilities | "Use this skill when working with GAS, Gameplay Ability System, GameplayAbility, GameplayEffect, AttributeSet, GameplayTags, ability system, buffs, debuffs, cooldowns, or attribute modification. See references/ for detailed setup patterns, effect configuration, and ability task usage." | `.agents/skills/ue-gameplay-abilities/SKILL.md` |
| ue-gameplay-framework | "Use this skill when working with Unreal Engine's gameplay framework classes: GameMode, GameState, PlayerController, PlayerState, Pawn, Character, or GameInstance. Also use when the user mentions 'gameplay framework', 'game rules', 'player management', 'match flow', or 'player spawning'. See references/framework-class-map.md for the full authority/presence matrix. For networking/replication, see ue-networking-replication. For input setup, see ue-input-system." | `.agents/skills/ue-gameplay-framework/SKILL.md` |
| ue-input-system | "Use this skill when implementing player input with Unreal Engine's Enhanced Input system. Also use when the user mentions 'Enhanced Input', 'input', 'input action', 'InputAction', 'mapping context', 'InputMappingContext', 'input binding', 'key binding', 'input trigger', 'input modifier', 'gamepad', or 'keyboard'. Covers ETriggerEvent, built-in triggers (Hold, Tap, Pulse, ChordAction, Combo), built-in modifiers (DeadZone, Scalar, Negate, SwizzleAxis), and custom trigger/modifier authoring. See references/input-action-reference.md for the full catalogue. For UI input modes, see ue-ui-umg-slate." | `.agents/skills/ue-input-system/SKILL.md` |
| ue-mass-entity | "Use this skill when working with Mass Entity, MassEntity, Mass AI, MassProcessor, MassFragment, MassTag, MassObserver, MassSpawner, MassCrowd, Mass ECS, entity archetype, ForEachEntityChunk, FMassEntityQuery, FMassEntityManager, ISM crowd, or large-scale entity simulation in Unreal Engine. See references/mass-entity-patterns.md for processor and observer templates. See references/mass-fragment-reference.md for built-in fragment types." | `.agents/skills/ue-mass-entity/SKILL.md` |
| ue-materials-rendering | "Use when the user is working with material, shader, MID, dynamic material, material instance, post-process, render target, parameter collection, decal, Nanite, Lumen, or rendering in Unreal Engine. See references/material-parameter-reference.md for parameter patterns and references/post-process-settings.md for post-process settings. For particle rendering, see ue-niagara-effects." | `.agents/skills/ue-materials-rendering/SKILL.md` |
| ue-module-build-system | Use when working with Build.cs, Target.cs, module creation, plugin setup, or build errors in Unreal Engine — including "unresolved external symbol," "cannot open include file," IWYU violations, missing API macros, or dependency configuration. See also ue-cpp-foundations for UObject macro patterns. | `.agents/skills/ue-module-build-system/SKILL.md` |
| ue-networking-replication | "Use this skill when working on multiplayer networking, replication, RPC calls, net role logic, server/client authority, prediction, or synchronizing game state. Also use when the user mentions 'DOREPLIFETIME', 'dedicated server', 'replicated', or 'net role'. See references/replication-patterns.md for common patterns and references/rpc-decision-guide.md for RPC type selection. For GAS networking, see ue-gameplay-abilities." | `.agents/skills/ue-networking-replication/SKILL.md` |
| ue-niagara-effects | "Use this skill when working with Niagara particle systems, VFX, effects, emitter, Niagara component, or Niagara parameter in Unreal Engine C++. Covers spawning systems, setting parameters, data interfaces (SkeletalMesh, StaticMesh, Curve, Array), OnSystemFinished delegate, and performance tuning. See references/niagara-parameter-types.md for type mapping and references/niagara-data-interfaces.md for data interface catalogue. For particle materials, see ue-materials-rendering." | `.agents/skills/ue-niagara-effects/SKILL.md` |
| ue-physics-collision | "Use when implementing collision detection, trace queries, physics simulation, or physical interactions in Unreal Engine. Triggers on: 'collision', 'trace', 'LineTrace', 'line trace', 'overlap', 'physics', 'hit result', 'sweep', 'collision channel', 'physics body', 'Chaos', 'raytrace', 'OnHit', 'OnBeginOverlap'. See related skills for component architecture and AI navigation." | `.agents/skills/ue-physics-collision/SKILL.md` |
| ue-procedural-generation | "Use this skill when working with procedural generation in Unreal Engine: PCG framework, ProceduralMesh, instanced mesh, HISM, spline, runtime mesh, noise, terrain generation, or dungeon generation. See references/pcg-node-reference.md for PCG node types and references/procedural-mesh-patterns.md for mesh generation patterns. For physics on procedural geometry, see ue-physics-collision." | `.agents/skills/ue-procedural-generation/SKILL.md` |
| ue-project-context | "When the user wants to create or update their Unreal Engine project context document. Use when the user says 'project context,' 'set up context,' 'UE context,' 'configure project,' or wants to avoid repeating their project setup across UE development tasks. Creates `.agents/ue-project-context.md` that all other UE skills reference. See related skills footer for skills that depend on this context." | `.agents/skills/ue-project-context/SKILL.md` |
| ue-sequencer-cinematics | "Use this skill when working with Sequencer, LevelSequence, cutscene, cinematic, camera, movie scene, sequencer event, or Movie Render Queue in Unreal Engine. See references/sequencer-patterns.md for dialogue cutscene, in-game camera, and scripted event patterns. For animation playback, see ue-animation-system." | `.agents/skills/ue-sequencer-cinematics/SKILL.md` |
| ue-serialization-savegames | "Use when implementing save/load systems, player progress persistence, or data serialization in Unreal Engine. Triggers on: save game, USaveGame, FArchive, serialization, SaveGameToSlot, config, persist data, save file, load game. See references/save-system-architecture.md for full slot management and multi-user patterns." | `.agents/skills/ue-serialization-savegames/SKILL.md` |
| ue-state-trees | "Use this skill when working with State Tree, StateTree, UStateTree, state machine, StateTreeTask, StateTreeCondition, StateTreeEvaluator, StateTreeSchema, AI State Tree, Mass StateTree, FStateTreeExecutionContext, or data-driven state logic in Unreal Engine. See references/state-tree-patterns.md for task/condition/evaluator templates and references/state-tree-mass-integration.md for Mass Entity integration." | `.agents/skills/ue-state-trees/SKILL.md` |
| ue-testing-debugging | Use when writing automation tests, functional tests, or any test in Unreal Engine. Also use when the user asks about "UE_LOG", logging, log categories, assertion, check, ensure, verify, DrawDebug, debug draw, console command, profiling, Unreal Insights, stat commands, or debugging techniques. See ue-module-build-system for test module setup, and ue-cpp-foundations for general C++ logging patterns. | `.agents/skills/ue-testing-debugging/SKILL.md` |
| ue-ui-umg-slate | "Use this skill when working with UMG, UI, widget, UserWidget, Slate, HUD, BindWidget, Common UI, menu, or UMG binding in Unreal Engine. See references/widget-types.md for widget type reference and references/common-ui-setup.md for Common UI plugin setup. For Slate in editor tools, see ue-editor-tools. For input mode management, see ue-input-system." | `.agents/skills/ue-ui-umg-slate/SKILL.md` |
| ue-world-level-streaming | "Use this skill when working with World Partition, level streaming, level travel, OpenLevel, ServerTravel, data layer, world subsystem, level instance, sub-level, seamless travel, open world, or HLOD. See references/streaming-patterns.md for configuration patterns by game type." | `.agents/skills/ue-world-level-streaming/SKILL.md` |
| vibe-code-auditor | Audit rapidly generated or AI-produced code for structural flaws, fragility, and production risks. | `.agents/skills/vibe-code-auditor/SKILL.md` |
| web-games | "Web browser game development principles. Framework selection, WebGPU, optimization, PWA." | `.agents/skills/web-games/SKILL.md` |
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->

## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:

- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->

## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
