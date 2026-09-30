---
phase: 01-map-audit-redesign-contract
verified: 2026-09-19T22:18:35Z
status: passed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
human_verification:

  - test: Open docs/WORLD_MAP_AUDIT.md and docs/WORLD_MAP_REDESIGN_CONTRACT.md. Census the current 14×14 map from the audit (camp, seed, eight routes, no spur today, 640/87/25, pocket 2). Then read the locked 30s Metsä loop and the five shout nouns from the contract without opening src/.
    expected: A stranger can name camp (9950, 2400), seed 0xB35E7E, eight routes with no camp dirt spur, OstariSouthShell vs pocket 2, then point the six Metsä 30s beats and the five shout nouns (Amber Gold, mall gate, west yard, city choke, Metsä threat weenie) with east unnamed. Proof file git path filter matches empty src/world/ diff.
    why_human: Harvested from 01-03-PLAN.md Task 2 <human-check>. Token presence proves the sentences exist; it does not prove a stranger can use the two docs as a walking census without src/.
---

# Phase 1: Map Audit + Redesign Contract Verification Report

**Phase Goal:** Team has a written redesign contract for the 14×14 world, grounded in a live audit, before anyone edits world layout
**Verified:** 2026-09-19T22:18:35Z
**Status:** human_needed
**Re-verification:** No — initial verification

**MVP note:** ROADMAP marks this phase `mode: mvp` but the phase goal is not a User Story (`user-story.validate` → `valid: false`). PLAN 01–03 goals *are* valid reviewer stories (`As a map reviewer, I want to…`). User Flow Coverage below uses those PLAN stories. Do not treat the ROADMAP wording gap as a CONT-01 failure; `/gsd mvp-phase 1` can reformat the ROADMAP goal later.

## User Flow Coverage

User story (PLAN 01–03, CONT-01): As a map reviewer, I want to open a live 14×14 census and a locked redesign contract in `docs/`, then run the heading / live-constant / git path-filter proof, so that the contract is grounded in current constants before anyone edits world layout.

| Step | Expected | Evidence | Status |
|------|----------|----------|--------|
| Open audit | `docs/WORLD_MAP_AUDIT.md` exists with live census headings | File on disk, 229 lines; H2 Method through What the contract must invent | ✓ |
| Read live map | Extents, seed `0xB35E7E`, camp `(9950, 2400)`, eight routes, no spur today | Quoted from `src/world/world_map_2d.gd` / `world_road_network_2d.gd`; `_build_road_network` eight polylines; none at camp | ✓ |
| Read density / tripwire / unreadables | 640 scenery, 87 IDs, 25 captures, OstariSouthShell vs pocket 2, 1× unreadables | Live consts in `world_ambient_scenery_2d.gd`, `resource_scatter_2d.gd`, `tests/world_render_validation.gd`, `tests/existing_wild_atlas_context_validation.gd` | ✓ |
| Open contract | `docs/WORLD_MAP_REDESIGN_CONTRACT.md` names camp, roads, jobs, landmarks, pockets, 30s beats, way-home, exclusions, cameras | File on disk, 264 lines; 15 H2s; five shout nouns; 15 `camera_id`s | ✓ |
| Run proof | Heading checklists, live-constant table, empty `src/world/` path filter | `docs/WORLD_MAP_PHASE1_PROOF.md` 184 lines; `git diff 388aeb0..HEAD -- src/world/` empty | ✓ |
| Outcome | Written contract grounded in live audit; zero world-authoring this phase | Three docs + phase commit list docs-only; LAYOUT_VERSION 2 and seed frozen | ✓ |

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | ------- | ---------- | -------------- |
| 1 | Reviewer can open a `docs/` redesign contract that names camp, roads, district jobs, landmarks, salvage/threat pockets, 30s-loop beats, way-home language that is not the minimap, exclusion volumes, and capture cameras that will prove the loop | ✓ VERIFIED | `docs/WORLD_MAP_REDESIGN_CONTRACT.md`: Camp / Roads / District jobs / Five shout nouns / Salvage and threat pockets / 30s loop beats / Way-home language (`minimap hidden`) / Exclusion volumes (`CampOpenGameplay`…`SatelliteFurnitureBowl`) / Capture cameras (`cam_loop_01_camp_clearing` through `cam_job_metsa_canopy_wall`) |
| 2 | Reviewer can read an audit of the current map — captures, density, pocket/obstacle overlaps, 1× unreadables — quoting live counts, not stale foundation docs | ✓ VERIFIED | `docs/WORLD_MAP_AUDIT.md` quotes `TOTAL_SCENERY_COUNT` 640, forest 236, `RESOURCE_COUNT` 87, `capture_count` 25, `OstariSouthShell` `(4850, -3150)`, pocket 2 `Vector4(2600, -2200, 700, 620)`, `forbidden_pending_human_visual_veto`. Drift table names foundation 576/23/150 as stale. Live `.gd` matches. |
| 3 | Phase 1 diff contains no `src/world/` layout edits, no new atlas regions in `src/world/`, and no scenery/cover/resource count changes | ✓ VERIFIED | `git diff --name-only 388aeb0318e0f05784670dfb18a226428b818554 HEAD` is `.planning/**` + the three `docs/WORLD_MAP_*.md` only. `git log 388aeb0..HEAD -- src/world/` empty. Live still `TOTAL_SCENERY_COUNT = 640`, `RESOURCE_COUNT = 87`, five `WILD_TREE_REGIONS` Rect2s unchanged, `LAYOUT_VERSION: int = 2`, `WORLD_BUILD_SEED = 0xB35E7E`. |
| 4 | Cameras are specified as IDs; this phase does not add nodes to `tests/world_render_validation.gd` / `.tscn` | ✓ VERIFIED | Fifteen IDs only in contract + proof. Grep `cam_loop_01_camp_clearing` / `cam_job_metsa_canopy_wall` over `*.gd`/`*.tscn` = no matches. `git diff --name-only -- tests/world_render_validation.gd tests/world_render_validation.tscn` empty. |
| 5 | `LAYOUT_VERSION` stays 2 and `WORLD_BUILD_SEED` stays `0xB35E7E` (D-28) | ✓ VERIFIED | `src/world/resource_scatter_2d.gd` `const LAYOUT_VERSION: int = 2`. `src/world/world_map_2d.gd` `const WORLD_BUILD_SEED: int = 0xB35E7E`. |

**Score:** 5/5 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | ----------- | ------ | ------- |
| `docs/WORLD_MAP_AUDIT.md` | Live current-state census for CONT-01 | ✓ VERIFIED | Exists, 229 lines, contains `TOTAL_SCENERY_COUNT`. Ten required H2s. Wired: quotes live consts from `src/world/` and tests. |
| `docs/WORLD_MAP_REDESIGN_CONTRACT.md` | Locked target anatomy for CONT-01 | ✓ VERIFIED | Exists, 264 lines, contains `cam_loop_01_camp_clearing`. Fifteen H2s. Dirt spur named as Phase 2 target, not as live polyline. |
| `docs/WORLD_MAP_PHASE1_PROOF.md` | Runnable coverage proof for CONT-01 | ✓ VERIFIED | Exists, 184 lines, contains `TOTAL_SCENERY_COUNT`. Heading checklists, live-constant table, git path filter, D-01–D-28. |

`gsd-tools query verify.artifacts` on 01-01, 01-02, 01-03: all_passed true.

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | --- | --- | ------ | ------- |
| `docs/WORLD_MAP_AUDIT.md` | `src/world/world_map_2d.gd` | Quoted `STARTING_CAMP_POSITION` `WORLD_BUILD_SEED` `GRID_SIZE` `PLAYABLE_HALF_EXTENT` | ✓ WIRED | Pattern `0xB35E7E` in audit; live `GRID_SIZE = 14`, `PLAYABLE_HALF_EXTENT = 14336.0`, `STARTING_CAMP_POSITION = Vector2(9950.0, 2400.0)` |
| `docs/WORLD_MAP_AUDIT.md` | `tests/existing_wild_atlas_context_validation.gd` | Pocket 2 unhostable tripwire recorded not moved | ✓ WIRED | `OstariSouthShell` + `MAXIMUM_UNHOSTABLE_POCKETS = 1` + `forbidden_pending_human_visual_veto`; no new `Vector4` proposed |
| `docs/WORLD_MAP_REDESIGN_CONTRACT.md` | `docs/WORLD_MAP_AUDIT.md` | Eight-route table referenced; dirt spur is target | ✓ WIRED | Contract cites audit eight-route / `dirt_flags` `[0,0,0,0,1,1,1,1]`; spur is “Phase 2 invention” |
| `docs/WORLD_MAP_REDESIGN_CONTRACT.md` | `tests/world_render_validation.gd` | Camera IDs specified for Phase 7; not implemented (D-27) | ✓ WIRED | IDs in contract table only; validation scene/script untouched |
| `docs/WORLD_MAP_PHASE1_PROOF.md` | `docs/WORLD_MAP_AUDIT.md` | Live-constant rows match audit + RESEARCH | ✓ WIRED | Table rows 640 / 9950 / `0xB35E7E` / OstariSouthShell / veto all present in audit |
| `docs/WORLD_MAP_PHASE1_PROOF.md` | `docs/WORLD_MAP_REDESIGN_CONTRACT.md` | Camera ID and shout-noun checklist | ✓ WIRED | Fifteen IDs listed; D-11 five nouns; east has no shout noun |

`gsd-tools query verify.key-links` on all three plans: `all_verified: true`.

### Data-Flow Trace (Level 4)

Docs, not UI. “Data” = live constants quoted into the audit. Traced to `.gd`, not foundation 576/23/150.

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| `WORLD_MAP_AUDIT.md` extents | `GRID_SIZE` 14, `PLAYABLE_HALF_EXTENT` 14336.0, camp `(9950, 2400)`, seed `0xB35E7E` | `src/world/world_map_2d.gd` L14–22, L62 | Yes — typed consts | ✓ FLOWING |
| `WORLD_MAP_AUDIT.md` density | `TOTAL_SCENERY_COUNT` 640, zone `[96, 72, 48, 48, 236, 92, 48]`, `RESOURCE_COUNT` 87 | `world_ambient_scenery_2d.gd` L23/L57; `resource_scatter_2d.gd` L33 | Yes | ✓ FLOWING |
| `WORLD_MAP_AUDIT.md` pocket 2 | `OstariSouthShell` `(4850, -3150)` size `(6400, 1800)`; pocket `Vector4(2600, -2200, 700, 620)` index 2 | `world_map_2d.gd` `_build_mall` L545–549; `world_ambient_scenery_2d.gd` `WILDERNESS_POCKETS` L131–134 | Yes | ✓ FLOWING |
| `WORLD_MAP_AUDIT.md` captures | `capture_count` 25, zoom 0.38 | `tests/world_render_validation.gd` L63, L138 | Yes | ✓ FLOWING |
| `WORLD_MAP_AUDIT.md` duplicate camp | `WorldBackgroundDecor2D.CAMP_POSITION` | `world_background_decor_2d.gd` L11 `Vector2(9950.0, 2400.0)` | Yes | ✓ FLOWING |
| `WORLD_MAP_REDESIGN_CONTRACT.md` exclusions | CampOpenGameplay 520; CampSceneryBowl 1760; RoadEdgeUrban 480; RoadEdgeForest 300 | `STARTING_CAMP_OPEN_RADIUS`; `CAMP_CLEAR_RADIUS`; `ROAD_EDGE_CLEARANCE`; `FOREST_ROAD_EDGE_CLEARANCE` | Yes — live numbers restated as jobs | ✓ FLOWING |

### Behavioral Spot-Checks

Docs-only phase. No Godot (PLAN: do not run GPU / headless world-map gates). Spot-checks are token + git + live-const reads.

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Audit required tokens | node string includes (10 H2s, 640, `0xB35E7E`, OstariSouthShell, veto, no camp spur) | `AUDIT TOKENS OK` | ✓ PASS |
| Contract required tokens | node string includes (15 H2s, 15 camera_ids, five nouns, CampOpenGameplay) | `CONTRACT TOKENS OK` | ✓ PASS |
| Proof required tokens | node string includes (checklists, D-01/D-11/D-24/D-28, 640) | `PROOF TOKENS OK` | ✓ PASS |
| `src/world/` path filter vs baseline | `git diff --name-only 388aeb0 HEAD -- src/world/` | empty | ✓ PASS |
| World-render cameras unimplemented | grep camera IDs in `*.gd`/`*.tscn`; git diff on validation files | no matches; empty diff | ✓ PASS |
| LAYOUT_VERSION / seed freeze | read `resource_scatter_2d.gd` / `world_map_2d.gd` | `LAYOUT_VERSION: int = 2`; `WORLD_BUILD_SEED = 0xB35E7E` | ✓ PASS |
| Godot GPU / headless world map | — | Skipped per PLAN (would prove the old map) | ? SKIP |

### Probe Execution

| Probe | Command | Result | Status |
| ----- | ------- | ------ | ------ |
| — | — | No PLAN/SUMMARY probe scripts; not a migration phase | SKIP |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| CONT-01 | 01-01, 01-02, 01-03 | Audit current 14×14 map and write redesign contract in `docs/` with zero world-authoring code | ✓ SATISFIED | Three deliverable docs; live-constant quotes; empty `src/world/` phase diff; cameras specified not implemented |

Orphaned requirements mapped to Phase 1: none. REQUIREMENTS.md maps only CONT-01 here. CONT-02 / SKEL-01 belong to Phase 2.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| — | — | No `TBD` / `FIXME` / `XXX` in the three deliverables | — | — |
| `tests/world_map_validation.gd` | 654 | Stale English “exact 576” while `EXPECTED_AMBIENT_SCENERY_TOTAL = 640` | ℹ️ Info | Pre-existing; audit names it as drift, does not rewrite the gate |
| git index | — | `src/world/` is untracked (`git ls-files src/world/` empty), so working-tree `git diff -- src/world/` is vacuously empty | ℹ️ Info | Phase commits still docs-only; live consts prove no layout bump. Path filter vs `388aeb0..HEAD` is the real proof |

Prohibitions checked (no silent pass):

- No `src/world/` layout edits / atlas Rect2 / scenery-cover-resource count changes — held
- No `LAYOUT_VERSION` or `WORLD_BUILD_SEED` bump — held
- Do not implement capture cameras — held
- Do not promote wild non-tree frames — held (veto restated; five `WILD_TREE_REGIONS` unchanged)
- Do not scaffold `tests/map_contract_validation.gd` or a web app — held (file absent)
- Do not rewrite `docs/WORLD_MAP_FOUNDATION.md` — held (not in phase commit list)

### Human Verification Required

Harvested from `01-03-PLAN.md` Task 2 `<human-check>` (workflow.human_verify_mode = end-of-phase). Automated token/git checks passed; this item still needs a person.

### 1. Stranger census without `src/`

**Test:** Open `docs/WORLD_MAP_AUDIT.md` and `docs/WORLD_MAP_REDESIGN_CONTRACT.md`. Census the current 14×14 map from the audit. Read the locked 30s Metsä loop and the five shout nouns from the contract. Confirm `docs/WORLD_MAP_PHASE1_PROOF.md` git path filter matches an empty `src/world/` diff.
**Expected:** Stranger can name camp `(9950, 2400)`, seed `0xB35E7E`, eight routes with **no camp dirt spur**, OstariSouthShell vs wilderness pocket 2, then point the six Metsä 30s beats and five shout nouns (camp Amber Gold, mall gate, west yard, city choke, Metsä threat weenie) with east unnamed.
**Why human:** Grep proves the sentences exist. It does not prove a reviewer can walk the two docs as a census without opening `src/`.

### Gaps Summary

No must-have FAILED. Phase goal (written contract grounded in live audit, zero world-authoring) holds in the files. Status is `human_needed` solely because PLAN 03 deferred a stranger-read check to end-of-phase.

Inversion (ways this could still be wrong despite tokens):

1. Audit could quote live consts but invent a ninth route — **checked:** eight rows 0–7; `_build_road_network` has eight `PackedVector2Array`s; prose “Do not list a ninth route.”
2. Contract could freeze compass seats as GDScript cells against D-21 — **checked:** “Compass seats are **not** frozen”; relative topology table; no new camp `Vector2`.
3. “Empty `src/world/` diff” could be vacuous because `src/world/` is untracked — **mitigated:** phase commit list + live freeze consts + unchanged `WILD_TREE_REGIONS`; noted as Info, not a blocker.

Confirmation-bias counter: PLAN 01 SUMMARY claims `git diff --name-only -- src/world/` empty. That command is empty even if untracked files changed. Independent proof is `388aeb0..HEAD` file list (docs + `.planning` only) plus live `640` / `87` / five tree Rect2s.

---

_Verified: 2026-09-19T22:18:35Z_
_Verifier: Claude (gsd-verifier)_
