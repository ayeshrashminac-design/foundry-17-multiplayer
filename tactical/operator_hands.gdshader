shader_type spatial;
render_mode cull_disabled;

// Retain the authored fabric, leather, stitching and normal maps.
uniform sampler2D albedo_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_strength = 1.0;

void fragment() {
	vec3 original = texture(albedo_map, UV).rgb;
	float detail = dot(original, vec3(0.2126, 0.7152, 0.0722));
	// Both FPS weapons use the same arms atlas: the sleeve is the lower-left island.
	float sleeve_top = 0.34 + max(UV.x - 0.30, 0.0) * 0.31;
	float sleeve = step(sleeve_top, UV.y) * step(UV.y, 0.935) * step(UV.x, 0.685);
	ALBEDO = detail * mix(vec3(0.48, 0.50, 0.52), vec3(0.65, 0.90, 1.35), sleeve);
	ROUGHNESS = mix(0.72, 0.90, sleeve);
	METALLIC = 0.0;
	NORMAL_MAP = texture(normal_map, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
}
