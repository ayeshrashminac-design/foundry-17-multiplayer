extends Node3D

const IK = preload("res://tactical/limb_ik.gd")
const HANDS = preload("res://tactical/hand_retarget.gd")
var rig: Skeleton3D
var weapon: Node3D

func setup(source: Node3D, path: String) -> void:
	weapon = source
	var model: Node3D = load(path).instantiate()
	add_child(model)
	rig = model.find_child("Skeleton3D",true,false)
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func update_pose() -> void:
	if not rig: return
	rig.clear_bones_global_pose_override()
	for side in ["L","R"]:
		var authored: Dictionary = weapon.authored_hand(side)
		if authored.is_empty(): continue
		var wrist := rig.find_bone("Wrist."+side)
		var rest := rig.get_bone_global_rest(wrist)
		var middle := rig.get_bone_global_rest(rig.find_bone("Middle2."+side)).origin
		var forward := (middle-rest.origin).normalized()
		var across := (rig.get_bone_global_rest(rig.find_bone("Index2."+side)).origin-rig.get_bone_global_rest(rig.find_bone("Pinky2."+side)).origin).normalized()
		across = (across-forward*across.dot(forward)).normalized()
		var frame := Basis(forward,across,forward.cross(across))
		var rotation: Basis = (rig.global_basis.inverse()*authored.basis*frame.inverse()).orthonormalized()
		var target: Vector3 = rig.to_local(authored.palm)-rotation*(middle-rest.origin)*0.65
		var sign_x := 1.0 if side=="R" else -1.0
		var shoulder := rig.to_local(weapon.actor.camera.to_global(Vector3(sign_x*0.24,-0.43,-0.08)))
		var elbow := rig.to_local(weapon.actor.camera.to_global(Vector3(sign_x*0.35,-0.34,-0.2)))
		IK.solve(rig,rig.find_bone("UpperArm."+side),rig.find_bone("LowerArm."+side),wrist,target,elbow,shoulder,rotation*rest.basis,true)
		HANDS.fit_fingers(rig,weapon,side,rotation)
