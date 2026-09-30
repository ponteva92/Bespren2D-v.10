# Bespren Visual AAA+ & Map Redesign

## What This Is

A brownfield visual overhaul of Bespren, the existing Godot 4.7.1 Mobile LAN co-op survival slice. The product stays the same game — two scavengers, Base Core, salvage loop, 480×270 landscape — but every visual surface is lifted to hyper-premium AAA+ authored quality, and the largest piece of work is a full audit, analysis, discussion, plan, then redesign of the 14×14 world map.

Players should always know which district they are in. A 30-second salvage run should read as camp → readable road → named landmark → salvage pocket → threat → back, with each beat a place, not a seed.

## Core Value

At 480×270, the world reads as authored places with a visible salvage loop — never as generated scatter on a grid.

## Requirements

### Validated

- ✓ Character-select boot (Heikki / Shane) plus Solo / Host LAN / Join LAN — existing
- ✓ Host-authoritative ENet on UDP 8791 with `OfflineMultiplayerPeer` Solo fallback — existing
- ✓ 14×14 / 28,672-unit playable extents, WorldStatic collision, flow mask, 512-unit walkability broadphase — existing
- ✓ Deterministic 87-node resource scatter, 3–5 step gather, replicated pool — existing
- ✓ 450s day/night, horde, eight enemy presentations, auto-aim, projectiles — existing
- ✓ Eight Tier-1 structures, three towers, three traps, 64px placement, Base relocation — existing
- ✓ Compact HUD, minimap, build deck, mobile controls, single weather overlay — existing
- ✓ Offline Blender 5 → PNG/atlas pipeline; no runtime 3D — existing
- ✓ Headless smoke (207) and world-map (169) gates; 25-capture world render gate — existing

### Active

- [ ] Audit, analyze, discuss, and write a map redesign contract before world-authoring code
- [ ] Keep 14×14 / ±14,336 extents; re-author camp, roads, obstacles, resources, landmarks, density
- [ ] Replace seeded scatter with authored composition so districts have jobs: city choke, mall salvage, village quiet, forest threat
- [ ] Make the 30s loop visible in captures: camp → road → named landmark → salvage pocket → threat → back
- [ ] At 480×270, a stranger can point at camp, road, landmark, salvage, threat without a label
- [ ] From any district, the way home is readable from roads, silhouettes, and landmarks — not the minimap
- [ ] Lift every visual surface in this milestone: map, terrain, props, foliage, structures, lighting, actors, camp, HUD, VFX, shaders
- [ ] More unique set pieces, less atlas-stamp repetition, stronger district identity
- [ ] Preserve the mobile rendering contract: one full-screen pass, no HDR 2D, no runtime 3D, identity redundant across hue / silhouette / iconography / placement

### Out of Scope

- New gameplay systems (deposit, inventory, progression, new combat rules) — this milestone is visual + map composition, not a mechanics slice
- Changing 480×270 logical viewport or `canvas_items` stretch — mobile clarity is the quality bar
- Desktop-only post-processing, extra full-screen passes, HDR 2D, shadow-casting 2D lights — CLAUDE.md §10 budgets
- Shipping GLTF / mesh / PBR / Node3D — runtime stays 2D atlases
- Physical Android device certification and two-device LAN gate — still a later release gate
- Shrinking or growing playable extents — 14×14 stays
- Promoting non-tree wild atlas frames currently forbidden pending visual veto

## Context

Bespren is a living product with a dense GDD in `CLAUDE.md` and a fresh codebase map in `.planning/codebase/` (2026-09-18). The current world is deterministic from `WORLD_BUILD_SEED` (`0xB35E7E`): biome cells, eight authored road polylines, district obstacle builders, then independently seeded dress layers (background decor, ambient scenery, wilderness accents, ground cover). Collision and flow stay canonical; sprites are presentation-only.

The map fails three ways at once:

1. **Generated scatter** — world reads as seeded props on a grid, not an authored place with history, routes, and landmarks.
2. **District layout** — Kaupunki / Ostari / Kylät / Metsä exist, but pacing, choke points, and salvage routes are wrong.
3. **1× readability** — at 480×270, silhouettes, density, ground language, and landmark pull do not survive the viewport.

Camp, roads, obstacles, and resources are all free to re-author. Gameplay systems (authority, gather rules, towers/traps, horde) stay. Their world data does not.

Visual AAA+ here means authored places plus denser unique set pieces — not cinematic desktop lift. CLAUDE.md already records the measurement discipline this work must keep: gates that test inputs to compressive operators, captures judged against a noise floor, 1× review as a verdict, and "a metric that includes a feature drawn outside the subject is measuring that feature."

Map work is audit-then-build in this same project: the audit/plan is first and largest, then implementation in later phases. No separate milestone.

## Constraints

- **Tech stack**: Godot 4.7.1 Mobile / Vulkan, typed GDScript, no autoloads — existing architecture stays
- **Viewport**: 480×270 logical landscape, `canvas_items` stretch — readability judged at 1×
- **World size**: 14×14 cells, 2,048-unit cells, ±14,336 extents — locked
- **Rendering budget**: one full-screen custom pass, zero shadow-casting 2D lights, zero dynamic shader loops, HDR 2D off
- **Runtime art**: 2D PNG/atlas only; Blender 5 workshops remain offline
- **Authority**: peer-one host path, ENet 8791 / OfflineMultiplayerPeer — presentation must not write simulation
- **Determinism**: world build remains seed-stable; authored composition must still be reproducible
- **Validation**: headless gates + Mobile/Vulkan capture gates remain the proof; a capture gate proves nothing until re-run
- **Addons vault**: no destructive cleanup of `Addons/`

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Full visual AAA+ in this milestone, map still the largest work | User wants every visual surface lifted; map is the load-bearing failure | — Pending |
| Keep 14×14 extents; layout otherwise open | Same playable world, new composition. Camp/roads/obstacles/resources may move | — Pending |
| AAA+ = authored places + unique set pieces, still on the mobile bar | Not cinematic desktop lift; not a new resolution | — Pending |
| Audit/plan first, then implement in later phases of this project | Largest work is the redesign contract; no world-authoring code until it exists | — Pending |
| Done = 1× named places + way-home without minimap + 30s loop visible in captures | Observable, capture-gated, matches CLAUDE.md measurement culture | — Pending |
| Gameplay systems stay; world data may change | Visual/map milestone, not a mechanics rewrite | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-09-18 after initialization*
