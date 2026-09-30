"""Pack baked actor frames into runtime sprite sheets.

Blender writes one supersampled PNG per pose; this step downsamples them to
the shipping cell size and lays them out as `rows = 8 compass directions,
columns = animation frames`, which is the layout an AnimatedSprite2D or a
region-stepped Sprite2D can index with two integers.

Runs on the host interpreter, not inside Blender: Blender's bundled Python has
no PIL, and keeping the pack step outside means a sheet can be re-laid-out
without re-rendering anything.
"""

import json
import os
import sys

from PIL import Image


def ground_offset(entry: dict) -> float:
	"""Pixels from the centre of a cell down to the point the actor stands on.

	The bake stands each actor on z = 0, centres it on the world origin, then
	aims one orthographic camera at `centre_y` measured in the camera own up
	axis. So the projected world origin - the feet, not the lowest limb - sits
	`centre_y` camera units below the middle of the frame, and `cell /
	ortho_scale` converts that to pixels.

	Measuring the alpha instead looks equivalent and is not: a death clip lies
	the actor down and an attack clip lunges it forward, so the lowest opaque
	pixel of a sheet set is up to eighteen pixels below the standing point. The
	marker ring, the status arc and the flow field all address the standing
	point, so that is what the sprite has to be pinned to.
	"""
	return float(entry["bounds"]["centre_y"]) * float(entry["cell"]) / float(entry["camera"]["ortho_scale"])


def pack_clip(frame_dir: str, rows: int, cols: int, cell: int, out_path: str) -> dict:
	sheet = Image.new("RGBA", (cols * cell, rows * cell), (0, 0, 0, 0))
	missing = []
	for row in range(rows):
		for col in range(cols):
			src = os.path.join(frame_dir, "r%d_c%d.png" % (row, col))
			if not os.path.isfile(src):
				missing.append(os.path.basename(src))
				continue
			with Image.open(src) as im:
				im = im.convert("RGBA")
				if im.size != (cell, cell):
					im = im.resize((cell, cell), Image.LANCZOS)
				sheet.paste(im, (col * cell, row * cell))
	os.makedirs(os.path.dirname(out_path), exist_ok=True)
	sheet.save(out_path, optimize=True)
	alpha = sheet.getchannel("A")
	bbox = alpha.getbbox()
	return {"out": out_path, "size": sheet.size, "missing": missing,
	        "content_bbox": bbox, "bytes": os.path.getsize(out_path)}


def _backdrop(size: tuple, cell: int) -> Image.Image:
	"""Mid-value checker, not black.

	Reviewing a transparent sprite on charcoal flatters every dark limb into
	invisibility, which is exactly the mistake the first pass made. The two
	tones bracket the terrain values the sprite actually sits on in-game.
	"""
	img = Image.new("RGB", size, (110, 115, 110))
	dark = Image.new("RGB", (cell, cell), (74, 79, 74))
	for y in range(0, size[1], cell):
		for x in range(0, size[0], cell):
			if ((x // cell) + (y // cell)) % 2:
				img.paste(dark, (x, y))
	return img


def row_variation(path: str, rows: int, cols: int, cell: int) -> list:
	"""Mean absolute difference of each direction row against row 0.

	A sheet whose eight rows are identical means the subject never turned, and
	that failure is invisible in a thumbnail of a chibi figure: measure it.
	"""
	import statistics
	with Image.open(path) as im:
		im = im.convert("RGBA")
		base = [im.crop((c * cell, 0, (c + 1) * cell, cell)) for c in range(cols)]
		out = []
		for r in range(rows):
			diffs = []
			for c in range(cols):
				cur = im.crop((c * cell, r * cell, (c + 1) * cell, (r + 1) * cell))
				a, b = cur.tobytes(), base[c].tobytes()
				diffs.append(sum(abs(x - y) for x, y in zip(a, b)) / float(len(a)))
			out.append(round(statistics.mean(diffs), 2))
	return out


def contact_sheet(sheets: list, out_path: str, scale: int = 2) -> list:
	"""Write one reviewable contact sheet per actor, and return their paths.

	This used to stack the whole roster into a single strip. On the full cast
	that is 96,256 px tall, which is past JPEG's 65,535 px limit, so the tool
	failed at the last line after doing all its work. Grouping by actor fixes
	that, and it is also the shape a reviewer wants: one page per character,
	every clip of that character stacked so a cadence or framing defect shows
	up against its neighbours instead of 200 sheets away.

	Sheets are labelled and drawn on the checkered backdrop, because a dark
	sprite on a dark ground reviews as a hole rather than as a silhouette.
	"""
	from collections import OrderedDict
	groups = OrderedDict()
	for path, label in sheets:
		groups.setdefault(label, []).append(path)

	root, ext = os.path.splitext(out_path)
	if ext.lower() in (".jpg", ".jpeg"):
		ext = ".png"
	written = []
	for label, paths in groups.items():
		images = []
		for path in paths:
			with Image.open(path) as im:
				images.append((os.path.basename(path), im.convert("RGBA").copy()))
		width = max(im.width for _, im in images) * scale
		height = sum(im.height for _, im in images) * scale
		out = _backdrop((width, height), 32)
		y = 0
		for _, im in images:
			big = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
			out.paste(big, (0, y), big)
			y += big.height
		target = "%s_%s%s" % (root, label, ext)
		out.convert("RGB").save(target)
		written.append(target)
	return written


def refresh_metadata(report: dict, out_root: str) -> int:
	"""Re-derive the manifest fields that come from the report, not the pixels.

	Repacking is the honest way to change a manifest, but `row_variation`
	compares every byte of every cell in pure Python, so a full run over the
	roster costs hundreds of millions of operations to reproduce sheets that are
	already correct. This path exists for the case where only a derived number
	changed - it touches no PNG, and it refuses to invent an entry that a real
	pack did not write.
	"""
	manifest_path = os.path.join(out_root, "sheet_manifest.json")
	packed = json.load(open(manifest_path, encoding="utf-8"))
	by_key = {(e["actor"], e["clip"]): e for e in packed}
	updated = 0
	for entry in report.get("actors", []):
		if "error" in entry:
			continue
		target = by_key.get((entry["actor"], entry["clip"]))
		if target is None:
			raise SystemExit("no packed sheet for %s %s - run a full pack"
			                 % (entry["actor"], entry["clip"]))
		target["ground_offset"] = round(ground_offset(entry), 4)
		updated += 1
	with open(manifest_path, "w", encoding="utf-8") as fh:
		json.dump(packed, fh, indent=1)
	return updated


def main() -> None:
	args = [a for a in sys.argv[1:] if not a.startswith("--")]
	flags = set(a for a in sys.argv[1:] if a.startswith("--"))
	report_path = args[0]
	out_root = args[1]
	contact = args[2] if len(args) > 2 else None
	report = json.load(open(report_path, encoding="utf-8"))
	if "--metadata-only" in flags:
		print("metadata refreshed for %d sheets" % refresh_metadata(report, out_root))
		return
	packed = []
	for entry in report.get("actors", []):
		if "error" in entry:
			print("SKIP", entry); continue
		name = "%s_%s.png" % (entry["actor"], entry["clip"])
		result = pack_clip(entry["frame_dir"], entry["rows"], entry["cols"],
		                   entry["cell"], os.path.join(out_root, name))
		result.update({"actor": entry["actor"], "clip": entry["clip"],
		               "rows": entry["rows"], "cols": entry["cols"],
		               "cell": entry["cell"],
		               "ground_offset": round(ground_offset(entry), 4)})
		result["row_variation"] = row_variation(result["out"], entry["rows"],
		                                        entry["cols"], entry["cell"])
		packed.append(result)
		print("%-28s %s bbox=%s missing=%d %.1fkB rowvar=%s" % (
			name, result["size"], result["content_bbox"], len(result["missing"]),
			result["bytes"] / 1024.0, result["row_variation"]))
	with open(os.path.join(out_root, "sheet_manifest.json"), "w", encoding="utf-8") as fh:
		json.dump(packed, fh, indent=1)
	if contact and packed:
		for path in contact_sheet([(p["out"], p["actor"]) for p in packed], contact):
			print("contact:", path)


main()
