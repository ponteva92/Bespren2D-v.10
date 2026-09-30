# Bespren 2D Asset Pipeline

This project keeps source discovery, reviewed promotion, offline rendering, and shipping runtime data as separate stages. The separation is deliberate: `Addons/` remains an immutable source vault, while Android receives only reviewed 2D resources and their provenance records.

## Source-vault audit

`tools/asset_pipeline/deep_asset_audit.py` is the exhaustive evidence pass. It hashes and classifies all 31,404 physical files under `Addons/` and recursively inspects 4,684 members in 159 signature-detected physical or nested ZIP/gzip-tar containers. The evidence ledgers live in `artifacts/asset_audit/`; exact totals, evidence-file hashes, container boundaries, and the manual-review limitation are recorded in `docs/ADDONS_DEEP_AUDIT.md`.

The current `assets/runtime_asset_manifest.json` selects 12 runtime items from that vault: two ClawAndBlade terrain/tree textures, one projectile strip, four audio cues, and five required license records. The earlier castle selection is retired: it is absent from the current manifest, absent from `base_core.tscn`, and must not be added to export closure metadata.

## Broad generated catalog

The broad 2D catalog converts approved Claw and Blade, 0x72 Dungeon Tileset II, Admurin, and Aekashics sources into deterministic Godot 4.7 resources under `res://assets/2d/`. Its current source manifest records 3,882 image records and 3,192 production bundles: 561 bosses, 866 enemies, 323 environment bundles, and 1,442 props. The Godot-native production catalog contains 10,710 registered animation frames.

This catalog is a reviewed project library, not an instruction to package all source content. Shipping scenes and `runtime_export_dependencies.tscn` must reference only the assets actually used by the runtime slice.

## Offline Blender atlas families

Four pipelines normalize dissimilar source art before Godot sees it:

- Local environment: `render_local_environment_sprites.py` renders 16 RGBA frames from 29 declared GLBs. The 4 x 4 `local_environment_atlas.png` includes four city ruins, mall and industrial shells, two village-house families, vehicle, barricade, pole, salvage, roadside barrier, and three camp satellites: bedding, supply cache, and medical cache.
- Poly Haven props: `render_polyhaven_environment_sprites.py` renders 12 frames from six CC0 model IDs: `tree_stump_01`, `dead_tree_trunk`, `rock_moss_set_01`, `metal_trash_can`, `concrete_road_barrier`, and `old_tyre`.
- Poly Haven Hidden Alley district: the immutable Blender 5 source workshop `bespren_polyhaven_district_workshop.blend` contains eight reviewed CC0 1k GLTF models: `modular_urban_apartments_facade`, `modular_factory_facade`, `modular_chainlink_fence`, `covered_car`, `exterior_aircon_unit`, `modular_street_seating`, `fire_hydrant`, and `barrel_stove`. `render_polyhaven_district_sprites.py` produces eight transparent 384 x 384 RGBA frames, and `build_polyhaven_district_atlas.gd` packs them into the deterministic 1536 x 768 `polyhaven_district_atlas.png` with SHA-256 `a73801d26937c0e2c958895c3817b9c9bc101958743b8ec23a73dea6f8242161`. The measured alpha-weighted luma floor is `65.967`, and every frame retains at least `30` transparent pixels to the nearest image edge.
- Poly Haven terrain: `bake_polyhaven_terrain_materials.py` packs four CC0 diffuse sources into a 1024 x 1024 2 x 2 atlas: `aerial_asphalt_01`, `muddy_tracks`, `forest_leaves_02`, and `concrete_pavement_03`. A separate 224 x 224 authored biome mask blends those materials over the 14 x 14 world.

All four are offline 2D bake paths. Source GLBs, PBR maps, Blender lights, materials, and `Node3D` do not enter the game scene or export payload. The local, Poly Haven nature/prop, and Hidden Alley district atlases use linear mipmaps and shared `sleek_sprite_finish.gdshader` grading. The district atlas contributes exactly 16 sprites to existing colliding city, Ostari mall, village, vehicle, and camp obstacles: three urban blocks, three factory blocks, two chainlink gates, two covered cars, four air-conditioner clusters, one camp bench, and one camp barrel stove. Its street-furniture frames also support 75 benches, 46 fire hydrants and 34 barrel stoves inside the 420-prop/1,100-mark background budget. The same approved atlases drive the 576-group collision-free ambient scenery pass for large ruins, canopies, rocks, logs, barriers, wrecks and fences. The terrain overlay is one batched `Sprite2D` with `terrain_material_blend.gdshader`, wrapped atlas gutters, a seamless blend mask, and a lighting-responsive finish.

## License and redistribution boundary

- Poly Haven sources are tracked as CC0 in their manifests and `assets/licenses/polyhaven_cc0.md`.
- Kenney inputs retain their upstream CC0/MIT evidence.
- Atomic Realm sources are permitted as edited, embedded project content under their included terms, but derived sprites must not be redistributed as a standalone asset pack.
- Filename or nearby-license detection in the deep audit is triage, not a legal opinion. A candidate without a license signal is not cleared for use.

## Build sequence

Run from the project root with an isolated writable Godot profile when required by the host environment:

```powershell
python tools/asset_pipeline/build_2d_asset_pipeline.py --project-root .
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --editor --quit-after 1
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tools/asset_pipeline/build_2d_resources.gd
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --editor --quit-after 1
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/asset_pipeline_validation.gd
```

Focused environment gates are:

```powershell
python tests/deep_asset_audit_validation.py
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/local_environment_validation.gd
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/polyhaven_environment_validation.gd
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/polyhaven_district_validation.gd
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script res://tests/terrain_material_validation.gd
```

Current passed evidence is `ASSET PIPELINE VALIDATION OK (66537 checks)`, `DEEP ASSET AUDIT VALIDATION OK (42 checks)`, `LOCAL ENVIRONMENT VALIDATION OK (47 checks)`, `POLY HAVEN ENVIRONMENT VALIDATION OK (36 checks)`, `POLY HAVEN DISTRICT VALIDATION OK (58 checks)`, and `TERRAIN MATERIAL VALIDATION OK (35 checks)`. These gates prove deterministic files, hashes, regions, provenance fields, runtime references, and scene contracts; they do not prove physical Android memory use, filtering quality, or thermal behavior.

## Generated resource contract

- `assets/2d/catalog/source_manifest.json` records accepted sources, archive decisions, slicing, exclusions, and categories.
- `assets/2d/catalog/production_catalog.json` and `.tres` are the runtime-facing broad catalog.
- `assets/2d/environment/local_baked/local_environment_manifest.json` records all 29 local GLBs, 16 outputs, licenses, render/workshop hashes, alpha bounds, and atlas regions.
- `assets/2d/environment/polyhaven/polyhaven_asset_manifest.json` records the six CC0 prop sources and 12 derived frames.
- `assets/2d/environment/polyhaven_district/polyhaven_district_manifest.json` records the exact eight CC0 1k GLTF district sources, eight derived frames, immutable Blender 5 workshop, renderer/generator hashes, luma and margin gates, padded regions, and the 1536 x 768 atlas hash.
- `assets/2d/environment/terrain/polyhaven_terrain_manifest.json` records four CC0 terrain IDs, packed-pixel hashes, atlas, blend mask, Blender workshop, and generator.
- Generated character/enemy/environment scenes use explicit bottom-center pivots and the filtering policy appropriate to their source language.

No source asset in `Addons/` should be deleted or altered as part of a runtime build. Any future promotion must preserve its source path, SHA-256, license evidence, derived output hash, and scene-level reachability.
