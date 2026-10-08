# Active character: textured Mixamo SWAT

`operator_realistic.glb` is shared by player bodies, training bots and training mannequins. It replaces the flat-colour operator variant. The imported character retains its original blue uniform, black equipment, texture maps and skin weights.

Source: Adobe Mixamo **Swat**, distributed as a converted GLB in the [three.ws Mixamo character library](https://github.com/nirholas/three.ws/tree/main/public/avatars/mixamo).

Downloaded 2026-10-08 from:
https://pub-2534e921bf9c4314addcd4d8a6e98b7b.r2.dev/avatars/mixamo/glb/swat.glb

Character rights remain under the Mixamo terms, not CC0. [Adobe's Mixamo FAQ](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html) describes royalty-free use in video games. Do not redistribute the character as a standalone asset pack.

Existing Quaternius CC0 operator animations were retargeted locally to this skeleton: idle, armed idle, walk, forward/side/back run and death. Bone names were mapped to the existing arm IK system. Gameplay and network authority are unchanged.

The original Cransh FPS hands and weapon animations are retained (credits in `assets/additional_weapons/CREDITS.md`). `tactical/operator_hands.gdshader` matches their sleeve and glove colours to the SWAT outfit while retaining their original leather, fabric and normal-map detail. It affects first-person hands only.

Editable source and conversion script are in the development workspace's `character_match/operator_realistic.blend` and `retarget_swat.py`; the game uses the smaller GLB.
