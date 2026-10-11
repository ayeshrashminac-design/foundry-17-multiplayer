extends Node3D

var map_id := "backrooms"

func _ready() -> void:
	var backrooms := $Navigation/BackroomsArena
	var use_backrooms := map_id == "backrooms"
	backrooms.visible = use_backrooms
	_set_collisions(backrooms, use_backrooms)
	for node in find_children("*", "MeshInstance3D", true, false):
		if not backrooms.is_ancestor_of(node): (node as MeshInstance3D).visible = not use_backrooms
	for node in find_children("*", "StaticBody3D", true, false):
		if not backrooms.is_ancestor_of(node):
			var body := node as StaticBody3D
			body.collision_layer = 1 if not use_backrooms else 0
			body.collision_mask = 1 if not use_backrooms else 0
	for node in find_children("*", "Light3D", true, false):
		if not backrooms.is_ancestor_of(node): (node as Light3D).visible = not use_backrooms
	for node in find_children("*", "Label3D", true, false):
		if not backrooms.is_ancestor_of(node): (node as Label3D).visible = not use_backrooms
	$PracticeTargets.visible = not use_backrooms
	for node in $PracticeTargets.find_children("*", "CollisionObject3D", true, false):
		var body := node as CollisionObject3D
		body.collision_layer = 1 if not use_backrooms else 0
		body.collision_mask = 1 if not use_backrooms else 0

func _set_collisions(root: Node, enabled: bool) -> void:
	for node in root.find_children("*", "CollisionObject3D", true, false):
		var body := node as CollisionObject3D
		body.collision_layer = 1 if enabled else 0
		body.collision_mask = 1 if enabled else 0
