# Pitfalls Research

**Domain:** AAA+ 2D mobile authored-map redesign + visual overhaul (Godot 4.7.1 Mobile, existing generated 14×14 world)
**Researched:** 2026-09-18
**Confidence:** HIGH for this repo's recorded failure modes and Godot 4.7 engine contracts; MEDIUM for industry PCG/wayfinding analogies

This milestone fails if it treats visual polish as more scatter, more shaders, or more atlas stamps. Largest work is audit → contract → then author. CLAUDE.md already paid for the measurement lessons below; rediscovering them in a later phase is a rewrite.

## Critical Pitfalls

### Pitfall 1: Implement before the map redesign contract

**What goes wrong:**
World-authoring code, density knobs, new props, and atlas promotions land before anyone writes which districts have jobs, which landmarks name the 30s loop, and how way-home reads without the minimap. The generated 14×14 world already *looks* like a map. Tuning `WORLD_BUILD_SEED` dress layers feels like progress. It is oatmeal: more unique oats, same bowl.

**Why it happens:**
Seeded scatter has a short feedback loop (change a constant, re-run world-map 169). Authored composition has a long one (blockout, 1× review, collision/flow, capture set). Teams pick the short loop. Kate Compton's "10,000 bowls of oatmeal" is the industry name: mathematical uniqueness is not perceptual uniqueness. Tanya Short (Gamasutra, 2018): newbies fear chaos; they should fear blandness. Into the Breach authored battle layouts, then randomized only non-critical dress — the inverse of "retune scatter first."

**How to avoid:**
Phase 1 produces a written redesign contract before any world-authoring diff. Contract must name: district jobs (city choke, mall salvage, village quiet, forest threat); camp / road / landmark / salvage / threat beats of the 30s loop; way-home language that is not the minimap; which layers stay seeded filler vs become authored set pieces; locked extents 14×14 / ±14,336. No `BesprenResourceScatter2D` count retune, no new `WorldObstacle2D` family, no wild-frame promotion until that document exists.

**Warning signs:**
- First commit of the milestone edits `world_map_2d.gd` placement loops or scenery counts
- "We'll document the layout after we see it in captures"
- New atlas regions land in `src/world/` during the audit week
- Ground-cover or ambient counts move to answer a "sparse" complaint

**Phase to address:**
Phase 1 (audit / analyze / discuss / write contract). This is the load-bearing pitfall of the milestone.

---

### Pitfall 2: A capture gate proves nothing until re-run

**What goes wrong:**
Camp moved to `(9950, 2400)` in code while every PNG on disk still showed `(11264, 1536)`. Gates that read live constants and write artifacts prove the *previous* build until they run again. A later planner treats stale captures as evidence.

**Why it happens:**
Capture scenes are slow; Godot MCP `run_project` quota previously blocked them. Headless smoke is cheap and green. Humans read the PNG that is already in `artifacts/`.

**How to avoid:**
Re-run `tests/world_render_validation.tscn` (25 captures, not `--headless`) after every camp, atlas, or layout move. Treat on-disk PNGs as untrusted until their file date and camp position match live `STARTING_CAMP_POSITION`. Do not need the MCP runner — point the 4.7.1 binary at the scene.

**Warning signs:**
- Capture file dates older than the layout change
- Camp visible in the wrong cell of `overview` / `forest_camp*`
- Argument cites a PNG the current gate no longer writes (retired `world_forest_props`)

**Phase to address:**
Every implementation phase that moves camp, roads, obstacles, or atlases. Phase 1 contract should list the capture set that will prove the 30s loop.

---

### Pitfall 3: Capture-gate noise floor is TIME, not the change

**What goes wrong:**
Run the 25-capture gate twice on unchanged code: only eleven frames are byte-identical. The other fourteen move from shader `TIME` (resource pulse, camp `AmberLight`/aura, actor frames). Camp frames can move 5,912 pixels by day and 21,799 at night between identical runs — more than some real art diffs. A before/after that has not been measured against that floor attributes the clock to the art.

**Why it happens:**
`TIME` is not paused by `SceneTree.paused`. Pulse materials keep moving between difference-probe passes. Windowed Godot returns physical size (`960×540` under the project override), not logical 480×270, so coordinates are wrong by exactly 2× until scale is derived from the image.

**How to avoid:**
Measure noise floor (two identical runs) before attributing a diff. Judge tree claims on `forest_density` (stable). Pause the tree *and* pin `pulse_speed` to 0; hide other `TIME`-driven materials. Derive capture scale from the PNG. Delete probe scenes the moment they answer (CLAUDE.md 8).

**Warning signs:**
- Camp-adjacent capture used as evidence for a tree or prop change
- Difference probe without paused tree or pinned pulse
- Coordinates assumed as 480×270 from a windowed run

**Phase to address:**
Visual and world implementation phases; validation after each atlas/layout change.

---

### Pitfall 4: A metric that includes a feature drawn outside the subject is measuring that feature

**What goes wrong:**
This lesson hit the project at least four times: Base `HealthBar2D` inside a camp-body mask; outline ring included in structure p10; three-pixel ring around a fir foot that was 22–34% trunk; wild-context card under a chain-link fence because the gate never tested `WorldObstacle2D` footprints. Confident numbers, wrong subject.

**Why it happens:**
The easy mask is composited alpha or a luma cut against ground. At delivered size the contour, bar, light spill, or occluder is a large share of the crop.

**How to avoid:**
Mask on source alpha downsampled through the same filter as colour, not the composite. Name what the mask admits. If two estimators disagree, decide which assumption the subject violates — do not average. Reuse the original instrument; a rewritten detector measures different crops.

**Warning signs:**
- Body p10 constant across different subjects (you found a floor or a ring)
- Mean luma ~15 above its own median (second population in the mask)
- Identical 72.0 body width on four actors (you measured the crop bound)

**Phase to address:**
All visual measurement work from Phase 1 probes through polish validation.

---

### Pitfall 5: Near-black capture background cannot test a dark subject

**What goes wrong:**
Contact shadows and dark structure bodies measured on luma-17 / luma-22 grounds. Peak delta saturates at the stimulus ceiling. `structure_visual_gameplay_scale.png` on near-black ground cannot judge a dark building against forest 50 / urban 60.

**Why it happens:**
Review scenes like a black void so silhouettes "pop." Shadows and dark grade live in the bottom 20 luma. The void eats them.

**How to avoid:**
Probe dark subjects on the shipped modal ground (forest ~50, urban ~60). Difference-isolate shadows (tree paused, shadow branch hidden on pass 2). Never judge contact or structure exposure on a luma-22 plate.

**Warning signs:**
- Capture background mean well under terrain modal
- Before/after peak delta identical and tiny
- "The shadow is gone" on a black plate

**Phase to address:**
Actor/prop/structure visual phases; any new contact or grade work.

---

### Pitfall 6: Hue-band that straddles two anchors reports one family as the other

**What goes wrong:**
20–70° "gold" band counted Heikki's rust tank as Gold identity. Tent canvas counted as Shane cyan. Forest canopy complaint attributed warm mass to trees when the dirt road owned 58% of the warm population. Identity and district-readability claims invert.

**Why it happens:**
A convenient hue window is drawn across two locked anchors. CLAUDE.md 8 palette splits rust (`#BC431A`, ~15°) from gold (`#FFD45A` / `#FFB52E`, ~40°+) near 30°.

**How to avoid:**
Check band edges against locked anchors *before* quoting a separation figure. Split rust/gold at 30°. Do not use `g > r` by one unit (flags authored Worn steel). Identity must stay redundant across hue, silhouette, iconography, placement (CLAUDE.md 11) — hue-only district identity will fail at 480×270.

**Warning signs:**
- Warm-share claim that moves when the band edge moves 5°
- "Trees are competing with the camp" from a hue mask that also selects roads

**Phase to address:**
Phase 1 readability criteria; later art/grade phases.

---

### Pitfall 7: A constant that describes one thing is reused for another job

**What goes wrong:**
`marker_radius` (threat ring) became enemy contact radius — 2.7× spread across the cast. Bake `ground_offset` (projected origin) was named `foot_offset` and used as feet. `TEXTURE_PIXEL_SIZE` authored a screen-space outline. `SHADOW_FOOTPRINT_SCALE` matched a UI affordance to a stance. CLAUDE.md: "A pipeline value that is correct for the job it was derived for will be reused for a job it was never measured against."

**Why it happens:**
An authored pivot looks like an answer. Matching two numbers that share a class feels principled.

**How to avoid:**
Before copying a constant, write one sentence: what quantity it measures. Contact radii come from silhouette bands, not marker rings. Outline width is screen-space (`fwidth(UV) * width * stretch`), not texels. After a wild rebake, re-derive `WILD_TREE_REGIONS` as `cell_region.xy + padded_atlas_region.xy` — `padded_atlas_region` is cell-local.

**Warning signs:**
- One scale applied to eight bodies
- Docstring claims a derivation that fails arithmetic (`GROUND_FLATTEN` 0.46 is not sin(52°) = 0.788)
- Copying `padded_atlas_region` verbatim into an atlas-absolute `Rect2`

**Phase to address:**
World atlas consumption and actor presentation phases. Do not "fix" `GROUND_FLATTEN` without a Mobile/Vulkan sweep on real ground.

---

### Pitfall 8: Per-segment coin flip does not deliver adjacent variety

**What goes wrong:**
Village fences used `_unit_noise < 0.5` per segment. One fence in eight shipped all-unflipped; half had three identical neighbours. The stamp-repeat the flip existed to kill is the likeliest run. Same species as "more random dress = authored place."

**Why it happens:**
Independent Bernoulli trials maximize run probability of the thing you hate. At 1× the eye reads adjacent copies, not the global 50/50.

**How to avoid:**
Author adjacent difference by construction (seeded phase + alternating flip). Variation must be deterministic from `stable_seed`. Do not retune `FENCE_SEGMENT_*` to hide the remaining house/barricade projection mismatch — that is a camera/bake problem.

**Warning signs:**
- `0,0,0,0` or `1,1,1,1` on a four-segment run
- Direct MAD between neighbours ≈ 5–9 while mirror MAD ≈ 20 (same orientation)

**Phase to address:**
World dress / village pass after the contract; not a Phase 1 scatter tweak.

---

### Pitfall 9: Pocket table and obstacle table authored separately will overlap

**What goes wrong:**
`WILDERNESS_POCKETS[2]` sits under `OstariSouthShell` foundation (x 1650..8050, y -4050..-2250). 12,031 samples found no clear centre for a 156-unit card. Ambient still samples "wilderness." Gate now allows exactly one unhostable pocket; a second fails.

**Why it happens:**
Scenery pockets and colliding shells are edited in different files, on different days, with different RNG streams.

**How to avoid:**
Any new pocket is sampled against `WorldObstacle2D.get_world_bounds` and road-edge clearance, not only origin walkability. Keep `MAXIMUM_UNHOSTABLE_POCKETS = 1` as a tripwire. Record overlap; do not silently move the pocket (that changes ambient determinism and world-map 169 counts). If layout is authorized, edit obstacle table and pocket table in the same change.

**Warning signs:**
- Pocket labelled wilderness that intersects a mall/city shell
- Forest pockets that sit entirely inside road-clearance and donate their budget
- Gate `unhostable > 1`

**Phase to address:**
Map implementation phases after the contract names pocket jobs. Phase 1 must inventory current overlaps, not "fix" them by shrinking a shell visual.

---

### Pitfall 10: Shader entry `COLOR` is already textured; `texture * COLOR` squares

**What goes wrong:**
Seven canvas shaders (`sleek_sprite_finish`, `sleek_canvas_grade`, `toon_emissive_outline`, `surface_weathering`, `projectile_glow`, `solid_white_flash`, `base_scale_glow`) used `vec4 source = texture(TEXTURE, UV) * COLOR`. Every texel shipped as its per-channel square — gamma-2.0 darkened before any grade. Godot 4.7 CanvasItem docs: fragment `COLOR` is already vertex/modulate × default `TEXTURE`. Empty `fragment()` is `COLOR = COLOR`. Godot 3 required a manual lookup; godot-docs#8280 recorded the stale docs. Copy-pasting a Godot 3 header re-squares the dressed world.

**Why it happens:**
Tutorials and muscle memory. A grade tuned through a square is tuned for a source the player never sees.

**How to avoid:**
New canvas shaders start from `vec4 source = COLOR;`. Keep the squared idiom only in comments. After any shader fix, re-run the model's own comparison before re-deriving grade numbers — the thing that moved may be the render, not the decision.

**Warning signs:**
- Fragment header samples `TEXTURE` into `COLOR`
- Modulate tints crush twice
- Offline model and GPU disagree by ~one 0.05 gamma step after a "grade" change

**Phase to address:**
Any shader/polish phase. Grep `texture(TEXTURE` in `shaders/` as a merge gate.

---

### Pitfall 11: `unshaded` CanvasItem exempts subjects from night `CanvasModulate`

**What goes wrong:**
`toon_emissive_outline`, then `sleek_canvas_grade` and `sleek_sprite_finish`, used `render_mode unshaded`. Refuge, resources, survivors, then the entire built world and dressing, held daylight while the ground fell to blue hour. Official 2D lights tutorial: unshaded skips lighting *and* `CanvasModulate`. Godot 4 lighting happens in the regular draw pass; `unshaded` means albedo only.

**Why it happens:**
`unshaded` looks like "I do my own COLOR, don't light me." It also means "ignore night." Audit on a frame that does not contain the material (open wilderness 0.27%) closes the case wrongly.

**How to avoid:**
World materials stay `blend_mix`. `unshaded` is for HUD that must ignore night, not for camp, props, or structures. Audit exemption as share of pixels whose night-to-day luma ratio > 0.92 on frames that actually contain the material. Additive Base aura is allowed to hold.

**Warning signs:**
- Night capture with full-value props on a darkened ground
- New shader with `render_mode unshaded` under `shaders/` for world content

**Phase to address:**
Lighting/atmosphere and any new CanvasItem shader.

---

### Pitfall 12: Outline authored in texels delivers different weights at different scales

**What goes wrong:**
`TEXTURE_PIXEL_SIZE * outline_width` is one source texel. Delivered thickness ran 0.13–2.83 screen px (21.6×) at gameplay zoom 0.38 — thinnest on player-built structures. A four-tap cross below one pixel is not a thin contour; it is no contour. Base Core, the emotional centre, drew 0.766 px of edge.

**Why it happens:**
An outline is a screen-space quantity authored in a unit the player never sees. Raw `fwidth` without `stretch` would be physical pixels and break under `canvas_items` stretch (1080p vs 1× logical).

**How to avoid:**
Offset = `fwidth(UV) * outline_width * stretch` with `stretch = (1.0 / SCREEN_PIXEL_SIZE.x) / 480.0`. Judge contours at 1× logical (exact for `fwidth`+stretch). Do not make one material per scale band.

**Warning signs:**
- New shader steps outline by `TEXTURE_PIXEL_SIZE`
- Structures read as cutouts with no ring while city blocks look inked

**Phase to address:**
Shader/polish phases; verify on delivered structure vs prop frames.

---

### Pitfall 13: 1× is worst-case for texture minification under `canvas_items` stretch

**What goes wrong:**
Resource SVG icons at 128 px, no mipmaps, linear filter, 5.7× minification at 1×: Wood anchor 11.2 px vs Metal/Tech ~70. A 24 px raster looked better at 1× and must not ship — on a 1080×2400 panel the 128 px master is minified 1.43×, and the 24 px raster would magnify into blocks.

**Why it happens:**
Desktop gates are 1×. Minification is a physical-pixel quantity under stretch. Contours (`fwidth`) are logical; textures are not. Mixing the two families' scale rules inverts the decision.

**How to avoid:**
Judge contours at 1×. Judge minified textures at 1× *and* simulated device scale. Enable mipmaps when a master is minified. Do not replace a 128 px master with a 24 px raster because the 1× capture aliased.

**Warning signs:**
- Icon shimmer that moves with sub-pixel camera phase
- Decision to downsample a master based only on 1× capture

**Phase to address:**
Icon/HUD/resource visual work; import settings review.

---

### Pitfall 14: Runtime multiply cannot fix a value defect baked into pixels

**What goes wrong:**
`WILD_TREE_TINT` greened the canopy (hue) and could not lift the contact puck (value). The puck was luma 1.8–3.6 baked into the PNG; the finish floor sits at ~13. A multiply only loses value.

**Why it happens:**
Tint is a one-line "fix" that shows in the editor. Value defects live below the tint's reach.

**How to avoid:**
Hue defects may take a temporary multiply (`WILD_TREE_TINT`) with both consumers on the same constant. Value defects rebake. Durable pine fix is exposure that does not AgX-desaturate toward tan, then drop the tint.

**Warning signs:**
- Foot band still a hole after a tint change
- One consumer updated, ambient chunk not (or the reverse)

**Phase to address:**
Wild/environment rebake phase — not a scatter retune.

---

### Pitfall 15: A silhouette defect that survives every grade is geometry

**What goes wrong:**
Fir "poker chip" was a 0.35 m glTF mound under a 0.17 m bole. Darken it → black puck. Leave it → lit disc. No ramp can grade away a hexagonal disc twice the trunk width at the contact row. Holdout plane at `FIR_GROUND_CLIP = 0.40` was the fix. Canopy density (stalk with tiers) is still open — a clip cannot invent mass.

**Why it happens:**
Grade is the cheap lever. Geometry is the true silhouette.

**How to avoid:**
If every grade leaves the same shape, fix the bake (holdout, denser source, two-clone clump). Re-derive both `WILD_TREE_REGIONS` tables after any fir crop change — shorter crop *enlarges* the tree because fit is `collision_radius * 4.35` on the longer edge.

**Warning signs:**
- Contact ramp "fixes" that invert to the opposite puck
- Sparse fir still a stalk at 1× on `forest_density`

**Phase to address:**
Environment bake phase after the contract; 1× verdict on `forest_density` (zero TIME delta).

---

### Pitfall 16: Promoting forbidden wild non-tree frames / salvage atlas

**What goes wrong:**
Of 29 wild frames, runtime draws five tree yaws. Root clusters read as tan boulders (~2.1× ground, no contact). Branches as black worms (contour 3:1 over subject). Recipe-B shrub as a crack on the slab. `runtime_promotion = forbidden_pending_human_visual_veto`. Salvage atlas is packed and manifested, named by nothing under `src/` or the export closure.

**Why it happens:**
Green capture counts look like promotion. Packed + SHA-256 looks like shipped.

**How to avoid:**
Keep the veto until a new composition passes 1× review on hosted pockets. Do not wire `ROOT_REGIONS` / `BRANCH_REGIONS` / `SHRUB_REGION`. Do not add salvage to `runtime_export_closure.json` until a live `preload` exists. A 1× review is a measurement with a verdict; a deferred review is promotion by default.

**Warning signs:**
- New `Rect2` literals for non-tree wild cells in `src/world/`
- Salvage paths in the export closure
- "The gate captured 36 frames so the shrubs are in"

**Phase to address:**
Out of scope for promotion until a later art composition pass explicitly lifts the veto. Phase 1 must restate the veto, not reverse it.

---

### Pitfall 17: Shrinking extents, extra fullscreen passes, or shipping Node3D

**What goes wrong:**
"Make the world feel denser" by shrinking 14×14. "Make it AAA+" with glow, HDR 2D, a second weather pass, shadow-casting 2D lights, or runtime GLTF. Godot 4.7 Mobile uses R10G10B10A2 unless `rendering/viewport/hdr_2d` is on — then RGBA16F, ~2× bandwidth. Extra fullscreen passes and screen-texture reads break subpasses on tile-based GPUs. CLAUDE.md 10 budget: one custom fullscreen pass, zero shadow-casting 2D lights, zero dynamic shader loops, HDR 2D off, no runtime 3D.

**Why it happens:**
Desktop Forward+ habits. AAA+ in this GDD means authored places on the mobile bar, not cinematic lift.

**How to avoid:**
Extents stay ±14,336. Weather/atmosphere stay in `weather_overlay.gdshader`. Additive sprites if a light is too expensive (official alternative) — they cannot light fully dark areas or cast shadows. Blender workshops stay offline behind `.gdignore`.

**Warning signs:**
- `hdr_2d` flipped in `project.godot`
- Second `CanvasLayer` fullscreen material
- `Light2D.shadow_enabled = true`
- `Node3D` / GLTF under `scenes/` or export closure

**Phase to address:**
All phases. Hard constraint, not a later optimization.

---

### Pitfall 18: Minimap / HUD as the way-home (world never wayfinds)

**What goes wrong:**
Level Design Book: always-on HUD/minimap is ~97% certainty wayfinding. If the 30s loop and way-home are only legible with the 72×54 minimap, the world is still generated scatter. Done criteria require a stranger to point at camp, road, landmark, salvage, threat at 480×270 without a label, and way-home from roads/silhouettes/landmarks.

**Why it happens:**
The HUD already works. Landmarks without local contrast are set dressing (Lynch: landmarks need to be useful). Density clutter hides hierarchy.

**How to avoid:**
Phase 1 contract names landmarks that contrast at 1× (silhouette + placement, not hue alone). Capture the loop with HUD hidden as a review instrument (shipping HUD stays). Do not add more HUD chrome to compensate for an unreadable road graph.

**Warning signs:**
- Playtest "I used the minimap to find camp"
- Districts distinguishable only by ground tint
- Every tile filled; no negative space around a weenie

**Phase to address:**
Phase 1 success criteria; proven in later capture phases.

---

### Pitfall 19: Presentation-only sprites drift from collision and flow

**What goes wrong:**
Atlas sprites replace presentation only. Collision, flow mask, seed, and `resolve_player_motion` stay canonical. Tree visual scale is `collision_radius * 4.35` — a shorter fir crop draws 1.03–1.07× larger at the same blocker. Ambient canopy at `z_index = -4` leans over a road the flow field treats as open. Players walk through dressed volume or stop in empty footprint.

**Why it happens:**
"It's just art" plus visual scale derived from radius.

**How to avoid:**
Grep collision/flow before any visual scale change. World-map validation keeps asserting obstacle counts, walkability, and flow raster independently of sprite regions. Do not "fix" a stuck player by shrinking a sprite, or a silhouette by grading geometry.

**Warning signs:**
- Walkable according to 169, blocked according to the screenshot
- Fence flip/slip/wobble "fixed" by moving `CollisionShape2D`

**Phase to address:**
Every world implementation phase.

---

### Pitfall 20: Inserting RNG into an existing `WORLD_BUILD_SEED` stream

**What goes wrong:**
Visual-only density still consumes sequential RNG. One extra roll shifts every later placement. Accent layer exists specifically to avoid perturbing ambient streams. Dual `WILD_TREE_REGIONS` literals in `world_obstacle_2d.gd` and `world_ambient_scenery_chunk_2d.gd` drift independently on rebake.

**Why it happens:**
Adding a roll in the obvious loop is one line.

**How to avoid:**
New visual layers get their own salt (`WORLD_BUILD_SEED + N`) and must not insert into existing loops. Re-run world-map 169 after any placement edit. After every wild pack, re-derive both region tables from the manifest with the same script.

**Warning signs:**
- World-map counts move when "only dress" changed
- Colliding trunks and distant canopy sample different atlas cells

**Phase to address:**
World implementation after contract.

---

## Moderate Pitfalls

### Pitfall 21: Hand-maintained export closure goes stale silently

**What goes wrong:**
`class_name` + `.new()` scripts are invisible to a scene-graph walk. Feedback stack shipped while named in neither `runtime_export_closure.json` nor `runtime_export_dependencies.tscn`. Gate sat at 194/195 and passed because it was not re-run against the closure it pins. Last APK/PCK predates that stack (173 resources vs source 201).

**How to avoid:**
When adding a `class_name` constructed from code, add script + packed scenes to closure and strong-retain scene in the same change. Re-run smoke. Do not certify from `Bespren-actor-roster.*`. This visual milestone still needs a current package before any device claim — device certification itself remains out of scope.

**Phase to address:**
Any phase that adds a visual class constructed in code; packaging before a later device gate.

### Pitfall 22: Docs vs live scenery/capture counts

**What goes wrong:**
`docs/WORLD_MAP_FOUNDATION.md` still carries 576 silhouettes / 172 forest / 23 captures / world-map 150. Live: 640 scenery, forest 236, captures=25, world-map 169.

**How to avoid:**
Treat `CLAUDE.md` and live `.gd` constants as canonical. Refresh foundation docs in the same change that moves counts. Phase 1 contract must quote live numbers.

**Phase to address:**
Phase 1 inventory; any count-changing implementation.

### Pitfall 23: Measuring the recovery path as the shipping actor

**What goes wrong:**
`heikki_topdown.png` / `shane_topdown.png` are Start Menu cards and `force_legacy_presentation`. Gameplay draws baked `hero_*.tscn`. Measuring the 320 px portraits as in-world survivors produced false silhouette/hue findings.

**How to avoid:**
Confirm the shipped draw path before measuring an asset. Keep legacy line weight in family with world sprites so recovery does not look like a second game.

**Phase to address:**
Actor visual polish.

### Pitfall 24: Shared readability widgets get a second implementation

**What goes wrong:**
`PlacedStructure2D` hand-rolled mint `draw_rect` bars and flat `draw_circle` contacts after `HealthBar2D` / `GroundShadow` existed. Loud-mint towers and hole-in-the-ground contacts. A class docstring that claims uniqueness does not make it unique.

**How to avoid:**
Grep `draw_rect` / `draw_circle` health or contact primitives rather than trusting the docstring. New widgets call the shared implementations.

**Phase to address:**
Structure/HUD visual phases.

### Pitfall 25: Light `range_z_min` vs terrain `z_index = -20`

**What goes wrong:**
Terrain sits at `z_index = -20`. A light whose Z range misses that band lights actors over dark ground. Project pins `range_z_min = -20` at three sites (`network_player.tscn`, `base_core.tscn`, `placed_structure_2d.gd`). Godot 4.7 `Light2D` class default is `-1024` (not the GDD's remembered −10). Copying a guessed engine default, or omitting the pin on a new gameplay light, still produces floating bodies.

**How to avoid:**
New `PointLight2D` nodes that should reach ground copy the project pin. Read the live node; do not treat a stale GDD default as engine truth. Do not add shadow-casting 2D lights without a budget exception.

**Phase to address:**
Lighting polish; any new local light.

### Pitfall 26: Compressive operator after a treatment undoes the treatment

**What goes wrong:**
`REST_DARKEN` then `Color.lightened(0.42)` re-inflated the health-bar bevel. Gate asserted `fill_color()` (input) not `bevel_color()` (output). "A gate that tests the input to a compressive operator does not test its output."

**How to avoid:**
Test operator outputs. Assert bevel/fill as a ratio. Order: lift then darken in the rest branch.

**Phase to address:**
HUD/health visual work.

### Pitfall 27: Density retune answering a stale or masked complaint

**What goes wrong:**
Ground cover looked sparse on a first colour pass; after value-pair presentation the gameplay capture already carried 4.42% pixels ≥18 luma above modal ground. Tripling 3,245 clusters would have multiplied something that was not missing (placement cost was already cut 1,908 ms → 192.5 ms via broadphase). Same pattern: "sparse forest" answered by more atlas stamps.

**How to avoid:**
Measure delivered occupancy before changing counts. Authored landmarks beat more oats. Broadphase stays; do not revert walk queries to a linear scan over ~461 obstacles on the 20 Hz tick.

**Phase to address:**
Phase 1 (forbid count-only answers); world dress only after composition.

### Pitfall 28: Folding mechanics into a visual/map milestone

**What goes wrong:**
Base deposit, persistent inventory, progression, new combat rules, Android lifecycle, two-device LAN. None of these make the 14×14 read as places. They dilute the contract.

**How to avoid:**
Out of scope stays out. Accessibility 0-scales already exist; do not build a settings UI in this milestone unless the contract explicitly adds it. Device certification remains a later release gate.

**Phase to address:**
Phase 1 scope lock.

## Minor Pitfalls

### Pitfall 29: `GROUND_FLATTEN` 0.46 docstring is arithmetically false

Docstring claimed 52° projection; `sin(52°) = 0.788`; 0.46 is `sin(27.4°)`. Keep 0.46 until a rendered sweep brackets 0.46 vs ~0.79 vs 1.0 at zoom 0.38 on real ground. Changing it unseats every measured contact.

### Pitfall 30: Wild-family EEVEE determinism is one-unit, not bit-identical

Survivor bakes must match exactly (tEXt chunks aside). Wild/salvage rebakes may move ≤1 channel on ≲0.1% of pixels. Mixing contracts hides real drift. Smoke pins the atlas PNG, not the wild manifest — a stale manifest is caught by nothing.

### Pitfall 31: `run_wild_bake.py` drops the other family from the report

A single-family bake rebuilds `families` from scratch; the packer requires both and refuses. Always bake both or hand-merge.

### Pitfall 32: Windowed parse failure leaves Godot hanging

An untyped `for` under `untyped_declaration = 2` can leave the window open. Kill the process before re-run. SubViewport 480×270 is true 1×; windowed 960×540 is not.

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Seeded atlas-stamp dress | Fast coverage, deterministic | Oatmeal districts; 1× stamp-repeat | Filler only, after authored landmarks exist |
| `WILD_TREE_TINT` multiply | Hue fix without rebake | Hides bake exposure; cannot lift value | Temporary, both consumers, until pine rebake |
| Dual `WILD_TREE_REGIONS` literals | No shared-module work | One-site rebake desyncs trunks vs canopy | Until a pass touches either file; then one constant |
| Hand-maintained export closure | Simple smoke pin | Silent miss of `class_name`.new() | Never grow it without the new script in the same PR |
| Probe scene left in `artifacts/` | Convenient re-check | Stale PNG becomes "evidence" | Never — delete when answered |
| Coin-flip variation | One line | Adjacent runs of identical stamps | Never for adjacent segments |
| Extra fullscreen / HDR 2D "just to see" | Desktop pretty | Bandwidth, subpass break, budget breach | Never on this milestone |
| Promote vetoed wild frames | More unique props | Unreadable microprops in wilderness | Never until 1× veto lifts |
| Shrink extents for density | Feels denser | Breaks 14×14 contract, flow, scatter IDs | Never |
| Certify from old APK | Skip export | Ships without feedback stack | Never |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Godot 4.7 CanvasItem shaders | `texture(TEXTURE,UV)*COLOR` (Godot 3 habit) | `vec4 source = COLOR;` |
| Godot 4.7 2D lights | `unshaded` for world materials | `blend_mix`; HUD may be unshaded |
| Godot 4.7 Mobile renderer | Enable HDR 2D or extra passes for glow | Keep HDR 2D off; one weather overlay |
| Light2D Z range | Guess default −10 from GDD | Read live node; project pin −20 for ground |
| Blender 5 EEVEE bake | Treat wild SHA-256 as bit-identical | One-unit / 0.1% contract for wild/salvage |
| Poly Haven / vault | Promote from `Addons/` or salvage atlas | Audited extractor only; veto stands |
| ENet / OfflineMultiplayerPeer | Presentation writes simulation | Peer-one authority; sprites do not move colliders |
| Capture gates | Trust PNG without re-run | Re-run after layout/atlas; measure TIME floor |
| `docs/WORLD_MAP_FOUNDATION.md` | Quote 576 / 23 captures | Live `.gd` + CLAUDE.md |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Extra fullscreen pass / HDR 2D | Bandwidth, heat, 30 FPS on mid Android | Budget: 1 pass, HDR 2D off | Tile-based GPU immediately |
| Shadow-casting 2D lights | Fill + occluder cost | Zero in foundation; additive sprites if needed | First shadow-casting light in busy night frame |
| Linear walk over ~461 obstacles | 25 ms/s of wall clock at 20 Hz × 2 seats | Keep 512-unit broadphase (~3.8 µs) | Already broke; do not revert |
| Triple ground-cover clusters | 192 ms world-build becomes 500+ ms | Measure occupancy first | World enter hitch |
| Overlapping PointLight2D | Showcase is allowed; shipping is not | Cull off-screen; limit overlap | Thermal throttle on device (unmeasured) |
| Horde cap raise | CPU + draw | `MAX_ALIVE_ENEMIES = 110` is a device decision | Night wave |
| Dynamic shader loops | Mobile instruction variance | Bounded math / LUTs | Mid-range Mali/Adreno |

Device frame time is **unmeasured**. Do not claim 60 FPS from desktop gates.

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Promote vault content without license review | Compliance (Atomic Realm may not ship as an asset pack; Poly Haven CC0 is fine) | Extractor + manifest only; no `Addons/` in APK |
| Expose UDP 8791 beyond LAN | Unauthenticated host authority | Trusted-LAN slice; no new internet auth in this milestone |
| Clients growing a second simulation | Desync / cheat on gather and build | Presentation never writes pool, nodes, or positions |
| Destructive `Addons/` cleanup | Irreversible source loss | License manifest + confirmation first |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Atlas-stamp districts | Cannot tell city from forest at 1× | Authored set pieces + landmark silhouettes |
| Way-home only on minimap | Lost on a 480×270 shared screen | Roads, camp amber, named landmarks |
| Identity by hue alone | Colour-vision / 14×23 px actors fail | Hue + silhouette + icon + placement |
| Clutter / no negative space | Landmarks invisible | Density contrast (Lynch / Level Design Book) |
| HUD covering 30s-loop proof | False "readable" | Review captures with HUD hidden; shipping HUD stays compact |
| Touch occlusion ignored while adding world chrome | Fingers hide landmarks | 44×44 targets and safe-area already exist; do not grow world-space UI |
| Night-exempt props | Camp reads as a daylight decal | `blend_mix` world materials |
| Walk-through canopy / stop-in-empty-footprint | Trust break | Presentation ≠ collision |

## "Looks Done But Isn't" Checklist

- [ ] **Redesign contract:** Named district jobs, 30s-loop beats, way-home without minimap, locked extents — not just a prettier seed
- [ ] **1× stranger test:** Camp, road, landmark, salvage, threat pointable without labels on 480×270 captures
- [ ] **Capture set re-run:** 25 world frames after layout/atlas; camp at live `(9950, 2400)` or whatever the contract moves it to
- [ ] **TIME noise floor:** Two identical runs; tree claims on stable frames only
- [ ] **Wild veto:** Non-tree frames still forbidden; salvage not in export closure
- [ ] **Shader grep:** No `texture(TEXTURE, UV) * COLOR`; no world `unshaded`; outlines use `fwidth`+stretch
- [ ] **Region literals:** Both wild-tree tables match `cell_region.xy + padded_atlas_region.xy`
- [ ] **Pockets vs obstacles:** Overlaps recorded; `unhostable ≤ 1`; no silent pocket move
- [ ] **Collision/flow independent:** World-map 169 still asserts walkability after visual scale changes
- [ ] **RNG salts:** New dress layers did not insert into existing streams
- [ ] **Export closure:** New `class_name` scripts listed; do not install actor-roster APK
- [ ] **Budgets:** No HDR 2D, no second fullscreen pass, no Node3D, no shadow-casting 2D lights, extents unchanged
- [ ] **Shipped draw path:** Actor measurements from `hero_*.tscn`, not Start Menu portraits
- [ ] **Shared widgets:** No new `draw_rect` health bars or `draw_circle` contacts
- [ ] **Mechanics creep:** No deposit / inventory / progression / device cert in this milestone

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Implemented before contract | HIGH | Stop coding. Write the contract. Revert scatter/prop diffs that are not in the contract. |
| Stale capture set | LOW | Re-run world render gate; delete retired PNGs |
| TIME attributed as art | LOW | Two identical runs; keep only diffs above floor on stable frames |
| Squared shaders | MEDIUM | `source = COLOR`; re-measure grades on GPU before retuning uniforms |
| Unshaded night exemption | MEDIUM | `blend_mix`; re-check night/day ratio on frames that contain the material |
| Promoted vetoed frames | MEDIUM | Revert `src/world/` wiring; restore forbidden flag; 1× review from scratch |
| Pocket silently moved | HIGH | Restore pocket; edit obstacle+pocket together; re-run 169 + wild-context |
| RNG stream insert | HIGH | Revert roll; own salt; accept world-map count churn only with a pin update |
| Extra pass / HDR 2D / Node3D | HIGH | Revert setting/node; restore single weather overlay |
| Collision/visual drift | MEDIUM | Restore footprints; change presentation only; re-run 169 |
| Old APK used for "done" | LOW | Rebuild from current closure; do not call it device cert |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Implement before contract | **Phase 1** | Contract exists; no world-authoring code in the Phase 1 diff |
| Oatmeal scatter / density retune | Phase 1 | No scenery/cover/resource count changes; landmarks named |
| Minimap as way-home | Phase 1 (criteria) + later captures | 1× review with HUD hidden |
| Forbidden wild/salvage promotion | Phase 1 restates veto | Grep `src/world/` for non-tree regions; closure has no salvage |
| Extents / HDR / extra pass / Node3D | Phase 1 constraints, all later | `project.godot` + shader list + export closure |
| Mechanics creep | Phase 1 scope | No deposit/inventory/progression files |
| Docs vs live counts | Phase 1 inventory | Contract quotes live 640 / 25 / 169 |
| Pocket/obstacle overlap inventory | Phase 1 record; fix in map-impl | `unhostable` census in contract |
| Capture re-run + TIME floor | Each impl phase | Fresh 25 captures; noise floor logged |
| Metric-outside-subject / near-black / hue-band | Visual validation | Probe checklist in VERIFICATION |
| COLOR square / unshaded / texel outline | Shader/polish phase | Grep + night/day ratio + 1× ring probe |
| Runtime tint vs baked value / geometry silhouette | Environment bake phase | Fir 1× on `forest_density`; puck gone |
| Coin-flip adjacent copies | Village/dress phase | Alternating phase, not Bernoulli |
| Presentation vs collision | Map-impl | World-map 169 independent of sprites |
| RNG stream insert / dual Rect2 | Map-impl | Own salts; both region tables from manifest |
| Export closure / old APK | Packaging (not device cert) | Closure matches new scripts; no actor-roster install |
| Shared widgets / recovery-path measure / z-range | Visual polish | Grep primitives; confirm draw path; lights pin −20 |
| Device FPS / two-device LAN | **Not this milestone** | Do not mark done from desktop gates |

## Sources

Repo (HIGH — primary for this milestone):

- `CLAUDE.md` sections 7–12, 16 — measurement lessons, budgets, capture contracts
- `.planning/PROJECT.md` — subsequent milestone scope and "audit before authoring"
- `.planning/codebase/CONCERNS.md` — live overlaps, veto, TIME noise, closure drift

Godot 4.7 official (HIGH — engine behavior):

- [CanvasItem shaders](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/canvas_item_shader.html) — fragment `COLOR` already includes default `TEXTURE`
- [godot-docs#8280](https://github.com/godotengine/godot-docs/issues/8280) — Godot 3 manual-lookup docs were wrong for Godot 4
- [Internal rendering architecture](https://docs.godotengine.org/en/4.7/engine_details/architecture/internal_rendering_architecture.html) — Mobile R10G10B10A2 vs HDR 2D RGBA16F; extra passes break subpasses
- [2D lights and shadows](https://docs.godotengine.org/en/4.7/tutorials/2d/2d_lights_and_shadows.html) — `CanvasModulate`, unshaded exemption, additive-sprite alternative
- [Light2D](https://docs.godotengine.org/en/4.7/classes/class_light2d.html) — `range_z_min` / `range_z_max`; 4.7 class default `range_z_min = -1024`

Industry (MEDIUM — analogy, not a substitute for CLAUDE.md):

- Kate Compton, “10,000 bowls of oatmeal” / [So you want to build a generator](http://galaxykate0.tumblr.com/post/139774965871/so-you-want-to-build-a-generator) — perceptual uniqueness
- [Gamasutra: Devs weigh in on procedural generation](https://www.gamedeveloper.com/design/devs-weigh-in-on-the-best-ways-to-use-but-not-abuse-procedural-generation) (2018) — blandness vs chaos; Into the Breach authored layouts
- [Level Design Book — Wayfinding](https://book.leveldesignbook.com/process/blockout/wayfinding) — paths/edges/districts/nodes/landmarks; HUD as 97% crutch; playtest without theory

---
*Pitfalls research for: Bespren visual AAA+ & authored 14×14 map redesign*
*Researched: 2026-09-18*
