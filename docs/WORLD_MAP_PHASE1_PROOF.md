# World Map Phase 1 Proof — CONT-01 Coverage

Proof date: 2026-09-19
Scope root: `C:\Users\heikk\Desktop\Claude\gpt_peli`
Requirement: CONT-01 (docs-only). Siblings: `docs/WORLD_MAP_AUDIT.md`, `docs/WORLD_MAP_REDESIGN_CONTRACT.md`.

This file is the runnable coverage slice of CONT-01 (D-25, D-26, D-27, D-28). A reviewer ticks headings, checks the live-constant table, and runs the git path filter. Proof is markdown + git. It is not a Godot gate, not a foundation rewrite, and not pixel proof.

## Method

Analog to `docs/ADDONS_DEEP_AUDIT.md`: honest method, named evidence, named non-claims.

**What this file is.** Grep evidence. Heading strings exist in the two deliverable docs. Decision IDs D-01 through D-28 map to those docs. Live constants in the census table match RESEARCH and the audit quotes. `git diff --name-only -- src/world/` is empty.

**What this file is not.** A Godot `--headless` or GPU gate. A rewrite of `docs/WORLD_MAP_FOUNDATION.md`. Instantiation of `BesprenWorldMap2D`. A new `tests/map_contract_validation.gd`. Camera implementation. Wild-atlas promotion. A `LAYOUT_VERSION` or `WORLD_BUILD_SEED` bump.

How to run:

1. Tick **Audit heading checklist** against `docs/WORLD_MAP_AUDIT.md`.
2. Tick **Contract heading checklist** against `docs/WORLD_MAP_REDESIGN_CONTRACT.md`.
3. Confirm **Decision coverage D-01 through D-28** has a non-empty Where-cited for every row.
4. Confirm **Cameras specified not implemented** lists fifteen `camera_id` strings and that `tests/world_render_validation.gd` / `.tscn` are untouched.
5. Fill and run **Live-constant table versus RESEARCH census** and **Git path filter** (Task 2 of this plan). Do not run Godot.

Phase 1 remaining proof is this file plus empty `src/world/` diff. Not GPU. Not device.

## Audit heading checklist

Required H2 strings copied from `docs/WORLD_MAP_AUDIT.md`. Present only after reading that file and finding the exact H2.

| Heading | Present |
|---------|---------|
| `## Method` | Present |
| `## Extents, seed, camp, cell` | Present |
| `## Biome seats as-is` | Present |
| `## Eight routes and missing spur` | Present |
| `## Density tables` | Present |
| `## Pocket versus obstacle overlaps` | Present |
| `## 1× unreadables` | Present |
| `## Capture inventory` | Present |
| `## Foundation drift` | Present |
| `## What the contract must invent` | Present |

Ten of ten. No miss. This plan does not rewrite the audit.

## Contract heading checklist

Required H2 strings copied from `docs/WORLD_MAP_REDESIGN_CONTRACT.md`. Present only after reading that file and finding the exact H2.

| Heading | Present |
|---------|---------|
| `## Banner` | Present |
| `## Camp` | Present |
| `## Natures` | Present |
| `## Roads` | Present |
| `## District jobs and topology` | Present |
| `## Five shout nouns` | Present |
| `## 30s loop beats` | Present |
| `## 10-minute loop` | Present |
| `## Salvage and threat pockets` | Present |
| `## Exclusion volumes` | Present |
| `## Way-home language` | Present |
| `## Capture cameras` | Present |
| `## Co-authorship and tripwires` | Present |
| `## Phase 2 consumer list` | Present |
| `## Out of scope` | Present |

Fifteen of fifteen. No miss. This plan does not rewrite the contract.

## Live-constant table versus RESEARCH census

Read live `.gd` this session. Do not copy foundation 576 / forest 172 / captures 23 / gate 150 as live. Every Matches-RESEARCH cell is yes because the audit quote and RESEARCH census agree with the `.gd` value.

| Constant | Live value in `.gd` | Quoted in WORLD_MAP_AUDIT.md | Matches RESEARCH |
|----------|---------------------|------------------------------|------------------|
| `GRID_SIZE` | 14 (`src/world/world_map_2d.gd`) | yes — Extents table `BesprenWorldMap2D.GRID_SIZE` 14 | yes |
| `PLAYABLE_HALF_EXTENT` | 14336.0 (`src/world/world_map_2d.gd`) | yes — Extents table 14336.0 | yes |
| `STARTING_CAMP_POSITION` | `Vector2(9950.0, 2400.0)` (`src/world/world_map_2d.gd`) | yes — `(9950, 2400)` | yes |
| `WORLD_BUILD_SEED` | `0xB35E7E` (`src/world/world_map_2d.gd`) | yes — freeze; this plan does not change the `.gd` (D-28) | yes |
| `TOTAL_SCENERY_COUNT` | 640 (`src/world/world_ambient_scenery_2d.gd`) | yes — Density tables | yes |
| `ZONE_SCENERY_COUNTS` forest index 4 | 236 (`[96, 72, 48, 48, 236, 92, 48]`) | yes — Forest zone (index 4) 236 | yes |
| `RESOURCE_COUNT` | 87 (`src/world/resource_scatter_2d.gd`) | yes — Density tables | yes |
| `LAYOUT_VERSION` | 2 (`src/world/resource_scatter_2d.gd`) | yes — freeze; do not bump (D-28) | yes |
| `capture_count` | 25 (`tests/world_render_validation.gd`) | yes — Capture inventory | yes |
| `MAXIMUM_UNHOSTABLE_POCKETS` | 1 (`tests/existing_wild_atlas_context_validation.gd`) | yes — Pocket versus obstacle overlaps | yes |
| `OstariSouthShell` | `(4850.0, -3150.0)` size `(6400.0, 1800.0)` (`src/world/world_map_2d.gd` `_build_mall`) | yes — Pocket versus obstacle overlaps | yes |
| wilderness pocket 2 | `Vector4(2600.0, -2200.0, 700.0, 620.0)` index 2 of 10 (`src/world/world_ambient_scenery_2d.gd` `WILDERNESS_POCKETS`) | yes — `Vector4(2600, -2200, 700, 620)` | yes |
| `forbidden_pending_human_visual_veto` | `runtime_promotion` string in `tests/existing_wild_atlas_context_validation.gd` | yes — 1× unreadables | yes |
| no camp spur today | eight polylines in `_build_road_network`; `dirt_flags` `[0,0,0,0,1,1,1,1]`; none terminate at `(9950, 2400)` | yes — Eight routes and missing spur | yes |
| `WorldBackgroundDecor2D.CAMP_POSITION` | `Vector2(9950.0, 2400.0)` duplicate literal (`src/world/world_background_decor_2d.gd`) | yes — Density tables, Phase 2 grep trap | yes — listed on contract Phase 2 consumer table |

Foundation drift (audit only; not live): scenery 576 / forest 172 / captures 23 / `WORLD MAP VALIDATION OK (150)`. Live is 640 / 236 / 25 / 169. This proof does not treat the left column as census.

## Git path filter

Commands run 2026-09-19 while writing this section. Expected empty on both path filters. Dirty `src/world/` would fail CONT-01.

```text
git diff --name-only -- src/world/
```

Output: empty (no names).

```text
git diff --name-only -- tests/world_render_validation.gd tests/world_render_validation.tscn
```

Output: empty (no names). Cameras specified, not implemented (D-27).

Read confirmations (not edited):

- `LAYOUT_VERSION` still `2` in `src/world/resource_scatter_2d.gd` (`const LAYOUT_VERSION: int = 2`)
- `WORLD_BUILD_SEED` still `0xB35E7E` in `src/world/world_map_2d.gd` (`const WORLD_BUILD_SEED: int = 0xB35E7E`)
- `TOTAL_SCENERY_COUNT` still `640` in `src/world/world_ambient_scenery_2d.gd` (`const TOTAL_SCENERY_COUNT: int = 640`)

Allowed paths this phase: `docs/*.md` and `.planning/phases/01-map-audit-redesign-contract/**`.

Forbidden even as comments: `world_map_2d.gd`, `world_road_network_2d.gd`, `world_obstacle_2d.gd`, `resource_scatter_2d.gd`, camera lists in world-render validation. Phase 1 proof file does not edit those paths.

## Decision coverage D-01 through D-28

Locked text matches `01-CONTEXT.md`. Every Where-cited is non-empty.

| Decision | Where cited | Locked text |
|----------|-------------|-------------|
| D-01 | both | Base Core stays secluded Metsä. Not a road-junction camp. |
| D-02 | both | Player leaves camp on a dirt spur that meets asphalt. Spur is the readable exit. Audit: no spur today. Contract invents the Phase 2 route. |
| D-03 | contract | Camp is a hero clearing: camp + three satellites + teach-pocket in one empty bowl. Forest wall is the edge. |
| D-04 | both | Keep the three camp satellites. Compose them as camp furniture in the clearing, not as distant stamps. |
| D-05 | both | Metsä's job is canopy wall + sparse interior. Camp is the one true clearing. |
| D-06 | contract | Two natures, not a fifth district. Metsä = threat canopy near camp/roads. Far wilderness = quieter empty (the 10-minute empty). |
| D-07 | contract | The 30s loop stays in Metsä. It does not enter far wilderness. |
| D-08 | both | Fir canopy stalk defect is named, not solved. FIR-01 later. Do not promote wild non-tree frames. |
| D-09 | contract | Sparse named-weenie list of five. Not a dense 10–12 roster. |
| D-10 | both | Landmarks shout at 480×270 by silhouette first. Hue is secondary. No world-space nameplates. No second Amber Gold competitor. |
| D-11 | both | Locked shout nouns: camp Amber Gold; mall gate (Ostari); west yard (west Kylät); city choke (Kaupunki); Metsä threat weenie. East village has no shout noun. |
| D-12 | contract | The 30s-loop named landmark beat is the Metsä threat weenie. Mall gate / west yard / city choke are wayfinding, not 30s-loop beats. The salvage pocket is a place, not a fifth weenie. |
| D-13 | contract | Two different village jobs in the same quiet family. West = quiet yards (named west yard). East = graveyard / abandoned rest (unnamed). East does not steal Ostari salvage. |
| D-14 | both | Keep two geographically separate villages. Do not collapse into one cluster with two yards. |
| D-15 | both | Village fence vs house projection mismatch is named, not solved. West yard reads by silhouette + negative space, not fence-as-hero. |
| D-16 | both | Keep both jobs. Kaupunki = dense urban choke. Ostari = mall salvage behind named mall gate. Neither sits on the 30s Metsä loop. |
| D-17 | contract | Ostari owns 10-minute salvage density. Metsä 30s pocket is teaching/nearby only. City/villages may hold sparse nodes but not the salvage identity. |
| D-18 | contract | Mall gate weenie is a gap in a long shell (missing tooth). Not a glowing vertical prop. |
| D-19 | both | Pocket 2 vs OstariSouthShell stays the recorded unhostable tripwire. Phase 1 names the collision and does not move the pocket. `MAXIMUM_UNHOSTABLE_POCKETS = 1` stays. |
| D-20 | both | Three readable road grades at 1×. Asphalt spine = way-home. Dirt = camp spur + village paths. Wilderness perimeter exists and is not the 30s path. Audit: two `dirt_flags` values today. |
| D-21 | both | Districts may rearrange on the locked 14×14 grid. Compass seats are not frozen. |
| D-22 | both | Camp is free to move inside Metsä. Still secluded, still dirt spur, still hero clearing. Extents stay ±14,336. |
| D-23 | contract | Asphalt always leads home. Every district exit hits the asphalt spine; follow it to the dirt spur and camp. Minimap is not the way-home. |
| D-24 | contract | 30s loop is a tight Metsä circuit. All beats stay near camp inside Metsä. Asphalt appears as a short readable segment, not a commute. Ostari is the 10-minute salvage commute. |
| D-25 | both | Phase 1 output is documents, not layout code. |
| D-26 | audit | Audit quotes live constants and current capture set from `.gd` / tests. Do not trust stale numbers in `docs/WORLD_MAP_FOUNDATION.md`. |
| D-27 | contract | Contract includes exclusion volumes and named capture cameras on the 30s-loop beats plus way-home-from-district frames with minimap hidden. Cameras are specified, not implemented. |
| D-28 | both | Presentation never writes simulation. Collision, flow, gather rules (87 IDs, 3–5 step, one-unit yield), and peer-one RPC stay canonical. Phase 1 does not bump `LAYOUT_VERSION` or `WORLD_BUILD_SEED`. |

Twenty-eight of twenty-eight. D-11 five shout nouns and D-12 Metsä threat weenie as the 30s named landmark are locked as in CONTEXT.

## Cameras specified not implemented

Fifteen `camera_id` strings from `docs/WORLD_MAP_REDESIGN_CONTRACT.md` **Capture cameras**. Specified, not implemented (D-27). `tests/world_render_validation.gd` and `tests/world_render_validation.tscn` are untouched.

1. `cam_loop_01_camp_clearing`
2. `cam_loop_02_dirt_spur`
3. `cam_loop_03_asphalt_read`
4. `cam_loop_04_metsa_threat_weenie`
5. `cam_loop_05_teaching_salvage`
6. `cam_loop_06_threat_approach`
7. `cam_home_from_kaupunki`
8. `cam_home_from_ostari`
9. `cam_home_from_west_kylat`
10. `cam_home_from_east_kylat`
11. `cam_job_kaupunki_choke`
12. `cam_job_ostari_mall_gate`
13. `cam_job_west_yard`
14. `cam_job_east_rest`
15. `cam_job_metsa_canopy_wall`

Shout-noun count is five (D-11). East has no shout noun. The 30s named landmark is the Metsä threat weenie (`cam_loop_04_metsa_threat_weenie`), not mall gate / west yard / city choke.

## Remaining proof boundary

Desktop/headless success does not certify Android. Phase 1 remaining proof is this file plus empty `src/world/` diff. Not GPU. Not device.

Do not run Godot. Do not rewrite `docs/WORLD_MAP_FOUNDATION.md`. Do not instantiate `BesprenWorldMap2D`. Do not create `tests/map_contract_validation.gd`. Live-constant table and git path filter are filled; CONT-01 is proven.
