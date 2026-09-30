# Tactical HUD, Day Clock, and Tier-1 Construction

This slice adds the mobile tactical layer to the existing 2D LAN runtime. It is composed under `GameWorld`; no new autoload is required.

## Runtime composition

- `GameHUD` remains a `CanvasLayer` fixed at layer `100`. Its safe-area-aware top-left dashboard is `148 x 58`, or `49.13%` of the former `208 x 84` union area. Wood/Metal/Tech remain readable and `Make Base`, `Build`, and `Start Night` preserve their original order with independent `44 x 44` hit targets, while their compact `40 x 18` chrome uses the labels `BASE`, `BUILD`, and `NIGHT`.
- Day, modifier, and clock state live in a separate safe-area wave chip instead of enlarging the dashboard. Generic status, nightfall warnings, and boss gates never render as center-screen gameplay text. A completed local harvest instead creates only a short world-space `+ x WOOD`, `+ x ROCK`, or `+ x TECH` pickup label; boss pacing stays in the wave chip and warnings retain their alert sound.
- `TacticalMinimap` maps the `28,672 x 28,672` world rect into a `96 x 72` top-right control. Its 14x14 fog grid permanently reveals sectors visited by any replicated player, then shows active Wood/Rock/Tech node markers only in revealed sectors. A tap creates an animated 2D tactical ping only inside explored territory and briefly pans the local `Camera2D`; it never performs a 3D raycast.
- `DayNightCycle` advances only on peer one. It reliably commits warnings at `60`, `45`, `30`, `15`, `10`, and `5` seconds and starts night automatically at zero. `Start Night` is a client request validated by the host. Day uses a `0.35` spawn multiplier (`-65%`); night uses `1.35` (`+35%`).
- `TacticalBuildDeck` derives its cards from `StructureCatalog` without a fixed card-count assumption. The current eight cards form `Towers` (`3`), `Traps` (`3`), and `Utilities` (`2`) groups. Its centered floating popup shows at most three cards per category page, then the selected structure information directly below the cards, with local thumbnails, live Wood/Metal/Tech chips, compact mechanics, and 44px tab/pager/close/place targets. Category, page, and per-category selection are remembered across closes. Gameplay controls are reset and hidden while the popup is open, preventing UI/world-action touch conflicts.
- `GridPlacementController2D` projects mouse input with `get_global_mouse_position()` and touch input with the inverse 2D canvas transform. Both axes snap through `snappedf(value, 64.0)`; no `Node3D`, ray origin, or camera unprojection is involved.
- `TacticalBuildSystem` validates registered peers, daytime state, catalog ID, exact grid coordinates, map clearance, structure overlap, and shared affordability before issuing reliable placement commits.

## Tier-1 catalog

| Card | Wood | Metal | Tech | Role |
|---|---:|---:|---:|---|
| T1 Kinetic | 18 | 22 | 4 | Direct-fire single-target sentry |
| T1 Chemical | 8 | 14 | 16 | Corrosive area denial |
| T1 Electric | 6 | 20 | 22 | Three-target chain control |
| T1 Support | 20 | 10 | 12 | Defense repair and scan support |
| T1 Barricade | 26 | 4 | 0 | Two-cell path blocker |
| T1 Landmine | 8 | 12 | 4 | Single-use radial blast trap |
| T1 Slowing Pit | 18 | 0 | 5 | Persistent movement trap |
| T1 Razor Snare | 12 | 18 | 8 | Reusable damage and short-root trap |

The catalog stores mechanics, exact Tier-1 stats, footprint, muted role accent, health, three-resource cost, typed `TOWER`/`TRAP`/`UTILITY` category, visual texture path, and navigation-blocking policy. Every ID resolves its own top-down texture. Kinetic, Chemical, and Electric retain distinct silhouettes and distinct single-target, area-burst, and chain presentation. Landmine is a single-use radial blast; Slowing Pit persistently refreshes a `0.62` movement multiplier for zombies in its 72px aura; Razor Snare deals 34 damage, applies a 0.45-second root, and rearms after 1.25 seconds.

All defense damage and movement status changes execute only on peer one. Clients receive attack presentation plus authoritative enemy snapshots. Structure health and EMP changes use reliable authority-only commits, while late-join build snapshots include validated health, EMP remaining time, aim direction, cooldown, and target ID arrays. Towers, Support, and Barricade retain `WorldStatic` collision and flow-field rasterization. The three ground traps remain selectable and placement-exclusive but do not block players, projectiles, or zombie flow, ensuring waves actually cross their trigger areas.

## Base relocation transaction

`Make Base` arms the same 64px 2D placement controller. Peer one validates the destination, totals the actual invested Wood, Metal, and Tech across every player-built tower or trap, computes `floor(total * 0.35)` independently for each resource, and sends one reliable commit containing:

1. the new Base Core `Vector2`;
2. the three-resource refund and resulting shared pool;
3. the number of destroyed structures.

The commit removes all placed defenses immediately, moves the Base Core and its collision, rebuilds the core contribution in the world flow mask, and calls `set_base_target(new_position)` on every node in the `zombies` group. Clients cannot supply refund values, destroyed IDs, or pool results.

## Resource interaction contract

Each of the 87 deterministic resource nodes now requires a seed- and resource-ID-derived `3` to `5` accepted interactions. Peer one chooses and locks the nearest in-range node per peer, advances exactly one step per accepted request, and broadcasts a reliable ordered delta containing the next revision and canonical ID/kind/progress. Receivers accept only the strict next revision and next progress step. Intermediate hits provide per-instance scale, glow, opacity, and progress-ring feedback without mutating the shared shader material.

The original economy is unchanged: `HARVEST_AMOUNT` remains `1`, intermediate steps grant `0`, and only the final step grants the one resource and emits `resource_gathered`. A late-join snapshot replaces all local state with the complete 87-byte progress array plus inventory, so partially harvested, depleted, and resurrected presentation cannot drift after reconnect.

## Feedback and touch behavior

`JuiceRig` owns the no-shake feedback contract: immediate `1.15x` scale pops that settle in exactly `0.25s`, plus the `solid_white_flash.gdshader` material pulse used by damage and alerts. `AudioManager` preserves the six positional world voices and preallocates eight fixed mono voices for pitch-varied click, alert, and metallic-thud feedback. Player and tower fire use a short local firearm crack rather than the legacy sci-fi laser stream; tower shots are mixed quieter than player shots. Teardown stops every voice and releases all stream references.

The compact dashboard occupies only `148 x 58` logical pixels in the top-left safe area. The movement joystick remains in the lower control band, and while the deck is open the dashboard and gameplay controls disappear on frame one so the centered popup owns touch input.

## Validation

- `res://tests/tactical_hud_validation.gd`: deterministic checks covering the `148 x 58` dashboard, hidden generic status surface, world-space resource gains, centered build popup with below-card information, all eight catalog cards, category grouping, three-card pagination, remembered selection, live resource chips, outside-close behavior, fogged minimap mapping/resource visibility, touch projection, placement, refund, warnings, and day/night authority.
- `res://tests/resource_scatter_validation.gd`: deterministic solo checks for 87-node layout identity, 3-5-step durability, focus/progress/final-yield behavior, immutable shared materials, and complete partial-progress snapshot replacement.
- `res://tests/resource_enet_probe.gd`: two-process host/client probe proving client action-only requests, host-selected focus, ordered progress replication, exactly one final grant, and identical depletion/inventory state.
- `res://tests/tower_combat_validation.gd`: focused host-runtime gate covering all three towers and all three traps, automatic kinetic fire plus its positional firearm cue, trap pass-through in flow/player motion, placement overlap, client mutation rejection, late-join runtime fields, lifecycle teardown, and the 16-tower/110-zombie cadence scenario.
- `res://tests/tactical_enet_probe.gd`: two-process host/client probe covering a client-requested nonblocking Razor Snare, host commit, client-requested Base relocation, `[4, 6, 2]` refund, replicated `[112, 88, 74]` pool, and client-requested night.
- `res://tests/tactical_hud_render_validation.tscn`: Mobile/Vulkan capture gate for the current `148 x 58` dashboard and centered category-driven popup at 480x270. It produces dashboard plus Towers, Traps, and Utilities captures and verifies that the preview and Place action remain inside the logical viewport.

Desktop Godot validation does not certify Android cutouts, touch ergonomics, audio perception, thermals, or physical two-device latency. Those remain device gates.
