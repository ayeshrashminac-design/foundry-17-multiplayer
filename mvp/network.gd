extends Node

const PLAYER = preload("res://mvp/player.tscn")
const Shooting = preload("res://mvp/shooting.gd")
const MAX_PLAYERS := 8
const MATCH_SECONDS := 600.0
const KILL_LIMIT := 20
const RESPAWN_SECONDS := 5.0
var app: Node
var players: Dictionary = {}
var active := false
var running := false
var ended := false
var winner := ""
var clock := 0.0
var remaining := MATCH_SECONDS
var snapshot_clock := 0.0
var ping_clock := 0.0
var pending: Array[Dictionary] = []
var nickname := "Player"
var connecting := false
var connect_timeout := 0.0
var ping_sent: Dictionary = {}
var state_sequence := 0
var received_sequence := -1
var training := false
var require_online_auth := false
var authenticated_tokens: Dictionary = {}
var max_players := MAX_PLAYERS
var match_seconds := MATCH_SECONDS
var kill_limit := KILL_LIMIT
var game_mode := "ffa"
var team_scores := {0: 0, 1: 0}

func start_training(name_text: String) -> void:
	leave()
	training = true
	active = true
	var arena = load("res://mvp/training_map.tscn").instantiate()
	app.add_child(arena)
	app.enter_match()
	arena.get_node("Navigation").bake_navigation_mesh(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not training or not is_instance_valid(arena) or not arena.is_inside_tree(): return
	_add_player(1, _unique_name(name_text))
	for index in 3:
		var bot = _add_player(-index - 1, "Bot " + str(index + 1))
		var brain := Node.new()
		brain.set_script(load("res://mvp/training_bot.gd"))
		bot.add_child(brain)
	_start_round()

func _ready() -> void:
	app = get_parent()
	process_physics_priority = 100
	multiplayer.peer_disconnected.connect(_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): leave("Could not connect to host."))
	multiplayer.server_disconnected.connect(func(): leave("Host left the match."))

func host(port: int, name_text: String, rules: Dictionary = {}) -> bool:
	leave()
	max_players = clampi(int(rules.get("max_players", MAX_PLAYERS)), 2, MAX_PLAYERS)
	match_seconds = clampf(float(rules.get("match_seconds", MATCH_SECONDS)), 300.0, 1800.0)
	kill_limit = clampi(int(rules.get("kill_limit", KILL_LIMIT)), 5, 50)
	game_mode = str(rules.get("mode", "tdm"))
	if game_mode not in ["ffa", "tdm"]: game_mode = "tdm"
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, max_players - 1)
	if error != OK:
		app.ui.status("Cannot host on port %d (error %d)." % [port, error])
		return false
	multiplayer.multiplayer_peer = peer
	active = true
	nickname = name_text
	_add_player(1, _unique_name(name_text))
	app.enter_match()
	app.ui.status("Hosting on UDP %d. Waiting for another player." % port)
	return true

func join(address: String, port: int, name_text: String) -> void:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		app.ui.status("Invalid host address or port.")
		return
	nickname = name_text
	multiplayer.multiplayer_peer = peer
	connecting = true
	connect_timeout = 10
	app.ui.status("Connecting…")

func _connected() -> void:
	register.rpc_id(1, nickname, app.online.access_token, app.online.player_code, app.settings.character_id)

@rpc("any_peer", "call_remote", "reliable", 0)
func register(name_text: String, token: String = "", claimed_code: String = "", character: int = 0) -> void:
	if not multiplayer.is_server(): return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id): return
	if players.size() >= max_players:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	if require_online_auth:
		var identity: Dictionary = await app.online.verify_access_token(token)
		if identity.is_empty():
			multiplayer.multiplayer_peer.disconnect_peer(id)
			return
		var auth_id := str(identity.get("id", ""))
		if auth_id.is_empty() or (claimed_code != "" and claimed_code != app.online._player_code(auth_id)):
			multiplayer.multiplayer_peer.disconnect_peer(id)
			return
		authenticated_tokens[id] = auth_id
		var metadata: Dictionary = identity.get("user_metadata", {})
		name_text = str(metadata.get("full_name", metadata.get("name", metadata.get("display_name", str(identity.get("email", "Player")).get_slice("@", 0)))))
	var joined = _add_player(id, _unique_name(name_text))
	joined.set_character(character)
	state_sequence += 1
	_broadcast_world()

func _unique_name(raw: String) -> String:
	var clean := ""
	for c in raw.strip_edges().substr(0, 16):
		if c.unicode_at(0) >= 32 and c not in ["\n", "\r", "\t", "[", "]"]: clean += c
	if clean.is_empty(): clean = "Player"
	var result := clean
	var suffix := 2
	var used := []
	for p in players.values(): used.append(p.player_name.to_lower())
	while result.to_lower() in used:
		result = clean.substr(0, 12) + "_" + str(suffix)
		suffix += 1
	return result

func _add_player(id: int, name_text: String) -> Node:
	var player = PLAYER.instantiate()
	player.name = "P" + str(id)
	app.get_node("Players").add_child(player)
	player.configure(id, name_text, self)
	if id == multiplayer.get_unique_id(): player.set_character(app.settings.character_id)
	elif id < 0: player.set_character(absi(id)%3)
	players[id] = player
	player.set_team(_balanced_team() if game_mode == "tdm" else -1)
	if multiplayer.is_server(): player.reset_at(_spawn_transform(id))
	return player

func _balanced_team() -> int:
	var blue := 0
	var red := 0
	for p in players.values():
		if p.team == 0: blue += 1
		elif p.team == 1: red += 1
	return 0 if blue <= red else 1

func _spawn_transform(id: int) -> Transform3D:
	var spawn_root = app.get_node("TrainingMap/Spawns") if training else app.get_node("Spawns")
	var best: Transform3D = spawn_root.get_child(0).global_transform
	var best_distance := -1.0
	for marker in spawn_root.get_children():
		if game_mode == "tdm" and players.has(id):
			var blue_side: bool = marker.global_position.z >= 0.0
			if blue_side != (players[id].team == 0): continue
		var nearest := 1000.0
		for other in players.values():
			if other.peer_id != id and not other.dead: nearest = minf(nearest, marker.global_position.distance_to(other.position))
		if nearest > best_distance:
			best_distance = nearest
			best = marker.global_transform
	return best

func _start_round() -> void:
	running = true
	ended = false
	winner = ""
	remaining = match_seconds
	team_scores = {0: 0, 1: 0}
	for p in players.values():
		p.kills = 0
		p.deaths = 0
		p.reset_at(_spawn_transform(p.peer_id))

func rematch() -> void:
	if active and multiplayer.is_server() and players.size() >= 2:
		_start_round()
		state_sequence += 1
		_broadcast_world()

func start_match() -> void:
	if not active or not multiplayer.is_server() or running or players.size() < 2: return
	_start_round()
	state_sequence += 1
	_broadcast_world()

func leave(message: String = "") -> void:
	if is_instance_valid(app) and app.audio: app.audio.stop_all()
	if app and app.online and not training and not app.online.room_code.is_empty(): app.online.clear_room()
	authenticated_tokens.clear()
	if is_instance_valid(app) and app.has_node("WeaponEffects"): app.get_node("WeaponEffects").clear()
	training = false
	if is_instance_valid(app) and app.has_node("TrainingMap"):
		var arena = app.get_node("TrainingMap")
		app.remove_child(arena)
		arena.queue_free()
	active = false
	connecting = false
	running = false
	ended = false
	winner = ""
	remaining = match_seconds
	clock = 0
	pending.clear()
	ping_sent.clear()
	state_sequence = 0
	received_sequence = -1
	max_players = MAX_PLAYERS
	match_seconds = MATCH_SECONDS
	kill_limit = KILL_LIMIT
	game_mode = "ffa"
	team_scores = {0: 0, 1: 0}
	if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for p in players.values():
		p.get_parent().remove_child(p)
		p.queue_free()
	players.clear()
	if is_instance_valid(app) and is_instance_valid(app.ui): app.show_menu(message)

func _disconnected(id: int) -> void:
	if not active or not multiplayer.is_server(): return
	if players.has(id):
		players[id].queue_free()
		players.erase(id)
	ping_sent.erase(id)
	state_sequence += 1
	_broadcast_world()

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func request_input(seq: int, movement: Vector2, look_yaw: float, look_pitch: float, sprinting: bool, jumping: bool, aiming: bool = false) -> void:
	if not multiplayer.is_server(): return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id) or not movement.is_finite() or not is_finite(look_yaw) or not is_finite(look_pitch): return
	var p = players[id]
	if seq <= p.last_packet: return
	p.last_packet = seq
	p.controls = movement.limit_length(1)
	p.yaw = wrapf(look_yaw, -PI, PI)
	p.pitch = clampf(look_pitch, -1.45, 1.45)
	p.sprint = sprinting and movement.y < -0.3 and not p.is_reloading and not aiming
	p.is_aiming = aiming and not p.sprint and not p.is_reloading
	p.jump_pending = p.jump_pending or jumping
	p.input_age = 0

func action(kind: int, slot: int, aim_yaw: float, aim_pitch: float, shot: int = 0) -> void:
	if not active: return
	if multiplayer.is_server(): _queue_action(1, kind, slot, aim_yaw, aim_pitch, shot)
	else: request_action.rpc_id(1, kind, slot, aim_yaw, aim_pitch, shot)

@rpc("any_peer", "call_remote", "reliable", 0)
func request_action(kind: int, slot: int, aim_yaw: float, aim_pitch: float, shot: int = 0) -> void:
	if multiplayer.is_server(): _queue_action(multiplayer.get_remote_sender_id(), kind, slot, aim_yaw, aim_pitch, shot)

func _queue_action(id: int, kind: int, slot: int, aim_yaw: float, aim_pitch: float, shot: int = 0) -> void:
	if not running or ended or not players.has(id) or players[id].dead: return
	if not is_finite(aim_yaw) or not is_finite(aim_pitch) or absf(aim_pitch) > 1.45 or kind not in [0, 1, 2]: return
	if slot < 0 or slot >= players[id].weapons.DATA.size(): return
	if pending.size() >= 64: return
	pending.append({"id": id, "kind": kind, "slot": slot, "yaw": aim_yaw, "pitch": aim_pitch, "shot": shot})

func _physics_process(delta: float) -> void:
	if connecting:
		connect_timeout -= delta
		if connect_timeout <= 0: leave("Connection timed out. Check IP, port and firewall.")
	if not active or not multiplayer.is_server(): return
	clock += delta
	if running and not ended:
		remaining = maxf(0, remaining - delta)
		if remaining == 0: _finish()
	for p in players.values():
		p.weapons.tick(delta)
		if p.dead and not ended and clock >= p.respawn_at: p.reset_at(_spawn_transform(p.peer_id))
	for command in pending:
		if not players.has(command.id) or not running or ended: continue
		var p = players[command.id]
		if command.kind == 0 and command.shot > 0:
			if command.shot <= p.last_shot_id: continue
			p.last_shot_id = command.shot
			if p.local_player: p.get_node("WeaponController").reconcile(command.shot)
		if p.dead: continue
		if command.kind == 2:
			p.weapons.switch_to(command.slot)
		elif command.kind == 1:
			if command.slot == p.weapons.slot and p.weapons.reload(): emit_event("reload", p.peer_id, 0, "")
		elif command.slot == p.weapons.slot and not p.sprint:
			# Origin is server-owned. Reject gross direction jumps from the latest movement input.
			if not p.local_player and p.peer_id > 0 and p.last_packet >= 0 and p.input_age < 0.3 and absf(angle_difference(p.yaw,command.yaw)) > deg_to_rad(120): continue
			if p.camera.global_position.distance_to(p.get_node("WeaponController").muzzle(true).global_position) > 2.0: continue
			if not p.weapons.fire(): continue
			p.yaw = wrapf(command.yaw, -PI, PI)
			p.pitch = clampf(command.pitch, -1.45, 1.45)
			p.rotation.y = p.yaw
			p.camera.rotation.x = p.pitch
			_fire(p, command.shot)
	pending.clear()
	if training: return
	snapshot_clock -= delta
	if snapshot_clock <= 0:
		snapshot_clock = 0.05
		state_sequence += 1
		var packet := var_to_bytes(_states()).compress(FileAccess.COMPRESSION_DEFLATE)
		for id in _connected_peers(): state.rpc_id(id, state_sequence, packet, remaining, running, ended, winner, _rules())
	ping_clock -= delta
	if ping_clock <= 0:
		ping_clock = 1.0
		for id in players:
			if id == 1: continue
			var stamp := Time.get_ticks_msec()
			ping_sent[id] = stamp
			probe.rpc_id(id, stamp)

func _fire(p: Node, shot: int) -> void:
	var spec = p.weapons.DATA[p.weapons.slot]
	var hits: Dictionary = {}
	var head_hit := false
	for pellet in spec.pellets:
		var hit := Shooting.cast(p,p.yaw,p.pitch)
		if pellet == 0:
			if training: shot_result(p.peer_id, shot, p.weapons.slot, hit.point, hit.normal)
			else: shot_result.rpc(p.peer_id, shot, p.weapons.slot, hit.point, hit.normal)
		if players.has(hit.victim) and not players[hit.victim].dead:
			hits[hit.victim] = hits.get(hit.victim,0) + (spec.head_damage if hit.head else spec.damage)
			head_hit = head_hit or hit.head
	for victim in hits: damage(p.peer_id,victim,hits[victim])
	if not hits.is_empty():
		if p.peer_id == 1: app.ui.hit_marker(head_hit)
		elif not training: confirmed_hit.rpc_id(p.peer_id,head_hit)

@rpc("authority", "call_local", "reliable", 0)
func shot_result(id: int, shot: int, slot: int, point: Vector3, normal: Vector3) -> void:
	if not players.has(id): return
	var p = players[id]
	p.get_node("WeaponController").feedback(point, normal, slot, not p.local_player or shot == 0)

func damage(killer: int, victim: int, amount: int) -> void:
	if not multiplayer.is_server() or not running or ended or not players.has(victim): return
	if game_mode == "tdm" and killer != victim and players.has(killer) and players[killer].team == players[victim].team: return
	var target = players[victim]
	if target.dead: return
	target.hp = maxi(0, target.hp - amount)
	emit_event("hurt", victim, amount, "")
	if target.hp > 0: return
	target.dead = true
	target.weapons.reload_left = 0
	target.is_aiming = false
	target.get_node("WeaponController").reset_state()
	target.get_node("Body").fall()
	target.deaths += 1
	target.collision_layer = 0
	target.velocity = Vector3.ZERO
	target.respawn_at = clock + RESPAWN_SECONDS
	var killer_name := "Environment"
	if killer != victim and players.has(killer):
		players[killer].kills += 1
		if game_mode == "tdm": team_scores[players[killer].team] = int(team_scores.get(players[killer].team,0)) + 1
		killer_name = players[killer].player_name
	emit_event("death", victim, killer, killer_name + " → " + target.player_name)
	if players.has(killer) and ((game_mode == "tdm" and int(team_scores.get(players[killer].team,0)) >= kill_limit) or (game_mode != "tdm" and players[killer].kills >= kill_limit)): _finish()

func _finish() -> void:
	ended = true
	running = false
	if game_mode == "tdm":
		var blue := int(team_scores.get(0,0))
		var red := int(team_scores.get(1,0))
		winner = "BLUE TEAM WINS!" if blue > red else ("RED TEAM WINS!" if red > blue else "DRAW")
		state_sequence += 1
		_broadcast_world()
		return
	var best := -1
	var leaders: Array[String] = []
	for p in players.values():
		if p.kills > best:
			best = p.kills
			leaders = [p.player_name]
		elif p.kills == best: leaders.append(p.player_name)
	winner = leaders[0] + " wins!" if leaders.size() == 1 else "Draw"
	state_sequence += 1
	_broadcast_world()

func _states() -> Array:
	var result := []
	for p in players.values(): result.append(p.snapshot(clock))
	return result

@rpc("authority", "call_remote", "reliable", 0)
func world(seq: int, roster: Array, time_left: float, started: bool, finished: bool, result: String, rules: Dictionary = {}) -> void:
	if seq <= received_sequence: return
	received_sequence = seq
	active = true
	connecting = false
	_sync(roster, time_left, started, finished, result, rules)
	app.enter_match()

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func state(seq: int, packet: PackedByteArray, time_left: float, started: bool, finished: bool, result: String, rules: Dictionary = {}) -> void:
	if not active or seq <= received_sequence: return
	received_sequence = seq
	var roster: Array = bytes_to_var(packet.decompress_dynamic(16384, FileAccess.COMPRESSION_DEFLATE))
	_sync(roster, time_left, started, finished, result, rules)

func _sync(roster: Array, time_left: float, started: bool, finished: bool, result: String, rules: Dictionary = {}) -> void:
	if ended and not finished and app.in_match and not app.paused and not app.ui.settings_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	remaining = time_left
	running = started
	ended = finished
	winner = result
	if not rules.is_empty():
		max_players = int(rules.get("max_players", max_players))
		match_seconds = float(rules.get("match_seconds", match_seconds))
		kill_limit = int(rules.get("kill_limit", kill_limit))
		game_mode = str(rules.get("mode", game_mode))
		team_scores = rules.get("team_scores",team_scores)
	var present := []
	for entry in roster:
		present.append(entry.id)
		if not players.has(entry.id): _add_player(entry.id, entry.name)
		players[entry.id].apply_snapshot(entry)
	for id in players.keys():
		if id not in present:
			players[id].queue_free()
			players.erase(id)

@rpc("authority", "call_local", "reliable", 0)
func event(kind: String, id: int, value: int, text: String) -> void:
	if not players.has(id): return
	var p = players[id]
	var origin: Vector3 = Vector3.INF if p.local_player else p.position
	if kind == "reload": app.audio.play("reload", origin)
	elif kind == "hurt" and p.local_player:
		app.ui.get_node("DamageFeedback").hit(value)
		p.hurt_kick = minf(1.0,p.hurt_kick+value/50.0)
	elif kind == "death":
		app.audio.play("death", origin)
		app.ui.add_kill(text)

@rpc("authority", "call_remote", "reliable", 0)
func confirmed_hit(headshot: bool = false) -> void:
	app.ui.hit_marker(headshot)

@rpc("authority", "call_remote", "unreliable", 3)
func probe(stamp: int) -> void:
	pong.rpc_id(1, stamp)

@rpc("any_peer", "call_remote", "unreliable", 3)
func pong(stamp: int) -> void:
	if not multiplayer.is_server(): return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id) and ping_sent.get(id, -1) == stamp: players[id].ping = clampi(Time.get_ticks_msec() - stamp, 0, 999)


func _connected_peers() -> Array:
	var result := []
	if training: return result
	for id in multiplayer.get_peers():
		if multiplayer.multiplayer_peer.get_peer(id).get_state() == ENetPacketPeer.STATE_CONNECTED: result.append(id)
	return result

func _broadcast_world() -> void:
	for id in _connected_peers(): world.rpc_id(id, state_sequence, _states(), remaining, running, ended, winner, _rules())

func _rules() -> Dictionary:
	return {"mode": game_mode, "max_players": max_players, "match_seconds": match_seconds, "kill_limit": kill_limit, "team_scores": team_scores}

func emit_event(kind: String, id: int, value: int, message: String) -> void:
	if training: event(kind, id, value, message)
	else: event.rpc(kind, id, value, message)


