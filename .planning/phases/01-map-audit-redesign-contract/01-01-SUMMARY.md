---
phase: 01-map-audit-redesign-contract
plan: 01
subsystem: map-docs
tags: [godot, world-map, census, CONT-01, docs-only]

requires:
  - phase: 01-map-audit-redesign-contract
    provides: Locked CONTEXT decisions D-01–D-28 and RESEARCH live-constant table
provides:
  - Live 14×14 census in docs/WORLD_MAP_AUDIT.md
  - Quoted GRID_SIZE 14, WORLD_BUILD_SEED 0xB35E7E, camp (9950, 2400)
  - Eight-route table with no camp dirt spur today
  - TOTAL_SCENERY_COUNT 640, RESOURCE_COUNT 87, capture_count 25
  - OstariSouthShell vs wilderness pocket 2 recorded, not moved
  - Empty src/world/ path filter (D-28)
affects:
  - 01-02 redesign contract
  - Phase 2 authored skeleton

tech-stack:
  added: []
  patterns:
    - Live-constant citation from src/world/*.gd and tests/*validation*.gd
    - Two-file current vs target (audit now; contract in plan 02)
    - Filename inventory is not pixel proof

key-files:
  created:
    - docs/WORLD_MAP_AUDIT.md
  modified: []

key-decisions:
  - "Audit quotes live .gd constants; docs/WORLD_MAP_FOUNDATION.md 576/23/150 are drift, not rewritten"
  - "No camp dirt spur exists today; D-02 remains a contract invention"
  - "Wilderness pocket 2 vs OstariSouthShell recorded; MAXIMUM_UNHOSTABLE_POCKETS stays 1"
  - "runtime_promotion = forbidden_pending_human_visual_veto restated; no wild non-tree Rect2 copied into src"
  - "LAYOUT_VERSION 2 and WORLD_BUILD_SEED 0xB35E7E frozen this plan"

patterns-established:
  - "Census tables name the const, the value, and the source path (D-26)"
  - "Comment figures (461 obstacles, ground-cover 3245/38947) stay comments unless a live gate pins them"
  - "Tree/canopy claims use forest_density; camp frames are TIME-noisy"

requirements-completed: [CONT-01]

coverage:
  - id: D1
    description: Live 14×14 census in docs/WORLD_MAP_AUDIT.md quoting current constants (640 scenery, 25 captures, 87 IDs, camp 9950,2400, seed 0xB35E7E, pocket 2 under OstariSouthShell)
    requirement: CONT-01
    verification:
      - kind: other
        ref: node token check AUDIT SPATIAL OK (Method, extents, eight routes, 0xB35E7E, 9950, no camp spur today)
        status: pass
      - kind: other
        ref: node token check AUDIT CENSUS OK (TOTAL_SCENERY_COUNT 640, OstariSouthShell, forbidden_pending_human_visual_veto, MAXIMUM_UNHOSTABLE_POCKETS, forest_density, CityScrapPile_00, drift 576)
        status: pass
      - kind: other
        ref: git diff --name-only -- src/world/ empty
        status: pass
    human_judgment: false

duration: 6min
completed: 2026-09-19
status: complete
---

# Phase 1 Plan 1: Live 14×14 Census Summary

**docs/WORLD_MAP_AUDIT.md quotes live 14×14 constants (seed 0xB35E7E, camp (9950, 2400), scenery 640, 87 IDs, 25 captures, pocket 2 under OstariSouthShell) with zero src/world/ edits**

## Performance

- **Duration:** 6 min
- **Started:** 2026-09-19T21:34:05Z
- **Completed:** 2026-09-19T21:40:03Z
- **Tasks:** 2/2
- **Files modified:** 1 created (`docs/WORLD_MAP_AUDIT.md`)

## Accomplishments

- Reviewer can census the current map from `docs/WORLD_MAP_AUDIT.md` without trusting stale foundation prose.
- Eight existing routes documented; **no camp spur today**; D-02 named as target, not as live polyline.
- Pocket-2 / `OstariSouthShell` overlap recorded; FIR-01 and fence/house mismatch named not solved; wild-atlas veto restated.
- `git diff --name-only -- src/world/` empty after both tasks.

## Task Commits

Each task was committed atomically:

1. **Task 1: Write audit method, spatial lock, biomes, and eight routes** - `2c4b331` (docs)
2. **Task 2: Fill density, pocket-2 overlap, unreadables, captures, drift** - `c3334f8` (docs)

**Plan metadata:** pending `docs(01-01): complete live 14x14 census plan`

## Files Created/Modified

- `docs/WORLD_MAP_AUDIT.md` — CONT-01 audit half: method, extents/seed/camp, biome seats, eight routes, density, pocket-2, 1× unreadables, 25-capture TIME class, foundation drift, contract inventions

## Decisions Made

- Audit is grep of live identifiers in `src/world/` and `tests/`; GPU and headless world-map gates were not re-run.
- Foundation scenery 576 / captures 23 / gate 150 stay in a drift table; `WORLD_MAP_FOUNDATION.md` was not rewritten.
- Duplicate `WorldBackgroundDecor2D.CAMP_POSITION = Vector2(9950, 2400)` called out as a Phase 2 grep trap.
- Filename inventory is not pixel proof; on-disk `artifacts/world_*` freshness versus camp was not verified this session.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 02 can lock `docs/WORLD_MAP_REDESIGN_CONTRACT.md` against this census (dirt spur, Metsä threat weenie, teaching salvage pocket as a place, three-grade visual look).
- Do not treat this audit as composition data. Do not edit `src/world/` until Phase 2 consumes the contract.

## Self-Check: PASSED

- FOUND: `docs/WORLD_MAP_AUDIT.md`
- FOUND: commit `2c4b331`
- FOUND: commit `c3334f8`
- FOUND: `git diff --name-only -- src/world/` empty

---
*Phase: 01-map-audit-redesign-contract*
*Completed: 2026-09-19*
