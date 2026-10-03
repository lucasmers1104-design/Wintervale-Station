// Fensterglas der Dorfhäuser: dunkel spiegelndes Glas mit sanfter Reflexion
// des Himmels am Rand und einem stilisierten schrägen Glanzstreifen; nachts
// leuchtet dahinter warmes Licht.
// Vertexfarbe Rot = wie hell dieses Fenster nachts ist (0 = bleibt dunkel),
// Grün = Höhe im Fenster (unten etwas heller, wie eine Lampe im Raum).
shader_type spatial;

uniform vec3 glass_color : source_color = vec3(0.1, 0.12, 0.16);
uniform vec3 sky_tint : source_color = vec3(0.55, 0.62, 0.78);
uniform vec3 light_color : source_color = vec3(1.0, 0.72, 0.4);
// 0 = Tag, 1 = Nacht (wird vom Haus weich überblendet).
uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform float glow_energy = 2.2;
uniform float shine = 0.16;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float band = fract((local_pos.x * 0.6 + local_pos.z * 0.6 + local_pos.y * 1.1) * 0.8);
	float streak = smoothstep(0.0, 0.05, band) * (1.0 - smoothstep(0.12, 0.2, band));
	// Tagsüber spiegelt der obere Teil der Scheibe den Himmel (Grün = Höhe im Fenster),
	// unten schimmert es warm aus dem Raum – so lesen sich Fenster als Glas statt als
	// graue Fläche. Nachts tritt die Spiegelung hinter das Lampenlicht zurück.
	float day = 1.0 - glow;
	float upper_sky = smoothstep(0.35, 1.0, COLOR.g) * 0.32 * day;
	ALBEDO = mix(glass_color, sky_tint, clamp(fresnel * 0.55 + upper_sky + streak * shine * day, 0.0, 0.8));
	ROUGHNESS = 0.12;
	METALLIC = 0.15;
	SPECULAR = 0.7;
	float lamp = COLOR.r * (0.75 + 0.25 * (1.0 - COLOR.g));
	float room = (1.0 - smoothstep(0.2, 0.8, COLOR.g)) * 0.1 * day;
	EMISSION = light_color * lamp * (0.07 + room + glow * glow_energy);
}
