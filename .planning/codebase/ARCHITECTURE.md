<!-- refreshed: 2026-09-18 -->
# Architecture

**Analysis Date:** 2026-09-18

## System Overview

```text
┌─────────────────────────────────────────────────────────────────────────┐
│  Boot / identity                                                         │
│  `scenes/ui/StartMenu.tscn`  →  `src/ui/start_menu.gd`                   │
│  Heikki | Shane  +  Solo / Host LAN / Join LAN                           │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │ instantiate + configure_launch()
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Composition root  `scenes/game/game_world.tscn`  `src/game/game_world.gd`│
│  No autoloads. Unique-name children. Cross-domain via signals / Callables│
├──────────────┬──────────────┬──────────────┬──────────────┬─────────────┤
│ Input / HUD  │ Authority    │ World layout │ Combat / AI  │ Feedback    │
│ `MobileCtrl` │ `CoopSession`│ `WorldMap2D` │ `HordeDir`   │ `VfxDirector`│
│ `GameHUD`    │ `TacticalBld`│ `ResourceSc` │ `CombatState`│ `JuiceRig`  │
│ `src/input`  │ `src/coop`   │ `src/world`  │ `src/ai`     │ `src/visual`│
│ `src/ui`     │ `src/tactical`│ `base_core` │ `src/combat` │ `src/feedback`│
└──────┬───────┴──────┬───────┴──────┬───────┴──────┬───────┴──────┬──────┘
       │              │              │              │              │
       ▼              ▼              ▼              ▼              ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌─────┐
│ Touch / kbd  │ │ Peer-one     │ │ 14×14 map    │ │ 20 Hz state  │ │ HUD │
│ 8-way stick  │ │ ENet :8791   │ │ obstacles    │ │ projectiles  │ │ L100│
│ Interact/Fire│ │ OfflinePeer  │ │ flow mask    │ │ towers/traps │ │ L50 │
└──────────────┘ └──────┬───────┘ └──────┬───────┘ └──────────────┘ └─────┘
                        │                │
                        ▼                ▼
              Host-validated Vector2     CanvasItem world
              + shared resource pool     z -20 / -5 / -4 / 5
                                         shaders/ + assets/2d/
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

**Overall:** Scene composition root + host-authoritative simulation, with a strict presentation/authority split.

**Key Characteristics:**
- No autoloads. Systems live as unique-name children of `GameWorld` (`scenes/game/game_world.tscn`).
- Peer one owns movement, gather, fire, build, day/night, horde, and health. Clients submit intents (`rpc_id(1)`); they interpolate snapshots.
- Visual drivers (`src/visual/`, `src/feedback/`) report simulation. They never write health, yield, occupancy, or authoritative position.
- World layout is deterministic from `WORLD_BUILD_SEED` (`0xB35E7E` in `src/world/world_map_2d.gd`). Presentation layers seed independently so density retunes do not move collisions.
- Runtime art is 2D only. Blender workshops bake PNG/atlas families; no `Node3D`, GLTF, or PBR graph ships.
- Typed GDScript: `class_name`, typed arrays/signals, `untyped_declaration = 2` in `project.godot`.

## Layers

**Boot / identity:**
- Purpose: Pick Heikki or Shane and Solo/Host/Join before `GameWorld` enters the tree.
- Location: `scenes/ui/StartMenu.tscn`, `src/ui/start_menu.gd`
- Contains: Character cards (legacy 320 px portraits), session buttons, safe-area layout.
- Depends on: `CoopSession.SessionMode`, `scenes/game/game_world.tscn`
- Used by: `project.godot` `run/main_scene`

**Composition:**
- Purpose: Wire domains through NodePaths and signals; never fold gameplay into the menu.
- Location: `scenes/game/game_world.tscn`, `src/game/game_world.gd`
- Contains: Unique-name children (`%WorldMap2D`, `%CoopSession`, `%TacticalBuildSystem`, …)
- Depends on: every domain below
- Used by: `StartMenu._launch()`

**Authority / simulation:**
- Purpose: Validate and mutate shared state on peer one.
- Location: `src/coop/`, `src/tactical/`, `src/world/resource_scatter_2d.gd`, `src/game/combat_state_coordinator.gd`, `src/ai/horde_director.gd`, `src/game/day_night_cycle.gd`
- Contains: RPC controllers, catalogs (`StructureCatalog`, `EnemyPresentationCatalog`), flow field
- Depends on: `BesprenWorldMap2D` walkability / obstacles
- Used by: `GameWorld` resolvers and HUD command path

**World layout:**
- Purpose: Author the 28,672-unit map: biomes, roads, colliding shells, flow mask.
- Location: `src/world/world_map_2d.gd`, `scenes/world/world_map_2d.tscn`
- Contains: biome table, district builders, `WorldObstacle2D` instances, 512-unit broadphase
- Depends on: atlas textures under `assets/2d/environment/`, `shaders/terrain_material_blend.gdshader`
- Used by: motion resolver, resource scatter, horde navigation, placement overlap

**Presentation / graphics:**
- Purpose: Deliver identity, weather, contact, health language, and juice without deciding rules.
- Location: `src/visual/`, `src/feedback/`, `shaders/`, `scenes/world/base_core.tscn`, `scenes/resources/`, `scenes/characters/`
- Contains: CanvasItem shaders (`blend_mix` for world subjects), `PointLight2D` with `range_z_min = -20`, Y-sorted actors
- Depends on: replicated snapshots and signals from authority
- Used by: `GameWorld` juice/VFX dispatch, `NightAtmosphere2D`

**Offline art pipeline:**
- Purpose: Workshop → PNG frames → atlas packer → runtime consumer. Provenance in JSON manifests.
- Location: `tools/art/`, `tools/asset_pipeline/`, `assets/2d/`
- Contains: Blender 5 workshops, Python renderers, Godot packers
- Depends on: CC0 Poly Haven / Kenney / Atomic Realm sources in workshops or `Addons/` vault
- Used by: `WorldObstacle2D`, ambient scenery, actor scenes, structures, HUD icons

## Data Flow

### Primary Request Path

1. `StartMenu._launch()` instantiates `scenes/game/game_world.tscn` and calls `configure_launch()` (`src/ui/start_menu.gd:451`).
2. `GameWorld._ready()` builds the map, scatters resources, binds session resolvers, then starts Solo/Host/Client (`src/game/game_world.gd:102`).
3. Touch/keyboard movement merges in `_physics_process`; `session.submit_movement()` (`src/game/game_world.gd:158`). Interact/Fire go through `submit_interaction` (`src/game/game_world.gd:189`).
4. Peer one integrates at 20 Hz. Motion uses `GameWorld._resolve_authoritative_motion` → `TacticalBuildSystem.resolve_player_motion` → `BesprenWorldMap2D.resolve_player_motion` (playable clamp + axis slide + obstacle broadphase) (`src/world/world_map_2d.gd:352`).
5. Fire uses `AutoAimController2D.get_firing_direction()`; host-recorded facing is what every peer draws (`src/game/game_world.gd:208`).
6. `PlayerAvatar` follows the snapshot with `move_and_slide()`; baked `AnimatedSprite2D` + `ActorFacing` pick the heading row. Collision radius stays 9 (`scenes/characters/network_player.tscn`).
7. Feedback listens: `VfxDirector` bursts, `CameraShake2D` trauma, `WeatherOverlay.flash()`, `HealthBar2D.set_health()`. None of these write simulation.

### World Map Layout Path

1. `BesprenWorldMap2D.ensure_built()` is idempotent (`src/world/world_map_2d.gd:115`).
2. `_build_biome_cells()` fills 14×14: default wilderness; perimeter + NE/W belts forest; cells (1–5,1–5) city; (7–10,2–5) mall; (1–4,9–12) west village; (9–12,9–12) east village (`src/world/world_map_2d.gd:375`). Public names: Kaupunki / Ostari / Kylät / Metsä-Luonto via `get_biome_regions()` (`src/world/world_map_2d.gd:185`).
3. Ground `TileMapLayer` + `TerrainMaterialOverlay` (`terrain_material_blend.gdshader` over `polyhaven_terrain_atlas.png` + `bespren_biome_blend_mask.png`) sit at `z_index = -20`, `z_as_relative = false` (`scenes/world/world_map_2d.tscn`).
4. `_build_road_network()` installs eight authored polylines (asphalt cross, district branches, dirt villages, wilderness perimeter) (`src/world/world_map_2d.gd:467`). Camp at `STARTING_CAMP_POSITION = (9950, 2400)` keeps ≥1600 units from every road edge.
5. District builders place `WorldObstacle2D` rectangles/circles on `WorldStatic` (layer 2): city shells, Ostari mall, villages, fences, camp satellites, dense landmarks, forest trees (`src/world/world_map_2d.gd:484` onward). Collision shape is canonical; atlas sprites are presentation-only.
6. Presentation layers configure **after** obstacles and flow bake, on separate seeds: background decor (`WORLD_BUILD_SEED+91`), ambient scenery (`+137`), wilderness accent (`+173`), ground cover (`+211`). They receive `is_position_walkable` and `get_minimum_road_edge_distance` Callables and must not mutate them.
7. `_bake_flow_field_mask()` rasterizes 112×112 cells at 256 units with agent radius 34 (`src/world/world_map_2d.gd:993`). `set_core_position()` rebakes when the Base relocates.
8. `is_position_walkable()` queries a 512-unit obstacle broadphase, pads by `clearance * sqrt(2)`, then exact `contains_world_point` (`src/world/world_map_2d.gd:295`). Do not replace this with a linear scan.

**Rendering matrix (absolute, `z_as_relative = false`):**

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

World `PointLight2D` nodes set `range_z_min = -20` so the ground pass receives light (`scenes/world/base_core.tscn`, `scenes/characters/network_player.tscn`, `src/tactical/placed_structure_2d.gd`).

### Asset / Graphics Path

```text
Addons/ vault (.gdignore, never res:// runtime)
        │ audit_and_extract_runtime_assets.py  →  assets/runtime_asset_manifest.json
        ▼
Blender 5 workshops (tools/art/blender/*.blend)  +  Python renderers (tools/art/*.py)
        │ isolated scene, ortho three-quarter, Freestyle, AgX, transparent PNG
        ▼
Per-family frames under assets/2d/environment/<family>/ or assets/2d/{structures,characters,actors}/
        │ Godot packers in tools/asset_pipeline/build_*_atlas.gd / build_actor_sprite_frames.gd
        ▼
Atlas PNG + manifest JSON (SHA-256, regions, licenses)
        ▼
Runtime consumers:
  WorldObstacle2D / WorldAmbientSceneryChunk2D  — cropped AtlasTexture + sleek_sprite_finish
  TerrainMaterialOverlay                         — terrain_material_blend
  PlacedStructure2D / base_core.tscn             — camp/structure bakes + toon / sleek
  PlayerAvatar / EnemyPresentation2D             — baked SpriteFrames, ActorFacing rows
  ResourceNodeView                               — SVG icons + toon_emissive_outline
```

**Shipped atlas families:**

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

**Shader family (put new world materials in `shaders/`, `blend_mix`, `COLOR` is already textured):**

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

Do not use `render_mode unshaded` on world subjects: it exempts them from `CanvasModulate` and `PointLight2D`. The weather overlay is the exception (`unshaded, blend_mix`). Outline widths are screen pixels via `fwidth(UV) * width * stretch` against logical 480, not `TEXTURE_PIXEL_SIZE`.

## Entry Points

**Application boot:**
- Location: `scenes/ui/StartMenu.tscn` (`project.godot` `run/main_scene`)
- Triggers: engine start
- Responsibilities: identity, session mode, instantiate `GameWorld`

**Gameplay composition:**
- Location: `scenes/game/game_world.tscn`
- Triggers: `StartMenu._launch()`
- Responsibilities: map build, session start, signal graph

**Foundation / art-direction showcase (not shipping level):**
- Location: `scenes/main/bespren_foundation.tscn`, `scenes/showcase/visual_validation.tscn`
- Triggers: editor / validation
- Responsibilities: roster/visual contract without LAN gameplay

**Headless / GPU gates:**
- Location: `tests/smoke_test.gd`, `tests/world_map_validation.gd`, `tests/world_render_validation.tscn`
- Triggers: Godot `--headless --script` or windowed scene run
- Responsibilities: contracts and 480×270 Mobile/Vulkan captures

**Offline bake:**
- Location: `tools/art/run_actor_bake.py`, `tools/art/run_wild_bake.py`, `tools/art/generate_*.py`, `tools/asset_pipeline/build_*.gd`
- Triggers: developer machine with Blender 5 / Godot 4.7.1
- Responsibilities: reproducible PNG/atlas/manifest output

## Abstractions

**`WorldObstacle2D`:**
- Location: `src/world/world_obstacle_2d.gd`
- Purpose: Single obstacle definition for physics, flow raster, and host motion. VisualKind selects atlas crop; collision stays rectangle/circle.
- Used by: `BesprenWorldMap2D` builders, walkability, flow bake

**`PlayerSlotDefinition` / `LocalCoopRoster`:**
- Location: `src/coop/player_slot_definition.gd`, `src/coop/local_coop_roster.gd`
- Purpose: Seat ID, device, identity color. Max two unique seats. Do not infer a second player from two touches.
- Used by: foundation roster; shipping slice uses peer-one via ENet / offline peer

**`StructureDefinition` / `StructureCatalog`:**
- Location: `src/tactical/structure_definition.gd`, `src/tactical/structure_catalog.gd`
- Purpose: Eight Tier-1 cards (three towers, three traps, barricade, support) with costs and textures.
- Used by: `TacticalBuildSystem`, `TacticalBuildDeck`

**`EnemyPresentationDefinition` / `EnemyPresentationCatalog`:**
- Location: `src/ai/enemy_presentation_definition.gd`, `src/ai/enemy_presentation_catalog.gd`
- Purpose: Map eight simulation variant IDs to one baked actor family. `contact_offset` / `contact_radius` are sheet-pixel contact geometry, not marker-ring copies.
- Used by: `EnemyPresentation2D`, `HordeDirector`

**`ActorFacing`:**
- Location: `src/visual/actor_facing.gd`
- Purpose: Pick bake row by dot product against measured 52° camera headings, not equal 45° wedges.
- Used by: survivor and enemy baked sprites

**`GroundShadow` / `HealthBar2D`:**
- Location: `src/visual/ground_shadow.gd`, `src/visual/health_bar_2d.gd`
- Purpose: One contact language and one bar language. Grep for `draw_circle` / `draw_rect` health before adding a fourth copy.
- Used by: avatars, enemies, Base, `PlacedStructure2D`, obstacles, scenery

**Motion resolver Callable:**
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

**What happens:** `CorePulseDriver`, `ResourceNodeView`, `CharacterPresentation`, `VfxDirector`, or `WeatherOverlay` start owning health, yield, occupancy, or fire direction.
**Why it's wrong:** Clients would simulate divergently; late-join snapshots would fight local tweens; CLAUDE.md 7 forbids feedback deciding the sim.
**Do this instead:** Authority node emits a signal; the visual node applies uniforms/tweens. Example: scatter mutates progress, then `ResourceNodeView.apply_harvest_progress()`.

### `unshaded` world materials

**What happens:** CanvasItem stays at daylight value after `NightAtmosphere2D` drops `CanvasModulate`.
**Why it's wrong:** Camp, props, and structures read as decals pasted on a night map.
**Do this instead:** `render_mode blend_mix`. Entry `COLOR` is already `texture * modulate` — assign `vec4 source = COLOR;`, never `texture(TEXTURE, UV) * COLOR`.

### Linear obstacle scan on the movement tick

**What happens:** `is_position_walkable` walks all ~461 obstacles per call.
**Why it's wrong:** Up to three calls per player per 20 Hz tick; measured ~25 ms/s of wall clock.
**Do this instead:** Keep the 512-unit broadphase in `BesprenWorldMap2D` (`src/world/world_map_2d.gd:326`). Invalidate `_obstacle_broadphase_ready` when obstacles are added.

### Second full-screen pass for damage or weather

**What happens:** Extra ColorRect / post-process for hit vignette.
**Why it's wrong:** Mobile budget is one custom full-screen pass (`CLAUDE.md` §10).
**Do this instead:** Raise `damage` on `shaders/weather_overlay.gdshader` through `WeatherOverlay.flash()`.

### Authoring outline / bar weight in texels or unscaled world units

**What happens:** `TEXTURE_PIXEL_SIZE * outline_width` or `_pixel()` ignoring owner scale.
**Why it's wrong:** Placed traps drew 0.13 px contours; Base bar outlines doubled under `scale = Vector2(2, 2)`.
**Do this instead:** `fwidth` + logical-480 stretch in shaders; `HealthBar2D._pixel()` divides owner scale out.

### Matching contact radius to `marker_radius`

**What happens:** Enemy shadows sized from the threat ring.
**Why it's wrong:** Ring language is UI, not stance; spread across the cast was 2.7×.
**Do this instead:** Set `EnemyPresentationDefinition.contact_radius` from silhouette measurements. Survivors use `ActorGroundShadow2D.base_radius = 16.0` in `network_player.tscn`.

### Promoting atlas frames without a 1× review

**What happens:** Wild non-tree frames (roots, shrubs) enter `WorldObstacle2D` / scenery because the packer succeeded.
**Why it's wrong:** `existing_wild_atlas_context_validation` records `runtime_promotion = forbidden_pending_human_visual_veto`. Composition at 256 px does not read at ~126 delivered px.
**Do this instead:** Only the five `WILD_TREE_REGIONS` Rect2 literals ship. New regions must match `cell_region.xy + padded_atlas_region.xy` from the manifest and pass a 1× capture review.

## Error Handling

**Strategy:** Host rejects illegal intents; clients keep last good snapshot. Visual systems fail closed (drop ambient VFX when pool is busy).

**Patterns:**
- Finite-vector / registered-peer / cooldown / allowed-action checks in `CoopSession`.
- Resource scatter rejects out-of-range, busy-focus, and mismatched layout snapshots (`resource_snapshot_rejected`).
- Build system emits `placement_rejected` with a `StringName` reason; HUD toasts, does not place locally.
- Walkability returns false for non-finite positions rather than clamping silently into obstacles.

## Cross-Cutting Concerns

**Logging:** `push_error` / HUD status strings. No telemetry service.

**Validation:** Headless `tests/*_validation.gd` plus GPU `tests/*_render_validation.tscn`. World layout contract: `tests/world_map_validation.gd`. Pixel contract: `tests/world_render_validation.tscn` (25 captures at 480×270).

**Authentication:** None. LAN ENet on UDP 8791, no accounts.

**Accessibility:** Identity redundant across hue, silhouette, iconography, placement. Weather / shake / pulse / damage wash expose a 0–1 scale where 0 means absent (`WeatherOverlay.damage_intensity_scale`, `CameraShake2D` intensity).

## Where to Add New Code

- New biome / district layout: `src/world/world_map_2d.gd` (`Biome` enum, `_build_biome_cells()`, a `_build_*()` placer). Update `get_biome_regions()`, `docs/WORLD_MAP_FOUNDATION.md`, and `tests/world_map_validation.gd`. Do not move `STARTING_CAMP_POSITION` without re-running `tests/world_render_validation.tscn`.
- New colliding landmark: `_add_rectangle_obstacle` / `_add_circle_obstacle` with a `WorldObstacle2D.VisualKind`. Collision first; then atlas crop in `world_obstacle_2d.gd`.
- New non-colliding density: add to `WorldAmbientScenery2D` / `WorldGroundCover2D` / `WorldWildernessAccent2D` on a **new seed offset**. Never append to an existing sequential RNG stream that a count-asserting gate pins.
- New environment atlas family: renderer in `tools/art/`, workshop under `tools/art/blender/` (`.gdignore`), packer in `tools/asset_pipeline/`, frames + manifest under `assets/2d/environment/<family>/`, consumer Rect2 literals derived from `cell_region + padded_atlas_region`. Add a focused `tests/<family>_validation.gd`.
- New shader: `shaders/<name>.gdshader`. World subjects: `blend_mix`, `vec4 source = COLOR;`, screen-space outlines. Combine atmosphere into `weather_overlay.gdshader` rather than a new full-screen pass.
- New structure visual: `tools/art/generate_camp_and_structure_sprites.py`, PNG in `assets/2d/structures/`, entry in `src/tactical/structure_catalog.gd`, `HealthBar2D` + `GroundShadow` (no hand-rolled bar/disc).
- New actor: `tools/art/run_actor_bake.py` roster, sheets in `assets/2d/actors/`, catalog row with measured `contact_offset` / `contact_radius`. Gameplay collision stays on the simulation node, not the sprite scale.

---

*Architecture analysis: 2026-09-18*
