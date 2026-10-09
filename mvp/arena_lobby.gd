extends Control

var app: Node
var slots: Array[Button] = []
var title: Label
var hint: Label
var start: Button
var friends: VBoxContainer
var social_signature := ""
var was_open := false

func _ready() -> void:
	app = get_parent().get_parent()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("101824")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,32)
	add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",20)
	margin.add_child(rows)
	title = Label.new()
	title.add_theme_font_size_override("font_size",28)
	rows.add_child(title)
	hint = Label.new()
	rows.add_child(hint)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation",22)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(columns)
	for team in 2:
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation",12)
		columns.add_child(list)
		var heading := Label.new()
		heading.text = "BLUE TEAM" if team == 0 else "RED TEAM"
		heading.modulate = Color("63b3ff") if team == 0 else Color("ff7068")
		list.add_child(heading)
		for cell in 4:
			var index := team*4+cell
			var button := Button.new()
			button.custom_minimum_size.y = 65
			button.pressed.connect(func(): app.network.choose_slot(index))
			list.add_child(button)
			slots.append(button)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 250
	columns.add_child(sidebar)
	var friends_title := Label.new()
	friends_title.text = "FRIENDS / INVITE"
	sidebar.add_child(friends_title)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(scroll)
	friends = VBoxContainer.new()
	friends.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(friends)
	var buttons := HBoxContainer.new()
	rows.add_child(buttons)
	start = Button.new()
	start.text = "START MATCH"
	start.custom_minimum_size = Vector2(230,48)
	start.pressed.connect(func(): app.network.start_match())
	buttons.add_child(start)
	var leave := Button.new()
	leave.text = "LEAVE ROOM"
	leave.pressed.connect(func():
		app.ui.room_attempt += 1
		app.network.leave()
	)
	buttons.add_child(leave)
	var copy := Button.new()
	copy.text = "COPY ROOM CODE"
	copy.pressed.connect(func(): DisplayServer.clipboard_set(app.online.room_code))
	buttons.add_child(copy)
	hide()

func _process(_delta: float) -> void:
	var net = app.network
	visible = net.active and not net.training and net.game_mode == "tdm" and not net.running and not net.ended
	if not visible:
		was_open = false
		return
	if not was_open:
		was_open = true
		app.paused = false
		app.ui.get_node("Pause").hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	app.ui.get_node("Scoreboard").hide()
	title.text = "ARENA  /  ROOM %s  /  %d OF 8" % [app.online.room_code if not app.online.room_code.is_empty() else "LOCAL",net.players.size()]
	hint.text = "Select an empty slot to choose your team. At least one player per team is required."
	for i in 8:
		var id: int = net.lobby_slots[i]
		var player = net.players.get(id)
		slots[i].text = (player.player_name + ("  [HOST]" if id == 1 else "") + ("  [YOU]" if id == multiplayer.get_unique_id() else "")) if player else "EMPTY SLOT %d  /  JOIN" % [i%4+1]
		slots[i].disabled = id != 0 and id != multiplayer.get_unique_id()
	start.visible = multiplayer.is_server()
	var publishing: bool = app.ui._room_busy
	start.disabled = publishing or not net.can_start()
	if publishing:
		hint.text = "Creating online room… Please wait."
	elif not app.ui.room_notice.is_empty():
		hint.text = app.ui.room_notice
	elif not net.can_start():
		hint.text = "Waiting for players: invite a friend and place at least one player on each team."
	var signature := JSON.stringify([app.online.friends,app.online.room_code,publishing])
	if signature == social_signature: return
	social_signature = signature
	for child in friends.get_children():
		friends.remove_child(child)
		child.queue_free()
	if app.online.friends.is_empty():
		var empty := Label.new()
		empty.text = "Add friends from the main menu.\nOr share your room code."
		friends.add_child(empty)
	for friend in app.online.friends:
		var button := Button.new()
		button.disabled = publishing or app.online.room_code.is_empty()
		button.text = "%s  /  INVITE" % friend.get("display_name",friend.get("name","Friend"))
		button.pressed.connect(func():
			button.disabled = true
			var sent: bool = await app.online.send_game_invite(str(friend.get("id","")))
			if is_instance_valid(button):
				button.text = "INVITE SENT" if sent else "RETRY INVITE"
				button.disabled = sent
		)
		friends.add_child(button)
