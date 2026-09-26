// Karostoff (Holzfällerhemd) – komplett prozedural aus den UV-Koordinaten.
// Zwei sich kreuzende Streifen ergeben das typische Buffalo-Karo,
// dazu feine helle Linien.
shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.62, 0.12, 0.12, 1.0);
uniform vec4 stripe_color : source_color = vec4(0.08, 0.06, 0.07, 1.0);
uniform vec4 line_color : source_color = vec4(0.85, 0.75, 0.6, 1.0);
// Anzahl der Karos rundherum (x) und in der Höhe (y).
uniform vec2 checks = vec2(8.0, 4.0);
uniform float line_strength : hint_range(0.0, 1.0) = 0.35;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	vec2 cell = fract(UV * checks);
	float band_u = step(0.5, cell.x);
	float band_v = step(0.5, cell.y);
	// 0 = Grundfarbe, 0.5 = ein Streifen, 1 = Kreuzung beider Streifen
	vec3 color = mix(base_color.rgb, stripe_color.rgb, (band_u + band_v) * 0.5);
	float line_u = 1.0 - smoothstep(0.02, 0.04, abs(cell.x - 0.25));
	float line_v = 1.0 - smoothstep(0.02, 0.04, abs(cell.y - 0.25));
	color = mix(color, line_color.rgb, max(line_u, line_v) * line_strength);
	ALBEDO = color;
	ROUGHNESS = roughness;
}
