// Gemeinsame Schnee- und Jahreszeitenlogik für die Welt-Shader.
//
// Der Alpha-Kanal der Vertexfarbe ist ein Schnee-Merker (die Modelle werden
// ohnehin nicht transparent gezeichnet):
//   a < 0.6   Schneeauflage (Dächer, Kappen, Zäune, Äste) – schmilzt mit
//             sinkender Schneedecke fleckig weg und gibt das Darunter frei
//   a < 0.9   Bodenschnee (Schotter, Felsen, Pflasterreste) – wird zu blankem
//             Boden in der Farbe der Jahreszeit (season_bare)
//   sonst     normale Farbe
// Die Werte setzt das Autoload "Seasons" (Projekt → Shader-Globals).

global uniform float snow_cover;
global uniform vec4 season_bare;
global uniform float wetness;

float ws_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float ws_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(ws_hash(i), ws_hash(i + vec2(1.0, 0.0)), u.x),
		mix(ws_hash(i + vec2(0.0, 1.0)), ws_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Flecken für das Tauwetter: große Flächen plus feiner Rand.
float ws_patches(vec3 world_pos) {
	return ws_noise(world_pos.xz * 0.35 + world_pos.y * 0.2) * 0.65 + ws_noise(world_pos.xz * 1.7) * 0.35;
}

// Ist dieser Punkt einer Schneeauflage schon geschmolzen?
bool ws_layer_melted(vec3 world_pos) {
	return ws_patches(world_pos) > snow_cover * 1.1 - 0.05;
}

// Bodenschnee in blanken Boden überblenden. Rückgabe: Anteil Schnee (0..1).
float ws_ground_snow(vec3 world_pos, inout vec3 color) {
	float melt = smoothstep(snow_cover - 0.1, snow_cover + 0.1, ws_patches(world_pos));
	vec3 bare = season_bare.rgb * (0.85 + 0.3 * ws_noise(world_pos.xz * 3.1));
	color = mix(color, bare, melt);
	return 1.0 - melt;
}

// Schnee etwas weicher und wärmer: nicht reinweiß, im Schatten leicht bläulich.
vec3 ws_soft_snow(vec3 color) {
	return color * vec3(0.95, 0.955, 0.965);
}
