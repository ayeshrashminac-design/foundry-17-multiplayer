@tool
extends MeshInstance3D

## Turning this off allows a deliberately different collision shape.
@export var collision_follows_mesh := true
var observed_mesh: Mesh

func _ready() -> void:
	_watch_mesh()
	set_process(Engine.is_editor_hint())

func _process(_delta: float) -> void:
	if observed_mesh != mesh: _watch_mesh()

func _watch_mesh() -> void:
	if observed_mesh and observed_mesh.changed.is_connected(_sync_collision):
		observed_mesh.changed.disconnect(_sync_collision)
	observed_mesh = mesh
	if mesh: mesh.changed.connect(_sync_collision)
	_sync_collision()

func _sync_collision() -> void:
	if not collision_follows_mesh or not mesh is BoxMesh: return
	var collider := get_node_or_null("StaticBody/CollisionShape") as CollisionShape3D
	if collider and collider.shape is BoxShape3D and collider.shape.size != mesh.size:
		collider.shape = collider.shape.duplicate()
		collider.shape.size = mesh.size
