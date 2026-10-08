shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(0.45, 0.49, 0.52, 1.0);
uniform float metalness = 0.3;
uniform float surface_roughness = 0.6;
uniform bool floor_surface = false;
varying vec3 world_pos;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 float grain = hash(floor(world_pos * 80.0));
 float detail_fade = 1.0 - smoothstep(0.005, 0.04, length(fwidth(world_pos)));
 grain = mix(0.5, grain, detail_fade);
 vec3 color = base_color.rgb * (0.985 + grain * 0.03);
 if (floor_surface) {
  vec2 tile = abs(fract(world_pos.xz * 0.5) - 0.5);
  float seam = smoothstep(0.484, 0.496, max(tile.x, tile.y));
  color *= mix(1.0, 0.52, seam);
  float grip = step(0.91, fract((world_pos.x + world_pos.z) * 22.0));
  color *= 1.0 - grip * 0.045;
 }
 ALBEDO = color;
 METALLIC = metalness;
 ROUGHNESS = clamp(surface_roughness + (grain - 0.5) * 0.12, 0.25, 0.95);
}
