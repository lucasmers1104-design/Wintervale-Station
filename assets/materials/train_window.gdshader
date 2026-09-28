// Zugfenster: dunkles Glas, oben spiegelt sich sanft der Himmel, dazu ein
// stilisierter schräger Glanzstreifen und warmes Innenlicht (oben etwas heller,
// wie unter den Deckenlampen). [glow] ist die Helligkeit des Innenlichts
// (tagsüber ein Hauch, nachts warm).
shader_type spatial;

uniform vec3 glass_color : source_color = vec3(0.1, 0.12, 0.15);
uniform vec3 sky_tint : source_color = vec3(0.6, 0.66, 0.8);
uniform vec3 light_color : source_color = vec3(1.0, 0.78, 0.5);
uniform float glow = 0.07;
uniform float shine = 0.18;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float upper = smoothstep(2.0, 2.85, local_pos.y);
	// Schräger Glanzstreifen (wie bei gezeichneten Fenstern)
	float band = fract((local_pos.z * 0.55 + local_pos.y * 0.9) * 0.45);
	float streak = smoothstep(0.0, 0.04, band) * (1.0 - smoothstep(0.1, 0.16, band));
	float reflect_amount = clamp(fresnel * 0.6 + upper * 0.3 + streak * shine, 0.0, 0.85);
	ALBEDO = mix(glass_color, sky_tint, reflect_amount);
	ROUGHNESS = 0.1;
	SPECULAR = 0.75;
	float ceiling = smoothstep(1.9, 2.9, local_pos.y);
	EMISSION = light_color * glow * (0.7 + 0.5 * ceiling) * (1.0 - streak * 0.3);
}
