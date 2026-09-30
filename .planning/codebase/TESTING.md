# Testing

**Analysis Date:** 2026-09-18

## Framework

- Godot 4.7.1 (`Godot_v4.7.1-stable_win64.exe`) `--headless --script` for deterministic contract gates.
- Same binary **without** `--headless` for Mobile/Vulkan pixel captures. Point it at a `*_validation.tscn`; do not use the Godot MCP `run_project` quota for this.
- No Jest/GUT/gdUnit. Gates are first-class Godot scripts that print `NAME OK (N checks)` and `quit(0|1)`.
- Python gates exist only for the Addons vault audit: `tests/deep_asset_audit_validation.py`, `tests/extract_addons_audit_sources_validation.py`.
- Android packaging: `tests/android_export_validation.ps1` plus `tests/export_pack_verifier/verify_export_pack.gd`.

## Structure

- Tests live under `tests/`. Production code is never tested from `src/` co-located `*.test.gd` files.
- Naming:
  - `smoke_test.gd` — umbrella headless gate.
  - `*_validation.gd` — focused `extends SceneTree` contract gate, run with `--script`.
  - `*_validation.tscn` + `*_validation.gd` (`extends Node2D`) — GPU capture scene.
  - `*_enet_probe.gd` — two-process desktop LAN probe (`enet_peer_probe.gd`, `resource_enet_probe.gd`, `tactical_enet_probe.gd`).
- Captures write under `artifacts/` at the exact 480×270 logical size. Metadata JSON rides beside the PNGs (`artifacts/world_render_validation.json`).

## Gate Inventory

| Gate | Path | Checks / captures | What it proves |
|------|------|-------------------|----------------|
| Smoke | `tests/smoke_test.gd` | `SMOKE OK (207 checks)` | Mobile renderer, 480×270, `untyped_declaration=2`, StartMenu boot, roster/device routing, curated manifests, required scenes/shaders/audio, player radius-9 physics, HUD geometry, camp/structures, environment atlases, projectile lifecycle |
| World map | `tests/world_map_validation.gd` | `WORLD MAP VALIDATION OK (169 checks)` | 14×14 grid, ±14,336 extents, camp `(9950, 2400)`, z-index matrix, flow-field hash, obstacle counts, road/decor chunk spans, deterministic seeds |
| World render | `tests/world_render_validation.tscn` | `captures=25` | Mobile/Vulkan pixels for overview, Kaupunki/Ostari, camp day/night, villages, density, ecology, terrain transition. Reads `STARTING_CAMP_POSITION` live |
| Art-direction showcase | `tests/render_validation.tscn` | GPU capture | Integrated visual_validation composition, not a shipping level |
| Poly Haven environment | `tests/polyhaven_environment_validation.gd` | `POLY HAVEN ENVIRONMENT VALIDATION OK (36 checks)` | Six CC0 sources, twelve frames, atlas, shader, filtering, retained collision, no runtime 3D |
| Poly Haven district | `tests/polyhaven_district_validation.gd` | `POLY HAVEN DISTRICT VALIDATION OK (58 checks)` | Eight CC0 sources, atlas/luma/margins, exact 16 obstacle sprites, 75/46/34 furniture mix, export closure |
| Local environment | `tests/local_environment_validation.gd` | `LOCAL ENVIRONMENT VALIDATION OK (47 checks)` | Sixteen Kenney/Atomic Realm frames, city/mall/village/camp composition, shared finish, retained collision |
| Terrain materials | `tests/terrain_material_validation.gd` | `TERRAIN MATERIAL VALIDATION OK (35 checks)` | Four CC0 ground sources, biome mask, lighting-responsive blend, no runtime 3D, CanvasModulate response |
| Resource scatter | `tests/resource_scatter_validation.gd` | `RESOURCE SCATTER VALIDATION OK (72 checks)` | 87 stable IDs, 3–5 step durability, zero intermediate yield, one-unit completion, late-join snapshots |
| Auto-aim | `tests/auto_aim_validation.gd` | `AUTO AIM OK (46 checks)` | Weighted scoring, 150° cone, LOS invalidation, hysteresis — not nearest-only |
| Tower/trap combat | `tests/tower_combat_validation.gd` | `TOWER COMBAT OK (70 checks)` | Three towers + blast/slow/root traps, host damage/status, replicated runtime |
| Enemy presentation | `tests/enemy_presentation_validation.gd` | `ENEMY PRESENTATION OK (44 checks)` | Eight variants, baked headings, contact_offset/radius, uniform scale |
| Enemy impact | `tests/enemy_impact_validation.gd` | `ENEMY IMPACT OK (42 checks)` | Knockback mass, root suppression, snapshot-fed health bars |
| VFX director | `tests/vfx_validation.gd` | `VFX DIRECTOR OK (133 checks)` | Pooled muzzle/impact/debris, no simulation authority |
| Health readability | `tests/health_readability_validation.gd` | `HEALTH READABILITY OK (67 checks)` | Shared `HealthBar2D`, screen-pixel thicknesses, camp-relative Base bar, rest/bevel ratios |
| Damage feedback | `tests/damage_feedback_validation.gd` | `DAMAGE FEEDBACK OK (35 checks)` | Hit wash inside the one weather pass, strongest-wins, zero scale = absent |
| Impact camera | `tests/camera_feedback_validation.gd` | `CAMERA FEEDBACK OK (21 checks)` | Trauma, offset-only writes, accessibility scale |
| Mobile systems | `tests/mobile_systems_validation.gd` | `MOBILE SYSTEMS OK (58 checks)` | Safe-area insets, 44×44 targets, UI vs world touch ownership |
| Tactical HUD | `tests/tactical_hud_validation.gd` | `TACTICAL HUD OK (52 checks)` | 148×58 dashboard, deck tabs, pagination, 50.9% area reduction |
| Co-op hardening | `tests/coop_hardening_validation.gd` | `COOP HARDENING OK (33 checks)` | RPC transfer strings, host validation, OfflineMultiplayerPeer fallback |
| Asset pipeline | `tests/asset_pipeline_validation.gd` | `ASSET PIPELINE VALIDATION OK (66,537 checks)` | Promoted runtime assets, hashes, no forbidden vault payload |
| Start menu layout | `tests/start_menu_layout_validation.gd` | `START MENU LAYOUT OK` | Character-select geometry, non-intercepting chrome |
| Structure readability | `tests/structure_readability_validation.gd` | `STRUCTURE READABILITY OK` | Eight unique silhouettes, shared bar/shadow primitives |
| Player avatar | `tests/player_avatar_readability_validation.gd` | `PLAYER AVATAR READABILITY OK` | Baked actor scale, legacy-presentation escape hatch |
| Wild atlas context | `tests/existing_wild_atlas_context_validation.tscn` | `pockets=9 \| unhostable=1 \| captures=36` | Placement clearance vs obstacles; does **not** authorize non-tree wild promotion |
| Enemy presentation render | `tests/enemy_presentation_render_validation.tscn` | `variants=8 \| captures=3` | Mobile/Vulkan contact sheet |
| Structure / HUD / VFX renders | `tests/structure_*_render_validation.tscn`, `tests/tactical_hud_render_validation.tscn`, `tests/vfx_gameplay_scale_render_validation.tscn` | GPU captures | Gameplay-scale silhouettes, dashboard, VFX ownership |
| ENet probes | `tests/enet_peer_probe.gd`, `tests/resource_enet_probe.gd`, `tests/tactical_enet_probe.gd` | two-process loopback | Movement/actions, gather replication, tactical pool/night/base |
| Export verifier | `tests/export_pack_verifier/verify_export_pack.gd` | isolated PCK load | Runtime closure, forbidden-payload inventory |

## Running Tests

Import once after asset or `.import` changes, then run a headless gate:

```powershell
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --editor --path 'C:\Users\heikk\Desktop\Claude\gpt_peli' --import --quit

& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path 'C:\Users\heikk\Desktop\Claude\gpt_peli' --script res://tests/smoke_test.gd
```

Focused contract gate (same pattern, swap the script):

```powershell
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path 'C:\Users\heikk\Desktop\Claude\gpt_peli' --script res://tests/world_map_validation.gd
```

GPU capture gate — **no** `--headless`. Godot renders the scene at the logical viewport:

```powershell
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64.exe' --path 'C:\Users\heikk\Desktop\Claude\gpt_peli' res://tests/world_render_validation.tscn
```

A windowed run whose script fails to parse (`untyped_declaration = 2`) leaves the Godot window open. Kill the process before re-running.

## Test Structure

Headless gates follow one shape (`tests/smoke_test.gd`, `tests/world_map_validation.gd`):

```gdscript
extends SceneTree

var _checks: int = 0
var _failures: int = 0

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	_validate_project_configuration()
	# ...
	_finish()

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS | %s" % message)
		return
	_failures += 1
	push_error("FAIL | %s" % message)

func _finish() -> void:
	if _failures == 0:
		print("SMOKE OK (%d checks)" % _checks)
		quit(0)
		return
	push_error("SMOKE FAILED (%d/%d checks failed)" % [_failures, _checks])
	quit(1)
```

GPU gates `extends Node2D`, live in a `.tscn`, await a frame, then `get_viewport().get_texture()` into `artifacts/`. They print `... RENDER OK | method=%s | driver=%s | captures=N`.

**Patterns:**
- Setup: `preload` the production scene, `instantiate()`, `root.add_child`, `await process_frame`, call `ensure_built()` on the world map.
- Teardown: `queue_free()` then `await process_frame` before `quit`.
- Assertion: boolean `_check(condition, message)` — no assertion library. Prefer reading live constants out of the class (`BesprenWorldMap2D.STARTING_CAMP_POSITION`) over duplicating a stale number in prose.
- Source-contract checks: `FileAccess.get_file_as_string("res://src/coop/coop_session.gd").contains("@rpc(...)")` in `tests/coop_hardening_validation.gd` pins transfer mode, not just behavior.

## Mocking

**Framework:** none. No mock library.

**Patterns:**
- Inject a `Callable` resolver (`CoopSession` `_motion_resolver`, `_fire_direction_resolver`) rather than stubbing the SceneTree.
- Build a tiny `StaticBody2D` in-script when a collider is required (`tests/smoke_test.gd` projectile impact body).
- For RPC shape, instantiate `CoopSession` under an `OfflineMultiplayerPeer` so `is_server()` is true at peer 1 — the same path the game uses in Solo.

**What to Mock:**
- Network peers (offline peer stands in for a server with no clients).
- Motion/fire resolvers when the test is about validation, not the world grid.

**What NOT to Mock:**
- Atlas textures, shaders, manifests, or camp position. Gates load the real resource and fail if the path moved.
- `HealthBar2D` / `GroundShadow` internals via a fake draw — convert authored units through the real `SCREEN_TO_WORLD` constant.

## Graphics / Map Validation Patterns

**Logic gates vs pixel gates:**
- Logic (`world_map_validation.gd`, `terrain_material_validation.gd`, `polyhaven_*_validation.gd`) proves seeds, counts, z-index, collision retention, manifest SHA-256, "no Node3D in the export closure."
- Pixel (`world_render_validation.tscn` and the `*_render_validation.tscn` family) proves delivered luma, silhouette, night response. Dummy headless renderer cannot prove pixels.

**Noise floor:**
- Run a capture gate twice on the same code before reading a before/after diff. `TIME`, actor frames, and the camp `AmberLight` pulse move thousands of pixels between identical runs. Eleven world frames are byte-stable (`forest_density`, `city_barrier`, `east_village`, …). Judge tree/prop claims on a stable frame; never on a camp frame.

**Measure delivered pixels, not source PNGs:**
- Convert through the real scale chain (`Sprite.scale * instance scale * camera zoom 0.38`). Read `Texture2D.get_image().get_used_rect()` for alpha bounds.
- A windowed Godot run returns the physical window (960×540) not the logical 480×270. Derive scale from the image, or capture through a 480×270 `SubViewport`.
- `fwidth` outlines are logical quantities — 1× is exact. Texture minification is a physical-pixel quantity under `canvas_items` stretch — a 1× capture is a worst-case bound, not the phone.
- Pause the SceneTree before a two-pass difference capture. Pausing does **not** stop shader `TIME`; pin `pulse_speed = 0` and hide other `TIME` materials.
- A near-black capture background cannot test a dark shadow or a dark structure. Use the shipped ground (forest ~50 luma, urban ~60).
- A metric that includes a feature drawn outside the subject (health bar, outline ring, trunk rows in a "ground" ring) is measuring that feature. Mask on source alpha, not the composite.
- A gate that tests the **input** to a compressive operator (`Color.lightened`) does not test its output. Expose the output (`bevel_color()`) and assert ratios.

**Map-specific:**
- Presentation-only atlas swaps must leave collision, flow mask, and `stable_seed` unchanged. `local_environment_validation.gd` pins `scale.y / scale.x` after fence wobble.
- Pocket tables and obstacle tables authored separately will overlap. Record unhostable pockets (`MAXIMUM_UNHOSTABLE_POCKETS = 1`); do not silently move the pocket — that moves ambient placement determinism.
- Capture gates that read live constants stay current when the camp moves; PNG artifacts on disk do not. Re-run the GPU gate after any world-authoring change.
- Wild non-tree frames stay `runtime_promotion = forbidden_pending_human_visual_veto` until a 1× review passes. A deferred review is a promotion by default — do not treat a green placement gate as an art sign-off.

## Coverage Philosophy

- Desktop gates prove the contracts they inspect: types, numbers, RPC strings, hashes, logical-viewport pixels.
- They do **not** prove Android rendering, audio perception, thermals, touch/safe-area ergonomics, lifecycle interruption, or physical two-device LAN.
- No coverage percentage is enforced. New gameplay domain → add a focused `*_validation.gd`. New visual language → add or refresh a GPU capture and a logic pin (manifest, shader path, z-index).
- Device certification and a post-feedback-stack APK rebuild remain open. Do not treat `SMOKE OK (207)` as a release gate.

---

*Testing analysis: 2026-09-18*
