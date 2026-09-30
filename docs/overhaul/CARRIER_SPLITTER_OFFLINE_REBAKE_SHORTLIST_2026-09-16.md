# Carrier / Splitter offline-rebake shortlist — 2026-09-16

## Decision

**HOLD the production sources.** This is a provenance and art-direction
shortlist, not an asset promotion. The character-relative 0.38 evidence in
`artifacts/enemy_body_combat_readability_validation/` says that the current
body-silhouette copy is materially visible for Goliath and Overlord but not
semantically useful for Carrier or Splitter:

| Variant | Day changed fraction | Night changed fraction | Decision |
|---|---:|---:|---|
| Carrier | 0.004638 | 0.003390 | Fail: the visible difference is not a two-pod body read. |
| Splitter | 0.004371 | 0.002676 | Fail: the visible difference is not a spaced-lobe body read. |

Increasing the shared rim would make the passing bosses louder before it made
these two bodies intelligible. The next change must therefore be a body-art
rebake, not another ring, label, light, particle, shader, or runtime-rim
adjustment.

## Source shortlist

`references_present` below is the existing
`artifacts/asset_audit/addons_file_ledger.jsonl` signal. It is followed by a
read of the named licence file; it is not a substitute for release/legal
approval. Nothing in this table may be copied to `res://` or shipped raw.

| Semantic target | Candidate source identifier and path | Licence signal and observed terms | Visual suitability at 0.38 | Verdict and allowed use |
|---|---|---|---|---|
| **Carrier: two discrete carried pods**, with a real negative gap/body bridge before the orbit marker is read | **Primary:** original Bespren geometry in `tools/art/build_actor_body.py` (`carrier` entry) on CC0 `Rig_Medium` actions under `Addons/KayKit_Character_Animations_1.1/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/` (the `Special`, `General`, and `CombatMelee` GLBs used by `run_actor_bake.py`) | `references_present`; the pack's `License.txt` says CC0 and explicitly permits personal, educational, and commercial use. `assets/licenses/kaykit_character_animations_cc0.md` records that only the skeleton/actions are used and Bespren owns the rendered geometry. | **Only direct technical fit.** It already supplies the correct rig, all required actions, 8 heading bake, locked camera, and the existing actor source can be altered as original geometry rather than a sampled sprite. | **PRIMARY CANDIDATE.** Replace the carrier's current many small carapace beads with two large, separately readable cargo sacs/canisters, each bound to a stable torso/back bone, bridged by a harness. At the camera-facing row, preserve a transparent gap of at least 6 source pixels (about 2.3 logical pixels at 0.38) and make each outer pod at least 16 source pixels wide. Do not import or reuse a third-party raster. |
| Carrier: broad carapace/value reference only | Admurins Freebies 2 — `Addons/Admurins_Freebies-2/Admurin's Freebies/Bosses_Gollux/Gollux/gollux_idle.png` | `references_present`; `Addons/Admurins_Freebies-2/License.txt` permits personal/commercial game use and modification, prohibits asset resale/redistribution and AI training, and makes credit optional. | The inspected 640 x 128, five-frame strip is a one-sided boulder/plate creature. It can inform dark-mass versus accent grouping, but it has neither two clear cargo pods nor eight headings/required clips. | **REFERENCE ONLY / NO DIRECT BAKE.** If an art director uses it at all, use it as an offline mood-board reference after licence sign-off; do not trace, sample, ingest into a generative model, or promote its pixels. |
| **Splitter: two spaced torso lobes**, separated by a vertical cleft that remains visible before the twin marker is read | **Primary:** original Bespren geometry in `tools/art/build_actor_body.py` (`splitter` entry), same CC0 KayKit action source above | `references_present`; same verified CC0 KayKit licence and existing local provenance record. | **Only direct technical fit.** Existing Splitter geometry is already rigged and has a full body/action bake route, but its extra heads/jaws collapse into one dark mass at 0.38. | **PRIMARY CANDIDATE.** Build two offset chest/shoulder lobes as original geometry, with a continuous centre cleft through the upper torso; bind each lobe to opposite stable chest/clavicle parents so action motion does not close the gap. Target a 6-source-pixel cleft and at least 16-source-pixel lobe width in the camera-facing idle frame. Keep the seam dark, not emissive. |
| Splitter: animal mass reference only | Admurins Freebies 2 — `Addons/Admurins_Freebies-2/Admurin's Freebies/Bosses_Badger/Badger/badger_idle.png` and `.../Bosses_Frogger/Frogger/frogger_idle.png` | `references_present`; same licence file/terms as the Gollux row. | Both inspected 640 x 128, five-frame strips are single side-view creatures. Badger foregrounds a jaw and Frogger foregrounds a belly/limbs; neither supplies a durable bilateral split silhouette or 8-heading action set. | **NO-GO FOR IMPLEMENTATION.** Optional mood-board reference only under the same no-raster/no-generative-ingestion restriction. |
| Either boss: pre-authored multi-view enemy replacement | Post Apocalypse — `Addons/PostApocalypse_AssetPack_v1.1.2/Enemies/Zombie_Big/` | `references_present`; its `LICENSE.txt` permits free non-commercial use but requires at least USD 2 payment for commercial use and prohibits redistribution. | The inspected `Zombie_Big_Down_Idle-Sheet6.png` is a small humanoid strip, not a boss silhouette; its available front/side/back vocabulary is not an eight-heading boss/action contract. | **NO-GO.** Do not spend a commercial licence payment for an asset that still fails semantic, scale, and animation fit. |
| Either boss: top-down directional source | top-down collection pack — `Addons/top-down-collection-pack/top-down-collection-pack/Topview Sci-Fi Patreon Collection/top-down-dungeon-enemy-robot/PNG/robot-walk-{back,front,side}.png` | `references_present`; `public-license.txt` allows personal/commercial use and modification, with credit optional. | The inspected robot is a 16-pixel mechanical walker with only back/front/side source strips. It communicates neither infected cargo nor division and cannot furnish the required seven clips/eight headings. | **NO-GO.** Useful for neither silhouette nor pipeline. |
| Either boss: Poly Haven/Blender source | `tools/art/blender/vault/polyhaven_wild/_fetch_manifest.json` and `.../polyhaven_salvage/_fetch_manifest.json` — reviewed IDs are trees, roots, plants, rocks, barrels, crates, tools, and industrial props | Both manifests record `CC0-1.0`, source IDs, URLs, and hashes. The current offline policy remains valid. | There is no character mesh, armature, or creature animation in either 16-item vault. Recombining static roots/props into a boss would read as environmental debris, compete with traversal language, and create an unproven action rig. | **NO-GO.** Retain Poly Haven for environment variation only; do not force a CC0 prop library into a character source. |
| Any apparently tempting raw monster/battler pack without a verified licence | Examples classified `not_detected` in the Addons ledger: `Aekashics Librarium Static Battlers`, `Aekashics Librarium - Dragonbones Animated Battlers`, `Aekashics Librarium - 3 Frame Frontview $Big_Monster Sprites`, and `Enemy_Animations_Set` | **No licence signal in the ledger.** | Several have genre-relevant creatures, but provenance is insufficient before visual fit is even considered. | **HARD NO-GO.** No inspection beyond the ledger, no extraction, no proxy, no promotion. |

## Exact offline bake contract

The approved primary path is a narrow modification of original body geometry
outside the runtime, followed by the existing actor bake/pack pipeline. It
must preserve all of the following exactly:

| Contract field | Carrier | Splitter |
|---|---|---|
| Actor identity | `enemy_carrier` / geometry key `carrier`; `EnemyAgent2D.Variant.CARRIER == 5` | `enemy_splitter` / geometry key `splitter`; `EnemyAgent2D.Variant.SPLITTER == 6` |
| Required named animations | `attack_[0..7]`, `death_[0..7]`, `hit_[0..7]`, `idle_[0..7]`, `spawn_[0..7]`, `taunt_[0..7]`, `walk_[0..7]` | Same 56 exact `StringName`s |
| Action source and frames per direction | `Melee_Unarmed_Attack_Punch_A` 4, `Death_B` 6, `Hit_A` 4, `Skeletons_Idle` 4, `Skeletons_Awaken_Standing` 6, `Skeletons_Taunt` 6, `Skeletons_Walking` 6 | Same mappings and counts |
| Heading order | 8 `ActorFacing.ROW_HEADINGS` rows, unchanged: left, down-left, down/camera-facing row 2, down-right, right, up-right, up, up-left | Same order; do not mirror/reorder rows or calculate local facing differently |
| Current packed-sheet geometry | attack 416x832 / cell 104 / 4 cols; death 816x1088 / 136 / 6; hit 352x704 / 88 / 4; idle 384x768 / 96 / 4; spawn 672x896 / 112 / 6; taunt 576x768 / 96 / 6; walk 528x704 / 88 / 6 | attack 384x768 / cell 96 / 4 cols; death 816x1088 / 136 / 6; hit 352x704 / 88 / 4; idle 352x704 / 88 / 4; spawn 672x896 / 112 / 6; taunt 528x704 / 88 / 6; walk 528x704 / 88 / 6 |
| Scene root/pivot | `WeatheredSprite`, nearest filtering, `idle_2` autoplay, `offset = Vector2(0, -18.5634)` | `WeatheredSprite`, nearest filtering, `idle_2` autoplay, `offset = Vector2(0, -17.8348)` |
| Presentation scale/origin | `ACTOR_SCALE == Vector2(1, 1)`, `visual_offset == Vector2.ZERO`, `copy_offsets == [Vector2.ZERO]` | Same |
| Simulation and networking boundary | Do not change layer `4`, world/player mask `3`, collision construction, host authority, `enemy_id`, facing-row replication, snapshot layout, presentation-token bit layout, or action/event tokens. | Same; additionally preserve the authoritative death-only `split_requested` signal. |

The planned body meshes must remain inside the existing per-clip source-cell
envelopes. If a candidate needs a larger cell, changed foot offset, different
row order, a second runtime sprite, a new light, or a marker enhancement, it
fails this bounded rebake and returns to design review.

## Minimal art brief for the successful candidate

1. **Carrier:** create two matte toxic cargo pods, one on each side/back of
   the torso, with a visible dark harness/negative-space bridge. The pod pair,
   not green specks or the orbit ring, must establish "carrier" in a
   marker-free grayscale idle frame.
2. **Splitter:** replace the visually merged upper body with two uneven,
   adjacent lobes and a deliberately dark centre cleft. The pair should shift
   slightly in depth across headings, but neither lobe may hide the other in
   row 2 or merge into a single cone in rows 1/3.
3. Use the existing `run_actor_bake.py` → `pack_actor_sheets.py` →
   `build_actor_sprite_frames.gd` route only. Stage outputs outside the runtime
   closure first; record source licence/hash, body-script hash, bake/renderer
   hash, alpha bounds, luma, pivot, and output hash before any promotion.
4. Re-run `enemy_presentation_validation.gd` and the existing
   `enemy_body_combat_readability_render_validation.tscn` at 0.38 with one
   hero, terrain, day/night, colour/grayscale, and a no-label/no-body-marker
   control. Promotion requires the pods/lobes to read before the marker in all
   four views, then a separate Mobile/Vulkan artifact review.

## Explicit no-go and cleanup result

There is **no external Addons or Poly Haven drop-in candidate** for either
boss. The actionable shortlist contains only the existing CC0 KayKit action
source plus new original Bespren body geometry. No Blender MCP scene was opened
for this source-only audit, so no temporary imported objects were created or
require cleanup. No Addons file, raw asset, runtime source, scene, collision,
RPC, snapshot, light, or particle was modified.
