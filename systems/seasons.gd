## Jahreszeiten (Autoload "Seasons"): Frühling, Sommer, Herbst, Winter.
##
## Das Jahr folgt den Spieltagen von [code]WorldClock[/code]. Jede Jahreszeit
## hat eine eigene Länge (der Winter ist am längsten – er ist die stärkste
## Stimmung des Spiels). Tag 1 beginnt im Winter.
##
## Die Übergänge sind weich: Im letzten Viertel einer Jahreszeit blendet alles
## langsam zur nächsten über (Schnee taut fleckig, Laub färbt sich, Tage werden
## länger). Die Werte gehen als Shader-Globals an alle Welt-Shader
## ([code]snow_cover[/code], [code]season_grass[/code], [code]season_bare[/code],
## [code]foliage_autumn[/code], [code]foliage_spring[/code]) und werden von
## DayNightCycle (Tageslänge, Sonnenhöhe, Farben, Nebel), Wetter und Klangkulisse gelesen.
##
## Zum Ausprobieren: Taste J blendet in ein paar Sekunden zur nächsten Jahreszeit.
extends Node

signal season_changed(season: Season)

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

const SAVE_ID := "seasons"
const NAMES: Array[String] = ["Frühling", "Sommer", "Herbst", "Winter"]
## Länge der Jahreszeiten in Spieltagen (Frühling, Sommer, Herbst, Winter).
const LENGTHS: Array[float] = [5.0, 5.0, 5.0, 8.0]
## So viel einer Jahreszeit (am Ende) ist Übergang zur nächsten.
const BLEND_SHARE := 0.28
## Tag 1 um Mitternacht liegt so weit (in Tagen) im Winter.
const START_IN_WINTER := 1.0

## Werte je Jahreszeit (Frühling, Sommer, Herbst, Winter).
const PROFILES := {
	"snow": [0.0, 0.0, 0.0, 1.0],
	"grass": [Color(0.4, 0.56, 0.3), Color(0.39, 0.53, 0.25), Color(0.42, 0.44, 0.26), Color(0.46, 0.47, 0.36)],
	"bare": [Color(0.42, 0.36, 0.29), Color(0.56, 0.5, 0.41), Color(0.45, 0.37, 0.29), Color(0.47, 0.44, 0.4)],
	"autumn": [0.0, 0.0, 1.0, 0.0],
	"spring": [1.0, 0.35, 0.0, 0.0],
	"sunrise": [6.0, 5.0, 6.6, 7.0],
	"sunset": [19.5, 21.4, 18.4, 17.0],
	"elevation": [44.0, 58.0, 36.0, 30.0],
	"fog": [0.8, 0.5, 1.1, 1.0],
	## Tönung des Tageslichts (Sommer satter und wärmer, Herbst golden, Frühling frisch)
	"light_tint": [Color(1.0, 1.0, 0.97), Color(1.03, 1.0, 0.92), Color(1.04, 0.97, 0.88), Color(1.0, 1.0, 1.0)],
	"sky_tint": [Color(0.95, 1.02, 1.05), Color(0.9, 1.0, 1.12), Color(1.05, 0.98, 0.9), Color(1.0, 1.0, 1.0)],
	## Klangkulisse: Vögel, Grillen in Sommernächten, Blätterrascheln
	"birds": [1.0, 0.8, 0.45, 0.35],
	"crickets": [0.0, 1.0, 0.25, 0.0],
	"leaves": [0.6, 0.8, 1.0, 0.25],
}

## Zusätzlicher Versatz im Jahr (Tage) – für "Nächste Jahreszeit" und Tests.
var offset_days := 0.0
## Zum Testen: feste Position im Jahr (0..1) statt aus der Uhr (-1 = aus).
var forced_position := -1.0

var _season := Season.WINTER
var _values := {}
var _skip_tween: Tween
var _timer := 0.0


func _ready() -> void:
	add_to_group(GameDefs.GROUP_SAVEABLE)
	_update(true)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.1
		_update(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"next_season"):
		skip_to_next()
		get_viewport().set_input_as_handled()


# --- Abfragen -----------------------------------------------------------------------------

func year_length() -> float:
	var total := 0.0
	for length in LENGTHS:
		total += length
	return total


## Position im Jahr in Tagen ab Frühlingsbeginn (0 … Jahreslänge).
func year_day() -> float:
	var winter_start := LENGTHS[0] + LENGTHS[1] + LENGTHS[2]
	if forced_position >= 0.0:
		return forced_position * year_length()
	var days := float(WorldClock.day - 1) + WorldClock.time_of_day / 24.0 + offset_days
	return fposmod(winter_start + START_IN_WINTER + days, year_length())


func get_season() -> Season:
	return _season


func get_season_name(season: Season = _season) -> String:
	return NAMES[season]


## Wie weit die aktuelle Jahreszeit fortgeschritten ist (0..1).
func get_season_progress() -> float:
	var day := year_day()
	var start := 0.0
	for i in LENGTHS.size():
		if day < start + LENGTHS[i]:
			return (day - start) / LENGTHS[i]
		start += LENGTHS[i]
	return 1.0


## Gewichte der vier Jahreszeiten (Summe 1): außerhalb der Übergänge ist es
## genau eine, im Übergang mischen sich zwei weich. Der Übergang liegt mittig
## auf der Grenze (halb am Ende der alten, halb am Anfang der neuen Jahreszeit).
func get_weights() -> Array[float]:
	var weights: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var day := year_day()
	var start := 0.0
	var half := BLEND_SHARE * 0.5
	for i in LENGTHS.size():
		var length := LENGTHS[i]
		if day < start + length or i == LENGTHS.size() - 1:
			var local := clampf((day - start) / length, 0.0, 1.0)
			if local > 1.0 - half:
				var t := smoothstep(0.0, 1.0, (local - (1.0 - half)) / (2.0 * half))
				weights[i] = 1.0 - t
				weights[(i + 1) % 4] += t
			elif local < half:
				var t := smoothstep(0.0, 1.0, (local + half) / (2.0 * half))
				weights[i] = t
				weights[(i + 3) % 4] += 1.0 - t
			else:
				weights[i] = 1.0
			return weights
		start += length
	weights[Season.WINTER] = 1.0
	return weights


## Aktueller (gemischter) Wert, z.B. get_value("sunrise").
func get_value(key: String) -> Variant:
	# Nicht als Standardwert von get() mischen – der würde bei jedem Aufruf berechnet
	if _values.has(key):
		return _values[key]
	return _mix(key, get_weights())


func get_snow_cover() -> float:
	return float(get_value("snow"))


func get_sunrise() -> float:
	return float(get_value("sunrise"))


func get_sunset() -> float:
	return float(get_value("sunset"))


# --- Steuern --------------------------------------------------------------------------------

## Blendet in ein paar Sekunden zur nächsten Jahreszeit (für Tests und zum Ausprobieren).
func skip_to_next(seconds := 6.0) -> void:
	var day := year_day()
	var start := 0.0
	var target := 0.0
	for i in LENGTHS.size():
		if day < start + LENGTHS[i]:
			target = start + LENGTHS[i] + LENGTHS[(i + 1) % 4] * 0.15
			break
		start += LENGTHS[i]
	var delta_days := target - day
	if _skip_tween and _skip_tween.is_valid():
		_skip_tween.kill()
	if seconds <= 0.0 or not is_inside_tree():
		offset_days += delta_days
		_update(true)
		return
	_skip_tween = create_tween()
	_skip_tween.tween_property(self, "offset_days", offset_days + delta_days, seconds).set_trans(Tween.TRANS_SINE)
	Events.notification_requested.emit("Jahreszeit: %s" % NAMES[(_season_at(target)) as int])


## Setzt das Jahr direkt auf den Anfang (oder [param progress]) einer Jahreszeit.
func set_season(season: Season, progress := 0.4) -> void:
	var start := 0.0
	for i in season:
		start += LENGTHS[i]
	var target := start + LENGTHS[season] * progress
	var current := year_day() - offset_days
	offset_days = fposmod(target - current, year_length())
	_update(true)


func _season_at(day: float) -> Season:
	var start := 0.0
	for i in LENGTHS.size():
		if fposmod(day, year_length()) < start + LENGTHS[i]:
			return i as Season
		start += LENGTHS[i]
	return Season.WINTER


func _update(force: bool) -> void:
	var weights := get_weights()
	for key: String in PROFILES:
		_values[key] = _mix(key, weights)
	var season := _season_at(year_day())
	if season != _season or force:
		var changed := season != _season
		_season = season
		if changed:
			season_changed.emit(season)
	RenderingServer.global_shader_parameter_set(&"snow_cover", float(_values["snow"]))
	RenderingServer.global_shader_parameter_set(&"season_grass", _values["grass"])
	RenderingServer.global_shader_parameter_set(&"season_bare", _values["bare"])
	RenderingServer.global_shader_parameter_set(&"foliage_autumn", float(_values["autumn"]))
	RenderingServer.global_shader_parameter_set(&"foliage_spring", float(_values["spring"]))


func _mix(key: String, weights: Array[float]) -> Variant:
	var list: Array = PROFILES[key]
	if list[0] is Color:
		var color := Color(0, 0, 0, 0)
		for i in 4:
			color += (list[i] as Color) * weights[i]
		return color
	var value := 0.0
	for i in 4:
		value += float(list[i]) * weights[i]
	return value


# --- Speichern -------------------------------------------------------------------------------

func get_save_id() -> String:
	return SAVE_ID


func save_state() -> Dictionary:
	return {"offset_days": offset_days}


func load_state(data: Dictionary) -> void:
	offset_days = float(data.get("offset_days", 0.0))
	_update(true)
