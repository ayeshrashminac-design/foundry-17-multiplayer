extends Node3D

func _ready() -> void:
	var new_map := $Navigation/BackroomsArena
	# Retire the previous training-room geometry while retaining its NavigationRegion.
	for node in find_children("*", "MeshInstance3D", true, false):
		if not new_map.is_ancestor_of(node):
			(node as MeshInstance3D).visible = false
	for node in find_children("*", "StaticBody3D", true, false):
		if not new_map.is_ancestor_of(node):
			var body := node as StaticBody3D
			body.collision_layer = 0
			body.collision_mask = 0
	for node in find_children("*", "Light3D", true, false):
		if not new_map.is_ancestor_of(node):
			(node as Light3D).visible = false
	$PracticeTargets.hide()
	for node in $PracticeTargets.find_children("*", "CollisionObject3D", true, false):
		var body := node as CollisionObject3D
		body.collision_layer = 0
		body.collision_mask = 0
