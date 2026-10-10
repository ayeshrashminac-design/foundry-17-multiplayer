shader_type canvas_item;
void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float light = max(pixel.r, max(pixel.g, pixel.b));
	COLOR = vec4(pixel.rgb, pixel.a * smoothstep(0.035, 0.15, light));
}
