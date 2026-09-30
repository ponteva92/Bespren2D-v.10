"""Measure how much of each baked actor cell the actor actually occupies.

The bake frames every clip of an actor with one shared camera so the figure
cannot breathe between animations. That is correct, but the first version
sized the shared frame from the union of *all* clips, and `death` lays the
body flat: at a diagonal heading a fallen skeleton projects roughly twice as
wide as the same skeleton standing. Every idle, walk and run frame therefore
inherited a cell scaled for a pose the player sees for half a second, and the
figure that is on screen the whole match resolved from about twenty pixels.

This tool measures the real content bounds cell by cell, so the framing
argument is settled by pixels instead of by bound_box guesses. Everything is
expressed as a half-extent from the cell centre, because the cell centre is
the one point every clip of an actor shares: the bake locks camera position
and ortho scale, so a given world point lands on the same fractional cell
coordinate in every sheet. That is what lets clips take different cell sizes
while a single `AnimatedSprite2D.offset` still puts every animation's feet in
the same place - a symmetric expansion around a common centre moves the
frame edges, never the centre.

Usage:
    python tools/art/validate_actor_fill.py [--json out.json]
"""

import argparse
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(os.path.dirname(HERE))
SHEETS = os.path.join(PROJECT, "assets", "2d", "actors", "sheets")
MANIFEST = os.path.join(SHEETS, "sheet_manifest.json")

# Clips the player reads continuously. The shared framing is sized from these
# and these only; one-shot poses are allowed a wider cell of their own.
GAMEPLAY_CLIPS = ("idle", "walk", "run", "attack", "hit", "gather", "shoot")

# Cell sizes the packer may emit. Must stay in step with `run_actor_bake.py`,
# which owns the reasoning: eight-pixel rungs, because the old power-of-two
# ladder spent 29% of the sheet budget rounding clips up to the next rung.
CELL_LADDER = tuple(range(40, 257, 8))

# Mirrors `run_actor_bake.py`. Kept here so this script can report the cells the
# next bake will actually choose, rather than a second opinion about them.
CELL_HEADROOM = 1.12

# Fraction of the half-cell the gameplay envelope is allowed to reach. The
# remainder absorbs the Freestyle outline, which is drawn outside the mesh
# silhouette and so is not present in the bound_box the bake measures.
TARGET_FILL = 0.92

ALPHA_FLOOR = 8


def cell_extents(sheet_path, rows, cols, cell):
	"""Half-extents (left, right, top, bottom) in px from each cell's centre."""
	image = Image.open(sheet_path).convert("RGBA")
	alpha = image.split()[3]
	half = cell / 2.0
	worst = [0.0, 0.0, 0.0, 0.0]
	filled = 0
	for row in range(rows):
		for col in range(cols):
			box = (col * cell, row * cell, (col + 1) * cell, (row + 1) * cell)
			region = alpha.crop(box)
			bounds = region.point(lambda v: 255 if v >= ALPHA_FLOOR else 0).getbbox()
			if bounds is None:
				continue
			filled += 1
			x0, y0, x1, y1 = bounds
			worst[0] = max(worst[0], half - x0)
			worst[1] = max(worst[1], x1 - half)
			worst[2] = max(worst[2], half - y0)
			worst[3] = max(worst[3], y1 - half)
	return worst, filled


def ladder_cell(required):
	for candidate in CELL_LADDER:
		if candidate >= required - 0.5:
			return candidate
	return CELL_LADDER[-1]


def main():
	parser = argparse.ArgumentParser()
	# Default to the path `run_actor_bake.py` reads. An empty default meant a
	# plain run printed a table and wrote nothing, so the bake silently planned
	# from whatever stale report happened to be on disk.
	parser.add_argument("--json", dest="json_out",
	                    default=os.path.join(PROJECT, "build", "actor_bake",
	                                         "actor_fill_report.json"))
	args = parser.parse_args()

	# Every half-extent below is in pixels, and pixels only mean something
	# alongside the density that produced them. Recording it is what makes this
	# report safe to regenerate: a consumer scales by the ratio of the density it
	# is baking at to the density here, so measuring freshly-baked sheets and
	# re-baking is a no-op rather than a second doubling.
	# Read it from the camera that actually rendered the frames - cell divided by
	# the ortho extent it saw - and not from the tier's nominal `density` field.
	# Those two disagreed: the old bake multiplied by PAD when it chose the tier
	# span and `apply_shared_camera` multiplied by PAD again, so the tier claimed
	# 15.00 px/unit while the pixels landed at 14.15. Taking the number off the
	# camera makes this report describe the sheets as rendered whatever the
	# driver believed it was doing.
	densities = {}
	bake_report = os.path.join(PROJECT, "build", "actor_bake", "actor_bake_report.json")
	if os.path.exists(bake_report):
		baked = json.load(open(bake_report, "r", encoding="utf-8"))
		seen = {}
		for record in baked.get("actors", []):
			ortho = float(record.get("camera", {}).get("ortho_scale", 0.0))
			if ortho <= 0.0:
				continue
			seen.setdefault(record["actor"], []).append(
				float(record["cell"]) / ortho)
		for name, found in seen.items():
			spread = max(found) - min(found)
			if spread > 1e-3:
				print("  ! %s rendered at %d densities (%.4f..%.4f) - its clips "
				      "cannot share one offset" % (name, len(set(found)),
				      min(found), max(found)))
			densities[name] = sum(found) / len(found)

	entries = json.load(open(MANIFEST, "r", encoding="utf-8"))
	actors = {}
	for entry in entries:
		name = os.path.basename(entry["out"].replace("\\", "/"))
		path = os.path.join(SHEETS, name)
		if not os.path.exists(path):
			print("MISSING SHEET %s" % name)
			return 1
		worst, filled = cell_extents(path, entry["rows"], entry["cols"], entry["cell"])
		cell = float(entry["cell"])
		# Symmetric half-extent: the cell must hold the worst side on both
		# sides, or the shared centre stops being the shared centre.
		half = max(worst)
		# Cells are per clip now, so an actor has no single cell. Track the
		# widest for reporting; every ratio below is against the clip's own.
		record = actors.setdefault(entry["actor"], {"cell": 0, "clips": {}})
		record["cell"] = max(record["cell"], entry["cell"])
		record["clips"][entry["clip"]] = {
			"cell": entry["cell"],
			"half_extent": round(half, 2),
			"required_cell": round(half * 2.0, 2),
			"fill": round(half * 2.0 / cell, 4),
			"cells": filled,
		}

	report = {"target_fill": TARGET_FILL, "actors": {}}
	print("%-22s %6s %8s %8s %8s  %s" % (
		"actor", "cell", "play", "widest", "margin", "widest clip"))
	print("-" * 72)
	for name in sorted(actors):
		info = actors[name]
		cell = float(info["cell"])
		clips = info["clips"]
		play = [c for c in clips if c in GAMEPLAY_CLIPS]
		play_half = max(clips[c]["half_extent"] for c in play)
		widest = max(clips, key=lambda c: clips[c]["half_extent"])
		widest_half = clips[widest]["half_extent"]
		# The plan the *bake* would choose, using the bake's own formula, so
		# this preview and the next run cannot disagree. Density is already at
		# its fixed point, so there is no ratio left to apply here.
		plan = {}
		for clip, data in clips.items():
			plan[clip] = ladder_cell(data["half_extent"] * 2.0 * CELL_HEADROOM)
		# The only number that can fail: how much of its own cell the tightest
		# clip leaves unused. Below 1.0 the pose is cut off; below CELL_HEADROOM
		# the next bake has less room than the drift already measured.
		margin = min(c["cell"] / max(c["half_extent"] * 2.0, 1e-6)
		             for c in clips.values())
		report["actors"][name] = {
			"cell": info["cell"],
			"measured_density": densities.get(name, 0.0),
			"gameplay_fill": round(play_half * 2.0 / cell, 4),
			"union_fill": round(widest_half * 2.0 / cell, 4),
			"widest_clip": widest,
			"margin": round(margin, 4),
			"clips": clips,
			"planned_cells": plan,
		}
		print("%-22s %6d %7.1f%% %7.1f%% %7.3fx  %s" % (
			name, info["cell"], play_half * 200.0 / cell,
			widest_half * 200.0 / cell, margin, widest))

	print()
	print("planned cells per clip (at the new density):")
	for name in sorted(report["actors"]):
		plan = report["actors"][name]["planned_cells"]
		order = sorted(plan, key=lambda c: (-plan[c], c))
		print("  %-22s %s" % (name, "  ".join(
			"%s:%d" % (c, plan[c]) for c in order)))

	now = sum(e["size"][0] * e["size"][1] for e in entries)
	after = 0
	for entry in entries:
		plan = report["actors"][entry["actor"]]["planned_cells"][entry["clip"]]
		scale = plan / float(entry["cell"])
		after += (entry["size"][0] * scale) * (entry["size"][1] * scale)
	print()
	print("sheet pixels: %.2f Mpx now -> %.2f Mpx planned (%.2fx)"
	      % (now / 1e6, after / 1e6, after / now))

	# A clip whose content is wider than its cell has already lost pixels off
	# the edge, and no later stage can tell - the packer sees a full cell and
	# the sheet looks correct. This is the one condition worth exiting on.
	clipped = []
	thin = []
	for name in sorted(report["actors"]):
		for clip, data in report["actors"][name]["clips"].items():
			if data["fill"] > 1.0:
				clipped.append((name, clip, data["fill"]))
			elif data["cell"] < data["half_extent"] * 2.0 * CELL_HEADROOM:
				thin.append((name, clip, data["cell"]
				             / (data["half_extent"] * 2.0)))
	for name, clip, ratio in thin:
		print("  ! %s %s has %.3fx of its content, under the %.2fx the next "
		      "bake assumes" % (name, clip, ratio, CELL_HEADROOM))
	if clipped:
		for name, clip, fill in clipped:
			print("CLIPPED %s %s fills %.1f%% of its cell" % (name, clip,
			                                                 fill * 100.0))
		print("ACTOR FILL FAILED (%d clipped)" % len(clipped))
		return 1
	print("ACTOR FILL OK (%d clips, %d thin, margin >= %.3fx)" % (
		len(entries), len(thin),
		min(report["actors"][n]["margin"] for n in report["actors"])))

	if args.json_out:
		json.dump(report, open(args.json_out, "w", encoding="utf-8"), indent="\t")
		print("wrote %s" % args.json_out)
	return 0


if __name__ == "__main__":
	sys.exit(main())
