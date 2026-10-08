# Current project layout

Open `project.godot`. The main game scene is `mvp/main.tscn`.

- `mvp/`: multiplayer, training, player controller, menus, settings, login and database setup.
- `tactical/`: current rifle/pistol scenes, character pose, hand materials and combat effects.
- `tactical/assets/`: character models and weapon sounds.
- `scenes/arena/`: current multiplayer arena.
- `scenes/characters/`: menu character.
- `scripts/`: shared map, character, audio and effects helpers still referenced by the game.
- `assets/`: models, textures, sounds and source credits used by the retained scenes.
- `.godot/`: Godot-generated local import cache. Do not edit these files manually.

## Cleanup on 2026-10-08

428 obsolete files (441.9 MB) were moved out of this project, including previous weapon variants, unused legacy scenes/scripts/assets and old backup directories. The archive is at:

`C:\Users\ayesh\Documents\ChatGPT\FPS\archive_20261008`

The archive's `manifest.json` lists original paths and sizes. To restore a file, copy it back to the same relative path under this project. No archived file was permanently deleted. SQL setup, configuration and asset credits were retained.

The player scene hides the first-person view in the editor; the game enables it for the local player. The body preview uses the same rifle/pistol pose code as bots and remote players. Reopen `mvp/player.tscn` if an already-open editor still shows the previous pose.
