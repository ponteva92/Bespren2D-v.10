"""Build the deterministic source manifest for Bespren's Godot 2D pipeline.

The script validates every ZIP below ``Addons`` before it writes anything,
selectively extracts production-relevant 2D content, converts animated GIFs to
PNG frames, detects standard pixel-art grids, and emits a manifest consumed by
``build_2d_resources.gd``. Source packs remain untouched.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
import re
import shutil
import sys
import unicodedata
import zipfile
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path, PurePosixPath
from typing import Any, Iterable

from PIL import Image, ImageSequence


IMAGE_EXTENSIONS = {".png", ".webp", ".jpg", ".jpeg", ".bmp", ".gif"}
DIRECT_IMAGE_EXTENSIONS = IMAGE_EXTENSIONS | {".tga"}
TEXT_EXTENSIONS = {".txt", ".md", ".url"}
ARCHIVE_EXTENSIONS = {".zip"}
MAX_ARCHIVE_MEMBER_BYTES = 192 * 1024 * 1024
MAX_NESTED_ARCHIVE_BYTES = 96 * 1024 * 1024
MAX_ARCHIVE_DEPTH = 4
COMMON_CELL_SIZES = (8, 12, 16, 24, 32, 40, 48, 64, 72, 80, 96, 128, 144, 160, 192, 256, 384, 512)

PRIMARY_ROOTS = (
    Path("Addons/ClawAndBlade_v1.5.0/ClawAndBlade"),
    Path("Addons/0x72_DungeonTilesetII_v1.7/0x72_DungeonTilesetII_v1.7"),
)

SEQUENCE_PATTERN = re.compile(
    r"^(?P<entity>.+?)[_-](?P<animation>idle|walk|run|move|attack(?:_[a-z0-9]+)?|"
    r"hurt|hit|death|die|ability(?:_[a-z0-9]+)?|stomp|open|close|loop|start|end)"
    r"(?:_anim)?[_-]?f?(?P<index>\d+)$",
    re.IGNORECASE,
)
EXPLICIT_GRID_PATTERN = re.compile(
    r"(?<!\d)(8|12|16|24|32|40|48|64|72|80|96|128|144|160|192|256|384|512)"
    r"\s*[xX]\s*"
    r"(8|12|16|24|32|40|48|64|72|80|96|128|144|160|192|256|384|512)(?!\d)"
)

MV_ANIMATIONS = (
    "walk",
    "wait",
    "chant",
    "guard",
    "damage",
    "evade",
    "thrust",
    "swing",
    "missile",
    "skill",
    "spell",
    "item",
    "escape",
    "victory",
    "dying",
    "abnormal",
    "sleep",
    "dead",
)


class PipelineError(RuntimeError):
    """Raised when a source cannot be processed without guessing."""


@dataclass(slots=True)
class ImageRecord:
    resource_path: str
    source_label: str
    family: str
    width: int
    height: int
    content_hash: str
    aliases: list[str] = field(default_factory=list)
    atlas_regions: list[dict[str, Any]] = field(default_factory=list)
    sequence_entity: str = ""
    sequence_animation: str = ""
    sequence_index: int = -1
    frame_duration: float = 1.0


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def slugify(value: str, limit: int = 72) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    ascii_value = normalized.encode("ascii", "ignore").decode("ascii").lower()
    slug = re.sub(r"[^a-z0-9]+", "_", ascii_value).strip("_")
    if not slug:
        slug = "asset"
    return slug[:limit].rstrip("_")


def res_path(project_root: Path, path: Path) -> str:
    return "res://" + path.resolve().relative_to(project_root.resolve()).as_posix()


def safe_member_name(name: str) -> bool:
    normalized = name.replace("\\", "/")
    member = PurePosixPath(normalized)
    if member.is_absolute() or ".." in member.parts:
        return False
    if re.match(r"^[a-zA-Z]:", normalized):
        return False
    return True


def family_for_label(label: str) -> str:
    lowered = label.lower()
    if "clawandblade" in lowered:
        return "claw_and_blade"
    if "0x72_dungeontileset" in lowered:
        return "dungeon_tileset"
    if "admurin" in lowered:
        return "admurin"
    if "aekashics librarium mv" in lowered:
        return "aekashics_mv"
    if "aekashics" in lowered or "librarium" in lowered:
        return "aekashics"
    return "archive_2d"


def is_nonproduction_reference(label: str) -> bool:
    lowered = label.replace("\\", "/").lower()
    stem = Path(lowered).stem
    path_tokens = set(PurePosixPath(lowered).parts)
    if "documentation" in path_tokens or "preview_stuff" in path_tokens:
        return True
    return bool(
        stem.startswith("_preview")
        or stem.startswith("_thumbnail")
        or stem in {"preview", "screenshot", "icon"}
    )


def archive_is_2d(path: Path, names: Iterable[str]) -> bool:
    label = str(path).lower()
    if any(token in label for token in ("admurin", "aekashics", "librarium")):
        return True
    lowered_names = [name.lower() for name in names]
    image_count = sum(Path(name).suffix.lower() in IMAGE_EXTENSIONS for name in lowered_names)
    if image_count == 0:
        return False
    strong_2d = any(
        any(token in name for token in ("sprite", "tile", "2d", "pixel", "enemy", "turret", "vfx", "parallax"))
        for name in lowered_names
    )
    has_2d_project = any(name.endswith("project.godot") for name in lowered_names) and strong_2d
    model_count = sum(Path(name).suffix.lower() in {".fbx", ".obj", ".gltf", ".glb"} for name in lowered_names)
    return strong_2d or has_2d_project or model_count == 0


def validate_zip_bytes(data: bytes, display_name: str, depth: int = 0) -> None:
    if depth > MAX_ARCHIVE_DEPTH:
        raise PipelineError(f"Archive nesting exceeds {MAX_ARCHIVE_DEPTH}: {display_name}")
    try:
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            bad_member = archive.testzip()
            if bad_member is not None:
                raise PipelineError(f"CRC failure in {display_name}: {bad_member}")
            for member in archive.infolist():
                if not safe_member_name(member.filename):
                    raise PipelineError(f"Unsafe path in {display_name}: {member.filename}")
                if member.file_size > MAX_ARCHIVE_MEMBER_BYTES:
                    raise PipelineError(f"Oversized archive member in {display_name}: {member.filename}")
                if Path(member.filename).suffix.lower() == ".zip" and not member.is_dir():
                    if member.file_size > MAX_NESTED_ARCHIVE_BYTES:
                        raise PipelineError(f"Oversized nested archive in {display_name}: {member.filename}")
                    validate_zip_bytes(archive.read(member), f"{display_name}!{member.filename}", depth + 1)
    except (zipfile.BadZipFile, OSError) as error:
        raise PipelineError(f"Corrupt archive {display_name}: {error}") from error


def alpha_bbox_nonempty(image: Image.Image, box: tuple[int, int, int, int]) -> bool:
    crop = image.crop(box)
    if "A" in crop.getbands():
        return crop.getchannel("A").getbbox() is not None
    return crop.getbbox() is not None


def alpha_boundary_ratio(image: Image.Image, cell_width: int, cell_height: int) -> float:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    width, height = rgba.size
    boundary_pixels = 0
    ink_pixels = 0
    for x in range(cell_width, width, cell_width):
        for sample_x in (max(0, x - 1), min(width - 1, x)):
            column = alpha.crop((sample_x, 0, sample_x + 1, height))
            histogram = column.histogram()
            ink_pixels += sum(histogram[8:])
            boundary_pixels += height
    for y in range(cell_height, height, cell_height):
        for sample_y in (max(0, y - 1), min(height - 1, y)):
            row = alpha.crop((0, sample_y, width, sample_y + 1))
            histogram = row.histogram()
            ink_pixels += sum(histogram[8:])
            boundary_pixels += width
    if boundary_pixels == 0:
        return 1.0
    return ink_pixels / boundary_pixels


def infer_alpha_grid(image: Image.Image) -> tuple[int, int] | None:
    width, height = image.size
    candidates: list[tuple[float, int, int]] = []
    for cell_width in COMMON_CELL_SIZES:
        if width % cell_width != 0:
            continue
        for cell_height in COMMON_CELL_SIZES:
            if height % cell_height != 0:
                continue
            columns = width // cell_width
            rows = height // cell_height
            total = columns * rows
            if total < 2 or total > 256:
                continue
            nonempty = 0
            for y in range(rows):
                for x in range(columns):
                    if alpha_bbox_nonempty(
                        image,
                        (x * cell_width, y * cell_height, (x + 1) * cell_width, (y + 1) * cell_height),
                    ):
                        nonempty += 1
            if nonempty < 2:
                continue
            boundary_ratio = alpha_boundary_ratio(image, cell_width, cell_height)
            if boundary_ratio > 0.075:
                continue
            aspect_penalty = abs(math.log(max(cell_width, 1) / max(cell_height, 1)))
            empty_penalty = (total - nonempty) / total
            score = boundary_ratio * 14.0 + aspect_penalty * 0.35 + empty_penalty * 0.15 - math.log(nonempty) * 0.04
            candidates.append((score, cell_width, cell_height))
    if not candidates:
        return None
    candidates.sort()
    _, cell_width, cell_height = candidates[0]
    return cell_width, cell_height


def grid_regions(image: Image.Image, cell_width: int, cell_height: int) -> list[dict[str, int | str]]:
    width, height = image.size
    if cell_width <= 0 or cell_height <= 0 or width % cell_width or height % cell_height:
        raise PipelineError(
            f"Atlas grid {cell_width}x{cell_height} does not divide texture {width}x{height}"
        )
    regions: list[dict[str, int | str]] = []
    for row in range(height // cell_height):
        for column in range(width // cell_width):
            box = (
                column * cell_width,
                row * cell_height,
                (column + 1) * cell_width,
                (row + 1) * cell_height,
            )
            if not alpha_bbox_nonempty(image, box):
                continue
            regions.append(
                {
                    "name": f"frame_{row:03d}_{column:03d}",
                    "x": box[0],
                    "y": box[1],
                    "w": cell_width,
                    "h": cell_height,
                    "column": column,
                    "row": row,
                }
            )
    if not regions:
        raise PipelineError(f"Atlas grid produced no visible frames for {width}x{height} texture")
    return regions


def animation_from_regions(name: str, regions: list[dict[str, Any]], fps: float = 8.0, loop: bool = True) -> dict[str, Any]:
    return {"name": name, "fps": fps, "loop": loop, "frames": regions}


class PipelineBuilder:
    def __init__(self, project_root: Path) -> None:
        self.project_root = project_root.resolve()
        self.addons_root = self.project_root / "Addons"
        self.output_root = self.project_root / "assets" / "2d"
        self.staging_root = self.output_root / "_source_imports"
        self.records: list[ImageRecord] = []
        self.record_index: dict[tuple[str, str], ImageRecord] = {}
        self.archives: list[dict[str, Any]] = []
        self.excluded: Counter[str] = Counter()
        self.slice_failures: list[str] = []
        self.pruned_staging_files = 0

    def validate_sources(self) -> list[Path]:
        for relative in PRIMARY_ROOTS:
            path = self.project_root / relative
            if not path.is_dir():
                raise PipelineError(f"Required source directory is missing: {path}")
        if not self.addons_root.is_dir():
            raise PipelineError(f"Required staging directory is missing: {self.addons_root}")
        archives = sorted(path for path in self.addons_root.rglob("*") if path.is_file() and path.suffix.lower() in ARCHIVE_EXTENSIONS)
        for path in archives:
            validate_zip_bytes(path.read_bytes(), str(path.relative_to(self.project_root)))
        return archives

    def _register_record(self, record: ImageRecord) -> ImageRecord:
        semantic_name = slugify(Path(record.source_label.split("!")[-1]).stem, 96)
        key = (record.content_hash, semantic_name)
        existing = self.record_index.get(key)
        if existing is not None:
            if record.source_label not in existing.aliases and record.source_label != existing.source_label:
                existing.aliases.append(record.source_label)
            if record.atlas_regions and not existing.atlas_regions:
                existing.atlas_regions = record.atlas_regions
            return existing
        self.record_index[key] = record
        self.records.append(record)
        return record

    def _read_direct_atlas_regions(self, path: Path) -> list[dict[str, Any]]:
        if not path.stem.lower().endswith("_tex"):
            return []
        metadata_path = path.with_suffix(".json")
        if not metadata_path.is_file():
            return []
        try:
            data = json.loads(metadata_path.read_text(encoding="utf-8-sig"))
        except (OSError, json.JSONDecodeError) as error:
            raise PipelineError(f"Invalid atlas metadata {metadata_path}: {error}") from error
        return self._normalize_atlas_regions(data, path.name)

    @staticmethod
    def _normalize_atlas_regions(data: Any, texture_name: str) -> list[dict[str, Any]]:
        if not isinstance(data, dict):
            return []
        image_path = str(data.get("imagePath", ""))
        if image_path and Path(image_path).name.lower() != Path(texture_name).name.lower():
            return []
        raw_regions = data.get("SubTexture", [])
        if not isinstance(raw_regions, list):
            return []
        regions: list[dict[str, Any]] = []
        for index, region in enumerate(raw_regions):
            if not isinstance(region, dict):
                continue
            try:
                x = int(region["x"])
                y = int(region["y"])
                width = int(region["width"])
                height = int(region["height"])
            except (KeyError, TypeError, ValueError) as error:
                raise PipelineError(f"Invalid DragonBones atlas region in {texture_name}: {error}") from error
            if width <= 0 or height <= 0 or x < 0 or y < 0:
                raise PipelineError(f"Invalid DragonBones atlas bounds in {texture_name}: {region}")
            regions.append(
                {
                    "name": slugify(str(region.get("name", f"part_{index}")), 64),
                    "x": x,
                    "y": y,
                    "w": width,
                    "h": height,
                    "column": index,
                    "row": 0,
                }
            )
        return regions

    def _convert_direct_gif(self, path: Path, family: str) -> None:
        source_label = str(path.relative_to(self.project_root)).replace("\\", "/")
        target_dir = self.staging_root / "gif_frames" / family / f"{slugify(path.stem)}_{sha256_file(path)[:10]}"
        target_dir.mkdir(parents=True, exist_ok=True)
        with Image.open(path) as image:
            frame_count = getattr(image, "n_frames", 1)
            if frame_count <= 1:
                self.excluded["single_frame_gif"] += 1
                return
            for index, frame in enumerate(ImageSequence.Iterator(image)):
                rgba = frame.convert("RGBA")
                target = target_dir / f"{slugify(path.stem)}_gif_f{index:03d}.png"
                rgba.save(target, "PNG", optimize=True)
                duration_ms = int(frame.info.get("duration", image.info.get("duration", 100)))
                record = ImageRecord(
                    resource_path=res_path(self.project_root, target),
                    source_label=f"{source_label}#frame={index}",
                    family=family,
                    width=rgba.width,
                    height=rgba.height,
                    content_hash=sha256_file(target),
                    sequence_entity=slugify(path.stem),
                    sequence_animation="preview_motion" if "preview" in path.stem.lower() else "default",
                    sequence_index=index,
                    frame_duration=max(duration_ms / 100.0, 0.1),
                )
                self._register_record(record)

    def scan_direct_sources(self) -> None:
        roots: list[Path] = [self.project_root / relative for relative in PRIMARY_ROOTS]
        for child in sorted(self.addons_root.iterdir()):
            lowered = child.name.lower()
            if child.is_dir() and any(token in lowered for token in ("admurin", "aekashic", "librarium")):
                roots.append(child)
        seen_roots: set[Path] = set()
        for root in roots:
            resolved = root.resolve()
            if resolved in seen_roots:
                continue
            seen_roots.add(resolved)
            family = family_for_label(str(root))
            for path in sorted(root.rglob("*")):
                if not path.is_file() or path.suffix.lower() not in DIRECT_IMAGE_EXTENSIONS:
                    continue
                label = str(path.relative_to(self.project_root)).replace("\\", "/")
                if is_nonproduction_reference(label):
                    self.excluded["preview_or_documentation"] += 1
                    continue
                if path.suffix.lower() == ".gif":
                    self._convert_direct_gif(path, family)
                    continue
                try:
                    with Image.open(path) as image:
                        width, height = image.size
                        image.verify()
                except (OSError, ValueError) as error:
                    raise PipelineError(f"Unreadable texture {path}: {error}") from error
                content_hash = sha256_file(path)
                direct_dir = self.staging_root / "images" / family / "direct"
                direct_dir.mkdir(parents=True, exist_ok=True)
                source_extension = path.suffix.lower()
                if source_extension in {".bmp", ".tga"}:
                    target = direct_dir / f"{slugify(path.stem, 58)}_{content_hash[:10]}.png"
                    with Image.open(path) as source_image:
                        source_image.convert("RGBA").save(target, "PNG", optimize=True)
                    content_hash = sha256_file(target)
                else:
                    target = direct_dir / f"{slugify(path.stem, 58)}_{content_hash[:10]}{source_extension}"
                    shutil.copy2(path, target)
                sequence = SEQUENCE_PATTERN.match(path.stem)
                record = ImageRecord(
                    resource_path=res_path(self.project_root, target),
                    source_label=label,
                    family=family,
                    width=width,
                    height=height,
                    content_hash=content_hash,
                    atlas_regions=self._read_direct_atlas_regions(path),
                )
                if sequence is not None:
                    record.sequence_entity = slugify(sequence.group("entity"))
                    record.sequence_animation = slugify(sequence.group("animation"))
                    record.sequence_index = int(sequence.group("index"))
                self._register_record(record)

    def _write_archive_image(
        self,
        data: bytes,
        entry_name: str,
        archive_label: str,
        archive_hash: str,
        family: str,
        atlas_regions: list[dict[str, Any]],
    ) -> None:
        source_label = f"{archive_label}!{entry_name}"
        if is_nonproduction_reference(source_label):
            self.excluded["preview_or_documentation"] += 1
            return
        try:
            with Image.open(io.BytesIO(data)) as image:
                width, height = image.size
                frame_count = getattr(image, "n_frames", 1)
                image_format = (image.format or "").upper()
                if image_format == "GIF" and frame_count > 1:
                    target_dir = self.staging_root / "gif_frames" / family / f"{slugify(Path(entry_name).stem)}_{archive_hash[:10]}"
                    target_dir.mkdir(parents=True, exist_ok=True)
                    for index, frame in enumerate(ImageSequence.Iterator(image)):
                        rgba = frame.convert("RGBA")
                        target = target_dir / f"{slugify(Path(entry_name).stem)}_gif_f{index:03d}.png"
                        rgba.save(target, "PNG", optimize=True)
                        duration_ms = int(frame.info.get("duration", image.info.get("duration", 100)))
                        self._register_record(
                            ImageRecord(
                                resource_path=res_path(self.project_root, target),
                                source_label=f"{source_label}#frame={index}",
                                family=family,
                                width=rgba.width,
                                height=rgba.height,
                                content_hash=sha256_file(target),
                                sequence_entity=slugify(Path(entry_name).stem),
                                sequence_animation="default",
                                sequence_index=index,
                                frame_duration=max(duration_ms / 100.0, 0.1),
                            )
                        )
                    return
                image.load()
        except (OSError, ValueError) as error:
            raise PipelineError(f"Unreadable archived texture {source_label}: {error}") from error

        extension = Path(entry_name).suffix.lower()
        content_hash = sha256_bytes(data)
        archive_dir = self.staging_root / "images" / family / f"{slugify(Path(archive_label).stem, 42)}_{archive_hash[:10]}"
        archive_dir.mkdir(parents=True, exist_ok=True)
        target_name = f"{slugify(Path(entry_name).stem, 58)}_{content_hash[:10]}{extension}"
        target = archive_dir / target_name
        target.write_bytes(data)
        sequence = SEQUENCE_PATTERN.match(Path(entry_name).stem)
        record = ImageRecord(
            resource_path=res_path(self.project_root, target),
            source_label=source_label,
            family=family,
            width=width,
            height=height,
            content_hash=content_hash,
            atlas_regions=atlas_regions,
        )
        if sequence is not None:
            record.sequence_entity = slugify(sequence.group("entity"))
            record.sequence_animation = slugify(sequence.group("animation"))
            record.sequence_index = int(sequence.group("index"))
        self._register_record(record)

    def _process_zip_payload(
        self,
        payload: bytes,
        archive_label: str,
        archive_hash: str,
        family: str,
        depth: int = 0,
    ) -> int:
        extracted_images = 0
        with zipfile.ZipFile(io.BytesIO(payload)) as archive:
            metadata: dict[str, dict[str, Any]] = {}
            for member in archive.infolist():
                if member.is_dir() or Path(member.filename).suffix.lower() != ".json":
                    continue
                try:
                    parsed = json.loads(archive.read(member).decode("utf-8-sig"))
                except (UnicodeDecodeError, json.JSONDecodeError):
                    continue
                if isinstance(parsed, dict) and isinstance(parsed.get("SubTexture"), list):
                    image_name = Path(str(parsed.get("imagePath", ""))).name.lower()
                    if image_name:
                        metadata[image_name] = parsed
                    metadata[Path(member.filename).with_suffix(".png").name.lower()] = parsed

            for member in archive.infolist():
                if member.is_dir():
                    continue
                extension = Path(member.filename).suffix.lower()
                if extension == ".zip":
                    nested_payload = archive.read(member)
                    nested_label = f"{archive_label}!{member.filename}"
                    nested_hash = sha256_bytes(nested_payload)
                    extracted_images += self._process_zip_payload(
                        nested_payload,
                        nested_label,
                        nested_hash,
                        family,
                        depth + 1,
                    )
                    continue
                if extension in TEXT_EXTENSIONS:
                    license_dir = self.staging_root / "licenses" / family
                    license_dir.mkdir(parents=True, exist_ok=True)
                    text_hash = sha256_bytes(archive.read(member))
                    target = license_dir / f"{slugify(Path(archive_label).stem, 36)}_{slugify(Path(member.filename).stem, 36)}_{text_hash[:8]}{extension}"
                    if not target.exists():
                        target.write_bytes(archive.read(member))
                    continue
                if extension not in IMAGE_EXTENSIONS:
                    continue
                data = archive.read(member)
                atlas_regions = self._normalize_atlas_regions(metadata.get(Path(member.filename).name.lower(), {}), Path(member.filename).name)
                self._write_archive_image(data, member.filename, archive_label, archive_hash, family, atlas_regions)
                extracted_images += 1
        return extracted_images

    def extract_archives(self, archives: list[Path]) -> None:
        seen_hashes: dict[str, str] = {}
        for path in archives:
            relative_label = str(path.relative_to(self.project_root)).replace("\\", "/")
            payload = path.read_bytes()
            archive_hash = sha256_bytes(payload)
            with zipfile.ZipFile(io.BytesIO(payload)) as archive:
                names = archive.namelist()
            if archive_hash in seen_hashes:
                self.archives.append(
                    {
                        "path": relative_label,
                        "sha256": archive_hash,
                        "status": "duplicate",
                        "duplicate_of": seen_hashes[archive_hash],
                        "images": 0,
                    }
                )
                continue
            seen_hashes[archive_hash] = relative_label
            if not archive_is_2d(path, names):
                self.archives.append(
                    {
                        "path": relative_label,
                        "sha256": archive_hash,
                        "status": "skipped_non_2d",
                        "images": 0,
                    }
                )
                continue
            family = family_for_label(relative_label)
            count = self._process_zip_payload(payload, relative_label, archive_hash, family)
            self.archives.append(
                {
                    "path": relative_label,
                    "sha256": archive_hash,
                    "status": "processed",
                    "images": count,
                }
            )

    @staticmethod
    def classify_category(record: ImageRecord) -> str:
        label = record.source_label.lower()
        if any(token in label for token in ("boss", "bigmonster", "big_monster", "dragonbones", "titan", "king", "queen", "goddess", "colossal")):
            return "bosses"
        if any(token in label for token in ("character", "enemy", "zombie", "demon", "ogre", "orc", "goblin", "slime", "knight", "dwarf", "elf", "angel", "wraith", "monster")):
            return "enemies"
        if any(token in label for token in ("building", "tree", "tilemap", "tileset", "ground", "wall", "floor", "castle", "house", "tower", "bridge", "parallax", "terrain", "road", "forest", "cave")):
            return "environment"
        return "props"

    @staticmethod
    def material_for(record: ImageRecord, category: str) -> str:
        label = record.source_label.lower()
        if any(token in label for token in ("tech", "clockwork", "automaton", "mecha", "machine", "turret", "drill", "robot", "cyber")):
            return "tech_cyan"
        if any(token in label for token in ("tree", "wood", "forest", "chest", "plank", "log")):
            return "wood_spore"
        if category == "environment" and any(token in label for token in ("building", "castle", "house", "tower", "roof", "wall", "bridge")):
            return "ruined_structure"
        if category == "bosses":
            return "boss_toxic"
        if category == "enemies":
            return "mutant_toxic"
        if any(token in label for token in ("copper", "bronze", "statue", "pipe")):
            return "oxidized_copper"
        return "rusted_prop"

    @staticmethod
    def is_tileset(record: ImageRecord) -> bool:
        label = record.source_label.lower().replace("\\", "/")
        if record.atlas_regions:
            return False
        return any(token in label for token in ("tilemap", "tileset", "atlas_floor", "atlas_wall", "/tilemaps/", "ground_all", "trees_all", "building_all"))

    def _open_record_image(self, record: ImageRecord) -> Image.Image:
        local = self.project_root / record.resource_path.removeprefix("res://")
        try:
            image = Image.open(local)
            image.load()
            return image.convert("RGBA")
        except (OSError, ValueError) as error:
            raise PipelineError(f"Cannot analyze imported texture {record.resource_path}: {error}") from error

    def _infer_record_animations(self, record: ImageRecord) -> tuple[list[dict[str, Any]], tuple[int, int] | None, str]:
        image = self._open_record_image(record)
        label = record.source_label.lower().replace("\\", "/")
        stem = Path(record.source_label.split("!")[-1]).stem.lower()

        if record.atlas_regions:
            for region in record.atlas_regions:
                if int(region["x"]) + int(region["w"]) > record.width or int(region["y"]) + int(region["h"]) > record.height:
                    raise PipelineError(f"Atlas metadata exceeds texture bounds: {record.source_label}")
                region["texture"] = record.resource_path
                region["duration"] = 1.0
            return [animation_from_regions("atlas_parts", record.atlas_regions, 1.0, False)], None, "atlas_parts"

        if (stem.startswith("$big") or "$big" in stem) and record.width % 3 == 0 and record.height % 4 == 0:
            cell = (record.width // 3, record.height // 4)
            regions = grid_regions(image, *cell)
            by_position = {(int(region["column"]), int(region["row"])): region for region in regions}
            animations: list[dict[str, Any]] = []
            for row, name in enumerate(("walk_down", "walk_left", "walk_right", "walk_up")):
                frames = [dict(by_position[(column, row)]) for column in range(3) if (column, row) in by_position]
                for frame in frames:
                    frame["texture"] = record.resource_path
                    frame["duration"] = 1.0
                if frames:
                    animations.append(animation_from_regions(name, frames, 6.0, True))
            if not animations:
                raise PipelineError(f"RPG Maker 3x4 atlas is empty: {record.source_label}")
            return animations, cell, "rpg_maker_3x4"

        if record.family == "aekashics_mv" and record.width % 9 == 0 and record.height % 6 == 0 and record.width >= 1152:
            cell = (record.width // 9, record.height // 6)
            regions = grid_regions(image, *cell)
            by_position = {(int(region["column"]), int(region["row"])): region for region in regions}
            animations = []
            for motion_index, name in enumerate(MV_ANIMATIONS):
                row = motion_index // 3
                start_column = (motion_index % 3) * 3
                frames = [dict(by_position[(start_column + offset, row)]) for offset in range(3) if (start_column + offset, row) in by_position]
                for frame in frames:
                    frame["texture"] = record.resource_path
                    frame["duration"] = 1.0
                if frames:
                    animations.append(animation_from_regions(name, frames, 8.0, name not in {"dead", "damage"}))
            if not animations:
                raise PipelineError(f"RPG Maker 9x6 atlas is empty: {record.source_label}")
            return animations, cell, "rpg_maker_9x6"

        source_filename = Path(record.source_label.split("!")[-1]).name
        explicit_match = EXPLICIT_GRID_PATTERN.search(source_filename)
        explicit_cell: tuple[int, int] | None = None
        if explicit_match is not None:
            explicit_cell = (int(explicit_match.group(1)), int(explicit_match.group(2)))
            if record.width == explicit_cell[0] and record.height == explicit_cell[1]:
                explicit_cell = None

        cell: tuple[int, int] | None = explicit_cell
        sheet_type = "grid"
        if cell is None and record.family == "claw_and_blade" and any(
            token in label for token in ("/tilemaps/", "building_all", "trees_all")
        ):
            cell = (64, 64)
        if cell is None and record.family == "claw_and_blade" and "character - tiles" in stem:
            trailing_size = re.search(r"(?:part\s*-\s*)?(64|128|256)$", stem)
            if trailing_size is not None:
                size = int(trailing_size.group(1))
                cell = (size, size)
        if cell is None and "3 frame frontview" in label and record.width % 3 == 0:
            cell = (record.width // 3, record.height)
            sheet_type = "three_frame"
        action_token = any(token in stem for token in ("idle", "move", "run", "attack", "hurt", "ability", "stomp", "death", "die", "loop"))
        if cell is None and action_token and record.width > record.height and record.height <= 512 and record.width % record.height == 0:
            cell = (record.height, record.height)
            sheet_type = "horizontal_strip"
        sheet_hint = any(token in stem for token in ("sheet", "sprites", "chests", "atlas"))
        if cell is None and sheet_hint and "_tex" not in stem:
            cell = infer_alpha_grid(image)
            if cell is not None:
                sheet_type = "alpha_grid"

        if cell is None:
            region = {
                "name": "frame_000_000",
                "x": 0,
                "y": 0,
                "w": record.width,
                "h": record.height,
                "column": 0,
                "row": 0,
                "texture": record.resource_path,
                "duration": 1.0,
            }
            return [animation_from_regions("default", [region], 1.0, False)], None, "standalone"

        try:
            regions = grid_regions(image, *cell)
        except PipelineError as error:
            qualified_error = f"{record.source_label}: {error}"
            self.slice_failures.append(qualified_error)
            raise PipelineError(qualified_error) from error
        for region in regions:
            region["texture"] = record.resource_path
            region["duration"] = 1.0
        animation_name = "default"
        for token in ("idle", "move", "run", "attack", "hurt", "ability", "stomp", "death", "die", "loop"):
            if token in stem:
                animation_name = token
                break
        return [animation_from_regions(animation_name, regions, 10.0 if action_token else 8.0, action_token)], cell, sheet_type

    def _sequence_bundles(self) -> tuple[list[dict[str, Any]], set[int]]:
        groups: dict[tuple[str, str, str], list[tuple[int, ImageRecord]]] = defaultdict(list)
        for record_index, record in enumerate(self.records):
            if not record.sequence_entity or record.sequence_index < 0:
                continue
            parent_key = str(PurePosixPath(record.source_label.split("!")[-1]).parent).lower()
            groups[(record.family, parent_key, record.sequence_entity)].append((record_index, record))

        bundles: list[dict[str, Any]] = []
        consumed: set[int] = set()
        for (_, parent_key, entity), indexed_records in sorted(groups.items()):
            animations_map: dict[str, list[ImageRecord]] = defaultdict(list)
            for record_index, record in indexed_records:
                animations_map[record.sequence_animation].append(record)
                consumed.add(record_index)
            sample = indexed_records[0][1]
            category = self.classify_category(sample)
            animations: list[dict[str, Any]] = []
            for animation_name, frames in sorted(animations_map.items()):
                sorted_frames = sorted(frames, key=lambda item: item.sequence_index)
                frame_entries: list[dict[str, Any]] = []
                for frame in sorted_frames:
                    frame_entries.append(
                        {
                            "name": f"{animation_name}_{frame.sequence_index:03d}",
                            "x": 0,
                            "y": 0,
                            "w": frame.width,
                            "h": frame.height,
                            "column": frame.sequence_index,
                            "row": 0,
                            "texture": frame.resource_path,
                            "duration": frame.frame_duration,
                        }
                    )
                animations.append(animation_from_regions(animation_name, frame_entries, 8.0, animation_name not in {"death", "die", "hit"}))
            identity = hashlib.sha1(f"{parent_key}|{entity}".encode("utf-8")).hexdigest()[:10]
            bundles.append(
                {
                    "id": f"{slugify(entity, 48)}_{identity}",
                    "display_name": entity.replace("_", " ").title(),
                    "category": category,
                    "material": self.material_for(sample, category),
                    "source_kind": "frame_sequence",
                    "animations": animations,
                    "tileset": None,
                    "source_aliases": sorted({record.source_label for _, record in indexed_records}),
                    "primary_texture": animations[0]["frames"][0]["texture"],
                }
            )
        return bundles, consumed

    def build_bundles(self) -> list[dict[str, Any]]:
        bundles, consumed = self._sequence_bundles()
        for index, record in enumerate(self.records):
            if index in consumed:
                continue
            animations, cell, source_kind = self._infer_record_animations(record)
            category = self.classify_category(record)
            identity = hashlib.sha1(record.source_label.encode("utf-8")).hexdigest()[:10]
            asset_id = f"{slugify(Path(record.source_label.split('!')[-1]).stem, 48)}_{identity}"
            tileset_data: dict[str, Any] | None = None
            if cell is not None and self.is_tileset(record):
                active_cells = [
                    {"column": int(frame["column"]), "row": int(frame["row"])}
                    for animation in animations
                    for frame in animation["frames"]
                ]
                unique_cells = sorted({(entry["column"], entry["row"]) for entry in active_cells}, key=lambda item: (item[1], item[0]))
                tileset_data = {
                    "texture": record.resource_path,
                    "region_size": [cell[0], cell[1]],
                    "tile_size": [cell[0], min(cell[0], cell[1])],
                    "cells": [{"column": column, "row": row} for column, row in unique_cells],
                }
            bundles.append(
                {
                    "id": asset_id,
                    "display_name": Path(record.source_label.split("!")[-1]).stem.replace("_", " ").title(),
                    "category": category,
                    "material": self.material_for(record, category),
                    "source_kind": source_kind,
                    "animations": animations,
                    "tileset": tileset_data,
                    "source_aliases": sorted({record.source_label, *record.aliases}),
                    "primary_texture": record.resource_path,
                }
            )
        bundles.sort(key=lambda item: (item["category"], item["id"]))
        return bundles

    def prune_unreferenced_staging_images(self) -> None:
        keep_paths = {
            (self.project_root / record.resource_path.removeprefix("res://")).resolve()
            for record in self.records
            if record.resource_path.startswith("res://assets/2d/_source_imports/")
        }
        for subtree_name in ("images", "gif_frames"):
            subtree = self.staging_root / subtree_name
            if not subtree.is_dir():
                continue
            for path in sorted(subtree.rglob("*"), reverse=True):
                if path.is_dir():
                    try:
                        path.rmdir()
                    except OSError:
                        pass
                    continue
                lowered = path.name.lower()
                if lowered.endswith(".import"):
                    source_path = Path(str(path)[: -len(".import")]).resolve()
                    if source_path in keep_paths:
                        continue
                    path.unlink()
                    self.pruned_staging_files += 1
                    continue
                if path.suffix.lower() not in DIRECT_IMAGE_EXTENSIONS:
                    continue
                if path.resolve() in keep_paths:
                    continue
                import_sidecar = Path(str(path) + ".import")
                path.unlink()
                self.pruned_staging_files += 1
                if import_sidecar.is_file():
                    import_sidecar.unlink()
                    self.pruned_staging_files += 1

    def run(self) -> dict[str, Any]:
        archives = self.validate_sources()
        self.staging_root.mkdir(parents=True, exist_ok=True)
        self.scan_direct_sources()
        self.extract_archives(archives)
        bundles = self.build_bundles()
        self.prune_unreferenced_staging_images()
        if self.slice_failures:
            raise PipelineError("Texture atlas slicing failed:\n" + "\n".join(self.slice_failures))
        category_counts = Counter(str(bundle["category"]) for bundle in bundles)
        manifest = {
            "schema_version": 1,
            "generator": "tools/asset_pipeline/build_2d_asset_pipeline.py",
            "source_roots": [relative.as_posix() for relative in PRIMARY_ROOTS] + ["Addons (2D archives and named staging packs)"],
            "archives": self.archives,
            "assets": bundles,
            "summary": {
                "archives_discovered": len(archives),
                "archives_processed": sum(record["status"] == "processed" for record in self.archives),
                "archives_duplicate": sum(record["status"] == "duplicate" for record in self.archives),
                "archives_skipped_non_2d": sum(record["status"] == "skipped_non_2d" for record in self.archives),
                "image_records": len(self.records),
                "production_bundles": len(bundles),
                "categories": dict(sorted(category_counts.items())),
                "excluded": dict(sorted(self.excluded.items())),
                "pruned_redundant_staging_files": self.pruned_staging_files,
                "slice_failures": 0,
            },
        }
        catalog_dir = self.output_root / "catalog"
        catalog_dir.mkdir(parents=True, exist_ok=True)
        manifest_path = catalog_dir / "source_manifest.json"
        manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
        return manifest


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
        help="Godot project root containing project.godot and Addons",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        builder = PipelineBuilder(args.project_root)
        manifest = builder.run()
    except PipelineError as error:
        print(f"ASSET PIPELINE FAILED | {error}", file=sys.stderr)
        return 2
    summary = manifest["summary"]
    print(
        "ASSET SOURCE MANIFEST OK | "
        f"archives={summary['archives_discovered']} "
        f"processed={summary['archives_processed']} "
        f"duplicates={summary['archives_duplicate']} "
        f"images={summary['image_records']} "
        f"bundles={summary['production_bundles']}"
    )
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
