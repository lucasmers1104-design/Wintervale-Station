// Lack der Züge: glänzend mit Klarlack, Farben aus den Vertexfarben.
// Schnee auf Dächern und Pufferbohlen gibt es nur, solange Winter ist.
shader_type spatial;

#include "res://assets/materials/world_snow.gdshaderinc"

uniform float roughness : hint_range(0.0, 1.0) = 0.45;
uniform float specular : hint_range(0.0, 1.0) = 0.55;
uniform float clearcoat_amount : hint_range(0.0, 1.0) = 0.35;
uniform float clearcoat_roughness : hint_range(0.0, 1.0) = 0.35;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 color = COLOR.rgb;
	float snow = 0.0;
	if (COLOR.a < 0.6) {
		// Mit dem Zug wandert, deshalb Flecken in Wagen-Koordinaten
		if (ws_patches(local_pos * 1.3) > snow_cover * 1.1 - 0.05) {
			discard;
		}
		snow = 1.0;
		color = ws_soft_snow(color);
	}
	// Dunkle, ungesättigte Teile (Fahrwerk, Schürzen, Gummi, Rahmen) sind matt – sonst
	// spiegeln sie Himmel und Sonne und wirken beige statt dunkel.
	float sat = max(max(color.r, color.g), color.b) - min(min(color.r, color.g), color.b);
	float lum = dot(color, vec3(0.3, 0.59, 0.11));
	float matte = (1.0 - smoothstep(0.04, 0.12, sat)) * (1.0 - smoothstep(0.22, 0.45, lum));
	ALBEDO = color * (1.0 - wetness * (1.0 - snow) * 0.12);
	ROUGHNESS = mix(mix(roughness, 0.78, matte), 0.96, snow);
	SPECULAR = mix(mix(specular, 0.3, matte), 0.18, snow);
	CLEARCOAT = clearcoat_amount * (1.0 - snow) * (1.0 - matte);
	CLEARCOAT_ROUGHNESS = mix(clearcoat_roughness, 0.15, wetness);
}
