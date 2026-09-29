// Flach schattiertes Material für beliebige Meshes – auch für runde Primitive
// wie Kugeln und Zylinder. Die Normale wird pro Pixel aus der Dreiecksfläche
// berechnet, dadurch wirkt jedes Mesh facettiert im Low-Poly-Stil.
// Mit [snow_layer] ist das ganze Mesh eine Schneeauflage (z.B. Schneehaube
// einer Laterne) und schmilzt mit den Jahreszeiten.
shader_type spatial;

#include "res://assets/materials/world_snow.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform bool snow_layer = false;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (snow_layer && ws_layer_melted(world_pos)) {
		discard;
	}
	vec3 face_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	// Sichtbare Flächen zeigen immer zur Kamera – so ist das Vorzeichen egal.
	if (dot(face_normal, VIEW) < 0.0) {
		face_normal = -face_normal;
	}
	NORMAL = face_normal;
	ALBEDO = snow_layer ? ws_soft_snow(albedo.rgb) : albedo.rgb * (1.0 - wetness * 0.2);
	ROUGHNESS = snow_layer ? roughness : mix(roughness, 0.45, wetness);
	METALLIC = metallic;
}
