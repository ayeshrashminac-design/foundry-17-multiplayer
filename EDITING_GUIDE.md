# Godot editing guide — Foundry 17

Open this folder's project.godot in Godot 4.7.1. Open scenes/main.tscn, then press F5 to play.
The map and characters now exist before Play. Scene files are authoritative: runtime code no longer rebuilds the arena, player meshes or weapon geometry.

## Where to edit

| What | Scene/resource | How |
| --- | --- | --- |
| Whole game | scenes/main.tscn | Level, Player, Enemies, HUD and WorldEnvironment are visible in the Scene tree. |
| Arena | scenes/arena/foundry_17.tscn | ArenaNavigation contains Structure, Cover and SurfaceDetails. Move, rotate, resize or duplicate nodes. |
| Lights and signs | Arena/Lighting and Arena/Signs | Light energy/color/range and Label3D text are native Inspector properties. |
| Respawn | Arena/PlayerSpawn | Move the Marker3D. Initial player position is the Player node in main.tscn. |
| Enemies | main.tscn → Enemies | Move, duplicate or delete soldier instances. The round automatically counts the placed roster. |
| Enemy prefab | scenes/enemy.tscn | Collider, detection area, navigation agent, HumanVisual and health bar. |
| Player | scenes/player.tscn | Camera, collision, HumanBody, HumanArms and all weapon models. Root Inspector exposes walk/sprint/ADS speeds, jump, gravity, mouse sensitivity and health/shield limits. |
| Human skeletons | scenes/characters/soldier.tscn, player_body.tscn, player_arms.tscn | Model/Skeleton3D, skinned meshes, materials, MotionClips and procedural settings. |
| Rifle pieces | scenes/weapons/tactical_rifle.tscn | Receiver, handguard, barrel, muzzle, stock, magazine, grip, rails and sight. |
| Weapon gameplay | assets/weapons/*.tres | Damage, ammo, magazine size, fire rate, reload duration and projectile type. Keep the eight-slot loadout order in Player. |
| HUD | scenes/ui/hud.tscn | Layout, fonts, colors and bar styles in the 2D editor. Gameplay still updates dynamic labels and bar values. |
| Materials | assets/materials/*.tres | Shared shader/material resources. Use Make Unique before changing only one object's appearance. |
| Surface shader | scripts/industrial_surface.gdshader | Native Godot shader; parameters are exposed on ShaderMaterial resources. |

## Working with scenes

Main has Editable Children enabled for Level, Player, HUD and soldiers. Open the source scene to make changes shared by every instance. Per-instance overrides in main.tscn affect only that instance. Save changes with Ctrl+S. Stop a running game before testing edits with F5.

Solid arena boxes keep their BoxShape collision dimensions synchronized when you edit Mesh → Size. Moving/scaling the whole mesh node also moves/scales its child collider. Disable Collision Follows Mesh when you intentionally want a different shape. Duplicating a node shares its mesh/material resources until you use Make Unique.

Navigation rebakes automatically on Play by default, using the edited solid geometry. You can also select ArenaNavigation and use Bake NavigationMesh in the editor. Disable Rebake Navigation On Start only after saving a current navigation bake. Keep traversable routes at least about 1.5 m wide for the configured agent radius.

## Editing animations

Open a character scene and select MotionClips. The Animation panel has editable idle, walk, sprint, strafe, reload and jump tracks. They are saved in assets/animations/*_motion.tres. You can play/scrub the timeline without launching the game.

The default live controller uses procedural full-body animation so the motion responds to movement direction, aiming, recoil and landing. Its root Inspector exposes Motion Rate, Stride Multiplier and Body Motion Scale. To use your edited timeline clips during gameplay, disable Procedural Motion on the relevant HumanVisual/HumanBody/HumanArms instance. The clip controller selects idle/walk/sprint/reload/jump according to gameplay. Preview Clip chooses the initial clip for standalone character previews. These in-place clips do not move the physics body.

Mesh topology remains in the character mesh resources; the original FBX and textures are retained in assets/models for external mesh authoring/reimport. Standard scene, skeleton, material, animation, UI and gameplay edits are available in Godot.

## Validation and recovery

Verified save/reload/play with changed cover position, light energy, respawn marker, walk speed and weapon damage; added an editor-placed enemy and checked its registration. Verified animation scrubbing, navigation, combat completion, scope visibility, full-body motion and player movement. Rendered the converted game with Forward+.

The pre-conversion scripts/scenes/project settings are backed up in editor-backup-20261001-015942. That directory is ignored by Godot. Earlier upgrade notes describe historical versions; this guide describes the current editable project.

## Expanded arena

The current floor is 96 x 96 metres (9,216 square metres), four times the previous 48 x 48 metre footprint. X/Z map dimensions and actor/spawn placement were doubled; ceiling and character heights are unchanged. Eight low cover blocks and twelve ceiling lights fill the expanded routes. The navigation mesh is baked for the new geometry, and all scene nodes remain editable. The previous arena and main scene are in map-size-backup-20261001-193423.
