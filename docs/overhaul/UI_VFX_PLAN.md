# UI & VFX Premium Upgrade Plan

Scope: raise the start menu ("alku menu"), `GameHUD`, `TacticalBuildDeck`, mobile input
chrome, and all gameplay VFX/feedback to "premium AAA++" presentation inside the exact
budgets `CLAUDE.md` already locks: 480x270 logical viewport, `canvas_items` stretch,
`mobile` renderer, HDR 2D off, **one** full-screen shader pass (already spent on
`shaders/weather_overlay.gdshader`), **zero** shadow-casting 2D lights, **zero** dynamic
shader loops, >=44x44 logical touch targets, and hue-redundant identity. This plan does
not touch code; it is the contract the next implementation slice executes against. Every
claim below was checked against the actual `.tscn`/`.gd` files and the two relevant
headless gates, not against prior prose.

## 0. Brief-vs-doc discrepancies (code wins)

- **The minimap is 96x72, not 72x54.** `CLAUDE.md` section 5, section 11, and
  `docs/ADDONS_DEEP_AUDIT.md` requirement 7 all say "72 x 54." The actual constant is
  `const MINIMAP_SIZE: Vector2 = Vector2(96.0, 72.0)` in `src/ui/game_hud.gd`, and
  `scenes/ui/game_hud.tscn`'s `TacticalMinimap` control has `offset_left=378, offset_top=6,
  offset_right=474, offset_bottom=78` -> 96x72 exactly. Two independent primary sources
  agree with each other and disagree with three doc references. This plan designs against
  **96x72**, the shipped size, and flags the doc text as stale rather than re-deriving a
  smaller minimap nobody asked for.
- **`JuiceRig` lives at `src/feedback/juice_rig.gd`, not `src/visual/juice_rig.gd`** as
  `CLAUDE.md` section 12's directory sketch implies. Section 5's tree doesn't list a
  `src/feedback/` folder at all. Code wins; this plan cites the real path throughout.
- **`assets/licenses/at_icons_mit.md` is already written, but nothing uses at-icons yet.**
  `grep -rn "at-icons|at_icons|AtIcons" src/ scenes/ project.godot` returns zero hits. The
  license record describes an intended pipeline ("recoloured to Bespren's locked semantic
  palette and imported as textures") that section 6 of this plan is the first document to
  actually specify. Treat the license file as a correct, ready obligation-fulfillment, not
  as evidence any icon is integrated.
- **`GameHUD.set_boss_gate()` and `show_warning()` are currently vestigial.** Reading
  `src/ui/game_hud.gd`, both methods unconditionally hide `BossMarqueePanel`/`WarningPanel`
  regardless of arguments passed. The scene still carries both panels and their StyleBoxFlat
  styling. Any VFX proposal for boss telegraphing or warning toasts is therefore proposing
  to *finish* an existing stub, not invent a new panel.
- **`game_hud.gd._resource_pickup_name()` labels resource kind 1 "ROCK," not "METAL."**
  Cosmetic, but if resource-pickup toast text is touched during this work it should be
  fixed alongside, not left inconsistent with the "METAL" chip label used everywhere else.
- **HDR 2D is not an explicit `project.godot` setting.** A case-insensitive grep for `hdr`
  across `project.godot` returns nothing. The project relies on Godot 4's engine default
  (HDR 2D off) rather than a hardened override. `CLAUDE.md` section 10's claim is correct
  in effect, just not enforced by an explicit key — worth a one-line project-settings
  addition so a future renderer-settings edit can't silently flip it on.

## 1. Honest audit: what a player sees today

### 1.1 Start menu (`scenes/ui/StartMenu.tscn`, `src/ui/start_menu.gd`)

A single `Control` scene: a flat dark-teal `ColorRect` background (`Color(0.018, 0.045,
0.04, 1)`), one decorative `Polygon2D` rust band, a 480x38 header `Panel` with two labels
("BESPREN // SIGNAL FOUND" at 17px amber, "SELECT SURVIVOR" at 9px), two 140x118 character
`Button` cards showing 94x86 portrait crops of `heikki_topdown.png`/`shane_topdown.png`, a
selection label, a 188x44 `LineEdit` defaulting to "127.0.0.1", three 84x44 mode buttons
(Solo/Host/Join), and a footer label. Selecting a card runs `_bounce_card()`: a single
TRANS_BACK/EASE_OUT scale tween, 0.94 -> 1.07 -> 1.0 over 0.14s + 0.18s.

What reads as programmer art: the background is one solid flat color with a single
decorative polygon and no depth, texture, or atmosphere behind the header/cards — nothing
here says "post-collapse refuge" the way `base_core.tscn` or the world map does. The two
character cards are plain `StyleBoxFlat` rectangles with a portrait pasted on; there is no
staged "signature" moment where Heikki's gold mass and Shane's cyan asymmetry get to compete
for the eye the way section 2 of `CLAUDE.md` demands. The mode row (Solo/Host/Join) and the
IP field are unstyled functional controls with no iconography, so a first-time player has to
read English words under time pressure to know Host means "you are the signal" and Join
means "you are finding one." The scale-bounce is the only tactile feedback event that exists
before the world loads. There is no transition treatment into `game_world.tscn` at all —
`_launch()` swaps `current_scene` and frees the menu in the same frame the new scene is
added, so the cut is instant and hard.

### 1.2 HUD (`scenes/ui/game_hud.tscn`, `src/ui/game_hud.gd`)

`CanvasLayer` at layer 100. Top-left is a 148x58 `CommandPanel` (offset 6,6 -> 154,64)
holding one horizontal row of three resource labels (`WoodValue`/`MetalValue`/`TechValue`,
text format `"WOOD 007"` etc.) above three 44x44 command buttons (`MakeBaseButton`,
`BuildButton`, `StartNightButton`) whose visible chrome is a small `Visual` sub-control
(area capped at 1200px² by the validation gate) plus an 8px `Label`. A separate 208x14
`WaveChip` sits below the reserved-controls line (`RESERVED_CONTROLS_TOP_Y = 164.0`). A
236x14 `StatusPanel`, a 196x28 `WarningPanel`, and a 216x34 `BossMarqueePanel` all exist but
start hidden and (per section 0) never actually show today. The interactive minimap is a
96x72 `TacticalMinimap` at top-right. `ResourcePickupLayer` spawns transient 88x16 pickup
toasts. `TacticalBuildDeck` is instanced as a child and opens as its own sheet.

What reads as programmer art: every panel is a flat `StyleBoxFlat` rectangle — solid fill,
uniform border, small corner radius — with no bevel, no directional light, no rust/patina
texture, nothing that reads as "salvaged tech HUD" rather than "default Godot panel with a
custom color." Resource counters are plain text with no glyph, so the player must read
"WOOD," "METAL," "TECH" as words instead of recognizing a silhouette the way `CLAUDE.md`
section 4 requires for colorblind-safe redundancy. Command buttons are text-only. The
minimap has "compact markers and 2D ping" per the docs but no frame ornamentation. There is
exactly one screen-space toast style (`GameHUD.show_status`) reused for everything, so
"systems nominal" and a future "under attack" would look identical apart from the string.

### 1.3 Build deck (`scenes/ui/tactical_build_deck.tscn`, `src/ui/tactical_build_deck.gd`)

A safe-area top sheet (`SHEET_MAX_SIZE = Vector2(448, 204)`), Towers/Traps/Utilities tabs,
`CARDS_PER_PAGE = 3`, 74x74 cards built at runtime from `StructureCatalog.get_all()`. Cards
already have a popup-intro tween (scale 0.94 -> 1.0 + fade, 0.18s/0.12s, TRANS_QUART/
EASE_OUT) and a 1.04x selection pop. Card art is each structure's own top-down Blender
sprite; styling is a `StyleBoxFlat` lightened/darkened from the structure's catalog accent
color. This is the most "already trying" surface in the game — the popup tween and
remembered-selection behavior are genuine polish — but the tab bar itself is plain text
buttons, there is no category glyph, and the three tab labels ("Towers," "Traps,"
"Utilities") carry the entire wayfinding load.

### 1.4 VFX and tactile feedback inventory

Every current effect is one of four techniques, and **zero `GPUParticles2D` or
`CPUParticles2D` nodes exist anywhere in `src/` or `scenes/`** (repo-wide grep, confirmed
twice). `AnimatedSprite2D` flipbooks are used in exactly one place today.

| Effect | Current technique | File |
|---|---|---|
| Character-select feedback | Scale tween (TRANS_BACK) | `src/ui/start_menu.gd` |
| Generic "pop" | Scale 1.15x/0.25s tween | `src/feedback/juice_rig.gd` |
| Generic "hit flash" | `ShaderMaterial` swap, `mix_weight` tween | `shaders/solid_white_flash.gdshader` |
| Base Core command punch | Scale 1.15x, 0.08s up/0.14s down | `src/visual/core_pulse_driver.gd` |
| Base Core aura | Additive radial shader + noise "vapor" | `shaders/volumetric_aura.gdshader` |
| Base Core rim glow | Vertex-stage pulse scale + additive glow | `shaders/base_scale_glow.gdshader` |
| Day/night transition | `CanvasModulate` tween, 3.0s, white -> `#91A3BD` | `src/visual/night_atmosphere_2d.gd` |
| Resource outline/emission | 4-sample outline + pulsing emission | `shaders/toon_emissive_outline.gdshader` |
| Structure surface finish | Outline + grading + sheen | `shaders/sleek_sprite_finish.gdshader` |
| Harvest progress | Scale/alpha/glow lerp + `_draw()` ring | `src/visual/resource_node_view.gd` |
| Tower/trap fire & trigger (all 6) | Per-`attack_kind` `_draw()` primitives, fixed 0.18s window | `src/tactical/placed_structure_2d.gd` |
| Placement ghost | `_draw()` box + range circle, no structure silhouette | `src/tactical/grid_placement_controller_2d.gd` |
| Enemy status rings (slow/root) | `_draw()` arc gauge + X mark | `src/visual/enemy_presentation_2d.gd` |
| Enemy body | `AnimatedSprite2D` flipbook ("WeatheredSprite") + `_draw()` marker language | `src/visual/enemy_presentation_2d.gd` |
| Impact decals | `MultiMeshInstance2D` GPU-batched stamps, `MAX_DECALS = 160` | `src/visual/blood_canvas.gd` |
| Projectile tracer/head | `Sprite2D` x2, `blend_add` pulsing shader | `shaders/projectile_glow.gdshader`, `scenes/combat/player_projectile.tscn` |
| Muzzle flash | **Does not exist** | — |
| Weather (rain/ash/vignette) | Single full-screen `CanvasItem` shader, `hash21` noise | `shaders/weather_overlay.gdshader` |
| Joystick/action buttons | 100% `_draw()` primitives + `draw_string` | `src/input/mobile_controls.gd` |

Two genuinely good, budget-correct precedents are already in the codebase and this plan
leans on both rather than replacing them: `night_atmosphere_2d.gd`'s use of `CanvasModulate`
for day/night (a node property, not a shader pass — it does not touch the 1-shader-pass
budget), and `enemy_presentation_2d.gd`'s layered "baked flipbook body + `_draw()` status
ring" pattern, which is exactly the shape this plan proposes reusing for tower/structure
status presentation.

**Confirmed gap:** `game_world.gd:_on_projectile_fired(peer_id, position, direction)`
(around line 313) is the single host-approved point where `projectiles_root.checkout(...)`
is called. There is no muzzle-flash spawn call there, and `player_projectile.tscn` has no
flash node. This is a real, cheap-to-close gap, not a hidden feature.

**Confirmed gap:** `grid_placement_controller_2d.gd._draw()` never draws the armed
structure's own texture — only a flat colored 64x64 box, crosshair, and (for towers) a range
ring. A player arming "Electric Tower" and "Landmine" sees the identical ghost box.

### 1.5 Mobile input chrome (`src/input/mobile_controls.gd`)

The entire joystick (`JOYSTICK_RADIUS = 38.0`) and both 44x44 action targets ("USE" teal,
"FIRE" orange-red) are drawn from scratch every frame with `draw_circle`/`draw_arc`/
`draw_string(ThemeDB.fallback_font, ...)`. There is no art asset backing on-screen controls
at all — this is the single largest "this looks like an engine tutorial, not a shipped game"
surface in the app, precisely because it is the one surface every player's thumbs touch
every second of play. `mobile_controls.gd` also reimplements the exact same safe-area-to-
logical-coordinate conversion that `game_hud.gd._get_logical_safe_insets()` already has,
independently — a maintenance risk (the two can drift) worth flagging even though fixing it
is a refactor, not a visual change, and therefore out of this plan's scope.

## 2. Start-menu redesign

Layout stays a single `Control` scene configuring `game_world.tscn` before it enters the
tree — that contract (`start_menu.gd:_launch()`) is not touched.

**Background.** Replace the flat `ColorRect` with a layered treatment built from pieces the
project already has rights to: the `surface_weathering.gdshader` Rust/Decayed-Wood mode
(already mobile-proven, zero new shader budget since it's a second *material*, not a second
*full-screen pass* — CanvasItem shaders on ordinary background nodes do not count against
the one full-screen-pass budget, only overlays that intercept the whole viewport do) on a
large background rect, plus one static parallax layer using an existing environment sprite
(e.g. a de-emphasized, heavily-darkened crop from the local/Poly Haven atlases) so the menu
reads as "looking at the refuge from outside" rather than a solid color. Keep the existing
`RustBand` `Polygon2D` as a foreground accent — it is cheap and on-brand, just currently
lonely.

**Character-select moment.** This is where "two players, two signatures" (`CLAUDE.md`
section 2) has to land hardest, and today it is two identically-styled buttons with a
portrait pasted in. Concretely:
- Give each card its own `StyleBoxFlat` accent border using the locked identity colors —
  Heikki gold `#FFD45A` border/corner accent on `HeikkiCard`, Shane cyan `#31E6E6` on
  `ShaneCard` — so hue-coded identity starts at first contact, not after spawn.
  Silhouette/iconography still has to carry the rest per the accessibility contract (see
  section 6): pair each card with a small structural glyph, not color alone (e.g. a broad
  horizontal accent bar under Heikki's card versus a narrow diagonal one under Shane's,
  echoing "broad stable silhouette" vs. "narrow asymmetric silhouette" from section 2).
- Upgrade `_bounce_card()`'s single scale tween into a short two-stage confirm: keep the
  existing 0.94 -> 1.07 -> 1.0 TRANS_BACK punch (it is already good, do not replace it),
  and layer a `JuiceRig.flash_white()` call on the *unselected* card fading to a dimmed
  state instead of only animating the selected one — this makes selection a relative event
  (one card wakes up, one goes quiet) instead of an isolated pop.
- Add the character's identity-color `PointLight2D` glow behind the selected card at low
  energy (reuse the existing non-shadow-casting `PointLight2D` idiom already used on
  characters/structures — zero new technique).

**Typography.** Section 6 covers font sourcing/licensing; functionally, the title and mode
buttons should move off `ThemeDB.fallback_font` onto one deliberately chosen face once one
is cleared, applied via a `Theme` resource so `GameHUD`/`TacticalBuildDeck`/`StartMenu`
share it (today there is no project `Theme` resource at all — confirmed, no `.tres` theme
file exists outside `Addons/`).

**Mode row (Solo/Host/Join) and address field.** Add a leading icon per button from
at-icons (mapping in section 6: `play.svg` / `satellite.svg` / `link.svg`) so the choice is
legible before the label is read, and a small `link.svg` glyph inside the `AddressEdit`
`LineEdit` to mark it as a network field. No layout/size change — all three buttons stay
84x44, `AddressEdit` stays 188x44 — this is chrome added inside existing rects, not a
geometry change, so it does not touch any validation gate.

**Transition into `game_world.tscn`.** `_launch()` currently swaps scenes in the same
frame. Insert a short (under ~0.35s) full-black or full-charcoal (`#060909`, the locked Void
charcoal role) `ColorRect` fade using a `CanvasLayer` on top of the menu, tweened to alpha 1
before `get_tree().root.add_child(game_world)` runs and back to 0 after — a `Tween`, not a
shader, so it costs nothing against the shader budget and cannot desync from the existing
scene-swap logic since it wraps the existing call rather than replacing it.

## 3. HUD and build-deck upgrade within validated geometry

The two gates that can break silently are `tests/tactical_hud_validation.gd` (48 checks) and
`tests/mobile_systems_validation.gd` (56 checks). Reading both in full, the assertions that
constrain *visual* changes are narrower than "48+56 things can break" suggests — most checks
are host-authority/networking behavior this plan never touches. The geometry/visual
assertions that matter are:

| Assertion (file:approx line) | What it locks | Room for this plan |
|---|---|---|
| `panel_rect.size.is_equal_approx(Vector2(148.0, 58.0))` (`mobile_systems_validation.gd` ~191) | `CommandPanel` outer size is exactly 148x58 | Panel outer rect is frozen. All visual upgrade must happen *inside* 148x58 (border art, corner treatment, background texture/StyleBoxFlat layering) |
| `panel_area <= GameHUD.LEGACY_TOP_LEFT_AREA * 0.5` (same block) | Panel area <= 8,736px² (148x58=8,584 already satisfies this with ~152px² of slack) | The stricter exact-size check above binds first; this one is already satisfied and stays satisfied as long as size doesn't change |
| `visual.size.x * visual.size.y > 1200.0` fails "chrome is compact" (~ line 178) | Each command button's `Visual` child (the decorative sub-control inside the 44x44 touch button) must stay <=1200px² | An icon added to `Visual` must be sized so `Visual` itself stays under 1200px² — e.g. a 34x34 icon container (1,156px²) fits; the outer `Button` can and must stay >=44x44 |
| `visible_label.get_theme_font_size(&font_size) < 8` fails readability (~ line 180) | `Visual/Label` font size floor is 8px | Any font swap must keep >=8px on this label |
| Button/label node names and exact text ("Make Base"/"Build"/"Start Night") (~ line 160-176) | `MakeBaseButton`/`BuildButton`/`StartNightButton` and their text are asserted verbatim | Icons must be *added* alongside the existing `Label`, never replace or rename it |
| Resource label names/text (`WoodValue`="WOOD 007" etc.) (~ line 104-125) | Exact node names and exact zero-padded text format | Same rule: an icon is an additional sibling node, the text node and its format are frozen |
| `resources_are_horizontal_and_readable` (~ line 128-140) | Labels stay left-to-right, same Y, >=8px font | Any icon insertion must not reorder or vertically offset the three labels |
| `buttons_do_not_overlap` (~ line 184) | Pairwise non-intersecting button rects | No visual addition may grow a button's actual `Rect2` into a neighbor |
| `wave_rect.end.y <= GameHUD.RESERVED_CONTROLS_TOP_Y` (164.0) and `not wave_rect.intersects(panel_rect)` (~ line 200-206) | Wave chip geometry vs. panel and the 164.0 reserved line | Wave-chip restyling must keep its calculated rect inside this line |
| `notch_safe_rect.encloses(calculated_panel/wave/status)` against a synthetic `Rect2((18,10),(16,8))` inset (~ line 208-250) | The *pure functions* `GameHUD.calculate_panel_rect/calculate_minimap_rect/calculate_wave_chip_rect/calculate_status_rect` must keep all HUD geometry inside a synthetic notch safe area | These are unit tests on static functions, independent of the live scene — if any `calculate_*_rect` function's math changes, this is what re-verifies it; today's constants pass, so *no geometry change is proposed here* |
| Command signal emission order (make_base, build, start_night) (~ line 253-260) | Pressing buttons 0/1/2 in order emits commands in that exact order | Not a visual concern; unaffected by any styling change |
| `tactical_hud_validation.gd`: "Build deck contains all eight Tier-1 definitions and cards," "Tower/Trap/Utility tabs retain 44px touch targets," "Deck close control remains touch-safe" | Card count, tab touch size, close-button touch size | Card/tab *chrome* (background art, icon) can change freely; the 44px touch rects and 8-card/3-tab structure cannot |

**Conclusion for this plan: zero geometry changes are proposed.** Every HUD/build-deck
upgrade below is either (a) a new `StyleBoxFlat`/texture drawn inside an already-locked
rect, (b) a new sibling node (icon) added next to an already-asserted node without touching
its name/text, or (c) restyling within an already-passing touch-size floor. Nothing here
requires editing a `_check()` call in either gate. If a future slice *does* want to grow the
panel, the exact line to edit is `mobile_systems_validation.gd`'s
`panel_rect.size.is_equal_approx(Vector2(148.0, 58.0))` assertion plus the matching
`calculate_panel_rect` unit test — but that is explicitly not part of this plan.

**Concrete HUD upgrades, all inside frozen rects:**
- Replace each flat `StyleBoxFlat` panel with a two-layer version: a darker base fill plus a
  1px lighter top-edge-only border (simulated bevel via two stacked `StyleBoxFlat`s or a
  `StyleBoxFlat` with asymmetric `border_width_*`), giving "salvaged plating" read without a
  texture or shader.
  the corners.
- Add a resource glyph (`tree.svg`/`nut_and_bolt.svg`/`cpu.svg`, section 6) as a small
  `TextureRect` sibling to each of `WoodValue`/`MetalValue`/`TechValue`, left of the text,
  sized to keep the row's total width inside the existing 148px panel width and preserve the
  horizontal/same-Y assertion.
- Add a command glyph (`house.svg`/`hammer.svg`/`moon.svg`) inside each button's `Visual`
  sub-control, budgeted at <=1200px² per the table above.
- Give the wave chip a `skull.svg` glyph and restyle its `StyleBoxFlat` to match the new
  panel bevel language.
- Finish the vestigial `WarningPanel`/`BossMarqueePanel` presentation (section 5) now that
  `set_boss_gate()`/`show_warning()` have real callers in mind — this is completing existing
  scene geometry, not adding new rects.
- Give `TacticalMinimap` a matching bevel frame and a `location.svg`-based ping marker
  instead of an undocumented "compact marker."

**Build deck:** add a category icon (`tower.svg`/`razor_blade.svg`/`wrench.svg`, section 6)
to each of the three tabs; add a small damage-type corner badge per card (kinetic
`bullseye.svg`, chemical `beaker.svg`, electric `lightning_bolt.svg`, landmine
`explosion.svg`, slowing pit `magnet.svg`, razor snare `razor_blade.svg` again, barricade
`brick_wall.svg`, support — tentatively `signal.svg`, pending a read of `support`'s exact
effect text in `structure_definition.gd` before lock, flagged here rather than guessed past
that). None of this changes the 74x74 card size, the 3-per-page pagination, or the tab
touch targets.

## 4. VFX plan by effect

Every entry states the exact technique and why it fits budget. "Existing" means extend a
technique already in the file named; "New, no shader" means a node/tween/particle
technique that does not touch the 1-shader-pass budget; nothing here proposes a second
full-screen pass, and anything that could tempt one is explicitly rejected below.

| Effect | Technique | Budget note |
|---|---|---|
| Muzzle flash | **New.** A pooled 2-3 frame `AnimatedSprite2D` or a single `Sprite2D` with a 0.05-0.08s scale+alpha tween, spawned at `game_world.gd:_on_projectile_fired()` alongside the existing `projectiles_root.checkout()` call, parented to the firing player so it inherits position/rotation for one frame then frees. Reuses `blend_add` the same way `projectile_glow.gdshader` already does. | CanvasItem sprite + tween, zero shader budget, zero particle budget |
| Projectile tracer/head | **Existing**, keep as-is | Already correct |
| Impact (wall/enemy hit) | **Existing pattern extended.** `blood_canvas.gd`'s `MultiMeshInstance2D` stamp technique is the right tool and already proven — add a second, small, additive "spark" `MultiMesh` pool for non-organic (WorldStatic) impacts, reusing one of the license-clearable spark frames in section 6 if cleared, otherwise 3-4 `draw_line` streaks matching the existing `_draw()` idiom | GPU-batched decals, no per-hit node churn, matches existing `MAX_DECALS`-style bound |
| Harvest progress | **Existing, extend.** Keep the scale/alpha/glow lerp and the `_draw()` ring in `resource_node_view.gd`; add a brief `JuiceRig.pop()` call on each accepted interaction step (not just on completion) so partial progress reads as tactile, not just visual | Reuses `JuiceRig`, zero new technique |
| Structure placement confirm | **Existing, extend.** `TacticalBuildSystem`'s commit already exists; add `JuiceRig.pop()` + `flash_white()` on the placed `PlacedStructure2D` the frame the host approves it | Reuses `JuiceRig` |
| Placement ghost | **New, no shader.** Give `grid_placement_controller_2d.gd._draw()` an actual semi-transparent copy of the armed structure's texture (already loaded by `StructureCatalog`) instead of a flat box — `draw_texture_rect` at ~50% alpha, tinted red/green by `TacticalBuildSystem`'s existing overlap-validity check if that signal is exposed to the controller | One extra `draw_texture_rect` call, zero new asset cost — texture is already resident |
| Tower fire (Kinetic/Chemical/Electric) | **Existing, extend.** Keep the exact `attack_kind`-keyed `_draw()` language in `placed_structure_2d.gd` (it is already distinct per tower and inside a tight 0.18s window — a real strength, not a gap); layer one small `PointLight2D` flash (energy tween 1 -> 0 over the same 0.18s window, non-shadow-casting) at the tower muzzle for Kinetic/Electric only, since Chemical's burst circle already self-illuminates via its fill alpha | One pooled/reused `PointLight2D` per tower, not per shot — stays inside "0 shadow-casting lights," well under any dynamic-light-count concern since it is 3 structures max on screen at once by design |
| Trap trigger (Landmine/Slowing Pit/Razor Snare) | **Existing, extend.** Same `_draw()` language; add a `JuiceRig`-style camera-independent screen shake substitute is explicitly rejected (see section 6's accessibility note — camera shake needs an intensity control before it ships at all) — instead add a brief radial `blend_add` sprite (a single pre-baked soft circle texture, modulated to the trap's accent color, scaled 0 -> 1 -> fade over the existing `ATTACK_TRACE_SECONDS = 0.18`) layered under the existing `_draw()` shapes for Landmine specifically, since a mine blast is the one trap event that reads as "explosion" | One `Sprite2D` + tween using an already-generatable radial texture (or the license-pending `glow_orb.png`, section 6); no shader |
| Tower/structure status (buffed/disabled) | **New, reuse existing idiom.** Copy `enemy_presentation_2d.gd`'s slow/root arc-gauge pattern (`_draw_movement_status`) onto `PlacedStructure2D` for a future "disabled" or "overcharged" state — same technique, new call site | Zero new technique, proven idiom |
| Day/night transition | **Existing, do not touch.** `CanvasModulate` tween in `night_atmosphere_2d.gd` already avoids the shader budget entirely; explicitly preserve this rather than "upgrading" it into a shader | Confirms budget headroom stays where it is |
| Damage feedback (player hit) | **New, no shader.** `JuiceRig.flash_white()` already exists and is unused on the player character today (confirmed: only structures/resources call it) — wire it to player damage, plus a short directional red vignette **is rejected** because it would require a second full-screen pass; use a local red-tinted `PointLight2D` pulse at the player position instead (non-shadow-casting, same idiom as everywhere else) | Reuses `JuiceRig`; explicitly rejects the tempting full-screen option |
| Weather intensity change | **Existing, do not touch technique.** Already one overlay, uniform-driven (`intensity`, `wind`, `storm_tint`) — any weather state change must stay a uniform swap on the existing material, never a second material/pass | Confirms the one-pass budget is respected going forward, not just today |

## 5. Accessibility controls (`CLAUDE.md` section 11 requirement)

Section 11 requires weather intensity, camera shake, and emissive pulse amplitude controls
"before content production locks them in." None exist today — there is no settings surface
of any kind in the current scene tree (`StartMenu` has no settings affordance;
`GameHUD` has no settings affordance). Concretely:

- **Where they live:** a new lightweight settings sheet reachable from `StartMenu`'s footer
  (a small `cog.svg`-iconed button, 44x44, added to the existing footer row — new node, no
  existing geometry disturbed) rather than from inside `GameHUD`, since these are pre-session
  preferences, not in-combat controls. Persisting them is out of scope for this plan (no
  save system exists yet in the reviewed code) — ship them as an in-memory `Resource`
  (e.g. `AccessibilitySettings`) that `GameWorld.configure_launch()` receives alongside the
  existing mode/character/address parameters, mirroring how those three are already threaded
  through.
- **Weather intensity:** a 0-1 slider mapped directly onto `weather_overlay.gdshader`'s
  existing `intensity` uniform (already a [0,1] ranged param, default 0.62) — no shader
  change required, purely a runtime uniform write.
- **Camera shake:** no camera-shake system exists in the reviewed code at all (confirmed —
  `JuiceRig` is explicitly documented as "no-shake" tactile feedback). This control should
  therefore ship as a 0-1 amplitude multiplier *now*, before any shake effect is added later,
  so the first shake implementation is required to read this value rather than retrofitting
  it. Section 4's rejected "screen shake on trap trigger" idea is exactly the kind of effect
  this multiplier must gate.
- **Emissive pulse amplitude:** a 0-1 multiplier applied to the existing pulse drivers —
  `core_pulse_driver.gd`'s `COMMAND_PUNCH_SCALE`, `toon_emissive_outline.gdshader`'s
  emission pulse, and `base_scale_glow.gdshader`'s vertex pulse all already expose the
  numeric inputs this multiplier would scale; no shader rewrite, just threading one more
  float into three already-parameterized places.

## 6. Icon and asset sourcing

### 6.1 `Addons/at-icons/` survey (the required exploit)

Confirmed structure: four style folders — `control/` (fill `#8eef97` mint), `node/` (fill
`#e0e0e0` — **this is Metal signal `#E0E0E0` exactly, no recolor needed for that one icon**),
`node2d/` (fill `#8da5f3`), `node3d/` (fill `#fc7f7f`) — each holding the *same* 512
filenames (`diff`-confirmed identical across all four). Every icon is a single flat-fill
16x16 `<path>` SVG (confirmed by opening `axe.svg`/`cog.svg` directly). MIT, Copyright (c)
2026-present Valentin Fossati (Voxybuns); notice already on file at
`assets/licenses/at_icons_mit.md`.

**Recoloring approach:** because every icon is one flat `fill="#......"` attribute, the
correct pipeline is a one-time text edit, not a shader or runtime modulate:
- For the three resource-anchor icons (Wood/Metal/Tech), directly edit the copied SVG's
  `fill` to the *exact* locked hex (`#FFD700`/`#E0E0E0`/`#00FFFF`) — `CLAUDE.md` section 4
  requires future UI to reuse these anchors exactly, so a modulate-multiply approximation
  is not acceptable here.
- For everything else, copy from the `node/` (`#E0E0E0`, near-white) variant and apply a
  Godot `modulate`/`self_modulate` tint per instance — one neutral source file, N palette-
  correct instances, no duplicated SVGs to maintain.
- Either way, import exactly like the existing Wood/Metal/Tech SVG icons already in
  `assets/2d/resources/` — same established pattern, not a new import convention.
- New destination folder: `assets/2d/ui/icons/` (confirmed: `assets/2d/` currently has
  `_source_imports/, bosses/, catalog/, characters/, effects/, enemies/, environment/,
  materials/, props/, resources/, structures/` and **no `ui/` folder yet** — this is a
  clean, net-new addition, not a conflict).

Every filename below was found via direct `grep`/`find` against the real 512-name list — no
filename here is invented:

| UI slot | File (relative to `Addons/at-icons/<style>/`) | Recolor target |
|---|---|---|
| Wood resource chip | `tree.svg` (or `tree_evergreen.svg`) | `#FFD700` exact |
| Metal resource chip | `nut_and_bolt.svg` | `#E0E0E0` exact (already baked in `node/`) |
| Tech resource chip | `cpu.svg` | `#00FFFF` exact |
| Make Base button | `house.svg` | modulate, on-palette |
| Build button | `hammer.svg` | modulate |
| Start Night button | `moon.svg` | modulate |
| Wave chip | `skull.svg` (boss variant: `skull_and_crossbones.svg`) | modulate |
| Minimap ping | `location.svg` (alt: `pin.svg`) | modulate |
| Build-deck tab: Towers | `tower.svg` | modulate |
| Build-deck tab: Traps | `razor_blade.svg` | modulate |
| Build-deck tab: Utilities | `wrench.svg` (alt: `cog.svg`) | modulate |
| Card badge: Kinetic tower | `bullseye.svg` (alt: `target.svg`) | modulate |
| Card badge: Chemical tower | `beaker.svg` (alt: `droplet.svg`) | modulate |
| Card badge: Electric tower | `lightning_bolt.svg` (alt: `lightning_in_circle.svg`) | modulate |
| Card badge: Landmine | `explosion.svg` | modulate |
| Card badge: Slowing Pit | `magnet.svg` | modulate |
| Card badge: Razor Snare | `razor_blade.svg` | modulate |
| Card badge: Barricade | `brick_wall.svg` | modulate |
| Card badge: Support | `signal.svg` — **tentative**, confirm against `support`'s actual effect in `structure_definition.gd` before lock | modulate |
| Start menu: Solo | `play.svg` | modulate |
| Start menu: Host | `satellite.svg` | modulate |
| Start menu: Join | `link.svg` | modulate |
| Address field leading glyph | `link.svg` | modulate |
| Build-deck/menu close control | `cross.svg` (alt: `cross_in_square.svg`) | modulate |
| Settings entry point | `cog.svg` | modulate |
| Accessibility: weather row | `cloud.svg` | modulate |
| Accessibility: shake/pulse rows | `sliders.svg` (generic — no dedicated "shake" glyph exists in the set; verified absent) | modulate |

Icons **not found** and not to be invented: no bare `wood.svg`, no `metal.svg`, no
`flag.svg`, no plain `shake`/`camera_shake` glyph, no "two people/co-op" glyph. Where a
slot's ideal concept doesn't exist, the table above already substitutes the closest real
concept rather than pretending the ideal one exists.

### 6.2 Broader `Addons/` survey

- **9-slice/panel textures: none found.** A repo-wide filename search for panel/9-slice/
  9-patch PNGs across all of `Addons/` returned zero results. This is not a gap to fill with
  an import — it means the `StyleBoxFlat`-only approach already used in `StartMenu.tscn`/
  `game_hud.tscn` is the *correct*, and only available, technique, and is genuinely cheaper
  on mobile than a texture (no texture memory, no import step, resolution-independent).
  Section 3's "two-layer bevel `StyleBoxFlat`" recommendation follows directly from this.
- **Fonts: real candidates exist, none license-cleared yet.** No font is referenced anywhere
  in `project.godot` or any `.tres` today — the project currently renders 100% of its text in
  Godot's built-in fallback font. Candidates found on disk:
  - `Addons/Game-Component-Bundle-.../Exponaut Components/Other/Fonts/IMPACT.TTF` —
    **license-clear**: the bundle root ships `license.txt`, MIT, Copyright (c) 2026 Paweł
    Gajewski (Pawlogates), read in full. Usable today under the same
    copy-the-notice-into-`assets/licenses/` pattern as at-icons. Stylistically generic bold
    poster sans; weaker aesthetic fit than a dedicated mono/pixel face, but the only
    zero-friction option.
  - `Addons/25.07 - Free Mana Seed RPG Starter Pack/fonts/ManaSeedBody.ttf` and
    `ManaSeedTitle.ttf` — no license file found at the package root during this survey;
    needs its own check before use.
  - `Addons/godot-jrpg-.../addons/godot_jrpg/assets/fonts/BigBlueTerm437NerdFont*.ttf` (6
    variants: Regular/Mono/Propo x plain/Plus) — terminal/mono face, thematically close to
    "Base Core signal" readouts; license not found in this survey, needs checking.
  - `Addons/Starter-Kit-City-Builder-main/fonts/lilita_one_regular.ttf` — publicly known as
    a Google Fonts OFL family, but that provenance was not independently re-verified inside
    this repo copy; treat as "likely fine, confirm before shipping," not confirmed.
  - `Addons/TopdownStarter-.../Art/Fonts/m3x6.ttf` — small pixel bitmap face, would suit the
    480x270 native-res target well; license not found in this survey, needs checking.
  Recommendation: verify `IMPACT.TTF`'s fit first since it is already clear, but its bold-
  poster style should be tested against Bespren's tone before committing; if it reads wrong,
  prioritize clearing `m3x6.ttf` or the BigBlueTerm family next since both are closer to a
  "salvaged terminal" read than a display poster face.
- **Particle/glow/gradient textures: mixed provenance.**
  - `Addons/Game-Component-Bundle-.../Exponaut Components/Assets/Graphics/other/glow_orb.png`,
    `glow_orb_strong.png`, `fg_gradient.png`, `fog_gradient_colorful.png` — **license-clear**,
    same MIT bundle as `IMPACT.TTF` above. These are ready candidates for the muzzle-flash
    and mine-blast radial sprites proposed in section 4.
  - `Addons/spritesheets/fx/` (`fx_bigfirehitspark.png`, `fx_collisionsparkgreen/purple/
    red.png`, `fx_explosionorangesmoke.png`, `fx_explosionpurplesmoke.png`,
    `fx_f1_bbs_afterglow.png`, `fx_radial_bluenoise.png`(+`@2x`), `fx_smoke.png`,
    `fx_smoke2.png`) — genuinely the richest impact/explosion frame set found, but **no
    license or readme file exists anywhere near this folder**. Provenance unknown. Do not
    promote to `assets/2d/` until sourced; if it cannot be sourced, do not use it.
  - `Addons/mystic_woods_free_2.2/sprites/particles/dust_particles_01.png` — no license
    found at shallow depth in this survey; needs a deeper check (Mystic Woods is a
    known-name itch.io asset with its own terms, likely findable, just not found in this
    pass).
  - `Addons/godot-2d-topdown-template-main/.../particles/smoke.png` — bundled with a
    template project; license not checked in this pass.

## 7. Ordered work plan

| # | Step | Effort | Validation |
|---:|---|---|---|
| 1 | Clear/record licenses for the two already-identified MIT sources (`IMPACT.TTF`, `glow_orb*`/`fg_gradient*`/`fog_gradient_colorful.png`) into `assets/licenses/`, following the exact `at_icons_mit.md` precedent | Small | Manual review only; no test depends on license files |
| 2 | Promote and recolor the at-icons table (section 6.1) into `assets/2d/ui/icons/`: direct-hex-edit the 3 resource anchors, copy the `node/` neutral for everything else | Small-Medium (mechanical, ~26 files) | `tests/smoke_test.gd` provenance checks (extend if it asserts curated-asset sourcing the way it does for other `assets/2d/` families) |
| 3 | Add resource/command/wave/minimap icons as new sibling nodes in `game_hud.tscn` + `game_hud.gd`, respecting every frozen rect/name/text in section 3's table | Medium | Full re-run of `tests/mobile_systems_validation.gd` (56) and `tests/tactical_hud_validation.gd` (48) — expect **no assertion edits**, only a pass/fail confirmation |
| 4 | Add build-deck tab/card icons in `tactical_build_deck.tscn` + `.gd` | Medium | Same two gates, plus visual spot-check via a fresh `tests/world_render_validation.tscn`-style Mobile/Vulkan capture of the deck if one is warranted |
| 5 | Two-layer `StyleBoxFlat` bevel pass across `CommandPanel`, `WaveChip`, `TacticalMinimap`, build-deck cards/tabs | Medium | Same two gates (pure restyle, no geometry) |
| 6 | Start-menu redesign: background treatment, card identity accents, mode-row/address icons, scene-transition fade | Medium-Large | `tests/mobile_systems_validation.gd`'s start-menu block (defaults-to-Heikki, bounce-active, card touch size) must keep passing; add a manual desktop run since no headless gate currently screenshots the menu |
| 7 | Wire `IMPACT.TTF` (or its cleared successor) into a new project `Theme` resource, apply across `StartMenu`/`GameHUD`/`TacticalBuildDeck` | Medium | Re-run both HUD gates for the 8px-floor label-size assertions specifically |
| 8 | Muzzle flash at `game_world.gd:_on_projectile_fired()` | Small | Manual desktop play test; no existing gate covers projectile presentation beyond lifecycle |
| 9 | Placement-ghost real-texture preview in `grid_placement_controller_2d.gd` | Small | Manual; `TacticalBuildSystem`'s own placement gates are unaffected (server-authoritative logic untouched) |
| 10 | Trap/tower `PointLight2D` flash + mine-blast radial sprite | Medium | `tests/tower_combat` -style gate (69 checks, per `CLAUDE.md` section 12) should be re-run since it inspects attack presentation, though the light/sprite addition is additive to, not a replacement of, the asserted `_draw()` behavior |
| 11 | Accessibility settings sheet (weather/shake/pulse) + `AccessibilitySettings` resource threaded through `configure_launch()` | Medium-Large | New coverage needed — none of the existing gates test a settings surface that doesn't exist yet; this step should add its own focused headless check rather than relying on an existing one |
| 12 | Finish `WarningPanel`/`BossMarqueePanel` real presentation now that boss/warning states exist to drive them | Medium | `tests/tactical_hud_validation.gd` likely has stub coverage for the hidden state today; extend it for the shown state as part of this step |
| 13 | Fresh Mobile/Vulkan contact sheet covering the redesigned menu, HUD, and build deck at 480x270, alongside the already-open camp/district refresh from `CLAUDE.md` section 12 | Medium | GPU capture, desktop-only proof per section 12's existing evidence boundary |

Steps 1-5 are the highest ratio of visible improvement to risk (icons and bevels inside
already-frozen geometry, zero contested assertions) and should land first. Step 6 (start
menu) is the highest-visibility single change and should follow immediately since it is the
literal first thing every player sees. Steps 8-10 (VFX) are independent of the UI work and
can run in parallel with it. Step 11 (accessibility) is a `CLAUDE.md` section 11 hard
requirement ("before content production locks them in") and should not be deferred past this
milestone even though it has the least code to reuse.
