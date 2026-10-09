extends CharacterBody3D

const WeaponState = preload("res://mvp/weapons.gd")
@export var walk_speed := 6.0
@export var sprint_speed := 9.5
@export var jump_speed := 5.0
@export var gravity := 18.0
@export var acceleration := 28.0
@export var braking := 36.0
var hurt_kick := 0.0
var jump_buffer := 0.0
var coyote_time := 0.0
@export var head_height := 1.5
var last_shot_id := 0
var peer_id := 1
var player_name := "Player"
var character_id := 0
var team := -1
var throw_counts: Array = [1,1]
var throw_left := 0.0

func set_team(value: int) -> void:
	team = value
	$Name.modulate = Color("63b3ff") if team == 0 else (Color("ff7068") if team == 1 else Color.WHITE)

func set_character(value: int) -> void:
	value = preload("res://mvp/character_catalog.gd").valid_id(value)
	if character_id == value: return
	character_id = value
	$Body.set_character(value)
	for weapon in $Camera/ViewWeapon.get_children():
		weapon.set_character(value)
var kills := 0
var deaths := 0
var hp := 100
var ping := 0
var dead := false
var respawn_at := 0.0
var weapons = WeaponState.new()
var session: Node
var local_player := false
var controls := Vector2.ZERO
var sprint := false
var jump_pending := false
var yaw := 0.0
var pitch := 0.0
var input_age := 0.0
var target_position := Vector3.ZERO
var target_yaw := 0.0
var target_pitch := 0.0
var remote_velocity := Vector3.ZERO
var phase := 0.0
var step_clock := 0.0
var send_clock := 0.0
var last_packet := -1
var sequence := 0
var last_spawn := -1
var spawn_serial := 0
var remote_reload := 0.0
var was_grounded := true
var is_aiming := false
var is_scoped := false
var reload_timer: float:
	get: return weapons.reload_left if multiplayer.is_server() else remote_reload
var is_reloading: bool:
	get: return (weapons.reload_left if multiplayer.is_server() else remote_reload) > 0
@onready var camera: Camera3D = $Camera

func configure(id: int, nickname: String, net: Node) -> void:
	peer_id = id
	player_name = nickname
	session = net
	local_player = id == multiplayer.get_unique_id()
	set_meta("fps_player", true)
	$Name.text = nickname
	$Name.visible = not local_player
	$Body.visible = not local_player
	
	$Camera/ViewWeapon.visible = local_player
	camera.current = local_player
	if local_player:
		var throw_view := Node3D.new()
		throw_view.name = "ThrowView"
		throw_view.set_script(preload("res://mvp/throw_view.gd"))
		camera.add_child(throw_view)

func _input(event: InputEvent) -> void:
	if not local_player or dead or not session.app.input_enabled(): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_G: session.throwables.request(0)
		elif event.physical_keycode == KEY_H: session.throwables.request(1)
	if event is InputEventMouseMotion:
		var sensitivity: float = session.app.settings.sensitivity * (0.7 if is_aiming else 1.0)
		yaw -= event.relative.x * sensitivity
		pitch = clampf(pitch - event.relative.y * sensitivity, -1.45, 1.45)
	if event.is_action_pressed("jump"):
		jump_pending = true
		jump_buffer = 0.12

func _physics_process(delta: float) -> void:
	if not session: return
	if local_player:
		var enabled: bool = session.app.input_enabled() and not dead and not session.ended
		controls = Input.get_vector("move_left", "move_right", "move_forward", "move_back") if enabled else Vector2.ZERO
		sprint = enabled and Input.is_action_pressed("sprint") and controls.y < -0.3 and not is_reloading and not Input.is_action_pressed("aim")
		is_aiming = enabled and not sprint and not is_reloading and Input.is_action_pressed("aim")
		if not enabled: jump_pending = false
		send_clock -= delta
		if send_clock <= 0 or jump_pending:
			send_clock = 1.0 / 30.0
			sequence += 1
			if not multiplayer.is_server(): session.request_input.rpc_id(1, sequence, controls, yaw, pitch, sprint, jump_pending, is_aiming)
	if multiplayer.is_server() or local_player:
		if not local_player:
			input_age += delta
			if input_age > 0.3: controls = Vector2.ZERO
		if dead:
			velocity.x = move_toward(velocity.x,0,braking*delta)
			velocity.z = move_toward(velocity.z,0,braking*delta)
			velocity.y -= gravity*delta
			move_and_slide()
			jump_pending = false
			return
		if session.ended or not session.running:
			velocity = Vector3.ZERO
			jump_pending = false
			return
		rotation.y = yaw
		camera.rotation.x = pitch
		var dir := (Basis(Vector3.UP, yaw) * Vector3(controls.x, 0, controls.y)).limit_length(1)
		var speed := sprint_speed if sprint else walk_speed
		if is_aiming: speed *= weapons.DATA[weapons.slot].aim_move_scale
		var horizontal := Vector2(velocity.x, velocity.z).move_toward(Vector2(dir.x, dir.z) * speed, (braking if dir.length_squared() < 0.01 else acceleration) * (1.0 if is_on_floor() else 0.28) * delta)
		velocity.x = horizontal.x
		velocity.z = horizontal.y
		if not is_on_floor(): velocity.y -= gravity * delta
		coyote_time = 0.10 if is_on_floor() else maxf(0, coyote_time - delta)
		jump_buffer = 0.12 if jump_pending else maxf(0, jump_buffer - delta)
		if jump_buffer > 0 and coyote_time > 0:
			velocity.y = jump_speed
			coyote_time = 0
			jump_buffer = 0
			if local_player: session.app.audio.play("jump")
		jump_pending = false
		move_and_slide()
		if local_player and is_on_floor() and not was_grounded: session.app.audio.play("landing")
		was_grounded = is_on_floor()
		if multiplayer.is_server() and position.y < -12: session.damage(peer_id, peer_id, 100)

func _process(delta: float) -> void:
	if not session: return
	hurt_kick = move_toward(hurt_kick,0,delta*3.5)
	if local_player and not dead:
		rotation.y = yaw
		camera.rotation.x = pitch + sin(hurt_kick*PI)*0.018
	if local_player:
		camera.position.y = lerpf(camera.position.y, 0.4 if dead else (1.6 + sin(phase*2.0)*minf(0.012,Vector2(velocity.x,velocity.z).length()*0.002)*(0.2 if is_aiming else 1.0)), 1.0-exp(-7.0*delta))
		camera.rotation.z = lerpf(camera.rotation.z, 0.2 if dead else -controls.x*0.012, 1.0-exp(-7.0*delta))
	$Name.visible = not local_player and not dead
	if not local_player and not multiplayer.is_server():
		position = position.lerp(target_position, 1.0 - exp(-15.0 * delta))
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-18.0 * delta))
		camera.rotation.x = lerpf(camera.rotation.x, target_pitch, 1.0 - exp(-18.0 * delta))
	var motion := velocity if multiplayer.is_server() or local_player else remote_velocity
	var speed := Vector2(motion.x, motion.z).length()
	phase += delta * speed * 1.25
	$Camera/ViewWeapon.visible = local_player and not dead
	$WeaponController.update_models()
	if speed > 1 and not dead and (is_on_floor() if local_player or multiplayer.is_server() else absf(motion.y) < 0.1):
		step_clock -= delta
		if step_clock <= 0:
			step_clock = 0.3 if speed > 6 else 0.45
			session.app.audio.play("step", global_position if not local_player else Vector3.INF)

func snapshot(clock: float) -> Dictionary:
	return {"id": peer_id, "name": player_name, "character":character_id, "team":team, "pos": position, "vel": velocity, "yaw": yaw, "pitch": pitch,
		"throw_counts": throw_counts, "throw_left": throw_left, "hp": hp, "dead": dead, "kills": kills, "deaths": deaths, "ping": ping, "slot": weapons.slot,
		"ammo": weapons.ammo, "reserve": weapons.reserve, "reload": weapons.reload_left,
		"respawn": maxf(0, respawn_at - clock), "spawn": spawn_serial, "ack": last_shot_id, "ads": is_aiming, "sprint": sprint, "heat": weapons.heat}

func apply_snapshot(state: Dictionary) -> void:
	set_character(int(state.get("character",0)))
	set_team(int(state.get("team",-1)))
	var teleport: bool = last_spawn != state.spawn or position.distance_to(state.pos) > 3.0
	if teleport:
		position = state.pos
		velocity = state.vel
		if last_spawn != state.spawn:
			$WeaponController.reset_state()
			yaw = state.yaw
			pitch = state.pitch
			rotation.y = yaw
			camera.rotation.x = pitch
	elif local_player:
		# Small server corrections preserve local input responsiveness.
		if position.distance_to(state.pos) > 0.18: position = position.lerp(state.pos, 0.25)
	target_position = state.pos
	target_yaw = state.yaw
	target_pitch = state.pitch
	remote_velocity = state.vel
	if not local_player: velocity = state.vel
	throw_counts = state.get("throw_counts",[1,1])
	throw_left = state.get("throw_left",0.0)
	hp = state.hp
	if state.dead and not dead:
		$Body.fall()
		$WeaponController.reset_state()
	if not state.dead and dead: _restore_body()
	dead = state.dead
	kills = state.kills
	deaths = state.deaths
	ping = state.ping
	weapons.slot = state.slot
	weapons.ammo = state.ammo
	weapons.reserve = state.reserve
	remote_reload = state.reload
	weapons.heat = state.heat
	$WeaponController.reconcile(state.ack)
	if not local_player:
		is_aiming = state.ads
		sprint = state.sprint
	respawn_at = state.respawn
	last_spawn = state.spawn
	$Camera/ViewWeapon.visible = local_player and not dead
	collision_layer = 0 if dead else 2
	$Name.visible = not local_player and not dead

func reset_at(point: Transform3D) -> void:
	transform = point
	yaw = rotation.y
	pitch = 0
	camera.rotation.x = 0
	velocity = Vector3.ZERO
	controls = Vector2.ZERO
	jump_pending = false
	jump_buffer = 0
	coyote_time = 0
	camera.position.y = 1.6
	camera.rotation.z = 0
	throw_counts = [1,1]
	throw_left = 0.0
	hp = 100
	hurt_kick = 0
	dead = false
	_restore_body()
	respawn_at = 0
	weapons = WeaponState.new()
	sprint = false
	remote_reload = 0
	$WeaponController.reset_state()
	spawn_serial += 1
	collision_layer = 2
	$Camera/ViewWeapon.visible = local_player

func get_reload_duration() -> float:
	return weapons.DATA[weapons.slot].reload

func animation_grounded() -> bool:
	return is_on_floor() if multiplayer.is_server() or local_player else absf(remote_velocity.y) < 0.1

func _restore_body() -> void:
	$Body.restore()
