"""Create compact all-clip review grids for staged Carrier and Splitter bakes.

Each grid samples the first, midpoint, and last pose of four cardinal rows from
every animation.  The paired layout makes geometry drift apparent while the
runtime fixture separately proves the full 56-animation SpriteFrames contract.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


PROJECT_ROOT = Path(__file__).resolve().parents[2]
LIVE_ROOT = PROJECT_ROOT / "assets" / "2d" / "actors" / "sheets"
STAGE_ROOT = PROJECT_ROOT / "build" / "boss_body_rebake_loop_f_20260916"
OUTPUT_ROOT = PROJECT_ROOT / "artifacts" / "enemy_body_rebake_candidate_validation"
CLIPS = ("idle", "walk", "attack", "hit", "death", "spawn", "taunt")
CARDINAL_ROWS = (0, 2, 4, 6)
THUMB = 34
HEADER = 18
LABEL = 38
GUTTER = 8


def _sheet(subject: str, clip: str, staged: bool) -> tuple[Image.Image, int, int]:
    root = STAGE_ROOT / (subject + "_sheets") if staged else LIVE_ROOT
    path = root / ("enemy_" + subject + "_" + clip + ".png")
    with Image.open(path) as image:
        rgba = image.convert("RGBA")
        if rgba.height % 8 != 0:
            raise RuntimeError("Sheet lacks eight directional rows: %s" % path)
        cell = rgba.height // 8
        if rgba.width % cell != 0:
            raise RuntimeError("Sheet cell geometry is invalid: %s" % path)
        return rgba.copy(), cell, rgba.width // cell


def _card(subject: str, clip: str, staged: bool) -> Image.Image:
    source, cell, columns = _sheet(subject, clip, staged)
    card_width = THUMB * 3
    card = Image.new("RGBA", (card_width, THUMB * len(CARDINAL_ROWS)), (17, 20, 18, 255))
    samples = (0, columns // 2, columns - 1)
    for row_index, direction in enumerate(CARDINAL_ROWS):
        for sample_index, column in enumerate(samples):
            frame = source.crop((column * cell, direction * cell, (column + 1) * cell, (direction + 1) * cell))
            frame.thumbnail((THUMB, THUMB), Image.Resampling.LANCZOS)
            x = sample_index * THUMB + (THUMB - frame.width) // 2
            y = row_index * THUMB + (THUMB - frame.height) // 2
            card.alpha_composite(frame, (x, y))
    return card


def _make(subject: str) -> Path:
    font = ImageFont.load_default()
    card_width = THUMB * 3
    row_height = THUMB * len(CARDINAL_ROWS) + HEADER
    sheet = Image.new(
        "RGBA",
        (LABEL + card_width * 2 + GUTTER * 3, HEADER + (row_height + GUTTER) * len(CLIPS) + GUTTER),
        (8, 11, 9, 255),
    )
    draw = ImageDraw.Draw(sheet)
    draw.text((LABEL + GUTTER, 4), "LIVE", fill=(218, 202, 162, 255), font=font)
    draw.text((LABEL + card_width + GUTTER * 2, 4), "LOOP F", fill=(218, 202, 162, 255), font=font)
    for row, clip in enumerate(CLIPS):
        y = HEADER + GUTTER + row * (row_height + GUTTER)
        draw.text((4, y + 4), clip.upper(), fill=(207, 216, 202, 255), font=font)
        sheet.alpha_composite(_card(subject, clip, False), (LABEL + GUTTER, y))
        sheet.alpha_composite(_card(subject, clip, True), (LABEL + card_width + GUTTER * 2, y))
    output = OUTPUT_ROOT / (subject + "_animation_sample_grid.png")
    sheet.save(output)
    return output


def main() -> int:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    outputs = [_make("carrier"), _make("splitter")]
    print("ACTOR ANIMATION SAMPLE GRID OK | outputs=%s" % ",".join(str(path) for path in outputs))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
