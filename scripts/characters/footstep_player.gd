## Spielt Schrittgeräusche passend zum Untergrund.
##
## Im Schnee knirscht es weich, auf Bahnsteig und Wegen klopft es leise, auf dem
## Bohlenübergang klingt es hohl nach Holz.
## Verbinden mit [signal CharacterModel.footstep]. Drei Varianten je Boden und
## leicht schwankende Tonhöhe verhindern, dass es mechanisch klingt.
class_name FootstepPlayer
extends AudioStreamPlayer3D

## Diese Ebenen zählen als Boden (Terrain, Bahnsteige, Holzübergänge).
const GROUND_MASK := GameDefs.LAYER_WORLD | GameDefs.LAYER_OBJECTS

@export var base_volume_db := -12.0

var _rng := RandomNumberGenerator.new()
var _last_surface := ""


func _ready() -> void:
	_rng.randomize()
	volume_db = base_volume_db
	unit_size = 3.0
	max_distance = 18.0
	bus = &"Master"


## Ein Schritt: Untergrund bestimmen und passenden Klang spielen.
func play_step() -> void:
	if not is_inside_tree():
		return
	_last_surface = get_surface()
	# Im Schnee bleiben Fußabdrücke zurück
	if _last_surface == "snow":
		var prints := get_tree().get_first_node_in_group(Footprints.GROUP) as Footprints
		if prints:
			prints.add_step(self, global_position)
	stream = SoundLibrary.get_sound("step_%s_%d" % [_last_surface, _rng.randi_range(0, 2)])
	pitch_scale = _rng.randf_range(0.9, 1.1)
	volume_db = base_volume_db + _rng.randf_range(-1.5, 1.0)
	SoundLibrary.play(self)


## "snow", "stone" oder "wood" – je nachdem, worauf die Figur gerade steht.
func get_surface() -> String:
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3.UP * 0.4
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 1.0, GROUND_MASK)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return _soft_ground()
	var collider: Object = hit["collider"]
	if collider is StationProp and (collider as StationProp).kind == StationProp.Kind.CROSSING:
		return "wood"
	if collider is RailwayPlatform or collider is StationProp:
		return "stone"
	# Gebaute Wege und der Dorfplatz sind geräumt – dort klingt es nach Stein
	var village := get_tree().get_first_node_in_group(VillageManager.GROUP) as VillageManager
	if village and village.is_on_path(global_position):
		return "stone"
	return _soft_ground()


func get_last_surface() -> String:
	return _last_surface


func _exit_tree() -> void:
	stop()
	stream = null


## Einen anderen Klang dieser Figur abspielen (z.B. Knarren der Bank).
func play_named(sound_name: String, volume_offset := 0.0) -> void:
	if not is_inside_tree():
		return
	stream = SoundLibrary.get_sound(sound_name)
	pitch_scale = _rng.randf_range(0.92, 1.08)
	volume_db = base_volume_db + volume_offset
	SoundLibrary.play(self)


## Weicher Boden: im Winter Schnee, sonst Wiese.
func _soft_ground() -> String:
	return "snow" if Seasons.get_snow_cover() >= 0.4 else "grass"
