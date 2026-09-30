"""Bake four reviewed Poly Haven CC0 surfaces into Bespren's 2D terrain set.

The dedicated Blender workshop stores only the reviewed 1k diffuse maps as
packed images. This script performs the deterministic palette grade, wrapped
atlas packing, and organic 14x14 biome blend-mask bake. Runtime never loads
the Poly Haven PBR source maps or any Node3D content.
"""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import bpy
import numpy as np


PROJECT_ROOT = Path(__file__).resolve().parents[2]
WORKSHOP_PATH = PROJECT_ROOT / "tools" / "art" / "blender" / "bespren_terrain_material_workshop.blend"
OUTPUT_DIR = PROJECT_ROOT / "assets" / "2d" / "environment" / "terrain"
ATLAS_PATH = OUTPUT_DIR / "polyhaven_terrain_atlas.png"
MASK_PATH = OUTPUT_DIR / "bespren_biome_blend_mask.png"
MANIFEST_PATH = OUTPUT_DIR / "polyhaven_terrain_manifest.json"
LICENSE_EVIDENCE = PROJECT_ROOT / "assets" / "licenses" / "polyhaven_cc0.md"

ATLAS_SIZE = 1024
CELL_SIZE = 512
GUTTER = 8
CONTENT_SIZE = CELL_SIZE - GUTTER * 2
MASK_PIXELS_PER_CELL = 16
MASK_SIZE = 14 * MASK_PIXELS_PER_CELL

# Cell order is also the runtime shader contract.
SURFACES = (
    {
        "key": "asphalt",
        "asset_id": "aerial_asphalt_01",
        "image": "aerial_asphalt_01_Diffuse.png",
        "cell": (0, 0),
        "tint_srgb": (0.26, 0.31, 0.30),
        "target_luma": 0.26,
        "url": "https://polyhaven.com/a/aerial_asphalt_01",
    },
    {
        "key": "mud_tracks",
        "asset_id": "muddy_tracks",
        "image": "muddy_tracks_Diffuse.png",
        "cell": (1, 0),
        "tint_srgb": (0.34, 0.28, 0.19),
        "target_luma": 0.20,
        "url": "https://polyhaven.com/a/muddy_tracks",
    },
    {
        "key": "forest_litter",
        "asset_id": "forest_leaves_02",
        "image": "forest_leaves_02_Diffuse.png",
        "cell": (0, 1),
        "tint_srgb": (0.22, 0.32, 0.25),
        "target_luma": 0.23,
        "url": "https://polyhaven.com/a/forest_leaves_02",
    },
    {
        "key": "concrete",
        "asset_id": "concrete_pavement_03",
        "image": "concrete_pavement_03_Diffuse.png",
        "cell": (1, 1),
        "tint_srgb": (0.34, 0.38, 0.36),
        "target_luma": 0.28,
        "url": "https://polyhaven.com/a/concrete_pavement_03",
    },
)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _packed_pixel_hash(image: bpy.types.Image) -> str:
    pixels = np.empty(int(image.size[0]) * int(image.size[1]) * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    quantized = np.rint(np.clip(pixels, 0.0, 1.0) * 255.0).astype(np.uint8)
    return hashlib.sha256(quantized.tobytes()).hexdigest()


def _srgb_to_linear(value: float) -> float:
    if value <= 0.04045:
        return value / 12.92
    return ((value + 0.055) / 1.055) ** 2.4


def _grade(source: tuple[float, float, float], tint_srgb: tuple[float, float, float]) -> tuple[float, float, float]:
    tint = tuple(_srgb_to_linear(value) for value in tint_srgb)
    luma = source[0] * 0.2126 + source[1] * 0.7152 + source[2] * 0.0722
    styled = []
    for channel in range(3):
        value = source[channel] * 0.64 + tint[channel] * (0.20 + luma * 0.80) * 0.36
        value = (value - 0.12) * 1.08 + 0.14
        value = max(0.018, min(0.86, value))
        styled.append(round(value * 31.0) / 31.0)
    return styled[0], styled[1], styled[2]


def _grade_array(
    source: np.ndarray,
    tint_srgb: tuple[float, float, float],
    target_luma: float,
) -> np.ndarray:
    tint = np.asarray([_srgb_to_linear(value) for value in tint_srgb], dtype=np.float32)
    luma = source[..., 0] * 0.2126 + source[..., 1] * 0.7152 + source[..., 2] * 0.0722
    exposure = target_luma / max(float(np.mean(luma)), 0.0001)
    source = np.clip(source * exposure, 0.0, 1.0)
    luma = source[..., 0] * 0.2126 + source[..., 1] * 0.7152 + source[..., 2] * 0.0722
    restrained = source * 0.42 + luma[..., np.newaxis] * 0.58
    styled = restrained * 0.56 + tint * (0.20 + luma[..., np.newaxis] * 0.80) * 0.44
    styled = (styled - 0.12) * 1.08 + 0.14
    return np.rint(np.clip(styled, 0.018, 0.86) * 31.0) / 31.0


def _bake_atlas() -> list[dict[str, object]]:
    output = bpy.data.images.get("BESPREN_POLYHAVEN_TERRAIN_ATLAS")
    if output is not None:
        bpy.data.images.remove(output)
    output = bpy.data.images.new("BESPREN_POLYHAVEN_TERRAIN_ATLAS", ATLAS_SIZE, ATLAS_SIZE, alpha=True)
    output.colorspace_settings.name = "sRGB"
    atlas = np.zeros((ATLAS_SIZE, ATLAS_SIZE, 4), dtype=np.float32)
    atlas[..., 3] = 1.0
    evidence: list[dict[str, object]] = []
    for definition in SURFACES:
        image = bpy.data.images.get(str(definition["image"]))
        if image is None or image.packed_file is None:
            raise RuntimeError(f"Missing packed reviewed diffuse image: {definition['image']}")
        # The workshop deliberately contains no runtime plane or material user;
        # fake-user retention keeps the reviewed packed sources reproducible
        # across repeated background bakes.
        image.use_fake_user = True
        width, height = int(image.size[0]), int(image.size[1])
        if width != 1024 or height != 1024:
            raise RuntimeError(f"{image.name} must be the reviewed 1k source")
        source_flat = np.empty(width * height * 4, dtype=np.float32)
        image.pixels.foreach_get(source_flat)
        source = source_flat.reshape((height, width, 4))
        source_x = np.minimum(
            ((np.arange(CONTENT_SIZE, dtype=np.float32) + 0.5) * width / CONTENT_SIZE).astype(np.int32),
            width - 1,
        )
        source_y = np.minimum(
            ((np.arange(CONTENT_SIZE, dtype=np.float32) + 0.5) * height / CONTENT_SIZE).astype(np.int32),
            height - 1,
        )
        resized = source[source_y[:, np.newaxis], source_x[np.newaxis, :], :3]
        styled = _grade_array(resized, definition["tint_srgb"], float(definition["target_luma"]))
        cell = np.pad(styled, ((GUTTER, GUTTER), (GUTTER, GUTTER), (0, 0)), mode="edge")
        cell_x, cell_y = definition["cell"]
        # Blender image pixels use a bottom-left origin while the runtime atlas
        # contract and PNG manifests use top-left coordinates.
        atlas_y = (1 - cell_y) * CELL_SIZE
        atlas_x = cell_x * CELL_SIZE
        atlas[atlas_y:atlas_y + CELL_SIZE, atlas_x:atlas_x + CELL_SIZE, :3] = cell
        evidence.append({
            "key": definition["key"],
            "asset_id": definition["asset_id"],
            "asset_type": "textures",
            "resolution": "1k",
            "license": "CC0",
            "url": definition["url"],
            "packed_diffuse_image": definition["image"],
            "packed_pixel_sha256": _packed_pixel_hash(image),
            "target_linear_luma": definition["target_luma"],
            "atlas_cell": [cell_x * CELL_SIZE, cell_y * CELL_SIZE, CELL_SIZE, CELL_SIZE],
            "sample_region": [cell_x * CELL_SIZE + GUTTER, cell_y * CELL_SIZE + GUTTER, CONTENT_SIZE, CONTENT_SIZE],
        })
    output.pixels.foreach_set(atlas.ravel())
    output.filepath_raw = str(ATLAS_PATH)
    output.file_format = "PNG"
    output.save()
    return evidence


def _biome_for_cell(column: int, row: int) -> str:
    biome = "wilderness"
    perimeter = column == 0 or row == 0 or column == 13 or row == 13
    if perimeter or (column >= 10 and row <= 8) or (column <= 2 and row >= 5):
        biome = "forest"
    if 1 <= column <= 5 and 1 <= row <= 5:
        biome = "city"
    elif 7 <= column <= 10 and 2 <= row <= 5:
        biome = "mall"
    elif 1 <= column <= 4 and 9 <= row <= 12:
        biome = "village_west"
    elif 9 <= column <= 12 and 9 <= row <= 12:
        biome = "village_east"
    return biome


def _biome_weights(column: int, row: int) -> tuple[float, float, float, float]:
    # Runtime order: forest, asphalt, concrete, mud.
    weights = {
        "forest": (0.84, 0.00, 0.00, 0.16),
        "wilderness": (0.72, 0.00, 0.00, 0.28),
        "city": (0.00, 0.68, 0.32, 0.00),
        "mall": (0.00, 0.28, 0.72, 0.00),
        "village_west": (0.26, 0.00, 0.00, 0.74),
        "village_east": (0.44, 0.00, 0.00, 0.56),
    }
    return weights[_biome_for_cell(max(0, min(13, column)), max(0, min(13, row)))]


def _smooth(value: float) -> float:
    value = max(0.0, min(1.0, value))
    return value * value * (3.0 - 2.0 * value)


def _bake_mask() -> None:
    output = bpy.data.images.get("BESPREN_BIOME_BLEND_MASK")
    if output is not None:
        bpy.data.images.remove(output)
    output = bpy.data.images.new("BESPREN_BIOME_BLEND_MASK", MASK_SIZE, MASK_SIZE, alpha=True)
    output.colorspace_settings.name = "Non-Color"
    pixels = np.zeros((MASK_SIZE, MASK_SIZE, 4), dtype=np.float32)
    pixels[..., 3] = 1.0
    for y in range(MASK_SIZE):
        for x in range(MASK_SIZE):
            map_x = (x + 0.5) / MASK_PIXELS_PER_CELL - 0.5
            map_y = (y + 0.5) / MASK_PIXELS_PER_CELL - 0.5
            # Use a broad, deterministic multi-frequency warp before sampling
            # the authored macro blueprint. The earlier sub-0.15-cell drift
            # still read as a ruler-straight district boundary at 480x270;
            # this bounded 0.42-cell warp keeps district ownership intact while
            # producing visibly organic shoulders over roughly one tile width.
            map_x += math.sin(map_y * 2.13 + 1.7) * 0.32 + math.sin(map_y * 5.91 + 0.4) * 0.10
            map_y += math.sin(map_x * 1.77 + 2.2) * 0.28 + math.sin(map_x * 4.81 + 1.1) * 0.08
            x0, y0 = math.floor(map_x), math.floor(map_y)
            tx, ty = _smooth(map_x - x0), _smooth(map_y - y0)
            weights = [0.0, 0.0, 0.0, 0.0]
            for offset_y, factor_y in ((0, 1.0 - ty), (1, ty)):
                for offset_x, factor_x in ((0, 1.0 - tx), (1, tx)):
                    sampled = _biome_weights(x0 + offset_x, y0 + offset_y)
                    factor = factor_x * factor_y
                    for channel in range(4):
                        weights[channel] += sampled[channel] * factor
            total = max(sum(weights), 0.0001)
            weights = [value / total for value in weights]
            # Mud is reconstructed as 1 - RGB in the runtime shader. Alpha is
            # deliberately opaque so PNG alpha processing cannot bias weights.
            pixels[y, x, :3] = weights[:3]
    # Store map row zero at the PNG top so Sprite2D UV.y follows Godot's world
    # row direction without a runtime flip.
    output.pixels.foreach_set(np.flipud(pixels).ravel())
    output.filepath_raw = str(MASK_PATH)
    output.file_format = "PNG"
    output.save()


def bake() -> dict[str, object]:
    current = Path(bpy.data.filepath).resolve() if bpy.data.filepath else None
    if current != WORKSHOP_PATH.resolve():
        raise RuntimeError(f"Open the dedicated workshop first: {WORKSHOP_PATH}")
    if not LICENSE_EVIDENCE.is_file():
        raise FileNotFoundError(LICENSE_EVIDENCE)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    sources = _bake_atlas()
    _bake_mask()
    scene = bpy.context.scene
    scene["bespren_terrain_bake_policy"] = "polyhaven_cc0_1k_diffuse_offline_2d_only"
    scene["bespren_terrain_atlas"] = str(ATLAS_PATH.relative_to(PROJECT_ROOT))
    scene["bespren_terrain_mask"] = str(MASK_PATH.relative_to(PROJECT_ROOT))
    bpy.ops.wm.save_as_mainfile(filepath=str(WORKSHOP_PATH))
    manifest = {
        "schema_version": 1,
        "license": "CC0",
        "license_evidence": "res://assets/licenses/polyhaven_cc0.md",
        "license_evidence_sha256": _sha256(LICENSE_EVIDENCE),
        "runtime_policy": "2D atlas and blend mask only; no PBR source maps, meshes, materials, or Node3D",
        "blender_version": bpy.app.version_string,
        "workshop": "res://tools/art/blender/bespren_terrain_material_workshop.blend",
        "workshop_bytes": WORKSHOP_PATH.stat().st_size,
        "workshop_sha256": _sha256(WORKSHOP_PATH),
        "generator": "res://tools/art/bake_polyhaven_terrain_materials.py",
        "generator_bytes": Path(__file__).resolve().stat().st_size,
        "generator_sha256": _sha256(Path(__file__).resolve()),
        "sources": sources,
        "atlas": {
            "path": "res://assets/2d/environment/terrain/polyhaven_terrain_atlas.png",
            "size": [ATLAS_SIZE, ATLAS_SIZE],
            "bytes": ATLAS_PATH.stat().st_size,
            "sha256": _sha256(ATLAS_PATH),
            "layout": "2x2 cells with 8px wrapped gutters",
        },
        "blend_mask": {
            "path": "res://assets/2d/environment/terrain/bespren_biome_blend_mask.png",
            "size": [MASK_SIZE, MASK_SIZE],
            "bytes": MASK_PATH.stat().st_size,
            "sha256": _sha256(MASK_PATH),
            "encoding": "R forest, G asphalt, B concrete, mud reconstructed as 1-R-G-B; alpha opaque",
            "grid": "14x14 authored biome blueprint with 16 mask pixels per macro cell and bounded 0.42-cell organic warp",
        },
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


if __name__ == "__main__":
    result = bake()
    print(json.dumps({"atlas": result["atlas"], "blend_mask": result["blend_mask"]}, indent=2))
