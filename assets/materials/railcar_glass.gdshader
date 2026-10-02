// Glazing over real openings: interior geometry supplies seats and warm lighting.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

instance uniform float cabin = 0.0;

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(vec3(0.10, 0.16, 0.18), vec3(0.42, 0.52, 0.58), fresnel * 0.35);
	ROUGHNESS = 0.16;
	SPECULAR = 0.5;
	EMISSION = vec3(0.28, 0.17, 0.055) * cabin;
	ALPHA = mix(0.48, 0.34, cabin) + fresnel * 0.18;
}
