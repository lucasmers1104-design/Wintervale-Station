// Blattwerk, das sich leicht im Wind wiegt (Bäume, Büsche, Hecken).
// Farben kommen wie überall aus den Vertexfarben (flacher Low-Poly-Look).
// Je höher ein Punkt über dem Stamm liegt, desto stärker schwingt er –
// der Stamm bleibt ruhig. Jede Pflanze schwingt dank ihrer Weltposition
// ein wenig anders.
shader_type spatial;

uniform float strength : hint_range(0.0, 0.2) = 0.035;
uniform float speed : hint_range(0.0, 4.0) = 1.1;
// Ab dieser Höhe (lokal, Meter) beginnt das Schwingen.
uniform float sway_start = 0.8;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float height = max(VERTEX.y - sway_start, 0.0);
	float bend = height * height * strength;
	float phase = TIME * speed + origin.x * 0.17 + origin.z * 0.13;
	float gust = 0.6 + 0.4 * sin(TIME * 0.23 + origin.x * 0.05);
	VERTEX.x += sin(phase) * bend * gust;
	VERTEX.z += cos(phase * 0.83 + 1.7) * bend * 0.7 * gust;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = roughness;
	SPECULAR = 0.3;
}
