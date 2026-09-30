"""Safely promote the reviewed Loop F Carrier/Splitter sheets.

The operation is deliberately narrow: it accepts only the fourteen existing
actor-sheet paths, snapshots the previous PNGs beneath build/, writes each new
PNG through a sibling temporary path, and records hashes/sizes.  It never
touches scenes, catalogs, exports, animations, or source-vault assets.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image


HERE = Path(__file__).resolve().parent
PROJECT_ROOT = HERE.parent.parent
DEFAULT_STAGE = PROJECT_ROOT / "build" / "boss_body_rebake_loop_f_20260916"
DESTINATION = PROJECT_ROOT / "assets" / "2d" / "actors" / "sheets"
SUBJECTS = ("carrier", "splitter")
CLIPS = ("idle", "walk", "attack", "hit", "death", "spawn", "taunt")


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _size(path: Path) -> tuple[int, int]:
    with Image.open(path) as image:
        return image.size


def _targets(stage: Path) -> list[tuple[str, str, Path, Path]]:
    result: list[tuple[str, str, Path, Path]] = []
    for subject in SUBJECTS:
        source_dir = stage / (subject + "_sheets")
        for clip in CLIPS:
            name = "enemy_%s_%s.png" % (subject, clip)
            result.append((subject, clip, source_dir / name, DESTINATION / name))
    return result


def _validate(stage: Path) -> list[dict[str, object]]:
    if not stage.is_dir() or PROJECT_ROOT / "build" not in stage.parents:
        raise RuntimeError("Stage must be a project build/ directory: %s" % stage)
    if not DESTINATION.is_dir():
        raise RuntimeError("Production actor-sheet directory is missing")
    records: list[dict[str, object]] = []
    for subject, clip, candidate, live in _targets(stage):
        if not candidate.is_file() or not live.is_file():
            raise RuntimeError("Missing candidate or live sheet: %s / %s" % (candidate, live))
        candidate_size = _size(candidate)
        live_size = _size(live)
        if candidate_size != live_size:
            raise RuntimeError("Cell/sheet geometry changed for %s: %s != %s" % (live.name, candidate_size, live_size))
        candidate_hash = _sha256(candidate)
        live_hash = _sha256(live)
        if candidate_hash == live_hash:
            raise RuntimeError("Candidate did not change %s" % live.name)
        records.append({
            "subject": subject,
            "clip": clip,
            "filename": live.name,
            "size": list(candidate_size),
            "candidate_sha256": candidate_hash,
            "live_before_sha256": live_hash,
        })
    if len(records) != len(SUBJECTS) * len(CLIPS):
        raise RuntimeError("Unexpected promotion target count")
    return records


def _apply(stage: Path, records: list[dict[str, object]], backup_root: Path) -> None:
    backup_root.mkdir(parents=True, exist_ok=False)
    for _subject, _clip, candidate, live in _targets(stage):
        backup = backup_root / live.name
        shutil.copy2(live, backup)
        temporary = live.with_name(live.name + ".loop_f_candidate.tmp")
        if temporary.exists():
            raise RuntimeError("Refusing to overwrite unexpected temporary file: %s" % temporary)
        shutil.copy2(candidate, temporary)
        os.replace(temporary, live)
    for record in records:
        live = DESTINATION / str(record["filename"])
        live_after = _sha256(live)
        if live_after != str(record["candidate_sha256"]):
            raise RuntimeError("Post-promotion hash mismatch for %s" % live.name)
        record["live_after_sha256"] = live_after


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage", type=Path, default=DEFAULT_STAGE)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    stage = args.stage.resolve()
    records = _validate(stage)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup_root = PROJECT_ROOT / "build" / "promotions" / ("boss_body_loop_f_" + timestamp)
    report: dict[str, object] = {
        "scope": "Carrier/Splitter actor sheet paths only",
        "stage": stage.relative_to(PROJECT_ROOT).as_posix(),
        "destination": DESTINATION.relative_to(PROJECT_ROOT).as_posix(),
        "dry_run": not args.apply,
        "subjects": list(SUBJECTS),
        "clips": list(CLIPS),
        "records": records,
        "backup": backup_root.relative_to(PROJECT_ROOT).as_posix() if args.apply else None,
    }
    if args.apply:
        _apply(stage, records, backup_root)
    report_root = backup_root if args.apply else stage
    if not report_root.exists():
        report_root.mkdir(parents=True, exist_ok=True)
    (report_root / "boss_body_promotion_report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("BOSS BODY PROMOTION %s | sheets=%d | report=%s" % (
        "APPLIED" if args.apply else "DRY RUN OK", len(records), report_root / "boss_body_promotion_report.json"
    ))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
