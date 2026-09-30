"""Bake 8-direction animated actor sprite sheets for Bespren.

The game is a 480x270 top-down co-op survival slice whose players and horde
are, before this module, single static PNGs that never change pose or facing.
KayKit's CC0 character animation set supplies a rigged mannequin and 139
authored clips, so the sheets are baked offline through the same stage as
every other Bespren sprite family instead of being hand-drawn.

Runtime stays 2D: this module emits RGBA sheets laid out as
`rows = 8 compass directions, columns = frames`, which an AnimatedSprite2D or
a region-animated Sprite2D can index directly. No mesh, armature, or Node3D
ever reaches the shipping project.

Source: Addons/KayKit_Character_Animations_1.1 (CC0 1.0, Kay Lousberg).
"""

import math
import os

import bpy
from mathutils import Vector

import aaa_bake_rig as rig
import rig_bespren_actor as authored

KAYKIT_ROOT = os.path.join(
	"Addons", "KayKit_Character_Animations_1.1", "KayKit_Character_Animations_1.1")
ANIM_SUBDIR = os.path.join("Animations", "gltf", "Rig_Medium")

# Eight compass headings, baked as rows. Row 0 faces the camera-down screen
# direction so a heading index maps straight onto the eight-way stick the
# mobile controls already quantise to.
DIRECTIONS = 8
DIR_STEP_DEG = 360.0 / DIRECTIONS
# The stage camera looks along azimuth -45deg, so the subject needs that same
# offset for row 0 to read as "walking towards the bottom of the screen".
YAW_OFFSET_DEG = 45.0


class ActorClip:
	"""One animation row-set: which action, how many frames, and its speed."""

	def __init__(self, name: str, action: str, frames: int = 6, loop: bool = True):
		self.name = name
		self.action = action
		self.frames = frames
		self.loop = loop


def _find_action(name_fragment: str):
	"""KayKit actions arrive namespaced, so match on the trailing clip name."""
	exact = []
	for action in bpy.data.actions:
		leaf = action.name.split("|")[-1]
		if leaf == name_fragment:
			exact.append(action)
	if exact:
		return exact[0]
	for action in bpy.data.actions:
		if name_fragment in action.name:
			return action
	return None


def _import_rig(scene: bpy.types.Scene, glb_path: str) -> dict:
	"""Load one KayKit animation group into the clean stage."""
	rig._clear_subjects(scene)
	for action in list(bpy.data.actions):
		bpy.data.actions.remove(action)
	before = set(bpy.data.objects)
	bpy.ops.import_scene.gltf(filepath=glb_path)
	imported = [o for o in bpy.data.objects if o not in before]
	for obj in imported:
		for coll in list(obj.users_collection):
			coll.objects.unlink(obj)
		scene.collection.objects.link(obj)

	# Classify before deleting anything: removing an object invalidates every
	# other reference still held in the imported list.
	meshes = [o for o in imported if o.type == "MESH"]
	armatures = [o for o in imported if o.type == "ARMATURE"]
	# The mannequin GLB ships a stray icosphere helper that otherwise
	# dominates the framing and renders as a grey ball.
	strays = [o for o in meshes if o.name.lower().startswith("icosphere")]
	meshes = [o for o in meshes if o not in strays]
	for obj in strays:
		bpy.data.objects.remove(obj, do_unlink=True)

	# Heading has to be driven from a pivot the animation cannot reach. KayKit
	# actions carry object-level channels on the armature itself, so writing
	# rotation_euler there is silently overwritten the moment frame_set()
	# evaluates the action - which is how the first sheet came out with all
	# eight direction rows pixel-identical.
	pivot = bpy.data.objects.new("BESPREN_ACTOR_PIVOT", None)
	scene.collection.objects.link(pivot)
	for obj in meshes + armatures:
		if obj.parent is None:
			obj.parent = pivot
			obj.matrix_parent_inverse = pivot.matrix_world.inverted()
	return {"meshes": meshes, "armatures": armatures, "pivot": pivot}


def _apply_identity(meshes: list, parts: dict) -> dict:
	"""Recolour the shared mannequin material per body part.

	Every KayKit mesh points at one `Character_Material`, so each part gets its
	own copy; without the copy, painting Shane's torso would silently repaint
	Heikki's. The split matters more than the hues: at a 64 px cell the torso is
	the only mass large enough to carry identity, while head and limbs have to
	stay value-separated from it or the whole figure collapses into one blob.
	"""
	assigned = {}
	for obj in meshes:
		low = obj.name.lower()
		if "head" in low:
			key = parts["head"]
		elif "arm" in low:
			key = parts["arm"]
		elif "leg" in low:
			key = parts["leg"]
		else:
			key = parts["body"]
		spec = rig.BESPREN_PALETTE[key]
		assigned[obj.name] = key
		mats = obj.data.materials
		for slot in range(len(mats)):
			if mats[slot] is None:
				continue
			mat = mats[slot].copy()
			mat.use_nodes = True
			bsdf = mat.node_tree.nodes.get("Principled BSDF")
			if bsdf is None:
				continue
			bsdf.inputs["Base Color"].default_value = rig._srgb_to_linear(spec[0])
			bsdf.inputs["Roughness"].default_value = spec[1]
			bsdf.inputs["Metallic"].default_value = spec[2]
			if spec[3] > 0.0:
				bsdf.inputs["Emission Color"].default_value = rig._srgb_to_linear(spec[0])
				bsdf.inputs["Emission Strength"].default_value = spec[3]
			mats[slot] = mat
	return assigned


def sheet_render_profile(scene: bpy.types.Scene) -> dict:
	"""Trade the offline outline pass for throughput on high-volume sheets.

	Freestyle re-solves its line set against the deformed mesh on every single
	frame, which dominates the cost of a sheet that is hundreds of poses deep.
	Characters do not need it: `character_presentation.gd` already runs the
	shared four-sample toon-outline shader over the sprite at runtime, so a
	baked line would only be a second, blurrier outline underneath the real one.
	Static props keep Freestyle, because nothing outlines them in-game.
	"""
	scene.render.use_freestyle = False
	scene.view_layers[0].use_freestyle = False
	eevee = getattr(scene, "eevee", None)
	if eevee is not None and hasattr(eevee, "taa_render_samples"):
		# 16 samples is past the point where a 64 px cell can resolve noise.
		eevee.taa_render_samples = 16
	return {"freestyle": False, "samples": 16}


ROOT_ANCHOR = ("root", "hips")


def _anchor_root(armature) -> None:
	"""Cancel a clip's horizontal root travel before it is measured or drawn.

	A sprite sheet holds a pose, not a position: the game moves the Sprite2D,
	and the cell is only ever as wide as the figure. KayKit's clips do not
	agree - `Skeletons_Death` slides its root metres away as the body falls,
	and `Skeletons_Awaken_Floor` crawls forward as it rises. Left alone that
	travel costs twice. The measuring pass unions it into the shared camera, so
	the death sprawl of one clip shrinks the idle pose of every other one; the
	full clip set dropped the actor tier from 20.65 to 6.64 px per unit, a
	third of the intended size on every sheet. And at render time the figure
	would walk out of its own collision body, because `EnemyAgent2D` owns the
	position the sprite is drawn at.

	Vertical travel is kept. A body rising out of the floor is the clip's
	content, not its drift, and the sheet has the height to show it.

	The correction is written as an offset on the armature rather than into the
	pose, so it is exact whatever roll the root bone carries. It is also
	idempotent: `here` is read back through `matrix_basis`, so it already
	includes the previous correction and re-anchoring an anchored pose is a
	no-op. That matters because KayKit actions carry object-level channels on
	some clips and not others, and this must not care which.
	"""
	bone = None
	for name in ROOT_ANCHOR:
		bone = armature.pose.bones.get(name)
		if bone is not None:
			break
	if bone is None:
		return
	here = armature.matrix_basis @ bone.matrix.translation
	if abs(here.x) < 1e-6 and abs(here.y) < 1e-6:
		return
	armature.location.x -= here.x
	armature.location.y -= here.y


def _pose(scene: bpy.types.Scene, armature, action, frame_ratio: float) -> None:
	"""Evaluate the rig at a normalised point inside one clip."""
	if armature.animation_data is None:
		armature.animation_data_create()
	armature.animation_data.action = action
	if hasattr(armature.animation_data, "action_slot") and action.slots:
		armature.animation_data.action_slot = action.slots[0]
	start, end = action.frame_range
	scene.frame_set(int(round(start + (end - start) * frame_ratio)))
	_anchor_root(armature)


def camera_basis() -> tuple:
	"""Right/up/forward of the stage camera.

	The rig's elevation and azimuth are constants and the camera is
	orthographic, so its orientation - and therefore the shape of everything it
	projects - does not depend on where along the view axis it is placed. That
	makes the basis computable before the camera is positioned, which is what
	lets bounds be measured in screen space during the measuring pass.
	"""
	el = math.radians(rig.CAM_ELEVATION_DEG)
	az = math.radians(rig.CAM_AZIMUTH_DEG)
	forward = Vector((-math.cos(el) * math.sin(az),
	                  math.cos(el) * math.cos(az),
	                  -math.sin(el))).normalized()
	quat = forward.to_track_quat("-Z", "Y")
	return quat @ Vector((1.0, 0.0, 0.0)), quat @ Vector((0.0, 1.0, 0.0)), forward


def reproportion(meshes: list, head_scale: float) -> dict:
	"""Shrink the mannequin skull without detaching it from the neck.

	KayKit rigs a deliberately chibi mannequin: the head is the single largest
	mass on the body, so at a 64 px cell every actor reads as a bobblehead and
	the torso - the only surface carrying player identity - is outshouted by a
	blank skull.

	The shrink has to happen in the mesh data, not on the object. The head is
	parented to the armature, so its `matrix_world` is `parent @ basis`: writing
	a world-space anchor into `obj.location` writes it into `basis`, where the
	parent transform then re-applies to it and slides the skull off sideways.
	Scaling vertices instead is also the only version that survives animation.
	Armature deformation is affine per vertex, so scaling the rest geometry
	about an anchor `p` produces `D(p) + s * (D(v) - D(p))` once deformed: the
	head shrinks toward the deformed neck joint on every frame, with weights and
	vertex groups untouched because the same vertices are still there.
	"""
	if head_scale >= 0.999:
		return {}
	applied = {}
	for obj in meshes:
		if "head" not in obj.name.lower():
			continue
		if obj.data.users > 1:
			# Another body part sharing this datablock would be scaled too.
			obj.data = obj.data.copy()
		mesh = obj.data
		verts = mesh.vertices
		if not verts:
			continue

		# Find which local axis the glTF import left pointing at world up, so
		# the anchor lands on the underside of the skull whatever convention
		# the source file used.
		up_local = obj.matrix_world.to_3x3().inverted() @ Vector((0.0, 0.0, 1.0))
		axis = max(range(3), key=lambda i: abs(up_local[i]))
		lo = Vector((min(v.co[i] for v in verts) for i in range(3)))
		hi = Vector((max(v.co[i] for v in verts) for i in range(3)))
		anchor = (lo + hi) * 0.5
		anchor[axis] = lo[axis] if up_local[axis] > 0.0 else hi[axis]

		for v in verts:
			v.co = anchor + (Vector(v.co) - anchor) * head_scale
		keys = mesh.shape_keys
		if keys is not None:
			for block in keys.key_blocks:
				for point in block.data:
					point.co = anchor + (Vector(point.co) - anchor) * head_scale
		mesh.update()
		applied[obj.name] = round(head_scale, 3)
	return applied


def measure_animated(scene, meshes: list, armature, pivot, actions: list,
                     samples: int = 5) -> dict:
	"""Measure the widest pose the sheet will contain, and stand the actor up.

	Two things make the naive measurement wrong. `Object.bound_box` reports the
	*rest* mesh, so measuring a skinned character on it describes a figure
	standing still and then clips its arms off the moment the walk cycle swings
	them out. And world-axis extents are not what an orthographic camera at 52
	degrees elevation and 45 degrees azimuth actually projects: along that
	diagonal a footprint spans up to 1.41 times its own X or Y, which is how the
	brute kept reaching its sheet edges even after the padding grew.

	So this samples the evaluated depsgraph across every clip at two headings,
	and accumulates the result in the camera own screen basis.
	"""
	right, up, _ = camera_basis()
	world_min = Vector((1e9, 1e9, 1e9))
	world_max = Vector((-1e9, -1e9, -1e9))
	corners = []
	depsgraph = bpy.context.evaluated_depsgraph_get()
	for action in actions:
		for step in range(samples):
			_pose(scene, armature, action, step / float(samples))
			# Measure every heading that will actually be rendered. Sampling
			# only the axes misses the 45-degree diagonals, where a figure
			# projects at its widest - the brute kept touching its sheet edges
			# for exactly that reason.
			for heading in [i * DIR_STEP_DEG for i in range(DIRECTIONS)]:
				pivot.rotation_euler = (0.0, 0.0, math.radians(YAW_OFFSET_DEG + heading))
				depsgraph.update()
				for obj in meshes:
					evaluated = obj.evaluated_get(depsgraph)
					for corner in evaluated.bound_box:
						world = evaluated.matrix_world @ Vector(corner)
						corners.append(world)
						world_min = Vector((min(world_min[i], world[i]) for i in range(3)))
						world_max = Vector((max(world_max[i], world[i]) for i in range(3)))
	if not corners:
		raise RuntimeError("could not measure animated bounds")

	# Stand the actor on z = 0 and centre it on the world origin, so every
	# roster member shares one ground plane and one camera.
	centre = (world_min + world_max) * 0.5
	shift = Vector((centre.x, centre.y, world_min.z))
	pivot.location -= shift
	screen_x = [(c - shift).dot(right) for c in corners]
	screen_y = [(c - shift).dot(up) for c in corners]
	return {"span_x": max(screen_x) - min(screen_x),
	        "span_y": max(screen_y) - min(screen_y),
	        "centre_x": (max(screen_x) + min(screen_x)) * 0.5,
	        "centre_y": (max(screen_y) + min(screen_y)) * 0.5,
	        "height": (world_max - world_min).z,
	        "extent": [round(v, 3) for v in (world_max - world_min)]}


def apply_shared_camera(scene, frame: dict, pad: float = 1.06) -> dict:
	"""Point one camera at the whole roster.

	Fitting the camera per actor would make every sheet fill its own cell, so a
	1.30x brute and a 0.74x crawler would render exactly the same number of
	pixels tall and the size difference built into the roster would vanish. One
	shared ortho scale keeps pixel density honest: the largest member fills the
	cell, everyone else occupies the fraction of it that they actually are.
	"""
	right, up, forward = camera_basis()
	span = max(frame["span_x"], frame["span_y"])
	scene.camera.data.ortho_scale = max(0.6, span * pad)
	target = right * frame["centre_x"] + up * frame["centre_y"]
	scene.camera.location = target - forward * rig.CAM_DISTANCE
	scene.camera.rotation_euler = forward.to_track_quat("-Z", "Y").to_euler()
	return {"ortho_scale": round(scene.camera.data.ortho_scale, 4),
	        "span": [round(frame["span_x"], 4), round(frame["span_y"], 4)]}


def stage_actor(scene, glb_path: str, clips: list, parts: dict) -> dict:
	"""Import one actor, dress it, size it, and report its animated bounds."""
	loaded = _import_rig(scene, glb_path)
	meshes, armatures, pivot = loaded["meshes"], loaded["armatures"], loaded["pivot"]
	if not meshes or not armatures:
		raise RuntimeError("no rig in %s" % glb_path)
	assigned = _apply_identity(meshes, parts)
	# Design pillar: Heikki reads broad and stable, Shane narrow and taller.
	# One shared mannequin cannot deliver that through hue alone, so each actor
	# gets a non-uniform build applied at the pivot, before measurement.
	pivot.scale = tuple(parts.get("scale", (1.0, 1.0, 1.0)))
	heads = reproportion(meshes, float(parts.get("head_scale", 0.78)))
	resolved = [(clip, _find_action(clip.action)) for clip in clips]
	found = [action for _, action in resolved if action is not None]
	if not found:
		raise RuntimeError("no actions resolved in %s" % glb_path)
	bounds = measure_animated(scene, meshes, armatures[0], pivot, found)
	loaded.update({"materials": assigned, "resolved": resolved, "bounds": bounds,
	               "head_scale": heads})
	return loaded


def stage_authored_actor(scene, project_root: str, source: str, groups: list,
                         clips: list, parts: dict, builder=None) -> dict:
	"""Stage an authored Bespren actor on a KayKit skeleton fitted to it.

	`stage_actor` dresses KayKit's own mannequin, and a mannequin is the one
	thing this roster cannot be built from. It is a chibi with a blank spherical
	head and no equipment, so every member baked from it is the same body in a
	different colour - and the design pillar that Heikki and Shane read as
	different silhouettes before any detail resolves is then unreachable, no
	matter how the parts are tinted.

	The authored library carries exactly those silhouettes: a broad rifleman, a
	narrow coated gunslinger, a hunched walker, a heavy brute, five bosses. It
	ships them as single unrigged meshes, which is why they were static PNGs.
	`rig_bespren_actor` closes that gap - it fits the KayKit skeleton to each
	authored body and binds the mesh to it, so the 139 CC0 clips drive the
	authored geometry. Everything downstream is unchanged, which is the point of
	returning the exact dict `bake_actor` already consumes.

	`builder` swaps where that body comes from. The default fits the skeleton
	to an authored glTF; `build_actor_body.build` instead authors geometry onto
	the skeleton's own rest pose and binds each shell to the bone that carries
	it. Both hand back the same keys, so this function - and everything after
	it - does not care which was used. It matters because most of the authored
	library turned out to be placeholder solids: a proportion fitted to a
	boulder is a boulder-shaped skeleton, and no clip recovers from that.
	"""
	rig._clear_subjects(scene)
	# The authored path re-imports the same KayKit groups once per actor, and a
	# leftover `Running_A` would make the next import land as `Running_A.001`.
	for action in list(bpy.data.actions):
		bpy.data.actions.remove(action)

	built = (builder or authored.build)(project_root, source, groups)
	mesh, armature = built["mesh"], built["armature"]
	for obj in (armature, mesh):
		if obj.name not in scene.collection.all_objects:
			for coll in list(obj.users_collection):
				coll.objects.unlink(obj)
			scene.collection.objects.link(obj)

	# Heading is driven from a pivot above the armature for the same reason as
	# on the mannequin path: KayKit actions carry object-level channels, so a
	# yaw written onto the armature is erased by the next frame_set().
	pivot = bpy.data.objects.new("BESPREN_ACTOR_PIVOT", None)
	scene.collection.objects.link(pivot)
	armature.parent = pivot
	armature.matrix_parent_inverse = pivot.matrix_world.inverted()
	pivot.scale = tuple(parts.get("scale", (1.0, 1.0, 1.0)))

	resolved = []
	for clip in clips:
		action = built["actions"].get(clip.action) or _find_action(clip.action)
		resolved.append((clip, action))
	found = [action for _, action in resolved if action is not None]
	if not found:
		raise RuntimeError("no actions resolved for %s" % glb_path)

	bounds = measure_animated(scene, [mesh], armature, pivot, found)
	materials = {slot.name: slot.material.name
	             for slot in mesh.material_slots if slot.material}
	return {"meshes": [mesh], "armatures": [armature], "pivot": pivot,
	        "materials": materials, "resolved": resolved, "bounds": bounds,
	        "head_scale": {}, "authored": {
	            "source": os.path.basename(str(source)), "name": built["name"],
	            "profile": built["profile"], "facing": built["facing"],
	            "fit": built["fit"], "skin": built["skin"],
	            "missing_clips": [c.action for c, a in resolved if a is None]}}


def bake_actor(scene, staged: dict, out_dir: str, actor: str,
               shared_frame: dict, cell: int = 64,
               clip_cells: dict = None, density: float = 0.0) -> list:
	"""Render every clip of one staged actor as a directions x frames sheet.

	`density` is pixels per world unit and is shared by the entire roster, so a
	goliath resolves to twice the pixels of a walker because it is twice the
	walker, not because it was framed more generously. `clip_cells` then lets a
	single clip take a wider cell at that same density: the camera keeps its
	position and only its ortho extent grows, which makes the wider cell a
	symmetric expansion around a world point every clip of the actor shares.

	That distinction is the whole point. `death` lays the body flat and at a
	diagonal heading a fallen skeleton projects about twice as wide as a
	standing one. Sizing one shared cell from that pose shrinks every idle,
	walk and run frame the player actually looks at; giving `death` its own
	wider cell costs a few hundred kilobytes and leaves the rest at full size.
	Because density is constant, `ground_offset` - centre_y * cell /
	ortho_scale, i.e. centre_y * density - is the same number of pixels in
	every clip however the cell grows, so one `AnimatedSprite2D.offset` still
	pins every animation's feet to the same point.
	"""
	os.makedirs(out_dir, exist_ok=True)
	meshes = staged["meshes"]
	armature = staged["armatures"][0]
	pivot = staged["pivot"]
	profile = sheet_render_profile(scene)
	clip_cells = clip_cells or {}
	# Position the camera once. Only its ortho extent varies below, and the
	# extent does not move the centre, so every clip stays centred on the same
	# world point.
	camera = apply_shared_camera(scene, shared_frame)
	if density <= 0.0:
		density = cell / max(scene.camera.data.ortho_scale, 1e-6)
	locked_loc = tuple(scene.camera.location)

	# Expose once, on a neutral pose, then hold it for the whole actor.
	# Re-metering per frame would make the finished sheet flicker.
	scene.render.resolution_x = cell * rig.SUPERSAMPLE
	scene.render.resolution_y = cell * rig.SUPERSAMPLE
	scene.view_settings.exposure = 0.0
	meter = rig.auto_expose(scene, os.path.join(out_dir, "_meter.png"))

	results = []
	for clip, action in staged["resolved"]:
		if action is None:
			results.append({"actor": actor, "clip": clip.name,
			                "error": "action not found: %s" % clip.action})
			continue
		frame_dir = os.path.join(out_dir, "_frames_%s_%s" % (actor, clip.name))
		os.makedirs(frame_dir, exist_ok=True)
		clip_cell = int(clip_cells.get(clip.name, cell))
		locked_ortho = clip_cell / density
		clip_camera = dict(camera, ortho_scale=round(locked_ortho, 6),
		                   cell=clip_cell, density=round(density, 4))
		scene.render.resolution_x = clip_cell * rig.SUPERSAMPLE
		scene.render.resolution_y = clip_cell * rig.SUPERSAMPLE
		written = 0
		for row in range(DIRECTIONS):
			yaw = math.radians(YAW_OFFSET_DEG + row * DIR_STEP_DEG)
			for col in range(clip.frames):
				ratio = col / float(clip.frames) if clip.loop else col / float(max(1, clip.frames - 1))
				_pose(scene, armature, action, ratio)
				# Pose and heading must not re-fit the camera or the actor
				# would breathe in and out across the sheet.
				pivot.rotation_euler = (0.0, 0.0, yaw)
				scene.camera.data.ortho_scale = locked_ortho
				scene.camera.location = locked_loc
				scene.render.filepath = os.path.join(frame_dir, "r%d_c%d.png" % (row, col))
				rig._render_still(scene)
				written += 1
		pivot.rotation_euler = (0.0, 0.0, 0.0)
		results.append({"actor": actor, "clip": clip.name, "action": action.name,
		                "rows": DIRECTIONS, "cols": clip.frames, "cell": clip_cell,
		                "frame_dir": frame_dir, "frames": written,
		                "exposure": meter["exposure"], "profile": profile,
		                "materials": staged["materials"], "camera": clip_camera,
		                "bounds": staged["bounds"],
		                "authored": staged.get("authored")})
	return results
