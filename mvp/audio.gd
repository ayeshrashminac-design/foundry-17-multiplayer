extends Node

func stop_all() -> void:
	for sound in get_children():
		if sound is AudioStreamPlayer or sound is AudioStreamPlayer3D:
			sound.stop()
			sound.stream = null
			sound.queue_free()

func _exit_tree() -> void:
	stop_all()

var sounds: Dictionary = {}
const STONE_STEPS = [
	preload("res://assets/fps_asset_kit/Fantozzi-StoneL1.ogg"),
	preload("res://assets/fps_asset_kit/Fantozzi-StoneL2.ogg"),
	preload("res://assets/fps_asset_kit/Fantozzi-StoneL3.ogg"),
	preload("res://assets/fps_asset_kit/Fantozzi-StoneR1.ogg"),
	preload("res://assets/fps_asset_kit/Fantozzi-StoneR2.ogg"),
	preload("res://assets/fps_asset_kit/Fantozzi-StoneR3.ogg")
]
var step_index := 0
const RATE := 22050

func _ready() -> void:
	var specs := {"rifle": [0.13, 100, 0.85], "pistol": [0.17, 160, 0.8], "reload": [0.22, 1100, 0.5], "step": [0.08, 70, 0.75], "jump": [0.12, 220, 0.35], "landing": [0.13, 65, 0.7], "hit": [0.08, 900, 0.2], "death": [0.3, 80, 0.5], "click": [0.05, 650, 0.1]}
	var random := RandomNumberGenerator.new()
	specs["hurt"] = [0.18, 55, 0.32]
	specs["empty"] = [0.06, 450, 0.25]
	specs["shotgun"] = [0.24, 65, 0.9]
	specs["smg"] = [0.10, 180, 0.9]
	random.seed = 42
	for key in specs:
		var spec: Array = specs[key]
		var bytes := PackedByteArray()
		var count := int(spec[0] * RATE)
		bytes.resize(count * 2)
		for i in count:
			var t := float(i) / RATE
			var envelope := pow(1.0 - float(i) / count, 3)
			var sample: float = (sin(TAU * spec[1] * t) * (1.0 - spec[2]) + random.randf_range(-1, 1) * spec[2]) * envelope * 0.55
			bytes.encode_s16(i * 2, int(sample * 32767))
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = RATE
		wav.data = bytes
		sounds[key] = wav

func play(key: String, location: Vector3 = Vector3.INF) -> void:
	if not sounds.has(key) or get_child_count() >= 32: return
	var sound: Node
	if location == Vector3.INF:
		sound = AudioStreamPlayer.new()
	else:
		sound = AudioStreamPlayer3D.new()
		sound.position = location
		sound.max_distance = 45
		sound.unit_size = 5
	sound.stream = sounds[key]
	if key == "step":
		sound.stream = STONE_STEPS[step_index % STONE_STEPS.size()]
		step_index += 1
	sound.bus = "SFX"
	sound.volume_db = -10.0 if key == "step" else -5.0
	add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()
