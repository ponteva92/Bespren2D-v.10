"""Render every built actor body at rest and in motion, before any sheet bake.

	blender --background --python tools/art/probe_built_bodies.py -- <out_dir> [key]

A full roster bake is thousands of renders. This is the cheap gate in front of
it: one rest pose and two posed frames per actor, framed to the figure, so a
body that is inside-out, bound to the wrong bone or simply ugly is caught for
the price of thirty images rather than three thousand.

The roster is also rendered to a single shared scale so the size hierarchy can
be judged - a goliath that fails to tower over a survivor is a design bug even
when every individual sprite is correct.
"""

import json
import math
import os
import sys
import traceback

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy
from mathutils import Vector

import aaa_bake_rig as rig
import build_actor_body as body

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

GROUPS = ["General", "MovementBasic", "MovementAdvanced", "CombatRanged",
          "CombatMelee", "Tools", "Special"]

# Which action stands in for each probe pose. The bake driver owns the real
# per-actor clip table; here we only need something that moves the limbs.
POSES = {
	"hero_heikki": ["Walking_A", "Running_HoldingRifle"],
	"hero_shane": ["Walking_A", "Running_HoldingBow"],
	"walker": ["Skeletons_Walking", "Melee_Unarmed_Attack_Punch_A"],
	"rat_swarm": ["Skeletons_Walking", "Skeletons_Idle"],
	"static_walker": ["Skeletons_Walking", "Skeletons_Awaken_Floor"],
	"scrap_shield": ["Skeletons_Walking", "Melee_Unarmed_Attack_Punch_A"],
	"goliath": ["Skeletons_Walking", "Skeletons_Taunt"],
	"carrier": ["Skeletons_Walking", "Skeletons_Idle"],
	"splitter": ["Skeletons_Walking", "Melee_Unarmed_Attack_Punch_A"],
	"overlord": ["Skeletons_Walking", "Skeletons_Taunt"],
}

SIZE = 256


def stage():
	scene = rig.build_stage()
	scene.render.use_freestyle = False
	scene.view_layers[0].use_freestyle = False
	scene.render.resolution_x = SIZE
	scene.render.resolution_y = SIZE
	if getattr(scene, "eevee", None) is not None:
		scene.eevee.taa_render_samples = 32
	return scene


def frame(scene, mesh, pad=1.14, fixed=None):
	elevation = math.radians(rig.CAM_ELEVATION_DEG)
	azimuth = math.radians(rig.CAM_AZIMUTH_DEG)
	forward = Vector((-math.cos(elevation) * math.sin(azimuth),
	                  math.cos(elevation) * math.cos(azimuth),
	                  -math.sin(elevation))).normalized()
	quat = forward.to_track_quat("-Z", "Y")
	right, up = quat @ Vector((1.0, 0.0, 0.0)), quat @ Vector((0.0, 1.0, 0.0))

	depsgraph = bpy.context.evaluated_depsgraph_get()
	depsgraph.update()
	evaluated = mesh.evaluated_get(depsgraph)
	corners = [evaluated.matrix_world @ Vector(c) for c in evaluated.bound_box]
	centre = sum(corners, Vector()) / float(len(corners))
	xs = [(c - centre).dot(right) for c in corners]
	ys = [(c - centre).dot(up) for c in corners]
	span = max(max(xs) - min(xs), max(ys) - min(ys))
	scene.camera.data.ortho_scale = fixed if fixed else max(0.6, span * pad)
	scene.camera.location = centre - forward * rig.CAM_DISTANCE
	scene.camera.rotation_euler = quat.to_euler()
	return round(span, 4)


def pose(scene, armature, action, ratio):
	if armature.animation_data is None:
		armature.animation_data_create()
	armature.animation_data.action = action
	if hasattr(armature.animation_data, "action_slot") and action.slots:
		armature.animation_data.action_slot = action.slots[0]
	start, end = action.frame_range
	scene.frame_set(int(round(start + (end - start) * ratio)))


def shot(scene, out_dir, name):
	scene.render.filepath = os.path.join(out_dir, "%s.png" % name)
	rig._render_still(scene)


def main():
	argv = sys.argv[sys.argv.index("--") + 1:]
	out_dir = argv[0]
	only = argv[1] if len(argv) > 1 else ""
	os.makedirs(out_dir, exist_ok=True)

	report = {"actors": [], "errors": []}
	keys = [k for k in body.ROSTER if not only or only in k]
	# One shared ortho width for the comparison pass, sized to the tallest
	# member so the whole roster can be judged against each other.
	tallest = max(body.ROSTER[k]["height"] for k in keys) * 1.35

	for key in keys:
		try:
			scene = stage()
			built = body.build(PROJECT_ROOT, key, GROUPS)
			mesh, armature = built["mesh"], built["armature"]

			for bone in armature.pose.bones:
				bone.matrix_basis.identity()
			bpy.context.view_layer.update()
			span = frame(scene, mesh)
			rig.auto_expose(scene, os.path.join(out_dir, "_meter.png"))
			shot(scene, out_dir, "%s_0rest" % key)

			# same camera width for everyone, so relative size is visible
			frame(scene, mesh, fixed=tallest)
			shot(scene, out_dir, "%s_1scale" % key)

			for index, clip in enumerate(POSES.get(key, [])):
				action = built["actions"].get(clip)
				if action is None:
					continue
				pose(scene, armature, action, 0.35 if index == 0 else 0.6)
				frame(scene, mesh)
				shot(scene, out_dir, "%s_2%s" % (key, clip))

			report["actors"].append({
				"key": key, "span": span, "height": body.ROSTER[key]["height"],
				"tier": body.ROSTER[key]["tier"], "skin": built["skin"],
				"fit": built["fit"]})
			print("[ok] %-14s h=%.2f span=%.2f shells=%d verts=%d bones=%d %s"
			      % (key, body.ROSTER[key]["height"], span,
			         built["skin"]["shells"], built["skin"]["verts"],
			         built["skin"]["bones_used"], built["skin"]["materials"]),
			      flush=True)
		except Exception as exc:  # noqa: BLE001 - a probe reports, it does not abort
			report["errors"].append({"key": key, "error": "%s: %s"
			                         % (type(exc).__name__, exc),
			                         "trace": traceback.format_exc()})
			print("[FAIL] %s %s" % (key, exc), flush=True)
			traceback.print_exc()

	path = os.path.join(out_dir, "built_bodies_probe.json")
	open(path, "w", encoding="utf-8").write(json.dumps(report, indent=1))
	print("WROTE", path, "errors=%d" % len(report["errors"]), flush=True)


main()
