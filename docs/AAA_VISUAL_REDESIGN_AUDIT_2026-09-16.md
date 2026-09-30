# AAA++ Visual Redesign — Current Audit, Decision and Review Ledger

Date: 2026-09-16  
Target: Godot 4.7.1, Mobile renderer, 2D, 480 x 270 logical landscape, Solo and LAN co-op  
Scope: every physical file under Addons, every supported nested archive member, and every player-facing current visual family.

## 1. Honest coverage boundary

The Addons vault was exhaustively classified without being modified. This means every physical file and every supported archive member has a hash, format decision, role signal, and provenance gate. It does **not** mean that 9,886 art candidates have all been manually approved for a premium game.

| Evidence | Result |
|---|---:|
| Physical Addons files hashed | 31,404 |
| Source bytes | 2,355,834,247 |
| Recursive archive containers checked | 159 |
| Archive members decompressed, integrity checked and hashed | 4,684 |
| Candidate visual files | 9,886 |
| Candidate visuals without a licence signal | 3,531 |
| Exact duplicate physical files | 1,887 |
| Direct reviewed vault promotions | 12 |

The source ledger role signals cover UI (7,997), terrain (5,037), character (4,879), resource (2,238), nature (1,768), building (1,605), audio (1,182), props (773), effects (768), and towers (359). The source vault is therefore broad enough to inform the redesign, but its contents never become runtime dependencies merely because they are available.

## 2. Non-negotiable production contract

1. Runtime remains 2D: no raw GLTF, Blend, PBR graph, Node3D, or source-vault reference enters the export closure.
2. Existing host authority, ordered snapshots, collision, flow field, placement grid, 480 x 270 logical layout, and 44 px touch contracts are preserved.
3. A new visual must pass provenance, import, deterministic scene binding, gameplay-scale capture, grayscale/semantic review, and focused regression tests before it is considered for runtime promotion.
4. A green headless or desktop-GPU test is not Android, touch, thermal, audio, lifecycle, or two-device LAN certification.
5. A visual veto overrides a numeric pass.

## 3. Parallel review and debate outcome

Independent UI/hero, combat/enemy, world/ecology, and composition reviews converged on one ordering:

1. establish a real 480 x 270 day/night combat composition before judging isolated contact sheets;
2. remove persistent diagnostic overlays that compete with bodies;
3. make the Base Core health state readable without hue;
4. improve menu safe-area resilience without destabilising launch/network flow;
5. prove any new wilderness vocabulary in every declared pocket before adding world density;
6. only then expand hero, tower, trap, boss, and biome art families.

This ordering intentionally rejects mass asset replacement before gameplay-scale evidence exists.

## 4. Completed audit -> analyze -> plan -> act -> review loops

### Loop A — combat composition, enemy hierarchy, and Base Core

Audit: the first shared day/night composition showed tiny survivors and a boss marker/ring that visually dominated the boss body. Existing core health state was only a bar-level read.

Act:

- Added tests/combat_composite_render_validation.tscn and .gd. It uses the actual WorldMap, NetworkPlayer presentation path, BaseCore, tower, trap, walker, Goliath, HUD, MobileControls, and real NightAtmosphere flashlight/security-light hooks without starting authority/timer systems.
- Changed src/visual/enemy_presentation_2d.gd so ordinary idle/moving enemies have no persistent marker; a resting boss keeps only a 55 percent legacy-alpha cue; action/slow/root cues remain fully readable.
- Changed src/visual/core_pulse_driver.gd to derive healthy, damaged, critical, and destroyed visual tiers from the existing HealthBar stops. It changes only existing material/light uniforms and bar visibility at literal zero health.
- Added tests/core_health_tier_render_validation.tscn and .gd, producing real WorldMap/BaseCore gameplay-scale colour and grayscale captures for all four tiers.

Review:

- Enemy presentation contract: 52 checks passed.
- Health readability contract: 76 checks passed.
- Mobile systems regression: 58 checks passed.
- Composite and core tier captures ran on Mobile/Vulkan at native 960 x 540 downsampled to 480 x 270.
- Grayscale review initially vetoed a dark-red-only critical read. The critical tier was revised to use the existing aura and silhouette glow as a brighter, wider shader-only warning; no collision, node, transform, or network mutation was introduced. The revised grayscale capture shows the critical perimeter separately from healthy and destroyed.

Remaining: hero body scale/identity is still below the intended premium reading threshold in the shared composition. This is not marked complete merely because the marker issue is fixed.

### Loop B — start menu safe area and selection hierarchy

Audit: the initial menu had valid targets and selection state but relied on fixed positions, making a real landscape cutout/camera inset fragile.

Act:

- Changed src/ui/start_menu.gd to resolve a device or test-only safe rectangle and relayout header, survivor cards, session controls, footer, beams, and signal field from it.
- Added tests/start_menu_layout_validation.gd with normal and 16,8,448,254 landscape-inset geometry.
- Expanded tests/start_menu_render_validation.gd from two to three Mobile/Vulkan captures, including the safe-inset state.

Review:

- Start-menu layout: 177 checks passed.
- Mobile systems regression: 58 checks passed.
- The Heikki, Shane, and safe-inset captures retain 44 px targets, keyboard focus, address/selection state, hierarchy, and no clipping.

Remaining: this is layout/readability work, not a final portrait-art or animated-diorama replacement.

### Loop C — wilderness ecosystem source trial

Audit: current world density is already high; adding more grass/props without composition would increase visual noise. The earlier Grass Medium 01 macro trial was technically valid but visually vetoed at gameplay scale.

Act:

- Added tests/existing_wild_atlas_context_validation.tscn and .gd. It samples only the currently shipped Poly Haven wild atlas as a transient, artifact-only sibling; no source texture or asset is promoted.
- Added read-only visual-envelope accessors in src/world/world_background_decor_2d.gd for rubble, crack, moss, and prop render extents. These do not mutate the seeded layout.
- The gate evaluates all 10 declared wilderness pockets, full transformed-card radius plus 32 px margin, complete card road clearance >= 480, explicit AmbientScenery/WildernessAccent/BackgroundDecor envelopes, real flashlight/security-light day/night capture, and grayscale proof. GroundCover is correctly retained as substrate, not falsely treated as an exclusion field.

Review:

- Contract passed all 10 pockets with card radius 156.213.
- World map regression: 169 checks passed.
- Mobile/Vulkan produced 40 A/B day/night captures, 10 night grayscale images, and a ten-pocket day grayscale sheet.
- Visual verdict: **REJECTED / no runtime promotion**. Root/branch cards overpower the approximately 23 px survivor and read as high-contrast orange carcass/rock forms. The optional shrub is effectively imperceptible at gameplay scale.

Next action: rebake/recompose a smaller, cooler, lower-contrast root/branch family with meaningful silhouette separation; do not fix this by simply lowering density or relaxing safety gates.

### Loop D — survivor silhouette and defense state language

Audit: the shared combat image showed both heroes merging into terrain at the
shipped zoom, while structure contact sheets did not prove that an armed,
tracking, rearming, disabled, or destroyed defense could be understood in a
real field frame.

Act:

- Changed src/game/player_avatar.gd to add two exact-frame, behind-body
  AnimatedSprite2D followers: a neutral charcoal keyline and a subdued
  class-specific rim. Heikki carries a broader contour and Shane a taller
  contour without relying on hue. The followers reuse the exact body
  SpriteFrames, pivot, heading, clip, and frame; they are hidden by the
  existing downed treatment.
- Added tests/player_avatar_readability_validation.gd. It covers both heroes,
  eight directions, fire, hit, death, respawn, draw order, screen-space
  contour width, remote camera, collision, and absence of new authority,
  lights, or HUD.
- Changed src/tactical/placed_structure_2d.gd to derive world-space
  READY/TRACKING/REARMING/DISABLED/DESTROYED presentation from existing health,
  EMP, cooldown, aim, and target snapshot fields. The three traps use distinct
  low-profile signatures; towers use a stateful aim language. No catalog,
  collision, pathing, placement, RPC, or snapshot-schema change was made.
- Added tests/structure_readability_validation.gd and
  tests/structure_readiness_render_validation.tscn. The shared combat fixture
  now shows a ready day state and tracking/rearming night state from
  non-authoritative presentation snapshots only.

Review:

- Player-avatar readability: 29 checks passed. The 0.38 camera contour
  measures 2.71 x 1.76 px for Heikki and 1.60 x 2.87 px for Shane.
- Structure readability: 40 checks passed; tower combat: 70 checks passed;
  smoke: 207 checks passed.
- The shared day/night/grayscale combat composition was re-rendered on
  Mobile/Vulkan. Heroes now separate from terrain without a persistent HUD
  marker. The tower/trap signatures remain subtle in the mixed frame and
  therefore need a dense real-combat/device review before any stronger effect
  is considered.

Remaining: the contour treatment improves legibility rather than replacing the
survivor sprite family, and desktop captures do not certify Android runtime
cost or real-player recognition speed.

### Loop E — build-deck decision hierarchy, boss body-first probe, and VFX ownership

Audit: three separate gameplay-scale reviews found three different problems:

- the compact build sheet preserved touch targets but made the actual spend
  decision too weak against its supporting mechanics text;
- boss active rings had been reduced, but there was still no body-first proof
  for the smaller boss silhouettes;
- the first isolated and composed VFX captures exposed a bright soft
  `DEATH_BURST` cloud that could read as a pickup/toxic field and replace a
  Walker's 8--12 px body in grayscale.

Act:

- Changed `scenes/ui/tactical_build_deck.tscn` and
  `src/ui/tactical_build_deck.gd`. Card cost, selected role, stats, and cost
  are now a 7 px outlined decision tier; the two-line mechanics explanation
  remains a 6 px outlined supporting tier. The 74 px cards, 46 px thumbnails,
  44 px targets, 148 x 58 dashboard, mobile ownership, and host build path
  were not changed. `get_current_sheet_rect()` exposes the stable layout rect
  for tests rather than the transient popup tween.
- Changed `src/visual/enemy_presentation_2d.gd` to give only boss definitions
  one stopped, frame-synchronised, body-shaped duplicate underlay. It reuses
  the existing baked `SpriteFrames`, frame, animation, offset, and facing;
  it adds no texture, marker, light, particles, collision, RPC, or snapshot
  schema. Added `tests/enemy_body_readability_render_validation.tscn` and
  `.gd` with control, idle, active, and grayscale comparison captures.
- Added `tests/vfx_gameplay_scale_render_validation.tscn` and `.gd`, then
  extended the shared combat composite with label-free real `VfxDirector`
  peak and 0.26-second-late samples in both day and night. The fixture directly
  invokes VFX on visible non-authoritative survivor/enemy owners; it does not
  claim an authoritative combat event.
- Tightened `src/feedback/vfx_director.gd`: muzzle is a compact hard-chip
  source flash; `DEATH_BURST` is now twelve small hard material fragments with
  a warm low-value derived debris tint instead of a bright soft accent cloud.
  `tests/vfx_validation.gd` binds every effect to a reviewed 0.38-camera
  particle-size ceiling.

Review and debate:

- Tactical HUD: 53 checks passed; mobile systems: 58 checks passed. The
  Mobile/Vulkan tower, trap, and utility captures show no clipping. The
  remaining caveat is deliberately small mechanics prose and `FOCUS_NONE`
  keyboard accessibility, not touch/authority regression.
- Enemy presentation: 55 checks passed; enemy impact: 42; damage feedback:
  35. Mobile/Vulkan body captures passed at native 960 x 540 downsampled to
  480 x 270.
- Independent body-rim review: **HOLD**. The subdued idle marker policy holds,
  and Goliath improves, but Carrier, Splitter, and Overlord do not yet prove a
  body-first grayscale read. Increasing scale/alpha blindly would risk
  reintroducing permanent marker hierarchy, so no escalation was promoted.
- A second label-free, character-relative A/B fixture then isolated one remote
  Heikki plus one boss at a time in day/night colour and grayscale. It confirms
  Goliath **passes**, Overlord is **conditional**, and Carrier/Splitter
  **fail**: their rim changes only 0.27--0.46 percent of the body ROI versus
  1.66--2.24 percent for Goliath/Overlord. This is evidence for an offline
  Carrier/Splitter body rebake/repaint, not permission to amplify the uniform
  rim.
- VFX director: 154 checks passed. The first composed review was **HOLD**:
  `DEATH_BURST` dominated a Walker. After the second material-fragment pass,
  independent review **accepted the DEATH_BURST hierarchy candidate only**:
  body/horns remain primary by day, the Walker remains visible at night, and
  late samples leave no static bright anchor. Muzzle and impact retain a
  separate integration gate because this direct-VFX fixture does not pair them
  with the normal projectile/hit-body event path.
- The missing muzzle/impact gate is now covered by
  `projectile_vfx_ownership_render_validation`: real PlayerAvatar shoot,
  prewarmed PlayerProjectile collision, ProjectilePool outward spray,
  VfxDirector, and a non-authoritative EnemyAgent2D HIT/white-flash run at
  0.38 in label-free day/night peak/late colour and grayscale captures. Review
  accepted the controlled semantic-owner fixture after the visual-only
  `IMPACT_SPARK` fan narrowed from 68 to 42 degrees; its former vertical,
  loot-like trail now resolves as an outward impact next to the lit target
  body. This does not certify Android/LAN/performance or replace human device
  review.
- Full focused smoke after all Loop E source changes: 207 checks passed.

Remaining: this is an accepted narrow death-feedback repair, not full VFX
art-direction approval. Boss body art and muzzle/impact semantic integration
remain explicit visual vetoes.

## 5. Area-by-area status and next redesign action

| Area | Current decision | Next high-value action |
|---|---|---|
| Start menu | Safe-area layout and selection hierarchy accepted; portrait art retained | Add restrained approved hero micro-motion only after in-world hero silhouette passes |
| HUD and build deck | Decision tier now has outlined 7 px role/stats/cost without changing compact targets or authority | Review dense text/focus hierarchy in a live world capture; retain the small supporting mechanics tier |
| Heikki and Shane | Direction/action/authority contracts are intact; presentation-only keyline/rim now passes day/night/grayscale composition | Judge absolute body mass and future authored sprite replacement only from device and real-combat review |
| Zombies | Persistent normal idle markers removed; active status/action tell remains | Improve body-first silhouette/material differentiation per variant, not another marker taxonomy |
| Bosses | Goliath passes and Overlord conditionally passes character-relative rim review; Carrier/Splitter **HOLD** for body-first proof; resting cue remains subdued | Offline rebake/repaint Carrier and Splitter body mass before any rim amplification or new chrome |
| Towers and utilities | Existing roles/collision/catalog remain authoritative; stateful aim language passes focused proof | Test idle/tracking/rearming/disabled states in dense combat and Android before increasing intensity |
| Traps | Existing gameplay/placement remains untouched; three compact armed/rearming signatures pass focused proof | Test trigger/spent readability in a crowded, moving encounter and preserve low visual noise |
| Base Core | Four real presentation tiers accepted at the capture gate | Later couple damage/destruction with accepted gameplay VFX/audio; preserve amber as dominant refuge signal |
| Terrain, nature and props | Existing density is sufficient; candidate macro card rejected | Expand only a small re-baked coherent family after a 10-pocket visual pass |
| City, mall and village salvage | Existing atlas vocabulary remains baseline | Prefer curated offline CC0 bake slices: barrel/toolbox/utility/remainder clusters, never bulk Addons copying |
| Effects, weather, audio and accessibility | `DEATH_BURST` and controlled projectile muzzle/impact owner hierarchy accepted; artifact scope remains limited | Validate reduced motion, device sound, Android frame time, and real combat density later |

## 6. Blender and Poly Haven disposition

Blender MCP and Poly Haven are active as an offline art department. Current source reconnaissance confirms 37 rock, 57 plant, and 32 ground-cover model candidates; examples such as Boulder 01 and Fern 02 were inspected as sources only. Their mesh density and raw GLTF form make direct shipping inappropriate for this project.

The approved route is:

1. select a licensed CC0 source with a documented semantic gap;
2. render it in an isolated Blender bake rig with shared top-down camera, palette, alpha margin, contact shadow, and pivot contract;
3. record source id/licence/hash, bake script hash, output hash, bounds, luma, and intended runtime reachability;
4. review it at 480 x 270 day/night/grayscale beside live players and threats;
5. promote only after human visual approval and mobile budget proof.

## 7. Required next loops

1. Re-run the shared composition after each accepted player-facing change; inspect colour and grayscale, not just numeric output.
2. Design the smaller cool wilderness rebake from the failed card evidence; repeat all 10 pockets rather than cherry-picking one attractive clearing.
3. Build a per-variant zombie/boss body-language matrix and character-relative gameplay capture before any boss-rim escalation or broad asset re-bake.
4. Capture tower/trap trigger, spent, and recovery language in a dense live combat fixture; increase neither light nor VFX count until that review needs it.
5. Collect physical Android, touch, thermal, audio, safe-area, lifecycle, real combat density, and two-device LAN evidence after the artifact gates.

## 8. Current release decision

This work materially improves presentation hierarchy and validates the review pipeline, but it does **not** certify AAA++ release quality. The authoritative remaining gates are gameplay-scale hero/structure/body reads, a successful nature replacement slice, Android/device validation, and human art-direction approval.

## 9. Evidence locations

- artifacts/asset_audit/deep_asset_audit_summary.json
- artifacts/combat_composite_validation/
- artifacts/core_health_tier_validation/
- artifacts/start_menu_render_validation.json and start_menu_*_validation.png
- artifacts/existing_wild_atlas_context_validation/
- tests/combat_composite_render_validation.gd
- tests/core_health_tier_render_validation.gd
- tests/start_menu_layout_validation.gd
- tests/existing_wild_atlas_context_validation.gd
- tests/player_avatar_readability_validation.gd
- tests/structure_readability_validation.gd
- artifacts/enemy_body_readability_validation/
- artifacts/vfx_gameplay_scale_validation/
- artifacts/projectile_vfx_ownership_validation/
- artifacts/enemy_body_combat_readability_validation/
- tests/enemy_body_readability_render_validation.gd
- tests/enemy_body_combat_readability_render_validation.gd
- tests/vfx_gameplay_scale_render_validation.gd
- tests/projectile_vfx_ownership_render_validation.gd
