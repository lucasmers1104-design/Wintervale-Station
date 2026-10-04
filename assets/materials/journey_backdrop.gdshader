shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
void fragment() {
	vec3 scene = textureLod(screen_texture, SCREEN_UV, 3.2).rgb;
	COLOR = vec4(mix(scene,vec3(0.18,0.13,0.11),0.20),1.0);
}
