## Drehpunkt eines hängenden Lampenkopfs: schwingt ganz leicht im Wind
## (stärker bei Sturm, fast ruhig bei klarem Wetter). Jede Lampe hat ihren
## eigenen Takt, damit nicht alle gleichzeitig pendeln.
class_name LampSway
extends Node3D

## Größter Ausschlag (Bogenmaß) bei vollem Wind.
@export var amplitude := 0.09

var _phase := 0.0
var _time := 0.0


func _ready() -> void:
	_phase = fposmod(global_position.x * 0.37 + global_position.z * 0.61, TAU)


func _process(delta: float) -> void:
	_time += delta
	var wind := WeatherSystem.wind
	var swing := amplitude * (0.12 + wind * 0.88)
	rotation.x = sin(_time * (1.3 + wind * 0.6) + _phase) * swing
	rotation.z = sin(_time * 0.9 + _phase * 1.7) * swing * 0.45
