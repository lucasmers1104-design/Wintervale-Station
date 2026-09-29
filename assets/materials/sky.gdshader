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

// Wolken: Bedeckung (0 = klar, 1 = geschlossene Decke), Verschiebung durch den Wind,
// Farbe der beleuchteten Wolkenseite.
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.3;
uniform float cloud_drift = 0.0;
uniform vec3 cloud_light : source_color = vec3(0.95, 0.93, 0.9);

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float cloud_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash13(vec3(i, 1.0));
	float b = hash13(vec3(i + vec2(1.0, 0.0), 1.0));
	float c = hash13(vec3(i + vec2(0.0, 1.0), 1.0));
	float d = hash13(vec3(i + vec2(1.0, 1.0), 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float cloud_fbm(vec2 p) {
	float value = 0.0;
	float amp = 0.55;
	for (int i = 0; i < 4; i++) {
		value += cloud_noise(p) * amp;
		p = p * 2.03 + vec2(1.7, 9.2);
		amp *= 0.5;
	}
	return value;
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

	// Wolken: weiche Schichtwolken, von der Sonne her aufgehellt, zum Horizont dichter
	float density = 0.0;
	if (h > 0.0 && cloud_cover > 0.01) {
		vec2 uv = dir.xz / (h + 0.18) * 0.9 + vec2(cloud_drift, cloud_drift * 0.35);
		float n = cloud_fbm(uv);
		float threshold = mix(0.72, 0.28, cloud_cover);
		density = smoothstep(threshold, threshold + 0.22, n) * smoothstep(0.0, 0.14, h);
		density = max(density, smoothstep(0.55, 1.0, cloud_cover) * 0.85);
		float lit = 0.55 + 0.45 * pow(max(dot(dir, sun_dir), 0.0), 3.0) * sun_above;
		vec3 shade = mix(cloud_light * 0.62, cloud_light, clamp(n * 1.3 - 0.2, 0.0, 1.0));
		col = mix(col, shade * lit + sun_color * 0.08 * sun_above, density * 0.92);
	}

	// Sterne (nicht in der Reflexions-Cubemap, dort wären sie nur Rauschen)
	if (!AT_CUBEMAP_PASS && star_intensity > 0.0 && h > 0.0) {
		col += vec3(stars(dir)) * star_intensity * smoothstep(0.0, 0.25, h) * (1.0 - density);
	}

	COLOR = col;
}
