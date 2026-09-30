---
phase: 1
slug: map-audit-redesign-contract
status: verified
nyquist_compliant: true
wave_0_complete: true
created: 2026-09-19
updated: 2026-09-20
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Docs-only CONT-01. No new test framework. Sample document completeness + git path filter.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None new. Existing Godot `--headless --script` gates stay **unrun** as a Phase 1 requirement (they prove the *old* map). Proof of CONT-01 is markdown + git |
| **Config file** | none — Wave 0 does not install a framework |
| **Quick run command** | `git diff --name-only -- src/world/` (must be empty) plus heading grep on the two docs |
| **Full suite command** | Same + confirm `LAYOUT_VERSION` / `WORLD_BUILD_SEED` / `TOTAL_SCENERY_COUNT` unchanged in `.gd` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `git diff --name-only -- src/world/` (must be empty) and confirm target `docs/` files exist
- **After every plan wave:** Heading checklist vs CONTEXT D-25–D-27 plus live-constant quotes
- **Before `/gsd-verify-work`:** Path filter empty; both docs present; live-constant table matches `01-RESEARCH.md` census; `LAYOUT_VERSION` still 2 in `src/world/resource_scatter_2d.gd`
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | CONT-01 | T-01-01 | No `src/world/` layout in the phase diff | smoke (git) | `git diff --name-only 388aeb0..HEAD -- src/world/` empty | ✅ git | ✅ green |
| 01-01-02 | 01 | 1 | CONT-01 | — | Audit quotes live constants (640 scenery, 25 captures, 87 IDs, camp, seed, pocket 2) | smoke (docs) | grep `docs/WORLD_MAP_AUDIT.md` for `TOTAL_SCENERY_COUNT`, `9950`, `0xB35E7E`, `OstariSouthShell`, `forbidden_pending_human_visual_veto` | ✅ docs | ✅ green |
| 01-02-01 | 02 | 2 | CONT-01 | T-01-02 | Contract names camp, 3 road grades, 4 district jobs, 5 shout nouns, 30s beats, way-home, exclusions, cameras | smoke (docs) | grep `docs/WORLD_MAP_REDESIGN_CONTRACT.md` for `cam_loop_01_camp_clearing` + heading checklist | ✅ docs | ✅ green |
| 01-02-02 | 02 | 2 | CONT-01 | T-01-01 | Cameras specified, not implemented | smoke (git) | Diff must not include `tests/world_render_validation.gd` / `src/world/` | ✅ git | ✅ green |
| 01-03-01 | 03 | 3 | CONT-01 | T-01-01 | Heading checklist + live-constant table vs RESEARCH | smoke (docs) | grep `docs/WORLD_MAP_PHASE1_PROOF.md` for `TOTAL_SCENERY_COUNT` 640 | ✅ docs | ✅ green |
| 01-03-02 | 03 | 3 | CONT-01 | T-01-01 | Empty `src/world/` path filter; `LAYOUT_VERSION` still 2 | smoke (git) | `LAYOUT_VERSION: int = 2` in `resource_scatter_2d.gd`; empty src/world diff | ✅ git | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `docs/WORLD_MAP_AUDIT.md` — covers CONT-01 census (created by Plan 01, not a test stub)
- [x] `docs/WORLD_MAP_REDESIGN_CONTRACT.md` — covers CONT-01 named anatomy (created by Plan 02)
- [x] No framework install
- [x] Do **not** create `tests/map_contract_validation.gd` that instantiates `BesprenWorldMap2D`

Existing `tests/world_map_validation.gd` / `tests/world_render_validation.tscn` cover the current map, not the unwritten contract. They are evidence sources for the audit, not Phase 1 deliverables.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Cameras specified not implemented | CONT-01 | Implementing cameras is Phase 7 (PROOF-02) | Confirm phase diff excludes `tests/world_render_validation.gd` and no new capture scene |
| Reviewer can read 30s loop without labels | CONT-01 | No capture retarget this phase | Human read of contract beats vs CONTEXT D-24 |
| 1× unreadables named from current captures | CONT-01 | Pixel judgment, not a SceneTree assert | Audit lists unreadables from existing capture filenames; do not re-run GPU |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify (git path filter + heading/constant grep) or Wave 0 doc deliverables
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers missing docs (the two markdown files), not a new test framework
- [x] No watch-mode flags
- [x] Feedback latency < 5s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** verified 2026-09-20 (UAT pass + live git/docs greps)

## Validation Audit 2026-09-20

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 6 tasks marked green |
| Escalated | 0 |

CONT-01 coverage is markdown + git, not a new Godot gate. Human stranger-read closed in `01-UAT.md`. No `tests/map_contract_validation.gd`.
