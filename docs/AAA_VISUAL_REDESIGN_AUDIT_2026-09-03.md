# AAA++ Visual Redesign Audit — Current Decision Record

**Date:** 2026-09-03  
**Target:** Godot 4.7.1 Mobile, Android, 480 x 270 logical landscape, local/LAN co-op  
**Scope:** every physical file below `C:\Users\heikk\Desktop\Claude\gpt_peli\Addons`, all archive members that the supported parser can safely open, and every current runtime visual family.  
**Status:** audit and redesign decision record. It is deliberately not a claim that the proposed replacement work, Android certification, or a human review of all candidate art has completed.

This document consolidates the older implementation reports into a current, evidence-led decision. `docs/VISUAL_ASSET_OVERHAUL_AUDIT.md` and `docs/overhaul/*.md` remain useful historical design and validation records; their date, stated capture limitations, and prior assumptions must be rechecked before treating a claim there as current.

## 1. Evidence, coverage, and honest boundary

| Evidence | Verified result | What it proves / does not prove |
|---|---:|---|
| `artifacts/asset_audit/addons_file_ledger.jsonl` | **31,404** physical Addons files, 2,355,834,247 bytes | Every physical file was classified and SHA-256 hashed. A hash/classification is not a subjective art approval. |
| `artifacts/asset_audit/archive_member_ledger.jsonl` | **4,684** recursive archive members, 892,666,069 decompressed bytes | Supported ZIP/KRA/FLA and gzip-tar/Unity-package members were path-checked and fully decompressed for integrity. It is not a persistent “extract every proprietary format” claim. |
| `artifacts/asset_audit/deep_asset_audit_summary.json` | **159** physical/nested containers, **1,887** duplicate physical files, **978** duplicate members | Source-vault scope is exhaustive for its supported format contract and remains immutable. |
| Persistent all-physical safe extraction stage | `artifacts/asset_audit/extraction_runs/vault-all-physical-20260903/run_manifest.json`: **31,259** loose physical files and **4,684** supported archive members are staged (**35,943** payloads / **3,068,269,449** bytes); **145** archive-wrapper files are separately hash/ledger verified, **159** recursive containers are covered, and the post-stage source rehash covers all **31,404** physical files / **2,355,834,247** bytes with **0** rejection rows. The final read-only validator directly returned `status: valid` for the same 35,943 payloads. | Every loose source payload plus every supported archive content member is materialized below an ignored, export-excluded, content-addressed staging tree—not below `Addons` and not in the shipped runtime. Archive wrappers are intentionally verified but not byte-copied because their contents are staged separately. Successful extraction remains evidence, not licence approval or runtime promotion. |
| Deep decision ledger | **9,886** visual candidates; **3,531** of them have no license signal | “candidate” is a review queue, never permission to ship. |
| `assets/runtime_asset_manifest.json` | **12** direct reviewed vault promotions | Runtime art must retain a source → licence → derived-output → scene-reachability chain. |
| Current runtime tree | 154 actor-family files, 9 structure PNGs, 36 already-shipped environment frames across three baked atlas families | There is a substantial foundation, but not yet a coherent premium presentation at gameplay scale. |
| Fresh world GPU captures | `artifacts/world_render_validation.json` records **23** 480x270 Forward Mobile/Vulkan captures generated on 2026-09-03; the separate Godot launch output identified AMD Radeon(TM) 610M. Examples include camp day/night, city density, wilderness, transition, and car wreck. | This is materially stronger than headless loading and was visually reviewed. It is still desktop-GPU evidence, not Android panel/thermal/touch/audio/two-device LAN proof. |
| Fresh live-survivor GPU captures | `artifacts/player_presentation_render_validation.json` records the native capture dimensions plus 480x270 logical review outputs for the real `NetworkPlayer`/`PlayerAvatar` path at the 0.38 gameplay scale: Heikki idle/run plus Shane fire/down, in day and sapphire-night captures. | The adapter, action binding, scale correction, and downed marker were visually reviewed on desktop Mobile/Vulkan. It does not certify a full in-world combat capture, Android, touch, or LAN. |
| Fresh start-menu GPU captures | `artifacts/start_menu_render_validation.json` records native capture dimensions plus two real 480x270 logical Mobile/Vulkan review outputs: Heikki selected and Shane selected. The captured scene includes the explicit active chip/frame, the address field, and three fully contained 44px deployment controls. | This validates the live boot-menu composition and both selection states on the desktop Mobile renderer. It does not certify Android safe areas, touch feel, or a complete animated-diorama pass. |
| Other visual captures | `artifacts/{enemy_presentation_library,structure_visual_library,tactical_hud_dashboard}.png` | Representative desktop evidence only; it does not certify Android panel contrast, thermals, touch ergonomics, sound perception, or real two-device LAN. |
| Boot-only renderer evidence | `scenes/showcase/visual_validation.tscn` launched under Godot 4.7.1 Forward Mobile on AMD Radeon(TM) 610M with no debug errors, then stopped. | It proves that showcase boot completed on that desktop GPU. No screenshot, Android-device, touch, audio, or LAN evidence was produced by that run. |

### Safe “unpack every file” interpretation

The deep audit fully reads every *supported* archive member without altering `Addons`. The completed `vault-all-physical-20260903` stage additionally materializes all **31,259** loose physical source files and all **4,684** matching supported archive members under `artifacts/asset_audit/extraction_runs/`; its **145** physical archive wrappers are hash-verified without redundant byte-copying. The persistent operation keeps this boundary:

1. write only below a new audit/staging directory outside `Addons` and outside runtime `res://` art;
2. reject absolute, drive-qualified, traversal, symlink/device, duplicate-normalized, oversized, or unsupported member paths before write;
3. preserve source archive/member hashes, byte counts, container ancestry, and licence association in a manifest;
4. never call an unsupported compound binary “unpacked”; retain its physical hash and record the parser limitation instead;
5. never promote staging output merely because it extracted successfully.

That turns “every file” into a reproducible evidence operation, rather than a destructive copy or a silent licensing bypass.

## 2. Current art-direction diagnosis

The game already has the right **survival-refuge** premise: weathered timber/steel, a singular amber Base Core, cool night readability, salvage, and an isometric/top-down camera. The current visual weakness is not a lack of individual assets. It is that the player-facing frame mixes polished offline renders with small procedural geometry, pixel-art foliage, minimally composed UI, and highly visible diagnostic overlays.

### The required visual hierarchy

1. **Player and immediate threat first:** readable silhouette, heading, state, and aim at 1x 480x270.
2. **Base and build choice second:** amber refuge, clear defense role and cooldown/armed state.
3. **Navigation silhouette third:** a player can identify forest, settlement, industrial ruin, road edge, and safe camp without a map label.
4. **Texture/detail last:** surface wear supports a silhouette; it must never erase touch targets, hostile tells, or interactive affordances.

The target is *premium mobile 2D*, not desktop 3D: a small number of reusable, coherent baked atlas families; controlled value hierarchy; motion with intent; and no runtime GLTF, Blender scene, `Node3D`, high-cost post-processing, or authority-coupled visuals.

### Fresh 480x270 GPU review (interpretive, not a device claim)

The 2026-09-03 Forward Mobile capture set makes four player-facing shortcomings unambiguous. These are visual-review conclusions from the cited captures, not automated test results:

| Capture evidence | Human-review finding | Consequence |
|---|---|---|
| `world_forest_camp_composition_validation.png` and `_night_validation.png` | The camp is mostly repeated grime with isolated satellite props; it does not yet compose as a survivor refuge. Sapphire night remains readable but thin. | Give the camp a contained silhouette/negative-space plan: tent/core, work zone, storage, defensive edge, fire/radio focal point, and vegetation transition. |
| `world_city_density_validation.png` | City density mixes incompatible scales/material languages and lets near-black masses dominate the view. | Normalize value floor/edge treatment and replace unrelated assets with a coherent hard-surface/salvage family. |
| `world_wilderness_density_validation.png` and `world_city_forest_transition_validation.png` | Pixel-tree clusters remain visually obvious and ecosystem layering is sparse. | Prioritize the CC0 wild slice, low/mid/tall vegetation strata, and biome-specific deterministic pools before adding more random props. |
| `world_local_car_wreck_validation.png` | The car wreck reads comparatively well at gameplay scale. | Retain it as a quality/scale reference for the replacement environment family rather than discarding all current local-baked work. |

## 3. Audit scorecard and replacement decisions

| Area | Verified baseline | Design verdict | Replacement / redesign decision |
|---|---|---|---|
| Start menu | `scenes/ui/StartMenu.tscn` now uses a 480x270 refuge-network composition: two 225x110 survivor cards, explicit active chip/frame, signal/session panel, amber/cyan semantics, and a clear `DEPLOY / SOLO` plus LAN Host/Join action trio. `start_menu_render_validation.json` has both live selection captures. | Initial premium hierarchy is implemented and the action targets remain legible/contained at true scale. It is not yet the fully authored moving refuge diorama or five-second survivor micro-animation target. | Keep the implemented semantic split and touch geometry. Add only a restrained, asset-provenanced diorama/pose layer after device safe-area and frame-cost review; never replace the independent 44x44 actions with a decorative full-screen click target. |
| HUD, deck, mobile controls | The dashboard capture leaves most of the frame visually empty; the validated resource/action dashboard is compact and touch-safe. | Correct geometry is not premium composition. Information hierarchy, feedback, and world/UI handoff are weak. | Keep safe-area and touch geometry; redesign visual hierarchy, card art, cooldown/wind-up, resource gain, blocked placement, wave/boss transitions, and haptic/audio coupling. |
| Heikki and Shane | Baked directional sheets/scenes now bind through the real `PlayerAvatar` path, with host-driven idle/run/aim/fire/hit/death selection, a legacy fallback, and `player_presentation_live_{day,night}.png` review captures. | The adapter is now a verified technical foundation rather than unused source art. The first true-scale capture exposed an undersized baked body, which was corrected presentation-only to match the legacy body read; in-world action composition remains a later gate. | Keep the baked scenes as primary with the safe local fallback. Feed only replicated/authoritative motion, facing, accepted fire, accepted interaction, hit/death—never local cosmetic input as simulation. |
| Zombie / boss roster | Eight stable catalog entries have baked scenes and eight headings. The inspected library is much more coherent than mixed-pack art, but marker rings, glyphs, and bars compete with body silhouettes. `EnemyPresentation2D` currently has an idle/walk state path, while other clips need event wiring. | The roster has an identity foundation; it is not yet visually disciplined enough at real camera scale. | Reduce persistent marker language to a quiet state layer; reserve emission/overlay for mechanics. Wire spawn, attack, hit, death and boss taunt to replicated/host-authoritative events. Add boss arrival staging and damaged-state readability without changing enemy IDs, stats, collision, or flow. |
| Towers, utilities, traps, Base Core | Nine 320px render assets exist. `structure_visual_library.png` shows distinct colors but extremely small, dark forms. Every current structure `.import` has `mipmaps/generate=false`. | Role coding is present but the silhouette and state machine need premium pass. | Re-bake the camp and eight defenses through one palette/camera/lighting contract. Enable and visually inspect mipmaps or appropriate VRAM compression. Add acquire, firing, cooldown, armed/spent, depletion, scorch/debris presentation through the existing presentation-only layer. |
| Terrain, props, nature | The runtime uses 36 environment frames across `polyhaven`, `polyhaven_district`, and `local_baked`; `WorldBackgroundDecor2D` has 420 props but `world_background_decor_chunk_2d.gd` still draws many circles, lines, and simple polygons. `world_wilderness_density_validation.png` exposes repeating pixel-art foliage beside rendered props. | This is the largest premium-quality gap: density exists, but variety, material consistency, and biome storytelling do not. | Keep collision/flow ownership intact; replace procedural low-salience forms with varied baked frame keys, deterministic mirror/yaw/value variation, zone-specific pools, and a dedicated WILDERNESS bucket. Do not mass-place new art until the small CC0 slice passes 1x review and memory profiling. |
| Effects, lighting, weather | Nine visual shaders are present; `weather_overlay.gd` and its shader exist. The game scene must be rechecked for live WeatherOverlay instantiation; the showcase uses it. | Good ingredients but not a complete, ordered feedback language. | Keep one full-screen weather overlay. Add bounded reusable impact, muzzle, harvest, build, EMP, boss-arrival, and destruction visual states; retain Base amber as the only dominant warm beacon. |
| Audio–visual coupling | Four current runtime gameplay/UI audio assets are listed in `assets/audio/`. | The motion/readability system needs sound and haptic punctuation, not more continuous effects. | Pair accepted actions only with pooled, rate-limited audio/haptic cues: interact complete, host-approved fire, placement accepted/rejected, structure wind-up/fire/spent, boss arrival/death. Device test every cue at normal phone speaker volume. |

## 4. Source-vault disposition — every asset family has a gate

### 4.1 What can be used now

| Family | Evidence | Disposition |
|---|---|---|
| Poly Haven environment/district/terrain already baked | Existing manifests under `assets/2d/environment/` and reproducible Blender scripts | Keep as baseline; re-review visually before extending. Runtime consumes only derived 2D output. |
| New Poly Haven wild family | `tools/art/blender/vault/polyhaven_wild/_fetch_manifest.json`: **16 CC0** models (trees, trunks, roots, shrubs, fern, grass, moss, rocks, branches) | Preferred source for forest/wilderness variation. Bake offline, manifest every input/output, then promote only reviewed frames. |
| New Poly Haven salvage family | `tools/art/blender/vault/polyhaven_salvage/_fetch_manifest.json`: **16 CC0** models (barrels, crates, jerrycan, propane tank, toolbox, lamp, utility box, compressor, etc.) | Preferred source for roadside/camp/industrial salvage. Same offline-only contract. |
| Fresh isolated bake trial | `artifacts/wild_salvage_trial/polyhaven_wild_render_report.json`: moss x1 and toolbox x2 frames, zero errors; SHA-256/margin/luma verified | The pipeline can render a narrow trial, not a runtime asset pack. Toolbox is a viable review candidate. Moss is technically valid (407 visible pixels, 0.0404 m tall, luma 36.952) but is only a potential visual-only ground-cover cluster: it must not become a lone gameplay prop, landmark, or collision obstacle without a true-scale silhouette/semantic review. |
| KayKit Character/Dungeon assets | Licence evidence is present in Addons; historical actor pipeline is already based on KayKit CC0 | Eligible only after per-source manifest and visual fit review. Favor CC0 hard-surface/rubble/wood forms that close a documented gap. |
| Kenney / MIT / ClawAndBlade | Licence signals present in the ledger and established source chains exist | Retain only when their visual language can be baked/graded coherently and licence text permits the intended distribution. |

### 4.2 What must not be silently promoted

* The 3,531 candidate visual files without a detected licence signal.
* Any Addons pack whose terms restrict commercial use, redistribution, or derivation until the exact licence text and planned use are reviewed.
* Pixel-art, fantasy, orthographic, side-view, or non-top-down sources merely because they are attractive in isolation.
* Raw GLTF/FBX/Blend, PBR materials, 3D lights, or authoring scenes in the shipping 2D runtime.
* Existing `Addons` content by copying/referencing it directly. The vault remains `.gdignore` source material.

### 4.3 Blender / Poly Haven production rule

Use Blender/Poly Haven as an **offline art department**: an isolated workshop or `--background --factory-startup` worker imports one reviewed source, applies the shared orthographic camera, normalised ground pivot, readable alpha margin, palette/lighting contract, then renders PNG frames. A builder packs the frame atlas and writes provenance (source URL/id/licence/hash, workshop hash, renderer hash, output hash, frame bounds, luma, and scene reachability). The interactive unsaved Blender scene is never overwritten.

## 5. Detailed redesign plan

### 5.1 Menu, HUD, controls, typography

**Menu redesign — initial act/review complete.** The live menu now has a low-contrast refuge/grid layer, readable command layer, two distinct survivor cards, explicit non-colour active state, signal/session language, and independently accessible `DEPLOY / SOLO`, Host LAN, and Join LAN targets. Two true-size Mobile/Vulkan captures confirm both selection states. The next visual increment is a low-cost moving camp/road silhouette and five-second idle/run/aim card micro-loops from the approved hero path; do not make the menu a movie or delay first interaction.

**HUD redesign.** Keep the current validated 148x58 dashboard footprint, 72x54 minimap, and 44x44 targets. Improve the order of attention: resource deltas briefly rise from the relevant icon; the active construction card gets a single strong outline; invalid placement has a restrained red ground tell and one rate-limited error cue; boss/wave moments occupy a temporary hierarchy slot then release it. Use icon lineage from reviewed `at-icons`/CC0/MIT source only, not arbitrary Addons UI art.

**Acceptance:** at 1x 480x270, a first-time tester identifies selected hero, connection state, three action buttons, active build card, shared resources, and immediate boss/wave state in five seconds; every touch control remains at least 44x44 logical pixels after safe-area adjustment; no control intercepts world input outside its visual/declared hit region.

### 5.2 Survivors and animation language

* Make Heikki and Shane recognisable by silhouette first, accent second: distinct shoulder/head/weapon mass, with amber reserved for camp and survivor accent colors never impersonating resource colors.
* Primary clips: 8-direction idle and walk/run; event clips: accepted fire, gathering/interaction, hit, death. Optional secondary loop is an almost-still breathing/weight shift, not visual noise.
* The animation adapter must choose the heading with `ActorFacing` from replicated/authoritative movement/facing, preserve the old presentation as fallback, and resume locomotion after a non-loop action finishes.
* Do not scale/flip a baked directional hero independently; it destroys the authored heading/pivot relationship. Do not touch the `CharacterBody2D`, collision, input, or peer-one state to improve art.

**Acceptance:** each survivor shows the correct directional idle/walk frame after an authoritative state change; accepted fire/interact reaches a non-loop action clip; fallback remains loadable; headless contract tests plus 1x day/night and action captures show grounded feet/no pivot drift.

### 5.3 Zombies and bosses — every variant

| Variant | Premium visual purpose | Mandatory tell / action pass |
|---|---|---|
| Walker / Toxic Brute | baseline infected silhouette | Simple rotten mass; no persistent decorative glyph. |
| Rat Swarm / Crawler Pack | fast, fragile, many | Three separate low bodies and fastest cadence; legible before color resolves. |
| Static Walker / Static Conduit | dangerous EMP source | Asymmetric cyan power cell plus pre-death warning radius/wind-up tied to the authoritative state. |
| Scrap Shield / Scrap Bulwark | slow armored advance | One wide hard-edged plate and slow cadence; marker only reinforces, never replaces it. |
| Goliath | first mass boss | broad shoulder mass, arrival/taunt, hit and depletion feedback; 40–48px body read at gameplay scale. |
| Carrier | cargo/corruption boss | carried object clearly separates from torso; controlled toxic state, never camp amber. |
| Splitter | foretells splitting mechanic | visible divided torso/seam before death; spawn add cue derives from actual split event. |
| Overlord | final escalation | tallest silhouette, contained interior emissive, arrival/title/death sequence without a permanent UI obstruction. |

At the 0.38 gameplay camera, target approximately 24–28px for ordinary horde bodies, 16–20px for the crawler cluster, and 40–48px for bosses. These are review targets, not a substitute for device captures. One sprite family may carry static semantic color; mechanic-critical tells must also survive grayscale/silhouette review.

### 5.4 Towers, traps, utilities, and Base Core

All nine images need a source-geometry and state-presentation pass. Rebuild through one current bake rig rather than accruing a fourth visual dialect: fixed 3/4 top-down camera, normalised ground pivot, outline width proportional to intended 37–54px play-space size, controlled cool shadow/warm edge, and an atlas/contact sheet review.

| Asset | Silhouette / state priority |
|---|---|
| Kinetic | low armored base plus unmistakable barrel; acquire → tracer → cooldown glow. |
| Chemical | two offset tank masses; toxic pulse is mechanics-only and never hides target silhouettes. |
| Electric | high coil/mast; brief cyan spool-up before arc, with a cooldown dim state. |
| Support | vertical mast/antenna; must not read as an offensive tower. |
| Barricade | long, grounded blocking silhouette; damaged and destroyed debris/scorch state. |
| Landmine | small but high-contrast armed indicator; trigger flash + retained scorch, not a silent vanish. |
| Slowing Pit | readable depression/field edge; armed/slow/cooldown contrast without an always-on light. |
| Razor Snare | crossed-blade resting silhouette; restrained violet armed state and unambiguous reusable cooldown. |
| Base Core | survivor refuge, not fantasy castle: tent ridge, workbench, supplies, radio mast, restrained amber aura. |

Do not alter `StructureCatalog`, placement, collision, flow field, resource cost, refunds, or host tower decisions. State presentation subscribes to those existing outcomes.

**Acceptance:** nine thumbnails are distinguishable in a shuffled grayscale contact sheet; each defense state (idle, acquire, fire/trigger, cooldown, depleted/spent) is identifiable in a 3-second 1x capture; imports use a verified minification strategy; no new permanent light per enemy/prop or a second full-screen pass is introduced.

### 5.5 World variety, terrain, props, and nature

The world already has six biome identities (forest, city, mall, west/east village, wilderness), 420 procedural props, 36 baked frames, terrain blending, and deterministic placement. The visual issue is **repeat grammar**: fixed small pools and simple primitives make a large world look stamped. The plan must increase diversity without destroying seeded collision/reachability.

1. **First vertical slice:** bake and inspect a very small CC0 wild/salvage selection (for example tree, root, fern/moss, rock, barrel/toolbox) before the full 32-source bake. Fix lighting, alpha margin, luma, pivot, and scale from a real camera view.
2. **Replace pool mechanics, not only texture count:** move from short modulo `PropKind` pools toward deterministic frame-key pools, mirroring, yaw variants, bounded value/saturation jitter, and per-zone frequency weights. Stable seed + index must still reproduce exactly.
3. **Forest/wilderness:** layered tall tree / fallen trunk / root / shrub / fern / grass / moss / rock / branch hierarchy with deliberate clearings and sight lines. Give WILDERNESS its own low-lying grass/fern/moss/stone bucket instead of borrowing forest cadence.
4. **City/mall:** use salvage clusters (barrel/crate/jerrycan/toolbox/utility box), wrecks, barriers, wall fragments, scaffolding and broken pavement to tell activity/abandonment, not random clutter.
5. **Villages/camp:** distinguish civilian remnants from survivor functionality: bedding, storage, radio, repair, table/seat, wood barricade. Keep amber light local to the camp.
6. **Next biome-system proposal, not a stealth prop patch:** burned/ash, wetland/water edge, and open-field/farmland require terrain, road, flow, and world-map design—plan them as a separate authoritative world slice.

**Acceptance:** every biome receives a 1x day/night capture; each contains at least three foreground/midground/background silhouette families plus intentional negative space; a blind reviewer can identify the biome in grayscale; no collision/flow/reachability/sync regression; texture/batch counts and Android frame time are measured before density is raised globally.

### 5.6 VFX, lighting, weather, audio, and accessibility

* One weather overlay only; change uniform presets for rain/ash/storm rather than layer full-screen effects.
* Pool finite world VFX: projectile impact, harvest complete, build accept/reject, EMP warning/impact, chemical burst, electric arc, boss arrival, and structure destruction residue.
* Base amber is the dominant warm signal. Toxic is green, electric is cyan, alerts are crimson/violet only when mechanic-specific; do not light every scenic prop.
* Pair the critical visual beats with rate-limited pooled sound/haptic feedback after accepted actions. Respect reduced-motion, screen-shake, flash, and high-contrast settings.
* Validate night floor/contrast, color-blind semantic redundancy, and a reduced-effects tier before adding bloom, particles, or screen distortion.

## 6. Performance, texture, and export gates

* The current three environment atlases plus terrain are already a material mobile texture budget. A previous plan estimates roughly 32.3 MiB uncompressed-with-mips for the shipped set; adding two full 256px 1536-wide wild/salvage atlases would raise the estimate to roughly 58.3 MiB before actors/UI. Recompute the actual imports before relying on either number.
* New wild/salvage assets must start as a narrow trial, use shared texture/material paths, and prove ETC2/VRAM-compressed alpha quality through a contact sheet before full-family promotion.
* Reuse the two cached environment finish materials; no per-instance `ShaderMaterial`, per-prop `PointLight2D`, or new Y-sort container.
* Boss sheets should remain VRAM-compressed and load on demand if profiling confirms residence pressure. Frame count is a safer reduction lever than boss silhouette cell size.
* Test Mobile Vulkan and GL compatibility path separately if both are supported. Desktop/headless success is a contract gate only.
* Each new asset source must be added to the runtime export dependency closure and isolated PCK/APK inspection must prove that neither Addons nor Blender/GLTF/source vault payload leaks into the build.

## 7. Audit → analyze → plan → act → review loops

| Loop | Analyze / plan | Act only after plan approval | Review / exit gate |
|---|---|---|---|
| 0 — provenance and extraction | Reconcile full ledger, archive ancestry, licence text, duplicates, and runtime reachability. | **Completed evidence act:** safe staging extraction + provenance manifest with no runtime promotion. | Hash/count match and path-safety negative tests passed; a human licence decision per selected source remains mandatory. |
| 1 — live character vertical slice | Verify the real PlayerAvatar path, action events, camera scale, fallback, and directional clips. | **Completed for the initial slice:** primary baked adapter, legacy fallback, correct 0.38-scale body read, critical downed marker, and day/night capture path. | `SMOKE OK (203 checks)` plus Mobile/Vulkan live-adapter day/night capture; still require an in-world action/day-night contact sheet and Android review before release certification. |
| 2 — small environment proof | Compare the fresh moss/toolbox trial against gameplay scale, luma, alpha margin, terrain, and survivor silhouette. | Fix bake rig and integrate only the smallest approved frame set behind existing decor helpers. | World/smoke validation, one real-camera contact sheet, texture/batch measurement. |
| 3 — full map vocabulary | Expand wild/salvage, then KayKit rubble/architecture only where a documented gap remains. Refactor deterministic frame-key pools and WILDERNESS. | Bake/manifest/atlas/builders, integrate biome by biome while retaining collision parent/flow mask/seed contracts. | Per-biome day/night/grayscale review, runtime closure audit, Android frame/thermal/profile data. |
| 4 — combat and command polish | Replace defense source geometry; wire enemy and defense event states; redesign menu/HUD feedback. | **Initial menu pass complete:** apply the remaining defense/enemy/HUD families one at a time with presentation-only signals and pooled VFX/audio. | Hero/enemy/structure/menu contact sheets; functional focused tests; touch/safe-area inspection. |
| 5 — device and LAN certification | Test the final composition under real Android thermal, loudness, color/contrast, safe-area, lifecycle, and two-device conditions. | Tune tiers/density/effects only from measured failures. | Device sign-off and capture matrix; no claim of AAA++ release readiness before it. |

## 8. Priority order and non-negotiable acceptance matrix

**P0 — do before broad asset production**

1. **Completed extraction evidence gate:** safe provenance/staging extraction is hash-validated; source-by-source licence selection remains a separate mandatory gate.
2. **Completed initial slice:** make the baked survivor animation family visible in the real game through authoritative presentation state, with legacy fallback and a true-scale day/night capture.
3. **Completed technical trial only:** repair the wild/salvage runner and accept/reject a tiny real-camera vertical slice; do not promote the trial frames yet.
4. Add a 480x270 review scene/capture matrix that includes day, night, combat, menus, and grayscale.

**P1 — highest player-facing quality return**

1. Replace procedural/repeating world decor via deterministic frame-key variation and a WILDERNESS bucket.
2. Re-bake and state-polish the Base Core plus eight defenses.
3. Reduce enemy overlay dominance, wire action clips, and add static-EMP/boss event tells.
4. **Initial menu hierarchy complete:** retain its verified mobile geometry; redesign the remaining HUD/build deck and add only measured, low-cost menu motion.

**P2 — depth after the core language is coherent**

1. KayKit rubble/walls/stairs/salvage micro-architecture where it closes real gaps.
2. Burnt, wetland, field, or water-edge biome systems as separately scoped world work.
3. Optional damaged enemy/structure variants, richer camp life, accessibility quality tiers, and expanded audio sets.

No item is “done” merely because a source downloaded, a Blender render looked attractive, an atlas packed, a headless check passed, or a screenshot existed. It is done only when the provenance chain, Godot import, runtime binding, 1x gameplay capture, collision/authority contract, export closure, and relevant device gate all pass.

## 9. Recommended current action

Do **not** mass-replace the entire world immediately. The live-hero adapter and narrow CC0 technical trial now exist; the next decision is to integrate a minimal, provenance-approved wild/salvage camera slice and review it beside live survivors at 480x270. That outcome decides the bake grade, import strategy, palette discipline, pool API, and mobile cost for every later replacement. This protects the project from a large, expensive art migration that looks premium in a Blender contact sheet but fails in the 480x270 co-op game.
