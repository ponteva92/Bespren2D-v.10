---
phase: 01-map-audit-redesign-contract
plan: 02
subsystem: map-docs
tags: [godot, world-map, redesign-contract, CONT-01, docs-only]

requires:
  - phase: 01-map-audit-redesign-contract
    provides: Live 14×14 census in docs/WORLD_MAP_AUDIT.md
provides:
  - Locked target anatomy in docs/WORLD_MAP_REDESIGN_CONTRACT.md
  - Camp job secluded Metsä + dirt spur + hero clearing (D-01–D-04, D-22)
  - Three road grades; five shout nouns; Metsä-only 30s beats
  - Exclusion volumes CampOpenGameplay through SatelliteFurnitureBowl
  - Fifteen named camera IDs specified not implemented (D-27)
  - Empty src/world/ path filter (D-28)
affects:
  - 01-03 CONT-01 proof
  - Phase 2 authored skeleton / WorldCompositionContract

tech-stack:
  added: []
  patterns:
    - Two-file current vs target (audit now; contract to-be)
    - Cameras specified as IDs; Phase 7 implements
    - Camp job locked; camp coordinates not frozen-at-pixel (D-22)

key-files:
  created:
    - docs/WORLD_MAP_REDESIGN_CONTRACT.md
  modified: []

key-decisions:
  - "Dirt spur is a Phase 2 route; contract uses relative language, no Vector2 join"
  - "Exactly five shout nouns; east village unnamed; mall gate is a missing-tooth gap"
  - "Fifteen camera IDs specified; tests/world_render_validation.gd untouched"
  - "WorldCompositionContract named as Phase 2 type; no .tres this plan"
  - "Duplicate WorldBackgroundDecor2D.CAMP_POSITION is a Phase 2 grep trap"

patterns-established:
  - "Contract analog voice: FOUNDATION freeze bullets + PRODUCTION_PLAN exclusion habit + AAA non-negotiables 1, 2, 4, 5"
  - "Landmark table has five rows; salvage pocket is a place not a weenie"
  - "Exclusion volumes name owner layer so dress radii never become WorldStatic"

requirements-completed: [CONT-01]

coverage:
  - id: D1
    description: Contract banner through 10-minute loop locks camp job, three road grades, district jobs, five shout nouns, Metsä-only 30s beats, and Ostari commute
    requirement: CONT-01
    verification:
      - kind: other
        ref: node token check CONTRACT CORE OK (Banner, Camp, Natures, Roads, District jobs, Five shout nouns, 30s loop beats, 10-minute loop, D-01, D-02, D-11, D-24, secluded Metsä, dirt spur, five nouns)
        status: pass
      - kind: other
        ref: git diff --name-only -- src/world/ empty
        status: pass
    human_judgment: false
  - id: D2
    description: Contract tail names exclusion volumes, way-home without minimap, fifteen camera IDs, pocket-2 tripwire, Phase 2 consumers including CAMP_POSITION, and out-of-scope list
    requirement: CONT-01
    verification:
      - kind: other
        ref: node token check CONTRACT TAIL OK (fifteen camera_ids, CampOpenGameplay, CampSceneryBowl, minimap hidden, WorldCompositionContract, CAMP_POSITION, OstariSouthShell, MAXIMUM_UNHOSTABLE_POCKETS)
        status: pass
      - kind: other
        ref: git diff --name-only -- src/world/ empty; tests/world_render_validation.gd and .tscn untouched
        status: pass
    human_judgment: false

duration: 3min
completed: 2026-09-19
status: complete
---

# Phase 1 Plan 2: Redesign Contract Summary

**docs/WORLD_MAP_REDESIGN_CONTRACT.md locks camp job, three road grades, five shout nouns, Metsä 30s beats, way-home without minimap, exclusion volumes, and fifteen specified camera IDs with zero src/world/ edits**

## Performance

- **Duration:** 3 min
- **Started:** 2026-09-19T21:49:31Z
- **Completed:** 2026-09-19T21:52:42Z
- **Tasks:** 2/2
- **Files modified:** 1 created (`docs/WORLD_MAP_REDESIGN_CONTRACT.md`)

## Accomplishments

- Reviewer can read locked target anatomy from `docs/WORLD_MAP_REDESIGN_CONTRACT.md` without opening `src/`.
- Camp stays secluded Metsä with a dirt-spur exit (audit: no spur today); hero clearing holds three satellites as furniture; camp may slide inside Metsä (D-22).
- Exactly five shout nouns; east village unnamed; mall gate is a missing-tooth gap; Metsä threat weenie is the 30s named landmark.
- Fifteen camera IDs specified (`cam_loop_01_camp_clearing` through `cam_job_metsa_canopy_wall`); world-render validation files untouched.
- `git diff --name-only -- src/world/` empty after both tasks.

## Task Commits

Each task was committed atomically:

1. **Task 1: Write contract banner through 10-minute loop** - `3dfcfb4` (docs)
2. **Task 2: Fill pockets, exclusions, way-home, cameras, consumers** - `29d3415` (docs)

**Plan metadata:** pending `docs(01-02): complete redesign contract plan`

## Files Created/Modified

- `docs/WORLD_MAP_REDESIGN_CONTRACT.md` — CONT-01 contract half: banner freeze, camp, natures, roads, district jobs, five shout nouns, 30s/10-minute loops, pockets, exclusion volumes, way-home, specified cameras, tripwires, Phase 2 consumers, out of scope

## Decisions Made

- Dirt spur is a Phase 2 route invention; relative language only (clearing bowl to nearest asphalt spine); no new `Vector2` join.
- Landmark table is five rows. Salvage pocket is a place, not a sixth shout noun.
- `WorldCompositionContract` is the Phase 2 Resource type name; this plan does not write `.tres`.
- Duplicate `WorldBackgroundDecor2D.CAMP_POSITION = Vector2(9950, 2400)` listed so Phase 2 grep does not miss it.
- Cameras are table IDs for Phase 7; leftover scrap look-ats are not loop-proof cameras.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 03 can proof CONT-01 against this contract (heading checklist, live-constant table, empty `src/world/` path filter).
- Phase 2 consumes this file as composition intent via `WorldCompositionContract`; do not treat audit coordinates as target seats.
- Do not implement capture cameras or edit `src/world/` until later phases.

## Self-Check: PASSED

- FOUND: `docs/WORLD_MAP_REDESIGN_CONTRACT.md`
- FOUND: commit `3dfcfb4`
- FOUND: commit `29d3415`
- FOUND: `git diff --name-only -- src/world/` empty
- FOUND: `git diff --name-only -- tests/world_render_validation.gd tests/world_render_validation.tscn` empty

---
*Phase: 01-map-audit-redesign-contract*
*Completed: 2026-09-19*
