# Start Menu Art Direction — Loop F

Date: 2026-09-16  
Scope: `StartMenu.tscn` boot screen at the live 480 x 270 logical target  
Verdict: **ACCEPT — constrained original portrait treatment; HOLD — bespoke full-menu illustration**

## Audit

The live boot flow was reviewed in `scenes/ui/StartMenu.tscn` and
`src/ui/start_menu.gd`, including survivor selection, Solo/Host/Join launch
paths, keyboard focus, touch bounds, safe-area reflow, and the real
Mobile/Vulkan capture fixture. The pre-change capture was structurally sound
but its portraits read as isolated dark plates; the common amber selection
outline was doing almost all the identity and state work.

For vault triage, both immutable deep-audit ledgers were queried together for
`raster_image`, `vector_image`, and editable art whose role tag includes `ui`
or `character`, then narrowed by the menu/portrait/title/frame/card/button and
survivor/hero/avatar pathname families. This yields **6,739** role-relevant
visual records and **1,810** plausibly menu-adjacent records. It is a focused
manual-review slice of the already exhaustive ledger, not a claim that every
source automatically earned a visual approval.

| Candidate family | Provenance observed | Art-direction result | Decision |
|---|---|---|---|
| Spirit Claw / ClawAndBlade banners, buttons, character parts | Commercial project use and modification permitted by bundled licence | Painted fantasy wood/panel language conflicts with Bespren's restrained refuge instrumentation | Reject direct use |
| Admurin UI logo sheets and character frames | Bundled licence permits game use and modification | Small ornamental fantasy grammar; no survivor-specific or post-collapse identity | Reject direct use |
| Game Component Bundle `menu_launch`, `menu_deco`, `UI_button` | MIT | Cute Exponaut/farm launch art is a foreign game identity | Reject direct use |
| Godot Tower Defense `Assets/menu/bg.png` | MIT | Pixel-combat background has incompatible scale, palette, and genre | Reject direct use |
| SpriteCook sample characters | Commercial sample use allowed by bundled licence | Pixel animals/robots would mix a third visual language into the survivor choice | Reject direct use |
| PostApocalypse pixel character set | Commercial use requires separate payment under bundled terms | Not cleared for this commercial path and remains a pixel-scale mismatch | Reject |
| Aekashics / unlicensed-signal character vault families | No package-level clearance established by the deep ledger | Missing clearance is not permission, independent of visual fit | Hard no-go |

The connected Blender/Poly Haven pipeline remains valuable for offline world
sprites, but not for a raw UI drop-in: a new 3D render would add a separate
menu-composition, bake, provenance, alpha-bound, and device-budget task while
the two full-size cards conceal most background art at 480 x 270. No Blender
scene, Poly Haven source, raw Addons file, or runtime manifest entry was
changed in this loop.

## Analyze and plan

The smallest high-value correction is to make each existing approved survivor
portrait feel locally authored without changing the card hit boxes, the
selected-character contract, or the launch flow. The treatment needs to be
visible at target size but quieter than the selection frame and the launch
buttons.

Plan:

1. Draw original identity-specific signal arcs, a short route trace, and tiny
   corner brackets as vectors within each survivor card.
2. Place that layer above the portrait plate and below the actual portrait and
   all copy, so the portrait gains staging without obscuring the character,
   labels, or focus state.
3. Only the selected field receives the low-cost pulse. It cannot accept
   pointer/keyboard input and it does not decide selection, safe layout, or
   networking.
4. Re-run headless layout and the existing real GPU fixture in both survivor
   states and a synthetic landscape inset.

## Act

- Added `src/ui/start_menu_card_signal.gd`, an original `Control` drawing only
  procedural vector marks. Heikki uses restrained amber and Shane restrained
  cyan; it owns no asset reference or game state.
- Added one `SignalField` child per existing card in `StartMenu.tscn`, ordered
  after the portrait plate and before the portrait texture/text. Both fields
  use `MOUSE_FILTER_IGNORE` and full responsive card anchors.
- `StartMenu.select_character()` now relays the already-authoritative selected
  state to those presentation-only nodes.
- Extended the focused layout and render gates so a missing/inactive field or
  an input-capturing field fails rather than becoming decorative drift.

## Review

| Gate | Evidence | Result |
|---|---|---|
| Safe layout, 44 px touch, focus, selection reflow | `tests/start_menu_layout_validation.gd` | `START MENU LAYOUT OK (188 checks)` |
| Live scene, Heikki / Shane / safe-inset images | `tests/start_menu_render_validation.tscn` on Mobile/Vulkan | Passed, PID 30640; native 960 x 540, reviewed at 480 x 270 |
| Render metadata | `artifacts/start_menu_render_validation.json` | Records the original-vector treatment and all three states |
| Visual outputs | `artifacts/start_menu_heikki_validation.png`, `artifacts/start_menu_shane_validation.png`, `artifacts/start_menu_safe_inset_validation.png` | Portrait plates gain quiet identity framing while names, roles, active chip, 44 px launch controls, and selected-frame hierarchy stay clear |
| Source-vault isolation | Live menu scene/scripts | No raw `Addons/`, `_source_imports/`, Poly Haven model, or `Node3D` reference added |

The treatment is intentionally not a full menu re-skin. It is accepted because
it creates a clear, identity-specific visual layer at the exact shipping
resolution while preserving every existing interaction contract. A bespoke
key-art or animated-world menu remains **HOLD** until it has an original visual
brief, an offline derived-art provenance chain, alpha/readability evidence at
480 x 270, and representative Android thermal/cutout/touch review.
