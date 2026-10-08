extends ColorRect
var strength := 0.0
var heartbeat := 0.0
var app: Node
func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var shader := Shader.new()
 shader.code = """shader_type canvas_item;
uniform float strength = 0.0;
void fragment(){
 vec2 p=abs(UV*2.0-1.0);
 float edge=smoothstep(0.35,1.05,max(p.x,p.y));
 COLOR=vec4(0.48,0.015,0.025,edge*strength);
}"""
 material = ShaderMaterial.new()
 material.shader = shader
func hit(amount: int) -> void:
 strength = minf(0.85,strength+0.25+amount*0.009)
 if app: app.audio.play("hurt")
func _process(delta: float) -> void:
 strength = move_toward(strength,0.0,delta*0.85)
 heartbeat += delta
 var low := 0.0
 if app and app.in_match:
  var p = app.network.players.get(multiplayer.get_unique_id())
  if p and not p.dead and p.hp<30: low=0.12+0.08*(0.5+0.5*sin(heartbeat*7))
 else: strength=0
 material.set_shader_parameter("strength",maxf(strength,low))
