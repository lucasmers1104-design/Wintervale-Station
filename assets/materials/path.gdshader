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
	vec2 p = world_pos.xz;
	float soil = ws_noise(p * 0.65);
	float grain = ws_noise(p * 37.0);
	// Broad worn patches, small loose stones and irregular, softened shoulders.
	float edge = 0.98 + (ws_noise(p * 1.3) - 0.5) * 0.28 + (ws_noise(p * 6.0) - 0.5) * 0.10;
	float detail = 1.0 - smoothstep(0.045, 0.16, length(fwidth(p)));
	vec3 color;
	float relief = 0.0;
	float rough = 0.94;
	float snow = 0.0;

	if (style == 1) {
		// Rounded natural stones: individual colour, recessed joints and worn crowns.
		vec3 v = voronoi(p * 3.5 + vec2(ws_noise(p * 0.7), ws_noise(p * 0.7 + 8.0)) * 0.22);
		float joint = 1.0 - smoothstep(0.018, 0.070, v.y);
		vec3 stone = mix(base_color, mix(dark_color, light_color, v.z), 0.72);
		stone *= 0.94 + 0.10 * soil + (grain - 0.5) * 0.07 * detail;
		vec3 mortar = dark_color * 0.77;
		color = mix(stone, mortar, joint);
		relief = (1.0 - joint) * (0.010 + 0.008 * (1.0 - smoothstep(0.0, 0.55, v.x)));
		rough = mix(0.82, 0.98, joint);
		float in_joints = joint * smoothstep(0.2, 0.7, snow_cover);
		float dust = smoothstep(0.58, 0.86, ws_noise(p * 1.3)) * snow_cover * 0.32;
		snow = clamp(in_joints * 0.85 + dust, 0.0, 1.0);
	} else if (style == 2) {
		// Packed gravel with softly wandering wheel tracks; fade them at junctions.
		float wander = (ws_noise(p * 0.8) - 0.5) * 0.055;
		float rut = (1.0 - smoothstep(0.045, 0.19, abs(across - 0.48 + wander))) * COLOR.r;
		vec3 v = voronoi(p * 13.0);
		float pebble = (1.0 - smoothstep(0.25, 0.44, v.x)) * smoothstep(0.01, 0.07, v.y);
		color = base_color * (0.91 + 0.14 * soil);
		color = mix(color, mix(dark_color, light_color, v.z), pebble * 0.48 * detail);
		color = mix(color, dark_color * (0.94 + 0.10 * soil), rut * 0.42);
		color *= 1.0 + (grain - 0.5) * 0.09 * detail;
		relief = pebble * 0.004 * detail - rut * 0.010;
		rough = mix(0.96, 0.84, rut);
		float packed = (1.0 - rut * 0.8) * smoothstep(0.3, 0.8, snow_cover) * (0.22 + 0.33 * soil);
		snow = clamp(packed, 0.0, 0.65);
	} else {
		// Mixed angular pebbles on an earthy bed, with a subtly compacted walking lane.
		vec3 v = voronoi(p * vec2(10.5, 12.0));
		float radius = mix(0.22, 0.47, v.z);
		float pebble = (1.0 - smoothstep(radius * 0.65, radius, v.x)) * smoothstep(0.012, 0.085, v.y);
		vec2 fine_cell = floor(p * 29.0);
		float chip_id = ws_hash(fine_cell);
		float chip = 1.0 - smoothstep(0.09, 0.21, length(fract(p * 29.0) - (hash2(fine_cell) * 0.5 + 0.25)));
		vec3 stone = mix(dark_color, light_color, v.z);
		stone = mix(stone, vec3(0.55, 0.57, 0.56), step(0.78, v.z) * 0.35);
		float wear = (1.0 - smoothstep(0.20, 0.85, across)) * COLOR.r;
		color = base_color * (0.87 + 0.20 * soil);
		color = mix(color, stone, pebble * (0.78 - wear * 0.12) * detail);
		color = mix(color, mix(dark_color, light_color, chip_id), chip * 0.38 * detail);
		color *= 1.0 + (grain - 0.5) * 0.15 * detail;
		color = mix(color, base_color * 0.91, wear * 0.10);
		relief = (pebble * (0.007 + 0.004 * v.z) + chip * 0.002 + grain * 0.0015) * detail;
		float cover = mix(0.24, 0.58, smoothstep(0.3, 0.75, ws_noise(p * 1.1 + 3.0)));
		snow = cover * smoothstep(0.1, 0.8, snow_cover) * (1.0 - pebble * 0.48);
	}
	// In der Wegmitte liegt weniger Schnee (dort wird gelaufen und gefahren)
	snow *= 0.6 + 0.4 * smoothstep(0.2, 0.9, across);
	color = mix(color, ws_soft_snow(vec3(0.88, 0.91, 0.95)), snow);

	// Rand und Bankett: sanft in die Geländefarbe übergehen
	float ground_snow;
	vec3 ground = ground_color(ground_snow);
	float shoulder = smoothstep(edge - 0.12, edge + 0.28, across);
	// Small earth pockets interrupt the transition into grass without a painted stripe.
	float verge = smoothstep(edge - 0.20, edge + 0.03, across) * (1.0 - shoulder);
	color = mix(color, season_bare.rgb * (0.88 + 0.16 * soil), verge * 0.32 * (1.0 - snow_cover));
	// Am Rand bleibt geräumter Schnee liegen (kleiner Wall)
	float bank = smoothstep(edge - 0.1, edge + 0.05, across) * (1.0 - smoothstep(edge + 0.1, edge + 0.3, across)) * snow_cover;
	color = mix(color, ws_soft_snow(vec3(0.9, 0.93, 0.97)), bank * 0.7);
	color = mix(color, ground, shoulder);
	snow = max(mix(snow, ground_snow, shoulder), bank * 0.7);

	// Derivative relief works without mesh tangents or extra geometry on every path.
	float height = relief * (1.0 - shoulder) * (1.0 - snow);
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	vec3 rx = cross(dy, NORMAL);
	vec3 ry = cross(NORMAL, dx);
	float determinant = dot(dx, rx);
	vec3 gradient = (rx * dFdx(height) + ry * dFdy(height)) * sign(determinant) / max(abs(determinant), 0.000001);
	NORMAL = normalize(NORMAL - gradient / max(1.0, length(gradient) / 0.45));
	float wet = wetness * (1.0 - snow);
	ALBEDO = color * (1.0 - wet * 0.24);
	ROUGHNESS = mix(mix(rough, 0.48, wet), 0.95, snow);
	SPECULAR = mix(0.28, 0.2, snow);
}
