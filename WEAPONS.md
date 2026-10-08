# Weapons and animation

Open `project.godot` in Godot and press **F5**. Choose **Training — Play with Bots**, or host/join multiplayer.

**Left mouse:** fire · **Right mouse:** ADS · **R:** reload · **1–7:** switch weapons. Sprint disables shooting and ADS.

| Key | Weapon | Body / head damage | Magazine / reserve | Shot interval |
|---|---|---|---|---|
| 1 | AK-12 | 25 / 50 | 30 / 120 | 0.12 s |
| 2 | MGP7 | 20 / 40 | 30 / 120 | 0.075 s |
| 3 | AK-74M | 27 / 54 | 30 / 120 | 0.11 s |
| 4 | FN 502 Tactical | 24 / 48 | 15 / 90 | 0.22 s |
| 5 | Benelli M4 | 12 / 18 per pellet, 8 pellets | 7 / 35 | 0.65 s |
| 6 | Saiga-12 | 10 / 15 per pellet, 8 pellets | 10 / 40 | 0.32 s |
| 7 | VSK-94 | 32 / 64 | 20 / 100 | 0.14 s |

FN 502 and Benelli are semi-automatic; the others support held fire. Shotguns debit one shell per shot. The server calculates every pellet and aggregates damage per victim. Benelli uses a timed full reload; individual shell insertion is not a separate gameplay system.

## Edit in Godot

Each weapon has a matching `mvp/*.tres` configuration and `mvp/*.tscn` model wrapper: `ak12`, `mgp7`, `ak74`, `fn502`, `benelli`, `saiga`, `vsk`. Tune damage, ammo, recoil, spread, ADS, fire rate and reload timing in the resources. Edit muzzle, shell and sight markers in the scenes. New models load on first selection and are cached.

The six animated weapons use their supplied arms and clips. Reload follows authoritative progress; muzzle/shell markers follow the animated weapon bone. ADS keeps hand grips while blending elbows below the sight. Duplicate hands are hidden on remote weapons. MGP7 retains its modular optic, suppressor, grip, laser and light controls. Original GLBs are preserved.

Movement has acceleration/braking, jump buffering and coyote time. Remote players interpolate snapshots. Existing human characters retain full-body procedural motion. Death blends into a grounded collapse, hides weapons, continues gravity, and resets on respawn; this is not a physics ragdoll. The supplied Russian Soldier has no rig or animation, so it appears as two static training mannequins. Animated training bots continue using the existing human rig.

## Systems

- `player.gd`: movement, camera, prediction and remote interpolation.
- `weapon_controller.gd`: input, switching, ADS, recoil and predicted effects.
- `weapons.gd` / `weapon_stats.gd`: ammunition, reload and weapon configuration.
- `animated_weapon.gd`: imported clip playback, ADS arm adjustment and effect markers.
- `asset_weapon.gd`: modular MGP7 model and procedural animation.
- `shooting.gd`: camera target, muzzle obstruction and server hitscan.
- `network.gd`: authoritative damage, health, ammo and scores; shot acknowledgements.
- `shot_effect.gd`: fixed pool of 32 tracer/impact pairs and 72 expiring casings.

## Credits

AK-12: **M37_R**, CC BY 4.0; see `assets/ak12/CREDITS.md`. Five additional weapons: **Cransh**, CC BY 4.0. Russian Soldier: **Bzovius**, CC BY 4.0. Source and license links and adaptation details are in `assets/additional_weapons/CREDITS.md`. MGP7, attachments and original casings: **Alstra Infinite**, supplied license in `assets/shooter_essentials/LICENSE.txt`.

## Verification

Local checks cover weapon damage and restrictions, reload conservation, muzzle cover, ADS markers, imported clips, movement/jump/landing, death/respawn and bounded effect reuse. Forward+ renders were inspected for all seven weapons at hip and ADS. Two separate local ENet processes exercise authoritative kills, prediction reconciliation, switching, reload, respawn, timer expiry, rematch and the 20-kill limit. Separate physical machines and internet latency remain untested.
