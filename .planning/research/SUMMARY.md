# Project Research Summary

**Project:** Bespren Visual AAA+ & Map Redesign
**Domain:** Brownfield AAA+ 2D mobile authored-map composition (Godot 4.7.1 Mobile LAN co-op survival)
**Researched:** 2026-09-18
**Confidence:** HIGH

## Executive Summary

Bespren is a shipping Godot 4.7.1 Mobile LAN co-op survival slice. This milestone is **not** a new product and **not** a mechanics rewrite. Experts build premium 2D survival maps the way Don't Starve Together, Core Keeper, and They Are Billions do: an authored skeleton (districts with jobs, hierarchical paths, unique landmarks, salvage as pockets) with seeded dress only as texture inside those envelopes. Bespren already has the names (Kaupunki, Ostari, Kylät, Metsä), the 14×14 / ±14,336 extents, and the gameplay systems. It does not yet have that anatomy on the ground at 480×270. The core value is: **at 480×270 the world reads as authored places with a visible salvage loop — never as generated scatter on a grid.**

Keep the runtime stack. Godot 4.7.1 Mobile/Vulkan, 480×270 `canvas_items`, typed GDScript, ENet peer-one authority, Blender 5 offline atlas pipeline, one weather overlay, HDR 2D off, no runtime 3D. The only stack gap is **authored layout data**: a typed `WorldCompositionContract` Resource that `BesprenWorldMap2D.ensure_built()` consumes. Do not paint the 28,672-unit world as a TileMap. Do not add Tiled/LDtk at runtime. Do not replace seeded dress with more seeded dress.

The load-bearing risk is implementing before the contract — retuning `WORLD_BUILD_SEED` dress and calling it authorship (Kate Compton's oatmeal). Mitigate with a hard phase lock: **Phase 1 is audit + written redesign contract with zero world-authoring code.** Then skeleton. Then capture gates that a stranger can point at. Then visual lift of remaining surfaces **on that skeleton**. A prettier stamp grid is still a stamp grid.

## Key Findings

### Recommended Stack

See [STACK.md](STACK.md). Keep what ships. No new runtime packages, no engine bump, no renderer change.

**Core technologies:**
- **Godot 4.7.1 Mobile + Vulkan** (`4.7.1.stable.official.a13da4feb`) — shipping renderer. Mobile is tile-based R10G10B10A2. Forward+ is desktop. Do not enable HDR 2D (RGBA16F, ~2× bandwidth).
- **480×270 landscape + `canvas_items` stretch** — design size. Contours are logical (`fwidth` × stretch). Texture minification is physical-pixel. Do not raise resolution or switch to `viewport` stretch.
- **Typed GDScript 2.0** (`untyped_declaration=2`) — `class_name`, typed arrays, no autoloads.
- **Existing CanvasItem shader family** — `blend_mix`, `vec4 source = COLOR;` (never `texture * COLOR`), screen-space outlines, one `weather_overlay` fullscreen pass.
- **`WorldObstacle2D` + 512-unit broadphase + 112×112 flow mask** — canonical collision/nav. Sprites are presentation-only. Do not move collision onto TileSet.
- **Host-authoritative ENet UDP 8791 / `OfflineMultiplayerPeer`** — presentation never writes simulation. Layout version may bump; RPC surface does not.
- **Offline Blender 5.0 EEVEE → PNG/atlas** — unique set pieces. No GLTF/`Node3D` at runtime.
- **Typed Godot `Resource` composition contract (new, thin)** — the one real stack gap. Nested `class_name` Resources + `data/world/bespren_world_composition.tres`. Not JSON, not inner classes (they do not serialize), not an Autoload.

**Hard rejects:** HDR 2D, extra fullscreen passes, shadow-casting 2D lights, runtime 3D, shrinking/growing extents, new gameplay systems, Tiled/LDtk as runtime, Godot 4.8+/Forward+, promoting forbidden wild non-tree frames.

### Expected Features

See [FEATURES.md](FEATURES.md). This milestone is visual + map composition. If it is not in a 1× capture of the 30s loop, it is not v1.

**Must have (table stakes) — P1:**
- **Map audit + redesign contract** — first-class feature; blocks all world-authoring code
- **Keep 14×14 / ±14,336** — camp/roads/obstacles/resources may move; extents do not
- **Authored skeleton** — paths, edges, districts, nodes, landmarks (Lynch)
- **District jobs** — city choke, mall salvage, village quiet, forest threat
- **Visible 30s loop** — camp → readable road → named landmark → salvage pocket → threat → back
- **1× named places without labels** — squint / desaturate / stranger-point
- **Way home without minimap** — roads, silhouettes, camp Amber Gold weenie
- **Salvage as pockets** — 87 IDs and 3–5 step gather stay; positions serve places
- **Unique set pieces at nodes** — kill `index % 8` wallpaper; adjacent-difference by construction
- **Negative space + camp clearing + pocket/obstacle co-authored**
- **Presentation/authority split + determinism + world-map/smoke gates green**
- **Capture cameras retargeted; noise floor measured; visual veto in force**
- **Mobile rendering contract held**

**Should have (competitive) — P2, after skeleton reads:**
- Full visual lift of remaining surfaces (terrain, props, foliage, structures, lighting, actors, camp, HUD, VFX, shaders)
- Fir canopy mass rebake (geometry, not grade) on `forest_density`
- Nested Theory of the Place per district
- Lighting-responsive world / one weather pass polish
- HUD/VFX hierarchy lift (do not grow the dashboard)
- Salvage atlas pocket consumer — only after hosted-pocket 1× veto

**Defer (v2+ / later milestone):**
- Deposit / persistent inventory / progression — wrong milestone
- Android device + two-device LAN certification — release gate, not this done
- Water/wetland/burnt biomes — only if a later contract assigns a job
- Shadow-casting 2D lights / extra passes / HDR 2D
- Wild non-tree frame promotion
- Accessibility settings UI / Android lifecycle
- APK rebuild (needed before device install; not a map feature)

### Architecture Approach

See [ARCHITECTURE.md](ARCHITECTURE.md). Do **not** add a second world. Evolve `BesprenWorldMap2D`. GameWorld, CoopSession, and the peer-one path stay locked.

**Major components:**
1. **`WorldCompositionContract` (Resource)** — districts, named landmarks, routes, salvage pockets, camp, 87 resource IDs. Data only. No physics, no RPC, no draw. Saved as `data/world/bespren_world_composition.tres`.
2. **`BesprenWorldMap2D`** — sole builder. Reads the contract. Still owns biome grid, obstacle list, 512-unit broadphase, flow bake, walkability, `resolve_player_motion`. `ensure_built()` order stays.
3. **`WorldRoadNetwork2D`** — authored asphalt/dirt graph from contract routes. Unchanged API.
4. **`WorldObstacle2D`** — one collision + flow footprint. Atlas sprites presentation-only. New landmarks add `VisualKind` + atlas crop, never a second obstacle type.
5. **`BesprenResourceScatter2D`** — 87 IDs from contract positions, not 12×7 sector RNG. Bump `LAYOUT_VERSION`. Gather rules unchanged.
6. **Dress quartet** — independent salts `+91/+137/+173/+211`. Pockets from the contract or derived from obstacle/road bounds. Never a twin `WILDERNESS_POCKETS` table.
7. **Capture gates** — headless world-map 169 (counts/hashes) + GPU 25-capture scene (named places). Both required; neither substitutes.

**Key patterns:** Contract is input, builder remains authority. Pockets derived from layout. Dress seeds for micro-variation only. Capture gate is the composition done-check. No autoloads. No parallel `WorldComposer`. No presentation writing simulation.

### Critical Pitfalls

See [PITFALLS.md](PITFALLS.md). Top load-bearing failures:

1. **Implement before the map redesign contract** — first commit of the milestone must not edit `world_map_2d.gd` placement loops. Stop. Write the contract. Revert scatter diffs that are not in it.
2. **A capture gate proves nothing until re-run** — camp moved to `(9950, 2400)` while PNGs still showed `(11264, 1536)`. On-disk captures are untrusted until file date and camp match live `STARTING_CAMP_POSITION`.
3. **Capture-gate noise floor is TIME, not the change** — 11 of 25 frames are byte-identical across identical runs. Camp frames can move 5,912 / 21,799 pixels between runs. Judge trees on `forest_density`. Two identical runs before attributing a diff.
4. **Minimap / HUD as the way-home** — if the 30s loop is only legible with the 72×54 minimap, the world is still scatter. Review captures with HUD hidden.
5. **Pocket table and obstacle table authored separately** — `WILDERNESS_POCKETS[2]` sits under Ostari South Shell. Edit both in the same change. `MAXIMUM_UNHOSTABLE_POCKETS = 1` is a tripwire, not a quota.
6. **Presentation sprites drift from collision/flow** — tree visual scale is `collision_radius * 4.35`; a shorter crop draws larger at the same blocker. Grep collision/flow before any visual scale change.
7. **Forbidden wild non-tree frames / salvage atlas promotion** — 1× veto stands. Five tree yaws only. Salvage stays out of export closure until a live preload and 1× pocket veto.
8. **Shader regressions already paid for** — `texture * COLOR` squares; `unshaded` exempts night; texel-space outlines; runtime multiply cannot fix baked value defects; silhouette defects that survive every grade are geometry.

## Implications for Roadmap

**Four phases. Do not reorder. Do not merge Phase 1 into implementation.**

Architecture research listed a finer 0–5 split (audit / Resource types / layout / dress / cameras / lift). Collapse that into the four phases below: Resource types + WorldMap2D/scatter/dress consumption live in Phase 2; camera re-aim and 1× verdict live in Phase 3; remaining surface lift lives in Phase 4. Dress is skeleton, not polish — pockets belong with camp/roads/landmarks so Phase 3 has places to point at.

### Phase 1: Map Audit + Redesign Contract
**Rationale:** PROJECT.md Active requirement 1 and every research file agree: largest work is the contract. Layout without a contract is more scatter. World-authoring code in this phase is a failed milestone, not a head start.
**Delivers:** Written redesign contract in `docs/` (suggested `docs/WORLD_MAP_REDESIGN_AUDIT.md` + contract). Census of current 25 captures + noise floor. Named district jobs, 30s-loop beats, way-home language that is not the minimap, landmark list, salvage/threat pockets, camp, road hierarchy, exclusion volumes, capture-camera list that will prove the loop. Live counts quoted (640 scenery / 25 captures / 169 world-map — `docs/WORLD_MAP_FOUNDATION.md` is stale). Pocket/obstacle overlaps recorded, not "fixed." Wild-frame veto restated.
**Addresses:** Map audit + redesign contract (P1); keep 14×14; district jobs named; 30s loop named; way-home criteria; mobile budget lock; mechanics-creep lock.
**Avoids:** Pitfall 1 (implement before contract); Pitfall 16 (promoting vetoed frames); Pitfall 17 (extents / HDR / extra pass / Node3D); Pitfall 18 (minimap as way-home — as criteria); Pitfall 22 (docs vs live counts); Pitfall 27 (density retune answering a stale complaint); Pitfall 28 (folding mechanics in).
**Touches:** `docs/` only. **Zero** `src/world/` layout edits. No new atlas regions in `src/world/`. No scenery/cover/resource count changes.
**Done when:** Contract exists, names every beat a later capture must prove, and the Phase 1 diff contains no world-authoring code.

### Phase 2: Authored Skeleton Consuming the Composition Contract
**Rationale:** Contract without consumption is fiction. Skeleton before dress-on-wrong-layout. Independent dress salts stay so art retunes do not move collisions.
**Delivers:**
- `WorldCompositionContract` + nested Resource types; one shipped `.tres` filled from the Phase 1 contract
- `BesprenWorldMap2D.ensure_built()` iterates the contract (camp, roads, colliding landmarks, district cells)
- Scatter 87 IDs from contract positions; `LAYOUT_VERSION++`
- Dress pockets from contract / obstacle bounds; duplicated pocket tables deleted
- Extents stay 14×14 / ±14,336. Broadphase stays. Gather rules unchanged. GameWorld / CoopSession structure unchanged
- Headless world-map 169 updated to new counts/hash; flow hash stable for a given `.tres`
**Uses:** Typed GDScript Resources, existing builders, `WORLD_BUILD_SEED` `0xB35E7E` as dress-salt root only, TileMapLayer as ground fill (not the landmark graph).
**Implements:** Architecture components 1–6. Authored skeleton + district jobs + salvage pockets + hierarchical roads + unique set pieces + negative space (FEATURES P1).
**Avoids:** Parallel world system; Autoload registry; sector RNG called "authored"; twin pocket tables; inserting RNG into an existing stream; linear walk scan; shrinking extents; promoting forbidden wild frames; presentation writing simulation.
**Done when:** Live map matches the contract on camp, roads, obstacles, 87 IDs, and dress envelopes. 169 green. Flow hash is the "dress did not touch nav" proof.

### Phase 3: Capture Gates Prove 1× Named Places, Way-Home, 30s Loop
**Rationale:** Headless 169 cannot prove "named landmark." A place is done when a stranger can point at it in a 480×270 Mobile/Vulkan capture, judged against a measured noise floor. Cameras must look at the new landmarks, not the old hardcoded `CityScrapPile_00` list.
**Delivers:** `world_render_validation` cameras aimed at contract named places: camp, home-road, each landmark, each salvage pocket, each threat approach. Two identical runs = noise floor. 1× stranger-point with HUD hidden (shipping HUD stays). Way-home from each district without minimap. Visual veto in force.
**Addresses:** 30s loop visible in captures; 1× named places; way-home without minimap; capture re-run + TIME floor.
**Avoids:** Stale PNGs; TIME attributed as art; camp frames used as tree evidence; 960×540 assumed as 1×; near-black grounds for dark subjects; metrics that include features drawn outside the subject; hue-bands that straddle two anchors.
**Done when:** A stranger can point at camp, road, landmark, salvage, threat without labels. Way-home reads from the world. Tree claims sit on `forest_density` (stable). On-disk captures match live camp.

### Phase 4: Visual Lift of Remaining Surfaces on That Skeleton
**Rationale:** Visual lift enhances the skeleton; it does not replace it. Lifting before named places makes captures unreadable as evidence (shader grade vs Ostari choke).
**Delivers:** Terrain, props, foliage, structures, lighting, actors, camp, HUD, VFX, shaders judged at delivered 1× against Phase 3 cameras. Fir canopy mass rebake if forest-threat still reads as stalks. Keep `WILD_TREE_TINT` until a pine rebake kills straw hue. Salvage atlas consumer only after pocket 1× veto. Shared `HealthBar2D` / `GroundShadow`. `range_z_min = -20`. `blend_mix`. `vec4 source = COLOR;`. `fwidth` outlines. One weather pass. No second Amber Gold.
**Avoids:** Folding juice into WorldMap2D; HDR 2D; extra fullscreen pass; shadow-casting 2D lights; `unshaded` world materials; texel outlines; measuring Start Menu portraits as shipping actors; hand-rolled health/contact primitives; runtime multiply for baked value defects; grading away geometry silhouettes.
**Done when:** Surfaces pass existing focused gates on the new places. Mobile budget intact. Forest-threat job holds on `forest_density` if the fir rebake ran.

### Phase Ordering Rationale

- **Audit before code.** Contract without audit is fiction. Layout without contract is more scatter. Phase 1 diff that touches `src/world/` placement is a process failure.
- **Skeleton before dress-as-place, dress-pockets with skeleton.** Pocket-vs-shell overlap already happened. Phase 2 edits obstacle + pocket together.
- **Captures after skeleton.** Cameras aimed at old hardcoded names cannot prove the new loop. Noise-floor method is known; the camera list is design.
- **Lift last.** AAA+ here is authored places plus unique set pieces on the mobile bar — not cinematic desktop lift. A lifted stamp grid still fails the core value.
- **Gameplay, extents, renderer, viewport stay frozen across all four phases.**

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2:** Flow-field / spawn-lane pass once camp and Ostari choke move — horde follows `set_core_position`, but teaching-resource offsets and co-op spawn ring are literals today. Pocket derivation math (ellipse from oriented AABB + road clearance) — do not invent per-family magic radii. Exact `.tres` schema is MEDIUM (not in repo yet); start from ARCHITECTURE.md nested Resource sketch, not Tiled.
- **Phase 4:** Fir canopy density (two-clone clump vs denser CC0 source) and wild non-tree veto remain open **art** problems. Do not "solve" them in the map builder. Device thermal cost of more unique atlases is unmeasured — do not claim 60 FPS from desktop gates.

Phases with standard patterns (skip research-phase):
- **Phase 1:** Standard for this repo. Measurement culture already in CLAUDE.md. Inventory + write. No ecosystem research.
- **Phase 3:** Noise-floor method, 11 stable frames, HUD-hidden stranger-point, and 1× verdict rules are already recorded. New camera list is design, not research.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Keep-runtime claims verified against `project.godot` + official Godot 4.7 renderer/CanvasItem/2D-lights/multiple-resolutions docs. Authored Resource format MEDIUM (schema not in repo). |
| Features | MEDIUM–HIGH | Table stakes and anti-features locked by PROJECT.md / CLAUDE.md. Wayfinding analogies (Lynch, Theory of the Place, competitor maps) are MEDIUM. |
| Architecture | HIGH | Live `src/world/` + locked GameWorld/CoopSession. Official Resource vs Autoload/Node guidance. Seam `classify-confidence --provider webfetch` tagged official docs LOW; treat that as provider-tier, not a reason to doubt Godot docs. |
| Pitfalls | HIGH | In-repo recorded failure modes (CLAUDE.md §§7–12, 16; CONCERNS.md) plus official shader/light/renderer contracts. Industry PCG analogies MEDIUM. |

**Overall confidence:** HIGH on what not to do and on phase order. MEDIUM on the exact composition `.tres` field list and on Phase 4 art solutions (fir mass, salvage-atlas promotion).

### Gaps to Address

- **Composition Resource schema:** Nested types sketched in ARCHITECTURE.md; not in repo. Phase 2 planning must freeze `@export` fields (camp, routes, landmarks, pockets, 87 placements, `layout_version`) before WorldMap2D consumption. Do not invent JSON/CSV to dodge this.
- **Spawn-ring and teaching-anchor literals:** Will go stale when camp moves. Phase 2 must grep `STARTING_CAMP_POSITION` consumers (CoopSession spawn, teaching anchors, satellites) in the same change.
- **Fir canopy mass:** Open. Geometry problem. Measure on `forest_density` after skeleton exists. Not a Phase 1 or Phase 2 density multiply.
- **Wild non-tree / salvage atlas:** Veto stands until a new composition passes 1× on hosted pockets. Phase 1 restates; Phase 4 may lift only with a verdict.
- **Device thermals / two-device LAN:** Unmeasured. Out of this milestone. Do not mark done from desktop gates. Last APK/PCK predates the feedback stack — rebuild is a later packaging step, not Phase 3 done.
- **`GROUND_FLATTEN` 0.46:** Docstring is arithmetically false. Keep 0.46 until a rendered sweep. Do not "fix" in the map phases.
- **Foundation docs lag:** Quote live `.gd` + CLAUDE.md. Refresh `docs/WORLD_MAP_FOUNDATION.md` when Phase 2 counts move.

## Sources

### Primary (HIGH confidence)
- Godot 4.7 [Internal rendering architecture](https://docs.godotengine.org/en/4.7/engine_details/architecture/internal_rendering_architecture.html) — Mobile R10G10B10A2 vs HDR 2D RGBA16F; extra passes vs subpasses
- Godot 4.7 [Overview of renderers](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html) — Mobile vs Forward+ on mobile
- Godot 4.7 [CanvasItem shaders](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/canvas_item_shader.html) — fragment `COLOR` already textured; `unshaded`; lighting in the draw pass
- Godot 4.7 [2D lights and shadows](https://docs.godotengine.org/en/4.7/tutorials/2d/2d_lights_and_shadows.html) — `CanvasModulate`, Z range, additive-sprite alternative
- Godot 4.7 [Resources](https://docs.godotengine.org/en/4.7/tutorials/scripting/resources.html) / [node alternatives](https://docs.godotengine.org/en/4.7/tutorials/best_practices/node_alternatives.html) / [autoloads vs nodes](https://docs.godotengine.org/en/4.7/tutorials/best_practices/autoloads_versus_regular_nodes.html)
- Godot 4.7 [TileMapLayer](https://docs.godotengine.org/en/4.7/classes/class_tilemaplayer.html) / [multiple resolutions](https://docs.godotengine.org/en/4.7/tutorials/rendering/multiple_resolutions.html)
- In-repo: `CLAUDE.md` §§1–4, 7–12, 16; `.planning/PROJECT.md`; `.planning/codebase/ARCHITECTURE.md`, `CONCERNS.md`, `CONVENTIONS.md`, `TESTING.md`; live `src/world/*.gd`; `project.godot`

### Secondary (MEDIUM confidence)
- [Level Design Book — Wayfinding](https://book.leveldesignbook.com/process/blockout/wayfinding) — Lynch elements; HUD/minimap as ~97% crutch
- Joris Dormans, [The Theory of the Place](https://www.gamedeveloper.com/game-platforms/the-theory-of-the-place-a-level-design-philosophy-for-unexplored-2) (2021)
- Don't Starve Together biomes / Core Keeper ring layout / They Are Billions map themes — authored skeleton + constrained dress
- Kate Compton, “10,000 bowls of oatmeal”; Gamasutra 2018 PCG blandness vs chaos
- Authored `.tres` schema — right pattern, fields not yet in repo
- Device thermal cost of unique atlases — desktop GPU ≠ Android

### Tertiary (LOW confidence)
- Tiled/LDtk as optional offline sketch — not needed this milestone
- Seam `classify-confidence --provider webfetch` LOW on docs.godotengine.org — provider-tier artifact; do not downrank official docs

---
*Research completed: 2026-09-18*
*Ready for roadmap: yes*
