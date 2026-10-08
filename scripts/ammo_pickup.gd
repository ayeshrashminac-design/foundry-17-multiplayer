extends Area3D

@export var ammo_amount: int = 30
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
		if body.has_method("add_ammo"):
			body.add_ammo(ammo_amount)
		elif "total_ammo" in body:
			body.total_ammo += ammo_amount
			if body.has_signal("ammo_changed"):
				body.emit_signal("ammo_changed", body.ammo, body.total_ammo)
		queue_free()
