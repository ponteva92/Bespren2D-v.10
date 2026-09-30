"""Generate Bespren's Heikki and Shane top-down presentation sprites in Blender.

Run through Blender MCP or Blender's scripting workspace. The script creates a
dedicated scene and never mutates the user's default scene.
"""

from pathlib import Path
import bpy
import math
from mathutils import Matrix, Vector


PROJECT_ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = PROJECT_ROOT / "assets" / "2d" / "characters"
STAGE_NAME = "BESPREN_SPRITE_STAGE"

# The shared rim is the only light that carries a hue both survivors must not share.
# Held at Shane's Cyan it painted a third of Heikki's delivered chroma in Shane's
# identity family; a desaturated cool grey keeps the warm/cool modelling contrast in
# value while leaving the chroma to Gold. Shane's colour is unchanged.
RIM_COLOR_HEIKKI = (0.58, 0.60, 0.60)
RIM_COLOR_SHANE = (0.10, 0.72, 0.82)


def _material(
    name: str,
    color: tuple[float, float, float],
    metallic: float = 0.0,
    roughness: float = 0.55,
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
    return material


def _activate(collection: bpy.types.Collection) -> None:
    bpy.context.view_layer.active_layer_collection = (
        bpy.context.view_layer.layer_collection.children[collection.name]
    )


def _cube(
    collection: bpy.types.Collection,
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material: bpy.types.Material,
    bevel: float = 0.1,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    _activate(collection)
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    modifier = obj.modifiers.new("Survival edge roll", "BEVEL")
    modifier.width = bevel
    modifier.segments = 2
    obj.data.materials.append(material)
    return obj


def _sphere(
    collection: bpy.types.Collection,
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material: bpy.types.Material,
) -> bpy.types.Object:
    _activate(collection)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    return obj


def _cylinder(
    collection: bpy.types.Collection,
    name: str,
    location: tuple[float, float, float],
    radius: float,
    depth: float,
    material: bpy.types.Material,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    vertices: int = 16,
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
    modifier = obj.modifiers.new("Worn edge", "BEVEL")
    modifier.width = 0.055
    modifier.segments = 2
    obj.data.materials.append(material)
    return obj


def _torus(
    collection: bpy.types.Collection,
    name: str,
    location: tuple[float, float, float],
    material: bpy.types.Material,
) -> bpy.types.Object:
    _activate(collection)
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.53,
        minor_radius=0.085,
        major_segments=24,
        minor_segments=8,
        location=location,
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    return obj


def _build_survivor(
    stage: bpy.types.Scene,
    name: str,
    materials: dict[str, bpy.types.Material],
    accent: bpy.types.Material,
    secondary: bpy.types.Material,
    broad: bool,
) -> bpy.types.Collection:
    collection = bpy.data.collections.new(name)
    stage.collection.children.link(collection)
    shoulder = 0.58 if broad else 0.44
    torso_x = 0.70 if broad else 0.61

    _cylinder(collection, f"{name}_LegL", (-0.27, 0.03, 0.68), 0.22, 1.10, materials["fabric"])
    _cylinder(collection, f"{name}_LegR", (0.27, 0.03, 0.68), 0.22, 1.10, materials["fabric"])
    _cube(collection, f"{name}_BootL", (-0.27, -0.16, 0.23), (0.27, 0.39, 0.20), materials["leather"], 0.08)
    _cube(collection, f"{name}_BootR", (0.27, -0.16, 0.23), (0.27, 0.39, 0.20), materials["leather"], 0.08)
    _cube(collection, f"{name}_Torso", (0, 0, 1.67), (torso_x, 0.42, 0.83), materials["fabric"], 0.15)
    _cube(collection, f"{name}_ArmorPlate", (0, -0.43, 1.72), (torso_x * 0.78, 0.12, 0.56), materials["steel"], 0.08)
    _cube(collection, f"{name}_Backpack", (0, 0.43, 1.72), (torso_x * 0.70, 0.22, 0.68), materials["leather"], 0.10)
    _cylinder(collection, f"{name}_ArmL", (-shoulder - 0.25, 0, 1.59), 0.21, 1.18, materials["fabric"], (0, -0.18, -0.08))
    _cylinder(collection, f"{name}_ArmR", (shoulder + 0.25, 0, 1.59), 0.21, 1.18, materials["fabric"], (0, 0.18, 0.08))
    _sphere(collection, f"{name}_ShoulderL", (-shoulder - 0.16, -0.03, 2.12), ((0.54, 0.46, 0.32) if broad else (0.38, 0.38, 0.28)), accent)
    _sphere(collection, f"{name}_ShoulderR", (shoulder + 0.16, -0.03, 2.12), ((0.54, 0.46, 0.32) if broad else (0.38, 0.38, 0.28)), accent)
    _sphere(collection, f"{name}_Hood", (0, 0.04, 2.68), (0.58, 0.53, 0.64), materials["charcoal"])
    _sphere(collection, f"{name}_Face", (0, -0.39, 2.64), (0.40, 0.18, 0.40), materials["skin"])
    _cube(collection, f"{name}_Respirator", (0, -0.56, 2.53), (0.31, 0.12, 0.18), materials["steel"], 0.07)
    _torus(collection, f"{name}_Collar", (0, 0, 2.25), accent)

    if broad:
        _cube(collection, f"{name}_GoldChestSlash", (0.04, -0.58, 1.91), (0.48, 0.055, 0.08), accent, 0.035, (0, 0, -0.50))
        _cylinder(collection, f"{name}_RustTankL", (-0.84, 0.45, 2.60), 0.17, 1.00, materials["rust"])
        _cylinder(collection, f"{name}_RustTankR", (0.84, 0.45, 2.60), 0.17, 1.00, materials["rust"])
        _cylinder(collection, f"{name}_RustYoke", (0, 0.45, 2.16), 0.10, 1.68, materials["rust"], (0, 1.5708, 0))
        _cube(collection, f"{name}_UtilityPlate", (-0.48, -0.47, 1.50), (0.18, 0.07, 0.25), accent, 0.04)
    else:
        _cube(collection, f"{name}_TealChestCore", (0, -0.59, 1.82), (0.24, 0.07, 0.30), accent, 0.07)
        _cylinder(collection, f"{name}_TechCell", (0.43, 0.59, 1.72), 0.15, 0.94, accent)
        _cube(collection, f"{name}_AsymPauldron", (-0.66, -0.12, 2.16), (0.42, 0.32, 0.13), secondary, 0.08, (0.08, 0, -0.16))
        _cylinder(collection, f"{name}_Antenna", (0.42, 0.54, 2.47), 0.035, 0.90, materials["steel"], (0.18, 0, 0), 10)
        _sphere(collection, f"{name}_AntennaGlow", (0.50, 0.50, 2.90), (0.11, 0.11, 0.11), accent)
    _face_camera(collection, 33.17851165939274)
    return collection


# Props authored against the spine's back face. The turn would bury them, so these
# are rotated back afterwards: they keep the screen position they were authored at
# and ride the survivor's flank instead of disappearing behind the torso.
_FLANK_PROPS = ("TechCell", "Antenna", "AntennaGlow")


def _face_camera(collection: bpy.types.Collection, degrees: float) -> None:
    """Turn a finished body so its shoulder line runs across the screen.

    The bodies are built on world X, but the camera looks in from 33 degrees off
    that axis, and its up vector carries a -0.329 X component. A shoulder pair at
    plus and minus X therefore separates in screen *Y* as well as screen X, which
    projected the shoulder line as a 21 degree diagonal and made "broad" and
    "bilaterally symmetric" anti-correlated. Yawing the body by the camera's own
    azimuth maps body +X onto camera-right and the chest onto the lens.
    """
    turn = Matrix.Rotation(math.radians(degrees), 4, "Z")
    back = Matrix.Rotation(math.radians(-degrees), 4, "Z")
    for obj in collection.objects:
        obj.matrix_world = turn @ obj.matrix_world
        if obj.name.rpartition("_")[2] in _FLANK_PROPS:
            obj.matrix_world = back @ obj.matrix_world


def generate() -> dict[str, str | tuple[int, int]]:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
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
    stage.render.line_thickness = 1.45
    try:
        stage.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass

    world = bpy.data.worlds.get("BESPREN_SPRITE_WORLD") or bpy.data.worlds.new("BESPREN_SPRITE_WORLD")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.018, 0.024, 0.024, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.32
    stage.world = world

    materials = {
        "charcoal": _material("BSP_Charcoal", (0.045, 0.060, 0.060), 0.05, 0.76),
        "fabric": _material("BSP_Fabric", (0.105, 0.125, 0.118), 0.0, 0.9),
        "leather": _material("BSP_Leather", (0.16, 0.085, 0.038), 0.0, 0.78),
        "skin": _material("BSP_Skin", (0.43, 0.235, 0.14), 0.0, 0.66),
        "steel": _material("BSP_Steel", (0.28, 0.32, 0.31), 0.72, 0.34),
        "rust": _material("BSP_Rust", (0.38, 0.089, 0.042), 0.38, 0.72),
    }
    # Accent emission is 0.4 and 0.5, down from 2.4 and 3.0, and the reason is
    # the AgX property CLAUDE.md 9 already records: the view transform
    # desaturates monotonically with brightness, so an emissive accent burns off
    # the identity hue it exists to carry. Measured over the accent surface
    # itself - the pixels the zero-emission bake renders in the anchor's own hue
    # band - 25.6 percent of Heikki's accent and 31.3 percent of Shane's sat
    # above value 0.90, and inside that blown region saturation fell to 56 and
    # 21 percent of the locked `#FFD45A` and `#31E6E6`. Roughly a third of each
    # survivor's identity surface was a white blob with the identity removed,
    # which is the one thing CLAUDE.md 11 asks these accents to hold. At 0.4 and
    # 0.5 the blown share is 1.7 and 0.1 percent, whole-surface saturation goes
    # from 88 to 102 percent of anchor on Heikki and 64 to 75 on Shane, and the
    # accent still reads as the brightest thing on the body at 1.78x and 2.03x
    # its mean luma, against 1.93x and 2.22x before. The glow was never what
    # made the accent read; the contrast against a dark body was.
    gold = _material("BSP_HeikkiGold", (1.0, 0.58, 0.035), 0.55, 0.28, (1.0, 0.38, 0.015), 0.4)
    cyan = _material("BSP_ShaneCyan", (0.015, 0.82, 0.92), 0.42, 0.24, (0.0, 0.9, 1.0), 0.5)
    teal = _material("BSP_ShaneTeal", (0.015, 0.25, 0.27), 0.36, 0.42)

    heikki = _build_survivor(stage, "Heikki_Gold", materials, gold, materials["rust"], True)
    shane = _build_survivor(stage, "Shane_Cyan", materials, cyan, teal, False)

    target = Vector((0.0, 0.0, 1.45))
    camera_data = bpy.data.cameras.new("BSP_TopDownCamera")
    camera = bpy.data.objects.new("BSP_TopDownCamera", camera_data)
    stage.collection.objects.link(camera)
    camera.location = (4.25, -6.5, 7.3)
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 4.65
    stage.camera = camera

    for name, location, energy, color, size in (
        ("BSP_Key", (-3.5, -4.5, 8.0), 1150, (1.0, 0.64, 0.30), 4.0),
        ("BSP_CoolRim", (4.5, 2.0, 6.0), 980, RIM_COLOR_SHANE, 3.0),
        ("BSP_Fill", (0.0, 4.0, 4.0), 620, (0.34, 0.42, 0.40), 5.0),
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
    line_set = line_sets[0] if len(line_sets) > 0 else line_sets.new("BSP Toon Outline")
    line_style = line_set.linestyle
    line_style.color = (0.004, 0.006, 0.006)
    line_style.thickness = 1.7

    outputs: dict[str, str | tuple[int, int]] = {"resolution": (320, 320)}
    for collection, filename, key in (
        (heikki, "heikki_topdown.png", "heikki"),
        (shane, "shane_topdown.png", "shane"),
    ):
        heikki.hide_render = collection != heikki
        shane.hide_render = collection != shane
        bpy.data.lights["BSP_CoolRim"].color = (
            RIM_COLOR_HEIKKI if key == "heikki" else RIM_COLOR_SHANE
        )
        target_path = OUTPUT_DIR / filename
        stage.render.filepath = str(target_path)
        bpy.ops.render.render(write_still=True)
        outputs[key] = str(target_path)

    heikki.hide_render = False
    shane.hide_render = False
    return outputs


if __name__ == "__main__":
    print(generate())
