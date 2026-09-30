# Phase 1: Map Audit + Redesign Contract - Context

**Gathered:** 2026-09-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 1 delivers a live audit of the current 14×14 map plus a written redesign contract in `docs/`. Zero world-authoring code. No `src/world/` layout edits, no new atlas regions in `src/world/`, no scenery/cover/resource count changes.

The contract must name: camp, roads, district jobs, landmarks, salvage/threat pockets, 30s-loop beats, way-home language that is not the minimap, exclusion volumes, and capture cameras that will prove the loop.

The audit must quote live counts (code + current captures), not stale foundation docs.

CONT-01 only. CONT-02 (moving camp/roads/obstacles/resources) is Phase 2. Extents stay 14×14 / ±14,336.

</domain>

<decisions>
## Implementation Decisions

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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Product / phase lock
- `.planning/PROJECT.md` — milestone vision, locked extents, audit-then-build, done = 1× named places + way-home without minimap
- `.planning/REQUIREMENTS.md` — CONT-01 is this phase; CONT-02+ later; out-of-scope table (no nameplates, no wild non-tree promotion, no world-authoring code before contract)
- `.planning/ROADMAP.md` — Phase 1 success criteria (contract names, live audit, zero `src/world/` layout edits)
- `.planning/STATE.md` — Phase 1 is docs-only; CONT-02 in Phase 2; FIR-01 / SALV-01 deferred

### Living GDD and map contract
- `CLAUDE.md` — product contract; §8 palette (camp Amber Gold only dominant warm); §11 identity redundancy; §16 tactical world (14×14, camp `(9950, 2400)`, Z matrix, 87-node scatter)
- `docs/WORLD_MAP_FOUNDATION.md` — coordinate/layering/network docs; treat as possibly stale on counts; live `.gd` + CLAUDE.md win
- `docs/WORLD_MAP_VISUAL_PRODUCTION_PLAN.md` — prior visual production notes; do not override this CONTEXT

### Research already done
- `.planning/research/SUMMARY.md` — authored skeleton vs seeded scatter; typed `WorldCompositionContract` Resource is Phase 2 stack gap, not Phase 1
- `.planning/codebase/CONCERNS.md` — pocket 2 unhostable, capture TIME noise, fir stalk, wild-frame veto, presentation vs collision
- `.planning/codebase/CONVENTIONS.md` — presentation vs authority; atlas `Rect2` derivation; no autoloads
- `.planning/codebase/STRUCTURE.md` — `src/world/` ownership; `docs/` as deliverable location

### Live code the audit must quote (read, do not edit in Phase 1)
- `src/world/world_map_2d.gd` — `WORLD_BUILD_SEED`, `STARTING_CAMP_POSITION`, extents, district builders, broadphase
- `src/world/world_road_network_2d.gd` — authored asphalt/dirt graph
- `src/world/world_obstacle_2d.gd` — VisualKind, wild tree regions, fence visuals
- `src/world/world_ambient_scenery_2d.gd` — pocket tables including wilderness pocket 2
- `src/world/world_wilderness_accent_2d.gd` — duplicated wilderness pocket table
- `src/world/resource_scatter_2d.gd` — 87 IDs, layout version, sector scatter
- `tests/world_map_validation.gd` — live world-map gate counts
- `tests/world_render_validation.tscn` / `tests/world_render_validation.gd` — 25-capture GPU set
- `tests/existing_wild_atlas_context_validation.gd` — unhostable pocket tripwire, promotion veto

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `docs/` — Phase 1 writes here. No new `src/world/` files.
- `BesprenWorldMap2D` (`src/world/world_map_2d.gd`) — sole later consumer of composition data. Phase 1 specifies what the contract contains; Phase 2 introduces the Resource.
- `WorldRoadNetwork2D` — existing polyline graph; contract names hierarchy (asphalt / dirt / perimeter), not a new road class.
- `WorldObstacle2D` — one obstacle type. New landmarks later add `VisualKind` + atlas crop, never a second obstacle class. Phase 1 only names the weenies.
- Capture scenes under `tests/world_render_validation.tscn` — contract lists cameras; Phase 7 retargets them.

### Established Patterns
- Presentation vs authority: sprites do not write collision/flow. Contract must keep that split when naming exclusion volumes.
- Deterministic seed: visual density uses offset salts. Phase 1 must not invent a second RNG story.
- Pocket tables and obstacle tables authored separately is a known failure (pocket 2). Contract requires co-authorship from Phase 5; Phase 1 records the overlap.
- Capture noise floor: two identical runs before attributing diffs. Contract cameras should prefer TIME-stable frames for tree/landmark claims (`forest_density` class).
- Stale docs: `docs/WORLD_MAP_FOUNDATION.md` scenery/capture counts lag live code. Audit must grep `.gd` constants.

### Integration Points
- Phase 1 does not integrate into GameWorld. Downstream Phase 2: `data/world/bespren_world_composition.tres` consumed by `BesprenWorldMap2D.ensure_built()`.
- Camp move (allowed inside Metsä) later touches every `STARTING_CAMP_POSITION` reader, including the world-render gate.
- Resource scatter later consumes contract positions; 87 IDs and gather rules stay. Phase 1 names pocket jobs, not node coordinates.

### Creative options
- Contract as one markdown file vs audit + contract pair — planner chooses; both under `docs/`.
- Weenie silhouette language is specified (gap-in-shell, yard, choke mass, forest threat) without picking atlas frames. Phase 6 owns unique set pieces.
- District rearrange is authorized; Phase 1 should sketch target seats in the contract (named places + relative topology), not pixel coordinates in GDScript.

</code_context>

<specifics>
## Specific Ideas

- 30s loop beats in order, all inside Metsä: camp (hero clearing) → dirt spur → short asphalt read → Metsä threat weenie → nearby teaching salvage pocket → threat → back.
- 10-minute loop: asphalt spine commute to Ostari mall salvage through the mall-gate gap.
- Co-op shout list is exactly five nouns. East graveyard is recognized as quiet, not named.
- Way-home: follow asphalt. Amber Gold confirms near camp. Hide minimap in way-home captures.
- Mall gate = missing tooth in the long shell, not a sign/mast glow.
- Camp furniture: three existing satellites stay in the clearing bowl.

</specifics>

<deferred>
## Deferred Ideas

- Extra stamps / more unique props — Phase 6 (SETP-01) and Phase 9 (VISL-01). Contract may name hero pieces and density rules only.
- FIR-01 fir canopy mass — geometry rebake, not this phase.
- SALV-01 salvage-atlas promotion — after hosted-pocket 1× veto.
- Fence vs house projection rebake — named in D-15; art later.
- TINT-01 drop `WILD_TREE_TINT` after pine rebake.
- PLACE-01 nested Theory of the Place after the primary path reads.
- Pocket 2 relocation / shell shrink — Phase 5 co-author, not Phase 1.
- WorldCompositionContract Resource + `.tres` — Phase 2.
- Android device / two-device LAN / deposit-inventory-progression — wrong milestone.

</deferred>

---

*Phase: 1-map-audit-redesign-contract*
*Context gathered: 2026-09-19*
