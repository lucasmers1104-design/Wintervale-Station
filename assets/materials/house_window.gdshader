// Fensterglas der Dorfhäuser: dunkel spiegelndes Glas mit sanfter Reflexion
// des Himmels am Rand; nachts leuchtet dahinter warmes Licht.
// Vertexfarbe Rot = wie hell dieses Fenster nachts ist (0 = bleibt dunkel),
// Grün = Höhe im Fenster (unten etwas heller, wie eine Lampe im Raum).
shader_type spatial;

uniform vec3 glass_color : source_color = vec3(0.1, 0.12, 0.16);
uniform vec3 sky_tint : source_color = vec3(0.55, 0.62, 0.78);
uniform vec3 light_color : source_color = vec3(1.0, 0.72, 0.4);
// 0 = Tag, 1 = Nacht (wird vom Dorf weich überblendet).
uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform float glow_energy = 2.2;

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(glass_color, sky_tint, fresnel * 0.55);
	ROUGHNESS = 0.12;
	METALLIC = 0.15;
	SPECULAR = 0.7;
	float lamp = COLOR.r * (0.75 + 0.25 * (1.0 - COLOR.g));
	EMISSION = light_color * lamp * (0.06 + glow * glow_energy);
}
