// Blattwerk, das sich leicht im Wind wiegt (Bäume, Büsche, Hecken).
// Farben kommen wie überall aus den Vertexfarben (flacher Low-Poly-Look).
// Je höher ein Punkt über dem Stamm liegt, desto stärker schwingt er –
// der Stamm bleibt ruhig. Jede Pflanze schwingt dank ihrer Weltposition
// ein wenig anders.
//
// Jahreszeiten (Shader-Globals vom Autoload "Seasons"):
// - Schnee auf den Ästen (Vertex-Alpha < 0.6) schmilzt fleckig mit der Schneedecke.
// - Frühling: frisches, helleres Grün. Herbst: helle Blätter werden goldgelb bis
//   rostrot (jeder Baum etwas anders), dunkle Nadeln nur etwas wärmer.
// - Wind: die Stärke kommt vom Wetter (wind_strength).
shader_type spatial;

#include "res://assets/materials/world_snow.gdshaderinc"

uniform float strength : hint_range(0.0, 0.2) = 0.035;
uniform float speed : hint_range(0.0, 4.0) = 1.1;
// Ab dieser Höhe (lokal, Meter) beginnt das Schwingen.
uniform float sway_start = 0.8;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;

global uniform float wind_strength;
global uniform float foliage_autumn;
global uniform float foliage_spring;

varying vec3 world_pos;
varying vec3 tree_origin;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	tree_origin = origin;
	float wind = 0.45 + wind_strength * 1.6;
	float height = max(VERTEX.y - sway_start, 0.0);
	float bend = height * height * strength * wind;
	float phase = TIME * speed * (0.8 + wind_strength * 0.6) + origin.x * 0.17 + origin.z * 0.13;
	float gust = 0.6 + 0.4 * sin(TIME * 0.23 + origin.x * 0.05);
	VERTEX.x += sin(phase) * bend * gust;
	VERTEX.z += cos(phase * 0.83 + 1.7) * bend * 0.7 * gust;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 color = COLOR.rgb;
	float snow = 0.0;
	if (COLOR.a < 0.6) {
		if (ws_layer_melted(world_pos)) {
			discard;
		}
		snow = 1.0;
		color = ws_soft_snow(color);
	} else {
		// Nur grüne Flächen (Blätter, Nadeln) färben sich mit den Jahreszeiten
		float leafy = smoothstep(0.02, 0.08, color.g - max(color.r, color.b));
		float light = dot(color, vec3(0.3, 0.55, 0.15));
		float deciduous = smoothstep(0.26, 0.36, light);
		float tree_rand = ws_hash(floor(tree_origin.xz * 0.5));
		vec3 autumn = mix(vec3(0.86, 0.6, 0.18), vec3(0.72, 0.28, 0.14), tree_rand) * (0.7 + light);
		vec3 conifer_autumn = color * vec3(1.08, 0.98, 0.86);
		vec3 autumn_color = mix(conifer_autumn, autumn, deciduous);
		color = mix(color, autumn_color, foliage_autumn * leafy);
		vec3 spring = color * vec3(1.06, 1.16, 0.9) + vec3(0.02, 0.04, 0.0);
		color = mix(color, spring, foliage_spring * leafy);
	}
	ALBEDO = color * (1.0 - wetness * (1.0 - snow) * 0.18);
	ROUGHNESS = mix(roughness, 0.96, snow);
	SPECULAR = mix(0.3, 0.18, snow);
}
