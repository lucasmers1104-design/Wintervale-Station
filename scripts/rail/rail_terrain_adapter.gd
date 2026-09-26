## Verbindet Gleisnetz und Gelände: Jedes Gleis formt einen Korridor im Terrain.
##
## Die Geländeanpassung wird nie separat gespeichert, sondern immer aus den
## gespeicherten Gleisen abgeleitet. Beim Bauen, Entfernen, Undo und Laden
## stimmt das Gelände dadurch automatisch – benachbarte Gleise behalten ihre
## eigene Anpassung, weil im Gleiskern stets das nächste Gleis bestimmt.
class_name RailTerrainAdapter
extends Node

@export var network: RailNetwork
@export var terrain: LowPolyTerrain


func _ready() -> void:
	network.segment_added.connect(_on_segment_added)
	network.segment_removed.connect(_on_segment_removed)
	for segment in network.get_segments():
		_on_segment_added(segment)


## Zeigt die Geländeanpassung eines geplanten Gleises (leer = Vorschau aus).
func show_preview(axis_points: PackedVector3Array) -> void:
	terrain.set_preview_corridor(axis_points)


func clear_preview() -> void:
	terrain.set_preview_corridor(PackedVector3Array())


func _on_segment_added(segment: RailSegment) -> void:
	terrain.set_track_corridor(segment.id, segment.axis_points)


func _on_segment_removed(segment: RailSegment) -> void:
	terrain.remove_track_corridor(segment.id)
