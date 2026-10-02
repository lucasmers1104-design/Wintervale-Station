## Baukasten für die Figuren-Meshes.
##
## Sammelt alle Teile, die an einem Gelenk hängen (Kopf, Rumpf, Arm …), in einem
## einzigen Mesh. Farbe und Muster jedes Teils stehen in den Vertexdaten und werden
## vom gemeinsamen Shader assets/materials/character.gdshader ausgewertet:
##   COLOR = Grundfarbe, CUSTOM0/1 = zweite/dritte Farbe, UV2 = (Muster, Maßstab).
## Teile sind facettiert (Low-Poly, flache Dreiecke – wie Stoff und Haare in den
## Vorlagen) oder glatt (Haut).
class_name CharacterKit
extends RefCounted

## Muster (müssen zu den Konstanten im Shader passen).
enum Pattern { SOLID, PLAID, GINGHAM, STRIPES, RIBS, FAIR_ISLE, DIAMONDS, FACE, SKIN, QUILT, KNIT_CUFF, GLOSS, TARTAN }

## Farbe und Muster eines Teils.
class Paint:
	var color := Color.WHITE
	var color2 := Color(0, 0, 0, 0)
	var color3 := Color(0, 0, 0, 0)
	var pattern := Pattern.SOLID
	var scale := 1.0

	func _init(c: Color = Color.WHITE, p: Pattern = Pattern.SOLID, s := 1.0, c2 := Color(0, 0, 0, 0), c3 := Color(0, 0, 0, 0)) -> void:
		color = c
		pattern = p
		scale = s
		color2 = c2
		color3 = c3


var _st := SurfaceTool.new()
var _count := 0


func _init() -> void:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	_st.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)


func is_empty() -> bool:
	return _count == 0


func commit() -> ArrayMesh:
	if _count == 0:
		return null
	return _st.commit()


static func paint(c: Color, p: Pattern = Pattern.SOLID, s := 1.0, c2 := Color(0, 0, 0, 0), c3 := Color(0, 0, 0, 0)) -> Paint:
	return Paint.new(c, p, s, c2, c3)


# --- Grundlage ---------------------------------------------------------------------------

func _vertex(p: Vector3, n: Vector3, uv: Vector2, pt: Paint) -> void:
	_st.set_color(pt.color)
	_st.set_custom(0, pt.color2)
	_st.set_custom(1, pt.color3)
	_st.set_uv(uv)
	_st.set_uv2(Vector2(float(pt.pattern), pt.scale))
	_st.set_normal(n)
	_st.add_vertex(p)
	_count += 1


## Dreieck. Mit Normalen [param na]..[param nc] wird es glatt schattiert, sonst flach
## (facettiert). [param outward] zeigt grob nach außen: Danach wird die Eckreihenfolge
## so gewählt, dass die Vorderseite außen liegt (Godot: im Uhrzeigersinn).
func triangle(a: Vector3, b: Vector3, c: Vector3, pt: Paint, uva := Vector2.ZERO, uvb := Vector2.ZERO, uvc := Vector2.ZERO,
		na := Vector3.ZERO, nb := Vector3.ZERO, nc := Vector3.ZERO, outward := Vector3.ZERO) -> void:
	var n := (c - a).cross(b - a)
	if n.length_squared() < 1e-14:
		return
	n = n.normalized()
	var hint := outward if outward != Vector3.ZERO else na + nb + nc
	if hint != Vector3.ZERO and n.dot(hint) < 0.0:
		# Umdrehen: b und c tauschen
		var t := b
		b = c
		c = t
		var tuv := uvb
		uvb = uvc
		uvc = tuv
		var tn := nb
		nb = nc
		nc = tn
		n = -n
	if na == Vector3.ZERO:
		na = n
		nb = n
		nc = n
	_vertex(a, na, uva, pt)
	_vertex(b, nb, uvb, pt)
	_vertex(c, nc, uvc, pt)


## Viereck a-b-c-d (Reihenfolge rundherum). [param outward] wie bei [method triangle].
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, pt: Paint, uv := Rect2(0, 0, 1, 1), outward := Vector3.ZERO) -> void:
	if outward == Vector3.ZERO:
		outward = (c - a).cross(b - a)
	triangle(a, b, c, pt, uv.position, Vector2(uv.end.x, uv.position.y), uv.end,
		Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, outward)
	triangle(a, c, d, pt, uv.position, uv.end, Vector2(uv.position.x, uv.end.y),
		Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, outward)


## Dreieck, das von [param inside] weg nach außen zeigt (für geschlossene Körper).
func _tri_away(a: Vector3, b: Vector3, c: Vector3, pt: Paint, inside: Vector3) -> void:
	triangle(a, b, c, pt, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO,
		(a + b + c) / 3.0 - inside)


# --- Drehkörper ----------------------------------------------------------------------------

## Drehkörper um die Y-Achse. [param profile] = Punkte (Radius, Höhe) von unten nach oben.
## Querschnitt elliptisch: Breite × [param sx], Tiefe × [param sz]. Winkel 0 = vorne (−Z),
## [param a0]..[param a1] begrenzt ihn auf einen Ausschnitt (Bruchteile von 0..1).
## [param offset] schiebt die Fläche nach außen (für Kleidung auf dem Körper).
func lathe(xf: Transform3D, profile: Array, segments: int, pt: Paint, flat := true, sx := 1.0, sz := 1.0,
		a0 := 0.0, a1 := 1.0, offset := 0.0, cap_bottom := false, cap_top := false) -> void:
	var normal_basis := xf.basis.inverse().transposed()
	var rings: Array = []
	var normals: Array = []
	var full := is_equal_approx(a1 - a0, 1.0)
	var steps := segments if not full else segments
	for i in profile.size():
		var p: Vector2 = profile[i]
		var row := PackedVector3Array()
		var nrow := PackedVector3Array()
		# Profilsteigung für glatte Normalen
		var prev: Vector2 = profile[maxi(i - 1, 0)]
		var next: Vector2 = profile[mini(i + 1, profile.size() - 1)]
		var tangent := Vector2(next.x - prev.x, next.y - prev.y)
		for s in steps + (0 if full else 1):
			var t := a0 + (a1 - a0) * float(s) / float(steps)
			var angle := t * TAU
			var dir := Vector3(sin(angle) * sx, 0.0, -cos(angle) * sz)
			var r := p.x + offset
			row.append(xf * Vector3(dir.x * r, p.y, dir.z * r))
			var radial := Vector3(sin(angle) / sx, 0.0, -cos(angle) / sz).normalized()
			var n := (radial * tangent.y - Vector3.UP * tangent.x).normalized()
			if n == Vector3.ZERO:
				n = Vector3.UP if i == profile.size() - 1 else Vector3.DOWN
			nrow.append((normal_basis * n).normalized())
		rings.append(row)
		normals.append(nrow)
	var count: int = rings[0].size()
	for i in profile.size() - 1:
		var lower: PackedVector3Array = rings[i]
		var upper: PackedVector3Array = rings[i + 1]
		var v0: float = profile[i].y
		var v1: float = profile[i + 1].y
		for s in (count if full else count - 1):
			var s1 := (s + 1) % count
			var u0 := a0 + (a1 - a0) * float(s) / float(steps)
			var u1 := a0 + (a1 - a0) * float(s + 1) / float(steps)
			var uv00 := Vector2(u0, v0)
			var uv10 := Vector2(u1, v0)
			var uv01 := Vector2(u0, v1)
			var uv11 := Vector2(u1, v1)
			var nl: PackedVector3Array = normals[i]
			var nu: PackedVector3Array = normals[i + 1]
			if flat:
				var out := nl[s] + nu[s] + nl[s1] + nu[s1]
				if (upper[s] - upper[s1]).length() > 0.0001:
					triangle(lower[s], upper[s], upper[s1], pt, uv00, uv01, uv11, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, out)
				if (lower[s] - lower[s1]).length() > 0.0001:
					triangle(lower[s], upper[s1], lower[s1], pt, uv00, uv11, uv10, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, out)
			else:
				if (upper[s] - upper[s1]).length() > 0.0001:
					triangle(lower[s], upper[s], upper[s1], pt, uv00, uv01, uv11, nl[s], nu[s], nu[s1])
				if (lower[s] - lower[s1]).length() > 0.0001:
					triangle(lower[s], upper[s1], lower[s1], pt, uv00, uv11, uv10, nl[s], nu[s1], nl[s1])
	if full and cap_bottom:
		_cap(rings[0], xf * Vector3(0, profile[0].y, 0), pt, xf.basis * Vector3.DOWN)
	if full and cap_top:
		_cap(rings[-1], xf * Vector3(0, profile[-1].y, 0), pt, xf.basis * Vector3.UP)


func _cap(row: PackedVector3Array, center: Vector3, pt: Paint, facing: Vector3) -> void:
	for s in row.size():
		var a := row[s]
		var b := row[(s + 1) % row.size()]
		triangle(center, a, b, pt, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO,
			facing)


## Anliegendes Stoffteil mit Materialstärke: Außenfläche eines Drehkörper-Ausschnitts
## plus schmale Kanten ringsum (so sieht man Latz, Taschen, Schürze als eigenes Teil).
func panel(xf: Transform3D, profile: Array, segments: int, pt: Paint, sx: float, sz: float, a0: float, a1: float,
		offset: float, thickness := 0.012, edge_paint: Paint = null) -> void:
	lathe(xf, profile, segments, pt, true, sx, sz, a0, a1, offset + thickness)
	var edge := edge_paint if edge_paint else pt
	# Kanten: links, rechts, unten, oben
	for side: float in [a0, a1]:
		var inner: Array = []
		var outer: Array = []
		for p: Vector2 in profile:
			var angle := side * TAU
			var dir := Vector3(sin(angle) * sx, 0.0, -cos(angle) * sz)
			inner.append(xf * Vector3(dir.x * (p.x + offset), p.y, dir.z * (p.x + offset)))
			outer.append(xf * Vector3(dir.x * (p.x + offset + thickness), p.y, dir.z * (p.x + offset + thickness)))
		for i in profile.size() - 1:
			# Kante zeigt quer zur Fläche, weg vom Paneel
			var tangent := xf.basis * Vector3(cos(side * TAU) * sx, 0.0, sin(side * TAU) * sz)
			quad(inner[i + 1], outer[i + 1], outer[i], inner[i], edge, Rect2(0, 0, 1, 1), -tangent if side == a0 else tangent)
	for k: int in [0, profile.size() - 1]:
		var p: Vector2 = profile[k]
		var steps := maxi(2, segments)
		for s in steps:
			var t0 := a0 + (a1 - a0) * float(s) / steps
			var t1 := a0 + (a1 - a0) * float(s + 1) / steps
			var pts: Array = []
			for t: float in [t0, t1]:
				var dir := Vector3(sin(t * TAU) * sx, 0.0, -cos(t * TAU) * sz)
				pts.append(xf * Vector3(dir.x * (p.x + offset), p.y, dir.z * (p.x + offset)))
				pts.append(xf * Vector3(dir.x * (p.x + offset + thickness), p.y, dir.z * (p.x + offset + thickness)))
			quad(pts[0], pts[2], pts[3], pts[1], edge, Rect2(0, 0, 1, 1), xf.basis * (Vector3.DOWN if k == 0 else Vector3.UP))


# --- Körper ------------------------------------------------------------------------------

## Ellipsoid. [param flat] = facettiert. UV: u rundherum, v von unten nach oben (0..1).
func ellipsoid(xf: Transform3D, radii: Vector3, segments: int, rings: int, pt: Paint, flat := true,
		v_from := 0.0, v_to := 1.0) -> void:
	var profile: Array = []
	for r in rings + 1:
		var v := lerpf(v_from, v_to, float(r) / rings)
		# v = 0 unten, 1 oben (Profil von unten nach oben wie bei lathe)
		profile.append(Vector2(sin(PI * v), -cos(PI * v)))
	var scaled := Transform3D(xf.basis * Basis.from_scale(Vector3(radii.x, radii.y, radii.z)), xf.origin)
	lathe(scaled, profile, segments, pt, flat)


## Kopfform: weich abgerundeter Würfel (Superellipsoid), glatt schattiert. UV = (x, y) der
## Einheitsform – dort zeichnet der Shader das Gesicht.
func head_shape(xf: Transform3D, radii: Vector3, segments: int, rings: int, pt: Paint, power := 2.6) -> void:
	var grid: Array = []
	var normals: Array = []
	for r in rings + 1:
		var phi := PI * float(r) / rings  # 0 oben
		var row := PackedVector3Array()
		var nrow := PackedVector3Array()
		for s in segments + 1:
			var theta := TAU * float(s) / segments
			var cp := cos(phi)
			var sp := sin(phi)
			var ct := cos(theta)
			var st := sin(theta)
			var e := 2.0 / power
			var x := _spow(sp, e) * _spow(st, e)
			var y := _spow(cp, 1.0)
			var z := -_spow(sp, e) * _spow(ct, e)
			var p := Vector3(x, y, z)
			row.append(p)
			nrow.append(Vector3(x / (radii.x * radii.x), y / (radii.y * radii.y), z / (radii.z * radii.z)))
		grid.append(row)
		normals.append(nrow)
	for r in rings:
		for s in segments:
			var pts := [grid[r][s], grid[r][s + 1], grid[r + 1][s + 1], grid[r + 1][s]]
			var ns := [normals[r][s], normals[r][s + 1], normals[r + 1][s + 1], normals[r + 1][s]]
			var world: Array = []
			var wn: Array = []
			var uvs: Array = []
			for k in 4:
				var p: Vector3 = pts[k]
				world.append(xf * Vector3(p.x * radii.x, p.y * radii.y, p.z * radii.z))
				var n: Vector3 = ns[k]
				wn.append((xf.basis * (n if n.length() > 0.0001 else p)).normalized())
				# Gesicht nur vorne: hintere Punkte bekommen Koordinaten weit außerhalb
				uvs.append(Vector2(p.x + (10.0 if p.z > 0.05 else 0.0), p.y))
			triangle(world[0], world[1], world[2], pt, uvs[0], uvs[1], uvs[2], wn[0], wn[1], wn[2])
			triangle(world[0], world[2], world[3], pt, uvs[0], uvs[2], uvs[3], wn[0], wn[2], wn[3])


static func _spow(v: float, e: float) -> float:
	return signf(v) * pow(absf(v), e)


## Ring (Bündchen, Kragen, Hutband): Querschnitt rund, facettiert.
func torus(xf: Transform3D, radius: float, tube: float, segments: int, sides: int, pt: Paint, sx := 1.0, sz := 1.0,
		tube_y := 1.0) -> void:
	var rows: Array = []
	for s in segments + 1:
		var a := TAU * float(s) / segments
		var row := PackedVector3Array()
		for k in sides + 1:
			var b := TAU * float(k) / sides
			var r := radius + cos(b) * tube
			row.append(xf * Vector3(sin(a) * r * sx, sin(b) * tube * tube_y, -cos(a) * r * sz))
		rows.append(row)
	for s in segments:
		for k in sides:
			var u0 := float(s) / segments
			var u1 := float(s + 1) / segments
			var a := TAU * (float(s) + 0.5) / segments
			var core := xf * Vector3(sin(a) * radius * sx, 0.0, -cos(a) * radius * sz)
			var centre: Vector3 = (rows[s][k] + rows[s + 1][k + 1]) * 0.5
			quad(rows[s][k + 1], rows[s + 1][k + 1], rows[s + 1][k], rows[s][k], pt, Rect2(u0, 0, u1 - u0, 1), centre - core)


## Kasten (Gürtelschnallen, Taschen, Schilder …), facettiert.
func box(xf: Transform3D, size: Vector3, pt: Paint) -> void:
	var h := size * 0.5
	var c := [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]
	for i in 8:
		c[i] = xf * c[i]
	var mid := xf.origin
	for face: Array in [[3, 2, 1, 0], [6, 7, 4, 5], [7, 3, 0, 4], [2, 6, 5, 1], [7, 6, 2, 3], [0, 1, 5, 4]]:
		var centre: Vector3 = (c[face[0]] + c[face[1]] + c[face[2]] + c[face[3]]) * 0.25
		quad(c[face[0]], c[face[1]], c[face[2]], c[face[3]], pt, Rect2(0, 0, 1, 1), centre - mid)


## Spitze Pyramide (Nase, Haarspitzen …): Grundfläche mit [param sides] Ecken, Spitze nach −Z.
func pyramid(xf: Transform3D, radius: float, length: float, sides: int, pt: Paint, roll := 0.0) -> void:
	var tip := xf * Vector3(0, 0, -length)
	var base: Array = []
	for i in sides:
		var a := TAU * float(i) / sides + roll
		base.append(xf * Vector3(sin(a) * radius, cos(a) * radius, 0.0))
	var inside := xf * Vector3(0, 0, -length * 0.25)
	for i in sides:
		_tri_away(base[i], base[(i + 1) % sides], tip, pt, inside)
	for i in range(1, sides - 1):
		_tri_away(base[0], base[i + 1], base[i], pt, inside)


## Haarbüschel: lang gezogener, facettierter Doppelkegel ("Blatt").
## Liegt entlang −Y (Spitze unten), [param width] quer (X), [param depth] dick (Z).
func chunk(xf: Transform3D, width: float, depth: float, length: float, pt: Paint, sides := 5, top := 0.35) -> void:
	var tip := xf * Vector3(0, -length * (1.0 - top), 0)
	var root := xf * Vector3(0, length * top, 0)
	var ring: Array = []
	for i in sides:
		var a := TAU * float(i) / sides
		ring.append(xf * Vector3(sin(a) * width * 0.5, 0.0, -cos(a) * depth * 0.5))
	for i in sides:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % sides]
		_tri_away(a, b, tip, pt, xf.origin)
		_tri_away(b, a, root, pt, xf.origin)


## Haarschuppe: facettierter Tropfen, der flach auf einer Fläche liegt (Tannenzapfen-Haar).
## Spitze zeigt entlang −Y, flach entlang Z (Normalenrichtung der Fläche, [param thickness]).
func scale_tuft(xf: Transform3D, width: float, length: float, thickness: float, pt: Paint, sides := 6) -> void:
	var profile := [Vector2(0.0, -length * 0.62), Vector2(width * 0.26, -length * 0.42), Vector2(width * 0.47, -length * 0.14),
		Vector2(width * 0.5, length * 0.06), Vector2(width * 0.4, length * 0.26), Vector2(0.0, length * 0.38)]
	lathe(xf, profile, sides, pt, true, 1.0, thickness / width)


## Flacher Strang entlang eines Pfades (Träger, Riemen, Schalenden, Gurte).
## [param outward] gibt die Richtung "von der Oberfläche weg" je Punkt an.
func strip(points: Array, outward: Array, width: float, thickness: float, pt: Paint, edge: Paint = null) -> void:
	var e := edge if edge else pt
	var count := points.size()
	var left: Array = []
	var right: Array = []
	var left_o: Array = []
	var right_o: Array = []
	for i in count:
		var p: Vector3 = points[i]
		var forward: Vector3 = (points[mini(i + 1, count - 1)] - points[maxi(i - 1, 0)]).normalized()
		var out: Vector3 = (outward[i] as Vector3).normalized()
		var side := forward.cross(out).normalized() * width * 0.5
		left.append(p - side)
		right.append(p + side)
		left_o.append(p - side + out * thickness)
		right_o.append(p + side + out * thickness)
	for i in count - 1:
		var v0 := float(i) / (count - 1)
		var v1 := float(i + 1) / (count - 1)
		var out: Vector3 = outward[i]
		var across: Vector3 = right[i] - left[i]
		quad(left_o[i], right_o[i], right_o[i + 1], left_o[i + 1], pt, Rect2(0, v0, 1, v1 - v0), out)
		quad(left[i], left_o[i], left_o[i + 1], left[i + 1], e, Rect2(0, 0, 1, 1), -across)
		quad(right_o[i], right[i], right[i + 1], right_o[i + 1], e, Rect2(0, 0, 1, 1), across)


## Runder Strang entlang eines Pfades (Brillenbügel, Schnürsenkel, Henkel …).
func tube(points: Array, radius: float, sides: int, pt: Paint) -> void:
	var rings: Array = []
	for i in points.size():
		var p: Vector3 = points[i]
		var forward: Vector3 = (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		var a := forward.cross(up).normalized()
		var b := forward.cross(a).normalized()
		var row := PackedVector3Array()
		for k in sides:
			var t := TAU * float(k) / sides
			row.append(p + (a * cos(t) + b * sin(t)) * radius)
		rings.append(row)
	for i in rings.size() - 1:
		for k in sides:
			var k1 := (k + 1) % sides
			quad(rings[i][k], rings[i][k1], rings[i + 1][k1], rings[i + 1][k], pt, Rect2(0, 0, 1, 1),
				(rings[i][k] + rings[i + 1][k1]) * 0.5 - (points[i] + points[i + 1]) * 0.5)
