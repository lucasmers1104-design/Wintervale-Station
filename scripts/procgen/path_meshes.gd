@tool
## Terrain-following path materials and shared, flat polygon surfaces.
class_name PathMeshes
extends RefCounted

const STYLES := {
	"path_gravel": {"width": 1.6, "lift": 0.05},
	"path_stone": {"width": 2.0, "lift": 0.062},
	"path_road": {"width": 3.2, "lift": 0.074},
}
const MATERIALS := {
	"path_gravel": preload("res://assets/materials/path_gravel.tres"),
	"path_stone": preload("res://assets/materials/path_stone.tres"),
	"path_road": preload("res://assets/materials/path_road.tres"),
}


static func get_width(item_id: String) -> float:
	return float(STYLES.get(item_id, STYLES["path_gravel"])["width"])


## Material der Wegoberfläche (Oberfläche 0 des Meshes).
static func material(item_id: String) -> Material:
	return MATERIALS.get(item_id, MATERIALS["path_gravel"])


static func route_length(points: PackedVector3Array) -> float:
	var length := 0.0
	for i in range(1,points.size()):
		length += Vector2(points[i].x-points[i-1].x,points[i].z-points[i-1].z).length()
	return length


## Shared paving for forecourts and door aprons, in the path shader's world pattern.
static func paved_rect(width: float, length: float) -> ArrayMesh:
	var st := _new_st()
	_quad(st,Vector3(-width/2,0,-length/2),Vector3(width/2,0,-length/2),Vector3(width/2,0,length/2),Vector3(-width/2,0,length/2),[Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO],[0,0,0,0])
	return st.commit()

static func paved_disc(radius: float) -> ArrayMesh:
	var st := _new_st()
	for i in 48:
		var a := TAU*i/48
		var b := TAU*(i+1)/48
		_triangle(st,Vector3.ZERO,Vector3(cos(a),0,sin(a))*radius,Vector3(cos(b),0,sin(b))*radius,[Vector2.ZERO,Vector2.ZERO,Vector2.ZERO],[0,0,0])
	return st.commit()


## A sampled quadratic bend, optionally continuing the preceding path's tangent.
static func curve_route(a: Vector3, b: Vector3, incoming := Vector3.ZERO, bend := 1.0) -> PackedVector3Array:
	var chord := Vector3(b.x-a.x,0,b.z-a.z)
	var length := chord.length()
	if length<2.0:
		return PackedVector3Array([a,b])
	var control := a+chord*0.5+chord.cross(Vector3.UP)*bend*0.28
	if incoming.length_squared()>0.01 and incoming.normalized().dot(chord.normalized())>0.15:
		control = a+incoming.normalized()*length*0.50
	var points := PackedVector3Array()
	var count := clampi(ceili(length/2.0),2,24)
	for i in count+1:
		var t := float(i)/count
		var point := a*(1-t)*(1-t)+control*2*(1-t)*t+b*t*t
		point.y = lerpf(a.y,b.y,t)
		points.append(point)
	return points


## Curves stay one saved object, one price and one undo action.
static func build_route(item_id: String, points: PackedVector3Array, height: Callable, _caps := [true,true], _blocked := Callable()) -> ArrayMesh:
	return build_network(item_id,[points],height)


static func build_network(item_id: String, routes: Array, height: Callable) -> ArrayMesh:
	var style: Dictionary = STYLES.get(item_id,STYLES["path_gravel"])
	return preload("res://scripts/procgen/path_surface.gd").build(routes,float(style["width"])*0.5,float(style["lift"]),height)


static func build(item_id: String, a: Vector3, b: Vector3, height: Callable, caps := [true,true], blocked := Callable()) -> ArrayMesh:
	return build_route(item_id,PackedVector3Array([a,b]),height,caps,blocked)

## Viereck mit UVs und Spurstärke je Ecke; die Vorderseite zeigt immer nach oben.
static func _quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, uvs: Array, lanes: Array) -> void:
	_triangle(st, p0, p1, p2, [uvs[0], uvs[1], uvs[2]], [lanes[0], lanes[1], lanes[2]])
	_triangle(st, p0, p2, p3, [uvs[0], uvs[2], uvs[3]], [lanes[0], lanes[2], lanes[3]])


static func _triangle(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, uvs: Array, lanes: Array) -> void:
	var points := [p0, p1, p2]
	var order := [0, 1, 2]
	if LowPolyBuilder.face_normal(p0, p1, p2).y < 0.0:
		order = [0, 2, 1]
	var normal := LowPolyBuilder.face_normal(points[order[0]], points[order[1]], points[order[2]])
	for idx: int in order:
		st.set_normal(normal.lerp(Vector3.UP, 0.6).normalized())
		st.set_uv(uvs[idx])
		st.set_color(Color(float(lanes[idx]), 1.0, 1.0))
		st.add_vertex(points[idx])


static func _new_st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st
