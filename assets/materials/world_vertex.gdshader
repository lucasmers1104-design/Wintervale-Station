// Welt-Shader für alle vertexfarbigen Low-Poly-Modelle (Häuser, Bahnhof,
// Gleise, Deko, Felsen …). Farben aus den Vertexfarben, dazu Jahreszeiten:
// Schneeauflagen schmelzen fleckig, Bodenschnee wird zu blankem Boden, bei
// Regen werden Oberflächen dunkler und glänzen leicht (siehe world_snow.gdshaderinc).
shader_type spatial;

#include "res://assets/materials/world_snow.gdshaderinc"

uniform float roughness : hint_range(0.0, 1.0) = 0.92;
uniform float specular : hint_range(0.0, 1.0) = 0.3;
uniform bool receives_wetness = true;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 color = COLOR.rgb;
	float snow = 0.0;
	float ice = 0.0;
	if (COLOR.a < 0.6) {
		if (ws_layer_melted(world_pos)) {
			discard;
		}
		// Bläuliche Auflagen sind Eis (Eiszapfen, gefrorene Pfützen): glatt und glänzend
		ice = step(0.12, COLOR.b - COLOR.r);
		snow = 1.0 - ice;
		color = mix(ws_soft_snow(color), color, ice);
	} else if (COLOR.a < 0.9) {
		snow = ws_ground_snow(world_pos, color);
		color = mix(color, ws_soft_snow(color), snow);
	}
	float wet = receives_wetness ? wetness * (1.0 - snow) : 0.0;
	ALBEDO = color * (1.0 - wet * 0.22);
	ROUGHNESS = mix(mix(mix(roughness, 0.4, wet), 0.96, snow), 0.08, ice);
	SPECULAR = mix(mix(specular, 0.18, snow), 0.85, ice);
}
