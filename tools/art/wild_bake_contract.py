"""Shared paths and safety checks for the wild/salvage offline bake.

The renderer runs inside Blender while the sharded runner uses the host Python
interpreter. Keeping their output-root calculation here prevents a trial from
silently writing reports somewhere the runner cannot later find.
"""

from __future__ import annotations

import os
from collections.abc import Mapping
from pathlib import Path


ART_ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = ART_ROOT.parent.parent
ENVIRONMENT_ROOT = PROJECT_ROOT / "assets" / "2d" / "environment"
TRIAL_ARTIFACT_ROOT = PROJECT_ROOT / "artifacts" / "wild_salvage_trial"
OUTPUT_ROOT_ENV = "BESPREN_WILD_BAKE_OUTPUT_ROOT"
TRIAL_SOURCES: dict[str, tuple[str, ...]] = {
    "polyhaven_wild": ("fern_02",),
    "polyhaven_salvage": ("metal_toolbox",),
}
# Sources that were fetched into the vault, evaluated, and deliberately not
# baked. [func sources] in [mod run_wild_bake] enumerates the fetch manifest
# rather than the renderer's roster, so without this set every rejected source
# renders nothing and is reported as "no frame written" - four such entries in
# an otherwise clean 67-frame run, and the atlas builder refuses to pack a
# family whose report carries errors. Listing them here states the decision
# once and keeps a re-fetch from quietly resurrecting one. The reasoning for
# each lives with the roster it was cut from, in [const FAMILIES].
REJECTED_SOURCES: dict[str, frozenset[str]] = {
    "polyhaven_wild": frozenset(
        {"pine_tree_01", "pine_sapling_medium", "shrub_01", "moss_01"}
    ),
    "polyhaven_salvage": frozenset(),
}
FRAME_SIZE = 256
MINIMUM_FRAME_MARGIN = 5
MINIMUM_ALPHA_WEIGHTED_LUMA = 34.0

# The packer's floor above is a hard contract - a frame under it is broken and
# the atlas refuses it - but it is not a target, and treating it as one is what
# produced the family's worst defect. The per-frame exposure loop stopped the
# moment a frame cleared 34.0, so ten of twenty-six wild frames landed at 35-39
# while `stump` landed at 131: a 3.7x value spread inside one prop family, with
# no centre.
#
# 34.0 was also chosen without reference to the ground. Composited over the
# forest floor - rgb(58, 53, 43), luma 53.0 - a prop at 36 is *darker than the
# terrain it stands on* and reads as a silhouette-shaped hole rather than an
# object. `rock_mossy`, `roots_cluster`, `grass`, `moss` and `shrub_b` all did.
#
# The band below is measured rather than chosen. Reviewing the family frame by
# frame against the floor, every frame judged to read correctly fell in
# 70.7 (`roots_pine_0`) to 103.5 (`roots_pine_1`) - with `fern`, `branches`,
# `rock_bare`, `shrub_a` and `fir` in between - and every frame judged broken
# fell outside it on one side or the other. The bounds therefore ratify the
# frames that already work: each of those nine sits inside the band and is not
# re-rendered by the change. Only the outliers move, and they move to the
# nearest edge, so `stump` stays brighter than `rock_mossy` afterwards.
#
# That ordering matters, because the falloff-compensation note in
# [render_polyhaven_district_sprites] argues that albedo differences between
# subjects are signal and must survive. They do: the band removes a *source*
# artefact - Poly Haven photographed the stump in sun and the mossy rock in
# shade, which is not information about Bespren's world - while leaving the
# relative order of every frame intact.
TARGET_LUMA_FLOOR = 70.0
TARGET_LUMA_CEILING = 108.0


def _is_within(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
    except ValueError:
        return False
    return True


def resolve_output_root(environment: Mapping[str, str] | None = None) -> Path:
    """Return the only two supported destinations for baked frame reports.

    Normal production bakes target ``assets/2d/environment``. A trial may
    target only the dedicated artifact directory so unreviewed frames cannot
    accidentally become runtime inputs.
    """

    values = os.environ if environment is None else environment
    raw = values.get(OUTPUT_ROOT_ENV, "").strip()
    if not raw:
        return ENVIRONMENT_ROOT
    candidate = Path(raw).expanduser().resolve()
    if not _is_within(candidate, TRIAL_ARTIFACT_ROOT):
        raise RuntimeError(
            "%s must stay under %s, got %s"
            % (OUTPUT_ROOT_ENV, TRIAL_ARTIFACT_ROOT, candidate)
        )
    return candidate


def report_path(output_root: Path, source_id: str = "") -> Path:
    """Return a report path while rejecting path-like source identifiers."""

    if source_id and (
        Path(source_id).name != source_id
        or "/" in source_id
        or "\\" in source_id
        or source_id in {".", ".."}
    ):
        raise ValueError("source_id must be a simple asset identifier: %r" % source_id)
    suffix = "_%s" % source_id if source_id else ""
    return output_root / ("polyhaven_wild_render_report%s.json" % suffix)


def validate_output_contract(output_root: Path) -> None:
    """Fail before Blender starts if the root/output/report contract drifted."""

    project_file = PROJECT_ROOT / "project.godot"
    if not project_file.is_file():
        raise RuntimeError("Project root is not valid: missing %s" % project_file)
    resolved = output_root.resolve()
    allowed = resolved == ENVIRONMENT_ROOT or _is_within(resolved, TRIAL_ARTIFACT_ROOT)
    if not allowed:
        raise RuntimeError("Unsupported bake output root: %s" % resolved)
    if not _is_within(resolved, PROJECT_ROOT):
        raise RuntimeError("Bake output must remain inside project root: %s" % resolved)
    if report_path(resolved).parent != resolved:
        raise RuntimeError("Aggregate report escaped bake output root: %s" % resolved)
