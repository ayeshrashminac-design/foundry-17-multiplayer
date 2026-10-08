extends Node

var sensitivity := 0.0025
var master := 0.8
var sfx := 0.8
var fullscreen := false
var resolution := 0
var character_id := 0
const SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]

func _ready() -> void:
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	var config := ConfigFile.new()
	if config.load("user://fps_settings.cfg") == OK:
		sensitivity = clampf(float(config.get_value("settings", "sensitivity", sensitivity)), 0.0005, 0.01)
		master = clampf(float(config.get_value("settings", "master", master)), 0, 1)
		sfx = clampf(float(config.get_value("settings", "sfx", sfx)), 0, 1)
		fullscreen = bool(config.get_value("settings", "fullscreen", false))
		resolution = clampi(int(config.get_value("settings", "resolution", 0)), 0, 2)
		character_id = preload("res://mvp/character_catalog.gd").valid_id(int(config.get_value("settings","character_id",0)))
	apply()

func apply() -> void:
	for pair in [["Master", master], ["SFX", sfx]]:
		var index := AudioServer.get_bus_index(pair[0])
		AudioServer.set_bus_mute(index, pair[1] <= 0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(pair[1], 0.0001)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		if not fullscreen: DisplayServer.window_set_size(SIZES[resolution])

func save() -> void:
	apply()
	var config := ConfigFile.new()
	for key in ["sensitivity", "master", "sfx", "fullscreen", "resolution", "character_id"]: config.set_value("settings", key, get(key))
	config.save("user://fps_settings.cfg")
