// Haus im Bau: Alles oberhalb von reveal_height (Objekthöhe in Metern) ist noch
// nicht gebaut und wird weggelassen. Direkt an der Baukante leuchtet frisches
// Material etwas heller (frisch verputzt, helles neues Holz). Rückseiten werden
// mitgezeichnet (etwas dunkler), damit man in den halbfertigen Rohbau sieht.
shader_type spatial;
render_mode cull_disabled;

uniform float reveal_height = 100.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.92;
uniform vec3 edge_color : source_color = vec3(0.96, 0.86, 0.66);

varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	if (local_y > reveal_height) {
		discard;
	}
	float edge = 1.0 - smoothstep(0.0, 0.18, reveal_height - local_y);
	vec3 color = mix(COLOR.rgb, edge_color, edge * 0.45);
	ALBEDO = FRONT_FACING ? color : color * 0.55;
	ROUGHNESS = roughness;
	SPECULAR = 0.3;
}
