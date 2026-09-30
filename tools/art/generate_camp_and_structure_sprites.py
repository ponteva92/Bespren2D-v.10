"""Render Bespren's camp refuge and eight Tier-1 structures in Blender.

The generator uses a dedicated scene, local primitives, shared authored
materials, orthographic three-quarter lighting, and transparent output.  It is
safe to run repeatedly and never mutates the user's default Blender scene.
"""

from __future__ import annotations

from math import cos, pi, sin
import os
from pathlib import Path

import bpy
from mathutils import Vector


PROJECT_ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = PROJECT_ROOT / "assets" / "2d" / "structures"
# The production renders above are deliberately immutable from an audit pass.
# A candidate must opt into both a named staging mode and a directory below
# build/.  This lets us render and compare a replacement silhouette without
# accidentally touching the live texture preloads in StructureCatalog.
STAGING_MODE_ENV = "BESPREN_STRUCTURE_SILHOUETTE_STAGE"
STAGING_OUTPUT_ENV = "BESPREN_STRUCTURE_STAGING_OUTPUT"
STAGING_MODE_VALUE = "v2"
STAGE_NAME = "BESPREN_CAMP_STRUCTURE_STAGE"

## Freestyle outline width in render pixels.  Every asset here is authored at
## 320 x 320 and then minified hard on screen, so the outline is not a stylistic
## flourish - it is the only thing holding a silhouette together once the sprite
## is a few dozen pixels wide.  The default suits a turret, which fills its
## frame; the camp is a wide cluster rendered at nearly twice the orthographic
## scale, so its lines arrive on screen roughly half as wide and need their own
## value.  See the per-asset fourth column in the render list.
OUTLINE_THICKNESS_DEFAULT = 1.45
OUTLINE_THICKNESS_CAMP = 2.7

## Energy of the shared teal rim light, per asset.  The rim earns its place on
## the eight structures: they are salvaged metal and tech, the palette gives
## them Copper patina #1C8270 as their weathering language, and a cool edge is
## what separates a rusted silhouette from a rusted background.  The camp is the
## one asset in this rig that must go the other way.  CLAUDE.md 2 makes the
## refuge "always warmer, rounder, and more rhythmic than the world around it",
## and at full strength this light does the opposite - it is a broad DISK of
## size 3.4 rather than a grazing rim, so it floods the tent's whole upper-right
## facet and paints the largest surface of the refuge in Shane's identity cyan.
## Retuning the canvas albedo was tried first and could not fix it, because the
## cause is the light and not the material.
## The shared rim is shared on purpose, and two attempts to give the camp its
## own settings are the reason that is written down here.  The camp's tent
## carried a bright facet that looked cyan next to its warm neighbours, so the
## rim was first cut from 820 W to 165 W and then, when that failed, recoloured
## to neutral grey.  Neither moved it, because neither was the cause: measuring
## the bake found six perceptibly green pixels in 26,950 - 0.022 percent, all
## dark, all in one 8 x 15 patch - and the facet itself measures (121, 120, 49),
## which is red-over-green.  It is a yellow highlight on a lit canvas slope,
## which is what a lit canvas slope is supposed to look like.  The metric that
## started this said 18 percent green because it tested g > r by a single unit,
## and BSP_Structure_Steel (0.27, 0.31, 0.29) and BSP_Camp_Stone (0.115, 0.125,
## 0.120) are authored a hair green while reading as neutral grey.  If a future
## asset genuinely needs its own key, add the column back - but measure the bake
## first, with a threshold that means something.
COOL_RIM_ENERGY: float = 820.0


def _material(
    name: str,
    color: tuple[float, float, float],
    metallic: float = 0.0,
    roughness: float = 0.6,
    emission: tuple[float, float, float] | None = None,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1.0)
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    if emission is not None:
        shader.inputs["Emission Color"].default_value = (*emission, 1.0)
        shader.inputs["Emission Strength"].default_value = emission_strength
    else:
        shader.inputs["Emission Strength"].default_value = 0.0
    return material


def _activate(collection: bpy.types.Collection) -> None:
    bpy.context.view_layer.active_layer_collection = (
        bpy.context.view_layer.layer_collection.children[collection.name]
    )


def _collection(stage: bpy.types.Scene, name: str) -> bpy.types.Collection:
    collection = bpy.data.collections.new(name)
    stage.collection.children.link(collection)
    return collection


def _finish(obj: bpy.types.Object, material: bpy.types.Material, bevel: float = 0.05) -> bpy.types.Object:
    if bevel > 0.0 and obj.type == "MESH":
        modifier = obj.modifiers.new("BSP worn edge", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    obj.data.materials.append(material)
    return obj


def _cube(
    collection: bpy.types.Collection,
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material: bpy.types.Material,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    bevel: float = 0.06,
) -> bpy.types.Object:
    _activate(collection)
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(obj, material, bevel)


def _cylinder(
    collection: bpy.types.Collection,
    name: str,
    location: tuple[float, float, float],
    radius: float,
    depth: float,
    material: bpy.types.Material,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    vertices: int = 16,
    bevel: float = 0.045,
) -> bpy.types.Object:
    _activate(collection)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    return _finish(obj, material, bevel)


def _sphere(
    collection: bpy.types.Collection,
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material: bpy.types.Material,
) -> bpy.types.Object:
    _activate(collection)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(obj, material, 0.035)


def _cone(
    collection: bpy.types.Collection,
    name: str,
    location: tuple[float, float, float],
    radius_1: float,
    radius_2: float,
    depth: float,
    material: bpy.types.Material,
    vertices: int = 8,
    rotation_z: float = 0.0,
) -> bpy.types.Object:
    _activate(collection)
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=radius_1,
        radius2=radius_2,
        depth=depth,
        location=location,
        rotation=(0.0, 0.0, rotation_z),
    )
    obj = bpy.context.object
    obj.name = name
    return _finish(obj, material, 0.04)


def _torus(
    collection: bpy.types.Collection,
    name: str,
    location: tuple[float, float, float],
    major_radius: float,
    minor_radius: float,
    material: bpy.types.Material,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    _activate(collection)
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius,
        minor_radius=minor_radius,
        major_segments=24,
        minor_segments=8,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    return obj


def _camp_light(
    collection: bpy.types.Collection,
    name: str,
    location: tuple[float, float, float],
    energy: float,
    color: tuple[float, float, float],
    light_type: str = "AREA",
    size: float = 3.0,
    target: tuple[float, float, float] = (0.0, -0.4, 0.7),
) -> bpy.types.Object:
    """A light that belongs to the camp collection rather than the shared rig.

    The shared rig is right for eight pieces of salvaged hardware and wrong for
    the one object that has to read as shelter.  Its cool rim lands squarely on
    the tent's broad canvas face, which painted the largest surface in the refuge
    in Shane's teal - the wrong identity colour, and the wrong temperature for
    the thing CLAUDE.md 2 calls the warm centre of the game.  Rather than retune
    a rig that eight finished assets already depend on, the camp brings its own
    firelight.  The render loop toggles ``hide_render`` per collection and a
    light inside a hidden collection contributes nothing, so these never reach
    the other eight renders.
    """
    light_data = bpy.data.lights.new(name, light_type)
    light_data.energy = energy
    light_data.color = color
    if light_type == "AREA":
        light_data.shape = "DISK"
        light_data.size = size
    else:
        light_data.shadow_soft_size = size
    light = bpy.data.objects.new(name, light_data)
    collection.objects.link(light)
    light.location = location
    light.rotation_euler = (
        Vector(target) - Vector(location)
    ).to_track_quat("-Z", "Y").to_euler()
    return light


def _build_camp(stage: bpy.types.Scene, m: dict[str, bpy.types.Material]) -> bpy.types.Collection:
    """The refuge, composed as one clustered mass around a fire.

    Rebuilt against a measurement rather than a taste call.  Downsampled to the
    74 x 55 screen pixels it actually occupies at the gameplay zoom of 0.38, the
    previous camp resolved into a flat brown ellipse: over half the frame was
    empty ground mat, the props were pushed out to its rim at roughly the mat's
    own value so nothing had a silhouette, and the brightest warm shape in the
    whole refuge was a six-pixel campfire sitting off at the left edge while a
    teal-lit canvas pyramid held the middle.

    Three things changed.  The ground shrank and split into two values so it
    grounds the camp instead of dominating it.  The props pulled into a ring
    around the fire so the silhouette reads as one mass rather than a scatter.
    And the fire moved to the centre and grew - with an ember bed, a real flame,
    and its own light - until it survives the downsample as the warm heart the
    refuge is supposed to be.
    """
    c = _collection(stage, "CampRefuge")

    # Two values, not one.  A single flat disc is what read as a poker chip; a
    # darker skirt under a lighter trodden centre gives the pad an edge and lets
    # everything standing on it separate.
    _cylinder(c, "Camp earth skirt", (0.0, 0.0, 0.05), 3.02, 0.10, m["camp_earth_dark"], vertices=26)
    _cylinder(c, "Camp packed earth", (0.0, 0.0, 0.13), 2.74, 0.13, m["camp_earth"], vertices=24)

    # --- the fire, at the centre, big enough to survive the downsample --------
    fire = (0.10, -0.80)
    for index in range(7):
        angle = index * (2.0 * pi / 7.0) + 0.35
        _sphere(
            c,
            f"Fire ring stone {index}",
            (fire[0] + cos(angle) * 0.92, fire[1] + sin(angle) * 0.92, 0.26),
            (0.27, 0.27, 0.17),
            m["camp_stone"],
        )
    _cylinder(c, "Fire ember bed", (fire[0], fire[1], 0.24), 0.66, 0.16, m["ember"], vertices=12)
    for index, angle in enumerate((-0.62, 0.78)):
        _cylinder(
            c,
            f"Fire log {index}",
            (fire[0], fire[1], 0.40),
            0.15,
            1.55,
            m["timber"],
            rotation=(0.0, pi / 2, angle),
            vertices=10,
        )
    # Small and saturated rather than large and bright. Measured across the whole
    # render, AgX pulls saturation from 0.58 in the 60-90 luma band down to 0.12
    # at the film white point, so a flame authored to be the brightest thing in
    # the sprite arrives as a white cone - a second, paler tent beside the real
    # one, which is exactly how the previous camp failed. The bake therefore keeps
    # the fire in the band where it is still orange and leaves the glow to the
    # engine, where base_core.tscn already stacks an amber PointLight2D, an
    # additive aura and an emissive shader over this texture.
    _cone(c, "Fire flame", (fire[0], fire[1], 0.86), 0.42, 0.0, 0.92, m["flame"], vertices=7)
    _camp_light(
        c,
        "BSP Camp Firelight",
        (fire[0], fire[1], 1.05),
        330.0,
        (1.0, 0.50, 0.15),
        light_type="POINT",
        size=0.35,
    )
    # A narrow warm fill from the camera's own side, aimed at the props rather
    # than spread across the floor. The first version of this was a broad 420 W
    # disc and it lifted the ground to within a few luma of everything standing
    # on it, which is how a camp full of distinct objects rendered as one tan
    # blob. Measured at the 74 px the sprite actually occupies, the tent, the
    # pad, the berm and the crates were all between 96 and 113.
    _camp_light(
        c,
        "BSP Camp Warm Fill",
        (-1.4, -5.2, 5.6),
        184.0,
        (1.0, 0.78, 0.56),
        size=2.2,
        target=(-0.9, 0.6, 1.1),
    )
    # The shared rig's cool rim sits up and to the right, which is exactly where
    # the shelter's broad canvas face points, so the largest surface in the
    # refuge came out a flat grey-green no matter how warm its albedo was set.
    # Darkening the canvas only made a darker grey-green. This puts a warm rim in
    # the same place, strong enough to take that face back, and it stays inside
    # the camp collection so the eight structures keep the cool rim they were lit
    # and approved under.
    #
    # Warm, but deliberately not orange, and that distinction cost a revision.
    # This light exists to CANCEL the teal rim, which a warm neutral does just as
    # well as a saturated one - and at (1.0, 0.56, 0.26) it did far more than
    # cancel. Stacked on the firelight and the shared warm key, roughly 1.3 kW of
    # near-pure orange landed on a camp whose albedos are all warm or neutral
    # already, so every material converged on one hue: the steel drum, the timber
    # crates, the canvas tent and the earth pad all rendered the same orange at
    # different values, with blue crushed under 20 everywhere. Measured over the
    # sprite the camp spanned 18.9 degrees of hue where the eight structures off
    # the same rig span 101 to 246, and it carried the highest mean saturation of
    # the nine. Energy is compensated for the lift in the green and blue channels
    # so the exposure the rest of the composition was tuned against holds.
    _camp_light(
        c,
        "BSP Camp Warm Rim",
        (4.6, 2.6, 6.4),
        580.0,
        (1.0, 0.80, 0.62),
        size=3.6,
        target=(-0.9, 0.7, 1.0),
    )

    # --- shelter, upper left, angled so its broad face takes the warm side ----
    tent = (-2.05, 1.52)
    _cone(c, "Canvas shelter", (tent[0], tent[1], 0.88), 1.52, 0.10, 1.52, m["canvas"], vertices=4, rotation_z=pi / 4)
    _cube(c, "Shelter dark entrance", (tent[0], tent[1] - 1.02, 0.62), (0.52, 0.06, 0.50), m["charcoal"], bevel=0.03)
    # The refuge glows from inside, not just from a seam painted on the outside.
    _cube(c, "Shelter inner glow", (tent[0], tent[1] - 0.94, 0.50), (0.34, 0.03, 0.30), m["amber"], bevel=0.02)
    _cylinder(c, "Shelter ridge pole", (tent[0], tent[1], 1.72), 0.055, 0.62, m["timber"], vertices=6)

    # --- sandbag berm, one continuous arc facing out ------------------------
    # The old two straight rows read as loose stones.  An arc along the outer
    # edge reads as a wall, which is the only thing a sandbag is for.
    # Eleven, alternating in radius and height. Fifteen evenly spaced bags
    # overlapped into one smooth tube that the outline then welded shut, and a
    # tube is a hose, not a wall. A scalloped top edge is what makes the eye
    # count individual bags at three screen pixels each.
    for index in range(11):
        angle = pi * 0.03 + index * (pi * 0.76 / 10.0)
        stagger = index % 2
        radius = 2.52 + 0.13 * stagger
        _sphere(
            c,
            f"Sandbag berm {index}",
            (cos(angle) * radius, sin(angle) * radius, 0.30 + 0.09 * stagger),
            (0.36, 0.32, 0.22 + 0.04 * stagger),
            m["sandbag"],
        )

    # --- utility ring around the fire ---------------------------------------
    _cylinder(c, "Water drum", (-2.28, -0.42, 0.62), 0.46, 1.10, m["steel"], vertices=16)
    _torus(c, "Drum band top", (-2.28, -0.42, 0.98), 0.47, 0.045, m["rust"])
    _cube(c, "Workbench", (1.92, 0.72, 0.68), (0.82, 0.32, 0.10), m["timber"])
    for x in (1.28, 2.56):
        _cube(c, f"Workbench leg {x}", (x, 0.72, 0.34), (0.08, 0.24, 0.34), m["steel"])
    _cube(c, "Radio console", (1.86, 0.64, 0.94), (0.32, 0.22, 0.23), m["steel"])
    _sphere(c, "Radio display", (1.86, 0.38, 1.00), (0.09, 0.04, 0.09), m["teal"])
    _cube(c, "Supply crate A", (1.78, -1.72, 0.48), (0.55, 0.50, 0.46), m["timber"])
    _cube(c, "Supply crate B", (2.58, -1.30, 0.36), (0.38, 0.38, 0.34), m["rust"])
    # The lower-left quarter of the pad was carrying nothing, which read as the
    # camp being a cluster pushed into one corner of its own ground. A bedroll is
    # also the one prop that says somebody lives here rather than works here.
    _cylinder(c, "Bedroll", (-1.62, -1.88, 0.32), 0.30, 1.15, m["canvas"],
              rotation=(0.0, pi / 2, 0.55), vertices=10)
    _cube(c, "Bedroll pack", (-2.28, -1.42, 0.38), (0.32, 0.30, 0.26), m["rust"])
    _cylinder(c, "Radio mast", (2.42, 1.32, 1.32), 0.055, 2.45, m["steel"], vertices=10)
    _sphere(c, "Radio beacon", (2.42, 1.32, 2.62), (0.19, 0.19, 0.19), m["amber"])
    return c


def _base_plate(c: bpy.types.Collection, m: dict[str, bpy.types.Material], radius: float = 1.35) -> None:
    _cylinder(c, "Base plate", (0.0, 0.0, 0.18), radius, 0.32, m["charcoal"], vertices=12)
    _torus(c, "Base retaining ring", (0.0, 0.0, 0.36), radius * 0.78, 0.1, m["rust"])


def _build_kinetic(
    stage: bpy.types.Scene,
    m: dict[str, bpy.types.Material],
    staging: bool = False,
) -> bpy.types.Collection:
    c = _collection(stage, "T1Kinetic")
    if staging:
        # Read as an asymmetrical gun carriage instead of another circular
        # generator.  The long forward rail, right-side ammunition feeder and
        # rear counterweight deliberately survive the 0.32 in-world scale as a
        # three-part T rather than collapsing into a round dark token.
        _cube(c, "Kinetic armored rail", (0.0, 0.18, 0.26), (1.48, 0.54, 0.22), m["charcoal"], rotation=(0.0, 0.0, -0.08))
        _cube(c, "Kinetic forward outrigger", (0.0, -0.96, 0.28), (0.48, 0.92, 0.16), m["steel"])
        _cube(c, "Kinetic swivel block", (0.0, -0.16, 0.82), (0.66, 0.58, 0.44), m["rust"], rotation=(0.0, 0.0, -0.08))
        _cylinder(c, "Scrap bolt barrel", (0.0, -1.55, 1.15), 0.16, 1.95, m["steel"], rotation=(pi / 2, 0.0, 0.0), vertices=10)
        _cube(c, "Kinetic right feeder", (0.92, 0.05, 0.92), (0.34, 0.48, 0.42), m["amber"], rotation=(0.0, 0.0, -0.18))
        _cylinder(c, "Kinetic rear counterweight", (-0.88, 0.52, 0.78), 0.38, 0.48, m["steel"], rotation=(0.0, pi / 2, 0.0), vertices=10)
        return c
    _base_plate(c, m)
    for angle in (0.0, 2.094, 4.188):
        end = Vector((1.05 * cos(angle), 1.05 * sin(angle), 0.2))
        _cube(c, f"Tripod {angle}", (end.x * 0.55, end.y * 0.55, 0.72), (0.09, 0.09, 0.75), m["steel"], rotation=(0.18 * end.y, -0.18 * end.x, angle))
    _cylinder(c, "Kinetic swivel", (0.0, 0.0, 1.25), 0.62, 0.48, m["steel"], vertices=14)
    _cube(c, "Kinetic receiver", (0.0, -0.18, 1.65), (0.48, 0.65, 0.34), m["rust"])
    _cylinder(c, "Scrap bolt barrel", (0.0, -1.22, 1.72), 0.14, 1.7, m["steel"], rotation=(pi / 2, 0.0, 0.0), vertices=12)
    _cylinder(c, "Ammo drum", (0.58, -0.18, 1.5), 0.34, 0.34, m["amber"], rotation=(0.0, pi / 2, 0.0), vertices=12)
    return c


def _build_chemical(
    stage: bpy.types.Scene,
    m: dict[str, bpy.types.Material],
    staging: bool = False,
) -> bpy.types.Collection:
    c = _collection(stage, "T1Chemical")
    if staging:
        # Two oversized pressure vessels with a visible central void make the
        # area-denial role legible even in grayscale.  A rectangular skid gives
        # it a different footprint from both the kinetic carriage and the coil.
        _cube(c, "Chemical twin-tank skid", (0.0, 0.14, 0.24), (1.62, 0.76, 0.20), m["charcoal"], rotation=(0.0, 0.0, 0.08))
        for index, x in enumerate((-0.76, 0.76)):
            _cylinder(c, f"Chemical pressure vessel {index}", (x, 0.18, 1.24), 0.48, 1.96, m["chemical"], vertices=12)
            _torus(c, f"Pressure vessel band {index}", (x, 0.18, 1.20), 0.49, 0.065, m["steel"])
        _cube(c, "Chemical bridge manifold", (0.0, -0.26, 1.78), (0.38, 0.32, 0.20), m["steel"])
        for index, x in enumerate((-0.45, 0.45)):
            _cylinder(c, f"Chemical paired nozzle {index}", (x, -0.96, 1.54), 0.14, 0.96, m["chemical"], rotation=(pi / 2.2, 0.0, 0.0), vertices=10)
        _sphere(c, "Chemical central warning", (0.0, -0.38, 2.14), (0.15, 0.12, 0.17), m["chemical_glow"])
        return c
    _base_plate(c, m)
    for index, x in enumerate((-0.52, 0.52)):
        _cylinder(c, f"Chemical tank {index}", (x, 0.15, 1.18), 0.43, 1.7, m["chemical"], vertices=14)
        _torus(c, f"Tank band {index}", (x, 0.15, 1.25), 0.44, 0.055, m["steel"])
    _cube(c, "Chemical manifold", (0.0, -0.38, 1.72), (0.7, 0.24, 0.2), m["steel"])
    _cylinder(c, "Chemical mortar", (0.0, -0.9, 1.92), 0.19, 1.2, m["chemical"], rotation=(pi / 2.35, 0.0, 0.0), vertices=12)
    _sphere(c, "Chemical pressure lamp", (0.0, 0.0, 2.22), (0.2, 0.2, 0.2), m["chemical_glow"])
    return c


def _build_electric(
    stage: bpy.types.Scene,
    m: dict[str, bpy.types.Material],
    staging: bool = False,
) -> bpy.types.Collection:
    c = _collection(stage, "T1Electric")
    if staging:
        # A deliberately open four-fork silhouette.  The gaps are as important
        # as the cyan material: they prevent the chain-control tower becoming a
        # third generic cylinder when the camera compresses its height.
        _cube(c, "Electric diamond plinth", (0.0, 0.0, 0.22), (1.28, 1.28, 0.20), m["charcoal"], rotation=(0.0, 0.0, pi * 0.25))
        _cube(c, "Electric open core", (0.0, 0.0, 0.76), (0.30, 0.30, 0.54), m["bone"])
        for index, angle in enumerate((0.14, pi * 0.5 + 0.14, pi + 0.14, pi * 1.5 + 0.14)):
            arm_x = 0.78 * cos(angle)
            arm_y = 0.78 * sin(angle)
            _cube(c, f"Electric fork arm {index}", (arm_x, arm_y, 1.20), (0.14, 0.72, 0.14), m["copper"], rotation=(0.0, 0.28, angle))
            _cylinder(c, f"Electric fork tip {index}", (1.24 * cos(angle), 1.24 * sin(angle), 1.46), 0.085, 0.66, m["cyan"], rotation=(0.30 * sin(angle), -0.30 * cos(angle), 0.0), vertices=7)
        _sphere(c, "Electric exposed corona", (0.0, 0.0, 1.74), (0.26, 0.26, 0.26), m["cyan"])
        return c
    _base_plate(c, m)
    _cylinder(c, "Electric ceramic column", (0.0, 0.0, 1.15), 0.38, 1.75, m["bone"], vertices=12)
    for index, z in enumerate((0.65, 1.02, 1.39, 1.76)):
        _torus(c, f"Copper coil {index}", (0.0, 0.0, z), 0.58 - index * 0.055, 0.075, m["copper"])
    _sphere(c, "Electric corona", (0.0, 0.0, 2.28), (0.43, 0.43, 0.43), m["cyan"])
    for angle in (0.0, pi * 0.5, pi, pi * 1.5):
        _cylinder(c, f"Arc fork {angle}", (0.72 * cos(angle), 0.72 * sin(angle), 1.72), 0.06, 0.72, m["cyan"], rotation=(0.3 * sin(angle), -0.3 * cos(angle), 0.0), vertices=8)
    return c


def _build_support(stage: bpy.types.Scene, m: dict[str, bpy.types.Material]) -> bpy.types.Collection:
    c = _collection(stage, "T1Support")
    _base_plate(c, m, 1.42)
    _cube(c, "Support worktop", (0.0, 0.15, 0.95), (1.0, 0.65, 0.16), m["timber"])
    _cube(c, "Support tool cabinet", (-0.62, 0.15, 0.6), (0.28, 0.5, 0.48), m["teal"])
    _cube(c, "Support scanner", (0.46, -0.12, 1.35), (0.38, 0.3, 0.34), m["steel"])
    _cylinder(c, "Support mast", (0.62, 0.42, 1.9), 0.07, 1.8, m["steel"], vertices=10)
    _cone(c, "Support dish", (0.62, 0.42, 2.67), 0.62, 0.08, 0.3, m["teal"], vertices=18)
    _sphere(c, "Support status", (-0.62, -0.42, 1.15), (0.16, 0.08, 0.16), m["teal_glow"])
    return c


def _build_barricade(stage: bpy.types.Scene, m: dict[str, bpy.types.Material]) -> bpy.types.Collection:
    c = _collection(stage, "T1Barricade")
    _cube(c, "Barricade shadow", (0.0, 0.0, 0.12), (2.45, 0.62, 0.1), m["charcoal"])
    for index, x in enumerate((-2.1, -0.7, 0.7, 2.1)):
        _cylinder(c, f"Barricade post {index}", (x, 0.0, 0.95), 0.18, 1.75, m["timber"], vertices=10)
    for index, z in enumerate((0.62, 1.16)):
        _cube(c, f"Barricade rail {index}", (0.0, 0.0, z), (2.42, 0.22, 0.18), m["timber"], rotation=(0.0, 0.0, 0.04 if index == 0 else -0.05))
    for index, x in enumerate((-1.35, 0.15, 1.45)):
        _cube(c, f"Barricade scrap plate {index}", (x, -0.28, 1.0), (0.48, 0.08, 0.42), m["rust"], rotation=(0.0, 0.0, 0.12 * (index - 1)))
    return c


def _build_landmine(
    stage: bpy.types.Scene,
    m: dict[str, bpy.types.Material],
    staging: bool = False,
) -> bpy.types.Collection:
    c = _collection(stage, "T1Landmine")
    if staging:
        # The consumable blast trap owns a compact diamond chassis and four
        # broad fins.  It must read as a deliberate warning device, never as a
        # buried hole or another low round base.
        _cube(c, "Mine diamond chassis", (0.0, 0.0, 0.18), (1.08, 1.08, 0.18), m["steel"], rotation=(0.0, 0.0, pi * 0.25))
        _cube(c, "Mine diamond pressure cap", (0.0, 0.0, 0.42), (0.62, 0.62, 0.14), m["charcoal"], rotation=(0.0, 0.0, pi * 0.25))
        for index, angle in enumerate((pi * 0.25, pi * 0.75, pi * 1.25, pi * 1.75)):
            _cube(c, f"Mine blast fin {index}", (0.98 * cos(angle), 0.98 * sin(angle), 0.38), (0.44, 0.12, 0.16), m["rust"], rotation=(0.0, 0.0, angle))
        _sphere(c, "Mine warning lamp", (0.0, -0.16, 0.64), (0.18, 0.18, 0.14), m["red"])
        return c
    _cylinder(c, "Mine pressure plate", (0.0, 0.0, 0.22), 1.28, 0.36, m["steel"], vertices=16)
    _cylinder(c, "Mine inner plate", (0.0, 0.0, 0.44), 0.76, 0.2, m["charcoal"], vertices=12)
    _sphere(c, "Mine warning lamp", (0.0, -0.15, 0.64), (0.2, 0.2, 0.15), m["red"])
    for index in range(8):
        angle = index * pi / 4.0
        _cube(c, f"Mine tooth {index}", (1.08 * cos(angle), 1.08 * sin(angle), 0.38), (0.16, 0.08, 0.14), m["rust"], rotation=(0.0, 0.0, angle))
    return c


def _build_slowing_pit(
    stage: bpy.types.Scene,
    m: dict[str, bpy.types.Material],
    staging: bool = False,
) -> bpy.types.Collection:
    c = _collection(stage, "T1SlowingPit")
    if staging:
        # A persistent scrap pit is an open, broken trench: irregular earth
        # berms frame a long dark cavity with a clear entrance.  It intentionally
        # avoids a radial rim, so it cannot be confused with the landmine above.
        # A low seven-sided depression keeps a visible dark *void* between the
        # berms.  The earlier rectangular slab read as a small platform / pallet
        # at 36px, which inverted the intended ground-trap hierarchy.
        cavity = _cylinder(
            c,
            "Pit open depression",
            (0.0, 0.06, 0.09),
            1.12,
            0.10,
            m["camp_earth_dark"],
            rotation=(0.0, 0.0, -0.18),
            vertices=7,
        )
        # The longer, narrow trench also prevents the mask from collapsing back
        # into the mine's compact central diamond after gameplay minification.
        cavity.scale = (1.62, 0.46, 1.0)
        berms = (
            (-1.42, 0.22, 0.34, 0.36, 0.20),
            (-0.66, 0.68, 0.48, 0.26, 0.18),
            (0.22, 0.72, 0.44, 0.24, 0.17),
            (1.30, 0.22, 0.34, 0.36, 0.20),
            (-0.24, -0.58, 0.30, 0.22, 0.14),
        )
        for index, (x, y, sx, sy, sz) in enumerate(berms):
            _sphere(c, f"Pit broken earth berm {index}", (x, y, 0.30), (sx, sy, sz), m["soil"])
        _cube(c, "Pit broken rim slat A", (-1.30, -0.18, 0.42), (0.26, 0.07, 0.07), m["timber"], rotation=(0.0, 0.0, 0.36))
        _cube(c, "Pit broken rim slat B", (1.12, 0.46, 0.40), (0.20, 0.07, 0.07), m["timber"], rotation=(0.0, 0.0, -0.48))
        return c
    _cylinder(c, "Pit earth ring", (0.0, 0.0, 0.16), 1.48, 0.3, m["soil"], vertices=14)
    _cylinder(c, "Pit cavity", (0.0, 0.0, 0.27), 1.04, 0.16, m["charcoal"], vertices=14)
    for index in range(10):
        angle = index * 2.0 * pi / 10.0
        radius = 0.5 + (index % 2) * 0.34
        _cone(c, f"Pit spike {index}", (radius * cos(angle), radius * sin(angle), 0.72), 0.11, 0.0, 1.1, m["bone"], vertices=7)
    _cube(c, "Pit camouflage slat A", (0.0, 0.0, 0.48), (1.25, 0.08, 0.06), m["timber"], rotation=(0.0, 0.0, 0.48))
    _cube(c, "Pit camouflage slat B", (0.0, 0.0, 0.5), (1.2, 0.08, 0.06), m["timber"], rotation=(0.0, 0.0, -0.52))
    return c


def _build_razor_snare(stage: bpy.types.Scene, m: dict[str, bpy.types.Material]) -> bpy.types.Collection:
    """Build a reusable low-profile jaw trap with a unique rectangular silhouette."""
    c = _collection(stage, "T1RazorSnare")
    _cylinder(c, "Snare hex foundation", (0.0, 0.0, 0.14), 1.42, 0.24, m["charcoal"], vertices=6)
    for side in (-1.0, 1.0):
        jaw_y = side * 0.72
        _cube(
            c,
            f"Snare jaw rail {side}",
            (0.0, jaw_y, 0.42),
            (1.18, 0.13, 0.18),
            m["steel"],
            rotation=(0.0, 0.0, side * 0.08),
        )
        for tooth_index, tooth_x in enumerate((-0.92, -0.46, 0.0, 0.46, 0.92)):
            _cone(
                c,
                f"Snare inward tooth {side} {tooth_index}",
                (tooth_x, jaw_y - side * 0.26, 0.72),
                0.14,
                0.025,
                0.68,
                m["bone"],
                vertices=4,
                rotation_z=pi * 0.25,
            )
    _cube(c, "Snare cross brace A", (0.0, 0.0, 0.38), (1.05, 0.10, 0.09), m["rust"], rotation=(0.0, 0.0, 0.65))
    _cube(c, "Snare cross brace B", (0.0, 0.0, 0.40), (1.05, 0.10, 0.09), m["rust"], rotation=(0.0, 0.0, -0.65))
    _cylinder(c, "Snare trigger plate", (0.0, 0.0, 0.56), 0.43, 0.16, m["violet"], vertices=4)
    _sphere(c, "Snare armed lamp", (0.0, -0.12, 0.78), (0.16, 0.16, 0.12), m["violet"])
    return c


def _configure_stage() -> tuple[
    bpy.types.Scene,
    bpy.types.Object,
    bpy.types.FreestyleLineSet,
]:
    stage = bpy.data.scenes.get(STAGE_NAME) or bpy.data.scenes.new(STAGE_NAME)
    for obj in list(stage.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for child in list(stage.collection.children):
        stage.collection.children.unlink(child)
        bpy.data.collections.remove(child)
    bpy.context.window.scene = stage
    stage.render.engine = "BLENDER_EEVEE"
    stage.render.resolution_x = 320
    stage.render.resolution_y = 320
    stage.render.resolution_percentage = 100
    stage.render.image_settings.file_format = "PNG"
    stage.render.image_settings.color_mode = "RGBA"
    stage.render.image_settings.color_depth = "8"
    stage.render.film_transparent = True
    stage.render.use_freestyle = True
    stage.render.line_thickness = 1.3
    try:
        stage.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    world = bpy.data.worlds.get("BESPREN_STRUCTURE_WORLD") or bpy.data.worlds.new("BESPREN_STRUCTURE_WORLD")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.018, 0.024, 0.022, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.28
    stage.world = world
    target = Vector((0.0, 0.0, 0.8))
    camera_data = bpy.data.cameras.new("BSP Structure Camera")
    camera = bpy.data.objects.new("BSP Structure Camera", camera_data)
    stage.collection.objects.link(camera)
    camera.location = (4.8, -7.4, 8.4)
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 5.8
    stage.camera = camera
    for name, location, energy, color, size in (
        ("BSP Warm Key", (-4.5, -5.5, 9.0), 1050, (1.0, 0.62, 0.26), 4.0),
        ("BSP Cool Rim", (5.0, 2.0, 7.0), COOL_RIM_ENERGY, (0.16, 0.58, 0.62), 3.4),
        ("BSP Soft Fill", (0.0, 5.5, 6.0), 540, (0.42, 0.46, 0.41), 5.5),
    ):
        light_data = bpy.data.lights.new(name, "AREA")
        light_data.energy = energy
        light_data.color = color
        light_data.shape = "DISK"
        light_data.size = size
        light = bpy.data.objects.new(name, light_data)
        stage.collection.objects.link(light)
        light.location = location
        light.rotation_euler = (target - light.location).to_track_quat("-Z", "Y").to_euler()
    line_sets = stage.view_layers[0].freestyle_settings.linesets
    line_set = line_sets[0] if len(line_sets) > 0 else line_sets.new("BSP Structure Outline")
    line_set.linestyle.color = (0.006, 0.009, 0.008)
    line_set.linestyle.thickness = OUTLINE_THICKNESS_DEFAULT
    return stage, camera, line_set


def _staging_output_dir() -> tuple[Path, bool]:
    staging = os.environ.get(STAGING_MODE_ENV, "").strip().lower() == STAGING_MODE_VALUE
    requested_output = os.environ.get(STAGING_OUTPUT_ENV, "").strip()
    if not staging:
        if requested_output:
            raise ValueError(f"{STAGING_OUTPUT_ENV} requires {STAGING_MODE_ENV}={STAGING_MODE_VALUE}")
        return OUTPUT_DIR, False
    if not requested_output:
        raise ValueError(f"{STAGING_MODE_ENV}={STAGING_MODE_VALUE} requires {STAGING_OUTPUT_ENV}")
    candidate_output = Path(requested_output).expanduser().resolve()
    build_root = (PROJECT_ROOT / "build").resolve()
    if candidate_output != build_root and build_root not in candidate_output.parents:
        raise ValueError("Staging output must stay under the project build directory")
    return candidate_output, True


def generate() -> dict[str, str]:
    output_dir, staging = _staging_output_dir()
    output_dir.mkdir(parents=True, exist_ok=True)
    stage, camera, line_set = _configure_stage()
    materials = {
        "charcoal": _material("BSP_Structure_Charcoal", (0.035, 0.048, 0.045), 0.15, 0.78),
        "steel": _material("BSP_Structure_Steel", (0.27, 0.31, 0.29), 0.68, 0.38),
        "rust": _material("BSP_Structure_Rust", (0.43, 0.17, 0.07), 0.34, 0.72),
        "timber": _material("BSP_Structure_Timber", (0.29, 0.16, 0.07), 0.0, 0.86),
        # Camp-only, and retuned toward the warm half of the palette. The old
        # canvas was a cool olive, which under the shared rig's teal rim painted
        # the largest surface in the refuge in Shane's identity colour - the one
        # thing CLAUDE.md 2 says the refuge must never be. The sandbags dropped in
        # value for the opposite reason: at 0.32 they were out-valuing the fire and
        # reading as a scatter of pale eggs around a dim centre.
        "canvas": _material("BSP_Camp_Canvas", (0.265, 0.200, 0.118), 0.0, 0.92),
        "sandbag": _material("BSP_Camp_Sandbag", (0.165, 0.148, 0.098), 0.0, 0.95),
        # The camp needs its own ground because "soil" is shared with the Slowing
        # Pit, which wants a wet dug-earth read rather than a trodden camp floor.
        "camp_earth": _material("BSP_Camp_Earth", (0.072, 0.058, 0.038), 0.0, 1.0),
        "camp_earth_dark": _material("BSP_Camp_EarthDark", (0.034, 0.028, 0.019), 0.0, 1.0),
        "camp_stone": _material("BSP_Camp_Stone", (0.115, 0.125, 0.120), 0.0, 0.92),
        "ember": _material("BSP_Camp_Ember", (0.62, 0.20, 0.035), 0.0, 0.55, (1.0, 0.26, 0.02), 2.6),
        # Strength 9 read as a white cone rather than as fire: AgX rolls a bright
        # emitter off toward the film white point, so the more energy the flame
        # got the less orange it was. The saturation has to come from a low-ish
        # strength on a deeply saturated colour, and the light the fire casts on
        # the camp comes from the point lamp beside it rather than from this mesh.
        "flame": _material("BSP_Camp_Flame", (0.95, 0.34, 0.05), 0.0, 0.35, (1.0, 0.30, 0.035), 1.45),
        "soil": _material("BSP_Structure_Soil", (0.13, 0.105, 0.065), 0.0, 1.0),
        "bone": _material("BSP_Structure_Bone", (0.62, 0.60, 0.50), 0.0, 0.86),
        "copper": _material("BSP_Structure_Copper", (0.42, 0.24, 0.10), 0.64, 0.32),
        "amber": _material("BSP_Structure_Amber", (0.85, 0.43, 0.075), 0.35, 0.32, (1.0, 0.32, 0.025), 3.2),
        "cyan": _material("BSP_Structure_Cyan", (0.10, 0.55, 0.58), 0.42, 0.3, (0.04, 0.76, 0.8), 3.0),
        "teal": _material("BSP_Structure_Teal", (0.12, 0.34, 0.30), 0.28, 0.48),
        "teal_glow": _material("BSP_Structure_TealGlow", (0.24, 0.62, 0.52), 0.25, 0.32, (0.12, 0.78, 0.62), 2.5),
        "chemical": _material("BSP_Structure_Chemical", (0.34, 0.49, 0.19), 0.18, 0.54),
        "chemical_glow": _material("BSP_Structure_ChemicalGlow", (0.48, 0.70, 0.22), 0.1, 0.4, (0.5, 0.82, 0.16), 2.3),
        "red": _material("BSP_Structure_Red", (0.55, 0.12, 0.06), 0.35, 0.36, (0.85, 0.055, 0.02), 2.6),
        "violet": _material("BSP_Structure_Violet", (0.47, 0.16, 0.62), 0.48, 0.3, (0.72, 0.18, 1.0), 3.0),
    }
    assets = (
        (_build_camp(stage, materials), "base_camp_topdown.png", 9.2, OUTLINE_THICKNESS_CAMP),
        (_build_kinetic(stage, materials, staging), "structure_t1_kinetic.png", 5.4, OUTLINE_THICKNESS_DEFAULT),
        (_build_chemical(stage, materials, staging), "structure_t1_chemical.png", 5.4, OUTLINE_THICKNESS_DEFAULT),
        (_build_electric(stage, materials, staging), "structure_t1_electric.png", 5.4, OUTLINE_THICKNESS_DEFAULT),
        (_build_support(stage, materials), "structure_t1_support.png", 5.4, OUTLINE_THICKNESS_DEFAULT),
        (_build_barricade(stage, materials), "structure_t1_barricade.png", 6.8, OUTLINE_THICKNESS_DEFAULT),
        (_build_landmine(stage, materials, staging), "structure_t1_landmine.png", 4.8, OUTLINE_THICKNESS_DEFAULT),
        (_build_slowing_pit(stage, materials, staging), "structure_t1_slowing_pit.png", 4.8, OUTLINE_THICKNESS_DEFAULT),
        (_build_razor_snare(stage, materials), "structure_t1_razor_snare.png", 4.8, OUTLINE_THICKNESS_DEFAULT),
    )
    requested_filename = os.environ.get("BESPREN_STRUCTURE_RENDER_ONLY", "").strip()
    render_assets = (
        tuple(asset for asset in assets if asset[1] == requested_filename)
        if requested_filename
        else assets
    )
    if requested_filename and not render_assets:
        raise ValueError(f"Unknown BESPREN_STRUCTURE_RENDER_ONLY target: {requested_filename}")
    outputs: dict[str, str] = {}
    for active_collection, filename, ortho_scale, outline_thickness in render_assets:
        for collection, _, _, _ in assets:
            collection.hide_render = collection != active_collection
        camera.data.ortho_scale = ortho_scale
        line_set.linestyle.thickness = outline_thickness
        target = output_dir / filename
        stage.render.filepath = str(target)
        bpy.ops.render.render(write_still=True)
        outputs[active_collection.name] = str(target)
    for collection, _, _, _ in assets:
        collection.hide_render = False
    return outputs


if __name__ == "__main__":
    print(generate())
