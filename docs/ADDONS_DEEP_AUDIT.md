# Addons Deep Audit and Visual Traceability

Audit date: 2026-08-14  
Scope root: `C:\Users\heikk\Desktop\Claude\gpt_peli\Addons`  
Runtime target: Godot 4.7.1 Mobile, 2D, 480 x 270 landscape

## What “every file” means

`tools/asset_pipeline/deep_asset_audit.py` inspected every physical file under `Addons/` without modifying the vault. Each physical file has one JSONL record containing its path, byte count, SHA-256, format classification, role signals, license signals, and automated runtime-fit decision.

Supported signature-detected containers were also opened recursively. Every member was path-safety checked, completely decompressed, integrity checked, SHA-256 hashed, classified, and written to a second JSONL ledger. ZIP CRC is checked for ordinary ZIPs and ZIP-based Krita `.kra` and Adobe Animate `.fla` files. Gzip integrity and TAR member safety are checked for Unity `.unitypackage` files, including supported nested packages.

This is an exhaustive automated file/container audit. It is not a claim that a person manually art-directed all 9,885 visual candidates one by one. Manual visual review was applied to the promoted shortlist, Blender-derived outputs, integrated scenes, and gameplay-scale captures. Unsupported compound binary internals receive a complete physical-file hash but are not described as extracted when no safe parser contract exists.

## Exact totals

| Measure | Exact result |
|---|---:|
| Physical files hashed | 31,404 |
| Physical source bytes | 2,355,834,247 |
| Physical signature-detected containers | 145 |
| Physical container formats | 144 ZIP, 1 gzip-tar |
| Recursive physical + nested containers | 159 |
| Recursive container formats | 155 ZIP, 4 gzip-tar |
| Nested containers | 14: 11 ZIP, 3 gzip-tar |
| Recursively audited member records | 4,684 |
| Member bytes decompressed and integrity-checked | 892,666,069 |
| Exact duplicate physical files | 1,887 |
| Duplicate physical bytes | 151,292,509 |
| Exact duplicate archive members | 978 |
| Duplicate archive-member bytes | 75,595,066 |

The physical-file ledger has exactly 31,404 lines. The archive-member ledger has exactly 4,684 lines. Member attribution is 3,292 records reached through ZIP containers and 1,392 through gzip-tar containers.

### Physical content classification

| Kind | Files | Kind | Files |
|---|---:|---|---:|
| Raster images | 11,004 | Vector images | 2,079 |
| 3D sources | 1,455 | Editable art masters | 211 |
| Audio | 161 | Video | 28 |
| Code | 723 | Documents | 389 |
| Project data | 2,267 | Fonts | 11 |
| Generated metadata/cache | 12,630 | Archives | 145 |
| Binary/unknown | 301 |  |  |

### Automated decision ledger

| Decision | Files |
|---|---:|
| `candidate_visual_review` | 9,885 |
| `candidate_audio_review` | 157 |
| `exclude_generated_cache` | 12,632 |
| `retain_audited_container` | 145 |
| `retain_provenance` | 45 |
| `retain_reference` | 354 |
| `retain_source_library` | 3,411 |
| `retain_source_only` | 1,483 |
| `retain_unclassified_source` | 290 |
| `retain_vendor_project_only` | 2,989 |
| `selected_runtime` in the audit snapshot | 13 |

The deep-audit snapshot still records 13 entries as `selected_runtime` because it preserves the classification state that included the former castle candidate. The live reviewed promotion manifest supersedes that decision: `assets/runtime_asset_manifest.json` contains exactly 12 assets after castle retirement. The castle is not in that manifest, is not referenced by `base_core.tscn`, and is not intended for the runtime export closure.

## Evidence hashes

These SHA-256 values identify the evidence files at the reconciliation date. Regenerating the audit after changing `Addons/` will intentionally change them.

| Evidence | SHA-256 |
|---|---|
| `artifacts/asset_audit/addons_file_ledger.jsonl` | `3A64F42EBE1F525821FFE20264CC0E6178869BEFC14298126C88FBCDAD3AB275` |
| `artifacts/asset_audit/archive_member_ledger.jsonl` | `501FA3192048A81D7617B1973C10A927037BD5130175D51CBAC6320A67340AEF` |
| `artifacts/asset_audit/deep_asset_audit_summary.json` | `BC9D69234ABFBC22FA74A588C3D0227395555C05164D22347F1775B890F6C5DC` |
| `assets/runtime_asset_manifest.json` | `AB6EF8B96E5AC9C95F1FBA6A8EA02D159636C23E3FD050B222A570875F8C3DEE` |

The runtime manifest’s 12 entries are two ClawAndBlade tile/tree textures, one MIT projectile strip, four audio cues, and five license records. Derived Blender atlases are governed by their own source manifests rather than counted as direct vault promotions.

## License boundary

License detection is evidence triage, not legal advice. The audit found 41 top-level packages with a license signal and 40 without one; 3,531 candidate visual files occur in packages without a detected license signal. No missing signal is silently treated as permission.

Runtime use is restricted to sources with a reviewed provenance chain:

- ClawAndBlade, Kenney, and MIT source evidence is copied beside the runtime material where required.
- Fourteen Poly Haven model IDs and four Poly Haven terrain IDs are CC0 and tracked in separate manifests. The original six nature/prop models are joined by the eight-model Hidden Alley family: `modular_urban_apartments_facade`, `modular_factory_facade`, `modular_chainlink_fence`, `covered_car`, `exterior_aircon_unit`, `modular_street_seating`, `fire_hydrant`, and `barrel_stove`. They were acquired through the Blender/Poly Haven workflow and are outside the `Addons/` totals.
- Atomic Realm-derived images remain edited, embedded Bespren game content. They must not be repackaged, resold, or redistributed as a standalone asset library.
- The presence of a README, URL, or filename containing “license” is only a signal until its terms are reviewed for the intended use.

## Past-plan review set

The current implementation was reconciled against every project design/production document present at the time of this audit:

1. `CLAUDE.md` — product, visual, architecture, mobile, and completion contract.
2. `docs/ASSET_2D_PIPELINE.md` — source promotion, broad catalog, and bake pipeline.
3. `docs/MOBILE_LAN_FOUNDATION.md` — mobile input, peer-one authority, and device gates.
4. `docs/TACTICAL_HUD_AND_BUILD.md` — compact HUD, minimap, build popup, placement, and tower collision.
5. `docs/VISUAL_ASSET_OVERHAUL_AUDIT.md` — visual issue-to-evidence record.
6. `docs/WORLD_MAP_FOUNDATION.md` — map coordinates, layers, collision, resources, and validation.
7. `docs/WORLD_MAP_VISUAL_PRODUCTION_PLAN.md` — district composition, negative space, materials, budgets, and remaining visual gates.

## Ten-requirement traceability matrix

| # | User requirement | Past plans checked | Current implementation/evidence | Remaining proof |
|---:|---|---|---|---|
| 1 | Towers/traps must be unmistakably different | `CLAUDE.md`; `TACTICAL_HUD_AND_BUILD.md`; `VISUAL_ASSET_OVERHAUL_AUDIT.md` | Eight different Blender silhouettes: three towers, three traps, and two utilities. Each defense has a distinct texture/role; `structure_visual_library.png` is reviewed at 480x270. | Physical-device readability at gameplay zoom |
| 2 | Buildings, nature, environment, and props need more variety | `ASSET_2D_PIPELINE.md`; `VISUAL_ASSET_OVERHAUL_AUDIT.md`; `WORLD_MAP_FOUNDATION.md`; `WORLD_MAP_VISUAL_PRODUCTION_PLAN.md` | 16-frame/29-GLB local atlas; 12-frame/six-source Poly Haven nature atlas; eight-frame/eight-source Hidden Alley district atlas; four-source terrain blend; three camp satellites; six village dressing props; exactly 16 district sprites on colliding city/Ostari-mall/village/vehicle/camp parents; 1,100 ground marks with 75 benches, 46 hydrants and 34 stoves; plus 576 collision-free ambient ruin/tree/prop groups | Refreshed final-state world captures; Android performance |
| 3 | Build menu must be dynamic and polished | `CLAUDE.md`; `TACTICAL_HUD_AND_BUILD.md`; `VISUAL_ASSET_OVERHAUL_AUDIT.md` | Safe-area top sheet; Towers/Traps/Utilities tabs; eight thumbnail cards; live resource chips; remembered selection; at most three cards per page; preview, affordability, outside close, and same-frame input release | Physical multitouch and cutout ergonomics |
| 4 | Night must not be too dark | `CLAUDE.md`; `TACTICAL_HUD_AND_BUILD.md`; `WORLD_MAP_VISUAL_PRODUCTION_PLAN.md`; `VISUAL_ASSET_OVERHAUL_AUDIT.md` | Three-second transition to `#91A3BD`; terrain shader remains responsive to CanvasModulate and local camp/tower lights | Physical OLED/LCD and outdoor-brightness review; fresh final camp-night capture |
| 5 | Top-left resources/actions 50% smaller | `CLAUDE.md`; `TACTICAL_HUD_AND_BUILD.md`; `VISUAL_ASSET_OVERHAUL_AUDIT.md` | `148 x 58` dashboard with one horizontal resource row, three independent `44 x 44` commands, separate wave chip, and transient toast. Its 8,584-pixel area is 50.9% below the former `208 x 84` dashboard/status union. | Physical finger-target and safe-area certification |
| 6 | Spawn in the middle of forest/middle of nowhere | `MOBILE_LAN_FOUNDATION.md`; `WORLD_MAP_FOUNDATION.md`; `WORLD_MAP_VISUAL_PRODUCTION_PLAN.md`; `VISUAL_ASSET_OVERHAUL_AUDIT.md` | Camp/spawn at `(9950, 2400)`, exactly 2,098 units from nearest road edge; complete satellites and spawn/resource approaches retain at least 1,600 units | Fresh final-state camp capture; physical navigation session |
| 7 | Minimap must be smaller | `CLAUDE.md`; `TACTICAL_HUD_AND_BUILD.md`; `VISUAL_ASSET_OVERHAUL_AUDIT.md` | 72 x 54 interactive minimap with compact markers and 2D ping | Physical readability/tap precision |
| 8 | Colors must stop looking cheap | `ASSET_2D_PIPELINE.md`; `VISUAL_ASSET_OVERHAUL_AUDIT.md`; `WORLD_MAP_VISUAL_PRODUCTION_PLAN.md`; `CLAUDE.md` | Muted petroleum/rust/patina palette, restrained saturation/contrast, lifted shadows, bounded sheen/contact shadows, seamless Poly Haven material blend, and Hidden Alley frames with minimum alpha-weighted luma `65.967` plus at least 30px source margins | Final pixel refresh and physical low-brightness review |
| 9 | Base must read as a camp, not a castle | `CLAUDE.md`; `ASSET_2D_PIPELINE.md`; `WORLD_MAP_FOUNDATION.md`; `VISUAL_ASSET_OVERHAUL_AUDIT.md` | Blender survivor camp plus bedding, supply, and medical satellites; castle removed from scene, live 12-item runtime manifest, export closure, and final APK inventory | Physical-device camp readability |
| 10 | Players must not run through towers | `MOBILE_LAN_FOUNDATION.md`; `TACTICAL_HUD_AND_BUILD.md`; `WORLD_MAP_FOUNDATION.md`; `CLAUDE.md` | Blocking towers/utilities own `WorldStatic` collision; ground traps are deliberately traversable but still participate in placement overlap. Peer one composes live-defense and static-map motion resolution before broadcasting. | Physical two-device collision session |

## Capture and device evidence boundary

The world render scene now writes 23 Mobile/Vulkan outputs at exactly 480 x 270, including the terrain-transition, camp-composition and dedicated city/forest/wilderness-density views. The refreshed artifacts use the final camp position and current district/ambient scenery state. Static/headless gates cover the current coordinates and assets with `WORLD MAP VALIDATION OK (150 checks)`, `RESOURCE SCATTER VALIDATION OK (72 checks)` and `POLY HAVEN DISTRICT VALIDATION OK (58 checks)`; the current smoke run has one unresolved east-camp flow-direction assertion. Fresh Mobile/Vulkan HUD, build, structure, and enemy artifacts are separately reviewed.

Likewise, desktop/headless success does not certify Android installation, safe-area/cutout behavior, physical multitouch, audio perception, sustained frame time or thermals, lifecycle interruption, or two-device Wi-Fi/LAN behavior. Fresh `Bespren-runtime-polish.pck` contains the 134-resource current closure and passes isolated loading/23 scene instantiations. Fresh `Bespren-polish.apk` exports successfully and verifies with APK Signature Schemes v2/v3. Physical-device gates remain open.
