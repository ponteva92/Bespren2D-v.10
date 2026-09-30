"""Bake curated local GLBs into a coherent Bespren 2D environment family.

Run this script only from ``bespren_local_environment_workshop.blend``.  The
shipping game consumes the transparent PNG renders, never these 3D sources.
Every sprite uses the same orthographic camera, three-point lighting, AgX
grade, restrained petroleum/rust/patina materials and Freestyle silhouette
treatment. Grounding shadows are authored once at runtime so local and Poly
Haven props share the same soft opacity and footprint. The imports are deleted after each render so
the workshop remains small and every output is reproducible from Addons.
"""

from __future__ import annotations

from dataclasses import dataclass
import hashlib
import math
from pathlib import Path
from typing import Iterable

import bpy
from mathutils import Vector


PROJECT_ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = PROJECT_ROOT / "assets" / "2d" / "environment" / "local_baked"
WORKSHOP_PATH = (
    PROJECT_ROOT / "tools" / "art" / "blender" /
    "bespren_local_environment_workshop.blend"
)
STAGE_PREFIX = "BSP_LOCAL_STAGE_"
FRAME_SIZE = 384

KENNEY = (
    PROJECT_ROOT / "Addons" / "Starter-Kit-City-Builder-main" /
    "Starter-Kit-City-Builder-main" / "models"
)
ATOMIC = (
    PROJECT_ROOT / "Addons" / "[AR] Post-Apocalyptic - Starter Pack" /
    "3. Models" / "gltf"
)
INTO_THE_WILD = (
    PROJECT_ROOT / "Addons" / "[FREE] Into The Wild" / "FREE" / "gltf"
)
GAS_STATION = (
    PROJECT_ROOT / "Addons" / "[FREE] Gas Station" / "FREE" / "gltf"
)
PHARMACY = (
    PROJECT_ROOT / "Addons" / "[FREE] Pharmacy" / "FREE" / "gltf"
)


@dataclass(frozen=True)
class Component:
    source: Path
    location: tuple[float, float, float] = (0.0, 0.0, 0.0)
    rotation_z: float = 0.0
    target_size: float = 3.4
    palette: str = "petroleum"


@dataclass(frozen=True)
class AssetBake:
    key: str
    output_name: str
    components: tuple[Component, ...]
    framing_scale: float = 1.24
    exposure_bias: float = 0.0


def k(name: str, *args: object, **kwargs: object) -> Component:
    return Component(KENNEY / name, *args, **kwargs)


def ar(name: str, *args: object, **kwargs: object) -> Component:
    return Component(ATOMIC / name, *args, **kwargs)


def wild(name: str, *args: object, **kwargs: object) -> Component:
    return Component(INTO_THE_WILD / name, *args, **kwargs)


def gas(name: str, *args: object, **kwargs: object) -> Component:
    return Component(GAS_STATION / name, *args, **kwargs)


def pharmacy(name: str, *args: object, **kwargs: object) -> Component:
    return Component(PHARMACY / name, *args, **kwargs)


ASSETS: tuple[AssetBake, ...] = (
    AssetBake("city_ruin_a", "local_city_ruin_a.png", (
        k("building-small-a.glb", palette="petroleum"),
        ar("metal_board_1.glb", (0.72, -0.68, 0.48), 12.0, 0.82, "rust"),
    ), exposure_bias=0.72),
    AssetBake("city_ruin_b", "local_city_ruin_b.png", (
        k("building-small-b.glb", rotation_z=-8.0, palette="concrete"),
        ar("wall_1_hole.glb", (-0.72, 0.35, 0.02), 88.0, 1.25, "patina"),
    )),
    AssetBake("city_ruin_c", "local_city_ruin_c.png", (
        k("building-small-c.glb", rotation_z=7.0, palette="patina"),
        ar("metal_board_2.glb", (0.82, -0.52, 0.52), -8.0, 0.74, "rust"),
    )),
    AssetBake("city_ruin_d", "local_city_ruin_d.png", (
        k("building-small-d.glb", rotation_z=-4.0, palette="oxide"),
        ar("wall_1_door_boarded.glb", (-0.54, -0.48, 0.01), 2.0, 1.18, "wood"),
    ), exposure_bias=0.72),
    AssetBake("mall_shell", "local_mall_shell.png", (
        k("building-garage.glb", rotation_z=4.0, target_size=3.8, palette="concrete"),
        ar("wall_concrete_metal.glb", (-0.95, -0.63, 0.04), 1.0, 1.68, "patina"),
        ar("wall_1_window_2.glb", (1.12, 0.48, 0.04), 90.0, 1.48, "petroleum"),
    ), 1.30),
    AssetBake("industrial_shell", "local_industrial_shell.png", (
        k("building-garage.glb", rotation_z=176.0, target_size=3.7, palette="oxide"),
        ar("wall_spiked.glb", (-0.92, 0.62, 0.03), 178.0, 1.62, "rust"),
        ar("wall_1_brick.glb", (1.02, -0.52, 0.02), 88.0, 1.46, "concrete"),
    ), 1.30),
    AssetBake("village_west_house", "local_village_west_house.png", (
        k("building-small-b.glb", rotation_z=-5.0, target_size=3.45, palette="wood"),
        ar("wooden_wall.glb", (-0.88, -0.62, 0.01), 4.0, 1.28, "wood"),
        ar("wooden_spike_barricade.glb", (0.92, 0.58, 0.01), -18.0, 0.82, "rust"),
    ), 1.28),
    AssetBake("village_east_house", "local_village_east_house.png", (
        k("building-small-c.glb", rotation_z=9.0, target_size=3.4, palette="patina"),
        ar("wall_metal_1.glb", (0.86, -0.58, 0.03), 8.0, 1.22, "oxide"),
        ar("metal_board_3.glb", (-0.76, 0.58, 0.54), 92.0, 0.74, "petroleum"),
    ), 1.28),
    AssetBake("vehicle_wreck", "local_vehicle_wreck.png", (
        ar("car.glb", rotation_z=-12.0, target_size=3.25, palette="oxide"),
        ar("tire.glb", (1.28, -0.54, 0.02), 18.0, 0.62, "rubber"),
    ), 1.20),
    AssetBake("wood_barricade", "local_wood_barricade.png", (
        ar("wooden_spike_barricade.glb", rotation_z=-7.0, target_size=2.85, palette="wood"),
        ar("wooden_wall.glb", (0.76, 0.48, 0.02), 84.0, 1.32, "rust"),
    ), 1.18),
    AssetBake("utility_pole", "local_utility_pole.png", (
        ar("electric_pole_1.glb", rotation_z=3.0, target_size=4.4, palette="petroleum"),
        ar("barrel.glb", (0.78, -0.42, 0.02), -5.0, 0.68, "oxide"),
    ), 1.30, 0.88),
    AssetBake("roadside_salvage", "local_roadside_salvage.png", (
        ar("metal_board_3.glb", (0.0, 0.0, 0.52), -3.0, 2.25, "patina"),
        ar("barrel.glb", (-0.78, -0.36, 0.02), 4.0, 0.74, "oxide"),
        ar("box_1.glb", (0.76, 0.34, 0.02), -12.0, 0.62, "wood"),
        ar("wheel.glb", (0.88, -0.50, 0.02), 18.0, 0.56, "rubber"),
    ), 1.22),
    AssetBake("roadside_barrier", "local_roadside_barrier.png", (
        ar("wall_concrete_metal.glb", rotation_z=-4.0, target_size=2.65, palette="concrete"),
        ar("barrel.glb", (0.92, -0.38, 0.02), 8.0, 0.68, "rust"),
        ar("metal_board_1.glb", (-0.72, 0.36, 0.34), 86.0, 0.72, "patina"),
    ), 1.18),
    AssetBake("camp_bedding", "local_camp_bedding.png", (
        wild("sleeping_bag.glb", rotation_z=-8.0, target_size=3.05, palette="fabric"),
        wild("sharpened_stick.glb", (1.08, 0.42, 0.03), 72.0, 1.12, "wood"),
        wild("bush_1.glb", (-1.02, 0.54, 0.02), -12.0, 1.08, "foliage"),
    ), 1.18, 0.18),
    AssetBake("camp_supply_cache", "local_camp_supply_cache.png", (
        gas("pallet_cluster_1.glb", rotation_z=-5.0, target_size=2.75, palette="wood"),
        gas("jerry_can_with_nozzle.glb", (-0.88, -0.48, 0.04), 8.0, 0.88, "oxide"),
        gas("jerry_can_with_nozzle.glb", (0.82, -0.28, 0.04), -14.0, 0.72, "petroleum"),
    ), 1.18, 0.20),
    AssetBake("camp_medical_cache", "local_camp_medical_cache.png", (
        pharmacy("medpack_1.glb", rotation_z=5.0, target_size=2.20, palette="medical"),
        wild("sharpened_stick.glb", (-0.92, 0.50, 0.03), -58.0, 1.06, "wood"),
        wild("bush_1.glb", (0.92, 0.46, 0.02), 14.0, 1.04, "foliage"),
    ), 1.18, 0.26),
)


PALETTES: dict[str, tuple[tuple[float, float, float, float], ...]] = {
    "petroleum": ((0.075, 0.115, 0.120, 1), (0.16, 0.235, 0.230, 1), (0.37, 0.42, 0.35, 1)),
    "concrete": ((0.20, 0.215, 0.20, 1), (0.39, 0.40, 0.36, 1), (0.56, 0.52, 0.43, 1)),
    "patina": ((0.075, 0.20, 0.19, 1), (0.20, 0.40, 0.36, 1), (0.48, 0.50, 0.34, 1)),
    "oxide": ((0.17, 0.10, 0.075, 1), (0.43, 0.22, 0.12, 1), (0.66, 0.38, 0.17, 1)),
    "rust": ((0.13, 0.075, 0.05, 1), (0.39, 0.16, 0.07, 1), (0.63, 0.31, 0.11, 1)),
    "wood": ((0.12, 0.075, 0.045, 1), (0.34, 0.20, 0.095, 1), (0.54, 0.38, 0.18, 1)),
    "rubber": ((0.018, 0.025, 0.024, 1), (0.055, 0.07, 0.065, 1), (0.15, 0.17, 0.15, 1)),
    "fabric": ((0.11, 0.15, 0.12, 1), (0.28, 0.34, 0.24, 1), (0.50, 0.45, 0.26, 1)),
    "foliage": ((0.07, 0.16, 0.11, 1), (0.19, 0.34, 0.20, 1), (0.39, 0.48, 0.25, 1)),
    "medical": ((0.30, 0.34, 0.31, 1), (0.68, 0.68, 0.56, 1), (0.58, 0.18, 0.12, 1)),
}


def _verify_sources() -> None:
    missing = sorted({str(c.source) for a in ASSETS for c in a.components if not c.source.is_file()})
    if missing:
        raise FileNotFoundError(f"Missing local GLB source files: {missing}")


def _clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.curves, bpy.data.cameras, bpy.data.lights):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def _configure_stage() -> tuple[bpy.types.Scene, bpy.types.Object, list[bpy.types.Object]]:
    scene = bpy.context.scene
    scene.name = "BESPREN_LOCAL_ENVIRONMENT_WORKSHOP"
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = FRAME_SIZE
    scene.render.resolution_y = FRAME_SIZE
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.film_transparent = True
    scene.render.use_freestyle = True
    scene.render.line_thickness = 1.08
    scene.view_settings.exposure = 1.42
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except (TypeError, ValueError):
        pass

    world = bpy.data.worlds.get(f"{STAGE_PREFIX}WORLD") or bpy.data.worlds.new(f"{STAGE_PREFIX}WORLD")
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    if background:
        background.inputs["Color"].default_value = (0.0238, 0.0254, 0.0271, 1.0)
        background.inputs["Strength"].default_value = 0.48
    scene.world = world

    camera_data = bpy.data.cameras.new(f"{STAGE_PREFIX}CAMERA_DATA")
    camera = bpy.data.objects.new(f"{STAGE_PREFIX}CAMERA", camera_data)
    scene.collection.objects.link(camera)
    camera.data.type = "ORTHO"
    scene.camera = camera

    lights: list[bpy.types.Object] = []
    specs = (
        ("WARM_KEY", (-5.4, -6.8, 10.2), 1180.0, (1.0, 0.58, 0.28), 5.5),
        # The rim is a sky bounce, and both its chroma and its hue are load-bearing.
        # It was authored at (0.18, 0.52, 0.58): HSV saturation 0.69 at hue 189, which
        # sits between the two hues section 8 has already spoken for - Copper patina
        # #1C8270 at 168 and Shane's #31E6E6 at 180. Any face turned toward the rim
        # and away from the warm key was therefore lit by an almost pure teal spectrum
        # and landed on a reserved anchor: measured across the shipped bakes the
        # district family ran to a median 16.6 percent of opaque pixels in that band
        # and the local family to 44 percent on one building, which in the game frame
        # reads as cyan-painted concrete standing beside correctly rust-brown concrete.
        # Desaturating to 0.28 and moving to hue 212 puts the rim in a hue the palette
        # has not reserved, so a rim-only face reads as cool grey rather than as paint;
        # the energy is scaled to hold the previous luminance, making this a change of
        # colour and not of exposure - but that algebra is linear and AgX is neither.
        # It held on the district and environment families, whose mean alpha-weighted
        # luma moved +0.42 and +0.14 percent, and under-shot here by one to two percent
        # on the frames whose mass is shadow rather than key, because a desaturated
        # light of equal linear luminance tonemaps slightly darker per channel than the
        # saturated one it replaced. That took city_ruin_d from 50.88 to 49.69 and broke
        # this family's own 50 luma floor, so the energy was re-derived by measurement
        # rather than by algebra: at 915 every frame is back at or above its pre-fix
        # luma, the floor clears at 51.06, and the median teal fraction still falls from
        # 5.06 to 0.51 percent. The world background above is moved the same way and for
        # the same reason - it was the shadow half of the same defect, sitting at hue 186
        # (local) and 163 (district and environment, on the patina hue), and it accounted
        # for the residue the rim left behind on the darkest frames.
        # What survives is not lit teal at all: it is the two hues section 8 authored.
        # `patina` (hue 168) is assigned by name to city_ruin_c and village_east_house,
        # `petroleum` (hue 176) to city_ruin_a and utility_pole, and the district shares
        # one flat `_roof_material` at hue 166. Copper patina #1C8270 is section 8's
        # weathered-technology accent and petroleum green is its stated value base. The
        # detector keys on blue over red with green over red, which is precisely what
        # those two anchors are, so it cannot separate them from the defect it was built
        # to find. Warming them toward concrete would delete an authored anchor to
        # satisfy a metric aimed at a lighting bug.
        ("COOL_RIM", (6.2, 3.0, 8.3), 915.0, (0.403, 0.476, 0.560), 4.6),
        ("SOFT_FILL", (-0.4, 6.6, 7.6), 780.0, (0.50, 0.54, 0.48), 6.6),
    )
    for suffix, offset, energy, color, size in specs:
        data = bpy.data.lights.new(f"{STAGE_PREFIX}{suffix}_DATA", "AREA")
        data.energy, data.color, data.shape, data.size = energy, color, "DISK", size
        light = bpy.data.objects.new(f"{STAGE_PREFIX}{suffix}", data)
        scene.collection.objects.link(light)
        light["bespren_offset"] = offset
        lights.append(light)

    line_sets = scene.view_layers[0].freestyle_settings.linesets
    line_set = line_sets[0] if len(line_sets) else line_sets.new("Bespren Local Silhouette")
    line_set.linestyle.color = (0.008, 0.014, 0.014)
    line_set.linestyle.thickness = 1.05
    line_set.select_silhouette = True
    line_set.select_border = True
    line_set.select_contour = True
    line_set.select_crease = False
    line_set.select_material_boundary = False
    return scene, camera, lights


def _style_material(role: str, seed: str, world_size: float = 1.2) -> bpy.types.Material:
    digest = hashlib.sha256(f"{role}:{seed}".encode()).digest()
    colors = PALETTES[role]
    first = colors[digest[0] % len(colors)]
    second = colors[(digest[0] + 1) % len(colors)]
    name = f"BSP_LOCAL_{role}_{digest.hex()[:8]}"
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = first
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    noise = nodes.new("ShaderNodeTexNoise")
    ramp = nodes.new("ShaderNodeValToRGB")
    bump_noise = nodes.new("ShaderNodeTexNoise")
    bump = nodes.new("ShaderNodeBump")
    texcoord = nodes.new("ShaderNodeTexCoord")
    # `Generated` texture coordinates are normalised to each object's own bounding box,
    # so a fixed noise Scale places a fixed number of blobs across the object whatever
    # its size - which makes texture frequency fall as the asset grows. At Scale 2.7-4.1
    # a 0.7m barrel received about five cycles per metre and a 3.4m building shell about
    # one, and that is the whole of why the shells measured 5.5-6.8 interior local std
    # against 10-14 on the small props: three blobs smeared across an entire wall, with
    # nothing else on it, since a shell has none of the geometric relief a barrel or a
    # wheel carries. Multiplying the frequency by the component's own world size gives a
    # constant cycles-per-metre, so the grain belongs to the material rather than to how
    # large the asset happens to be. Every component in a frame then shares one grain in
    # pixels, since the camera frames the whole assembly at a single metres-per-pixel,
    # and every frame shares one grain in world units, since each is drawn in world at a
    # size proportional to the assembly it was framed on. Components at or under 1.2 are
    # multiplied by exactly one and are therefore bit-identical to before, which is most
    # of the dressing: the roster's shells sit at 3.4 to 4.4 and its scatter at 0.5 to 1.5.
    frequency_scale = max(1.0, world_size / 1.2)
    noise.inputs["Scale"].default_value = (2.7 + (digest[1] % 15) * 0.10) * frequency_scale
    # Detail and Roughness are deliberately left where they are. Raising them to 5.0 and
    # 0.86 to chase fine grain was measured and reverted: every frame in the family moved
    # by at most 0.005 of its normalised local contrast, and most moved down. The base
    # octave here already lands near 10 cycles across a subject that spans some 300 pixels,
    # so Detail 3.4 puts the fourth octave at roughly two pixels and everything above it
    # under the sample grid, where the render averages it away. Octave content above
    # Nyquist costs evaluation time and returns nothing, and the usable band for grain
    # that survives to the atlas is about 2 to 100 cycles across the frame.
    noise.inputs["Detail"].default_value = 3.4
    noise.inputs["Roughness"].default_value = 0.72
    # The stops are tight rather than spread because what separates these procedural
    # surfaces from the photoscanned families is edges, not amplitude. Perlin noise is
    # smooth by construction, so a wide ramp turns it into a gradient that a 7px window
    # reads as almost nothing however far apart the two colours are; real weathering is
    # patchy, and a stain, a scorch or a run of damp has a boundary. Narrowing the band
    # from 0.53 to 0.22 multiplies the transfer gain across it by about 2.4 while leaving
    # both endpoint colours exactly where they were, so the surface gains boundaries
    # without gaining a value range it was not authored to have.
    ramp.color_ramp.elements[0].position = 0.40
    ramp.color_ramp.elements[0].color = first
    ramp.color_ramp.elements[1].position = 0.62
    ramp.color_ramp.elements[1].color = second
    bump_noise.inputs["Scale"].default_value = 18.0 * frequency_scale
    bump_noise.inputs["Detail"].default_value = 2.2
    bump.inputs["Strength"].default_value = 0.30 if role != "concrete" else 0.40
    bump.inputs["Distance"].default_value = 0.08
    shader.inputs["Roughness"].default_value = 0.64 if role not in {"rubber", "wood"} else 0.78
    shader.inputs["Metallic"].default_value = 0.24 if role in {"petroleum", "patina", "oxide", "rust"} else 0.02
    shader.inputs["Specular IOR Level"].default_value = 0.28
    links.new(texcoord.outputs["Generated"], noise.inputs["Vector"])
    links.new(texcoord.outputs["Generated"], bump_noise.inputs["Vector"])
    links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], shader.inputs["Base Color"])
    links.new(bump_noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], shader.inputs["Normal"])
    links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    return material


def _bounds(objects: Iterable[bpy.types.Object]) -> tuple[Vector, Vector]:
    minimum = Vector((math.inf, math.inf, math.inf))
    maximum = Vector((-math.inf, -math.inf, -math.inf))
    found = False
    for obj in objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            point = obj.matrix_world @ Vector(corner)
            for axis in range(3):
                minimum[axis] = min(minimum[axis], point[axis])
                maximum[axis] = max(maximum[axis], point[axis])
            found = True
    if not found:
        raise RuntimeError("Imported component contains no mesh bounds")
    return minimum, maximum


def _import_component(component: Component, index: int) -> list[bpy.types.Object]:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(component.source))
    imported = [obj for obj in bpy.data.objects if obj not in before]
    meshes = [obj for obj in imported if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh imported from {component.source}")
    root = bpy.data.objects.new(f"BSP_LOCAL_COMPONENT_{index:02d}", None)
    bpy.context.scene.collection.objects.link(root)
    top_level = [obj for obj in imported if obj.parent is None]
    for obj in top_level:
        obj.parent = root
    bpy.context.view_layer.update()
    minimum, maximum = _bounds(meshes)
    span = maximum - minimum
    scale = component.target_size / max(span.x, span.y, span.z, 0.001)
    root.scale = (scale, scale, scale)
    root.rotation_euler.z = math.radians(component.rotation_z)
    bpy.context.view_layer.update()
    minimum, maximum = _bounds(meshes)
    center = (minimum + maximum) * 0.5
    root.location += Vector(component.location) - Vector((center.x, center.y, minimum.z))
    for mesh_index, obj in enumerate(meshes):
        obj.name = f"BSP_LOCAL_MESH_{index:02d}_{mesh_index:02d}"
        material = _style_material(component.palette, f"{component.source.name}:{mesh_index}", component.target_size)
        obj.data.materials.clear()
        obj.data.materials.append(material)
    bpy.context.view_layer.update()
    return imported + [root]


def _frame(camera: bpy.types.Object, lights: Iterable[bpy.types.Object], objects: list[bpy.types.Object], framing_scale: float) -> None:
    minimum, maximum = _bounds(objects)
    dimensions = maximum - minimum
    target = Vector(((minimum.x + maximum.x) * 0.5, (minimum.y + maximum.y) * 0.5, minimum.z + dimensions.z * 0.43))
    direction = Vector((5.0, -7.8, 8.6)).normalized()
    projected = max(dimensions.x, dimensions.y * 0.84 + dimensions.z * 0.60, dimensions.z * 1.10, 0.75)
    camera.data.ortho_scale = projected * framing_scale
    camera.location = target + direction * max(projected * 4.2, 8.0)
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    for light in lights:
        offset = Vector(light["bespren_offset"])
        light.location = target + offset * max(projected * 0.36, 0.72)
        light.rotation_euler = (target - light.location).to_track_quat("-Z", "Y").to_euler()
        light.data.size = max(light.data.size, projected * 0.78)


def _delete_asset_objects(objects: Iterable[bpy.types.Object]) -> None:
    for obj in list(dict.fromkeys(objects)):
        if obj.name in bpy.data.objects:
            bpy.data.objects.remove(obj, do_unlink=True)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(block):
            if item.users == 0 and not item.name.startswith(STAGE_PREFIX):
                block.remove(item)


def generate(asset_keys: Iterable[str] | None = None) -> dict[str, str]:
    current = Path(bpy.data.filepath).resolve() if bpy.data.filepath else None
    if current != WORKSHOP_PATH.resolve():
        raise RuntimeError(f"Open dedicated workshop first: {WORKSHOP_PATH}")
    _verify_sources()
    _clear_scene()
    scene, camera, lights = _configure_stage()
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    requested = set(asset_keys) if asset_keys else {asset.key for asset in ASSETS}
    unknown = requested.difference(asset.key for asset in ASSETS)
    if unknown:
        raise KeyError(f"Unknown local bake keys: {sorted(unknown)}")
    outputs: dict[str, str] = {}
    for asset in ASSETS:
        if asset.key not in requested:
            continue
        imported: list[bpy.types.Object] = []
        meshes: list[bpy.types.Object] = []
        for index, component in enumerate(asset.components):
            imported.extend(_import_component(component, index))
        meshes = [obj for obj in imported if obj.type == "MESH"]
        _frame(camera, lights, meshes, asset.framing_scale)
        target = OUTPUT_DIR / asset.output_name
        scene.render.filepath = str(target)
        scene.view_settings.exposure = 1.42 + asset.exposure_bias
        scene["bespren_active_asset"] = asset.key
        scene["bespren_source_files"] = ";".join(str(c.source.relative_to(PROJECT_ROOT)) for c in asset.components)
        bpy.ops.render.render(write_still=True)
        outputs[asset.key] = str(target)
        _delete_asset_objects(imported)
    scene["bespren_active_asset"] = ""
    scene["bespren_source_files"] = ""
    scene["bespren_render_count"] = len(outputs)
    scene["bespren_render_policy"] = "orthographic_rgba_freestyle_agx_mobile_midtones_runtime_grounding"
    bpy.ops.wm.save_as_mainfile(filepath=str(WORKSHOP_PATH))
    return outputs


if __name__ == "__main__":
    print(generate())
