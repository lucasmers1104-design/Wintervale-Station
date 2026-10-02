shader_type spatial;
render_mode unshaded, shadows_disabled;

void fragment() {
	// Warm bulbs retain their amber tint in the Compatibility renderer.
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb * 0.30;
}
