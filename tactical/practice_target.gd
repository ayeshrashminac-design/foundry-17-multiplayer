extends Node3D
func _ready() -> void:
	var animation: AnimationPlayer = find_child("AnimationPlayer",true,false)
	if animation: animation.play("CharacterArmature|Idle_Gun")
