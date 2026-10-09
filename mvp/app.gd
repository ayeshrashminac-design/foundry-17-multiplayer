extends Node3D

@onready var network = $Network
@onready var ui = $UI
@onready var settings = $Settings
@onready var audio = $Audio
@onready var online = $Online
var in_match := false
var paused := false

func _ready() -> void:
	var lobby := Control.new()
	lobby.name = "ArenaLobby"
	lobby.set_script(preload("res://mvp/arena_lobby.gd"))
	$UI.add_child(lobby)
	$Arena/ArenaNavigation.enabled = false
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

func enter_match() -> void:
	if not in_match:
		in_match = true
		paused = false
		$Arena.visible = not network.training
		$ArenaAdditions.visible = not network.training
		ui.get_node("Menu").hide()
		ui.get_node("HUD").show()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func show_menu(message: String = "") -> void:
	in_match = false
	paused = false
	$Arena.hide()
	$ArenaAdditions.hide()
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

