# Visual and Addons Asset Overhaul Audit

Date: 2026-08-15  
Target: Godot 4.7.1 Mobile, 480 x 270 landscape, 2D runtime

## Audit scope and evidence

`tools/asset_pipeline/deep_asset_audit.py` performs the exhaustive source-vault pass without editing `Addons`:

- 31,404 physical files, totaling 2,355,834,247 bytes, were individually SHA-256 hashed and classified.
- Signature detection found 145 physical containers: 144 ZIP-family files, including Krita KRA and Adobe Animate FLA, plus one gzip-tar Unity package. Recursive inspection adds 14 nested containers for 159 total.
- All 4,684 member records were path-safety checked, completely decompressed, integrity checked, SHA-256 hashed, and classified, covering 892,666,069 member bytes.
- Physical classification includes 11,004 rasters, 2,079 vectors, 1,455 3D sources, 161 audio files, 28 videos, 211 editable-art masters, 723 code files, 389 documents, 2,267 project-data files, and 12,630 generated metadata/cache files.
- There are 1,887 noncanonical duplicate physical files (151,292,509 bytes) and 978 noncanonical duplicate archive members (75,595,066 bytes).
- Six non-resource-fork PSDs remain metadata-unreadable; they retain complete physical hashes and are not falsely described as extracted layers.

Evidence is stored under `artifacts/asset_audit/`: `addons_file_ledger.jsonl` has exactly 31,404 records; `archive_member_ledger.jsonl` has exactly 4,684; `deep_asset_audit_summary.json` contains the aggregate counts; and `DEEP_ASSET_AUDIT.md` is the generated compact report. `docs/ADDONS_DEEP_AUDIT.md` records the full boundary, evidence hashes, license triage, promoted-source traceability, and past-plan review.

The file/member checks are exhaustive automated inspection, not a claim that a person manually art-directed all 9,885 physical visual candidates and 572 archive-member visual candidates one by one. Manual visual review was applied to the promoted shortlist, Blender-derived outputs, integrated scenes, and gameplay-scale captures. Of 1,455 physical 3D sources, 29 Addons GLBs currently have explicit Blender-derived review evidence; candidates without license evidence are not treated as cleared for use.

## Runtime-fit decision

The vault contains several strong source libraries, but no single pack solves the established top-down, weathered, non-pixel-mixed Bespren direction. Existing licensed ClawAndBlade foliage/ground remains as a provenance-backed terrain source, with a non-destructive petroleum-green runtime modulation. The castle silhouette was removed from the Base scene. Reproducible local Blender renders supply the camp and eight defense identities so they share camera, outline, value range, and mobile readability.

Poly Haven is now used selectively through an offline hybrid pipeline rather than loaded as runtime 3D. The connected Blender/Poly Haven MCP workflow imported six reviewed CC0 1k GLTF sources into the dedicated Blender 5 workshop: `tree_stump_01`, `dead_tree_trunk`, `rock_moss_set_01`, `metal_trash_can`, `concrete_road_barrier`, and `old_tyre`. `tools/art/render_polyhaven_environment_sprites.py` applies one orthographic camera, transparent background, Freestyle silhouette treatment, AgX color management, and a shared warm-key/cool-rim/fill rig, producing twelve 384 x 384 RGBA sprites. This conversion keeps the useful scanned surface character while removing runtime mesh, material, light, and high-resolution texture costs.

The reviewed local vault contributes a second offline Blender family. `tools/art/render_local_environment_sprites.py` composes 29 declared Kenney City Builder and Atomic Realm Post-Apocalyptic GLBs into sixteen coherent 384 x 384 RGBA renders: four city ruins, mall and industrial shells, separate west/east village houses, a vehicle wreck, wood barricade, utility pole, roadside salvage, roadside barrier, camp bedding, supply cache, and medical cache. `build_local_environment_atlas.gd` fills one 4 x 4, 1536 x 1536 atlas. The manifest records the 29 exact source GLBs, six license-evidence records, source/derived/workshop/script hashes, alpha bounds, coverage, and luminance. Atomic Realm-derived outputs remain embedded game assets and must not be redistributed as an asset pack.

A third offline family converts four Poly Haven CC0 terrain sources into `polyhaven_terrain_atlas.png` and an authored organic biome mask. `terrain_material_blend.gdshader` cross-fades wrapped asphalt, mud, leaf litter, and concrete across the complete world using one lighting-responsive 2D overlay. This replaces square macro-color blocks without adding runtime 3D or extra per-cell nodes.

`tools/asset_pipeline/build_polyhaven_environment_atlas.gd` deterministically packs those renders into the 4 x 3, 1536 x 1152 `polyhaven_environment_atlas.png`. It computes alpha content bounds with six-pixel padding and writes source IDs, CC0 evidence, URLs, file hashes, workshop/render-script hashes, and atlas regions to `polyhaven_asset_manifest.json`. Godot creates cropped `AtlasTexture` views lazily and applies shared forest or urban `sleek_sprite_finish.gdshader` materials with linear mipmap filtering. Rocks/stumps, fallen trunks, trash-can/tyre clusters, and selected concrete roadblocks replace procedural drawings while retaining the pre-existing `StaticBody2D` footprints, flow blocking, deterministic creation order, and peer-one movement authority. No Poly Haven GLTF, mesh, or PBR material is instantiated in the shipping 2D scene.

A fourth offline family is the Poly Haven Hidden Alley district set. Its immutable Blender 5 workshop `tools/art/blender/bespren_polyhaven_district_workshop.blend` contains exactly eight reviewed CC0 1k GLTF models: `modular_urban_apartments_facade`, `modular_factory_facade`, `modular_chainlink_fence`, `covered_car`, `exterior_aircon_unit`, `modular_street_seating`, `fire_hydrant`, and `barrel_stove`. `render_polyhaven_district_sprites.py` produces eight transparent 384 x 384 RGBA frames; `build_polyhaven_district_atlas.gd` packs them into the fixed 4 x 2, 1536 x 768 atlas with SHA-256 `a73801d26937c0e2c958895c3817b9c9bc101958743b8ec23a73dea6f8242161`. The source frames retain at least 30 pixels of edge margin, and their minimum alpha-weighted luma is `65.967`, above the manifest's `50.0` gate. Exactly 16 cropped sprites polish existing colliding city, Ostari mall, East-village, vehicle, and camp footprints, while 75 benches, 46 hydrants and 34 stoves are batched inside the 420-prop/1,100-decoration budget. The same approved atlas supports the collision-free ambient scenery pass; no district GLTF, mesh, PBR material, or `Node3D` enters runtime.

## Requirement-by-requirement changes

| User-visible issue | Implemented change | Evidence |
|---|---|---|
| Towers and traps needed unmistakable roles | Eight distinct top-down Blender silhouettes: kinetic turret, chemical tanks, electric coil, support mast, barricade, landmine, slowing pit, and violet-triggered Razor Snare. The three towers and three traps are separately color-, shape-, and mechanic-coded. | `artifacts/structure_visual_library.png`; `TOWER COMBAT OK (69 checks)`; smoke uniqueness check |
| Buildings, nature, and environment were sparse | Sixteen local-baked frames cover city, mall, villages, roadside and three camp satellites; twelve Poly Haven nature/prop frames, eight Hidden Alley district frames, four blended terrain materials, imported trees, deterministic forest stands, fallen logs, six asymmetric village dressing props, 16 colliding-obstacle district sprites, 1,100 region-allocated ground marks and 576 collision-free ambient ruin/tree/prop groups complete the current slice | world/local/Poly/district/terrain gates; refreshed density captures; Android performance open |
| Build menu lacked polish and interaction | Safe-area top sheet with Towers/Traps/Utilities tabs, live resource chips, card thumbnails, remembered category/selection, readable mechanics, and at most three cards per category page | `TACTICAL HUD OK (48 checks)`; four Mobile/Vulkan captures |
| Night was too dark | Night floor lifted to readable blue-hour `#91A3BD`; three-second transition and local camp/tower safety lights retained | smoke night contract; day/night camp Vulkan pair |
| Top-left resource/buttons were too large | Wood/Metal/Tech are one compact row in a `148 x 58` dashboard. `Make Base`, `Build`, and `Start Night` retain independent `44 x 44` touch targets; the panel area is 50.9% below the former `208 x 84` dashboard/status union. | `MOBILE SYSTEMS OK (56 checks)`; Mobile/Vulkan dashboard capture |
| Spawn was at the crossroads | Initial refuge and authoritative spawn moved to `(9950, 2400)` in east forest; the camp center is exactly 2,098 units from the nearest road edge and all Base/spawn/resource/satellite footprints retain at least 1,600 units | world/smoke/resource/mobile gates; final pixel refresh open |
| Minimap was too large | Reduced to `72 x 54`, with simplified topology, smaller markers, and animated ping pulse | HUD validation and dashboard capture |
| Colors looked cheap | Four Poly Haven terrain materials now blend organically under muted petroleum/rust/patina grading; roofs, props, UI, cards, towers, lifted shadows, and restrained contact shading share a controlled value range | terrain/shader validators plus overview, transition, city, deck, and camp captures |
| Base looked like a castle | Castle texture removed from `base_core.tscn` and the live 12-item promotion manifest; survivor camp adds bedding, supply, and medical satellites around the tent/fire/workbench/crate/radio/sandbag refuge | camp atlas/scene; smoke and world assertions; final APK inventory |
| Players ran through towers | Blocking towers/utilities own `WorldStatic` rectangles and peer one composes static-map/live-defense motion resolution before broadcasting player state. Ground traps deliberately remain traversable while still rejecting overlapping placement. | smoke dynamic blocker check; tower combat and co-op hardening gates |

## Generated runtime library

`assets/2d/structures/` contains:

- `base_camp_topdown.png`
- `structure_t1_kinetic.png`
- `structure_t1_chemical.png`
- `structure_t1_electric.png`
- `structure_t1_support.png`
- `structure_t1_barricade.png`
- `structure_t1_landmine.png`
- `structure_t1_slowing_pit.png`
- `structure_t1_razor_snare.png`

All eight sources import through Godot and are regenerated by one checked-in Blender script. Runtime nodes retain collision, Y-sort, security-light, EMP, health, cost, refund, flow-field, and replication contracts.

`assets/2d/environment/polyhaven/` contains twelve transparent source renders plus one deterministic runtime atlas:

- one forest stump and one dead trunk
- six moss-rock silhouettes
- clean and rusted trash-can variants
- one concrete road barrier and one old tyre

The corresponding provenance is stored in `polyhaven_asset_manifest.json` and `assets/licenses/polyhaven_cc0.md`. The Blender source workshop lives under `tools/art/blender/` behind `.gdignore`; it is an offline authoring artifact, not a runtime 3D dependency. Together with the integrated local, Hidden Alley, and terrain atlases below, this replaces the targeted nature, city, mall, village, camp, vehicle, fence, pole, roadside, and macro-ground families. Representative Android performance/readability checks remain open.

`assets/2d/environment/local_baked/` contains sixteen transparent renders plus `local_environment_atlas.png` and `local_environment_manifest.json`. Its four city ruins, mall/industrial shells, two village families, wreck, barricade, pole, salvage, barrier, and three camp satellites are mapped onto authored obstacle footprints. `assets/licenses/local_baked_environment_sources.md` records the Kenney and Atomic Realm evidence and the restriction against repackaging, resale, or redistribution. This atlas broadens the building/roadside/camp language without shipping a runtime mesh or changing collision authority.

`assets/2d/environment/terrain/` contains the four-source 1024 x 1024 terrain atlas, 224 x 224 biome blend mask, manifest, and dedicated shader. The overlay remains one batched 2D draw layer, uses linear mipmaps and seamless source-cell cross-fades, responds to CanvasModulate and camp lights, and leaves the legacy nature tiles available beneath it for compatibility.

`assets/2d/environment/polyhaven_district/` contains eight transparent 384 x 384 frames, `polyhaven_district_atlas.png`, and `polyhaven_district_manifest.json`. The packed atlas is 1536 x 768 with SHA-256 `a73801d26937c0e2c958895c3817b9c9bc101958743b8ec23a73dea6f8242161`. The integrated colliding mix is exact: three apartment sprites, three factory sprites, two chainlink gates, two covered cars, four air-conditioner clusters, one camp bench, and one camp barrel stove. The non-colliding background furniture mix is also exact: 75 benches, 46 hydrants, and 34 stoves inside 420 props and 1,100 total ground marks. The district frames are also reused by the 576-group collision-free ambient scenery pass. All derived sprites use cropped atlas views, linear mipmaps, the shared sleek shader, and their original collision/flow parents.

Long Ostari obstacles keep their canonical collision-sized foundation visible beneath four alternating baked modules and a salvage accent, so the authored shell reads as one grounded commercial footprint rather than isolated sprites. West/east village houses retain different atlas silhouettes and apply separate top-down vertical correction after width fitting; the local validator confirms all eight houses use their intended regional frame, and the capture matrix includes both villages by day plus the west village at night.

## Validation record

- `ASSET PIPELINE VALIDATION OK (66537 checks)` across all 3,192 curated raster candidates
- `DEEP ASSET AUDIT VALIDATION OK (42 checks)`
- Current smoke run has one unresolved east-camp flow-direction assertion; do not treat it as green
- `WORLD MAP VALIDATION OK (150 checks)`
- `POLY HAVEN ENVIRONMENT VALIDATION OK (36 checks)`
- `POLY HAVEN DISTRICT VALIDATION OK (58 checks)`
- `LOCAL ENVIRONMENT VALIDATION OK (47 checks)`
- `TERRAIN MATERIAL VALIDATION OK (35 checks)`
- `MOBILE SYSTEMS OK (56 checks)`
- `TACTICAL HUD OK (48 checks)`
- `RESOURCE SCATTER VALIDATION OK (72 checks)`
- `COOP HARDENING OK (33 checks)`
- `AUTO AIM OK (46 checks)`
- `TOWER COMBAT OK (69 checks)`
- `ENEMY PRESENTATION OK (27 checks)`
- Fresh Mobile/Vulkan 480x270 artifacts cover the `148 x 58` dashboard, all three build categories, eight defense silhouettes, and eight enemy presentations.

The current revision has headless shader compilation, scene instantiation, geometry, pagination, touch-target, material-assignment, all three obstacle-sprite atlases, terrain atlas/mask integration, and export-closure proof. Fresh desktop Mobile/Vulkan captures cover the HUD, all build categories, structures, and enemy presentations; the separate world capture scene still predates the final camp/district state and remains a distinct refresh item. Physical-device profiling also remains open; neither headless nor desktop evidence certifies Android thermals, cutout behavior, touch ergonomics, audio perception, or physical two-device Wi-Fi/LAN behavior.

Fresh polish packages are `build/android/Bespren-runtime-polish.pck` (5,737,388 bytes; SHA-256 `D853276FC4880A4F7C4D99D692BBC1780BCE09EE078B4ED67C7EF24ED71AD76A`) and `build/android/Bespren-polish.apk` (34,394,814 bytes; SHA-256 `3A0B62212C152B4729A6C56AD32A8CA51CDB4985519CEB29A063A0D1DA9935A9`). The isolated PCK verifier loads all 134 closure resources and instantiates 23 scenes; the APK export completed and its v2/v3 signatures verify. Installation, rendering, sustained performance/thermals, cutout and touch ergonomics, lifecycle interruption, and physical two-device LAN behavior remain open until tested on representative Android hardware.

## Reproduction

```powershell
python tools\asset_pipeline\deep_asset_audit.py

& 'C:\Program Files\Blender Foundation\Blender 5.0\blender.exe' `
  --background --python tools\art\generate_camp_and_structure_sprites.py

& 'C:\Program Files\Blender Foundation\Blender 5.0\blender.exe' `
  --background tools\art\blender\bespren_map_asset_workshop.blend `
  --python tools\art\render_polyhaven_environment_sprites.py

& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64_console.exe' `
  --headless --path . --script res://tools/asset_pipeline/build_polyhaven_environment_atlas.gd

& 'C:\Program Files\Blender Foundation\Blender 5.0\blender.exe' `
  --background tools\art\blender\bespren_polyhaven_district_workshop.blend `
  --python tools\art\render_polyhaven_district_sprites.py

& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64_console.exe' `
  --headless --path . --script res://tools/asset_pipeline/build_polyhaven_district_atlas.gd

& 'C:\Program Files\Blender Foundation\Blender 5.0\blender.exe' `
  --background tools\art\blender\bespren_local_environment_workshop.blend `
  --python tools\art\render_local_environment_sprites.py

& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64_console.exe' `
  --headless --path . --script res://tools/asset_pipeline/build_local_environment_atlas.gd

& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64_console.exe' `
  --headless --path . --script res://tests/smoke_test.gd
```

Run `tests/structure_visual_render_validation.tscn`, `tests/tactical_hud_render_validation.tscn`, and `tests/world_render_validation.tscn` with the normal Godot renderer for the GPU captures.
