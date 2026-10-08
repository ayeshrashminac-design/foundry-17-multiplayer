shader_type canvas_item;
render_mode unshaded;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
void fragment() {
	vec2 p = UV;
	float glow = exp(-5.0 * distance(p, vec2(0.74,0.39)));
	vec3 base = mix(vec3(0.017,0.032,0.045),vec3(0.08,0.19,0.20),glow);
	vec2 grid = abs(fract(p * vec2(42.0,24.0)) - 0.5);
	float line = step(0.491, max(grid.x, grid.y));
	base += line * vec3(0.025,0.043,0.042);
	base += (hash(floor(p * vec2(1280.0,720.0))) - 0.5) * 0.024;
	float band = smoothstep(0.004,0.0,abs(p.y - (0.90 - p.x * 0.18)));
	base += band * vec3(0.08,0.23,0.20);
	COLOR = vec4(base,1.0);
}
