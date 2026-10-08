extends Node

signal auth_changed(signed_in: bool)

signal room_changed(code: String)

signal operation_failed(message: String)

signal social_changed

signal invites_changed

signal confirmation_pending

var auth_busy := false

var _waiting_email := ""

var _waiting_password := ""

var _confirmation_timer: Timer

var _confirmation_tries := 0

var _confirmation_check_busy := false

const CONFIG_PATH := "res://mvp/online_config.cfg"

const SESSION_PATH := "user://foundry17_session.cfg"

const CALLBACK_PATH := "/callback"

const ROOM_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var app: Node

var supabase_url := ""

var publishable_key := ""

var redirect_port := 53682

var access_token := ""

var refresh_token := ""

var user_id := ""

var email := ""

var display_name := ""

var player_code := ""

var room_code := ""

var friends: Array[Dictionary] = []

var incoming_requests: Array[Dictionary] = []

var game_invites: Array[Dictionary] = []

var expires_at := 0

var _verifier := ""

var _callback_server := TCPServer.new()

var _callback_peer: StreamPeerTCP

var _callback_deadline := 0

var _social_timer: Timer

var _social_refreshing := false

var _upnp: UPNP

var _mapped_port := 0

var configured: bool:

	get: return not supabase_url.is_empty() and not publishable_key.is_empty()

var signed_in: bool:

	get: return not access_token.is_empty() and not user_id.is_empty()

func _ready() -> void:

	app = get_parent()

	_load_config()

	_load_session()

	_confirmation_timer = Timer.new()

	_confirmation_timer.wait_time = 12.0

	_confirmation_timer.timeout.connect(_check_confirmation)

	add_child(_confirmation_timer)

	_social_timer = Timer.new()

	_social_timer.wait_time = 5.0

	_social_timer.timeout.connect(refresh_social)

	add_child(_social_timer)

	set_process(false)

	if configured and not refresh_token.is_empty(): call_deferred("_restore_session")

func _load_config() -> void:

	var config := ConfigFile.new()

	if config.load(CONFIG_PATH) != OK: return

	supabase_url = str(config.get_value("backend", "supabase_url", "")).strip_edges().trim_suffix("/")

	publishable_key = str(config.get_value("backend", "publishable_key", "")).strip_edges()

	redirect_port = clampi(int(config.get_value("backend", "redirect_port", 53682)), 1024, 65535)

func _load_session() -> void:

	var config := ConfigFile.new()

	if config.load(SESSION_PATH) != OK: return

	# Sessions belong to one backend; never reuse credentials after migration.
	if str(config.get_value("session", "backend_url", "")) != supabase_url:
		return
	refresh_token = str(config.get_value("session", "refresh_token", ""))

func _save_session() -> void:

	var config := ConfigFile.new()

	config.set_value("session", "backend_url", supabase_url)
	config.set_value("session", "refresh_token", refresh_token)

	config.save(SESSION_PATH)

func sign_in_google() -> bool:

	if not configured:

		_fail("Online login needs Supabase URL and publishable key in mvp/online_config.cfg.")

		return false

	if _callback_server.is_listening(): _callback_server.stop()
	var provider := await _request_json("/auth/v1/settings", HTTPClient.METHOD_GET, {}, false)
	if not _is_success(provider):
		_fail("Could not reach the sign-in service. Please retry.")
		return false
	if not bool(provider.data.get("external", {}).get("google", false)):
		_fail("Google sign-in is awaiting publisher setup. Email login is available meanwhile.")
		return false
	var error := _callback_server.listen(redirect_port, "127.0.0.1")

	if error != OK:

		_fail("Login callback port %d is unavailable." % redirect_port)

		return false

	_verifier = _random_url_token(48)

	var hash := HashingContext.new()

	hash.start(HashingContext.HASH_SHA256)

	hash.update(_verifier.to_utf8_buffer())

	var challenge := _base64_url(hash.finish())

	var redirect := "http://127.0.0.1:%d%s" % [redirect_port, CALLBACK_PATH]

	var url := supabase_url + "/auth/v1/authorize?provider=google"

	url += "&redirect_to=" + redirect.uri_encode()

	url += "&code_challenge=" + challenge.uri_encode() + "&code_challenge_method=s256"

	_callback_deadline = Time.get_ticks_msec() + 180000

	set_process(true)

	if OS.shell_open(url) != OK:
		_stop_callback()
		_fail("Could not open your browser.")
		return false
	return true

func sign_in_email(email_text: String, password: String) -> bool:

	if not configured:

		_fail("Online login is not configured.")

		return false

	email_text = email_text.strip_edges().to_lower()

	if not _valid_email(email_text) or password.length() < 6:

		_fail("Enter a valid Gmail/email and a password with at least 6 characters.")

		return false

	var result := await _request_json("/auth/v1/token?grant_type=password", HTTPClient.METHOD_POST, {"email": email_text, "password": password}, false)

	if not _is_success(result):

		if result.data is Dictionary and str(result.data.get("error_code", "")) == "email_not_confirmed":

			_wait_for_confirmation(email_text, password)

		_fail(_error_message(result, "Could not sign in. Check your email and password."))

		return false

	_apply_session(result.data)

	await _upsert_profile()

	auth_changed.emit(true)

	_start_social_updates()

	return true

func sign_up_email(email_text: String, password: String) -> bool:

	if not configured:

		_fail("Online login is not configured.")

		return false

	email_text = email_text.strip_edges().to_lower()

	if not _valid_email(email_text) or password.length() < 6:

		_fail("Enter a valid Gmail/email and a password with at least 6 characters.")

		return false

	var name := email_text.get_slice("@", 0).substr(0, 32)

	var result := await _request_json("/auth/v1/signup", HTTPClient.METHOD_POST, {"email": email_text, "password": password, "data": {"display_name": name}}, false)

	if not _is_success(result):

		_fail(_error_message(result, "Could not create the account."))

		return false

	var data: Dictionary = result.data if result.data is Dictionary else {}

	if not str(data.get("access_token", "")).is_empty():

		_apply_session(data)

		await _upsert_profile()

		auth_changed.emit(true)

		_start_social_updates()

	else:

		_wait_for_confirmation(email_text, password)

		_fail("Check your inbox on any device. After confirming, this game signs you in automatically.")

	return true

func _process(_delta: float) -> void:

	if Time.get_ticks_msec() >= _callback_deadline:

		_stop_callback()

		_fail("Google login timed out. Try again.")

		return

	if _callback_peer == null and _callback_server.is_connection_available():

		_callback_peer = _callback_server.take_connection()

	if _callback_peer == null: return

	_callback_peer.poll()

	if _callback_peer.get_status() != StreamPeerTCP.STATUS_CONNECTED: return

	if _callback_peer.get_available_bytes() <= 0: return

	var request := _callback_peer.get_utf8_string(_callback_peer.get_available_bytes())

	var first_line := request.split("\r\n", false)[0] if not request.is_empty() else ""

	var target := first_line.split(" ")[1] if first_line.split(" ").size() >= 2 else ""

	var params := _query_params(target)

	var code := str(params.get("code", ""))

	var error_text := str(params.get("error_description", params.get("error", "")))

	var ok := not code.is_empty()

	var page := "<h2>Foundry 17</h2><p>%s</p><script>window.close()</script>" % ("Login received. Return to the game." if ok else "Login failed. Return to the game.")

	var response := "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [page.to_utf8_buffer().size(), page]

	_callback_peer.put_data(response.to_utf8_buffer())

	_stop_callback()

	if ok: _exchange_code(code)

	else: _fail(error_text if not error_text.is_empty() else "Google login was cancelled.")

func _stop_callback() -> void:

	set_process(false)

	_callback_server.stop()

	_callback_peer = null

func _exchange_code(code: String) -> void:

	var result := await _request_json("/auth/v1/token?grant_type=pkce", HTTPClient.METHOD_POST, {"auth_code": code, "code_verifier": _verifier}, false)

	if not _is_success(result):

		_fail(_error_message(result, "Could not complete Google login."))

		return

	_apply_session(result.data)

	await _upsert_profile()

	auth_changed.emit(true)

	_start_social_updates()

func _restore_session() -> void:

	var result := await _request_json("/auth/v1/token?grant_type=refresh_token", HTTPClient.METHOD_POST, {"refresh_token": refresh_token}, false)

	if _is_success(result):

		_apply_session(result.data)

		await _upsert_profile()

		auth_changed.emit(true)

		_start_social_updates()

	else:

		sign_out(false)

func _apply_session(data: Dictionary) -> void:

	cancel_confirmation()

	access_token = str(data.get("access_token", ""))

	refresh_token = str(data.get("refresh_token", refresh_token))

	expires_at = int(Time.get_unix_time_from_system()) + int(data.get("expires_in", 3600))

	var user: Dictionary = data.get("user", {})

	user_id = str(user.get("id", ""))

	email = str(user.get("email", ""))

	var metadata: Dictionary = user.get("user_metadata", {})

	display_name = str(metadata.get("full_name", metadata.get("name", metadata.get("display_name", email.get_slice("@", 0)))))

	if display_name.strip_edges().is_empty(): display_name = "Player"

	player_code = _player_code(user_id)

	_save_session()

func sign_out(call_server := true) -> void:

	cancel_confirmation()

	_stop_callback()

	if call_server and signed_in: await _request_json("/auth/v1/logout", HTTPClient.METHOD_POST, {}, true)

	access_token = ""; refresh_token = ""; user_id = ""; email = ""; display_name = ""; player_code = ""

	room_code = ""

	friends.clear(); incoming_requests.clear(); game_invites.clear()

	if _social_timer: _social_timer.stop()

	_save_session()

	auth_changed.emit(false)

	room_changed.emit("")

	social_changed.emit()

	invites_changed.emit()

func ensure_access_token() -> bool:

	if signed_in and Time.get_unix_time_from_system() < expires_at - 60: return true

	if refresh_token.is_empty(): return false

	await _restore_session()

	return signed_in

func verify_access_token(token: String) -> Dictionary:

	if not configured or token.is_empty(): return {}

	var result := await _request_json("/auth/v1/user", HTTPClient.METHOD_GET, {}, false, token)

	return result.data if _is_success(result) else {}

func prepare_internet_host(port: int) -> String:

	if not await ensure_access_token():

		_fail("Sign in before hosting online.")

		return ""

	_upnp = UPNP.new()

	var worker := Thread.new()

	if worker.start(func(): return _upnp.discover(2000, 2, "InternetGatewayDevice")) != OK: return ""

	while worker.is_alive(): await get_tree().process_frame

	var discover_error: int = worker.wait_to_finish()

	if discover_error == OK and _upnp.get_gateway() and _upnp.get_gateway().is_valid_gateway():

		var map_error := _upnp.add_port_mapping(port, port, "Foundry 17", "UDP")

		if map_error == OK:

			_mapped_port = port

			var address := _upnp.query_external_address().strip_edges()

			if not address.is_empty(): return address

	var result := await _request_json("/functions/v1/public-address", HTTPClient.METHOD_GET, {}, true)

	if _is_success(result) and result.data is Dictionary:

		var fallback := str(result.data.get("address", "")).strip_edges()

		if not fallback.is_empty():

			_fail("Router auto-forwarding is unavailable. Forward UDP %d to this PC, then friends can join." % port)

			return fallback

	_fail("Could not prepare internet hosting. Check the internet connection and router UPnP.")

	return ""

func create_room(address: String, port: int, settings: Dictionary = {}) -> Dictionary:

	if not await ensure_access_token():

		_fail("Sign in before hosting online.")

		return {}

	address = address.strip_edges()

	if address.is_empty() or address.length() > 255:

		_fail("Enter the host public/LAN address before creating a room.")

		return {}

	for attempt in 3:

		var code := _room_token()

		var payload := {"code": code, "host_id": user_id, "host_address": address, "port": port, "host_name": display_name.substr(0, 32), "mode": str(settings.get("mode", "ffa")), "max_players": clampi(int(settings.get("max_players", 8)), 2, 8), "kill_limit": clampi(int(settings.get("kill_limit", 20)), 5, 50), "match_seconds": clampi(int(settings.get("match_seconds", 600)), 300, 1800)}

		var result := await _request_json("/rest/v1/game_rooms", HTTPClient.METHOD_POST, payload, true, "", ["Prefer: return=representation"])

		if _is_success(result):

			room_code = code

			room_changed.emit(code)

			var rows: Variant = result.get("data", [])

			return rows[0] if rows is Array and not rows.is_empty() else payload

		if result.status != 409:

			_fail(_error_message(result, "Could not create the online room."))

			return {}

	_fail("Could not allocate a unique room code. Try again.")

	return {}

func resolve_room(code: String) -> Dictionary:

	if not await ensure_access_token():

		_fail("Sign in before joining online.")

		return {}

	code = code.strip_edges().to_upper()

	if code.length() != 8:

		_fail("Enter the 8-character room code.")

		return {}

	var path := "/rest/v1/game_rooms?select=code,host_address,port,host_name,mode,max_players,kill_limit,match_seconds&code=eq." + code.uri_encode() + "&limit=1"

	var result := await _request_json(path, HTTPClient.METHOD_GET, {}, true)

	if not _is_success(result):

		_fail(_error_message(result, "Could not find the room."))

		return {}

	var rows: Variant = result.get("data", [])

	if not (rows is Array) or rows.is_empty():

		_fail("Room not found or expired.")

		return {}

	return rows[0]

func clear_room() -> void:

	if room_code.is_empty(): return

	var old_code := room_code

	room_code = ""

	room_changed.emit("")

	if signed_in: await _request_json("/rest/v1/game_rooms?code=eq." + old_code.uri_encode() + "&host_id=eq." + user_id.uri_encode(), HTTPClient.METHOD_DELETE, {}, true)

	if _upnp and _mapped_port > 0: _upnp.delete_port_mapping(_mapped_port, "UDP")

	_mapped_port = 0

func refresh_social() -> void:

	if _social_refreshing or not signed_in: return

	_social_refreshing = true

	var path := "/rest/v1/friendships?select=id,requester_id,addressee_id,status&or=(requester_id.eq.%s,addressee_id.eq.%s)&order=created_at.asc" % [user_id, user_id]

	var relation_result := await _request_json(path, HTTPClient.METHOD_GET, {}, true)

	var invite_result := await _request_json("/rest/v1/game_invites?select=id,sender_id,room_code,status,expires_at&recipient_id=eq." + user_id + "&status=eq.pending&expires_at=gt." + Time.get_datetime_string_from_system(true).uri_encode() + "Z&order=created_at.desc", HTTPClient.METHOD_GET, {}, true)

	if not _is_success(relation_result) or not _is_success(invite_result):

		_social_refreshing = false

		return

	if not signed_in:

		_social_refreshing = false

		return

	var relations: Array = relation_result.data if _is_success(relation_result) and relation_result.data is Array else []

	var invites: Array = invite_result.data if _is_success(invite_result) and invite_result.data is Array else []

	var ids: Array[String] = []

	for row in relations:

		var other := str(row.addressee_id if str(row.requester_id) == user_id else row.requester_id)

		if other not in ids: ids.append(other)

	for row in invites:

		var sender := str(row.sender_id)

		if sender not in ids: ids.append(sender)

	var profiles := await _profiles_by_ids(ids)

	friends.clear(); incoming_requests.clear(); game_invites.clear()

	for row in relations:

		var other_id := str(row.addressee_id if str(row.requester_id) == user_id else row.requester_id)

		var entry: Dictionary = profiles.get(other_id, {"id": other_id, "display_name": "Player", "player_code": _player_code(other_id)})

		entry = entry.duplicate(); entry["friendship_id"] = str(row.id)

		if str(row.status) == "accepted": friends.append(entry)

		elif str(row.addressee_id) == user_id: incoming_requests.append(entry)

	for row in invites:

		var sender_profile: Dictionary = profiles.get(str(row.sender_id), {"display_name": "Player", "player_code": ""})

		game_invites.append({"id": str(row.id), "sender_id": str(row.sender_id), "sender_name": str(sender_profile.get("display_name", "Player")), "sender_code": str(sender_profile.get("player_code", "")), "room_code": str(row.room_code)})

	_social_refreshing = false

	social_changed.emit()

	invites_changed.emit()

func add_friend_by_code(code: String) -> bool:

	if not await ensure_access_token(): return false

	code = code.strip_edges().to_upper()

	if not code.begins_with("F17-") or code.length() != 16:

		_fail("Enter a valid F17 player ID.")

		return false

	var result := await _request_json("/rest/v1/profiles?select=id,display_name,player_code&player_code=eq." + code.uri_encode() + "&limit=1", HTTPClient.METHOD_GET, {}, true)

	var rows: Array = result.data if _is_success(result) and result.data is Array else []

	if rows.is_empty(): _fail("Player ID not found."); return false

	var target_id := str(rows[0].id)

	if target_id == user_id: _fail("You cannot add your own ID."); return false

	var existing := await _request_json("/rest/v1/friendships?select=id&or=(and(requester_id.eq.%s,addressee_id.eq.%s),and(requester_id.eq.%s,addressee_id.eq.%s))&limit=1" % [user_id, target_id, target_id, user_id], HTTPClient.METHOD_GET, {}, true)

	if _is_success(existing) and existing.data is Array and not existing.data.is_empty(): _fail("A friend request or friendship already exists."); return false

	var created := await _request_json("/rest/v1/friendships", HTTPClient.METHOD_POST, {"requester_id": user_id, "addressee_id": target_id, "status": "pending"}, true, "", ["Prefer: return=minimal"])

	if not _is_success(created): _fail(_error_message(created, "Could not send the friend request.")); return false

	await refresh_social()

	return true

func answer_friend_request(friendship_id: String, accept: bool) -> bool:

	var method := HTTPClient.METHOD_PATCH if accept else HTTPClient.METHOD_DELETE

	var body := {"status": "accepted"} if accept else {}

	var result := await _request_json("/rest/v1/friendships?id=eq." + friendship_id.uri_encode(), method, body, true, "", ["Prefer: return=minimal"])

	if not _is_success(result): _fail(_error_message(result, "Could not update the friend request.")); return false

	await refresh_social()

	return true

func remove_friend(friendship_id: String) -> bool:

	var result := await _request_json("/rest/v1/friendships?id=eq." + friendship_id.uri_encode(), HTTPClient.METHOD_DELETE, {}, true)

	if not _is_success(result): _fail(_error_message(result, "Could not remove the friend.")); return false

	await refresh_social()

	return true

func send_game_invite(friend_id: String) -> bool:

	if room_code.is_empty(): _fail("Create a room before inviting friends."); return false

	var payload := {"sender_id": user_id, "recipient_id": friend_id, "room_code": room_code}

	var result := await _request_json("/rest/v1/game_invites", HTTPClient.METHOD_POST, payload, true, "", ["Prefer: return=minimal"])

	if not _is_success(result): _fail(_error_message(result, "Could not send the game invite.")); return false

	return true

func answer_game_invite(invite_id: String, accept: bool) -> bool:

	var result := await _request_json("/rest/v1/game_invites?id=eq." + invite_id.uri_encode(), HTTPClient.METHOD_PATCH, {"status": "accepted" if accept else "declined"}, true, "", ["Prefer: return=minimal"])

	if not _is_success(result): _fail(_error_message(result, "Could not update the invite.")); return false

	await refresh_social()

	return true

func _profiles_by_ids(ids: Array[String]) -> Dictionary:

	var result := {}

	if ids.is_empty(): return result

	var query := await _request_json("/rest/v1/profiles?select=id,display_name,player_code&id=in.(" + ",".join(ids) + ")", HTTPClient.METHOD_GET, {}, true)

	if _is_success(query) and query.data is Array:

		for row in query.data: result[str(row.id)] = row

	return result

func _start_social_updates() -> void:

	if not _social_timer.is_stopped(): return

	_social_timer.start()

	refresh_social()

func _upsert_profile() -> void:

	if not signed_in: return

	var payload := {"id": user_id, "display_name": display_name.substr(0, 32)}

	var result := await _request_json("/rest/v1/profiles?on_conflict=id", HTTPClient.METHOD_POST, payload, true, "", ["Prefer: resolution=merge-duplicates,return=minimal"])

	if not _is_success(result): _fail("Signed in, but your player profile could not be saved. Please retry.")

func _request_json(path: String, method: int, body: Variant, authenticated: bool, bearer := "", extra_headers: Array[String] = []) -> Dictionary:

	var request := HTTPRequest.new()

	request.timeout = 20.0

	add_child(request)

	var headers := PackedStringArray(["apikey: " + publishable_key, "Content-Type: application/json", "Accept: application/json"])

	if authenticated and not access_token.is_empty(): headers.append("Authorization: Bearer " + access_token)

	elif not bearer.is_empty(): headers.append("Authorization: Bearer " + bearer)

	for header in extra_headers: headers.append(header)

	var text := "" if method in [HTTPClient.METHOD_GET, HTTPClient.METHOD_DELETE] else JSON.stringify(body)

	var start_error := request.request(supabase_url + path, headers, method, text)

	if start_error != OK:

		request.queue_free()

		return {"status": 0, "data": {}, "error": "Network request could not start."}

	var completed: Array = await request.request_completed

	request.queue_free()

	var status := int(completed[1])

	var response_text := (completed[3] as PackedByteArray).get_string_from_utf8()

	var parsed: Variant = JSON.parse_string(response_text) if not response_text.is_empty() else {}

	return {"status": status, "data": parsed if parsed != null else {}, "error": response_text}

func _is_success(result: Dictionary) -> bool:

	return int(result.get("status", 0)) >= 200 and int(result.get("status", 0)) < 300

func _error_message(result: Dictionary, fallback: String) -> String:

	var data: Variant = result.get("data", {})

	if data is Dictionary:

		for key in ["msg", "message", "error_description", "error"]:

			if data.has(key) and not str(data[key]).is_empty(): return str(data[key])

	return fallback

func _fail(message: String) -> void:

	operation_failed.emit(message)

func _valid_email(value: String) -> bool:

	var at := value.find("@")

	return at > 0 and at < value.length() - 3 and value.substr(at + 1).contains(".")

func _query_params(target: String) -> Dictionary:

	var result := {}

	var query := target.get_slice("?", 1) if "?" in target else ""

	for item in query.split("&", false):

		var pair := item.split("=", true, 1)

		result[pair[0].uri_decode()] = pair[1].replace("+", " ").uri_decode() if pair.size() > 1 else ""

	return result

func _room_token() -> String:

	var bytes := Crypto.new().generate_random_bytes(8)

	var result := ""

	for byte in bytes: result += ROOM_ALPHABET[byte % ROOM_ALPHABET.length()]

	return result

func _random_url_token(length: int) -> String:

	return _base64_url(Crypto.new().generate_random_bytes(length)).substr(0, length)

func _base64_url(bytes: PackedByteArray) -> String:

	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").replace("=", "")

func _player_code(id: String) -> String:

	return "F17-" + id.replace("-", "").substr(0, 12).to_upper()

func _wait_for_confirmation(address: String, password: String) -> void:

	_waiting_email = address

	_waiting_password = password

	_confirmation_tries = 0

	_confirmation_timer.start()

	confirmation_pending.emit()

func cancel_confirmation() -> void:

	_waiting_email = ""

	_waiting_password = ""

	if _confirmation_timer: _confirmation_timer.stop()

func _check_confirmation() -> void:

	if _confirmation_check_busy or auth_busy or _waiting_email.is_empty(): return

	_confirmation_check_busy = true

	var address := _waiting_email

	var result := await _request_json("/auth/v1/token?grant_type=password", HTTPClient.METHOD_POST, {"email": address, "password": _waiting_password}, false)

	_confirmation_check_busy = false

	if address != _waiting_email: return

	_confirmation_tries += 1

	if _is_success(result):

		_apply_session(result.data)

		await _upsert_profile()

		auth_changed.emit(true)

		_start_social_updates()

	elif _confirmation_tries >= 25:

		cancel_confirmation()

		_fail("Confirmation check paused. Confirm your email, then press Sign In.")

func resend_confirmation(address: String) -> bool:

	var result := await _request_json("/auth/v1/resend", HTTPClient.METHOD_POST, {"type": "signup", "email": address.strip_edges().to_lower()}, false)

	if not _is_success(result):

		_fail(_error_message(result, "Could not resend. Wait a minute and try again."))

		return false

	return true

func verify_confirmation(address: String, value: String) -> bool:

	value = value.strip_edges()

	var payload := {"type": "email"}

	if value.begins_with(supabase_url + "/auth/v1/verify?"):

		var params := _query_params(value)

		var kind := str(params.get("type", ""))

		if kind not in ["signup", "email"]:

			_fail("Use the account confirmation link from this game's email.")

			return false

		payload = {"type": kind, "token_hash": str(params.get("token", params.get("token_hash", "")))}

	elif value.is_valid_int() and value.length() >= 6 and value.length() <= 10:

		payload["email"] = address.strip_edges().to_lower()

		payload["token"] = value

	else:

		_fail("Paste the confirmation link, or the code shown in your email.")

		return false

	var result := await _request_json("/auth/v1/verify", HTTPClient.METHOD_POST, payload, false)

	if not _is_success(result):

		_fail(_error_message(result, "This confirmation expired. Request another email."))

		return false

	_apply_session(result.data)

	await _upsert_profile()

	auth_changed.emit(true)

	_start_social_updates()

	return true

