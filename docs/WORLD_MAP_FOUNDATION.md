# Bespren 14x14 World Foundation

This document is the implementation contract for the centered 2D world assembled by `BesprenWorldMap2D`.

## Spatial contract

- Macro grid: `14 x 14`
- Macro cell: `2048 x 2048` world units
- Playable bounds: `Rect2(-14336, -14336, 28672, 28672)`
- Initial forest refuge: Base Camp at `(9950, 2400)` inside east-forest macro-cell `(11, 8)`; center-to-nearest-road-edge clearance is exactly `2098` units
- Flow-field raster: `112 x 112` cells at `256` world units per cell

The authored tactical regions use zero-based inclusive macro-cell ranges:

| Region | Cells | Purpose |
|---|---|---|
| Kaupunki | columns 1-5, rows 1-5 | Dense non-enterable urban shells, cracked asphalt, rusted wrecks |
| Ostari | columns 7-10, rows 2-5 | Collapsed commercial wings with a narrow east-west passage |
| West village | columns 1-4, rows 9-12 | Timber homesteads and broken fence gaps |
| East village | columns 9-12, rows 9-12 | Separate homestead cluster and fence rhythm |
| Metsä / Luonto | perimeter plus northeast and western belts | Pine-like canopy clusters, mossy rocks, wilderness ground |

The road graph contains a central asphalt cross, a Kaupunki spine, an Ostari branch, village dirt branches, and a connected wilderness perimeter route. All road and terrain drawing remains on the absolute ground pass. The complete Base footprint, four spawn approaches, three teaching resources, and bedding/supply/medical satellites all retain at least `1600` units from every road edge; the tightest measured derived-content clearance is `1612.907` units.

## Rendering matrix

| Content | Absolute Z | Y-sort policy |
|---|---:|---|
| `GroundTiles`, `TerrainTiles`, `RoadNetwork` | `-20` | Disabled |
| Non-colliding cracks, moss, rubble, scrap | `-5` | Disabled |
| Visual-only ruin, canopy and prop groups | `-4` | Disabled |
| Static structural obstacles | `5` | Nested below the gameplay Y-sort hierarchy |
| Base Core, resources, players, future towers | `5` | Parent containers explicitly enable Y-sort |

Every absolute pass sets `z_as_relative = false`. This prevents an instanced scene or future parent offset from silently changing the matrix.

Road segments are subdivided into bounded CanvasItems no longer than 4,096 units. `WorldBackgroundDecor2D` groups 1,100 deterministic ground decorations into the same regional grid: 300 rubble marks, 160 cracks, 220 moss patches and 420 props. The regional totals are Kaupunki 265, Ostari 193, West village 116, East village 116, forest 286 and connectors 124; the prop stream includes exactly 75 benches, 46 hydrants and 34 barrel stoves. `WorldAmbientScenery2D` adds 576 collision-free large silhouettes at absolute z=-4: 96 city, 72 mall, 48 west-village, 48 east-village, 172 forest, 92 wilderness and 48 connector groups. Its 4,096-unit chunk grid uses padded culling bounds no wider than 5,500 units, keeps a 1,760-unit camp clearing and road-center margins, and never changes physics, flow masks, resources or host-authoritative state. Forest macro-cells also retain their deterministic colliding canopy stands and fallen logs.

The current environment presentation is a four-family offline 2D bake system. Twelve Poly Haven-derived CC0 nature/prop frames supply rocks/stumps, dead trunks, trash cans, tyres, and selected concrete barriers. Sixteen local Blender-baked frames from 29 reviewed GLBs supply four city-ruin composites, mall and industrial shells, separate west/east village houses, vehicle and roadside obstacles, wooden barricades, salvage, utility poles, and three camp satellites. The Hidden Alley family adds eight 384×384 frames from eight CC0 1k GLTF models; its 1536×768 atlas has SHA-256 `a73801d26937c0e2c958895c3817b9c9bc101958743b8ec23a73dea6f8242161`, a measured luma floor of `65.967`, and frame margins of at least `30` pixels. Exactly 16 of those sprites polish existing colliding city, Ostari mall, village, vehicle, and camp obstacles while preserving their canonical footprints. Four additional Poly Haven CC0 terrain sources are packed into one seamless terrain atlas and blended through a 224×224 organic biome mask. No source mesh or `Node3D` enters runtime; the terrain remains one non-colliding ground overlay. See `WORLD_MAP_VISUAL_PRODUCTION_PLAN.md` for exact regional allocation, provenance, shader policy, and mobile budgets.

## Collision and flow-field contract

`WorldObstacle2D` is the single obstacle definition used by all three consumers:

1. It is a `StaticBody2D` on the named `WorldStatic` physics layer.
2. It installs a simplified `CollisionShape2D` matching its rectangle or trunk/rock circle.
3. It exposes the same oriented footprint to `BesprenWorldMap2D` for flow-field rasterization and host motion resolution.

The four outer boundaries are also `StaticBody2D` rectangles. `CoopSession` does not trust client movement results: peer one calls the composed map/build resolver before committing and broadcasting each authoritative position. The resolver clamps the playable rectangle, performs axis-separated sliding against canonical terrain obstacles, and rejects overlap against every live placed-defense footprint. Remote avatars are collision-free presentation shells, so clients interpolate host snapshots without running a second divergent physics simulation. Replaceable movement and 20 Hz state use ordered-unreliable delivery; registration, lifecycle, interactions, and resource commits remain reliable.

## Resource scattering and USE

`BesprenResourceScatter2D` is a fixed-path RPC controller. It owns 87 deterministic resource IDs: three immediately readable teaching anchors beside the forest camp and one stratified spawn in each of 84 global sectors. A dedicated `RandomNumberGenerator` seed, obstacle rejection, 96-unit clearance, and 300-unit minimum spacing produce the same manifest on every peer.

Wood, Metal, and Tech alternate evenly and retain their exact semantic colors:

- Wood: `#FFD700`
- Metal: `#E0E0E0`
- Tech: `#00FFFF`

Their emissive shader pulses both fill and outline. Point lights use a neutral mask and are visibility-gated so off-screen scatter nodes do not keep mobile lights enabled.

The existing touch button remains the visible `[USE]` control and emits the existing `interact` command. A client never submits a resource ID, amount, or position. Peer one rate-limits interactions, uses its stored authoritative player position, selects the nearest available node within 260 units, applies one fixed harvest unit, and broadcasts the result. Commits and snapshots carry an explicit layout version, seed-derived SHA-256 layout identity, and monotonic state revision. Late-join/reconnect snapshots fully replace availability and inventories, can restore stale local depletion, and reject mismatched or older layouts before mutating a numeric resource ID.

## Validation gates

Run the focused gates with Godot 4.7.1 after import:

```powershell
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/world_map_validation.gd
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/polyhaven_environment_validation.gd
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/polyhaven_district_validation.gd
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/local_environment_validation.gd
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/terrain_material_validation.gd
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/resource_scatter_validation.gd
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/mobile_systems_validation.gd
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/smoke_test.gd
```

Run `tests/resource_enet_probe.gd` as one host process and one client process with `-- --role=host` and `-- --role=client`. The client sends only `interact`; both processes must report resource `0` depleted with inventory `1`. The original `tests/enet_peer_probe.gd` remains the independent movement/action regression probe.

The current focused evidence on Godot 4.7.1 is:

- `WORLD MAP VALIDATION OK (150 checks)`
- `POLY HAVEN ENVIRONMENT VALIDATION OK (36 checks)`
- `POLY HAVEN DISTRICT VALIDATION OK (58 checks)`
- `LOCAL ENVIRONMENT VALIDATION OK (47 checks)`
- `TERRAIN MATERIAL VALIDATION OK (35 checks)`
- `RESOURCE SCATTER VALIDATION OK (72 checks)`
- `COOP HARDENING OK (28 checks)`
- `MOBILE SYSTEMS OK (54 checks)`
- `TACTICAL HUD OK (42 checks)`
- Current smoke run: one unresolved east-camp flow-direction assertion; do not treat it as green
- `RESOURCE ENET HOST OK` and `RESOURCE ENET CLIENT OK` on desktop loopback

`tests/world_render_validation.tscn` is the GPU gate. It writes twenty-three captures to `res://artifacts/`: overview; Kaupunki and Ostari districts; camp and camp-satellite composition by day/night; city salvage; city barrier day/night; forest rock and log; city-building detail; long Ostari shell; west/east villages by day; west village night; local car wreck; city-to-forest terrain transition; central road shoulder; and city, forest and wilderness density views. The refreshed metadata records `mobile`, Vulkan, `480 x 270`, `28672 x 28672`, the final `(9950, 2400)` camp camera and all 23 outputs. `WORLD MAP VALIDATION OK (150 checks)` proves the exact 1,100-ground-mark and 576-silhouette allocation, collision-free ambient contract, chunk bounds and retained map collision; `RESOURCE SCATTER VALIDATION OK (72 checks)` proves resources remain deterministic and legal. The focused Poly Haven nature, Hidden Alley district, local-environment and terrain validators cover provenance, atlas regions, shared materials, filtering, no-3D, named visual composition and retained collision.

Headless and desktop GPU evidence do not certify Android thermals, physical multitouch ergonomics, cutout handling, or two-device LAN behavior. Those remain device gates.
