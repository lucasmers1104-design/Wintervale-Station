// Zugfenster: dunkles Glas, oben spiegelt sich sanft der Himmel, dazu ein
// stilisierter schräger Glanzstreifen und warmes Innenlicht (oben etwas heller,
// wie unter den Deckenlampen). [glow] ist die Grundhelligkeit für alle Züge
// (tagsüber ein Hauch, nachts warm), die Instanz-Größe [cabin] das Innenlicht
// des einzelnen Wagens (Etappe 9.5: im Stand am Bahnsteig hell).
//
// Durch das Licht zeichnen sich die Rückenlehnen der Sitze als dunkle Umrisse
// ab – ohne echte Innenausstattung wirkt der Wagen bewohnt.
shader_type spatial;

uniform vec3 glass_color : source_color = vec3(0.1, 0.12, 0.15);
uniform vec3 sky_tint : source_color = vec3(0.6, 0.66, 0.8);
uniform vec3 light_color : source_color = vec3(1.0, 0.78, 0.5);
uniform float glow = 0.07;
uniform float shine = 0.18;
// Abstand der Sitzreihen (m) und Höhe der Lehnen (lokal über Schienenoberkante)
uniform float seat_pitch = 0.95;
uniform float seat_top = 2.32;
instance uniform float cabin = 0.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float upper = smoothstep(2.0, 2.85, local_pos.y);
	// Schräger Glanzstreifen (wie bei gezeichneten Fenstern)
	float band = fract((local_pos.z * 0.55 + local_pos.y * 0.9) * 0.45);
	float streak = smoothstep(0.0, 0.04, band) * (1.0 - smoothstep(0.1, 0.16, band));
	float light = min(glow + cabin * 0.95, 1.25);
	// Je heller innen, desto weniger spiegelt die Scheibe
	// Markierung im Alpha der Vertexfarbe: < 0.6 Frontscheibe (spiegelt wenig, Führerstand
	// dunkel), 0.6–0.9 Einstiegsraum hinter offenen Türen (hell, keine Sitze), sonst Fenster.
	float screen = step(COLOR.a, 0.6);
	float vestibule = step(0.6, COLOR.a) * (1.0 - step(0.9, COLOR.a));
	float reflect_amount = clamp(fresnel * 0.6 + upper * 0.3 * (1.0 - screen) + streak * shine, 0.0, 0.85)
		* (1.0 - clamp(light, 0.0, 1.0) * 0.45) * mix(1.0, 0.4, screen) * (1.0 - vestibule * 0.8);
	ALBEDO = mix(glass_color, sky_tint, reflect_amount);
	// Frontscheibe: getöntes Glas mit Tiefe statt einer schwarzen Fläche – oben spiegelt
	// sich der Himmel stärker, ein breiter weicher Glanz läuft schräg über die Scheibe.
	float screen_height = smoothstep(1.95, 3.45, local_pos.y);
	float sheen_band = fract((local_pos.x * 0.7 + local_pos.y * 1.2) * 0.32 + 0.35);
	float sheen = smoothstep(0.0, 0.18, sheen_band) * (1.0 - smoothstep(0.24, 0.5, sheen_band));
	float screen_reflect = clamp(0.1 + screen_height * 0.34 + fresnel * 0.3 + sheen * 0.2, 0.0, 0.78);
	ALBEDO = mix(ALBEDO, mix(glass_color * 0.85, sky_tint, screen_reflect), screen);
	ROUGHNESS = 0.1;
	SPECULAR = mix(0.75, 0.3, screen);
	float ceiling = smoothstep(1.9, 2.9, local_pos.y);
	// Sitzlehnen: abgerundete dunkle Buckel im unteren Teil des Fensters
	float cell = fract(local_pos.z / seat_pitch) - 0.5;
	float back = seat_top - 0.1 * (cell * cell * 4.0);
	float seat = (1.0 - smoothstep(back - 0.02, back + 0.02, local_pos.y)) * step(abs(cell), 0.38) * (1.0 - screen) * (1.0 - vestibule);
	vec3 inside = light_color * light * (0.7 + 0.5 * ceiling) * (1.0 - streak * 0.3);
	// Führerstand hinter der Frontscheibe bleibt dunkel (nur ein Hauch Pultbeleuchtung)
	// Einstiegsraum: unten dunkler Boden, darüber warmes Licht
	inside *= mix(1.0, mix(0.35, 0.95, smoothstep(1.15, 1.7, local_pos.y)), vestibule);
	EMISSION = inside * (1.0 - seat * 0.75) * mix(1.0, 0.06, screen);
	// Führerstand: unten am Scheibenrand glimmt nachts das Pult bernsteinfarben
	float console = (1.0 - smoothstep(2.02, 2.4, local_pos.y)) * smoothstep(1.9, 1.98, local_pos.y);
	EMISSION += vec3(1.0, 0.58, 0.26) * console * screen * clamp(glow, 0.0, 1.2) * 0.35;
}
