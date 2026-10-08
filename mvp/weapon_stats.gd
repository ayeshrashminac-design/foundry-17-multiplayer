extends Resource

@export var name := "ZC57"
@export var ammo_type := "5.56"
@export var sound := "rifle"
@export var automatic := true
@export var damage := 25
@export var head_damage := 50
@export var interval := 0.12
@export var magazine := 30
@export var reserve := 120
@export var reload := 1.6
@export var switch_delay := 0.25
@export var range := 100.0
@export_group("Handling")
@export var standing_spread := 0.0015
@export var moving_spread := 0.012
@export var airborne_spread := 0.035
@export var ads_spread_multiplier := 0.3
@export var sustained_spread := 0.001
@export var camera_recoil := 0.009
@export var horizontal_recoil := 0.003
@export var visual_recoil := 0.045
@export var ads_fov := 65.0
@export var ads_position := Vector3(0, 0, -0.4)



@export_file("*.tscn") var visual_scene := ""
@export var pellets := 1
@export var pellet_spread := 0.0
@export var casing_type := 0

@export var hip_position := Vector3(0.17,-0.17,-0.55)
@export var ads_speed := 12.0
@export var aim_move_scale := 0.62
