"""Bake reviewed Poly Haven models into Bespren's 2D environment sprites.

This script is intentionally run from the dedicated
``bespren_map_asset_workshop.blend`` file.  Poly Haven meshes and PBR textures
are offline source material only; the shipping Godot project consumes the
transparent PNG outputs.  The camera, light rig, color management, silhouette
lines, and framing are shared across every asset so unrelated scans read as one
stylized mobile set.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import bpy
from mathutils import Vector


PROJECT_ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = PROJECT_ROOT / "assets" / "2d" / "environment" / "polyhaven"
WORKSHOP_PATH = PROJECT_ROOT / "tools" / "art" / "blender" / "bespren_map_asset_workshop.blend"
STAGE_PREFIX = "BSP_ENV_STAGE_"


@dataclass(frozen=True)
class AssetBake:
    key: str
    source_id: str
    object_names: tuple[str, ...]
    output_name: str
    framing_scale: float = 1.28


ASSETS: tuple[AssetBake, ...] = (
    AssetBake(
        "forest_stump",
        "tree_stump_01",
        ("tree_stump_01",),
        "polyhaven_forest_stump_01.png",
        1.34,
    ),
    AssetBake(
        "forest_dead_trunk",
        "dead_tree_trunk",
        ("dead_tree_trunk",),
        "polyhaven_forest_dead_trunk_01.png",
        1.22,
    ),
    AssetBake(
        "moss_rock_01",
        "rock_moss_set_01",
        ("rock_moss_set_01_rock01",),
        "polyhaven_moss_rock_01.png",
    ),
    AssetBake(
        "moss_rock_02",
        "rock_moss_set_01",
        ("rock_moss_set_01_rock02",),
        "polyhaven_moss_rock_02.png",
    ),
    AssetBake(
        "moss_rock_03",
        "rock_moss_set_01",
        ("rock_moss_set_01_rock03",),
        "polyhaven_moss_rock_03.png",
    ),
    AssetBake(
        "moss_rock_04",
        "rock_moss_set_01",
        ("rock_moss_set_01_rock04",),
        "polyhaven_moss_rock_04.png",
    ),
    AssetBake(
        "moss_rock_05",
        "rock_moss_set_01",
        ("rock_moss_set_01_rock05",),
        "polyhaven_moss_rock_05.png",
    ),
    AssetBake(
        "moss_rock_06",
        "rock_moss_set_01",
        ("rock_moss_set_01_rock06",),
        "polyhaven_moss_rock_06.png",
    ),
    AssetBake(
        "city_trash_clean",
        "metal_trash_can",
        (
            "metal_trash_can",
            "metal_trash_can_lid",
            "metal_trash_can_handle_left",
            "metal_trash_can_handle_right",
        ),
        "polyhaven_city_trash_can_clean_01.png",
        1.42,
    ),
    AssetBake(
        "city_trash_rust",
        "metal_trash_can",
        (
            "metal_trash_can_rust",
            "metal_trash_can_rust_lid",
            "metal_trash_can_rust_handle_left",
            "metal_trash_can_rust_handle_right",
        ),
        "polyhaven_city_trash_can_rust_01.png",
        1.42,
    ),
    AssetBake(
        "city_barrier",
        "concrete_road_barrier",
        ("concrete_road_barrier",),
        "polyhaven_city_concrete_barrier_01.png",
        1.20,
    ),
    AssetBake(
        "city_tyre",
        "old_tyre",
        ("old_tyre",),
        "polyhaven_city_old_tyre_01.png",
        1.36,
    ),
)


def _require_workshop() -> bpy.types.Scene:
    current = Path(bpy.data.filepath).resolve() if bpy.data.filepath else None
    if current is None or current != WORKSHOP_PATH.resolve():
        raise RuntimeError(
            "Open the dedicated Bespren map asset workshop before rendering: "
            f"{WORKSHOP_PATH}"
        )
    scene = bpy.context.scene
    missing = sorted(
        {
            object_name
            for asset in ASSETS
            for object_name in asset.object_names
            if bpy.data.objects.get(object_name) is None
        }
    )
    if missing:
        raise RuntimeError(f"Workshop is missing imported source objects: {missing}")
    return scene


def _remove_old_stage_objects(scene: bpy.types.Scene) -> None:
    for obj in list(scene.objects):
        if obj.name.startswith(STAGE_PREFIX):
            bpy.data.objects.remove(obj, do_unlink=True)


def _configure_stage(scene: bpy.types.Scene) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    _remove_old_stage_objects(scene)
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 384
    scene.render.resolution_y = 384
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.film_transparent = True
    scene.render.use_freestyle = True
    scene.render.line_thickness = 1.15
    # Poly Haven scans carry deep photographic blacks. A deliberate exposure
    # lift and stronger neutral fill keep their midtones readable after the
    # game's blue-hour modulation without flattening AgX-protected highlights.
    scene.view_settings.exposure = 1.55
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
        background.inputs["Strength"].default_value = 0.40
    scene.world = world

    camera_data = bpy.data.cameras.new(f"{STAGE_PREFIX}CAMERA_DATA")
    camera = bpy.data.objects.new(f"{STAGE_PREFIX}CAMERA", camera_data)
    scene.collection.objects.link(camera)
    camera.data.type = "ORTHO"
    scene.camera = camera

    lights: list[bpy.types.Object] = []
    specifications = (
        ("WARM_KEY", Vector((-5.2, -6.6, 9.4)), 920.0, (1.0, 0.62, 0.30), 4.6),
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
        ("COOL_RIM", Vector((5.8, 2.8, 7.6)), 711.0, (0.418, 0.493, 0.580), 3.8),
        ("SOFT_FILL", Vector((-0.6, 6.2, 6.8)), 640.0, (0.46, 0.49, 0.44), 5.8),
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
        lights.append(light)

    line_sets = scene.view_layers[0].freestyle_settings.linesets
    line_set = line_sets[0] if len(line_sets) else line_sets.new("BSP Environment Silhouette")
    line_set.linestyle.color = (0.005, 0.009, 0.008)
    line_set.linestyle.thickness = 1.18
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
        raise RuntimeError("Cannot frame an asset with no mesh bounds")
    return minimum, maximum


def _frame_asset(
    camera: bpy.types.Object,
    lights: Iterable[bpy.types.Object],
    objects: list[bpy.types.Object],
    framing_scale: float,
) -> None:
    minimum, maximum = _world_bounds(objects)
    dimensions = maximum - minimum
    target = Vector(
        (
            (minimum.x + maximum.x) * 0.5,
            (minimum.y + maximum.y) * 0.5,
            minimum.z + dimensions.z * 0.42,
        )
    )
    camera_direction = Vector((5.0, -7.8, 8.6)).normalized()
    projected_span = max(
        dimensions.x,
        dimensions.y * 0.82 + dimensions.z * 0.62,
        dimensions.z * 1.10,
        0.75,
    )
    camera.data.ortho_scale = projected_span * framing_scale
    camera.location = target + camera_direction * max(projected_span * 4.0, 7.0)
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    for light in lights:
        offset = Vector(light["bespren_offset"])
        light.location = target + offset * max(projected_span * 0.38, 0.72)
        light.rotation_euler = (target - light.location).to_track_quat("-Z", "Y").to_euler()
        light.data.size = max(light.data.size, projected_span * 0.72)


def generate(asset_keys: Iterable[str] | None = None) -> dict[str, str]:
    scene = _require_workshop()
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    camera, lights = _configure_stage(scene)
    requested = set(asset_keys) if asset_keys is not None else {asset.key for asset in ASSETS}
    unknown = requested.difference(asset.key for asset in ASSETS)
    if unknown:
        raise KeyError(f"Unknown Poly Haven bake keys: {sorted(unknown)}")

    source_meshes = [
        obj
        for obj in scene.objects
        if obj.type == "MESH" and not obj.name.startswith(STAGE_PREFIX)
    ]
    outputs: dict[str, str] = {}
    for asset in ASSETS:
        if asset.key not in requested:
            continue
        active_objects = [bpy.data.objects[name] for name in asset.object_names]
        active_names = set(asset.object_names)
        for obj in source_meshes:
            obj.hide_render = obj.name not in active_names
        _frame_asset(camera, lights, active_objects, asset.framing_scale)
        target = OUTPUT_DIR / asset.output_name
        scene.render.filepath = str(target)
        scene["bespren_active_asset"] = asset.key
        scene["bespren_polyhaven_source"] = asset.source_id
        bpy.ops.render.render(write_still=True)
        outputs[asset.key] = str(target)

    for obj in source_meshes:
        obj.hide_render = False
    scene["bespren_active_asset"] = ""
    scene["bespren_polyhaven_source"] = ""
    try:
        bpy.ops.file.pack_all()
    except RuntimeError as error:
        print(f"PACK WARNING: {error}")
    bpy.ops.wm.save_as_mainfile(filepath=str(WORKSHOP_PATH))
    return outputs


if __name__ == "__main__":
    print(generate())
