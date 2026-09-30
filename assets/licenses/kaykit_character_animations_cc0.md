# KayKit Character Animations CC0 source rig

Every animated actor sheet under `res://assets/2d/enemies/` and
`res://assets/2d/characters/` is an original Bespren render. The bodies are
authored geometry (`tools/art/build_actor_body.py`) bound to the CC0 KayKit
`Rig_Medium` skeleton, driven by KayKit's animation clips.

- License: Creative Commons Zero (CC0 1.0 Universal)
- License page: http://creativecommons.org/publicdomain/zero/1.0/
- Author: Kay Lousberg — https://www.kaylousberg.com
- Pack: KayKit Character Animations (1.1)

No KayKit mesh, texture, material, or Node3D reaches `res://`. What is used is
the skeleton and the motion; the geometry rendered onto it is Bespren's own.

Reproducible pipeline:
- bodies: `res://tools/art/build_actor_body.py`
- rig and palette: `res://tools/art/aaa_bake_rig.py`
- bake driver: `res://tools/art/run_actor_bake.py`
- sheet packing: `res://tools/art/pack_actor_sheets.py`
