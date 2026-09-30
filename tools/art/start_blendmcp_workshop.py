"""Start the installed BlendMCP addon for a dedicated Blender workshop.

This helper is intentionally tiny so automated art sessions can reopen a
reviewed ``.blend`` file without requiring a manual sidebar click.  Blender
loads the workshop before executing this script.
"""

from __future__ import annotations

import bpy


def start() -> None:
    bpy.ops.preferences.addon_enable(module="blendmcp_addon")
    result = bpy.ops.blendermcp.start_server()
    if "FINISHED" not in result:
        raise RuntimeError(f"BlendMCP server did not start: {result}")
    print(
        "BESPREN BLENDMCP READY | "
        f"scene={bpy.context.scene.name} | file={bpy.data.filepath}"
    )


if __name__ == "__main__":
    start()
