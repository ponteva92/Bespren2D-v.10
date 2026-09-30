"""Bake the Poly Haven wild and salvage families into mobile-ready 2D sprites.

Two things make this renderer different from its three siblings, and both are
deliberate.

It has no workshop `.blend`. The district, nature, and local families each
require one, because their sources arrived through Blender MCP and the saved
scene is the only record of what was imported. These sources arrived through
the documented public API instead, so the source contract is
`vault/<family>/_fetch_manifest.json`: every file with its SHA-256, its
polyhaven.com asset page, and its CC0 declaration. That is a stronger
provenance chain than a binary scene - it is diffable, and it reproduces on a
machine that has never run Blender MCP. Nothing else about the promotion rule
changes: no mesh, PBR graph, authoring light, or Node3D reaches `res://`.

And it bakes several yaw variants per model. A 2D sprite cannot be turned at
runtime, so a single frame per source is a single silhouette forever - which
is exactly the shortage this family exists to fix. Rendering one pine from
three headings costs three frames and yields three trees that do not read as
the same stamp repeated down a treeline. Frames are 256 px rather than the
384 px the building families use, because these subjects are small on a
480x270 screen; that trades a resolution nobody can see for 2.25x the
vocabulary in the same atlas footprint.

The stage itself is imported from the district renderer rather than copied.
Sharing one camera direction, one three-light rig, one Freestyle silhouette,
and one AgX look is what keeps a new family from reading as a different game.
"""

from __future__ import annotations

import hashlib
import json
import os
import sys
from dataclasses import dataclass, field
from math import log2
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import render_polyhaven_district_sprites as district
from wild_bake_contract import (
    FRAME_SIZE,
    MINIMUM_ALPHA_WEIGHTED_LUMA,
    MINIMUM_FRAME_MARGIN,
    PROJECT_ROOT,
    TARGET_LUMA_CEILING,
    TARGET_LUMA_FLOOR,
    resolve_output_root,
)

VAULT = HERE / "blender" / "vault"
# Production bakes target assets/; isolated trial frames may only target the
# dedicated artifact root through BESPREN_WILD_BAKE_OUTPUT_ROOT.
OUTPUT_ROOT = resolve_output_root()
STAGE_PREFIX = "BSP_WILD_STAGE_"
ISOLATED_PROCESS_ENV = "BESPREN_WILD_BAKE_ISOLATED"


@dataclass(frozen=True)
class WildBake:
    """One source model and the headings it is worth seeing from."""

    source_id: str
    key: str
    yaws: tuple[float, ...] = (0.0,)
    framing: float = 1.18
    # Poly Haven models are metrically accurate, so the source height is the
    # honest one. An override exists only for sets whose bounding box is
    # dominated by spread rather than by the subject.
    height_override: float | None = None
    # Freestyle traces every edge in the mesh, so its cost tracks triangle
    # count rather than silhouette complexity. Measured on tree_small_02
    # (2,062,487 triangles, framed): EEVEE renders it in 15.7 s and Freestyle
    # pushes the same frame past 880 s, which is what put the four standing
    # trees over the 540 s bake timeout while the other 32 sources finished.
    #
    # Turning it off for those four is not a concession. A leaf-card tree has
    # tens of thousands of little quad borders, and Freestyle would ink every
    # one of them - a scribble where the art direction wants the one outline
    # that separates the canopy from the ground behind it. That outline is the
    # subject's own alpha border, so [method _apply_silhouette_rim] draws it in
    # 2D instead, which is also how the runtime does it: the four-sample
    # `toon_emissive_outline.gdshader` described in CLAUDE.md 8.
    freestyle: bool = True
    # Several Poly Haven sources are catalogues, not props: the file holds
    # three, four or seven finished subjects standing side by side so a 3D
    # artist can pick one. Baked whole they became a single sprite of a row -
    # `pine_tree_01` framed 21.83 m across to fit three pines into 256 px, so
    # each tree got roughly 50 px and dissolved into needle noise, and the
    # measured 38.7 alpha-weighted luma was the least of it.
    #
    # Naming the subjects splits them into one frame each, which is what the
    # module docstring wanted from the yaw list in the first place: variety
    # that does not read as the same stamp repeated down a treeline. The three
    # pines are three different trees, so they beat three headings of one.
    #
    # This is declared per source rather than inferred. The obvious automatic
    # rule - split objects whose ground footprints do not overlap - reports 3
    # groups for `metal_toolbox`, whose handle latches sit beside the body, and
    # would silently resplit a shipped salvage frame. An empty tuple keeps the
    # whole-import behaviour, so every source not named here is untouched.
    variants: tuple[str, ...] = ()
    # Stage-camera pitch in degrees, or 0 for the shared 42.7-degree stage.
    # Declared per source rather than derived from height, because height is not
    # the question: a 3.87 m street lamp is tall and still wants the default,
    # since a lamp *is* a pole and foreshortening it away leaves a lit disc. A
    # tree is a canopy carried on a bole, and the canopy is the part the player
    # navigates around. See [func _camera_direction] for the full reasoning.
    elevation: float = 0.0
    # Height in metres, above the grounded subject's own lowest point, at
    # which a holdout plane clips the render; 0 leaves the source untouched.
    #
    # This exists for a source that ships its own ground. `fir_tree_01` models
    # a root mound into the trunk primitive - about 0.35 m tall and 0.6 to
    # 0.78 m in radius under a bole of 0.17 to 0.20 m - and under the
    # 70-degree tree camera that flare renders as a lit disc the trunk stands
    # on. The runtime draws the contact it wants as `GroundShadow`, so the
    # baked mound was a second contact under the first, lit where the other
    # is shaded, and no grade downstream can remove a shape. See
    # [const FIR_GROUND_CLIP] for the measurement that chose the height.
    #
    # The mechanism is a holdout, not a cut: a plane at this height with
    # `is_holdout` set writes alpha 0 wherever it is the first surface the
    # camera sees, and a camera looking down sees it before everything under
    # it. EEVEE in Blender 5.0 honours the flag - confirmed by render rather
    # than by the manual. The plane casts no shadow and is never part of the
    # subject, so bounds, framing, exposure and every luma measured in
    # [func generate] are taken from the subject alone, exactly as they are
    # for a source that declares nothing here. It is placed after framing
    # and removed before the next unit; see [func _place_ground_clip].
    #
    # Two things follow that are easy to get backwards. The cut is not
    # capped, so the trunk's visible foot is the front half of the plane's
    # intersection with the bole, an ellipse whose width tapers to nothing
    # over about half its diameter of rows - it is the trunk's own diameter
    # at the clip height and not a mound remnant. And the runtime fits the
    # cropped frame's longer edge to `collision_radius * 4.35`, so a shorter
    # crop delivers a tree of the same height and slightly greater width, not
    # a smaller one.
    #
    # Declared per source rather than inferred, like `elevation`: 0 keeps
    # every source not named byte-untouched within the one-unit contract.
    ground_clip: float = 0.0
    # Composition, for the sources that no camera or exposure can fix.
    #
    # `variants` splits a catalogue into its subjects, which is right when the
    # subjects are props. It is wrong when they are ground cover: one moss
    # patch is 14 mm across, one grass tuft 0.28 m, and framing either of them
    # to fill 256 px produces a botanical specimen photograph, not terrain. The
    # shipped whole-import frames failed the other way - `grass_0` and `grass_1`
    # measured 1.1 and 1.2 percent coverage and were statistically identical to
    # each other, because the source is a 17-tuft catalogue laid out in a line
    # along X and a yaw only rotates a line.
    #
    # A clump entry is (token, x, y, z_rotation_radians, scale). Each names a
    # subject the way `variants` does, and each becomes its own clone, so K
    # entries compose K instances of real geometry into one frame. Clones share
    # `source.data`, which keeps the geometry, UVs and materials immutable - the
    # only edits are the transforms that replace the catalogue's own layout.
    #
    # Declaring a clump replaces `yaws`: a frame is a composition rather than a
    # heading, and the compositions already differ from one another by more than
    # a rotation would.
    #
    # The fern and grass layouts below are the ones the artifact-only macro
    # probes rendered and that survived review against the forest floor, carried
    # over unchanged. See [const FERN_CLUMP].
    clump: tuple[tuple[tuple[str, float, float, float, float], ...], ...] = ()
    note: str = ""


# Wild. Trees carry the most silhouette information and earn the most
# headings; ground cover reads the same from every side and earns one.
#
# Where a source ships several finished subjects side by side, the headings
# give way to one of two modes - see the field comments on [class WildBake].
# Measured footprints started the sort: fir 18.78 m and the mossy rock set
# 8.28 m are catalogue rows whose subjects are each worth a frame, so they
# split through `variants`. `dry_branches_medium_01` (1.06 m) and `pine_roots`
# (1.77 m) are genuine clumps at that framing and stay whole.
#
# Footprint alone turned out to be the wrong test for the rest, and each bake
# said so in its own numbers. `shrub_02` measures 5.98 m and split cleanly into
# four subjects through `variants`, and each subject then covered 4.5 percent of
# its own frame because a scan of a real bush is mostly the gaps between its
# branches. It wanted the third mode: `clump`, which composes named subjects
# into one deliberate arrangement rather than accepting the catalogue's.
# `fern_02` and `grass_medium_01` are here for the same reason, composed from
# the layouts the macro probes validated rather than deferred to those probes'
# own renderers.
# Measured, not chosen. One fir subject was rendered at 42.7, 55 and 70 degrees
# of stage elevation and composited over the forest floor: at 42.7 the trunk was
# 40 percent of the sprite and a single pixel wide at the gameplay camera, at 55
# it was a quarter, and at 70 it was a short stub under a canopy that filled the
# frame - the silhouette this game wants, and still enough bole to say tree
# rather than bush. Luma and lit area rose with it (82.8 -> 92.3 -> 104.5,
# 7405 -> 7818 -> 8946 visible pixels), because tipping a conifer toward the
# camera turns edge-on needles into facing ones.
#
# It is declared only on the three pine/fir sources. `tree_small_02` is a wide
# broadleaf whose canopy already dominates at the shared angle, and
# `dead_tree_trunk_02` is the street-lamp case from [class WildBake]: a bare
# bole is a pole, and foreshortening a pole away leaves a disc.
#
# `elevation` is a camera angle and nothing more, which is worth stating because
# it has been misread once. [_frame_asset] rotates the camera by it and leaves
# the three lights at their fixed world offsets, so raising it changes what is
# framed and never what is lit. An earlier attempt moved a ground-cover source
# from 42.66 to 68 degrees expecting its substrate to light up and got a better
# view down into the same unlit crevices; see the rejection note on `moss_01` in
# [const FAMILIES].
TREE_ELEVATION = 70.0
# Where the holdout plane sits for `fir_tree_01`; see `ground_clip` on
# [class WildBake] for what the plane does and why the source needs one.
#
# Read out of the glTF rather than off a render: the three variants' mounds
# top out at 0.35, 0.30 and 0.35 m above each trunk's own lowest point, and
# the bole narrows from a 0.33 m radius at 0.35 m to its 0.17 to 0.20 m
# proper radius by 0.60 m. 0.40 clears every mound top with 0.05 m to spare
# and keeps the natural flare above it. 0.45 was baked and measured against
# it at 1x and 6x: one pixel narrower at the foot on variant b, unchanged on
# a and c, one pixel shorter on b and c, and indistinguishable on the sheet -
# so 0.40 ships and 0.45 is recorded as the probe that did not pay.
#
# The consequence for delivered size runs the other way from intuition.
# Cropped to alpha the frames lose 4 to 10 rows, the runtime fits the longer
# edge of the crop to `collision_radius * 4.35`, and the delivered tree is
# therefore the same 174 px tall at the gameplay zoom and 1.02 to 1.08x its
# previous width. The mound leaves; the tree does not shrink.
FIR_GROUND_CLIP = 0.40
# The clip plane's name and half-extent. Six metres a side covers every
# framing the family uses at a tree's ortho scale with margin to spare. The
# name wears the wild stage prefix so a dangling plane is legible in a
# scene; what actually sweeps it is the import tag, as for every clone.
GROUND_CLIP_NAME = STAGE_PREFIX + "GROUND_CLIP"
GROUND_CLIP_HALF_SIZE = 3.0
# Smallest largest-world-dimension a composed clump is allowed to keep.
# Derived in [_normalise_clump_span] from the shared framing routine's own
# 0.75 m floor and the stage's 42.66-degree camera elevation.
CLUMP_MINIMUM_SPAN = 1.25

# The fern and grass compositions the artifact-only macro probes rendered,
# carried over unchanged rather than re-authored. Those probes exist to test one
# idea - that ground cover has to be composed rather than framed - and reviewing
# their output against the forest floor settled it: the shipped row frames
# `grass_0` and `grass_1` measured luma 36.7 at 1.1 and 1.2 percent coverage and
# were statistically identical to each other, while the macro frames measured
# 83.0 to 92.3 at 1.7 to 1.9 percent and read as tufts. The ferns were the same
# verdict at larger numbers: 78.8 at 9.3 percent scattered, against 107.7 at
# 15.6 percent clumped.
#
# Copying the numbers rather than the workers is deliberate. The probes each
# hard-code an artifact-only output directory in about eight places and stamp
# their reports `runtime_promotion: forbidden`, which is what they should keep
# saying; the reviewed thing is the layout, and the layout is five floats.
FERN_CLUMP: tuple[tuple[tuple[str, float, float, float, float], ...], ...] = (
    (("fern_02_b", -0.18, 0.12, -0.17, 1.00),
     ("fern_02_c", 0.22, 0.10, 0.20, 0.95),
     ("fern_02_a", -0.12, -0.23, 0.33, 1.10),
     ("fern_02_d", 0.20, -0.22, -0.28, 1.08)),
    (("fern_02_b", -0.22, 0.10, 0.22, 1.05),
     ("fern_02_c", 0.17, 0.16, -0.19, 0.90),
     ("fern_02_a", -0.18, -0.24, -0.12, 1.22),
     ("fern_02_d", 0.23, -0.20, 0.37, 1.00)),
)

# The grass layout is the one place the macro probes' numbers were copied and
# then thrown away. Their three compositions rendered correctly *for a macro
# probe* - four tufts framed to fill a 256 px frame at a screen class that draws
# them large - and at the wild family's own framing they came back as pale wispy
# starbursts, the same dried-thistle read that disqualified the pine sources.
# The cause is density rather than exposure: four tufts averaging 0.20 m across
# do not close a canopy, so the frame is mostly fine blade tips, and fine tips
# at 256 px resolve to near-white fringe no matter what the exposure loop does.
#
# These layouts use seven overlapping tufts inside +/- 0.13 m, where a single
# tuft is 0.15 to 0.32 m wide, so every tuft overlaps its neighbours. They also
# lead with the `tall_*` subjects, which the probe layouts never used at all:
# `tall_a` is 0.32 m tall against `large_a`'s 0.15, and vertical blades are what
# separates grass from lichen when the world draws this at 26 px.
GRASS_CLUMP: tuple[tuple[tuple[str, float, float, float, float], ...], ...] = (
    (("grass_medium_01_tall_a", -0.02, 0.03, 0.31, 1.00),
     ("grass_medium_01_tall_c", 0.09, -0.01, -0.42, 0.94),
     ("grass_medium_01_large_a", -0.11, -0.05, 0.18, 0.92),
     ("grass_medium_01_large_c", 0.10, 0.08, -0.24, 0.88),
     ("grass_medium_01_mid_b", 0.02, -0.09, 0.61, 1.05),
     ("grass_medium_01_mid_c", -0.09, 0.09, -0.55, 0.98),
     ("grass_medium_01_small_a", 0.13, 0.02, 0.12, 1.10)),
    (("grass_medium_01_tall_b", 0.01, -0.02, -0.27, 1.02),
     ("grass_medium_01_tall_a", -0.10, 0.06, 0.49, 0.90),
     ("grass_medium_01_large_b", 0.11, 0.05, -0.16, 0.95),
     ("grass_medium_01_large_a", -0.05, -0.10, 0.36, 0.86),
     ("grass_medium_01_mid_a", 0.07, 0.10, -0.63, 1.00),
     ("grass_medium_01_mid_c", -0.13, -0.03, 0.22, 1.04),
     ("grass_medium_01_small_b", 0.04, 0.00, -0.38, 1.15)),
    (("grass_medium_01_tall_c", -0.04, 0.01, 0.14, 1.06),
     ("grass_medium_01_tall_b", 0.08, 0.07, -0.51, 0.92),
     ("grass_medium_01_large_c", -0.12, 0.04, 0.28, 0.90),
     ("grass_medium_01_large_b", 0.06, -0.09, -0.33, 0.94),
     ("grass_medium_01_mid_b", -0.06, -0.06, 0.57, 1.08),
     ("grass_medium_01_mid_a", 0.12, -0.02, -0.20, 0.98),
     ("grass_medium_01_small_a", 0.00, 0.11, 0.44, 1.12)),
)


# `shrub_02` supplies four separate bush meshes, and the roster originally
# rendered them one per frame through `variants`. That was the wrong mode for
# this source and the bake measured it: a single bush covered 4.5 to 5.0 percent
# of its frame and read as bare twigs, because a photogrammetry scan of a real
# deciduous shrub is mostly the gaps between its branches. It is the fern
# problem rather than a bad source - the subject is 1.28 to 2.18 m wide and 1.17
# to 1.71 m tall, which is a bush by any measure.
#
# Three interpenetrating bushes close those gaps. At +/- 0.35 m the centres sit
# 0.7 m apart against a 1.5 m width, so each pair overlaps by more than half its
# span and the branch masses read as one canopy. Mixing a different trio per
# layout also gives more variety per frame than the four single-subject frames
# it replaces.
#
# This layout previously belonged to `shrub_01`, which has been dropped. That
# source ships one mesh measuring 2.59 m wide by 0.40 m tall by 0.22 m deep - a
# ground creeper, not a bush - and three copies crossed at 66 and 128 degrees
# still rendered as a diagonal line of pale specks at 6.1 to 7.6 percent
# coverage, unreadable at the 40 px the world draws it. It is the same verdict
# the two pine sources got, reached the same way.
SHRUB_CLUMP: tuple[tuple[tuple[str, float, float, float, float], ...], ...] = (
    (("shrub_02_b", 0.00, 0.00, 0.00, 1.00),
     ("shrub_02_a", -0.34, 0.21, 1.15, 0.86),
     ("shrub_02_d", 0.31, -0.24, 2.24, 0.92)),
    (("shrub_02_c", 0.00, 0.00, 0.52, 0.94),
     ("shrub_02_b", 0.29, 0.32, 1.83, 0.88),
     ("shrub_02_a", -0.35, -0.19, 2.71, 0.80)),
    (("shrub_02_a", 0.00, 0.00, 1.05, 0.90),
     ("shrub_02_d", -0.26, -0.30, 2.09, 0.96),
     ("shrub_02_c", 0.33, 0.22, 0.31, 0.84)),
)

WILD: tuple[WildBake, ...] = (
    # `pine_tree_01` and `pine_sapling_medium` were baked, measured and cut.
    # Both objections that could be fixed were fixed - the split gave them one
    # tree per frame, TREE_ELEVATION gave them a canopy instead of a side
    # elevation, and the value band lifted them off the floor from luma 35-38 to
    # 74-79 - and they still do not read. Composited over the forest floor and
    # resampled to the 48 px the world actually draws a tree at, both are pale
    # fibrous starbursts: dried thistle, not conifer.
    #
    # The measurement says why, and it is not a defect the stage can correct.
    # Their natural render lands at luma 35-38, below the forest floor's 53, so
    # they are silhouette-shaped holes before any correction; and the exposure
    # needed to lift them into the band pushes them through AgX's monotonic
    # desaturation to hue 60-65 degrees at saturation 0.33 - a warm tan, and the
    # furthest frames in the family from every green the runtime already uses
    # for trees. Light energy and exposure feed the same view transform, so
    # there is no version of the shared stage that is both bright enough and
    # green enough for these two.
    #
    # `fir_tree_01` reaches the band with less than half that correction and
    # holds hue 70-79 at saturation 0.37-0.47, and `tree_small_02` is the
    # greenest frame in the family at hue 88. Five standing-tree frames from
    # those two beat the four unique regions in the pixel-art atlas they are
    # replacing, so the roster loses nothing by dropping a source that fails.
    # A two-copy clump was baked once and the Blender process hit the 540s
    # per-source timeout before writing frames, so the shipping atlas is the
    # single fir. `forest_density` still shows a stalk with separated tiers.
    # Salvage frames read as objects at bake size and stay unwired until a
    # delivered-size review on the forest ground.
    WildBake("fir_tree_01", "fir", (0.0, 118.0, 224.0), freestyle=False,
             variants=("fir_tree_01_a", "fir_tree_01_b", "fir_tree_01_c"),
             elevation=TREE_ELEVATION, ground_clip=FIR_GROUND_CLIP),
    WildBake("tree_small_02", "broadleaf_small", (0.0, 143.0), freestyle=False),
    WildBake("dead_tree_trunk_02", "dead_trunk", (0.0, 129.0, 242.0)),
    WildBake("tree_stump_02", "stump", (0.0, 151.0)),
    WildBake("pine_roots", "roots_pine", (0.0, 133.0)),
    WildBake("root_cluster_01", "roots_cluster", (0.0, 147.0)),
    WildBake("shrub_02", "shrub", freestyle=False, clump=SHRUB_CLUMP),
    WildBake("fern_02", "fern", (0.0, 128.0), freestyle=False,
             clump=FERN_CLUMP),
    WildBake("grass_medium_01", "grass", (0.0, 144.0), freestyle=False,
             clump=GRASS_CLUMP),
    # `moss_01` is deliberately absent, and it cost four experiments to be sure,
    # so the verdict is recorded rather than left to be rediscovered. Every bake
    # of it came back with about half its opaque pixels below luma 12, against a
    # median of 0.2 percent across this family's 64 shipped frames and 32.6 for
    # its darkest legitimate subject, a black bin bag.
    #
    # Three of those experiments assumed the black was cast shadow. Scattered
    # pieces, nine packed at 8 to 16 mm, and pairs at 26 mm - just past the
    # 0.87h shadow a 26 mm piece lays under a 49-degree key - measured 51.8, then
    # 54.4/52.3/50.7 percent black. Tripling the spacing and removing seven of
    # the nine pieces moved nothing, which rules out members shadowing each
    # other. Raising the world fill 12x, from 0.42 strength to 5.04, moved it to
    # 52.9/51.1/50.4 - so the dark pixels are occluded from the sky as well as
    # from the three lights, and no external source can reach them.
    #
    # Looking at the frames says why: each piece renders as fronds lying on an
    # opaque black slab with hard straight polygonal edges. Moss has no straight
    # edges. The scan carries its substrate, and from the top-down angle a
    # ground decal needs, that substrate is most of the visible mass. It is a
    # property of the source geometry, not of the stage or the layout, which is
    # why composition, camera and light each failed to touch it.
    #
    # Dropped on the same standard as `pine_tree_01`, `pine_sapling_medium` and
    # `shrub_01`. Forest-floor moss, if it is wanted later, wants a source whose
    # subjects are cut free of their substrate.
    # Three of the set's seven, chosen for proportion rather than count: a low
    # flat rock, a tall chunky one, and a broad flat one. The environment atlas
    # already carries six mossy rocks from `rock_moss_set_01`, so the rest of
    # this set would be vocabulary nobody can tell apart at 480x270.
    WildBake("rock_moss_set_02", "rock_mossy", (0.0, 126.0, 248.0),
             variants=("rock_moss_set_02_rock08", "rock_moss_set_02_rock13",
                       "rock_moss_set_02_rock10")),
    WildBake("rock_07", "rock_bare", (0.0, 139.0)),
    WildBake("dry_branches_medium_01", "branches", (0.0, 154.0)),
)

# Salvage. These are man-made and mostly radially dull, so headings go to the
# asymmetric ones - a hand truck and a compressor look different from behind,
# a barrel does not.
SALVAGE: tuple[WildBake, ...] = (
    WildBake("Barrel_01", "barrel_steel", (0.0, 142.0)),
    WildBake("Barrel_02", "barrel_ribbed", (0.0, 131.0)),
    WildBake("barrel_03", "barrel_rusted", (0.0, 155.0)),
    # Two of these barrels are off-palette and the source names hide it, so the
    # measurement is recorded here rather than rediscovered. Hue must be averaged
    # circularly and weighted by saturation and value - a linear mean over a rust
    # subject whose pixels straddle 0 degrees returns ~180 and invents a cyan
    # object that is not there, which happened once during this review.
    #
    # Measured that way, `Barrel_02` ("barrel_ribbed") is a bright blue plastic
    # drum at hue 199.1, saturation 0.76, concentration 0.96 - the most chromatic
    # cool object in either family, sitting between Shane's #31E6E6 and the Tech
    # resource's #00FFFF. CLAUDE.md 4 reserves those as semantic anchors and
    # CLAUDE.md 8 gives cool patina to weathered technology, not to salvage, so a
    # drum this saturated reads as a Tech pickup at 40 px. `barrel_03`
    # ("barrel_rusted") is not rusted at all: a pale blue-grey steel drum at hue
    # 195.6 and mean luma 101.3, the brightest barrel of the four and cool-cast.
    #
    # The other two are fine and are the reason this is a colour note rather than
    # a source cull: `barrel_01` ("barrel_steel") is a red hazard drum at hue 8.3
    # and `metal_jerrycan` sits at hue 17.8, both inside the Rust bloom #BC431A
    # family the palette already owns. Nothing is regraded yet - this family is
    # not consumed by any runtime scene, so the fix belongs with the wiring-up
    # rather than ahead of it.
    WildBake("wooden_crate_01", "crate_wood", (0.0, 34.0, 149.0)),
    WildBake("wooden_military_crate", "crate_military", (0.0, 41.0, 152.0)),
    WildBake("plastic_crate_01", "crate_plastic", (0.0, 37.0)),
    WildBake("metal_jerrycan", "jerrycan", (0.0, 124.0, 236.0)),
    WildBake("propane_tank", "propane", (0.0, 138.0)),
    WildBake("trashbag", "trashbag", (0.0, 147.0, 259.0)),
    WildBake("hand_truck", "hand_truck", (0.0, 118.0, 243.0)),
    WildBake("rusted_wheel_rim_01", "wheel_rim", (0.0, 133.0)),
    WildBake("metal_toolbox", "toolbox", (0.0, 39.0)),
    WildBake("street_lamp_01", "street_lamp", (0.0, 127.0)),
    WildBake("utility_box_01", "utility_box", (0.0, 36.0)),
    WildBake("old_military_compressor", "compressor", (0.0, 122.0, 246.0)),
    WildBake("plastic_container", "container_plastic", (0.0, 145.0)),
)

FAMILIES = {"polyhaven_wild": WILD, "polyhaven_salvage": SALVAGE}


def _purge_imported() -> None:
    """Drop everything a previous import left behind, geometry data included."""
    for obj in list(bpy.data.objects):
        if obj.get("bespren_wild_import"):
            bpy.data.objects.remove(obj, do_unlink=True)
    for collection in (bpy.data.meshes, bpy.data.materials, bpy.data.images,
                       bpy.data.lights, bpy.data.cameras):
        for block in list(collection):
            if block.users == 0:
                collection.remove(block)


def _prepare_isolated_startup_scene(scene: bpy.types.Scene) -> None:
    """Remove Blender's factory cube/camera/light before any source import.

    The sharded runner launches Blender with ``--factory-startup`` precisely to
    avoid a user's unsaved Blender UI scene. That startup file contains visible
    default objects, which must not leak into a transparent prop render. Refuse
    to mutate a non-isolated process rather than risk touching an artist scene.
    """

    if os.environ.get(ISOLATED_PROCESS_ENV) != "1":
        raise RuntimeError(
            "Wild renderer requires an isolated --factory-startup process; "
            "run tools/art/run_wild_bake.py instead of a live Blender scene"
        )
    for obj in list(scene.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    _purge_imported()


def _import_source(scene: bpy.types.Scene, gltf_path: Path) -> list[bpy.types.Object]:
    """Import one glTF and hand back only its renderable meshes.

    Poly Haven ships display scenes, not props: several carry their own camera
    or a lamp that would fight the stage rig. Those are dropped rather than
    hidden, so a later `bpy.ops` pass cannot resurrect them.
    """
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(gltf_path))
    fresh = [obj for obj in bpy.data.objects if obj not in before]

    meshes: list[bpy.types.Object] = []
    for obj in fresh:
        obj["bespren_wild_import"] = True
        if obj.type == "MESH":
            meshes.append(obj)
    for obj in fresh:
        if obj.type in {"LIGHT", "CAMERA"}:
            bpy.data.objects.remove(obj, do_unlink=True)
    for obj in meshes:
        if obj.name not in scene.collection.all_objects:
            scene.collection.objects.link(obj)
    return meshes


def _ground_and_centre(objects: list[bpy.types.Object]) -> Vector:
    """Stand the subject on z = 0 and centre it on the vertical axis.

    Yaw variants rotate about that axis, so a subject left off-centre would
    orbit instead of turning and every variant would be framed differently.
    """
    minimum, maximum = district._world_bounds(objects)
    shift = Vector((-(minimum.x + maximum.x) * 0.5,
                    -(minimum.y + maximum.y) * 0.5,
                    -minimum.z))
    for obj in objects:
        if obj.parent is None:
            obj.location += shift
    bpy.context.view_layer.update()
    return maximum - minimum


def _yaw(objects: list[bpy.types.Object], degrees: float) -> None:
    from math import radians
    for obj in objects:
        if obj.parent is None:
            obj.rotation_mode = "XYZ"
            obj.rotation_euler.z = radians(degrees)
    bpy.context.view_layer.update()


# Void charcoal #060909, the outline anchor in CLAUDE.md 8.
#
# These are the stored bytes over 255, not a linear-light conversion of them.
# The float buffer behind `image.pixels` round-trips to this PNG unencoded, so
# a byte is simply `value * 255` - which is also why `_analyze_output` reports
# alpha-weighted luma on that scale and why a frame measuring 0.0046 there was
# reported as 1.21. Dividing by 12.92 to "convert to linear" first is the
# obvious move and it is wrong: it wrote the rim at rgb (0, 1, 1) instead of
# (6, 9, 9), six times darker than the anchor and effectively pure black.
SILHOUETTE_RIM_ENCODED: tuple[float, float, float] = (
    6.0 / 255.0,
    9.0 / 255.0,
    9.0 / 255.0,
)
SILHOUETTE_RIM_RADIUS = 2

# The stage has no ground, so it produces no contact ambient occlusion, and the
# family hid that for as long as every subject was wide and low: a rock or a
# fern reads as resting on the floor because its silhouette is already flat
# against it. A tree does not. Repointing the forest canopy onto this atlas put
# a tall narrow subject on the map for the first time and the omission became
# the family's loudest defect - the fir's own root flare, a fully opaque disc
# about 1.2 m across on an 18.9 m tree, measured mean luma 84.5 / 85.8 / 90.1
# against a forest floor of 53.0, so the tree stood on a lit poker chip.
#
# `_apply_silhouette_rim` then converted that into a ring rather than a
# highlight, and the asymmetry is the whole mechanism: the rim ink lands at
# full strength against a hard opaque alpha edge and is diluted to nothing
# against the fuzzy alpha of a leaf card, so a canopy takes a soft line while
# the root flare takes a hard black annulus. Nothing was wrong with the rim,
# with `GroundShadow`, or with the retired procedural tree - all three were
# checked first and all three were innocent.
#
# The first grade multiplied RGB by a smoothstep ramp over the bottom band of
# the subject's own alpha content, flat across the row, to a floor of 0.22. It
# took the fir bases from a lit chip to 54.0 / 56.4 / 28.5, which answered the
# poker chip and produced the next defect: a black puck. A flat row ramp cannot
# tell a trunk from a low branch tier, and at 0.22 it does not need to - the
# rim ink itself is (6, 9, 9), luma 8.4, and 8.4 x 0.22 is 1.85, so the two
# lowest rows of every frame shipped at luma 1.8 to 3.6, under anything the
# game draws. Row profiles say where the rest of the puck came from. fir_1's
# trunk base is 29 px wide (bottom-up rows 174-191) and fir_2's is 27 px
# (167-181), and both sat fully at the floor: a floor problem. fir_0's trunk
# tapers 18 -> 5 px (182-188) under a 33 px low-branch tier (174-181), and
# the tier is what the flat ramp blackened: a lateral problem. The broadleaves
# carry 9 px trunks that are dark in the ungraded source (delivered 28.6 and
# 19.0 against a ground of 50) and pin at the finish shader's own delivered
# floor of about 13 whatever this grade does, so they read as a trunk line
# rather than a puck and are unchanged by any of this.
#
# Delivered numbers are what settled the operator, because a runtime multiply
# (`WorldObstacle2D.WILD_TREE_TINT`) fixed the canopy's hue defect and cannot
# touch a value defect in the same frame: a multiply can only lose value, and
# the puck is baked below the tint's reach. Modelled at the 48/140 the forest
# draws a tree at, through `sleek_sprite_finish` at its forest parameters on a
# luma-50 ground, the shipped bottom three body rows of the five trees sat at
# 15.2 / 15.5 / 16.1 / 17.9 / 15.8 - about 35 under the ground, and 13.0 is the
# shader floor - while the ungraded frames sat at 46.6 / 41.2 / 55.2 / 28.6 /
# 19.0, the firs at ground value, which is the floating foot this grade was
# added for. The operator below is between the two: the same row ramp, times a
# lateral weight that is 1.0 over the columns the subject actually stands on
# (alpha over 0.5 in its lowest `CONTACT_FOOT_DEPTH` of alpha height) and
# falls by smoothstep to 0.0 over `CONTACT_REACH` of alpha height to either
# side, to a floor of 0.60. Swept at floors 0.55 / 0.60 / 0.65, the firs'
# delivered foot lands at 0.58-0.71 / 0.62-0.76 / 0.67-0.81 of a
# `GroundShadow`-darkened ground (50 x 0.74 = 37), and their share of delivered
# band pixels under luma 20 at 15.0-23.2 / 12.0-18.8 / 9.8-16.0 percent against
# 24.5-59.8 shipped. 0.60 is the one that keeps every fir foot below its
# shadowed ground and every fir band share under 20 percent; 0.65 puts fir_2 at
# 0.81 of it, which is a foot at ground value again. Reach 0.12 was tried and
# rejected: it costs the low branches about 3 luma more than 0.06 and is not
# distinguishable from it at delivered size. Off-axis branch luma at the
# shipped reach matches the ungraded frame to within 1 luma on every tree.
#
# The rim rows are graded with everything else and land at 8.4 x 0.60 = 5.0.
# That is under the Void charcoal 8.4 CLAUDE.md 8 reserves for outlines, and
# it is the outline, so nothing else in the frame is under it. Excluding rim
# pixels from the grade was considered and not done, because a grade that
# skips one ink value is a grade that changes shape when the ink does.
#
# It is one shared constant set rather than a per-source column, for the reason
# CLAUDE.md 9 records about `COOL_RIM_ENERGY`: this corrects a deficiency of the
# shared stage, and a stage correction that has to be re-authored per subject is
# a stage correction that will be wrong on the next subject added. The lateral
# term is not a per-subject constant either: it is measured off each frame's
# own footprint columns, which is the one thing about a subject's contact the
# stage does record.
CONTACT_BAND = 0.26
CONTACT_FLOOR = 0.60
CONTACT_HOLD = 0.65
CONTACT_FOOT_DEPTH = 0.06
CONTACT_REACH = 0.06


def _apply_contact_grade(
    path: Path,
    band: float = CONTACT_BAND,
    floor: float = CONTACT_FLOOR,
    hold: float = CONTACT_HOLD,
    foot_depth: float = CONTACT_FOOT_DEPTH,
    reach: float = CONTACT_REACH,
) -> None:
    """Darken the subject where it meets the ground, following its footprint.

    `band` is the fraction of the subject's own alpha height the row ramp
    spans, so a fir and a fern are graded over the same proportion of
    themselves rather than the same pixel count. `floor` is the multiplier
    reached at the contact row over the footprint. `hold` shortens the ramp's
    rise within that span, leaving the lowest rows fully at `floor` instead of
    only touching it on the last row - without it the darkest value exists on
    one row and the foot still reads lit.

    The row ramp is multiplied by a lateral weight so the grade darkens the
    trunk and not the branch tier above it. The footprint is the set of
    columns carrying alpha over 0.5 in the lowest `foot_depth` of the alpha
    height, at least two rows; the weight is 1.0 over those columns and falls
    by smoothstep to 0.0 at `reach` of the alpha height from the nearest one.
    A subject whose lowest rows are all faint - nothing over 0.5 - takes the
    flat row ramp, which is the previous behaviour.

    Orientation matters and is the opposite of the obvious: Blender's
    `Image.pixels` starts at the bottom-left, so the subject's foot is at the
    *smallest* row index here, while the same array read out of PIL would put
    it at the largest. Grading the wrong end darkens the canopy and leaves the
    defect untouched.

    Alpha is deliberately not written. The atlas packer derives
    `content_bounds`, `padded_atlas_region` and every runtime region table from
    alpha alone, so a pure RGB grade cannot move a sprite's placement or
    invalidate a region constant that already ships. Outside the ramp's rows
    the multiplier is exactly 1.0, so a rebake differs from the previous one
    only inside the band and the difference can be checked as such.
    """

    image = bpy.data.images.load(str(path), check_existing=False)
    try:
        width, height = int(image.size[0]), int(image.size[1])
        buffer = np.empty(width * height * 4, dtype=np.float32)
        image.pixels.foreach_get(buffer)
        pixels = buffer.reshape(height, width, 4)

        rows = np.nonzero((pixels[..., 3] > 0.02).any(axis=1))[0]
        if rows.size == 0:
            return
        foot = int(rows.min())
        alpha_height = float(rows.max() - rows.min() + 1)
        span = max(band * alpha_height, 1.0)

        # A column ramp must carry an explicit trailing axis. Broadcasting
        # (height, 1) against (height, width, 3) aligns the ramp with the
        # colour channels on a non-square frame and with *x* on a square one,
        # which these 256 px frames are - it silently grades left-to-right and
        # the measured value does not move at all.
        row_index = np.arange(height, dtype=np.float32)[:, None]
        ramp = np.clip(((foot + float(span)) - row_index) / (span * hold), 0.0, 1.0)
        row_weight = ramp * ramp * (3.0 - 2.0 * ramp)

        depth = max(int(round(foot_depth * alpha_height)), 2)
        footprint = (pixels[foot : foot + depth, :, 3] > 0.5).any(axis=0)
        columns = np.nonzero(footprint)[0]
        if columns.size == 0:
            lateral = np.ones((1, width), dtype=np.float32)
        else:
            x = np.arange(width, dtype=np.float32)
            distance = np.abs(x[:, None] - columns[None, :].astype(np.float32)).min(axis=1)
            t = np.clip(distance / max(reach * alpha_height, 1.0), 0.0, 1.0)
            lateral = (1.0 - t * t * (3.0 - 2.0 * t))[None, :]

        weight = (row_weight * lateral)[..., None]
        pixels[..., :3] *= 1.0 - (1.0 - floor) * weight

        image.pixels.foreach_set(pixels.reshape(-1))
        image.filepath_raw = str(path)
        image.file_format = "PNG"
        image.save()
    finally:
        bpy.data.images.remove(image)


def _apply_silhouette_rim(path: Path, radius: int = SILHOUETTE_RIM_RADIUS) -> None:
    """Ink the subject's own alpha border, for frames that skip Freestyle.

    Freestyle is a 3D edge tracer, so on a leaf-card canopy it inks every card
    border rather than the canopy. This grows the alpha channel instead and
    fills only what the growth added, which is the outer silhouette and nothing
    else - the same shape the runtime's four-sample toon outline draws.

    The neighbourhood is taken with `np.roll`, which wraps at the frame edge.
    That is safe here and not by luck: `_render_to_quality` rejects any frame
    whose subject comes within `MINIMUM_FRAME_MARGIN` of the border, so the
    wrapped samples are always empty background.
    """

    image = bpy.data.images.load(str(path), check_existing=False)
    try:
        width, height = int(image.size[0]), int(image.size[1])
        buffer = np.empty(width * height * 4, dtype=np.float32)
        image.pixels.foreach_get(buffer)
        pixels = buffer.reshape(height, width, 4)
        alpha = pixels[..., 3]

        grown = alpha.copy()
        for offset_y in range(-radius, radius + 1):
            for offset_x in range(-radius, radius + 1):
                if offset_x * offset_x + offset_y * offset_y > radius * radius:
                    continue
                np.maximum(
                    grown,
                    np.roll(np.roll(alpha, offset_y, axis=0), offset_x, axis=1),
                    out=grown,
                )

        added = np.clip(grown - alpha, 0.0, 1.0)
        if not added.any():
            return
        # Straight-alpha source-over with the rim behind the subject.
        safe = np.maximum(grown, 1e-6)[..., None]
        rim = np.array(SILHOUETTE_RIM_ENCODED, dtype=np.float32)
        pixels[..., :3] = (
            pixels[..., :3] * alpha[..., None] + rim * added[..., None]
        ) / safe
        pixels[..., 3] = grown

        image.pixels.foreach_set(pixels.reshape(-1))
        image.filepath_raw = str(path)
        image.file_format = "PNG"
        image.save()
    finally:
        bpy.data.images.remove(image)


def _render_to_quality(
    scene: bpy.types.Scene, target: Path, label: str, rim: bool = False
) -> dict:
    """Render an individual frame until it lands inside the family value band.

    Moss, bark, and a black trashbag are valid dark subjects, but a subject
    darker than the ground it will stand on is not a dark subject, it is a hole.
    The loop therefore aims at the measured band in [wild_bake_contract] rather
    than at the packer's hard floor, and it corrects in both directions: a
    stump photographed in sun is as wrong for this world as a rock photographed
    in shade, and only one of those two errors used to be caught.

    The correction is intentionally per frame: it preserves the shared stage
    while preventing one dark prior source from drifting every following source
    brighter.

    Two different values are measured here and conflating them is a trap worth
    naming, because both halves of it have now been got wrong. The exposure
    decision reads the frame after [func _apply_silhouette_rim] and before
    [func _apply_contact_grade]; the returned stats read the finished file,
    because the manifest and the packer's hard floor describe what actually
    ships.

    The grade is excluded because the band exists to correct how Poly Haven
    photographed a source, and an authored contact shadow is not that.
    Measuring the exposure off the graded frame would buy a canopy brightness
    to pay for a shadow at its feet.

    The rim is included because the band was calibrated with the rim in it,
    and that is the part that was got wrong. Excluding the rim as well looks
    like the same argument - it is also authored, not photographed - but the
    rim was never outside the target the numbers in [wild_bake_contract] were
    measured against, so dropping it silently re-pointed the whole band.
    Because the rim only darkens, the pre-rim value reads brighter, the loop
    read that as overexposure and pulled the stage down: a third of a stop off
    every source, canopy included. It was legible in the profile as a constant
    ratio at 35, 50 and 75 percent of subject height, where the contact ramp is
    exactly zero and nothing should have moved at all - `fir_0` at 0.84
    everywhere above the band, `shrub_0` down from 71.2 to 45.4 against a hard
    floor of 34. `rock_bare_0` was the control that made it obvious: alone in
    the family it held 1.00 above the band, because its silhouette is compact
    enough that the rim costs it almost nothing. Re-calibrating the band would
    not have worked either, since a hard alpha edge takes the rim's ink at full
    strength while a fuzzy canopy dilutes it, so the offset is per subject.
    """

    centre = (TARGET_LUMA_FLOOR + TARGET_LUMA_CEILING) * 0.5
    baseline_exposure = scene.view_settings.exposure
    try:
        for attempt in range(4):
            bpy.ops.render.render(write_still=True)
            if rim:
                _apply_silhouette_rim(target)
            lit_luma = float(
                district._analyze_output(target)["alpha_weighted_luma"]
            )
            _apply_contact_grade(target)
            district._canonicalize_png(target)
            stats = district._analyze_output(target)
            visible = int(stats["visible_pixels"])
            margin = int(stats["edge_margin_px"])
            luma = float(stats["alpha_weighted_luma"])
            if visible < 128:
                raise RuntimeError("%s rendered only %d visible pixels" % (label, visible))
            if margin < MINIMUM_FRAME_MARGIN:
                raise RuntimeError(
                    "%s touches the protected %d px margin (margin=%d)"
                    % (label, MINIMUM_FRAME_MARGIN, margin)
                )
            if TARGET_LUMA_FLOOR <= lit_luma <= TARGET_LUMA_CEILING:
                return stats
            if attempt == 3:
                # Out of stops. Too bright is a cosmetic miss and the frame is
                # still a legal atlas input, so it ships and the report carries
                # the number. Too dark is the defect this band exists to stop,
                # and only the packer's hard floor can excuse it.
                if luma >= MINIMUM_ALPHA_WEIGHTED_LUMA:
                    return stats
                raise RuntimeError(
                    "%s remains below luma floor %.1f after exposure correction (%.2f)"
                    % (label, MINIMUM_ALPHA_WEIGHTED_LUMA, luma)
                )
            # Aim at the centre, not the nearest edge: a frame nudged to sit
            # exactly on a bound is one render seed away from falling out again.
            step = log2(centre / max(lit_luma, 1.0))
            scene.view_settings.exposure += (
                max(0.20, min(step, 1.20)) if step > 0.0
                else min(-0.20, max(step, -1.20))
            )
    finally:
        scene.view_settings.exposure = baseline_exposure
    raise RuntimeError("Unreachable quality loop for %s" % label)


def _match_subject(
    bake: WildBake, meshes: list[bpy.types.Object], token: str, kind: str
) -> list[bpy.types.Object]:
    subset = [obj for obj in meshes if token in obj.name]
    if not subset:
        raise RuntimeError(
            "%s declares %s %r, which matches no imported mesh (have: %s)"
            % (bake.source_id, kind, token, ", ".join(sorted(o.name for o in meshes)))
        )
    return subset


def _clone_layout(
    scene: bpy.types.Scene,
    bake: WildBake,
    meshes: list[bpy.types.Object],
    layout: tuple[tuple[str, float, float, float, float], ...],
) -> list[bpy.types.Object]:
    """Compose one clump frame from clones of the named subjects.

    Clones deliberately share `source.data`, so the geometry, UVs and materials
    stay the immutable CC0 source and the only edits are the transforms that
    replace the catalogue's own row-along-X layout. A token may repeat: a source
    that ships one sprawling shrub becomes a thicket by crossing three of it.

    The set is recentred on its own combined bounds and dropped to z=0, so the
    caller frames a clump exactly the way it frames a single subject - and is
    then normalised up if it is smaller than that caller can frame. See
    [const CLUMP_MINIMUM_SPAN].
    """

    clones: list[bpy.types.Object] = []
    for token, x, y, z_rotation, scale in layout:
        for source in _match_subject(bake, meshes, token, "clump member"):
            clone = source.copy()
            clone.data = source.data
            scene.collection.objects.link(clone)
            clone.matrix_world = Matrix.Identity(4)
            clone.hide_render = False
            clone.hide_set(False)
            clone.location = Vector((x, y, 0.0))
            clone.rotation_mode = "XYZ"
            clone.rotation_euler = (0.0, 0.0, z_rotation)
            clone.scale = Vector((scale, scale, scale))
            clone["bespren_wild_import"] = True
            clones.append(clone)
    bpy.context.view_layer.update()
    minimum, maximum = district._world_bounds(clones)
    shift = Vector(
        (-(minimum.x + maximum.x) * 0.5, -(minimum.y + maximum.y) * 0.5, -minimum.z)
    )
    for clone in clones:
        clone.location += shift
    bpy.context.view_layer.update()
    _normalise_clump_span(clones)
    return clones


def _normalise_clump_span(clones: list[bpy.types.Object]) -> None:
    """Scale a clump up until the shared framing routine can actually frame it.

    `district._frame_asset` floors the span it fits to at 0.75 m, which is a
    guard against degenerate geometry and against an ortho_scale small enough to
    lose precision. Ground cover is genuinely smaller than that guard: a moss mat
    composed at source-real size spans 47 mm, so the routine framed it as though
    it were sixteen times larger and the bake landed 282 lit pixels in a 256 px
    frame - a speck with 117 px of empty margin on every side. Grass hit the same
    floor less severely at 0.60 m.

    Scaling the composition is the correct answer rather than lowering the floor,
    and it is exact rather than approximate. The camera is orthographic, so the
    rendered pixels are invariant to a uniform scale of the whole set; the only
    parts of the rig that read a size are the light distance and the light area,
    and both are themselves floored (`max(exact_span * 0.38, 0.72)` and
    `max(base_size, exact_span * 0.72)`) for every span up to 1.89 m. A clump
    below the framing floor is therefore below the lighting floors both before
    and after, and this scales the framing without touching the light.

    The target is a world dimension rather than the projected span the camera
    actually measures, because that span is not known until the camera has been
    placed from these bounds. At the stage's 42.66-degree elevation the worst
    projection of a world extent is sin(42.66) = 0.678, so a largest-dimension
    target of 1.25 m guarantees a projected span of at least 0.85 - clear of the
    0.75 floor with margin, without needing to solve the placement twice.

    Clumps already larger than the target are left exactly alone: `fern` at 1.3 m
    and `shrub_a` at 2.59 m frame correctly today, and normalising them *down*
    would drop them under the lighting floors and change their exposure.
    """

    if not clones:
        return
    minimum, maximum = district._world_bounds(clones)
    span = max((maximum - minimum).x, (maximum - minimum).y, (maximum - minimum).z)
    if span <= 0.0 or span >= CLUMP_MINIMUM_SPAN:
        return
    factor = CLUMP_MINIMUM_SPAN / span
    for clone in clones:
        clone.location *= factor
        clone.scale *= factor
    bpy.context.view_layer.update()
    minimum, maximum = district._world_bounds(clones)
    shift = Vector(
        (-(minimum.x + maximum.x) * 0.5, -(minimum.y + maximum.y) * 0.5, -minimum.z)
    )
    for clone in clones:
        clone.location += shift
    bpy.context.view_layer.update()


def _place_ground_clip(scene: bpy.types.Scene,
                       height: float) -> list[bpy.types.Object]:
    """Put a holdout plane under the framed subject, or nothing at all.

    Returns the objects it created so the caller can remove them before the
    next unit is framed. A height of zero or less creates nothing and returns
    an empty list, which is the path every source that declares no
    `ground_clip` takes - see the field on `WildBake` for why the plane exists
    and `FIR_GROUND_CLIP` for how its height was chosen.

    The plane is a holdout rather than a cutter: it writes alpha 0 wherever it
    is the first surface the camera sees, so under a camera looking down it
    erases everything beneath its height without touching a vertex. It casts
    no shadow, so the lighting of what remains above it is unchanged. It is
    tagged like an imported clone so `_purge_imported` sweeps it if a bake
    aborts between placement and removal.
    """
    if height <= 0.0:
        return []
    half = GROUND_CLIP_HALF_SIZE
    mesh = bpy.data.meshes.new(GROUND_CLIP_NAME)
    mesh.from_pydata(
        [(-half, -half, 0.0), (half, -half, 0.0),
         (half, half, 0.0), (-half, half, 0.0)],
        [], [(0, 1, 2, 3)])
    mesh.update()
    plane = bpy.data.objects.new(GROUND_CLIP_NAME, mesh)
    plane.location = (0.0, 0.0, height)
    plane.is_holdout = True
    plane.visible_shadow = False
    plane["bespren_wild_import"] = True
    scene.collection.objects.link(plane)
    bpy.context.view_layer.update()
    return [plane]


def _remove_objects(objects: list[bpy.types.Object]) -> None:
    for obj in objects:
        if obj.name in bpy.data.objects:
            bpy.data.objects.remove(obj, do_unlink=True)


def _bake_units(
    scene: bpy.types.Scene, bake: WildBake, meshes: list[bpy.types.Object]
) -> list[tuple[int, list[bpy.types.Object], float, list[bpy.types.Object]]]:
    """Resolve one bake into the frames it actually renders.

    Without `variants` or `clump` a frame is one heading of the whole import,
    which is every source that is genuinely a single subject. With `variants` a
    frame is one named subject, and the heading list is consumed index-wise
    rather than multiplied: three pines from three angles would be nine frames
    of three trees, and the three trees were the point. With `clump` a frame is
    an authored composition of clones and the headings are not consulted at all.

    The fourth element of each unit is the objects that exist only for that
    frame. Clones are not siblings in the import, so the caller's `hide_render`
    sweep cannot reach them and they have to be removed rather than hidden.
    """

    if bake.clump:
        units: list[
            tuple[int, list[bpy.types.Object], float, list[bpy.types.Object]]
        ] = []
        for index, layout in enumerate(bake.clump):
            clones = _clone_layout(scene, bake, meshes, layout)
            units.append((index, clones, 0.0, clones))
        return units

    if not bake.variants:
        return [(index, meshes, yaw, []) for index, yaw in enumerate(bake.yaws)]

    return [
        (
            index,
            _match_subject(bake, meshes, token, "variant"),
            bake.yaws[index % len(bake.yaws)],
            [],
        )
        for index, token in enumerate(bake.variants)
    ]


def _sha256(path: Path) -> str:
    with open(path, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()


def generate(families: tuple[str, ...] = (), only: str = "") -> dict:
    wanted = families or tuple(FAMILIES)
    scene = bpy.context.scene
    _prepare_isolated_startup_scene(scene)
    camera, lights = district._configure_stage(scene)
    scene.render.resolution_x = FRAME_SIZE
    scene.render.resolution_y = FRAME_SIZE
    previous_frame_size = district.FRAME_SIZE
    # `_analyze_output` gates on the module's frame size; this family is
    # smaller on purpose, so tell the analyser the truth for the whole run.
    district.FRAME_SIZE = FRAME_SIZE

    report: dict = {"frame_size": FRAME_SIZE, "families": {}, "errors": []}
    try:
        for family in wanted:
            bakes = FAMILIES[family]
            manifest_path = VAULT / family / "_fetch_manifest.json"
            fetched = json.load(open(manifest_path, encoding="utf-8"))
            sources = {asset["id"]: asset for asset in fetched["assets"]}
            out_dir = OUTPUT_ROOT / family
            out_dir.mkdir(parents=True, exist_ok=True)

            frames = []
            for bake in bakes:
                if only and bake.source_id != only:
                    continue
                asset = sources.get(bake.source_id)
                if asset is None or not asset.get("entry"):
                    report["errors"].append(
                        {"family": family, "id": bake.source_id,
                         "error": "not in fetch manifest"})
                    continue
                gltf = VAULT / family / asset["entry"]
                units: list[
                    tuple[int, list[bpy.types.Object], float, list[bpy.types.Object]]
                ] = []
                try:
                    _purge_imported()
                    meshes = _import_source(scene, gltf)
                    if not meshes:
                        raise RuntimeError("no mesh in %s" % gltf.name)
                    scene.render.use_freestyle = bake.freestyle
                    units[:] = _bake_units(scene, bake, meshes)
                    # Clones for every clump layout exist at once, so the sweep
                    # below has to be able to see them. Hiding is the mechanism
                    # for both kinds of non-subject: an unrendered sibling in the
                    # import, and a clone belonging to a different composition.
                    staged = list(meshes) + [
                        obj for _, _, _, temporary in units for obj in temporary
                    ]
                    for index, subject, yaw, _temporary in units:
                        # Siblings stay in the file but out of the frame. Every
                        # measurement below - bounds, framing, luma - is taken
                        # from `subject` alone, so a whole-import bake and a
                        # single-subject bake go down the same path.
                        for obj in staged:
                            obj.hide_render = obj not in subject
                        size = _ground_and_centre(subject)
                        _yaw(subject, yaw)
                        district._frame_asset(
                            camera, lights, subject, bake.framing,
                            compensate_falloff=True,
                            elevation_degrees=bake.elevation,
                        )
                        name = "%s_%d.png" % (bake.key, index)
                        target = out_dir / name
                        scene.render.filepath = str(target)
                        # The clip plane is created after framing and removed
                        # before the next unit, so it never enters `subject`
                        # or `staged` and no measurement in this loop can see
                        # it; see [func _place_ground_clip].
                        clip = _place_ground_clip(scene, bake.ground_clip)
                        try:
                            stats = _render_to_quality(
                                scene, target, "%s/%s" % (family, name),
                                rim=not bake.freestyle,
                            )
                        finally:
                            _remove_objects(clip)
                        frames.append({
                            "key": bake.key, "variant": index, "yaw_deg": yaw,
                            "file": name, "source_id": bake.source_id,
                            "source_name": asset["name"],
                            "source_url": asset["url"],
                            "license": asset["license"],
                            "authors": asset["authors"],
                            "world_size_m": [round(v, 4) for v in size],
                            "world_height_m": round(
                                bake.height_override or size.z, 4),
                            "sha256": _sha256(target),
                            **{k: (round(v, 3) if isinstance(v, float) else v)
                               for k, v in stats.items()},
                        })
                        print("[wild] %-14s %-22s v%d  %5.2f m  luma %5.1f  margin %d"
                              % (family.split("_")[1], bake.key, index, size.z,
                                 stats["alpha_weighted_luma"],
                                 stats["edge_margin_px"]), flush=True)
                except Exception as exc:  # noqa: BLE001 - render the rest
                    report["errors"].append({"family": family, "id": bake.source_id,
                                             "error": "%s: %s" % (type(exc).__name__, exc)})
                    print("[FAIL] %s %s: %s" % (family, bake.source_id, exc), flush=True)
                finally:
                    # Clones carry the import tag and would be swept by the next
                    # `_purge_imported` anyway; removing them here keeps one
                    # source's compositions out of the next source's bounds.
                    _remove_objects([
                        obj for _, _, _, temporary in units for obj in temporary
                    ])
                    units.clear()
            _purge_imported()

            report["families"][family] = {
                "output_dir": str(out_dir.relative_to(PROJECT_ROOT)).replace(os.sep, "/"),
                "source_manifest": str(manifest_path.relative_to(PROJECT_ROOT)).replace(os.sep, "/"),
                "license": "CC0-1.0",
                "license_url": "https://polyhaven.com/license",
                "sources": len(bakes), "frames": len(frames), "frame_list": frames,
            }
            print("[wild] %s -> %d frame(s) from %d source(s)"
                  % (family, len(frames), len(bakes)), flush=True)
    finally:
        district.FRAME_SIZE = previous_frame_size
        district._remove_stage_objects(scene)
        _purge_imported()

    suffix = ("_" + only) if only else ""
    path = OUTPUT_ROOT / ("polyhaven_wild_render_report%s.json" % suffix)
    json.dump(report, open(path, "w", encoding="utf-8"), indent=1)
    print("[wild] %d error(s) -> %s" % (len(report["errors"]), path), flush=True)
    return report


if __name__ == "__main__":
    # `-- <family> [asset_id]`. Naming one asset is how `run_wild_bake.py`
    # drives this: Poly Haven's scanned conifers carry hundreds of megabytes of
    # leaf geometry apiece, and importing several into one session crashes
    # Blender outright. One process per asset both caps the peak and keeps a
    # crash from costing the other thirty-one renders.
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    families = tuple(argv[:1]) if argv else ()
    generate(families, argv[1] if len(argv) > 1 else "")
