// Gelände mit Schnee: flach schattierte Vertexfarben wie überall, dazu feines
// Glitzern auf hellen Schneeflächen. Jede winzige "Kristallzelle" hat eine
// eigene, leicht verkippte Normale – nur wenige spiegeln das Licht genau zur
// Kamera. Funktioniert mit Sonne, Mond und warmen Laternen; in der Ferne
// ausgeblendet (sonst flimmert es).
shader_type spatial;

uniform float roughness : hint_range(0.0, 1.0) = 0.9;
// Kristalle pro Meter und Anteil der Zellen, die überhaupt glitzern können.
uniform float sparkle_density = 14.0;
uniform float sparkle_amount : hint_range(0.0, 1.0) = 0.035;
uniform float sparkle_strength = 2.4;
uniform float sparkle_fade_distance = 38.0;

varying vec3 world_pos;
varying float view_distance;
varying float snowiness;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	return vec3(hash13(p), hash13(p + 19.19), hash13(p + 47.47));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	view_distance = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	// Nur helle, bläulich-weiße Flächen sind Schnee (Fels, Erde, Schotter glitzern nicht)
	snowiness = smoothstep(0.78, 0.86, min(COLOR.r, min(COLOR.g, COLOR.b)));
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = roughness;
	SPECULAR = 0.35;
}

void light() {
	// Lambert wie der Standard (LIGHT_COLOR enthält bereits den Faktor PI)
	float n_dot_l = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += n_dot_l * ATTENUATION * LIGHT_COLOR / PI;
	float fade = 1.0 - smoothstep(sparkle_fade_distance * 0.6, sparkle_fade_distance, view_distance);
	if (snowiness > 0.0 && fade > 0.0 && n_dot_l > 0.0) {
		vec3 cell = floor(world_pos * sparkle_density);
		float chance = hash13(cell);
		if (chance < sparkle_amount) {
			vec3 tilt = (hash33(cell + 7.0) - 0.5) * 1.4;
			vec3 facet = normalize(NORMAL + tilt);
			float glint = pow(max(dot(reflect(-LIGHT, facet), VIEW), 0.0), 90.0);
			SPECULAR_LIGHT += glint * sparkle_strength * ATTENUATION * LIGHT_COLOR / PI * snowiness * fade;
		}
	}
}
