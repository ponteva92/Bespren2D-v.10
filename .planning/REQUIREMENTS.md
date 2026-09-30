# Requirements: Bespren Visual AAA+ & Map Redesign

**Defined:** 2026-09-18
**Core Value:** At 480×270, the world reads as authored places with a visible salvage loop — never as generated scatter on a grid.

## v1 Requirements

Requirements for this milestone. Each maps to roadmap phases.

### Map Contract

- [x] **CONT-01**: Team can audit the current 14×14 map (captures, density, pocket/obstacle overlaps, 1× unreadables) and write a redesign contract in `docs/` that names camp, roads, district jobs, landmarks, salvage/threat pockets, 30s-loop beats, way-home language, exclusion volumes, and capture cameras — with zero world-authoring code in that phase
- [ ] **CONT-02**: Playable extents stay 14×14 cells / ±14,336; camp, roads, obstacles, and resources may relocate to serve the contract

### Authored Skeleton

- [ ] **SKEL-01**: Player traverses an authored skeleton of paths, edges, districts, nodes, and landmarks stored as composition data — not biome cell IDs or seeded scatter
- [ ] **DIST-01**: Player can tell each district's job at 1× without a label: Kaupunki city choke, Ostari mall salvage, Kylät village quiet, Metsä forest threat
- [ ] **ROAD-01**: Player can read road hierarchy at 1× (asphalt spine vs dirt branch vs wilderness perimeter) as the loop's path, not only as polylines in code

### Loop and Readability

- [ ] **LOOP-01**: A stranger viewing 480×270 captures can point at the 30s loop in order: camp → readable road → named landmark → salvage pocket → threat → back
- [ ] **READ-01**: At 480×270 with no world-space labels, a stranger can point at camp, road, landmark, salvage pocket, and threat as named places
- [ ] **READ-02**: From any district, the way home is readable from roads, silhouettes, and the camp Amber Gold weenie with the minimap hidden

### Salvage and Set Pieces

- [ ] **SLVG-01**: The 87 resource IDs and 3–5 step gather rules stay; spawn positions serve authored salvage pockets instead of uniform 84-sector scatter
- [ ] **SETP-01**: Nodes and landmarks use unique hero set pieces; dress no longer reads as `index % 8` wallpaper; adjacent variety is constructed, not a per-instance coin
- [ ] **CAMP-01**: Camp reads as a clearing; negative space and landmark exclusion exist; pocket tables and obstacle tables are authored in the same change

### Visual Lift

- [ ] **VISL-01**: After the skeleton reads at 1×, every visual surface is lifted on that skeleton: terrain, props, foliage, structures, lighting, actors, camp, HUD, VFX, shaders — still on the 480×270 mobile bar, authored places plus unique set pieces

### Proof and Constraints

- [ ] **PROOF-01**: Presentation never writes simulation (collision, flow, gather, RPC stay canonical); headless world-map and smoke gates stay green after layout changes
- [ ] **PROOF-02**: World-render capture cameras sit on the 30s-loop beats; a noise floor is measured by two identical runs before attributing diffs; visual veto overrides a numeric pass

## v2 Requirements

Deferred. Tracked but not in current roadmap.

### Visual / Art

- **FIR-01**: Fir canopy reads as mass, not a stalk — geometry rebake measured on `forest_density`
- **SALV-01**: Salvage atlas frames dress mall/city pockets only after a hosted-pocket 1× visual veto
- **PLACE-01**: Nested Theory of the Place polish per district (antechamber, secondary routes) after the primary path already reads
- **TINT-01**: Drop or retune `WILD_TREE_TINT` after a pine rebake no longer AgX-tans

### Release / Later Slices

- **DEV-01**: Representative Android readability, frame time, thermals, touch/safe-area, lifecycle
- **LAN-01**: Physical two-device LAN tactical validation
- **MECH-01**: Base Core deposit, persistent inventory, long-term progression (wrong milestone)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| World-authoring code before the audit/contract | Repeats scatter with new seeds; Phase 1 is docs only |
| Shrinking or growing 14×14 extents | Locked playable world; shrink is fake authorship |
| New gameplay systems (deposit, inventory, progression, new combat) | Visual + map composition milestone, not a mechanics slice |
| Changing 480×270 or `canvas_items` stretch | Mobile clarity is the quality bar |
| Extra fullscreen custom passes / desktop post / glow stacks | Budget is one weather overlay |
| HDR 2D | Mobile bandwidth; RGBA16F |
| Runtime 3D / GLTF / mesh / PBR / Node3D | Runtime stays 2D atlases |
| Shadow-casting 2D lights | Foundation budget is zero |
| Promoting forbidden wild non-tree frames | 1× veto stands; five tree yaws only |
| World-space district nameplates | Admits silhouette failure |
| Minimap as the only way-home | Product requires the world to read |
| Destructive `Addons/` cleanup | Vault is provenance |
| Android device certification as this milestone's done | Separate release gate |

## User Stories

- As a player at 480×270, I want the world to look like named places so I know which district I am in without a label.
- As a scavenger, I want a 30-second run to read camp → road → landmark → salvage → threat → back so the loop is spatial, not a seed.
- As a co-op partner, I want landmarks I can call out ("mall gate", "west yard") so we share nouns without the minimap.
- As a player far from camp, I want the way home from roads, silhouettes, and Amber Gold so the HUD is confirmation, not the compass.

## Definition of Done

- Phase 1 diff contains no `src/world/` layout edits.
- 14×14 / ±14,336 extents unchanged.
- Loop, named-place, and way-home (HUD hidden) captures exist at 480×270 and pass a stranger-point review.
- 87 resource IDs and gather rules unchanged; positions match authored pockets.
- Smoke and world-map headless gates green; GPU capture set re-run after layout moves.
- One fullscreen pass, HDR 2D off, no runtime 3D, no shadow-casting 2D lights.

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CONT-01 | Phase 1 | Complete |
| CONT-02 | Phase 2 | Pending |
| SKEL-01 | Phase 2 | Pending |
| DIST-01 | Phase 4 | Pending |
| ROAD-01 | Phase 3 | Pending |
| LOOP-01 | Phase 8 | Pending |
| READ-01 | Phase 8 | Pending |
| READ-02 | Phase 8 | Pending |
| SLVG-01 | Phase 5 | Pending |
| SETP-01 | Phase 6 | Pending |
| CAMP-01 | Phase 5 | Pending |
| VISL-01 | Phase 9 | Pending |
| PROOF-01 | Phase 7 | Pending |
| PROOF-02 | Phase 7 | Pending |

**Coverage:**

- v1 requirements: 14 total
- Mapped to phases: 14
- Unmapped: 0

---
*Requirements defined: 2026-09-18*
*Last updated: 2026-09-19 after roadmap creation*
