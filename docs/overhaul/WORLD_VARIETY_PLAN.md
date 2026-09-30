# World Variety Plan

Scope: raise perceived prop/nature variety on the 480x270 world map to "premium AAA++"
readability without adding runtime 3D, without changing canonical collision/flow/seed
behavior, and inside the mobile budgets in `CLAUDE.md` section 10. This plan does not
touch code; it is the contract the next implementation slice executes against.

## 0. Brief-vs-code discrepancies (code wins)

- **The two new sprite families have not been baked.** `assets/2d/environment/polyhaven_wild/`
  and `assets/2d/environment/polyhaven_salvage/` do not exist on disk, and
  `assets/2d/environment/polyhaven_wild_render_report.json` (the report
  `tools/art/render_polyhaven_wild_sprites.py` line 267-269 writes on completion) does not
  exist either. Nothing has run yet. This plan is written against the renderer script's
  declared design, which is code and therefore authoritative over the "being baked right
  now" framing.
- **Frame counts differ from the brief's estimate.** The brief said "~36 wild / ~36 salvage."
  Counting the `WILD`/`SALVAGE` tuples in `tools/art/render_polyhaven_wild_sprites.py`
  (lines 72-89 and 94-111) by summing each `WildBake.yaws` length gives **36 wild frames
  from 16 sources** and **38 salvage frames from 16 sources** — 74 total, not ~72. All
  numbers below use 36/38.
- **No atlas-builder scripts exist yet for the two new families.** `tools/asset_pipeline/`
  has `build_polyhaven_environment_atlas.gd`, `build_polyhaven_district_atlas.gd`, and
  `build_local_environment_atlas.gd` (one per shipped family, each cited in its manifest's
  `atlas_generator` key). No `build_polyhaven_wild_atlas.gd` or `build_polyhaven_salvage_atlas.gd`
  was found. Packing the new frames into atlases is unstarted work, not a pending run of an
  existing tool — budgeted explicitly in section 7.

## 1. Inventory

### 1.1 Shipped baked vocabulary today

Three atlas families are shipped and referenced from their manifests in
`assets/2d/environment/{polyhaven,polyhaven_district,local_baked}/`:

| Family | Atlas | Size | Frames | Manifest |
|---|---|---:|---:|---|
| polyhaven (nature/props) | `polyhaven_environment_atlas.png` | 1536x1152 | 12 | `polyhaven/polyhaven_asset_manifest.json` |
| polyhaven_district (Hidden Alley) | `polyhaven_district_atlas.png` | 1536x768 | 8 | `polyhaven_district/polyhaven_district_manifest.json` |
| local_baked (Kenney + Atomic Realm) | `local_environment_atlas.png` | 1536x1536 | 16 | `local_baked/local_environment_manifest.json` |

**Total shipped baked frames: 36.** These back exactly 13 `VisualKind` values in
`src/world/world_obstacle_2d.gd` (CITY_BUILDING, MALL_SHELL, VILLAGE_HOUSE, TREE,
VEHICLE_WRECK, WOODEN_FENCE, MOSSY_ROCK, FALLEN_LOG, SCRAP_PILE, UTILITY_POLE,
CAMP_BEDDING, CAMP_SUPPLY_CACHE, CAMP_MEDICAL_CACHE), and the same 36 frames are reused by
the two non-colliding dressing layers: `WorldBackgroundDecor2D`'s 9-value `PropKind` enum
(`SHRUB, ROOT, TYRE, BARREL, BONES, GROWTH, STREET_SEATING, FIRE_HYDRANT, BARREL_STOVE`) and
`WorldAmbientScenery2D`'s 10-value `SceneryKind` enum. Both decor and scenery select which
kind appears where from fixed 8-entry pools (`FOREST_PROP_KINDS`, `VILLAGE_PROP_KINDS`,
`URBAN_PROP_KINDS` in `world_background_decor_2d.gd`; equivalent `*_KIND_POOL` arrays in
`world_ambient_scenery_2d.gd`), cycled with `zone_index % pool.size()`. **The real variety
ceiling today is not texture count, it is this 8-slot modulo cap** — FOREST's 126 prop
instances draw from only 8 kinds, repeating each roughly 16 times regardless of how many
frames exist in the atlas. Section 3 makes this the first fix.

### 1.2 New families as designed (unbaked — see section 0)

| Family | Sources | Frames | Frame size | Subjects |
|---|---:|---:|---:|---|
| polyhaven_wild | 16 | 36 | 256px | pine/fir/broadleaf/sapling trees, dead trunk, stump, roots (pine+cluster), 2 shrubs, fern, grass, moss, 2 rocks, dry branches |
| polyhaven_salvage | 16 | 38 | 256px | 3 barrels, 3 crates, jerrycan, propane tank, trashbag, hand truck, wheel rim, toolbox, street lamp, utility box, compressor, plastic container |

Once baked this raises total baked frames to **110** (36 shipped + 74 new) from **32** new
source subjects, at 256px each — smaller than the district family's 384px by design, per
the renderer's own comment ("these subjects are small on a 480x270 screen").

### 1.3 Missing subjects (confirmed gaps, not opinion)

Checked against `Biome` (6 values in `world_map_2d.gd`: FOREST, CITY, MALL, VILLAGE_WEST,
VILLAGE_EAST, WILDERNESS), the 4-material terrain atlas (`polyhaven_terrain_manifest.json`:
asphalt, mud_tracks, forest_leaves, concrete), and both new families' subject lists:

- **No water or wetland anything.** No swamp/riverbank biome, no terrain material, no reeds,
  cattails, mud-specific flora, or water-edge prop in wild or salvage.
- **No burnt/scorched register.** Every decay language in `CLAUDE.md` section 8 is rust,
  rot, or patina; nothing is char. No scorched ground material, no burnt-trunk variant, no
  ash-pile prop distinct from generic rubble.
- **No open field/farmland.** WILDERNESS is the only open biome and it has zero dedicated
  decor bucket (section 2 below) and no low-lying crop/hay/tall-grass subject beyond the new
  wild family's single `grass` frame.
- **No dedicated small-rubble or free-standing wall-fragment obstacle.** Building-scale
  ruin only exists as full `CITY_BUILDING`/`VILLAGE_HOUSE` footprints or the `SCRAP_PILE`
  composite; there is nothing sized between a tyre and a building. KayKit's
  `rubble_half`/`rubble_large`/`wall_broken`/`wall_cracked` fill this exactly (section 4).
- **No elevation prop.** Nothing reads as stairs or a raised platform anywhere in the world
  system. KayKit's `stairs_wood` variants fill this.

Swamp/burnt/field/riverbank are **biome-system changes** (new `Biome` value, new terrain
material, new road/flow interaction), not prop additions — out of scope for this plan per
section 7 item 8, consistent with `CLAUDE.md` section 15's one-slice-at-a-time rule.

## 2. Biome-by-biome assignment

Region cells from `get_biome_regions()` in `world_map_2d.gd`; instance counts from the zone
arrays in `world_background_decor_2d.gd` (`RUBBLE/CRACK/MOSS/PROP_ZONE_COUNTS`, order
CITY/MALL/VILLAGE_WEST/VILLAGE_EAST/FOREST/CONNECTORS) and `world_ambient_scenery_2d.gd`
(`ZONE_SCENERY_COUNTS`, order CITY/MALL/VILLAGE_WEST/VILLAGE_EAST/FOREST/WILDERNESS/CONNECTORS).

| Biome | Cells | Existing obstacle mix | Decor instances | Scenery instances | New content to route here |
|---|---|---|---:|---:|---|
| Kaupunki (city) | (1,1)-(5,5), 25 cells | 6 CITY_BUILDING, 5 VEHICLE_WRECK, 6 SCRAP_PILE, 8 dense ruin landmarks | 265 | 96 | Industrial salvage: crate/barrel/toolbox/compressor/hand_truck/utility_box/wheel_rim/jerrycan/trashbag/container_plastic. KayKit rubble/wall-fragment/column/scaffold to break up repeated building silhouette. Minimal wild (rock_bare, branches at crack edges only). |
| Ostari (mall) | (7,2)-(10,5), 16 cells | 2 MALL_SHELL (6400x1800), 2 pylons, 1 wreck, 5 dense ruin landmarks | 193 | 72 | Same salvage pool as Kaupunki **plus** KayKit shelf_large/shelf_small/table_long_broken/chest/floor_tile_broken — this is the concrete lever that makes Ostari read as "collapsed commercial" instead of a second Kaupunki, since both biomes currently draw the same CITY_BUILDING/local-ruin dispatch. |
| Kylä west | (1,9)-(4,12), 16 cells | 4 houses, 6-seg fence ring, 5 poles, +rock/log/scrap | 116 | 48 | Wild (shrub/fern/grass/moss/stump/roots — villages sit at the forest edge per `_build_biome_cells()` default). Domestic salvage only: trunk_small, chair, stool, bed_frame, keg. No industrial salvage — keeps the village register distinct from the cities. |
| Kylä east | (9,9)-(12,12), 16 cells | asymmetric mix (code comment: intentional), similar totals | 116 | 48 | Same rule as Kylä west. |
| Metsä (forest) | perimeter + inner cells | 68 explicit trees, dense stands (seed+7001, min 180), 12 rock, 12 log | 286 (largest decor zone) | 172 (largest scenery zone) | Full 16-species wild mix: all trees, shrubs, ferns, moss, rock, branches. |
| Luonto (wilderness) | default-fill cells | dense groves only (seed+8191, min 35) | **0 — no WILDERNESS entry in `DecorZone`** | 92 | Open/sparse wild subset only: grass, shrub, rock_bare, dead_trunk, stump — never the dense-canopy species. This is the natural anchor for a future field subject and the gap called out in 1.3; see work item 7. |
| Connectors (roads) | road-adjacent | — | 124 | 48 | Roads carry `dirt_flags` (`world_map_2d.gd`: first 4 routes paved, last 4 dirt). Paved segments get salvage roadside dressing (wheel_rim, barrel, wrecked-adjacent clutter); dirt segments get wild roadside dressing (branches, rock_bare). |

Route new frames through the **non-colliding** decor/scenery layers by default — almost
every wild and salvage subject (trees, shrubs, barrels, crates, toolboxes) is a natural
`PropKind`/`SceneryKind` citizen, not a new `WorldObstacle2D` footprint, so this needs zero
new `CollisionShape2D` work and cannot regress the flow-field mask baked in
`_bake_flow_field_mask()`. Only promote a frame to a colliding `VisualKind` if a specific
gameplay reason is stated (per the hard constraint that presentation changes must not imply
collision changes) — none of the shortlisted frames need that in this plan.

## 3. Raising variety without more texture memory

Ranked by cost; all are deterministic (seed-derived) so host and client still agree.

1. **Mirroring.** `Sprite2D.flip_h = true` costs nothing — no new pixels, no new draw call,
   applies to all 36 shipped frames today. Doubles apparent silhouette count instantly.
   Skip only on frames whose collision shape is asymmetric (check case by case before
   enabling on a `WorldObstacle2D`; unconditionally safe on decor/scenery since those are
   non-colliding).
2. **Yaw variants (already the wild/salvage technique).** Rendering one subject from 2-3
   headings costs extra atlas cells, not a new material or shader — the existing multiplier
   is 74 frames from 32 sources (2.3x average). Reuse this pattern for any future family
   before reaching for more source models.
3. **Per-instance hue/value/saturation jitter, at render time, not bake time.** Both cached
   `sleek_sprite_finish.gdshader` variants (`_get_environment_finish(forest_finish)` in
   `world_obstacle_2d.gd`) already expose `accent_color`, `saturation`, `contrast`,
   `shadow_lift`, `accent_strength`, `sheen_strength` as material uniforms. Declaring the
   jittered subset as Godot 4 `instance uniform` (per the CanvasItem shader reference
   `CLAUDE.md` section 8 already cites) keeps every instance in the same batch — no per-
   instance material duplication, no extra draw call. Bounds, derived from the existing
   `_unit_noise(stable_seed * 131 + index * 977)` deterministic pattern already in
   `world_obstacle_2d.gd`: hue **±6%**, value **±8%**, saturation **±5%**. This is what
   removes the "stamped" look from repeated frames without touching the atlas at all.
4. **Scale jitter**, bounds grounded in ranges the codebase already uses rather than
   invented: props **0.85x-1.15x**, trees/clusters **0.85x-1.35x** (matching the existing
   `TREE_CLUSTER` 360-610 and `ROCK_CLUSTER` 250-410 unit ranges in
   `world_ambient_scenery_2d.gd`, both already ~1.6-1.7x spans).
5. **Layered composition (clustering).** The codebase already composites multiple sprites
   into one placeable unit — `SCRAP_PILE` is a trash-can + tyre at jittered rotation, and
   the mall long-shell splits into up to 4 modules mixing local/district frames
   (`_install_imported_visuals()` dispatch in `world_obstacle_2d.gd`). Extend the exact same
   pattern to salvage: author 4-6 named micro-clusters (barrel+crate+jerrycan;
   toolbox+wheel_rim+trashbag) as single placeable entries. This multiplies 38 raw salvage
   frames into a materially larger set of distinct silhouettes at the group level, with zero
   new pixels.
6. **Pool-to-frame-key refactor (the unlock).** Replace the fixed 8-slot enum-modulo pools
   (`FOREST_PROP_KINDS` etc., `*_KIND_POOL` in scenery) with arrays of frame-key strings.
   This is a data-shape change, not a new system, and it is the prerequisite for every row
   in section 2 — without it, new baked frames cannot exceed the current 8-kind-per-zone
   ceiling no matter how many exist in the atlas.

Illustrative combined effect: today's ceiling is 8 visually distinct kinds per zone. After
items 1, 3, 4, and 6 (mirroring x2, continuous jitter, pool refactor unlocking ~30-45
frame keys city-wide once new families ship), the same 110 baked frames can plausibly
present 60-90 perceptually distinct instances without a single additional baked pixel.
This is an estimate, not a measured figure — validate visually against
`world_render_validation.tscn` once implemented (work item 10).

## 4. KayKit Dungeon Remastered shortlist

Source confirmed on disk at
`Addons/KayKit_DungeonRemastered_1.1_FREE/KayKit_DungeonRemastered_1.1_FREE/Assets/gltf/`
(every filename below verified present). License confirmed at the sibling `License.txt`:
CC0, attribution to Kay Lousberg optional — no evidence file for this family exists yet in
`assets/licenses/`; add `assets/licenses/kaykit_dungeon_remastered_cc0.md` following the
existing per-family convention before promoting anything (work item 6). All entries bake
through `tools/art/aaa_bake_rig.py` (Standard view transform, **not** the AgX pipeline the
wild/salvage/district renderers use — `aaa_bake_rig.py`'s own comment explains AgX
desaturates the locked semantic palette) via `apply_bespren_palette()` / `bake_many()`.
Default bake size 128px (`bake_objects(..., size=128)`); the wall/column/rubble rows use
192px to hold edge crispness at their larger placed footprint.

| KayKit source | Bespren name | Palette key(s) | Layer | Size |
|---|---|---|---|---:|
| barrel_large | fuel_drum_full | RUSTED_IRON + DARK_IRON | PropKind | 128 |
| barrel_small_stack | fuel_drum_stack | RUSTED_IRON + IRON_SILVER | PropKind | 128 |
| barrel_large_decorated | chem_drum_marked | OXIDIZED_COPPER | PropKind | 128 |
| box_large | supply_crate_large | DECAYED_WOOD | PropKind | 128 |
| box_small_decorated | ration_crate | DECAYED_WOOD + IRON_SILVER | PropKind | 128 |
| box_stacked | crate_stack | DECAYED_WOOD | PropKind | 128 |
| crates_stacked | salvage_crate_pile | DECAYED_WOOD + RUSTED_IRON | SceneryKind | 128 |
| keg | water_keg | DECAYED_WOOD | PropKind | 128 |
| keg_decorated | sealed_keg | DECAYED_WOOD + OXIDIZED_COPPER | PropKind | 128 |
| chest | gear_locker | DARK_IRON | PropKind | 128 |
| trunk_large_A/B/C | footlocker_large_{A,B,C} | DARK_IRON + DECAYED_WOOD | PropKind | 128 |
| trunk_medium_A/B/C | footlocker_medium_{A,B,C} | DARK_IRON + DECAYED_WOOD | PropKind | 128 |
| trunk_small_A/B/C | toolbox_small_{A,B,C} | IRON_SILVER | PropKind | 128 |
| shelf_large | salvage_shelf | RUSTED_IRON | new VisualKind (Ostari only) | 128 |
| shelf_small | scrap_shelf | RUSTED_IRON | PropKind | 128 |
| table_long_broken | broken_workbench | DECAYED_WOOD | SceneryKind | 128 |
| table_medium_broken | broken_table | DECAYED_WOOD | SceneryKind | 128 |
| table_small | camp_table | DECAYED_WOOD | PropKind (villages) | 128 |
| chair | camp_chair | DECAYED_WOOD | PropKind (villages) | 128 |
| stool | camp_stool | DECAYED_WOOD | PropKind (villages) | 128 |
| bed_frame | salvaged_bedframe | DARK_IRON | PropKind (villages) | 128 |
| wall_broken | ruin_wall_broken | ASH_CONCRETE | SceneryKind | 192 |
| wall_cracked | ruin_wall_cracked | ASH_CONCRETE | SceneryKind | 192 |
| wall_half | ruin_wall_half | ASH_CONCRETE | SceneryKind | 192 |
| wall_pillar | ruin_pillar_wall | ASH_CONCRETE | SceneryKind | 192 |
| wall_scaffold | scaffold_frame | DARK_IRON | SceneryKind | 192 |
| column / pillar | ruin_column | ASH_CONCRETE | SceneryKind | 192 |
| rubble_half | rubble_small | ASH_CONCRETE | SceneryKind | 128 |
| rubble_large | rubble_large | ASH_CONCRETE | SceneryKind | 192 |
| barrier / barrier_corner | checkpoint_barrier / _corner | ASH_CONCRETE | SceneryKind (city/mall) | 128 |
| stairs_wood / _decorated | salvage_stairs_wood | DECAYED_WOOD | SceneryKind (villages) | 128 |
| floor_dirt_small_weeds | dirt_patch_weeds | (ground tint only) | WorldBackgroundDecor2D ground layer | 128 |
| floor_tile_small_broken_A/B | broken_tile_patch_{A,B} | ASH_CONCRETE | WorldBackgroundDecor2D ground layer | 128 |
| floor_tile_small_weeds_A/B | weedy_tile_patch_{A,B} | ASH_CONCRETE | WorldBackgroundDecor2D ground layer | 128 |

37 models — inside the requested 25-40 range. Deliberately **excluded**: banner_* (dungeon-
coded, no post-apo reading), all `stairs_modular_*`/`stairs_long_*` segment variants beyond
the plain wood pair (near-duplicate silhouettes, low marginal value), torch/torch_lit/
torch_mounted/candle* family, and chest_gold.

**Two explicit palette-safety exclusions, not oversights:**
- `torch_lit`/`candle_lit`/`torch_mounted` are dropped rather than reskinned. `CLAUDE.md`
  section 2 makes Base Core amber (`#FFB52E`) "the only dominant Amber Gold source" in the
  world; any lit-flame prop scattered through city/village zones would compete with that
  pillar. If a future slice wants them, the emissive must come from `MOLTEN_SLAG` (`#FF6A1E`,
  already hazard-coded in `BESPREN_PALETTE`) at reduced emission strength, never
  `AMBER_GOLD`/`ACCENT_GOLD`.
- `chest_gold` is dropped rather than reskinned. Its natural "gold latch" reading sits too
  close to `NEON_CYAN`/`ACCENT_GOLD`, which `CLAUDE.md` reserves for Tech resource signal and
  Heikki identity respectively. `chest` (plain, `DARK_IRON`) covers the same gameplay need
  with no palette ambiguity.

## 5. Draw-call and texture-memory budget

### 5.1 VRAM estimate

Checked `assets/2d/environment/local_baked/local_environment_atlas.png.import`:
`compress/mode=0` (Lossless) and `mipmaps/generate=true`. Godot decompresses lossless PNG
import to full RGBA8 in VRAM at runtime, so the estimate below is uncompressed-RGBA8 x 1.33
(mip chain), not the on-disk PNG byte size. The other atlas `.import` files were not
individually re-checked but share the same generator lineage and are assumed consistent —
flag as a one-line verification, not a re-derivation, before trusting this table further.

| Atlas | Size | Raw RGBA8 | With mips (x1.33) |
|---|---|---:|---:|
| polyhaven (shipped) | 1536x1152 | 6.75 MB | 9.0 MB |
| polyhaven_district (shipped) | 1536x768 | 4.5 MB | 6.0 MB |
| local_baked (shipped) | 1536x1536 | 9.0 MB | 12.0 MB |
| terrain (shipped) | 1024x1024 | 4.0 MB | 5.3 MB |
| **Shipped subtotal** | | | **32.3 MB** |
| wild (new, 36 frames @256px, packs exactly into a 6x6 grid — 1536x1536, zero waste) | 1536x1536 | 9.0 MB | 12.0 MB |
| salvage (new, 38 frames @256px, needs a 6x7 grid with 4 spare cells) | 1536x1792 | 10.5 MB | 14.0 MB |
| **New subtotal** | | | **26.0 MB** |
| **Grand total, both new families shipped** | | | **~58.3 MB** |

~58 MB of environment-atlas VRAM alone (before character sprites, UI, tilesets) is a real
but not immediately fatal slice of a mid-range Android budget. It is also entirely
avoidable overhead: switching `compress/mode` from 0 (Lossless) to 2 (VRAM Compressed,
ETC2) on all five atlases cuts this to roughly **14.6 MB** — a ~44 MB saving — at the cost
of a one-time recompression plus a contact-sheet check for ETC2 banding on the smoother
gradients (Base Core amber glow, sky-adjacent frames). This is the single biggest lever in
this plan and costs no gameplay or content work; see work item 9.

### 5.2 Draw-call estimate

Every environment sprite goes through `_add_environment_sprite()` and one of exactly two
cached `ShaderMaterial` instances from `_get_environment_finish(forest_finish)`. Godot 2D
batches consecutive `CanvasItem`s that share material + texture, so draw-call count is
governed by the number of distinct (material, texture) pairs in view, not by the ~2,200
total obstacle/decor/scenery instances the world places. Today that is roughly 2 finishes x
~4 atlas textures actually paired in practice ≈ **6-8 batches** for the entire environment-
sprite population. Adding the wild and salvage atlases adds at most 2 more texture pairings
— **≤10 batches total**, provided (hard requirement, not a suggestion) the new families are
wired through the same `_add_environment_sprite`/`_get_environment_finish` helpers rather
than new `ShaderMaterial` instances. The KayKit family in section 4 must follow the same
rule when it lands. Z-sort/paint-order breaks (Y-sort containers) can still force extra
flushes independent of texture count; that risk is unchanged by this plan since it adds no
new Y-sort containers.

### 5.3 What to cut first if frame time is missed, in order

1. Reduce jitter/mirror instance density in the lowest-identity zones first — CONNECTORS
   and WILDERNESS — before touching Kaupunki/Ostari/village silhouettes players actually
   navigate by.
2. Drop salvage micro-cluster composites (section 3 item 5) back to single-sprite
   placements. Halves sprite count in decorated zones instantly with no atlas change.
3. Ship the VRAM-compressed import switch (section 5.1) — the largest single lever, zero
   gameplay change, do this before cutting content.
4. Reduce FOREST's decor instance total (286, the largest of any zone) proportionally to
   the variety gained from yaw variants — fewer raw instances are needed once each instance
   reads as more distinct.
5. Last resort: trim wild-family yaw count on the least distinctive species (moss and grass
   already ship at 1-2 yaws; do not go below 1) — this is the only cut that touches the
   already-designed bake list itself.

## 6. Validation additions

Every shipped family in this codebase gets its own focused gate — `polyhaven_environment_validation.gd`,
`polyhaven_district_validation.gd`, `local_environment_validation.gd`, `terrain_material_validation.gd`
— and `world_map_validation.gd` only proves placement/collision/flow-mask, not per-family
provenance. Follow that convention: add `tests/world_variety_validation.gd`, `extends SceneTree`,
using the same structure `polyhaven_district_validation.gd` and `local_environment_validation.gd`
both use — manifest/provenance, then atlas resource, then runtime dependency graph, then world
integration — plus the `_check(condition, message)` / `"PASS | %s"` / `"... OK (%d checks)"`
harness (`_checks`/`_failures` counters, `push_error` on failure, nonzero `quit()` code) every
existing gate in this repo shares. This section only proposes what the new gate should assert;
authoring it is work item 10 below and cannot start before the atlases it inspects exist.

**Phase 1 — manifest and provenance**, one block per new family, mirroring `_validate_manifest()`
in the district gate:
- Wild: manifest exists, parses, `schema_version == 1`, records exactly 16 source ids and
  **36** derived frames (section 1.2's corrected count, not the brief's ~36 estimate — already
  reconciled in section 0), `license == "CC0-1.0"`, and a license-evidence file that exists and
  contains "cc0"/"poly haven".
- Salvage: same shape, exactly 16 sources and **38** derived frames.
- KayKit: exactly **37** source paths (section 4's table count) resolve under
  `Addons/KayKit_DungeonRemastered_1.1_FREE/.../Assets/gltf/` and exist on disk; manifest
  license field is `"CC0-1.0"`; `assets/licenses/kaykit_dungeon_remastered_cc0.md` exists and
  contains "cc0" (work item 6's own prerequisite, now enforced instead of just requested); every
  source's `render_policy` uses `aaa_bake_rig.py`'s Standard view transform and explicitly
  asserts `"agx"` is **absent** — the opposite polarity from the district/wild manifest checks,
  since section 4 established KayKit deliberately skips AgX to protect the locked palette; worth
  a one-line comment in the test itself, or a future reviewer "fixes" it back to match the other
  families.
- All three: every derived frame is RGBA8 at its declared size (256px wild/salvage, 128 or 192px
  KayKit per section 4's table), with `alpha_weighted_luma` at least the existing 50-luma floor
  (`polyhaven_district_validation.gd` line 261) — reused verbatim rather than picking a new bar.

**Phase 2 — atlas resource**, mirroring `_validate_atlas_resource()`: the wild atlas imports as
`Texture2D` at exactly 1536x1536 (section 5.1's zero-waste 6x6 grid); the salvage atlas at
exactly 1536x1792 (6x7 grid, 4 spare cells — assert those 4 cells are fully transparent, not
stray content, since nothing else in the pipeline checks that); the KayKit atlas at whatever
size its own builder computes, left as a named constant rather than a guess until
`build_kaykit_atlas.gd` exists; every atlas reports `get_mipmap_count() > 0`.

**Phase 3 — runtime dependency graph**, mirroring `_validate_runtime_dependency_graph()`: walk
`world_map_2d.tscn`'s dependencies and assert zero `.glb`/`.gltf`/`.blend` entries reach
runtime. This needs no new logic — the existing district gate's walker already generalizes; a
new gate only needs its own copy pointed at the same scene.

**Phase 4 — world integration**, the part that actually proves this plan's mechanics rather
than just that new pixels exist:
- **Mirroring** (section 3 item 1): for a sample of decor/scenery instances keyed by
  `stable_seed`, assert `flip_h` is a deterministic function of that seed (re-running the same
  seed in one process yields the same `flip_h`), and assert it is `false` on every instance
  whose `VisualKind` was excluded for asymmetric-collision reasons.
- **Jitter** (section 3 items 3-4): assert every placed sprite's per-instance shader
  parameters — read individually via `CanvasItem.get_instance_shader_parameter(name)` for each
  jittered uniform name from section 3 item 3 — fall inside this plan's bounds (hue ±6%, value
  ±8%, saturation ±5%; prop scale 0.85x-1.15x, tree/cluster 0.85x-1.35x). An out-of-bounds
  jitter value is exactly the kind of regression a human contact-sheet review will not reliably
  catch.
- **Pool-to-frame-key refactor** (section 3 item 6, the prerequisite item): assert the
  replacement pools (successors to `FOREST_PROP_KINDS` etc.) have **strictly more** distinct
  frame keys than today's fixed 8-entry pools, and assert each zone's realized kind-diversity
  (the set of distinct kinds actually drawn across that zone's placed instances) increases
  versus today's fixed 8 — the one check that directly falsifies "frames were added but variety
  did not change," which is this plan's actual thesis.
- **WILDERNESS decor bucket** (work item 7): assert `WorldBackgroundDecor2D`'s zone-count
  arrays gain a nonzero WILDERNESS entry. Today's gap is exactly zero (section 1.3/2), so this
  is a strict `> 0` regression check — trivial to write, trivial to silently lose if skipped.
- **New colliding `VisualKind` exception**: section 4's `shelf_large -> salvage_shelf` is the
  *only* KayKit entry that becomes a new `VisualKind` rather than `PropKind`/`SceneryKind`
  dressing. `tests/world_map_validation.gd` currently asserts `"WORLD MAP VALIDATION OK (132
  checks)"` (`CLAUDE.md` section 12) against today's fixed obstacle roster; adding this one
  colliding kind changes that gate's own obstacle-count constants, not just the new gate
  proposed here — update `world_map_validation.gd` in the same commit that adds `salvage_shelf`,
  or that unrelated-looking gate goes red.
- **Draw-call ceiling** (section 5.2): assert the number of distinct (material, texture) pairs
  actually instantiated stays at or under this plan's **10**-batch budget, by collecting
  `(sprite.material.get_instance_id(), _texture_source_path(sprite.texture))` pairs across every
  obstacle/decor/scenery node the way the district gate's `material_ids` dictionary already does
  for one family, generalized across all atlases.

**What this gate cannot prove**, stated plainly rather than left implicit: perceptual variety —
whether the world actually reads as more varied — is not something a headless `SceneTree`
script can assert. The honest closing step is the same one every other visual family in
`CLAUDE.md` section 12 already uses: a fresh Mobile/Vulkan capture through
`world_render_validation.tscn` (work item 10 below), reviewed by a person against this plan's
section 2 table, before the slice counts as "integrated" rather than "unintegrated asset work"
per `CLAUDE.md` section 15.

## 7. Prioritized work list (highest visual-impact-per-hour first)

1. **Mirroring.** Add deterministic `flip_h` to existing sprite placement call sites.
   Code-only, no Blender, no Godot import step. Touches all 36 shipped frames immediately.
2. **Per-instance hue/value/saturation jitter.** Add `instance uniform` jitter parameters to
   `sleek_sprite_finish.gdshader` (bounds in section 3 item 3) and set them at placement
   time from the existing `_unit_noise`-style deterministic function. Code + one shader
   edit; removes the stamped look project-wide, including on every future frame.
3. **Pool-to-frame-key refactor.** Replace the 8-slot `PropKind`/`SceneryKind` modulo pools
   with frame-key string arrays (section 3 item 6). Code-only; this is the prerequisite that
   lets every later item actually reach the screen instead of hitting the current 8-kind
   ceiling.
4. **Run the wild/salvage bake and author the two missing atlas builders**
   (`build_polyhaven_wild_atlas.gd`, `build_polyhaven_salvage_atlas.gd`, following
   `build_polyhaven_district_atlas.gd`'s exact pattern). This is the first item that needs
   Blender. Produces the 74 designed frames from section 1.2.
5. **Wire wild/salvage frames into the biome table in section 2**, including the 4-6
   salvage micro-cluster composites (section 3 item 5). Code-only once step 4's atlases
   exist.
6. **KayKit palette-retarget bake batch** (section 4): add the license evidence file, run
   `bake_many()` for the 37 shortlisted models through `aaa_bake_rig.py`, author a 6th atlas
   builder. This is the highest new-vocabulary lever (stairs, chests, tables, free-standing
   wall fragments — nothing like this exists today) and the most manual step, since each
   model needs a palette-fit visual check, not just an automated import.
7. **Add a WILDERNESS bucket to `WorldBackgroundDecor2D`'s `DecorZone` enum.** Currently
   missing entirely (section 1.3/2) — wilderness is the only biome with zero dedicated
   decor. Needs the new low-lying wild frames (grass/fern/moss) from step 4 to populate it
   meaningfully, so sequence after step 4.
8. **Defer swamp/burnt-zone/field/riverbank biomes explicitly.** These require a new
   `Biome` enum value, a new terrain-atlas material, and new road/flow interactions — a
   biome-system slice, not a props slice. Flag as the next milestone candidate, not part of
   this plan's execution.
9. **VRAM-compressed import pass** (section 5.1) on all atlases, sequenced after step 6 so
   it covers the final atlas count in one contact-sheet-verified sweep instead of twice.
10. **Author `tests/world_variety_validation.gd` and refresh the GPU capture set.** Write the
    four-phase gate designed in section 6 (manifest/provenance, atlas resource, runtime
    dependency graph, world integration — including the mirroring, jitter, pool-diversity,
    WILDERNESS-bucket, and draw-call-ceiling checks) and update `world_map_validation.gd`'s
    obstacle-count constants for the one new `salvage_shelf` `VisualKind`. Then refresh
    `tests/world_render_validation.tscn`'s capture set for a human contact-sheet pass, since
    section 6 is explicit that perceptual variety is not something the headless gate can
    itself prove. Required before any of the above is "integrated" rather than "unintegrated
    asset work," per `CLAUDE.md` section 15.
