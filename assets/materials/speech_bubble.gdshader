// Sprechblase: cremefarbenes, abgerundetes Rechteck mit weichem Rand und einem
// kleinen Zipfel unten, immer zur Kamera gedreht. Liegt minimal hinter dem Text
// (Label3D). Sie wird ohne Tiefentest im Durchsichtig-Pfad gezeichnet – so verdecken
// Pfosten oder Äste sie nie; der Text liegt mit höherer Priorität darüber.
// [size] = Größe in Metern (ohne Zipfel).
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, depth_test_disabled, depth_draw_never;

uniform vec2 size = vec2(1.0, 0.4);
uniform float radius = 0.1;
uniform vec4 fill : source_color = vec4(0.99, 0.96, 0.9, 1.0);
uniform vec4 border : source_color = vec4(0.34, 0.25, 0.19, 1.0);
uniform float border_width = 0.018;
uniform float tail = 0.13;

varying vec2 local;

void vertex() {
	// Billboard: Achsen der Kamera, Größe aus [size] (Quad 1×1 m, Zipfel darunter)
	vec2 extent = size + vec2(0.0, tail);
	local = VERTEX.xy * extent + vec2(0.0, -tail * 0.5);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz + right * local.x + up * local.y;
	vec3 to_camera = normalize(INV_VIEW_MATRIX[3].xyz - world);
	world -= to_camera * 0.03;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Abstand zu einem Dreieck (Inigo Quilez)
float triangle(vec2 p, vec2 p0, vec2 p1, vec2 p2) {
	vec2 e0 = p1 - p0, e1 = p2 - p1, e2 = p0 - p2;
	vec2 v0 = p - p0, v1 = p - p1, v2 = p - p2;
	vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
	vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
	vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
	float s = sign(e0.x * e2.y - e0.y * e2.x);
	vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
		vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
		vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
	return -sqrt(d.x) * sign(d.y);
}

void fragment() {
	float d = rounded_box(local, size * 0.5, radius);
	// Zipfel: kleines Dreieck unten links der Mitte
	vec2 base = vec2(-size.x * 0.18, -size.y * 0.5 + 0.02);
	d = min(d, triangle(local, base + vec2(-0.07, 0.0), base + vec2(0.1, 0.0), base + vec2(-0.1, -tail)));
	float aa = fwidth(d) * 1.2;
	float shape = 1.0 - smoothstep(-aa, aa, d);
	float inner = 1.0 - smoothstep(-aa, aa, d + border_width);
	if (shape < 0.5) {
		discard;
	}
	ALBEDO = mix(border.rgb, fill.rgb, inner);
	// Durchsichtig-Pfad (nach allem Undurchsichtigen gezeichnet) – so liegt die Blase immer obenauf
	ALPHA = 1.0;
}
