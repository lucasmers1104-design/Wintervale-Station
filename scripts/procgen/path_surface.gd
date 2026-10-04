## Unified path polygons: square free ends, rounded junctions and no piled snow.
## Scanline tessellation preserves gardens inside closed path loops.
class_name PathSurface
extends RefCounted
const STEP := 0.4
const VERGE := 0.18

static func contours(routes: Array, half: float) -> Dictionary:
	var outer: Array[PackedVector2Array] = []
	var holes: Array[PackedVector2Array] = []
	for route: PackedVector3Array in routes:
		var line := PackedVector2Array()
		for point in route:
			var p := Vector2(point.x,point.z)
			if line.is_empty() or p.distance_to(line[-1])>0.001:
				line.append(p)
		if line.size()<2:
			continue
		for ribbon in Geometry2D.offset_polyline(line,half,Geometry2D.JOIN_ROUND,Geometry2D.END_BUTT):
			var remaining: Array[PackedVector2Array] = []
			for hole in holes:
				for piece in Geometry2D.clip_polygons(hole,ribbon):
					if not Geometry2D.is_polygon_clockwise(piece):
						remaining.append(piece)
			holes = remaining
			var current: PackedVector2Array = ribbon
			var i := 0
			while i<outer.size():
				if not _bounds(current).intersects(_bounds(outer[i]),true):
					i += 1
					continue
				var merged := Geometry2D.merge_polygons(current,outer[i])
				var shells: Array[PackedVector2Array] = []
				var cavities: Array[PackedVector2Array] = []
				for polygon in merged:
					if Geometry2D.is_polygon_clockwise(polygon):
						polygon.reverse()
						cavities.append(polygon)
					else:
						shells.append(polygon)
				if shells.size()==1:
					outer.remove_at(i)
					current = shells[0]
					holes.append_array(cavities)
					i = 0
				else:
					i += 1
			outer.append(current)
	# Closing rounds the inner corners of connected roads without round end caps.
	var radius := half*0.32
	var rounded: Array[PackedVector2Array] = []
	for polygon in outer:
		for grown in Geometry2D.offset_polygon(polygon,radius,Geometry2D.JOIN_ROUND):
			rounded.append_array(Geometry2D.offset_polygon(grown,-radius,Geometry2D.JOIN_ROUND))
	var cavities: Array[PackedVector2Array] = []
	for hole in holes:
		for reduced in Geometry2D.offset_polygon(hole,-radius,Geometry2D.JOIN_ROUND):
			cavities.append_array(Geometry2D.offset_polygon(reduced,radius,Geometry2D.JOIN_ROUND))
	return {"outer":rounded,"holes":cavities}

static func build(routes: Array, half: float, lift: float, height: Callable) -> ArrayMesh:
	var core := contours(routes,half)
	var boundaries: Array = core["outer"]+core["holes"]
	var polygons: Array[PackedVector2Array] = []
	for polygon in core["outer"]:
		polygons.append_array(Geometry2D.offset_polygon(polygon,VERGE,Geometry2D.JOIN_ROUND))
	for hole in core["holes"]:
		polygons.append_array(Geometry2D.offset_polygon(hole,-VERGE,Geometry2D.JOIN_ROUND))
	var mesh := ArrayMesh.new()
	if polygons.is_empty():
		return mesh
	var buckets := _boundary_buckets(boundaries,half+VERGE+0.02)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var levels: Array[float] = []
	var edges: Array = []
	for polygon in polygons:
		for i in polygon.size():
			levels.append(polygon[i].y)
			edges.append([polygon[i],polygon[(i+1)%polygon.size()]])
	levels.sort()
	var bottom := levels[0]
	var top := levels[-1]
	for i in range(1,ceili((top-bottom)/STEP)):
		levels.append(bottom+i*STEP)
	levels.sort()
	var rows: Array[float] = []
	for value in levels:
		if rows.is_empty() or value-rows[-1]>0.00001:
			rows.append(value)
	var cache := {}
	for row in range(1,rows.size()):
		var z0 := rows[row-1]
		var z1 := rows[row]
		var mid := (z0+z1)*0.5
		var crossings: Array = []
		for edge: Array in edges:
			var a: Vector2 = edge[0]
			var b: Vector2 = edge[1]
			if mid>minf(a.y,b.y) and mid<maxf(a.y,b.y):
				crossings.append([_x_at(a,b,mid),a,b])
		crossings.sort_custom(func(a: Array,b: Array) -> bool: return a[0]<b[0])
		for i in range(0,crossings.size()-1,2):
			var left: Array = crossings[i]
			var right: Array = crossings[i+1]
			var x00 := _x_at(left[1],left[2],z0)
			var x01 := _x_at(left[1],left[2],z1)
			var x10 := _x_at(right[1],right[2],z0)
			var x11 := _x_at(right[1],right[2],z1)
			var columns := maxi(1,ceili(maxf(x10-x00,x11-x01)/STEP))
			for k in columns:
				var t0 := float(k)/columns
				var t1 := float(k+1)/columns
				var points := [Vector2(lerpf(x00,x10,t0),z0),Vector2(lerpf(x00,x10,t1),z0),Vector2(lerpf(x01,x11,t1),z1),Vector2(lerpf(x01,x11,t0),z1)]
				for triangle in [[0,1,2],[0,2,3]]:
					for index: int in triangle:
						var info := _vertex(points[index],core,buckets,half,lift,height,cache)
						st.set_normal(Vector3.UP)
						st.set_uv(Vector2(info[1],1.0))
						st.set_color(Color(1,1,1))
						st.add_vertex(info[0])
	st.commit(mesh)
	return mesh

static func _vertex(p: Vector2, core: Dictionary, buckets: Dictionary, half: float, lift: float, height: Callable, cache: Dictionary) -> Array:
	var key := Vector2i(roundi(p.x*100000),roundi(p.y*100000))
	if cache.has(key):
		return cache[key]
	var distance := half
	for edge: Array in buckets.get(Vector2i(floori(p.x),floori(p.y)),[]):
		distance = minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,edge[0],edge[1])))
	var inside := false
	for shell in core["outer"]:
		inside = inside or Geometry2D.is_point_in_polygon(p,shell)
	for hole in core["holes"]:
		if Geometry2D.is_point_in_polygon(p,hole):
			inside = false
	var across := maxf(0.0,1.0-distance/half) if inside else 1.0+distance/half
	var ground := float(height.call(p.x,p.y))
	var support := ground
	for x: float in [-0.3,0,0.3]:
		for z: float in [-0.3,0,0.3]:
			support = maxf(support,float(height.call(p.x+x,p.y+z)))
	var y := support+lift
	if not inside:
		y = lerpf(y,ground+0.004,clampf(distance/VERGE,0,1))
	var value := [Vector3(p.x,y,p.y),across]
	cache[key] = value
	return value

static func _boundary_buckets(polygons: Array, reach: float) -> Dictionary:
	var buckets := {}
	for polygon: PackedVector2Array in polygons:
		for i in polygon.size():
			var edge := [polygon[i],polygon[(i+1)%polygon.size()]]
			var box := Rect2(edge[0],Vector2.ZERO).expand(edge[1]).grow(reach)
			for x in range(floori(box.position.x),ceili(box.end.x)+1):
				for y in range(floori(box.position.y),ceili(box.end.y)+1):
					var key := Vector2i(x,y)
					if not buckets.has(key):
						buckets[key] = []
					buckets[key].append(edge)
	return buckets

static func _x_at(a: Vector2,b: Vector2,y: float) -> float:
	return lerpf(a.x,b.x,(y-a.y)/(b.y-a.y))

static func _bounds(polygon: PackedVector2Array) -> Rect2:
	var box := Rect2(polygon[0],Vector2.ZERO)
	for point in polygon:
		box = box.expand(point)
	return box
