// Gesperrte Achievement-Abzeichen: silbergraue Medaille wie in der freigegebenen
// Achievements-Vorlage ("Busy Platform", "Welcoming Place" …). Die Helligkeit wird
// angehoben, damit das dunkle Gesicht des Siegels hellgrau statt schwarz wirkt.
shader_type canvas_item;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float grey = dot(color.rgb, vec3(0.3, 0.59, 0.11));
	vec3 silver = vec3(0.34 + grey * 0.6) * vec3(1.0, 0.97, 0.94);
	COLOR = vec4(silver, color.a * COLOR.a);
}
