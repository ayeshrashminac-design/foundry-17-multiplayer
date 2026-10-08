# Full-body movement update

Restart the running game and use F5 in Godot.

- Procedural full-body gait: pelvis weight shift, spine counter-rotation, shoulders, neck/head stabilisation, bent elbows, wrists, fingers, knees, ankles and toes.
- Bone-length-constrained limb solving prevents stretching during forward, backward and lateral movement.
- Idle breathing, walk/run blending, turn lean, airborne tuck and landing compression.
- Rifle and gripping hands share the upper-body motion; support hand reaches during reload and firing adds recoil.
- Player accelerates/brakes gradually, with reduced air control. Enemy direction changes also ease in.
- First-person body and arms resolve the same player, with gait-synchronised weapon/head bob and reduced motion during aiming.

This is procedural animation using the existing rig, not a new motion-capture animation pack. Foot trajectories target the arena's flat floor; terrain-adaptive foot placement is not included.

Validation: Godot runtime tests cover bone motion and limb lengths, actual player acceleration/braking/jumping, scope visibility, enemy death and round completion. Walking, sprinting, reload and first-person views were rendered for inspection.
Previous scripts: motion-backup-20261001-015025.
