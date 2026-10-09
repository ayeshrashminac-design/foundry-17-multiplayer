extends Node

const Shooting = preload("res://mvp/shooting.gd")
@export_node_path("Camera3D") var aim_reference := NodePath("../Camera")
@onready var actor = get_parent()
@onready var view: Node3D = actor.get_node("Camera/ViewWeapon")
var cooldown := 0.0
var recoil := 0.0
var flash := 0.0
var shot_id := 0
var pending: Dictionary = {}
var click_pending := false
var require_release := false
var reload_lock := 0.0
var switch_slot := -1
var switch_wait := 0.0
var base_fov := 80.0
var last_slot := -1
var equip_time := 0.0
var extra_models: Dictionary = {}
var sway := Vector2.ZERO
var previous_yaw := 0.0
var previous_pitch := 0.0
var motion_blend := 0.0
var landing := 0.0
var was_airborne := false
var idle_clock := 0.0
var wall_blend := 0.0

func _ready() -> void:
	process_priority = 10
	process_physics_priority = 50
	base_fov = get_node(aim_reference).fov
	update_models()

func model(first_person: bool, slot: int = -1) -> Node3D:
	if slot < 0: slot = actor.weapons.slot
	var key := slot * 2 + int(first_person)
	if not extra_models.has(key):
		var mount: Node3D = view if first_person else actor.get_node("Body/WeaponMount")
		extra_models[key] = mount.get_node("Weapon" + str(slot))
	return extra_models[key]

func update_models() -> void:
	view.visible = actor.local_player and not actor.dead and actor.throw_left <= 0
	for first in [true,false]:
		for index in actor.weapons.DATA.size():
			var weapon = model(first,index)
			weapon.visible = index == actor.weapons.slot and not actor.dead

func muzzle(authoritative_view := false) -> Marker3D:
	return model(authoritative_view or actor.local_player).get_node("MuzzlePoint")

func available_ammo() -> int:
	var count: int = actor.weapons.ammo[actor.weapons.slot]
	for item in pending.values():
		if item.slot == actor.weapons.slot: count -= 1
	return maxi(0, count)

func reconcile(ack: int) -> void:
	for id in pending.keys():
		if id <= ack: pending.erase(id)

func reset_state() -> void:
	pending.clear()
	cooldown = 0
	reload_lock = 0
	switch_slot = -1
	recoil = 0
	flash = 0
	click_pending = false
	require_release = true
	actor.is_aiming = false

func _input(event: InputEvent) -> void:
	if not actor.local_player or not actor.session or actor.dead or not actor.session.app.input_enabled(): return
	if event.is_action_pressed("shoot") and not event.is_echo(): click_pending = true
	for index in actor.weapons.DATA.size():
		if event.is_action_pressed("slot_"+str(index+1)): switch_weapon(index)
	if event.is_action_pressed("reload"):
		var spec = actor.weapons.DATA[actor.weapons.slot]
		if available_ammo() < spec.magazine and actor.weapons.reserve[actor.weapons.slot] > 0 and not actor.is_reloading and reload_lock <= 0:
			reload_lock = spec.reload
			click_pending = false
			actor.session.action(1, actor.weapons.slot, actor.yaw, actor.pitch)

func switch_weapon(slot: int) -> void:
	if slot < 0 or slot >= actor.weapons.DATA.size() or slot == actor.weapons.slot: return
	require_release = true
	click_pending = false
	reload_lock = 0
	cooldown = actor.weapons.DATA[slot].switch_delay
	switch_slot = slot
	switch_wait = 1.0
	actor.session.action(2, slot, actor.yaw, actor.pitch)
	actor.session.app.audio.play("click")

func _physics_process(delta: float) -> void:
	if not actor.session: return
	cooldown = maxf(0, cooldown - delta)
	reload_lock = maxf(0, reload_lock - delta)
	switch_wait -= delta
	if switch_slot == actor.weapons.slot or switch_wait <= 0: switch_slot = -1
	for id in pending.keys():
		if Time.get_ticks_msec() - pending[id].time > 2000: pending.erase(id)
	if not actor.local_player: return
	if not Input.is_action_pressed("shoot"): require_release = false
	var enabled: bool = actor.session.app.input_enabled() and not actor.dead and not actor.session.ended
	if not enabled or actor.throw_left > 0:
		click_pending = false
		require_release = true
		return
	var spec = actor.weapons.DATA[actor.weapons.slot]
	var trigger: bool = Input.is_action_pressed("shoot") if spec.automatic else click_pending
	click_pending = false
	if not trigger or require_release or cooldown > 0 or reload_lock > 0 or actor.is_reloading or actor.sprint or switch_slot >= 0: return
	if available_ammo() <= 0:
		cooldown = 0.3
		actor.session.app.audio.play("empty", muzzle().global_position)
		return
	cooldown = spec.interval
	shot_id += 1
	pending[shot_id] = {"slot": actor.weapons.slot, "time": Time.get_ticks_msec()}
	var aim_yaw: float = actor.yaw
	var aim_pitch: float = actor.pitch
	# Prediction is cosmetic only; the server sends the final impact and damage.
	var preview := Shooting.cast(actor, aim_yaw, aim_pitch, false)
	feedback(preview.point, Vector3.ZERO, actor.weapons.slot, true)
	actor.session.action(0, actor.weapons.slot, aim_yaw, aim_pitch, shot_id)
	var multiplier: float = (1.0 + minf(5, actor.weapons.heat) * 0.12 if spec.automatic else 1.0) * model(true).recoil_factor()
	actor.pitch = clampf(actor.pitch + spec.camera_recoil * multiplier, -1.45, 1.45)
	actor.yaw += randf_range(-spec.horizontal_recoil, spec.horizontal_recoil)

func feedback(point: Vector3, normal: Vector3, slot: int, play_feedback: bool) -> void:
	if play_feedback:
		if model(actor.local_player, slot).has_method("fire"): model(actor.local_player, slot).fire()
		flash = 0.055
		recoil = minf(0.15, recoil + actor.weapons.DATA[slot].visual_recoil * model(actor.local_player, slot).recoil_factor())
		actor.get_node("Body").kick()
		var source: AudioStreamPlayer3D = model(actor.local_player, slot).get_node("MuzzlePoint/AudioSource")
		source.stream = load("res://tactical/assets/"+actor.weapons.DATA[slot].sound+"_shot.wav")
		source.play()
	var weapon = model(actor.local_player, slot)
	actor.session.app.get_node("WeaponEffects").emit(weapon.get_node("MuzzlePoint").global_position if play_feedback else point, point, normal, weapon.get_node("ShellEjectPoint").global_transform, actor.weapons.DATA[slot].casing_type, play_feedback)

func _process(delta: float) -> void:
	if not actor.session: return
	view.visible = actor.local_player and not actor.dead and actor.throw_left <= 0
	flash = maxf(0, flash - delta)
	recoil = lerpf(recoil, 0.0, 1.0-exp(-14.0*delta))
	var spec = actor.weapons.DATA[actor.weapons.slot]
	if last_slot != actor.weapons.slot:
		flash = 0
		last_slot = actor.weapons.slot
		equip_time = spec.switch_delay
	equip_time = maxf(0, equip_time - delta)
	var speed := Vector2(actor.velocity.x,actor.velocity.z).length()
	var damping := 1.0-exp(-spec.ads_speed*delta)
	var target: Vector3 = spec.ads_position if actor.is_aiming else spec.hip_position
	# Keep the first-person weapon and arms out of nearby level geometry.
	# The player capsule stops the body, while this camera ray retracts the visual rig.
	var wall_target := 0.0
	if actor.local_player and actor.camera.is_inside_tree():
		var ray_from: Vector3 = actor.camera.global_position
		var ray_to: Vector3 = ray_from + -actor.camera.global_basis.z * 1.4
		var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1, [actor.get_rid()])
		query.hit_from_inside = true
		var obstruction: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(query)
		if not obstruction.is_empty():
			var distance: float = ray_from.distance_to(obstruction.position)
			wall_target = clampf((1.2-distance)/0.9,0.0,1.0)
	wall_blend = lerpf(wall_blend,wall_target,1.0-exp(-18.0*delta))
	target += Vector3(0.07*wall_blend,-0.22*wall_blend,0.9*wall_blend)
	idle_clock += delta
	var grounded: bool = actor.animation_grounded()
	if grounded and was_airborne: landing = 0.035
	was_airborne = not grounded
	landing = lerpf(landing,0.0,1.0-exp(-10.0*delta))
	motion_blend = lerpf(motion_blend,minf(speed/5.0,1.0) if grounded else 0.0,1.0-exp(-8.0*delta))
	var bob := Vector3(sin(actor.phase)*0.012,sin(actor.phase*2.0)*0.009,-cos(actor.phase)*0.006)*motion_blend
	bob.y += sin(idle_clock*1.7)*0.0015-landing
	bob.y -= clampf(actor.velocity.y*0.003,-0.02,0.02)
	if actor.is_aiming: bob *= 0.12
	var turn := Vector2(angle_difference(previous_yaw,actor.yaw),actor.pitch-previous_pitch)
	previous_yaw = actor.yaw
	previous_pitch = actor.pitch
	sway = sway.lerp(Vector2(clampf(-turn.y/maxf(delta,0.001)*0.016,-0.07,0.07),clampf(-turn.x/maxf(delta,0.001)*0.016,-0.07,0.07)),1.0-exp(-12.0*delta))
	if actor.sprint: target += Vector3(0.01,-0.035,0.015)
	if switch_slot >= 0 or equip_time > 0: target.y -= 0.22 * (1.0 if switch_slot >= 0 else equip_time/maxf(spec.switch_delay,0.01))
	var reload_blend: float = sin(clampf(1.0-actor.reload_timer/spec.reload,0,1)*PI) if actor.is_reloading else 0.0
	target += Vector3(-0.025,-0.065,0.04)*reload_blend
	if actor.throw_left > 0: target += Vector3(0,-0.45,0.15) * sin((1-actor.throw_left/0.9)*PI)
	view.position = view.position.lerp(target+bob+Vector3(0,0,recoil),damping)
	var rotation_target := Vector3(recoil*0.8+sway.x-0.26*wall_blend,sway.y+0.12*wall_blend,-0.08*reload_blend+sin(actor.phase)*motion_blend*0.012+0.10*wall_blend)
	if actor.is_aiming: rotation_target *= 0.12
	view.rotation = view.rotation.lerp(rotation_target,1.0-exp(-18.0*delta))
	if actor.local_player: actor.camera.fov = lerpf(actor.camera.fov,spec.ads_fov if actor.is_aiming else (base_fov+5.0 if actor.sprint else base_fov),damping)
	for first in [true, false]:
		for index in [actor.weapons.slot]:
			var weapon = model(first, index)
			var reload_amount: float = sin(clampf(1.0 - actor.reload_timer / spec.reload,0,1)*PI) if actor.is_reloading and index == actor.weapons.slot else 0.0
			weapon.animate(reload_amount, recoil if index == actor.weapons.slot else 0.0)
			var point = model(first, index).get_node("MuzzlePoint")
			var active: bool = flash > 0 and not actor.dead and index == actor.weapons.slot and first == actor.local_player
			point.get_node("MuzzleFlash").visible = active
			point.get_node("FlashLight").light_energy = 1.4 if active else 0.0


