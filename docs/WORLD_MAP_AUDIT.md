# World Map Audit — Live 14×14 Census

Audit date: 2026-09-19
Scope root: `C:\Users\heikk\Desktop\Claude\gpt_peli`
Runtime target: Godot 4.7.1 Mobile, 2D, 480×270 landscape

This census greps live `const` values in `src/world/` and `tests/` as they stand on 2026-09-19. It does not re-run GPU or headless world-map gates. It does not trust scenery, capture, or gate-count prose in `docs/WORLD_MAP_FOUNDATION.md`. This document is not pixel proof. On-disk `artifacts/world_*` freshness versus camp `(9950, 2400)` is not verified this session (RESEARCH A2). Filename inventory is not a claim that those PNGs match the live camera.

Phase 1 is docs-only (CONT-01, D-25, D-28). This file does not bump `LAYOUT_VERSION` or `WORLD_BUILD_SEED`. It does not edit `src/world/`.

## Method

Method is grep of live identifiers, not a render pass and not a foundation-doc paraphrase.

1. Read `const` and authored tables in `src/world/world_map_2d.gd`, `world_road_network_2d.gd`, dress/scatter scripts, and matching `tests/*validation*.gd`.
2. Quote the identifier, the numeric value, and the source path beside each row (D-26).
3. Do not re-run Godot GPU or `--headless` world-map gates. Those gates prove the old map; they are not this census.
4. Do not copy scenery 576 / forest 172 / captures 23 / `WORLD MAP VALIDATION OK (150)` from `docs/WORLD_MAP_FOUNDATION.md`. Those counts lag live code.
5. Do not treat on-disk `artifacts/world_*` PNGs as proof that the camp camera sits at `(9950, 2400)`. Capture-gate freshness versus camp is not verified this session (RESEARCH A2).
6. Comment figures that no live gate pins this session — for example the `461` obstacle remark on `OBSTACLE_BROADPHASE_CELL` — stay comments, not census pins (RESEARCH A3).

What this document is not: pixel proof, a redesign contract, a camera implementation, a wild-atlas promotion, or a `LAYOUT_VERSION` / `WORLD_BUILD_SEED` bump.

## Extents, seed, camp, cell

Locked playable world. Seed and layout version are frozen this phase (D-28). Camp coordinates are current-state, not a Phase 2 target.

| Constant | Value | File |
|----------|-------|------|
| `BesprenWorldMap2D.GRID_SIZE` | 14 | `src/world/world_map_2d.gd` |
| `BesprenWorldMap2D.CELL_SIZE` | 2048.0 | `src/world/world_map_2d.gd` |
| `BesprenWorldMap2D.PLAYABLE_HALF_EXTENT` | 14336.0 | `src/world/world_map_2d.gd` |
| `BesprenWorldMap2D.WORLD_SIZE` | 28672.0 (`PLAYABLE_HALF_EXTENT * 2.0`) | `src/world/world_map_2d.gd` |
| `BesprenWorldMap2D.WORLD_BUILD_SEED` | `0xB35E7E` — freeze; this plan does not change the `.gd` (D-28) | `src/world/world_map_2d.gd` |
| `BesprenWorldMap2D.STARTING_CAMP_POSITION` | `Vector2(9950, 2400)` | `src/world/world_map_2d.gd` |
| `BesprenWorldMap2D.STARTING_CAMP_REQUIRED_ROAD_EDGE_CLEARANCE` | 1600 | `src/world/world_map_2d.gd` |
| Comment-measured nearest road edge | 2098 | `src/world/world_map_2d.gd` comment on `STARTING_CAMP_POSITION`; gate pin `EXPECTED_STARTING_CAMP_ROAD_EDGE_DISTANCE` in `tests/world_map_validation.gd` |
| `BesprenWorldMap2D.STARTING_CAMP_OPEN_RADIUS` | 520 | `src/world/world_map_2d.gd` |
| `BesprenWorldMap2D.STARTING_CAMP_SATELLITE_COUNT` | 3 | `src/world/world_map_2d.gd` |
| Satellite Bedding offset | `Vector2(-650, -300)` (`StartingCampBedding`) | `src/world/world_map_2d.gd` `_build_starting_camp_satellites`; `tests/world_map_validation.gd` `EXPECTED_CAMP_SATELLITE_OFFSETS` |
| Satellite Supply offset | `Vector2(350, 650)` (`StartingCampSupplyCache`) | same |
| Satellite Medical offset | `Vector2(0, 720)` (`StartingCampMedicalCache`) | same |
| Derived camp cell | `(11, 8)` east-forest: `floor((9950+14336)/2048)=11`, `floor((2400+14336)/2048)=8` | derived from live constants; biome rule `column >= 10 and row <= 8` is `FOREST` |
| `BesprenResourceScatter2D.LAYOUT_VERSION` | 2 — freeze; do not bump (D-28) | `src/world/resource_scatter_2d.gd` |

Playable rect is `PLAYABLE_RECT`: origin `(-14336, -14336)`, size `(28672, 28672)`.

Camp is a secluded east-forest clearing, not a road-junction camp. Required road-edge clearance is 1600; the comment-measured nearest road edge is 2098. Three satellites sit as furniture offsets around the core. None of that is a dirt spur polyline — see Eight routes.

## Biome seats as-is

Current seats from `_build_biome_cells` / `get_biome_regions`. Not frozen. D-21 (districts may rearrange on the locked 14×14 grid) belongs to the redesign contract, not this census.

Fill order in `_build_biome_cells`: start `WILDERNESS`, then forest if perimeter or `(column >= 10 and row <= 8)` or `(column <= 2 and row >= 5)`, then overlay city / mall / west village / east village.

| Region key | Cells | Source |
|------------|-------|--------|
| `kaupunki` | `(1,1)–(5,5)` | `get_biome_regions` / `_build_biome_cells` (`Biome.CITY`) |
| `ostari` | `(7,2)–(10,5)` | `get_biome_regions` / `_build_biome_cells` (`Biome.MALL`) |
| `kyla_west` | `(1,9)–(4,12)` | `get_biome_regions` / `_build_biome_cells` (`Biome.VILLAGE_WEST`) |
| `kyla_east` | `(9,9)–(12,12)` | `get_biome_regions` / `_build_biome_cells` (`Biome.VILLAGE_EAST`) |
| `metsa_perimeter` | `PLAYABLE_RECT` | `get_biome_regions` |

Forest rule (Metsä wrap, not a fifth named region): `metsa_perimeter = PLAYABLE_RECT`; cell is `FOREST` when `column == 0 or row == 0 or column == GRID_SIZE - 1 or row == GRID_SIZE - 1` (perimeter) **or** `column >= 10 and row <= 8` **or** `column <= 2 and row >= 5`, unless a later district overlay wins. Camp cell `(11, 8)` is that east-forest belt.

Compass today: Kaupunki NW, Ostari NE interior, two Kylät south, Metsä wrapping the secluded camp. Those seats are current, not a lock.

## Eight routes and missing spur

`BesprenWorldMap2D._build_road_network` authors **eight** polylines. `dirt_flags` is `PackedByteArray([0, 0, 0, 0, 1, 1, 1, 1])` — four zeros then four ones. There is **no camp spur today**. Eight routes; none terminate at `(9950, 2400)`. D-02 is the *target* (dirt spur that meets asphalt). Live map has seclusion, not a spur polyline. Do not list a ninth route.

Widths from `src/world/world_road_network_2d.gd`: asphalt outer 540 / inner 420 (`ASPHALT_OUTER_WIDTH` / `ASPHALT_INNER_WIDTH`); dirt outer 480 / inner 360 (`DIRT_OUTER_WIDTH` / `DIRT_INNER_WIDTH`). Code today has two `dirt_flags` values. Three readable grades at 1× (D-20) are a contract invention, not a third flag in this census.

| i | dirt_flags | polyline | job today |
|---|------------|----------|-----------|
| 0 | 0 asphalt | `(-12288,0)`–origin–`(12288,0)` | EW spine |
| 1 | 0 asphalt | `(0,-12288)`–origin–`(0,12288)` | NS spine |
| 2 | 0 asphalt | `(-8192,-11264)`–`(-8192,0)`–origin | Kaupunki branch |
| 3 | 0 asphalt | `(0,-5500)`–`(9000,-5500)`–`(9000,0)` | Ostari branch |
| 4 | 1 dirt | `(0,4096)`–`(-8192,4096)`–`(-8192,11264)` | West village |
| 5 | 1 dirt | `(0,4096)`–`(8192,4096)`–`(8192,11264)` | East village |
| 6 | 1 dirt | closed ±12288 rectangle `(-12288,-12288)`–`(12288,-12288)`–`(12288,12288)`–`(-12288,12288)`–`(-12288,-12288)` | Wilderness perimeter — not the 30s path |
| 7 | 1 dirt | `(9000,-5500)`–`(11264,-5500)`–`(11264,-11264)` | Ostari east spur |

Nearest asphalt to camp is the EW spine (route 0) and the Ostari branch (route 3) at `y = 0` / `x = 9000`; camp sits at `(9950, 2400)` with 2098 units to the nearest physical road edge. No polyline walks that gap.

### Z matrix (absolute)

From CONVENTIONS / `tests/world_map_validation.gd` `EXPECTED_*_Z`:

| Pass | z | Owners |
|------|--:|--------|
| Ground tiles, terrain overlay, roads | -20 | `GroundTiles`, `TerrainMaterialOverlay`, `WorldRoadNetwork2D` (`EXPECTED_GROUND_Z`) |
| Non-colliding rubble / moss / cover / wilderness accent | -5 | `WorldBackgroundDecor2D`, `WorldGroundCover2D`, `WorldWildernessAccent2D` (`EXPECTED_DECOR_Z`, `EXPECTED_WILDERNESS_ACCENT_Z`) |
| Ambient silhouettes | -4 | `WorldAmbientScenery2D` (`EXPECTED_AMBIENT_SCENERY_Z`) |
| Gameplay / static occlusion | 5 | `WorldObstacle2D`, Base, scatter, avatars (`EXPECTED_ENTITY_Z`) |

## Density tables

Live dress and scatter counts. Quote the constant, not stale assertion English. `tests/world_map_validation.gd` still says `"Ambient scenery owns its exact 576 region-weighted ruin, tree, and prop groups"` while `EXPECTED_AMBIENT_SCENERY_TOTAL = 640` — the constant wins.

| Constant | Value | File |
|----------|-------|------|
| `WorldAmbientScenery2D.TOTAL_SCENERY_COUNT` | 640 | `src/world/world_ambient_scenery_2d.gd` |
| `WorldAmbientScenery2D.ZONE_SCENERY_COUNTS` | `[96, 72, 48, 48, 236, 92, 48]` | `src/world/world_ambient_scenery_2d.gd` |
| Forest zone (index 4) | 236 | same (`SceneryZone.FOREST`) |
| `tests/world_map_validation.gd` `EXPECTED_AMBIENT_SCENERY_TOTAL` | 640 | `tests/world_map_validation.gd` — quote this, not the stale "exact 576" English |
| `WorldBackgroundDecor2D.RUBBLE_COUNT` | 300 | `src/world/world_background_decor_2d.gd` |
| `WorldBackgroundDecor2D.CRACK_COUNT` | 160 | same |
| `WorldBackgroundDecor2D.MOSS_COUNT` | 220 | same |
| `WorldBackgroundDecor2D.PROP_COUNT` | 420 | same |
| `WorldBackgroundDecor2D.TOTAL_DECORATION_COUNT` | 300+160+220+420 = 1100 | same |
| `WorldWildernessAccent2D.TOTAL_ANCHOR_COUNT` | 24 | `src/world/world_wilderness_accent_2d.gd` |
| Dress salt decor | `WORLD_BUILD_SEED + 91` | `src/world/world_map_2d.gd` `ensure_built` |
| Dress salt ambient | `WORLD_BUILD_SEED + 137` | same |
| Dress salt accent | `WORLD_BUILD_SEED + 173` | same |
| Dress salt cover | `WORLD_BUILD_SEED + 211` | same |
| `BesprenResourceScatter2D.RESOURCE_COUNT` | 87 | `src/world/resource_scatter_2d.gd` |
| `BesprenResourceScatter2D.LAYOUT_VERSION` | 2 — freeze; do not bump (D-28) | same |
| `BesprenResourceScatter2D.DEFAULT_SCATTER_SEED` | `0x5CA77E2` | same |
| Sectors | `GLOBAL_SECTOR_COLUMNS` 12 × `GLOBAL_SECTOR_ROWS` 7 | same |
| Teaching offsets | `(390, 120)`, `(-410, 150)`, `(130, -430)` relative to `STARTING_CAMP_POSITION` | same `_placement_for` |
| `MIN_GATHER_INTERACTIONS` / `MAX_GATHER_INTERACTIONS` | 3–5 | same |
| `HARVEST_AMOUNT` | 1 | same — freeze gather rules (D-28) |
| `WorldBackgroundDecor2D.CAMP_POSITION` | `Vector2(9950, 2400)` duplicate literal | `src/world/world_background_decor_2d.gd` — Phase 2 grep trap; does not reference `BesprenWorldMap2D.STARTING_CAMP_POSITION` |
| `WorldObstacle2D.WILD_TREE_REGIONS` | five `Rect2`s: `(76, 54, 104, 136)`, `(314, 49, 137, 141)`, `(574, 45, 131, 139)`, `(839, 41, 132, 133)`, `(1065, 44, 170, 161)` | `src/world/world_obstacle_2d.gd` — inventory only; do not copy new regions into `src` |

Ground-cover `3,245` clusters / `38,947` elements is a CLAUDE.md §16 GDD figure, not a live gate pin this session (RESEARCH A1). Omit as a census authority. Obstacle count `461` is a comment on `OBSTACLE_BROADPHASE_CELL`, not a live gate pin (RESEARCH A3).

Five shipped tree yaws only. Wild non-tree frames stay unpromoted.

## Pocket versus obstacle overlaps

Record the overlap. Do not propose a new `Vector4`. Do not move the pocket (D-19).

| Item | Live value | File |
|------|------------|------|
| Obstacle name | `OstariSouthShell` | `src/world/world_map_2d.gd` `_build_mall` |
| Position | `Vector2(4850, -3150)` | same |
| Size | `Vector2(6400, 1800)` | same |
| Visual | `WorldObstacle2D.VisualKind.MALL_SHELL` | same |
| Zero-clearance bounds (derived) | x 1650..8050, y −4050..−2250 | half-size of `(6400, 1800)` about `(4850, -3150)` |
| Wilderness pocket 2 | `Vector4(2600, -2200, 700, 620)` | `src/world/world_ambient_scenery_2d.gd` `WILDERNESS_POCKETS` index 2 of 10 |
| Duplicate pocket table | same `Vector4` at index 2 | `src/world/world_wilderness_accent_2d.gd` `WILDERNESS_POCKETS` |
| `MAXIMUM_UNHOSTABLE_POCKETS` | 1 | `tests/existing_wild_atlas_context_validation.gd` |

Pocket 2 sits under the long Ostari south shell. The shell's full-footprint foundation covers the upper portion of a pocket the ambient scenery table still calls wilderness. Accent layer duplicates the same pocket table, so both dress streams inherit the collision. The wild-atlas context gate records this as the one allowed unhostable pocket. Phase 1 names the collision. Pocket tables and obstacle tables are co-authored from Phase 5. `MAXIMUM_UNHOSTABLE_POCKETS = 1` stays.

## 1× unreadables

Analog Loop C voice from `docs/AAA_VISUAL_REDESIGN_AUDIT_2026-09-16.md`: a visual veto overrides a numeric pass. A green headless or desktop-GPU test is not a promotion.

**Fir canopy stalk (D-08, FIR-01).** Named, not solved. Sparse fir still reads as a stalk with branch tiers rather than a conifer mass at 1×. Geometry clip removed the hexagonal mound; canopy density is a subject problem a clip cannot address. Do not require a mass language in Phase 1. FIR-01 is later art.

**Wild non-tree frames.** `runtime_promotion = forbidden_pending_human_visual_veto` in `tests/existing_wild_atlas_context_validation.gd`. Do not promote wild non-tree frames. Five shipped tree yaws in `WILD_TREE_REGIONS` only. Salvage atlas has no `src/` consumer.

**Village fence vs house projection (D-15).** Named, not solved. Houses are three-quarter bakes; barricade segments are top-down. Alternating seeded flips broke equal-gap stamps; they did not make fence-as-hero. West yard will read by silhouette and negative space, not a fence rebake in this phase.

**Scatter-as-place.** 87 IDs: three teaching offsets around camp plus 84 stratified global sectors (`12 × 7`). That is oatmeal plus three camp-adjacent nodes, not authored pocket places. Ostari does not own a salvage *place* today; the mall is a pair of shells with sector scatter nearby.

**Product locks, not new weenies.** No second Amber Gold. Base Core remains the only dominant warm source (`CLAUDE.md` §8). No world-space nameplates. Identity stays redundant across hue, silhouette, iconography, and placement. East village has no shout noun (D-11) — that is a contract lock, not a missing sixth landmark in this census.

## Capture inventory

`tests/world_render_validation.gd` metadata sets `"capture_count": 25`. Do not write twenty-three. `GAMEPLAY_CAMERA_ZOOM = 0.38`.

This is a **filename inventory**. It is not pixel proof. On-disk `artifacts/world_*` PNGs are not claimed to match camp `(9950, 2400)` this session (RESEARCH A2 / Pitfall 9). Do not re-run GPU.

TIME-stable class (byte-identical across identical runs; use for tree/landmark-shape claims): `central_road_shoulder`, `city_barrier` day/night, `city_building_detail`, `city_density`, `city_salvage`, `east_village`, `forest_density`, `forest_log`, `forest_rock`, `local_car_wreck`, `mall`.

Tree/canopy claims: `forest_density` only.

Camp frames are TIME-noisy (shader `TIME`, resource pulse, `AmberLight` / aura). Between identical runs they can move up to 5912 pixels by day and 21799 at night. They are not silhouette evidence.

Do not treat leftover look-ats `CityScrapPile_00` (`CITY_SALVAGE_POSITION`) or `CityVehicleWreck_02` (`CITY_BARRIER_POSITION`) as 30s-loop cameras. Those are density/detail leftovers, not loop-proof.

| Intent (script const) | Path |
|-----------------------|------|
| Overview | `artifacts/world_overview_validation.png` |
| Kaupunki district | `artifacts/world_city_validation.png` |
| Ostari district | `artifacts/world_mall_validation.png` |
| Camp | `artifacts/world_forest_camp_validation.png` |
| Camp composition | `artifacts/world_forest_camp_composition_validation.png` |
| City salvage (`CityScrapPile_00`) | `artifacts/world_city_salvage_validation.png` |
| City barrier (`CityVehicleWreck_02`) | `artifacts/world_city_barrier_validation.png` |
| Forest rock | `artifacts/world_forest_rock_validation.png` |
| Forest log | `artifacts/world_forest_log_validation.png` |
| City building detail | `artifacts/world_city_building_detail_validation.png` |
| Long Ostari shell | `artifacts/world_mall_long_shell_validation.png` |
| West village | `artifacts/world_west_village_validation.png` |
| East village | `artifacts/world_east_village_validation.png` |
| Local car wreck | `artifacts/world_local_car_wreck_validation.png` |
| City–forest transition | `artifacts/world_city_forest_transition_validation.png` |
| Central road shoulder | `artifacts/world_central_road_shoulder_validation.png` |
| City density | `artifacts/world_city_density_validation.png` |
| Forest density | `artifacts/world_forest_density_validation.png` |
| Wilderness density | `artifacts/world_wilderness_density_validation.png` |
| Wilderness ecology gameplay | `artifacts/world_wilderness_ecology_gameplay_validation.png` |
| Night camp | `artifacts/world_forest_camp_night_validation.png` |
| Night camp composition | `artifacts/world_forest_camp_composition_night_validation.png` |
| Night city barrier | `artifacts/world_city_barrier_night_validation.png` |
| Night west village | `artifacts/world_west_village_night_validation.png` |
| Night wilderness ecology | `artifacts/world_wilderness_ecology_gameplay_night_validation.png` |

Twenty-five paths. Filename inventory is not pixel proof.

## Foundation drift

`docs/WORLD_MAP_FOUNDATION.md` tracks the *implemented* world and lagged live constants. Do not rewrite that file in this plan. Planners must stop copying the left column.

| Claim in `WORLD_MAP_FOUNDATION.md` | Live |
|------------------------------------|------|
| Ambient scenery 576 / forest 172 | `TOTAL_SCENERY_COUNT` 640 / forest zone 236 |
| Captures 23 | `capture_count` 25 |
| `WORLD MAP VALIDATION OK (150)` | 169 (TESTING.md / current world-map gate print) |

Decor 1100 (300+160+220+420) still matches live. Camp `(9950, 2400)` still matches live. Extents 14×14 / ±14,336 still match live. The drift that bites is scenery, capture count, and gate check count.

## What the contract must invent

This census does not specify GDScript coordinates for the target. Sibling `docs/WORLD_MAP_REDESIGN_CONTRACT.md` (plan 02) names the anatomy.

1. **Dirt spur (D-02).** Live map has seclusion, not a spur polyline. Contract adds a dirt exit that meets asphalt. Still not a junction camp (D-01).
2. **Metsä threat weenie.** No named forest landmark exists today. D-12 makes it the 30s-loop named-landmark beat.
3. **Teaching salvage pocket as a place.** Today: three teaching offsets plus 84-sector oatmeal. Contract names a nearby Metsä pocket (not Ostari; Ostari is the 10-minute commute).
4. **Three-grade visual look.** Code today has two `dirt_flags` values (four asphalt, four dirt; perimeter is dirt like villages). D-20 wants asphalt spine / dirt branch / wilderness perimeter readable at 1×. Third look is Phase 3 (ROAD-01), not a Phase 1 enum.

Also later, not this file: five shout nouns, exclusion volumes, named capture cameras (spec only). Honest coverage: filename inventory is not pixel proof.
