"""Prove the authored-actor rig deforms correctly before baking 1000+ frames.

Run headless:
	blender --background --python tools/art/probe_authored_rig.py -- <out_dir>

Three stages are rendered for every actor, in this order, because they fail
for different reasons and only the sequence tells them apart:

	raw   the authored mesh as it ships, before any rig touches it
	rest  the same mesh bound to the fitted skeleton, at rest
	<clip> the bound mesh evaluated inside a real action

`raw` vs `rest` isolates the fit: if a leg is already a spike at rest, the
skeleton was fitted outside the geometry and no weighting can recover it.
`rest` vs `<clip>` isolates the binding: a figure that stands correctly and
tears when it walks is a weights problem. Judging a bad sheet without those
two references is how an afternoon goes into the wrong half of the pipeline.

The fitted bone ladder is printed next to the actor's own measured landmarks
for the same reason - a number that sits below the mesh floor or above its
crown is visible in the log before it is visible in the pixels.
"""

import json
import math
import traceback
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy
from mathutils import Vector

import aaa_bake_rig as rig
import rig_bespren_actor as authored

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TESTI_3D = os.path.join(os.path.dirname(PROJECT_ROOT), "testi", "assets", "3d")


def _case(name, kind, stem, groups, clips):
	return (name, os.path.join(TESTI_3D, kind, "%s.glb" % stem), groups, clips)


CASES = [
	_case("heikki", "characters", "char_heikki_rifleman",
	      ["General", "MovementBasic", "MovementAdvanced"],
	      ["Walking_A", "Running_HoldingRifle"]),
	_case("shane", "characters", "char_shane_gunslinger",
	      ["General", "MovementBasic", "MovementAdvanced"],
	      ["Walking_A", "Running_HoldingBow"]),
	_case("walker", "enemies", "enemy_static_walker",
	      ["Special", "General"], ["Skeletons_Walking"]),
	_case("brute", "enemies", "enemy_brute",
	      ["Special", "General"], ["Skeletons_Walking"]),
	_case("goliath", "bosses", "boss_goliath",
	      ["Special", "General"], ["Skeletons_Walking"]),
]

FRAMES = 3
SIZE = 256


def pose(scene, armature, action, ratio):
	if armature.animation_data is None:
		armature.animation_data_create()
	armature.animation_data.action = action
	if hasattr(armature.animation_data, "action_slot") and action.slots:
		armature.animation_data.action_slot = action.slots[0]
	start, end = action.frame_range
	scene.frame_set(int(round(start + (end - start) * ratio)))


def unpose(armature):
	if armature.animation_data is not None:
		armature.animation_data.action = None
	for bone in armature.pose.bones:
		bone.matrix_basis.identity()
	bpy.context.view_layer.update()


def frame_camera(scene, mesh, pad=1.12):
	"""Fit the ortho camera to the deformed figure across a turn."""
	elevation = math.radians(rig.CAM_ELEVATION_DEG)
	azimuth = math.radians(rig.CAM_AZIMUTH_DEG)
	forward = Vector((-math.cos(elevation) * math.sin(azimuth),
	                  math.cos(elevation) * math.cos(azimuth),
	                  -math.sin(elevation))).normalized()
	quat = forward.to_track_quat("-Z", "Y")
	right = quat @ Vector((1.0, 0.0, 0.0))
	up = quat @ Vector((0.0, 1.0, 0.0))

	depsgraph = bpy.context.evaluated_depsgraph_get()
	depsgraph.update()
	evaluated = mesh.evaluated_get(depsgraph)
	corners = [evaluated.matrix_world @ Vector(c) for c in evaluated.bound_box]
	centre = sum(corners, Vector()) / float(len(corners))
	xs = [(c - centre).dot(right) for c in corners]
	ys = [(c - centre).dot(up) for c in corners]
	span = max(max(xs) - min(xs), max(ys) - min(ys))
	scene.camera.data.ortho_scale = max(0.6, span * pad)
	scene.camera.location = centre - forward * rig.CAM_DISTANCE
	scene.camera.rotation_euler = quat.to_euler()
	return round(span, 4)


def bone_ladder(armature, profile) -> dict:
	"""Where the fitted bones actually sit, against the mesh they must fill."""
	height = profile["height"]
	ladder = {}
	for bone in armature.data.bones:
		ladder[bone.name] = [round(bone.head_local.z, 3), round(bone.tail_local.z, 3)]
	lowest = min(v[1] for v in ladder.values())
	highest = max(v[1] for v in ladder.values())
	return {"bones": ladder, "lowest_tail": round(lowest, 3),
	        "highest_tail": round(highest, 3),
	        "mesh_height": round(height, 3),
	        # A tail below zero means the skeleton hangs through the floor, and
	        # every vertex nearest it is dragged down with it - which is exactly
	        # what a leg drawn as a spike looks like.
	        "below_floor": round(min(0.0, lowest), 3),
	        "above_crown": round(max(0.0, highest - height), 3)}


def render(scene, out_dir, name, tag):
	path = os.path.join(out_dir, "%s_%s.png" % (name, tag))
	scene.render.filepath = path
	rig._render_still(scene)
	return os.path.basename(path)


def main():
	argv = sys.argv[sys.argv.index("--") + 1:]
	out_dir = argv[0]
	only = argv[1] if len(argv) > 1 else ""
	os.makedirs(out_dir, exist_ok=True)

	report = {"cases": [], "errors": []}
	for name, glb, groups, clips in CASES:
		if only and only not in name:
			continue
		scene = rig.build_stage()
		scene.render.use_freestyle = False
		scene.view_layers[0].use_freestyle = False
		scene.render.resolution_x = SIZE
		scene.render.resolution_y = SIZE
		if getattr(scene, "eevee", None) is not None:
			scene.eevee.taa_render_samples = 24

		# Stage 1: the authored mesh exactly as it ships. This is the reference
		# every later stage is judged against, so it is rendered before the rig
		# module has had any chance to touch the geometry.
		written = []
		try:
			raw = authored.import_authored(glb)["mesh"]
			frame_camera(scene, raw)
			rig.auto_expose(scene, os.path.join(out_dir, "_meter.png"))
			written.append(render(scene, out_dir, name, "0raw"))
		except Exception:
			report["errors"].append({"actor": name, "stage": "raw",
			                         "trace": traceback.format_exc()})
			traceback.print_exc()
			continue

		scene = rig.build_stage()
		scene.render.use_freestyle = False
		scene.view_layers[0].use_freestyle = False
		scene.render.resolution_x = SIZE
		scene.render.resolution_y = SIZE
		if getattr(scene, "eevee", None) is not None:
			scene.eevee.taa_render_samples = 24
		try:
			built = authored.build(PROJECT_ROOT, glb, groups)
		except Exception as exc:  # noqa: BLE001 - probe must report, not abort
			report["errors"].append({"actor": name, "stage": "build",
			                         "error": "%s: %s" % (type(exc).__name__, exc),
			                         "trace": traceback.format_exc()})
			print("[FAIL] %s %s" % (name, exc), flush=True)
			traceback.print_exc()
			continue

		mesh = built["mesh"]
		armature = built["armature"]
		ladder = bone_ladder(armature, built["profile"])

		unpose(armature)
		span = frame_camera(scene, mesh)
		rig.auto_expose(scene, os.path.join(out_dir, "_meter.png"))
		written.append(render(scene, out_dir, name, "1rest"))

		resolved = [(c, built["actions"].get(c)) for c in clips]
		missing = [c for c, a in resolved if a is None]
		for clip, action in [(c, a) for c, a in resolved if a is not None]:
			for index in range(FRAMES):
				pose(scene, armature, action, index / float(FRAMES))
				written.append(render(scene, out_dir, name,
				                      "2%s_%d" % (clip, index)))

		report["cases"].append({
			"actor": name, "glb": glb, "span": span, "missing_clips": missing,
			"profile": built["profile"], "fit": built["fit"],
			"facing": built["facing"], "ladder": ladder,
			"skin": built["skin"], "frames": written,
			"tris": len(mesh.data.polygons),
			"vertex_groups": len(mesh.vertex_groups)})
		print("[ok] %-8s span=%.3f turn=%s" % (name, span, built["facing"]["turn_deg"]), flush=True)
		print("      prof %s" % {k: (round(v, 3) if isinstance(v, float) else v)
		                         for k, v in built["profile"].items()}, flush=True)
		print("      fit  %s" % built["fit"], flush=True)
		print("      skel lowest=%.3f (below floor %.3f) highest=%.3f "
		      "(above crown %.3f) mesh_h=%.3f"
		      % (ladder["lowest_tail"], ladder["below_floor"],
		         ladder["highest_tail"], ladder["above_crown"],
		         ladder["mesh_height"]), flush=True)

	path = os.path.join(out_dir, "authored_rig_probe.json")
	open(path, "w", encoding="utf-8").write(json.dumps(report, indent=1))
	print("WROTE", path, flush=True)


main()
