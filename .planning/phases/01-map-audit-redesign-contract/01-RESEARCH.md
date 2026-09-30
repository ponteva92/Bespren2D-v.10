# Phase 1: Map Audit + Redesign Contract - Research

**Researched:** 2026-09-19
**Domain:** Brownfield Godot 4.7.1 Mobile docs-only map composition (audit + written redesign contract)
**Confidence:** HIGH

## Summary

Phase 1 is a **docs-only** walking skeleton for this GSD milestone. Deliverable is a live census of the 14×14 world plus a written redesign contract under `docs/`. Zero world-authoring code. No `src/world/` layout edits, no new atlas `Rect2`s, no scenery/cover/resource count changes, no `LAYOUT_VERSION` / `WORLD_BUILD_SEED` bump, no new packages, no UI-SPEC, no web/DB scaffold.

The current map already has names (Kaupunki, Ostari, Kylät, Metsä), locked extents (±14,336), eight polylines, colliding district shells, and independently salted dress layers. It does **not** have an authored 30s loop on the ground: camp at `(9950, 2400)` has **no dirt spur**, salvage is 84-sector scatter plus three teaching offsets, there is no Metsä threat weenie, and pocket 2 sits under `OstariSouthShell`. The contract must name the target anatomy so Phase 2 can consume it as composition data. Audit must quote live `.gd` constants and the current 25-capture set — `docs/WORLD_MAP_FOUNDATION.md` scenery/capture counts are stale.

**Primary recommendation:** Write two markdown files — `docs/WORLD_MAP_AUDIT.md` (current-state census) and `docs/WORLD_MAP_REDESIGN_CONTRACT.md` (locked target). Prove CONT-01 with heading completeness + live-constant quotes + `git diff --name-only -- src/world/` empty. Do not run GPU gates. Do not implement cameras.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Camp
- **D-01:** Base Core stays secluded Metsä. Not a road-junction camp.
- **D-02:** Player leaves camp on a dirt spur that meets asphalt. Spur is the readable exit.
- **D-03:** Camp is a hero clearing: camp + three satellites + teach-pocket in one empty bowl. Forest wall is the edge.
- **D-04:** Keep the three camp satellites. Compose them as camp furniture in the clearing, not as distant stamps.

### Nature
- **D-05:** Metsä's job is canopy wall + sparse interior. Camp is the one true clearing.
- **D-06:** Two natures, not a fifth district. Metsä = threat canopy near camp/roads. Far wilderness = quieter empty (the 10-minute empty).
- **D-07:** The 30s loop stays in Metsä. It does not enter far wilderness.
- **D-08:** Fir canopy stalk defect is named, not solved. FIR-01 later. Do not promote wild non-tree frames. Contract may cite the 1× veto; it must not require a mass language now.

### Landmarks
- **D-09:** Sparse named-weenie list of five. Not a dense 10–12 roster.
- **D-10:** Landmarks shout at 480×270 by silhouette first. Hue is secondary. No world-space nameplates. No second Amber Gold competitor.
- **D-11:** Locked shout nouns: camp Amber Gold; mall gate (Ostari); west yard (west Kylät); city choke (Kaupunki); Metsä threat weenie. East village has no shout noun.
- **D-12:** The 30s-loop "named landmark" beat is the Metsä threat weenie. Mall gate / west yard / city choke are wayfinding, not 30s-loop beats. The salvage pocket is a place, not a fifth weenie.

### Towns (Kylät)
- **D-13:** Two different village jobs in the same quiet family. West = quiet yards (named west yard). East = graveyard / abandoned rest (unnamed). East does not steal Ostari salvage.
- **D-14:** Keep two geographically separate villages. Do not collapse into one cluster with two yards.
- **D-15:** Village fence vs house projection mismatch is named, not solved. Open art debt. No fence rebake in Phase 1. West yard reads by silhouette + negative space, not fence-as-hero.

### City + Ostari
- **D-16:** Keep both jobs. Kaupunki = dense urban choke (named city-choke silhouette). Ostari = mall salvage behind named mall gate. Neither sits on the 30s Metsä loop.
- **D-17:** Ostari owns 10-minute salvage density. Metsä 30s pocket is teaching/nearby only. City/villages may hold sparse nodes but not the salvage identity.
- **D-18:** Mall gate weenie is a gap in a long shell (missing tooth). Not a glowing vertical prop. Hero dressing later only if the gap already reads.
- **D-19:** Pocket 2 vs `OstariSouthShell` stays the recorded unhostable tripwire. Phase 1 names the collision and does not move the pocket. Pocket tables and obstacle tables are co-authored from Phase 5. `MAXIMUM_UNHOSTABLE_POCKETS = 1` stays.

### Roads + layout
- **D-20:** Three readable road grades at 1×. Asphalt spine = way-home. Dirt = camp spur + village paths. Wilderness perimeter exists and is not the 30s path.
- **D-21:** Districts may rearrange on the locked 14×14 grid. Compass seats (NW city / NE mall / south villages / Metsä wrap) are not frozen.
- **D-22:** Camp is free to move inside Metsä. Still secluded, still dirt spur, still hero clearing. Phase 2 must grep every `STARTING_CAMP_POSITION` consumer. Extents stay ±14,336.
- **D-23:** Asphalt always leads home. Every district exit hits the asphalt spine; follow it to the dirt spur and camp. Silhouettes + Amber Gold confirm. District weenies are local nouns, not compasses. Minimap is not the way-home.
- **D-24:** 30s loop is a tight Metsä circuit. All five beats stay near camp inside Metsä. Asphalt appears as a short readable segment, not a commute. Ostari is the 10-minute salvage commute on the spine.

### Contract + audit (phase delivery)
- **D-25:** Phase 1 output is documents, not layout code. Researcher/planner must treat `docs/` as the deliverable. Suggested contract path: `docs/WORLD_MAP_REDESIGN_CONTRACT.md` (planner confirms name). Audit may live in the same doc or a sibling under `docs/`.
- **D-26:** Audit quotes live constants and current capture set: `BesprenWorldMap2D` extents/seed/camp, obstacle/pocket/scenery counts from `.gd` files, `tests/world_map_validation.gd`, `tests/world_render_validation.tscn` (25 captures), pocket-2 unhostable record in `tests/existing_wild_atlas_context_validation.gd`. Do not trust stale numbers in `docs/WORLD_MAP_FOUNDATION.md`.
- **D-27:** Contract must include exclusion volumes (camp clearing, landmark discs, road-edge clearance) and named capture cameras on the 30s-loop beats plus way-home-from-district frames with minimap hidden. Cameras are specified, not implemented, in this phase.
- **D-28:** Presentation never writes simulation. Collision, flow, gather rules (87 IDs, 3–5 step, one-unit yield), and peer-one RPC stay canonical. Phase 1 does not bump `LAYOUT_VERSION` or `WORLD_BUILD_SEED`.

### Claude's Discretion
- Landmark count and the five shout nouns (D-09, D-11) — user chose "You decide"; sparse 5 as above.
- 30s-loop landmark = Metsä threat weenie (D-12) — "You decide".
- East village job = graveyard / abandoned rest (D-13) — "You decide".
- Pocket-2 tripwire kept, not forbidden-now (D-19) — "You decide".
- Three road grades (D-20) — user declined the question twice; locked to ROAD-01 three-grade hierarchy.

### Deferred Ideas (OUT OF SCOPE)
- Extra stamps / more unique props — Phase 6 (SETP-01) and Phase 9 (VISL-01). Contract may name hero pieces and density rules only.
- FIR-01 fir canopy mass — geometry rebake, not this phase.
- SALV-01 salvage-atlas promotion — after hosted-pocket 1× veto.
- Fence vs house projection rebake — named in D-15; art later.
- TINT-01 drop `WILD_TREE_TINT` after pine rebake.
- PLACE-01 nested Theory of the Place after the primary path reads.
- Pocket 2 relocation / shell shrink — Phase 5 co-author, not Phase 1.
- WorldCompositionContract Resource + `.tres` — Phase 2.
- Android device / two-device LAN / deposit-inventory-progression — wrong milestone.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CONT-01 | Team can audit the current 14×14 map (captures, density, pocket/obstacle overlaps, 1× unreadables) and write a redesign contract in `docs/` that names camp, roads, district jobs, landmarks, salvage/threat pockets, 30s-loop beats, way-home language, exclusion volumes, and capture cameras — with zero world-authoring code in that phase | Two-file `docs/` deliverable; live-constant census below; contract section outline; named cameras (spec only); git path-filter proof that `src/world/` is untouched; Nyquist map of heading completeness + empty world-layout diff |
</phase_requirements>

## Architectural Responsibility Map

Phase 1 is documentation, not a web stack. Tiers are ownership of the written contract vs later runtime.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Live map census (extents, seed, camp, counts, pockets, captures) | Docs (`docs/WORLD_MAP_AUDIT.md`) | Source-of-truth (`src/world/*.gd`, `tests/*validation*`) | Audit quotes code; does not become a second authority |
| Target camp / dirt spur / hero clearing | Docs (contract) | Forbidden-runtime (`src/world/` this phase) | D-01–D-04 name the place; Phase 2 moves `STARTING_CAMP_POSITION` |
| Road hierarchy (asphalt / dirt / perimeter) | Docs (contract) | Validation-gate (Phase 3 / ROAD-01) | D-20 names three grades; current code has two `dirt_flags` only |
| District jobs + rearrange on 14×14 | Docs (contract topology) | Forbidden-runtime | D-21 allows seat slide; extents stay; no biome-table edit now |
| Five shout nouns + 30s-loop beats | Docs (contract) | Validation-gate (Phase 7–8 cameras) | Cameras specified here, implemented Phase 7 |
| Way-home language (not minimap) | Docs (contract) | Validation-gate (HUD-hidden captures Phase 8) | D-23; shipping HUD stays; review frames hide minimap |
| Exclusion volumes | Docs (named radii) | Source-of-truth later (`WorldObstacle2D` + dress salts) | Presentation never writes collision/flow (D-28) |
| Pocket 2 vs `OstariSouthShell` | Docs (record overlap) | Validation-gate (`MAXIMUM_UNHOSTABLE_POCKETS = 1`) | D-19: name, do not move |
| Capture-camera list | Docs (IDs + intent + TIME class) | Forbidden-runtime (`tests/world_render_validation.gd` this phase) | D-27: specified, not implemented |
| Composition Resource / `.tres` | Forbidden-runtime this phase | Phase 2 (`BesprenWorldMap2D.ensure_built()`) | CONTEXT deferred; SUMMARY.md stack gap is Phase 2 |
| Gather rules 87 / 3–5 / one-unit | Source-of-truth (unchanged) | Docs (must restate freeze) | D-28; Phase 1 names pocket *jobs*, not node coords |
| Proof of zero layout code | Validation-gate (`git diff` path filter) | Docs (phase boundary banner) | Success criterion 3 |

## Standard Stack

Docs-only phase. Keep the shipping runtime. Install nothing.

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Godot | `4.7.1.stable.official.a13da4feb` | Existing runtime; **not invoked** unless a later phase re-runs gates | Locked in `CLAUDE.md` / `project.godot` [VERIFIED: CLAUDE.md §13, `.planning/codebase/TESTING.md`] |
| Typed GDScript 2.0 | `untyped_declaration=2` | Live constants the audit quotes | Existing [VERIFIED: `project.godot` via CONVENTIONS.md] |
| Markdown under `docs/` | — | Phase 1 deliverable format | Existing `docs/` is the spatial-contract home [VERIFIED: `.planning/codebase/STRUCTURE.md`] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Git path filter | repo git | Prove `src/world/` untouched | Phase-gate verification |
| Existing capture PNGs under `artifacts/` | current on-disk set | Filename inventory for audit; **do not re-run GPU** | Quote names + TIME-stable class; do not treat pixels as re-proven |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Two files (audit + contract) | One combined markdown | One file is shorter; two files stop Phase 2 from treating current-state counts as target composition. **Use two files.** |
| Quoting `docs/WORLD_MAP_FOUNDATION.md` | Live `.gd` | Foundation scenery 576 / forest 172 / 23 captures / gate 150 are stale vs live 640 / 236 / 25 / 169 [VERIFIED: foundation vs `world_ambient_scenery_2d.gd` / `world_render_validation.gd`] |
| `WorldCompositionContract` Resource now | Markdown contract | Resource is Phase 2. Writing `.gd`/`.tres` in Phase 1 is world-authoring by another name |
| Tiled / LDtk / TileMap as landmark graph | Authored markdown topology | Hard reject from project research; TileMapLayer stays ground fill only |
| GUT / pytest / Jest | Existing Godot `*_validation.gd` later | Phase 1 has no runtime tests to add. Do not introduce a JS/Python test runner |

**Installation:** none.

**Version verification:** no packages. Godot binary if ever needed: `C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64.exe`. Phase 1 does not require running it.

## Package Legitimacy Audit

> Docs-only phase installs nothing.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| — | — | — | — | — | — | none |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

*No external packages. Planner must not add `npm install` / `pip install` / Godot AssetLib tasks.*

## Architecture Patterns

### System Architecture Diagram

```text
                    ┌──────────────────────────────────────┐
                    │  Reviewer / Phase 2 planner          │
                    └──────────────────┬───────────────────┘
                                       │ reads
           ┌───────────────────────────┴────────────────────────────┐
           ▼                                                        ▼
┌─────────────────────────┐                           ┌──────────────────────────────┐
│ docs/WORLD_MAP_AUDIT.md │                           │ docs/WORLD_MAP_REDESIGN_     │
│ CURRENT STATE           │                           │ CONTRACT.md  TARGET STATE    │
│ extents/seed/camp       │                           │ camp job + dirt spur         │
│ 8 routes + dirt_flags   │                           │ 3 road grades                │
│ biome seats (live)      │                           │ district jobs + topology     │
│ pocket 2 overlap        │                           │ 5 shout nouns                │
│ 1× unreadables          │                           │ 30s beats (Metsä only)       │
│ 25 capture filenames    │                           │ way-home (not minimap)       │
│ TIME-stable class       │                           │ exclusion volumes            │
│ FIR-01 / wild veto named│                           │ named cameras (spec only)    │
└────────────▲────────────┘                           └──────────────▲───────────────┘
             │ grep live constants                                   │ must not
             │ do NOT trust WORLD_MAP_FOUNDATION.md counts           │ edit runtime
             │                                                       │
   ┌─────────┴──────────┐     Phase 1 FORBIDDEN      ┌───────────────┴────────┐
   │ src/world/*.gd     │◄──── no layout edits ─────►│ tests/world_render_*.gd│
   │ tests/*validation* │     no Rect2 / counts      │ (cameras Phase 7)      │
   │ artifacts/*.png    │     no LAYOUT_VERSION bump │                        │
   └────────────────────┘                            └────────────────────────┘
             │
             │ Phase 2+ only
             ▼
   BesprenWorldMap2D.ensure_built()  ←  data/world/bespren_world_composition.tres
```

Trace CONT-01: live `.gd` → audit quotes → contract names target anatomy → reviewer opens `docs/` → `git diff src/world` empty.

### Recommended Project Structure

```
docs/
├── WORLD_MAP_AUDIT.md                 # Phase 1: current census (NEW)
├── WORLD_MAP_REDESIGN_CONTRACT.md     # Phase 1: locked target (NEW)
├── WORLD_MAP_FOUNDATION.md            # existing; treat counts as stale; do not "refresh" by inventing numbers
└── WORLD_MAP_VISUAL_PRODUCTION_PLAN.md

.planning/phases/01-map-audit-redesign-contract/
├── 01-CONTEXT.md                      # locked decisions (already exists)
├── 01-RESEARCH.md                     # this file
└── (PLAN.md later — not this agent)

src/world/                             # READ ONLY this phase
tests/                                 # READ ONLY this phase
```

**Confirm path (D-25):** use `docs/WORLD_MAP_REDESIGN_CONTRACT.md` as the contract. Put the census in sibling `docs/WORLD_MAP_AUDIT.md`. Do **not** merge them. Phase 2 consumes the contract; the audit is the evidence the contract is grounded.

Do **not** refresh `WORLD_MAP_FOUNDATION.md` counts in Phase 1 (that doc tracks the *implemented* world; counts move in Phase 2). Audit may include a one-line "foundation drift" table so planners stop copying 576/23/150.

### Pattern 1: Two-file current vs target

**What:** Audit = as-is. Contract = to-be. Every number in the audit has a `[VERIFIED: path]` or a live constant name. Every named place in the contract maps to a later capture camera ID.
**When to use:** This phase, always.
**Example:**

```markdown
# Source: contract outline (this research). Not runtime.

## 30s loop (all Metsä, D-24)
1. Camp hero clearing (Amber Gold weenie)
2. Dirt spur (readable exit, D-02)
3. Short asphalt read (not a commute)
4. Metsä threat weenie (D-12 named landmark)
5. Nearby teaching salvage pocket (not Ostari)
6. Threat approach → back along spur
```

### Pattern 2: Live-constant citation, never foundation prose

**What:** Census tables copy identifiers from `.gd` (`const` names), then the numeric value read this session.
**When to use:** Every count in `WORLD_MAP_AUDIT.md`.
**Example:**

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

### Pattern 3: Cameras specified as a table, not nodes

**What:** Contract lists `camera_id`, beat, suggested look-at (place name, not GDScript `Vector2` unless quoting current camp), zoom class (`overview` / `district` / `gameplay 0.38`), TIME class (`stable` vs `noisy`), HUD (`minimap hidden` for way-home).
**When to use:** D-27. Phase 7 retargets `tests/world_render_validation.gd`.
**Example:** see Code Examples → Capture camera IDs.

### Anti-Patterns to Avoid

- **Implementing the skeleton in Phase 1:** editing `_build_biome_cells`, routes, or scatter is a failed milestone, not a head start [CITED: `.planning/research/SUMMARY.md` Pitfall 1].
- **One oatmeal seed retune:** changing `WORLD_BUILD_SEED` or dress salts (`+91/+137/+173/+211`) and calling it authorship.
- **World-space nameplates:** admits silhouette failure (D-10, REQUIREMENTS out of scope).
- **Second Amber Gold:** Base Core is the only dominant warm weenie (`CLAUDE.md` §8).
- **Minimap as way-home:** D-23 / READ-02. Review captures hide the 72×54 minimap.
- **Promoting wild non-tree frames:** `runtime_promotion = forbidden_pending_human_visual_veto` [VERIFIED: `tests/existing_wild_atlas_context_validation.gd`].
- **Moving pocket 2** to make a review card fit [VERIFIED: CONCERNS.md; D-19].
- **Scaffolding a web app / DB / router:** GSD walking-skeleton for *this* phase is the written audit+contract.
- **UI-SPEC for product HUD:** Phase writes markdown in `docs/`, not GameHUD.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Authored layout data | JSON/CSV/Autoload/`WorldComposer` node | Markdown contract now; typed `Resource` in Phase 2 | Inner classes don't serialize; Autoload forbidden; Phase 1 is docs |
| Landmark graph | Paint 28,672-unit TileMap | Named places + relative topology in contract | TileMapLayer is ground fill only [CITED: SUMMARY.md] |
| Proof of no layout edits | Memory / "we didn't touch it" | `git diff --name-only -- src/world/` | Success criterion 3 is a path filter |
| Live counts | `WORLD_MAP_FOUNDATION.md` | Grep `const` in `src/world/` + tests | Foundation 576/172/23/150 vs live 640/236/25/169 |
| 30s-loop proof | Re-run 25 GPU captures | Named camera table + existing filename inventory | Cameras implemented Phase 7; TIME noise makes camp frames unusable as tree evidence |
| Collision/flow from sprites | New obstacle class | Keep `WorldObstacle2D`; Phase 1 only *names* weenies | One obstacle type [VERIFIED: `world_obstacle_2d.gd`] |
| Adjacent variety | `index % 8` or per-segment coin | Named later (SETP-01); contract may state "by construction" | Fence coin already failed [VERIFIED: CLAUDE.md §9] |
| Walking skeleton | Express/Next/DB | Two markdown files | Phase 01 of a Godot brownfield docs slice |

**Key insight:** Largest work is the written anatomy. Layout code without that anatomy is more seeded scatter (Kate Compton oatmeal). Phase 1 that touches `src/world/` placement is a process failure.

## Runtime State Inventory

> SKIPPED — Phase 1 is not a rename / rebrand / identifier-migration phase.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — verified by phase type (docs-only; no datastore keys renamed) | none |
| Live service config | None — no n8n/Datadog/cloud map IDs | none |
| OS-registered state | None — Godot project, no scheduled-task rename | none |
| Secrets/env vars | None — gameplay has no `.env`; LAN address typed at Join [VERIFIED: STACK.md / CONCERNS.md Security] | none |
| Build artifacts | None this phase — do not rebuild APK | none |

Camp move is **authorized later inside Metsä** (D-22) but is **not executed** here. When Phase 2 moves it, grep consumers listed under Code Examples.

## Common Pitfalls

### Pitfall 1: Trusting `docs/WORLD_MAP_FOUNDATION.md` counts
**What goes wrong:** Planner copies 576 scenery, 172 forest, 23 captures, `WORLD MAP VALIDATION OK (150)`.
**Why it happens:** Foundation is an implementation contract that lagged live constants.
**How to avoid:** Quote `WorldAmbientScenery2D.TOTAL_SCENERY_COUNT = 640`, `ZONE_SCENERY_COUNTS = [96, 72, 48, 48, 236, 92, 48]`, `capture_count = 25`, gate file prints `WORLD MAP VALIDATION OK (%d checks)` (TESTING.md records 169). [VERIFIED: `src/world/world_ambient_scenery_2d.gd`, `tests/world_render_validation.gd`, `.planning/codebase/TESTING.md`, `docs/WORLD_MAP_FOUNDATION.md` lines 37–38]
**Warning signs:** Audit table matches foundation prose instead of `.gd` consts. Extra: `tests/world_map_validation.gd` assertion *string* still says "exact 576" while `EXPECTED_AMBIENT_SCENERY_TOTAL = 640` — quote the **constant**, not the stale English. [VERIFIED: `tests/world_map_validation.gd` ~26 and ~654]

### Pitfall 2: TIME-noisy captures as art evidence
**What goes wrong:** Camp day/night diffs attributed to layout; tree claims judged on camp frames.
**Why it happens:** Shader `TIME`, resource pulse, `AmberLight`/aura, actor frames. 11/25 frames byte-identical across identical runs; camp can move 5,912 / 21,799 pixels between runs. [VERIFIED: CONCERNS.md; CLAUDE.md §9]
**How to avoid:** Audit lists TIME-stable vs noisy. Tree/canopy claims: `forest_density`. Do not re-run GPU in Phase 1.
**Warning signs:** Audit treats `world_forest_camp_*.png` as silhouette evidence.

**TIME-stable class (use for tree/landmark-shape claims):** `central_road_shoulder`, `city_barrier` day/night, `city_building_detail`, `city_density`, `city_salvage`, `east_village`, `forest_density`, `forest_log`, `forest_rock`, `local_car_wreck`, `mall` [VERIFIED: CONCERNS.md].

### Pitfall 3: Pocket tables and obstacle tables authored separately
**What goes wrong:** `WILDERNESS_POCKETS[2] = Vector4(2600, -2200, 700, 620)` under `OstariSouthShell` at `(4850, -3150)` size `(6400, 1800)` (bounds x 1650..8050, y -4050..-2250). Accent layer **duplicates** the same pocket table. [VERIFIED: `world_ambient_scenery_2d.gd`, `world_wilderness_accent_2d.gd`, `world_map_2d.gd` `_build_mall`]
**Why it happens:** Dress layers and colliding builders do not share a composition source.
**How to avoid:** Phase 1 **records** the overlap. Do not move the pocket. `MAXIMUM_UNHOSTABLE_POCKETS = 1` stays (D-19). Co-author from Phase 5.
**Warning signs:** Audit "fixes" unhostable by proposing a new Vector4.

### Pitfall 4: Bumping `LAYOUT_VERSION` or `WORLD_BUILD_SEED`
**What goes wrong:** Scatter IDs / dress streams shift with no composition contract.
**Why it happens:** Habit from gather-layout changes (`LAYOUT_VERSION = 2` comment: increment when ID ordering/placement semantics change) [VERIFIED: `resource_scatter_2d.gd`].
**How to avoid:** D-28 freeze. Phase 1 docs restate the freeze. Phase 2 bumps layout when 87 IDs move to pockets.
**Warning signs:** Diff in `src/world/resource_scatter_2d.gd` or `WORLD_BUILD_SEED`.

### Pitfall 5: Editing `src/world/` "just to measure"
**What goes wrong:** Success criterion 3 fails; oatmeal begins.
**Why it happens:** Temptation to print obstacle count or nudge a camera.
**How to avoid:** Read-only grep. Obstacle **count 461** in comments is historical ("linear scan over all 461 obstacles") — do not assert 461 without a live gate run, and do not add a count print in production. [VERIFIED: `world_map_2d.gd` comment at `OBSTACLE_BROADPHASE_CELL`]
**Warning signs:** Any path under `src/world/` in `git diff --name-only`.

### Pitfall 6: Assuming a camp dirt spur already exists
**What goes wrong:** Contract writes "keep the spur" when none exists.
**Why it happens:** D-02 describes the *target*. Live camp has `STARTING_CAMP_REQUIRED_ROAD_EDGE_CLEARANCE = 1600` and measured 2098 to nearest road edge — secluded, **no spur polyline**. Eight routes; none terminate at `(9950, 2400)`. [VERIFIED: `world_map_2d.gd` `_build_road_network` + camp constants]
**How to avoid:** Audit states "no camp spur today." Contract **adds** a dirt spur as a Phase 2 route, still secluded (not a junction camp, D-01).
**Warning signs:** Audit lists 9 routes or a spur flag that is not in `dirt_flags`.

### Pitfall 7: Duplicate camp literals miss the Phase 2 grep
**What goes wrong:** Camp moves in `BesprenWorldMap2D.STARTING_CAMP_POSITION` but `WorldBackgroundDecor2D.CAMP_POSITION = Vector2(9950, 2400)` stays. [VERIFIED: `world_background_decor_2d.gd`]
**Why it happens:** Decor does not reference the map constant.
**How to avoid:** Contract "Phase 2 consumer list" includes that literal plus spawn/teaching offsets (see Code Examples). Phase 1 does not fix it.
**Warning signs:** Contract says "grep STARTING_CAMP_POSITION" only.

### Pitfall 8: Two road flags vs three readable grades
**What goes wrong:** Contract assumes a third `dirt_flags` value exists.
**Why it happens:** D-20 wants asphalt / dirt / wilderness-perimeter at 1×. Code is `PackedByteArray([0, 0, 0, 0, 1, 1, 1, 1])` — four asphalt, four dirt; perimeter is dirt like villages. [VERIFIED: `world_map_2d.gd` `_build_road_network`]
**How to avoid:** Contract names three **visual** grades. Implementation of the third look is Phase 3 (ROAD-01). Phase 1 does not add a flag enum.
**Warning signs:** Phase 1 task edits `WorldRoadNetwork2D`.

### Pitfall 9: Stale capture PNGs vs live camp
**What goes wrong:** On-disk frames still show old camp `(11264, 1536)` while code is `(9950, 2400)`.
**Why it happens:** Gate reads camp live; PNGs are not re-run automatically [VERIFIED: CLAUDE.md §12, CONCERNS.md].
**How to avoid:** Audit inventories **filenames and intents** from `tests/world_render_validation.gd`. Do not claim pixels match current camp unless file dates are checked. Prefer not to re-run GPU in Phase 1.
**Warning signs:** Audit pastes pixel measurements from undated PNGs.

### Pitfall 10: Naming East village
**What goes wrong:** Sixth shout noun appears ("east graveyard" as a callout).
**Why it happens:** Designers want symmetry.
**How to avoid:** D-11/D-13: east is unnamed quiet rest. Co-op shout list is exactly five.
**Warning signs:** Landmark table has six rows.

## Code Examples

Verified patterns from this repo (read-only).

### How to grep live counts (executor recipe)

```text
# Source: this research. Run from repo root. Do not edit files.

# Extents / camp / seed
# files: src/world/world_map_2d.gd
GRID_SIZE, CELL_SIZE, PLAYABLE_HALF_EXTENT, STARTING_CAMP_POSITION,
STARTING_CAMP_REQUIRED_ROAD_EDGE_CLEARANCE, WORLD_BUILD_SEED,
STARTING_CAMP_OPEN_RADIUS, STARTING_CAMP_SATELLITE_COUNT

# Roads
# files: src/world/world_map_2d.gd  func _build_road_network
#        src/world/world_road_network_2d.gd  ASPHALT_* DIRT_* widths

# Scenery / dress
# files: src/world/world_ambient_scenery_2d.gd
TOTAL_SCENERY_COUNT, ZONE_SCENERY_COUNTS, WILDERNESS_POCKETS
# files: src/world/world_background_decor_2d.gd
TOTAL_DECORATION_COUNT, RUBBLE_COUNT, CAMP_POSITION  (duplicate literal)
# files: src/world/world_wilderness_accent_2d.gd
TOTAL_ANCHOR_COUNT, WILDERNESS_POCKETS  (duplicate table)

# Scatter freeze
# files: src/world/resource_scatter_2d.gd
RESOURCE_COUNT, LAYOUT_VERSION, DEFAULT_SCATTER_SEED,
MIN_GATHER_INTERACTIONS, MAX_GATHER_INTERACTIONS, HARVEST_AMOUNT

# Unhostable tripwire
# files: tests/existing_wild_atlas_context_validation.gd
MAXIMUM_UNHOSTABLE_POCKETS
# files: tests/world_render_validation.gd
capture_count == 25
```

### Live constants to quote in the audit (this session)

[VERIFIED: files cited]

| Item | Live value | Source |
|------|------------|--------|
| Grid / cell / extent | 14 × 2048, half-extent 14336, world 28672 | `world_map_2d.gd` |
| Seed | `WORLD_BUILD_SEED = 0xB35E7E` | same |
| Camp | `Vector2(9950, 2400)`, road-edge clearance 1600, comment 2098 measured | same |
| Camp open / satellites | radius 520; count 3; offsets Bedding `(-650,-300)`, Supply `(350,650)`, Medical `(0,720)` | `world_map_2d.gd` + `world_map_validation.gd` |
| Biome seats (current, not frozen) | City cols 1–5 rows 1–5; Mall 7–10 × 2–5; West village 1–4 × 9–12; East village 9–12 × 9–12; Forest = perimeter or (col≥10 & row≤8) or (col≤2 & row≥5) | `_build_biome_cells` |
| `get_biome_regions()` | kaupunki `(1,1)–(5,5)`, ostari `(7,2)–(10,5)`, kyla_west `(1,9)–(4,12)`, kyla_east `(9,9)–(12,12)`, metsa_perimeter = PLAYABLE_RECT | `get_biome_regions` |
| Routes | 8 polylines; `dirt_flags [0,0,0,0,1,1,1,1]`; gate asserts `get_route_count() == 8` | `_build_road_network`, `world_map_validation.gd` |
| Asphalt widths | outer 540 / inner 420 | `world_road_network_2d.gd` |
| Dirt widths | outer 480 / inner 360 | same |
| Ostari south shell | name `OstariSouthShell`, pos `(4850, -3150)`, size `(6400, 1800)`, `VisualKind.MALL_SHELL` | `_build_mall` |
| Wilderness pocket 2 | `Vector4(2600, -2200, 700, 620)` index 2 of 10 | `world_ambient_scenery_2d.gd` and duplicate in `world_wilderness_accent_2d.gd` |
| Ambient scenery | 640 total; zones `[96, 72, 48, 48, 236, 92, 48]` | `TOTAL_SCENERY_COUNT`, `ZONE_SCENERY_COUNTS` |
| Background decor | 300+160+220+420 = 1100 | `world_background_decor_2d.gd` |
| Wilderness accent | 24 anchors | `TOTAL_ANCHOR_COUNT` |
| Dress salts | decor `+91`, ambient `+137`, accent `+173`, cover `+211` | `ensure_built` |
| Scatter | 87 IDs; layout v2; seed `0x5CA77E2`; 12×7 sectors; 3 teaching offsets `(390,120)`, `(-410,150)`, `(130,-430)` | `resource_scatter_2d.gd` |
| Gather freeze | 3–5 interactions, yield 1 on completion only | same |
| Captures | 25 paths listed in `world_render_validation.gd` `capture_count` | tests |
| Wild veto | `runtime_promotion = "forbidden_pending_human_visual_veto"`; max unhostable 1 | `existing_wild_atlas_context_validation.gd` |
| Z matrix | ground/roads −20; decor −5; ambient −4; entities 5 | CONVENTIONS / world_map_validation EXPECTED_*_Z |
| Gameplay zoom | 0.38 | `GAMEPLAY_CAMERA_ZOOM` in render validation |
| Five shipped tree yaws | `WILD_TREE_REGIONS` five `Rect2`s | `world_obstacle_2d.gd` |

**Camp cell (derived, not a named const):** `floor((9950+14336)/2048) = 11`, `floor((2400+14336)/2048) = 8` → cell `(11, 8)` east-forest. [VERIFIED: arithmetic on live constants; biome rule col≥10 & row≤8 → FOREST]

**Do not quote as live without a gate run:** comment "461 obstacles"; ground-cover "3,245 clusters / 38,947 elements" (CLAUDE.md §16 — may lag). Audit may cite them as *comment/GDD figures* with that caveat.

### `STARTING_CAMP_POSITION` consumers (contract appendix for Phase 2)

Phase 1 does not move camp. Contract must list grep targets so Phase 2 cannot miss them:

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

[VERIFIED: grep `src/` and `tests/` this session]

### Current 8-route census (audit must copy)

[VERIFIED: `world_map_2d.gd` `_build_road_network`]

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

**Missing vs D-02:** camp dirt spur to `(9950, 2400)`.

### Contract section outline (executor must fill)

`docs/WORLD_MAP_REDESIGN_CONTRACT.md`:

1. **Banner** — Phase 1 docs-only; extents 14×14 / ±14,336 frozen; no `src/world/` in this milestone slice; `LAYOUT_VERSION`/`WORLD_BUILD_SEED` frozen
2. **Camp** — secluded Metsä (D-01); hero clearing + 3 satellites as furniture (D-03/D-04); dirt spur meets asphalt (D-02); free to slide inside Metsä (D-22); Amber Gold only dominant warm
3. **Natures** — Metsä canopy wall + sparse interior vs far wilderness empty (D-05–D-07); FIR-01 named not solved (D-08)
4. **Roads** — three 1× grades (D-20); asphalt = way-home (D-23); perimeter exists, not 30s; current 8-route table referenced from audit
5. **District jobs + topology** — Kaupunki choke, Ostari mall salvage, west yard, east unnamed graveyard, Metsä threat (D-13–D-17); seats **may rearrange** on the grid (D-21); sketch relative topology (named places + connections), **not** GDScript coordinates
6. **Five shout nouns** — camp Amber Gold; mall gate (gap-in-shell, D-18); west yard; city choke; Metsä threat weenie (D-09–D-12). East has no shout noun
7. **30s loop beats (order, all Metsä)** — camp → dirt spur → short asphalt read → Metsä threat weenie → teaching salvage pocket → threat → back (D-24). Ostari is 10-minute commute, not a 30s beat
8. **10-minute loop** — asphalt spine to Ostari through mall-gate gap; Ostari owns salvage density (D-17)
9. **Salvage / threat pockets** — jobs only (teaching near camp; Ostari 10-min; city/villages sparse). 87 IDs / 3–5 / one-unit frozen. No node coordinates
10. **Exclusion volumes** — camp clearing (`STARTING_CAMP_OPEN_RADIUS` 520 gameplay / scenery 1760 — **name both and which layer owns which**); satellite furniture inside bowl; landmark discs; road-edge (asphalt urban 480 vs forest dress 300 vs camp 1600). Presentation ≠ collision
11. **Way-home language** — follow asphalt to dirt spur; Amber Gold confirms; district weenies are local nouns; minimap hidden in proof frames (D-23)
12. **Capture cameras** — table below; specified not implemented
13. **Co-authorship / tripwires** — pocket 2 recorded; `MAXIMUM_UNHOSTABLE_POCKETS = 1`; wild non-tree forbidden; no nameplates; no second Amber Gold
14. **Phase 2 consumer list** — `STARTING_CAMP_POSITION` grep table; `WorldCompositionContract` is Phase 2, not this file's runtime
15. **Out of scope pointer** — FIR-01, SALV-01, fence projection, TINT-01, PLACE-01, Resource `.tres`

`docs/WORLD_MAP_AUDIT.md`:

1. Method (live `.gd` > CLAUDE.md > foundation)
2. Extents / seed / camp / cell
3. Biome seats as-is
4. Eight routes + missing spur
5. Density tables (640 / 1100 / 24 / 87)
6. Pocket vs obstacle overlaps (pocket 2)
7. 1× unreadables (fir stalk, wild-frame veto, fence/house projection, scatter-as-place)
8. Capture inventory (25 filenames, TIME class, current look-ats including hardcoded `CityScrapPile_00`)
9. Foundation drift table
10. What the contract must invent (spur, Metsä weenie, teaching pocket as a *place*, three-grade *look*)

### Capture camera IDs (specify in contract; do not add nodes)

Gameplay zoom class = 0.38 (`GAMEPLAY_CAMERA_ZOOM`). Way-home rows: **minimap hidden**. Prefer TIME-stable look-ats for silhouette claims.

| camera_id | Beat | HUD | TIME class | Phase that implements |
|-----------|------|-----|------------|------------------------|
| `cam_loop_01_camp_clearing` | Hero bowl + Amber Gold + 3 satellites | optional | noisy (camp lights) — judge silhouette, not pixel diffs | 7 |
| `cam_loop_02_dirt_spur` | Readable camp exit | optional | prefer stable verge | 7 |
| `cam_loop_03_asphalt_read` | Short spine segment on 30s circuit | optional | `central_road_shoulder` class | 7 |
| `cam_loop_04_metsa_threat_weenie` | 30s named landmark (D-12) | optional | `forest_density` class if treed | 7 |
| `cam_loop_05_teaching_salvage` | Nearby pocket, not Ostari | optional | noisy if nodes pulse | 7 |
| `cam_loop_06_threat_approach` | Threat beat then return | optional | as weenie | 7 |
| `cam_home_from_kaupunki` | Way-home | **minimap hidden** | district | 7–8 |
| `cam_home_from_ostari` | Way-home via mall-gate then spine | **minimap hidden** | `mall` stable | 7–8 |
| `cam_home_from_west_kylat` | Way-home | **minimap hidden** | west village (night variant is noisy) | 7–8 |
| `cam_home_from_east_kylat` | Way-home; east unnamed | **minimap hidden** | `east_village` stable | 7–8 |
| `cam_job_kaupunki_choke` | District job DIST-01 | optional | `city_density` / `city_building_detail` | 7 |
| `cam_job_ostari_mall_gate` | Missing-tooth gap D-18 | optional | `mall` / `mall_long_shell` | 7 |
| `cam_job_west_yard` | Negative space + silhouette, not fence-as-hero | optional | west village | 7 |
| `cam_job_east_rest` | Unnamed graveyard quiet | optional | `east_village` | 7 |
| `cam_job_metsa_canopy_wall` | Forest threat job; FIR-01 named | optional | **`forest_density` only** | 7 |

Do not retarget `CityScrapPile_00` / `CityVehicleWreck_02` as loop proof cameras — those are leftover authored scrap look-ats [VERIFIED: `world_render_validation.gd` `CITY_SALVAGE_POSITION`].

### Git proof of zero layout edits

```text
# Phase gate (docs-only). Must print nothing:
git diff --name-only -- src/world/
git diff --name-only -- src/world/ src/ai/flow_field_navigation_2d.gd

# Allowed: docs/*.md, .planning/phases/01-*/**
# Forbidden even if "just comments": world_map_2d.gd, world_road_network_2d.gd,
# world_obstacle_2d.gd, world_*_2d.gd, resource_scatter_2d.gd,
# tests/world_render_validation.gd camera lists (Phase 7)
```

Also grep the Phase 1 diff for `LAYOUT_VERSION`, `WORLD_BUILD_SEED`, `TOTAL_SCENERY_COUNT`, `WILD_TREE_REGIONS`, `WILDERNESS_POCKETS` — must be unchanged in `.gd` files.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Seeded biome cells + 84-sector scatter as "the map" | Authored skeleton from a written contract, dress as texture inside envelopes | This milestone; Phase 1 writes the contract | Core value: places not oatmeal |
| Compass seats treated as frozen | D-21: districts may slide on locked 14×14 | 2026-09-19 CONTEXT | Contract sketches topology, not pixel GDScript |
| Foundation.md as count source | Live `.gd` + CLAUDE.md | Recorded 2026-09-18 CONCERNS | Audit method |
| Capture cameras on `CityScrapPile_00` | Named loop/way-home IDs | Phase 7 consumes Phase 1 table | Headless 169 cannot prove "named landmark" |
| Combined visual AAA+ with layout in one commit | Audit → skeleton → roads → jobs → pockets → set pieces → cameras → 1× verdict → lift | ROADMAP 1–9 | Lift-last so captures remain evidence |

**Deprecated/outdated:**
- Treating `docs/WORLD_MAP_FOUNDATION.md` scenery 576 / captures 23 / gate 150 as live
- `WorldCompositionContract` in Phase 1 (deferred to Phase 2)
- Promoting `polyhaven_salvage` or non-tree wild frames
- Minimap-as-compass as a done check
- Web-app walking skeleton for GSD Phase 01 here

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Ground-cover 3,245 / 38,947 not re-counted from `.gd` this session (constants are min/max 1400–9000) | Live constants | Audit over-precise on cover; cite as GDD figure or omit |
| A2 | On-disk `artifacts/world_*` pixels match current camp — **not verified** this session | Pitfall 9 | Audit must inventory filenames, not claim pixel proof |
| A3 | Historical comment "461 obstacles" is not a gate-pinned live count | Pitfall 5 | Do not put 461 in the audit as canonical without a headless run |

**If this table is empty:** N/A — three assumed/unverified items above. All locked CONTEXT decisions are user-confirmed, not assumed.

## Open Questions

1. **Exact Metsä threat-weenie silhouette language**
   - What we know: D-10 silhouette-first; D-12 it is the 30s named landmark; Phase 6 owns unique set pieces; no atlas frame pick now.
   - What's unclear: fallen-tower vs rock-arch vs wreck-mass — CONTEXT left silhouette family as "forest threat" without a prop.
   - Recommendation: Contract names **job + scale** ("one colliding Metsä mass readable at 0.38, not Amber Gold, not a tree stamp"). Do not pick `VisualKind` or atlas `Rect2` in Phase 1.

2. **Where the dirt spur meets asphalt (coordinates)**
   - What we know: spur is required (D-02); camp may slide inside Metsä (D-22); current nearest road is not a spur.
   - What's unclear: exact join cell — depends on Phase 2 camp seat.
   - Recommendation: Contract uses relative language ("spur from clearing bowl to nearest asphalt spine, length short enough that 30s loop is a circuit"). No GDScript `Vector2` for the new spur in Phase 1.

3. **Whether to run Godot 25-capture in Phase 1**
   - What we know: CONTEXT D-26 says quote current capture set; additional_context says prefer constants + filenames over GPU.
   - What's unclear: on-disk PNG freshness vs `(9950, 2400)`.
   - Recommendation: **Do not re-run.** Inventory filenames + TIME class. If planner wants pixel proof, that is Phase 7.

## Environment Availability

Step 2.6: **SKIPPED** (no external dependencies required to write markdown quoting live constants).

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Godot 4.7.1 | Not required this phase | — | `C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64.exe` if later | Quote `.gd` + existing capture names |
| npm / pip packages | none | n/a | — | — |

**Missing dependencies with no fallback:** none
**Missing dependencies with fallback:** none

## Validation Architecture

`workflow.nyquist_validation` is **true** in `.planning/config.json` [VERIFIED: `.planning/config.json`].

This is a **docs-only** phase. There is no GUT/Jest. Do not add a test framework. Nyquist samples **document completeness + git path filter**, not SceneTree asserts.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None new. Existing Godot `--headless --script` gates stay **unrun** as a Phase 1 requirement (they prove the *old* map). Proof of CONT-01 is markdown + git |
| Config file | none — see Wave 0 |
| Quick run command | `git diff --name-only -- src/world/` (must be empty) plus heading grep on the two docs |
| Full suite command | Same + confirm `LAYOUT_VERSION` / `WORLD_BUILD_SEED` / `TOTAL_SCENERY_COUNT` unchanged in `.gd` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CONT-01 | Audit markdown exists and quotes live constants (640, 25, 87, camp, seed, pocket 2) | smoke (docs) | grep files for `TOTAL_SCENERY_COUNT`, `9950`, `0xB35E7E`, `OstariSouthShell`, `forbidden_pending_human_visual_veto` | ❌ Wave 0 — `docs/WORLD_MAP_AUDIT.md` |
| CONT-01 | Contract names camp, 3 road grades, 4 district jobs, 5 shout nouns, 30s beats, way-home, exclusions, cameras | smoke (docs) | grep `docs/WORLD_MAP_REDESIGN_CONTRACT.md` for section headings listed in Pattern outline | ❌ Wave 0 — contract file |
| CONT-01 | Zero world-authoring code | smoke (git) | `git diff --name-only -- src/world/` empty; no new atlas regions | ✅ git (no new test file) |
| CONT-01 | Cameras specified not implemented | manual-only | Diff must not include `tests/world_render_validation.gd` | — justification: implementing cameras is Phase 7 (PROOF-02) |
| CONT-01 | Reviewer can read 30s loop without labels | manual-only | Human read of contract beats vs D-24 | — no capture retarget this phase |

### Sampling Rate

- **Per task commit:** `git diff --name-only -- src/world/` + files exist under `docs/`
- **Per wave merge:** heading checklist vs CONTEXT D-25–D-27
- **Phase gate:** path filter empty; both docs present; live-constant table matches this RESEARCH.md census; `LAYOUT_VERSION` still 2 in `resource_scatter_2d.gd`

### Wave 0 Gaps

- [ ] `docs/WORLD_MAP_AUDIT.md` — covers CONT-01 census
- [ ] `docs/WORLD_MAP_REDESIGN_CONTRACT.md` — covers CONT-01 named anatomy
- [ ] No framework install
- [ ] Do **not** create `tests/map_contract_validation.gd` that instantiates `BesprenWorldMap2D` — that is layout-adjacent and out of Phase 1
- [ ] Optional executor helper (not a Godot gate): a short heading-presence grep in the plan's verification block

*(Existing `tests/world_map_validation.gd` / `world_render_validation.tscn` cover the current map, not the unwritten contract. They are evidence sources for the audit, not Phase 1 deliverables.)*

## Security Domain

`security_enforcement` enabled, ASVS L1, `block_on` high [VERIFIED: `.planning/config.json`]. Honest assessment: this phase writes public game-design markdown. No auth, sessions, or crypto.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No accounts. LAN Join types an address; not in Phase 1 |
| V3 Session Management | no | ENet / OfflineMultiplayerPeer unchanged |
| V4 Access Control | no | Peer-one authority unchanged; docs cannot grant RPC |
| V5 Input Validation | no* | No new trust boundary. *Do not paste secrets into `docs/`* |
| V6 Cryptography | no | `encrypt_pck=false` is existing export; do not "fix" in a map-docs phase |
| V1 Architecture | yes (process) | Threat is **shipping layout code / atlas promotion** disguised as docs — git path filter is the control |

### Known Threat Patterns for docs-only Godot map phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Accidental `src/world/` layout commit | Tampering | `git diff --name-only -- src/world/` must be empty; plan tasks write only `docs/` |
| Promoting forbidden wild / salvage frames via "audit recommendation" | Elevation of privilege (content) | Contract restates `runtime_promotion` veto; no new `Rect2` in `src/world/` |
| Copying vault paths / licenses incorrectly into docs | Information disclosure (compliance) | Do not dump `Addons/` listings; no destructive vault cleanup |
| Treating UDP 8791 as internet-ready in the contract | Spoofing | Contract must not expand LAN threat model; CONCERNS.md: trusted-LAN only |
| Secrets in markdown | Information disclosure | None expected; do not invent `.env` examples |

No high ASVS findings that block planning. Do not add auth libraries.

## Project Constraints (from CLAUDE.md)

Treat as locked alongside CONTEXT.md.

- Godot 4.7.1 Mobile / Vulkan; typed GDScript; **no autoloads**
- Logical viewport **480×270** landscape, `canvas_items` stretch; readability at **1×**
- World **14×14**, cell 2048, extents **±14,336** — do not shrink or grow
- One full-screen custom pass (`weather_overlay`); **HDR 2D off**; **zero** shadow-casting 2D lights; **zero** dynamic shader loops
- Runtime art = 2D PNG/atlas only; **no** GLTF / mesh / PBR / `Node3D`
- Presentation **never writes** simulation (collision, flow, gather, RPC)
- Deterministic world build; visual density uses **offset salts**, not a second RNG story
- Base Core is the **only dominant Amber Gold**; identity redundant across hue / silhouette / iconography / placement
- **No world-space nameplates**
- Capture gate proves nothing until re-run; judge trees on TIME-stable `forest_density`
- `Addons/` — no destructive cleanup
- Do not promote wild non-tree frames
- `WorldObstacle2D` is the single obstacle record; sprites presentation-only
- Camp currently `(9950, 2400)` with 1600 road-edge clearance — Phase 1 may *plan* a Metsä move, must not *edit* the const
- Z matrix: ground/roads −20, rubble −5, ambient −4, gameplay 5

## Project skill patterns (research account)

Load only 2d-games, game-design, game-art, godot-gdscript-patterns, mobile-games. Do not load Unreal / Three.js.

- **2d-games:** Clarity over density; atlases; simplified collision; z-order. Contract names places a 480×270 camera can read, not tile-perfect painting.
- **game-design:** 30-second loop is spatial (camp → road → landmark → salvage → threat → back), not a seed. Phase 1 writes that loop; does not implement it.
- **game-art:** Inspect at 1×; silhouette before hue; do not pick atlas frames for weenies yet (Phase 6).
- **godot-gdscript-patterns:** No autoload; composition via `GameWorld`; Phase 2 Resource, not Phase 1 script.
- **mobile-games:** 44×44 already shipping; Phase 1 does not retune HUD. Thermal/device out of milestone.

## Sources

### Primary (HIGH confidence)

- `.planning/phases/01-map-audit-redesign-contract/01-CONTEXT.md` — locked D-01–D-28
- `src/world/world_map_2d.gd` — extents, camp, seed, biome seats, 8 routes, mall shell, satellites
- `src/world/world_road_network_2d.gd` — asphalt/dirt widths
- `src/world/world_obstacle_2d.gd` — VisualKind, `WILD_TREE_REGIONS`
- `src/world/world_ambient_scenery_2d.gd` — 640, pockets including wilderness[2]
- `src/world/world_wilderness_accent_2d.gd` — duplicated `WILDERNESS_POCKETS`, 24 anchors
- `src/world/world_background_decor_2d.gd` — 1100, duplicate `CAMP_POSITION`
- `src/world/resource_scatter_2d.gd` — 87, layout v2, teaching offsets
- `tests/world_map_validation.gd` — expected camp/satellites/scenery 640; route count 8; stale "576" string
- `tests/world_render_validation.gd` — 25 captures, look-ats, zoom 0.38
- `tests/existing_wild_atlas_context_validation.gd` — unhostable cap 1, promotion veto
- `CLAUDE.md` §§8, 10, 11, 12, 16 — palette, budgets, gates, tactical world
- `.planning/REQUIREMENTS.md` CONT-01; `.planning/ROADMAP.md` Phase 1 success criteria
- `.planning/research/SUMMARY.md` — oatmeal pitfall, Phase 1 docs-only
- `.planning/codebase/CONCERNS.md` — pocket 2, TIME noise, foundation drift
- `.planning/codebase/TESTING.md` — 169 / 25 / 207 gates
- `.planning/config.json` — nyquist true, security ASVS L1

### Secondary (MEDIUM confidence)

- `.planning/codebase/ARCHITECTURE.md` — Phase 2 Resource consumption (not built)
- `docs/WORLD_MAP_FOUNDATION.md` — spatial intent; **counts stale**
- Game-design 30s-loop skill (community skill text) — aligned with LOOP-01 already in REQUIREMENTS

### Tertiary (LOW confidence)

- Ground-cover exact cluster counts from CLAUDE.md §16 without reading a live getter this session
- On-disk capture pixel freshness vs camp const

**Graph:** `.planning/graphs/graph.json` absent — continued without graphify.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — keep-runtime, zero installs, docs path confirmed in CONTEXT D-25
- Architecture: HIGH — two-file docs vs forbidden `src/world/`; Phase 2 Resource explicitly deferred
- Pitfalls: HIGH — in-repo failure modes (stale foundation, TIME noise, pocket 2, missing spur) verified by read

**Research date:** 2026-09-19
**Valid until:** 30 days (docs/process; live constants drift only if someone edits `src/world/` — which Phase 1 forbids)
