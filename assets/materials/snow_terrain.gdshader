// Gelände mit Schnee: flach schattierte Vertexfarben wie überall, dazu feines
// Glitzern auf hellen Schneeflächen. Jede winzige "Kristallzelle" hat eine
// eigene, leicht verkippte Normale – nur wenige spiegeln das Licht genau zur
// Kamera. Funktioniert mit Sonne, Mond und warmen Laternen; in der Ferne
// ausgeblendet (sonst flimmert es).
//
// Jahreszeiten: Mit sinkender Schneedecke (snow_cover) tauen die Schneeflächen
// fleckig zu Wiese in der Farbe der Jahreszeit (season_grass) auf; der helle
// Streifen neben den Gleisen und das Seeufer werden zu Erde (season_bare).
// Welche Fläche was ist, steht im Alpha-Kanal der Vertexfarbe (kein Raten über
// Helligkeit mehr – das ließ blasse Dreiecke im Sommer stehen). Glitzern gibt es
// nur, wo noch Schnee liegt.
shader_type spatial;

#include "res://assets/materials/world_snow.gdshaderinc"

global uniform vec4 season_grass;

uniform float roughness : hint_range(0.0, 1.0) = 0.9;
// Kristalle pro Meter und Anteil der Zellen, die überhaupt glitzern können.
uniform float sparkle_density = 14.0;
uniform float sparkle_amount : hint_range(0.0, 1.0) = 0.035;
uniform float sparkle_strength = 2.4;
uniform float sparkle_fade_distance = 38.0;

varying vec3 world_pos;
varying float view_distance;
varying float snowiness;
varying float trackside;
varying float snow_left;

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
	// Der Alpha-Kanal markiert die Flächenart (siehe LowPolyTerrain._terrain_color):
	// < 0.6 Schnee, < 0.9 Boden neben den Gleisen und am Seeufer, sonst Fels/Erde.
	snowiness = 1.0 - step(0.6, COLOR.a);
	trackside = step(0.6, COLOR.a) * (1.0 - step(0.9, COLOR.a));
}

void fragment() {
	vec3 color = COLOR.rgb;
	float melt = smoothstep(snow_cover - 0.12, snow_cover + 0.12, ws_patches(world_pos));
	float variation = 0.82 + 0.36 * ws_noise(world_pos.xz * 0.45) - 0.12 * ws_noise(world_pos.xz * 2.3);
	vec3 grass = season_grass.rgb * variation;
	color = mix(color, grass, melt * snowiness);
	color = mix(color, season_bare.rgb * (0.9 + 0.2 * ws_noise(world_pos.xz * 1.3)), melt * trackside);
	snow_left = snowiness * (1.0 - melt);
	color = mix(color, ws_soft_snow(color), snow_left);
	ALBEDO = color * (1.0 - wetness * (1.0 - snow_left) * 0.25);
	ROUGHNESS = mix(roughness, 0.55, wetness * (1.0 - snow_left));
	SPECULAR = 0.35;
}

void light() {
	// Lambert wie der Standard (LIGHT_COLOR enthält bereits den Faktor PI)
	float n_dot_l = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += n_dot_l * ATTENUATION * LIGHT_COLOR / PI;
	float fade = 1.0 - smoothstep(sparkle_fade_distance * 0.6, sparkle_fade_distance, view_distance);
	if (snow_left > 0.0 && fade > 0.0 && n_dot_l > 0.0) {
		vec3 cell = floor(world_pos * sparkle_density);
		float chance = hash13(cell);
		if (chance < sparkle_amount) {
			vec3 tilt = (hash33(cell + 7.0) - 0.5) * 1.4;
			vec3 facet = normalize(NORMAL + tilt);
			float glint = pow(max(dot(reflect(-LIGHT, facet), VIEW), 0.0), 90.0);
			SPECULAR_LIGHT += glint * sparkle_strength * ATTENUATION * LIGHT_COLOR / PI * snow_left * fade;
		}
	}
}
