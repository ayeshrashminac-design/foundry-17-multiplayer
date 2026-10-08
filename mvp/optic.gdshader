shader_type spatial;
render_mode cull_disabled;
uniform sampler2D palette : source_color;
uniform vec2 aperture_center = vec2(0.0, -2.1);
uniform vec2 aperture_radius = vec2(0.72, 0.72);
varying vec3 local_vertex;
void vertex() { local_vertex = VERTEX; }
void fragment() {
	// The supplied optic has opaque lens faces. Open only its sight aperture.
	if (length((local_vertex.yz - aperture_center) / aperture_radius) < 1.0) discard;
	ALBEDO = texture(palette, UV).rgb;
	ROUGHNESS = 0.7;
}
