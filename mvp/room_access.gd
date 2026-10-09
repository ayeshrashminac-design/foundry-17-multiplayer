extends ConfirmationDialog

var ui: Node
var room_id: LineEdit
var password: LineEdit
var feedback: Label
var busy := false

func setup(owner_ui: Node) -> void:
	ui = owner_ui
	title = "JOIN ARENA ROOM"
	min_size = Vector2i(440,250)
	ok_button_text = "JOIN ROOM"
	dialog_hide_on_ok = false
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",14)
	add_child(rows)
	var label := Label.new()
	label.text = "Enter the Room ID and password shared by the host."
	rows.add_child(label)
	room_id = LineEdit.new()
	room_id.placeholder_text = "Room ID (8 characters)"
	room_id.max_length = 8
	rows.add_child(room_id)
	password = LineEdit.new()
	password.placeholder_text = "Room password"
	password.secret = true
	password.max_length = 64
	rows.add_child(password)
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(feedback)
	confirmed.connect(_join)
	password.text_submitted.connect(func(_text): _join())
	ui.online.operation_failed.connect(func(message):
		if visible: feedback.text = message
	)

func open(code: String = "") -> void:
	room_id.text = code
	password.clear()
	feedback.text = ""
	popup_centered()
	room_id.grab_focus() if code.is_empty() else password.grab_focus()

func _join() -> void:
	if busy: return
	var code := room_id.text.strip_edges().to_upper()
	if code.length() != 8 or password.text.length() < 4:
		feedback.text = "Enter an 8-character Room ID and a password of at least 4 characters."
		return
	busy = true
	get_ok_button().disabled = true
	feedback.text = "Finding room…"
	var room: Dictionary = await ui.online.resolve_room(code)
	busy = false
	get_ok_button().disabled = false
	if not visible: return
	if room.is_empty(): return
	ui.app.network.require_online_auth = true
	var address := ui.online.room_connection_address(room)
	ui.app.network.join(address,int(room.port),ui.online.display_name,password.text)
	password.clear()
	if ui.app.network.connecting:
		ui.online.room_code = code
		ui.online.room_changed.emit(code)
		hide()
