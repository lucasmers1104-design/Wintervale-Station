// Festbeleuchtung: Birnen an Buden, am Weihnachtsbaum, am Karussell und am Sonderzug.
//
// Farbe aus den Vertexfarben. Die Birnen funkeln leicht, jede in ihrem eigenen Takt
// (Alpha der Vertexfarbe = Zufallswert je Birne). [lit] schaltet ein (0..1). [reveal] lässt die Lichter
// von unten nach oben angehen – die Lichterwelle beim Lichterfest: Birnen unterhalb
// von reveal_height leuchten, darüber sind sie noch dunkel (Welt-Höhe relativ zum
// Ursprung des Objekts). [chase] > 0: Lauflicht (Karussell).
shader_type spatial;

uniform float lit : hint_range(0.0, 1.0) = 1.0;
uniform float energy = 3.2;
uniform float twinkle = 0.25;
uniform float reveal_height = 1000.0;
uniform float reveal_soft = 0.6;
uniform float chase = 0.0;

varying vec3 local_pos;
varying float seed;

void vertex() {
	local_pos = VERTEX;
	// Alpha der Vertexfarbe = Zufallswert je Birne (beim Bauen gesetzt)
	seed = COLOR.a;
}

void fragment() {
	float on = lit * (1.0 - smoothstep(reveal_height - reveal_soft, reveal_height, local_pos.y));
	float t = TIME * (1.2 + seed * 1.6) + seed * 40.0;
	float sparkle = 1.0 - twinkle * (0.5 + 0.5 * sin(t)) * step(0.35, seed);
	if (chase > 0.0) {
		float angle = atan(local_pos.z, local_pos.x);
		sparkle *= 0.45 + 0.55 * step(0.5, fract(angle * 1.9099 - TIME * chase));
	}
	ALBEDO = COLOR.rgb * mix(0.35, 1.0, on);
	ROUGHNESS = 0.25;
	EMISSION = COLOR.rgb * energy * on * sparkle + COLOR.rgb * 0.04;
}
