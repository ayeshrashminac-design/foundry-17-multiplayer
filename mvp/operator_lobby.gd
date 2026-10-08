extends Control

const CATALOG = preload("res://mvp/character_catalog.gd")
const STYLE = preload("res://mvp/lobby_style.gd")
var ui: CanvasLayer
var preview: CharacterBody3D
var viewport: SubViewport
var title: Label
var detail: Label
var badge: Label
var buttons: Array[Button] = []
var dragging := false
var turn := -0.25
var timer := 0.0

func label_at(text: String, point: Vector2, font_size: int, color := Color("ecf4f5")) -> Label:
	var label := Label.new()
	label.text = text
	label.position = point
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	add_child(label)
	return label

func panel_at(point: Vector2, dimensions: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = point
	panel.size = dimensions
	panel.add_theme_stylebox_override("panel",STYLE.box(Color("101e29"),Color("304653")))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	return panel

func setup(owner_ui: CanvasLayer) -> void:
	ui = owner_ui
	for child in ui.get_node("Menu").get_children():
		if child is Label: child.hide()
	name = "OperatorLobby"
	ui.get_node("Menu").add_child(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var menu_panel: Control = ui.get_node("Menu/Panel")
	menu_panel.position = Vector2(36,125)
	menu_panel.size = Vector2(310,535)
	var rows = ui.get_node("Menu/Panel/Rows")
	rows.add_theme_constant_override("separation",8)
	rows.get_node("Title").text = "DEPLOYMENT"
	rows.get_node("Title").add_theme_font_size_override("font_size",22)
	rows.get_node("Subtitle").text = "YOUR NEXT MATCH STARTS HERE"
	rows.get_node("Subtitle").add_theme_font_size_override("font_size",10)
	for node in rows.get_children():
		if node is Button:
			node.custom_minimum_size.y = 42
			node.add_theme_font_size_override("font_size",14)
	rows.get_node("Training").text = "TRAINING RANGE"
	rows.get_node("LoginGoogle").text = "SIGN IN TO PLAY ONLINE"
	rows.get_node("Status").text = ""
	label_at("FOUNDRY  /  17",Vector2(38,28),32)
	label_at("OPERATIONS LOBBY",Vector2(40,73),11,Color("83dace"))
	badge = label_at("TRAINING AVAILABLE",Vector2(989,40),12,Color("83dace"))
	panel_at(Vector2(989,126),Vector2(249,269))
	label_at("THE MISSION",Vector2(1009,146),12,Color("83dace"))
	label_at("FREE FOR ALL",Vector2(1009,177),23)
	label_at("BUNKER ARENA",Vector2(1009,214),13,Color("97acb8"))
	label_at("2–8 players\n10-minute rounds\nFirst to 20 kills",Vector2(1009,251),17)
	label_at("Same weapons. Same rules.",Vector2(1009,356),12,Color("97acb8"))
	panel_at(Vector2(989,417),Vector2(249,163))
	label_at("PLAY YOUR WAY",Vector2(1009,435),12,Color("83dace"))
	label_at("Invite friends to your room.\nOr warm up against bots\nin the training range.",Vector2(1009,468),15)
	label_at("WASD  Move     1 / 2  Weapons     RMB  Aim     R  Reload",Vector2(390,686),12,Color("97acb8"))
	var view := SubViewportContainer.new()
	view.name = "CharacterView"
	view.position = Vector2(357,90)
	view.size = Vector2(621,487)
	view.stretch = true
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(view)
	view.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT: dragging = event.pressed
		if event is InputEventMouseMotion and dragging: turn += event.relative.x*0.008
	)
	viewport = SubViewport.new()
	viewport.size = Vector2i(621,487)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	view.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0,0,0,0)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b8cbd7")
	environment.environment.ambient_light_energy = 0.65
	stage.add_child(environment)
	preview = load("res://mvp/player.tscn").instantiate()
	preview.process_mode = Node.PROCESS_MODE_DISABLED
	stage.add_child(preview)
	preview.get_node("Name").hide()
	preview.get_node("Camera/ViewWeapon").hide()
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0,1.12,-3.6)
	camera.look_at(Vector3(0,0.98,0))
	camera.fov = 34
	camera.current = true
	var light := DirectionalLight3D.new()
	stage.add_child(light)
	light.rotation_degrees = Vector3(-25,150,0)
	light.light_energy = 2.0
	var rim := OmniLight3D.new()
	stage.add_child(rim)
	rim.position = Vector3(-1,1.6,1)
	rim.light_color = Color("b6c7d4")
	rim.light_energy = 0.35
	var plinth := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.62
	cylinder.bottom_radius = 0.66
	cylinder.height = 0.07
	plinth.mesh = cylinder
	plinth.position.y = -0.045
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("253d47")
	metal.metallic = 0.6
	metal.roughness = 0.5
	plinth.material_override = metal
	stage.add_child(plinth)
	title = label_at("",Vector2(397,532),25)
	detail = label_at("",Vector2(398,568),12,Color("97acb8"))
	var group := ButtonGroup.new()
	for index in CATALOG.OPERATORS.size():
		var button := Button.new()
		button.text = CATALOG.OPERATORS[index].name
		button.position = Vector2(395+index*191,605)
		button.size = Vector2(179,48)
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(choose.bind(index,true))
		add_child(button)
		buttons.append(button)
	choose(ui.get_parent().get_node("Settings").character_id,false)
	menu_panel.set_deferred("size",Vector2(310,535))
	ui.get_node("Menu").visibility_changed.connect(func():
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if ui.get_node("Menu").visible else SubViewport.UPDATE_DISABLED
	)

func choose(index: int, persist: bool) -> void:
	index = CATALOG.valid_id(index)
	preview.set_character(index)
	for i in buttons.size(): buttons[i].set_pressed_no_signal(i == index)
	title.text = CATALOG.OPERATORS[index].name
	detail.text = CATALOG.OPERATORS[index].role+"  •  Appearance only  •  Drag to rotate"
	if persist:
		var settings = ui.get_parent().get_node("Settings")
		settings.character_id = index
		settings.save()
		ui.get_parent().get_node("Audio").play("click")

func _process(delta: float) -> void:
	if not is_instance_valid(preview) or not is_visible_in_tree(): return
	timer += delta
	preview.rotation.y = turn
	var body = preview.get_node("Body")
	body.skeleton.clear_bones_global_pose_override()
	body.play("Idle_Gun")
	body.animation.advance(delta)
	body.pose_weapon(0,0,timer,0)
	var online = ui.get_parent().get_node("Online")
	badge.text = "ONLINE  •  "+online.player_code if online.signed_in else "TRAINING AVAILABLE"
