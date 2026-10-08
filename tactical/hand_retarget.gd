extends RefCounted

static func fit_fingers(rig: Skeleton3D, weapon: Node3D, side: String, hand_delta: Basis) -> void:
	for finger in ["Index","Middle","Ring","Pinky","Thumb"]:
		for segment in 3:
			var bone := rig.find_bone(finger+str(segment+2)+"."+side)
			if bone < 0: continue
			var direction: Vector3 = rig.global_basis.inverse()*weapon.authored_finger_direction(side,finger,segment)
			if direction.length_squared() < 0.5: continue
			var parent := rig.get_bone_parent(bone)
			var rest := rig.get_bone_global_rest(bone)
			var parent_rest := rig.get_bone_global_rest(parent)
			var pose := rig.get_bone_global_pose(parent)*parent_rest.affine_inverse()*rest
			var children := rig.get_bone_children(bone)
			var rest_direction := (rest.origin-parent_rest.origin).normalized()
			if not children.is_empty(): rest_direction = (rig.get_bone_global_rest(children[0]).origin-rest.origin).normalized()
			var rotated := hand_delta*rest_direction
			pose.basis = Basis(Quaternion(rotated.normalized(),direction.normalized()))*hand_delta*rest.basis
			rig.set_bone_global_pose_override(bone,pose,1.0,true)
