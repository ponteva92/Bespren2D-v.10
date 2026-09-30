"""Fetch reviewed Poly Haven CC0 models into a local workshop vault.

Runs on the host interpreter. The Blender addon's Poly Haven integration is a
GUI checkbox this pipeline cannot reach headlessly, so the models come from the
documented public API instead - which refuses a bare urllib request with 403
until a browser User-Agent is supplied.

Nothing here enters `res://`. The downloads land in the Blender workshop vault,
are baked to RGBA frames by the matching renderer, and only the packed atlas
plus its provenance manifest are promoted. Every file is recorded with its
SHA-256 and its polyhaven.com asset page so the CC0 chain stays checkable.
"""

import hashlib
import json
import os
import sys
import urllib.request

UA = {"User-Agent": "Mozilla/5.0 BesprenAssetPipeline/1.0"}
API = "https://api.polyhaven.com"
RESOLUTION = "1k"
FORMAT = "gltf"


def _get(url, binary=False):
	with urllib.request.urlopen(urllib.request.Request(url, headers=UA),
	                            timeout=120) as fh:
		return fh.read() if binary else json.load(fh)


def _walk_files(node, acc, rel=None):
	"""Collect (relative path, file record) pairs in Poly Haven's own layout.

	The relative path has to come from the `include` key, not from the URL. A
	glTF asks for `textures/<name>.jpg`, and that is exactly what the key says -
	but the texture is served from `.../Models/jpg/1k/<asset>/<name>.jpg`, with
	no `textures/` segment anywhere in it. Deriving the path from the URL
	therefore flattens every texture into the model root, the glTF's image URIs
	resolve to nothing, and the asset imports untextured. That failure is
	silent: Blender logs "Missing image file" and renders the model grey.
	"""
	if isinstance(node, dict):
		if "url" in node and "md5" in node:
			acc.append((rel or os.path.basename(node["url"]), node))
			for key, include in (node.get("include") or {}).items():
				_walk_files(include, acc, key)
			return acc
		for value in node.values():
			_walk_files(value, acc, rel)
	elif isinstance(node, list):
		for value in node:
			_walk_files(value, acc, rel)
	return acc


def fetch(asset_id: str, dest_root: str) -> dict:
	meta = _get("%s/info/%s" % (API, asset_id))
	files = _get("%s/files/%s" % (API, asset_id))
	node = files.get(FORMAT, {}).get(RESOLUTION, {}).get(FORMAT)
	if node is None:
		raise RuntimeError("%s has no %s/%s" % (asset_id, RESOLUTION, FORMAT))

	dest = os.path.join(dest_root, asset_id)
	os.makedirs(dest, exist_ok=True)
	written = []
	for rel, entry in _walk_files(node, []):
		url = entry["url"]
		path = os.path.join(dest, rel.replace("/", os.sep))
		os.makedirs(os.path.dirname(path), exist_ok=True)
		if not os.path.isfile(path) or os.path.getsize(path) == 0:
			blob = _get(url, binary=True)
			with open(path, "wb") as fh:
				fh.write(blob)
		with open(path, "rb") as fh:
			digest = hashlib.sha256(fh.read()).hexdigest()
		written.append({"path": os.path.relpath(path, dest_root).replace(os.sep, "/"),
		                "bytes": os.path.getsize(path), "sha256": digest,
		                "url": url})

	gltf = [f for f in written if f["path"].lower().endswith((".gltf", ".glb"))]
	return {"id": asset_id, "name": meta.get("name", asset_id),
	        "license": "CC0-1.0", "type": "model", "format": FORMAT,
	        "resolution": RESOLUTION,
	        "url": "https://polyhaven.com/a/%s" % asset_id,
	        "authors": sorted((meta.get("authors") or {}).keys()),
	        "categories": sorted(meta.get("categories") or []),
	        "entry": gltf[0]["path"] if gltf else None,
	        "files": written}


def main() -> None:
	dest_root = sys.argv[1]
	manifest_path = sys.argv[2]
	ids = sys.argv[3:]
	if not ids:
		raise SystemExit("usage: fetch_polyhaven_models.py <dest> <manifest> <id>...")

	os.makedirs(dest_root, exist_ok=True)
	records, errors = [], []
	for asset_id in ids:
		try:
			record = fetch(asset_id, dest_root)
			records.append(record)
			print("[ok]   %-34s %2d file(s)  %s"
			      % (asset_id, len(record["files"]), record["entry"]), flush=True)
		except Exception as exc:  # noqa: BLE001 - report every failure, fetch the rest
			errors.append({"id": asset_id, "error": "%s: %s" % (type(exc).__name__, exc)})
			print("[FAIL] %-34s %s" % (asset_id, exc), flush=True)

	with open(manifest_path, "w", encoding="utf-8") as fh:
		json.dump({"api": API, "resolution": RESOLUTION, "format": FORMAT,
		           "license": "CC0-1.0",
		           "license_url": "https://polyhaven.com/license",
		           "assets": records, "errors": errors}, fh, indent=1)
	print("[fetch] %d ok, %d failed -> %s"
	      % (len(records), len(errors), manifest_path), flush=True)


main()
