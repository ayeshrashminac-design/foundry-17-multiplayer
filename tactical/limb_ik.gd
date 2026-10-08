extends RefCounted

# Analytic two-bone IK in skeleton space. Keeps the elbow's bend direction stable.
static func solve(rig: Skeleton3D, upper: int, lower: int, hand: int, target: Vector3, pole: Vector3, shoulder: Vector3 = Vector3.INF, wrist_basis: Basis = Basis.IDENTITY, use_rest_lengths := false) -> void:
	if mini(upper, mini(lower, hand)) < 0: return
	var poses: Array[Transform3D] = []
	for i in rig.get_bone_count(): poses.append(rig.get_bone_global_pose(i))
	var a := rig.get_bone_global_pose(upper)
	var b := rig.get_bone_global_pose(lower)
	var c := rig.get_bone_global_pose(hand)
	var original_a := a
	var original_b := b
	var original_c := c
	var first := a.origin.distance_to(b.origin)
	var second := b.origin.distance_to(c.origin)
	if use_rest_lengths:
		first = rig.get_bone_global_rest(upper).origin.distance_to(rig.get_bone_global_rest(lower).origin)
		second = rig.get_bone_global_rest(lower).origin.distance_to(rig.get_bone_global_rest(hand).origin)
	if shoulder != Vector3.INF: a.origin = shoulder
	var direction := (target - a.origin).normalized()
	var epsilon := minf(first,second)*0.01
	var distance := clampf(a.origin.distance_to(target), absf(first-second)+epsilon, first+second-epsilon)
	var bend := pole - a.origin
	bend = (bend - direction * bend.dot(direction)).normalized()
	if bend.length_squared() < 0.5: bend = direction.cross(Vector3.RIGHT).normalized()
	var along := (first*first + distance*distance - second*second) / (2.0*distance)
	var elbow := a.origin + direction*along + bend*sqrt(maxf(0,first*first-along*along))
	var wrist := a.origin + direction*distance
	var rest_a := rig.get_bone_global_rest(upper)
	var rest_b := rig.get_bone_global_rest(lower)
	var rest_c := rig.get_bone_global_rest(hand)
	a.basis = Basis(Quaternion((rest_b.origin-rest_a.origin).normalized(),(elbow-a.origin).normalized())) * rest_a.basis
	b.basis = Basis(Quaternion((rest_c.origin-rest_b.origin).normalized(),(wrist-elbow).normalized())) * rest_b.basis
	b.origin = elbow
	c.basis = b.basis * rest_b.basis.inverse() * rest_c.basis
	if wrist_basis != Basis.IDENTITY: c.basis = wrist_basis
	c.origin = wrist
	# Explicitly transform descendants, including twist and finger skinning bones.
	# Global overrides alone do not update their descendants' cached poses.
	for i in rig.get_bone_count():
		var pose := poses[i]
		if descendant(rig,i,hand): pose = c*original_c.affine_inverse()*pose
		elif descendant(rig,i,lower): pose = b*original_b.affine_inverse()*pose
		elif descendant(rig,i,upper): pose = a*original_a.affine_inverse()*pose
		else: continue
		rig.set_bone_global_pose_override(i,pose,1.0,true)

static func descendant(rig: Skeleton3D, bone: int, ancestor: int) -> bool:
	while bone >= 0:
		if bone == ancestor: return true
		bone = rig.get_bone_parent(bone)
	return false

static func grip_fingers(rig: Skeleton3D) -> void:
	for i in rig.get_bone_count():
		var bone_name := String(rig.get_bone_name(i))
		var finger := bone_name.begins_with("Index") or bone_name.begins_with("Middle") or bone_name.begins_with("Ring") or bone_name.begins_with("Pinky")
		if finger and ("2." in bone_name or "3." in bone_name or "4." in bone_name):
			var curl := 0.8 if "2." in bone_name else 0.95
			rig.set_bone_pose_rotation(i,rig.get_bone_rest(i).basis.get_rotation_quaternion()*Quaternion(Vector3.RIGHT,curl))
