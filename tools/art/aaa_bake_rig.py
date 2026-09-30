"""Bespren AAA++ sprite bake rig.

Creates an isolated Blender scene (BESPREN_AAA_STAGE) that never touches the
user's active scene, imports curated low-poly GLB sources, and renders them
through one reproducible orthographic top-down three-quarter recipe:

  * warm key / cool fill / white rim area-light triad
  * AgX + Medium High Contrast, transparent film
  * Freestyle silhouette line for 480x270 readability
  * 4x supersampled render, LANCZOS downsample at pack time

The rig owns presentation only. Collision, flow masks and gameplay contracts
stay in Godot exactly as they are today.
"""

import bpy
import json
import math
import os
from mathutils import Vector

STAGE = "BESPREN_AAA_STAGE"

# Top-down three-quarter matching the shipping world camera.
CAM_ELEVATION_DEG = 52.0
CAM_AZIMUTH_DEG = -45.0
CAM_DISTANCE = 24.0
SUPERSAMPLE = 4

KEY_COLOR = (1.0, 0.847, 0.659)      # warm afternoon sun
FILL_COLOR = (0.498, 0.659, 1.0)     # cool sky bounce
RIM_COLOR = (0.780, 0.890, 1.0)      # cold separation rim
WORLD_AMBIENT = (0.150, 0.172, 0.186, 1.0)


def _purge_stage() -> bpy.types.Scene:
	if bpy.app.background:
		# A headless render starts from a throwaway factory file, so the active
		# scene is already ours to take over. Making a second scene here would
		# be unreachable: with no window there is nothing to point at it, and
		# bpy.ops.render.render() only ever renders the context scene.
		scene = bpy.context.scene
		for ob in list(scene.collection.all_objects):
			bpy.data.objects.remove(ob, do_unlink=True)
		scene.name = STAGE
		return scene
	old = bpy.data.scenes.get(STAGE)
	if old is not None:
		for ob in list(old.collection.all_objects):
			bpy.data.objects.remove(ob, do_unlink=True)
		bpy.data.scenes.remove(old, do_unlink=True)
	scene = bpy.data.scenes.new(STAGE)
	# Removing the active scene silently moves every window onto some other
	# scene, and bpy.ops.render.render() always renders the *context* scene.
	# Without this the rig reports FINISHED while writing nothing.
	for window in bpy.context.window_manager.windows:
		window.scene = scene
	return scene


def _world(scene: bpy.types.Scene) -> None:
	world = bpy.data.worlds.get("BESPREN_AAA_WORLD") or bpy.data.worlds.new("BESPREN_AAA_WORLD")
	world.use_nodes = True
	bg = world.node_tree.nodes.get("Background")
	if bg is not None:
		bg.inputs[0].default_value = WORLD_AMBIENT
		bg.inputs[1].default_value = 1.0
	scene.world = world


def _area_light(scene, name, color, energy, location, size, target=Vector((0, 0, 0.6))):
	data = bpy.data.lights.new(name, type="AREA")
	data.color = color
	data.energy = energy
	data.size = size
	ob = bpy.data.objects.new(name, data)
	ob.location = location
	direction = target - Vector(location)
	ob.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
	scene.collection.objects.link(ob)
	return ob


def _sun_light(scene, name, color, energy, elevation_deg, azimuth_deg, angle_deg=14.0):
	"""Distance-invariant key/fill/rim.

	Area lights fall off with distance squared, so a batch that refits
	`ortho_scale` per subject would light a 0.1 m bottle and a 10 m rock shelf
	completely differently. Sun lamps keep one exposure across the whole set.
	"""
	data = bpy.data.lights.new(name, type="SUN")
	data.color = color
	data.energy = energy
	data.angle = math.radians(angle_deg)
	ob = bpy.data.objects.new(name, data)
	el = math.radians(elevation_deg)
	az = math.radians(azimuth_deg)
	direction = Vector((
		-math.cos(el) * math.sin(az),
		math.cos(el) * math.cos(az),
		-math.sin(el),
	))
	ob.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
	ob.location = (0.0, 0.0, 6.0)
	scene.collection.objects.link(ob)
	return ob


def _camera(scene: bpy.types.Scene) -> bpy.types.Object:
	data = bpy.data.cameras.new("BESPREN_AAA_CAM")
	data.type = "ORTHO"
	data.ortho_scale = 4.0
	ob = bpy.data.objects.new("BESPREN_AAA_CAM", data)
	el = math.radians(CAM_ELEVATION_DEG)
	az = math.radians(CAM_AZIMUTH_DEG)
	ob.location = (
		CAM_DISTANCE * math.cos(el) * math.sin(az),
		-CAM_DISTANCE * math.cos(el) * math.cos(az),
		CAM_DISTANCE * math.sin(el),
	)
	direction = Vector((0.0, 0.0, 0.0)) - Vector(ob.location)
	ob.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
	scene.collection.objects.link(ob)
	scene.camera = ob
	return ob


def build_stage() -> bpy.types.Scene:
	scene = _purge_stage()
	_world(scene)
	_camera(scene)
	# Warm key from the camera's upper left, cool fill opposite, cold rim behind.
	# The rim used to sit at 62 degrees, which is steep enough that it read as a
	# second top light and washed the upper planes instead of drawing an edge.
	# Dropping it to 34 puts it behind the subject at roughly shoulder height,
	# where it separates the silhouette from the ground it stands on, and the
	# tighter angle keeps that edge crisp rather than smeared. Fill comes down
	# at the same time: the shadow side was lifted far enough to flatten form,
	# and the warm key against a colder, lower rim is what gives the roster its
	# local contrast at 480x270.
	_sun_light(scene, "AAA_KEY", KEY_COLOR, 4.2, 48.0, -58.0, 9.0)
	_sun_light(scene, "AAA_FILL", FILL_COLOR, 1.25, 26.0, 128.0, 26.0)
	_sun_light(scene, "AAA_RIM", RIM_COLOR, 3.8, 34.0, 152.0, 3.0)

	scene.render.engine = "BLENDER_EEVEE"
	scene.render.film_transparent = True
	scene.render.image_settings.file_format = "PNG"
	scene.render.image_settings.color_mode = "RGBA"
	scene.render.image_settings.compression = 15
	# Standard, not AgX: the A/B/C probe showed AgX desaturates the locked
	# semantic anchors (cyan tech read as blown white, foliage read as olive).
	scene.view_settings.view_transform = "Standard"
	scene.view_settings.look = "None"
	scene.view_settings.exposure = 0.0
	scene.view_settings.gamma = 1.0

	scene.render.use_freestyle = True
	vl = scene.view_layers[0]
	vl.use_freestyle = True
	vl.freestyle_settings.crease_angle = math.radians(132.0)
	if not vl.freestyle_settings.linesets:
		vl.freestyle_settings.linesets.new("AAA_SILHOUETTE")
	ls = vl.freestyle_settings.linesets[0]
	ls.select_silhouette = True
	ls.select_border = True
	ls.select_crease = True
	ls.linestyle.color = (0.024, 0.035, 0.035)
	scene.render.line_thickness = 1.12
	ls.linestyle.thickness = 1.20
	ls.linestyle.alpha = 1.0
	return scene


# ---------------------------------------------------------------------------
# Adaptive exposure
#
# A fixed exposure cannot serve a batch that spans near-black tar traps and
# pale bone cairns: half the set renders as mud, the other half blows out.
# Each subject is metered on a cheap low-resolution pass and the exposure is
# corrected towards one shared alpha-weighted luma target before the real
# frame is written, which is what keeps the atlas internally consistent.
# ---------------------------------------------------------------------------

def _render_still(scene: bpy.types.Scene) -> None:
	"""Render the stage scene, never whatever scene the context drifted to."""
	if bpy.app.background:
		bpy.ops.render.render(write_still=True)
		return
	for window in bpy.context.window_manager.windows:
		if window.scene is not scene:
			window.scene = scene
	bpy.ops.render.render(write_still=True)


TARGET_LUMA = 104.0     # 0-255, alpha-weighted, mid-key for 480x270 readability
METER_SIZE = 64
MAX_EXPOSURE_STEPS = 4
SRGB_GAMMA = 2.2


def _measure_luma(path: str) -> float:
	img = bpy.data.images.load(path, check_existing=False)
	try:
		img.colorspace_settings.name = "Non-Color"
		px = img.pixels[:]
		total = 0.0
		weight = 0.0
		for i in range(0, len(px), 4):
			a = px[i + 3]
			if a <= 0.02:
				continue
			luma = 0.2126 * px[i] + 0.7152 * px[i + 1] + 0.0722 * px[i + 2]
			total += luma * a
			weight += a
		return (total / weight) * 255.0 if weight > 0.0 else 0.0
	finally:
		bpy.data.images.remove(img)


def auto_expose(scene: bpy.types.Scene, meter_path: str, target: float = TARGET_LUMA) -> dict:
	"""Converge scene exposure so the subject hits `target` mean luma."""
	prev_x = scene.render.resolution_x
	prev_y = scene.render.resolution_y
	prev_fp = scene.render.filepath
	prev_fs = scene.render.use_freestyle
	scene.render.resolution_x = METER_SIZE
	scene.render.resolution_y = METER_SIZE
	scene.render.use_freestyle = False       # the outline biases a small meter
	scene.render.filepath = meter_path
	history = []
	try:
		for _ in range(MAX_EXPOSURE_STEPS):
			_render_still(scene)
			luma = _measure_luma(meter_path)
			history.append(round(luma, 1))
			if luma <= 0.5:
				scene.view_settings.exposure += 2.0
				continue
			# Exposure is a scene-linear stop, but the meter reads display-
			# referred pixels through the sRGB curve, so a raw log2 ratio
			# under-corrects by roughly the transfer gamma.
			delta = math.log2(target / luma) * SRGB_GAMMA
			if abs(delta) < 0.10:
				break
			scene.view_settings.exposure += max(-3.0, min(delta, 3.0))
		return {"luma_history": history, "exposure": round(scene.view_settings.exposure, 3)}
	finally:
		scene.render.resolution_x = prev_x
		scene.render.resolution_y = prev_y
		scene.render.use_freestyle = prev_fs
		scene.render.filepath = prev_fp


def _clear_subjects(scene: bpy.types.Scene) -> None:
	keep = {"BESPREN_AAA_CAM", "AAA_KEY", "AAA_FILL", "AAA_RIM"}
	for ob in list(scene.collection.all_objects):
		if ob.name not in keep:
			bpy.data.objects.remove(ob, do_unlink=True)


def _frame_subject(scene: bpy.types.Scene, objects, pad: float = 1.16) -> None:
	"""Fit ortho scale to the imported subject and recentre it on the origin."""
	mins = Vector((1e9, 1e9, 1e9))
	maxs = Vector((-1e9, -1e9, -1e9))
	for ob in objects:
		if ob.type != "MESH":
			continue
		for corner in ob.bound_box:
			world = ob.matrix_world @ Vector(corner)
			mins = Vector((min(mins[i], world[i]) for i in range(3)))
			maxs = Vector((max(maxs[i], world[i]) for i in range(3)))
	if mins.x > 1e8:
		return
	centre = (mins + maxs) * 0.5
	for ob in objects:
		if ob.parent is None:
			ob.location -= Vector((centre.x, centre.y, mins.z))
	size = maxs - mins
	radius = max(size.x, size.y, size.z * 1.15)
	scene.camera.data.ortho_scale = max(0.6, radius * pad)
	# aim the camera at the subject's visual centre of mass
	height = (maxs.z - mins.z) * 0.42
	el = math.radians(CAM_ELEVATION_DEG)
	az = math.radians(CAM_AZIMUTH_DEG)
	scene.camera.location = (
		CAM_DISTANCE * math.cos(el) * math.sin(az),
		-CAM_DISTANCE * math.cos(el) * math.cos(az),
		CAM_DISTANCE * math.sin(el) + height,
	)
	direction = Vector((0.0, 0.0, height)) - Vector(scene.camera.location)
	scene.camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def bake_objects(scene: bpy.types.Scene, objects: list, out_path: str,
                 size: int = 128, retarget_palette: bool = True) -> dict:
	"""Frame, expose and render whatever is already staged.

	`retarget_palette` is the difference between the two asset families the
	project draws from. Untextured low-poly source geometry is remapped onto
	the locked Bespren palette so it joins one art direction; photoscanned
	Poly Haven nature keeps its own PBR surfaces, because that authored bark
	and foliage detail is the whole reason it is worth importing.
	"""
	meshes = [o for o in objects if o.type == "MESH"]
	if not meshes:
		raise RuntimeError("no mesh objects to bake: %s" % out_path)
	palette = apply_bespren_palette(meshes) if retarget_palette else {"unmapped": set(), "mapped": {}}
	_frame_subject(scene, meshes)

	scene.render.resolution_x = size * SUPERSAMPLE
	scene.render.resolution_y = size * SUPERSAMPLE
	scene.render.resolution_percentage = 100
	scene.view_settings.exposure = 0.0
	meter = auto_expose(scene, os.path.join(os.path.dirname(out_path), "_meter.png"))
	scene.render.filepath = out_path
	_render_still(scene)

	tris = 0
	for o in meshes:
		try:
			tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
		except Exception:
			pass
	return {"out": out_path, "objects": len(meshes), "tris": tris,
	        "unmapped": sorted(palette["unmapped"]), **meter}


def bake_glb(scene: bpy.types.Scene, glb_path: str, out_path: str,
             size: int = 128, retarget_palette: bool = True) -> dict:
	"""Import one GLB into the clean stage and render a single sprite."""
	_clear_subjects(scene)
	before = set(bpy.data.objects)
	bpy.ops.import_scene.gltf(filepath=glb_path)
	imported = [o for o in bpy.data.objects if o not in before]
	for o in imported:
		for coll in list(o.users_collection):
			coll.objects.unlink(o)
		scene.collection.objects.link(o)
	row = bake_objects(scene, imported, out_path, size, retarget_palette)
	row["glb"] = glb_path
	return row


def bake_many(pairs, out_dir: str, size: int = 128) -> list:
	os.makedirs(out_dir, exist_ok=True)
	scene = build_stage()
	report = []
	for name, glb in pairs:
		out = os.path.join(out_dir, name + ".png")
		try:
			report.append(bake_glb(scene, glb, out, size))
		except Exception as exc:  # noqa: BLE001 - report, never abort the batch
			report.append({"glb": os.path.basename(glb), "error": repr(exc)[:300]})
	return report


# ---------------------------------------------------------------------------
# Bespren palette retarget
#
# The curated GLB sources carry generic authoring materials. Baking them raw
# produces desaturated mud at 480x270. Every source material is therefore
# retargeted onto the locked Bespren palette with deliberate value separation,
# so silhouettes and semantic colours survive a 40 px sprite.
# ---------------------------------------------------------------------------

def _srgb_to_linear(hex_color: str) -> tuple:
	hex_color = hex_color.lstrip("#")
	out = []
	for i in (0, 2, 4):
		c = int(hex_color[i:i + 2], 16) / 255.0
		out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
	return (out[0], out[1], out[2], 1.0)


# name -> (hex, roughness, metallic, emission_strength)
# Hard-surface neutrals carried almost no chroma - ash concrete sat at 0.04 and
# iron silver at 0.02 - and they are exactly what the large enemies are built
# from, so a goliath read as grey mush beside a rust-saturated walker. The four
# lifted entries were re-solved to hold their original Rec.709 luma to three
# decimals, so greyscale silhouette mass, and every gate that measures it, is
# unchanged; only chroma moved. The semantic anchors below - the golds, the
# teals, the cyan, oxidized copper - are locked by the design document and were
# not touched.
BESPREN_PALETTE = {
	"BLACK_OBSIDIAN":  ("#0A0D0D", 0.42, 0.00, 0.0),
	"TAR":             ("#13100E", 0.30, 0.00, 0.0),
	"DARK_IRON":       ("#22312E", 0.55, 0.85, 0.0),
	"ASH_CONCRETE":    ("#61776C", 0.88, 0.00, 0.0),
	"RUSTED_IRON":     ("#B8541F", 0.78, 0.35, 0.0),
	"IRON_SILVER":     ("#B9D2CA", 0.34, 0.95, 0.0),
	"DECAYED_WOOD":    ("#6B3E1E", 0.86, 0.00, 0.0),
	"BONE":            ("#E2CE9E", 0.72, 0.00, 0.0),
	"NECROTIC_FLESH":  ("#5E7038", 0.80, 0.00, 0.0),
	"TOXIC_SLUDGE":    ("#8FD13A", 0.42, 0.00, 0.6),
	"OXIDIZED_COPPER": ("#1C8270", 0.66, 0.30, 0.0),
	"MOLTEN_SLAG":     ("#FF6A1E", 0.50, 0.00, 2.4),
	"CLOTH_OLIVE":     ("#3E4A32", 0.92, 0.00, 0.0),
	"CLOTH_LEATHER":   ("#4A3324", 0.84, 0.00, 0.0),
	"SKIN_PALE":       ("#C79C7A", 0.76, 0.00, 0.0),
	"CRIMSON_STEEL":   ("#B4232A", 0.60, 0.45, 0.0),
	"ACCENT_GOLD":     ("#FFD45A", 0.44, 0.55, 0.9),
	"AMBER_GOLD":      ("#FFB52E", 0.44, 0.30, 1.6),
	"ACCENT_TEAL":     ("#31E6E6", 0.44, 0.40, 1.0),
	"NEON_CYAN":       ("#00FFFF", 0.30, 0.00, 2.8),
	"CYAN_CRYSTAL":    ("#31E6E6", 0.22, 0.00, 2.2),
}


def _palette_key(material_name: str) -> str:
	"""Source materials arrive as BSP_RUSTED_IRON, RUSTED_IRON.001 and so on."""
	name = material_name.upper()
	if name.startswith("BSP_"):
		name = name[4:]
	if "." in name:
		name = name.split(".")[0]
	return name


def apply_bespren_palette(objects) -> dict:
	"""Retarget every Principled BSDF on `objects` onto the locked palette."""
	hits, misses = {}, {}
	for ob in objects:
		if ob.type != "MESH" or ob.data is None:
			continue
		for slot in ob.data.materials:
			if slot is None or not slot.use_nodes:
				continue
			key = _palette_key(slot.name)
			entry = BESPREN_PALETTE.get(key)
			if entry is None:
				misses[key] = misses.get(key, 0) + 1
				continue
			hex_color, rough, metal, emit = entry
			linear = _srgb_to_linear(hex_color)
			for node in slot.node_tree.nodes:
				if node.type != "BSDF_PRINCIPLED":
					continue
				node.inputs["Base Color"].default_value = linear
				node.inputs["Roughness"].default_value = rough
				node.inputs["Metallic"].default_value = metal
				if "Emission Color" in node.inputs:
					node.inputs["Emission Color"].default_value = linear
				if "Emission Strength" in node.inputs:
					node.inputs["Emission Strength"].default_value = emit
			hits[key] = hits.get(key, 0) + 1
	return {"retargeted": hits, "unmapped": misses}
