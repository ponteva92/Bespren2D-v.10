# Architecture Research

**Domain:** Authored-place 2D world-map composition on an existing Godot 4.7.1 Mobile LAN co-op survival slice
**Researched:** 2026-09-18
**Confidence:** HIGH (locked codebase + live `src/world/` + official Godot 4.7 docs). Seam `classify-confidence --provider webfetch` returned LOW even for docs.godotengine.org; treat that as a provider-tier artifact. Project-local architecture claims are HIGH because they come from the shipping scripts, not the fetch.

## Standard Architecture

### System Overview

Do **not** add a second world. Evolve `BesprenWorldMap2D`. GameWorld, CoopSession, and the peer-one authority path stay as they are.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  LOCKED — do not redesign                                              │
│  StartMenu → GameWorld (no autoloads)                                   │
│  CoopSession peer-1 20 Hz  ·  TacticalBuild  ·  Horde/Flow              │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │ world_map.ensure_built()
                                 │ scatter.configure_world_map()
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  NEW DATA, SAME NODE — WorldCompositionContract (Resource, not a Node)  │
│  districts · named landmarks · routes · salvage pockets · camp · IDs    │
│  data/world/bespren_world_composition.tres                              │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │ preload / @export, never Autoload
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  BesprenWorldMap2D.ensure_built()  — still the only builder             │
│  1 biome cells     2 ground/terrain     3 roads                         │
│  4 WorldObstacle2D  5 flow bake + 512-unit broadphase                   │
│  6 dress configure (read-only Callables + contract pockets)             │
├──────────────┬──────────────┬──────────────┬──────────────┬─────────────┤
│ RoadNetwork  │ Obstacles    │ Scatter      │ Dress        │ Validation  │
│ authored     │ collision +  │ 87 IDs from  │ independent  │ world_map   │
│ polylines    │ flow canon.  │ contract,    │ seeds +91/   │ 169 + GPU   │
│ z=-20        │ sprites =    │ not 12×7 RNG │ 137/173/211  │ 25 captures │
│              │ presentation │ LAYOUT_VER++ │ z=-5 / -4    │ noise floor │
└──────────────┴──────────────┴──────────────┴──────────────┴─────────────┘
                                 │
                                 ▼
                    CanvasItem matrix (absolute, z_as_relative=false)
                    terrain -20 · rubble/cover -5 · ambient -4
                    gameplay Y-sort 5 · weather L50 · HUD L100
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| `WorldCompositionContract` | Authored places: district jobs, named landmarks, routes, salvage pockets, camp, resource IDs. Data only. No physics, no RPC, no draw. | New `class_name` Resource under `src/world/`, saved as `data/world/*.tres`. Same pattern as `StructureDefinition` / `PlayerSlotDefinition`. |
| `BesprenWorldMap2D` | Sole builder. Reads the contract, still owns biome grid, obstacle list, 512-unit broadphase, flow bake, walkability, `resolve_player_motion`. | Keep `src/world/world_map_2d.gd`. Replace inline `PackedVector2Array` city/mall/village tables with contract iteration. `ensure_built()` order stays. |
| `WorldObstacle2D` | One collision + flow footprint. Atlas sprites presentation-only. | Unchanged class. New landmarks add `VisualKind` + atlas crop; never a second obstacle type. |
| `WorldRoadNetwork2D` | Authored asphalt/dirt graph, edge-distance queries, chunked draw at z=-20. | Unchanged API. `configure(routes, dirt_flags)` fed from contract routes instead of the eight hardcoded polylines. |
| `BesprenResourceScatter2D` | 87 deterministic IDs, 3–5 step harvest, late-join snapshots, host-only mutation. | Keep RPC/authority. Replace `_placement_for` 12×7 sector RNG with contract positions. Bump `LAYOUT_VERSION`. Teaching anchors stay camp-relative. |
| Dress quartet | Non-colliding density. Independent seeds so art retunes do not move collisions. | Keep `WorldBackgroundDecor2D`, `WorldAmbientScenery2D`, `WorldWildernessAccent2D`, `WorldGroundCover2D`. Pockets come from the contract (or are derived from obstacle/road bounds), not a second table. |
| `GameWorld` | Composition root, signal graph, motion/fire resolvers. | **Locked.** Still `world_map.ensure_built()` then `resource_scatter.configure_world_map`. |
| `CoopSession` | Host-authoritative ENet / `OfflineMultiplayerPeer`. | **Locked.** Still calls the motion Callable. Never learns about districts. |
| `TacticalBuildSystem` | Shared pool, 64 px snap, Base relocation. | Reads `STARTING_CAMP_POSITION` / `set_core_position`. Camp may move; the API does not. |
| `FlowFieldNavigation2D` | 112×112 integration toward active Base. | Consumes the mask WorldMap2D already bakes. No new nav system. |
| Capture gates | Done-check for authored places at 480×270. | `tests/world_map_validation.gd` (counts/hashes) + `tests/world_render_validation.tscn` (25 Mobile/Vulkan frames + noise floor). |

## Recommended Project Structure

```
src/world/                              # keep; do not fork a src/map/
├── world_map_2d.gd                     # still the builder; reads contract
├── world_composition_contract.gd       # NEW class_name Resource (data only)
├── world_district_definition.gd        # NEW nested Resource: job, cells, landmarks
├── world_landmark_definition.gd        # NEW nested Resource: id, shape, VisualKind
├── world_route_definition.gd           # NEW nested Resource: polyline + dirt flag
├── world_pocket_definition.gd          # NEW nested Resource: dress/salvage ellipse
├── world_obstacle_2d.gd                # unchanged contract
├── world_road_network_2d.gd            # unchanged API
├── resource_scatter_2d.gd              # placement from contract; LAYOUT_VERSION++
├── world_background_decor_2d.gd        # pockets from contract
├── world_ambient_scenery_2d.gd         # pockets from contract; drop duplicated tables
├── world_wilderness_accent_2d.gd       # same
└── world_ground_cover_2d.gd            # same; last in ensure_built()

data/world/                             # NEW; matches data/coop/ reservation
└── bespren_world_composition.tres      # one shipped contract (seed 0xB35E7E)

docs/                                   # audit + contract live here FIRST
├── WORLD_MAP_REDESIGN_AUDIT.md         # phase-0, no code
└── WORLD_MAP_FOUNDATION.md             # refresh after layout lands (code wins)

tests/
├── world_map_validation.gd             # pin contract identity, not stale counts
└── world_render_validation.tscn        # cameras from contract named places

scenes/world/world_map_2d.tscn          # unchanged child graph
scenes/game/game_world.tscn             # unchanged unique-name children
```

### Structure Rationale

- **`src/world/` stays the only world package.** A parallel `src/map/` or `WorldComposer` node next to `%WorldMap2D` splits walkability, flow, and dress. Motion already goes `GameWorld → TacticalBuildSystem → BesprenWorldMap2D`. A second owner of obstacles would desync the 20 Hz tick.
- **Contract is a Resource, not a Node and not an Autoload.** Godot 4.7 Resources are data containers: serialize to `.tres`, nest sub-Resources, Inspector-edit, typed `Array[WorldLandmarkDefinition]`. Nodes draw and simulate. Autoloads persist across scene changes and create global state — Bespren has none on purpose (`project.godot` has no `[autoload]`). Official: [Resources](https://docs.godotengine.org/en/4.7/tutorials/scripting/resources.html), [node alternatives](https://docs.godotengine.org/en/4.7/tutorials/best_practices/node_alternatives.html), [autoloads vs nodes](https://docs.godotengine.org/en/4.7/tutorials/best_practices/autoloads_versus_regular_nodes.html).
- **`data/world/` not `src/world/*.gd` constants.** Layout is OPEN this milestone. Moving camp/roads/obstacles by editing a `.tres` keeps `ensure_built()` stable. Today city buildings are `PackedVector2Array` literals inside `_build_city()`; that is the scatter smell.
- **Dress scripts stay.** They already chunk, cull, and seed independently (`WORLD_BUILD_SEED+91/+137/+173/+211`). The defect is *what they sample* (independent pocket tables), not that they exist.
- **Tests stay under `tests/`.** No co-located `*.test.gd`. GPU captures remain a scene, not a headless script.

## Architectural Patterns

### Pattern 1: Composition contract as typed Resource

**What:** One `class_name WorldCompositionContract extends Resource` owns districts, landmarks, routes, pockets, camp, and resource placements. Nested Resources, `@export`, `_init` defaults so the Inspector can construct them. WorldMap2D `preload`s the `.tres` (or takes `@export var composition: WorldCompositionContract`).

**When to use:** Any layout that must be deterministic, reviewable, and movable without rewriting builder logic. This milestone.

**Trade-offs:** Extra types vs today's inline arrays. Worth it: the inline arrays *are* the generated-scatter problem. JSON/CSV would fight `untyped_declaration = 2` and skip Inspector/type checks. Inner classes do **not** serialize in Godot 4.7 — each nested type needs its own `class_name` file.

**Example:**
```gdscript
class_name WorldCompositionContract
extends Resource
## Authored 14x14 place data. No physics, no RPC, no draw.

@export var layout_version: int = 1
@export var world_build_seed: int = 0xB35E7E
@export var camp_position: Vector2 = Vector2(9950.0, 2400.0)
@export var districts: Array[WorldDistrictDefinition] = []
@export var routes: Array[WorldRouteDefinition] = []
@export var resource_placements: Array[Vector2] = []  # 87 slots; 0..2 = teaching anchors

func _init(
	p_layout_version: int = 1,
	p_world_build_seed: int = 0xB35E7E,
	p_camp_position: Vector2 = Vector2(9950.0, 2400.0)
) -> void:
	layout_version = p_layout_version
	world_build_seed = p_world_build_seed
	camp_position = p_camp_position
```

### Pattern 2: Builder remains the authority node; contract is input

**What:** `BesprenWorldMap2D.ensure_built()` keeps the same sequence. It iterates contract landmarks into `_add_rectangle_obstacle` / `_add_circle_obstacle` instead of district-specific `_build_city()` coordinate dumps. Walkability, flow hash, and obstacle ordering stay in this node.

**When to use:** Always. GameWorld, TacticalBuild, scatter, and horde already talk to WorldMap2D.

**Trade-offs:** WorldMap2D stays large. Splitting builders into helper RefCounteds is fine; splitting *ownership* of `_obstacles` is not. Helpers must not keep their own obstacle lists.

**Example:**
```gdscript
func ensure_built() -> void:
	if _built:
		return
	_built = true
	var contract: WorldCompositionContract = _composition
	_build_biome_cells(contract)
	_build_ground_tile_map()
	_build_nature_tile_map()
	_build_road_network(contract.routes)
	background_decor.configure(PLAYABLE_HALF_EXTENT, WORLD_BUILD_SEED + 91)
	_build_landmarks(contract)          # was _build_city/_mall/_village_*
	_build_starting_camp_satellites(contract)
	_build_forest_from_contract(contract)
	ambient_scenery.call(&"configure", ..., contract.pockets_for(&"ambient"), ...)
	_build_world_boundaries()
	_bake_flow_field_mask()
	wilderness_accent.call(&"configure", ..., WORLD_BUILD_SEED + 173, ...)
	ground_cover.call(&"configure", ..., WORLD_BUILD_SEED + 211, ...)
```

Keep dress **after** obstacles + flow. That comment in `world_map_2d.gd:141-154` is load-bearing.

### Pattern 3: Pockets derived from layout, not twin-authored

**What:** Dress/salvage ellipses are either (a) fields on the contract next to the landmark they belong to, or (b) computed from `WorldObstacle2D.get_world_bounds()` + road-edge distance after obstacles exist. Never a second `WILDERNESS_POCKETS` table in `WorldAmbientScenery2D` that can overlap `OstariSouthShell`.

**When to use:** Any non-colliding density. Pocket 2 (`Vector4(2600, -2200, 700, 620)`) vs mall shell `(4850, -3150)` size `(6400, 1800)` is the recorded proof.

**Trade-offs:** Derived pockets cannot float in empty wilderness without a parent landmark — add an explicit wilderness *place* to the contract instead of a scavenged ellipse. `MAXIMUM_UNHOSTABLE_POCKETS = 1` stays a tripwire until the layout pass edits obstacle + pocket together.

### Pattern 4: Independent dress seeds for micro-variation only

**What:** Keep `WORLD_BUILD_SEED + 91/137/173/211`. Use them for flip/slip/wobble, kind pick, and ground-cover jitter *inside* an authored pocket. Do not use them to decide *whether a place exists*.

**When to use:** Fence cadence, moss size, canopy yaw. Not camp location, not Ostari choke, not the 30-second loop.

**Trade-offs:** Authored composition is less "free density." That is the point. New visual layers still take a **new salt**. Never insert a roll into an existing sequential RNG a count-asserting gate pins.

### Pattern 5: Capture gate as the composition done-check

**What:** A place is done when a stranger can point at it in a 480×270 Mobile/Vulkan capture, judged against a measured noise floor. Headless 169 proves counts/hashes; it cannot prove "named landmark."

**When to use:** After every layout or dress change that moves pixels. After camp moves — the gate reads `STARTING_CAMP_POSITION` live; stale PNGs of `(11264, 1536)` prove the previous build.

**Trade-offs:** Fourteen of twenty-five frames move from shader `TIME`. Camp frames can move 5,912 / 21,799 pixels between identical runs. Tree claims belong on `forest_density` (zero between-run delta). Difference probes pause the tree, pin `pulse_speed`, hide `TIME` materials. Pause does not stop shader `TIME`.

## Data Flow

### Request Flow (runtime — unchanged)

```
StartMenu._launch()
    ↓ instantiate game_world.tscn + configure_launch()
GameWorld._ready()
    ↓ world_map.ensure_built()          # contract → biomes → roads → obstacles → flow → dress
    ↓ resource_scatter.configure_world_map + ensure_scattered()
    ↓ session.set_motion_resolver(...)  # still GameWorld._resolve_authoritative_motion
CoopSession 20 Hz
    ↓ rpc_id(1) intents
    ↓ host: TacticalBuild.resolve_player_motion → WorldMap2D.resolve_player_motion
    ↓ broadcast Vector2 snapshots
src/visual + src/feedback
    ↓ report only (no health / yield / occupancy / position writes)
```

### Composition Flow (this milestone)

```
Phase 0  Audit markdown + 25-capture census + noise floor
              ↓  no src/world/ layout edits
Phase 1  WorldCompositionContract.tres  (district jobs, named places, loop beats)
              ↓  validation reads contract against CURRENT world (expect mismatches)
Phase 2  WorldMap2D + Scatter consume contract
              ↓  collision, flow hash, LAYOUT_VERSION, camp, roads, 87 IDs
Phase 3  Dress pockets from contract / obstacle bounds
              ↓  independent seeds untouched; duplicated pocket tables deleted
Phase 4  Visual lift (shaders, actors, camp, HUD, VFX) on the new places
              ↓
tests/world_map_validation.gd     counts, z-matrix, flow hash, seed identity
tests/world_render_validation.tscn cameras aimed at named contract places
              ↓  two identical runs = noise floor; 1× verdict = done
```

### State Management

There is no world-state store and none should appear.

- **Simulation state** lives on peer one: player Vector2, scatter availability, shared pool, day/night, horde. Clients interpolate.
- **Layout data** is immutable after `ensure_built()`. Base relocation calls `set_core_position` and rebakes flow only.
- **Presentation** listens to signals. Dress layers never write `_obstacles` or `_flow_field_blocked`.

### Key Data Flows

1. **Contract → biomes:** District cell ranges fill `_biome_cells`. Extents stay 14×14 / ±14336. `get_biome_regions()` returns contract names (Kaupunki / Ostari / Kylät / Metsä) so HUD/minimap labels and capture metadata share one vocabulary.

2. **Contract → roads → dress clearance:** `WorldRoadNetwork2D.configure(routes, dirt_flags)`. `get_minimum_road_edge_distance` remains the Callable dress and density trees use. Camp keeps a declared road-edge floor (today 1600 / measured 2098). Changing routes without updating that floor re-opens the secluded-camp contract.

3. **Contract → obstacles → broadphase → motion:** Each landmark becomes one `WorldObstacle2D` on `WorldStatic`. `_obstacle_broadphase_ready = false` on add. `is_position_walkable` stays the 512-unit grid with `clearance * sqrt(2)` pad. Linear scan is forbidden on the 20 Hz path.

4. **Obstacles → flow mask → horde:** `_bake_flow_field_mask()` after all colliding geometry. `get_flow_field_mask_hash()` is the dress-did-not-touch-nav proof. Visual canopy at z=-4 must not be mistaken for the walk grid.

5. **Contract → scatter:** 87 IDs remain. Positions come from the contract (three teaching anchors + 84 authored salvage slots). `_is_valid_candidate` still requires walkability + 96 clearance + 300 spacing so a bad contract fails loudly. `LAYOUT_VERSION` increments; late-join snapshots reject mismatch. Gather rules (3–5 steps, zero intermediate yield, one-unit finish) do not change.

6. **Contract → capture cameras:** `world_render_validation.gd` currently hardcodes `CityScrapPile_00`, `OstariNorthShell`, etc. After re-author, cameras must be named places from the contract (`camp`, `road_home`, `landmark_X`, `salvage_pocket_Y`, `threat_Z`) so the 30-second loop is a capture sequence, not a comment.

## Scaling Considerations

This is one 28,672-unit LAN arena, not a user-count problem. Scale is **content and tick cost**.

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Current slice (~461 obstacles, 640 ambient, 1,100 decor, 38,947 cover elements, 87 nodes, 110 horde cap) | Keep 512-unit broadphase, chunked dress (4096), material-less ground cover, one weather pass. Do not triple cover clusters. |
| Authored unique set pieces (more distinct landmarks, fewer stamps) | Prefer fewer, larger `WorldObstacle2D` records with unique atlas frames over more RNG instances. Unique frames cost atlas pages, not tick time. |
| Dress budget creep | New density = new seed offset + chunk. Cap by zone counts the world-map gate pins. Ambient at z=-4 never becomes collision. |
| Capture set growth | Add cameras only for named loop beats. Measure noise floor on the new names. Do not keep TIME-noisy camp frames as evidence for tree/dress diffs. |

### Scaling Priorities

1. **First bottleneck:** `is_position_walkable` on the 20 Hz authority tick (measured 209.9 µs linear vs 3.8 µs grid over 461 obstacles). Authored landmarks that inflate obstacle count must keep the broadphase. Do not revert to a scan.
2. **Second bottleneck:** Overdraw + light Z at 480×270 Mobile. Terrain is z=-20; lights need `range_z_min = -20`. Zero shadow-casting 2D lights. Unique set pieces are atlas frames, not extra `PointLight2D`s or a second full-screen pass.
3. **Third bottleneck:** Capture TIME noise hiding real diffs. Done-check is two identical runs, then 1× review — not "PNG exists."

## Anti-Patterns

### Anti-Pattern 1: Parallel world system

**What people do:** Add `WorldComposer2D` / `AuthoredMap2D` beside `%WorldMap2D`, or a new scene that GameWorld swaps in.
**Why it's wrong:** Motion, flow, scatter, Base relocation, and 169-check gate all bind to `BesprenWorldMap2D`. Two owners of obstacles desync host positions from what the player sees.
**Do this instead:** One builder. Contract in, same `ensure_built()` out.

### Anti-Pattern 2: Autoload map registry

**What people do:** `WorldRegistry` autoload so HUD, scatter, and dress `WorldRegistry.camp` from anywhere.
**Why it's wrong:** Bespren forbids production autoloads. Godot's own guidance: autoloads create global state and hide bug sources. Camp is already a constant on the map class; after the contract, it is `world_map.get_core_position()` / contract field.
**Do this instead:** NodePath / unique-name `%WorldMap2D`. HUD already talks through GameWorld signals.

### Anti-Pattern 3: Presentation writes simulation

**What people do:** Dress layers spawn `StaticBody2D`, scatter views decide yield, shaders own occupancy, or "fix stuck player" by shrinking a sprite.
**Why it's wrong:** Clients would diverge. Canopy at z=-4 is already visually over roads the flow field treats as open. CLAUDE.md 7: feedback never decides the sim.
**Do this instead:** Collision first, sprite second. `WorldObstacle2D` comment is a contract. Grep collision/flow before any visual scale change (trees fit long edge to `collision_radius * 4.35` — a shorter crop draws larger at the same blocker).

### Anti-Pattern 4: Twin-authored pocket vs obstacle tables

**What people do:** Keep `CITY_POCKETS` / `WILDERNESS_POCKETS` in scenery and a separate mall shell in WorldMap2D. "Fix" overlap by moving the pocket so a review card fits.
**Why it's wrong:** Pocket 2 is unhostable under Ostari. Moving it changes ambient determinism and world-map counts. `MAXIMUM_UNHOSTABLE_POCKETS = 1` is a tripwire, not a quota to fill.
**Do this instead:** One contract. Layout pass edits both. Gate records unhostable pockets; it does not silently relocate them.

### Anti-Pattern 5: Sector RNG as "authored salvage"

**What people do:** Keep `_placement_for`'s 12×7 `randf_range` and call it composition because the seed is fixed.
**Why it's wrong:** Deterministic scatter is still scatter. The 30-second loop needs named salvage pockets a capture can point at. 84 global sectors will not read as Ostari choke vs village quiet.
**Do this instead:** Contract positions. Keep 87 IDs, 3–5 step rules, and walkability rejection. Increment `LAYOUT_VERSION`.

### Anti-Pattern 6: World-authoring code before the contract

**What people do:** Start moving camp/roads in `world_map_2d.gd` while the audit is still a chat.
**Why it's wrong:** PROJECT.md Active requirement 1: audit/analyze/discuss/write the redesign contract **before** world-authoring code. Layout is OPEN; without a contract, every coordinate is another seed.
**Do this instead:** Phase 0 markdown + capture census. Phase 1 `.tres` that the current world *fails* against. Then code.

### Anti-Pattern 7: Capture without noise floor; stale PNG as proof

**What people do:** Diff one `world_forest_camp_validation.png` and ship. Or trust on-disk frames after camp moved to `(9950, 2400)`.
**Why it's wrong:** Eleven frames are stable; fourteen are not. Camp TIME deltas exceed some real art diffs. Windowed Godot returns 960×540, not 480×270.
**Do this instead:** Two identical runs. Judge trees on `forest_density`. Derive scale from the PNG. Re-run GPU after camp/atlas/layout moves. 1× review is a verdict, not a deferral.

### Anti-Pattern 8: Fold visual AAA+ into the map builder

**What people do:** Put actor rebakes, HUD, VFX, and shader grade into `ensure_built()`, or delay layout until every surface is lifted.
**Why it's wrong:** Map composition is the load-bearing failure. Other surfaces lift **on** the new places. Mixing them hides whether a capture failed because Ostari moved or because a shader squared `COLOR`.
**Do this instead:** Layout + dress first. Then camp/structures/actors/HUD/VFX against named cameras. Shader rules stay (`blend_mix`, `vec4 source = COLOR;`, `fwidth` outlines, one weather pass).

### Anti-Pattern 9: Promote forbidden atlas frames to "add unique set pieces"

**What people do:** Wire wild roots/shrubs or the unused salvage atlas because the packer succeeded.
**Why it's wrong:** `runtime_promotion = forbidden_pending_human_visual_veto`. Roots read as tan boulders at 1×. Salvage has no `src/` consumer.
**Do this instead:** Unique set pieces are new authored landmarks with reviewed frames. Five `WILD_TREE_REGIONS` only until a 1× veto passes.

## Integration Points

### External Services

None at runtime. Offline only:

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Blender 5 workshops | Python renderers → PNG → Godot atlas packers | Behind `.gdignore`. No Node3D/GLTF/PBR ships. |
| Poly Haven CC0 / Kenney / Atomic Realm | Existing atlas families | Atomic Realm frames stay embedded; no asset-pack redistribute. Salvage atlas remains reserve. |
| Godot 4.7.1 Mobile / Vulkan | `ensure_built` + GPU captures without `--headless` | Desktop pixels ≠ Android device gate (out of this milestone). |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| GameWorld ↔ WorldMap2D | Unique-name child, `ensure_built()`, motion Callable | Do not add signals for layout. Layout is build-once. |
| GameWorld ↔ ResourceScatter2D | `configure_world_map` then `ensure_scattered` | Scatter reads walkability; does not own obstacles. |
| WorldMap2D ↔ dress layers | `configure(..., Callable is_position_walkable, Callable get_minimum_road_edge_distance)` plus contract pockets | Dress must not mutate those Callables. |
| WorldMap2D ↔ TacticalBuildSystem | `set_core_position` on relocate; composed `resolve_player_motion` | Camp may move; RPC boundary unchanged. |
| WorldMap2D ↔ FlowFieldNavigation2D | Baked 112×112 mask | Hash is the "dress did not touch nav" evidence. |
| Scatter / Build / Horde ↔ CoopSession | Existing reliable RPCs to peer 1 | No new world RPCs. Clients never submit layout. |
| `src/visual` / `src/feedback` ↔ simulation | Typed signals only | No occupancy, yield, or authoritative position. |
| Contract Resource ↔ validation | Headless reads `.tres`; GPU cameras named from it | Pin layout_version + seed. Do not pin pixel SHA of TIME-noisy frames. |

## Suggested Build Order (roadmap input)

Audit/contract **before** any world-authoring code. Then layout. Then dress. Then other visual surfaces. Capture gates are the done-check, not a polish pass.

| Phase | Work | Touches | Done when | Avoids |
|-------|------|---------|-----------|--------|
| **0 Audit** | Census of current places vs 30s loop. 25-capture noise floor. Name failures: scatter, district jobs, 1× readability. Write redesign contract markdown. | `docs/` only. **Zero** `src/world/` layout edits. | Contract names districts, landmarks, routes, salvage pockets, camp, way-home silhouettes. | Coding coordinates from taste. |
| **1 Contract Resource** | `WorldCompositionContract` + nested types. `.tres` filled from the audit. Validation that **loads** it and reports drift vs live map. | `src/world/*_definition.gd`, `data/world/`, test that does not yet require the live map to match. | Inspector-roundtrip `.tres`; typed arrays; no autoload. | JSON dumps, inner classes, GameWorld rewrite. |
| **2 Layout** | WorldMap2D + roads + obstacles + camp + scatter consume the contract. Extents stay 14×14. `LAYOUT_VERSION++`. Refresh `STARTING_CAMP_POSITION` consumers (`CoopSession` spawn, teaching anchors, satellites). | `world_map_2d.gd`, `resource_scatter_2d.gd`, `world_map_validation.gd`. Not GameWorld/CoopSession structure. | 169-check updated to new counts/hash. Flow hash stable for a given `.tres`. Broadphase still on. | Parallel builder; linear walk scan; gather-rule changes. |
| **3 Dress** | Delete duplicated pocket tables. Feed contract/derived pockets. Independent seeds kept. Fence/canopy remain presentation-only. | dress quartet, wild-context gate (`unhostable` tripwire). | Dress cannot host a pocket inside a colliding shell. Zone counts pinned. | Moving pocket 2 to please a card; promoting forbidden wild frames. |
| **4 Capture re-aim** | Point the 25 cameras at named loop beats. Measure noise floor again. 1× verdict: camp, road, landmark, salvage, threat, way-home. | `world_render_validation.gd/.tscn`, `artifacts/`. | Stranger can point without labels. TIME-noisy frames not used as dress evidence. | Stale PNGs; 960×540 assumed as 1×. |
| **5 Visual lift** | Terrain/prop/foliage/structure/lighting/actor/camp/HUD/VFX/shaders **on the new places**. Same mobile budgets. | `shaders/`, `src/visual`, `src/feedback`, offline bake tools. | Surfaces pass existing focused gates; no second full-screen pass; `vec4 source = COLOR;`. | Folding juice into WorldMap2D; HDR 2D; shadow-casting lights. |

**Phase ordering rationale**

- Contract without audit is fiction. Layout without contract is more scatter.
- Dress before layout re-opens pocket-vs-shell overlap.
- Visual lift before named places makes captures unreadable as evidence (you cannot tell shader grade from Ostari choke).
- Capture re-aim sits with or immediately after dress: cameras must look at the new landmarks, but the noise-floor method is the done-check for phases 2–5, not a substitute for headless 169.

**Research flags for later phases**

- Phase 0–1: Standard for this repo (measurement culture already in CLAUDE.md). Unlikely to need extra ecosystem research.
- Phase 2: Likely needs a **flow-field / spawn-lane pass** once camp and Ostari choke move — horde integration target follows `set_core_position`, but teaching-resource offsets and co-op spawn ring are literals today.
- Phase 3: Likely needs **pocket derivation math** (ellipse from oriented AABB + road clearance) — do not invent per-family magic radii.
- Phase 4: Noise-floor method is known; new camera list is design, not research.
- Phase 5: Fir canopy density and wild non-tree veto remain open art problems; do not "solve" them in the map builder.

## Capture Gates as Done-Check

`tests/world_render_validation.tscn` writes 25 Mobile/Vulkan frames at logical 480×270. It is the composition acceptance test once cameras name places.

**Method (already recorded in CONCERNS / CLAUDE.md — keep it):**

1. Run the GPU scene twice on unchanged code. Eleven stable frames (`central_road_shoulder`, `city_barrier` day/night, `city_building_detail`, `city_density`, `city_salvage`, `east_village`, `forest_density`, `forest_log`, `forest_rock`, `local_car_wreck`, `mall`) are the only ones that can certify dress/layout. The other fourteen move from shader `TIME` (resource pulse, camp `AmberLight`/aura, actor frames).
2. After a layout change, re-run. A capture set that still shows camp at `(11264, 1536)` is invalid.
3. Aim cameras from the contract: camp, home-road, each named landmark, each salvage pocket, each threat approach. The 30-second loop is a **sequence of frames**, not a paragraph in PROJECT.md.
4. 1× review is a verdict. "Looks better at 3×" is not evidence.
5. Difference probes: pause SceneTree, pin `pulse_speed = 0`, hide other `TIME` materials. Pause does not stop shader `TIME`. Mask on source alpha, not composite. Derive scale from the PNG (windowed runs are 960×540 under the project override).
6. Headless `WORLD MAP VALIDATION OK` proves grid, extents, z-matrix, seeds, counts, flow hash. It does **not** prove named-place readability. Both gates must pass; neither substitutes for the other.

## Locked Constraints (do not "improve")

- No autoloads. No folding presentation into authority.
- No GameWorld / CoopSession redesign. No new world RPC. Clients never submit layout.
- Extents 14×14, 2048-unit cells, ±14,336. Flow 112×112 @ 256. Broadphase 512 with `sqrt(2)` pad.
- `WORLD_BUILD_SEED` `0xB35E7E` remains the dress-salt root unless the contract explicitly versions a new seed together with `LAYOUT_VERSION`.
- One full-screen custom pass. HDR 2D off. Zero shadow-casting 2D lights. Zero dynamic shader loops. No runtime Node3D.
- Identity redundant across hue, silhouette, iconography, placement.
- `Addons/` vault: no destructive cleanup.

## Sources

**Project (HIGH — live code 2026-09-18):**

- `.planning/PROJECT.md` — visual AAA+ & map redesign; audit before world-authoring code
- `.planning/codebase/ARCHITECTURE.md` — locked GameWorld composition, world layout path, z-matrix
- `.planning/codebase/CONCERNS.md` — pocket 2 vs Ostari, capture TIME noise, presentation/collision drift
- `.planning/codebase/CONVENTIONS.md` — Resources not autoloads; dress presentation-only; new density = new salt
- `.planning/codebase/TESTING.md` — smoke 207, world map 169, world render 25 captures
- `src/world/world_map_2d.gd` — `ensure_built()` order, seed, camp `(9950, 2400)`, district builders
- `src/world/resource_scatter_2d.gd` — 87 IDs, `LAYOUT_VERSION = 2`, 12×7 sector RNG to replace
- `src/world/world_ambient_scenery_2d.gd` — duplicated pocket tables
- `src/world/world_obstacle_2d.gd` — collision canonical, sprites presentation-only
- `src/game/game_world.gd` — `ensure_built` then scatter; motion resolver
- `tests/world_render_validation.gd` — 25 hardcoded cameras
- `docs/WORLD_MAP_FOUNDATION.md` — spatial contract (counts in this doc are stale vs live 640 scenery / 169 checks; code wins)

**Godot 4.7 official (primary docs; seam tagged webfetch LOW):**

- [Resources](https://docs.godotengine.org/en/4.7/tutorials/scripting/resources.html) — custom Resource + `class_name`, nested sub-Resources, `.tres`, `_init` defaults, inner classes do not serialize
- [Resource class](https://docs.godotengine.org/en/4.7/classes/class_resource.html) — data container, Inspector, `emit_changed`
- [When and how to avoid using nodes for everything](https://docs.godotengine.org/en/4.7/tutorials/best_practices/node_alternatives.html) — Resource over Node for authored data
- [Autoloads versus regular nodes](https://docs.godotengine.org/en/4.7/tutorials/best_practices/autoloads_versus_regular_nodes.html) — prefer `class_name` + Resource; autoloads are global state
- [CanvasItem](https://docs.godotengine.org/en/4.7/classes/class_canvasitem.html) — `z_index` default 0, `z_as_relative` default **true**; absolute matrix requires `false`
- [2D lights and shadows](https://docs.godotengine.org/en/4.7/tutorials/2d/2d_lights_and_shadows.html) — light Range Z Min/Max; additive sprites cheaper than extra lights; shadows are a budget exception Bespren does not take

---
*Architecture research for: Bespren authored-place 2D world-map composition*
*Researched: 2026-09-18*
