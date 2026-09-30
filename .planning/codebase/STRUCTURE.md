# Project Structure

**Analysis Date:** 2026-09-18

## Directory Layout

```text
gpt_peli/
├── project.godot                 # Bespren, main_scene StartMenu, 480×270, Mobile
├── CLAUDE.md                     # Living GDD / architecture contract
├── export_presets.cfg
├── scenes/                       # Packed shipping + showcase scenes
│   ├── ui/                       # StartMenu, GameHUD, MobileControls, build deck
│   ├── game/                     # game_world.tscn composition root
│   ├── world/                    # world_map_2d, base_core, resource_scatter
│   ├── characters/               # network_player + legacy heikki/shane
│   ├── resources/                # wood/metal/tech node scenes
│   ├── combat/                   # player_projectile.tscn
│   ├── showcase/                 # visual_validation.tscn (not a level)
│   ├── main/                     # bespren_foundation.tscn
│   └── build/                    # runtime_export_dependencies.tscn
├── src/                          # Typed GDScript, class_name per file
│   ├── core/                     # BesprenBootstrap
│   ├── coop/                     # Session, roster, seat definition
│   ├── game/                     # GameWorld, PlayerAvatar, day/night, combat state
│   ├── world/                    # Map, obstacles, roads, scatter, decor layers
│   ├── tactical/                 # Build, catalog, placement, towers
│   ├── combat/                   # Auto-aim, projectile, pool
│   ├── ai/                       # Horde, flow field, enemy presentation
│   ├── input/                    # MobileControls
│   ├── ui/                       # HUD, start menu, deck, minimap
│   ├── visual/                   # Presentation drivers (no game rules)
│   ├── feedback/                 # VfxDirector, CameraShake2D, JuiceRig
│   ├── audio/                    # AudioManager, GameAudioController
│   └── economy/                  # Loot boxes
├── shaders/                      # CanvasItem family (11 gdshader)
├── assets/
│   ├── 2d/                       # Curated runtime art
│   │   ├── actors/               # Baked 8-heading SpriteFrames + scenes
│   │   ├── characters/           # Portrait PNGs + generated_asset_manifest.json
│   │   ├── structures/           # Camp + eight T1 silhouettes
│   │   ├── resources/            # Wood/Metal/Tech SVG masters
│   │   ├── effects/              # Radial lights, base_core.svg
│   │   ├── environment/          # Atlases: polyhaven, district, wild, local, terrain
│   │   ├── ui/                   # 12 px HUD icons
│   │   ├── catalog/              # Broad generated catalog (not all shipped)
│   │   └── _source_imports/      # Staged vault extracts, not the shipping slice
│   ├── audio/                    # Promoted cues
│   ├── licenses/                 # CC0 / Kenney / Atomic Realm evidence
│   ├── runtime_asset_manifest.json
│   ├── sprites/                  # Sparse leftover sprites
│   └── tiles/                    # Nature detail sheet (claw_forest_ground.png)
├── data/
│   ├── coop/                     # Reserved seat Resources
│   └── runtime_export_closure.json
├── tests/                        # Headless *_validation.gd + GPU *.tscn gates
├── tools/
│   ├── art/                      # Blender workshops, bake/render Python
│   │   └── blender/              # *.blend workshops + vault/polyhaven_*
│   └── asset_pipeline/           # Audit, extract, atlas packers
├── docs/                         # WORLD_MAP_FOUNDATION, ASSET_2D_PIPELINE, …
├── artifacts/                    # Gate captures (do not treat as source art)
├── build/                        # Actor bake intermediates, APK/PCK
├── Addons/                       # External source vault (.gdignore; not res://)
└── .planning/codebase/           # This map
```

## Directory Purposes

**`scenes/`:**
- Purpose: Packed composition. Gameplay domains arrive as child systems, not as menu logic.
- Contains: `.tscn` only (scripts live in `src/`).
- Key files: `scenes/game/game_world.tscn`, `scenes/world/world_map_2d.tscn`, `scenes/world/base_core.tscn`, `scenes/ui/StartMenu.tscn`, `scenes/characters/network_player.tscn`

**`src/world/`:**
- Purpose: Map layout authority and presentation-only density layers.
- Contains: `world_map_2d.gd`, `world_obstacle_2d.gd`, `world_road_network_2d.gd`, scatter, ambient/background/ground-cover/wilderness chunk pairs.
- Key files: `src/world/world_map_2d.gd` (14×14 contract), `src/world/world_obstacle_2d.gd` (atlas consumers)

**`src/visual/` + `src/feedback/`:**
- Purpose: Report the sim. Pulse, weather, health bars, shadows, facing, VFX, shake.
- Contains: drivers with no yield/HP/occupancy writes.
- Key files: `core_pulse_driver.gd`, `resource_node_view.gd`, `health_bar_2d.gd`, `ground_shadow.gd`, `weather_overlay.gd`, `vfx_director.gd`

**`src/tactical/`:**
- Purpose: Host-validated construction on the 64 px grid.
- Contains: catalog, build system, placed structure, placement controller, tower targeting.
- Key files: `tactical_build_system.gd`, `structure_catalog.gd`, `placed_structure_2d.gd`

**`shaders/`:**
- Purpose: Mobile CanvasItem family. One file per look. Pair with `.uid`.
- Contains: terrain blend, sleek finish/grade, toon outline, weathering, weather overlay, aura, projectile.
- Key files: `terrain_material_blend.gdshader`, `sleek_sprite_finish.gdshader`, `toon_emissive_outline.gdshader`, `weather_overlay.gdshader`

**`assets/2d/environment/`:**
- Purpose: Shipped atlas families for map dressing.
- Contains: `polyhaven/`, `polyhaven_district/`, `polyhaven_wild/`, `polyhaven_salvage/` (reserve), `local_baked/`, `terrain/`, `tiles/`.
- Key files: `polyhaven_environment_atlas.png`, `polyhaven_district_atlas.png`, `polyhaven_wild_atlas.png`, `local_environment_atlas.png`, `terrain/polyhaven_terrain_atlas.png`, matching `*_manifest.json`

**`assets/2d/actors/`:**
- Purpose: Gameplay survivor + eight enemy presentations.
- Contains: `sheets/`, `frames/*.tres`, `scenes/*.tscn`, `sheet_manifest.json`, `actor_frames_manifest.json`
- Key files: `scenes/hero_heikki.tscn`, `scenes/hero_shane.tscn`, `scenes/enemy_*.tscn`

**`tools/art/`:**
- Purpose: Reproducible Blender 5 bakes. Isolated scenes; do not touch the user's default .blend.
- Contains: `generate_character_sprites.py`, `generate_camp_and_structure_sprites.py`, `run_actor_bake.py`, `run_wild_bake.py`, `render_polyhaven_*.py`, `render_local_environment_sprites.py`, `bake_polyhaven_terrain_materials.py`, `write_generated_asset_manifest.py`
- Key files: `tools/art/blender/bespren_map_asset_workshop.blend`, `bespren_polyhaven_district_workshop.blend`, `bespren_local_environment_workshop.blend`, `bespren_terrain_material_workshop.blend`

**`tools/asset_pipeline/`:**
- Purpose: Vault audit, promotion, Godot atlas packers.
- Contains: `audit_and_extract_runtime_assets.py`, `deep_asset_audit.py`, `build_*_atlas.gd`, `build_actor_sprite_frames.gd`
- Key files: `audit_and_extract_runtime_assets.py` → `assets/runtime_asset_manifest.json`

**`Addons/`:**
- Purpose: Immutable source-asset vault (Kenney, Atomic Realm, Poly Haven caches, third-party Godot projects).
- Contains: thousands of packs. `Addons/.gdignore` keeps Godot from importing them as production `res://`.
- Generated: No. Committed: Yes (vault). Do not delete. Promote through the audit script only.

**`tests/`:**
- Purpose: Headless contract gates and windowed Mobile/Vulkan capture scenes.
- Contains: `smoke_test.gd`, `world_map_validation.gd`, `*_environment_validation.gd`, `*_render_validation.tscn`
- Key files: `tests/world_render_validation.tscn` (25 world captures), `tests/world_map_validation.gd`

**`docs/`:**
- Purpose: Spatial, pipeline, and HUD contracts the code must not silently drift from.
- Key files: `docs/WORLD_MAP_FOUNDATION.md`, `docs/ASSET_2D_PIPELINE.md`, `docs/WORLD_MAP_VISUAL_PRODUCTION_PLAN.md`

**`artifacts/` + `build/`:**
- Purpose: Gate PNGs and bake/export intermediates.
- Generated: Yes. Committed: captures used as review evidence; do not hand-edit. A capture outliving its gate is not evidence about the current build.

## Key File Locations

**Entry Points:**
- `scenes/ui/StartMenu.tscn`: application main scene
- `src/ui/start_menu.gd`: `_launch()` → `GameWorld.configure_launch()`
- `scenes/game/game_world.tscn`: shipping composition
- `src/game/game_world.gd`: signal graph, resolvers, juice table
- `scenes/main/bespren_foundation.tscn`: visual/local-roster foundation (not LAN slice)

**Configuration:**
- `project.godot`: name Bespren, features 4.7 Mobile, viewport 480×270, stretch `canvas_items`, `untyped_declaration=2`
- `export_presets.cfg`: Android export
- `data/runtime_export_closure.json`: 201 unique runtime resources
- `scenes/build/runtime_export_dependencies.tscn`: strong retain list (+1 manifest)

**World map layout:**
- `src/world/world_map_2d.gd`: `GRID_SIZE=14`, `CELL_SIZE=2048`, `PLAYABLE_HALF_EXTENT=14336`, `STARTING_CAMP_POSITION=(9950, 2400)`
- `scenes/world/world_map_2d.tscn`: z-matrix nodes + terrain overlay material
- `src/world/world_obstacle_2d.gd`: VisualKind, atlas Rect2 literals (`WILD_TREE_REGIONS`, district/local/polyhaven crops)
- `src/world/world_road_network_2d.gd`: route draw + `get_minimum_road_edge_distance()`
- `docs/WORLD_MAP_FOUNDATION.md`: cell ranges for Kaupunki / Ostari / Kylät / Metsä

**Core logic:**
- `src/coop/coop_session.gd`: UDP 8791, 20 Hz, peer one
- `src/tactical/tactical_build_system.gd`: pool + placement + relocation
- `src/world/resource_scatter_2d.gd`: 87 IDs, 3–5 interactions
- `src/ai/horde_director.gd`: night waves, 110 alive
- `src/game/combat_state_coordinator.gd`: HP / respawn / game over

**Presentation scenes:**
- `scenes/world/base_core.tscn`: camp bake, Amber `PointLight2D` (`range_z_min=-20`), aura, `CorePulseDriver`
- `scenes/resources/resource_node_{wood,metal,tech}.tscn`: SVG + `toon_emissive_outline`
- `scenes/characters/network_player.tscn`: radius-9 body, `Shadow.base_radius=16`, flashlight
- `scenes/characters/heikki.tscn` / `shane.tscn`: legacy portraits; gameplay uses `assets/2d/actors/scenes/hero_*.tscn` unless `force_legacy_presentation`

**Graphics / shaders:**
- `shaders/terrain_material_blend.gdshader`
- `shaders/sleek_sprite_finish.gdshader`
- `shaders/toon_emissive_outline.gdshader`
- `shaders/weather_overlay.gdshader`
- `shaders/surface_weathering.gdshader`

**Testing:**
- `tests/smoke_test.gd`: 207-check headless gate
- `tests/world_map_validation.gd`: layout / collision / decor counts
- `tests/world_render_validation.tscn`: 25 GPU captures
- `tests/polyhaven_environment_validation.gd`, `polyhaven_district_validation.gd`, `local_environment_validation.gd`, `terrain_material_validation.gd`
- `tests/existing_wild_atlas_context_validation.tscn`: wild-family 1× review (non-tree promotion forbidden)

## Naming Conventions

**Files:**
- Scripts: `snake_case.gd` with matching `class_name PascalCase` (`world_map_2d.gd` → `BesprenWorldMap2D`). Prefix `bespren_` only on map/scatter types that would otherwise collide.
- Scenes: `snake_case.tscn` except boot UI `StartMenu.tscn` and `MobileControls.tscn`.
- Shaders: `snake_case.gdshader` describing the look (`sleek_sprite_finish`, not `sprite.gdshader`).
- Tests: `<domain>_validation.gd` headless; `<domain>_render_validation.tscn` GPU. Probes: `<domain>_enet_probe.gd`.
- Art: `type_subject_variant_state` (`structure_t1_kinetic.png`, `polyhaven_forest_stump_01.png`, `hero_heikki_idle.png`, `resource_wood.svg`).
- Manifests: `<family>_manifest.json` or `generated_asset_manifest.json` next to the renders they list (no globbing).

**Directories:**
- `src/<domain>/` matches scene folder where a packed scene exists (`src/world` ↔ `scenes/world`).
- Atlas families: `assets/2d/environment/<source>_<role>/` (`polyhaven_district`, `local_baked`, `polyhaven_wild`).
- Chunk scripts pair as `<layer>_2d.gd` + `<layer>_chunk_2d.gd`.

**Types / nodes:**
- Unique names in `game_world.tscn` / `world_map_2d.tscn` (`%WorldMap2D`, `%BaseCore`). Access via `%Name` / NodePath, not `get_node("../../Unrelated")`.
- Signals: past-tense domain events (`structure_placed`, `resource_gathered`, `night_started`).
- Enums: `Biome`, `VisualKind`, `ResourceKind` in the owning class.

**Identifiers:**
- Characters: `&"heikki"`, `&"shane"`.
- Structures: `&"t1_kinetic"` … `&"t1_razor_snare"` in `StructureCatalog`.
- Resources: Wood `#FFD700`, Metal `#E0E0E0`, Tech `#00FFFF` — reuse, do not invent a fourth signal color.

## Where to Add New Code

**New map / biome / district:**
- Primary: `src/world/world_map_2d.gd` — extend `Biome`, `_build_biome_cells()`, add `_build_<district>()`.
- Scene: only if a new child pass is required; default is to parent obstacles under `%Structures` (`scenes/world/world_map_2d.tscn`).
- Decor density: `src/world/world_ambient_scenery_2d.gd` pockets/counts or `world_ground_cover_2d.gd` on a **new seed**. Do not grow `WorldBackgroundDecor2D` prop counts without updating `tests/polyhaven_district_validation.gd` (75 benches / 46 hydrants / 34 stoves).
- Contract: `docs/WORLD_MAP_FOUNDATION.md` + `tests/world_map_validation.gd`. Re-run `tests/world_render_validation.tscn` if camp or district pixels move.
- Tests: `tests/world_map_validation.gd`

**New colliding obstacle visual:**
- Collision/flow: `_add_rectangle_obstacle` / `_add_circle_obstacle` in `world_map_2d.gd`.
- Sprite: crop in `src/world/world_obstacle_2d.gd` (`_install_*_visual`). Derive Rect2 as `cell_region.xy + padded_atlas_region.xy` from the family manifest. Tint via `WILD_TREE_TINT` only for the wild canopy.
- Contact: `GroundShadow.draw_ellipse` anchored to the **sprite**, not the collision AABB.
- Tests: family validation + world map gate.

**New environment atlas family:**
1. Fetch/pin sources under `tools/art/blender/vault/<family>/` (not `Addons/` runtime).
2. Workshop `.blend` + `.gdignore` beside it.
3. Renderer `tools/art/render_<family>_sprites.py` (isolated scene, ortho, Freestyle, AgX, transparent).
4. Packer `tools/asset_pipeline/build_<family>_atlas.gd`.
5. Output `assets/2d/environment/<family>/` (frames + atlas + manifest with SHA-256, luma floor, margins).
6. Consumer literals in `world_obstacle_2d.gd` and/or `world_ambient_scenery_chunk_2d.gd`.
7. Gate `tests/<family>_validation.gd`. 1× human veto before promoting non-tree wild frames.

Do not add `polyhaven_salvage` consumers until a 1× review ships; the atlas is reserve only.

**New shader:**
- File: `shaders/<look>.gdshader`.
- World item: `render_mode blend_mix`; `vec4 source = COLOR;` (never refetch × COLOR).
- Outline: `fwidth(UV) * width * ((1.0 / SCREEN_PIXEL_SIZE.x) / 480.0)`.
- Atmosphere/damage: uniforms on `weather_overlay.gdshader`, not a second overlay.
- Wire through the owning scene or `_get_environment_finish()` in `world_obstacle_2d.gd`.
- Compare against `scenes/showcase/visual_validation.tscn` before accepting.

**New structure card:**
- Bake: `tools/art/generate_camp_and_structure_sprites.py` → `assets/2d/structures/structure_t1_<id>.png`
- Data: `src/tactical/structure_catalog.gd` + `structure_definition.gd`
- Runtime: `placed_structure_2d.gd` (shared `HealthBar2D`, `GroundShadow`, `sleek_sprite_finish`; `range_z_min = -20` on lights)
- UI: `src/ui/tactical_build_deck.gd` picks catalog; do not duplicate thumbnails in the deck scene
- Tests: `tests/structure_visual_render_validation.tscn`, `tests/tower_combat_validation.gd` if combat changes

**New actor / enemy presentation:**
- Roster: `tools/art/run_actor_bake.py` (game's actual cast, not a side demo)
- Sheets: `assets/2d/actors/sheets/` + `build_actor_sprite_frames.gd`
- Catalog: `src/ai/enemy_presentation_catalog.gd` — uniform `ACTOR_SCALE = (1,1)`; per-variant `contact_offset` / `contact_radius` measured off the sheet
- Survivors: `PlayerAvatar` defaults to `assets/2d/actors/scenes/hero_*.tscn` at `BAKED_ACTOR_VISUAL_SCALE = 1.5`. Do not retarget gameplay to `heikki_topdown.png`.
- Facing: `src/visual/actor_facing.gd` row table; do not use 45° wedges
- Tests: `tests/enemy_presentation_validation.gd`, `tests/enemy_presentation_render_validation.tscn`

**New HUD / touch control:**
- `src/ui/` + `scenes/ui/`. CanvasLayer 100. Convert Android safe-area insets into 480×270 before placing. 44×44 minimum targets. Resource colors stay the three anchors.

**New utility / shared visual primitive:**
- Prefer extending `HealthBar2D`, `GroundShadow`, `ActorGroundShadow2D`, `JuiceRig`. Grep for the primitive the shared class replaced (`draw_rect` bars, `draw_circle` discs) before adding a local copy.

**Utilities / helpers:**
- Domain-local first (`src/world/`, `src/visual/`). No `src/util/` dump. No autoload singletons.

**Do not put new production code in:**
- `Addons/` (vault)
- `assets/2d/_source_imports/` (staging)
- `assets/2d/catalog/` broad library unless the shipping scene references it
- `artifacts/` or `build/` (generated)
- `src/visual/` if the change decides a game rule — that belongs in coop/tactical/world/ai

## Special Directories

**`Addons/`:**
- Purpose: External source-asset vault
- Generated: No
- Committed: Yes
- Godot-scanned: No (`Addons/.gdignore`)

**`tools/art/blender/`:**
- Purpose: Immutable workshops + Poly Haven GLTF vaults
- Generated: Workshops authored; `vault/` fetched via `tools/asset_pipeline/fetch_polyhaven_models.py`
- Committed: Yes
- Godot-scanned: Workshops excluded with `.gdignore`. No GLTF/`Node3D` in shipping scenes.

**`assets/2d/environment/polyhaven_salvage/`:**
- Purpose: Packed reserve atlas (no runtime consumer)
- Generated: Yes (`run_wild_bake.py` always bakes wild **and** salvage)
- Committed: Yes
- Promote: only after 1× review and an explicit `src/` consumer

**`assets/2d/catalog/`, `assets/2d/enemies/`, `assets/2d/bosses/`, `assets/2d/props/`:**
- Purpose: Broad generated 2D catalog from vault sources
- Generated: Yes (`tools/asset_pipeline/build_2d_resources.gd`)
- Committed: Yes
- Shipping: only paths listed in `data/runtime_export_closure.json` / `runtime_export_dependencies.tscn`

**`artifacts/`:**
- Purpose: Validation captures
- Generated: Yes
- Committed: review evidence only
- Rule: re-run the gate after camp/atlas/shader changes; stale PNGs are not the build

**`build/`:**
- Purpose: Actor bake scratch, Android PCK/APK
- Generated: Yes
- Committed: selected APK/PCK artifacts; treat as predating current closure until rebuilt

**`data/coop/`:**
- Purpose: Reserved authored seat Resources
- Generated: No
- Committed: empty placeholder

## Skill constraints (apply when adding code)

- **godot-gdscript-patterns:** `class_name`, typed signals, scene composition, no autoloads, unique-name contracts.
- **2d-games:** Atlases over loose textures; simplified collision (circle/rect, not mesh); absolute z-matrix; Y-sort only on gameplay participants.
- **game-art:** `type_subject_variant_state`; inspect new art at 1× logical 480×270; identity redundant across hue/silhouette/icon/placement; measure delivered pixels, not bake resolution.
- **game-design:** Keep the scan → salvage → return → reinforce → survive loop. Presentation must not invent a parallel resource or combat rule.

---

*Structure analysis: 2026-09-18*
