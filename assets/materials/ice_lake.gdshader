// Der See: im Winter zugefroren (helles, glattes Eis mit Rissen und
// Schneeflecken), in den warmen Jahreszeiten offenes, ruhiges Wasser mit
// leichten Wellen und Himmelsspiegelung. Der Übergang folgt der Schneedecke.
// An den Rändern bleiben im Frühling noch kleine Eisschollen liegen.
shader_type spatial;

#include "res://assets/materials/world_snow.gdshaderinc"

uniform vec3 ice_color : source_color = vec3(0.66, 0.8, 0.9);
uniform vec3 water_deep : source_color = vec3(0.08, 0.2, 0.26);
uniform vec3 water_shallow : source_color = vec3(0.2, 0.36, 0.36);
uniform vec2 lake_center = vec2(52.0, -38.0);
uniform float lake_radius = 16.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float r = length(world_pos.xz - lake_center) / lake_radius;
	// Das Eis taut von der Mitte her; am Ufer halten sich Schollen länger
	float freeze = snow_cover * 1.2 + (r - 0.6) * 0.5 + (ws_noise(world_pos.xz * 0.6) - 0.5) * 0.35;
	float ice = smoothstep(0.45, 0.55, freeze);
	// Eis: Risse und dünne Schneeflecken
	float crack = smoothstep(0.02, 0.0, abs(ws_noise(world_pos.xz * 0.9) - 0.5)) * 0.35;
	float snow_spot = smoothstep(0.62, 0.8, ws_noise(world_pos.xz * 0.4 + 7.0)) * snow_cover;
	vec3 ice_col = mix(ice_color * (1.0 - crack), vec3(0.88, 0.91, 0.95), snow_spot);
	// Wasser: sanfte Wellen über die Normale, tiefer in der Mitte
	float t = TIME * 0.6;
	vec2 wave = vec2(sin(world_pos.x * 1.3 + t) + sin(world_pos.z * 0.9 - t * 1.3),
		cos(world_pos.z * 1.1 + t * 0.8) + sin((world_pos.x + world_pos.z) * 0.7 + t));
	vec3 water_col = mix(water_shallow, water_deep, smoothstep(0.3, 0.9, 1.0 - r));
	ALBEDO = mix(water_col, ice_col, ice);
	ROUGHNESS = mix(0.06, mix(0.12, 0.8, snow_spot), ice);
	METALLIC = 0.0;
	SPECULAR = mix(0.5, 0.8, ice);
	NORMAL = normalize(mix(NORMAL + (VIEW_MATRIX * vec4(wave.x * 0.04, 0.0, wave.y * 0.04, 0.0)).xyz, NORMAL, ice));
}
