"""Build a magnified, paired visual review sheet for Loop F boss rebakes.

The source captures come from the real 0.38 Mobile/Vulkan candidate fixture.
This helper only crops and labels those already-produced artifacts; it never
alters a runtime sheet or candidate render.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCE = PROJECT_ROOT / "artifacts" / "enemy_body_rebake_candidate_validation"
OUTPUT = SOURCE / "boss_body_rebake_loop_f_review_sheet.png"
ROI = (255, 64, 356, 175)
SCALE = 4
ROWS = (
    ("CARRIER / DAY", "carrier_day_baseline_body_only.png", "carrier_day_candidate_body_only.png"),
    ("CARRIER / NIGHT GRAYSCALE", "carrier_night_baseline_body_only_grayscale.png", "carrier_night_candidate_body_only_grayscale.png"),
    ("SPLITTER / DAY", "splitter_day_baseline_body_only.png", "splitter_day_candidate_body_only.png"),
    ("SPLITTER / NIGHT GRAYSCALE", "splitter_night_baseline_body_only_grayscale.png", "splitter_night_candidate_body_only_grayscale.png"),
)


def _crop(name: str) -> Image.Image:
    path = SOURCE / name
    with Image.open(path) as image:
        if image.size != (480, 270):
            raise RuntimeError("Unexpected capture size for %s: %s" % (path, image.size))
        return image.convert("RGBA").crop(ROI).resize(
            ((ROI[2] - ROI[0]) * SCALE, (ROI[3] - ROI[1]) * SCALE),
            Image.Resampling.NEAREST,
        )


def main() -> int:
    font = ImageFont.load_default()
    crop_width, crop_height = (ROI[2] - ROI[0]) * SCALE, (ROI[3] - ROI[1]) * SCALE
    gutter, label_height = 12, 22
    sheet = Image.new(
        "RGBA",
        (crop_width * 2 + gutter * 3, (crop_height + label_height + gutter) * len(ROWS) + gutter),
        (9, 12, 10, 255),
    )
    draw = ImageDraw.Draw(sheet)
    for row, (label, baseline_name, candidate_name) in enumerate(ROWS):
        y = gutter + row * (crop_height + label_height + gutter)
        draw.text((gutter, y), label + "  LIVE", fill=(214, 200, 160, 255), font=font)
        draw.text((crop_width + gutter * 2, y), label + "  LOOP F", fill=(214, 200, 160, 255), font=font)
        sheet.alpha_composite(_crop(baseline_name), (gutter, y + label_height))
        sheet.alpha_composite(_crop(candidate_name), (crop_width + gutter * 2, y + label_height))
    sheet.save(OUTPUT)
    print("BOSS BODY REBAKE REVIEW SHEET OK | output=%s" % OUTPUT)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
