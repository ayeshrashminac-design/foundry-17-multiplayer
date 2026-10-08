# Tactical player and weapons

Run `project.godot` in Godot and press F5. Choose Training to play immediately.

Controls: WASD move, mouse look, Space jump, Shift forward sprint, right mouse aim, left mouse fire, R reload, 1 rifle, 2 pistol, Tab scores, Escape pause.

- `mvp/player.tscn`: replacement player, camera, matching SWAT arms and body.
- `rifle.tres`, `pistol.tres`: damage, magazine/reserve, fire rate, recoil and aiming settings.
- `rifle.tscn`, `pistol.tscn`: editable gun models, muzzle, casing, sight and hand-grip markers.
- `weapon_visual.gd`: bolt/slide and magazine reload motion.
- `operator.gd`: imported locomotion/death clips plus arm aiming.
- `limb_ik.gd`: shared arm and hand posing.
- `assets/SOURCES.md`: download sources and licenses.

Damage, ammunition and score remain server-authoritative. Existing friends, rooms and account services are preserved.
Visuals use independent low-poly tactical assets. This is a compact FPS implementation inspired by modern shooter handling, not a reproduction of Warzone's assets or complete mechanics.

Validation: training combat, ammunition and fire-rate enforcement, reload, switching, kill/death/respawn; separate local host/client movement, weapon state, health, score and respawn replication; rendered hip-fire, ADS, pistol, operator and death views. Remote internet/NAT connectivity was not retested in this change.
