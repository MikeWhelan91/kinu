shader_type spatial;
render_mode unshaded, cull_front, specular_disabled;

uniform float width = 0.028;
uniform vec3 ink : source_color = vec3(0.17, 0.1, 0.09);

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = ink;
}
