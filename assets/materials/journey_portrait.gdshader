shader_type canvas_item;
uniform vec4 portrait_region = vec4(0.0, 0.0, 1.0, 1.0);
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
// Keep the reference's oval brass portrait and its bottom diamond,
// without drawing the rectangular paper around them.
void fragment() {
	vec2 local_uv = (UV - portrait_region.xy) / portrait_region.zw;
	vec2 oval = (local_uv - vec2(0.5, 0.452)) / vec2(0.486, 0.454);
	float diamond = abs(local_uv.x - 0.5) + abs(local_uv.y - 0.913);
	COLOR = texture(TEXTURE, UV) * tint;
	COLOR.a *= (dot(oval, oval) < 1.0 || diamond < 0.088) ? 1.0 : 0.0;
}
