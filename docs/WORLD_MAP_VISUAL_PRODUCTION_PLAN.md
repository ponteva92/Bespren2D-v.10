# World Map Visual Production Plan

This is the production record and forward plan for Bespren's authored 2D tactical world. It describes what the current implementation actually builds, which gameplay contracts are frozen while the art changes, how source assets become mobile-ready sprites, and which visual and device gates remain open.

## Implemented world blueprint

The map is a centered `14 x 14` macro-grid. Each macro-cell is `2048 x 2048` world units, producing the exact playable rectangle `Rect2(-14336, -14336, 28672, 28672)`. All cell references below are zero-based and inclusive.

| Region identity | Macro-cells | Authored landmarks and traversal character |
|---|---|---|
| Kaupunki | columns 1-5, rows 1-5 | Six large ruin footprints, five wreck footprints, six scrap clusters, an asphalt spine, block-to-block sightline changes, and dense hard-surface debris pockets |
| Ostari | columns 7-10, rows 2-5 | Two long commercial footprints with full-footprint foundations and four alternating baked modules each, two pylons, a collapsed truck, and a deliberately narrow east-west salvage passage |
| West Kylä | columns 1-4, rows 9-12 | Four timber homesteads, six broken-fence footprints, five utility poles, and a dirt approach with open yard rhythm |
| East Kylä | columns 9-12, rows 9-12 | A separate four-house silhouette family, six fence footprints, five utility poles, and its own dirt approach |
| Metsä / Luonto | perimeter, northeast forest and western wilderness belts | Imported canopy variants, twelve authored rock/stump footprints, deterministic mixed-age stands, fallen trunks, moss pockets, and the secluded starting clearing |
| Connectors | shoulders between the named regions | Sparse roadside salvage, cracks, moss and props that visually join districts without filling the navigation centerlines |

The road graph contains exactly eight authored routes: the central east-west and north-south asphalt cross, the Kaupunki spine, the Ostari branch, two village dirt branches, the wilderness perimeter loop, and the northeast dirt branch. The asphalt and dirt routes share topology but remain visually distinct through separate widths, edge treatments, lane marks, ruts and surface breaks.

## Frozen gameplay and authority contracts

Visual production may replace presentation, but it must not silently change these contracts:

- `BesprenWorldMap2D.WORLD_BUILD_SEED` and the authored obstacle creation order remain deterministic.
- The playable extent, `14 x 14` macro-grid, `2048`-unit macro-cell, and secluded Base Camp start at `(9950, 2400)` remain exact. The camp center stays `2098` units from the nearest road edge, and all complete Base/spawn/resource/satellite footprints stay at least `1600` units from every road edge.
- Every structural obstacle remains a `StaticBody2D` on `WorldStatic` with its canonical rectangle or circle `CollisionShape2D`.
- The same obstacle footprint remains the source for physics overlap, host motion resolution, spawn rejection, and the `112 x 112` flow-field mask at `256` units per cell.
- Peer one remains authoritative. Clients submit movement intent or the existing action command, never a trusted final position, resource ID, harvest amount, collision result, or world-layout mutation.
- Placed-defense collision remains composed with the static-map resolver, so a visual tower change cannot reintroduce player traversal through towers.
- The 87 resource identities remain three teaching anchors plus 84 seeded global-sector spawns. Their layout version, stable IDs, depletion revision and host-selected gather target are gameplay data, not decoration data.
- No Blender object, Poly Haven GLTF, local source GLB, `Node3D`, PBR material, or authoring light enters the shipping runtime. The game consumes only the derived 2D textures and manifests.

Any later landmark or road-footprint change therefore requires an explicit gameplay-layout revision, new flow/resource evidence, and a network compatibility decision. Pure sprite, shader, palette and non-colliding decor improvements can iterate without changing that version.

## Layered 1,676-mark world composition

`WorldBackgroundDecor2D` creates exactly 1,100 non-colliding ground marks: 300 rubble shapes, 160 cracks, 220 moss patches and 420 props. They are allocated by district intent rather than one world-wide random scatter.

| Zone | Rubble | Cracks | Moss | Props | Zone total |
|---|---:|---:|---:|---:|---:|
| Kaupunki | 115 | 52 | 16 | 82 | 265 |
| Ostari | 65 | 40 | 18 | 70 | 193 |
| West village | 24 | 15 | 25 | 52 | 116 |
| East village | 24 | 15 | 25 | 52 | 116 |
| Forest | 32 | 18 | 110 | 126 | 286 |
| Connectors | 40 | 20 | 26 | 38 | 124 |
| Exact total | 300 | 160 | 220 | 420 | 1,100 |

The 420-prop budget draws from nine deterministic prop types: shrubs, broken roots/branches, atlas-baked abandoned tyres, barrel tops, bones/antlers, mushroom/toxic growth clusters, and Hidden Alley street benches, fire hydrants, and barrel stoves. The furniture mix is exactly 75 benches, 46 hydrants, and 34 stoves. Forest, village, urban, and connector zones retain separate deterministic pools. The shared `sleek_canvas_grade.gdshader` grades each regional decor batch as one CanvasItem rather than creating hundreds of unique materials.

`WorldAmbientScenery2D` adds exactly 576 large, visual-only silhouette groups above the ground marks and below gameplay entities: 96 city, 72 mall, 48 west-village, 48 east-village, 172 forest, 92 wilderness and 48 connector groups. It draws local city/village ruins, Claw tree clusters, Poly Haven rocks/logs/trash/barriers, vehicles and fences from the approved 2D atlases. These groups never create a physics body, collision shape, flow-field blocker, resource-state mutation or network message.

### Negative space and camp rules

Ground decor is sampled into deliberate elliptical pockets: seven in Kaupunki, seven around Ostari, six in each village, thirteen around the forest perimeter, and seven along connectors. Ambient scenery uses additional district, forest, wilderness and road-shoulder pockets so normal gameplay cameras read layered ruins, trees and props rather than large empty fields.

Every candidate also obeys these implemented exclusions:

- a `1360`-unit clear radius around the camp;
- eighteen landmark exclusion rectangles covering principal building, mall and village footprints;
- a `320`-unit world-edge margin;
- road-center clearance of `350` units for moss, `380` for props, `390` for rubble and `410` for cracks;
- connector marks remain on the road shoulder and are rejected beyond `1450` units from a route;
- within-category minimum separation of `72` units for rubble, `118` for crack starts, `105` for moss and `132` for props.

The colliding forest builder independently protects a `720`-unit inner camp clearing when it adds mixed-age trees and fallen logs. The ambient pass independently preserves a `1760`-unit camp clearing, a `480`-unit road-center margin (`360` in connector shoulders), and a `340`-unit gap between large ruin/village silhouettes. Together these rules make the start read as a camp in a forest clearing, preserve immediate movement space, and stop visual noise from erasing roads or landmark silhouettes.

## Visual language and runtime asset families

### Terrain and roads

The six-biome `bespren_ground_atlas.svg` and licensed ClawAndBlade detail tiles remain compatibility layers, but their square macro presentation now yields visually to one full-world Poly Haven material overlay. `bake_polyhaven_terrain_materials.py` packs the reviewed CC0 IDs `aerial_asphalt_01`, `muddy_tracks`, `forest_leaves_02`, and `concrete_pavement_03` into a wrapped-gutter 1024 x 1024 atlas. A deterministic 224 x 224 biome mask applies bounded multi-frequency organic warp to the 14 x 14 blueprint, and `terrain_material_blend.gdshader` cross-fades both biome weights and source-cell edges using one lighting-responsive `Sprite2D`. The overlay remains fully 2D and responds to CanvasModulate plus local camp lights.

Road drawing is bounded, deterministic custom 2D geometry. Asphalt uses a dark petroleum outer shoulder, restrained gray-green inner lane, faint edges, low-saturation dashes and stable cracks. Dirt uses warm umber shoulders, muted brown centers, twin ruts, fine grain and stable surface breaks. Every authored segment is subdivided to a maximum of `4096` units while dash and break phase remains continuous across chunk boundaries. The focused terrain matrix now includes both the city-to-forest blend and central road shoulder.

### Poly Haven CC0 bake family

The dedicated Blender 5 workshop `tools/art/blender/bespren_map_asset_workshop.blend` contains six reviewed Poly Haven 1k GLTF sources: `tree_stump_01`, `dead_tree_trunk`, `rock_moss_set_01`, `metal_trash_can`, `concrete_road_barrier` and `old_tyre`. `render_polyhaven_environment_sprites.py` normalizes them through one orthographic top-down three-quarter camera, transparent film, Freestyle silhouettes, AgX midtones and a shared warm-key/cool-rim/fill rig.

The result is twelve `384 x 384` RGBA renders: one stump, one dead trunk, six rock silhouettes, clean and rusted trash cans, one concrete barrier and one tyre. `build_polyhaven_environment_atlas.gd` packs them in fixed order into a `1536 x 1152` atlas, crops runtime views to alpha-derived padded bounds, and records URLs, source IDs, CC0 status, source/render/workshop hashes and atlas regions in `polyhaven_asset_manifest.json`. `assets/licenses/polyhaven_cc0.md` is the local provenance note.

At runtime this family supplies rocks or occasional stumps, fallen logs, trash-can/tyre scrap clusters, selected concrete barriers and flat tyre decor. Existing obstacle collision and flow identities remain unchanged.

### Poly Haven Hidden Alley district family

The immutable Blender 5 source workshop `tools/art/blender/bespren_polyhaven_district_workshop.blend` contains exactly eight reviewed CC0 models imported as 1k GLTF: `modular_urban_apartments_facade`, `modular_factory_facade`, `modular_chainlink_fence`, `covered_car`, `exterior_aircon_unit`, `modular_street_seating`, `fire_hydrant`, and `barrel_stove`. It is the reproducible acquisition/source record; runtime does not open the workshop or any GLTF.

`render_polyhaven_district_sprites.py` renders one transparent 384 x 384 RGBA frame per model using the shared orthographic, Freestyle, AgX, and three-light discipline. `build_polyhaven_district_atlas.gd` packs all eight frames in fixed 4 x 2 order into `polyhaven_district_atlas.png` at 1536 x 768. The atlas SHA-256 is `a73801d26937c0e2c958895c3817b9c9bc101958743b8ec23a73dea6f8242161`; measured alpha-weighted frame luminance never falls below `65.967`, and the nearest source-frame edge margin is at least `30` pixels. `polyhaven_district_manifest.json` records all source URLs, CC0 status, workshop/renderer/generator hashes, alpha bounds, padded regions, coverage, luminance, and output hashes.

The runtime maps exactly 16 cropped, mipmapped, sleek-shaded district sprites onto existing colliding footprints: three urban apartment blocks, three factory blocks, two chainlink gates, two covered cars, four air-conditioner clusters, one camp bench, and one camp barrel stove. Their parents span Kaupunki, the Ostari mall, East Kylä, vehicle obstacles, and camp satellites. Separately, batched non-colliding decor draws exactly 75 street benches, 46 fire hydrants, and 34 barrel stoves inside the 420-prop/1,100-decoration budget. This adds silhouette variety without adding a runtime mesh, `Node3D`, new navigation footprint, or client-authoritative state.

### Local Blender bake family

The complementary local pipeline turns reviewed vault sources into one coherent environment family. `render_local_environment_sprites.py` imports only declared GLBs from Kenney Starter Kit City Builder and Atomic Realm Post-Apocalyptic Starter Pack, composes each requested subject, applies shared petroleum/rust/patina materials, and renders transparent `384 x 384` images with the same orthographic, Freestyle and AgX discipline.

`build_local_environment_atlas.gd` fills all sixteen cells of a `1536 x 1536` atlas:

- four distinct Kaupunki ruin composites;
- Ostari mall and industrial shell composites;
- separate west and east village houses;
- vehicle wreck, wood barricade and utility pole silhouettes;
- roadside salvage and roadside barrier composites;
- camp bedding, supply cache, and medical cache satellites.

The runtime maps those cropped frames onto existing city shells, mall shells, houses, wrecks, fences, utility poles, and three new collidable/Y-sorted camp satellites. Each long Ostari shell retains a dark full-footprint foundation and canopy, then composes four alternating mall/industrial modules plus a salvage accent; this prevents transparent gaps from making the collision footprint look empty. Long fences repeat bounded barricade segments. West and east houses use their separate atlas regions plus deliberate vertical silhouette correction (`0.74` west and `0.62` east after width fitting), keeping the top-down houses inside their authored footprints while preserving distinct profiles. Each village now also owns three asymmetric imported dressing obstacles. The local manifest records all 29 source GLBs, six license-evidence records, derived image hashes, alpha coverage, alpha-weighted luminance, padded atlas regions, render-script hash and workshop hash.

Kenney model sources are recorded as CC0 in the package README. Atomic Realm's included license permits edited project use but forbids repackaging, resale and redistribution. Its derived sprites must remain embedded in Bespren and must never be published as a stand-alone asset pack. `assets/licenses/local_baked_environment_sources.md` is the operational provenance record; upstream documents remain authoritative.

### Sleek material finish

Three shared CanvasItem shaders keep unrelated sources inside one art direction:

- `surface_weathering.gdshader` uses restrained rust, directional wood rot or patina islands, softened edge soot, cooler shadows and a small warm material sheen. Weathering enriches a surface without replacing its readable base value.
- `sleek_sprite_finish.gdshader` grades atlas sprites with controlled saturation/contrast, lifted deep shadows, a narrow dark silhouette, a low-strength regional accent and a restrained diagonal sheen. Forest and urban sprites share one cached material instance per family.
- `sleek_canvas_grade.gdshader` applies a cheaper shared cool-shadow/warm-highlight grade to each background-decor batch.

Imported environment sprites use cropped `AtlasTexture` views and `LINEAR_WITH_MIPMAPS`. The existing illustrated tree atlas remains nearest-filtered so its intended edge language is not blurred.

## Mobile rendering budget

The target remains a `480 x 270` logical landscape viewport using Godot's Mobile renderer. HDR 2D is disabled. The production policy is coherence and bounded overdraw rather than desktop-only effects.

| Budget area | Implemented constraint | Production gate |
|---|---|---|
| Runtime dimensionality | 2D nodes and textures only; authoring meshes are baked offline | Reject any `Node3D` or runtime source-GLB dependency |
| Atlas pressure | `1536 x 1152` Poly Haven nature, `1536 x 768` Hidden Alley district, and `1536 x 1536` local obstacle atlases; cropped views share textures | Profile memory and upload behavior on representative Android hardware |
| Static geometry | Simplified rectangle/circle collision; one canonical footprint per obstacle | Keep physics and flow masks aligned after any layout revision |
| Road draw scope | Each road CanvasItem covers no more than `4096` authored units | Verify off-camera culling and frame time on device |
| Decor draw scope | 1,100 ground marks use `4096`-unit batches; 576 large visual groups use the same chunk grid with up to `5500` units of padded culling bounds | Inspect batch count, overdraw and visibility on device |
| Texture filtering | Nearest for illustrated tiles/trees; linear mipmaps for Blender bakes | Inspect shimmer and small-scale legibility at gameplay zoom |
| Lights | Local presentation/resource lights are visibility-gated; night uses a readable blue-hour floor | Measure overlapping light cost and thermal behavior on device |
| Effects | No required full-screen bloom, 3D lighting or screen shake | Preserve silhouette, touch clarity and stable frame pacing |

Numerical Android frame-time, thermal, GPU-memory and fill-rate limits are not declared passed until captured on representative hardware. Desktop Vulkan evidence is a pixel-review gate, not a substitute for those measurements.

## Validation and capture matrix

| Concern | Deterministic or static gate | GPU evidence | Still open |
|---|---|---|---|
| Grid, biome cells, eight routes, Z matrix and bounds | `tests/world_map_validation.gd` | `world_overview_validation.png` | Physical-device readability at overview scale |
| Static collision, motion resolver and flow mask | `tests/world_map_validation.gd`, co-op hardening and smoke gates | Gameplay-scale district captures | Physical two-device movement/collision certification |
| Resource layout and host-only gather selection | `tests/resource_scatter_validation.gd`, `tests/resource_enet_probe.gd` | Resource visibility in gameplay views | Physical Wi-Fi late-join/reconnect behavior |
| Poly Haven manifest, atlas, shaders and retained collision | `tests/polyhaven_environment_validation.gd` | Forest rock/log, city salvage and day/night barrier captures | Android atlas memory, filtering and night readability |
| Hidden Alley district provenance, bake quality, exact placement mix, export closure, and retained collision | `tests/polyhaven_district_validation.gd` passes 58 checks | Final-state Kaupunki, Ostari, East Kylä, vehicle, camp, and furniture captures are not yet refreshed | Godot MCP capture refresh; Android atlas memory, filtering and night readability |
| Local baked atlas and district replacement family | `tests/local_environment_validation.gd` passes 47 manifest, license, atlas, material, collision and integration checks | Kaupunki detail, long Ostari shell, local wreck, west/east village day, west village night, and camp-satellite composition | Final-state capture refresh; Android atlas memory, filtering and readability |
| Road/terrain palette and stable detail | `tests/terrain_material_validation.gd` passes 35 provenance, blend, lighting, seam, filtering and no-3D checks | Overview, city-to-forest transition, and central road shoulder | Device shimmer, fill rate and low-brightness panel review |
| Night floor and local light hierarchy | day/night scene assertions | Camp day/night and barrier day/night pairs | Physical OLED/LCD black-level and outdoor-brightness review |

The refreshed density evidence is `WORLD MAP VALIDATION OK (150 checks)`, `RESOURCE SCATTER VALIDATION OK (72 checks)`, and `WORLD RENDER OK | method=mobile | driver=vulkan | captures=23`. Earlier asset-provenance gates remain the Poly Haven environment/district, local-environment and terrain-material validators. The current full smoke run is not green: its one failing assertion expects the initial east-camp approach cell to point left even after all `ForestStand_*` collision radii are removed from a diagnostic rebuild, so it is tracked separately from this visual-only density pass.

`tests/world_render_validation.tscn` now writes twenty-three `480 x 270` Mobile/Vulkan captures: the existing overview, district, camp, prop, day/night and terrain views plus dedicated city-ruin, forest-canopy and wilderness-density views. `world_render_validation.json` records the rendering method, driver, camera positions, zooms, named obstacle targets, density-view intent and output list. The refreshed normal-renderer evidence records `mobile`, Vulkan, the final `(9950, 2400)` camp camera and all 23 outputs.

## Remaining production work

The current four-family offline bake system is a coherent environment vertical slice, not a claim that every biome is content-complete. The next visual work should stay ordered and evidence-backed:

1. Review the refreshed camp, village, Kaupunki, Ostari and density Mobile/Vulkan captures on a physical `480 x 270` Android device.
2. Resolve the separate smoke flow-direction expectation around the east-camp approach before treating the broad smoke gate as green.
3. Profile atlas memory, draw calls, overdraw, local-light overlap, 60/30 FPS frame pacing and sustained thermals on representative low/mid-range Android hardware.
4. Certify safe areas, cutouts, multitouch occlusion, pause/background/resume and install lifecycle on physical devices.
5. Run a physical two-device LAN session covering forest spawn, resource depletion, tower collision, Base relocation, disconnect/rejoin and late state replacement.
6. Only after those gates, expand district landmarks or alter navigation footprints under an explicit layout-version change.

No runtime-visual change is complete merely because Blender rendered it or a headless scene loaded it. Completion requires provenance, deterministic integration, gameplay collision/authority preservation, a gameplay-scale pixel review, and—where mobile performance or ergonomics is involved—representative Android evidence.
