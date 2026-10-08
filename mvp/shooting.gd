extends RefCounted

# Camera selects the intended target; the muzzle ray decides what can actually be hit.
static func cast(player: CharacterBody3D, yaw: float, pitch: float, spread := true) -> Dictionary:
	var spec = player.weapons.DATA[player.weapons.slot]
	var direction := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Vector3.FORWARD
	if spread:
		var cone: float = spec.moving_spread if Vector2(player.velocity.x, player.velocity.z).length() > 0.5 else spec.standing_spread
		if not player.animation_grounded(): cone = spec.airborne_spread
		cone += player.weapons.heat * spec.sustained_spread
		if player.is_aiming: cone *= spec.ads_spread_multiplier
		cone += spec.pellet_spread
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
		var angle := randf() * TAU
		var radius := sqrt(randf()) * cone
		direction = (direction + basis.x * cos(angle) * radius + basis.y * sin(angle) * radius).normalized()
	var camera_origin: Vector3 = player.camera.global_position
	var muzzle: Vector3 = player.get_node("WeaponController").muzzle(true).global_position
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(camera_origin, camera_origin + direction * spec.range, 3, [player.get_rid()])
	var aim := space.intersect_ray(query)
	var target: Vector3 = aim.position if not aim.is_empty() else query.to
	# A barrel pushed through nearby cover still cannot fire through that cover.
	query.to = muzzle
	query.collision_mask = 1
	var obstruction := space.intersect_ray(query)
	var hit: Dictionary
	if not obstruction.is_empty():
		hit = obstruction
	else:
		query.from = muzzle
		query.to = muzzle + (target - muzzle).normalized() * (muzzle.distance_to(target) + 0.02)
		query.collision_mask = 3
		hit = space.intersect_ray(query)
	var result := {"muzzle": muzzle, "point": target, "normal": Vector3.ZERO, "victim": 0, "head": false}
	if not hit.is_empty():
		result.point = hit.position
		result.normal = hit.normal
		if hit.collider.has_meta("fps_player"):
			result.victim = hit.collider.peer_id
			result.head = hit.collider.to_local(hit.position).y >= hit.collider.head_height
	return result
