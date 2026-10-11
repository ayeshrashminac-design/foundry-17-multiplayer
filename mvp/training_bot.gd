extends Node

# Only the server runs bot decisions; snapshots replicate the resulting player state.
var actor: CharacterBody3D
var agent: NavigationAgent3D
var target: CharacterBody3D
var think := 0.0
var trigger := 0.6
var reaction := 0.5
var weapon_think := 0.0
var stuck_time := 0.0
var last_position := Vector3.ZERO
var observed_spawn := -1

func _ready() -> void:
	actor = get_parent()
	process_physics_priority = -10
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.5
	agent.target_desired_distance = 0.8
	agent.path_desired_distance = 0.8
	last_position = actor.global_position
	actor.add_child(agent)

func _physics_process(delta: float) -> void:
	var net = actor.session
	if not multiplayer.is_server(): return
	if observed_spawn != actor.spawn_serial:
		observed_spawn = actor.spawn_serial
		target = null
		think = 0.0
		stuck_time = 0.0
		last_position = actor.global_position
	actor.input_age = 0
	actor.controls = Vector2.ZERO
	if actor.dead or not net.running:
		actor.sprint = false
		actor.is_aiming = false
		return
	think -= delta
	trigger -= delta
	reaction -= delta
	weapon_think -= delta
	if think <= 0:
		think = 0.35
		var nearest: CharacterBody3D = null
		var distance := INF
		for candidate in net.players.values():
			if candidate == actor or candidate.dead: continue
			if net.game_mode == "tdm" and candidate.team == actor.team: continue
			var gap := actor.global_position.distance_squared_to(candidate.global_position)
			# Prefer an enemy we can actually engage over one behind a nearby wall.
			if _can_see(candidate): gap *= 0.15
			if candidate == target: gap *= 0.8
			if gap < distance:
				distance = gap
				nearest = candidate
		if nearest != target: reaction = 0.55
		target = nearest
		if is_instance_valid(target): agent.target_position = target.global_position
	if not is_instance_valid(target) or target.dead:
		actor.sprint = false
		actor.is_aiming = false
		return
	var offset := target.global_position - actor.global_position
	var aim := atan2(-offset.x, -offset.z)
	actor.yaw = lerp_angle(actor.yaw, aim, 1.0 - exp(-6.0 * delta))
	actor.pitch = atan2(offset.y - 0.3, maxf(Vector2(offset.x, offset.z).length(), 0.01))
	var origin := actor.global_position + Vector3(0, 1.6, 0)
	var query := PhysicsRayQueryParameters3D.create(origin, target.global_position + Vector3(0, 1.3, 0), 3, [actor.get_rid()])
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	var visible: bool = not hit.is_empty() and hit.collider == target and not net.throwables.obscures(origin,target.global_position+Vector3.UP)
	var distance := offset.length()
	if weapon_think <= 0.0:
		weapon_think = 0.45
		var rifle_available: bool = actor.weapons.ammo[0] + actor.weapons.reserve[0] > 0
		var pistol_available: bool = actor.weapons.ammo[1] + actor.weapons.reserve[1] > 0
		var desired_slot := 1 if distance < 8.0 and pistol_available else 0
		if not rifle_available and pistol_available: desired_slot = 1
		if desired_slot != actor.weapons.slot and not actor.is_reloading:
			net._queue_action(actor.peer_id, 2, desired_slot, actor.yaw, actor.pitch)
			trigger = maxf(trigger, 0.3)
	if NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) > 0:
		# Advance the path before checking completion, including after a new target.
		var next := agent.get_next_path_position()
		if not agent.is_navigation_finished() and (not visible or distance > 12.0):
			var direction := next - actor.global_position
			direction.y = 0.0
			# Separate teammates at narrow doors rather than pushing the same waypoint.
			var separation := Vector3.ZERO
			for other in net.players.values():
				if other == actor or other.dead: continue
				var away: Vector3 = actor.global_position - other.global_position
				away.y = 0.0
				if away.length() > 0.01 and away.length() < 1.1:
					separation += away.normalized() * (1.1 - away.length())
			direction = (direction.normalized() + separation * 1.2).normalized()
			var local_direction := Basis(Vector3.UP, actor.yaw).inverse() * direction
			actor.controls = Vector2(local_direction.x, local_direction.z)
	if actor.controls.length_squared() > 0.1 and actor.global_position.distance_to(last_position) < 0.005:
		stuck_time += delta
	else: stuck_time = maxf(0.0, stuck_time - delta * 2.0)
	last_position = actor.global_position
	if stuck_time > 0.8:
		actor.controls.x = 0.8 if absi(actor.peer_id) % 2 == 0 else -0.8
		actor.controls = actor.controls.normalized()
		if stuck_time > 1.6:
			think = 0.0
			stuck_time = 0.0
	actor.sprint = actor.controls.length_squared() > 0.1 and distance > 16.0 and not visible
	actor.is_aiming = visible and distance < 28.0 and reaction <= 0.0 and not actor.sprint and not actor.is_reloading
	if actor.weapons.ammo[actor.weapons.slot] == 0:
		if actor.weapons.reserve[actor.weapons.slot] > 0:
			net._queue_action(actor.peer_id, 1, actor.weapons.slot, actor.yaw, actor.pitch)
	elif visible and offset.length() < 28 and reaction <= 0 and trigger <= 0 and absf(angle_difference(actor.yaw, aim)) < 0.15:
		var spec = actor.weapons.DATA[actor.weapons.slot]
		trigger = randf_range(maxf(spec.interval, 0.18), maxf(spec.interval + 0.18, 0.36))
		net._queue_action(actor.peer_id, 0, actor.weapons.slot, actor.yaw + randf_range(-0.055, 0.055), actor.pitch + randf_range(-0.035, 0.035))

func _can_see(candidate: CharacterBody3D) -> bool:
	var origin := actor.global_position + Vector3(0, 1.6, 0)
	var end := candidate.global_position + Vector3(0, 1.3, 0)
	var query := PhysicsRayQueryParameters3D.create(origin, end, 3, [actor.get_rid()])
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == candidate and not actor.session.throwables.obscures(origin, end)
