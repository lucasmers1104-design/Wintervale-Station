// Gemeinsamer Teil der Figuren-Shader (character.gdshader für Körper,
// character_head.gdshader für den Kopf mit Blinzeln). Beschreibung der Vertexdaten
// siehe character.gdshader.

// Wie weit die Augen offen sind (1 offen, 0.1 zu) – je Figur (Blinzeln). Nur der Kopf
// braucht den Instanzparameter; jede Instanz mit Instanzparametern belegt Platz im
// globalen Puffer (Kompatibilitäts-Renderer: max. 4096), daher die Körperteile ohne.
#ifdef CHARACTER_BLINK
instance uniform float eye_open = 1.0;
#else
const float eye_open = 1.0;
#endif
uniform float rim_strength = 0.18;

varying flat float pattern;
varying float pattern_scale;
varying vec4 color2;
varying vec4 color3;

const float PATTERN_SOLID = 0.0;
const float PATTERN_PLAID = 1.0;      // Karo mit zwei Streifenrichtungen und feiner Linie
const float PATTERN_GINGHAM = 2.0;    // Vichy-Karo (Grundfarbe + halbtransparente Streifen)
const float PATTERN_STRIPES = 3.0;    // Querstreifen (Ringelpulli, Schal)
const float PATTERN_RIBS = 4.0;       // Strick-Rippen (senkrechte feine Rillen)
const float PATTERN_FAIR_ISLE = 5.0;  // Norweger-Band um die Brust
const float PATTERN_DIAMONDS = 6.0;   // Rautenmuster auf der Brust
const float PATTERN_FACE = 7.0;       // Gesicht (Augen, Brauen, Mund, Wangen)
const float PATTERN_SKIN = 8.0;       // Haut (etwas glatter)
const float PATTERN_QUILT = 9.0;      // Steppnähte (Daunenjacke, Weste)
const float PATTERN_KNIT_CUFF = 10.0; // Strickbund (dichte senkrechte Rippen)
const float PATTERN_GLOSS = 11.0;     // Knöpfe, Schnallen, Brillenfassung
const float PATTERN_TARTAN = 12.0;    // Schottenkaro (Rock): dunkle Grundlinien

void vertex() {
	pattern = UV2.x;
	pattern_scale = max(UV2.y, 0.001);
	color2 = CUSTOM0;
	color3 = CUSTOM1;
}

float ellipse(vec2 p, vec2 c, vec2 r) {
	vec2 d = (p - c) / r;
	return length(d);
}

// Weiche Kante für eine Fläche mit Wert < 1 innen.
float fill(float d, float soft) {
	return 1.0 - smoothstep(1.0 - soft, 1.0 + soft, d);
}

vec3 face(vec2 p, vec3 skin) {
	// p: x nach rechts aus Sicht der Figur gespiegelt egal (symmetrisch), y nach oben.
	vec2 q = vec2(abs(p.x), p.y);
	vec3 col = skin;
	float flags = color3.a;
	// Wangen
	float blush = fill(ellipse(q, vec2(0.72, -0.64), vec2(0.17, 0.13)), 0.45);
	col = mix(col, mix(skin, vec3(0.96, 0.52, 0.47), 0.75), blush * 0.85);
	// Sommersprossen (CUSTOM1.a > 0.5)
	if (flags > 0.5) {
		vec2 f1 = q - vec2(0.56, -0.56);
		vec2 f2 = q - vec2(0.68, -0.52);
		vec2 f3 = q - vec2(0.63, -0.62);
		float dots = 0.0;
		dots = max(dots, 1.0 - smoothstep(0.018, 0.026, length(f1)));
		dots = max(dots, 1.0 - smoothstep(0.016, 0.024, length(f2)));
		dots = max(dots, 1.0 - smoothstep(0.016, 0.024, length(f3)));
		col = mix(col, vec3(0.72, 0.4, 0.28), dots * 0.8);
	}
	// Augen: hohes Oval, weiß; Pupille zur Nase versetzt; dunkler Lidstrich oben
	vec2 eye_c = vec2(0.58, -0.32);
	vec2 eye_r = vec2(0.19, 0.215 * max(eye_open, 0.08));
	float eye = ellipse(q, eye_c, eye_r);
	float white = fill(eye, 0.06);
	vec3 eye_col = vec3(0.97, 0.96, 0.94);
	float pupil = fill(ellipse(q, eye_c + vec2(-0.055, -0.008), vec2(0.135, 0.195 * max(eye_open, 0.08))), 0.07) * white;
	eye_col = mix(eye_col, vec3(0.2, 0.12, 0.09), pupil);
	// Lichtpunkt oben außen in der Pupille
	float glint = fill(ellipse(q, eye_c + vec2(0.03, 0.09 * eye_open), vec2(0.035, 0.045 * eye_open)), 0.3) * pupil;
	eye_col = mix(eye_col, vec3(1.0), glint * 0.85);
	// Oberes Lid: dunkler Bogen, etwas breiter als das Auge
	float lid_ring = ellipse(q, eye_c + vec2(0.0, -0.01), eye_r + vec2(0.03, 0.035));
	float lid = (1.0 - smoothstep(1.0, 1.06, lid_ring)) * smoothstep(0.92, 1.0, lid_ring) * step(eye_c.y + eye_r.y * 0.15, q.y);
	col = mix(col, eye_col, white);
	col = mix(col, vec3(0.16, 0.1, 0.08), max(lid, (1.0 - white) * fill(lid_ring, 0.02) * step(eye_c.y + eye_r.y * 0.1, q.y)));
	// Geschlossenes Auge: nur ein Strich
	if (eye_open < 0.3) {
		float line = 1.0 - smoothstep(0.012, 0.024, abs(q.y - eye_c.y)) ;
		line *= step(abs(q.x - eye_c.x), eye_r.x);
		col = mix(col, vec3(0.16, 0.1, 0.08), line);
	}
	// Brauen: kurze, kräftige Bögen
	vec2 bq = q - vec2(0.57, 0.06);
	float arch = bq.y - (0.03 - bq.x * bq.x * 1.4);
	// color3.r: zusätzliche Dicke (0 = normal, 1 = buschig)
	float thick = 1.0 + color3.r;
	float brow = (1.0 - smoothstep(0.03 * thick, 0.045 * thick, abs(arch))) * (1.0 - smoothstep(0.14 + 0.02 * color3.r, 0.17 + 0.02 * color3.r, abs(bq.x)));
	brow *= step(0.5, color2.a);
	col = mix(col, color2.rgb, brow);
	// Mund: schmaler Lächelbogen (Kreisbogen unter dem Mittelpunkt)
	vec2 mq = (p - vec2(0.0, -0.52)) * vec2(1.0, 1.15);
	float r = length(mq);
	float smile = (1.0 - smoothstep(0.014, 0.028, abs(r - 0.22))) * step(mq.y, -0.1) * step(abs(mq.x), 0.2);
	col = mix(col, vec3(0.22, 0.12, 0.1), smile);
	return col;
}

void fragment() {
	vec3 base = COLOR.rgb;
	vec3 col = base;
	float rough = 0.88;
	float spec = 0.25;
	vec2 uv = UV * pattern_scale;
	if (pattern < 0.5) {
		col = base;
	} else if (pattern < 1.5) {
		vec2 cell = fract(uv);
		float bu = step(0.5, cell.x);
		float bv = step(0.5, cell.y);
		col = mix(base, color2.rgb, (bu + bv) * 0.5);
		float lu = 1.0 - smoothstep(0.03, 0.06, abs(cell.x - 0.25));
		float lv = 1.0 - smoothstep(0.03, 0.06, abs(cell.y - 0.25));
		col = mix(col, color3.rgb, max(lu, lv) * 0.4);
	} else if (pattern < 2.5) {
		vec2 cell = fract(uv);
		float bu = step(0.5, cell.x);
		float bv = step(0.5, cell.y);
		col = mix(base, color2.rgb, (bu + bv) * 0.5);
	} else if (pattern < 3.5) {
		col = mix(base, color2.rgb, step(0.5, fract(uv.y)));
	} else if (pattern < 4.5) {
		float rib = abs(fract(uv.x) - 0.5);
		col = base * (0.94 + rib * 0.12);
	} else if (pattern < 5.5) {
		// Norweger-Band (grandpa_fairisle): Zickzacklinie oben, Reihe aus Kreuzen in der Mitte,
		// Punktreihe unten. Höhe in Metern (UV.y, unskaliert), Wiederholung rundherum
		// = pattern_scale, Bandmitte = color3.a.
		float v = UV.y - color3.a;
		float u = UV.x * pattern_scale;
		float cell = fract(u) - 0.5;
		float zig = abs(fract(u * 2.0) - 0.5) * 0.03;
		float line1 = 1.0 - smoothstep(0.004, 0.008, abs(v - 0.045 + zig));
		vec2 c = vec2(cell * 0.06, v);
		float cross = step(abs(c.x), 0.008) * step(abs(c.y), 0.022) + step(abs(c.y), 0.008) * step(abs(c.x), 0.022);
		vec2 d = vec2(fract(u + 0.5) - 0.5, v + 0.045);
		float dots = step(abs(d.x * 0.06), 0.008) * step(abs(d.y), 0.008);
		col = mix(base, color2.rgb, clamp(line1 + cross + dots, 0.0, 1.0));
	} else if (pattern < 6.5) {
		// Rauten in drei Gruppen auf Brusthöhe
		vec2 c = vec2(fract(uv.x * 3.0) - 0.5, uv.y - color3.a);
		vec2 d = abs(c * vec2(1.0, 1.4));
		float dot1 = step(d.x + d.y, 0.05);
		vec2 c2 = abs(c - vec2(0.0, 0.07)) * vec2(1.0, 1.4);
		vec2 c3 = abs(c + vec2(0.0, 0.07)) * vec2(1.0, 1.4);
		vec2 c4 = abs(c - vec2(0.09, 0.0)) * vec2(1.0, 1.4);
		vec2 c5 = abs(c + vec2(0.09, 0.0)) * vec2(1.0, 1.4);
		float dots = max(max(dot1, step(c2.x + c2.y, 0.04)), max(step(c3.x + c3.y, 0.04), max(step(c4.x + c4.y, 0.04), step(c5.x + c5.y, 0.04))));
		dots *= step(abs(c.y), 0.14);
		col = mix(base, color2.rgb, dots);
	} else if (pattern < 7.5) {
		col = face(UV, base);
		rough = 0.62;
		spec = 0.32;
	} else if (pattern < 8.5) {
		rough = 0.62;
		spec = 0.32;
	} else if (pattern < 9.5) {
		float seam = 1.0 - smoothstep(0.0, 0.1, abs(fract(uv.y) - 0.5) - 0.38);
		col = base * mix(1.0, 0.8, seam);
	} else if (pattern < 10.5) {
		float rib = smoothstep(0.2, 0.5, abs(fract(uv.x) - 0.5));
		col = base * (0.86 + rib * 0.16);
	} else if (pattern < 11.5) {
		rough = 0.35;
		spec = 0.5;
	} else {
		vec2 cell = fract(uv);
		float lu = 1.0 - smoothstep(0.05, 0.1, abs(cell.x - 0.5));
		float lv = 1.0 - smoothstep(0.05, 0.1, abs(cell.y - 0.5));
		float fine_u = 1.0 - smoothstep(0.01, 0.025, abs(cell.x - 0.2));
		float fine_v = 1.0 - smoothstep(0.01, 0.025, abs(cell.y - 0.2));
		col = mix(base, color2.rgb, max(lu, lv) * 0.75);
		col = mix(col, color3.rgb, max(fine_u, fine_v) * 0.6);
	}
	ALBEDO = clamp(col, 0.0, 1.0);
	ROUGHNESS = rough;
	SPECULAR = spec;
	RIM = rim_strength;
	RIM_TINT = 0.6;
}
