# Foundry 17 visual upgrade

Open project.godot in Godot 4 and press F5. Stop any previously running instance first.

- Corrected disabled ambient lighting. Neutral fill lighting now works across the arena.
- F8 increases room brightness; F7 decreases it (current session only).
- Existing textured Vanguard human soldier asset replaces alien models at native human scale.
- Procedural rifle-holding pose, walking legs, and death fall; no new motion-captured animations.
- Player has a visible lower body and skinned first-person forearms/hands. Scope hides the viewmodel arms.
- Detailed tactical rifle receiver, barrel, rails, magazine, stock and reflex sight.
- Industrial surface shader, floor seams, vents, blast-door details, signs and overhead shadow lights.
- 4x MSAA, restrained ambient occlusion and glow. Shadows limited to key lights for GPU cost.
- HUD text no longer overlaps built-in progress percentages.

The game remains an offline bot arena; this update does not add network multiplayer.
Original files are in visual-backup-20261001-013526 (ignored by Godot).
