"""Drive the wild/salvage bake one Blender process per source model.

The renderer itself is happy to loop; Blender is not. Poly Haven's conifers are
photogrammetry-grade - `pine_tree_01` is 914 MB of leaf geometry on disk and
takes 87 seconds just to parse - and importing two of them into one session
raises a C++ exception and takes the whole run with it, including the thirty
sources that would have rendered fine. Blender also never returns that memory
to the OS within a session, so even without the crash the peak would climb all
run.

One process per source fixes both. The peak is one model, the address space is
reclaimed on exit, and a source that cannot be imported at all costs exactly
itself: it lands in `failed` and the next process starts clean. A production
run writes the atlas-builder input under ``assets/`` only after the explicit
``--production`` opt-in; ``--trial`` writes only to the dedicated artifact
directory and never becomes a runtime input.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import time
from pathlib import Path

from wild_bake_contract import (
    ENVIRONMENT_ROOT,
    OUTPUT_ROOT_ENV,
    PROJECT_ROOT,
    REJECTED_SOURCES,
    TRIAL_ARTIFACT_ROOT,
    TRIAL_SOURCES,
    report_path,
    validate_output_contract,
)


HERE = Path(__file__).resolve().parent
BLENDER = Path(r"C:\Program Files\Blender Foundation\Blender 5.0\blender.exe")
RENDERER = HERE / "render_polyhaven_wild_sprites.py"
VAULT = HERE / "blender" / "vault"
# A source that has not produced a frame in this long is not going to. The
# slowest legitimate import measured is 87 s, so this is generous by 6x.
TIMEOUT_S = 540


def sources(family: str) -> list[str]:
    """Return the fetched sources this family actually bakes.

    The fetch manifest records what was downloaded, which is a superset of what
    the renderer's roster renders: a source can be fetched, evaluated and cut.
    Filtering [const REJECTED_SOURCES] here keeps a deliberate omission from
    surfacing as a bake error and blocking the atlas.
    """

    path = VAULT / family / "_fetch_manifest.json"
    with path.open(encoding="utf-8") as handle:
        fetched = [str(asset["id"]) for asset in json.load(handle)["assets"]]
    rejected = REJECTED_SOURCES.get(family, frozenset())
    return [asset_id for asset_id in fetched if asset_id not in rejected]


def _renderer_environment(output_root: Path) -> dict[str, str]:
    """Return the exact isolated Blender environment for one source render."""

    environment = os.environ.copy()
    if output_root == ENVIRONMENT_ROOT:
        # Production uses the renderer's default assets/ root. Clearing a
        # caller-provided override prevents a stale trial environment variable
        # from redirecting or rejecting a real atlas build.
        environment.pop(OUTPUT_ROOT_ENV, None)
    else:
        environment[OUTPUT_ROOT_ENV] = str(output_root)
    environment["BESPREN_WILD_BAKE_ISOLATED"] = "1"
    return environment


def run_one(family: str, asset_id: str, output_root: Path) -> dict:
    """Render one source into ``output_root`` without ever opening the UI file."""

    report = report_path(output_root, asset_id)
    if report.exists():
        report.unlink()
    started = time.time()
    environment = _renderer_environment(output_root)
    try:
        proc = subprocess.run(
            [
                str(BLENDER),
                "--factory-startup",
                "--background",
                "--python",
                str(RENDERER),
                "--",
                family,
                asset_id,
            ],
            capture_output=True,
            text=True,
            timeout=TIMEOUT_S,
            env=environment,
        )
        code = proc.returncode
        tail = ((proc.stdout or "") + (proc.stderr or ""))[-400:]
    except subprocess.TimeoutExpired:
        code, tail = -1, "timeout after %ds" % TIMEOUT_S
    elapsed = time.time() - started

    if report.exists():
        with report.open(encoding="utf-8") as handle:
            data = json.load(handle)
        report.unlink()
        frames = data.get("families", {}).get(family, {}).get("frame_list", [])
        errors = data.get("errors", [])
        if frames:
            print(
                "  ok   %-26s %d frame(s) in %5.1fs" % (asset_id, len(frames), elapsed),
                flush=True,
            )
            return {"frames": frames, "errors": errors}
        return {
            "frames": [],
            "errors": errors
            or [{"family": family, "id": asset_id, "error": "no frame written"}],
        }
    print(
        "  FAIL %-26s exit=%s in %5.1fs  %s"
        % (asset_id, code, elapsed, tail.replace("\n", " ")[-120:]),
        flush=True,
    )
    return {
        "frames": [],
        "errors": [{"family": family, "id": asset_id, "error": "blender exit %s" % code}],
    }


def _selection(args: argparse.Namespace) -> dict[str, list[str]]:
    if args.trial:
        return {family: list(ids) for family, ids in TRIAL_SOURCES.items()}
    return {
        family: sources(family)
        for family in args.families or ["polyhaven_wild", "polyhaven_salvage"]
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Bake Poly Haven wild/salvage sprites in isolated Blender CLI processes."
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument(
        "--trial",
        action="store_true",
        help="Bake only moss_01 and metal_toolbox into the non-runtime trial artifact.",
    )
    mode.add_argument(
        "--production",
        action="store_true",
        help="Explicitly allow a full bake to write atlas-builder inputs under assets/.",
    )
    parser.add_argument(
        "families",
        nargs="*",
        choices=["polyhaven_wild", "polyhaven_salvage"],
        help="Production families to bake with --production; omit to bake both.",
    )
    args = parser.parse_args()
    if args.trial and args.families:
        parser.error("--trial cannot be combined with production family arguments")

    output_root = TRIAL_ARTIFACT_ROOT if args.trial else ENVIRONMENT_ROOT
    validate_output_contract(output_root)
    if not BLENDER.is_file():
        raise RuntimeError("Blender executable is missing: %s" % BLENDER)
    if not RENDERER.is_file():
        raise RuntimeError("Renderer is missing: %s" % RENDERER)
    if args.trial:
        # This verifies root/output/report agreement plus input hashes before a
        # Blender process spends time importing even the lightweight smoke set.
        from validate_wild_bake_contract import validate_preflight

        validate_preflight()

    selected = _selection(args)
    known = {family: set(sources(family)) for family in selected}
    for family, ids in selected.items():
        unknown = sorted(set(ids).difference(known[family]))
        if unknown:
            raise RuntimeError("Unknown %s source(s): %s" % (family, unknown))

    output_root.mkdir(parents=True, exist_ok=True)
    merged = {
        "schema_version": 1,
        "mode": "trial" if args.trial else "production",
        "output_root": str(output_root.relative_to(PROJECT_ROOT)).replace(os.sep, "/"),
        "frame_size": 256,
        "families": {},
        "errors": [],
        "sharded": "one Blender --factory-startup process per source",
    }
    started = time.time()
    for family, ids in selected.items():
        print("[wild] %s: %d source(s)" % (family, len(ids)), flush=True)
        frames = []
        for asset_id in ids:
            result = run_one(family, asset_id, output_root)
            frames.extend(result["frames"])
            merged["errors"].extend(result["errors"])
        merged["families"][family] = {
            "output_dir": str((output_root / family).relative_to(PROJECT_ROOT)).replace(
                os.sep, "/"
            ),
            "source_manifest": "tools/art/blender/vault/%s/_fetch_manifest.json" % family,
            "license": "CC0-1.0",
            "license_url": "https://polyhaven.com/license",
            "source_ids": ids,
            "sources": len(ids),
            "frames": len(frames),
            "frame_list": frames,
        }
        print(
            "[wild] %s -> %d frame(s) from %d source(s)" % (family, len(frames), len(ids)),
            flush=True,
        )
    merged["seconds"] = round(time.time() - started, 1)
    path = report_path(output_root)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(merged, handle, indent=1)
    print(
        "[wild] %d error(s) in %.1fs -> %s"
        % (len(merged["errors"]), merged["seconds"], path),
        flush=True,
    )
    if merged["errors"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
