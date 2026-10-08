# Selectable operators

The lobby offers SWAT, Ely and Vanguard. Selection is saved locally, applied when hosting/joining or entering training, validated against the roster and included in server snapshots. Appearance does not change health, damage or movement speed. Training bots cycle through the same roster.

- SWAT: existing Mixamo SWAT; see `REALISTIC_OPERATOR.md`.
- Ely by K. Atienza: Mixamo character converted to GLB by the three.ws library, downloaded 2026-10-08 (3,725,780 bytes): https://pub-2534e921bf9c4314addcd4d8a6e98b7b.r2.dev/avatars/mixamo/glb/ely-by-k-atienza.glb
- Vanguard by T. Choonyung: reused the existing locally supplied `Vanguard By T. Choonyung.fbx`; no new Vanguard download.

Original character textures and skin weights are retained. Existing Quaternius animation clips were retargeted locally. Mixamo character terms apply, not CC0. Source library: https://github.com/nirholas/three.ws/tree/main/public/avatars/mixamo

The requested CGTrader free listing provides a compiled UE4 gameplay demo, not the source character pack, so none of its demo content was extracted or used.

Edit roster labels/paths in `mvp/character_catalog.gd`; edit the menu in `mvp/operator_lobby.gd`. Converted characters are in `tactical/assets/`. Conversion script is in the development workspace at `operator_lobby/retarget.py`.

Ely and Vanguard also use their own first-person arm meshes (`arms_ely.glb`, `arms_vanguard.glb`), extracted locally from these same characters with original materials. Arm-only skin weights are normalized after removing torso influences. `tactical/character_arms.gd` follows the weapon's authored wrist and finger animation; `hand_retarget.gd` shares finger fitting with the full-body rig. SWAT retains the original authored weapon arms. Extraction script: development workspace `selected_arms/extract.py`.
