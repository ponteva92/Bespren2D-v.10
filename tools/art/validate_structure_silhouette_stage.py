"""Offline preflight for the isolated Loop H defense-silhouette bake.

This is intentionally *not* a gameplay acceptance test.  It compares the
transparent source masks at the same tiny screen proxy used for the visual
review and makes sure the staging directory has no path into the runtime.  A
passing report permits a human / Godot context review; it never promotes the
candidate PNGs into ``assets/2d/structures``.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


HERE = Path(__file__).resolve().parent
PROJECT_ROOT = HERE.parent.parent
LIVE_ROOT = PROJECT_ROOT / "assets" / "2d" / "structures"
DEFAULT_STAGE = PROJECT_ROOT / "build" / "structure_silhouette_loop_h_20260917"
NAMES = ("kinetic", "chemical", "electric", "landmine", "slowing_pit")
PAIR_GATES = {
    ("landmine", "slowing_pit"): 0.68,
    ("kinetic", "chemical"): 0.86,
    ("kinetic", "electric"): 0.86,
    ("chemical", "electric"): 0.86,
}
CANVAS_SIZE = (320, 320)
PROXY_SIZE = (48, 48)
ALPHA_THRESHOLD = 20


def _alpha_mask(path: Path) -> Image.Image:
    with Image.open(path) as image:
        rgba = image.convert("RGBA")
        if rgba.size != CANVAS_SIZE:
            raise RuntimeError("Unexpected canvas size for %s: %s" % (path, rgba.size))
        return rgba.getchannel("A").copy()


def _mask_metrics(mask: Image.Image) -> dict[str, float | int | list[int]]:
    bounds = mask.getbbox()
    if bounds is None:
        raise RuntimeError("Candidate has no visible alpha")
    pixels = mask.load()
    visible = 0
    for y in range(mask.height):
        for x in range(mask.width):
            if pixels[x, y] > ALPHA_THRESHOLD:
                visible += 1
    left, top, right, bottom = bounds
    width = right - left
    height = bottom - top
    return {
        "alpha_bbox": [left, top, right, bottom],
        "alpha_bbox_width_px": width,
        "alpha_bbox_height_px": height,
        "alpha_visible_px": visible,
        "alpha_coverage": visible / float(mask.width * mask.height),
        "alpha_bbox_density": visible / float(max(1, width * height)),
    }


def _tiny_binary(mask: Image.Image) -> set[tuple[int, int]]:
    reduced = mask.resize(PROXY_SIZE, Image.Resampling.LANCZOS)
    pixels = reduced.load()
    return {
        (x, y)
        for y in range(reduced.height)
        for x in range(reduced.width)
        if pixels[x, y] > ALPHA_THRESHOLD
    }


def _jaccard(first: set[tuple[int, int]], second: set[tuple[int, int]]) -> float:
    union = first | second
    if not union:
        raise RuntimeError("Cannot compare empty silhouettes")
    return len(first & second) / float(len(union))


def _load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA").copy()


def _to_grayscale_rgba(image: Image.Image) -> Image.Image:
    grayscale = image.convert("L")
    result = Image.merge("RGBA", (grayscale, grayscale, grayscale, image.getchannel("A")))
    return result


def _contact_sheet(stage: Path) -> Path:
    cell_width, cell_height = 156, 112
    sheet = Image.new("RGBA", (cell_width * 2, cell_height * len(NAMES)), (10, 13, 12, 255))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for row, name in enumerate(NAMES):
        live = _load_rgba(LIVE_ROOT / ("structure_t1_" + name + ".png"))
        candidate = _load_rgba(stage / ("structure_t1_" + name + ".png"))
        # A 96px source proxy approximates the 0.30 world sprite scale.  The
        # adjacent monochrome strip makes silhouette drift readable even when
        # palette differences are attractive but semantically misleading.
        for column, (label, image) in enumerate((("LIVE", live), ("LOOP H", candidate))):
            card = Image.new("RGBA", (cell_width, cell_height), (16, 20, 18, 255))
            preview = image.resize((86, 86), Image.Resampling.LANCZOS)
            gray = _to_grayscale_rgba(image).resize((36, 36), Image.Resampling.LANCZOS)
            card.alpha_composite(preview, (8, 18))
            card.alpha_composite(gray, (108, 54))
            card_draw = ImageDraw.Draw(card)
            card_draw.text((6, 4), "%s  %s" % (name.upper(), label), fill=(224, 214, 183, 255), font=font)
            sheet.alpha_composite(card, (column * cell_width, row * cell_height))
    output = stage / "structure_silhouette_loop_h_contact.png"
    sheet.save(output)
    return output


def _validate_runtime_exclusion(stage: Path) -> bool:
    stage_token = stage.resolve().relative_to(PROJECT_ROOT.resolve()).as_posix()
    for root in (PROJECT_ROOT / "src", PROJECT_ROOT / "scenes", PROJECT_ROOT / "data"):
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if not path.is_file() or path.suffix.lower() not in {".gd", ".tscn", ".json", ".tres", ".res"}:
                continue
            if stage_token in path.read_text(encoding="utf-8", errors="ignore").replace("\\", "/"):
                raise RuntimeError("Staging path leaked into runtime source: %s" % path)
    return True


def run(stage: Path) -> dict[str, object]:
    stage = stage.resolve()
    if not stage.is_dir() or PROJECT_ROOT / "build" not in stage.parents:
        raise RuntimeError("Stage must be a directory below build/: %s" % stage)
    source_masks: dict[str, Image.Image] = {}
    candidate_masks: dict[str, Image.Image] = {}
    metrics: dict[str, dict[str, dict[str, float | int | list[int]]]] = {}
    for name in NAMES:
        filename = "structure_t1_" + name + ".png"
        live_path = LIVE_ROOT / filename
        candidate_path = stage / filename
        if not live_path.is_file() or not candidate_path.is_file():
            raise RuntimeError("Missing live or candidate render: %s" % filename)
        source_masks[name] = _alpha_mask(live_path)
        candidate_masks[name] = _alpha_mask(candidate_path)
        metrics[name] = {
            "live": _mask_metrics(source_masks[name]),
            "candidate": _mask_metrics(candidate_masks[name]),
        }
        candidate_coverage = float(metrics[name]["candidate"]["alpha_coverage"])
        live_coverage = float(metrics[name]["live"]["alpha_coverage"])
        if candidate_coverage < live_coverage * 0.38 or candidate_coverage > live_coverage * 1.80:
            raise RuntimeError("%s candidate coverage escaped a mobile-safe envelope" % name)
    pairwise: dict[str, dict[str, float | bool]] = {}
    for (left, right), maximum in PAIR_GATES.items():
        live_similarity = _jaccard(_tiny_binary(source_masks[left]), _tiny_binary(source_masks[right]))
        candidate_similarity = _jaccard(_tiny_binary(candidate_masks[left]), _tiny_binary(candidate_masks[right]))
        if candidate_similarity > maximum:
            raise RuntimeError("%s/%s candidate Jaccard %.4f exceeds %.4f" % (left, right, candidate_similarity, maximum))
        if candidate_similarity >= live_similarity:
            raise RuntimeError("%s/%s silhouette did not improve" % (left, right))
        pairwise[left + "__" + right] = {
            "live_jaccard_48px": live_similarity,
            "candidate_jaccard_48px": candidate_similarity,
            "maximum_candidate_jaccard": maximum,
            "improved": candidate_similarity < live_similarity,
        }
    contact = _contact_sheet(stage)
    return {
        "scope": "offline source-mask preflight only; no runtime asset promotion",
        "stage": stage.relative_to(PROJECT_ROOT).as_posix(),
        "proxy": {"source_canvas_px": list(CANVAS_SIZE), "world_scale": 0.30, "mask_proxy_px": list(PROXY_SIZE)},
        "alpha_threshold": ALPHA_THRESHOLD,
        "assets": metrics,
        "pairwise": pairwise,
        "runtime_staging_path_excluded": _validate_runtime_exclusion(stage),
        "contact_sheet": contact.relative_to(PROJECT_ROOT).as_posix(),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage", type=Path, default=DEFAULT_STAGE)
    args = parser.parse_args()
    report = run(args.stage)
    report_path = args.stage / "structure_silhouette_loop_h_report.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("STRUCTURE SILHOUETTE STAGE OK | pairs=%d | report=%s" % (len(PAIR_GATES), report_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
