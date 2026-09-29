@tool
## Tag-/Nacht-Zyklus: steuert Sonne, Mond, Himmel, Umgebungslicht und Nebel.
##
## Liest im Spiel die Uhrzeit aus [code]WorldClock[/code]. Im Editor zeigt
## er stattdessen [member editor_preview_hour] an – so lässt sich jede
## Stimmung direkt in der Szene begutachten.
##
## Die Farbstimmungen sind als Stützpunkte (Stunde → Farbe) in
## _build_gradients() definiert: warmes Gold am Tag, ruhiges Tintenblau in der Nacht.
class_name DayNightCycle
extends Node3D

## Kleinste Drehung (Bogenmaß, ≈ 0,15°), ab der Sonne und Mond nachgeführt werden.
const LIGHT_STEP := 0.0026

@export var sun: DirectionalLight3D
@export var moon: DirectionalLight3D
@export var world_environment: WorldEnvironment
## Wetter (Wolken dämpfen Sonne und Schatten, Nebel, Sterne). Optional.
@export var weather: WeatherSystem

## Tageszeit, die im Editor als Vorschau gezeigt wird.
@export_range(0.0, 24.0, 0.25) var editor_preview_hour := 15.5:
	set(value):
		editor_preview_hour = value
		if Engine.is_editor_hint() and is_node_ready():
			apply_time(value)

@export_group("Himmelsbahnen")
## Maximale Sonnenhöhe in Grad – im Winter steht die Sonne flach.
@export_range(5.0, 80.0, 1.0) var max_sun_elevation := 30.0
@export_range(5.0, 80.0, 1.0) var max_moon_elevation := 42.0

@export_group("Helligkeit")
@export var sun_energy := 1.25
@export var moon_energy := 0.22
@export var day_ambient_energy := 0.5
@export var night_ambient_energy := 0.38

var _zenith_colors: Gradient
var _horizon_colors: Gradient
var _sun_colors: Gradient
var _ambient_colors: Gradient
var _base_fog := -1.0
var _base_fog_height := 0.0
var _cloud_drift := 0.0


func _ready() -> void:
	_build_gradients()
	apply_time(editor_preview_hour if Engine.is_editor_hint() else WorldClock.time_of_day)


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		apply_time(WorldClock.time_of_day)


## Wendet die Lichtstimmung einer Tageszeit (Stunden) auf die Szene an.
func apply_time(hour: float) -> void:
	if sun == null or moon == null or world_environment == null:
		return
	if _zenith_colors == null:
		_build_gradients()

	var in_game := not Engine.is_editor_hint()
	# Die Farbverläufe sind für den Wintertag (7–17 Uhr) angelegt; im Sommer wird
	# die Uhrzeit so umgerechnet, dass Morgen- und Abendfarben mit der Sonne wandern.
	var t := _winter_hour(hour) / 24.0
	var sun_angle := _celestial_angle(hour)
	var elevation := float(Seasons.get_value("elevation")) if in_game else max_sun_elevation
	var sun_dir := _sky_direction(sun_angle, elevation)
	var moon_dir := _sky_direction(sun_angle + PI, max_moon_elevation)

	var daylight := smoothstep(-0.05, 0.12, sun_dir.y)
	var moonlight := smoothstep(-0.05, 0.15, moon_dir.y) * (1.0 - daylight)
	# Wetter: Wolken dämpfen Sonne und Schatten, der Himmel wird grauer
	var cloud := weather.get_value("cloud") if weather and in_game else 0.0
	var sun_factor := weather.get_value("sun") if weather and in_game else 1.0
	var light_tint: Color = Seasons.get_value("light_tint") if in_game else Color.WHITE
	var sky_tint: Color = Seasons.get_value("sky_tint") if in_game else Color.WHITE

	_orient_light(sun, sun_dir)
	sun.light_color = _sun_colors.sample(t) * light_tint
	sun.light_energy = sun_energy * daylight * sun_factor
	sun.shadow_opacity = lerpf(1.0, 0.45, cloud)
	sun.visible = daylight > 0.001

	_orient_light(moon, moon_dir)
	moon.light_energy = moon_energy * moonlight * lerpf(1.0, 0.4, cloud)
	moon.visible = moonlight > 0.001

	var overcast := Color(0.62, 0.64, 0.68) * lerpf(0.25, 1.0, daylight)
	var zenith := (_zenith_colors.sample(t) * sky_tint).lerp(overcast * 0.85, cloud * 0.7)
	var horizon := (_horizon_colors.sample(t) * sky_tint).lerp(overcast, cloud * 0.6)
	var env := world_environment.environment
	env.ambient_light_color = _ambient_colors.sample(t).lerp(overcast, cloud * 0.35)
	env.ambient_light_energy = lerpf(night_ambient_energy, day_ambient_energy, daylight) * (1.0 + cloud * 0.18)
	env.fog_light_color = horizon.lerp(zenith, 0.35)
	if in_game:
		if _base_fog < 0.0:
			_base_fog = env.fog_density
			_base_fog_height = env.fog_height_density
		var weather_fog := weather.get_value("fog") if weather else 1.0
		var fog := float(Seasons.get_value("fog")) * weather_fog
		# Dichter Nebel ist kühl-grau, nicht vom warmen Horizont gefärbt
		var mist := clampf((weather_fog - 1.5) / 3.0, 0.0, 1.0)
		env.fog_light_color = env.fog_light_color.lerp(Color(0.74, 0.77, 0.8) * lerpf(0.22, 1.0, daylight), mist * 0.75)
		env.fog_density = _base_fog * fog
		env.fog_height_density = _base_fog_height * clampf(fog, 0.5, 2.5)
		_cloud_drift += get_process_delta_time() * (0.004 + (weather.get_value("wind") if weather else 0.3) * 0.02)

	var sky_material: ShaderMaterial = env.sky.sky_material as ShaderMaterial if env.sky else null
	if sky_material:
		var stars := weather.get_value("stars") if weather and in_game else 1.0
		sky_material.set_shader_parameter(&"zenith_color", zenith)
		sky_material.set_shader_parameter(&"horizon_color", horizon)
		sky_material.set_shader_parameter(&"ground_color", horizon.darkened(0.55))
		sky_material.set_shader_parameter(&"sun_direction", sun_dir)
		sky_material.set_shader_parameter(&"sun_color", sun.light_color * lerpf(1.0, 0.4, cloud))
		sky_material.set_shader_parameter(&"moon_direction", moon_dir)
		sky_material.set_shader_parameter(&"star_intensity", (1.0 - smoothstep(-0.2, 0.05, sun_dir.y)) * clampf(stars, 0.0, 1.4))
		sky_material.set_shader_parameter(&"cloud_cover", cloud)
		sky_material.set_shader_parameter(&"cloud_drift", _cloud_drift)
		sky_material.set_shader_parameter(&"cloud_light", _horizon_colors.sample(t).lerp(Color(0.86, 0.87, 0.9), 0.4) * lerpf(0.18, 1.0, daylight))


## Uhrzeit → "Winter-Uhrzeit": Sonnenaufgang wird 7 Uhr, Sonnenuntergang 17 Uhr.
func _winter_hour(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	var rise := _sunrise()
	var set_hour := _sunset()
	var w_rise := GameDefs.SUNRISE_HOUR
	var w_set := GameDefs.SUNSET_HOUR
	if h >= rise and h <= set_hour:
		return w_rise + (h - rise) / (set_hour - rise) * (w_set - w_rise)
	var night := fposmod(h - set_hour, 24.0) / (24.0 - (set_hour - rise))
	return fposmod(w_set + night * (24.0 - (w_set - w_rise)), 24.0)


func _sunrise() -> float:
	return GameDefs.SUNRISE_HOUR if Engine.is_editor_hint() else WorldClock.get_sunrise()


func _sunset() -> float:
	return GameDefs.SUNSET_HOUR if Engine.is_editor_hint() else WorldClock.get_sunset()


## Position auf der Himmelsbahn: 0..PI am Tag (Aufgang → Untergang),
## PI..TAU in der Nacht. Tag und Nacht dürfen unterschiedlich lang sein.
func _celestial_angle(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	var rise := _sunrise()
	var set_hour := _sunset()
	var day_length := set_hour - rise
	if h >= rise and h <= set_hour:
		return (h - rise) / day_length * PI
	return PI + fposmod(h - set_hour, 24.0) / (24.0 - day_length) * PI


## Richtung zum Himmelskörper. Er geht im Osten (+X) auf, zieht über den
## Süden (-Z) und geht im Westen (-X) unter.
func _sky_direction(angle: float, max_elevation_deg: float) -> Vector3:
	var elevation := sin(angle) * deg_to_rad(max_elevation_deg)
	var azimuth := PI * 0.5 + angle
	return Vector3(cos(elevation) * sin(azimuth), sin(elevation), cos(elevation) * cos(azimuth))


## Richtet ein Himmelslicht aus – in kleinen Schritten statt jedes Bild: Ein
## ständig minimal wanderndes Licht lässt die Schattenkanten flimmern
## ("Schattenkriechen"). Schritte unter [constant LIGHT_STEP] werden ausgelassen.
func _orient_light(light: DirectionalLight3D, direction_to_light: Vector3) -> void:
	var current := light.basis.z
	if Engine.is_editor_hint() or current.angle_to(direction_to_light) > LIGHT_STEP:
		light.basis = Basis.looking_at(-direction_to_light, Vector3.UP)


func _build_gradients() -> void:
	# Gemütlich: Tagsüber goldenes Sonnenlicht mit cremigem Horizont, die Schatten
	# kühl lavendel ("gelbes Licht, kalter Schnee"). Nachts ein ruhiges, entsättigtes
	# Tintenblau – dunkel genug, dass Laternen und Fenster warm leuchten.
	_zenith_colors = _make_gradient([
		[0.0, Color(0.020, 0.030, 0.065)],
		[5.8, Color(0.030, 0.040, 0.085)],
		[7.0, Color(0.24, 0.24, 0.40)],
		[8.5, Color(0.40, 0.50, 0.68)],
		[12.0, Color(0.44, 0.58, 0.76)],
		[15.2, Color(0.42, 0.50, 0.66)],
		[16.8, Color(0.30, 0.28, 0.44)],
		[18.3, Color(0.045, 0.050, 0.11)],
		[24.0, Color(0.020, 0.030, 0.065)],
	])
	_horizon_colors = _make_gradient([
		[0.0, Color(0.06, 0.07, 0.13)],
		[5.8, Color(0.07, 0.08, 0.15)],
		[6.6, Color(0.62, 0.42, 0.40)],
		[7.3, Color(1.0, 0.68, 0.44)],
		[8.6, Color(0.96, 0.87, 0.78)],
		[12.0, Color(0.93, 0.91, 0.88)],
		[15.0, Color(0.99, 0.87, 0.74)],
		[16.5, Color(1.0, 0.64, 0.38)],
		[17.4, Color(0.68, 0.38, 0.34)],
		[18.3, Color(0.10, 0.10, 0.18)],
		[24.0, Color(0.06, 0.07, 0.13)],
	])
	_sun_colors = _make_gradient([
		[0.0, Color(1.0, 0.48, 0.24)],
		[6.8, Color(1.0, 0.48, 0.24)],
		[7.8, Color(1.0, 0.68, 0.42)],
		[9.5, Color(1.0, 0.83, 0.62)],
		[12.0, Color(1.0, 0.88, 0.70)],
		[14.5, Color(1.0, 0.80, 0.56)],
		[16.2, Color(1.0, 0.64, 0.36)],
		[17.2, Color(1.0, 0.46, 0.22)],
		[24.0, Color(1.0, 0.48, 0.24)],
	])
	_ambient_colors = _make_gradient([
		[0.0, Color(0.24, 0.23, 0.30)],
		[6.5, Color(0.25, 0.23, 0.30)],
		[7.8, Color(0.58, 0.50, 0.58)],
		[10.0, Color(0.60, 0.62, 0.74)],
		[14.5, Color(0.64, 0.62, 0.72)],
		[16.5, Color(0.6, 0.5, 0.52)],
		[17.8, Color(0.28, 0.26, 0.34)],
		[24.0, Color(0.24, 0.23, 0.30)],
	])


## Erzeugt einen Verlauf aus [Stunde, Farbe]-Paaren.
func _make_gradient(keys: Array) -> Gradient:
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for key: Array in keys:
		offsets.append(float(key[0]) / 24.0)
		colors.append(key[1])
	var gradient := Gradient.new()
	gradient.offsets = offsets
	gradient.colors = colors
	return gradient
