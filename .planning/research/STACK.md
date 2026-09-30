# Stack Research

**Domain:** Brownfield AAA+ 2D world composition and visual polish on an existing Godot 4.7.1 Mobile LAN co-op survival slice (Bespren)
**Researched:** 2026-09-18
**Confidence:** HIGH for keep-the-runtime-stack; MEDIUM for the new authored-map data format (not in repo yet)

Subsequent milestone. Do **not** replace Godot, ENet, typed GDScript, the atlas pipeline, or the 480×270 `canvas_items` viewport. Lift quality by authoring places and measuring 1× pixels inside the stack that already ships.

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Godot 4.7.1 Mobile + Vulkan | `4.7.1.stable.official.a13da4feb` (`PackedStringArray("4.7", "Mobile")`) | Shipping renderer | Already validation runtime. Mobile is Forward Mobile: tile-based, raster-only, default **R10G10B10A2** 2D buffer. Forward+ is desktop-clustered and poorly optimized for Android. Compatibility is OpenGL-only and drops MSAA 2D / HDR 2D / RenderingDevice. Keep `renderer/rendering_method="mobile"`. **Confidence: HIGH** |
| Logical viewport 480×270 landscape | `display/window/size/viewport_{width,height}` + `window/stretch/mode="canvas_items"` | Design size and stretch | Official 4.7 multiple-resolutions guide: `canvas_items` renders 2D at the **target** panel resolution from a design size. That is why mipmaps, `fwidth(UV)`, and 1× vs device-scale measurements differ. Do not switch to `viewport` stretch (pixelates the whole world) or raise the logical size (HUD, thermal, and every existing gate assume 480×270). Desktop override 960×540 is 2× preview only. **Confidence: HIGH** |
| Typed GDScript 2.0 | `gdscript/warnings/untyped_declaration=2` | Runtime, gates, world builders | Existing contract. New map/visual code stays `class_name`, typed arrays/signals/enums. No autoloads. **Confidence: HIGH** |
| CanvasItem shader family under `shaders/` | Godot 4.7 `shader_type canvas_item` | World grade, outlines, terrain, one weather pass | Lighting is computed in the **regular draw pass** in 4.x (no per-light redraw). `render_mode blend_mix` receives `CanvasModulate` and `PointLight2D`. Entry `COLOR` is already `texture * modulate`; never `texture(TEXTURE, UV) * COLOR`. Screen-space widths use `fwidth(UV) * stretch` against `LOGICAL_VIEWPORT_WIDTH = 480.0`. **Confidence: HIGH** |
| `TileMapLayer` (ground only) | Godot 4.7 (replaces deprecated `TileMap`) | Cheap biome/ground fill at `z_index = -20` | Official: one layer per node; `rendering_quadrant_size` batches 16×16 tiles **unless** Y-sort is on, in which case tiles group by Y and quadrant batching is skipped. Ground tiles must stay **not** Y-sorted. Collision/occlusion on tiles stay off — `WorldObstacle2D` owns WorldStatic. **Confidence: HIGH** |
| `PointLight2D` + `CanvasModulate` | Godot 4.7 Light2D | Local refuge/resource lights; night floor | Official 2D lights: lights add over unshaded albedo; `CanvasModulate` (`NightAtmosphere2D`) is the unlit floor. `Range > Z Min` must be `-20` so terrain at absolute z `-20` receives light. Texture scale costs fill-rate. **Confidence: HIGH** |
| Host-authoritative ENet | Existing `ENetMultiplayerPeer` UDP 8791 / `OfflineMultiplayerPeer` | Unchanged authority | Presentation must not write simulation. Map redesign may change world **data** (camp, roads, obstacles, resources) and must bump layout version; it must not change the peer-one path. **Confidence: HIGH** |
| Offline Blender 5.0 EEVEE → PNG/atlas | Blender `5.0.0` at `C:\Program Files\Blender Foundation\Blender 5.0\blender.exe` | Unique set-piece and landmark bakes | Existing isolated-scene policy, `aaa_bake_rig.py` (elev 52°, az −45°), AgX Medium High Contrast, Freestyle, transparent film, holdout clips. No GLTF/`Node3D` at runtime. **Confidence: HIGH** |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Existing shaders: `terrain_material_blend`, `sleek_sprite_finish`, `sleek_canvas_grade`, `toon_emissive_outline`, `surface_weathering`, `weather_overlay`, `road_surface_detail`, `volumetric_aura` / `base_scale_glow` | in-repo `shaders/` | One art direction, one full-screen pass | Always. New look = retune uniforms / add atlas frames, not new shader files, unless a new **job** appears (do not add a second weather/glow pass). |
| `WorldObstacle2D` + 512-unit walkability broadphase + 112×112 flow mask | in-repo `src/world/` | Canonical collision and navigation | Always. Visual sprites are presentation-only. Do not move collision into TileSet physics. |
| Chunked dress: `WorldBackgroundDecor2D`, `WorldAmbientScenery2D`, `WorldWildernessAccent2D`, `WorldGroundCover2D`, `WorldRoadNetwork2D` | in-repo, 4096-unit batches | Fill **after** authored landmarks | Keep as dress inside authored envelopes. Stop using them as the place itself. |
| Typed Godot `Resource` layout tables (new, thin) | GDScript `Resource` / `.tres` | Authored camp, roads, landmarks, salvage/threat pockets, district jobs | **The one real stack gap.** Seeded scatter cannot produce named places. Prefer const tables in `BesprenWorldMap2D` first; promote to `.tres` only when the audit contract needs editor-diffable data. Do not add Tiled/LDtk as a runtime. **Confidence: MEDIUM** (format not in repo). |
| Atlas families under `assets/2d/environment/` | Existing PNG + JSON manifests | Runtime art | More unique set pieces = more **baked frames** in existing families (or a new family with the same packer/manifest contract). Do not promote wild non-tree frames until the visual veto lifts. |
| Pillow (`PIL`) + NumPy | Host Python 3.11+ / Blender interpreter | Pack, audit, bake math | Host-only. Never a Godot export dep. |
| Poly Haven CC0 1k glTF (offline vault) | Existing fetch + workshops | New landmark/prop sources | Fetch → workshop → renderer → Godot atlas builder. Same path as district/wild. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Godot 4.7.1 console binary | Headless gates + windowed Mobile/Vulkan captures | `--headless --script` for contracts. Same binary **without** `--headless` for `tests/world_render_validation.tscn` (`captures=25`). Do not put Godot MCP `run_project` on the critical path. |
| `tests/world_render_validation.tscn` + sibling GPU gates | 1× readability evidence | `get_viewport().get_texture().get_image()`, then resize to 480×270 with LANCZOS **only for review stills**. Ring/outline/contact geometry: 480×270 `SubViewport` (true 1×) or divide a 960×540 windowed capture by 2. Measure the gate's noise floor by running it twice on unchanged code before attributing a diff to a change. |
| Temporary probe scenes | Difference isolation | Pause `SceneTree` before two-pass diffs. Pin shader `TIME` / `pulse_speed`. Hide additive aura. Retire the probe and its PNGs the moment they answer. |
| Blender 5.0 console (`blender.exe -b`) | Production rebakes | Isolated scene. Transparent film + holdout for ground-clip (fir mound lesson). Determinism: survivor family = byte-identical IDAT; wild/salvage family = ≤1 unit on ≲0.1% of pixels. |
| `tools/art/write_generated_asset_manifest.py` + family packers | Provenance | Re-run after every rebake. Smoke pins paths; a stale manifest is a silent failure unless a gate hashes it. |
| `tools/asset_pipeline/audit_and_extract_runtime_assets.py` | Vault → `res://` | Only reviewed runtime art. `Addons/.gdignore` stays. No destructive `Addons/` cleanup. |
| Host Python validators | Bake contracts, atlas CRC | Keep stdlib + optional PIL/numpy. No `requirements.txt` in the game. |

## Installation

No new runtime packages. This milestone does not add npm, pip, or Godot addons to the shipping game.

```powershell
# Runtime is the existing Godot 4.7.1 project. Confirm renderer + viewport:
# project.godot: renderer/rendering_method="mobile"
# project.godot: window/size/viewport_width=480, viewport_height=270, stretch/mode="canvas_items"

# Headless contract (after import)
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --editor --path 'C:\Users\heikk\Desktop\Claude\gpt_peli' --import --quit
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path 'C:\Users\heikk\Desktop\Claude\gpt_peli' --script res://tests/smoke_test.gd
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path 'C:\Users\heikk\Desktop\Claude\gpt_peli' --script res://tests/world_map_validation.gd

# GPU 1x captures (not --headless)
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64.exe' --path 'C:\Users\heikk\Desktop\Claude\gpt_peli' res://tests/world_render_validation.tscn

# Host bake tools already in repo (Blender 5.0 + Python 3.11+ with Pillow)
# tools/art/run_wild_bake.py, generate_camp_and_structure_sprites.py, run_actor_bake.py
# tools/asset_pipeline/build_polyhaven_*.gd, build_local_environment_atlas.gd
```

Do **not** enable `rendering/viewport/hdr_2d` (absent from `project.godot` today = engine default `false`). Do **not** `npm install` anything for this slice.

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Keep Godot 4.7.1 Mobile | Godot 4.8+ or Forward+ | Never this milestone. Forward+ is clustered desktop lighting; official renderer overview says it is poorly optimized on mobile. 4.8 would invalidate every gate binary pin. |
| `canvas_items` 480×270 | `viewport` stretch or raise logical res | `viewport` stretch is for pixel-art integer scaling. This game is mipmapped Blender bakes + `fwidth` contours; `canvas_items` is the correct physical-pixel path. Raise resolution only with HUD, readability, **and** thermal evidence — out of scope. |
| Authored Resource/const tables + existing builders | Paint the 14×14 in the TileMap editor | TileMapLayer is a **ground fill**, not a 28,672-unit collision/landmark graph. Macro cells are 2048 units; painting tiles cannot own roads, flow, or salvage pockets. |
| Authored Resource/const tables | Tiled / LDtk / Godot TileMap patterns as source of truth | Fine as an **offline** sketch if a later phase writes an exporter to `.tres`. Do not load TMX/LDtk at runtime and do not add an editor plugin this milestone. |
| Seeded dress **inside** authored envelopes | Pure seeded scatter (`WORLD_BUILD_SEED + N`) as the place | Keep seed for moss/rubble/ground-cover variation so two forests are not clones. Landmarks, roads, camp, salvage pockets, threat silhouettes must be explicit lists. |
| `PointLight2D` (no shadows) + `CanvasModulate` | Additive `Sprite2D` “lights” | Official cheaper alternative for short-lived FX (muzzle, explosions). Do **not** replace the Base Core amber light — additive sprites cannot light a fully dark `CanvasModulate` floor correctly. |
| Shared `ShaderMaterial` instances per family | Per-asset materials quantized by scale | Official and in-repo lesson: screen-space width via `fwidth`, not N materials. Runtime-scaled `PlacedStructure2D` cannot be binned. |
| Existing flow field | `NavigationRegion2D` / TileMap navigation | Official TileMap docs: built-in tile navigation is inferior; Bespren already has a measured 112×112 flow bake. Do not dual-stack. |
| Offline Blender 5 EEVEE PNG | Runtime GLTF / `Node3D` / MeshInstance2D | Violates the 2D-only export closure and mobile bandwidth. MeshInstance2D is still a mesh path. |
| One `weather_overlay` CanvasLayer | WorldEnvironment glow, extra `hint_screen_texture` passes, CompositorEffect | Mobile renderer: extra full-screen reads break subpasses and cost bandwidth. Glow is a 3D/env feature, not the 2D weather contract. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `rendering/viewport/hdr_2d` / `Viewport.use_hdr_2d` | Official architecture: Mobile default is R10G10B10A2; HDR 2D switches the buffer to **RGBA16F** and roughly **doubles** bandwidth. 4.7 HDR *output* is not Android. | Keep HDR 2D off. Emission via CanvasItem color + local lights. |
| Extra full-screen custom passes | CLAUDE.md §10 budget = **1**. Screen texture reads force a full write-out and kill Mobile subpasses. | Fold atmosphere + damage wash into `weather_overlay.gdshader`. |
| Shadow-casting 2D lights / `LightOccluder2D` | Foundation budget = **0** shadow-casting 2D lights. Occluders + PCF5/PCF13 are fill-rate and atlas cost; Directional 2D shadows are infinitely long. | Contact ellipses (`GroundShadow`) baked into sprites; `PointLight2D` with **Shadow disabled**. |
| `render_mode unshaded` on world subjects | Official: unshaded skips lighting. In-repo: camp, resources, survivors, props, structures held daylight while `CanvasModulate` fell to blue hour. | `blend_mix`. Aura may stay `blend_add`. |
| `vec4 source = texture(TEXTURE, UV) * COLOR` | Official fragment `COLOR` is already textured × modulate. The product is a per-channel square. | `vec4 source = COLOR;` |
| `TEXTURE_PIXEL_SIZE` outline taps | Delivers width in **source texels** × sprite scale × camera zoom (in-repo 21.6× spread). | `fwidth(UV) * outline_width * stretch` with `stretch = (1.0 / SCREEN_PIXEL_SIZE.x) / 480.0`. |
| Runtime GLTF / mesh / PBR / `Node3D` | Export closure and device bandwidth. Workshops are `.gdignore`. | Offline bake → atlas PNG + manifest. |
| Per-asset `ShaderMaterial` for scale bands | N materials to keep correct; breaks on runtime scale. | One family material + `fwidth`. |
| Normal/specular `CanvasTexture` + Laigter | Extra textures, light-height tuning, and 2D lighting cost for a 19–70 px delivered body. | Baked three-quarter lighting in Blender; sleek grade at runtime. |
| Y-sort on ground `TileMapLayer` | Official: Y-sort disables `rendering_quadrant_size` batching. Ground is a flat pass at z `-20`. | Y-sort only the gameplay parent (`YSortWorld` at z `5`). |
| TileSet physics / occlusion as world collision | Diverges from `WorldObstacle2D` footprints, flow mask, and host motion resolver. | Simplified rectangle/circle on `WorldStatic`. |
| Godot Glow, FXAA, SMAA, MSAA 2D, TAA, FSR as “AAA+” | Desktop/3D post stack. FXAA/SMAA are extra full-screen; TAA/FSR2 are Forward+ only; MSAA 2D is a bandwidth tax at 480×270. | Authored silhouettes, Freestyle in the bake, one weather overlay. |
| `Parallax2D` / stacked camera-relative layers | Fights 1× landmark readability and the absolute Z matrix. | Static absolute z `-20 / -5 / -4 / 5`. |
| Dynamic shader loops | Instruction-cost unpredictability on mobile. | Bounded hash/value-noise (existing `surface_weathering`). |
| New autoloads, new net protocol, new engine | Out of scope. | Compose under `GameWorld`. |
| Promoting `polyhaven_salvage` or non-tree wild frames | In-repo veto: 1× review failed (root clusters read as tan boulders). | New composition + new 1× verdict before promotion. |
| Destructive `Addons/` cleanup | Reproducibility of workshops/sources. | Promote through the audit script only. |

## Stack Patterns by Variant

**If changing presentation only (sprite, shader uniform, non-colliding dress):**
- Keep `WORLD_BUILD_SEED`, obstacle order, flow mask, resource IDs.
- Re-run family validators + world render gate. Judge diffs against the eleven stable (zero TIME) frames.

**If changing camp, roads, colliding landmarks, salvage pockets, or resource positions:**
- Treat as a **layout-version** change. Update flow bake, resource scatter rejection, ENet layout identity, and `world_map_validation.gd` counts.
- Authored lists first; seed only for intra-envelope dress.
- Capture the 30s loop path: camp → road → named landmark → salvage pocket → threat → back, at gameplay zoom **0.38**, 480×270.

**If adding a unique set piece:**
- New bake in an existing family (or a new family that reuses the packer/manifest/smoke pin).
- One shared finish material. Distinct silhouette at 1×, not a new shader.
- Collision footprint authored to the sprite the camera sees, not the bake origin.

**If measuring readability:**
- 1× logical is the verdict for contours (`fwidth` + `stretch`).
- Texture minification is a **physical-pixel** quantity under `canvas_items`; a 1× capture is a worst-case bound for aliasing, not the phone.
- Never judge a dark subject or contact shadow on a near-black capture ground.
- A metric that includes a feature drawn outside the subject is measuring that feature.

**If lighting a new world object:**
- `range_z_min = -20`. Visibility-gate off-screen lights. No occluders. No second full-screen grade.

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| Godot 4.7.1 Mobile | Vulkan Android + OpenGL fallback | Fallback is engine-side, not a project toggle. Gates run Mobile/Vulkan on desktop. |
| Godot 4.7.1 `TileMapLayer` | Ground pass at z `-20`, Y-sort **off** | `TileMap` node is deprecated. Do not reintroduce it. |
| Godot 4.7 CanvasItem lights | `blend_mix` materials; `range_z_min = -20` | Lighting in the normal draw pass. `unshaded` opts out of `CanvasModulate`. |
| Godot 4.7 `Viewport.use_hdr_2d` default false | Mobile R10G10B10A2 | Enabling is a bandwidth regression; not required for 2D lights. |
| Blender 5.0.0 EEVEE | Existing Python renderers + workshops | Holdout + transparent film confirmed in-repo for fir ground-clip. Do not bump to a newer Blender without rebake determinism evidence. |
| ENet 8791 / OfflineMultiplayerPeer | Unchanged RPC surface | Visual milestone may change world data, not net types. |
| Atlas packers (`build_polyhaven_*.gd`) | Manifest SHA-256 + smoke pins | A family bake that drops sibling families from the wild report breaks the packer — always bake both wild+salvage together or merge reports. |

## Map-authoring stack (the actual gap)

Current world: 14×14 biome table + eight authored road polylines + district obstacle builders, then **independently seeded** dress (`WORLD_BUILD_SEED+91/+137/+173/+211`). Deterministic, but it reads as scatter on a grid.

Prescribe this order — no new engine:

1. **Audit contract (data, not code):** named districts with jobs; 30s loop waypoints; way-home silhouettes; exclusion volumes. Write it before moving obstacles.
2. **Authored layout tables** (const arrays or `.tres`): camp, eight-plus road polylines, colliding landmarks, salvage pockets, threat pockets, teaching resources. Same `WORLD_BUILD_SEED` only as a dress salt.
3. **Keep** `TileMapLayer` + `terrain_material_blend` as the ground language; retune the biome mask to the new district edges so asphalt/forest/dirt **agree** with the authored roads.
4. **Keep** chunked dress, but sample **inside** envelopes and off landmark footprints (the existing pocket/exclusion idea, inverted: place is authored, fill is seeded).
5. **Proof:** headless layout hashes + 1× captures a stranger can point at without labels. A capture gate proves nothing until re-run after camp/layout moves.

Do not author the 28,672-unit world as a painted TileMap. Do not replace the Python/Blender atlas pipeline with a 3D runtime. Do not add HDR 2D to “make it AAA+”.

## Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Keep Godot 4.7.1 Mobile / Vulkan / 480×270 / `canvas_items` | HIGH | `project.godot` + official 4.7 renderer, architecture, and multiple-resolutions docs |
| Keep existing shader family, Z matrix, lights-without-shadows | HIGH | Official CanvasItem + 2D lights docs; in-repo CLAUDE.md §8–10, 16 |
| Keep Blender 5 offline atlas pipeline | HIGH | In-repo workshops/renderers/manifests; no gap that a new tool fills |
| Do not enable HDR 2D / extra passes / 2D shadows | HIGH | Official Mobile R10G10B10A2 vs RGBA16F; CLAUDE.md §10 budgets |
| Authored Resource/const map tables | MEDIUM | Right pattern for “not seeded scatter”; exact `.tres` schema not in repo — start with const tables |
| Tiled/LDtk as optional offline sketch | LOW | Not needed until an exporter exists; do not adopt this milestone |
| Device thermal cost of more unique atlases | MEDIUM | Desktop GPU gates ≠ Android; profile after content lands |

`gsd-tools query classify-confidence --provider websearch --verified` → **MEDIUM**. `--provider webfetch --verified` → **LOW** (seam under-rates official docs.godotengine.org). Claims below treat **official 4.7 documentation** as primary and the in-repo stack as corroboration.

## Sources

- [Godot 4.7 internal rendering architecture](https://docs.godotengine.org/en/4.7/engine_details/architecture/internal_rendering_architecture.html) — Mobile vs Forward+; R10G10B10A2 vs RGBA16F when `rendering/viewport/hdr_2d`; extra passes vs subpasses; 2D lights in one pass
- [Godot 4.7 overview of renderers](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html) — HDR 2D supported on Mobile/Forward+ not Compatibility; Forward+ poorly optimized on mobile
- [Godot 4.7 2D lights and shadows](https://docs.godotengine.org/en/4.7/tutorials/2d/2d_lights_and_shadows.html) — `PointLight2D`, `CanvasModulate`, Z range, occluders, additive-sprite alternative
- [Godot 4.7 CanvasItem shaders](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/canvas_item_shader.html) — fragment `COLOR` already textured; `unshaded`; `SCREEN_PIXEL_SIZE`; lighting in the draw pass
- [Godot 4.7 TileMapLayer](https://docs.godotengine.org/en/4.7/classes/class_tilemaplayer.html) + [Using TileMaps](https://docs.godotengine.org/en/4.7/tutorials/2d/using_tilemaps.html) — quadrant batching vs Y-sort; `TileMap` deprecated
- [Godot 4.7 multiple resolutions](https://docs.godotengine.org/en/4.7/tutorials/rendering/multiple_resolutions.html) — `canvas_items` vs `viewport` stretch; mipmaps on downsample
- [Godot 4.7 Viewport](https://docs.godotengine.org/en/4.7/classes/class_viewport.html) — `use_hdr_2d` default false; `get_texture()`
- In-repo: `.planning/codebase/STACK.md`, `ARCHITECTURE.md`, `CLAUDE.md` §8–10/16, `docs/WORLD_MAP_FOUNDATION.md`, `docs/WORLD_MAP_VISUAL_PRODUCTION_PLAN.md`, `project.godot`, `tests/world_render_validation.gd`

---
*Stack research for: Bespren visual AAA+ and 14×14 map redesign*
*Researched: 2026-09-18*
