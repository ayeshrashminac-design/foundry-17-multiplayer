@tool
extends Node3D

const IK = preload("res://tactical/limb_ik.gd")
var actor: CharacterBody3D
var model: Node3D
var skeleton: Skeleton3D
var animation: AnimationPlayer
var dead := false
var death_clock := 0.0
var shot := 0.0
var current := ""

func set_character(value: int) -> void:
	var catalog = preload("res://mvp/character_catalog.gd")
	var replacement: Node3D = load(catalog.OPERATORS[catalog.valid_id(value)].path).instantiate()
	remove_child(model)
	model.queue_free()
	replacement.name = "OperatorModel"
	replacement.rotation.y = PI
	add_child(replacement)
	move_child(replacement,0)
	select_model()
	if dead: fall()

func _ready() -> void:
	actor = get_parent()
	process_priority = 35
	select_model()

func select_model() -> void:
	model = $OperatorModel
	skeleton = model.find_child("Skeleton3D",true,false)
	animation = model.find_child("AnimationPlayer",true,false)
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip in animation.get_animation_list():
		if any_loop(clip): animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	current = ""
	play("Idle")
	animation.advance(0)

func play(clip: String, blend := 0.16) -> void:
	if current == clip: return
	current = clip
	animation.play("CharacterArmature|"+clip,blend)

func any_loop(clip: String) -> bool:
	return "Idle" in clip or "Run" in clip or "Walk" in clip

func kick() -> void: shot = 1.0

func fall() -> void:
	dead = true
	death_clock = 0.0
	animation.speed_scale = 1.0
	skeleton.clear_bones_global_pose_override()
	play("Death",0.12)

func restore() -> void:
	dead = false
	death_clock = 0.0
	shot = 0.0
	skeleton.clear_bones_global_pose_override()
	animation.stop()
	current = ""
	play("Idle",0.0)
	animation.advance(0)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if not is_instance_valid(skeleton): return
		skeleton.clear_bones_global_pose_override()
		play("Idle_Gun",0.0)
		animation.advance(0)
		pose_weapon(0.0,0.0,0.0,0.0)
		return
	if not actor or not actor.session: return
	skeleton.clear_bones_global_pose_override()
	shot = move_toward(shot,0.0,delta*8.0)
	if dead:
		death_clock += delta
		animation.advance(delta)
		return
	var velocity: Vector3 = actor.velocity if actor.local_player or multiplayer.is_server() else actor.remote_velocity
	var speed := Vector2(velocity.x,velocity.z).length()
	var grounded: bool = actor.animation_grounded()
	var motion: Vector3 = actor.global_basis.inverse()*velocity
	var clip := "Idle_Gun"
	if grounded and speed > 0.35:
		clip = "Run_Shoot" if speed>6.0 else "Walk"
		if absf(motion.x)>absf(motion.z): clip = "Run_Left" if motion.x<0 else "Run_Right"
		elif motion.z>0: clip = "Run_Back"
	play(clip)
	animation.speed_scale = clampf(speed/(8.5 if speed>6.0 else 4.5),0.65,1.5) if speed>0.35 and actor.animation_grounded() else 1.0
	animation.advance(delta)
	if not grounded:
		for side in ["L","R"]:
			var thigh := skeleton.find_bone("UpperLeg."+side)
			var knee := skeleton.find_bone("LowerLeg."+side)
			if thigh>=0: skeleton.set_bone_pose_rotation(thigh,skeleton.get_bone_pose_rotation(thigh)*Quaternion(Vector3.RIGHT,-0.25))
			if knee>=0: skeleton.set_bone_pose_rotation(knee,skeleton.get_bone_pose_rotation(knee)*Quaternion(Vector3.RIGHT,0.45))
	var reload_amount: float = sin((1.0-actor.reload_timer/actor.get_reload_duration())*PI) if actor.is_reloading else 0.0
	pose_weapon(actor.camera.rotation.x,speed,actor.phase,reload_amount)

func pose_weapon(pitch: float, speed: float, phase: float, reload_amount: float) -> void:
	var mount: Node3D = $WeaponMount
	var weapon: Node3D = $WeaponMount/Weapon1 if $WeaponMount/Weapon1.visible else $WeaponMount/Weapon0
	var pistol := weapon == $WeaponMount/Weapon1
	# Place the rifle stock at the right shoulder and the pistol ahead of the chest.
	mount.rotation = Vector3(clampf(pitch,-0.9,0.9),0,-0.35*reload_amount)
	if pistol:
		mount.position = Vector3(0.04,1.43,-0.58)
	else:
		var shoulder := aim_shoulder("R")
		var contact := actor.to_local(skeleton.to_global(shoulder)) + Vector3(-0.055,-0.055,-0.075)
		var stock: Vector3 = weapon.transform * weapon.get_node("StockContact").position
		mount.position = contact - mount.basis*stock
	mount.position.z += shot*0.018
	mount.position += Vector3(sin(phase)*0.004,sin(phase*2.0)*0.004,0)*minf(speed/6.0,1.0)
	for side in ["L","R"]:
		var authored: Dictionary = weapon.authored_hand(side)
		if authored.is_empty(): continue
		var pole := skeleton.to_local(actor.to_global(Vector3(-0.42 if side=="L" else 0.46,1.04,0.04)))
		var wrist := skeleton.find_bone("Wrist."+side)
		var rest := skeleton.get_bone_global_rest(wrist)
		var middle := skeleton.get_bone_global_rest(skeleton.find_bone("Middle2."+side)).origin
		var rest_forward := (middle-rest.origin).normalized()
		var across := (skeleton.get_bone_global_rest(skeleton.find_bone("Index2."+side)).origin-skeleton.get_bone_global_rest(skeleton.find_bone("Pinky2."+side)).origin).normalized()
		across = (across-rest_forward*across.dot(rest_forward)).normalized()
		var source := Basis(rest_forward,across,rest_forward.cross(across))
		var delta_basis: Basis = (skeleton.global_basis.inverse()*authored.basis*source.inverse()).orthonormalized()
		var basis := delta_basis*rest.basis
		var target: Vector3 = skeleton.to_local(authored.palm)-delta_basis*(middle-rest.origin)*0.65
		IK.solve(skeleton,skeleton.find_bone("UpperArm."+side),skeleton.find_bone("LowerArm."+side),wrist,target,pole,aim_shoulder(side),basis,true)
		fit_fingers(weapon,side,delta_basis)

func aim_shoulder(side: String) -> Vector3:
	var chest := skeleton.find_bone("Chest")
	var upper := skeleton.find_bone("UpperArm."+side)
	var point := skeleton.get_bone_global_pose(chest)*skeleton.get_bone_global_rest(chest).affine_inverse()*skeleton.get_bone_global_rest(upper).origin
	if side == "L": point += skeleton.global_basis.inverse()*actor.global_basis*Vector3(0.05,0,-0.11)
	return point

func fit_fingers(weapon: Node3D, side: String, hand_delta: Basis) -> void:
	preload("res://tactical/hand_retarget.gd").fit_fingers(skeleton,weapon,side,hand_delta)
