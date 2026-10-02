// Matte painted panels and seasonal snow, with the authored vertex palette.
shader_type spatial;
#include "res://assets/materials/world_snow.gdshaderinc"
varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 color = COLOR.rgb;
	float snow = 0.0;
	if (COLOR.a < 0.6) {
		if (ws_patches(local_pos * 1.3) > snow_cover * 1.1 - 0.05) { discard; }
		snow = 1.0;
		color = ws_soft_snow(color);
	}
	// Bright cream/orange panels keep headroom under the game's strong winter sun.
	float peak = max(max(color.r, color.g), color.b);
	float pigment = mix(0.86, 0.62, smoothstep(0.48, 0.82, peak));
	ALBEDO = color * mix(pigment, 1.0, snow) * (1.0 - wetness * (1.0 - snow) * 0.10);
	float saturation = peak - min(min(color.r, color.g), color.b);
	float matte = (1.0 - smoothstep(0.04, 0.12, saturation)) * (1.0 - smoothstep(0.22, 0.45, peak));
	ROUGHNESS = mix(mix(0.46, 0.80, matte), 0.96, snow);
	SPECULAR = mix(mix(0.50, 0.28, matte), 0.18, snow);
	CLEARCOAT = 0.22 * (1.0 - snow) * (1.0 - matte);
	CLEARCOAT_ROUGHNESS = 0.35;
}
