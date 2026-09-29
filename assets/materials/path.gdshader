// Wege: Kies, Natursteinpflaster und kleine Straße – prozedural in Weltkoordinaten.
//
// Weil alle Muster in Weltkoordinaten liegen, gehen Wegstücke, Kurven und
// Kreuzungen nahtlos ineinander über (keine sichtbaren Kanten zwischen Stücken).
// UV.x = Abstand zur Wegmitte (0 = Mitte, 1 = Wegrand, > 1 = Bankett, das ins
// Gelände ausläuft). Der Rand ist unregelmäßig, das Bankett nimmt die Farbe
// des Geländes an (Schnee bzw. Wiese der Jahreszeit), damit der Weg ohne harte
// Kante im Boden liegt.
//
// Winter: geräumt, aber mit einem Hauch Schnee, Schnee in den Pflasterfugen und
// festgefahrener Schnee zwischen den Fahrspuren. Regen: dunkler und glänzend.
shader_type spatial;

#include "res://assets/materials/world_snow.gdshaderinc"

global uniform vec4 season_grass;

// 0 = Kies, 1 = Steinpflaster, 2 = kleine Straße
uniform int style = 0;
uniform vec3 base_color : source_color = vec3(0.64, 0.58, 0.5);
uniform vec3 dark_color : source_color = vec3(0.46, 0.42, 0.37);
uniform vec3 light_color : source_color = vec3(0.78, 0.73, 0.64);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 hash2(vec2 p) {
	return vec2(ws_hash(p), ws_hash(p + 17.31));
}

// Voronoi: Abstand zum nächsten Zellzentrum, Abstand zur Zellgrenze, Zell-ID.
vec3 voronoi(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float best = 8.0;
	float second = 8.0;
	vec2 best_id = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash2(cell + g) * 0.8 + 0.1;
			float d = length(g + o - f);
			if (d < best) {
				second = best;
				best = d;
				best_id = cell + g;
			} else if (d < second) {
				second = d;
			}
		}
	}
	return vec3(best, second - best, ws_hash(best_id));
}

// Geländefarbe am Bankett – genau wie der Gelände-Shader (Schnee taut zu Wiese).
vec3 ground_color(out float snow) {
	float melt = smoothstep(snow_cover - 0.12, snow_cover + 0.12, ws_patches(world_pos));
	float variation = 0.82 + 0.36 * ws_noise(world_pos.xz * 0.45) - 0.12 * ws_noise(world_pos.xz * 2.3);
	vec3 snow_col = ws_soft_snow(vec3(0.9, 0.93, 0.97)) * (0.97 + 0.03 * ws_noise(world_pos.xz * 3.0));
	snow = 1.0 - melt;
	return mix(snow_col, season_grass.rgb * variation, melt);
}

void fragment() {
	float across = abs(UV.x);
	// Unregelmäßiger Rand: kleine Buchten und Vorsprünge statt einer Linie
	float edge = 1.0 + (ws_noise(world_pos.xz * 2.2) - 0.5) * 0.22 + (ws_noise(world_pos.xz * 7.0) - 0.5) * 0.08;
	vec3 color;
	float rough = 0.9;
	float snow = 0.0;

	if (style == 1) {
		// Natursteinpflaster: unregelmäßige Steine, Fugen, leicht gewölbt
		vec3 v = voronoi(world_pos.xz * 3.1);
		float joint = 1.0 - smoothstep(0.03, 0.09, v.y);
		vec3 stone = mix(base_color, mix(dark_color, light_color, v.z), 0.55);
		stone *= 0.92 + 0.16 * ws_noise(world_pos.xz * 9.0);
		vec3 mortar = dark_color * 0.72;
		color = mix(stone, mortar, joint);
		rough = mix(0.72, 0.95, joint);
		// Schnee in den Fugen, ein wenig auf den Steinen
		float in_joints = joint * smoothstep(0.2, 0.7, snow_cover);
		float dust = smoothstep(0.55, 0.85, ws_noise(world_pos.xz * 1.3)) * snow_cover * 0.5;
		snow = clamp(in_joints * 0.9 + dust, 0.0, 1.0);
	} else if (style == 2) {
		// Kleine Straße: festgefahrener Kies, zwei Fahrspuren, in der Mitte heller
		// Vertexfarbe R = Spurstärke: an Knotenscheiben laufen die Spuren aus (keine Ringe)
		float rut = smoothstep(0.16, 0.0, abs(across - 0.48)) * COLOR.r;
		float n = ws_noise(world_pos.xz * 5.0) * 0.6 + ws_noise(world_pos.xz * 17.0) * 0.4;
		color = mix(base_color, dark_color, rut * 0.55) * (0.88 + n * 0.24);
		float speck = step(0.93, ws_hash(floor(world_pos.xz * 14.0)));
		color = mix(color, light_color, speck * 0.5);
		rough = mix(0.88, 0.7, rut);
		// Winter: festgefahrener Schnee außerhalb der Spuren
		float packed = (1.0 - rut) * smoothstep(0.3, 0.8, snow_cover) * (0.35 + 0.45 * ws_noise(world_pos.xz * 0.8));
		snow = clamp(packed, 0.0, 0.85);
	} else {
		// Kies: Kiesel in mehreren Größen, helle und dunkle Steinchen
		vec3 v = voronoi(world_pos.xz * 11.0);
		float pebble = smoothstep(0.34, 0.1, v.x);
		vec3 stone = mix(dark_color, light_color, v.z);
		color = mix(base_color * (0.9 + 0.2 * ws_noise(world_pos.xz * 3.0)), stone, pebble * 0.65);
		vec3 fine = voronoi(world_pos.xz * 26.0);
		color *= 0.92 + 0.14 * smoothstep(0.3, 0.05, fine.x) * fine.z;
		rough = 0.95;
		// Winter: eine dünne, fleckige Schneedecke, durch die die Kiesel schauen
		float cover = mix(0.5, 0.9, smoothstep(0.3, 0.75, ws_noise(world_pos.xz * 1.1 + 3.0)));
		snow = cover * smoothstep(0.1, 0.8, snow_cover) * (1.0 - pebble * 0.4);
	}
	// In der Wegmitte liegt weniger Schnee (dort wird gelaufen und gefahren)
	snow *= 0.6 + 0.4 * smoothstep(0.2, 0.9, across);
	color = mix(color, ws_soft_snow(vec3(0.88, 0.91, 0.95)), snow);

	// Rand und Bankett: sanft in die Geländefarbe übergehen
	float ground_snow;
	vec3 ground = ground_color(ground_snow);
	float shoulder = smoothstep(edge - 0.06, edge + 0.22, across);
	// Am Rand bleibt geräumter Schnee liegen (kleiner Wall)
	float bank = smoothstep(edge - 0.1, edge + 0.05, across) * (1.0 - smoothstep(edge + 0.1, edge + 0.3, across)) * snow_cover;
	color = mix(color, ws_soft_snow(vec3(0.9, 0.93, 0.97)), bank * 0.7);
	color = mix(color, ground, shoulder);
	snow = max(mix(snow, ground_snow, shoulder), bank * 0.7);

	float wet = wetness * (1.0 - snow);
	ALBEDO = color * (1.0 - wet * 0.3);
	ROUGHNESS = mix(mix(rough, 0.3, wet), 0.95, snow);
	SPECULAR = mix(0.35, 0.2, snow);
}
