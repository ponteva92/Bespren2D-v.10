# Feature Research

**Domain:** AAA+ 2D mobile top-down survival map composition and visual polish (brownfield Bespren, 480×270)
**Researched:** 2026-09-18
**Confidence:** MEDIUM (composition/wayfinding) / HIGH (Godot 4.7 mobile budgets, project contracts)

## Feature Landscape

This milestone is **visual + map composition**, not a mechanics slice. Gameplay systems already exist (ENet authority, gather, towers/traps, horde, HUD). The product failure is **scatter, district pacing, and 1× readability**. Largest work is a **map audit + redesign contract before any world-authoring code**.

Premium 2D top-down survival / co-op maps do not win by adding more seeded props. They win by an authored skeleton: districts with jobs, hierarchical paths, unique landmarks, then scatter only as texture. Don't Starve Together still *guarantees* themed biomes and authored set pieces (Florid Postern, Pig King, Oasis) on a procedural continent. Core Keeper rings biomes around a central Core and a Great Wall. They Are Billions themes maps by choke versus openness around a Command Center. Unexplored 2's Theory of the Place (place / path / environment / antechamber / vault) is the same anatomy at site scale. Bespren already has the names (Kaupunki, Ostari, Kylät, Metsä) and the extents. It does not yet have that anatomy on the ground at 480×270.

### Table Stakes (Users Expect These)

Missing these = the map still reads as scatter. These are launch-for-this-milestone, not optional polish.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Map audit + redesign contract (first-class)** | Cannot re-author a 14×14 world from taste. Current failure modes are already named: seeded dress on a grid, wrong district pacing, 1× unreadability. Industry hybrid practice: audit at multiple scales, then lock a hand-authored high-level frame before filling. | HIGH | Deliverable is a written contract: camp, roads, obstacles, resources, landmarks, density, district jobs, 30s-loop beats, capture cameras. **No world-authoring code until this exists.** Independent dress salts stay (`WORLD_BUILD_SEED + N`) so density retunes do not move collisions. |
| **Keep 14×14 / ±14,336 extents** | Same playable world; composition changes, size does not. Shrinking is the cheap fake of "authored." | LOW | Locked product requirement. Camp/roads/obstacles/resources may all move. Macro cell stays 2,048. |
| **Authored skeleton: paths, edges, districts, nodes, landmarks** | Lynch *Image of the City* + Level Design Book wayfinding. Players form mental maps from these five, not from biome cell IDs. Test without HUD. | HIGH | Paths = hierarchical road graph (asphalt spine vs dirt branch vs wilderness perimeter). Edges = district boundaries that *read* (terrain, wreck lines, fence, canopy wall) not just cell tables. Districts = squint-test identity. Nodes = junctions with a sense of place. Landmarks = unique silhouettes visible from multiple approaches. |
| **District jobs (city choke, mall salvage, village quiet, forest threat)** | Named regions that do the same thing are wallpaper. DST biomes, Cult of the Lamb crusade biomes, and TAB map themes all assign a *job* per zone. | HIGH | Kaupunki = dense non-enterable shells + sightline breaks + choke. Ostari = collapsed commercial salvage with a narrow passage (antechamber → place). Kylät = quiet yards, timber, broken-fence gaps, rest rhythm. Metsä = threat canopy, sparse mass, camp as clearing. Connectors stay shoulders, not a fifth biome. |
| **Visible 30s loop: camp → readable road → named landmark → salvage pocket → threat → back** | Core value. A stranger must see the loop in captures, not infer it from seed. Survival maps that work (TAB Command Center runs, DST day-one wood/road/landmark, Core Keeper Core → wall) make the beat spatial. | HIGH | Capture-gated, not design-doc-gated. Teaching resources stop being "three nodes near camp" and become the first salvage pocket on a readable road. Threat is a *place* (choke, nest silhouette, canopy wall), not uniform horde fog. |
| **1× named places without labels** | At 480×270, floating names are a confession the silhouette failed. Identity must be redundant across hue, silhouette, iconography, placement (CLAUDE.md §11). | HIGH | Squint / desaturate / 1× logical review. Camp, mall, village cluster, city choke, forest threat each have a unique skyline. No world-space nameplates. |
| **Way home without minimap** | Level Design Book ranks always-on HUD/minimap as ~97% certainty — a crutch. Product requirement: from any district, home is readable from roads, silhouettes, and landmarks. | HIGH | Camp Amber Gold weenie + road hierarchy + at least one landmark per return vector. Minimap stays as confirmation, never as the only compass. Gate: play/capture with minimap hidden. |
| **Hierarchical, readable roads** | Paths organize everything else. Current eight polylines exist; they do not yet *read* as the loop's spine at 1×. | MEDIUM | Asphalt vs dirt already distinct in code. Need width, edge, dash/rut, shoulder salvage, and negative space so a 480×270 frame shows "this is the way" without the minimap. Roads stay on z=-20. Chunk ≤4,096. |
| **Salvage as pockets, not 84-sector scatter** | Uniform sector scatter is the oatmeal problem. Theory of the Place: loot lives in the place / vault, optional in the environment. 87 IDs can stay; *positions and grouping* must serve pockets. | HIGH | Keep deterministic IDs, 3–5 step gather, one-unit yield, late-join snapshots. Re-author spawn rejection around authored pockets and teaching anchors. Do not add a new gather system. |
| **Negative space, camp clearing, landmark exclusion** | Quiet regions make motion and the Base Core pop. Fill every tile and the frame buzzes. Camp must read as a clearing, not a stamp in a forest. | MEDIUM | Keep / retune camp clear radius, road-center clearance, landmark exclusion rects. Pocket tables and obstacle tables must be authored *together* (pocket 2 vs Ostari South Shell is the standing proof they were not). |
| **Unique set pieces over atlas-stamp repetition** | Eye spots repeating hotspots instantly. Village fence coin-flip already taught: a per-segment coin delivers runs of the same thing. Variety ceiling today is 8-slot modulo pools, not texture count. | HIGH | Hero pieces at nodes/landmarks (mall gate, city choke wreck, village well/yard, forest camp satellites). Dress layers use larger kind pools and adjacent-difference rules, not `index % 8`. Do not promote wild non-tree frames. |
| **1× silhouette / value hierarchy** | Table stakes at this viewport: player, camp, threat, salvage, path must parse in <200 ms with HUD eating corners. Interior linework is secondary. | MEDIUM | One focal story per screen. Terrain mid-low contrast; interactables and landmarks get the high end. Base Core remains the only dominant Amber Gold. Screen-space outline (`fwidth` × stretch), not texel-space. Judge at 1× logical; texture minification also at device scale. |
| **Presentation never writes simulation** | Co-op and authority already work. Visual lift that mutates collision/flow/RPC is a rewrite. | MEDIUM | Collision, flow mask, `resolve_player_motion`, resource IDs stay canonical. Sprites stay presentation-only. Visual scale derived from `collision_radius` must be grepped before any rebake. |
| **Capture-gated 1× review as a verdict** | A green headless count is placement evidence, not art promotion. Capture gates prove nothing until re-run; TIME noise must be measured. | MEDIUM | World render gate cameras retargeted to the 30s-loop beats. Noise floor = two identical runs. Tree claims on `forest_density` (stable). Visual veto overrides numeric pass. |
| **Deterministic authored composition** | LAN co-op and late-join need the same world. Authored ≠ hand-wavy. | MEDIUM | Skeleton is data (polylines, obstacle tables, landmark list, pocket list). Dress still salted. World-map validation (169) remains the count/walkability/flow pin. |

### Differentiators (Competitive Advantage)

Not required for "the map is a place," but they are the AAA+ lift and the reason this milestone is not a layout-only patch.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Full visual lift of every surface** | Authored places plus denser unique set pieces on the mobile bar — map, terrain, props, foliage, structures, lighting, actors, camp, HUD, VFX, shaders. | HIGH | After the contract, not instead of it. Each family judged at delivered 1×. Actors already have baked 8-heading sheets; lift is contact, silhouette, night response — not a new roster. |
| **Theory of the Place nested per district** | Each district is a site: environment + path + antechamber + place (+ optional vault). Players learn one navigation grammar and apply it four times. | HIGH | Ostari already wants this (long shells, narrow east-west passage). Apply the same grammar to city choke, village quiet, forest threat. Secondary routes exist; they are harder, not missing. |
| **Camp as Lynch landmark / weenie** | Core Keeper's Core and TAB's Command Center are unmissable centers. Bespren's emotional center is already the Base Core; the map must orbit it visually. | MEDIUM | Amber Gold PointLight2D + aura + pulse stay the only dominant warm source. Way-home is a side-effect of this weenie working at distance, not a new HUD widget. |
| **Co-op callout landmarks** | Two players on two devices need shared nouns: "mall gate," "west yard," "asphalt cross." | MEDIUM | Landmarks that survive desaturation and 1× become voice-comms without labels. Bonus of unique silhouettes, not a chat system. |
| **Decay as district language** | Rust / rot / patina already reserved. Using them as *district* weather (hot rust city, rotten village timber, cool patina tech mall, forest rot) makes identity without new biomes. | MEDIUM | `surface_weathering` + terrain blend + finish grade. Interactable silhouettes stay cleaner than background. Do not add a burnt biome this milestone unless the contract demands it. |
| **Hero set pieces at nodes** | AAA 2D polish is modular filler + hand-crafted heroes at decision points. | HIGH | One unforgettable silhouette per district + camp satellites that read as camp, not props. Prefer rebaking a few large pieces over stuffing 74 more 256px stamps. |
| **Fir canopy as mass, not a stalk** | Forest threat cannot job if trees read as tiered sticks. Geometry, not grade. Holdout clip already killed the poker-chip mound; density is still open. | HIGH | Two-clone clump in the bake or a denser CC0 source. Measure on `forest_density`. Re-derive both `WILD_TREE_REGIONS` tables from the manifest. Keep `WILD_TREE_TINT` until a rebake kills straw hue. |
| **Lighting-responsive world, one weather pass** | Night that still parses, camp that pulls focus, no extra fullscreen tax. | MEDIUM | `blend_mix` (not `unshaded`) so CanvasModulate and PointLight2D reach the world. `range_z_min = -20`. Additive sprites for short-lived glow instead of more lights. Weather stays the single overlay. |
| **HUD/VFX that refuse to compete with the world** | Compact dashboard already 50.9% smaller. Lift is hierarchy, not size. Juice reports simulation. | MEDIUM | Shared `HealthBar2D` / `GroundShadow`. No second Amber Gold. Accessibility scales stay 0 = absent. Do not grow the dashboard. |
| **Salvage atlas as pocket dressing (conditional)** | 38 packed frames, zero runtime consumer. Authored scrap in mall/city pockets is the intended use. | MEDIUM | Only after 1× pocket review. Do not add to export closure until a live preload exists. Always bake wild+salvage together or merge the report. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **World-authoring code before the audit/contract** | "Just move the camp and add props." | Repeats the scatter failure with new seeds. Pocket/obstacle desync already happened once. | Audit → discuss → written contract → then implement in later phases of *this* project. |
| **Shrinking or growing 14×14** | Smaller world is easier to hand-place; bigger feels "more game." | Locked extents. Shrink is fake authorship; grow blows flow raster, scatter, and capture cameras. | Re-author inside ±14,336. |
| **New gameplay systems (deposit, inventory, progression, new combat)** | Feels like content. | Wrong milestone. No stubs. Would bury the map rewrite. | Leave pool/gather/towers as-is. Spatial loop is the feature. |
| **Changing 480×270 or `canvas_items` stretch** | More pixels = more AAA. | Mobile clarity *is* the quality bar. Stretch changes every `fwidth` outline and HUD geometry. | Lift at 1× logical. |
| **Extra fullscreen custom passes / glow / SSAO / desktop post** | Cinematic. | Godot 4.7 Mobile is tile-based; screen/depth reads break subpasses and cost bandwidth. Budget is **one** custom fullscreen pass (weather + damage wash). | Combine atmosphere in `weather_overlay.gdshader`. |
| **HDR 2D** | Cleaner bloom, less banding. | Mobile default is R10G10B10A2; HDR 2D switches to RGBA16F and raises bandwidth. Official docs: can reduce performance on mobile GPUs. | Keep HDR 2D off. Emission via CanvasItem color + local lights. |
| **Runtime 3D / GLTF / mesh / PBR / Node3D** | "Real" lighting and unique buildings. | Runtime stays 2D atlases. Workshops stay offline. Export closure would explode; thermal budget dies. | Blender 5 bake → PNG/atlas → presentation-only sprites. |
| **Shadow-casting 2D lights** | Contact and night drama. | Foundation budget is **zero**. PCF5/PCF13 are expensive; lights already process in the draw pass. | Authored `GroundShadow` ellipses + value grade. Additive sprites for short glows. |
| **`render_mode unshaded` on world subjects** | Faster / "already lit in the bake." | Skips CanvasModulate and PointLight2D. World falls to blue hour around daylight decals. Already burned once. | `blend_mix`. Entry `COLOR` is already textured; do not `texture(TEXTURE,UV)*COLOR`. |
| **Promoting forbidden wild non-tree frames** | Atlas is packed; "use the roots/branches/shrubs." | 1× review: tan boulders, black-worm branches, shrub as crack. `runtime_promotion = forbidden_pending_human_visual_veto`. | New composition + hosted-pocket 1× veto. Until then, five tree yaws only. |
| **Mass density / tripling clusters** | Feels premium in the editor. | Ground cover was nearly retuned on a stale "five elements per screen" complaint; current capture already has value pairs. Uniform density is scatter with a bigger budget. | Authored pockets + negative space. Variety via kinds and set pieces, not count. |
| **World labels / floating district names** | Guarantee 1× naming. | Admits silhouette failure. Fights the 480×270 HUD. | Redundant identity. Labels stay in design docs and capture *filenames*, not the scene. |
| **Minimap as primary way-home** | Already have a 72×54 map. | Product requires way-home from the world. Minimap-first teaches players not to read districts. | Hide minimap in the way-home gate. Keep ping as co-op aid. |
| **Per-instance random flip/yaw as "variety"** | Cheap anti-repetition. | Per-segment coin leaves identical runs (village fence). Adjacent-difference must be *constructed*. | Seeded phase + alternating rule, or authored hero pieces. |
| **Matching survivor contact to enemy `marker_radius` (or any constant to the wrong job)** | Looks principled. | A metric whose spread is 2.7× is measuring something else. Pipeline values reused for unmeasured jobs. | Measure what the constant describes. Per-variant radii from stance. |
| **Desktop-only Forward+ features, TAA, FSR2, volumetric fog** | AAA checklist. | Forward+ is poorly optimized on mobile. Official renderer overview: use Mobile. | Stay on Mobile/Vulkan, OpenGL fallback. |
| **Destructive `Addons/` cleanup** | Disk. | Vault is provenance. No deletion authorized. | Promote only through the audited extractor. |
| **Android device certification / two-device LAN as this milestone's done** | Want ship. | Separate release gate. Desktop captures do not prove thermals or physical LAN. | Keep as later. Do not block the map contract on a device. |
| **New water/wetland/burnt biomes as the first move** | Variety plan named them as gaps. | New biomes without a skeleton are more scatter. Not required for district jobs. | Only if the redesign contract assigns them a job. Otherwise defer. |

## Feature Dependencies

```
Map audit (captures, density, pocket/obstacle overlaps, 1× unreadables)
    └──requires──> Redesign contract (camp, roads, districts, landmarks, pockets, 30s cameras)
                       └──requires──> Authored skeleton in data (extents locked)
                                          ├──requires──> Hierarchical roads + edges
                                          ├──requires──> District jobs + unique landmarks/nodes
                                          ├──requires──> Camp weenie + clearings
                                          └──requires──> Salvage pockets (reposition 87 IDs)
                                                 └──requires──> Way-home + 1× named-place gates
                                                        └──enhances──> Dress layers (kinds, set pieces, negative space)
                                                               └──enhances──> Per-family visual lift
                                                                      (terrain, props, foliage, structures,
                                                                       lighting, actors, camp, HUD, VFX, shaders)
                                                                          └──requires──> Capture re-run + noise floor

Fir canopy rebake ──enhances──> Forest-threat district job
Salvage atlas consumer ──requires──> Pocket 1× veto (else conflicts with anti-feature)
WILD_TREE_TINT drop ──requires──> Fir/hue rebake
Pocket table edits ──requires──> Obstacle table edits (same change)
Visual scale / atlas region edits ──requires──> Collision/flow grep + manifest re-derive
Night/lighting lift ──requires──> blend_mix + range_z_min=-20 (conflicts with unshaded)
HUD/VFX lift ──conflicts──> Extra fullscreen pass / second Amber Gold
Gameplay systems (deposit/inventory/progression) ──conflicts──> This entire milestone
```

### Dependency Notes

- **Audit requires nothing else, and everything else requires the audit:** Largest work. Moving camp or roads first invalidates every capture camera and pocket. Contract is the phase-0 feature, not a preamble.
- **Skeleton before dress:** Dress on a wrong skeleton is how 1,100 marks and 640 silhouettes still read as scatter. Independent salts (`+91/+137/+173/+211`) stay so dress iteration does not scramble collision.
- **30s loop requires roads + landmark + pocket + threat as one composition:** Any one beat missing and the capture fails. Teaching resources are the first pocket, not a separate tutorial system.
- **Way-home requires the camp weenie and road hierarchy:** Minimap cannot substitute in the gate.
- **Visual lift enhances, it does not replace, the skeleton:** A prettier stamp grid is still a stamp grid. Shader/actor/HUD work can overlap *after* the contract exists, but must not land atlas region changes before the new obstacle table.
- **Fir canopy enhances forest threat:** Forest job is table stakes; current five yaw frames are not enough mass. Geometry fix, not a density multiply.
- **Salvage atlas conflicts with promotion-without-veto:** Consumer is a differentiator only after 1× pocket review.
- **Pocket vs obstacle:** Authoring them separately created unhostable wilderness pocket 2. Same-change rule is a feature of the contract, not a later fix.

## MVP Definition

### Launch With (v1)

Minimum for this milestone to claim the world reads as authored places. Ruthless: if it is not in a 1× capture of the 30s loop, it is not v1.

- [ ] **Map audit + redesign contract** — first-class feature; blocks all world-authoring code
- [ ] **14×14 extents kept**; camp/roads/obstacles/resources re-authored to the contract
- [ ] **District jobs** visible: city choke, mall salvage, village quiet, forest threat
- [ ] **30s loop visible in captures:** camp → readable road → named landmark → salvage pocket → threat → back
- [ ] **1× named places without labels** (squint / desaturate / stranger-point test)
- [ ] **Way home without minimap** from each district
- [ ] **Salvage pockets** replace uniform 84-sector scatter (IDs/rules unchanged)
- [ ] **Unique set pieces at nodes**; dress no longer `index % 8` wallpaper
- [ ] **Negative space + camp clearing + pocket/obstacle co-authored**
- [ ] **Presentation/authority split + determinism + world-map/smoke gates green**
- [ ] **Capture cameras retargeted**; noise floor measured; visual veto in force
- [ ] **Mobile rendering contract held:** one fullscreen pass, no HDR 2D, no runtime 3D, no shadow-casting 2D lights

### Add After Validation (v1.x)

Once the skeleton reads at 1×, lift surfaces against it.

- [ ] **Full visual lift pass** — terrain, props, foliage, structures, lighting, actors, camp, HUD, VFX, shaders — trigger: 30s-loop captures pass stranger-point
- [ ] **Fir canopy mass rebake** — trigger: forest-threat district still reads as stalks on `forest_density`
- [ ] **Drop or retune `WILD_TREE_TINT`** — trigger: pine rebake no longer AgX-tans
- [ ] **Salvage atlas pocket consumer** — trigger: hosted-pocket 1× veto passes
- [ ] **Nested Theory of the Place polish** (secondary entrances, antechamber encounters as *places*) — trigger: primary path already readable
- [ ] **Shared wild-tree region constant** (kill duplicated `Rect2` literals) — trigger: next wild rebake

### Future Consideration (v2+)

- [ ] **Deposit / persistent inventory / progression** — out of scope; next coherent slice
- [ ] **Android device + two-device LAN certification** — release gate, not this milestone's done
- [ ] **Water/wetland/burnt biomes** — only if a later contract assigns a job
- [ ] **Shadow-casting 2D lights / extra passes / HDR 2D** — only with profiler + readability proof and a budget exception
- [ ] **Wild non-tree frame promotion** — only after a new composition passes 1× veto
- [ ] **Accessibility settings UI / Android lifecycle pause** — required before content lock, not before map authorship
- [ ] **APK rebuild** — needed before device install; not a map feature

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Map audit + redesign contract | HIGH | HIGH | P1 |
| Keep 14×14; re-author camp/roads/obstacles | HIGH | MEDIUM | P1 |
| District jobs (choke / salvage / quiet / threat) | HIGH | HIGH | P1 |
| 30s loop visible in captures | HIGH | HIGH | P1 |
| 1× named places, no labels | HIGH | HIGH | P1 |
| Way home without minimap | HIGH | HIGH | P1 |
| Salvage pockets (reposition 87 IDs) | HIGH | HIGH | P1 |
| Hierarchical readable roads | HIGH | MEDIUM | P1 |
| Unique set pieces; kill modulo-stamp | HIGH | HIGH | P1 |
| Negative space / camp clearing / co-authored pockets | HIGH | MEDIUM | P1 |
| Capture gates + noise floor + visual veto | HIGH | MEDIUM | P1 |
| Presentation/authority + determinism held | HIGH | LOW | P1 |
| Full visual lift (all surfaces) | HIGH | HIGH | P2 |
| Fir canopy mass rebake | HIGH | HIGH | P2 |
| Nested Theory of the Place per district | MEDIUM | HIGH | P2 |
| Lighting-responsive world / one weather pass polish | MEDIUM | MEDIUM | P2 |
| HUD/VFX hierarchy lift | MEDIUM | MEDIUM | P2 |
| Salvage atlas consumer | MEDIUM | MEDIUM | P2 |
| Shared wild-tree region constant | LOW | LOW | P3 |
| New biomes (water/burnt) | LOW | HIGH | P3 |
| Device certification | HIGH | HIGH | P3 (later milestone) |
| Deposit/inventory/progression | HIGH | HIGH | — anti-feature here |

**Priority key:**
- P1: Must have or the map still reads as scatter
- P2: AAA+ lift once the skeleton reads
- P3: Nice / later milestone

## Competitor Feature Analysis

| Feature | Don't Starve Together | Core Keeper | They Are Billions | Cult of the Lamb | Our Approach |
|---------|----------------------|-------------|-------------------|------------------|--------------|
| World size vs authorship | Procedural continent; **guaranteed** biomes + set pieces | Concentric rings around Core; wall gates outer biomes | Compact survival maps; themes weight chokes vs openness | Authored hub + themed crusade biomes | **Keep 14×14.** Authored skeleton, constrained dress. No shrink. |
| Landmark / weenie | Florid Postern, Pig King, Oasis, roads | Core at origin, Great Wall, bosses on arcs | Command Center, Doom Villages, terrain barriers | Cult base; bishop biomes | Base Core Amber Gold weenie + one unique silhouette per district |
| District identity | Terrain color + exclusive fauna/resources | Block type, ore, enemy, sub-biome | Theme: forest chokes vs open wasteland | Four aesthetic/resource/enemy packages | Jobs: city choke, mall salvage, village quiet, forest threat |
| Paths | Roads/trails/wormholes | Tunnels, Ghorm path, wall ring | Natural chokes (wood/stone/water) | Crusade path rooms | Hierarchical asphalt/dirt/perimeter; way-home without minimap |
| Scatter vs places | Set pieces in biomes; rest is biome fill | Scenes/dungeons at distances; noise for terrain | Resource patches inside theme | Rooms remix inside biome | Pockets + hero pieces; 87 IDs stay, positions serve places |
| Co-op orientation | Shared map + distinctive biomes | Shared Core/wall language | Single-player | Single-player hub | Shared callout landmarks; LAN already exists |
| Readability aid | Map UI heavy | In-game map + scanners | Lookouts / Beholder | Run map | **World-first.** Minimap is confirmation only |
| Visual bar | Stylized readable 2D | Readable voxel 2D | Readable RTS 2D | Stylized 2D | AAA+ at 480×270: silhouette/value, not desktop post |

## Sources

**Official / HIGH (docs, verified webfetch):**
- Godot 4.7 [Internal rendering architecture](https://docs.godotengine.org/en/4.7/engine_details/architecture/internal_rendering_architecture.html) — Mobile tile-based renderer, R10G10B10A2 vs RGBA16F HDR 2D, subpass limits, 2D lights in one pass
- Godot 4.7 [Overview of renderers](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html) — Mobile vs Forward+ on mobile; 2D HDR Viewport; Compatibility fallback
- Godot 4.7 [2D lights and shadows](https://docs.godotengine.org/en/4.7/tutorials/2d/2d_lights_and_shadows.html) — PointLight2D cost vs additive sprites; PCF5/13; CanvasModulate
- Godot 4.7 [CanvasItem shaders](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/canvas_item_shader.html) — lighting in the regular draw pass; `unshaded` skips light; fragment `COLOR` already includes `TEXTURE`

**Wayfinding / composition — MEDIUM (primary texts, verified webfetch):**
- [Level Design Book — Wayfinding](https://book.leveldesignbook.com/process/blockout/wayfinding) — Lynch elements; HUD/minimap as 97% crutch; test without HUD; everything is a wayfinding aid
- Joris Dormans, [The Theory of the Place](https://www.gamedeveloper.com/game-platforms/the-theory-of-the-place-a-level-design-philosophy-for-unexplored-2) (2021) — place, path, environment, antechamber, vault; readability as agency
- Kevin Lynch, *The Image of the City* (1960) — paths, edges, districts, nodes, landmarks (via Level Design Book)

**Competitor maps — MEDIUM (wiki/official community, webfetch + search):**
- [Don't Starve Together biomes](https://dontstarve.wiki.gg/wiki/Biomes/DST) — guaranteed vs random biomes; authored set pieces on a procedural puzzle of biomes
- Core Keeper world/biome layout (central Core, Great Wall ~450–520 tiles, outer titans) — ring landmarks
- They Are Billions survival map themes — choke-point identity around Command Center / Doom Villages

**Project contracts (canonical for Bespren, not industry):**
- `.planning/PROJECT.md` — locked requirements, out of scope, 14×14, audit-first
- `CLAUDE.md` §§1–4, 8, 10–11, 16 — loop, palette, mobile budgets, accessibility, world matrix
- `.planning/codebase/ARCHITECTURE.md` — world build path, dress salts, z matrix
- `.planning/codebase/CONCERNS.md` — fir canopy, forbidden wild frames, pocket 2, capture TIME noise, salvage atlas unused
- `docs/WORLD_MAP_FOUNDATION.md`, `docs/WORLD_MAP_VISUAL_PRODUCTION_PLAN.md` — spatial contract (treat live `.gd` + CLAUDE.md as count-canonical; foundation docs lag)

**Readability craft — LOW as industry-generic blogs, used only where they agree with CLAUDE.md measurement culture:**
- Silhouette/value hierarchy, unique set pieces vs tile-stamp, 1× testing with HUD overlay. Do not treat pixel-art integer-scale dogma as a Bespren requirement (`canvas_items` stretch is locked).

---
*Feature research for: Bespren visual AAA+ and 14×14 map redesign*
*Researched: 2026-09-18*
*Do not commit — orchestrator commits after parallel researchers finish.*
