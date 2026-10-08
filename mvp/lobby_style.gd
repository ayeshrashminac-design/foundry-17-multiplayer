extends RefCounted

static func box(color: Color, border: Color, width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(5)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

static func apply(ui: CanvasLayer) -> void:
	var theme := Theme.new()
	theme.default_font_size = 16
	var ink := Color("101c24")
	var teal := Color("81ead1")
	var edge := Color("2a414a")
	var paper := Color("e7f3ef")
	for kind in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", kind, box(ink, edge))
		theme.set_stylebox("hover", kind, box(Color("203e43"), teal))
		theme.set_stylebox("pressed", kind, box(Color("28564f"), teal))
		theme.set_stylebox("disabled", kind, box(Color("0d171d"), Color("182a31")))
		theme.set_stylebox("focus", kind, box(Color(0,0,0,0), teal, 2))
		theme.set_color("font_color", kind, paper)
		theme.set_color("font_hover_color", kind, Color.WHITE)
	theme.set_stylebox("normal", "LineEdit", box(Color("09151c"), edge))
	theme.set_stylebox("focus", "LineEdit", box(Color(0,0,0,0), teal, 2))
	theme.set_stylebox("panel", "ItemList", box(Color("09151c"), edge))
	theme.set_stylebox("selected", "ItemList", box(Color("235046"), teal))
	theme.set_stylebox("selected_focus", "ItemList", box(Color("235046"), teal))
	theme.set_color("font_color", "Label", paper)
	theme.set_color("font_color", "LineEdit", paper)
	theme.set_color("font_color", "ItemList", paper)
	for node in ui.get_children():
		if node is Control: node.theme = theme
	for path in ["Menu/Panel/Rows/LoginGoogle", "Menu/Panel/Rows/Host", "AuthPanel/Panel/Rows/SignIn", "RoomPanel/Panel/Rows/Create", "InvitesPanel/Panel/Rows/Join"]:
		var button: Button = ui.get_node(path)
		button.add_theme_stylebox_override("normal", box(teal, teal))
		button.add_theme_color_override("font_color", Color("09231e"))
	# Load after the shared theme exists; the lobby uses this style helper too.
	var lobby := Control.new()
	lobby.set_script(load("res://mvp/operator_lobby.gd"))
	lobby.setup(ui)
