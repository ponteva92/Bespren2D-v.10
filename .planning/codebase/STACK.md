# Technology Stack

**Analysis Date:** 2026-09-18

## Languages

**Primary:**
- GDScript 2.0 (Godot 4.7 typed) - Runtime game, scenes, validation gates under `src/`, `scenes/`, `tests/`
- Godot Shader Language (`shader_type canvas_item`) - All mobile CanvasItem materials under `shaders/`

**Secondary:**
- Python 3.11 / 3.12 / 3.14 (host interpreter; `__pycache__` shows all three) - Offline art/asset pipeline under `tools/art/` and `tools/asset_pipeline/`
- Blender Python (`bpy`, `mathutils`) - Headless EEVEE bakes executed inside Blender 5.0, not at game runtime
- PowerShell - Android APK inventory gate in `tests/android_export_validation.ps1`

## Runtime

**Environment:**
- Godot `4.7.1.stable.official.a13da4feb` - Validation and shipping runtime
- Features: `PackedStringArray("4.7", "Mobile")` in `project.godot`
- Rendering method: `mobile` (`project.godot` `[rendering] renderer/rendering_method="mobile"`)
- Viewport: 480×270 logical landscape, `canvas_items` stretch, 960×540 window override for desktop
- Physics layers: `Players` (1), `WorldStatic` (2), `Enemies` (3)
- Autoloads: none. Compose systems as scene children or typed Resources.

**Package Manager:**
- None for the game. No `package.json`, `requirements.txt`, `pyproject.toml`, `Cargo.toml`, or `go.mod`
- Lockfile: missing (not applicable)
- Tooling Python uses stdlib plus optional `PIL` / `numpy` imported by bake/pack/audit scripts. Install those on the host interpreter; do not add them as Godot runtime deps

## Frameworks

**Core:**
- Godot 4.7 Mobile 2D - SceneTree, `CharacterBody2D` / `StaticBody2D`, `TileMapLayer`, `Sprite2D` / `AnimatedSprite2D`, `CanvasItem` lights, RPC multiplayer
- `ENetMultiplayerPeer` - LAN host/client on UDP 8791 (`src/coop/coop_session.gd`)
- `OfflineMultiplayerPeer` - Solo fallback with the same peer-one authority path

**Testing:**
- Godot `--headless --script` SceneTree gates - Deterministic contracts (`tests/smoke_test.gd`, `tests/world_map_validation.gd`, family validators)
- Godot windowed Mobile/Vulkan scenes - Pixel captures (`tests/world_render_validation.tscn` and sibling `*_render_validation.tscn`)
- Two-process ENet probes - `tests/enet_peer_probe.gd`, `tests/resource_enet_probe.gd`, `tests/tactical_enet_probe.gd`
- Host-interpreter Python validators - `tests/deep_asset_audit_validation.py`, bake-contract scripts under `tools/art/`

**Build/Dev:**
- Godot editor import + Android export preset - `export_presets.cfg`
- Blender 5.0.0 EEVEE - Isolated-scene orthographic transparent Freestyle bakes
- BlendMCP (`blendmcp_addon`) - Live workshop control via `tools/art/start_blendmcp_workshop.py`; production bakes use console Blender, not the MCP session
- Godot MCP (optional) - Not on the critical path; gates run from the Godot binary directly

## Key Dependencies

**Critical:**
- Godot 4.7.1 Mobile renderer + Vulkan (OpenGL fallback enabled by engine, not a project toggle) - Shipping Android path. Do not enable HDR 2D; it would switch the viewport to RGBA16F
- `ENetMultiplayerPeer` / `OfflineMultiplayerPeer` - Host-authoritative LAN and Solo. Authority is always peer 1
- CanvasItem shader family under `shaders/` - `blend_mix` grading/outline, one full-screen `weather_overlay.gdshader`. Entry `COLOR` is already textured; never `texture(TEXTURE, UV) * COLOR`
- Baked 2D atlases under `assets/2d/` - Runtime art. No GLTF, mesh, PBR graph, or `Node3D` ships

**Infrastructure:**
- Poly Haven CC0 1k glTF (offline vault) - Fetched by `tools/asset_pipeline/fetch_polyhaven_models.py`, baked, packed; only PNG atlas + JSON manifest reach `res://`
- KayKit Character Animations 1.1 CC0 - Skeleton + clip vocabulary for actor bake (`Addons/KayKit_Character_Animations_1.1`, license `assets/licenses/kaykit_character_animations_cc0.md`)
- Kenney Starter Kit City Builder MIT/CC0 - Local environment GLB sources (`assets/licenses/local_baked_environment_sources.md`)
- Atomic Realm Post-Apocalyptic pack - Local environment GLBs; derived PNGs may ship in-game, must not be redistributed as an asset pack
- Pillow (`PIL`) - Host-side sheet packing (`tools/art/pack_actor_sheets.py`) and audit imaging
- NumPy - Blender-side pixel math in wild/terrain renderers (`tools/art/render_polyhaven_wild_sprites.py`, `tools/art/bake_polyhaven_terrain_materials.py`)

## Configuration

**Environment:**
- Gameplay has no `.env` and no runtime cloud keys. LAN address is typed at Join; default client target is `127.0.0.1`
- Android export editor paths (not gameplay):
  - `BESPREN_JAVA_SDK_PATH` - JDK root with `bin/java.exe`
  - `BESPREN_ANDROID_SDK_PATH` - SDK root with `platform-tools/adb.exe`
  - Applied by `tools/configure_android_export.gd` into Godot `EditorSettings`
- Bake isolation:
  - `BESPREN_WILD_BAKE_ISOLATED=1` - Required by wild/fern/grass renderers
  - `BESPREN_WILD_BAKE_OUTPUT_ROOT` - Trial output; production clears it
  - `BESPREN_ACTOR_BAKE_BASELINE_REPORT` - Actor bake baseline pin
  - `BESPREN_MICROPROP_RECIPE` - Wilderness microprop validation recipe

**Build:**
- `project.godot` - App name Bespren, main scene `res://scenes/ui/StartMenu.tscn`, Mobile features, viewport, input map, physics layers, mobile renderer, ETC2/ASTC VRAM compression
- `export_presets.cfg` - Single Android preset, `com.bespren.game`, version `0.1.0`, arm64-v8a only, immersive, internet permission, scene-filter export of `StartMenu.tscn` + `game_world.tscn` + `runtime_export_dependencies.tscn`
- Exclude filter: `Addons/*,artifacts/asset_audit/extraction_runs/*,assets/2d/catalog/*,assets/2d/props/*`
- `data/runtime_export_closure.json` + `scenes/build/runtime_export_dependencies.tscn` - Hand-maintained runtime resource pin (201 resources / 202 strong deps)
- `gdscript/warnings/untyped_declaration=2` - Untyped declarations are errors. Keep every new script typed
- Texture import: actor sheets VRAM-compress with `process/fix_alpha_border=true`; resource SVGs generate mipmaps (`assets/2d/resources/*.svg.import`)

## Platform Requirements

**Development:**
- Windows host with Godot 4.7.1 (console binary used for `--headless --script`)
- Blender `C:\Program Files\Blender Foundation\Blender 5.0\blender.exe` for rebakes (`tools/art/run_wild_bake.py`)
- Python 3.11+ with Pillow for sheet packing / audits; NumPy available inside Blender for terrain/wild pixel ops
- Android SDK + JDK only when configuring/exporting APKs
- Do not scan `Addons/` as `res://` content (`Addons/.gdignore`). Promote through `tools/asset_pipeline/audit_and_extract_runtime_assets.py`

**Production:**
- Android arm64-v8a, package `com.bespren.game`, signed debug APK at `build/android/Bespren-debug.apk`
- Logical 480×270 landscape, `canvas_items` stretch, Mobile/Vulkan, 60 FPS preferred / 30 FPS fallback
- Local two-player LAN (one touch player per device) or Solo `OfflineMultiplayerPeer`
- Desktop keyboard remains a development input path, not the shipping control surface

## Graphics And Map Layout Stack

Use this stack when adding premium art or world layout. Do not introduce a second renderer, a second atlas convention, or a runtime 3D path.

**Viewport and camera:**
- Author and gate at 1× logical 480×270. Desktop window is 2× (960×540); measure rings/geometry from a `SubViewport` or divide physical pixels
- Gameplay camera zoom is 0.38. Screen-space quantities (outlines, bar weights) must use `fwidth(UV)` × stretch against `LOGICAL_VIEWPORT_WIDTH = 480.0`, never `TEXTURE_PIXEL_SIZE`
- One full-screen custom pass: `shaders/weather_overlay.gdshader` via `src/visual/weather_overlay.gd`. Combine atmosphere and damage wash here

**CanvasItem shader set (`shaders/`):**
- `terrain_material_blend.gdshader` - World ground overlay; biome mask + 1024 atlas, lighting-responsive, no extra full-screen pass
- `sleek_sprite_finish.gdshader` - Environment props, `WorldObstacle2D`, `PlacedStructure2D`. `render_mode blend_mix`
- `sleek_canvas_grade.gdshader` - Ambient scenery / background decor / wilderness accents. `blend_mix`
- `toon_emissive_outline.gdshader` - Base Core, resource nodes, legacy survivor scenes. Identity rims, `blend_mix`
- `surface_weathering.gdshader` - Rust / decayed wood / oxidized copper; bounded hash, no dynamic loops
- `weather_overlay.gdshader` - Rain/ash/tint/vignette + hit wash
- `volumetric_aura.gdshader`, `base_scale_glow.gdshader` - Base Core presentation only
- `projectile_glow.gdshader`, `solid_white_flash.gdshader`, `road_surface_detail.gdshader` - Combat/road accents
- Lights: set `range_z_min = -20` so they reach terrain at `z_index = -20` (`scenes/world/base_core.tscn`, `scenes/characters/network_player.tscn`, `src/tactical/placed_structure_2d.gd`)

**World map layout (`src/world/`):**
- `BesprenWorldMap2D` in `src/world/world_map_2d.gd` owns the 14×14 macro-grid (2048-unit cells, ±14,336 playable), biome table, obstacle list, 512-unit walkability broadphase, and 112×112 flow-field mask
- Seed: `WORLD_BUILD_SEED = 0xB35E7E`. Keep placement deterministic
- Camp: `STARTING_CAMP_POSITION = Vector2(9950, 2400)` with 1600-unit road-edge clearance
- Regions: Kaupunki (city), Ostari (mall), west/east villages, Metsä/Luonto forest/wilderness — see `docs/WORLD_MAP_FOUNDATION.md`
- Absolute Z matrix: ground/roads `-20`, non-colliding rubble/moss `-5`, ambient silhouettes `-4`, gameplay/static `5` under Y-sort
- `WorldObstacle2D` (`src/world/world_obstacle_2d.gd`) is the single obstacle record: `StaticBody2D` on `WorldStatic`, collision shape, flow footprint, atlas visual
- Visual-only layers must not write collision or flow: `WorldAmbientScenery2D`, `WorldBackgroundDecor2D`, `WorldGroundCover2D`, `WorldWildernessAccent2D`, `WorldRoadNetwork2D`
- Navigation: `FlowFieldNavigation2D` (`src/ai/flow_field_navigation_2d.gd`) reads the map mask; traps do not block flow

**Runtime art layout (`assets/2d/`):**
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

**Bake toolchain (`tools/art/`, `tools/asset_pipeline/`):**
- Isolated Blender scene policy: never mutate the user's default scene
- Shared rig: `tools/art/aaa_bake_rig.py` — elevation 52°, azimuth −45°, AgX Medium High Contrast, Freestyle, 4× supersample
- Character/camp generators write PNG then `tools/art/write_generated_asset_manifest.py`
- Actor path: `run_actor_bake.py` → `pack_actor_sheets.py` → `tools/asset_pipeline/build_actor_sprite_frames.gd`
- Environment path: fetch → workshop render → Godot atlas builder (`build_polyhaven_*.gd`, `build_local_environment_atlas.gd`)
- Workshops: `tools/art/blender/bespren_map_asset_workshop.blend`, `bespren_polyhaven_district_workshop.blend`, `bespren_local_environment_workshop.blend`, `bespren_terrain_material_workshop.blend`
- New art naming: `type_subject_variant_state`. Inspect at 1× logical size before accepting

**Skill constraints to keep:**
- 2D games: atlas over loose textures; simplified collision; 8-direction facing via `ActorFacing` (`src/visual/actor_facing.gd`)
- Game art: identity redundant across hue, silhouette, iconography, placement
- Mobile games: 44×44 touch targets, thermal-aware budgets, no extra full-screen passes
- GDScript patterns: `class_name`, typed arrays/signals/enums, no autoload unless a later milestone truly needs process-global lifetime

---

*Stack analysis: 2026-09-18*
