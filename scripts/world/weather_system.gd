## Dynamisches Wetter: sonnig, bewölkt, leichter und starker Schneefall,
## klarer Winterabend, Regen und Nebel.
##
## Jedes Wetter hat eigene Werte ([constant PROFILES]): Schnee- und Regenpartikel,
## Wolken (dämpfen die Sonne, weichere Schatten, grauerer Himmel), Wind (Bäume,
## Fahnen, Schneetreiben, Windgeräusch), Nebel (Sichtweite), Sonnenlicht und
## Sterne. Welches Wetter als Nächstes kommt, hängt von der Jahreszeit ab
## ([constant CHANCES]): Schnee nur, solange Schnee liegt, Regen nur im Tauwetter
## und in den warmen Jahreszeiten, der klare Winterabend nur am Nachmittag.
##
## Wechsel sind weich: Alle Werte gleiten über [member transition_hours]
## Spielstunden zum neuen Wetter. Wer liest: DayNightCycle (Licht, Himmel,
## Nebel), Snowfall/Rainfall (Partikel), AmbientSoundscape (Klang), Shader
## (Globals [code]wind_strength[/code] und [code]wetness[/code]).
##
## Zum Ausprobieren: Taste K wechselt zum nächsten Wetter.
class_name WeatherSystem
extends Node

signal weather_changed(weather: Weather)

enum Weather { SUNNY, CLOUDY, LIGHT_SNOW, HEAVY_SNOW, CLEAR_EVENING, RAIN, FOG }

const SAVE_ID := "weather"
const GROUP := &"weather_system"
const NAMES: Array[String] = ["Sonnig", "Bewölkt", "Leichter Schneefall", "Starker Schneefall", "Klarer Winterabend",
	"Regen", "Nebel"]
## snow/rain = Niederschlag (0..1), cloud = Bewölkung, wind = Windstärke, fog = Nebel
## (Faktor auf die Grunddichte), sun = Sonnenlicht (Faktor), stars = Sterne (Faktor).
const PROFILES := {
	Weather.SUNNY: {"snow": 0.0, "rain": 0.0, "cloud": 0.08, "wind": 0.25, "fog": 0.7, "sun": 1.0, "stars": 1.0},
	Weather.CLOUDY: {"snow": 0.0, "rain": 0.0, "cloud": 0.75, "wind": 0.45, "fog": 1.15, "sun": 0.55, "stars": 0.15},
	Weather.LIGHT_SNOW: {"snow": 0.45, "rain": 0.0, "cloud": 0.7, "wind": 0.3, "fog": 1.6, "sun": 0.6, "stars": 0.2},
	Weather.HEAVY_SNOW: {"snow": 1.0, "rain": 0.0, "cloud": 0.95, "wind": 0.85, "fog": 3.4, "sun": 0.35, "stars": 0.0},
	Weather.CLEAR_EVENING: {"snow": 0.0, "rain": 0.0, "cloud": 0.0, "wind": 0.08, "fog": 0.55, "sun": 1.05, "stars": 1.35},
	Weather.RAIN: {"snow": 0.0, "rain": 1.0, "cloud": 0.9, "wind": 0.6, "fog": 1.9, "sun": 0.4, "stars": 0.0},
	Weather.FOG: {"snow": 0.0, "rain": 0.0, "cloud": 0.55, "wind": 0.06, "fog": 5.5, "sun": 0.5, "stars": 0.1},
}
## Gewichte je Jahreszeit (Frühling, Sommer, Herbst, Winter).
const CHANCES := {
	Weather.SUNNY: [3.0, 5.0, 2.0, 2.0],
	Weather.CLOUDY: [3.0, 2.0, 3.0, 2.0],
	Weather.LIGHT_SNOW: [0.4, 0.0, 0.4, 4.0],
	Weather.HEAVY_SNOW: [0.0, 0.0, 0.0, 1.4],
	Weather.CLEAR_EVENING: [0.0, 0.0, 0.6, 2.2],
	Weather.RAIN: [3.0, 1.6, 3.0, 0.0],
	Weather.FOG: [1.0, 0.4, 2.0, 1.2],
}

@export var snowfall: Snowfall
@export var rainfall: Rainfall
@export var enabled := true
## So lange (Spielstunden) gleitet das Wetter zum nächsten.
@export var transition_hours := 1.2
## So lange (Spielstunden) bleibt ein Wetter mindestens / höchstens.
@export var duration_hours := Vector2(2.5, 6.5)
@export var weather_seed := 1234

## Aktuelle Windstärke (0..1) für alles, was im Wind schwingt (Lampen, Fahnen …).
static var wind := 0.35

var current := Weather.LIGHT_SNOW
## Nässe des Bodens (0..1): steigt bei Regen, trocknet danach langsam.
var wetness := 0.0

var _values := {}
var _from := {}
var _blend := 1.0
var _remaining := 3.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(GameDefs.GROUP_SAVEABLE)
	_rng.seed = weather_seed
	_values = (PROFILES[current] as Dictionary).duplicate()
	_from = _values.duplicate()
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"next_weather"):
		set_weather(((current + 1) % NAMES.size()) as Weather)
		Events.notification_requested.emit("Wetter: %s" % NAMES[current])
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not enabled or WorldClock.paused:
		_apply()
		return
	var hours := WorldClock.seconds_to_hours(delta * WorldClock.time_scale)
	_blend = minf(1.0, _blend + hours / maxf(transition_hours, 0.01))
	var target: Dictionary = PROFILES[current]
	var t := smoothstep(0.0, 1.0, _blend)
	for key: String in target:
		_values[key] = lerpf(float(_from[key]), float(target[key]), t)
	# Nässe: Regen macht nass (≈ 1,5 h), danach trocknet es langsam (≈ 5 h)
	wetness = move_toward(wetness, 1.0 if float(_values["rain"]) > 0.3 else 0.0,
		hours / (1.5 if float(_values["rain"]) > 0.3 else 5.0))
	_remaining -= hours
	if _remaining <= 0.0:
		_choose_next()
	_apply()


# --- Abfragen -------------------------------------------------------------------------------

## Aktueller (übergeblendeter) Wert: snow, rain, cloud, wind, fog, sun, stars.
func get_value(key: String) -> float:
	return float(_values.get(key, 0.0))


func get_weather_name() -> String:
	return NAMES[current]


func is_transitioning() -> bool:
	return _blend < 1.0


# --- Steuern ---------------------------------------------------------------------------------

## Wechselt zum Wetter [param weather] (weich, außer [param instant]).
func set_weather(weather: Weather, instant := false, hours := -1.0) -> void:
	_from = _values.duplicate()
	current = weather
	_blend = 1.0 if instant else 0.0
	if instant:
		_values = (PROFILES[weather] as Dictionary).duplicate()
		_from = _values.duplicate()
	_remaining = hours if hours > 0.0 else _rng.randf_range(duration_hours.x, duration_hours.y)
	weather_changed.emit(weather)
	_apply()


## Nächstes Wetter passend zur Jahreszeit und Tageszeit auswählen.
func _choose_next() -> void:
	var weights := Seasons.get_weights()
	var snow_cover := Seasons.get_snow_cover()
	var hour := WorldClock.time_of_day
	var total := 0.0
	var options: Array = []
	for weather: Weather in CHANCES:
		var chance := 0.0
		for i in 4:
			chance += float(CHANCES[weather][i]) * weights[i]
		# Niederschlag passend zum Boden: Schnee nur, wo Schnee liegt; Regen nicht im tiefen Winter
		if (weather == Weather.LIGHT_SNOW or weather == Weather.HEAVY_SNOW) and snow_cover < 0.3:
			chance = 0.0
		if weather == Weather.RAIN and snow_cover > 0.7:
			chance = 0.0
		if weather == Weather.CLEAR_EVENING and (hour < 13.5 or hour > 19.0):
			chance = 0.0
		if weather == current:
			chance *= 0.3  # lieber etwas Abwechslung
		if chance > 0.0:
			options.append([weather, chance])
			total += chance
	var pick := _rng.randf() * total
	for option: Array in options:
		pick -= float(option[1])
		if pick <= 0.0:
			set_weather(option[0])
			return
	set_weather(Weather.CLOUDY)


func _apply() -> void:
	wind = get_value("wind")
	RenderingServer.global_shader_parameter_set(&"wind_strength", wind)
	RenderingServer.global_shader_parameter_set(&"wetness", wetness)
	if snowfall:
		snowfall.set_weather(get_value("snow"), wind)
	if rainfall:
		rainfall.set_weather(get_value("rain"), wind)


# --- Speichern -------------------------------------------------------------------------------

func get_save_id() -> String:
	return SAVE_ID


func save_state() -> Dictionary:
	return {"current": current, "remaining": _remaining, "wetness": wetness}


func load_state(data: Dictionary) -> void:
	set_weather(clampi(int(data.get("current", current)), 0, NAMES.size() - 1) as Weather, true,
		float(data.get("remaining", 3.0)))
	wetness = float(data.get("wetness", 0.0))
	_apply()
