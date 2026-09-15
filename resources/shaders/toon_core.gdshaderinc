// Shared toon lighting for solid and see-through surfaces. Include after shader_type/render_mode;
// define TOON_GLASS before including for the transparent variant.
uniform vec3 shadow_tint : source_color = vec3(0.78, 0.66, 0.9);
uniform float rim_strength = 0.06;
uniform bool flat_color = false;
uniform vec3 override_color : source_color = vec3(0.5);
uniform vec3 ink : source_color = vec3(0.17, 0.1, 0.09);
// Hard cartoon highlight for metals and crystal (0 = none).
uniform float shine = 0.0;
// Self-lit glow, e.g. galaxy tofu (0 = none).
uniform float glow = 0.0;
uniform float opacity = 1.0;
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
	EMISSION = base_color * (rim * rim_strength + glow);
#ifdef TOON_GLASS
	ALPHA = mix(opacity, 1.0, rim * 0.6);
#endif
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(0.0, 0.05, ndl) * smoothstep(0.3, 0.6, ATTENUATION);
	DIFFUSE_LIGHT += mix(shadow_tint, vec3(1.0), lit) * LIGHT_COLOR / PI;
	if (shine > 0.0) {
		float facing = dot(NORMAL, normalize(LIGHT + VIEW));
		SPECULAR_LIGHT += smoothstep(0.9, 0.93, facing) * shine * lit * LIGHT_COLOR / PI;
	}
}
