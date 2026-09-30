# Technical Concerns

**Analysis Date:** 2026-09-18

Premium-asset, graphics, and map-layout issues sit first. Product gaps (Base deposit, persistent inventory, long-term progression) are named only as out-of-scope slice limits, not as code debt: no deposit/save stubs exist under `src/`. Session gather inventory in `src/world/resource_scatter_2d.gd` and loot credits in `src/economy/loot_box_manager_2d.gd` feed the shared construction pool in `src/tactical/tactical_build_system.gd`, then stop.

## High Priority

**Android device gates remain unproven:**
- Location: `CLAUDE.md` sections 12–15; `export_presets.cfg`; `build/android/`
- Impact: Desktop headless/GPU gates do not prove Android pixels, thermals, touch/safe-area ergonomics, lifecycle interruption, or physical two-device LAN. Shipping claims about 480×270 readability, 60/30 FPS, and co-op on UDP 8791 are desktop-only until a representative device run exists.
- Fix approach: Rebuild a current APK from `export_presets.cfg` (Android, `arm64-v8a`, `com.bespren.game`), install on mid-range hardware, and certify: Mobile/Vulkan pixels vs the twenty-five `tests/world_render_validation.tscn` frames; frame time and thermal throttle; `src/input/mobile_controls.gd` 44×44 targets plus safe-area insets; background/resume; two-device Host/Join on `src/coop/coop_session.gd` port `8791`. Do not treat `SMOKE OK (207)` or desktop ENet loopback as substitutes.

**Packaged APK/PCK predates the feedback stack:**
- Location: `build/android/Bespren-actor-roster.apk`, `Bespren-actor-roster.pck`, `Bespren-debug.apk`, `Bespren-polish.apk`, `Bespren-runtime.pck`, `Bespren-runtime-polish.pck`; `data/runtime_export_closure.json`; `scenes/build/runtime_export_dependencies.tscn`
- Impact: Last isolated closure load was 173 resources / 23 scenes. Current source closure lists 201 unique runtime resources and 202 strong scene dependencies, including `src/feedback/camera_shake_2d.gd`, `src/feedback/vfx_director.gd`, `src/visual/actor_ground_shadow_2d.gd`, and `src/visual/health_bar_2d.gd`. Installing an on-disk APK ships a game without the current juice, health language, or contact shadows.
- Fix approach: Re-export from `export_presets.cfg` after an import pass, re-run the inventory/forbidden-payload gate, verify APK Signature Schemes v2/v3, then device-install. Do not certify from `Bespren-actor-roster.*`.

**Fir canopy density still reads as a stalk with tiers:**
- Location: `src/world/world_obstacle_2d.gd` (`WILD_TREE_REGIONS`, `_install_imported_tree_visual`); `src/world/world_ambient_scenery_chunk_2d.gd` (`WILD_TREE_REGIONS`); `assets/2d/environment/polyhaven_wild/polyhaven_wild_atlas.png`; `tools/art/render_polyhaven_wild_sprites.py`
- Impact: Holdout clip at `FIR_GROUND_CLIP = 0.40` removed the hexagonal “poker-chip” mound. At 1× gameplay zoom the five shipped frames (`fir_tree_01` ×3, `tree_small_02` ×2) still read as a sparse conifer stalk rather than a mass. Distant ambient canopy and colliding trunks share those five `Rect2` literals, so the silhouette defect is visible on both the walkable tree and the background stand.
- Fix approach: Geometry, not grade. Candidates already recorded: two-clone clump in the bake, or a denser CC0 source. Measure at 1× on `artifacts/world_forest_density_validation.png` (zero between-run TIME delta). After any rebake, re-derive both `WILD_TREE_REGIONS` tables as `cell_region.xy + padded_atlas_region.xy` from the new manifest — do not copy `padded_atlas_region` verbatim.

**Wild non-tree frames blocked pending human visual veto:**
- Location: `tests/existing_wild_atlas_context_validation.gd` (`runtime_promotion = forbidden_pending_human_visual_veto`); `artifacts/existing_wild_atlas_context_validation/existing_wild_atlas_context_validation.json`; `assets/2d/environment/polyhaven_wild/`
- Impact: Of twenty-nine wild frames, runtime draws five tree yaws only. Root clusters read as tan boulders (~2.1× ground luma, no contact), fallen branches as black worms with white cores (contour outweighs subject ~3:1), and recipe-B shrub as a crack on the slab. Promoting them would drop unreadable microprops onto wilderness pockets.
- Fix approach: Keep `runtime_promotion` forbidden until a new composition passes a 1× review on hosted pockets. Do not wire `ROOT_REGIONS` / `BRANCH_REGIONS` / `SHRUB_REGION` into `src/world/`. A green capture count is placement evidence, not art promotion.

**Capture-gate TIME noise and stale PNGs:**
- Location: `tests/world_render_validation.tscn`; `tests/world_render_validation.gd`; `artifacts/world_*_validation.png`
- Impact: Twenty-five captures. Run twice on unchanged code: only eleven frames are byte-identical (`central_road_shoulder`, `city_barrier` day/night, `city_building_detail`, `city_density`, `city_salvage`, `east_village`, `forest_density`, `forest_log`, `forest_rock`, `local_car_wreck`, `mall`). The other fourteen move from shader `TIME` (resource pulse, camp `AmberLight`/aura, actor frames). Camp frames can move 5,912 pixels by day and 21,799 at night between identical runs — more than some real art diffs. A capture set that still shows camp at `(11264, 1536)` while `BesprenWorldMap2D.STARTING_CAMP_POSITION` is `(9950, 2400)` proves the previous build, not this one.
- Fix approach: Measure the noise floor (two identical runs) before attributing a diff. Judge tree claims on `forest_density` (stable). Pause `SceneTree` and pin `pulse_speed` to 0 before difference probes; pausing does not stop shader `TIME`. Re-run GPU captures after camp/atlas moves. Windowed Godot returns physical size (`960×540` under `project.godot` override), not logical 480×270 — derive scale from the image.

## Medium Priority

**Wilderness pocket 2 unhostable under Ostari mall shell:**
- Location: `src/world/world_ambient_scenery_2d.gd` `WILDERNESS_POCKETS[2]` = `Vector4(2600, -2200, 700, 620)`; `src/world/world_wilderness_accent_2d.gd` (same table); `src/world/world_map_2d.gd` `_build_mall()` `OstariSouthShell` at `(4850, -3150)` size `(6400, 1800)` `VisualKind.MALL_SHELL`; `tests/existing_wild_atlas_context_validation.gd` (`MAXIMUM_UNHOSTABLE_POCKETS = 1`)
- Impact: South mall foundation bounds x 1650..8050, y -4050..-2250 cover the upper ~45% of a pocket the ambient layer calls wilderness. A 10-unit grid of 12,031 samples found no clear centre for a 156-unit review card. Accent/scenery still sample the pocket; colliding shell and “wilderness” label disagree. A second unhostable pocket fails the wild-context gate.
- Fix approach: Record, do not silently move. Relocating the pocket changes ambient placement determinism and `tests/world_map_validation.gd` counts. If a layout pass is authorized, edit obstacle table and pocket table together, then re-run world-map (169) and wild-context (`pockets=9 | unhostable=1 | captures=36`) gates.

**Salvage atlas has no runtime consumer:**
- Location: `assets/2d/environment/polyhaven_salvage/`; `tools/art/run_wild_bake.py`; `tools/asset_pipeline/build_polyhaven_wild_atlas.gd` (`FAMILY_ORDER` includes `polyhaven_salvage`); `data/runtime_export_closure.json` (wild atlas listed, salvage not)
- Impact: Sixteen sources / thirty-eight frames packed (SHA-256 `4b880142841bace5b3b69f4cfd0c83a6064d1720fa56f512d6479c8b62f859ef`) and manifested. Nothing under `src/` or the export closure names it. Bake cost and disk stay; players see none of it. `run_wild_bake.py` rebuilds the report `families` block from scratch, so a wild-only bake drops salvage from `polyhaven_wild_render_report.json` and the packer (which requires both) refuses the whole report.
- Fix approach: Keep as baked reserve until a presentation-only consumer is designed against colliding salvage/scrap already in `src/world/world_obstacle_2d.gd`. Always bake both families or hand-merge the report. Do not add salvage to `runtime_export_closure.json` until a live `preload` exists.

**Presentation-only vs collision/flow drift:**
- Location: `src/world/world_obstacle_2d.gd` (`_install_local_fence_visuals`, `_install_imported_tree_visual`, atlas sprites); `src/world/world_ambient_scenery_2d.gd`; `src/world/world_background_decor_2d.gd`; `src/world/world_wilderness_accent_2d.gd`; `src/ai/flow_field_navigation_2d.gd`
- Impact: Atlas sprites replace presentation only. Collision, flow mask, `WORLD_BUILD_SEED`, and peer-one `resolve_player_motion` stay canonical. Visual scale is often derived from `collision_radius` (trees: longer edge fitted to `collision_radius * 4.35`; a shorter fir crop therefore draws 1.03×–1.07× larger at the same blocker). Fence flip/slip/wobble never touch the `CollisionShape2D`. Ambient scenery at `z_index = -4` never occludes gameplay at `5`, so a canopy can lean over a road the flow field still treats as open. Players can walk through dressed volume or be blocked by empty footprint.
- Fix approach: Grep collision/flow before any visual scale change. Keep “presentation only” comments as a contract, not a hope. World-map validation must keep asserting obstacle counts, walkability, and flow raster independently of sprite regions.

**Duplicated wild-tree region literals:**
- Location: `src/world/world_obstacle_2d.gd` lines 140–146; `src/world/world_ambient_scenery_chunk_2d.gd` lines 22–28
- Impact: Five identical `Rect2` values in two files. A rebake that updates one consumer leaves colliding trunks and distant canopy sampling different cells. `padded_atlas_region` is cell-local; copying it as atlas-absolute samples the wrong cell.
- Fix approach: After every wild atlas pack, re-derive both tables from the manifest with the same script. Prefer one shared constant if a later pass touches either file; until then, treat dual literals as a two-site edit.

**Pocket tables and obstacle tables authored separately:**
- Location: `src/world/world_ambient_scenery_2d.gd` (`CITY_POCKETS`, `MALL_POCKETS`, `FOREST_POCKETS`, `WILDERNESS_POCKETS`, …); `src/world/world_wilderness_accent_2d.gd` `WILDERNESS_POCKETS`; `src/world/world_map_2d.gd` `_build_mall()`, village/city obstacle builders
- Impact: Pocket 2 vs `OstariSouthShell` is the known collision. Forest belt pockets previously sat entirely inside road-clearance bands and silently donated their budget to fillable pockets. Accent layer duplicates the wilderness table so density art cannot perturb ambient RNG — but it also duplicates the overlap.
- Fix approach: Any new pocket must be sampled against `WorldObstacle2D.get_world_bounds` and road-edge clearance, not only against origin walkability. Keep `MAXIMUM_UNHOSTABLE_POCKETS = 1` as a tripwire. Do not “fix” overlap by shrinking a colliding shell’s visual without changing its footprint.

**Village fence vs house projection mismatch:**
- Location: `src/world/world_obstacle_2d.gd` `_install_local_fence_visuals`, `_draw_village_house`; `src/world/world_map_2d.gd` west/east village house placement
- Impact: Houses are three-quarter bakes; wooden barricade is a top-down projection. Alternating flip/slip/wobble removed the stamp-repeat, but the first west-fence segment still merges with the house behind it into one ~66-pixel run. Adjacent variety is solved; family projection is not.
- Fix approach: Recorded open. Do not retune `FENCE_SEGMENT_*` to hide the merge. A later art pass should either rebake the barricade to the house camera or accept a different fence language. Reuse the original run-detector instrument; a rewritten detector measures different crops.

**`ActorGroundShadow2D.GROUND_FLATTEN` is 0.46 against a 52° bake:**
- Location: `src/visual/actor_ground_shadow_2d.gd` (`GROUND_FLATTEN = 0.46`); `tools/art/aaa_bake_rig.py` (`CAM_ELEVATION_DEG = 52.0`)
- Impact: Docstring previously claimed 0.46 was the 52° ground-circle projection. Actual projection is `sin(52°) = 0.788`. 0.46 is `sin(27.4°)`. Props use other flattens (0.34 atlas, 0.55 foliage, aspect-derived structures). Changing 0.46 without a Mobile/Vulkan sweep would unseat every survivor and horde contact that `contact_radius` / `Shadow.position` were measured against.
- Fix approach: Keep 0.46 until a rendered sweep brackets 0.46 vs ~0.79 vs 1.0 at gameplay zoom 0.38 on real ground (not luma-17 capture backgrounds). A near-black frame cannot test a dark shadow.

**Canopy hue is a runtime multiply over a bake defect:**
- Location: `src/world/world_obstacle_2d.gd` `WILD_TREE_TINT = Color(0.60, 1.0, 0.70)`; `src/world/world_ambient_scenery_chunk_2d.gd` `WILD_TREE_TINT = WorldObstacle2D.WILD_TREE_TINT * Color(0.78, 0.83, 0.74, 0.88)`
- Impact: Shipped firs sit hue 56–61 (straw, adjacent to Heikki gold / camp amber). Tint folds into entry `COLOR` ahead of `sleek_sprite_finish.gdshader` and cannot lift a value defect baked into the PNG (the old contact puck). Durable fix is a rebake with exposure that does not AgX-desaturate toward tan.
- Fix approach: Rebake pines; then drop or retune `WILD_TREE_TINT`. Until then keep both consumers on the same correction (ambient already multiplies the obstacle constant).

**Hand-maintained export closure goes stale silently:**
- Location: `data/runtime_export_closure.json`; `scenes/build/runtime_export_dependencies.tscn`; `tests/smoke_test.gd`
- Impact: `class_name` + `.new()` scripts are invisible to a scene-graph dependency walk. Feedback-stack scripts shipped in runtime while named in neither artifact; the gate sat at 194/195 and passed because it was not re-run against the closure it pins.
- Fix approach: When adding a `class_name` constructed from code, add both the script and any packed scenes to the closure and the strong-retain scene in the same change. Re-run smoke. Derive paired counts from one source where a gate currently authors both.

**Docs vs live scenery/capture counts:**
- Location: `docs/WORLD_MAP_FOUNDATION.md` (576 silhouettes, 172 forest, 23 captures, `WORLD MAP VALIDATION OK (150)`); `src/world/world_ambient_scenery_2d.gd` `TOTAL_SCENERY_COUNT = 640`, `ZONE_SCENERY_COUNTS` forest 236; `CLAUDE.md` captures=25, world map 169
- Impact: A later planner that trusts `docs/` will under-count ambient load and look for the wrong capture set.
- Fix approach: Treat `CLAUDE.md` and the live `.gd` constants as canonical. Refresh foundation docs in the same change that moves counts.

**Accessibility scales exist; no player-facing settings or Android lifecycle:**
- Location: `src/feedback/camera_shake_2d.gd` `intensity_scale`; `src/visual/weather_overlay.gd` `damage_intensity_scale`; `src/visual/health_bar_2d.gd`; no `NOTIFICATION_APPLICATION_*` / pause handlers under `src/`
- Impact: CLAUDE.md 11 requires weather/shake/pulse off-switches and pause/background/resume before content lock. Scales default to 1.0 with no settings UI. Overlay ignores mouse (`MOUSE_FILTER_IGNORE`) but the app does not pause on Android background.
- Fix approach: Wire the existing 0=absent scales to a settings surface; add lifecycle pause. Do not add a second full-screen pass for damage.

## Low Priority / Recorded Open

**`Addons/` vault is a huge source archive behind `.gdignore`:**
- Location: `Addons/`; `Addons/.gdignore`; `docs/ADDONS_AUDIT_EXTRACTION_GATE.md`; `tools/asset_pipeline/audit_and_extract_runtime_assets.py`
- Impact: Tens of thousands of third-party files (deep audit: 31,404 physical ledger records, 145 archive wrappers, 4,684 members). Godot does not scan it as `res://` production. `export_presets.cfg` excludes `Addons/*`. Vault size still hurts clone/disk and tempts accidental promotion.
- Fix approach: No destructive cleanup is authorized. If reduction is required: license/dependency manifest first, separate generated caches from authored sources, confirm before any deletion. Promote only through the audited extractor into `assets/` with `assets/runtime_asset_manifest.json`.

**Wild-family provenance is weaker than camp/character manifests:**
- Location: `tools/art/write_generated_asset_manifest.py` (camp, structure, character only); `assets/2d/environment/polyhaven_wild/polyhaven_wild_manifest.json`; `tests/smoke_test.gd`; `tests/world_map_validation.gd`
- Impact: Smoke and world-map pin the atlas PNG, not the wild manifest. A stale manifest is caught by nothing. EEVEE wild/salvage rebakes are allowed one-unit deltas on ≲0.1% of pixels; survivor bakes must match exactly. Mixing those contracts hides real drift.
- Fix approach: Pin wild/salvage manifests in smoke, or extend `write_generated_asset_manifest.py`. Do not treat wild SHA-256 as bit-identical across unmodified reruns.

**Shader/grade measurement traps (standing instructions, not open bugs):**
- Location: `shaders/sleek_sprite_finish.gdshader`, `shaders/sleek_canvas_grade.gdshader`, `shaders/toon_emissive_outline.gdshader`, `shaders/surface_weathering.gdshader`, `shaders/projectile_glow.gdshader`, `shaders/solid_white_flash.gdshader`, `shaders/base_scale_glow.gdshader`; `CLAUDE.md` sections 7–9
- Impact: Reintroducing `vec4 source = texture(TEXTURE, UV) * COLOR` squares every texel. Compressive operators (`Color.lightened`) after a darken undo the darken. Gates that assert inputs (bevel width, `fill_color()`) miss outputs (`bevel_color()`). Hue bands that straddle two anchors report one family as the other. Near-black capture grounds cannot test dark subjects. 1× captures overstate texture minification under `canvas_items` stretch.
- Fix approach: Keep `vec4 source = COLOR;`. Test operator outputs. Name hue-band edges against locked anchors. Judge contours at 1× logical; judge minified textures at device scale as well.

**Legacy survivor presentation is a recovery path, not the ship path:**
- Location: `src/game/player_avatar.gd` `BAKED_ACTOR_VISUAL_SCALE = 1.5`, `force_legacy_presentation`; `scenes/characters/heikki.tscn`, `shane.tscn`; `scenes/ui/StartMenu.tscn`
- Impact: Gameplay draws `assets/2d/actors/scenes/hero_*.tscn`. `heikki_topdown.png` / `shane_topdown.png` appear on Start Menu cards and when `force_legacy_presentation` is true. Measuring those PNGs as the in-world survivors produces false silhouette/hue findings.
- Fix approach: Confirm the shipped draw path before measuring an asset. Keep legacy line weight in family with world sprites so recovery does not look like a second game.

**`HealthBar2D` / `GroundShadow` divergence risk:**
- Location: `src/visual/health_bar_2d.gd`; `src/visual/ground_shadow.gd`; `src/visual/actor_ground_shadow_2d.gd`; `src/tactical/placed_structure_2d.gd`
- Impact: Structures previously hand-rolled mint `draw_rect` bars and flat `draw_circle` contacts. Shared classes now own both. A new widget that draws its own bar or disc reintroduces the loud-mint / hole-in-the-ground defects.
- Fix approach: Grep `draw_rect` / `draw_circle` health or contact primitives rather than trusting a class docstring that claims uniqueness.

**World lights need `range_z_min = -20`:**
- Location: `scenes/characters/network_player.tscn`; `scenes/world/base_core.tscn`; `src/tactical/placed_structure_2d.gd`
- Impact: Terrain sits at `z_index = -20`. Default light Z min −10 lights actors and leaves ground dark — illuminated bodies over unlit terrain. Only those three sites set −20.
- Fix approach: New `PointLight2D` nodes that should reach ground copy this value. Do not add shadow-casting 2D lights without a budget exception (`CLAUDE.md` section 10: 0 shadow-casting lights in foundation).

**Product gaps (not code debt):**
- Location: `CLAUDE.md` sections 1, 4, 14, 15
- Impact: Base Core deposit feedback, persistent inventory, and long-term progression are outside the implemented slice. `BesprenResourceScatter2D` session inventories and `LootBoxManager2D` grants credit `TacticalBuildSystem`’s shared pool (`INITIAL_RESOURCE_POOL` 120/100/80) and do not persist across process restarts.
- Fix approach: Do not stub these in graphics/layout phases. Pick one coherent next slice after device certification.

## Fragile Areas

**World atlas region tables:**
- Location: `src/world/world_obstacle_2d.gd`, `src/world/world_ambient_scenery_chunk_2d.gd`, `src/world/world_background_decor_chunk_2d.gd`
- Why fragile: Cropped `AtlasTexture` rects are literals derived from packer manifests. A one-pixel packer shift mis-crops every tree, house, or district sprite while collision stays put.
- Safe change pattern: Change the generator, pack, re-derive literals from the manifest with a script, update SHA-256 pins in smoke/world-map, re-run GPU captures. Never edit one consumer’s `Rect2` by eye.

**Deterministic world build seed:**
- Location: `src/world/world_map_2d.gd` `WORLD_BUILD_SEED = 0xB35E7E`; scenery/decor/cover RNGs derived from it
- Why fragile: Visual-only density still consumes sequential RNG. Inserting a roll shifts every later placement. Accent layer exists specifically to avoid perturbing ambient streams.
- Safe change pattern: New visual layers get their own salt (`WORLD_BUILD_SEED + N`) and must not insert into existing loops. Re-run `tests/world_map_validation.gd` (169) after any placement edit.

**Capture and difference probes:**
- Location: `tests/world_render_validation.gd`; `tests/existing_wild_atlas_context_validation.gd`; retired sweep scenes under `artifacts/`
- Why fragile: TIME, animation clocks, window size vs logical size, unpaused `AnimatedSprite2D`, and composite-alpha masks have each produced confident wrong numbers.
- Safe change pattern: Pause the tree; pin pulsing shader speeds; hide `TIME`-driven materials; mask on source alpha downsampled with the colour filter; derive capture scale from the PNG; delete probe scenes once they have answered (`CLAUDE.md` 8).

**Host-authoritative motion vs presentation:**
- Location: `src/coop/coop_session.gd`; `src/world/world_map_2d.gd` `resolve_player_motion`, `is_position_walkable`; 512-unit `_obstacle_broadphase`
- Why fragile: Clients send intents; peer 1 integrates at 20 Hz against static collision. Visual canopy/fence must not be mistaken for the walk grid. Broadphase pads rotated rects by `clearance * sqrt(2)`; a tighter pad would false-accept.
- Safe change pattern: Gameplay movement changes go through `resolve_player_motion` only. Do not “fix” a stuck player by shrinking a sprite.

**CanvasItem shader entry `COLOR`:**
- Location: `shaders/*.gdshader`
- Why fragile: Copy-pasting a fragment header that samples `TEXTURE` into `COLOR` re-squares the whole dressed world (props, structures, camp, nodes, tracers).
- Safe change pattern: New canvas shaders start from `vec4 source = COLOR;` and keep the old squared idiom only in comments.

**Shared readability widgets:**
- Location: `src/visual/health_bar_2d.gd`, `src/visual/ground_shadow.gd`
- Why fragile: Instance scale (`game_world.tscn` Base Core `Vector2(2, 2)`), hide-at-full policy, and rest-darken order all change delivered pixels. A bar that tests authored fill and not delivered bevel will pass a loud widget.
- Safe change pattern: Assert `bevel_color()` vs `fill_color()` as a ratio; read instance scale out of the scene; never author a second bar.

## Security

- No networked account auth and no runtime secrets files in `src/`. Do not read `.env` or credential files if present.
- LAN transport is Godot ENet on UDP `8791` (`src/coop/coop_session.gd`) with `encrypt_pck=false` in `export_presets.cfg`. Host validates character IDs, finite movement, interaction cooldown, and allowed `interact`/`fire` identifiers, then broadcasts. This is a trusted-LAN slice, not an internet-hardened service. Do not expose 8791 beyond local network without a new auth contract.
- `Addons/` is excluded from Android export (`exclude_filter="Addons/*,..."`). Promoting vault content into `res://assets/` without license review is a compliance risk, not only an art risk.
- `OfflineMultiplayerPeer` fallback keeps peer-one authority when ENet fails; clients must not grow a second simulation.

## Performance

- Logical viewport 480×270, `canvas_items` stretch, Mobile renderer, HDR 2D off (`project.godot` `renderer/rendering_method="mobile"`). One full-screen custom pass (`src/visual/weather_overlay.gd` + `shaders/weather_overlay.gdshader`). Zero shadow-casting 2D lights in foundation. Zero dynamic shader loops.
- Horde hard cap `HordeDirector.MAX_ALIVE_ENEMIES = 110` (`src/ai/horde_director.gd`). Raising it is a device thermal decision, not a design tweak.
- Obstacle walk queries: 512-unit broadphase in `src/world/world_map_2d.gd` (~3.8 µs vs ~210 µs linear over 461 obstacles). Do not revert to a full scan on the 20 Hz authority tick.
- Ground cover: 3,245 clusters / 38,947 elements, two draws per cluster, 170 chunks, no material (`src/world/world_ground_cover_2d.gd`). Density constants were kept after measurement; tripling cluster count is the wrong response to a “sparse floor” complaint.
- Ambient scenery budget is live 640 groups (`TOTAL_SCENERY_COUNT`), not the older 576 in `docs/WORLD_MAP_FOUNDATION.md`. Chunked at 4096 units.
- Device frame time, overdraw, and thermal throttle are unmeasured. Quality-tier reductions (weather/light energy) exist as policy in `CLAUDE.md` 10, not as runtime code.

## Testing Gaps

- Desktop `tests/smoke_test.gd` (`SMOKE OK (207)`), world map (169), wild-context (`pockets=9 | unhostable=1 | captures=36`), and focused art/combat gates do not prove Android rendering, audio perception, thermals, touch, or two-device sync.
- GPU capture gates prove logical 480×270 Mobile/Vulkan on the desktop binary pointed at the scene without `--headless`. They do not prove a phone panel under `canvas_items` stretch.
- TIME-unstable frames cannot certify camp-adjacent art. Difference probes that omit obstacle footprints certify fences, not shrubs.
- No automated test covers Android background/resume, controller disconnect, or late Player 2 join.
- Accessibility 0-scale paths are unit-testable on desktop; there is no settings UI test because there is no settings UI.
- Export-closure tests pass on authored JSON, not on “every `class_name` constructed at runtime.”
- Physical two-device ENet (movement, gather, tactical, auto-aim) remains a release gate after desktop loopback.

## Do Not

- Do not delete or shrink `Addons/` without a license manifest and explicit confirmation. `.gdignore` is the isolation mechanism.
- Do not promote wild non-tree frames, salvage atlas sprites, fern/grass macro probes, or any `runtime_promotion = forbidden_*` artifact into `src/world/` or the export closure.
- Do not move wilderness pocket 2 to make a review card fit; that is a world-authoring change, not a gate workaround.
- Do not change `GROUND_FLATTEN`, contact radii, or outline widths without a Mobile/Vulkan delivered-pixel sweep on real ground.
- Do not reintroduce `texture(TEXTURE, UV) * COLOR` in canvas shaders.
- Do not treat `docs/WORLD_MAP_FOUNDATION.md` scenery/capture counts as live.
- Do not certify from `build/android/Bespren-actor-roster.*`.
- Do not fold Base deposit, persistent inventory, or progression into a graphics/layout phase.
- Do not add a second full-screen pass, HDR 2D, or shadow-casting 2D lights without a budget exception backed by device profiler evidence.
- Do not “fix” collision by editing a sprite, or “fix” a silhouette by grading geometry.

---

*Concerns analysis: 2026-09-18*
