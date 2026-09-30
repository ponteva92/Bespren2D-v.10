# Bespren Mobile LAN Foundation

Bespren now boots at 480×270 landscape into `StartMenu.tscn`, selects Heikki or Shane with a bounce tween, and launches Solo, Host LAN, or Join LAN. Host and Client use ENet over UDP 8791; client connection failure or host loss automatically restores an `OfflineMultiplayerPeer` Solo session at authority peer 1.

## Runtime contract

- `MobileControls` owns separate finger indices for the left eight-way joystick, Interact, and Fire. Both action regions are exactly 44×44 logical points, owned touches are marked handled, and Android safe-area insets are converted into logical canvas coordinates.
- `CoopSession` accepts reliable movement and action requests only from registered peers. Clients call peer 1, the host validates finite unit movement and allowed actions, integrates `Vector2` positions, and reliably broadcasts authoritative state at 20 Hz.
- `GameWorld` contains only 2D nodes. Each peer is represented by `network_player.tscn`, a `CharacterBody2D` under a Y-sorted root; Fire and Interact currently trigger presentation feedback only.

## Desktop controls

- Move: WASD or arrow keys
- Interact: E
- Fire: F
- Menu: the top-right MENU button

## Verification

Run the structural and mobile-system gates:

```powershell
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\Users\heikk\Desktop\Claude\gpt_peli' --script res://tests/smoke_test.gd
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\Users\heikk\Desktop\Claude\gpt_peli' --script res://tests/mobile_systems_validation.gd
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\Users\heikk\Desktop\Claude\gpt_peli' --script res://tests/polyhaven_district_validation.gd
```

Run `tests/enet_peer_probe.gd` simultaneously in two terminals, starting Host first:

```powershell
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\Users\heikk\Desktop\Claude\gpt_peli' --script res://tests/enet_peer_probe.gd -- --role=host
& 'C:\Users\heikk\Desktop\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\Users\heikk\Desktop\Claude\gpt_peli' --script res://tests/enet_peer_probe.gd -- --role=client
```

The historical package snapshot below was validated with `SMOKE OK (191 checks)`, `MOBILE SYSTEMS OK (54 checks)`, and `POLY HAVEN DISTRICT VALIDATION OK (58 checks)`. Current source-state evidence is `WORLD MAP VALIDATION OK (150 checks)`, `RESOURCE SCATTER VALIDATION OK (72 checks)`, and `POLY HAVEN DISTRICT VALIDATION OK (58 checks)`; the current smoke run has one unresolved east-camp flow-direction assertion and must not be treated as green. The district family remains an offline 2D atlas integration: no GLTF, runtime mesh, or `Node3D` was added to the mobile scene. The settled `build/android/Bespren-runtime.pck` is 5,597,484 bytes with SHA-256 `A613EE0B45D6146288F91FF1F7FDF5A75FEFD58B5AA32BC3605AFD63587E6565`; the isolated verifier loads 120 closure resources and instantiates 23 scenes. `build/android/Bespren-debug.apk` is 34,252,025 bytes with SHA-256 `7B3381817EC8D8ED48AE4E43D4E31D714A67E323C67813400E5F6196A3163A79`; its inventory passes with 337 ZIP entries, 239 Godot payload entries, 120 closure resources, 42 scripts, 66 remaps, 24 scenes, 45 imports, and zero forbidden entries, and APK Signature Schemes v2/v3 verify. The freshness gate checked 124 paths with zero missing and nothing newer than either package. No physical Android device was attached during this implementation, so install, cutout ergonomics, resume behavior, sustained thermal performance, and physical two-device LAN behavior remain device gates.
