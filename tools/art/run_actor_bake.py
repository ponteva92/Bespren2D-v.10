"""Headless driver: bake Bespren's animated actor sheets.

Run with the console Blender so the bake is not bound by the live MCP
session's timeout, e.g.

    blender --background --python tools/art/run_actor_bake.py -- full out_dir

The roster is the game's actual cast and nothing else: the two survivors from
`StartMenu`, and the eight `EnemyAgent2D.Variant` slots the horde spawns. Each
body is authored directly onto the CC0 KayKit skeleton by `build_actor_body`,
so all 119 clips drive it by construction.

Two earlier versions of this file are worth remembering, because both failed
in ways that stay invisible until the sheets are on screen. The first baked
KayKit's own mannequin recoloured per actor - one chibi body in fourteen paint
jobs, which can never satisfy the pillar that Heikki and Shane read as
different silhouettes before any detail resolves. The second baked the authored
`testi` library, which does carry a real silhouette for Heikki - and ships Shane
as a cone with a sphere on top, and every enemy and boss as an untextured
boulder. Fitting a skeleton to a boulder yields a boulder-shaped skeleton.

The rig itself lives in aaa_bake_rig.py; this file declares the roster,
resolves the two size tiers, and reports what was produced.
"""

import json
import os
import sys
import time
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
	sys.path.insert(0, HERE)
PROJECT = os.path.dirname(os.path.dirname(HERE))

import aaa_bake_rig as rig
import bake_animated_actor as actor
import build_actor_body as body

C = actor.ActorClip

# Clip vocabulary. Each group is one KayKit glTF, imported for its actions
# only, so a roster member costs one import per group it draws from.
HERO_GROUPS = ["General", "MovementBasic", "MovementAdvanced",
               "CombatRanged", "Tools"]
UNDEAD_GROUPS = ["Special", "General", "CombatMelee"]

# Both survivors bake the same verb set - the co-op HUD promises identical
# affordances - but not the same clips. Heikki carries a rifle two-handed and
# Shane a pistol, and each run clip matches the weapon the body is holding.
HEIKKI_CLIPS = [
	C("idle", "Idle_A", 4),
	C("walk", "Walking_A", 6),
	C("run", "Running_HoldingRifle", 6),
	C("shoot", "Ranged_2H_Shooting", 4),
	C("gather", "Chopping", 6),
	C("hit", "Hit_A", 4, loop=False),
	C("death", "Death_A", 6, loop=False),
]
SHANE_CLIPS = [
	C("idle", "Idle_A", 4),
	C("walk", "Walking_A", 6),
	C("run", "Running_HoldingBow", 6),
	C("shoot", "Ranged_1H_Shooting", 4),
	C("gather", "Chopping", 6),
	C("hit", "Hit_A", 4, loop=False),
	C("death", "Death_A", 6, loop=False),
]
# The horde reads through cadence, not through pose variety: KayKit's skeleton
# set already moves at the shamble the enemy design calls for, and the spawn
# clip is what lets a wave rise out of the ground instead of popping in.
#
# Two of that set are unusable here and it is worth saying why, because their
# names are exactly what a reader would reach for. `Skeletons_Death` and
# `Skeletons_Awaken_Floor` animate a skeleton coming apart and reassembling:
# they translate individual bones metres away from the body. On KayKit's own
# mannequin that reads as a pile of bones. On a body whose shells are bound
# rigidly per bone it reads as a person bursting into disconnected boxes, and
# it cost the sheet twice over - the render is broken, and the measuring pass
# unioned the debris field into the shared camera and shrank every other
# sprite to a third of its size. `Death_B` and `Skeletons_Awaken_Standing`
# carry the same beats and hold the figure together, and `Death_B` has the
# side benefit that the horde does not die in the survivors' exact pose.
UNDEAD_CLIPS = [
	C("idle", "Skeletons_Idle", 4),
	C("walk", "Skeletons_Walking", 6),
	C("attack", "Melee_Unarmed_Attack_Punch_A", 4, loop=False),
	C("hit", "Hit_A", 4, loop=False),
	C("death", "Death_B", 6, loop=False),
	C("spawn", "Skeletons_Awaken_Standing", 6, loop=False),
]
BOSS_CLIPS = UNDEAD_CLIPS + [C("taunt", "Skeletons_Taunt", 6, loop=False)]

# actor id, build_actor_body key, KayKit groups, clips, tier.
#
# The ids are the names the Godot side loads, and the enemy order is the
# declaration order of `EnemyAgent2D.Variant`, so a variant index and a sheet
# cannot drift apart while someone edits one list and not the other.
ROSTER = [
	("hero_heikki", "hero_heikki", HERO_GROUPS, HEIKKI_CLIPS, "actor"),
	("hero_shane", "hero_shane", HERO_GROUPS, SHANE_CLIPS, "actor"),

	("enemy_walker", "walker", UNDEAD_GROUPS, UNDEAD_CLIPS, "actor"),
	("enemy_rat_swarm", "rat_swarm", UNDEAD_GROUPS, UNDEAD_CLIPS, "actor"),
	("enemy_static_walker", "static_walker", UNDEAD_GROUPS, UNDEAD_CLIPS, "actor"),
	("enemy_scrap_shield", "scrap_shield", UNDEAD_GROUPS, UNDEAD_CLIPS, "actor"),
	("enemy_goliath", "goliath", UNDEAD_GROUPS, BOSS_CLIPS, "boss"),
	("enemy_carrier", "carrier", UNDEAD_GROUPS, BOSS_CLIPS, "boss"),
	("enemy_splitter", "splitter", UNDEAD_GROUPS, BOSS_CLIPS, "boss"),
	("enemy_overlord", "overlord", UNDEAD_GROUPS, BOSS_CLIPS, "boss"),
]

# Cell size per tier. Bosses do not get a bigger cell so they can be drawn
# bigger - they get one so they can be drawn at the same pixel density as
# everyone else while still being twice as tall. Sharing a 64 px cell would
# either crop the goliath or shrink every survivor to fit beside it.
TIER_CELL = {"actor": 64, "boss": 128}
# Eight-pixel rungs, not powers of two plus midpoints. The coarse ladder made a
# clip needing 65 px pay for 96 - a 2.18x area penalty at the worst boundary,
# and 29% of the whole sheet budget across the roster. Nothing downstream wants
# a power of two: sheets are already cell*cols by cell*rows and so already
# non-square, and ETC2 only asks that a cell divide into 4x4 blocks, which every
# multiple of 8 does. Measured over the current roster this alone returns
# 8.4 Mpx, which is most of what the density increase cost.
CELL_LADDER = list(range(40, 257, 8))
PAD = 1.06

# Per-clip framing at one shared density.
#
# The bake locks one camera per actor so the figure cannot breathe between
# animations, which is right. Sizing that lock from the union of *every* clip
# is not. `death` lays the body flat, and at a diagonal heading a fallen
# skeleton projects about twice as wide as a standing one, so the death pose
# alone decided the cell that idle, walk and run had to live inside. Measured
# on the shipped sheets: Heikki's death fills 81% of his cell and his idle
# fills 31%. The frames the player looks at for the whole match were resolving
# from roughly twenty real pixels.
#
# The obvious fix - bake the whole family one ladder step larger and halve the
# runtime scale - buys a clean 2x and costs 4x the texture, taking actor VRAM
# from 25 MB to 100 MB. A mid-range Android will not carry that.
#
# So the density is per roster and the cell is per clip. Every clip renders at
# one shared px-per-unit from one camera position; only the ortho extent
# changes, which makes a wider cell a symmetric expansion around a world point
# all clips share. Relative size stays honest - a goliath is twice a walker
# because it is twice the walker, not because it was framed differently - and
# one-shot poses take a wider cell instead of shrinking everything else.
# `ground_offset` is centre_y * cell / ortho_scale, i.e. centre_y * density, so
# it stays constant in pixels however the cell grows and one
# `AnimatedSprite2D.offset` still pins every animation's feet to one point.
# `build_actor_sprite_frames.gd` re-checks that invariant per actor.
#
# DENSITY_GAIN is measured, not guessed. `tools/art/validate_actor_fill.py`
# reads the alpha bounds of the shipped sheets - which include the Freestyle
# outline that `bound_box` cannot see - and reports what each clip really
# occupies. At 2.0 the continuously-visible clips still fit the 64/128 tier
# cells for all but the largest members, total sheet pixels rise 25.2 -> 30.3
# Mpx, and the runtime presentation scale divides to exactly 1.0 for enemies,
# so a texel maps 1:1 onto a logical pixel and nearest filtering is finally
# doing what it claims to. `tests/actor_fill_validation.gd` gates the result.
DENSITY_GAIN = 2.0

# Clips the player reads continuously. These hold the tier cell as a floor so a
# hero never resolves smaller than his tier promises; one-shot poses are free
# to take a wider cell or a narrower one, whichever their content needs.
GAMEPLAY_CLIPS = ("idle", "walk", "run", "attack", "hit", "gather", "shoot")

# The fill report now records the density its pixels were actually rendered at,
# taken off the camera rather than off the tier's nominal figure, so the ratio
# below already carries the old double-PAD discrepancy and must not be corrected
# for it a second time. What is left is ordinary safety: the measurement is an
# envelope over every heading and frame of a previous bake, and a re-baked pose
# is not obliged to land inside it to the pixel.
#
# Raised from 1.04 with the ladder. The coarse rungs used to donate slack no one
# accounted for - a clip could sit at 68% of its cell purely because the rung
# above was so far away - and 1.04 was survivable only because of that gift.
# Measuring the current sheets against the previous bake put the worst per-clip
# drift at exactly 1.04x, so the old figure covered the worst observed case with
# nothing to spare, and the tighter ladder would have handed that margin back.
# 1.12 keeps eight points over the worst drift actually seen across 66 clips.
CELL_HEADROOM = 1.12

FILL_REPORT = os.path.join(PROJECT, "build", "actor_bake", "actor_fill_report.json")
## A narrow candidate bake must keep the already-shipping camera, density and
## per-clip cells.  Without this explicit opt-in, filtering to one boss would
## re-measure a one-member tier and silently change its sprite dimensions.
## The normal full/smoke path intentionally ignores this environment variable.
BASELINE_CONTRACT_ENV = "BESPREN_ACTOR_BAKE_BASELINE_REPORT"


def ladder_cell(required: float) -> int:
	for candidate in CELL_LADDER:
		if candidate >= required - 0.5:
			return candidate
	return CELL_LADDER[-1]


def resolve_clip_cells(densities: dict, tier_of: dict) -> dict:
	"""Per-clip cell sizes, measured from the sheets the last bake produced.

	Returns {} when no fill report exists, which makes the bake fall back to
	one cell per tier - the previous behaviour - rather than guessing.

	The report's extents are pixels measured at a density it records, so a
	clip's requirement here is its measured extent times the ratio between the
	density this bake is using and the density it was measured at. Scaling by a
	ratio rather than by a fixed multiplier is what makes the pair idempotent:
	re-measuring the sheets this bake produces and baking again finds a ratio of
	1.0 and changes nothing, where a blind multiplier would double the cells a
	second time and keep doubling on every pass.
	"""
	if not os.path.exists(FILL_REPORT):
		print("[fill] no %s - falling back to one cell per tier" % FILL_REPORT,
		      flush=True)
		return {}
	with open(FILL_REPORT, "r", encoding="utf-8") as fh:
		report = json.load(fh)
	plan = {}
	for name, info in report.get("actors", {}).items():
		measured = float(info.get("measured_density", 0.0))
		target = float(densities.get(tier_of.get(name, "actor"), 0.0))
		if measured <= 0.0 or target <= 0.0:
			print("[fill] %s has no density to scale from - skipping" % name,
			      flush=True)
			continue
		ratio = target / measured
		cells = {}
		for clip, data in info.get("clips", {}).items():
			need = float(data["half_extent"]) * 2.0 * ratio * CELL_HEADROOM
			# No floor. An earlier draft raised gameplay clips to the tier
			# cell, but that cell is sized from the union of every clip and so
			# carries the death pose's width - the exact inflation this whole
			# change exists to remove. Relative size is protected by the shared
			# density, not by a shared cell: a tighter cell at the same density
			# is a tighter crop, not a smaller figure.
			cells[clip] = ladder_cell(need)
		plan[name] = cells
	return plan


def load_baseline_contract(path: str, roster: list) -> tuple:
	"""Load a previous full-bake framing contract for an isolated staging run.

	This is deliberately an authoring-only opt-in.  It lets a one-actor
	candidate render at the exact density, shared frame centre and per-clip cell
	sizes the production sheets use, rather than treating that actor as the only
	member of its tier.  It never writes to the baseline report and fails closed
	when the selected actor or tier is absent.
	"""
	if not os.path.isfile(path):
		raise RuntimeError("baseline bake contract does not exist: %s" % path)
	with open(path, "r", encoding="utf-8") as fh:
		baseline = json.load(fh)
	baseline_tiers = baseline.get("tiers", {})
	baseline_cells = baseline.get("clip_cells", {})
	requested_tiers = sorted({tier for _name, _key, _groups, _clips, tier in roster})
	tiers = {}
	for tier in requested_tiers:
		entry = baseline_tiers.get(tier)
		if not isinstance(entry, dict):
			raise RuntimeError("baseline bake contract is missing tier: %s" % tier)
		frame = entry.get("frame")
		if (
			not isinstance(frame, dict)
			or int(entry.get("cell", 0)) <= 0
			or float(entry.get("density", 0.0)) <= 0.0
		):
			raise RuntimeError("baseline bake contract has invalid tier: %s" % tier)
		tiers[tier] = entry
	clip_cells = {}
	for name, _key, _groups, clips, _tier in roster:
		actor_cells = baseline_cells.get(name)
		if not isinstance(actor_cells, dict):
			raise RuntimeError("baseline bake contract is missing actor: %s" % name)
		required = {clip.name for clip in clips}
		missing = sorted(required.difference(actor_cells))
		if missing:
			raise RuntimeError(
			"baseline bake contract is missing %s clip(s) for %s: %s"
			% (len(missing), name, ", ".join(missing))
		)
		clip_cells[name] = {clip: int(actor_cells[clip]) for clip in required}
	return tiers, clip_cells


SMOKE = [ROSTER[0][:3] + ([C("run", "Running_HoldingRifle", 4)],) + ROSTER[0][4:],
         ROSTER[1][:3] + ([C("run", "Running_HoldingBow", 4)],) + ROSTER[1][4:],
         ROSTER[2][:3] + ([C("walk", "Skeletons_Walking", 4)],) + ROSTER[2][4:],
         ROSTER[6][:3] + ([C("walk", "Skeletons_Walking", 4)],) + ROSTER[6][4:]]


def stage(scene, key, groups, clips):
	"""Stage one built body, reusing the authored path's staging wholesale."""
	return actor.stage_authored_actor(scene, PROJECT, key, groups, clips,
	                                  {"scale": (1.0, 1.0, 1.0)},
	                                  builder=body.build)


def resolve_tiers(measured: dict) -> dict:
	"""Give every tier one camera, and every tier the same pixels per unit.

	The measuring pass hands back the widest projected span inside each tier.
	The actor tier sets the density: its largest member fills its cell, so a
	survivor occupies the fraction of that cell he actually is. Every other
	tier then picks the smallest cell on the ladder that can hold its own
	largest member at that same density, which is what keeps a 3 unit boss
	reading as twice a 1.8 unit survivor instead of as a survivor in a bigger
	frame.
	"""
	base = measured.get("actor")
	if base is None:
		raise RuntimeError("no actor-tier member measured")
	base_cell = TIER_CELL["actor"]
	# PAD is applied here and nowhere else. The camera now takes an explicit
	# density, so the extent is no longer re-padded a second time at render.
	density = DENSITY_GAIN * base_cell / max(base["span"] * PAD, 1e-6)

	tiers = {}
	for name, frame in measured.items():
		need = frame["span"] * PAD * density
		cell = TIER_CELL.get(name, base_cell)
		for candidate in CELL_LADDER:
			if candidate >= need - 0.5:
				cell = max(cell, candidate) if name != "actor" else candidate
				break
		else:
			cell = CELL_LADDER[-1]
		if name == "actor":
			cell = base_cell
		# Feed the camera a span that means "this cell, at the shared density"
		# rather than "this tier's own bounds", then hold the padding at 1.0 so
		# the density is not quietly reapplied a second time.
		span = cell / density
		tiers[name] = {"cell": cell, "density": round(density, 4),
		               "measured_span": round(frame["span"], 4),
		               "frame": {"span_x": span, "span_y": span,
		                         "centre_x": frame["centre_x"],
		                         "centre_y": frame["centre_y"]}}
	return tiers


def main() -> None:
	argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	mode = argv[0] if argv else "smoke"
	# Resolved against the project, never against the caller's working
	# directory. Blender does not inherit the shell's CWD reliably - a plain
	# `build/actor_bake` argument resolved to C:\build\actor_bake, so the
	# frames and `actor_bake_report.json` landed at the drive root while the
	# validator kept reading the stale copy under the project, reporting on a
	# bake that had not happened. The default was already absolute; this makes
	# an explicit argument behave the same way.
	out_dir = argv[1] if len(argv) > 1 else os.path.join(PROJECT, "build", "actor_bake")
	if not os.path.isabs(out_dir):
		out_dir = os.path.join(PROJECT, out_dir)
	out_dir = os.path.normpath(out_dir)
	if mode == "smoke":
		roster = SMOKE
	elif mode == "full":
		roster = ROSTER
	else:
		# Any other word is a substring filter, so one member can be re-baked
		# without paying for the other nine.
		roster = [r for r in ROSTER if mode in r[0]]

	os.makedirs(out_dir, exist_ok=True)
	scene = rig.build_stage()
	report = {"mode": mode, "out_dir": out_dir, "source": "build_actor_body",
	          "actors": [], "measured": [], "errors": []}
	started = time.time()

	# Pass 1 measures every actor before anything renders. A tier has to agree
	# on one camera, and that camera cannot be chosen until its largest member
	# is known - otherwise each sheet fits its own cell and the goliath and the
	# crawler pack ship at identical pixel heights.
	spans = {}
	for name, key, groups, clips, tier in roster:
		try:
			staged = stage(scene, key, groups, clips)
			bounds = staged["bounds"]
			span = max(bounds["span_x"], bounds["span_y"])
			held = spans.setdefault(tier, {"span": 0.0, "centre_x": 0.0,
			                               "centre_y": 0.0})
			if span >= held["span"]:
				held.update(span=span, centre_x=bounds["centre_x"],
				            centre_y=bounds["centre_y"])
			auth = staged["authored"]
			report["measured"].append(dict(actor=name, key=key, tier=tier,
			                               span=round(span, 4),
			                               height=round(bounds["height"], 4),
			                               missing=auth["missing_clips"],
			                               skin=auth["skin"], fit=auth["fit"]))
			print("[measure] %-20s %-5s span=%.3f h=%.3f missing=%s"
			      % (name, tier, span, bounds["height"], auth["missing_clips"]),
			      flush=True)
		except Exception:
			report["errors"].append({"actor": name, "phase": "measure",
			                         "trace": traceback.format_exc()})
			print("[FAIL measure] %s" % name, flush=True)
			traceback.print_exc()

	baseline_contract = os.environ.get(BASELINE_CONTRACT_ENV, "").strip()
	if baseline_contract:
		baseline_contract = os.path.abspath(baseline_contract)
		tiers, clip_cells = load_baseline_contract(baseline_contract, roster)
		print("[contract] staging baseline=%s" % baseline_contract, flush=True)
	else:
		tiers = resolve_tiers(spans)
		tier_of = {name: tier for name, _key, _groups, _clips, tier in roster}
		clip_cells = resolve_clip_cells(
			{tier: info["density"] for tier, info in tiers.items()}, tier_of)
	report["tiers"] = tiers
	report["density_gain"] = DENSITY_GAIN
	report["clip_cells"] = clip_cells
	report["baseline_contract"] = baseline_contract
	for name, info in sorted(tiers.items()):
		print("[tier] %-6s cell=%d density=%.2f px/unit measured_span=%.3f"
		      % (name, info["cell"], info["density"], info["measured_span"]),
		      flush=True)

	for name, key, groups, clips, tier in roster:
		if tier not in tiers:
			continue
		try:
			staged = stage(scene, key, groups, clips)
			results = actor.bake_actor(scene, staged, out_dir, name,
			                           tiers[tier]["frame"], cell=tiers[tier]["cell"],
			                           clip_cells=clip_cells.get(name, {}),
			                           density=tiers[tier]["density"])
			for entry in results:
				entry["tier"] = tier
			report["actors"].extend(results)
			print("[bake] %-20s -> %d clip(s) @ %s px"
			      % (name, len(results),
			         sorted({e["cell"] for e in results})), flush=True)
		except Exception:
			report["errors"].append({"actor": name, "phase": "bake",
			                         "trace": traceback.format_exc()})
			print("[FAIL bake] %s" % name, flush=True)
			traceback.print_exc()

	report["seconds"] = round(time.time() - started, 1)
	report["frames"] = sum(a.get("frames", 0) for a in report["actors"])
	with open(os.path.join(out_dir, "actor_bake_report.json"), "w", encoding="utf-8") as fh:
		json.dump(report, fh, indent=1)
	print("[bake] done in %.1fs, %d clips, %d frames, %d errors"
	      % (report["seconds"], len(report["actors"]), report["frames"],
	         len(report["errors"])), flush=True)


main()
