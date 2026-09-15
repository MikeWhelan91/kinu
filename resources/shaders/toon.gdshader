shader_type spatial;
render_mode specular_disabled;

uniform vec3 shadow_tint : source_color = vec3(0.78, 0.66, 0.9);
uniform float rim_strength = 0.06;
uniform bool flat_color = false;
uniform vec3 override_color : source_color = vec3(0.5);
uniform vec3 ink : source_color = vec3(0.17, 0.1, 0.09);
varying vec3 base_color;
varying vec3 model_normal;
varying float creased;

void vertex() {
	// Vertex colours are authored in sRGB; alpha marks boxy surfaces whose edges get inked.
	base_color = flat_color ? override_color : pow(COLOR.rgb, vec3(2.2));
	model_normal = NORMAL;
	creased = COLOR.a;
}

void fragment() {
	ALBEDO = base_color;
	if (creased > 0.5) {
		// On a flat face only one normal axis is non-zero; along a rounded edge two are.
		vec3 n = abs(normalize(model_normal));
		float middle = max(min(n.x, n.y), min(max(n.x, n.y), n.z));
		float soft = fwidth(middle);
		ALBEDO = mix(base_color, ink, smoothstep(0.61-soft, 0.61+soft, middle));
	}
	ROUGHNESS = 1.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = base_color * rim * rim_strength;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(0.0, 0.05, ndl) * smoothstep(0.3, 0.6, ATTENUATION);
	DIFFUSE_LIGHT += mix(shadow_tint, vec3(1.0), lit) * LIGHT_COLOR / PI;
}
