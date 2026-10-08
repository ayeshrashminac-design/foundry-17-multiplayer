# Foundry 17 Multiplayer

Foundry 17 is an editable Godot 4.7.1 multiplayer FPS project. It includes an indoor team arena, internet rooms, Google/Supabase sign-in, a training mode with bots, synced combat, respawning, score and match UI, character selection, and an in-game update flow.

## Open the project

1. Install Godot 4.7.1.
2. Import `project.godot`.
3. Open `scenes/main.tscn` and press **F6**, or press **F5** to run the configured main scene.

## Play

- **Training** starts the local bot arena.
- **Host Game** creates an internet room and displays its room ID.
- Friends sign in, join or accept an invite, then the room host starts the match.

## Controls

- **WASD**: move
- **Mouse**: look
- **Left mouse**: fire
- **Right mouse**: aim
- **Space**: jump
- **Shift**: sprint
- **R**: reload
- **1 / 2**: switch weapon
- **Tab**: scoreboard
- **Esc**: pause

## Project guides

See `EDITING_GUIDE.md`, `MULTIPLAYER.md`, `WEAPONS.md`, and `PROJECT_LAYOUT.md` for the scene and script layout.

Third-party asset credits are recorded in `assets/additional_weapons/CREDITS.md` and the related asset folders.
