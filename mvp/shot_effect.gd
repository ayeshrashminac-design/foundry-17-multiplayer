extends Node3D

# Fixed pools: 32 tracer/impact pairs and 24 casings per calibre. No physical bullets.
const CASINGS = [preload("res://assets/shooter_essentials/Bullet_556_V1_Shell.glb"), preload("res://assets/shooter_essentials/Bullet_9_V1_Shell.glb")]
var shots: Array[Dictionary] = []
var shells: Array[Array] = [[], [], []]
var shot_cursor := 0
var shell_cursor := [0, 0, 0]

func _ready() -> void:
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.008
	beam_mesh.bottom_radius = 0.008
	beam_mesh.height = 1
	beam_mesh.radial_segments = 4
	var hit_mesh := SphereMesh.new()
	hit_mesh.radius = 0.035
	hit_mesh.height = 0.07
	hit_mesh.radial_segments = 6
	hit_mesh.rings = 3
	var beam_mat := _material(Color(1, 0.77, 0.3))
	var hit_mat := _material(Color(1, 0.55, 0.2))
	for i in 32:
		var beam := MeshInstance3D.new()
		beam.mesh = beam_mesh
		beam.material_override = beam_mat
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(beam)
		beam.hide()
		var impact := MeshInstance3D.new()
		impact.mesh = hit_mesh
		impact.material_override = hit_mat
		impact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		impact.scale = Vector3(1,1,0.18)
		add_child(impact)
		impact.hide()
		shots.append({"beam":beam,"impact":impact,"age":1.0,"origin":Vector3.ZERO,"direction":Vector3.FORWARD,"distance":0.0})
	for slot in 3:
		for i in 24:
			var shell: Node3D
			if slot < 2: shell = CASINGS[slot].instantiate()
			else:
				var mesh := MeshInstance3D.new()
				var casing := CylinderMesh.new()
				casing.top_radius=0.009
				casing.bottom_radius=0.009
				casing.height=0.06
				casing.radial_segments=6
				mesh.mesh=casing
				mesh.material_override=_material(Color(0.65,0.05,0.025))
				shell=mesh
			add_child(shell)
			shell.hide()
			shells[slot].append({"node":shell,"age":2.0,"velocity":Vector3.ZERO,"spin":Vector3.ZERO})
	set_process(false)

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	return mat

func emit(origin: Vector3, point: Vector3, normal: Vector3, eject: Transform3D, slot: int, casing: bool) -> void:
	var entry: Dictionary = shots[shot_cursor]
	shot_cursor = (shot_cursor + 1) % shots.size()
	entry.age = 0.0
	entry.origin = origin
	entry.distance = origin.distance_to(point)
	entry.direction = (point-origin).normalized() if entry.distance > 0.001 else Vector3.FORWARD
	entry.beam.visible = entry.distance > 0.01
	entry.beam.quaternion = Quaternion(Vector3.UP, entry.direction)
	entry.beam.position = origin
	entry.beam.scale.y = 0.01
	entry.impact.visible = normal.length_squared() > 0.1
	if entry.impact.visible:
		entry.impact.position = point + normal*0.012
		entry.impact.quaternion = Quaternion(Vector3.FORWARD, normal)
	if casing:
		var shell: Dictionary = shells[slot][shell_cursor[slot]]
		shell_cursor[slot] = (shell_cursor[slot]+1) % shells[slot].size()
		shell.node.global_transform = eject
		shell.node.show()
		shell.age = 0.0
		shell.velocity = eject.basis.x.normalized()*randf_range(1.6,2.7) + Vector3.UP*randf_range(1.1,1.8) + eject.basis.z.normalized()*0.4
		shell.spin = Vector3(randf_range(3,8),randf_range(4,9),randf_range(2,7))
	set_process(true)

func _process(delta: float) -> void:
	var busy := false
	for entry in shots:
		if entry.age >= 0.18: continue
		busy = true
		entry.age += delta
		var front: float = minf(entry.distance, entry.age*2200)
		var back := maxf(0,front-4)
		entry.beam.position = entry.origin + entry.direction*(front+back)*0.5
		entry.beam.scale.y = maxf(0.01,front-back)
		entry.beam.visible = entry.age < 0.055 and entry.distance > 0.01
		if entry.age >= 0.18: entry.impact.hide()
	for group in shells:
		for shell in group:
			if shell.age >= 1.2: continue
			busy = true
			shell.age += delta
			shell.velocity.y -= 9.8*delta
			shell.node.position += shell.velocity*delta
			shell.node.rotation += shell.spin*delta
			if shell.age >= 1.2: shell.node.hide()
	if not busy: set_process(false)

func clear() -> void:
	for entry in shots:
		entry.age = 1.0
		entry.beam.hide()
		entry.impact.hide()
	for group in shells:
		for shell in group:
			shell.age = 2.0
			shell.node.hide()
	set_process(false)
