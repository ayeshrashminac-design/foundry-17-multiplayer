extends Node3D
var remaining := 0.0
var flame: MeshInstance3D
var smoke: CPUParticles3D
func _ready() -> void:
 flame = MeshInstance3D.new()
 var quad := QuadMesh.new()
 quad.size = Vector2(0.19,0.19)
 flame.mesh = quad
 flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var shader := Shader.new()
 shader.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float seed = 0.0;
void vertex() { MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]); }
void fragment() {
 vec2 p = UV*2.0-1.0;
 float angle = atan(p.y,p.x)+seed;
 float r = length(p);
 float jets = pow(abs(cos(angle*3.0)),12.0);
 float edge = 0.27+jets*0.65;
 float a = pow(max(0.0,1.0-r/edge),1.8);
 ALBEDO = mix(vec3(1.0,0.23,0.025),vec3(1.0,0.92,0.65),pow(max(0.0,1.0-r*3.0),2.0))*2.5;
 ALPHA = a;
}"""
 var mat := ShaderMaterial.new()
 mat.shader = shader
 flame.material_override = mat
 flame.position.z = -0.035
 flame.hide()
 add_child(flame)
 smoke = CPUParticles3D.new()
 smoke.emitting = false
 smoke.amount = 6
 smoke.one_shot = true
 smoke.explosiveness = 0.85
 smoke.lifetime = 0.42
 smoke.local_coords = false
 smoke.direction = Vector3(0,0,-1)
 smoke.spread = 17
 smoke.initial_velocity_min = 0.45
 smoke.initial_velocity_max = 1.0
 smoke.gravity = Vector3(0,0.28,0)
 smoke.scale_amount_min = 0.025
 smoke.scale_amount_max = 0.06
 var ramp := Gradient.new()
 ramp.set_color(0,Color(0.6,0.62,0.65,0.12))
 ramp.set_color(1,Color(0.65,0.67,0.7,0))
 smoke.color_ramp = ramp
 var mesh := QuadMesh.new()
 var sm := ShaderMaterial.new()
 var ss := Shader.new()
 ss.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void vertex(){ MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]); }
void fragment(){ ALBEDO=COLOR.rgb; ALPHA=COLOR.a*pow(max(0.0,1.0-length(UV*2.0-1.0)),2.0); }"""
 sm.shader = ss
 mesh.material = sm
 smoke.mesh = mesh
 add_child(smoke)
func burst() -> void:
 remaining = randf_range(0.025,0.045)
 flame.material_override.set_shader_parameter("seed",randf()*TAU)
 flame.scale = Vector3.ONE*randf_range(0.75,1.25)
 flame.show()
 smoke.restart()
func _process(delta: float) -> void:
 remaining = maxf(0,remaining-delta)
 flame.visible = remaining>0
