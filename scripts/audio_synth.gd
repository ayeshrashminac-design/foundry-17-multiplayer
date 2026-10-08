extends Node

# Procedural Sound Synthesizer for Classic Low-Poly Sci-Fi Military FPS
# Generates realistic low-poly sci-fi procedural audio samples using AudioStreamWAV

var sample_rate := 22050
var sounds := {}

func _ready() -> void:
	_generate_all_sounds()

func _generate_all_sounds() -> void:
	# Human Weapon SFX
	sounds["rifle_shoot"] = _synth_gunshot(0.18, 300.0, 70.0, 0.4)
	sounds["shotgun_shoot"] = _synth_shotgun(0.35, 180.0, 45.0)
	sounds["sniper_shoot"] = _synth_sniper(0.55, 450.0, 50.0)
	sounds["pistol_shoot"] = _synth_gunshot(0.14, 380.0, 90.0, 0.3)
	
	# Alien Weapon SFX
	sounds["plasma_shoot"] = _synth_plasma(0.22, 780.0, 160.0, 0.5)
	sounds["plasma_pistol"] = _synth_plasma(0.15, 950.0, 220.0, 0.6)
	sounds["cannon_shoot"] = _synth_cannon(0.55, 130.0, 30.0)
	sounds["sword_swing"] = _synth_sword_swing(0.28, 600.0, 200.0)
	
	# Reload & Mechanical
	sounds["reload_click"] = _synth_click(0.08, 1200.0)
	sounds["reload_done"] = _synth_beep(0.15, 880.0)
	sounds["zoom_in"] = _synth_beep(0.08, 1400.0)
	sounds["zoom_out"] = _synth_beep(0.08, 900.0)
	
	# Impacts & Destruction
	sounds["bullet_hit_metal"] = _synth_metal_hit(0.12, 1400.0)
	sounds["bullet_hit_flesh"] = _synth_flesh_hit(0.15)
	sounds["explosion"] = _synth_explosion(0.65)
	sounds["acid_pop"] = _synth_acid_pop(0.3)
	
	# Alien Vocalizations
	sounds["alien_screech"] = _synth_alien_screech(0.45)
	sounds["alien_growl"] = _synth_alien_growl(0.6)
	sounds["boss_roar"] = _synth_boss_roar(1.1)
	sounds["boss_laser"] = _synth_laser_beam(0.8)
	
	# Environment & Atmosphere
	sounds["alarm_beep"] = _synth_alarm(0.4)
	sounds["pickup_ammo"] = _synth_pickup(0.18, 523.25, 783.99)
	sounds["pickup_health"] = _synth_pickup(0.25, 440.0, 880.0)
	sounds["terminal_beep"] = _synth_beep(0.1, 1046.5)
	sounds["player_hurt"] = _synth_flesh_hit(0.2)
	sounds["jump"] = _synth_whoosh(0.15)
	sounds["footstep"] = _synth_footstep(0.08)
	sounds["energy_bridge_hum"] = _synth_energy_hum(1.0)
	sounds["vehicle_engine"] = _synth_engine(0.8)

func play_sound(sound_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> AudioStreamPlayer:
	if not sounds.has(sound_name):
		return null
	var player = AudioStreamPlayer.new()
	player.stream = sounds[sound_name]
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale * randf_range(0.96, 1.04)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	return player

func play_sound_3d(sound_name: String, pos: Vector3, volume_db: float = 0.0, max_distance: float = 40.0) -> AudioStreamPlayer3D:
	if not sounds.has(sound_name):
		return null
	var player = AudioStreamPlayer3D.new()
	player.stream = sounds[sound_name]
	player.volume_db = volume_db
	player.max_distance = max_distance
	player.unit_size = 6.0
	player.pitch_scale = randf_range(0.94, 1.06)
	get_tree().current_scene.add_child(player)
	player.global_position = pos
	player.play()
	player.finished.connect(player.queue_free)
	return player

func _create_wav(data: PackedByteArray) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _synth_gunshot(dur: float, start_freq: float, end_freq: float, noise_mix: float) -> AudioStreamWAV:
	var num_samples = int(dur * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	var phase = 0.0
	for i in range(num_samples):
		var t = float(i) / num_samples
		var freq = lerp(start_freq, end_freq, t)
		phase += 2.0 * PI * freq / sample_rate
		var env = pow(1.0 - t, 2.4)
		var tone = sin(phase)
		var noise = randf_range(-1.0, 1.0)
		var sample = (tone * (1.0 - noise_mix) + noise * noise_mix) * env
		var s_int = int(clampf(sample * 30000.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, s_int)
	return _create_wav(bytes)

func _synth_sniper(dur: float, start_freq: float, end_freq: float) -> AudioStreamWAV:
	var num_samples = int(dur * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	var phase = 0.0
	for i in range(num_samples):
		var t = float(i) / num_samples
		var freq = lerp(start_freq, end_freq, pow(t, 0.4))
		phase += 2.0 * PI * freq / sample_rate
		var env = pow(1.0 - t, 1.5)
		var tone = sin(phase) * 0.4
		var crack = randf_range(-1.0, 1.0) * (1.0 - t * 0.5)
		var sample = (tone + crack * 0.6) * env
		var s_int = int(clampf(sample * 32760.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, s_int)
	return _create_wav(bytes)

func _synth_shotgun(dur: float, start_freq: float, end_freq: float) -> AudioStreamWAV:
	var num_samples = int(dur * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	var phase = 0.0
	for i in range(num_samples):
		var t = float(i) / num_samples
		var freq = lerp(start_freq, end_freq, t)
		phase += 2.0 * PI * freq / sample_rate
		var env = pow(1.0 - t, 2.0)
		var tone = sin(phase) * 0.4
		var noise = randf_range(-1.0, 1.0) * 0.6
		var sample = (tone + noise) * env
		var s_int = int(clampf(sample * 32000.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, s_int)
	return _create_wav(bytes)

func _synth_plasma(dur: float, start_freq: float, end_freq: float, mod_freq: float) -> AudioStreamWAV:
	var num_samples = int(dur * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	var phase = 0.0
	for i in range(num_samples):
		var t = float(i) / num_samples
		var freq = lerp(start_freq, end_freq, pow(t, 0.5))
		phase += 2.0 * PI * freq / sample_rate
		var env = pow(1.0 - t, 1.8)
		var mod = sin(2.0 * PI * 80.0 * (float(i) / sample_rate))
		var tone = sin(phase + mod * 2.0)
		var sample = tone * env
		var s_int = int(clampf(sample * 28000.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, s_int)
	return _create_wav(bytes)

func _synth_sword_swing(dur: float, start_freq: float, end_freq: float) -> AudioStreamWAV:
	var num_samples = int(dur * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	var phase = 0.0
	for i in range(num_samples):
		var t = float(i) / num_samples
		var freq = lerp(start_freq, end_freq, t)
		phase += 2.0 * PI * freq / sample_rate
		var env = sin(t * PI)
		var buzz = sin(phase * 2.5) * 0.4
		var tone = sin(phase) * 0.6
		var sample = (tone + buzz) * env
		var s_int = int(clampf(sample * 29000.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, s_int)
	return _create_wav(bytes)

func _synth_cannon(dur: float, start_freq: float, end_freq: float) -> AudioStreamWAV:
	var num_samples = int(dur * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	var phase = 0.0
	for i in range(num_samples):
		var t = float(i) / num_samples
		var freq = lerp(start_freq, end_freq, t)
		phase += 2.0 * PI * freq / sample_rate
		var env = pow(1.0 - t, 1.5)
		var tone = sin(phase) * 0.5
		var noise = randf_range(-1.0, 1.0) * 0.5
		var sample = (tone + noise) * env
		var s_int = int(clampf(sample * 32000.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, s_int)
	return _create_wav(bytes)

func _synth_metal_hit(dur: float, freq: float) -> AudioStreamWAV:
	var num_samples = int(dur * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / num_samples
		var env = exp(-t * 25.0)
		var tone = sin(2.0 * PI * freq * (float(i) / sample_rate)) * 0.6
		var tone2 = sin(2.0 * PI * (freq * 1.6) * (float(i) / sample_rate)) * 0.4
		var sample = (tone + tone2) * env
		var s_int = int(clampf(sample * 25000.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, s_int)
	return _create_wav(bytes)

func _synth_flesh_hit(dur: float) -> AudioStreamWAV:
	var num_samples = int(dur * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / num_samples
		var env = exp(-t * 18.0)
		var low = sin(2.0 * PI * 120.0 * (float(i) / sample_rate)) * 0.5
		var noise = randf_range(-0.5, 0.5)
		var sample = (low + noise) * env
		var s_int = int(clampf(sample * 26000.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, s_int)
	return _create_wav(bytes)

func _synth_explosion(dur: float) -> AudioStreamWAV:
	var num_samples = int(dur * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	var filter = 0.0
	for i in range(num_samples):
		var t = float(i) / num_samples
		var env = pow(1.0 - t, 1.6)
		var noise = randf_range(-1.0, 1.0)
		filter = filter * 0.85 + noise * 0.15
		var sub = sin(2.0 * PI * (60.0 * (1.0 - t)) * (float(i) / sample_rate)) * 0.5
		var sample = (filter + sub) * env
		var s_int = int(clampf(sample * 32000.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, s_int)
	return _create_wav(bytes)

func _synth_acid_pop(dur: float) -> AudioStreamWAV:
	var num_samples = int(dur * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / num_samples
		var env = pow(1.0 - t, 2.0)
		var freq = lerp(400.0, 80.0, pow(t, 0.4))
		var tone = sin(2.0 * PI * freq * (float(i) / sample_rate))
		var noise = randf_range(-0.4, 0.4)
		var sample = (tone * 0.6 + noise * 0.4) * env
		var s_int = int(clampf(sample * 28000.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, s_int)
	return _create_wav(bytes)

func _synth_alien_screech(dur: float) -> AudioStreamWAV:
	var num_samples = int(dur * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / num_samples
		var env = sin(t * PI)
		var freq = 600.0 + sin(t * 40.0) * 300.0 + randf_range(-40.0, 40.0)
		var tone = sin(2.0 * PI * freq * (float(i) / sample_rate))
		var sample = tone * env
		var s_int = int(clampf(sample * 26000.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, s_int)
	return _create_wav(bytes)

func _synth_alien_growl(dur: float) -> AudioStreamWAV:
	var num_samples = int(dur * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / num_samples
		var env = sin(t * PI)
		var freq = 90.0 + sin(t * 25.0) * 45.0
		var tone = sin(2.0 * PI * freq * (float(i) / sample_rate))
		var noise = randf_range(-0.3, 0.3)
		var sample = (tone + noise) * env
		var s_int = int(clampf(sample * 28000.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, s_int)
	return _create_wav(bytes)

func _synth_boss_roar(dur: float) -> AudioStreamWAV:
	var num_samples = int(dur * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / num_samples
		var env = sin(t * PI)
		var freq = 75.0 + sin(t * 12.0) * 35.0
		var tone = sin(2.0 * PI * freq * (float(i) / sample_rate))
		var tone2 = sin(2.0 * PI * (freq * 2.1) * (float(i) / sample_rate)) * 0.4
		var noise = randf_range(-0.35, 0.35)
		var sample = (tone + tone2 + noise) * env
		var s_int = int(clampf(sample * 31000.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, s_int)
	return _create_wav(bytes)

func _synth_laser_beam(dur: float) -> AudioStreamWAV:
	var num_samples = int(dur * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / num_samples
		var env = 1.0 if t < 0.8 else (1.0 - (t - 0.8) / 0.2)
		var freq = 120.0 + sin(float(i) / sample_rate * 300.0) * 80.0
		var tone = sin(2.0 * PI * freq * (float(i) / sample_rate))
		var sample = tone * env
		var s_int = int(clampf(sample * 27000.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, s_int)
	return _create_wav(bytes)

func _synth_alarm(dur: float) -> AudioStreamWAV:
	var num_samples = int(dur * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / num_samples
		var freq = 800.0 if fmod(t, 0.2) < 0.1 else 600.0
		var tone = sin(2.0 * PI * freq * (float(i) / sample_rate))
		var sample = tone * 0.6
		var s_int = int(clampf(sample * 24000.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, s_int)
	return _create_wav(bytes)

func _synth_pickup(dur: float, freq1: float, freq2: float) -> AudioStreamWAV:
	var num_samples = int(dur * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / num_samples
		var freq = freq1 if t < 0.5 else freq2
		var env = 1.0 - t
		var tone = sin(2.0 * PI * freq * (float(i) / sample_rate))
		var sample = tone * env
		var s_int = int(clampf(sample * 24000.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, s_int)
	return _create_wav(bytes)

func _synth_beep(dur: float, freq: float) -> AudioStreamWAV:
	var num_samples = int(dur * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / num_samples
		var env = exp(-t * 8.0)
		var tone = sin(2.0 * PI * freq * (float(i) / sample_rate))
		var sample = tone * env
		var s_int = int(clampf(sample * 22000.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, s_int)
	return _create_wav(bytes)

func _synth_click(dur: float, freq: float) -> AudioStreamWAV:
	var num_samples = int(dur * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / num_samples
		var env = exp(-t * 40.0)
		var tone = sin(2.0 * PI * freq * (float(i) / sample_rate))
		var sample = tone * env
		var s_int = int(clampf(sample * 25000.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, s_int)
	return _create_wav(bytes)

func _synth_whoosh(dur: float) -> AudioStreamWAV:
	var num_samples = int(dur * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	var filt = 0.0
	for i in range(num_samples):
		var t = float(i) / num_samples
		var env = sin(t * PI)
		var noise = randf_range(-1.0, 1.0)
		filt = filt * 0.9 + noise * 0.1
		var sample = filt * env
		var s_int = int(clampf(sample * 20000.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, s_int)
	return _create_wav(bytes)

func _synth_footstep(dur: float) -> AudioStreamWAV:
	var num_samples = int(dur * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / num_samples
		var env = exp(-t * 30.0)
		var noise = randf_range(-0.5, 0.5)
		var tone = sin(2.0 * PI * 90.0 * (float(i) / sample_rate)) * 0.5
		var sample = (tone + noise) * env
		var s_int = int(clampf(sample * 18000.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, s_int)
	return _create_wav(bytes)

func _synth_energy_hum(dur: float) -> AudioStreamWAV:
	var num_samples = int(dur * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / num_samples
		var tone1 = sin(2.0 * PI * 110.0 * (float(i) / sample_rate)) * 0.4
		var tone2 = sin(2.0 * PI * 220.0 * (float(i) / sample_rate)) * 0.3
		var tone3 = sin(2.0 * PI * 330.0 * (float(i) / sample_rate)) * 0.15
		var sample = tone1 + tone2 + tone3
		var s_int = int(clampf(sample * 20000.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, s_int)
	return _create_wav(bytes)

func _synth_engine(dur: float) -> AudioStreamWAV:
	var num_samples = int(dur * sample_rate)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / num_samples
		var low = sin(2.0 * PI * 65.0 * (float(i) / sample_rate)) * 0.5
		var rumble = sin(2.0 * PI * 130.0 * (float(i) / sample_rate)) * 0.3
		var noise = randf_range(-0.2, 0.2)
		var sample = low + rumble + noise
		var s_int = int(clampf(sample * 22000.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, s_int)
	return _create_wav(bytes)
