## Alles, was Bauwerkzeuge von der Welt brauchen – an einer Stelle gebündelt.
##
## Werkzeuge greifen nur über diesen Kontext auf Kamera, Terrain, Gleisnetz,
## Stellwerk und Undo zu. Neue Werkzeuge nutzen denselben Kontext.
class_name BuildContext
extends RefCounted

var camera: Camera3D
var terrain: LowPolyTerrain
var rail_network: RailNetwork
var rail_view: RailNetworkView
var interlocking: RailInterlocking
var terrain_adapter: RailTerrainAdapter
var undo_redo: UndoRedo


## Punkt auf dem Gelände unter dem Mauszeiger (Vector3.INF = keiner).
func get_mouse_ground_point() -> Vector3:
	if camera == null or not camera.is_inside_tree():
		return Vector3.INF
	var mouse := camera.get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	return terrain.intersect_ray(origin, direction, 800.0)


func get_space_state() -> PhysicsDirectSpaceState3D:
	return camera.get_world_3d().direct_space_state
