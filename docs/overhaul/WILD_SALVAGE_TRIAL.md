# Wild / Salvage Blender CLI Trial

Status: technical vertical slice passed on 2026-09-03. This is **not** a
runtime promotion, an atlas build, or approval to deploy either source family.

## What the trial proves

`tools/art/run_wild_bake.py --trial` launches one `--factory-startup
--background` Blender 5.0 process per selected source and writes only below
`artifacts/wild_salvage_trial/`. The directory carries `.gdignore`; no frame
is scanned as a Godot runtime resource and no world scene references it.

The runner has no implicit production mode. Invoking it without either mode
flag fails before any output path is selected. A full source-family bake can
write below `assets/` only with an explicit `--production` opt-in, and remains
subject to the approval and review gate below.

The runner and renderer now share `tools/art/wild_bake_contract.py`. The old
runner derived `PROJECT` as `tools/`, while the renderer used the actual
project root, so the runner could not collect the renderer's per-source
reports. The shared contract fixes that disagreement, limits trial output to
the artifact root, and rejects path-like source identifiers. The runner also
sets an isolation flag. The renderer refuses a live Blender scene and removes
only the factory-startup Cube/Camera/Light before constructing its temporary
stage, keeping an artist's unsaved UI scene untouched.

Preflight checks the project/output/report paths plus every selected source
file's manifest SHA-256 and CC0 declaration. Postflight checks the renderer's
frame SHA-256, visible pixels, protected transparent margin, alpha-weighted
luma, source id, and metric height.

## Executed evidence

```powershell
$env:PYTHONDONTWRITEBYTECODE='1'
python tools\art\validate_wild_bake_contract.py
python tools\art\run_wild_bake.py --trial
python tools\art\validate_wild_bake_contract.py --trial-report artifacts\wild_salvage_trial\polyhaven_wild_render_report.json
```

The aggregate artifact is
`artifacts/wild_salvage_trial/polyhaven_wild_render_report.json`.

| Family | Source | Frames | Quality evidence |
|---|---|---:|---|
| `polyhaven_wild` | `moss_01` (Rob Tuytel, CC0-1.0) | 1 | 407 visible pixels; 101 px margin; luma 36.952; height 0.0404 m; SHA-256 `546b5f9f2f38545216e8319cf6bbaf226c0be2e654db5556811e936ad98986d5` |
| `polyhaven_salvage` | `metal_toolbox` (Mateusz Sadek, CC0-1.0) | 2 | yaw 0: 12,527 pixels; 56 px margin; luma 132.624; SHA-256 `e592368db27a05224b961b6a50fe4dd6049962d65712ace6dc3bbddd8e017d5c` |
| `polyhaven_salvage` | `metal_toolbox` (Mateusz Sadek, CC0-1.0) | 2 | yaw 39: 11,846 pixels; 58 px margin; luma 120.564; SHA-256 `db49ddd5302e9058aebdaf30726380a6511cf5ea091d1f686b8e907dfdf088ee` |

The first isolated run exposed two real safeguards rather than a source-file
failure: factory-startup geometry filled the initial frame, then the true moss
render missed the 34.0 luma floor at 27.31. The renderer now clears only the
factory scene under the explicit isolation flag and performs bounded per-frame
exposure correction. The accepted moss frame reaches luma 36.952 while
retaining a 101 px transparent margin. The existing full atlas packer remains
the later independent margin/luma gate.

## Visual acceptance boundary

The technical pass must not be mistaken for an art-promotion pass. In direct
review `moss_0.png` is a nearly invisible sliver at 256 px: its 407 visible
source pixels and 0.0404 m metric height are correct for ground cover, but not
for a gameplay-readable prop, interactable, collision obstacle, landmark, or
standalone world decoration. It must not be registered in `WorldObstacle2D`
or promoted as an individual map prop.

Moss may advance only under a separate **ground-cover cluster** acceptance
rule: an authored cluster recipe must state its scale range, per-biome density,
spacing, and visual-only status; a true camera-scale 480x270 day and night
capture must show the cluster adding terrain breakup without obscuring players,
build footprints, or combat reads. A gameplay-visible prop instead needs its
own true-scale 480x270 capture proving a distinct silhouette and semantic role
against the target terrain in both value conditions. The SHA/margin/luma
validator is intentionally insufficient evidence for either judgement.

## Macro ground-cover review: fern_02 and grass_medium_01

Two macro probes were carried past the metric validator and into a real
480x270 Mobile/Vulkan gameplay context, because a bake that satisfies alpha,
margin, and luma gates can still be invisible once the gameplay camera puts it
on screen at zoom 0.38.

`tests/grass_macro_context_render_validation.{gd,tscn}` is the current gate.
It pins the three `grass_medium_01_macro_v2` frame hashes, requires
`runtime_promotion: forbidden_pending_grass_context_review`, re-asserts that
neither `runtime_export_closure.json` nor `runtime_export_dependencies.tscn`
mentions the trial, then composites the frames as a transient `z=-5` child of
the live `WorldMap2D` across eight render-clear wilderness pockets, in day and
Sapphire-night, under three named recipes, against a per-patch baseline.

### Two measurement corrections made during the review

The first numbers this review produced were wrong in a way worth recording,
because both errors flatter or damn a source for reasons that have nothing to
do with the source.

**Averaging over changed pixels only.** Thresholding on change admits pixels
where the accent departs from the ground and silently drops the ones that
match it, so the mean luma delta is biased toward whichever direction the
accent differs in. Measured that way the fern read -16.0 luma in day. Measured
over its full footprint in both captures - matched pixels included - the same
saved captures read **-3.4**. Coverage is still counted on the thresholded
set, where the question really is "did this pixel move"; contrast is now
measured over a fixed region.

**Skipping the importer's alpha border fix.** The gate loads probe PNGs with
`Image.load` into an `ImageTexture`, bypassing the import step where all 4012
of the project's runtime texture imports set `process/fix_alpha_border=true`.
`Image.fix_alpha_edges()` is now applied before mipmap generation so the review
measures the pixels the runtime would ship. This was worth ruling out but was
not the cause: it moved the result by under 0.5 luma, and an A/B with mipmaps
disabled entirely moved it no further.

### Measured result

Averaged over eight pockets, footprint-relative, day and Sapphire night:

| Family | Footprint | Coverage | Day delta | Day peak | Night delta | Night peak |
|---|---:|---:|---:|---:|---:|---:|
| fern_02 (patch 00) | 78 x 29 px | 0.369% | -3.4 | -3.6 | -1.3 | +8.5 |
| grass subordinate | ~15 x 8 px | 0.039% | -4.6 | -1.1 | -2.9 | +1.7 |
| grass natural | ~15 x 8 px | 0.042% | -4.8 | -1.6 | -2.0 | +1.8 |
| grass lifted | ~15 x 8 px | 0.045% | -4.6 | -0.1 | -1.1 | +1.7 |

The three grass recipes span a fully suppressed tint (the fern gate's
`Color(0.66, 0.74, 0.48, 0.66)`), an unsuppressed one at 0.9 alpha, and an
opaque one brightened 18%. They differ by 0.2 luma in the mean and 1.5 at the
peak. Composition is not the variable that decides this.

### Verdict

Both families fail the ground-cover cluster rule above, for two separate
reasons that the corrected measurement finally separates:

- **No tonal separation.** The grass tuft's *brightest* pixel sits within
  1.6 luma of the terrain beneath it in daylight. The bake and the Poly Haven
  terrain atlas occupy the same value band, and `sleek_canvas_grade` is applied
  to both, so its contrast and shadow terms compress them together rather than
  apart. Brightening the accent cannot open a gap the grade then closes.
- **Scale, for grass specifically.** At zoom 0.38 a 120-unit card is 45.6
  logical pixels and the tuft inside it is ~21 x 12, of which ~15 x 8 register
  as changed. That is an order of magnitude below the fern's 78 x 29. It is
  also exactly what the probe's own reviewed `projected_width_px: 14..30` band
  asks for, at the tightest framing that still holds the 24 px margin - so the
  band itself, not the bake, describes something too small to read as ground
  cover.

Neither is a defect in the CC0 source and neither is fixed by re-baking
brighter. The grass macro is authored as a single tuft; ground cover at this
camera needs a footprint on the fern's order, which means composing clusters
and widening the reviewed projected-size band to match, then re-running this
gate. The tonal question has to be answered against the terrain atlas and the
grade together, not against the accent alone.

### What this gate does not decide

It measures readability; it does not approve one. No coverage floor or contrast
threshold is encoded, because choosing them is an art-direction call that
belongs in this document before any promotion. `grass_macro_context_validation.json`
carries every per-patch measurement so a threshold can be set against real
numbers rather than guessed. Night is still a Sapphire `CanvasModulate` proxy;
flashlight and security-light behaviour are not exercised.

## Required decision before full rollout

Do not run `tools/art/run_wild_bake.py --production` for all 32 sources or
build either runtime atlas until this trial is approved. The next vertical
slice is: full offline bake -> existing atlas
packer/provenance manifests -> Android memory/profile gate -> only then
replace the legacy tree presentation in `WorldObstacle2D` and add
visual-only salvage clusters in background/ambient chunks. Collision, flow
field, seeds, and host-authoritative gameplay remain canonical; no GLTF,
Blender scene, or `Node3D` may enter the runtime world.
