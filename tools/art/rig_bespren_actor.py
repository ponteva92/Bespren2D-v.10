"""Give the authored Bespren characters the KayKit skeleton and its actions.

Two asset families exist and each is half of what a sprite sheet needs.

`Addons/KayKit_Character_Animations_1.1` ships 139 CC0 actions on a mannequin
that is a deliberate chibi toy: its head measures roughly 40 percent of its own
height and its face is a blank egg. Baked at a 64 px cell it reads as a bath
toy, whatever palette is painted onto it.

`../testi/assets/3d` holds authored Bespren geometry - Heikki at 588 tris with a
0.26-unit head on a 1.785-unit body, Shane, six enemies and five bosses -
already carrying the locked BSP palette and the two silhouettes the design
document asks for. None of it has a skeleton.

So this module fits the KayKit skeleton to the authored mesh rather than the
other way round. Bone *directions* are never touched, only lengths and the
offsets that follow from them, which is what keeps all 139 actions valid: a
glTF action stores bone-local rotations, and a rotation is still the same
rotation when the bone it turns is longer.
"""

import math
import os

import bpy
from mathutils import Vector

KAYKIT_RIG = os.path.join("Addons", "KayKit_Character_Animations_1.1",
                          "KayKit_Character_Animations_1.1", "Animations",
                          "gltf", "Rig_Medium")

SPINE_CHAIN = ["hips", "spine", "chest"]
HEAD_CHAIN = ["head"]
LEG_CHAINS = [["upperleg.l", "lowerleg.l", "foot.l", "toes.l"],
              ["upperleg.r", "lowerleg.r", "foot.r", "toes.r"]]
ARM_CHAINS = [["upperarm.l", "lowerarm.l", "wrist.l", "hand.l"],
              ["upperarm.r", "lowerarm.r", "wrist.r", "hand.r"]]

PROFILE_SLICES = 48
DEFORM_SKIP = {"root"}


def _import(path):
	"""Import a glTF and return only what it added."""
	before = set(bpy.data.objects)
	bpy.ops.import_scene.gltf(filepath=path)
	return [o for o in bpy.data.objects if o not in before]


def _activate(obj):
	# Deleting objects leaves empty slots in the view layer list until the
	# depsgraph catches up, and iterating over those slots hands back None.
	# Importing the skeleton first put a batch of deletions immediately before
	# the first selection, which is how a working function started raising.
	bpy.context.view_layer.update()
	for other in list(bpy.context.view_layer.objects):
		if other is not None:
			other.select_set(False)
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj


def _bounds(obj):
	mw = obj.matrix_world
	pts = [mw @ Vector(c) for c in obj.bound_box]
	lo = Vector((min(p[i] for p in pts) for i in range(3)))
	hi = Vector((max(p[i] for p in pts) for i in range(3)))
	return lo, hi


def import_authored(path):
	"""Load an authored actor and hand back one mesh standing on z = 0."""
	imported = _import(path)
	meshes = [o for o in imported if o.type == "MESH"]
	strays = [o for o in meshes if o.name.lower().startswith("icosphere")]
	meshes = [o for o in meshes if o not in strays]
	for stray in strays:
		bpy.data.objects.remove(stray, do_unlink=True)
	if not meshes:
		raise RuntimeError("no mesh in %s" % path)

	if len(meshes) > 1:
		_activate(meshes[0])
		for extra in meshes[1:]:
			extra.select_set(True)
		bpy.ops.object.join()
		meshes = [bpy.context.view_layer.objects.active]
	mesh = meshes[0]

	# Bake the import transform in so every later measurement is in one space.
	_activate(mesh)
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	lo, _ = _bounds(mesh)
	mesh.location -= Vector((0.0, 0.0, lo.z))
	bpy.context.view_layer.update()
	_activate(mesh)
	bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)

	for empty in [o for o in imported if o.type == "EMPTY"]:
		if empty.name in bpy.data.objects:
			bpy.data.objects.remove(empty, do_unlink=True)
	return {"mesh": mesh, "name": os.path.splitext(os.path.basename(path))[0]}


def _extent(points, axis):
	values = [p[axis] for p in points]
	return max(values) - min(values)


def align_to_rig(mesh, rig_forward) -> dict:
	"""Turn the authored actor to face the way the KayKit rig faces.

	The authored library is not internally consistent about orientation: Heikki
	stands with his legs side by side across X and the walker with its legs side
	by side across Y. A single fixed assumption about forward would therefore
	fit the rig to one actor's shoulders and to another actor's chest, and no
	amount of care further down would recover from that.

	Two silhouette facts settle it per actor without any hand-authored table. A
	standing figure is wider across the shoulders than through the chest, which
	names the lateral axis; and its toes overhang the rest of the body on the
	forward side, which names the sign. The correction snaps to a quarter turn
	because these are authored assets sitting on axis, not scans.
	"""
	mw = mesh.matrix_world
	points = [mw @ v.co for v in mesh.data.vertices]
	zs = [p.z for p in points]
	lo_z, hi_z = min(zs), max(zs)
	height = max(hi_z - lo_z, 1e-6)

	upper = [p for p in points if p.z > lo_z + height * 0.60] or points
	lateral = 0 if _extent(upper, 0) >= _extent(upper, 1) else 1
	depth = 1 - lateral

	feet = [p for p in points if p.z < lo_z + height * 0.10] or points
	body_centre = sum(p[depth] for p in points) / float(len(points))
	feet_centre = sum(p[depth] for p in feet) / float(len(feet))
	forward = Vector((0.0, 0.0, 0.0))
	forward[depth] = 1.0 if feet_centre >= body_centre else -1.0

	angle = (math.atan2(rig_forward.y, rig_forward.x)
	         - math.atan2(forward.y, forward.x))
	angle = round(angle / (math.pi * 0.5)) * (math.pi * 0.5)
	if abs(angle) > 1e-6:
		mesh.rotation_euler = (0.0, 0.0, angle)
		bpy.context.view_layer.update()
		_activate(mesh)
		bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
	return {"lateral_axis": "XY"[lateral],
	        "forward": [round(v, 3) for v in forward],
	        "turn_deg": round(math.degrees(angle), 1)}


def measure_profile(mesh) -> dict:
	"""Read hip, shoulder, neck and arm length straight off the silhouette.

	Hard-coded anatomical ratios would put the knee in the right place on a
	survivor and in the wrong place on a hunched walker or a 2.4-unit brute, so
	every landmark is measured from the actor itself.

	The first version of the hip test looked for the highest slice that broke
	into two lobes, and on Heikki it answered 1.283 on a 1.785-unit body: the
	gap it had found was the one between an arm and the ribs, not the one
	between the legs. Two further conditions make the test mean what its name
	says. A leg gap straddles the body's own midline, and it leaves roughly as
	much mesh on one side of it as on the other; an arm gap satisfies neither.

	The shoulder is then found by walking down from the crown until the
	silhouette stops being head-width. That survives the case the old
	widest-slice rule could not - arms hanging wider than the shoulders they
	hang from, which is every actor in this roster.
	"""
	mw = mesh.matrix_world
	points = [mw @ v.co for v in mesh.data.vertices]
	if not points:
		raise RuntimeError("empty mesh")
	zs = [p.z for p in points]
	lo_z, hi_z = min(zs), max(zs)
	height = hi_z - lo_z
	if height <= 1e-6:
		raise RuntimeError("flat mesh")
	step = height / float(PROFILE_SLICES)
	midline = (max(p.x for p in points) + min(p.x for p in points)) * 0.5

	slices = []
	for index in range(PROFILE_SLICES):
		z0 = lo_z + index * step
		top = z0 + step if index < PROFILE_SLICES - 1 else hi_z + 1.0
		band = [p for p in points if z0 <= p.z < top]
		entry = {"z": z0 + step * 0.5, "width": 0.0, "n": len(band), "legs": False}
		if band:
			xs = sorted(p.x for p in band)
			entry["width"] = xs[-1] - xs[0]
			gap, cut, centre = 0.0, 0, midline
			for position, (a, b) in enumerate(zip(xs, xs[1:])):
				if b - a > gap:
					gap, cut, centre = b - a, position + 1, (a + b) * 0.5
			balanced = min(cut, len(xs) - cut) >= max(2, int(len(xs) * 0.20))
			entry["legs"] = (gap > max(height * 0.02, entry["width"] * 0.10)
			                 and abs(centre - midline) < height * 0.08
			                 and balanced)
		slices.append(entry)

	filled = [s for s in slices if s["n"] > 0]
	legs = [s for s in filled if s["legs"]
	        and lo_z + height * 0.25 < s["z"] < lo_z + height * 0.62]
	hip = max(legs, key=lambda s: s["z"]) if legs else \
		min(filled, key=lambda s: abs(s["z"] - (lo_z + height * 0.52)))

	crown = [s["width"] for s in filled if s["z"] > hi_z - height * 0.10]
	head_width = sorted(crown)[len(crown) // 2] if crown else 0.0
	shoulder = None
	for entry in reversed(filled):
		if entry["z"] <= hip["z"]:
			break
		if head_width > 1e-5 and entry["width"] > head_width * 1.6:
			shoulder = entry
			break
	if shoulder is None:
		upper = [s for s in filled if s["z"] > lo_z + height * 0.55]
		shoulder = max(upper or filled, key=lambda s: s["width"])

	above = [s for s in filled if shoulder["z"] < s["z"] < hi_z - height * 0.12]
	neck = min(above, key=lambda s: s["width"]) if above else shoulder

	# Arms are the outermost vertical column above the hip, so how far they
	# reach down from the shoulder is their length - which is the measurement
	# the rig actually needs, and the one an arms-down silhouette refuses to
	# give sideways.
	torso = [p for p in points if p.z > hip["z"]]
	reach = max((abs(p.x - midline) for p in torso), default=0.0)
	limb = [p for p in torso if abs(p.x - midline) > reach * 0.62]
	arm_len = (shoulder["z"] - min(p.z for p in limb)) if len(limb) >= 8 else 0.0
	if arm_len <= height * 0.10:
		arm_len = height * 0.38

	# Measurement wins inside a plausible band and a prior wins outside it.
	# Silhouette reading is honest on a survivor and unreliable on a hunched
	# walker whose legs never separate or a brute whose head merges into its
	# shoulders: unguarded, those two answered a hip at 6 percent of body height
	# and a shoulder below the hip, and the fit multipliers then hit their own
	# clamps and tore the actor apart. Guarding here keeps the failure mode to
	# "slightly generic proportions" instead of "exploded mesh".
	measured = {"hip": (hip["z"] - lo_z) / height,
	            "shoulder": (shoulder["z"] - lo_z) / height,
	            "neck": (neck["z"] - lo_z) / height,
	            "arm": arm_len / height}
	hip_r = min(max(measured["hip"], 0.40), 0.60)
	shoulder_r = min(max(measured["shoulder"], 0.70), 0.88)
	neck_r = min(max(measured["neck"], max(shoulder_r + 0.02, 0.80)), 0.92)
	arm_r = min(max(measured["arm"], 0.28), 0.50)
	return {"height": height, "floor": lo_z, "top": hi_z,
	        "hip_z": hip_r * height, "shoulder_z": shoulder_r * height,
	        "neck_z": neck_r * height, "arm_len": arm_r * height,
	        "half_width": reach, "arm_span": reach * 2.0,
	        "head_width": head_width, "legs_found": bool(legs),
	        "measured": {k: round(v, 3) for k, v in measured.items()},
	        "guarded": {k: round(v, 3) for k, v in
	                    (("hip", hip_r), ("shoulder", shoulder_r),
	                     ("neck", neck_r), ("arm", arm_r))},
	        "profile": [(round(s["z"], 3), round(s["width"], 3)) for s in slices]}


def import_skeleton(project_root, groups):
	"""Bring in the KayKit armature plus every action from the named groups."""
	armature = None
	actions = {}
	# A re-import of the same group lands as `Running_A.001`, and this runs once
	# per actor, so harvesting raw names would hand back a dictionary that no
	# clip list can look anything up in. Clearing the orphans the previous actor
	# left behind keeps the names clean; stripping the suffix covers the rest.
	for stale in list(bpy.data.actions):
		if stale.users == 0:
			bpy.data.actions.remove(stale)
	for index, group in enumerate(groups):
		path = os.path.join(project_root, KAYKIT_RIG, "Rig_Medium_%s.glb" % group)
		if not os.path.exists(path):
			raise RuntimeError("missing KayKit group: %s" % path)
		known = {a.name for a in bpy.data.actions}
		imported = _import(path)
		for action in bpy.data.actions:
			if action.name in known:
				continue
			stem, _, suffix = action.name.rpartition(".")
			actions[stem if suffix.isdigit() and len(suffix) == 3
			        else action.name] = action
		arms = [o for o in imported if o.type == "ARMATURE"]
		if index == 0 and arms:
			armature = arms[0]
			drop = [o for o in imported if o is not armature]
		else:
			# Later groups exist only for their actions; their duplicate rigs
			# would otherwise pile up empty mannequins in the stage.
			drop = list(imported)
		for obj in drop:
			if obj.name in bpy.data.objects:
				bpy.data.objects.remove(obj, do_unlink=True)
	if armature is None:
		raise RuntimeError("no armature imported")
	_activate(armature)
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	return {"armature": armature, "actions": actions}


def _rest_positions(armature):
	return {b.name: (b.head_local.copy(), b.tail_local.copy())
	        for b in armature.data.bones}


def _hierarchy_order(armature):
	order = []

	def walk(bone):
		order.append(bone.name)
		for child in bone.children:
			walk(child)

	for bone in armature.data.bones:
		if bone.parent is None:
			walk(bone)
	return order


def _safe(target, source):
	if source <= 1e-5 or target <= 1e-5:
		return 1.0
	return max(0.25, min(4.0, target / source))


def fit_skeleton(armature, profile):
	"""Stretch the KayKit rest pose onto the authored figure.

	Every bone keeps its own direction vector and only changes length, so each
	bone's rest orientation - and therefore the meaning of every rotation key in
	all 139 actions - is preserved exactly. What changes is where the joints sit,
	which is the whole point: the chibi rig's knee lands at 30 percent of its own
	height and Heikki's knee is at 30 percent of a body proportioned completely
	differently.
	"""
	_activate(armature)
	rest = _rest_positions(armature)
	rig_height = max(max(h.z, t.z) for h, t in rest.values())
	if rig_height <= 1e-6:
		raise RuntimeError("degenerate armature")
	uniform = profile["height"] / rig_height

	rig_hip = rest["upperleg.l"][0].z * uniform
	rig_shoulder = rest["upperarm.l"][0].z * uniform
	rig_head_len = (rest["head"][1] - rest["head"][0]).length * uniform
	rig_arm = sum((rest[n][1] - rest[n][0]).length for n in ARM_CHAINS[0]) * uniform

	leg_mult = _safe(profile["hip_z"], rig_hip)
	spine_mult = _safe(profile["shoulder_z"] - profile["hip_z"],
	                   rig_shoulder - rig_hip)
	head_mult = _safe(profile["height"] - profile["neck_z"], rig_head_len)
	arm_mult = _safe(profile["arm_len"], rig_arm)

	scales = {"hips": spine_mult}
	for chain in LEG_CHAINS:
		for name in chain:
			scales[name] = leg_mult
	for name in SPINE_CHAIN[1:]:
		scales[name] = spine_mult
	for name in HEAD_CHAIN:
		scales[name] = head_mult
	for chain in ARM_CHAINS:
		for name in chain:
			scales[name] = arm_mult

	armature.scale = (uniform, uniform, uniform)
	bpy.context.view_layer.update()
	_activate(armature)
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

	bpy.ops.object.mode_set(mode="EDIT")
	edit = armature.data.edit_bones
	before = {b.name: (b.head.copy(), b.tail.copy()) for b in edit}
	placed = {}
	for name in _hierarchy_order(armature):
		if name not in before:
			continue
		bone = edit[name]
		old_head, old_tail = before[name]
		if bone.parent is None:
			new_head = old_head.copy()
		else:
			parent_old_tail = before[bone.parent.name][1]
			parent_new_tail = placed[bone.parent.name][1]
			if bone.use_connect:
				new_head = parent_new_tail.copy()
			else:
				new_head = parent_new_tail + (old_head - parent_old_tail)
		direction = old_tail - old_head
		placed[name] = (new_head, new_head + direction * scales.get(name, 1.0))
	for name, (head, tail) in placed.items():
		edit[name].head = head
		edit[name].tail = tail
	bpy.ops.object.mode_set(mode="OBJECT")

	# Drop the whole rig so the feet land on the floor the mesh stands on.
	foot_z = min(min(h.z, t.z) for h, t in _rest_positions(armature).values())
	armature.location.z -= foot_z
	bpy.context.view_layer.update()
	_activate(armature)
	bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)

	return {"uniform": round(uniform, 4), "leg": round(leg_mult, 4),
	        "spine": round(spine_mult, 4), "head": round(head_mult, 4),
	        "arm": round(arm_mult, 4),
	        "rig_hip": round(rig_hip, 4),
	        "target_hip": round(profile["hip_z"], 4),
	        "rig_shoulder": round(rig_shoulder, 4),
	        "target_shoulder": round(profile["shoulder_z"], 4),
	        "rig_arm": round(rig_arm, 4),
	        "target_arm": round(profile["arm_len"], 4)}


def _segment_distance(point, a, b):
	ab = b - a
	length_sq = ab.length_squared
	if length_sq < 1e-9:
		return (point - a).length
	t = max(0.0, min(1.0, (point - a).dot(ab) / length_sq))
	return (point - (a + ab * t)).length


def _islands(mesh) -> list:
	"""Group vertices into connected shells with a union-find over the edges."""
	parent = list(range(len(mesh.data.vertices)))

	def find(index):
		while parent[index] != index:
			parent[index] = parent[parent[index]]
			index = parent[index]
		return index

	for edge in mesh.data.edges:
		a, b = (find(v) for v in edge.vertices)
		if a != b:
			parent[a] = b
	groups = {}
	for index in range(len(parent)):
		groups.setdefault(find(index), []).append(index)
	return list(groups.values())


def _common_ancestor(armature, names) -> str:
	"""Deepest bone that every one of `names` descends from."""
	chains = []
	for name in names:
		bone = armature.data.bones.get(name)
		path = []
		while bone is not None:
			path.append(bone.name)
			bone = bone.parent
		chains.append(path[::-1])
	if not chains:
		return "hips"
	common = chains[0]
	for chain in chains[1:]:
		cut = 0
		while cut < min(len(common), len(chain)) and common[cut] == chain[cut]:
			cut += 1
		common = common[:cut]
	name = common[-1] if common else "hips"
	return "hips" if name in DEFORM_SKIP else name


def _weights(point, segments, power, top_k) -> list:
	ranked = sorted((_segment_distance(point, head, tail), name)
	                for name, head, tail in segments)[:max(1, top_k)]
	raw = [(name, 1.0 / (dist ** power + 1e-6)) for dist, name in ranked]
	total = sum(w for _, w in raw)
	return [(name, weight / total) for name, weight in raw]


def skin(mesh, armature, power=4.0, top_k=2, rigid_span=0.0) -> dict:
	"""Weight the mesh by inverse distance, one rigid shell at a time.

	Blender's own automatic weights solve a heat equation over a closed surface.
	These actors are not closed surfaces - Shane alone is 106 separate shells,
	plates and straps floating beside each other - so heat weighting either
	fails outright or silently falls back to envelopes sized for a rig that has
	just been re-proportioned.

	Inverse-distance weighting has no such precondition, but weighting each
	vertex independently is what tore Shane and the walker into confetti in the
	first probe: a shoulder plate spanning two bones had half its corners follow
	the arm and half follow the chest, and nothing in the mesh held it together
	because there was nothing connecting those corners. So a shell small enough
	to be one solid piece is weighted once, at its centroid, and every vertex in
	it is given that same result - it can then swing, but it cannot come apart.
	Shells too large to be rigid, meaning the body itself, keep the per-vertex
	path, which is what puts a real bend at the knee.
	"""
	bones = [b for b in armature.data.bones if b.name not in DEFORM_SKIP]
	segments = [(b.name, b.head_local.copy(), b.tail_local.copy()) for b in bones]
	to_arm = armature.matrix_world.inverted() @ mesh.matrix_world
	if rigid_span <= 0.0:
		reach = max((max(h.z, t.z) for _, h, t in segments), default=1.0)
		rigid_span = reach * 0.25

	for bone_name, _, _ in segments:
		if bone_name not in mesh.vertex_groups:
			mesh.vertex_groups.new(name=bone_name)

	counts = {}
	rigid = 0
	frozen = set()
	for island in _islands(mesh):
		coords = [to_arm @ mesh.data.vertices[i].co for i in island]
		lo = Vector((min(c[k] for c in coords) for k in range(3)))
		hi = Vector((max(c[k] for c in coords) for k in range(3)))
		if (hi - lo).length <= rigid_span:
			# Where a rigid shell lies entirely beside one bone, the centroid
			# answers correctly and a soft two-bone blend keeps it from popping.
			# Where it spans two, the centroid answers confidently and wrongly:
			# Shane's coat hem is a single ring whose midpoint sits nearest a
			# foot, so a running cycle flung the whole hem out with that foot.
			# A shell straddling two limbs belongs to what those limbs have in
			# common - two feet resolve to the hips, an arm and the ribs resolve
			# to the chest - and it then swings as one piece, which is the only
			# thing a rigid shell can do without coming apart.
			nearest = {_weights(c, segments, power, 1)[0][0] for c in coords}
			if len(nearest) == 1:
				centre = sum(coords, Vector()) / float(len(coords))
				shared = _weights(centre, segments, power, top_k)
			else:
				shared = [(_common_ancestor(armature, sorted(nearest)), 1.0)]
			for name, weight in shared:
				mesh.vertex_groups[name].add(island, weight, "REPLACE")
			counts[shared[0][0]] = counts.get(shared[0][0], 0) + len(island)
			frozen.update(island)
			rigid += 1
			continue
		for index, point in zip(island, coords):
			solved = _weights(point, segments, power, top_k)
			for name, weight in solved:
				mesh.vertex_groups[name].add([index], weight, "REPLACE")
			counts[solved[0][0]] = counts.get(solved[0][0], 0) + 1

	mesh.parent = armature
	mesh.matrix_parent_inverse = armature.matrix_world.inverted()
	modifier = mesh.modifiers.new(name="BESPREN_SKIN", type="ARMATURE")
	modifier.object = armature
	modifier.use_vertex_groups = True
	islands = _islands(mesh)
	return {"bones_used": len(counts), "islands": len(islands),
	        "rigid_islands": rigid, "rigid_span": round(rigid_span, 4),
	        "frozen_vertices": len(frozen),
	        "dominant": dict(sorted(counts.items(), key=lambda kv: -kv[1])[:8])}


def build(project_root, glb_path, groups, power=4.0, top_k=2):
	"""Full path from an authored glTF to a posable, animated actor."""
	rig = import_skeleton(project_root, groups)
	actor = import_authored(glb_path)
	# The rig states its own forward through the toe bone rather than through a
	# constant, so a future roster member on a different skeleton still aligns.
	toes = rig["armature"].data.bones.get("toes.l")
	forward = Vector((0.0, -1.0, 0.0))
	if toes is not None:
		flat = toes.tail_local - toes.head_local
		flat.z = 0.0
		if flat.length > 1e-5:
			forward = flat.normalized()
	facing = align_to_rig(actor["mesh"], forward)
	profile = measure_profile(actor["mesh"])
	fitted = fit_skeleton(rig["armature"], profile)
	bound = skin(actor["mesh"], rig["armature"], power=power, top_k=top_k,
	             rigid_span=profile["height"] * 0.25)
	return {"mesh": actor["mesh"], "armature": rig["armature"],
	        "actions": rig["actions"], "name": actor["name"],
	        "profile": {k: v for k, v in profile.items() if k != "profile"},
	        "facing": facing, "fit": fitted, "skin": bound}
