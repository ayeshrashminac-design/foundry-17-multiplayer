# Replacement tactical assets

SWAT operator by Quaternius (CC0): https://poly.pizza/m/Btfn3G5Xv4
Download: https://static.poly.pizza/713f6535-f4f3-4367-a4c6-ced126ae0936.glb
operator_arms.glb is a derived first-person mesh from SWAT, with torso removed and arm weights normalized in Blender.

Flat Guns West rifle and pistol rigs (CC0), obtained from:
https://github.com/petroulacl/fps-asset-kit
Revision a19b7458a593598211c95ec46ef4eb4b6d1f94d7
Source files: weapons/flat_guns_west/Flat Guns West/FBX/Rifle_Assault_West.Rig.fbx and Pistol_Full_West.Rig.fbx.

Firearm recordings from the same pinned repository: Prepared SFX Library/AR-15/D_24P.wav and 1911/A_34P.wav. Cropped to a single transient, normalized and converted to 48 kHz mono PCM.

Game-specific IK, weapon poses, open reflex sight, handling and integration are original code.
These are independent stylized assets; no Call of Duty game assets are included.

## Active first-person weapons (2026-10-07)
The active rifle and pistol now use the user-supplied Cransh AK-74M and FN 502 Tactical models, textures and authored hand animations (CC BY 4.0). See ../../assets/additional_weapons/CREDITS.md for original model links and license attribution. Source GLBs remain unchanged. The wrappers retime and blend their authored clips, fit shoulders beneath the camera without changing finger grips, and follow the animated weapon bone for muzzle/ejection markers. The earlier Flat Guns West models and extracted SWAT arms are no longer used by the active player scene. Quaternius SWAT remains the third-person body.

Technical references consulted: [FPS camera, hand IK, ADS and sway tutorial overview](https://forums.unrealengine.com/t/true-fps-character-setup-camera-animation-ik-system-weapon-ads-weapon-sway/148452) and [Godot particle material documentation](https://docs.godotengine.org/en/stable/tutorials/3d/particles/process_material_properties.html). Muzzle flash/smoke shaders and damage feedback are original project code.
