extends Node3D

var collision_count := 0

func _ready() -> void:
	# The supplied GLB has no physics or lights. Build static mesh collision once
	# when the level enters the scene and keep lighting cheap for integrated GPUs.
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mesh_instance.create_trimesh_collision()
		collision_count += 1
	_add_corridor_lights()

func _add_corridor_lights() -> void:
	for index in 7:
		var light := OmniLight3D.new()
		light.name = "CorridorLight%d" % (index + 1)
		light.position = Vector3(0, 2.35, -33.0 + index * 11.0)
		light.light_color = Color("fff0c5")
		light.light_energy = 0.72
		light.omni_range = 11.0
		light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = 34.0
		light.distance_fade_length = 8.0
		add_child(light)

func prepare_navigation() -> void:
	if has_node("BotNavigation"): return
	var region := NavigationRegion3D.new()
	region.name = "BotNavigation"
	var nav := NavigationMesh.new()
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.agent_height = 2.0
	nav.agent_radius = 0.5
	region.navigation_mesh = nav
	var geometry := get_children()
	add_child(region)
	for child in geometry: child.reparent(region)
	region.bake_navigation_mesh(false)
