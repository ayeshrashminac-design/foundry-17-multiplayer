extends Area3D

@export var heal_amount: float = 40.0
var start_y: float = 0.0
var time_passed: float = 0.0

func _ready() -> void:
	start_y = position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	time_passed += delta
	position.y = start_y + sin(time_passed * 3.0) * 0.15
	rotate_y(delta * 1.5)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body.has_method("heal"):
			body.heal(heal_amount)
		elif "health" in body:
			body.health = min(body.MAX_HEALTH, body.health + heal_amount)
			if body.has_signal("health_changed"):
				body.emit_signal("health_changed", body.health)
		queue_free()
