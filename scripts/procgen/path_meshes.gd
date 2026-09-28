@tool
## Wege, die dem Gelände folgen: Kiesweg, Steinweg und kleine Straße.
##
## Ein Wegstück ist ein Band zwischen zwei Knoten, an beiden Enden liegt eine
## runde Knotenscheibe. Die Bänder enden unter den Scheiben – so verbinden sich
## Wegstücke in jedem Winkel sauber, ohne Lücken oder Überlappungsflackern.
## Breitere Wegarten liegen minimal höher und decken schmalere an Kreuzungen ab.
## An den Rändern liegt ein kleiner Wall aus geräumtem Schnee.
##
## Koordinaten sind Weltkoordinaten (der Weg-Node liegt im Ursprung).
class_name PathMeshes
extends RefCounted

const STYLES := {
	"path_gravel": {"width": 1.6, "lift": 0.06, "base": Color(0.66, 0.6, 0.52), "alt": Color(0.58, 0.53, 0.46), "border": false},
	"path_stone": {"width": 2.0, "lift": 0.075, "base": Color(0.6, 0.57, 0.55), "alt": Color(0.5, 0.48, 0.47), "border": true},
	"path_road": {"width": 3.2, "lift": 0.09, "base": Color(0.55, 0.5, 0.46), "alt": Color(0.47, 0.43, 0.4), "border": false},
}
const SNOW := Color(0.92, 0.94, 0.98)
const SNOW_SHADE := Color(0.84, 0.87, 0.93)
const EDGE_STONE := Color(0.62, 0.6, 0.58)


static func get_width(item_id: String) -> float:
	return float(STYLES.get(item_id, STYLES["path_gravel"])["width"])


## Baut ein Wegstück von [param a] nach [param b]. [param height] liefert die
## Geländehöhe an (x, z). [param caps] = [Scheibe am Anfang, Scheibe am Ende].
static func build(item_id: String, a: Vector3, b: Vector3, height: Callable, caps := [true, true]) -> ArrayMesh:
	var style: Dictionary = STYLES.get(item_id, STYLES["path_gravel"])
	var width := float(style["width"])
	var lift := float(style["lift"])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var flat_a := Vector3(a.x, 0, a.z)
	var flat_b := Vector3(b.x, 0, b.z)
	var length := flat_a.distance_to(flat_b)
	if length < 0.05:
		return st.commit()
	var dir := (flat_b - flat_a) / length
	var side := dir.cross(Vector3.UP).normalized()
	var half := width * 0.5
	# Band: beginnt und endet unter den Knotenscheiben
	var start := half * 0.8 if caps[0] else 0.0
	var stop := length - (half * 0.8 if caps[1] else 0.0)
	var steps := maxi(1, ceili((stop - start) / 0.8))
	var across := 4 if item_id == "path_road" else 3
	for i in steps:
		var d0 := lerpf(start, stop, float(i) / steps)
		var d1 := lerpf(start, stop, float(i + 1) / steps)
		for j in across:
			var s0 := lerpf(-half, half, float(j) / across)
			var s1 := lerpf(-half, half, float(j + 1) / across)
			var p00 := _ground(flat_a + dir * d0 + side * s0, height, lift)
			var p01 := _ground(flat_a + dir * d0 + side * s1, height, lift)
			var p10 := _ground(flat_a + dir * d1 + side * s0, height, lift)
			var p11 := _ground(flat_a + dir * d1 + side * s1, height, lift)
			var color := _surface_color(item_id, style, p00, j, across)
			LowPolyBuilder.add_quad_facing(st, p00, p01, p11, p10, color, Vector3.UP)
		# Geräumter Schnee an beiden Rändern, bei Steinwegen zusätzlich Randsteine
		for sign_value: float in [-1.0, 1.0]:
			var e0 := flat_a + dir * d0 + side * sign_value * half
			var e1 := flat_a + dir * d1 + side * sign_value * half
			var o0 := e0 + side * sign_value * 0.35
			var o1 := e1 + side * sign_value * 0.35
			var inner0 := _ground(e0, height, lift + 0.02)
			var inner1 := _ground(e1, height, lift + 0.02)
			var crest0 := _ground(e0 + side * sign_value * 0.15, height, lift + 0.12)
			var crest1 := _ground(e1 + side * sign_value * 0.15, height, lift + 0.12)
			var outer0 := _ground(o0, height, -0.02)
			var outer1 := _ground(o1, height, -0.02)
			var up := Vector3.UP
			LowPolyBuilder.add_quad_facing(st, inner0, inner1, crest1, crest0, SNOW_SHADE, up)
			LowPolyBuilder.add_quad_facing(st, crest0, crest1, outer1, outer0, SNOW, up)
			if bool(style["border"]):
				var mid := (e0 + e1) * 0.5
				var h := height.call(mid.x, mid.z) as float
				LowPolyBuilder.add_oriented_box(st, Transform3D(Basis.looking_at(dir, Vector3.UP), Vector3(mid.x, h + lift + 0.02, mid.z)),
					Vector3(0.14, 0.1, d1 - d0 - 0.05), EDGE_STONE.lerp(EDGE_STONE.darkened(0.15), fposmod(mid.x * 3.1 + mid.z * 1.7, 1.0)))
	# Knotenscheiben (rund) an den Enden
	for k in 2:
		if caps[k]:
			_disc(st, flat_a if k == 0 else flat_b, half, height, lift + 0.004, style, item_id)
	return st.commit()


static func _disc(st: SurfaceTool, center: Vector3, radius: float, height: Callable, lift: float, style: Dictionary,
		item_id: String) -> void:
	var segments := 14
	var c := _ground(center, height, lift)
	for ring in 2:
		var r0 := radius * ring * 0.5
		var r1 := radius * (ring + 1) * 0.5
		for i in segments:
			var a0 := TAU * i / segments
			var a1 := TAU * (i + 1) / segments
			var p0 := _ground(center + Vector3(cos(a0), 0, sin(a0)) * r1, height, lift)
			var p1 := _ground(center + Vector3(cos(a1), 0, sin(a1)) * r1, height, lift)
			var color := _surface_color(item_id, style, p0, ring + i, 5)
			if ring == 0:
				LowPolyBuilder.add_triangle_facing(st, c, p0, p1, color, Vector3.UP)
			else:
				var q0 := _ground(center + Vector3(cos(a0), 0, sin(a0)) * r0, height, lift)
				var q1 := _ground(center + Vector3(cos(a1), 0, sin(a1)) * r0, height, lift)
				LowPolyBuilder.add_quad_facing(st, q0, p0, p1, q1, color, Vector3.UP)
	# Schneekranz um die Scheibe
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var i0 := _ground(center + Vector3(cos(a0), 0, sin(a0)) * radius, height, lift - 0.004)
		var i1 := _ground(center + Vector3(cos(a1), 0, sin(a1)) * radius, height, lift - 0.004)
		var o0 := _ground(center + Vector3(cos(a0), 0, sin(a0)) * (radius + 0.3), height, -0.02)
		var o1 := _ground(center + Vector3(cos(a1), 0, sin(a1)) * (radius + 0.3), height, -0.02)
		LowPolyBuilder.add_quad_facing(st, i0, i1, o1, o0, SNOW_SHADE, Vector3.UP)


## Oberfläche: Kies gesprenkelt, Pflaster im Muster, Straße mit dunkleren Fahrspuren.
static func _surface_color(item_id: String, style: Dictionary, p: Vector3, column: int, columns: int) -> Color:
	var base: Color = style["base"]
	var alt: Color = style["alt"]
	var hash_value := fposmod(sin(floorf(p.x * 1.7) * 12.9898 + floorf(p.z * 1.7) * 78.233) * 43758.5453, 1.0)
	match item_id:
		"path_stone":
			var checker := (int(floorf(p.x * 1.25)) + int(floorf(p.z * 1.25))) % 2 == 0
			return (base if checker else alt).lerp(base.lightened(0.08), hash_value * 0.5)
		"path_road":
			if column == 0 or column == columns - 1:
				return SNOW_SHADE.lerp(base, 0.35 + hash_value * 0.2)  # festgefahrener Schnee am Rand
			return alt.lerp(base, hash_value * 0.5)
	return base.lerp(alt, hash_value * 0.8)


static func _ground(p: Vector3, height: Callable, lift: float) -> Vector3:
	return Vector3(p.x, (height.call(p.x, p.z) as float) + lift, p.z)
