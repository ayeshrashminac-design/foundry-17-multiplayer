extends CanvasLayer

var app: Node

var settings_open := false

var hit_time := 0.0

var feed: Array[Dictionary] = []

var scoreboard_clock := 0.0

var online: Node

var _last_social := ""

var _room_busy := false

var _resend_at := 0

@onready var menu = $Menu/Panel/Rows

@onready var options = $SettingsPanel/Panel/Rows

func _ready() -> void:

	preload("res://mvp/lobby_style.gd").apply(self)

	app = get_parent()
	var damage := ColorRect.new()
	damage.name = "DamageFeedback"
	damage.set_script(preload("res://tactical/damage_feedback.gd"))
	damage.app = app
	add_child(damage)
	move_child(damage,0)

	online = app.get_node("Online")

	menu.get_node("Play").pressed.connect(_host_direct)

	menu.get_node("Host").pressed.connect(_open_room_panel)

	menu.get_node("Join").pressed.connect(_join)

	menu.get_node("Friends").pressed.connect(_open_friends)

	menu.get_node("Invites").pressed.connect(_open_invites)

	menu.get_node("LoginGoogle").pressed.connect(_open_auth)
	$AuthPanel/Panel/Rows/Google.pressed.connect(_login_google)
	menu.get_node("LogoutGoogle").pressed.connect(_logout_google)

	$AuthPanel/Panel/Rows/SignIn.pressed.connect(_login_email)

	$AuthPanel/Panel/Rows/CreateAccount.pressed.connect(_create_email)

	$AuthPanel/Panel/Rows/Back.pressed.connect(func(): online.cancel_confirmation(); $AuthPanel.hide())

	$AuthPanel/Panel/Rows/Verify.pressed.connect(_verify_email)

	$AuthPanel/Panel/Rows/Resend.pressed.connect(_resend_email)

	$AuthPanel/Panel/Rows/Password.text_submitted.connect(func(_text): _login_email())

	$FriendsPanel/Panel/Rows/CopyID.pressed.connect(func(): DisplayServer.clipboard_set(online.player_code); status("Player ID copied."))

	$FriendsPanel/Panel/Rows/AddFriend.pressed.connect(_add_friend)

	$FriendsPanel/Panel/Rows/Accept.pressed.connect(func(): _answer_friend(true))

	$FriendsPanel/Panel/Rows/Reject.pressed.connect(func(): _answer_friend(false))

	$FriendsPanel/Panel/Rows/Remove.pressed.connect(_remove_friend)

	$FriendsPanel/Panel/Rows/Refresh.pressed.connect(func(): online.refresh_social())

	$FriendsPanel/Panel/Rows/Back.pressed.connect(func(): $FriendsPanel.hide())

	$InvitesPanel/Panel/Rows/Join.pressed.connect(_join_invite)

	$InvitesPanel/Panel/Rows/Decline.pressed.connect(_decline_invite)

	$InvitesPanel/Panel/Rows/Refresh.pressed.connect(func(): online.refresh_social())

	$InvitesPanel/Panel/Rows/Back.pressed.connect(func(): $InvitesPanel.hide())

	$RoomPanel/Panel/Rows/Create.pressed.connect(_create_internet_room)

	$RoomPanel/Panel/Rows/Back.pressed.connect(func(): $RoomPanel.hide())

	menu.get_node("Training").pressed.connect(func(): app.audio.play("click"); app.network.start_training(menu.get_node("PlayerName").text))

	menu.get_node("Settings").pressed.connect(open_settings)

	menu.get_node("Quit").pressed.connect(func(): get_tree().quit())

	$Pause/Panel/Rows/Resume.pressed.connect(func(): app.audio.play("click"); app.toggle_pause())

	$Pause/Panel/Rows/Settings.pressed.connect(open_settings)

	$Pause/Panel/Rows/Leave.pressed.connect(func(): app.network.leave())

	$Pause/Panel/Rows/Quit.pressed.connect(func(): get_tree().quit())

	$Scoreboard/Panel/Rows/Leave.pressed.connect(func(): app.network.leave())

	$Scoreboard/Panel/Rows/Rematch.pressed.connect(_start_or_rematch)

	options.get_node("Back").pressed.connect(close_settings)

	options.get_node("Sensitivity").value_changed.connect(func(value): app.settings.sensitivity = value)

	options.get_node("Master").value_changed.connect(func(value): app.settings.master = value; app.settings.apply())

	options.get_node("SFX").value_changed.connect(func(value): app.settings.sfx = value; app.settings.apply())

	options.get_node("Fullscreen").toggled.connect(func(value): app.settings.fullscreen = value; app.settings.apply())

	options.get_node("Resolution").item_selected.connect(func(index): app.settings.resolution = index; app.settings.apply())

	online.auth_changed.connect(_auth_changed)

	online.confirmation_pending.connect(_show_verification)

	online.operation_failed.connect(status)

	online.room_changed.connect(func(_code): _refresh_account())

	online.social_changed.connect(_render_social)

	online.invites_changed.connect(_render_social)

	_refresh_account()

func _host_direct() -> void:

	app.audio.play("click")

	app.network.require_online_auth = false

	app.network.host(int(menu.get_node("Port").value), menu.get_node("PlayerName").text)

func _host_online() -> void:

	app.audio.play("click")

	if not await online.ensure_access_token():

		status("Sign in before hosting an online room.")

		return

	var address: String = menu.get_node("Address").text.strip_edges()

	if address.is_empty():

		status("Enter the host LAN/public address first.")

		return

	app.network.require_online_auth = true

	if not app.network.host(int(menu.get_node("Port").value), online.display_name): return

	var room: Dictionary = await online.create_room(address, int(menu.get_node("Port").value))

	if room.is_empty():

		app.network.leave()

		return

	status("Room code: " + online.room_code)

func _open_room_panel() -> void:
	status("")

	app.audio.play("click")

	if not await online.ensure_access_token():

		status("Sign in before creating an internet room.")

		return

	await online.refresh_social()

	_render_social()

	$RoomPanel.show()

func _create_internet_room() -> void:

	if _room_busy: return

	_room_busy = true

	$RoomPanel/Panel/Rows/Create.disabled = true

	app.audio.play("click")

	var rows = $RoomPanel/Panel/Rows

	var rules := {"mode": "tdm" if rows.get_node("Mode").get_item_id(rows.get_node("Mode").selected) == 1 else "ffa", "max_players": int(rows.get_node("MaxPlayers").value), "kill_limit": int(rows.get_node("KillLimit").value), "match_seconds": int(rows.get_node("Duration").get_item_id(rows.get_node("Duration").selected))}

	var invite_ids: Array[String] = []

	var friend_list: ItemList = rows.get_node("Friends")

	for index in friend_list.get_selected_items():

		var data: Dictionary = friend_list.get_item_metadata(index)

		invite_ids.append(str(data.get("id", "")))

	status("Preparing the internet room…")

	var address: String = await online.prepare_internet_host(7777)

	if address.is_empty():

		_room_busy = false

		$RoomPanel/Panel/Rows/Create.disabled = false

		return

	$RoomPanel.hide()

	app.network.require_online_auth = true

	if not app.network.host(7777, online.display_name, rules):

		_room_busy = false

		$RoomPanel/Panel/Rows/Create.disabled = false

		return

	var room: Dictionary = await online.create_room(address, 7777, rules)

	_room_busy = false

	$RoomPanel/Panel/Rows/Create.disabled = false

	if room.is_empty():

		app.network.leave()

		return

	for friend_id in invite_ids:

		if not friend_id.is_empty(): await online.send_game_invite(friend_id)

	status("Internet room %s created. %d invite(s) sent." % [online.room_code, invite_ids.size()])

func _join() -> void:

	app.audio.play("click")

	var code: String = menu.get_node("RoomCode").text.strip_edges().to_upper()

	if not code.is_empty():

		if not await online.ensure_access_token():

			status("Sign in before joining a room.")

			return

		var room: Dictionary = await online.resolve_room(code)

		if room.is_empty(): return

		online.room_code = code

		online.room_changed.emit(code)

		app.network.require_online_auth = true

		app.network.join(str(room.get("host_address", "")), int(room.get("port", 7777)), online.display_name)

		return

	var address: String = menu.get_node("Address").text.strip_edges()

	if address.is_empty(): status("Enter the host IP address."); return

	app.network.require_online_auth = false

	app.network.join(address, int(menu.get_node("Port").value), menu.get_node("PlayerName").text)

func _login_google() -> void:
	if online.auth_busy: return
	_set_auth_busy(true)
	app.audio.play("click")
	if await online.sign_in_google(): status("Browser opened. Complete Google login there…")
	_set_auth_busy(false)

func _open_auth() -> void:
	status("")

	app.audio.play("click")

	for key in ["VerificationHint", "Verification", "Verify", "Resend"]:
		$AuthPanel/Panel/Rows.get_node(key).hide()
	for key in ["Google", "Hint", "Password", "SignIn", "CreateAccount"]:
		$AuthPanel/Panel/Rows.get_node(key).show()
	$AuthPanel.show()

	$AuthPanel/Panel/Rows/Email.grab_focus()

func _set_auth_busy(value: bool) -> void:

	online.auth_busy = value

	for key in ["Google", "SignIn", "CreateAccount", "Verify", "Resend"]:

		$AuthPanel/Panel/Rows.get_node(key).disabled = value

func _login_email() -> void:

	if online.auth_busy: return

	_set_auth_busy(true)

	status("Signing in…")

	var rows = $AuthPanel/Panel/Rows

	await online.sign_in_email(rows.get_node("Email").text, rows.get_node("Password").text)

	_set_auth_busy(false)

func _create_email() -> void:

	if online.auth_busy: return

	_set_auth_busy(true)

	status("Creating your account…")

	var rows = $AuthPanel/Panel/Rows

	await online.sign_up_email(rows.get_node("Email").text, rows.get_node("Password").text)

	_set_auth_busy(false)

func _show_verification() -> void:
	for key in ["Google", "Hint", "Password", "SignIn", "CreateAccount"]:
		$AuthPanel/Panel/Rows.get_node(key).hide()

	for key in ["VerificationHint", "Verification", "Verify", "Resend"]:

		$AuthPanel/Panel/Rows.get_node(key).show()

func _verify_email() -> void:

	if online.auth_busy: return

	_set_auth_busy(true)

	var rows = $AuthPanel/Panel/Rows

	await online.verify_confirmation(rows.get_node("Email").text, rows.get_node("Verification").text)

	_set_auth_busy(false)

func _resend_email() -> void:

	if online.auth_busy: return

	if Time.get_ticks_msec() < _resend_at:

		status("Please wait a minute before requesting another email.")

		return

	_set_auth_busy(true)

	_resend_at = Time.get_ticks_msec() + 60000

	if await online.resend_confirmation($AuthPanel/Panel/Rows/Email.text): status("New confirmation sent. Check your inbox and spam folder.")

	_set_auth_busy(false)

func _auth_changed(signed: bool) -> void:

	_refresh_account()

	if signed:

		$AuthPanel/Panel/Rows/Password.clear()

		$AuthPanel/Panel/Rows/Verification.clear()

		$AuthPanel.hide()

		status("Welcome back. Add your friends or create a room.")

func _open_friends() -> void:
	status("")

	app.audio.play("click")

	if not online.signed_in: _open_auth(); return

	await online.refresh_social()

	_render_social()

	$FriendsPanel.show()

func _open_invites() -> void:
	status("")

	app.audio.play("click")

	if not online.signed_in: _open_auth(); return

	await online.refresh_social()

	_render_social()

	$InvitesPanel.show()

func _add_friend() -> void:

	app.audio.play("click")

	var input: LineEdit = $FriendsPanel/Panel/Rows/FriendCode

	if await online.add_friend_by_code(input.text):

		input.text = ""

		status("Friend request sent.")

func _answer_friend(accept: bool) -> void:

	app.audio.play("click")

	var list: ItemList = $FriendsPanel/Panel/Rows/Requests

	var selected := list.get_selected_items()

	if selected.is_empty(): status("Select a friend request first."); return

	var data: Dictionary = list.get_item_metadata(selected[0])

	if await online.answer_friend_request(str(data.get("friendship_id", "")), accept): status("Friend request accepted." if accept else "Friend request rejected.")

func _remove_friend() -> void:

	app.audio.play("click")

	var list: ItemList = $FriendsPanel/Panel/Rows/Friends

	var selected := list.get_selected_items()

	if selected.is_empty(): status("Select a friend first."); return

	var data: Dictionary = list.get_item_metadata(selected[0])

	if await online.remove_friend(str(data.get("friendship_id", ""))): status("Friend removed.")

func _join_invite() -> void:

	app.audio.play("click")

	var list: ItemList = $InvitesPanel/Panel/Rows/Invites

	var selected := list.get_selected_items()

	if selected.is_empty(): status("Select an invite first."); return

	var data: Dictionary = list.get_item_metadata(selected[0])

	var room: Dictionary = await online.resolve_room(str(data.get("room_code", "")))

	if room.is_empty(): return

	if not await online.answer_game_invite(str(data.get("id", "")), true): return

	$InvitesPanel.hide()

	app.network.require_online_auth = true

	app.network.join(str(room.host_address), int(room.port), online.display_name)

	online.room_code = str(room.code)

	online.room_changed.emit(online.room_code)

func _decline_invite() -> void:

	app.audio.play("click")

	var list: ItemList = $InvitesPanel/Panel/Rows/Invites

	var selected := list.get_selected_items()

	if selected.is_empty(): status("Select an invite first."); return

	var data: Dictionary = list.get_item_metadata(selected[0])

	if await online.answer_game_invite(str(data.get("id", "")), false): status("Invite declined.")

func _render_social() -> void:

	if not is_node_ready(): return

	var signature := JSON.stringify([online.friends, online.incoming_requests, online.game_invites, online.player_code])

	if signature == _last_social: return

	_last_social = signature

	menu.get_node("Invites").text = "INVITES   /   %02d" % online.game_invites.size()

	$FriendsPanel/Panel/Rows/YourID.text = "YOUR ID: " + (online.player_code if online.signed_in else "—")

	var friends_list: ItemList = $FriendsPanel/Panel/Rows/Friends

	var requests_list: ItemList = $FriendsPanel/Panel/Rows/Requests

	var room_friends: ItemList = $RoomPanel/Panel/Rows/Friends

	var invites_list: ItemList = $InvitesPanel/Panel/Rows/Invites

	friends_list.clear(); requests_list.clear(); room_friends.clear(); invites_list.clear()

	for entry in online.friends:

		var label := "%s   %s" % [entry.get("display_name", "Player"), entry.get("player_code", "")]

		var index := friends_list.add_item(label); friends_list.set_item_metadata(index, entry)

		var room_index := room_friends.add_item(label); room_friends.set_item_metadata(room_index, entry)

	for entry in online.incoming_requests:

		var index := requests_list.add_item("%s   %s" % [entry.get("display_name", "Player"), entry.get("player_code", "")]); requests_list.set_item_metadata(index, entry)

	for entry in online.game_invites:

		var index := invites_list.add_item("%s invited you to room %s" % [entry.get("sender_name", "Player"), entry.get("room_code", "")]); invites_list.set_item_metadata(index, entry)

func _logout_google() -> void:

	app.audio.play("click")

	await online.sign_out()

	_refresh_account()

func _refresh_account() -> void:

	if not online.configured:

		menu.get_node("Account").text = "Online: configure mvp/online_config.cfg"

		menu.get_node("LoginGoogle").disabled = true

		menu.get_node("LogoutGoogle").visible = false

		return

	menu.get_node("LoginGoogle").visible = not online.signed_in

	menu.get_node("LogoutGoogle").visible = online.signed_in

	menu.get_node("Host").visible = online.signed_in

	menu.get_node("Friends").visible = online.signed_in

	menu.get_node("Invites").visible = online.signed_in

	if online.signed_in:

		menu.get_node("Account").text = "%s  •  ID %s" % [online.display_name, online.player_code]

		menu.get_node("PlayerName").text = online.display_name.substr(0, 16)

		online.refresh_social()

	else:

		menu.get_node("Account").text = "Sign in with Gmail/email to play online"

	_render_social()

func status(message: String) -> void:

	menu.get_node("Status").text = message

	for panel in ["AuthPanel", "FriendsPanel", "InvitesPanel", "RoomPanel"]:

		var rows = get_node(panel + "/Panel/Rows")

		if rows.has_node("Feedback"): rows.get_node("Feedback").text = message

	$Notice.text = message

	$Notice.visible = not message.is_empty()

func open_settings() -> void:

	app.audio.play("click")

	settings_open = true

	options.get_node("Sensitivity").set_value_no_signal(app.settings.sensitivity)

	options.get_node("Master").set_value_no_signal(app.settings.master)

	options.get_node("SFX").set_value_no_signal(app.settings.sfx)

	options.get_node("Fullscreen").set_pressed_no_signal(app.settings.fullscreen)

	options.get_node("Resolution").select(app.settings.resolution)

	$SettingsPanel.show()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_settings() -> void:

	app.settings.save()

	settings_open = false

	$SettingsPanel.hide()

	if app.in_match and not app.paused and not app.network.ended: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func hit_marker(headshot: bool = false) -> void:

	$HUD/Hit.modulate = Color(1,0.6,0.15) if headshot else Color.WHITE

	hit_time = 0.15

	app.audio.play("hit")

func add_kill(text: String) -> void:

	feed.append({"text": text, "time": 5.0})

	if feed.size() > 5: feed.pop_front()

func _process(delta: float) -> void:

	if not app.in_match: return

	var net = app.network

	var p = net.players.get(multiplayer.get_unique_id())

	if not p: return

	var seconds := maxi(0, int(ceil(net.remaining)))

	var mode_text := "TEAM ARENA  •  BLUE %d  RED %d  •  FIRST TO %d" % [int(net.team_scores.get(0,0)),int(net.team_scores.get(1,0)),net.kill_limit] if net.game_mode == "tdm" else "FREE FOR ALL  •  FIRST TO %d" % net.kill_limit
	$HUD/Top.text = "%02d:%02d  •  %s" % [seconds / 60, seconds % 60, mode_text] if net.running else (net.winner if net.ended else ("ROOM LOBBY  •  START WHEN READY" if multiplayer.is_server() else "ROOM LOBBY  •  WAITING FOR HOST"))

	$HUD/OnlineRoom.text = "ROOM %s" % online.room_code if not online.room_code.is_empty() else ""

	$HUD/Health.text = "HP  %d" % p.hp

	if net.training and net.running: $HUD/Top.text = "%02d:%02d  •  TRAINING  •  3 BOTS  •  FIRST TO 20" % [seconds / 60, seconds % 60]

	$HUD/Ammo.text = "%s   %d / %d" % [p.weapons.DATA[p.weapons.slot].name, p.get_node("WeaponController").available_ammo(), p.weapons.reserve[p.weapons.slot]]

	$HUD/Score.text = "KILLS %d   DEATHS %d" % [p.kills, p.deaths]

	var countdown: float = maxf(0, p.respawn_at - net.clock) if multiplayer.is_server() else p.respawn_at

	$HUD/Respawn.text = "RESPAWNING IN %d" % int(ceil(countdown)) if p.dead and not net.ended else ""

	var reload_left: float = p.weapons.reload_left if multiplayer.is_server() else p.remote_reload

	$HUD/Reload.text = "RELOADING…" if reload_left > 0 else ""

	hit_time = maxf(0, hit_time - delta)

	$HUD/Hit.visible = hit_time > 0

	$HUD/Crosshair.text = "·" if p.is_aiming else "+"
	$HUD/Crosshair.modulate = Color(1,0.22,0.12) if p.is_aiming else Color.WHITE
	$HUD/Crosshair.visible = not p.dead and not app.paused and not settings_open and not net.ended

	var lines := PackedStringArray()

	for entry in feed:

		entry.time -= delta

		if entry.time > 0: lines.append(entry.text)

	feed = feed.filter(func(entry): return entry.time > 0)

	$HUD/KillFeed.text = "\n".join(lines)

	$Scoreboard.visible = (net.active and not net.running and not net.training) or net.ended or (Input.is_physical_key_pressed(KEY_TAB) and not settings_open and not app.paused)
	var action: Button = $Scoreboard/Panel/Rows/Rematch
	action.visible = multiplayer.is_server()
	action.text = "START MATCH" if not net.running and not net.ended else "PLAY AGAIN"
	action.disabled = net.players.size() < 2
	if net.active and not net.running and not net.training: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if net.ended and not settings_open: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	scoreboard_clock -= delta

	if $Scoreboard.visible and scoreboard_clock <= 0:

		scoreboard_clock = 0.2

		_update_scoreboard()

func _update_scoreboard() -> void:

	var net = app.network

	var roster: Array = net.players.values()

	roster.sort_custom(func(a, b): return a.kills > b.kills if a.kills != b.kills else a.deaths < b.deaths)

	$Scoreboard/Panel/Rows/Title.text = net.winner if net.ended else ("ROOM LOBBY  •  BLUE %d / RED %d" % [int(net.team_scores.get(0,0)),int(net.team_scores.get(1,0))] if net.game_mode == "tdm" else "SCOREBOARD")

	var grid = $Scoreboard/Panel/Rows/Grid

	for row in 8:

		for column in 4:

			var cell: Label = grid.get_node("Cell%d_%d" % [row, column])

			cell.visible = row < roster.size()

			if row < roster.size():

				var p = roster[row]

				var team_name := ("[BLUE] " if p.team == 0 else "[RED] ") if net.game_mode == "tdm" else ""
				cell.text = [team_name+p.player_name, str(p.kills), str(p.deaths), str(p.ping) + " ms"][column]
				cell.modulate = Color("8bc9ff") if p.team == 0 else (Color("ff9b95") if p.team == 1 else Color.WHITE)

func _start_or_rematch() -> void:
	if not multiplayer.is_server(): return
	if app.network.ended: app.network.rematch()
	else: app.network.start_match()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

