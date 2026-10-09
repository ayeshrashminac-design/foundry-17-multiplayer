extends Node3D
# Host simulates flight, fuse and damage; clients render the replicated state.
const FUSE := 2.5
const SMOKE_SECONDS := 12.0
const RADIUS := 3.6
var net: Node
var items: Dictionary = {}
var visuals: Dictionary = {}
var sequence := 0
var awaiting: Array[Dictionary] = []
var overlay: ColorRect

func _ready() -> void:
	net = get_parent()
	process_physics_priority = 110
	overlay = ColorRect.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.48,0.51,0.52,0)
	net.app.get_node("UI").add_child.call_deferred(overlay)

func request(kind: int) -> void:
	if multiplayer.is_server(): _begin(1,kind)
	else: request_throw.rpc_id(1,kind)

@rpc("any_peer", "call_remote", "reliable", 0)
func request_throw(kind: int) -> void:
	if multiplayer.is_server(): _begin(multiplayer.get_remote_sender_id(),kind)

func _begin(id: int, kind: int) -> bool:
	if not net.running or net.ended or kind not in [0,1] or not net.players.has(id): return false
	var p = net.players[id]
	if p.dead or p.throw_left > 0 or p.is_reloading or p.throw_counts[kind] <= 0: return false
	p.throw_counts[kind] -= 1
	p.throw_left = 0.9
	p.is_aiming = false
	awaiting.append({"id":id,"kind":kind,"release":net.clock+0.35,"spawn":p.spawn_serial})
	return true

func clear() -> void:
	items.clear()
	awaiting.clear()
	for visual in visuals.values(): visual.queue_free()
	visuals.clear()
	if is_instance_valid(overlay): overlay.color.a = 0

func _physics_process(delta: float) -> void:
	if not net.active: return
	if multiplayer.is_server():
		for p in net.players.values(): p.throw_left = maxf(0,p.throw_left-delta)
		for pending in awaiting.duplicate():
			if net.clock < pending.release: continue
			awaiting.erase(pending)
			var p = net.players.get(pending.id)
			if not is_instance_valid(p) or p.dead or p.spawn_serial != pending.spawn or not net.running: continue
			sequence += 1
			var direction: Vector3 = -p.camera.global_basis.z
			items[sequence] = {"id":sequence,"owner":p.peer_id,"kind":pending.kind,"pos":p.camera.global_position,"vel":direction*13+Vector3.UP*3,"left":FUSE,"smoke":false}
		for id in items.keys():
			var item: Dictionary = items[id]
			item.left -= delta
			if item.left <= 0:
				if item.smoke:
					items.erase(id)
				elif item.kind == 1:
					item.smoke = true
					item.left = SMOKE_SECONDS
					item.vel = Vector3.ZERO
				else:
					_explode(item)
					items.erase(id)
				continue
			if item.smoke: continue
			item.vel += Vector3.DOWN*15*delta
			var query := PhysicsRayQueryParameters3D.create(item.pos,item.pos+item.vel*delta,1)
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty(): item.pos += item.vel*delta
			else:
				item.pos = hit.position+hit.normal*0.08
				item.vel = item.vel.bounce(hit.normal)*0.42
		_render(delta)

func _explode(item: Dictionary) -> void:
	for id in net.players:
		var p = net.players[id]
		if p.dead: continue
		var center: Vector3 = p.global_position+Vector3.UP
		var distance: float = center.distance_to(item.pos)
		if distance > 5.0: continue
		var query := PhysicsRayQueryParameters3D.create(item.pos,center,1)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		net.damage(item.owner,id,int(120*(1.0-distance/5.0)))
	if net.training: burst(item.pos)
	else: burst.rpc(item.pos)

@rpc("authority", "call_local", "reliable", 0)
func burst(point: Vector3) -> void:
	net.app.audio.play("explosion",point)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1,0.55,0.15)
	flash.light_energy = 5
	flash.omni_range = 7
	add_child(flash)
	flash.global_position = point
	var puff := _mesh(false)
	add_child(puff)
	puff.global_position = point
	puff.material_override = _material(Color(1,0.45,0.08,0.8))
	var tween := create_tween().set_parallel(true)
	tween.tween_property(flash,"light_energy",0.0,0.3)
	tween.tween_property(puff,"scale",Vector3.ONE*22,0.35)
	tween.tween_property(puff.material_override,"albedo_color:a",0.0,0.35)
	tween.chain().tween_callback(func(): flash.queue_free(); puff.queue_free())

func snapshot() -> Array:
	return items.values()

func sync(state: Array) -> void:
	items.clear()
	for item in state: items[item.id] = item

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if color.a < 1:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func _mesh(smoke: bool) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = RADIUS if smoke else 0.075
	shape.height = shape.radius*2
	shape.radial_segments = 16
	shape.rings = 8
	mesh.mesh = shape
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.material_override = _material(Color(0.48,0.51,0.52,0.91) if smoke else Color(0.18,0.23,0.1))
	return mesh

func _render(delta: float) -> void:
	for id in visuals.keys():
		if not items.has(id) or visuals[id].get_meta("smoke") != items[id].smoke:
			visuals[id].queue_free()
			visuals.erase(id)
	var density := 0.0
	var local = net.players.get(multiplayer.get_unique_id())
	for id in items:
		var item: Dictionary = items[id]
		if not visuals.has(id):
			var mesh := _mesh(item.smoke)
			mesh.set_meta("smoke",item.smoke)
			add_child(mesh)
			mesh.global_position = item.pos
			visuals[id] = mesh
		visuals[id].global_position = visuals[id].global_position.lerp(item.pos,1-exp(-25*delta))
		if item.smoke:
			var growth: float = clampf((SMOKE_SECONDS-item.left)*2,0.05,1)*clampf(item.left/2,0,1)
			visuals[id].scale = Vector3.ONE*growth
			if is_instance_valid(local) and not local.dead:
				density = maxf(density,clampf((RADIUS*growth-local.camera.global_position.distance_to(item.pos))*2,0,0.97))
	overlay.color.a = density

func obscures(from: Vector3, to: Vector3) -> bool:
	for item in items.values():
		if not item.smoke: continue
		var closest := Geometry3D.get_closest_point_to_segment(item.pos,from,to)
		if closest.distance_to(item.pos) < RADIUS: return true
	return false
