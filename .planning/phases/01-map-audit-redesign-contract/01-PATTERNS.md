# Phase 1: Map Audit + Redesign Contract - Pattern Map

**Mapped:** 2026-09-19
**Files analyzed:** 2 (create only; no `src/` / `tests/` / `scenes/` edits)
**Analogs found:** 2 / 2

Docs-only CONT-01. Planner copies **structure and citation habits** from analogs. Do **not** copy analog **counts** — `docs/WORLD_MAP_FOUNDATION.md` scenery 576 / forest 172 / captures 23 / gate 150 are stale vs live 640 / 236 / 25 / 169.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `docs/WORLD_MAP_AUDIT.md` | config | transform | `docs/ADDONS_DEEP_AUDIT.md` (census voice) + `docs/WORLD_MAP_FOUNDATION.md` (spatial headings, **not** numbers) | exact (docs census) |
| `docs/WORLD_MAP_REDESIGN_CONTRACT.md` | config | transform | `docs/WORLD_MAP_FOUNDATION.md` (spatial/freeze sections) + `docs/WORLD_MAP_VISUAL_PRODUCTION_PLAN.md` (frozen contracts + exclusion volumes) + `Claude.md` §16 (product contract) | exact (docs contract) |

**Not in this phase (forbidden even as "refresh"):**

| File | Why out |
|------|---------|
| `docs/WORLD_MAP_FOUNDATION.md` | Tracks *implemented* world; counts move in Phase 2. Audit may add a one-line drift table; do not rewrite foundation. |
| `src/world/*.gd` | Success criterion 3: `git diff --name-only -- src/world/` empty |
| `tests/world_render_validation.gd` / `.tscn` | Cameras specified in contract; implemented Phase 7 |
| `data/world/bespren_world_composition.tres` | Phase 2 Resource, not markdown |

## Pattern Assignments

### `docs/WORLD_MAP_AUDIT.md` (config, transform)

**Analog (primary):** `docs/ADDONS_DEEP_AUDIT.md` — honest method, exact-total tables, evidence boundary, remaining proof.
**Analog (spatial headings):** `docs/WORLD_MAP_FOUNDATION.md` — region table, Z matrix, scatter, gates. **Copy heading shape only.**
**Analog (unreadables / veto):** `docs/AAA_VISUAL_REDESIGN_AUDIT_2026-09-16.md` Loop C + evidence locations.

**Fill order from RESEARCH (do not invent extra top-level sections):**

1. Method (live `.gd` > `Claude.md` > foundation)
2. Extents / seed / camp / cell
3. Biome seats as-is
4. Eight routes + missing spur
5. Density tables (640 / 1100 / 24 / 87)
6. Pocket vs obstacle overlaps (pocket 2)
7. 1× unreadables (fir stalk, wild-frame veto, fence/house projection, scatter-as-place)
8. Capture inventory (25 filenames, TIME class, look-ats including hardcoded `CityScrapPile_00`)
9. Foundation drift table
10. What the contract must invent (spur, Metsä weenie, teaching pocket as a *place*, three-grade *look*)

---

**Imports / front-matter pattern** (`docs/ADDONS_DEEP_AUDIT.md` lines 1–13):

```markdown
# Addons Deep Audit and Visual Traceability

Audit date: 2026-08-14
Scope root: `C:\Users\heikk\Desktop\Claude\gpt_peli\Addons`
Runtime target: Godot 4.7.1 Mobile, 2D, 480 x 270 landscape

## What “every file” means

`tools/asset_pipeline/deep_asset_audit.py` inspected every physical file under `Addons/` without modifying the vault. [...]
This is an exhaustive automated file/container audit. It is not a claim that a person manually art-directed all 9,885 visual candidates one by one.
```

**Copy:** date + scope + runtime target + one paragraph that names the **method** and what the doc is **not**. Audit method = grep live `const` in `src/world/` + tests; do not re-run GPU; do not trust foundation counts.

**Honest-coverage sibling** (`docs/AAA_VISUAL_REDESIGN_AUDIT_2026-09-16.md` lines 7–9):

```markdown
## 1. Honest coverage boundary

The Addons vault was exhaustively classified without being modified. This means every physical file and every supported archive member has a hash, format decision, role signal, and provenance gate. It does **not** mean that 9,886 art candidates have all been manually approved for a premium game.
```

**Copy:** "filename inventory ≠ pixel proof." On-disk `artifacts/world_*` freshness vs camp `(9950, 2400)` is **not verified** this session (RESEARCH A2).

---

**Core census-table pattern** (`docs/ADDONS_DEEP_AUDIT.md` lines 15–32):

```markdown
## Exact totals

| Measure | Exact result |
|---|---:|
| Physical files hashed | 31,404 |
| Physical source bytes | 2,355,834,247 |
[...]
The physical-file ledger has exactly 31,404 lines.
```

**Copy:** one table per census block; every number named as a **constant**, then the value, then the file. RESEARCH Pattern 2:

```markdown
| Constant | Value | File |
|----------|-------|------|
| `BesprenWorldMap2D.GRID_SIZE` | 14 | `src/world/world_map_2d.gd` |
| `PLAYABLE_HALF_EXTENT` | 14336.0 | same |
| `STARTING_CAMP_POSITION` | `(9950, 2400)` | same |
| `WORLD_BUILD_SEED` | `0xB35E7E` | same |
| `WorldAmbientScenery2D.TOTAL_SCENERY_COUNT` | 640 | `src/world/world_ambient_scenery_2d.gd` |
| `ZONE_SCENERY_COUNTS` forest | 236 | same (index 4) |
| `BesprenResourceScatter2D.RESOURCE_COUNT` | 87 | `src/world/resource_scatter_2d.gd` |
| `LAYOUT_VERSION` | 2 | same — **do not bump** |
| `world_render_validation` `capture_count` | 25 | `tests/world_render_validation.gd` |
| `MAXIMUM_UNHOSTABLE_POCKETS` | 1 | `tests/existing_wild_atlas_context_validation.gd` |
```

**Do not quote as live without a gate run:** comment "461 obstacles"; ground-cover "3,245 clusters / 38,947 elements" (`Claude.md` §16). Cite as *comment/GDD figures* or omit (RESEARCH A1/A3).

---

**Spatial-heading analog — structure only** (`docs/WORLD_MAP_FOUNDATION.md` lines 5–23):

```markdown
## Spatial contract

- Macro grid: `14 x 14`
- Macro cell: `2048 x 2048` world units
- Playable bounds: `Rect2(-14336, -14336, 28672, 28672)`
- Initial forest refuge: Base Camp at `(9950, 2400)` inside east-forest macro-cell `(11, 8)`; center-to-nearest-road-edge clearance is exactly `2098` units
[...]
| Region | Cells | Purpose |
|---|---|---|
| Kaupunki | columns 1-5, rows 1-5 | Dense non-enterable urban shells, cracked asphalt, rusted wrecks |
| Ostari | columns 7-10, rows 2-5 | Collapsed commercial wings with a narrow east-west passage |
| West village | columns 1-4, rows 9-12 | Timber homesteads and broken fence gaps |
| East village | columns 9-12, rows 9-12 | Separate homestead cluster and fence rhythm |
| Metsä / Luonto | perimeter plus northeast and western belts | Pine-like canopy clusters, mossy rocks, wilderness ground |
```

**Copy:** bullet spatial lock + region table. **Replace** foundation scenery/road prose with live route table from RESEARCH (8 polylines; **no camp spur**):

| i | `dirt_flags` | Polyline | Job today |
|---|-------------:|----------|-----------|
| 0 | 0 asphalt | `(-12288,0)–origin–(12288,0)` | EW spine |
| 1 | 0 asphalt | `(0,-12288)–origin–(0,12288)` | NS spine |
| 2 | 0 asphalt | `(-8192,-11264)–(-8192,0)–origin` | Kaupunki branch |
| 3 | 0 asphalt | `(0,-5500)–(9000,-5500)–(9000,0)` | Ostari branch |
| 4 | 1 dirt | `(0,4096)–(-8192,4096)–(-8192,11264)` | West village |
| 5 | 1 dirt | `(0,4096)–(8192,4096)–(8192,11264)` | East village |
| 6 | 1 dirt | closed `±12288` rectangle | Wilderness perimeter — **not** 30s path (D-20) |
| 7 | 1 dirt | `(9000,-5500)–(11264,-5500)–(11264,-11264)` | Ostari east spur |

**Missing vs D-02:** camp dirt spur to `(9950, 2400)`. Audit must say **"no camp spur today"** — do not list 9 routes.

Camp cell (derived, not a named const): `floor((9950+14336)/2048) = 11`, `floor((2400+14336)/2048) = 8` → `(11, 8)` east-forest.

---

**Z-matrix analog** (`docs/WORLD_MAP_FOUNDATION.md` lines 25–37) — copy table shape; quote live `EXPECTED_*_Z` / CONVENTIONS, not foundation scenery 576:

```markdown
## Rendering matrix

| Content | Absolute Z | Y-sort policy |
|---|---:|---|
| `GroundTiles`, `TerrainTiles`, `RoadNetwork` | `-20` | Disabled |
| Non-colliding cracks, moss, rubble, scrap | `-5` | Disabled |
| Visual-only ruin, canopy and prop groups | `-4` | Disabled |
| Static structural obstacles | `5` | Nested below the gameplay Y-sort hierarchy |
| Base Core, resources, players, future towers | `5` | Parent containers explicitly enable Y-sort |
```

**Stale clause in the same analog (do not copy numbers):** lines 37–38 claim 576 scenery / 172 forest. Live: `TOTAL_SCENERY_COUNT = 640`, `ZONE_SCENERY_COUNTS = [96, 72, 48, 48, 236, 92, 48]`. Extra pitfall: `tests/world_map_validation.gd` assertion *string* still says "exact 576" while `EXPECTED_AMBIENT_SCENERY_TOTAL = 640` — quote the **constant**, not the stale English.

Decor live: 300+160+220+420 = 1100 (`world_background_decor_2d.gd`). Accent: `TOTAL_ANCHOR_COUNT = 24`. Dress salts: decor `+91`, ambient `+137`, accent `+173`, cover `+211`.

---

**Overlap / tripwire pattern** — no dedicated analog file; copy RESEARCH pitfall 3 citation habit:

```markdown
| Item | Live value | Source |
| Ostari south shell | name `OstariSouthShell`, pos `(4850, -3150)`, size `(6400, 1800)`, `VisualKind.MALL_SHELL` | `world_map_2d.gd` `_build_mall` |
| Wilderness pocket 2 | `Vector4(2600, -2200, 700, 620)` index 2 of 10 | `world_ambient_scenery_2d.gd` **and duplicate** `world_wilderness_accent_2d.gd` |
| Unhostable cap | `MAXIMUM_UNHOSTABLE_POCKETS = 1` | `tests/existing_wild_atlas_context_validation.gd` |
```

**Copy:** record overlap; do **not** propose a new `Vector4`. D-19.

---

**1× unreadables / visual-veto pattern** (`docs/AAA_VISUAL_REDESIGN_AUDIT_2026-09-16.md` lines 86–103):

```markdown
### Loop C — wilderness ecosystem source trial
[...]
Review:
- Contract passed all 10 pockets with card radius 156.213.
- World map regression: 169 checks passed.
- Mobile/Vulkan produced 40 A/B day/night captures [...]
- Visual verdict: **REJECTED / no runtime promotion**. Root/branch cards overpower the approximately 23 px survivor and read as high-contrast orange carcass/rock forms.
```

**Copy:** numeric gate pass ≠ promotion. Audit names: fir canopy stalk (FIR-01, not solved); `runtime_promotion = forbidden_pending_human_visual_veto`; fence vs house projection (D-15); scatter-as-place (84-sector oatmeal). Do not promote wild non-tree frames.

---

**Capture inventory analog** (`docs/WORLD_MAP_FOUNDATION.md` lines 96–97 + `docs/WORLD_MAP_VISUAL_PRODUCTION_PLAN.md` lines 136–151):

```markdown
`tests/world_render_validation.tscn` is the GPU gate. It writes twenty-three captures to `res://artifacts/`: overview; Kaupunki and Ostari districts; camp and camp-satellite composition by day/night; [...]
```

**Do not copy "twenty-three".** Live `capture_count == 25`. Inventory **filenames + intents + TIME class** from `tests/world_render_validation.gd`. Do not re-run GPU.

TIME-stable class (tree/landmark-shape claims only): `central_road_shoulder`, `city_barrier` day/night, `city_building_detail`, `city_density`, `city_salvage`, `east_village`, `forest_density`, `forest_log`, `forest_rock`, `local_car_wreck`, `mall`. Tree/canopy: **`forest_density` only**. Camp frames are TIME-noisy (up to 5,912 / 21,799 pixels between identical runs).

Do not retarget leftover scrap look-ats `CityScrapPile_00` / `CityVehicleWreck_02` (`CITY_SALVAGE_POSITION`) as loop-proof cameras.

---

**Foundation drift table** — no analog file has this; add a short table so planners stop copying 576/23/150:

| Claim in `WORLD_MAP_FOUNDATION.md` | Live |
|---|---|
| Ambient scenery 576 / forest 172 | 640 / 236 |
| Captures 23 | 25 |
| `WORLD MAP VALIDATION OK (150)` | 169 (TESTING.md / gate print) |

---

**Error handling / remaining-proof pattern** (`docs/ADDONS_DEEP_AUDIT.md` lines 116–120):

```markdown
## Capture and device evidence boundary

The world render scene now writes 23 Mobile/Vulkan outputs [...]
Likewise, desktop/headless success does not certify Android installation, [...]
```

**Copy the boundary voice, not the 23.** Phase 1 remaining proof = heading completeness + live-constant quotes + empty `src/world/` diff. Not Android. Not GPU.

---

**Validation of the audit itself** (from `01-VALIDATION.md` / RESEARCH): grep `docs/WORLD_MAP_AUDIT.md` for `TOTAL_SCENERY_COUNT`, `9950`, `0xB35E7E`, `OstariSouthShell`, `forbidden_pending_human_visual_veto`.

---

### `docs/WORLD_MAP_REDESIGN_CONTRACT.md` (config, transform)

**Analog (primary):** `docs/WORLD_MAP_FOUNDATION.md` — "implementation contract" voice, spatial lock, region jobs, collision/flow freeze, scatter freeze, verification.
**Analog (freeze + exclusions):** `docs/WORLD_MAP_VISUAL_PRODUCTION_PLAN.md` lines 20–66.
**Analog (product GDD):** `Claude.md` §16 (starts line 469) — 14×14, Z matrix, 87-node scatter, presentation ≠ simulation.
**Analog (non-negotiables list):** `docs/AAA_VISUAL_REDESIGN_AUDIT_2026-09-16.md` lines 24–30.
**Analog (authority freeze):** `docs/MOBILE_LAN_FOUNDATION.md` lines 5–9.

**Fill order from RESEARCH (executor must fill; do not drop a heading):**

1. Banner — docs-only; extents 14×14 / ±14,336 frozen; no `src/world/` this slice; `LAYOUT_VERSION` / `WORLD_BUILD_SEED` frozen
2. Camp — D-01–D-04, D-22; Amber Gold only dominant warm
3. Natures — D-05–D-08; FIR-01 named not solved
4. Roads — D-20, D-23; three **visual** grades; current 8-route table referenced from audit (do not add a `dirt_flags` enum here)
5. District jobs + topology — D-13–D-17, D-21; relative topology, **not** GDScript coordinates
6. Five shout nouns — D-09–D-12; east has no shout noun
7. 30s loop beats — D-24; all Metsä
8. 10-minute loop — Ostari commute via mall-gate gap
9. Salvage / threat pockets — jobs only; 87 / 3–5 / one-unit frozen; no node coordinates
10. Exclusion volumes — name both camp radii and which layer owns which
11. Way-home language — D-23; minimap hidden in proof frames
12. Capture cameras — table; specified not implemented
13. Co-authorship / tripwires — pocket 2; unhostable=1; wild veto; no nameplates; no second Amber Gold
14. Phase 2 consumer list — `STARTING_CAMP_POSITION` grep table
15. Out of scope — FIR-01, SALV-01, fence projection, TINT-01, PLACE-01, Resource `.tres`

---

**Banner / freeze pattern** (`docs/WORLD_MAP_VISUAL_PRODUCTION_PLAN.md` lines 20–33):

```markdown
## Frozen gameplay and authority contracts

Visual production may replace presentation, but it must not silently change these contracts:

- `BesprenWorldMap2D.WORLD_BUILD_SEED` and the authored obstacle creation order remain deterministic.
- The playable extent, `14 x 14` macro-grid, `2048`-unit macro-cell, and secluded Base Camp start at `(9950, 2400)` remain exact. [...]
- Every structural obstacle remains a `StaticBody2D` on `WorldStatic` with its canonical rectangle or circle `CollisionShape2D`.
- The same obstacle footprint remains the source for physics overlap, host motion resolution, spawn rejection, and the `112 x 112` flow-field mask at `256` units per cell.
- Peer one remains authoritative. Clients submit movement intent or the existing action command, never a trusted final position, resource ID, harvest amount, collision result, or world-layout mutation.
- The 87 resource identities remain three teaching anchors plus 84 seeded global-sector spawns. [...]
- No Blender object, Poly Haven GLTF, local source GLB, `Node3D`, PBR material, or authoring light enters the shipping runtime.
```

**Adapt, do not paste camp as frozen-at-pixel:** D-22 allows camp to **slide inside Metsä** in Phase 2. Phase 1 banner freezes **extents**, **seed**, **LAYOUT_VERSION**, **gather rules**, **peer-one**, **no `src/world/` this phase**. Camp *job* (secluded Metsä, dirt spur, hero clearing, 3 satellites as furniture) is locked; coordinates are not.

**Non-negotiable numbered list** (`docs/AAA_VISUAL_REDESIGN_AUDIT_2026-09-16.md` lines 24–30):

```markdown
## 2. Non-negotiable production contract

1. Runtime remains 2D: no raw GLTF, Blend, PBR graph, Node3D, or source-vault reference enters the export closure.
2. Existing host authority, ordered snapshots, collision, flow field, placement grid, 480 x 270 logical layout, and 44 px touch contracts are preserved.
3. A new visual must pass provenance, import, deterministic scene binding, gameplay-scale capture, grayscale/semantic review, and focused regression tests before it is considered for runtime promotion.
4. A green headless or desktop-GPU test is not Android, touch, thermal, audio, lifecycle, or two-device LAN certification.
5. A visual veto overrides a numeric pass.
```

**Copy items 1, 2, 4, 5.** Item 3 is later-phase promotion; Phase 1 restates veto + no atlas `Rect2`.

**Authority freeze sibling** (`docs/MOBILE_LAN_FOUNDATION.md` lines 5–9):

```markdown
## Runtime contract

- `MobileControls` owns separate finger indices [...]
- `CoopSession` accepts reliable movement and action requests only from registered peers. Clients call peer 1, [...]
- `GameWorld` contains only 2D nodes.
```

**Copy:** short locked bullets. Contract does **not** retune HUD (44×44 already shipping). Minimap stays in the game; **review frames** hide it (D-23).

---

**Collision / single-obstacle pattern** (`docs/WORLD_MAP_FOUNDATION.md` lines 41–48):

```markdown
## Collision and flow-field contract

`WorldObstacle2D` is the single obstacle definition used by all three consumers:

1. It is a `StaticBody2D` on the named `WorldStatic` physics layer.
2. It installs a simplified `CollisionShape2D` matching its rectangle or trunk/rock circle.
3. It exposes the same oriented footprint to `BesprenWorldMap2D` for flow-field rasterization and host motion resolution.
```

**Copy:** weenies later add `VisualKind` + atlas crop, never a second obstacle class. Phase 1 **names** weenies; does not pick `Rect2`. Metsä threat weenie = "one colliding Metsä mass readable at 0.38, not Amber Gold, not a tree stamp" (RESEARCH Open Question 1).

---

**Scatter freeze pattern** (`docs/WORLD_MAP_FOUNDATION.md` lines 51–63):

```markdown
## Resource scattering and USE

`BesprenResourceScatter2D` is a fixed-path RPC controller. It owns 87 deterministic resource IDs: three immediately readable teaching anchors beside the forest camp and one stratified spawn in each of 84 global sectors.
[...]
A client never submits a resource ID, amount, or position. Peer one rate-limits interactions, uses its stored authoritative player position, [...]
```

**Copy the freeze, not the 84-sector identity.** Contract names pocket **jobs** (teaching near camp; Ostari 10-min; city/villages sparse). No node coordinates. `LAYOUT_VERSION = 2` / seed `0x5CA77E2` / 3–5 interactions / yield 1 — **do not bump**. Teaching offsets today `(390,120)`, `(-410,150)`, `(130,-430)` are audit facts, not target coords.

---

**Exclusion-volume pattern** (`docs/WORLD_MAP_VISUAL_PRODUCTION_PLAN.md` lines 53–66):

```markdown
### Negative space and camp rules

Every candidate also obeys these implemented exclusions:

- a `1360`-unit clear radius around the camp;
- eighteen landmark exclusion rectangles covering principal building, mall and village footprints;
- a `320`-unit world-edge margin;
- road-center clearance of `350` units for moss, `380` for props, `390` for rubble and `410` for cracks;
[...]
The colliding forest builder independently protects a `720`-unit inner camp clearing when it adds mixed-age trees and fallen logs. The ambient pass independently preserves a `1760`-unit camp clearing, a `480`-unit road-center margin (`360` in connector shoulders), and a `340`-unit gap between large ruin/village silhouettes.
```

**Copy the habit: name radius + owning layer.** Contract must distinguish:

| Volume | Live / target | Owner |
|--------|---------------|--------|
| Camp open (gameplay) | `STARTING_CAMP_OPEN_RADIUS` 520 | map / colliding forest |
| Camp scenery bowl | 1760 ambient | dress layer (salt `+137`) |
| Camp road-edge | `STARTING_CAMP_REQUIRED_ROAD_EDGE_CLEARANCE` 1600 (measured 2098 today) | map |
| Road-edge urban asphalt dress | 480 | dress |
| Road-edge forest dress | 300 | dress |
| Landmark discs | named, not GDScript yet | later co-author with obstacles |
| Satellite furniture | 3 offsets stay **inside** the bowl (D-04) | map |

Presentation never writes collision/flow (D-28). Analog numbers above are **current implementation**; contract restates jobs and which layer owns which, then Phase 2 retunes.

Also copy analog's **asphalt vs dirt visual split** (`WORLD_MAP_VISUAL_PRODUCTION_PLAN.md` lines 18, 74): widths live `ASPHALT` outer 540 / inner 420, `DIRT` outer 480 / inner 360 (`world_road_network_2d.gd`). Third grade (wilderness perimeter) is a **look** in Phase 3 (ROAD-01), not a new flag in Phase 1. Code today is `PackedByteArray([0, 0, 0, 0, 1, 1, 1, 1])` — four asphalt, four dirt; perimeter is dirt like villages.

---

**District-job table analog** (`docs/WORLD_MAP_VISUAL_PRODUCTION_PLAN.md` lines 9–16):

```markdown
| Region identity | Macro-cells | Authored landmarks and traversal character |
|---|---|---|
| Kaupunki | columns 1-5, rows 1-5 | Six large ruin footprints, [...] |
| Ostari | columns 7-10, rows 2-5 | Two long commercial footprints [...] |
```

**Copy table columns as Job / Topology / Shout noun — not frozen cells.** D-21: seats **may rearrange** on locked 14×14. Sketch relative topology (named places + connections). No new `Vector2` for the dirt spur (Open Question 2: "spur from clearing bowl to nearest asphalt spine, length short enough that 30s loop is a circuit").

Locked jobs:

| Place | Job | Shout noun |
|-------|-----|------------|
| Camp | secluded Metsä hero clearing | Amber Gold (only dominant warm) |
| Ostari | 10-minute mall salvage | mall gate = gap in long shell (missing tooth), not a glow prop (D-18) |
| West Kylät | quiet yards | west yard (silhouette + negative space, not fence-as-hero) |
| East Kylät | unnamed graveyard / abandoned rest | **none** |
| Kaupunki | dense urban choke | city choke |
| Metsä (near) | canopy wall + sparse interior + 30s loop | Metsä threat weenie (D-12 named landmark) |
| Far wilderness | quieter empty (10-minute empty) | none; not on 30s loop |

---

**30s loop pattern** — no analog file lists these beats; copy RESEARCH Pattern 1 + CONTEXT specifics:

```markdown
## 30s loop (all Metsä, D-24)
1. Camp hero clearing (Amber Gold weenie)
2. Dirt spur (readable exit, D-02)
3. Short asphalt read (not a commute)
4. Metsä threat weenie (D-12 named landmark)
5. Nearby teaching salvage pocket (not Ostari)
6. Threat approach → back along spur
```

10-minute: asphalt spine to Ostari through mall-gate gap. Ostari owns salvage density (D-17). Salvage pocket is a **place**, not a fifth weenie (D-12). Co-op shout list is **exactly five**. Warning: landmark table with six rows = failed D-11.

---

**Capture-camera table** — specified as a table, not nodes (RESEARCH Pattern 3). Gameplay zoom class = 0.38 (`GAMEPLAY_CAMERA_ZOOM`). Way-home rows: **minimap hidden**. Prefer TIME-stable look-ats for silhouette claims. Phase that implements = 7 (loop) / 7–8 (way-home).

| camera_id | Beat | HUD | TIME class | Phase |
|-----------|------|-----|------------|-------|
| `cam_loop_01_camp_clearing` | Hero bowl + Amber Gold + 3 satellites | optional | noisy (camp lights) — judge silhouette, not pixel diffs | 7 |
| `cam_loop_02_dirt_spur` | Readable camp exit | optional | prefer stable verge | 7 |
| `cam_loop_03_asphalt_read` | Short spine segment on 30s circuit | optional | `central_road_shoulder` class | 7 |
| `cam_loop_04_metsa_threat_weenie` | 30s named landmark (D-12) | optional | `forest_density` class if treed | 7 |
| `cam_loop_05_teaching_salvage` | Nearby pocket, not Ostari | optional | noisy if nodes pulse | 7 |
| `cam_loop_06_threat_approach` | Threat beat then return | optional | as weenie | 7 |
| `cam_home_from_kaupunki` | Way-home | **minimap hidden** | district | 7–8 |
| `cam_home_from_ostari` | Way-home via mall-gate then spine | **minimap hidden** | `mall` stable | 7–8 |
| `cam_home_from_west_kylat` | Way-home | **minimap hidden** | west village (night variant noisy) | 7–8 |
| `cam_home_from_east_kylat` | Way-home; east unnamed | **minimap hidden** | `east_village` stable | 7–8 |
| `cam_job_kaupunki_choke` | District job DIST-01 | optional | `city_density` / `city_building_detail` | 7 |
| `cam_job_ostari_mall_gate` | Missing-tooth gap D-18 | optional | `mall` / `mall_long_shell` | 7 |
| `cam_job_west_yard` | Negative space + silhouette | optional | west village | 7 |
| `cam_job_east_rest` | Unnamed graveyard quiet | optional | `east_village` | 7 |
| `cam_job_metsa_canopy_wall` | Forest threat job; FIR-01 named | optional | **`forest_density` only** | 7 |

Capture analog for "named list of intents" (`WORLD_MAP_VISUAL_PRODUCTION_PLAN.md` lines 150–151) — copy the *inventory* habit, replace 23 with the IDs above. Do not add nodes to `tests/world_render_validation.gd`.

---

**Phase 2 consumer list** (contract appendix; Phase 1 does not move camp):

| Site | Role |
|------|------|
| `src/world/world_map_2d.gd` | canonical const + satellites + dress configure + tree clear |
| `src/world/resource_scatter_2d.gd` | three teaching anchors |
| `src/coop/coop_session.gd` `_spawn_position_for` | spawn ring literals |
| `src/tactical/tactical_build_system.gd` | Base Core global_position + `set_core_position` |
| `src/world/world_background_decor_2d.gd` | **duplicate** `CAMP_POSITION = Vector2(9950, 2400)` |
| `tests/world_map_validation.gd` | `EXPECTED_STARTING_CAMP_POSITION` + satellite offsets |
| `tests/smoke_test.gd` | expected camp |
| `tests/mobile_systems_validation.gd` | expected camp |
| `tests/world_render_validation.gd` | cameras read live const (good) |

Warning: grepping only `STARTING_CAMP_POSITION` misses the decor literal (RESEARCH Pitfall 7).

`WorldCompositionContract` Resource + `.tres` is **Phase 2**, not this file's runtime.

---

**Out-of-scope / remaining-work pattern** (`docs/WORLD_MAP_VISUAL_PRODUCTION_PLAN.md` lines 153–164 + `docs/AAA_VISUAL_REDESIGN_AUDIT_2026-09-16.md` lines 259–265):

```markdown
## Remaining production work
[...]
6. Only after those gates, expand district landmarks or alter navigation footprints under an explicit layout-version change.

No runtime-visual change is complete merely because Blender rendered it or a headless scene loaded it.
```

**Copy ordered deferral.** Phase 1 out of scope pointer: FIR-01, SALV-01, fence projection, TINT-01, PLACE-01, pocket-2 move, Resource `.tres`, extra stamps (SETP-01 / VISL-01), Android / two-device LAN.

---

**Verification pattern for the contract** (`docs/WORLD_MAP_FOUNDATION.md` lines 65–78) — copy PowerShell gate *shape* only if citing how later phases prove the *old* map. Phase 1 proof is **not** those scripts:

```text
git diff --name-only -- src/world/
# must print nothing

# Also grep Phase 1 diff for LAYOUT_VERSION, WORLD_BUILD_SEED,
# TOTAL_SCENERY_COUNT, WILD_TREE_REGIONS, WILDERNESS_POCKETS
# — must be unchanged in .gd files.
```

Heading grep on `docs/WORLD_MAP_REDESIGN_CONTRACT.md` vs the 15-section outline. Do **not** create `tests/map_contract_validation.gd`.

**Read-only / not-an-importer analog** (`docs/ADDONS_AUDIT_EXTRACTION_GATE.md` lines 1–8):

```markdown
`Addons/` is an immutable source vault. The extraction gate materializes every
physical non-container file plus every supported archive member as review
evidence; it is not an importer, does not promote assets, and never writes a
byte under `Addons/` or `assets/`.
```

**Copy:** Phase 1 docs are not importers. No new `Rect2`, no wild/salvage promotion, no `Addons/` dump.

## Shared Patterns

### Two-file current vs target
**Source:** RESEARCH Architecture Pattern 1; analog split = `ADDONS_DEEP_AUDIT.md` (as-is) vs `WORLD_MAP_FOUNDATION.md` / production plan (contract).
**Apply to:** both new files. Do **not** merge. Phase 2 consumes the contract; audit is evidence the contract is grounded.

### Live-constant citation
**Source:** RESEARCH Pattern 2; anti-pattern in `docs/WORLD_MAP_FOUNDATION.md` lines 37–38, 84, 96.
**Apply to:** every number in the audit.
```markdown
[VERIFIED: `src/world/world_ambient_scenery_2d.gd` `TOTAL_SCENERY_COUNT`]
```
Never copy 576 / 172 / 23 / 150 from foundation, `ADDONS_DEEP_AUDIT.md` line 118, `MOBILE_LAN_FOUNDATION.md` line 35, or `WORLD_MAP_VISUAL_PRODUCTION_PLAN.md` line 149.

### Presentation never writes simulation
**Source:** `docs/WORLD_MAP_FOUNDATION.md` lines 41–48; `docs/WORLD_MAP_VISUAL_PRODUCTION_PLAN.md` lines 20–33; `Claude.md` §16 / CONVENTIONS.
**Apply to:** contract exclusion volumes, weenie naming, pocket jobs.
Sprites / dress salts (`+91/+137/+173/+211`) do not move collision, flow, gather IDs, or RPC.

### Visual veto overrides numeric pass
**Source:** `docs/AAA_VISUAL_REDESIGN_AUDIT_2026-09-16.md` lines 24–30, 86–103.
**Apply to:** unreadables section + contract tripwires. `runtime_promotion = forbidden_pending_human_visual_veto`. FIR-01 named, not solved.

### TIME-stable vs noisy captures
**Source:** RESEARCH Pitfall 2; CLAUDE.md §9 (cited in RESEARCH).
**Apply to:** audit capture inventory + contract camera TIME class. Do not re-run 25 GPU captures in Phase 1.

### No second Amber Gold / no world-space nameplates
**Source:** `Claude.md` §8 palette; CONTEXT D-10; execution matrix rule 4 (`docs/AAA_VISUAL_REDESIGN_EXECUTION_MATRIX_2026-09-16.md` lines 57–59):
```markdown
4. **Warm refuge / cool threat.** Base Core ja eloonjäämisen signalointi voivat
   pitää lämpimän amberin; wilderness, UI secondary ja material debris eivät
   käytä sitä kilpailevana jatkuvana aksenttina.
```
**Apply to:** five shout nouns. Mall gate is a **gap**, not a glow.

### Git path filter as the Phase 1 test
**Source:** `01-VALIDATION.md` lines 21–24, 40–45; RESEARCH git proof.
**Apply to:** every plan task. Allowed: `docs/*.md`, `.planning/phases/01-*/**`. Forbidden: `world_map_2d.gd`, `world_road_network_2d.gd`, `world_obstacle_2d.gd`, `world_*_2d.gd`, `resource_scatter_2d.gd`, camera lists in `tests/world_render_validation.gd`.

### No autoload / no composition Resource this phase
**Source:** CONVENTIONS; RESEARCH Don't Hand-Roll.
**Apply to:** planner must not add `WorldComposer` node, Autoload, JSON/CSV layout, or `.tres` in Phase 1.

### Identity at 1× / silhouette first
**Source:** game-art skill (silhouette before hue); 2d-games skill ("Every pixel should communicate"); CONTEXT D-10; mobile-games 480×270.
**Apply to:** weenie language. Judge at 1× logical. Do not pick atlas frames (Phase 6).

### 30s loop is spatial
**Source:** game-design skill "The 30-Second Test"; CONTEXT D-24.
**Apply to:** contract beats. Loop is places, not a seed retune (`WORLD_BUILD_SEED` stay `0xB35E7E`).

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| — | — | — | Both deliverable docs have exact docs analogs. |

**Not missing — deferred (planner must not create):**

| File | Reason |
|------|--------|
| `data/world/bespren_world_composition.tres` | Phase 2 |
| `tests/map_contract_validation.gd` | Layout-adjacent; Wave 0 forbids |
| Third `dirt_flags` enum / `WorldRoadNetwork2D` edit | Phase 3 ROAD-01 |
| New capture scene / camera nodes | Phase 7 |

Use RESEARCH.md outlines when analog counts conflict with live `.gd`.

## Metadata

**Analog search scope:** `docs/` (WORLD_MAP_*, ADDONS_*, AAA_VISUAL_*, MOBILE_LAN_FOUNDATION.md); `Claude.md` §16; `.planning/phases/01-map-audit-redesign-contract/{01-CONTEXT,01-RESEARCH,01-VALIDATION}.md`; skill indexes `2d-games`, `game-design`, `game-art`, `godot-gdscript-patterns`, `mobile-games` (SKILL.md only).
**Files scanned:** 10 docs + 3 phase files + 5 skill indexes (no `src/` writes; live constants taken from RESEARCH verified census).
**Pattern extraction date:** 2026-09-19
