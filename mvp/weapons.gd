extends RefCounted

const DATA := [preload("res://tactical/rifle.tres"), preload("res://tactical/pistol.tres")]
var slot := 0
var ammo: Array = []
var reserve: Array = []
var heat := 0.0

func _init() -> void:
	ammo.resize(DATA.size())
	reserve.resize(DATA.size())
	for index in DATA.size():
		ammo[index] = DATA[index].magazine
		reserve[index] = DATA[index].reserve
var cooldown := 0.0
var reload_left := 0.0

func tick(delta: float) -> void:
	heat = maxf(0, heat - delta * 3.0)
	cooldown = maxf(0, cooldown - delta)
	if reload_left > 0:
		reload_left = maxf(0, reload_left - delta)
		if reload_left == 0:
			var count: int = mini(DATA[slot].magazine - ammo[slot], reserve[slot])
			ammo[slot] += count
			reserve[slot] -= count

func switch_to(next: int) -> void:
	if next < 0 or next >= DATA.size() or next == slot: return
	slot = next
	heat = 0
	reload_left = 0
	cooldown = maxf(cooldown, DATA[slot].switch_delay)

func reload() -> bool:
	if reload_left > 0 or ammo[slot] >= DATA[slot].magazine or reserve[slot] <= 0: return false
	reload_left = DATA[slot].reload
	return true

func fire() -> bool:
	if cooldown > 0 or reload_left > 0 or ammo[slot] <= 0: return false
	ammo[slot] -= 1
	heat = minf(5, heat + 1)
	cooldown = DATA[slot].interval
	return true

