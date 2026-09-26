// Selbstgebauter Himmel: Farbverlauf, Sonne mit warmem Schein, Mond und Sterne.
// Die Werte werden jeden Frame vom DayNightCycle-Skript gesetzt.
shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.33, 0.52, 0.78);
uniform vec3 horizon_color : source_color = vec3(0.80, 0.86, 0.92);
uniform vec3 ground_color : source_color = vec3(0.30, 0.32, 0.36);
// Je höher, desto schmaler das helle Band am Horizont.
uniform float horizon_curve : hint_range(0.5, 8.0) = 3.0;

// Richtung ZUR Sonne (nicht die Lichtrichtung).
uniform vec3 sun_direction = vec3(0.0, 0.5, -0.86);
uniform vec3 sun_color : source_color = vec3(1.0, 0.85, 0.65);
uniform float sun_disc_size : hint_range(0.005, 0.2) = 0.045;
uniform float sun_glow_strength : hint_range(0.0, 2.0) = 0.6;

uniform vec3 moon_direction = vec3(0.0, -0.5, 0.86);
uniform vec3 moon_color : source_color = vec3(0.85, 0.9, 1.0);
uniform float moon_disc_size : hint_range(0.005, 0.2) = 0.03;

uniform float star_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float star_density : hint_range(0.0, 0.05) = 0.012;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

// Sterne: ein 3D-Zellraster auf der Himmelskugel, wenige Zellen bekommen einen Stern.
float stars(vec3 dir) {
	vec3 p = dir * 250.0;
	vec3 cell = floor(p);
	float rnd = hash13(cell);
	if (rnd > star_density) {
		return 0.0;
	}
	vec3 jitter = vec3(hash13(cell + 17.3), hash13(cell + 41.7), hash13(cell + 73.1)) - 0.5;
	vec3 center = cell + 0.5 + jitter * 0.5;
	float brightness = 0.35 + 0.65 * (rnd / star_density);
	return smoothstep(0.45, 0.0, length(p - center)) * brightness;
}

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;

	// Grundverlauf: Zenit -> Horizont -> Boden
	vec3 col;
	if (h >= 0.0) {
		col = mix(zenith_color, horizon_color, pow(1.0 - h, horizon_curve));
	} else {
		col = mix(horizon_color, ground_color, smoothstep(0.0, 0.2, -h));
	}

	// Sonne: warmer Schein am Horizont und eine weiche Scheibe
	vec3 sun_dir = normalize(sun_direction);
	float sun_dot = max(dot(dir, sun_dir), 0.0);
	float sun_above = smoothstep(-0.15, 0.05, sun_dir.y);
	float horizon_band = pow(1.0 - abs(h), 4.0);
	col += sun_color * pow(sun_dot, 6.0) * sun_glow_strength * horizon_band * sun_above * 0.6;
	col += sun_color * pow(sun_dot, 64.0) * sun_glow_strength * 0.5 * sun_above;
	float sun_angle = acos(clamp(dot(dir, sun_dir), -1.0, 1.0));
	float sun_disc = 1.0 - smoothstep(sun_disc_size * 0.8, sun_disc_size, sun_angle);
	col += sun_color * sun_disc * 6.0 * sun_above;

	// Mond
	vec3 moon_dir = normalize(moon_direction);
	float moon_above = smoothstep(-0.05, 0.05, moon_dir.y);
	float moon_angle = acos(clamp(dot(dir, moon_dir), -1.0, 1.0));
	float moon_disc = 1.0 - smoothstep(moon_disc_size * 0.85, moon_disc_size, moon_angle);
	col = mix(col, moon_color * 1.4, moon_disc * moon_above);
	col += moon_color * pow(max(dot(dir, moon_dir), 0.0), 200.0) * 0.25 * moon_above;

	// Sterne (nicht in der Reflexions-Cubemap, dort wären sie nur Rauschen)
	if (!AT_CUBEMAP_PASS && star_intensity > 0.0 && h > 0.0) {
		col += vec3(stars(dir)) * star_intensity * smoothstep(0.0, 0.25, h);
	}

	COLOR = col;
}
