@tool
## Modelle der Baustelle: Bauzaun-Elemente mit Betonfüßen, Gerüst (je Etage
## ein Mesh, damit es mit dem Haus wachsen kann), Materialstapel, kleiner
## Baukran und Baustellenschild. Gemütlich statt grell: Holz, warmes Gelb,
## rotweiße Latten, viel Schnee.
class_name ConstructionMeshes
extends RefCounted

const WOOD := Color(0.62, 0.46, 0.3)
const WOOD_DARK := Color(0.4, 0.28, 0.18)
const PLANK := Color(0.72, 0.56, 0.36)
const IRON := Color(0.3, 0.31, 0.33)
const STEEL := Color(0.62, 0.64, 0.66)
const RED := Color(0.78, 0.2, 0.16)
const WHITE := Color(0.94, 0.92, 0.88)
const YELLOW := Color(0.95, 0.72, 0.2)
const CONCRETE := Color(0.66, 0.65, 0.62)
const SNOW := Color(0.92, 0.94, 0.98, 0.5)
const GLASS := Color(0.62, 0.8, 0.88)
## Höhe einer Gerüstetage.
const SCAFFOLD_LEVEL := 1.9

static var _cache := {}


static func clear_cache() -> void:
	_cache.clear()


static func _new_st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## Ein Bauzaun-Element (Länge [param length] entlang X): Rohrrahmen mit Gitter,
## zwei Betonfüße, rotweiße Warnlatte und Schnee auf dem Rahmen.
static func fence_panel(length: float) -> ArrayMesh:
	var key := "fence|%.2f" % length
	if _cache.has(key):
		return _cache[key]
	var st := _new_st()
	var height := 1.8
	var half := length * 0.5
	for x: float in [-half + 0.1, half - 0.1]:
		LowPolyBuilder.add_box(st, Vector3(x, 0.1, 0), Vector3(0.24, 0.2, 0.6), CONCRETE)
		LowPolyBuilder.add_box(st, Vector3(x, 0.21, 0), Vector3(0.2, 0.03, 0.5), SNOW)
		LowPolyBuilder.add_box(st, Vector3(x, 0.2 + height * 0.5, 0), Vector3(0.05, height, 0.05), STEEL)
	for y: float in [0.25, 0.2 + height]:
		LowPolyBuilder.add_box(st, Vector3(0, y, 0), Vector3(length - 0.2, 0.05, 0.05), STEEL)
	# Gitter (dünne Stäbe)
	var x := -half + 0.35
	while x < half - 0.2:
		LowPolyBuilder.add_box(st, Vector3(x, 0.2 + height * 0.5, 0), Vector3(0.012, height - 0.05, 0.012), STEEL.darkened(0.2))
		x += 0.22
	var y := 0.55
	while y < height:
		LowPolyBuilder.add_box(st, Vector3(0, y, 0), Vector3(length - 0.25, 0.012, 0.012), STEEL.darkened(0.2))
		y += 0.3
	# Warnlatte, abwechselnd rot und weiß
	var stripes := int(length / 0.35)
	for i in stripes:
		var sx := -half + 0.2 + (i + 0.5) * (length - 0.4) / stripes
		LowPolyBuilder.add_box(st, Vector3(sx, 1.05, 0.05), Vector3((length - 0.4) / stripes, 0.14, 0.03), RED if i % 2 == 0 else WHITE)
	LowPolyBuilder.add_box(st, Vector3(0, 2.03, 0), Vector3(length - 0.25, 0.05, 0.1), SNOW)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## Eine Gerüstetage rund um ein Rechteck (lokale Mitte 0, Größe [param size]):
## Rohre an den Ecken und alle ~2,5 m, Bohlenbelag, Geländer, Diagonalen, Schnee.
## Die Etage beginnt bei y = 0 und ist [constant SCAFFOLD_LEVEL] hoch.
static func scaffold_level(size: Vector2, top: bool) -> ArrayMesh:
	var key := "scaffold|%s|%s" % [size, top]
	if _cache.has(key):
		return _cache[key]
	var st := _new_st()
	var h := SCAFFOLD_LEVEL
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var depth := 0.8
	# Rohre (innen und außen) entlang aller vier Seiten
	var edges := [[Vector2(-hx, -hz), Vector2(hx, -hz)], [Vector2(hx, -hz), Vector2(hx, hz)],
		[Vector2(hx, hz), Vector2(-hx, hz)], [Vector2(-hx, hz), Vector2(-hx, -hz)]]
	for edge: Array in edges:
		var a: Vector2 = edge[0]
		var b: Vector2 = edge[1]
		var along := (b - a)
		var length := along.length()
		var dir := along / length
		var out := Vector2(dir.y, -dir.x)
		var posts := maxi(2, ceili(length / 2.5) + 1)
		for i in posts:
			var p := a + dir * (length * i / (posts - 1))
			for off: float in [0.0, depth]:
				var q := p + out * off
				LowPolyBuilder.add_box(st, Vector3(q.x, h * 0.5, q.y), Vector3(0.06, h, 0.06), STEEL)
		# Bohlen
		var mid := (a + b) * 0.5 + out * depth * 0.5
		var plank_basis := Basis(Vector3.UP, atan2(-dir.y, dir.x))
		LowPolyBuilder.add_oriented_box(st, Transform3D(plank_basis, Vector3(mid.x, h - 0.04, mid.y)), Vector3(length + depth, 0.05, depth), PLANK)
		LowPolyBuilder.add_oriented_box(st, Transform3D(plank_basis, Vector3(mid.x, h + 0.005, mid.y)), Vector3(length + depth - 0.2, 0.02, depth * 0.7), SNOW)
		# Geländer außen und Diagonale
		var rail := (a + b) * 0.5 + out * depth
		LowPolyBuilder.add_oriented_box(st, Transform3D(plank_basis, Vector3(rail.x, h * 0.55, rail.y)), Vector3(length, 0.05, 0.05), YELLOW)
		var d0 := a + out * depth
		var d1 := b + out * depth
		LowPolyBuilder.add_beam(st, Vector3(d0.x, 0.1, d0.y), Vector3(d1.x, h - 0.1, d1.y), 0.04, STEEL.darkened(0.15))
		if top:
			LowPolyBuilder.add_oriented_box(st, Transform3D(plank_basis, Vector3(rail.x, h + 1.0, rail.y)), Vector3(length, 0.05, 0.05), YELLOW)
			for i in posts:
				var p := a + dir * (length * i / (posts - 1)) + out * depth
				LowPolyBuilder.add_box(st, Vector3(p.x, h + 0.55, p.y), Vector3(0.05, 1.1, 0.05), STEEL)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## Materialstapel der Baustelle (Einheitsgröße, wird mit dem Rest verkleinert).
## [param goods_id]: wood (Bretterstapel), brick (Ziegelpalette), glass (Kiste
## mit Scheiben), steel (Träger), stone (Steinhaufen).
static func stack(goods_id: String) -> ArrayMesh:
	var key := "stack|%s" % goods_id
	if _cache.has(key):
		return _cache[key]
	var st := _new_st()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	match goods_id:
		"wood":
			for layer in 6:
				for i in 5:
					var color := PLANK.lerp(WOOD, rng.randf())
					LowPolyBuilder.add_box(st, Vector3(-0.44 + i * 0.22, 0.14 + layer * 0.1, 0), Vector3(0.2, 0.08, 2.4 - rng.randf() * 0.2), color)
				LowPolyBuilder.add_box(st, Vector3(0, 0.1 + layer * 0.1, 0), Vector3(1.1, 0.02, 0.08), WOOD_DARK)
			for z: float in [-0.8, 0.0, 0.8]:
				LowPolyBuilder.add_box(st, Vector3(0, 0.05, z), Vector3(1.2, 0.1, 0.12), WOOD_DARK)
			LowPolyBuilder.add_box(st, Vector3(0, 0.74, 0), Vector3(1.0, 0.04, 2.1), SNOW)
		"brick":
			var mesh := TrainMeshes.create_cargo("brick_pallet", 2)
			_cache[key] = mesh
			return mesh
		"glass":
			LowPolyBuilder.add_box(st, Vector3(0, 0.06, 0), Vector3(1.4, 0.12, 0.9), WOOD_DARK)
			for side: float in [-1.0, 1.0]:
				LowPolyBuilder.add_beam(st, Vector3(-0.6, 0.12, side * 0.4), Vector3(0.0, 1.2, side * 0.08), 0.07, WOOD)
				LowPolyBuilder.add_beam(st, Vector3(0.6, 0.12, side * 0.4), Vector3(0.0, 1.2, side * 0.08), 0.07, WOOD)
			for i in 4:
				var z := -0.25 + i * 0.16
				var tilt := Basis(Vector3.RIGHT, -0.28 * signf(z + 0.01))
				LowPolyBuilder.add_oriented_box(st, Transform3D(tilt, Vector3(0, 0.62, z)), Vector3(1.1, 0.95, 0.03), GLASS)
			LowPolyBuilder.add_box(st, Vector3(0, 1.22, 0), Vector3(1.3, 0.05, 0.2), SNOW)
		"steel":
			for layer in 2:
				for i in 3:
					var x := -0.3 + i * 0.3
					var y := 0.12 + layer * 0.3
					LowPolyBuilder.add_box(st, Vector3(x, y, 0), Vector3(0.2, 0.03, 2.2), STEEL.darkened(0.1))
					LowPolyBuilder.add_box(st, Vector3(x, y + 0.1, 0), Vector3(0.03, 0.18, 2.2), STEEL.darkened(0.25))
					LowPolyBuilder.add_box(st, Vector3(x, y + 0.2, 0), Vector3(0.2, 0.03, 2.2), STEEL)
				LowPolyBuilder.add_box(st, Vector3(0, 0.05 + layer * 0.3, 0.6), Vector3(1.0, 0.08, 0.1), WOOD_DARK)
				LowPolyBuilder.add_box(st, Vector3(0, 0.05 + layer * 0.3, -0.6), Vector3(1.0, 0.08, 0.1), WOOD_DARK)
			LowPolyBuilder.add_box(st, Vector3(0.1, 0.73, 0.2), Vector3(0.4, 0.02, 1.2), SNOW)
		"stone":
			var heap := TrainMeshes.create_cargo("stone_heap")
			_cache[key] = heap
			return heap
	var result := st.commit()
	_cache[key] = result
	return result


## Kleiner Baukran (Turmdrehkran): Turm aus Gitterstücken auf Betonfüßen.
## [param height] = Höhe des Auslegers.
static func tower_crane_mast(height: float) -> ArrayMesh:
	var key := "tower|%.1f" % height
	if _cache.has(key):
		return _cache[key]
	var st := _new_st()
	LowPolyBuilder.add_box(st, Vector3(0, 0.25, 0), Vector3(1.6, 0.5, 1.6), CONCRETE)
	LowPolyBuilder.add_box(st, Vector3(0, 0.52, 0), Vector3(1.4, 0.04, 1.4), SNOW)
	var corners := [Vector2(-0.35, -0.35), Vector2(0.35, -0.35), Vector2(0.35, 0.35), Vector2(-0.35, 0.35)]
	for c: Vector2 in corners:
		LowPolyBuilder.add_box(st, Vector3(c.x, (height + 0.5) * 0.5, c.y), Vector3(0.08, height - 0.5, 0.08), YELLOW)
	var y := 0.9
	var k := 0
	while y < height - 0.4:
		for i in 4:
			var a: Vector2 = corners[i]
			var b: Vector2 = corners[(i + 1) % 4]
			if k % 2 == 0:
				LowPolyBuilder.add_beam(st, Vector3(a.x, y, a.y), Vector3(b.x, y + 0.7, b.y), 0.035, YELLOW)
			else:
				LowPolyBuilder.add_beam(st, Vector3(b.x, y, b.y), Vector3(a.x, y + 0.7, a.y), 0.035, YELLOW)
		y += 0.7
		k += 1
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## Drehbarer Oberteil des Baukrans: Ausleger (entlang -Z), Gegenausleger mit
## Gewicht, Führerhäuschen, Turmspitze. Ursprung = Drehpunkt oben auf dem Turm.
static func tower_crane_top(jib: float) -> Dictionary:
	var key := "tower_top|%.1f" % jib
	if _cache.has(key):
		return _cache[key]
	var st := _new_st()
	var glow := _new_st()
	LowPolyBuilder.add_box(st, Vector3(0, 0.1, 0), Vector3(0.9, 0.2, 0.9), IRON)
	for x: float in [-0.25, 0.25]:
		LowPolyBuilder.add_box(st, Vector3(x, 0.45, -jib * 0.5), Vector3(0.06, 0.06, jib), YELLOW)
	LowPolyBuilder.add_box(st, Vector3(0, 0.85, -jib * 0.5), Vector3(0.06, 0.06, jib), YELLOW)
	# Fachwerk: Zickzack von den Untergurten zum Obergurt
	var z := 0.0
	while z > -jib + 0.4:
		for x: float in [-0.25, 0.25]:
			LowPolyBuilder.add_beam(st, Vector3(x, 0.45, z), Vector3(0, 0.85, z - 0.25), 0.03, YELLOW)
			LowPolyBuilder.add_beam(st, Vector3(0, 0.85, z - 0.25), Vector3(x, 0.45, z - 0.5), 0.03, YELLOW)
		z -= 0.5
	LowPolyBuilder.add_box(st, Vector3(0, 0.5, 1.5), Vector3(0.5, 0.12, 3.0), YELLOW)
	LowPolyBuilder.add_box(st, Vector3(0, 0.45, 2.7), Vector3(0.9, 0.7, 0.6), CONCRETE)
	LowPolyBuilder.add_box(st, Vector3(0, 0.82, 2.7), Vector3(0.85, 0.04, 0.55), SNOW)
	LowPolyBuilder.add_box(st, Vector3(0, 1.5, 0), Vector3(0.1, 2.6, 0.1), YELLOW)
	LowPolyBuilder.add_beam(st, Vector3(0, 2.8, 0), Vector3(0, 0.9, -jib * 0.8), 0.02, IRON)
	LowPolyBuilder.add_beam(st, Vector3(0, 2.8, 0), Vector3(0, 0.6, 2.7), 0.02, IRON)
	# Führerhaus mit warmem Licht
	LowPolyBuilder.add_box(st, Vector3(0.6, -0.35, -0.2), Vector3(0.6, 0.7, 0.7), YELLOW)
	LowPolyBuilder.add_box(glow, Vector3(0.6, -0.3, -0.56), Vector3(0.45, 0.35, 0.02), Color(1.0, 0.86, 0.6))
	LowPolyBuilder.add_box(st, Vector3(0.6, 0.02, -0.2), Vector3(0.62, 0.03, 0.72), SNOW)
	# Laufkatze am Ausleger
	var result := {"body": st.commit(), "glow": glow.commit()}
	_cache[key] = result
	return result


## Katze mit Seil und Lasthaken (Seil wird im Spiel skaliert).
static func tower_crane_hook() -> ArrayMesh:
	if _cache.has("tower_hook"):
		return _cache["tower_hook"]
	var st := _new_st()
	LowPolyBuilder.add_box(st, Vector3(0, 0.35, 0), Vector3(0.4, 0.14, 0.4), IRON)
	LowPolyBuilder.add_box(st, Vector3(0, -0.15, 0), Vector3(0.18, 0.22, 0.14), YELLOW)
	LowPolyBuilder.add_cone(st, Vector3(0, -0.4, 0), 0.07, 0.15, 6, IRON)
	var mesh := st.commit()
	_cache["tower_hook"] = mesh
	return mesh


## Baustellenschild auf zwei Pfosten.
static func site_sign() -> ArrayMesh:
	if _cache.has("sign"):
		return _cache["sign"]
	var st := _new_st()
	for x: float in [-0.55, 0.55]:
		LowPolyBuilder.add_box(st, Vector3(x, 0.8, 0), Vector3(0.08, 1.6, 0.08), WOOD_DARK)
	LowPolyBuilder.add_box(st, Vector3(0, 1.35, 0), Vector3(1.4, 0.7, 0.05), WHITE)
	LowPolyBuilder.add_box(st, Vector3(0, 1.35, -0.03), Vector3(1.46, 0.76, 0.03), YELLOW)
	LowPolyBuilder.add_box(st, Vector3(0, 1.73, 0), Vector3(1.4, 0.05, 0.14), SNOW)
	var mesh := st.commit()
	_cache["sign"] = mesh
	return mesh


## Kleine warme Baustellenlaterne (Glas separat, leuchtet nachts).
static func site_lamp() -> Dictionary:
	if _cache.has("lamp"):
		return _cache["lamp"]
	var st := _new_st()
	var glow := _new_st()
	LowPolyBuilder.add_box(st, Vector3(0, 0.02, 0), Vector3(0.2, 0.04, 0.2), IRON)
	LowPolyBuilder.add_box(glow, Vector3(0, 0.14, 0), Vector3(0.14, 0.2, 0.14), Color(1.0, 0.78, 0.4))
	LowPolyBuilder.add_cone(st, Vector3(0, 0.25, 0), 0.13, 0.08, 4, IRON, PI * 0.25)
	var result := {"body": st.commit(), "glow": glow.commit()}
	_cache["lamp"] = result
	return result
