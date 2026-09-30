"""Rewrite the camp/structure provenance manifest from what is on disk.

The manifest was hand maintained, which is the failure mode CLAUDE.md 12 already
names for the export closure: an artifact that has to be edited by hand goes
stale silently, and nothing notices until someone trusts it.  It went stale the
first time a single asset was rerendered to test the pipeline.

Run this after any run of ``generate_camp_and_structure_sprites.py``::

    python tools/art/write_generated_asset_manifest.py

A note on what the hashes mean, and a correction to what this note used to say.

Three runs of the unmodified generator under Blender 5.0.0 do produce three
different digests for the same asset - but at an identical byte count, which was
the clue.  Decoding the four PNGs shows the render is bit deterministic: the
IDAT stream is byte identical run to run, and the max per-channel delta across
R, G, B and A is exactly 0 on all 102,400 pixels.  What differs is metadata
Blender stamps outside the pixels - a ``tEXt`` ``Date`` holding the wall clock
and a ``tEXt`` ``RenderTime`` holding how long the render happened to take.

The distinction is worth the paragraph because the old wording said EEVEE itself
was not deterministic, and that licensed exactly the wrong conclusion: it made a
rebake whose pixels had genuinely drifted look like expected noise.  It is not.
A rebake of unmodified source must match the shipped pixels exactly, and any
per-channel delta above zero is a real regression to be explained rather than
absorbed.  The recorded ``sha256`` still identifies the file that shipped rather
than one a rerun can reproduce byte for byte, and ``generator_sha256`` still
pins the source - but the reason is the timestamp, not the renderer.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]

## Both offline Blender families, not just the camp one.  The character pair
## shipped for the whole project with no provenance entry anywhere, so nothing
## recorded that a bake had changed - the same silent staleness the docstring
## above describes, in its more complete form: not a manifest gone stale but a
## manifest that was never written.  Each family lists its renders rather than
## globbing them, so a stray PNG cannot enter a manifest and a missing render
## fails loudly instead of shrinking one.
FAMILIES = (
    {
        "generator": "generate_camp_and_structure_sprites.py",
        "output_dir": PROJECT_ROOT / "assets" / "2d" / "structures",
        "manifest_name": "generated_asset_manifest.json",
        "render_policy": "isolated_scene_orthographic_transparent_freestyle",
        "filenames": (
            "base_camp_topdown.png",
            "structure_t1_barricade.png",
            "structure_t1_chemical.png",
            "structure_t1_electric.png",
            "structure_t1_kinetic.png",
            "structure_t1_landmine.png",
            "structure_t1_razor_snare.png",
            "structure_t1_slowing_pit.png",
            "structure_t1_support.png",
        ),
    },
    {
        "generator": "generate_character_sprites.py",
        "output_dir": PROJECT_ROOT / "assets" / "2d" / "characters",
        "manifest_name": "generated_asset_manifest.json",
        "render_policy": "isolated_scene_orthographic_transparent_freestyle",
        "filenames": (
            "heikki_topdown.png",
            "shane_topdown.png",
        ),
    },
)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def write_manifest(family: dict[str, object]) -> dict[str, object]:
    output_dir = family["output_dir"]
    assert isinstance(output_dir, Path)
    filenames = family["filenames"]
    assert isinstance(filenames, tuple)
    generator = PROJECT_ROOT / "tools" / "art" / str(family["generator"])
    missing = [name for name in filenames if not (output_dir / name).is_file()]
    if missing:
        raise FileNotFoundError(
            "%s has not produced: %s" % (family["generator"], ", ".join(missing))
        )
    manifest: dict[str, object] = {
        "schema_version": 1,
        "generator": "res://tools/art/%s" % family["generator"],
        "generator_sha256": _sha256(generator),
        "blender_version": "5.0.0",
        "render_policy": family["render_policy"],
        "reproducibility": (
            "EEVEE renders these bit deterministically - verified byte-identical "
            "IDAT and zero max per-channel delta across three consecutive bakes. "
            "File digests still differ because Blender stamps wall-clock Date and "
            "RenderTime into PNG tEXt chunks, so generator_sha256 pins the source "
            "and asset hashes identify the shipped files; a rebake that changes "
            "pixels is a regression, not noise"
        ),
        "assets": [
            {
                "path": "res://%s/%s"
                % (output_dir.relative_to(PROJECT_ROOT).as_posix(), name),
                "bytes": (output_dir / name).stat().st_size,
                "sha256": _sha256(output_dir / name),
            }
            for name in filenames
        ],
    }
    manifest_path = output_dir / str(family["manifest_name"])
    manifest_path.write_text(json.dumps(manifest, indent=2) + chr(10), encoding="utf-8")
    return manifest


if __name__ == "__main__":
    for entry_family in FAMILIES:
        family_dir = entry_family["output_dir"]
        assert isinstance(family_dir, Path)
        written = write_manifest(entry_family)
        assets = written["assets"]
        assert isinstance(assets, list)
        print(
            "wrote %s (%d assets)"
            % (family_dir / str(entry_family["manifest_name"]), len(assets))
        )
        for entry in assets:
            assert isinstance(entry, dict)
            print(
                "  %-52s %8d bytes  %s"
                % (entry["path"], entry["bytes"], entry["sha256"][:16])
            )
