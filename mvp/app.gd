extends Node3D

@onready var network = $Network
@onready var ui = $UI
@onready var settings = $Settings
@onready var audio = $Audio
@onready var online = $Online
var in_match := false
var paused := false

func _ready() -> void:
	var tactical_hud := Control.new()
	tactical_hud.name = "TacticalHUD"
	tactical_hud.set_script(preload("res://mvp/tactical_hud.gd"))
	$UI.add_child(tactical_hud)
	$UI.move_child(tactical_hud, $UI.get_node("HUD").get_index() + 1)
	var lobby := Control.new()
	lobby.name = "ArenaLobby"
	lobby.set_script(preload("res://mvp/arena_lobby.gd"))
	$UI.add_child(lobby)
	$Arena/ArenaNavigation.enabled = false
	$BackroomsArena.hide()
	$Arena/Pickups.hide()
	$Arena/Pickups.process_mode = Node.PROCESS_MODE_DISABLED
	$UI.get_node("Menu").hide()
	$UpdateGate.begin()
	var allowed: bool = await $UpdateGate.finished
	if not allowed: return
	if not network.active: show_menu()
	# Optional direct launch is useful for local multi-process testing.
	var args := OS.get_cmdline_user_args()
	if "--host" in args:
		network.host(7777, "Host")
	elif "--join" in args:
		network.join("127.0.0.1", 7777, "Player")
	elif "--training" in args:
		network.start_training("Player")

func input_enabled() -> bool:
	return in_match and network.running and not paused and not network.ended and not ui.settings_open and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func update_map_visibility() -> void:
	var foundry_active: bool = in_match and not network.training and network.map_id == "foundry"
	var backrooms_active: bool = in_match and not network.training and network.map_id == "backrooms"
	_set_map_active($Arena, foundry_active)
	_set_map_active($ArenaAdditions, foundry_active)
	$Arena/ArenaNavigation.enabled = foundry_active
	_set_map_active($BackroomsArena, backrooms_active)

func _set_map_active(map_root: Node3D, enabled: bool) -> void:
	if map_root.has_meta("map_active") and map_root.get_meta("map_active") == enabled: return
	map_root.set_meta("map_active", enabled)
	map_root.visible = enabled
	for body in map_root.find_children("*", "CollisionObject3D", true, false):
		if not body.has_meta("map_collision_layer"):
			body.set_meta("map_collision_layer", body.collision_layer)
			body.set_meta("map_collision_mask", body.collision_mask)
		body.collision_layer = int(body.get_meta("map_collision_layer")) if enabled else 0
		body.collision_mask = int(body.get_meta("map_collision_mask")) if enabled else 0
	for region in map_root.find_children("*", "NavigationRegion3D", true, false):
		region.enabled = enabled

func enter_match() -> void:
	if not in_match:
		in_match = true
		paused = false
		ui.get_node("Menu").hide()
		ui.get_node("HUD").show()
		ui.get_node("Notice").hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	update_map_visibility()

func show_menu(message: String = "") -> void:
	in_match = false
	paused = false
	update_map_visibility()
	ui.get_node("Menu").show()
	ui.get_node("HUD").hide()
	ui.get_node("Pause").hide()
	ui.get_node("Scoreboard").hide()
	ui.get_node("SettingsPanel").hide()
	for panel in ["AuthPanel", "FriendsPanel", "InvitesPanel", "RoomPanel"]:
		if ui.has_node(panel): ui.get_node(panel).hide()
	ui.settings_open = false
	ui.status(message)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func toggle_pause() -> void:
	if not in_match or not network.running: return
	paused = not paused
	ui.get_node("Pause").visible = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if ui.settings_open: ui.close_settings()
		elif in_match and not network.ended: toggle_pause()

