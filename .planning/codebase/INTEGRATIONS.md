# External Integrations

**Analysis Date:** 2026-09-18

## APIs & External Services

**Asset acquisition (offline, never at gameplay):**
- Poly Haven public API - Fetch reviewed CC0 1k glTF sources into the Blender vault
  - SDK/Client: `urllib.request` in `tools/asset_pipeline/fetch_polyhaven_models.py`
  - Endpoint: `https://api.polyhaven.com` (`/info/{id}`, `/files/{id}`)
  - Auth: none. Send User-Agent `Mozilla/5.0 BesprenAssetPipeline/1.0` or the API returns 403
  - Resolution/format pin: `1k` / `gltf`
  - Destinations: `tools/art/blender/vault/polyhaven_wild/`, `tools/art/blender/vault/polyhaven_salvage/`
  - Provenance: `_fetch_manifest.json` records SHA-256, asset page `https://polyhaven.com/a/{id}`, license `https://polyhaven.com/license`
  - Runtime rule: nothing from this fetch enters `res://`. Bake RGBA frames, pack an atlas, promote atlas + JSON manifest only

**LAN multiplayer (runtime):**
- Godot ENet - Host-authoritative two-device LAN
  - SDK/Client: `ENetMultiplayerPeer` in `src/coop/coop_session.gd`
  - Transport: UDP port `8791` (`CoopSession.PORT`)
  - Auth: none. No accounts, tokens, or matchmaking
  - Max clients: 3 (`MAX_CLIENTS`)
  - Client timeout: 2.5 s then Solo fallback
  - RPC: clients `rpc_id(1)`; movement/aim snapshots `unreliable_ordered` at 20 Hz; registration and Interact/Fire `reliable`
  - Android export enables `permissions/internet=true` in `export_presets.cfg` for this UDP path only

**Offline peer (runtime):**
- `OfflineMultiplayerPeer` - Solo and disconnect fallback
  - Implementation: `CoopSession.start_solo()` and `_fallback_to_solo()` in `src/coop/coop_session.gd`
  - Same authority boundary: `is_server()` true, unique ID = peer 1
  - Use this path for headless gates; do not invent a second local-authority type

**DCC / MCP (authoring only):**
- BlendMCP - Drive a live Blender 5 workshop
  - Client: Blender addon `blendmcp_addon` started by `tools/art/start_blendmcp_workshop.py` (`bpy.ops.blendermcp.start_server()`)
  - Auth: local Blender session, no cloud key
  - Use for catalog import into workshops. Production bakes run `blender --background --python`, not the MCP timeout
- Godot MCP - Optional editor `run_project`. Gates do not depend on it; point the Godot binary at `--headless --script` or a capture `.tscn`

**Not present:**
- Stripe, Supabase, AWS, Firebase, REST gameplay backends, analytics SDKs, ads, IAP

## Data Storage

**Databases:**
- None. No SQL, no Godot `SQLite`, no remote store
  - Connection: Not applicable
  - Client: In-memory host state in `CoopSession`, `BesprenResourceScatter2D`, `TacticalBuildSystem`
  - Persistence: not implemented (inventory/progression remain out of slice)

**File Storage:**
- Local filesystem only
  - Runtime art: `assets/2d/`, `assets/audio/`, `assets/licenses/`
  - Manifests: `assets/runtime_asset_manifest.json`, family `generated_asset_manifest.json`, Poly Haven `*_manifest.json`, `assets/2d/actors/actor_frames_manifest.json`, `assets/2d/actors/sheets/sheet_manifest.json`
  - Export pin: `data/runtime_export_closure.json`
  - Bake intermediates: `build/actor_bake/`, `build/actor_sheets/`, `artifacts/`
  - APK/PCK: `build/android/`
  - Source vault (not shipped): `Addons/` behind `.gdignore`

**Caching:**
- Godot import cache under `.godot/imported/` (S3TC + ETC2 `.ctex` for VRAM textures)
- None at gameplay. No Redis, no HTTP cache

## Authentication & Identity

**Auth Provider:**
- Custom local seat identity, not an account service
  - Implementation: `PlayerSlotDefinition` + `LocalCoopRoster` in `src/coop/`; character IDs `&"heikki"` / `&"shane"` validated by `CoopSession.VALID_CHARACTERS`
  - Device routing uses `InputEvent.device`. Do not infer a second player from two touches on one device
  - LAN Join takes a typed IP string; empty becomes `127.0.0.1`. No login, no NAT punchthrough, no relay

## Monitoring & Observability

**Error Tracking:**
- None (no Sentry/Crashlytics)

**Logs:**
- `print` / `push_error` from GDScript and bake scripts
- Headless gates emit `SMOKE OK (N checks)` / family `OK` lines
- Bake reports: `assets/2d/environment/polyhaven_wild_render_report.json` and per-family manifests
- GPU capture metadata written beside PNGs by `tests/world_render_validation.gd`
- Do not add a telemetry SDK for this slice

## CI/CD & Deployment

**Hosting:**
- Sideloaded Android APK. No Play/App Store pipeline in-repo
- Package: `com.bespren.game`, name Bespren, version `0.1.0` / code 1
- Architecture: `arm64-v8a` only (`export_presets.cfg`)
- Gradle build: off. Godot built-in Android export
- Signing: `package/signed=true` on the debug preset; device install still an open certification gate

**CI Pipeline:**
- None (no `.github/workflows`, no cloud runner)
- Local evidence classes:
  1. Headless scripts: `& Godot --headless --path . --script res://tests/smoke_test.gd` (and family validators listed in `docs/WORLD_MAP_FOUNDATION.md`)
  2. Windowed Mobile/Vulkan captures: open `tests/world_render_validation.tscn` without `--headless`
  3. Two-process ENet: host/client roles on loopback
  4. APK inventory: `tests/android_export_validation.ps1`
  5. Isolated PCK load: `tests/export_pack_verifier/verify_export_pack.gd`

## Environment Configuration

**Required env vars:**
- Gameplay: none
- Android editor export: `BESPREN_JAVA_SDK_PATH`, `BESPREN_ANDROID_SDK_PATH` (`tools/configure_android_export.gd`)
- Wild bake: `BESPREN_WILD_BAKE_ISOLATED=1`; optional `BESPREN_WILD_BAKE_OUTPUT_ROOT` for trials
- Actor bake: optional `BESPREN_ACTOR_BAKE_BASELINE_REPORT`
- Microprop validation: optional `BESPREN_MICROPROP_RECIPE`

**Secrets location:**
- No gameplay secrets. Do not add `.env` for LAN or Poly Haven
- Android keystore / SDK paths live in Godot `EditorSettings` after `configure_android_export.gd`; treat those as machine-local, never commit

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None at runtime
- Authoring-only HTTP: Poly Haven `api.polyhaven.com` plus CDN file URLs recorded in fetch manifests

## Graphics Toolchain Integrations

Keep these as offline integrations. Runtime consumes packed 2D only.

**Blender 5.0.0 EEVEE:**
- Binary pin: `C:\Program Files\Blender Foundation\Blender 5.0\blender.exe` in `tools/art/run_wild_bake.py`
- Isolated stages: `BESPREN_SPRITE_STAGE`, `BESPREN_AAA_STAGE`, workshop-specific prefixes
- Shared camera/light: `tools/art/aaa_bake_rig.py` (52° elevation, −45° azimuth, AgX Medium High Contrast, Freestyle, transparent film)
- Generators:
  - `tools/art/generate_character_sprites.py` → `assets/2d/characters/`
  - `tools/art/generate_camp_and_structure_sprites.py` → `assets/2d/structures/`
  - `tools/art/run_actor_bake.py` + `bake_animated_actor.py` + `build_actor_body.py` + `rig_bespren_actor.py` → supersampled frames
  - `tools/art/render_polyhaven_environment_sprites.py` / `render_polyhaven_district_sprites.py` / `render_polyhaven_wild_sprites.py` / `render_local_environment_sprites.py`
  - `tools/art/bake_polyhaven_terrain_materials.py` (NumPy atlas + 224×224 biome mask)
- After camp/character rebake run `tools/art/write_generated_asset_manifest.py`
- Determinism: survivor/camp IDAT must match shipped pixels (PNG `tEXt` Date/RenderTime may differ). Wild/salvage family allows ≤1 channel unit on ≲0.1% of pixels
- One Blender process per heavy Poly Haven source (`run_wild_bake.py`); do not import two photogrammetry trees in one session

**KayKit (CC0, vault only):**
- Path: `Addons/KayKit_Character_Animations_1.1`
- Role: armature + clip names. `build_actor_body.py` authors Bespren masses onto that skeleton. Do not ship the mannequin or any `Node3D`

**Godot atlas builders (headless SceneTree):**
- `tools/asset_pipeline/build_actor_sprite_frames.gd` - Sheets → `SpriteFrames` + actor scenes; headings via `ActorFacing`
- `tools/asset_pipeline/build_polyhaven_environment_atlas.gd`
- `tools/asset_pipeline/build_polyhaven_district_atlas.gd`
- `tools/asset_pipeline/build_polyhaven_wild_atlas.gd` (packs `polyhaven_wild` then `polyhaven_salvage`; a single-family bake report is invalid input)
- `tools/asset_pipeline/build_local_environment_atlas.gd`
- After packing, `WorldObstacle2D` / `WorldAmbientSceneryChunk2D` atlas `Rect2` literals must equal `cell_region.xy + padded_atlas_region.xy` from the new manifest

**Addons vault promotion:**
- `tools/asset_pipeline/audit_and_extract_runtime_assets.py` + `deep_asset_audit.py`
- Copy only the reviewed shortlist into `assets/`; write `assets/runtime_asset_manifest.json`
- `Addons/.gdignore` keeps the vault out of `res://`. Do not delete vault sources without a license manifest and explicit confirmation

**Godot Android export:**
- Preset `export_presets.cfg` scene-filter: `res://scenes/ui/StartMenu.tscn`, `res://scenes/game/game_world.tscn`, `res://scenes/build/runtime_export_dependencies.tscn`
- Closure must list every `class_name` script reached only via `.new()` (feedback stack lesson: `camera_shake_2d.gd`, `vfx_director.gd`, `actor_ground_shadow_2d.gd`, `health_bar_2d.gd`)
- Verify with `tests/android_export_validation.ps1` and `tests/export_pack_verifier/verify_export_pack.gd`

## Map Layout Integration Contract

When adding world content, integrate through `BesprenWorldMap2D` (`src/world/world_map_2d.gd`) rather than a new service.

**Layout ownership:**
- Macro grid, biomes, roads, colliding obstacles, flow mask, walkability broadphase: `BesprenWorldMap2D`
- Visual dressing: `WorldRoadNetwork2D`, `WorldBackgroundDecor2D`, `WorldAmbientScenery2D`, `WorldGroundCover2D`, `WorldWildernessAccent2D`
- Salvage nodes: `BesprenResourceScatter2D` (`src/world/resource_scatter_2d.gd`) — 87 seeded IDs, host-only yield
- Collision/visual bind: `WorldObstacle2D` (`src/world/world_obstacle_2d.gd`) atlas regions for Poly Haven, district, local, and wild families

**Terrain blend:**
- One `Sprite2D` + `shaders/terrain_material_blend.gdshader`
- Atlas: `assets/2d/environment/terrain/polyhaven_terrain_atlas.png`
- Mask: `assets/2d/environment/terrain/bespren_biome_blend_mask.png`
- Sources: `aerial_asphalt_01`, `muddy_tracks`, `forest_leaves_02`, `concrete_pavement_03` (CC0)

**Authority boundary:**
- Peer one calls `resolve_player_motion` / `is_position_walkable` before broadcasting positions
- Clients interpolate snapshots. Do not run a second physics sim on remote avatars
- Traps remain placeable and non-blocking for players and flow

**Licenses to preserve on every promotion:**
- `assets/licenses/polyhaven_cc0.md`
- `assets/licenses/kaykit_character_animations_cc0.md`
- `assets/licenses/kenney_city_builder_mit.md`
- `assets/licenses/local_baked_environment_sources.md` (Atomic Realm: embed in-game, do not redistribute as a pack)

---

*Integration audit: 2026-09-18*
