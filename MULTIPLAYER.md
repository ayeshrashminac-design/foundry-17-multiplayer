# Foundry 17 multiplayer

Open `project.godot` in Godot 4.7.1 and press **F5**.

This uses the existing Foundry 17 arena, textured human characters, animated arms and weapon models. The previously enlarged 96 × 96 metre map is retained, with two accessible rooftop rooms and eight spawn points. Everything remains editable in Godot.

## Play

1. Enter your name and choose **Host Game** (or **Play**, which also hosts).
2. On another instance/computer, enter the host's IP and choose **Join Game**. For two instances on one computer, use `127.0.0.1`.
3. The round starts when the second player joins. Supports 2–8 players; 10 minutes or 20 kills; 5-second respawn. The host can start a rematch from the results screen.

Default port: **UDP 7777**. On a LAN, use the host's LAN address and allow Godot through its firewall. Internet hosting requires a reachable host and router UDP port forwarding; there is no matchmaking service or relay. Leaving as host ends the session for everyone.

## Controls

WASD move · Mouse look · Space jump · Shift sprint · Left mouse fire · Right mouse ADS · R reload · 1 AK-12 · 2 MGP7 · 3 AK-74M · 4 FN 502 · 5 Benelli · 6 Saiga · 7 VSK · Tab scoreboard · Esc pause.

Settings save sensitivity, master/SFX volume, fullscreen and resolution. Pausing stops your input; the multiplayer match continues.

## Edit

- `mvp/main.tscn`: multiplayer entry scene, lighting and spawn markers.
- `scenes/arena/foundry_17.tscn`: original arena geometry and materials.
- `mvp/extensions.tscn`: extra rooms, stairs and rooftop cover.
- `mvp/player.tscn`: existing character and weapon assets adapted for multiplayer.
- `mvp/ui.tscn`: menus, HUD and scoreboard.
- `mvp/player.gd`: movement, prediction and remote interpolation.
- `mvp/network.gd`: ENet connections, authoritative combat, spawning and match rules.
- `mvp/weapons.gd`: the seven weapon definitions, fire rate and ammunition.
- `mvp/settings.gd`, `audio.gd`, `ui.gd`, `app.gd`: separate settings, synthesized audio, interface and scene coordination.

The server simulates movement and validates weapon cooldown/ammunition, hits, damage and scores. Clients predict their own movement and interpolate remote players. Snapshots are compressed and sent at 20 Hz. This is a direct-connect MVP, without lag compensation or host migration.

The original single-player scene remains at `scenes/main.tscn`. Pre-multiplayer project settings and the character animation script are saved under `multiplayer-backup/`.

## Verification

Local automated checks covered eight simultaneous ENet peers, unique names, movement, jumping and floor collision; a separate real host/client test covered hitscan kills, replicated health and score, reloads, weapon switching, five-second respawn, timer expiry, rematch and the 20-kill condition. Weapon edge cases and walking upstairs to the roof were also checked. Menu, settings and in-game rendering were inspected using Forward+.

Internet latency and separate physical computers have not been tested. During the eight-process simultaneous shutdown test, Godot logged one ENet channel-close error; the two-player lifecycle test completed without errors.

## Offline training

Choose **Training — Play with Bots** on the main menu. This starts a separate, brightly lit 40 × 32 metre indoor practice arena with three human bots. No host, second player or internet connection is needed.

Bots navigate around cover, aim, shoot, reload and respawn using the same weapons and combat rules as the player. Training uses a 10-minute/20-kill round and 5-second respawn. Use Esc → Leave Match to return to the menu; multiplayer continues to use the original Foundry arena.

Edit `mvp/training_map.tscn` for the training arena and spawn points, and `mvp/training_bot.gd` for bot reaction time, movement and aim spread. Navigation is baked from the training map's collision geometry when training starts. Bot navigation, damage, scoring, respawn and returning to multiplayer were tested; the arena and menu were visually checked.

