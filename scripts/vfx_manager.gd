extends Node

# Visual Effects Spawner (Sparks, Plasma Bursts, Explosions, Slime Splatters, Smoke)

func spawn_sparks(pos: Vector3, normal: Vector3 = Vector3.UP, color: Color = Color(1.0, 0.7, 0.2)) -> void:
	var root = get_tree().current_scene
	if not root:
		return
	var particles = CPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.4
	particles.amount = 14
	particles.direction = normal + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
	particles.spread = 45.0
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 9.0
	particles.gravity = Vector3(0, -9.8, 0)
	particles.scale_amount_min = 0.04
	particles.scale_amount_max = 0.09
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	particles.material_override = mat
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 0.12)
	particles.mesh = mesh
	
	root.add_child(particles)
	particles.global_position = pos
	
	var t = root.get_tree().create_timer(0.6)
	t.timeout.connect(particles.queue_free)

func spawn_alien_blood(pos: Vector3, normal: Vector3 = Vector3.UP, is_acid: bool = false) -> void:
	var root = get_tree().current_scene
	if not root:
		return
	var particles = CPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 0.5
	particles.amount = 18
	particles.direction = normal
	particles.spread = 60.0
	particles.initial_velocity_min = 3.0
	particles.initial_velocity_max = 7.0
	particles.gravity = Vector3(0, -12.0, 0)
	particles.scale_amount_min = 0.06
	particles.scale_amount_max = 0.14
	
	var col = Color(0.1, 1.0, 0.2) if is_acid else Color(0.7, 0.0, 0.9)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.5
	mat.roughness = 0.1
	particles.material_override = mat
	
	var mesh = SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	particles.mesh = mesh
	
	root.add_child(particles)
	particles.global_position = pos
	
	var t = root.get_tree().create_timer(0.7)
	t.timeout.connect(particles.queue_free)

func spawn_explosion(pos: Vector3, radius: float = 4.0, is_plasma: bool = true) -> void:
	var root = get_tree().current_scene
	if not root:
		return
		
	var col = Color(0.0, 0.9, 1.0) if is_plasma else Color(1.0, 0.4, 0.1)
	
	# Light flash
	var light = OmniLight3D.new()
	light.light_color = col
	light.light_energy = 8.0
	light.omni_range = radius * 3.5
	root.add_child(light)
	light.global_position = pos
	
	# Blast Sphere Mesh
	var sphere = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.6
	sphere.mesh = sm
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(col.r, col.g, col.b, 0.8)
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 5.0
	sphere.material_override = mat
	root.add_child(sphere)
	sphere.global_position = pos
	
	# Particles
	var particles = CPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.6
	particles.amount = 30
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 6.0
	particles.initial_velocity_max = 14.0
	particles.scale_amount_min = 0.1
	particles.scale_amount_max = 0.25
	particles.material_override = mat
	particles.mesh = sm
	root.add_child(particles)
	particles.global_position = pos
	
	# Tween animate explosion shockwave
	var tween = root.create_tween()
	tween.tween_property(sphere, "scale", Vector3.ONE * radius * 2.0, 0.35)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tween.parallel().tween_property(light, "light_energy", 0.0, 0.4)
	tween.tween_callback(sphere.queue_free)
	tween.tween_callback(light.queue_free)
	
	var t = root.get_tree().create_timer(0.8)
	t.timeout.connect(particles.queue_free)
