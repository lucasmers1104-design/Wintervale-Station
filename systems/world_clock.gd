## Weltzeit (Autoload "WorldClock"): Tageszeit, Tageszähler und Zeitraffer.
##
## Andere Systeme lesen die Zeit hier oder reagieren auf die Signale:
## das Licht (DayNightCycle), Laternen – und später z.B. Fahrpläne.
## Die Uhr selbst weiß nichts über Grafik.
extends Node

signal minute_changed(hour: int, minute: int)
signal hour_changed(hour: int)
signal day_changed(day: int)
## Wechselt, wenn es dämmert (true) bzw. hell wird (false) – Lichter reagieren darauf.
signal darkness_changed(is_dark: bool)
signal time_scale_changed(time_scale: float)

const SAVE_ID := "world_clock"
## Wie viele Stunden vor Sonnenuntergang / nach Sonnenaufgang Lichter brennen.
const LIGHTS_MARGIN_HOURS := 0.75
## Stufen des Zeitraffers (Taste T).
const TIME_SCALES: Array[float] = [1.0, 10.0, 60.0]

## Echtzeit-Minuten für einen vollen Spieltag bei Zeitfaktor 1
## (48 → eine Spielminute dauert 2 Sekunden; genug Zeit für ruhige Zugfahrten).
@export var day_length_minutes := 48.0

## Aktuelle Tageszeit in Stunden (0.0 bis < 24.0).
var time_of_day := 15.0
var day := 1
var time_scale := 1.0
var paused := false

var _time_scale_index := 0
var _last_total_minutes := -1
var _is_dark := false


func _ready() -> void:
	add_to_group(GameDefs.GROUP_SAVEABLE)
	_is_dark = _compute_dark()
	_last_total_minutes = int(time_of_day * 60.0)


func _process(delta: float) -> void:
	if paused:
		return
	advance(delta * time_scale * 24.0 / (day_length_minutes * 60.0))


## Spult die Uhr um [param hours] Spielstunden vor.
func advance(hours: float) -> void:
	time_of_day += hours
	while time_of_day >= 24.0:
		time_of_day -= 24.0
		day += 1
		day_changed.emit(day)
	_emit_changes()


## Setzt die Uhr direkt auf eine Tageszeit (Stunden, z.B. 18.5 = 18:30).
func set_time(hour: float) -> void:
	time_of_day = fposmod(hour, 24.0)
	_emit_changes()


## Schaltet zur nächsten Zeitraffer-Stufe und gibt den neuen Faktor zurück.
func cycle_time_scale() -> float:
	_set_time_scale_index((_time_scale_index + 1) % TIME_SCALES.size())
	return time_scale


func get_hour() -> int:
	return int(time_of_day)


func get_minute() -> int:
	return int(fmod(time_of_day, 1.0) * 60.0)


func get_time_string() -> String:
	return "%02d:%02d" % [get_hour(), get_minute()]


## Rechnet Sekunden (Spielgeschwindigkeit ×1) in Spielstunden um.
func seconds_to_hours(seconds: float) -> float:
	return seconds * 24.0 / (day_length_minutes * 60.0)


## true zwischen Abenddämmerung und Morgendämmerung.
func is_dark() -> bool:
	return _is_dark


# --- Speichern -------------------------------------------------------------

func get_save_id() -> String:
	return SAVE_ID


func save_state() -> Dictionary:
	return {
		"time_of_day": time_of_day,
		"day": day,
		"time_scale_index": _time_scale_index,
	}


func load_state(data: Dictionary) -> void:
	day = int(data.get("day", day))
	_set_time_scale_index(int(data.get("time_scale_index", 0)))
	set_time(float(data.get("time_of_day", time_of_day)))


# --- Intern ----------------------------------------------------------------

func _set_time_scale_index(index: int) -> void:
	_time_scale_index = clampi(index, 0, TIME_SCALES.size() - 1)
	time_scale = TIME_SCALES[_time_scale_index]
	time_scale_changed.emit(time_scale)


func _emit_changes() -> void:
	var total_minutes := int(time_of_day * 60.0)
	if total_minutes != _last_total_minutes:
		var previous_hour := int(_last_total_minutes / 60.0)
		_last_total_minutes = total_minutes
		minute_changed.emit(get_hour(), get_minute())
		if get_hour() != previous_hour:
			hour_changed.emit(get_hour())

	var dark := _compute_dark()
	if dark != _is_dark:
		_is_dark = dark
		darkness_changed.emit(dark)


func _compute_dark() -> bool:
	return time_of_day < get_sunrise() + LIGHTS_MARGIN_HOURS \
		or time_of_day > get_sunset() - LIGHTS_MARGIN_HOURS


## Sonnenaufgang und -untergang (Stunden) – je nach Jahreszeit ("Seasons"), sonst Winter.
func get_sunrise() -> float:
	var seasons := get_node_or_null(^"/root/Seasons")
	return float(seasons.call(&"get_sunrise")) if seasons else GameDefs.SUNRISE_HOUR


func get_sunset() -> float:
	var seasons := get_node_or_null(^"/root/Seasons")
	return float(seasons.call(&"get_sunset")) if seasons else GameDefs.SUNSET_HOUR
