# Enemy roster art plan

Scope: the eight `EnemyAgent2D.Variant` slots, their sprite sheets, and the
Godot wiring that replaces the current presentation catalog. Written against
the code as it exists, not against intent.

## 1. What is actually wrong today

`src/ai/enemy_presentation_catalog.gd:7-29` preloads eight scenes from four
unrelated commercial packs:

| Variant | Current scene | Origin problem |
|---|---|---|
| WALKER | `big_zombie_68b060d92d` | pixel-art zombie |
| RAT_SWARM | `tiny_zombie_1940012f50` | different pixel-art pack |
| STATIC_WALKER | `ice_zombie_anim_f3_4aa0bd4a05` | *ice* zombie — wrong element entirely |
| SCRAP_SHIELD | `undead_claw_knight_a53e1f4c2e` | fantasy knight |
| GOLIATH | `boss_runic_stone_golem_goliath_*` | **runic stone golem** — high fantasy |
| CARRIER | `boss_mecha_rattlesnake_*` | **mecha snake** — sci-fi, not even bipedal |
| SPLITTER | `boss_blood_feral_*` | fantasy beast |
| OVERLORD | `megpack_iii_fallen_kings_undead_king_berthelot_*` | **a crowned fantasy king** |

Four separate art styles, three separate genres, and a named fantasy monarch
in a post-apocalyptic survival game. No amount of shader tinting fixes a
roster whose members were drawn by different people for different games. The
`EnemyPresentation2D` tint/scale/marker layer (CLAUDE.md §7) is doing real
work holding this together, and it is doing it on top of a broken foundation.

This is also a licence exposure: several of these packs are commercial and at
least one family (`PostApocalypse_AssetPack_v1.1.2`, TheLazyStone) is free
only for non-commercial use, with commercial use requiring a paid purchase.
Replacing them with CC0-derived bakes removes that exposure as a side effect.

## 2. The readability contract the simulation demands

The stats are the design. From `src/ai/horde_director.gd:511-544`:

| Variant | HP | Damage | Speed | Unlock | Player response |
|---|---:|---:|---:|---|---|
| WALKER | 90 | 12 | 112 | always | baseline — ignore or clear |
| RAT_SWARM | 34 | 7 | **220** | night 6 | **kite**, do not stand still |
| STATIC_WALKER | 105 | 13 | 104 | night 8 | **kill at range** — EMP on death |
| SCRAP_SHIELD | 165 | 16 | **82** | night 12 | focus fire, safe to back away from |
| GOLIATH | 1700 | 34 | 62 | night 5 boss | sustained damage |
| CARRIER | 2100 | 29 | 68 | night 10 boss | sustained damage |
| SPLITTER | 2500 | 36 | 76 | night 15 boss | expect adds on death |
| OVERLORD | 3400 | 48 | 70 | night 20 boss | everything |

Speed spans 220 → 62, a **3.5× range**. Health spans 34 → 3400, a **100×
range**. The correct response to the fastest enemy (kite) is the opposite of
the correct response to the slowest (stand and focus). A player who misreads
one for the other dies.

So the art has exactly one non-negotiable job: **at 480×270, at a glance,
before colour resolves, a player must be able to tell fast-fragile from
slow-tanky.** Everything else in this document is secondary to that.

Two variants carry information beyond the stat block and it must be
telegraphed *before* it fires, not after:

- **STATIC_WALKER** releases an EMP on death — radius 260, duration 2.4 s
  (`enemy_agent_2d.gd:28-29`). Radius 260 at a 480-wide viewport is over half
  the screen. A player must know this one is different while it is still
  alive and at range.
- **SPLITTER** emits `split_requested` on death (`enemy_agent_2d.gd:7`). Its
  silhouette must read as *already segmented*, so the split is a payoff
  rather than a surprise.

## 3. What the bake delivers

`tools/art/run_actor_bake.py` bakes all eight from bodies authored directly
onto the CC0 KayKit skeleton (`tools/art/build_actor_body.py`), so all 119
KayKit clips drive every one of them by construction. Measured this run:

- actor tier: cell 64 px, **density 15.00 px/unit**, measured span 4.025
- boss tier: cell 128 px, **density 15.00 px/unit**, measured span 7.719
- **0 missing clips across all ten actors** (eight enemies + two survivors)

Identical density across both tiers is the point: the goliath is drawn twice
the height of a walker because it *is* twice the height, not because it was
given a bigger frame. Boss span 7.719 / actor span 4.025 = 1.92× against a 2×
cell.

Per-variant vertex counts confirm eight genuinely distinct bodies rather than
one body recoloured: walker 336, rat_swarm 588 (across 3 bones), static_walker
310, scrap_shield 274, goliath 422, carrier 362, splitter 306, overlord 338.

Clip sets — `run_actor_bake.py:85-93`:
- all eight: idle(4) walk(6) attack(4) hit(4) death(6) spawn(6)
- four bosses additionally: taunt(6)

Each frame count is per direction, and there are **8 compass directions**, so
a walker sheet is 8 rows × 30 columns and a boss sheet is 8 × 36.

### Two clips that cannot be used, and why

`Skeletons_Death` and `Skeletons_Awaken_Floor` are the names a reader reaches
for first, and both are traps. They animate a skeleton *coming apart* —
translating individual bones metres from the body. KayKit authored them for a
pile of bones; on a body whose shells are rigidly bound one-per-bone they
render as a person bursting into disconnected boxes. They cost the sheet
twice: the render is broken, and the measuring pass unioned the debris field
into the shared camera and shrank every other sprite to a third of its size.
Replaced with `Death_B` and `Skeletons_Awaken_Standing`, both verified
coherent by rendering. `Death_B` has the side benefit that the horde does not
die in the survivors' exact pose.

`Crawling` is a coherent flat crawl clip and is the right basis for a future
crawler variant. Not used yet; noted so it is not rediscovered.

## 4. Per-variant art direction

Palette keys are from `BESPREN_PALETTE` in `tools/art/aaa_bake_rig.py`. Each
row names the one shape feature that must survive greyscale at 64 px — if
that feature is not legible, the design has failed regardless of paint.

### Horde tier (64 px cell)

**WALKER** — the reference the other seven are read against.
Upright, neutral proportions, both arms hanging. Body `NECROTIC_FLESH`,
clothing `CLOTH_OLIVE`, exposed bone `BONE`. No emissive.
*Distinguishing feature:* none, deliberately. It is the baseline; anything
that reads as "not a walker" must differ from this.

**RAT_SWARM** — must read **fast and fragile** at a glance.
Three small bodies on three bones (588 verts across 3), low to the ground,
forward-pitched. Roughly 40% walker height. `NECROTIC_FLESH` over `TAR`.
*Distinguishing feature:* **it is three separate silhouettes, not one.**
Multiplicity is the fastest possible read of "swarm" and it survives at any
size. Reinforce with the highest motion cadence in the roster — the cadence
does the "220 speed" communication that a still frame cannot.

**STATIC_WALKER** — must telegraph the death-EMP *while alive*.
Walker proportions with a visible back-mounted cell. Body `NECROTIC_FLESH`,
apparatus `DARK_IRON`, cell `NEON_CYAN` (emit 2.8).
*Distinguishing feature:* **an asymmetric hard-edged mass on the upper back**
breaking the walker's smooth shoulder line. This is the one place in the
horde where an emissive is justified — cyan reads as *technology*, which is
exactly what the EMP is, and it is the game's established tech signal. It
also correctly does **not** compete with Base Core amber, which per CLAUDE.md
§8 must remain the only dominant amber source.
*Additional requirement, not art:* a pre-death tell. See §6.

**SCRAP_SHIELD** — must read **slow and armoured**, the inverse of RAT_SWARM.
Widest silhouette in the horde tier, hunched, one arm carrying a plate.
Plate `RUSTED_IRON` and `DARK_IRON`, body `NECROTIC_FLESH`.
*Distinguishing feature:* **a flat straight-edged slab breaking the outline
on one side.** Every other body in the roster is organic and irregular; a
single manufactured straight line is unmistakable at 64 px. Slowest cadence
in the roster.

### Boss tier (128 px cell)

Bosses share the taunt clip, which is the on-arrival beat. All four are
roughly 2× horde height at the same pixel density.

**GOLIATH** (1700 hp, slowest at 62) — mass.
Heaviest build, 422 verts. `DARK_IRON` plating over `NECROTIC_FLESH`,
`RUSTED_IRON` at the joints.
*Distinguishing feature:* **shoulder width exceeding hip width by the largest
ratio in the roster.** Pure bulk, no gimmick — it is the first boss and
should teach "boss = big" before the later three complicate it.

**CARRIER** (2100 hp) — carries something.
`CLOTH_LEATHER` harness, `TOXIC_SLUDGE` (emit 0.6) in a carried vessel.
*Distinguishing feature:* **a discrete object held clear of the body
silhouette**, so the outline reads as body-plus-cargo rather than one mass.

**SPLITTER** (2500 hp) — must read as *already divided*.
`CRIMSON_STEEL` seams over `NECROTIC_FLESH`.
*Distinguishing feature:* **a visible vertical seam splitting the torso**,
with the two halves offset slightly so the outline itself is interrupted.
This is the one boss whose art carries a mechanical promise; when it dies and
spawns adds, the player should feel it was foretold rather than sprung.

**OVERLORD** (3400 hp, night 20) — the final silhouette in the game.
Tallest, `MOLTEN_SLAG` (emit 2.4) at the core, `DARK_IRON` and
`BLACK_OBSIDIAN` shell.
*Distinguishing feature:* **the tallest silhouette plus the only interior
emissive that reads through the body.** It arrives at night 20 and must
outrank everything the player has already learned to ignore.

## 5. Godot wiring

Replacing the catalog is the smallest possible change, because
`EnemyPresentation2D` already isolates presentation from simulation.

1. Pack the sheets: `tools/art/pack_actor_sheets.py <report.json> <out_root>`.
2. Promote to `assets/2d/enemies/sheets/` with a provenance manifest matching
   the environment-family schema (source = KayKit CC0, renderer, bake report
   hash). Add `assets/licenses/kaykit_cc0.md` — KayKit is CC0 by Kay
   Lousberg, free for personal, educational and commercial use, credit
   optional. **Verify and quote the pack's own licence file when writing it.**
3. Author one `AnimatedSprite2D`-backed scene per variant reading its sheet as
   8 direction rows × N frame columns. Direction is selected from the
   replicated facing, not from local input — `enemy_agent_2d.gd:47` already
   holds `_facing_direction`.
4. Repoint the eight `preload`s in `enemy_presentation_catalog.gd:7-29`.
   `VARIANT_COUNT`, the enum order, and `get_catalog_errors()` are unchanged.
5. Re-run `tests/enemy_presentation_validation.gd` (currently `ENEMY
   PRESENTATION OK (27)`). It asserts eight distinct scenes/scales/tints, so
   it should pass unchanged — if it does not, the wiring is wrong, not the
   test.
6. Delete nothing under `Addons/`. CLAUDE.md §16 forbids destructive cleanup
   without a licence and dependency manifest plus explicit confirmation. The
   old scenes stop being referenced; that is sufficient.

### Memory

`pack_actor_sheets.py:20` writes **one sheet per clip**, not one per actor, so
no sheet is anywhere near the 2048 px safe edge for mid-range Android. The
largest is a boss taunt/walk/death at 6 columns x 128 px = 768 x 1024. Nothing
needs splitting.

Total RGBA8 uncompressed is the real problem:

| Tier | Cell | Frames/dir | Px per actor | Count | Subtotal |
|---|---:|---:|---:|---:|---:|
| survivors | 64 | 36 | 4.72 MB | 2 | 9.4 MB |
| horde | 64 | 30 | 3.93 MB | 4 | 15.7 MB |
| bosses | 128 | 36 | 18.87 MB | 4 | **75.5 MB** |
| | | | | | **~100 MB** |

**That is far too much for this target and must not ship uncompressed.**
Three levers, in the order they should be pulled:

1. **VRAM compression on import.** Roughly 4:1, taking ~100 MB to ~25 MB. Do
   this first; it costs nothing but an import setting. Verify the alpha
   survives — these are cutout sprites and block-compression artefacts on the
   alpha edge are visible at 1x.
2. **Load boss sheets on demand.** Bosses arrive on nights 5/10/15/20 and
   never more than one at a time, so three of the four are dead weight in
   memory on any given night. The horde and survivors stay resident; a boss
   loads with its wave. That alone removes ~57 MB of the ~75 MB boss cost.
3. **Frame counts, not cell size.** If it still misses on device, cut death
   from 6 to 4 frames before touching the cell. Cell size is what makes the
   goliath read as twice a walker; frame count is what makes its death slightly
   smoother. Only one of those is load-bearing.

## 6. Gaps this plan does not close

- **STATIC_WALKER has no pre-death tell.** The art marks it as different, but
  a player who has not yet learned what the cyan cell means gets EMP'd once
  with no warning. Needs either a wind-up on the death clip or a HUD-level
  radius hint. This is a design decision, not an art one — flagging it, not
  deciding it.
- **No damaged state.** Nothing in the roster shows accumulated damage; a
  3400 hp overlord at 5% health looks identical to one at 100%. The hit clip
  covers the instant, not the state.
- **No crawler variant** despite `Crawling` being available and verified.
- **Device validation is entirely open.** Every number above is desktop
  evidence. Readability at 480×270 on a real mid-range Android panel, under
  sustained thermal load, is unproven and is the gate that matters.

## 7. Order of work

1. Pack and review the sheets at 1× and 4×. **Review before wiring** — a
   framing or cadence defect is far cheaper to catch here than after eight
   scenes exist.
2. Split the boss sheets and set VRAM compression on import.
3. Author the eight scenes; repoint the catalog.
4. Re-run `enemy_presentation_validation.gd` and `smoke_test.gd` (192 checks).
5. Capture a Mobile/Vulkan contact sheet of all eight at 480×270 and check
   the fast/tanky read in greyscale.
6. Only then consider the gaps in §6.

## 8. Status

Steps 1–5 are done; step 6 is untouched by design.

1. **Packed and reviewed.** `sheets/sheet_manifest.json` records 66 sheets with
   cell size, content bounds, per-row variation, and `ground_offset`. Reviewed
   at 1× and at 4× in `artifacts/enemy_presentation_library_4x_detail.png`; no
   framing, cadence, or alpha defect found.
2. **VRAM compression set.** Every sheet imports with `compress/mode=2` and
   `process/fix_alpha_border=true`. Confirmed against the built APK: Android
   ships only the `.etc2.ctex` variant, and the cutout edge survives block
   compression with no halo at 4×.
3. **Eight scenes authored, catalog repointed.** `EnemyPresentationCatalog`
   preloads `assets/2d/actors/scenes/enemy_*.tscn`, applies one uniform
   `ACTOR_SCALE` of `Vector2(2.0, 2.0)`, and carries a zero `visual_offset` for
   every variant, because each baked scene already pins its sprite to the
   projected world origin the bake recorded.
4. **Gates re-run and green.** `ENEMY PRESENTATION OK (29)` and
   `SMOKE OK (192 checks)`, alongside the rest of the suite:
   `AUTO AIM OK (46)`, `TOWER COMBAT OK (70)`, `COOP HARDENING OK (33)`,
   `RESOURCE SCATTER VALIDATION OK (72)`, `MOBILE SYSTEMS OK (55)`,
   `TACTICAL HUD OK (50)`, `WORLD MAP VALIDATION OK (150)`,
   `POLY HAVEN DISTRICT VALIDATION OK (58)`,
   `LOCAL ENVIRONMENT VALIDATION OK (47)`,
   `EXPORT PACK VALIDATION OK (173 resources, 23 scenes instantiated)`, and
   `ANDROID EXPORT VALIDATION OK`.
5. **Contact sheet captured and read in greyscale.**
   `artifacts/enemy_presentation_library.png` at 480×270,
   `method=mobile | driver=vulkan | variants=8`. Greyscale mass separates the
   roster as intended: crawler pack lightest at 42 px wide / 45718 mass, then
   static conduit (44 / 75575) and toxic brute (49 / 87726), then scrap bulwark
   (62 / 117160), then the bosses at 72–84 px wide. Blood splitter is
   deliberately lighter than its tier (64891) because it is the fast boss.

Two things were repaired in passing. The Android export closure is
hand-maintained and still named the eight retired pixel-art scenes with their
twenty-two source textures; it now names the baked family instead — eight actor
scenes, eight `SpriteFrames`, fifty-two sheets, and `actor_facing.gd` — taking
the closure from 134 to 173 resources and the dependency scene from 135 to 174.
`SpriteFrames` was a type the closure had never carried, so the GDScript
verifier, the PowerShell APK gate, and the dependency scene each learned it, and
the APK gate's imported-asset regex learned that a VRAM-compressed texture spells
its format into the compiled name. Separately, `local_environment_validation.gd`
had gone stale on its own: a later `Dense*Ruin_*` filler family reuses
`CITY_BUILDING` and `VILLAGE_HOUSE`, so two counters now scope to authored names
while the filler stays covered by the region, scale, shader, and collision
checks.

Nothing under `Addons/` was deleted. The retired scenes are simply no longer
referenced, which is what §7 asked for.
