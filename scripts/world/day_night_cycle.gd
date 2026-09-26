@tool
## Tag-/Nacht-Zyklus: steuert Sonne, Mond, Himmel, Umgebungslicht und Nebel.
##
## Liest im Spiel die Uhrzeit aus [code]WorldClock[/code]. Im Editor zeigt
## er stattdessen [member editor_preview_hour] an – so lässt sich jede
## Stimmung direkt in der Szene begutachten.
##
## Die Farbstimmungen sind als Stützpunkte (Stunde → Farbe) in
## _build_gradients() definiert: warmes Gold am Tag, kaltes Blau in der Nacht.
class_name DayNightCycle
extends Node3D

@export var sun: DirectionalLight3D
@export var moon: DirectionalLight3D
@export var world_environment: WorldEnvironment

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
@export var sun_energy := 1.15
@export var moon_energy := 0.3
@export var day_ambient_energy := 0.6
@export var night_ambient_energy := 0.45

var _zenith_colors: Gradient
var _horizon_colors: Gradient
var _sun_colors: Gradient
var _ambient_colors: Gradient


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

	var t := fposmod(hour, 24.0) / 24.0
	var sun_angle := _celestial_angle(hour)
	var sun_dir := _sky_direction(sun_angle, max_sun_elevation)
	var moon_dir := _sky_direction(sun_angle + PI, max_moon_elevation)

	var daylight := smoothstep(-0.05, 0.12, sun_dir.y)
	var moonlight := smoothstep(-0.05, 0.15, moon_dir.y) * (1.0 - daylight)

	_orient_light(sun, sun_dir)
	sun.light_color = _sun_colors.sample(t)
	sun.light_energy = sun_energy * daylight
	sun.visible = daylight > 0.001

	_orient_light(moon, moon_dir)
	moon.light_energy = moon_energy * moonlight
	moon.visible = moonlight > 0.001

	var zenith := _zenith_colors.sample(t)
	var horizon := _horizon_colors.sample(t)
	var env := world_environment.environment
	env.ambient_light_color = _ambient_colors.sample(t)
	env.ambient_light_energy = lerpf(night_ambient_energy, day_ambient_energy, daylight)
	env.fog_light_color = horizon.lerp(zenith, 0.35)

	var sky_material: ShaderMaterial = env.sky.sky_material as ShaderMaterial if env.sky else null
	if sky_material:
		sky_material.set_shader_parameter(&"zenith_color", zenith)
		sky_material.set_shader_parameter(&"horizon_color", horizon)
		sky_material.set_shader_parameter(&"ground_color", horizon.darkened(0.55))
		sky_material.set_shader_parameter(&"sun_direction", sun_dir)
		sky_material.set_shader_parameter(&"sun_color", sun.light_color)
		sky_material.set_shader_parameter(&"moon_direction", moon_dir)
		sky_material.set_shader_parameter(&"star_intensity", 1.0 - smoothstep(-0.2, 0.05, sun_dir.y))


## Position auf der Himmelsbahn: 0..PI am Tag (Aufgang → Untergang),
## PI..TAU in der Nacht. Tag und Nacht dürfen unterschiedlich lang sein.
func _celestial_angle(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	var rise := GameDefs.SUNRISE_HOUR
	var set_hour := GameDefs.SUNSET_HOUR
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


func _orient_light(light: DirectionalLight3D, direction_to_light: Vector3) -> void:
	light.basis = Basis.looking_at(-direction_to_light, Vector3.UP)


func _build_gradients() -> void:
	_zenith_colors = _make_gradient([
		[0.0, Color(0.015, 0.025, 0.07)],
		[5.8, Color(0.02, 0.035, 0.09)],
		[7.0, Color(0.16, 0.20, 0.38)],
		[8.5, Color(0.30, 0.45, 0.68)],
		[12.0, Color(0.33, 0.52, 0.78)],
		[15.5, Color(0.28, 0.42, 0.66)],
		[17.0, Color(0.16, 0.17, 0.36)],
		[18.3, Color(0.03, 0.04, 0.11)],
		[24.0, Color(0.015, 0.025, 0.07)],
	])
	_horizon_colors = _make_gradient([
		[0.0, Color(0.04, 0.06, 0.13)],
		[5.8, Color(0.05, 0.07, 0.15)],
		[6.6, Color(0.55, 0.38, 0.40)],
		[7.3, Color(0.98, 0.62, 0.40)],
		[8.6, Color(0.86, 0.82, 0.80)],
		[12.0, Color(0.80, 0.86, 0.92)],
		[15.2, Color(0.92, 0.80, 0.66)],
		[16.6, Color(1.0, 0.58, 0.34)],
		[17.4, Color(0.55, 0.30, 0.32)],
		[18.3, Color(0.07, 0.08, 0.17)],
		[24.0, Color(0.04, 0.06, 0.13)],
	])
	_sun_colors = _make_gradient([
		[0.0, Color(1.0, 0.42, 0.22)],
		[6.8, Color(1.0, 0.42, 0.22)],
		[7.8, Color(1.0, 0.66, 0.40)],
		[9.5, Color(1.0, 0.86, 0.68)],
		[12.0, Color(1.0, 0.93, 0.84)],
		[14.5, Color(1.0, 0.84, 0.64)],
		[16.2, Color(1.0, 0.62, 0.36)],
		[17.2, Color(1.0, 0.40, 0.20)],
		[24.0, Color(1.0, 0.42, 0.22)],
	])
	_ambient_colors = _make_gradient([
		[0.0, Color(0.16, 0.21, 0.38)],
		[6.5, Color(0.18, 0.22, 0.38)],
		[7.8, Color(0.55, 0.52, 0.58)],
		[10.0, Color(0.62, 0.67, 0.78)],
		[14.5, Color(0.64, 0.64, 0.72)],
		[16.5, Color(0.55, 0.45, 0.50)],
		[17.8, Color(0.20, 0.23, 0.40)],
		[24.0, Color(0.16, 0.21, 0.38)],
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
