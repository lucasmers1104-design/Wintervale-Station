// Fahne, die sich sanft im Wind bewegt. Die Welle läuft vom Mast (UV.x = 0)
// zum freien Ende (UV.x = 1) und wird dorthin stärker. Farben aus den Vertexfarben.
shader_type spatial;
render_mode cull_disabled;

uniform float strength = 0.16;
uniform float speed = 2.4;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
global uniform float wind_strength;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float along = UV.x;
	float gust = (0.7 + 0.3 * sin(TIME * 0.37 + origin.x * 0.1)) * (0.35 + wind_strength * 1.5);
	float phase = TIME * speed - along * 5.0 + origin.z * 0.3;
	VERTEX.z += sin(phase) * along * strength * gust;
	VERTEX.y += sin(phase * 0.5 + 1.0) * along * strength * 0.25 * gust;
	// Die Normale grob mitkippen, damit das Licht über die Falten wandert
	NORMAL = normalize(NORMAL + vec3(0.0, 0.0, cos(phase) * along * 0.9));
}

void fragment() {
	ALBEDO = COLOR.rgb * (FRONT_FACING ? 1.0 : 0.82);
	ROUGHNESS = roughness;
	SPECULAR = 0.25;
}
