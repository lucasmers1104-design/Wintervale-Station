// Flach schattiertes Material für beliebige Meshes – auch für runde Primitive
// wie Kugeln und Zylinder. Die Normale wird pro Pixel aus der Dreiecksfläche
// berechnet, dadurch wirkt jedes Mesh facettiert im Low-Poly-Stil.
shader_type spatial;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 face_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	// Sichtbare Flächen zeigen immer zur Kamera – so ist das Vorzeichen egal.
	if (dot(face_normal, VIEW) < 0.0) {
		face_normal = -face_normal;
	}
	NORMAL = face_normal;
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
