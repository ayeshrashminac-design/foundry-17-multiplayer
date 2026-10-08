extends Node3D

## The saved scene is authoritative. This script never creates map geometry.
@export var rebake_navigation_on_start := true
@export_node_path("Marker3D") var player_spawn_path := NodePath("PlayerSpawn")
var navigation_ready := false
@onready var geometry: NavigationRegion3D = $ArenaNavigation
var player_spawn: Vector3:
	get:
		var marker := get_node_or_null(player_spawn_path) as Marker3D
		return marker.global_position if marker else global_position

func _ready() -> void:
	if rebake_navigation_on_start:
		geometry.bake_finished.connect(_navigation_finished, CONNECT_ONE_SHOT)
		geometry.bake_navigation_mesh()
	else:
		_navigation_finished()

func _navigation_finished() -> void:
	await get_tree().physics_frame
	navigation_ready = true
