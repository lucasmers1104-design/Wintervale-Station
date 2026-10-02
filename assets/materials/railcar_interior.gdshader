// Low-poly cabin materials with a gentle warm fill; alpha marks ceiling lamps.
shader_type spatial;
render_mode cull_disabled, shadows_disabled;

instance uniform float cabin = 0.0;

void fragment() {
	float lamp = 1.0 - step(0.9, COLOR.a);
	float level = 0.22 + cabin * 0.78;
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.82;
	SPECULAR = 0.2;
	EMISSION = COLOR.rgb * vec3(1.0, 0.76, 0.42) * level * mix(0.55, 2.5, lamp);
}
