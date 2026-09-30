"""Bake a premium Poly Haven district family into mobile-ready 2D sprites.

Run this script only from ``bespren_polyhaven_district_workshop.blend``.  The
workshop contains the reviewed 1k GLTF source models acquired through Blender
MCP.  Godot ships only the transparent PNG outputs and deterministic atlas;
no mesh, PBR graph, authoring light, or Node3D enters the runtime project.
"""

from __future__ import annotations

from dataclasses import dataclass
from array import array
from math import log2, radians, tan
from pathlib import Path
from typing import Iterable

import bpy
from mathutils import Matrix, Vector


PROJECT_ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = PROJECT_ROOT / "assets" / "2d" / "environment" / "polyhaven_district"
WORKSHOP_PATH = (
    PROJECT_ROOT
    / "tools"
    / "art"
    / "blender"
    / "bespren_polyhaven_district_workshop.blend"
)
FRAME_SIZE = 384
STAGE_PREFIX = "BSP_DISTRICT_STAGE_"


@dataclass(frozen=True)
class ObjectInstance:
    object_name: str
    location: tuple[float, float, float]
    rotation_degrees: float = 0.0
    scale: tuple[float, float, float] = (1.0, 1.0, 1.0)


@dataclass(frozen=True)
class AssetBake:
    key: str
    source_id: str
    object_names: tuple[str, ...]
    output_name: str
    framing_scale: float
    group_scale: tuple[float, float, float] = (1.0, 1.0, 1.0)
    rotation_degrees: float = 0.0
    assembly: tuple[ObjectInstance, ...] = ()
    roof_dimensions: tuple[float, float, float] | None = None
    roof_center: tuple[float, float, float] = (0.0, 0.0, 0.0)
    exposure_bias: float = 0.0
    minimum_exposure: float = -32.0
    target_luma: float = 70.0
    freestyle: bool = True
    render_samples: int = 64


def _instance(
    object_name: str,
    location: tuple[float, float, float],
    rotation_degrees: float = 0.0,
) -> ObjectInstance:
    return ObjectInstance(object_name, location, rotation_degrees)


# Facade objects use a bottom-right origin and local X bounds of [-3, 0].
# These explicit transforms therefore make three nine-metre front bays and a
# three-metre return wall.  The old bake kept Poly Haven's catalogue-preview
# spacing, producing disconnected trim strips instead of a usable building.
URBAN_ASSEMBLY: tuple[ObjectInstance, ...] = (
    _instance("wall_window_centered_double_01", (-1.5, 0.0, 0.0)),
    _instance("window_centered_double_01", (-1.5, 0.0, 0.0)),
    _instance("wall_door_centered_small_01", (1.5, 0.0, 0.0)),
    _instance("door_centered_small_01", (1.5, 0.0, 0.0)),
    _instance("wall_window_centered_double_02", (4.5, 0.0, 0.0)),
    _instance("window_centered_double_02", (4.5, 0.0, 0.0)),
    _instance("wall_window_centered_double_02", (-1.5, 0.0, 3.0)),
    _instance("window_centered_double_02", (-1.5, 0.0, 3.0)),
    _instance("wall_window_centered_double_03", (1.5, 0.0, 3.0)),
    _instance("window_centered_double_03", (1.5, 0.0, 3.0)),
    _instance("wall_window_centered_double_01", (4.5, 0.0, 3.0)),
    _instance("window_centered_double_01", (4.5, 0.0, 3.0)),
    _instance("wall_standard_standard_01", (4.5, 3.0, 0.0), 90.0),
    _instance("wall_standard_standard_01", (4.5, 3.0, 3.0), 90.0),
    _instance("cornice_standard_standard_01", (-1.5, 0.0, 2.92)),
    _instance("cornice_standard_standard_01", (1.5, 0.0, 2.92)),
    _instance("cornice_standard_standard_01", (4.5, 0.0, 2.92)),
    _instance("cornice_standard_standard_01", (4.5, 3.0, 2.92), 90.0),
    _instance("crown_standard_standard_01", (-1.5, 0.0, 6.0)),
    _instance("crown_standard_standard_01", (1.5, 0.0, 6.0)),
    _instance("crown_standard_standard_01", (4.5, 0.0, 6.0)),
    _instance("crown_standard_standard_01", (4.5, 3.0, 6.0), 90.0),
)

FACTORY_ASSEMBLY: tuple[ObjectInstance, ...] = (
    _instance("wall_door_garage_double_01", (4.5, 0.0, 0.0)),
    _instance("door_garage_double_01", (4.5, 0.0, 0.0)),
    _instance("dado_garage_double_01", (4.5, 0.0, 0.0)),
    _instance("wall_window_tall_large_05", (-1.5, 0.0, 3.0)),
    _instance("window_tall_large_05", (-1.5, 0.0, 3.0)),
    _instance("wall_window_centered_double_01.001", (1.5, 0.0, 3.0)),
    _instance("window_centered_double_01.001", (1.5, 0.0, 3.0)),
    _instance("wall_window_tall_large_06", (4.5, 0.0, 3.0)),
    _instance("window_tall_large_06", (4.5, 0.0, 3.0)),
    _instance("wall_standard_standard_01.001", (4.5, 3.0, 0.0), 90.0),
    _instance("wall_standard_standard_01.001", (4.5, 3.0, 3.0), 90.0),
    _instance("cornice01_standard_standard_01", (-1.5, 0.0, 2.92)),
    _instance("cornice01_standard_standard_01", (1.5, 0.0, 2.92)),
    _instance("cornice01_standard_standard_01", (4.5, 0.0, 2.92)),
    _instance("cornice01_standard_standard_01", (4.5, 3.0, 2.92), 90.0),
    _instance("crown_standard_standard_01.001", (-1.5, 0.0, 6.0)),
    _instance("crown_standard_standard_01.001", (1.5, 0.0, 6.0)),
    _instance("crown_standard_standard_01.001", (4.5, 0.0, 6.0)),
    _instance("crown_standard_standard_01.001", (4.5, 3.0, 6.0), 90.0),
)


ASSETS: tuple[AssetBake, ...] = (
    AssetBake(
        "urban_apartment_block",
        "modular_urban_apartments_facade",
        tuple(dict.fromkeys(instance.object_name for instance in URBAN_ASSEMBLY)),
        "polyhaven_district_urban_apartment_block.png",
        1.20,
        assembly=URBAN_ASSEMBLY,
        roof_dimensions=(9.0, 3.0, 0.14),
        roof_center=(0.0, 1.5, 6.07),
        exposure_bias=1.35,
        # Blender's image cache reports this facade much brighter than the raw
        # PNG channels consumed by Godot. This floor is pinned from the external
        # Pillow/Godot-equivalent gate, not from the cached preview.
        minimum_exposure=7.10,
        target_luma=72.0,
    ),
    AssetBake(
        "factory_block",
        "modular_factory_facade",
        tuple(dict.fromkeys(instance.object_name for instance in FACTORY_ASSEMBLY)),
        "polyhaven_district_factory_block.png",
        1.20,
        assembly=FACTORY_ASSEMBLY,
        roof_dimensions=(9.0, 3.0, 0.14),
        roof_center=(0.0, 1.5, 6.07),
        exposure_bias=1.45,
        target_luma=72.0,
    ),
    AssetBake(
        "chainlink_gate",
        "modular_chainlink_fence",
        (
            "modular_chainlink_fence_door_frame",
            "modular_chainlink_fence_door_gate",
            "modular_chainlink_fence_door_latch",
        ),
        "polyhaven_district_chainlink_gate.png",
        1.27,
        (1.70, 1.00, 0.86),
        -5.0,
        render_samples=1,
    ),
    AssetBake(
        "covered_car",
        "covered_car",
        (
            "covered_car",
            "covered_car_wheel_01",
            "covered_car_wheel_02",
            "covered_car_wheel_03",
            "covered_car_wheel_04",
        ),
        "polyhaven_district_covered_car.png",
        1.22,
        (1.0, 1.0, 1.0),
        -18.0,
        exposure_bias=0.75,
        target_luma=65.0,
    ),
    AssetBake(
        "aircon_cluster",
        "exterior_aircon_unit",
        ("exterior_aircon_unit", "exterior_aircon_unit_rusted"),
        "polyhaven_district_aircon_cluster.png",
        1.30,
        (1.15, 1.0, 1.0),
        10.0,
        render_samples=1,
    ),
    AssetBake(
        "street_bench",
        "modular_street_seating",
        (
            "seat",
            "seat_back",
            "legs_single",
            "legs_double",
            "back_support_l",
            "back_support_r",
            "arm_rest_01",
            "arm_rest_02",
            "suspended_support_01",
        ),
        "polyhaven_district_street_bench.png",
        1.27,
        (1.15, 1.0, 1.0),
        -9.0,
    ),
    AssetBake(
        "aged_fire_hydrant",
        "fire_hydrant",
        (
            "fire_hydrant_aged",
            "fire_hydrant_cap_01_aged",
            "fire_hydrant_cap_02_aged",
            "fire_hydrant_cap_03_aged",
            "fire_hydrant_chain_aged",
        ),
        "polyhaven_district_aged_fire_hydrant.png",
        1.34,
        (1.18, 1.18, 1.0),
        0.0,
    ),
    AssetBake(
        "barrel_stove",
        "barrel_stove",
        ("barrel_stove",),
        "polyhaven_district_barrel_stove.png",
        1.31,
        (1.08, 1.08, 1.0),
        8.0,
        target_luma=72.0,
    ),
)


def _require_workshop() -> bpy.types.Scene:
    current = Path(bpy.data.filepath).resolve() if bpy.data.filepath else None
    if current is None or current != WORKSHOP_PATH.resolve():
        raise RuntimeError(
            "Open the dedicated Bespren Poly Haven district workshop first: "
            f"{WORKSHOP_PATH}"
        )
    missing = sorted(
        {
            object_name
            for asset in ASSETS
            for object_name in asset.object_names
            if bpy.data.objects.get(object_name) is None
        }
    )
    if missing:
        raise RuntimeError(f"District workshop is missing source objects: {missing}")
    return bpy.context.scene


def _remove_stage_objects(scene: bpy.types.Scene) -> None:
    for obj in list(scene.objects):
        if obj.name.startswith(STAGE_PREFIX):
            bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        if mesh.name.startswith(STAGE_PREFIX) and mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    for material in list(bpy.data.materials):
        if material.name.startswith(STAGE_PREFIX) and material.users == 0:
            bpy.data.materials.remove(material)


def _configure_stage(scene: bpy.types.Scene) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    _remove_stage_objects(scene)
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = FRAME_SIZE
    scene.render.resolution_y = FRAME_SIZE
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.film_transparent = True
    if hasattr(scene.render, "dither_intensity"):
        scene.render.dither_intensity = 0.0
    if hasattr(scene, "eevee"):
        scene.eevee.use_taa_reprojection = False
    scene.render.use_freestyle = True
    scene.render.line_thickness = 1.10
    scene.view_settings.exposure = 1.48
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except (TypeError, ValueError):
        pass

    world = bpy.data.worlds.get(f"{STAGE_PREFIX}WORLD") or bpy.data.worlds.new(
        f"{STAGE_PREFIX}WORLD"
    )
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    if background is not None:
        background.inputs["Color"].default_value = (0.0184, 0.0195, 0.0209, 1.0)
        background.inputs["Strength"].default_value = 0.42
    scene.world = world

    camera_data = bpy.data.cameras.new(f"{STAGE_PREFIX}CAMERA_DATA")
    camera = bpy.data.objects.new(f"{STAGE_PREFIX}CAMERA", camera_data)
    scene.collection.objects.link(camera)
    camera.data.type = "ORTHO"
    scene.camera = camera

    lights: list[bpy.types.Object] = []
    specifications = (
        ("WARM_KEY", Vector((-5.2, -6.6, 9.6)), 980.0, (1.0, 0.62, 0.30), 4.8),
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
        # colour and not of exposure. That algebra is linear and AgX is not, so it is
        # a prediction rather than a guarantee: it held here, moving mean alpha-weighted
        # luma by +0.42 percent on the district and +0.14 on the environment family, and
        # it under-shot by one to two percent on the local family's shadow-dominated
        # frames, where the energy had to be re-derived by measurement instead. The
        # world background above is moved the same way and for the same reason - it was
        # the shadow half of the same defect, sitting at hue 186 (local) and 163
        # (district and environment, on the patina hue), and it accounted for the residue
        # the rim left behind on the darkest frames. Median teal fell from 0.43 to 0.00
        # percent of opaque pixels on the environment family and from 16.58 to 0.66 on
        # the district.
        # What survives is not lit teal at all: it is the two hues section 8 authored.
        # `patina` (hue 168) and `petroleum` (hue 176) are assigned by name in the local
        # roster, and the district shares one flat `_roof_material` at hue 166. Copper
        # patina #1C8270 is section 8's weathered-technology accent and petroleum green
        # is its stated value base. The detector keys on blue over red with green over
        # red, which is precisely what those two anchors are, so it cannot separate them
        # from the defect it was built to find. Warming them toward concrete would delete
        # an authored anchor to satisfy a metric aimed at a lighting bug.
        ("COOL_RIM", Vector((6.0, 2.8, 7.8)), 739.0, (0.418, 0.493, 0.580), 4.0),
        ("SOFT_FILL", Vector((-0.6, 6.4, 7.0)), 700.0, (0.48, 0.50, 0.45), 6.0),
    )
    for suffix, offset, energy, color, size in specifications:
        light_data = bpy.data.lights.new(f"{STAGE_PREFIX}{suffix}_DATA", "AREA")
        light_data.energy = energy
        light_data.color = color
        light_data.shape = "DISK"
        light_data.size = size
        light = bpy.data.objects.new(f"{STAGE_PREFIX}{suffix}", light_data)
        scene.collection.objects.link(light)
        light["bespren_offset"] = tuple(offset)
        light["bespren_base_size"] = size
        light["bespren_base_energy"] = energy
        lights.append(light)

    line_sets = scene.view_layers[0].freestyle_settings.linesets
    line_set = line_sets[0] if len(line_sets) else line_sets.new("BSP District Silhouette")
    line_set.linestyle.color = (0.005, 0.009, 0.008)
    line_set.linestyle.thickness = 1.14
    for property_name, enabled in (
        ("select_silhouette", True),
        ("select_border", True),
        ("select_contour", True),
        ("select_crease", False),
        ("select_edge_mark", False),
        ("select_material_boundary", False),
        ("select_suggestive_contour", False),
    ):
        if hasattr(line_set, property_name):
            setattr(line_set, property_name, enabled)
    return camera, lights


def _world_bounds(objects: Iterable[bpy.types.Object]) -> tuple[Vector, Vector]:
    minimum = Vector((float("inf"), float("inf"), float("inf")))
    maximum = Vector((float("-inf"), float("-inf"), float("-inf")))
    found_corner = False
    for obj in objects:
        for corner in obj.bound_box:
            world_corner = obj.matrix_world @ Vector(corner)
            minimum.x = min(minimum.x, world_corner.x)
            minimum.y = min(minimum.y, world_corner.y)
            minimum.z = min(minimum.z, world_corner.z)
            maximum.x = max(maximum.x, world_corner.x)
            maximum.y = max(maximum.y, world_corner.y)
            maximum.z = max(maximum.z, world_corner.z)
            found_corner = True
    if not found_corner:
        raise RuntimeError("Cannot frame a district asset with no mesh bounds")
    return minimum, maximum


def _roof_material() -> bpy.types.Material:
    name = f"{STAGE_PREFIX}ROOF_MATERIAL"
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = (0.055, 0.085, 0.078, 1.0)
    shader = material.node_tree.nodes.get("Principled BSDF")
    if shader is not None:
        shader.inputs["Base Color"].default_value = (0.055, 0.085, 0.078, 1.0)
        shader.inputs["Metallic"].default_value = 0.08
        shader.inputs["Roughness"].default_value = 0.82
        if "Specular IOR Level" in shader.inputs:
            shader.inputs["Specular IOR Level"].default_value = 0.24
    return material


def _create_roof(scene: bpy.types.Scene, asset: AssetBake, index: int) -> bpy.types.Object:
    if asset.roof_dimensions is None:
        raise RuntimeError(f"{asset.key} has no roof dimensions")
    width, depth, height = asset.roof_dimensions
    half_x, half_y, half_z = width * 0.5, depth * 0.5, height * 0.5
    vertices = [
        (-half_x, -half_y, -half_z),
        (half_x, -half_y, -half_z),
        (half_x, half_y, -half_z),
        (-half_x, half_y, -half_z),
        (-half_x, -half_y, half_z),
        (half_x, -half_y, half_z),
        (half_x, half_y, half_z),
        (-half_x, half_y, half_z),
    ]
    faces = [
        (0, 3, 2, 1),
        (4, 5, 6, 7),
        (0, 1, 5, 4),
        (1, 2, 6, 5),
        (2, 3, 7, 6),
        (3, 0, 4, 7),
    ]
    mesh = bpy.data.meshes.new(f"{STAGE_PREFIX}{asset.key}_ROOF_MESH")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(_roof_material())
    roof = bpy.data.objects.new(f"{STAGE_PREFIX}{asset.key}_{index:02d}_ROOF", mesh)
    roof.location = Vector(asset.roof_center)
    scene.collection.objects.link(roof)
    return roof


def _clone_source(
    scene: bpy.types.Scene,
    asset: AssetBake,
    object_name: str,
    index: int,
) -> bpy.types.Object:
    source = bpy.data.objects[object_name]
    clone = source.copy()
    clone.name = f"{STAGE_PREFIX}{asset.key}_{index:02d}"
    clone.hide_render = False
    clone.hide_viewport = False
    clone.hide_set(False)
    scene.collection.objects.link(clone)
    return clone


def _clone_asset(scene: bpy.types.Scene, asset: AssetBake) -> list[bpy.types.Object]:
    clones: list[bpy.types.Object] = []
    if asset.assembly:
        for index, instance in enumerate(asset.assembly):
            clone = _clone_source(scene, asset, instance.object_name, index)
            # Every facade source has a useful local origin, but its saved world
            # location is only the Poly Haven catalogue-preview grid. Replace
            # that grid transform completely with the authored block transform.
            clone.matrix_world = Matrix.Identity(4)
            clone.location = Vector(instance.location)
            clone.rotation_euler = (0.0, 0.0, radians(instance.rotation_degrees))
            clone.scale = Vector(instance.scale)
            clones.append(clone)
        if asset.roof_dimensions is not None:
            clones.append(_create_roof(scene, asset, len(clones)))
        bpy.context.view_layer.update()
        return clones

    for index, object_name in enumerate(asset.object_names):
        source = bpy.data.objects[object_name]
        clone = _clone_source(scene, asset, object_name, index)
        clone.matrix_world = source.matrix_world.copy()
        clones.append(clone)

    minimum, maximum = _world_bounds(clones)
    pivot = Vector(
        (
            (minimum.x + maximum.x) * 0.5,
            (minimum.y + maximum.y) * 0.5,
            minimum.z,
        )
    )
    scale = Vector(asset.group_scale)
    rotation = Matrix.Rotation(radians(asset.rotation_degrees), 4, "Z")
    for clone in clones:
        relative = clone.location - pivot
        relative = Vector((relative.x * scale.x, relative.y * scale.y, relative.z * scale.z))
        clone.location = rotation @ relative
        clone.scale = Vector(
            (
                clone.scale.x * scale.x,
                clone.scale.y * scale.y,
                clone.scale.z * scale.z,
            )
        )
        clone.rotation_euler.z += radians(asset.rotation_degrees)

    # Blender defers matrix_world evaluation after scripted local-transform
    # edits. Framing against the stale matrices would still target the source
    # model's catalogue offset (for example x=-21 for the factory) and crop or
    # entirely miss the staged clone.
    bpy.context.view_layer.update()
    minimum, _maximum = _world_bounds(clones)
    if abs(minimum.z) > 0.0001:
        for clone in clones:
            clone.location.z -= minimum.z
        bpy.context.view_layer.update()
    return clones


# The stage puts its lights at a distance proportional to the framed span, so a
# tall subject pushes them away and collects 1/r^2 less light - even though the
# ortho camera is holding its *projected* size constant, which is the whole
# point of framing this way. The result was a rig that lit small props and
# starved large ones. Measured across the wild/salvage family: a 0.35 m toolbox
# reached alpha-weighted luma 132.6, a 1.4 m subject 81-86, a 2.55 m shrub 36.7,
# and a 3.87 m street lamp 34.5 - scraping the packer's 34.0 floor - while a
# 4.56 m tree rendered at 1.2 and could not be rescued, because the per-frame
# exposure loop tops out at 3.6 stops and that tree needed 4.8.
#
# Scaling each light's energy by the square of its distance ratio removes the
# scale term. What survives is albedo, which is the difference that should:
# measured at the same distance scale, bare rock_07 sits at 57.9 against bright
# stump wood at 141.7, and it should stay that way.
#
# The reference is the floor of the distance expression below, so subjects small
# enough to sit at that floor are untouched and only oversized ones are lifted.
# It is opt-in because the shipped district atlas hash is pinned in CLAUDE.md 9
# and every asset in that family already frames near the reference.
REFERENCE_DISTANCE_SCALE = 0.72


# The stage camera looks down the canonical direction below, which is 42.7
# degrees of elevation. That is the right three-quarter for the props this
# family was built for - a 1 m barrel, a 2 m air-conditioner - where the eye
# wants to see a lid and a face at once.
#
# It is the wrong angle for a 15 m tree. At 42.7 degrees a scots pine projects
# as trunk from root to canopy, which is a side elevation of a tree wearing a
# hat; the game draws it 48 px wide and the trunk eats most of that. The fix is
# not a different tree but a different camera: raising the elevation
# foreshortens the trunk into the canopy and leaves a compact, canopy-dominant
# silhouette that still shows enough bole to read as a tree rather than a bush.
#
# The azimuth is deliberately shared with the default, so a tree is lit and
# shaded from the same side as the barrel beside it. Only the pitch moves.
CANONICAL_CAMERA_DIRECTION = Vector((5.2, -8.0, 8.8))


def _camera_direction(elevation_degrees: float) -> Vector:
    """Canonical stage direction, or the same azimuth at a steeper pitch."""

    if elevation_degrees <= 0.0:
        return CANONICAL_CAMERA_DIRECTION.normalized()
    ground = Vector((CANONICAL_CAMERA_DIRECTION.x, CANONICAL_CAMERA_DIRECTION.y, 0.0))
    return Vector(
        (
            ground.x,
            ground.y,
            ground.length * tan(radians(elevation_degrees)),
        )
    ).normalized()


def _frame_asset(
    camera: bpy.types.Object,
    lights: Iterable[bpy.types.Object],
    objects: list[bpy.types.Object],
    framing_scale: float,
    compensate_falloff: bool = False,
    elevation_degrees: float = 0.0,
) -> None:
    minimum, maximum = _world_bounds(objects)
    dimensions = maximum - minimum
    target = Vector(
        (
            (minimum.x + maximum.x) * 0.5,
            (minimum.y + maximum.y) * 0.5,
            minimum.z + dimensions.z * 0.40,
        )
    )
    camera_direction = _camera_direction(elevation_degrees)
    rough_span = max(dimensions.length, 0.75)
    camera.location = target + camera_direction * max(rough_span * 4.0, 7.0)
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.clip_start = 0.01
    camera.data.clip_end = max(rough_span * 12.0, 100.0)
    bpy.context.view_layer.update()

    # A world-axis span is not a bound for an oblique camera. Project every
    # evaluated box corner onto camera right/up, recenter on that exact screen
    # rectangle, and derive ortho_scale from the larger projected dimension.
    view_matrix = camera.matrix_world.inverted()
    projected: list[Vector] = []
    for obj in objects:
        for corner in obj.bound_box:
            projected.append(view_matrix @ (obj.matrix_world @ Vector(corner)))
    minimum_x = min(point.x for point in projected)
    maximum_x = max(point.x for point in projected)
    minimum_y = min(point.y for point in projected)
    maximum_y = max(point.y for point in projected)
    projected_width = maximum_x - minimum_x
    projected_height = maximum_y - minimum_y
    screen_center = Vector(
        (
            (minimum_x + maximum_x) * 0.5,
            (minimum_y + maximum_y) * 0.5,
            0.0,
        )
    )
    camera.location += camera.matrix_world.to_3x3() @ screen_center
    aspect = (
        float(bpy.context.scene.render.resolution_x)
        / float(max(bpy.context.scene.render.resolution_y, 1))
    )
    exact_span = max(projected_height, projected_width / aspect, 0.75)
    camera.data.ortho_scale = exact_span * max(framing_scale, 1.16)
    bpy.context.view_layer.update()

    distance_scale = max(exact_span * 0.38, 0.72)
    for light in lights:
        offset = Vector(light["bespren_offset"])
        light.location = target + offset * distance_scale
        light.rotation_euler = (target - light.location).to_track_quat("-Z", "Y").to_euler()
        light.data.size = max(float(light["bespren_base_size"]), exact_span * 0.72)
        if compensate_falloff:
            light.data.energy = float(light["bespren_base_energy"]) * (
                distance_scale / REFERENCE_DISTANCE_SCALE
            ) ** 2


def _analyze_output(path: Path) -> dict[str, float | int]:
    image = bpy.data.images.load(str(path), check_existing=False)
    try:
        width, height = int(image.size[0]), int(image.size[1])
        if width != FRAME_SIZE or height != FRAME_SIZE:
            raise RuntimeError(f"{path.name} must be {FRAME_SIZE}x{FRAME_SIZE}")
        pixels = array("f", [0.0]) * (width * height * 4)
        image.pixels.foreach_get(pixels)
        minimum_x, minimum_y = width, height
        maximum_x, maximum_y = -1, -1
        visible_pixels = 0
        alpha_sum = 0.0
        weighted_luma = 0.0
        alpha_threshold = 4.0 / 255.0
        for pixel_index in range(width * height):
            offset = pixel_index * 4
            alpha = float(pixels[offset + 3])
            if alpha <= alpha_threshold:
                continue
            x = pixel_index % width
            y = pixel_index // width
            minimum_x = min(minimum_x, x)
            minimum_y = min(minimum_y, y)
            maximum_x = max(maximum_x, x)
            maximum_y = max(maximum_y, y)
            visible_pixels += 1
            # Blender exposes the reloaded PNG channels in the same numeric
            # representation used by Godot's Image loader and the atlas gate.
            # Applying another transfer curve here materially overestimated
            # dark-facade readability.
            red = float(pixels[offset])
            green = float(pixels[offset + 1])
            blue = float(pixels[offset + 2])
            weighted_luma += (red * 0.2126 + green * 0.7152 + blue * 0.0722) * alpha
            alpha_sum += alpha
        if visible_pixels == 0:
            return {
                "visible_pixels": 0,
                "edge_margin_px": -1,
                "alpha_weighted_luma": 0.0,
            }
        edge_margin = min(
            minimum_x,
            minimum_y,
            width - 1 - maximum_x,
            height - 1 - maximum_y,
        )
        return {
            "visible_pixels": visible_pixels,
            "edge_margin_px": edge_margin,
            "alpha_weighted_luma": weighted_luma / max(alpha_sum, 0.0001) * 255.0,
        }
    finally:
        bpy.data.images.remove(image)


def _canonicalize_png(path: Path) -> None:
    """Strip Blender's volatile Date/RenderTime/EXIF chunks.

    Eevee's RGBA pixels are deterministic with render dithering disabled, but
    Blender writes per-run metadata into ancillary PNG chunks. Keeping only
    critical chunks preserves the exact pixels while making the file hash a
    stable provenance value across repeated bakes.
    """
    payload = path.read_bytes()
    signature = b"\x89PNG\r\n\x1a\n"
    if not payload.startswith(signature):
        raise RuntimeError(f"{path.name} is not a PNG")
    canonical = bytearray(signature)
    offset = len(signature)
    found_iend = False
    while offset + 12 <= len(payload):
        data_length = int.from_bytes(payload[offset : offset + 4], "big")
        chunk_end = offset + 12 + data_length
        if chunk_end > len(payload):
            raise RuntimeError(f"{path.name} has a truncated PNG chunk")
        chunk_type = payload[offset + 4 : offset + 8]
        # PNG critical chunk names have an uppercase first byte.
        if chunk_type and not (chunk_type[0] & 0x20):
            canonical.extend(payload[offset:chunk_end])
        offset = chunk_end
        if chunk_type == b"IEND":
            found_iend = True
            break
    if not found_iend:
        raise RuntimeError(f"{path.name} has no IEND chunk")
    path.write_bytes(canonical)


def _render_validated(scene: bpy.types.Scene, asset: AssetBake, target: Path) -> dict[str, float | int]:
    exposure = max(1.48 + asset.exposure_bias, asset.minimum_exposure)
    metrics: dict[str, float | int] = {}
    for attempt in range(4):
        scene.view_settings.exposure = exposure
        bpy.ops.render.render(write_still=True)
        _canonicalize_png(target)
        metrics = _analyze_output(target)
        visible_pixels = int(metrics["visible_pixels"])
        edge_margin = int(metrics["edge_margin_px"])
        luma = float(metrics["alpha_weighted_luma"])
        if visible_pixels < 128:
            raise RuntimeError(f"{asset.key} rendered only {visible_pixels} visible pixels")
        if edge_margin < 8:
            raise RuntimeError(
                f"{asset.key} touches the frame edge (margin={edge_margin}px)"
            )
        if luma >= asset.target_luma or attempt == 3:
            break
        exposure += max(0.30, min(log2(asset.target_luma / max(luma, 1.0)), 2.50))
    if float(metrics["alpha_weighted_luma"]) < 50.0:
        raise RuntimeError(
            f"{asset.key} is underexposed after correction: "
            f"luma={float(metrics['alpha_weighted_luma']):.2f}"
        )
    print(
        "DISTRICT FRAME OK | key=%s | visible=%d | margin=%d | luma=%.2f | exposure=%.2f"
        % (
            asset.key,
            int(metrics["visible_pixels"]),
            int(metrics["edge_margin_px"]),
            float(metrics["alpha_weighted_luma"]),
            exposure,
        )
    )
    return metrics


def generate(asset_keys: Iterable[str] | None = None) -> dict[str, str]:
    scene = _require_workshop()
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    previous_camera_name = (
        scene.camera.name
        if scene.camera is not None and not scene.camera.name.startswith(STAGE_PREFIX)
        else ""
    )
    previous_world = scene.world
    previous_exposure = scene.view_settings.exposure
    previous_freestyle = scene.render.use_freestyle
    camera, lights = _configure_stage(scene)
    requested = set(asset_keys) if asset_keys is not None else {asset.key for asset in ASSETS}
    unknown = requested.difference(asset.key for asset in ASSETS)
    if unknown:
        raise KeyError(f"Unknown district bake keys: {sorted(unknown)}")

    source_meshes = [
        obj
        for obj in scene.objects
        if obj.type == "MESH" and not obj.name.startswith(STAGE_PREFIX)
    ]
    source_visibility = {source.name: source.hide_render for source in source_meshes}

    outputs: dict[str, str] = {}
    try:
        for source in source_meshes:
            source.hide_render = True
        for asset in ASSETS:
            if asset.key not in requested:
                continue
            clones = _clone_asset(scene, asset)
            try:
                _frame_asset(camera, lights, clones, asset.framing_scale)
                target = OUTPUT_DIR / asset.output_name
                scene.render.filepath = str(target)
                scene.render.use_freestyle = asset.freestyle
                if hasattr(scene, "eevee"):
                    scene.eevee.taa_render_samples = asset.render_samples
                scene["bespren_active_asset"] = asset.key
                scene["bespren_polyhaven_source"] = asset.source_id
                _render_validated(scene, asset, target)
                outputs[asset.key] = str(target)
            finally:
                for clone in clones:
                    if clone.name in bpy.data.objects:
                        bpy.data.objects.remove(clone, do_unlink=True)
                bpy.context.view_layer.update()
    finally:
        for source in source_meshes:
            if source.name in bpy.data.objects:
                source.hide_render = source_visibility[source.name]
        scene["bespren_active_asset"] = ""
        scene["bespren_polyhaven_source"] = ""
        scene.camera = (
            bpy.data.objects.get(previous_camera_name)
            if previous_camera_name
            else None
        )
        scene.world = previous_world
        scene.view_settings.exposure = previous_exposure
        scene.render.use_freestyle = previous_freestyle
        _remove_stage_objects(scene)
        bpy.context.view_layer.update()

    # Deliberately do not pack or save here. The workshop is immutable input;
    # repeat renders must not alter its provenance hash or the artist's scene.
    return outputs


if __name__ == "__main__":
    print(generate())
