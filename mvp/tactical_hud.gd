extends Control

const BLUE := Color("59cfff")
const RED := Color("ff656b")
const GOLD := Color("efcd72")
const PAPER := Color("e1edf4")
const MUTED := Color("839cac")
var app: Node
var clock := 0.0
var font: Font = ThemeDB.fallback_font
var reference_icons: Array[TextureRect] = []

func _ready() -> void:
	var face := SystemFont.new()
	face.font_names = PackedStringArray(["Bahnschrift Condensed", "Arial Narrow", "sans-serif"])
	face.font_weight = 600
	font = face
	app = get_parent().get_parent()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item in ["Top", "Health", "Ammo", "Score", "OnlineRoom", "Crosshair"]:
		app.ui.get_node("HUD/" + item).hide()
	var notice: Label = app.ui.get_node("Notice")
	notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice.offset_left = -320
	notice.offset_right = 320
	notice.offset_top = 115
	notice.offset_bottom = 140
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_font_size_override("font_size", 12)
	# Use the supplied artwork directly; crop at render time without modifying it.
	add_reference_icon(Rect2(486,47,89,31),Rect2(1130,499,100,35))
	add_reference_icon(Rect2(370,164,52,34),Rect2(1143,564,65,37))
	add_reference_icon(Rect2(450,164,24,29),Rect2(1143,651,24,30))

func add_reference_icon(region: Rect2, rect: Rect2) -> void:
	var icon := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = preload("res://mvp/ui_reference.png")
	atlas.region = region
	atlas.filter_clip = true
	icon.texture = atlas
	icon.position = rect.position
	icon.size = rect.size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://mvp/reference_icon.gdshader")
	icon.material = material
	icon.set_meta("design_rect",rect)
	add_child(icon)
	reference_icons.append(icon)

func _process(delta: float) -> void:
	visible = app.in_match and app.network.running and not app.network.ended
	app.ui.get_node("HUD/Crosshair").hide()
	var ratio := get_viewport_rect().size/Vector2(1280,720)
	for icon in reference_icons:
		var rect: Rect2 = icon.get_meta("design_rect")
		icon.position = rect.position*ratio
		icon.size = rect.size*ratio
	clock -= delta
	if visible and clock <= 0:
		clock = 0.05
		queue_redraw()

func text_at(value: String, point: Vector2, pixels := 16, tint := PAPER) -> void:
	draw_string_outline(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,3,Color(0,0,0,0.8))
	draw_string(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,tint)

func frame(rect: Rect2, tint: Color, cut := 7.0) -> void:
	var p := rect.position
	var s := rect.size
	var points := PackedVector2Array([p+Vector2(cut,0),p+Vector2(s.x,0),p+s-Vector2(0,cut),p+Vector2(s.x-cut,s.y),p+Vector2(0,s.y),p+Vector2(0,cut)])
	draw_colored_polygon(points,Color(tint.r*0.13,tint.g*0.13,tint.b*0.13,0.9))
	points.append(points[0])
	for width in [7.0,4.0]: draw_polyline(points,Color(tint,0.07),width,true)
	draw_polyline(points,Color(tint,0.85),1,true)
	draw_line(p+Vector2(cut+2,3),p+Vector2(s.x-3,3),Color(tint,0.4),1,true)

func bar(rect: Rect2, fraction: float, tint: Color) -> void:
	draw_rect(rect,Color("090d10"))
	draw_rect(rect,Color("7f898d"),false,1)
	var fill := Rect2(rect.position+Vector2(3,3),Vector2((rect.size.x-6)*clampf(fraction,0,1),rect.size.y-6))
	draw_rect(fill,tint.darkened(0.22))
	draw_rect(Rect2(fill.position,Vector2(fill.size.x,fill.size.y*0.42)),tint.lightened(0.15))

func rifle(p: Vector2, tint: Color, pistol := false) -> void:
	var shape := PackedVector2Array([Vector2(0,9),Vector2(14,9),Vector2(18,5),Vector2(45,5),Vector2(47,8),Vector2(76,8),Vector2(76,12),Vector2(45,12),Vector2(40,17),Vector2(44,29),Vector2(35,30),Vector2(29,17),Vector2(24,17),Vector2(22,26),Vector2(16,24),Vector2(17,15),Vector2(4,19),Vector2(0,19)])
	if pistol: shape = PackedVector2Array([Vector2(14,6),Vector2(61,6),Vector2(61,15),Vector2(34,15),Vector2(30,32),Vector2(18,30),Vector2(23,15),Vector2(14,15)])
	for i in shape.size(): shape[i] += p
	draw_colored_polygon(shape,tint.darkened(0.2))
	shape.append(shape[0])
	draw_polyline(shape,tint,1,true)
	draw_line(p+Vector2(21,10),p+Vector2(55,10),tint.lightened(0.3),1)

func grenade(p: Vector2, smoke: bool) -> void:
	if smoke: draw_rect(Rect2(p+Vector2(7,10),Vector2(15,26)),MUTED,false,2)
	else:
		draw_circle(p+Vector2(15,24),11,MUTED,false,2,true)
		for y in [18,24,30]: draw_line(p+Vector2(5,y),p+Vector2(25,y),MUTED,1)
		for x in [11,18]: draw_line(p+Vector2(x,14),p+Vector2(x,33),MUTED,1)
	draw_rect(Rect2(p+Vector2(10,5),Vector2(10,6)),PAPER,false,1)
	draw_line(p+Vector2(10,5),p+Vector2(24,8),PAPER,2)

func _draw() -> void:
	if not is_instance_valid(app): return
	var net = app.network
	var player = net.players.get(multiplayer.get_unique_id())
	if not player: return
	draw_set_transform(Vector2.ZERO,0,get_viewport_rect().size/Vector2(1280,720))
	for side in 2:
		var x := 398.0 if side == 0 else 724.0
		var tint := BLUE if side == 0 else RED
		frame(Rect2(x,34,158,27),tint,0)
		text_at(("TEAM A" if side == 0 else "TEAM B") if net.game_mode == "tdm" else ("KILLS" if side == 0 else "TARGET"),Vector2(x+31,54),18)
		for i in 7:
			var stripe := Vector2(x+24+i*14,65)
			draw_colored_polygon(PackedVector2Array([stripe,stripe+Vector2(9,0),stripe+Vector2(15,9),stripe+Vector2(6,9)]),Color(tint,0.5))
		var bx := 551.0 if side == 0 else 674.0
		frame(Rect2(bx,28,55,57),tint)
		var score: int = net.team_scores.get(side,0) if net.game_mode == "tdm" else (player.kills if side == 0 else net.kill_limit)
		text_at("%02d" % score,Vector2(bx+10,67),33)
	frame(Rect2(609,39,62,40),Color("7b929c"),0)
	var seconds := maxi(0,int(ceil(net.remaining)))
	text_at("MATCH TIMER",Vector2(609,32),10)
	text_at("%02d:%02d" % [seconds/60,seconds%60],Vector2(614,66),23)
	text_at("TRAINING" if net.training else ("TEAM ARENA" if net.game_mode == "tdm" else "FREE FOR ALL"),Vector2(600,104),12,GOLD)
	text_at("♥",Vector2(27,623),24,RED)
	bar(Rect2(58,607,223,18),player.hp/100.0,Color("bd4b40"))
	text_at("%d HP / 100" % player.hp,Vector2(124,621),12)
	text_at(player.player_name.to_upper().substr(0,24),Vector2(29,593),17)
	text_at("SPRINT",Vector2(29,651),12,MUTED)
	bar(Rect2(87,639,118,11),1.0 if player.sprint else 0.0,BLUE)
	text_at("K / D   %02d / %02d" % [player.kills,player.deaths],Vector2(29,682),16)
	# Friendly-only radar uses real world offsets; no hidden enemy positions.
	var radar := Vector2(104,122)
	draw_circle(radar,60,Color(0.015,0.025,0.03,0.82))
	draw_arc(radar,60,0,TAU,64,Color("82939a"),1,true)
	draw_arc(radar,55,0,TAU,64,Color("45555e"),1,true)
	draw_colored_polygon(PackedVector2Array([radar,radar+Vector2(-33,-44),radar+Vector2(33,-44)]),Color(BLUE,0.11))
	for mark in [["N",Vector2(-4,-65)],["S",Vector2(-4,77)],["W",Vector2(-76,5)],["E",Vector2(67,5)]]:
		text_at(mark[0],radar+mark[1],12,MUTED)
	for member in net.players.values():
		if member == player or member.dead or member.team != player.team or net.game_mode != "tdm": continue
		var offset: Vector3 = member.global_position-player.global_position
		var point := Vector2(offset.x,offset.z).rotated(player.rotation.y)*2.0
		if point.length() < 50: draw_circle(radar+point,3,BLUE)
	draw_colored_polygon(PackedVector2Array([radar+Vector2(0,-5),radar+Vector2(-4,4),radar+Vector2(4,4)]),PAPER)
	for slot in 2:
		var y := 493.0+slot*66
		var active: bool = player.weapons.slot == slot
		var spec = player.weapons.DATA[slot]
		var tint := GOLD if active else Color("64757d")
		frame(Rect2(972,y,142,57),tint,0)
		var ammo: int = player.get_node("WeaponController").available_ammo() if active else player.weapons.ammo[slot]
		text_at("%02d" % ammo,Vector2(984,y+32),29)
		text_at("/ %02d" % player.weapons.reserve[slot],Vector2(1030,y+31),17,MUTED)
		for tick in 20: draw_rect(Rect2(979+tick*6,y+43,4,7),tint if float(tick)/20 < float(ammo)/maxf(1,spec.magazine) else Color("283035"))
		frame(Rect2(1120,y,130,57),tint,0)
		text_at(spec.name.to_upper(),Vector2(1127,y+48),11,PAPER if active else MUTED)
		text_at(str(slot+1),Vector2(1235,y+17),12,tint)
	text_at("R  RELOADING" if player.is_reloading else "R  RELOAD",Vector2(1144,630),12,GOLD if player.is_reloading else PAPER)
	for kind in 2:
		var x := 1130.0+kind*63
		frame(Rect2(x,644,55,55),GOLD if player.throw_counts[kind]>0 else MUTED)
		if kind == 1: grenade(Vector2(x+6,646),true)
		text_at(("G" if kind==0 else "H")+"  "+str(player.throw_counts[kind]),Vector2(x+9,695),11)
	if not net.training and net.game_mode == "tdm":
		var row := 0
		for member in net.players.values():
			if member.peer_id == player.peer_id or member.team != player.team: continue
			if row == 0: text_at("SQUAD STATUS",Vector2(28,235),18)
			var y := 247.0+row*62
			var tint := RED if member.dead else BLUE
			frame(Rect2(28,y,272,54),tint,0)
			text_at(member.player_name.substr(0,18)+(" (DEAD)" if member.dead else ""),Vector2(37,y+19),14)
			bar(Rect2(39,y+30,125,12),member.hp/100.0,tint)
			text_at(str(member.hp)+"%",Vector2(169,y+40),12)
			rifle(Vector2(210,y+20),tint,member.weapons.slot==1)
			row += 1
	if not player.dead and not app.paused and not app.ui.settings_open:
		var center := Vector2(640,360)
		for quadrant in (0 if player.is_aiming else 4):
			var angle := quadrant*PI/2
			draw_arc(center,17,angle+0.23,angle+PI/2-0.23,12,Color(PAPER,0.65),1,true)
			draw_line(center+Vector2.from_angle(angle)*11,center+Vector2.from_angle(angle)*23,Color(PAPER,0.9),1,true)
		draw_circle(center,1.5,RED)
	if not app.online.room_code.is_empty(): text_at("ROOM  "+app.online.room_code,Vector2(29,37),12,MUTED)

