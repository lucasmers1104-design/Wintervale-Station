@tool
## Wege, die dem Gelände folgen: Kiesweg, Steinweg und kleine Straße.
##
## Etappe 9 (überarbeitet): Das Aussehen kommt aus einem Wege-Shader
## (assets/materials/path.gdshader) mit Mustern in Weltkoordinaten – Kiesel,
## Natursteinpflaster, Fahrspuren. Dadurch gibt es zwischen Wegstücken, an
## Kurven und Kreuzungen keine Nähte mehr.
##
## Geometrie eines Wegstücks:
## - ein feines Band (alle 0,4 m, 10 Spalten), das dem Gelände folgt und nie
##   vom Boden durchstoßen wird (jede Ecke liegt über der höchsten Stelle ringsum),
## - ein Bankett links und rechts, das unter das Gelände abtaucht – der Weg
##   läuft weich in den Boden aus, statt mit einer Kante aufzuhören,
## - runde Knotenscheiben an den Enden (gleiches Muster → nahtlose Kurven und
##   Kreuzungen); breitere Wegarten liegen minimal höher und decken schmalere ab.
## Zweite Oberfläche (Vertexfarben, Welt-Shader): Randsteine beim Steinweg und ein
## flacher Wall aus geräumtem Schnee, der im Frühling wegtaut.
##
## UV.x = Abstand zur Wegmitte in Wegbreiten (1 = Rand), UV.y = Weg entlang.
## Koordinaten sind Weltkoordinaten (der Weg-Node liegt im Ursprung).
class_name PathMeshes
extends RefCounted

const STYLES := {
	"path_gravel": {"width": 1.6, "lift": 0.05, "border": false},
	"path_stone": {"width": 2.0, "lift": 0.062, "border": true},
	"path_road": {"width": 3.2, "lift": 0.074, "border": false},
}
const MATERIALS := {
	"path_gravel": preload("res://assets/materials/path_gravel.tres"),
	"path_stone": preload("res://assets/materials/path_stone.tres"),
	"path_road": preload("res://assets/materials/path_road.tres"),
}
## Breite des Banketts, das ins Gelände ausläuft.
const SHOULDER := 0.6
const STEP := 0.4
const COLUMNS := 10
const SNOW := Color(0.9, 0.93, 0.97, 0.5)
const SNOW_SHADE := Color(0.82, 0.86, 0.93, 0.5)
const EDGE_STONE := Color(0.6, 0.58, 0.56)
## Auf dieser Länge (m) laufen die Fahrspuren vor einer Knotenscheibe aus.
const LANE_FADE := 1.6


static func get_width(item_id: String) -> float:
	return float(STYLES.get(item_id, STYLES["path_gravel"])["width"])


## Material der Wegoberfläche (Oberfläche 0 des Meshes).
static func material(item_id: String) -> Material:
	return MATERIALS.get(item_id, MATERIALS["path_gravel"])


## Baut ein Wegstück von [param a] nach [param b]. [param height] liefert die
## Geländehöhe an (x, z). [param caps] = [Scheibe am Anfang, Scheibe am Ende].
## Rückgabe: Mesh mit Oberfläche 0 (Weg, [method material]) und 1 (Details, Vertexfarben).
static func build(item_id: String, a: Vector3, b: Vector3, height: Callable, caps := [true, true]) -> ArrayMesh:
	var style: Dictionary = STYLES.get(item_id, STYLES["path_gravel"])
	var width := float(style["width"])
	var lift := float(style["lift"])
	var half := width * 0.5
	var surface := _new_st()
	var details := _new_st()
	var flat_a := Vector3(a.x, 0, a.z)
	var flat_b := Vector3(b.x, 0, b.z)
	var length := flat_a.distance_to(flat_b)
	var mesh := ArrayMesh.new()
	if length < 0.05:
		return mesh
	var dir := (flat_b - flat_a) / length
	var side := dir.cross(Vector3.UP).normalized()
	# Band: beginnt und endet unter den Knotenscheiben
	var start := half * 0.7 if caps[0] else 0.0
	var stop := length - (half * 0.7 if caps[1] else 0.0)
	var steps := maxi(1, ceili((stop - start) / STEP))
	# Querschnitt: Bankett – Weg (COLUMNS Spalten) – Bankett
	var offsets: Array[float] = [-(half + SHOULDER), -(half + SHOULDER * 0.45)]
	for j in COLUMNS + 1:
		offsets.append(lerpf(-half, half, float(j) / COLUMNS))
	offsets.append_array([half + SHOULDER * 0.45, half + SHOULDER])
	var rows: Array[PackedVector3Array] = []
	for i in steps + 1:
		var d := lerpf(start, stop, float(i) / steps)
		var row := PackedVector3Array()
		for s in offsets:
			row.append(_vertex(flat_a + dir * d + side * s, s, half, lift, height, dir, side))
		rows.append(row)
	for i in steps:
		var d0 := lerpf(start, stop, float(i) / steps)
		var d1 := lerpf(start, stop, float(i + 1) / steps)
		var l0 := _lanes(d0, start, stop, caps)
		var l1 := _lanes(d1, start, stop, caps)
		for k in offsets.size() - 1:
			var u0 := offsets[k] / half
			var u1 := offsets[k + 1] / half
			_quad(surface, rows[i][k], rows[i][k + 1], rows[i + 1][k + 1], rows[i + 1][k],
				[Vector2(u0, d0), Vector2(u1, d0), Vector2(u1, d1), Vector2(u0, d1)], [l0, l0, l1, l1])
		_edge_details(details, item_id, style, flat_a + dir * d0, flat_a + dir * d1, dir, side, half, lift, height)
	for k in 2:
		if caps[k]:
			_disc(surface, flat_a if k == 0 else flat_b, half, lift + 0.003, height)
	surface.commit(mesh)
	details.commit(mesh)
	return mesh


## Fahrspuren (Straße) laufen zu den Knotenscheiben hin aus – die Scheiben haben
## keine, sonst entstünden dort Ringe. Rückgabe: Stärke der Spuren (Vertexfarbe R).
static func _lanes(d: float, start: float, stop: float, caps: Array) -> float:
	var fade := 1.0
	if caps[0]:
		fade = minf(fade, clampf((d - start) / LANE_FADE, 0.0, 1.0))
	if caps[1]:
		fade = minf(fade, clampf((stop - d) / LANE_FADE, 0.0, 1.0))
	return fade


## Eckpunkt des Bands: auf dem Weg über der höchsten Geländestelle ringsum,
## im Bankett sanft bis knapp unter das Gelände abfallend.
static func _vertex(p: Vector3, offset: float, half: float, lift: float, height: Callable, dir: Vector3,
		side: Vector3) -> Vector3:
	var over := absf(offset) - half
	var ground := height.call(p.x, p.z) as float
	if over <= 0.001:
		return Vector3(p.x, _max_ground(p, height, dir, side) + lift, p.z)
	var t := clampf(over / SHOULDER, 0.0, 1.0)
	var top := _max_ground(p, height, dir, side) + lift * 0.6
	return Vector3(p.x, lerpf(top, ground - 0.04, t), p.z)


## Höchste Geländehöhe in einem kleinen Kreuz um [param p] (verhindert, dass
## Geländekanten zwischen den Wegpunkten durch den Weg stoßen).
static func _max_ground(p: Vector3, height: Callable, dir: Vector3, side: Vector3) -> float:
	var best := height.call(p.x, p.z) as float
	for o: Vector3 in [dir * 0.3, -dir * 0.3, side * 0.3, -side * 0.3]:
		best = maxf(best, height.call(p.x + o.x, p.z + o.z) as float)
	return best


## Runde Knotenscheibe mit Bankett (UV.x = Abstand zur Mitte in Wegbreiten).
static func _disc(st: SurfaceTool, center: Vector3, half: float, lift: float, height: Callable) -> void:
	var segments := 20
	var radii: Array[float] = [0.0, half * 0.4, half * 0.8, half, half + SHOULDER * 0.45, half + SHOULDER]
	var rings: Array[PackedVector3Array] = []
	for r in radii:
		var ring := PackedVector3Array()
		for i in segments:
			var angle := TAU * i / segments
			var dir := Vector3(cos(angle), 0, sin(angle))
			var side := Vector3(-dir.z, 0, dir.x)
			ring.append(_vertex(center + dir * r, r, half, lift, height, dir, side))
		rings.append(ring)
	for ring in radii.size() - 1:
		for i in segments:
			var j := (i + 1) % segments
			var u0 := radii[ring] / half
			var u1 := radii[ring + 1] / half
			if ring == 0:
				_triangle(st, rings[0][i], rings[1][i], rings[1][j], [Vector2(0, 0), Vector2(u1, 0), Vector2(u1, 0)], [0.0, 0.0, 0.0])
			else:
				_quad(st, rings[ring][i], rings[ring + 1][i], rings[ring + 1][j], rings[ring][j],
					[Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 0), Vector2(u0, 0)], [0.0, 0.0, 0.0, 0.0])


## Randsteine (Steinweg) und flacher Wall aus geräumtem Schnee an beiden Rändern.
static func _edge_details(st: SurfaceTool, item_id: String, style: Dictionary, p0: Vector3, p1: Vector3, dir: Vector3,
		side: Vector3, half: float, lift: float, height: Callable) -> void:
	var seed_value := absf(sin(p0.x * 12.9898 + p0.z * 78.233) * 43758.5453)
	var jitter := fposmod(seed_value, 1.0)
	for sign_value: float in [-1.0, 1.0]:
		if bool(style["border"]):
			var mid := (p0 + p1) * 0.5 + side * sign_value * (half - 0.05)
			var h := _max_ground(mid, height, dir, side) + lift
			LowPolyBuilder.add_oriented_box(st, Transform3D(Basis.looking_at(dir, Vector3.UP), Vector3(mid.x, h + 0.015, mid.z)),
				Vector3(0.16, 0.08, p0.distance_to(p1) - 0.04), EDGE_STONE.lerp(EDGE_STONE.darkened(0.18), jitter))
		# Schneewall: weich gewölbt, etwas unregelmäßig hoch
		var inner0 := p0 + side * sign_value * (half + 0.05)
		var inner1 := p1 + side * sign_value * (half + 0.05)
		var crest0 := p0 + side * sign_value * (half + 0.22)
		var crest1 := p1 + side * sign_value * (half + 0.22)
		var outer0 := p0 + side * sign_value * (half + 0.5)
		var outer1 := p1 + side * sign_value * (half + 0.5)
		# Kammhöhe aus Weltkoordinaten: benachbarte Stücke treffen sich nahtlos
		var rise := 0.08 if item_id != "path_road" else 0.12
		var a0 := _on_ground(inner0, height, lift * 0.6)
		var a1 := _on_ground(inner1, height, lift * 0.6)
		var c0 := _on_ground(crest0, height, _bank_rise(crest0, rise))
		var c1 := _on_ground(crest1, height, _bank_rise(crest1, rise))
		var o0 := _on_ground(outer0, height, -0.03)
		var o1 := _on_ground(outer1, height, -0.03)
		LowPolyBuilder.add_quad_facing(st, a0, a1, c1, c0, SNOW_SHADE, Vector3.UP)
		LowPolyBuilder.add_quad_facing(st, c0, c1, o1, o0, SNOW, Vector3.UP)


## Sanft wellige Höhe des Schneewalls an einer Stelle der Welt.
static func _bank_rise(p: Vector3, rise: float) -> float:
	return rise * (0.8 + 0.25 * sin(p.x * 1.3 + p.z * 0.7) * cos(p.z * 1.1 - p.x * 0.4))


static func _on_ground(p: Vector3, height: Callable, lift: float) -> Vector3:
	return Vector3(p.x, (height.call(p.x, p.z) as float) + lift, p.z)


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
