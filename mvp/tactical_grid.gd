extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("07131e"))
	draw_line(Vector2(32, 100), Vector2(size.x - 32, 100), Color("2c586e"), 1)
	draw_line(Vector2(32, 100), Vector2(200, 100), Color("59cfff"), 3)
