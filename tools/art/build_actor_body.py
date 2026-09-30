"""Author Bespren actor bodies directly onto the KayKit skeleton.

`rig_bespren_actor` solves the opposite problem: it takes an authored mesh and
fits a skeleton to it. That is the right tool when the mesh is good, and it is
proven on `char_heikki_rifleman` - the fitted rest pose is indistinguishable
from the source and the walk and run cycles read correctly.

It is the wrong tool for the rest of the roster, because the rest of the roster
does not exist. `testi/assets/3d` ships Shane as a cone with a sphere on top,
and every enemy and boss as an untextured boulder. A probe render of the raw
glTF, before any rig code touches it, is what settled that: the blobs are the
source, not the deformation. No skinning recovers a silhouette the geometry
never had, and `Addons/` has no creature meshes either - only KayKit's own
mannequins.

So this module inverts the problem. Instead of guessing where a blob's hips
are, it places geometry at bone positions it already knows exactly, and binds
each shell to the bone it was built around. That removes the entire class of
failure the fitting path fights: there is no landmark to mis-measure, no
guardrail to clamp, no ambiguity about which bone owns a vertex. Every one of
the 119 CC0 clips then drives the result by construction.

The bodies are parameterised rather than hand-modelled. `humanoid()` emits a
complete figure from proportions, and each roster member is those proportions
plus a short list of signature shells - the goliath's horns, the bulwark's
front plate, the conduit's forked prongs. That is what makes ten distinct
silhouettes maintainable, and it is what the "two players, two signatures"
pillar needs: Heikki and Shane differ in mass and outline, not in hue.

Everything is built from explicit vertex and face lists. No bpy.ops, because
operators depend on context that does not exist in `--background`.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy
from mathutils import Vector

import aaa_bake_rig as rig
import rig_bespren_actor as fitrig

# The skeleton is a T-pose roughly 1.49 units tall, arms out along +/-X at
# z=1.1068. Shells are authored in these armature-space units and the finished
# actor is scaled once, so proportions stay comparable across the roster.
RIG_HEIGHT = 1.4923


# --------------------------------------------------------------------------
# geometry
# --------------------------------------------------------------------------

def _frame(axis: Vector, up: Vector):
	"""A stable orthonormal frame around `axis`, biased to `up`."""
	axis = axis.normalized()
	if abs(axis.dot(up)) > 0.999:
		up = Vector((0.0, 1.0, 0.0)) if abs(axis.z) > 0.9 else Vector((0.0, 0.0, 1.0))
	side = axis.cross(up).normalized()
	return side, side.cross(axis).normalized()


def prism(a, b, r0, r1, sides: int = 6, up=(0.0, 0.0, 1.0), roll: float = 0.0):
	"""A tapered n-gon prism from `a` to `b`, radii given as (x, y) pairs.

	This one primitive covers limbs, torsos, plates, horns and spikes. Keeping
	the roster on a single shape family is deliberate: it is what makes the
	silhouettes read as one art direction rather than ten separate experiments.
	"""
	a, b = Vector(a), Vector(b)
	r0 = (r0, r0) if isinstance(r0, (int, float)) else r0
	r1 = (r1, r1) if isinstance(r1, (int, float)) else r1
	side, other = _frame(b - a, Vector(up))
	verts, faces = [], []
	for end, radius in ((a, r0), (b, r1)):
		for i in range(sides):
			theta = roll + 2.0 * math.pi * i / sides
			verts.append(end + side * (radius[0] * math.cos(theta))
			             + other * (radius[1] * math.sin(theta)))
	for i in range(sides):
		j = (i + 1) % sides
		faces.append([i, j, sides + j, sides + i])
	faces.append(list(range(sides - 1, -1, -1)))
	faces.append(list(range(sides, sides * 2)))
	return [tuple(v) for v in verts], faces


def ball(centre, radii, rings: int = 4, segs: int = 8):
	"""A low-resolution ellipsoid for heads and organic masses."""
	centre = Vector(centre)
	radii = (radii, radii, radii) if isinstance(radii, (int, float)) else radii
	verts = [tuple(centre + Vector((0.0, 0.0, radii[2])))]
	for ring in range(1, rings):
		phi = math.pi * ring / rings
		for seg in range(segs):
			theta = 2.0 * math.pi * seg / segs
			verts.append(tuple(centre + Vector((
				radii[0] * math.sin(phi) * math.cos(theta),
				radii[1] * math.sin(phi) * math.sin(theta),
				radii[2] * math.cos(phi)))))
	verts.append(tuple(centre - Vector((0.0, 0.0, radii[2]))))
	bottom = len(verts) - 1
	faces = []
	for seg in range(segs):
		faces.append([0, 1 + (seg + 1) % segs, 1 + seg])
	for ring in range(rings - 2):
		base, nxt = 1 + ring * segs, 1 + (ring + 1) * segs
		for seg in range(segs):
			s = (seg + 1) % segs
			faces.append([base + seg, base + s, nxt + s, nxt + seg])
	base = 1 + (rings - 2) * segs
	for seg in range(segs):
		faces.append([base + seg, base + (seg + 1) % segs, bottom])
	return verts, faces


# --------------------------------------------------------------------------
# shells
# --------------------------------------------------------------------------

class Shell:
	"""One rigid piece of geometry and the bone that carries it."""

	def __init__(self, bone, verts, faces, material, mirror=True):
		self.bone = bone
		self.verts = verts
		self.faces = faces
		self.material = material
		self.mirror = mirror


def limb(bone, r0, r1, mat, sides=6, t0=0.0, t1=1.0, up=(0, 0, 1)):
	"""A shell that spans its own bone - the common case for arms and legs."""
	return ("limb", bone, dict(r0=r0, r1=r1, mat=mat, sides=sides, t0=t0, t1=t1, up=up))


def bar(bone, a, b, r0, r1, mat, sides=6, up=(0, 0, 1), roll=0.0, mirror=True):
	"""A shell placed by explicit armature-space endpoints."""
	return ("bar", bone, dict(a=a, b=b, r0=r0, r1=r1, mat=mat, sides=sides,
	                          up=up, roll=roll, mirror=mirror))


def blob(bone, at, radii, mat, rings=4, segs=8, mirror=True):
	return ("blob", bone, dict(at=at, radii=radii, mat=mat, rings=rings,
	                           segs=segs, mirror=mirror))


def _along(armature, bone_name, t):
	bone = armature.data.bones[bone_name]
	return bone.head_local.lerp(bone.tail_local, t)


def _mirror_bone(name):
	if name.endswith(".l"):
		return name[:-2] + ".r"
	if name.endswith(".r"):
		return name[:-2] + ".l"
	return name


def realise(armature, parts):
	"""Turn the declarative part list into concrete `Shell` objects.

	Left-side parts are authored once and mirrored across X onto the matching
	`.r` bone. Asymmetry is then a deliberate act - Shane's single pauldron and
	the bulwark's off-centre plate say `mirror=False` - rather than something
	that happens by accident because a number was typed twice.
	"""
	shells = []
	for kind, bone, spec in parts:
		if kind == "limb":
			# A limb spans its own bone, so mirroring it means mirroring the
			# bone. On a centre bone there is nothing to mirror onto.
			mirrorable = bone.endswith((".l", ".r"))
		else:
			# Explicitly placed geometry mirrors whenever it sits off the
			# centre line - the walker's shoulder sludge hangs on both sides
			# even though it is carried by the single `chest` bone.
			extent = max(abs(Vector(spec[k]).x) for k in ("a", "b", "at")
			             if k in spec)
			mirrorable = spec.get("mirror", True) and extent > 1e-4
		sides_wanted = [False, True] if mirrorable else [False]
		for flipped in sides_wanted:
			target = _mirror_bone(bone) if flipped else bone
			if target not in armature.data.bones:
				continue
			sign = -1.0 if flipped else 1.0
			if kind == "limb":
				a = _along(armature, target, spec["t0"])
				b = _along(armature, target, spec["t1"])
				verts, faces = prism(a, b, spec["r0"], spec["r1"],
				                     spec["sides"], spec["up"])
			elif kind == "bar":
				a = Vector(spec["a"]); a.x *= sign
				b = Vector(spec["b"]); b.x *= sign
				verts, faces = prism(a, b, spec["r0"], spec["r1"],
				                     spec["sides"], spec["up"], spec["roll"])
			else:
				at = Vector(spec["at"]); at.x *= sign
				verts, faces = ball(at, spec["radii"], spec["rings"], spec["segs"])
			shells.append(Shell(target, verts, faces, spec["mat"]))
	return shells


# --------------------------------------------------------------------------
# the parameterised humanoid
# --------------------------------------------------------------------------

def humanoid(*, skin="NECROTIC_FLESH", cloth="CLOTH_OLIVE", metal="DARK_IRON",
             head_r=(0.115, 0.115, 0.125), head_z=0.62, neck_r=0.052,
             chest_r=(0.175, 0.115), waist_r=(0.13, 0.095), hip_r=(0.145, 0.105),
             shoulder=0.0, shoulder_mat=None, arm_r=(0.058, 0.046),
             leg_r=(0.082, 0.062), foot=(0.075, 0.135, 0.045),
             hunch=0.0, head_mat=None, extras=(), sides=6):
	"""A complete figure from proportions alone.

	`hunch` slides the head and chest forward along -Y, which is the whole
	difference between a soldier standing upright and a shambling infected. It
	is a proportion rather than an animation so it survives every clip.
	"""
	head_mat = head_mat or skin
	parts = []

	# torso: hips -> spine -> chest, tapering so the shoulders read widest
	parts.append(limb("hips", hip_r, waist_r, cloth, sides))
	parts.append(limb("spine", waist_r, chest_r, cloth, sides))
	parts.append(bar("chest", (0.0, -hunch * 0.35, 0.9726),
	                 (0.0, -hunch, 1.2235), chest_r,
	                 (chest_r[0] * 0.82, chest_r[1] * 0.9), cloth, sides,
	                 mirror=False))
	# neck and head ride the hunch so the silhouette stays connected
	parts.append(bar("head", (0.0, -hunch * 1.05, 1.2050),
	                 (0.0, -hunch * 1.15, 1.2900), neck_r, neck_r * 0.92,
	                 skin, sides, mirror=False))
	parts.append(blob("head", (0.0, -hunch * 1.2, 1.2414 + head_z * 0.251),
	                  head_r, head_mat, mirror=False))

	if shoulder > 0.0:
		parts.append(bar("upperarm.l", (0.175, 0.0, 1.115), (0.315, 0.0, 1.075),
		                 (shoulder, shoulder * 0.8), (shoulder * 0.62, shoulder * 0.55),
		                 shoulder_mat or metal, sides))

	parts.append(limb("upperarm.l", arm_r[0], arm_r[0] * 0.9, skin, sides))
	parts.append(limb("lowerarm.l", arm_r[0] * 0.88, arm_r[1], skin, sides))
	parts.append(limb("hand.l", arm_r[1] * 1.25, arm_r[1] * 0.9, skin, sides))

	parts.append(limb("upperleg.l", leg_r[0], leg_r[0] * 0.86, cloth, sides))
	parts.append(limb("lowerleg.l", leg_r[0] * 0.84, leg_r[1], cloth, sides))
	parts.append(bar("foot.l", (0.1709, 0.02, 0.145 - foot[2]),
	                 (0.1709, -0.115, 0.030),
	                 (foot[0], foot[2] * 1.5), (foot[0] * 0.9, foot[2]),
	                 metal, sides))
	parts.extend(extras)
	return parts


# --------------------------------------------------------------------------
# roster
# --------------------------------------------------------------------------

def _hero_common(accent):
	return [
		# chest rig and belt, shared so the two survivors read as one faction
		bar("chest", (0.0, -0.09, 1.06), (0.0, -0.10, 1.20), (0.10, 0.035),
		    (0.075, 0.03), "CLOTH_LEATHER", 6, mirror=False),
		bar("hips", (0.0, 0.0, 0.545), (0.0, 0.0, 0.575), (0.155, 0.115),
		    (0.155, 0.115), "CLOTH_LEATHER", 8, mirror=False),
		bar("chest", (0.055, -0.10, 1.145), (0.055, -0.105, 1.075), 0.022, 0.022,
		    accent, 5),
	]


def _rifle():
	"""A rifle in the right hand slot, bound to the hand so it swings with it."""
	return [
		bar("hand.r", (-0.86, 0.10, 1.085), (-0.86, -0.34, 1.085), (0.028, 0.030),
		    (0.020, 0.022), "DARK_IRON", 6, mirror=False),
		bar("hand.r", (-0.86, -0.04, 1.055), (-0.86, 0.10, 1.020), (0.024, 0.020),
		    (0.020, 0.018), "DECAYED_WOOD", 6, mirror=False),
		bar("hand.r", (-0.86, -0.20, 1.085), (-0.86, -0.20, 1.130), 0.014, 0.012,
		    "ACCENT_GOLD", 5, mirror=False),
	]


def _pistol():
	return [
		bar("hand.r", (-0.86, 0.02, 1.085), (-0.86, -0.20, 1.085), (0.024, 0.026),
		    (0.017, 0.019), "IRON_SILVER", 6, mirror=False),
		bar("hand.r", (-0.86, 0.01, 1.075), (-0.86, 0.05, 1.020), 0.021, 0.018,
		    "CLOTH_LEATHER", 6, mirror=False),
		bar("hand.r", (-0.86, -0.13, 1.098), (-0.86, -0.13, 1.126), 0.012, 0.010,
		    "ACCENT_TEAL", 5, mirror=False),
	]


ROSTER = {}


def _actor(key, height, parts, clips, tier="actor"):
	ROSTER[key] = {"height": height, "parts": parts, "clips": clips, "tier": tier}


HERO_CLIPS = ["idle", "walk", "run", "shoot", "gather", "hit", "death"]
FOE_CLIPS = ["idle", "walk", "attack", "hit", "death", "spawn"]

# --- heroes ---------------------------------------------------------------
# Heikki: broad, stable, gold. Shane: narrow, asymmetric, teal. The pillar is
# that this is legible from the outline alone, so the difference is carried by
# shoulder width, torso taper and a one-sided pauldron - not by tint.
_actor("hero_heikki", 1.78, humanoid(
	skin="SKIN_PALE", cloth="CLOTH_OLIVE", metal="DARK_IRON",
	head_mat="DARK_IRON", head_r=(0.125, 0.128, 0.108), head_z=0.55,
	chest_r=(0.205, 0.128), waist_r=(0.150, 0.104), hip_r=(0.160, 0.112),
	shoulder=0.085, shoulder_mat="CLOTH_OLIVE",
	arm_r=(0.066, 0.050), leg_r=(0.092, 0.068), foot=(0.082, 0.14, 0.05),
	extras=_hero_common("ACCENT_GOLD") + _rifle() + [
		# back tank: the mass that makes his outline unmistakably the broad one
		bar("chest", (0.062, 0.115, 1.010), (0.062, 0.125, 1.215), 0.058, 0.052,
		    "RUSTED_IRON", 8),
		bar("chest", (0.0, 0.125, 1.215), (0.0, 0.125, 1.255), (0.115, 0.030),
		    (0.100, 0.026), "DARK_IRON", 6, mirror=False),
		# helmet brim, front only, to break the skull into a readable shape
		bar("head", (0.0, -0.075, 1.380), (0.0, -0.155, 1.372), (0.118, 0.030),
		    (0.098, 0.022), "DARK_IRON", 6, mirror=False),
	]), HERO_CLIPS)

_actor("hero_shane", 1.74, humanoid(
	skin="SKIN_PALE", cloth="CLOTH_LEATHER", metal="DARK_IRON",
	head_mat="CLOTH_LEATHER", head_r=(0.104, 0.108, 0.112), head_z=0.58,
	chest_r=(0.152, 0.104), waist_r=(0.118, 0.088), hip_r=(0.132, 0.100),
	shoulder=0.0, arm_r=(0.052, 0.042), leg_r=(0.078, 0.058),
	foot=(0.072, 0.13, 0.044),
	extras=_hero_common("ACCENT_TEAL") + _pistol() + [
		# one pauldron only - the asymmetry is the signature
		bar("upperarm.l", (0.168, 0.0, 1.128), (0.330, 0.0, 1.062),
		    (0.098, 0.082), (0.070, 0.058), "DARK_IRON", 6, mirror=False),
		bar("upperarm.l", (0.205, 0.0, 1.148), (0.300, 0.0, 1.100), 0.020, 0.016,
		    "ACCENT_TEAL", 5, mirror=False),
		# coat tails: two narrow panels, so a run cycle reads as cloth
		bar("hips", (0.070, 0.055, 0.520), (0.082, 0.075, 0.235),
		    (0.060, 0.030), (0.052, 0.024), "CLOTH_LEATHER", 5),
		# tech cell and antenna
		bar("chest", (-0.070, 0.100, 1.030), (-0.070, 0.108, 1.150), 0.044, 0.040,
		    "OXIDIZED_COPPER", 6, mirror=False),
		bar("chest", (-0.070, 0.104, 1.150), (-0.052, 0.104, 1.420), 0.010, 0.005,
		    "IRON_SILVER", 4, mirror=False),
		bar("chest", (-0.052, 0.104, 1.420), (-0.050, 0.104, 1.452), 0.016, 0.014,
		    "ACCENT_TEAL", 5, mirror=False),
	]), HERO_CLIPS)

# --- variant 0: walker / toxic_brute / broad_shoulders ---------------------
_actor("walker", 1.95, humanoid(
	skin="NECROTIC_FLESH", cloth="CLOTH_OLIVE", metal="DARK_IRON",
	head_r=(0.098, 0.100, 0.092), head_z=0.30, neck_r=0.040,
	chest_r=(0.215, 0.130), waist_r=(0.140, 0.100), hip_r=(0.150, 0.108),
	shoulder=0.125, shoulder_mat="NECROTIC_FLESH",
	arm_r=(0.070, 0.052), leg_r=(0.090, 0.064), hunch=0.085,
	extras=[
		# the brief is broad_shoulders: a trapezius slab wider than the head is
		# tall, with the skull sunk between the two masses
		bar("chest", (0.0, -0.02, 1.205), (0.0, -0.02, 1.245), (0.245, 0.115),
		    (0.215, 0.100), "NECROTIC_FLESH", 6, mirror=False),
		blob("upperarm.l", (0.225, -0.01, 1.150), (0.098, 0.092, 0.080),
		     "NECROTIC_FLESH"),
		# toxic sludge weeping from the shoulders and mouth
		bar("chest", (0.150, -0.06, 1.215), (0.168, -0.05, 1.120), 0.026, 0.014,
		    "TOXIC_SLUDGE", 5),
		bar("head", (0.0, -0.175, 1.330), (0.0, -0.160, 1.255), 0.020, 0.012,
		    "TOXIC_SLUDGE", 5, mirror=False),
	]), FOE_CLIPS)

# --- variant 1: rat_swarm / infected_crawler_pack / three_low_crawlers -----
def _crawler(offset, scale, mat, bone):
	"""One low crawler, offset within the pack and carried by a single bone.

	Every shell here binds to the same bone on purpose. A crawler sits well
	away from the skeleton's centre line, so splitting it across bones makes
	each piece orbit a pivot it is nowhere near - the first probe showed the
	pack bursting apart mid-stride for exactly that reason. Bound as one rigid
	body it scuttles instead, and giving the three crawlers three torso bones
	rather than three limb bones keeps the scuttle from tipping them over.

	The stance is deliberately squat. Long thin legs turned the second probe's
	pack into mosquitoes; at the 64 px cell this ships in, a crawler has to be
	body first and legs second or it dissolves into scratches.
	"""
	ox, oy, oz = offset
	s = scale
	parts = [
		# body: a low hunched sac, wider than it is tall
		bar(bone, (ox, oy + 0.115 * s, oz + 0.545), (ox, oy - 0.150 * s, oz + 0.512),
		    (0.128 * s, 0.092 * s), (0.086 * s, 0.068 * s), mat, 6, mirror=False),
		# haunches, so the outline has shoulders instead of a smooth tube
		blob(bone, (ox, oy + 0.070 * s, oz + 0.560), (0.130 * s, 0.086 * s, 0.078 * s),
		     mat, mirror=False),
		blob(bone, (ox, oy - 0.205 * s, oz + 0.498), (0.070 * s, 0.078 * s, 0.062 * s),
		     mat, mirror=False),
		# jaw tusks - the only bright value on the creature, and what sells the
		# front of the silhouette at distance
		bar(bone, (ox - 0.034 * s, oy - 0.250 * s, oz + 0.492),
		    (ox - 0.052 * s, oy - 0.316 * s, oz + 0.474), 0.020 * s, 0.008 * s,
		    "BONE", 4, mirror=False),
		bar(bone, (ox + 0.034 * s, oy - 0.250 * s, oz + 0.492),
		    (ox + 0.052 * s, oy - 0.316 * s, oz + 0.474), 0.020 * s, 0.008 * s,
		    "BONE", 4, mirror=False),
		# spore vent on the back
		bar(bone, (ox, oy + 0.090 * s, oz + 0.612), (ox, oy + 0.140 * s, oz + 0.664),
		    0.032 * s, 0.013 * s, "TOXIC_SLUDGE", 4, mirror=False),
	]
	# three short leg pairs rather than one long pair: the count is what reads
	# as "vermin", and short legs keep the mass low where the brief wants it
	for index, (fy, splay, drop) in enumerate((( 0.070, 0.150, 0.352),
	                                           (-0.020, 0.162, 0.344),
	                                           (-0.110, 0.142, 0.356))):
		for sign in (-1.0, 1.0):
			hip = (ox + sign * 0.070 * s, oy + fy * s, oz + 0.520)
			knee = (ox + sign * splay * s, oy + (fy - 0.010) * s, oz + 0.430)
			toe = (ox + sign * (splay + 0.014) * s, oy + (fy - 0.030) * s,
			       oz + drop)
			parts.append(bar(bone, hip, knee, 0.038 * s, 0.026 * s, mat, 5,
			                 mirror=False))
			parts.append(bar(bone, knee, toe, 0.026 * s, 0.014 * s,
			                 "BONE" if index == 1 else mat, 4, mirror=False))
	return parts


# The three crawlers ride three torso bones. Those sway in a walk cycle without
# swinging through the large arcs the leg bones do, so the pack staggers against
# itself while every body stays upright and intact.
_actor("rat_swarm", 0.92,
       _crawler((0.0, -0.06, -0.10), 1.00, "NECROTIC_FLESH", "hips")
       + _crawler((0.175, 0.20, -0.13), 0.80, "DECAYED_WOOD", "spine")
       + _crawler((-0.160, 0.15, -0.12), 0.72, "NECROTIC_FLESH", "chest"),
       FOE_CLIPS)

# --- variant 2: static_walker / static_conduit / forked_emp_prongs ---------
_actor("static_walker", 1.72, humanoid(
	skin="DARK_IRON", cloth="DARK_IRON", metal="IRON_SILVER",
	head_mat="DARK_IRON", head_r=(0.090, 0.092, 0.106), head_z=0.62,
	neck_r=0.042, chest_r=(0.140, 0.104), waist_r=(0.104, 0.082),
	hip_r=(0.120, 0.094), arm_r=(0.054, 0.043), leg_r=(0.076, 0.058),
	foot=(0.072, 0.13, 0.044), shoulder=0.048, shoulder_mat="OXIDIZED_COPPER",
	sides=5,
	extras=[
		# forked EMP prongs: two tines rising and splaying from the skull
		bar("head", (0.046, -0.010, 1.400), (0.112, -0.030, 1.690), 0.028, 0.014,
		    "IRON_SILVER", 4),
		bar("head", (0.112, -0.030, 1.690), (0.126, -0.034, 1.748), 0.020, 0.015,
		    "CYAN_CRYSTAL", 5),
		# the arc that gives the fork its name, drawn as a bridge between tines
		bar("head", (0.0, -0.032, 1.720), (0.112, -0.032, 1.690), 0.014, 0.011,
		    "NEON_CYAN", 4),
		# exposed capacitor core
		blob("chest", (0.0, -0.052, 1.100), (0.068, 0.048, 0.074),
		     "CYAN_CRYSTAL", mirror=False),
		bar("spine", (0.0, 0.082, 0.690), (0.0, 0.086, 0.990), 0.042, 0.036,
		    "OXIDIZED_COPPER", 5, mirror=False),
		# conduit lines down the forearms, so the cyan reads from every angle
		bar("lowerarm.l", (0.520, -0.040, 1.107), (0.760, -0.038, 1.107),
		    0.014, 0.011, "NEON_CYAN", 4),
	]), FOE_CLIPS)

# --- variant 3: scrap_shield / scrap_bulwark / armored_front_plate ---------
_actor("scrap_shield", 1.86, humanoid(
	skin="NECROTIC_FLESH", cloth="DECAYED_WOOD", metal="RUSTED_IRON",
	head_r=(0.090, 0.092, 0.086), head_z=0.34, neck_r=0.042,
	chest_r=(0.172, 0.118), waist_r=(0.132, 0.098), hip_r=(0.146, 0.106),
	shoulder=0.070, shoulder_mat="RUSTED_IRON",
	arm_r=(0.062, 0.048), leg_r=(0.086, 0.064), hunch=0.055,
	extras=[
		# the plate is the whole silhouette: a slab held forward and to one
		# side, tall enough to hide the head from the front
		bar("lowerarm.l", (0.115, -0.300, 0.700), (0.115, -0.318, 1.420),
		    (0.235, 0.034), (0.205, 0.030), "RUSTED_IRON", 4, mirror=False),
		bar("lowerarm.l", (0.115, -0.330, 0.760), (0.115, -0.340, 1.340),
		    (0.060, 0.016), (0.052, 0.014), "DARK_IRON", 4, mirror=False),
		bar("lowerarm.l", (-0.060, -0.322, 1.060), (0.290, -0.326, 1.060),
		    (0.030, 0.026), (0.026, 0.022), "IRON_SILVER", 4, mirror=False),
		# rivets read as a row of bright pips along the top edge at 64px
		bar("lowerarm.l", (0.0, -0.320, 1.390), (0.230, -0.322, 1.386),
		    0.020, 0.017, "IRON_SILVER", 4, mirror=False),
	]), FOE_CLIPS)

# --- variant 4: goliath / runic_goliath / towering_rune_horns --------------
_actor("goliath", 3.05, humanoid(
	skin="DARK_IRON", cloth="DARK_IRON", metal="ASH_CONCRETE",
	head_mat="ASH_CONCRETE", head_r=(0.148, 0.152, 0.130), head_z=0.30,
	neck_r=0.082, chest_r=(0.310, 0.208), waist_r=(0.232, 0.170),
	hip_r=(0.252, 0.186), shoulder=0.190, shoulder_mat="ASH_CONCRETE",
	arm_r=(0.132, 0.104), leg_r=(0.168, 0.124), foot=(0.118, 0.18, 0.070),
	hunch=0.050,
	extras=[
		# towering rune horns - the tallest thing in the game's silhouette set
		bar("head", (0.082, -0.020, 1.355), (0.168, 0.048, 1.735), 0.060, 0.026,
		    "BONE", 5),
		bar("head", (0.168, 0.048, 1.735), (0.150, 0.024, 1.815), 0.028, 0.011,
		    "BONE", 5),
		# runes: amber slots cut along the horn and across the chest slab
		bar("head", (0.120, 0.008, 1.545), (0.136, 0.026, 1.640), 0.021, 0.017,
		    "AMBER_GOLD", 4),
		bar("chest", (0.0, -0.205, 1.090), (0.0, -0.210, 1.225), (0.170, 0.032),
		    (0.136, 0.027), "ASH_CONCRETE", 4, mirror=False),
		bar("chest", (0.0, -0.222, 1.125), (0.0, -0.224, 1.195), (0.108, 0.016),
		    (0.089, 0.014), "AMBER_GOLD", 4, mirror=False),
		# pauldrons: the widest part of the outline, and the reason a player
		# reads "boss" before the sprite has finished crossing the screen
		bar("upperarm.l", (0.236, 0.0, 1.190), (0.400, 0.0, 1.148),
		    (0.150, 0.130), (0.128, 0.108), "ASH_CONCRETE", 5),
		bar("upperarm.l", (0.300, -0.070, 1.215), (0.348, -0.076, 1.180),
		    0.030, 0.024, "AMBER_GOLD", 4),
		# knuckle slabs so the arms end in weight rather than tapering away
		blob("hand.l", (0.905, 0.0, 1.107), (0.124, 0.108, 0.108), "ASH_CONCRETE"),
		# thigh plates, matching the pauldrons so the mass reads top to bottom
		bar("upperleg.l", (0.171, 0.0, 0.470), (0.171, 0.0, 0.330),
		    (0.185, 0.150), (0.160, 0.128), "ASH_CONCRETE", 5),
	]), FOE_CLIPS, tier="boss")

# --- variant 5: carrier / plague_carrier / wide_orbiting_carapace ----------
def _carrier_pods():
	"""Two body-bound cargo pods, deliberately separated above one low harness.

	The earlier seven small carapace plates and two tiny slime dots made a wide
	but generic halo at gameplay scale.  These paired shells are large enough to
	make the body itself say ``carrier`` in the camera-facing row: the chest is
	narrowed below, each pod owns one stable chest-bound silhouette, and the
	bridge stays below their midline so it cannot close their gap.
	"""
	return [
		# The wooden outer cases carry the silhouette.  Keeping them on chest (not
		# upperarm) makes the pair survive attacks and walks as cargo, not wings.
		blob("chest", (0.365, 0.025, 1.075), (0.175, 0.118, 0.165),
		     "DECAYED_WOOD", rings=4, segs=8),
		# One inset toxic window per case says what the cargo is without making a
		# green particle halo or a new runtime emissive effect.
		blob("chest", (0.365, -0.105, 1.075), (0.086, 0.030, 0.092),
		     "TOXIC_SLUDGE", rings=3, segs=6),
		# Mirrored vertical straps keep each object visibly attached while the
		# actual gap remains open through the important upper half of the torso.
		bar("chest", (0.365, -0.138, 0.950), (0.365, -0.142, 1.195),
		    (0.018, 0.012), (0.014, 0.010), "DARK_IRON", 4),
		# The only cross-body connection sits below both pod centres.  It grounds
		# them as a harness rather than reconnecting their silhouette into a ring.
		bar("chest", (0.0, -0.140, 0.970), (0.0, -0.150, 0.980),
		    (0.330, 0.014), (0.314, 0.012), "DARK_IRON", 4, mirror=False),
	]


_actor("carrier", 2.10, humanoid(
	skin="NECROTIC_FLESH", cloth="DECAYED_WOOD", metal="DARK_IRON",
	head_r=(0.088, 0.090, 0.084), head_z=0.28, neck_r=0.044,
	# The torso deliberately steps inside the paired pod silhouettes.  The boss
	# stays broad through carried mass, not through a featureless body barrel.
	chest_r=(0.145, 0.125), waist_r=(0.130, 0.110), hip_r=(0.155, 0.120),
	arm_r=(0.058, 0.046), leg_r=(0.088, 0.066), hunch=0.095,
	extras=_carrier_pods()), FOE_CLIPS, tier="boss")

# --- variant 6: splitter / blood_splitter / paired_feral_echoes ------------
def _splitter_lobes():
	"""Two uneven upper-body lobes divided by a stable, dark vertical cleft."""
	return [
		# These are chest-bound on purpose: arm-bound copies would read as blades
		# or wings during an attack, while a Splitter's promise must remain part of
		# its torso in every action and heading.
		blob("chest", (0.310, -0.035, 1.180), (0.135, 0.092, 0.150),
		     "CRIMSON_STEEL", rings=4, segs=8),
		# A slight fore-edge per lobe gives the seam a real depth break rather than
		# relying on hue alone.  It is baked body geometry, not a marker line.
		bar("chest", (0.310, -0.135, 1.060), (0.310, -0.145, 1.305),
		    (0.018, 0.011), (0.015, 0.009), "RUSTED_IRON", 4),
		# The centre stays physically narrow and optically dark from sternum to
		# collar.  This makes the split survive greyscale even where the lobes
		# overlap the body in projection.
		bar("chest", (0.0, -0.158, 1.020), (0.0, -0.168, 1.350),
		    (0.024, 0.012), (0.020, 0.010), "BLACK_OBSIDIAN", 4, mirror=False),
	]


_actor("splitter", 1.88, humanoid(
	skin="CRIMSON_STEEL", cloth="TAR", metal="CRIMSON_STEEL",
	# A narrow dark core leaves the paired upper lobes to own the outline rather
	# than hiding them behind one continuous humanoid chest.
	head_mat="TAR", head_r=(0.068, 0.074, 0.078), head_z=0.46, neck_r=0.034,
	chest_r=(0.075, 0.080), waist_r=(0.075, 0.070), hip_r=(0.105, 0.084),
	arm_r=(0.046, 0.036), leg_r=(0.070, 0.052), foot=(0.066, 0.125, 0.040),
	hunch=0.070, sides=5,
	extras=_splitter_lobes() + [
		# blade forearms
		bar("lowerarm.l", (0.740, -0.020, 1.107), (0.980, -0.115, 1.107),
		    (0.052, 0.014), (0.014, 0.006), "IRON_SILVER", 4),
	]), FOE_CLIPS, tier="boss")

# --- variant 7: overlord / undead_overlord / crowned_royal_mass ------------
def _crown(count=5, radius=0.128, z=1.455):
	points = []
	for i in range(count):
		theta = math.pi * (-0.5 + i / float(count - 1))
		x, y = radius * math.cos(theta), radius * math.sin(theta) * 0.85
		h = 0.075 if i % 2 == 0 else 0.048
		points.append(bar("head", (x, y, z), (x * 1.04, y * 1.04, z + h),
		                  0.020, 0.006, "ACCENT_GOLD", 4, mirror=False))
	return points


_actor("overlord", 2.62, humanoid(
	skin="BONE", cloth="TAR", metal="ACCENT_GOLD",
	head_mat="BONE", head_r=(0.100, 0.104, 0.112), head_z=0.52, neck_r=0.046,
	chest_r=(0.205, 0.150), waist_r=(0.200, 0.150), hip_r=(0.290, 0.215),
	arm_r=(0.054, 0.042), leg_r=(0.070, 0.055), foot=(0.070, 0.13, 0.040),
	extras=_crown() + [
		# crowned royal mass: the robe is a single flared cone from chest to
		# floor, so the outline is a triangle no other roster member owns
		bar("hips", (0.0, 0.0, 0.980), (0.0, 0.0, 0.020), (0.185, 0.150),
		    (0.430, 0.330), "TAR", 8, mirror=False),
		bar("hips", (0.0, -0.140, 0.560), (0.0, -0.300, 0.030), (0.075, 0.020),
		    (0.130, 0.026), "CRIMSON_STEEL", 4, mirror=False),
		# gold mantle across the shoulders
		bar("chest", (0.0, 0.0, 1.200), (0.0, 0.0, 1.268), (0.255, 0.180),
		    (0.170, 0.125), "ACCENT_GOLD", 8, mirror=False),
		bar("chest", (0.215, 0.0, 1.190), (0.300, 0.0, 1.120), (0.070, 0.062),
		    (0.048, 0.042), "ACCENT_GOLD", 6),
		# hollow eyes: two small emissive pips carry the face at any size
		bar("head", (0.040, -0.092, 1.400), (0.040, -0.104, 1.400), 0.020, 0.017,
		    "AMBER_GOLD", 4),
	]), FOE_CLIPS, tier="boss")


# --------------------------------------------------------------------------
# assembly
# --------------------------------------------------------------------------

def _material(key):
	name = "BSP_%s" % key
	existing = bpy.data.materials.get(name)
	if existing is not None:
		return existing
	mat = bpy.data.materials.new(name)
	mat.use_nodes = True
	return mat


def assemble(armature, key: str):
	"""Weld every shell into one mesh, bound rigidly to the bone it was built on.

	Rigid binding is a choice, not a shortcut. These are faceted low-poly
	figures in the KayKit idiom, where a limb is meant to read as a solid
	segment; smooth falloff across a joint would only add the tearing the
	fitting path already showed us, and buys nothing at 64 px.
	"""
	spec = ROSTER[key]
	shells = realise(armature, spec["parts"])

	verts, faces, groups, slots = [], [], {}, {}
	mesh_data = bpy.data.meshes.new("BODY_%s" % key)
	for shell in shells:
		base = len(verts)
		if shell.material not in slots:
			slots[shell.material] = len(slots)
		verts.extend(shell.verts)
		faces.extend([[i + base for i in face] for face in shell.faces])
		groups.setdefault(shell.bone, []).extend(
			range(base, base + len(shell.verts)))
		shell.slot = slots[shell.material]

	mesh_data.from_pydata(verts, [], faces)
	mesh_data.update()
	for material_key in slots:
		mesh_data.materials.append(_material(material_key))
	index = 0
	for shell in shells:
		for _ in shell.faces:
			mesh_data.polygons[index].material_index = shell.slot
			index += 1
	for polygon in mesh_data.polygons:
		polygon.use_smooth = False

	obj = bpy.data.objects.new("BESPREN_%s" % key.upper(), mesh_data)
	bpy.context.scene.collection.objects.link(obj)

	for bone, indices in groups.items():
		group = obj.vertex_groups.new(name=bone)
		group.add(indices, 1.0, "REPLACE")

	obj.parent = armature
	obj.matrix_parent_inverse = armature.matrix_world.inverted()
	modifier = obj.modifiers.new(name="BESPREN_SKIN", type="ARMATURE")
	modifier.object = armature
	modifier.use_vertex_groups = True

	scale = spec["height"] / RIG_HEIGHT
	armature.scale = (scale, scale, scale)
	return {"object": obj, "shells": len(shells), "verts": len(verts),
	        "faces": len(faces), "bones": sorted(groups),
	        "materials": sorted(slots), "scale": round(scale, 4)}


def build(project_root: str, key: str, groups: list):
	"""Mirror `rig_bespren_actor.build`'s contract so the bake driver is shared."""
	rigged = fitrig.import_skeleton(project_root, groups)
	armature = rigged["armature"]
	built = assemble(armature, key)
	rig.apply_bespren_palette([built["object"]])
	return {"mesh": built["object"], "armature": armature,
	        "actions": rigged["actions"], "name": key,
	        "profile": {"height": ROSTER[key]["height"], "authored": True},
	        "facing": {"turn_deg": 0.0, "forward": [0.0, -1.0, 0.0]},
	        "fit": {"scale": built["scale"], "tier": ROSTER[key]["tier"]},
	        "skin": {"shells": built["shells"], "verts": built["verts"],
	                 "faces": built["faces"], "bones_used": len(built["bones"]),
	                 "materials": built["materials"]}}
