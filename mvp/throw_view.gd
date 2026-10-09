extends Node3D
# Editable procedural wind-up, release and recovery on the existing arm rig.
const IK = preload("res://tactical/limb_ik.gd")
var actor: Node
var rig: Skeleton3D
var grenade: MeshInstance3D
var model: Node3D
var character := -1

func _ready() -> void:
	actor = get_parent().get_parent()
	process_priority = 30
	grenade = MeshInstance3D.new()
	var shape := CapsuleMesh.new()
	shape.radius = 0.035
	shape.height = 0.11
	grenade.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("45532b")
	grenade.material_override = material
	add_child(grenade)
	hide()

func _process(_delta: float) -> void:
	visible = actor.local_player and not actor.dead and actor.throw_left > 0
	if not visible: return
	if character != actor.character_id:
		character = actor.character_id
		if is_instance_valid(model): remove_child(model); model.queue_free()
		var path: String = preload("res://mvp/character_catalog.gd").OPERATORS[character].arms
		if path.is_empty(): path = "res://tactical/assets/arms_vanguard.glb"
		model = load(path).instantiate()
		add_child(model)
		rig = model.find_child("Skeleton3D",true,false)
		for mesh in model.find_children("*","MeshInstance3D",true,false): mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	actor.get_node("Camera/ViewWeapon").visible = false
	rig.clear_bones_global_pose_override()
	var t: float = clampf(1-actor.throw_left/0.9,0,1)
	var hand: Vector3
	if t < 0.39: hand = Vector3(0.2,-0.28,-0.6).lerp(Vector3(0.34,-0.14,-0.45),smoothstep(0,0.39,t))
	else: hand = Vector3(0.34,-0.14,-0.45).lerp(Vector3(0.12,-0.12,-0.75),sin((t-0.39)/0.61*PI))
	for side in ["R","L"]:
		var sign_x := 1.0 if side == "R" else -1.0
		var target := hand if side == "R" else Vector3(-0.2,-0.5,-0.23)
		var wrist := rig.find_bone("Wrist."+side)
		IK.solve(rig,rig.find_bone("UpperArm."+side),rig.find_bone("LowerArm."+side),wrist,rig.to_local(to_global(target)),rig.to_local(to_global(Vector3(sign_x*0.45,-0.3,0))),rig.to_local(to_global(Vector3(sign_x*0.22,-0.42,0.03))),rig.get_bone_global_rest(wrist).basis,true)
	grenade.position = hand+Vector3(0,0,-0.035)
	grenade.visible = t < 0.39
