// Lichterkette: Kabel und Birnen schwingen sanft im Wind (Vertexfarbe Alpha =
// Schwinggewicht, 0 an den Pfosten). Birnen leuchten nachts warm und flackern leicht.
shader_type spatial;

uniform bool emissive = false;
uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform float glow_energy = 3.0;
uniform float sway = 0.07;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float weight = COLOR.a;
	float t = TIME * 1.3 + origin.x * 0.21 + origin.z * 0.17;
	float gust = 0.7 + 0.3 * sin(TIME * 0.37 + origin.x);
	VERTEX.z += sin(t + VERTEX.x * 0.35) * sway * weight * gust;
	VERTEX.y += cos(t * 0.8 + VERTEX.x * 0.5) * sway * 0.35 * weight;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = emissive ? 0.3 : 0.8;
	if (emissive) {
		float flicker = 0.9 + 0.1 * sin(TIME * 7.0 + VERTEX.x * 13.0);
		EMISSION = COLOR.rgb * glow * glow_energy * flicker + COLOR.rgb * 0.05;
	}
}
