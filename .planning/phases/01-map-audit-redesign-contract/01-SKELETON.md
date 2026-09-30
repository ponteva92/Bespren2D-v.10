# Walking Skeleton — Bespren Visual AAA+ & Map Redesign

**Phase:** 1
**Generated:** 2026-09-19

## Capability Proven End-to-End

A map reviewer can open `docs/WORLD_MAP_AUDIT.md` (live 14×14 census) and `docs/WORLD_MAP_REDESIGN_CONTRACT.md` (locked target anatomy) and confirm with git that `src/world/` did not change.

## Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Framework | Existing Godot `4.7.1.stable.official.a13da4feb` Mobile / Vulkan, typed GDScript, no autoloads | Brownfield shipping runtime. Phase 1 does not scaffold an app, router, or lint toolchain. Godot is not invoked this phase. |
| Data layer | Markdown contract now (`docs/WORLD_MAP_AUDIT.md` + `docs/WORLD_MAP_REDESIGN_CONTRACT.md`). Typed `WorldCompositionContract` Resource at `data/world/bespren_world_composition.tres` is **Phase 2** — `BesprenWorldMap2D.ensure_built()` consumes it later. | Inner classes do not serialize; autoloads forbidden; writing `.gd`/`.tres` in Phase 1 is world-authoring by another name (D-25, CONTEXT deferred). |
| Auth | Unchanged peer-one host path. `ENetMultiplayerPeer` UDP 8791 / `OfflineMultiplayerPeer` Solo. No accounts. | Docs cannot grant RPC. LAN Join still types an address. Do not expand the LAN threat model. |
| Deployment | Local markdown in this git repo. No Vercel, no hosting, no APK rebuild. | Reviewer opens `docs/` in the working tree. Proof of CONT-01 is heading completeness + live-constant quotes + empty `src/world/` path filter. |
| Directory layout | `docs/WORLD_MAP_AUDIT.md` (as-is census) sibling to `docs/WORLD_MAP_REDESIGN_CONTRACT.md` (to-be). Do not merge. Do not rewrite `docs/WORLD_MAP_FOUNDATION.md` counts. | Two files stop Phase 2 from treating current-state counts as target composition (D-25). Foundation tracks the *implemented* world; counts move in Phase 2. |

## Stack Touched in Phase 1

- [x] Project scaffold — **reuse existing Godot 4.7.1 project**; no Next.js/DB/UI/deploy scaffold
- [x] Routing — **not applicable**; no HTTP routes. Reviewer path is open-the-markdown
- [x] Database — **not applicable**; census is grep of live `.gd` constants, not a DB
- [x] UI — **not applicable**; no GameHUD / UI-SPEC work (false-positive on the word "layout" in world layout)
- [x] Deployment — documented local full-stack run: open the two `docs/` files; run `git diff --name-only -- src/world/` (must print nothing)

## Out of Scope (Deferred to Later Slices)

- `WorldCompositionContract` Resource + `data/world/bespren_world_composition.tres` (Phase 2)
- Any `src/world/` layout edit, atlas `Rect2`, scenery/cover/resource count change, `LAYOUT_VERSION` or `WORLD_BUILD_SEED` bump
- Capture camera nodes in `tests/world_render_validation.gd` (Phase 7 implements IDs named here)
- Third `dirt_flags` enum / `WorldRoadNetwork2D` visual grade (Phase 3 ROAD-01)
- Pocket 2 relocation / `OstariSouthShell` move (Phase 5 co-author)
- FIR-01 fir canopy mass, SALV-01 salvage-atlas promotion, fence vs house projection rebake, TINT-01, PLACE-01
- Extra unique stamps (SETP-01 / VISL-01)
- Android device certification, physical two-device LAN, deposit/inventory/progression
- Web app, Express/Next, Postgres, lint runner, GUT/Jest, `tests/map_contract_validation.gd`

## Subsequent Slice Plan

Each later phase adds one vertical slice on top of this skeleton without altering its architectural decisions:

- Phase 2: Player traverses an authored skeleton stored as `WorldCompositionContract` composition data inside locked 14×14 / ±14,336
- Phase 3: Asphalt spine, dirt branch, and wilderness perimeter read as the loop's path at 1×
- Phase 4: Kaupunki choke, Ostari salvage, Kylät quiet, Metsä threat read without labels
- Phase 5: Camp clearing + 87 IDs in co-authored salvage pockets
- Phase 6: Unique hero set pieces; adjacent variety by construction
- Phase 7: Capture cameras on contract IDs; noise floor; simulation untouched
- Phase 8: Stranger-point 30s loop, named places, way-home with minimap hidden
- Phase 9: Visual lift on the skeleton that already reads
