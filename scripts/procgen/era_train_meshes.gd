@tool
## Individually authored vehicle layouts from the six supplied front/side sheets.
## Shared mesh-writing helpers enforce one gauge; bodies, cabs and consists differ.
class_name EraTrainMeshes
extends RefCounted

const SPECS := {
	"heritage_diesel":{"length":16.0,"bogie":5.5,"wheel_base":1.9},
	"heritage_loco":{"length":10.0,"bogie":3.2,"wheel_base":2.0},
	"heritage_coach":{"length":13.0,"bogie":4.6,"wheel_base":1.9},
	"reference_freight_loco":{"length":13.0,"bogie":4.3,"wheel_base":2.1},
	"reference_boxcar":{"length":10.0,"bogie":3.4,"wheel_base":1.8},
	"reference_tank":{"length":9.0,"bogie":3.0,"wheel_base":1.8},
	"reference_coal":{"length":9.0,"bogie":3.0,"wheel_base":1.8},
	"local_front":{"length":17.0,"bogie":5.9,"wheel_base":2.0},
	"local_middle":{"length":16.0,"bogie":5.4,"wheel_base":2.0},
	"local_rear":{"length":17.0,"bogie":5.9,"wheel_base":2.0},
	"intercity_front":{"length":18.0,"bogie":6.5,"wheel_base":2.1},
	"intercity_middle":{"length":17.0,"bogie":5.9,"wheel_base":2.1},
	"intercity_rear":{"length":18.0,"bogie":6.5,"wheel_base":2.1},
	"speed_front":{"length":20.0,"bogie":6.3,"wheel_base":2.1},
	"speed_middle":{"length":18.0,"bogie":6.4,"wheel_base":2.1},
	"speed_rear":{"length":20.0,"bogie":6.3,"wheel_base":2.1}
}
const BLACK := Color(0.06,0.07,0.08)
const METAL := Color(0.36,0.38,0.40)
const RUBBER := Color(0.10,0.105,0.11)
const WARM := Color(1.0,0.84,0.48)

static func build(kind: String, l: Dictionary, variant: int) -> Dictionary:
	var result: Dictionary
	match kind:
		"heritage_diesel": result = _diesel(l)
		"heritage_loco": result = _nostalgic_loco(l)
		"heritage_coach": result = _nostalgic_coach(l)
		"reference_freight_loco": result = _freight_loco(l)
		"reference_boxcar": result = _boxcar()
		"reference_tank": result = _tank()
		"reference_coal": result = _coal()
		_:
			if kind.begins_with("local_"):
				result = _local(kind,l)
			elif kind.begins_with("intercity_"):
				result = _intercity(kind,l,variant)
			else:
				result = _high_speed(kind,l,variant)
	if kind.ends_with("_rear"):
		for key in ["paint","glass","interior","light_front","light_rear"]:
			if result.get(key):
				result[key] = RailcarMeshes._mirror_mesh(result[key])
		for door in result["doors"]:
			door["position"].z = -door["position"].z
			door["open_offset"].z = -door["open_offset"].z
			door["mesh"] = RailcarMeshes._mirror_mesh(door["mesh"])
		if result.has("display"):
			var display: Transform3D = result["display"]
			result["display"] = Transform3D(Basis(Vector3.UP,PI)*display.basis,Vector3(display.origin.x,display.origin.y,-display.origin.z))
		var swap: Variant = result.get("light_front")
		result["light_front"] = result.get("light_rear")
		result["light_rear"] = swap
	return result

static func _streams() -> Dictionary:
	return {"p":TrainMeshes._new_st(),"g":TrainMeshes._new_st(),"i":TrainMeshes._new_st(),"h":TrainMeshes._new_st(),"t":TrainMeshes._new_st(),"doors":[]}

static func _finish(s: Dictionary, interior := true, lamps := true) -> Dictionary:
	return {"paint":s["p"].commit(),"glass":s["g"].commit(),"interior":s["i"].commit() if interior else null,"light_front":s["h"].commit() if lamps else null,"light_rear":s["t"].commit() if lamps else null,"doors":s["doors"],"lamps_front":[],"lamps_rear":[],"reference_railcar":true}

static func _side_quad(st: SurfaceTool, side: float, z0: float, z1: float, y0: float, y1: float, color: Color, x := 1.34) -> void:
	LowPolyBuilder.add_quad_facing(st,Vector3(side*x,y0,z0),Vector3(side*x,y1,z0),Vector3(side*x,y1,z1),Vector3(side*x,y0,z1),color,Vector3(side,0,0))

static func _side_poly(st: SurfaceTool, side: float, vertices: Array[Vector2], color: Color, x := 1.352) -> void:
	for i in range(1,vertices.size()-1):
		LowPolyBuilder.add_triangle_facing(st,Vector3(side*x,vertices[0].y,vertices[0].x),Vector3(side*x,vertices[i].y,vertices[i].x),Vector3(side*x,vertices[i+1].y,vertices[i+1].x),color,Vector3(side,0,0))

static func _band_color(y: float, l: Dictionary, style: String) -> Color:
	if y<1.04:
		return BLACK
	if style == "diesel":
		if y<1.80:
			return l["primary"]
		if y<1.86:
			return l["secondary"]
		if y<1.93:
			return l["primary"]
		return l["secondary"]
	if style == "heritage":
		return l["primary"] if y<1.84 else l["secondary"]
	if style == "local":
		return l["primary"] if y<1.60 or y>3.05 else l["secondary"]
	if style == "intercity":
		return l["accent"] if (y>1.53 and y<1.77) or y>3.30 else l["secondary"]
	return l["accent"] if (y>1.60 and y<1.82) or (y>2.96 and y<3.10) else (BLACK if y<1.20 else l["secondary"])

static func _body(s: Dictionary, start: float, end: float, windows: Array[Vector2], door_zs: Array, l: Dictionary, style: String, seat: Color) -> void:
	var cuts: Array[float] = [start,end]
	for window in windows:
		cuts.append(window.x)
		cuts.append(window.y)
	for z in door_zs:
		cuts.append(z-0.68)
		cuts.append(z+0.68)
	cuts.sort()
	var heights: Array[float] = [0.94,1.04,1.08,1.20,1.53,1.60,1.77,1.80,1.82,1.84,1.86,1.93,1.98,2.96,3.05,3.10,3.22,3.30,3.38]
	for side: float in [-1,1]:
		for j in range(cuts.size()-1):
			var z0 := maxf(start,cuts[j])
			var z1 := minf(end,cuts[j+1])
			if z1-z0<0.001:
				continue
			var z := (z0+z1)/2
			for k in range(heights.size()-1):
				var y0 := heights[k]
				var y1 := heights[k+1]
				var y := (y0+y1)/2
				var hole := false
				for window in windows:
					hole = hole or (z>window.x and z<window.y and y>=1.98 and y<=2.96)
				for door in door_zs:
					hole = hole or (absf(z-door)<0.68 and y>=1.08 and y<=3.10)
				if not hole:
					_side_quad(s["p"],side,z0,z1,y0,y1,_band_color(y,l,style))
		for window in windows:
			_side_quad(s["g"],side,window.x+0.055,window.y-0.055,2.035,2.905,Color(0.15,0.2,0.21),1.348)
			for edge: float in [window.x,window.y]:
				LowPolyBuilder.add_box(s["p"],Vector3(side*1.35,2.47,edge),Vector3(0.06,1.04,0.075),BLACK)
			for y: float in [2.0,2.94]:
				LowPolyBuilder.add_box(s["p"],Vector3(side*1.35,y,(window.x+window.y)/2),Vector3(0.065,0.075,window.y-window.x),BLACK)
		for z in door_zs:
			var leaf := _door_leaf(l["primary"] if style in ["diesel","heritage"] else l["accent"],l["secondary"] if style=="diesel" else l["primary"])
			for direction: float in [-1,1]:
				s["doors"].append({"mesh":leaf,"position":Vector3(side*1.367,2.08,z+direction*0.33),"open_offset":Vector3(side*0.12,0,direction*0.68),"side":side})
			for edge: float in [-1,1]:
				LowPolyBuilder.add_box(s["p"],Vector3(side*1.35,2.09,z+edge*0.7),Vector3(0.08,2.08,0.06),BLACK)
			LowPolyBuilder.add_box(s["p"],Vector3(side*1.35,3.13,z),Vector3(0.08,0.08,1.45),BLACK)
			LowPolyBuilder.add_box(s["i"],Vector3(side*1.28,1.11,z),Vector3(0.20,0.06,1.35),TrainMeshes.STEP_YELLOW)
		# The local train has sweeping turquoise wedges, not rectangular paint bands.
		if style=="local":
			for z in door_zs:
				_side_poly(s["p"],side,[Vector2(z+0.85,1.5),Vector2(z+1.3,1.72),Vector2(end,1.72),Vector2(end,1.5)],l["primary"])
			_side_quad(s["p"],side,start,start+1.0,1.76,1.83,l["accent"],1.355)
	# Faceted roof, independent floor and visible cabin furniture.
	var roof_profile: Array[Vector2] = [Vector2(-1.34,3.38),Vector2(-1.18,3.52),Vector2(-0.75,3.58),Vector2(0.75,3.58),Vector2(1.18,3.52),Vector2(1.34,3.38)]
	for j in roof_profile.size()-1:
		var a := roof_profile[j]
		var b := roof_profile[j+1]
		LowPolyBuilder.add_quad_facing(s["p"],Vector3(a.x,a.y,start),Vector3(b.x,b.y,start),Vector3(b.x,b.y,end),Vector3(a.x,a.y,end),l["roof"],Vector3.UP)
	LowPolyBuilder.add_box(s["i"],Vector3(0,1.03,(start+end)/2),Vector3(2.60,0.1,end-start),Color(0.31,0.29,0.25))
	LowPolyBuilder.add_box(s["i"],Vector3(0,3.34,(start+end)/2),Vector3(2.58,0.08,end-start),Color(0.83,0.74,0.59))
	var row := start+0.5
	while row<end-0.4:
		var clear := true
		for z in door_zs:
			clear = clear and absf(row-z)>0.85
		if clear:
			for side: float in [-1,1]:
				for x: float in [0.63,1.06]:
					_seat(s["i"],Vector3(side*x,1.12,row),seat)
			LowPolyBuilder.add_box(s["i"],Vector3(0,3.28,row),Vector3(0.64,0.045,0.12),Color(1,0.85,0.47,0.5))
		row += 1.16 if style in ["diesel","heritage"] else 1.05
	for z in range(int(start)+2,int(end),3):
		LowPolyBuilder.add_box(s["p"],Vector3(0,3.68,z),Vector3(1.50,0.18,1.0),l["roof"].lightened(0.12))
		for i in 5:
			LowPolyBuilder.add_box(s["p"],Vector3(-0.5+i*0.25,3.782,z),Vector3(0.075,0.016,0.7),BLACK)
	for z in range(int(start)+1,int(end),2):
		LowPolyBuilder.add_box(s["p"],Vector3(0,0.67,z),Vector3(1.45,0.46,1.2),BLACK)
		for side: float in [-1,1]:
			LowPolyBuilder.add_box(s["p"],Vector3(side*0.78,0.72,z),Vector3(0.06,0.32,0.88),METAL)

static func _seat(st: SurfaceTool, at: Vector3, color: Color) -> void:
	LowPolyBuilder.add_box(st,at+Vector3(0,0.12,0),Vector3(0.12,0.25,0.35),METAL)
	LowPolyBuilder.add_box(st,at+Vector3(0,0.36,0),Vector3(0.40,0.16,0.46),color)
	LowPolyBuilder.add_box(st,at+Vector3(0,0.66,0.22),Vector3(0.40,0.57,0.12),color)
	LowPolyBuilder.add_box(st,at+Vector3(0,0.94,0.22),Vector3(0.34,0.09,0.14),color.lightened(0.09))

static func _door_leaf(lower: Color, upper: Color) -> ArrayMesh:
	var p := TrainMeshes._new_st()
	var g := TrainMeshes._new_st()
	LowPolyBuilder.add_box(p,Vector3(0,-0.61,0),Vector3(0.06,0.78,0.64),lower)
	LowPolyBuilder.add_box(p,Vector3(0,0.93,0),Vector3(0.06,0.14,0.64),upper)
	for side: float in [-1,1]:
		LowPolyBuilder.add_box(p,Vector3(0,0.31,side*0.295),Vector3(0.06,1.10,0.05),upper)
	_side_quad(g,1,-0.258,0.258,-0.18,0.855,Color(0.1,0.15,0.17),0.035)
	LowPolyBuilder.add_box(p,Vector3(0.043,-0.40,-0.23),Vector3(0.04,0.26,0.035),METAL)
	LowPolyBuilder.add_box(p,Vector3(0.036,0,-0.315),Vector3(0.02,2,0.013),BLACK)
	var mesh := p.commit()
	g.commit(mesh)
	return mesh

static func _end(st: SurfaceTool, z: float, color: Color, gangway := true) -> void:
	LowPolyBuilder.add_box(st,Vector3(0,2.16,z),Vector3(2.65,2.25,0.08),color)
	if gangway:
		for i in 6:
			LowPolyBuilder.add_box(st,Vector3(0,2.17,z+signf(z)*(0.06+i*0.052)),Vector3(1.18,2.15,0.04),BLACK.lightened((i%2)*0.035))
	_coupler(st,z,signf(z))

static func _coupler(st: SurfaceTool, z: float, facing: float, buffers := false) -> void:
	ReferenceRailcarMeshes._bevel_box(st,Vector3(0,1.05,z+facing*0.2),Vector3(0.48,0.45,0.4),0.06,METAL)
	LowPolyBuilder.add_box(st,Vector3(0,0.84,z+facing*0.27),Vector3(0.13,0.24,0.16),BLACK)
	if buffers:
		for side: float in [-1,1]:
			ReferenceRailcarMeshes._bevel_box(st,Vector3(side*0.91,1.1,z+facing*0.18),Vector3(0.58,0.44,0.28),0.06,METAL)

static func _diesel(l: Dictionary) -> Dictionary:
	var s := _streams()
	var windows: Array[Vector2] = [Vector2(-6.4,-4.8),Vector2(-4.5,-3.65),Vector2(-3.35,-2.75),Vector2(-0.60,0.90),Vector2(1.20,2.70),Vector2(3.00,4.35),Vector2(4.70,6.40)]
	var doors: Array[float] = [-1.7]
	_body(s,-6.8,6.8,windows,doors,l,"diesel",Color(0.55,0.16,0.11))
	for end: float in [-1,1]:
		_old_cab(s,end*8,end,l,false)
		_coupler(s["p"],end*8,end,true)
	# Large center radiator, square destination lamp and distinctive twin screens.
	for end: float in [-1,1]:
		for i in 6:
			LowPolyBuilder.add_box(s["p"],Vector3(0,1.50+i*0.10,end*8.085),Vector3(0.82,0.044,0.04),BLACK)
		LowPolyBuilder.add_box(s["p"],Vector3(0,3.18,end*8.06),Vector3(0.52,0.3,0.15),METAL)
		LowPolyBuilder.add_box(s["h"] if end<0 else s["t"],Vector3(0,3.18,end*8.155),Vector3(0.39,0.20,0.035),WARM)
	for z: float in [-5.2,5.1]:
		LowPolyBuilder.add_cylinder(s["p"],Vector3(0,3.56,z),0.18,0.17,0.33,10,METAL)
		LowPolyBuilder.add_cylinder(s["p"],Vector3(0,3.89,z),0.26,0.26,0.05,10,BLACK)
	var result := _finish(s)
	return result

static func _old_cab(s: Dictionary, z: float, facing: float, l: Dictionary, loco: bool) -> void:
	var back := z-facing*1.2
	for side: float in [-1,1]:
		_side_quad(s["p"],side,minf(back,z),maxf(back,z),1.05,1.98,l["primary"])
		_side_quad(s["p"],side,minf(back,z),maxf(back,z),2.96,3.38,l["secondary"])
		_side_quad(s["g"],side,minf(back,z)+0.15,maxf(back,z)-0.15,2.07,2.88,Color(0.14,0.19,0.18))
		LowPolyBuilder.add_box(s["p"],Vector3(side*1.49,2.48,z-facing*0.35),Vector3(0.16,0.44,0.20),BLACK)
	LowPolyBuilder.add_box(s["p"],Vector3(0,1.47,z),Vector3(2.67,0.86,0.12),l["primary"])
	LowPolyBuilder.add_box(s["p"],Vector3(0,1.93,z),Vector3(2.67,0.07,0.12),l["primary"])
	LowPolyBuilder.add_box(s["p"],Vector3(0,1.84,z+facing*0.012),Vector3(2.67,0.045,0.12),l["secondary"])
	LowPolyBuilder.add_box(s["p"],Vector3(0,3.20,z-facing*0.08),Vector3(2.66,0.35,0.18),l["secondary"])
	ReferenceRailcarMeshes._bevel_box(s["p"],Vector3(0,3.43,z-facing*0.55),Vector3(2.68,0.26,1.25),0.12,l["roof"])
	for x: float in [-1.24,0,1.24]:
		LowPolyBuilder.add_box(s["p"],Vector3(x,2.47,z),Vector3(0.11,1.09,0.09),BLACK)
	for y: float in [1.99,2.98]:
		LowPolyBuilder.add_box(s["p"],Vector3(0,y,z),Vector3(2.5,0.10,0.1),BLACK)
	for side: float in [-1,1]:
		var x0 := -1.17 if side<0 else 0.08
		var x1 := -0.08 if side<0 else 1.17
		LowPolyBuilder.add_quad_facing(s["g"],Vector3(x0,2.06,z+facing*0.014),Vector3(x1,2.06,z+facing*0.014),Vector3(x1,2.92,z+facing*0.014),Vector3(x0,2.92,z+facing*0.014),Color(0.12,0.17,0.17),Vector3(0,0,facing))
		LowPolyBuilder.add_beam(s["p"],Vector3(side*0.70,2.16,z+facing*0.08),Vector3(side*0.35,2.72,z+facing*0.08),0.035,BLACK)
		_seat(s["i"],Vector3(side*0.66,1.3,z-facing*0.8),Color(0.28,0.27,0.22))
		if not loco:
			LowPolyBuilder.add_cylinder_between(s["p"],Vector3(side*0.92,1.54,z),Vector3(side*0.92,1.54,z+facing*0.10),0.17,12,METAL)
			LowPolyBuilder.add_cylinder_between(s["h"] if facing<0 else s["t"],Vector3(side*0.92,1.54,z+facing*0.10),Vector3(side*0.92,1.54,z+facing*0.13),0.125,12,WARM)

static func _nostalgic_coach(l: Dictionary) -> Dictionary:
	var s := _streams()
	var windows: Array[Vector2] = [Vector2(-5.6,-4.7),Vector2(-4.35,-2.6),Vector2(-2.25,-1.35),Vector2(1.35,2.65),Vector2(2.95,4.7),Vector2(5.0,5.65)]
	_body(s,-6.5,6.5,windows,[0.0],l,"heritage",Color(0.61,0.27,0.12))
	for side: float in [-1,1]:
		for y: float in [1.84,1.92]:
			_side_quad(s["p"],side,-6.45,6.45,y,y+0.036,l["secondary"],1.357)
	for end: float in [-1,1]:
		_end(s["p"],end*6.5,l["primary"])
		for side: float in [-1,1]:
			LowPolyBuilder.add_beam(s["p"],Vector3(side*1.3,1.2,end*6.35),Vector3(side*1.3,2.4,end*6.35),0.05,l["secondary"])
	for side: float in [-1,1]:
		LowPolyBuilder.add_box(s["h"],Vector3(side*0.98,1.53,-6.56),Vector3(0.12,0.16,0.025),WARM)
		LowPolyBuilder.add_box(s["t"],Vector3(side*0.98,1.53,6.56),Vector3(0.12,0.16,0.025),WARM)
	return _finish(s,true,true)

static func _nostalgic_loco(l: Dictionary) -> Dictionary:
	var s := _streams()
	# Center cabin, long narrow hood, open running boards: separate silhouette.
	LowPolyBuilder.add_box(s["p"],Vector3(0,1.15,0),Vector3(2.65,0.26,10),Color(0.47,0.19,0.13))
	for side: float in [-1,1]:
		LowPolyBuilder.add_box(s["p"],Vector3(side*1.29,1.31,0),Vector3(0.08,0.06,9.9),l["accent"])
	ReferenceRailcarMeshes._bevel_box(s["p"],Vector3(0,1.98,-2.25),Vector3(1.8,1.45,5.25),0.15,l["primary"])
	ReferenceRailcarMeshes._bevel_box(s["p"],Vector3(0,1.78,3.4),Vector3(1.9,1.03,2.9),0.13,l["primary"])
	LowPolyBuilder.add_box(s["p"],Vector3(0,1.51,1.2),Vector3(2.65,0.52,3.5),l["primary"])
	LowPolyBuilder.add_box(s["i"],Vector3(0,1.28,1.2),Vector3(2.50,0.1,3.5),Color(0.35,0.31,0.25))
	LowPolyBuilder.add_box(s["i"],Vector3(0,3.3,1.2),Vector3(2.5,0.10,3.5),l["secondary"])
	for end: float in [-0.55,2.95]:
		LowPolyBuilder.add_box(s["p"],Vector3(0,1.93,end),Vector3(2.65,0.33,0.1),l["secondary"])
		LowPolyBuilder.add_box(s["p"],Vector3(0,3.2,end),Vector3(2.65,0.3,0.1),l["secondary"])
		for x: float in [-1.25,0,1.25]:
			LowPolyBuilder.add_box(s["p"],Vector3(x,2.64,end),Vector3(0.12,1.1,0.1),l["secondary"])
	for side: float in [-1,1]:
		_side_quad(s["p"],side,-0.55,2.95,1.33,1.88,l["primary"])
		for window in [Vector2(-0.30,0.65),Vector2(0.94,2.52)]:
			for edge in [window.x-0.04,window.y+0.04]:
				LowPolyBuilder.add_box(s["p"],Vector3(side*1.355,2.64,edge),Vector3(0.07,1.03,0.07),BLACK)
			for y in [2.17,3.08]:
				LowPolyBuilder.add_box(s["p"],Vector3(side*1.355,y,(window.x+window.y)/2),Vector3(0.07,0.07,window.y-window.x+0.1),BLACK)
			_side_quad(s["g"],side,window.x,window.y,2.2,3.05,Color(0.13,0.2,0.17),1.369)
		for z: float in [-4.5,-1,3.8]:
			LowPolyBuilder.add_beam(s["p"],Vector3(side*1.22,1.3,z),Vector3(side*1.22,2.15,z),0.045,l["secondary"])
			LowPolyBuilder.add_box(s["p"],Vector3(side*1.22,0.85,z),Vector3(0.40,0.10,0.45),l["accent"])
		LowPolyBuilder.add_beam(s["p"],Vector3(side*1.22,2.15,-4.5),Vector3(side*1.22,2.15,-1),0.045,l["secondary"])
		for i in 7:
			LowPolyBuilder.add_box(s["p"],Vector3(side*0.91,1.70+i*0.09,-1.6),Vector3(0.024,0.03,1.3),BLACK)
	ReferenceRailcarMeshes._bevel_box(s["p"],Vector3(0,3.47,1.2),Vector3(2.80,0.25,3.9),0.14,l["roof"])
	for x: float in [-0.6,0.6]:
		for y in [2.26,3.08]:
			LowPolyBuilder.add_box(s["p"],Vector3(x,y,-0.58),Vector3(1.05,0.065,0.1),BLACK)
		LowPolyBuilder.add_box(s["g"],Vector3(x,2.66,-0.65),Vector3(0.88,0.65,0.025),Color(0.12,0.18,0.17))
	LowPolyBuilder.add_box(s["p"],Vector3(0,2.02,-4.90),Vector3(1.10,1.18,0.13),l["secondary"])
	for i in 8:
		LowPolyBuilder.add_box(s["p"],Vector3(0,1.56+i*0.13,-4.98),Vector3(0.90,0.057,0.035),BLACK)
	LowPolyBuilder.add_cylinder(s["p"],Vector3(0,2.74,-2.2),0.17,0.16,0.55,10,BLACK)
	LowPolyBuilder.add_cylinder(s["p"],Vector3(0,3.55,0.2),0.15,0.15,0.42,10,BLACK)
	for side: float in [-1,1]:
		LowPolyBuilder.add_cylinder_between(s["p"],Vector3(side*0.84,1.67,-4.86),Vector3(side*0.84,1.67,-4.98),0.17,12,METAL)
		LowPolyBuilder.add_cylinder_between(s["h"],Vector3(side*0.84,1.67,-4.99),Vector3(side*0.84,1.67,-5.015),0.12,12,WARM)
	LowPolyBuilder.add_cylinder_between(s["h"],Vector3(0,3.39,-0.68),Vector3(0,3.39,-0.76),0.14,12,WARM)
	for end: float in [-1,1]:
		_coupler(s["p"],end*5,end,true)
	_seat(s["i"],Vector3(0,1.35,0.5),Color(0.28,0.3,0.24))
	return _finish(s)

static func _local(kind: String, l: Dictionary) -> Dictionary:
	var s := _streams()
	var cab := kind != "local_middle"
	var half := 8.5 if cab else 8.0
	var start := -5.55 if cab else -half
	var windows: Array[Vector2] = []
	windows.assign([Vector2(-5.22,-4.40),Vector2(-4.0,-2.6),Vector2(-0.2,1.5),Vector2(1.7,3.55),Vector2(4.0,6.55),Vector2(6.85,7.7)] if cab else [Vector2(-7.3,-5.6),Vector2(-5.35,-3.25),Vector2(-2.95,-1.1),Vector2(1.15,3.15),Vector2(3.4,5.4),Vector2(5.7,7.35)])
	_body(s,start,half,windows,[-1.40] if cab else [0.0],l,"local",Color(0.13,0.27,0.34))
	_end(s["p"],half,l["primary"])
	if cab:
		var shape: Array[Vector3] = [Vector3(1.06,1.02,-8.5),Vector3(1.3,1.38,-8.43),Vector3(1.34,1.8,-8.14),Vector3(1.28,2.08,-7.93),Vector3(1.18,3.05,-7.15),Vector3(1.0,3.47,-6.75),Vector3(0.8,3.58,-6.4)]
		_modern_cab(s,shape,start,l,"local")
	else:
		_end(s["p"],-half,l["primary"])
	var result := _finish(s,true,cab)
	if cab:
		result["display"] = Transform3D(Basis(Vector3.UP,PI),Vector3(0,3.13,-7.08))
	return result

static func _intercity(kind: String, l: Dictionary, variant: int) -> Dictionary:
	var s := _streams()
	var cab := kind != "intercity_middle"
	var half := 9.0 if cab else 8.5
	var start := -5.7 if cab else -half
	var doors: Array = [-2.45] if cab else ([4.55] if variant%2 else [-4.55])
	var windows: Array[Vector2] = []
	var z := start+0.40
	while z<half-0.7:
		var end := minf(z+1.2,half-0.4)
		var clear := true
		for door in doors:
			clear = clear and (end<door-0.9 or z>door+0.9)
		if clear:
			windows.append(Vector2(z,end))
		z += 1.45
	_body(s,start,half,windows,doors,l,"intercity",Color(0.46,0.11,0.13))
	_end(s["p"],half,l["secondary"])
	if cab:
		var shape: Array[Vector3] = [Vector3(1.0,1.02,-9),Vector3(1.22,1.38,-8.94),Vector3(1.29,1.78,-8.65),Vector3(1.26,2.06,-8.4),Vector3(1.13,3.05,-7.2),Vector3(1.0,3.43,-6.8),Vector3(0.78,3.58,-6.4)]
		_modern_cab(s,shape,start,l,"intercity")
	else:
		_end(s["p"],-half,l["secondary"])
	var result := _finish(s,true,cab)
	if cab:
		result["display"] = Transform3D(Basis(Vector3.UP,PI),Vector3(0,3.14,-7.08))
	return result

static func _high_speed(kind: String, l: Dictionary, variant: int) -> Dictionary:
	var s := _streams()
	var cab := kind != "speed_middle"
	var half := 10.0 if cab else 9.0
	var start := -3.65 if cab else -half
	var doors: Array = [7.65] if cab else ([7.3] if variant%2 else [-7.3])
	var windows: Array[Vector2] = []
	var z := start+0.6
	while z<half-1.0:
		var end := minf(z+1.0,half-0.4)
		var clear := true
		for door in doors:
			clear = clear and (end<door-0.85 or z>door+0.85)
		if clear:
			windows.append(Vector2(z,end))
		z += 1.28
	_body(s,start,half,windows,doors,l,"speed",Color(0.15,0.25,0.32))
	for side: float in [-1,1]:
		# Continuous black window ribbon with a fine cobalt border.
		for window in windows:
			_side_quad(s["p"],side,window.x-0.075,window.y+0.075,1.89,1.98,BLACK,1.354)
			_side_quad(s["p"],side,window.x-0.075,window.y+0.075,2.96,3.03,BLACK,1.354)
		for z0 in range(int(start)+1,int(half)-1,3):
			LowPolyBuilder.add_box(s["p"],Vector3(side*1.29,1.15,z0),Vector3(0.06,0.2,1.05),METAL)
	_end(s["p"],half,l["secondary"])
	if cab:
		var shape: Array[Vector3] = [Vector3(0.46,1.00,-10),Vector3(0.77,1.34,-9.76),Vector3(1.03,1.80,-8.93),Vector3(1.14,2.10,-7.48),Vector3(1.12,3.05,-5.02),Vector3(0.98,3.43,-4.22),Vector3(0.75,3.58,-3.65)]
		_modern_cab(s,shape,start,l,"speed")
	else:
		_end(s["p"],-half,l["secondary"])
	var result := _finish(s,true,cab)
	if cab:
		result["display"] = Transform3D(Basis(Vector3.UP,PI),Vector3(0,3.14,-4.8))
	return result

static func _at(shape: Array[Vector3], x: float, y: float, outset := 0.0) -> Vector3:
	for j in range(shape.size()-1):
		if y <= shape[j+1].y:
			var t := inverse_lerp(shape[j].y,shape[j+1].y,y)
			var point := shape[j].lerp(shape[j+1],clampf(t,0,1))
			return Vector3(x,y,point.z-outset)
	return Vector3(x,y,shape[-1].z-outset)

static func _cab_polygon(st: SurfaceTool, shape: Array[Vector3], polygon: Array[Vector2], color: Color, outset := 0.01) -> void:
	# Split the paint and lamp inlays at every nose ring. A single flat triangle
	# crossing several slopes otherwise cuts through the curved body panels.
	for ring in range(shape.size()-1):
		var clipped := _clip_y(_clip_y(polygon,shape[ring].y,true),shape[ring+1].y,false)
		for i in range(1,clipped.size()-1):
			LowPolyBuilder.add_triangle_facing(st,_at(shape,clipped[0].x,clipped[0].y,outset),_at(shape,clipped[i].x,clipped[i].y,outset),_at(shape,clipped[i+1].x,clipped[i+1].y,outset),color,Vector3(0,0.5,-1))

static func _clip_y(polygon: Array[Vector2], height: float, above: bool) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if polygon.is_empty():
		return result
	var previous := polygon[-1]
	var previous_inside := previous.y>=height if above else previous.y<=height
	for current in polygon:
		var inside := current.y>=height if above else current.y<=height
		if inside!=previous_inside:
			result.append(previous.lerp(current,(height-previous.y)/(current.y-previous.y)))
		if inside:
			result.append(current)
		previous = current
		previous_inside = inside
	return result

static func _modern_cab(s: Dictionary, shape: Array[Vector3], start: float, l: Dictionary, style: String) -> void:
	# The three front profiles are separately measured; the speed nose is twice as long.
	for side: float in [-1,1]:
		for j in range(shape.size()-1):
			var a := shape[j]
			var b := shape[j+1]
			var color := _band_color((a.y+b.y)/2,l,style)
			var outer_a := Vector3(side*1.34,a.y,start)
			var outer_b := Vector3(side*1.34,b.y,start)
			var front_a := Vector3(side*a.x,a.y,a.z)
			var front_b := Vector3(side*b.x,b.y,b.z)
			LowPolyBuilder.add_quad_facing(s["p"],outer_a,outer_b,front_b,front_a,color,Vector3(side,0,0))
		# Tapered side cab window; its black frame is part of the nose silhouette.
		var a := Vector3(side*1.351,2.04,start-0.12)
		var b := Vector3(side*1.351,3.08,start-0.12)
		var c := _at(shape,side*1.13,2.85,0.015)
		LowPolyBuilder.add_triangle_facing(s["g"],a,b,c,Color(0.1,0.16,0.18),Vector3(side,0,0))
		LowPolyBuilder.add_beam(s["p"],a,b,0.08,BLACK)
		LowPolyBuilder.add_beam(s["p"],b,c,0.08,BLACK)
		LowPolyBuilder.add_beam(s["p"],c,a,0.08,BLACK)
	# Front lower panels and shoulders leave the windscreen physically open.
	for j in range(shape.size()-1):
		var a := shape[j]
		var b := shape[j+1]
		var panel: Array[Vector2] = [Vector2(-a.x,a.y),Vector2(a.x,a.y),Vector2(b.x,b.y),Vector2(-b.x,b.y)]
		_cab_polygon(s["p"],shape,_clip_y(panel,2.08,false),l["secondary"])
		_cab_polygon(s["p"],shape,_clip_y(panel,3.05,true),l["secondary"])
	for side: float in [-1,1]:
		_cab_polygon(s["p"],shape,[Vector2(side*0.98,2.08),Vector2(side*1.27,2.08),Vector2(side*1.13,3.05),Vector2(side*0.89,3.05)],l["primary"] if style=="local" else l["secondary"])
	var frame: Array[Vector2] = [Vector2(-0.96,2.05),Vector2(0.96,2.05),Vector2(1.02,3.12),Vector2(-1.02,3.12)]
	var pane: Array[Vector2] = [Vector2(-0.82,2.17),Vector2(0.82,2.17),Vector2(0.88,3.00),Vector2(-0.88,3.00)]
	for j in 4:
		var k := (j+1)%4
		_cab_polygon(s["p"],shape,[frame[j],frame[k],pane[k],pane[j]],BLACK,0.035)
	_cab_polygon(s["g"],shape,pane,Color(0.1,0.15,0.18),0.055)
	LowPolyBuilder.add_beam(s["p"],_at(shape,0.64,2.19,0.10),_at(shape,0.05,2.70,0.10),0.04,BLACK)
	var seat := Color(0.47,0.12,0.14) if style=="intercity" else Color(0.14,0.25,0.34)
	# A real cab partition replaces the previously visible cream end of the car.
	LowPolyBuilder.add_box(s["p"],Vector3(0,2.20,start+0.04),Vector3(2.55,2.25,0.08),BLACK)
	for side: float in [-1,1]:
		_seat(s["i"],Vector3(side*0.63,1.48,start-0.6),seat)
	LowPolyBuilder.add_box(s["i"],Vector3(0,2.0,start-1.05),Vector3(1.9,0.14,0.35),Color(0.30,0.32,0.32))
	if style=="speed":
		_cab_polygon(s["p"],shape,[Vector2(-0.18,1.50),Vector2(0.18,1.50),Vector2(0.74,2.05),Vector2(-0.74,2.05)],BLACK,0.045)
		for side: float in [-1,1]:
			_cab_polygon(s["p"],shape,[Vector2(side*0.36,1.48),Vector2(side*0.65,1.6),Vector2(side*1.02,2.13),Vector2(side*0.88,2.2)],BLACK,0.055)
			_cab_polygon(s["h"],shape,[Vector2(side*0.43,1.56),Vector2(side*0.62,1.66),Vector2(side*0.94,2.08),Vector2(side*0.87,2.10)],WARM,0.065)
			_cab_polygon(s["p"],shape,[Vector2(side*0.20,1.3),Vector2(side*0.62,1.44),Vector2(side*1.15,2.02),Vector2(side*1.09,2.17)],l["accent"],0.030)
	else:
		for side: float in [-1,1]:
			_cab_polygon(s["p"],shape,[Vector2(side*0.66,1.44),Vector2(side*1.20,1.51),Vector2(side*1.12,1.97),Vector2(side*0.73,1.91)],BLACK,0.10)
			_cab_polygon(s["h"],shape,[Vector2(side*0.76,1.57),Vector2(side*1.07,1.61),Vector2(side*1.01,1.84),Vector2(side*0.79,1.82)],WARM,0.13)
		if style=="local":
			for side: float in [-1,1]:
				_cab_polygon(s["p"],shape,[Vector2(side*0.34,1.07),Vector2(side*0.65,1.13),Vector2(side*0.88,1.99),Vector2(side*1.17,3.20),Vector2(side*0.94,3.37),Vector2(side*0.70,2.03)],l["primary"],0.035)
		else:
			_cab_polygon(s["p"],shape,[Vector2(-0.66,1.53),Vector2(0.66,1.53),Vector2(0.66,1.73),Vector2(-0.66,1.73)],l["accent"],0.018)
			for side: float in [-1,1]:
				_cab_polygon(s["p"],shape,[Vector2(side*1.20,1.53),Vector2(side*1.28,1.53),Vector2(side*1.28,1.73),Vector2(side*1.20,1.73)],l["accent"],0.018)
	_cab_polygon(s["p"],shape,[Vector2(-0.9,3.06),Vector2(0.9,3.06),Vector2(0.85,3.30),Vector2(-0.85,3.30)],BLACK,0.055)
	_cab_polygon(s["h"],shape,[Vector2(-0.65,3.12),Vector2(0.65,3.12),Vector2(0.64,3.23),Vector2(-0.64,3.23)],WARM,0.070)
	if style=="speed":
		ReferenceRailcarMeshes._bevel_box(s["p"],Vector3(0,1.08,shape[0].z-0.06),Vector3(0.48,0.22,0.10),0.035,BLACK)
	else:
		_coupler(s["p"],shape[0].z,-1,true)
	# Roof bridge between the last cab ring and the straight body roof.
	LowPolyBuilder.add_quad_facing(s["p"],Vector3(-0.8,3.58,shape[-1].z),Vector3(0.8,3.58,shape[-1].z),Vector3(1.18,3.52,start),Vector3(-1.18,3.52,start),l["roof"],Vector3.UP)

static func _freight_loco(l: Dictionary) -> Dictionary:
	var s := _streams()
	# Full-width red end cab and long engine room, unlike the green center-cab loco.
	LowPolyBuilder.add_box(s["p"],Vector3(0,1.17,0),Vector3(2.68,0.30,13),BLACK)
	ReferenceRailcarMeshes._bevel_box(s["p"],Vector3(0,2.14,1.05),Vector3(2.39,1.85,10.75),0.16,l["primary"])
	_old_cab(s,-6.5,-1,l,true)
	for side: float in [-1,1]:
		_side_quad(s["p"],side,-5.25,6.2,1.88,2.08,l["secondary"],1.21)
		for z: float in [-1.8,1.2,4.5]:
			for i in 11:
				LowPolyBuilder.add_box(s["p"],Vector3(side*1.215,2.22+i*0.055,z),Vector3(0.025,0.021,1.42),BLACK)
		for z: float in [-6.1,-4.9,5.8]:
			LowPolyBuilder.add_beam(s["p"],Vector3(side*1.37,1.28,z),Vector3(side*1.37,2.3,z),0.05,l["accent"])
		LowPolyBuilder.add_beam(s["p"],Vector3(side*1.37,2.3,-6.1),Vector3(side*1.37,2.3,-4.9),0.05,l["accent"])
		for i in 3:
			LowPolyBuilder.add_box(s["p"],Vector3(side*1.36,0.59+i*0.26,-6.02),Vector3(0.48,0.055,0.43),l["accent"])
		LowPolyBuilder.add_box(s["h"],Vector3(side*0.91,1.53,-6.59),Vector3(0.26,0.24,0.03),WARM)
	_cab_polygon(s["p"],[Vector3(1.34,1.01,-6.57),Vector3(1.34,3.5,-6.57)],[Vector2(-1.3,1.99),Vector2(0,1.70),Vector2(1.3,1.99),Vector2(1.3,2.14),Vector2(0,1.92),Vector2(-1.3,2.14)],l["secondary"])
	for z: float in [-0.5,2.6,4.7]:
		LowPolyBuilder.add_cylinder(s["p"],Vector3(0,3.15,z),0.42,0.42,0.15,12,BLACK)
		LowPolyBuilder.add_box(s["p"],Vector3(0,3.34,z),Vector3(1.08,0.12,0.96),METAL)
	LowPolyBuilder.add_box(s["p"],Vector3(0,0.69,0.2),Vector3(1.9,0.7,3.6),BLACK)
	for end: float in [-1,1]:
		_coupler(s["p"],end*6.5,end,true)
	LowPolyBuilder.add_box(s["h"],Vector3(0,3.12,-6.48),Vector3(0.4,0.19,0.055),WARM)
	return _finish(s)

static func _wagon_frame(st: SurfaceTool, half: float, color: Color) -> void:
	LowPolyBuilder.add_box(st,Vector3(0,1.08,0),Vector3(2.6,0.27,half*2),color)
	for end: float in [-1,1]:
		_coupler(st,end*half,end)
		for side: float in [-1,1]:
			LowPolyBuilder.add_beam(st,Vector3(side*1.33,1.1,end*(half-0.2)),Vector3(side*1.33,2.3,end*(half-0.2)),0.045,TrainMeshes.STEP_YELLOW)
			LowPolyBuilder.add_box(st,Vector3(side*1.28,0.78,end*(half-0.2)),Vector3(0.36,0.055,0.35),TrainMeshes.STEP_YELLOW)

static func _boxcar() -> Dictionary:
	var s := _streams()
	var color := Color(0.45,0.20,0.15)
	_wagon_frame(s["p"],5,color)
	LowPolyBuilder.add_box(s["p"],Vector3(0,2.17,0),Vector3(2.56,2.10,9.86),color)
	ReferenceRailcarMeshes._bevel_box(s["p"],Vector3(0,3.28,0),Vector3(2.64,0.3,10),0.14,color.lightened(0.08))
	for side: float in [-1,1]:
		for z in range(-4,5):
			LowPolyBuilder.add_box(s["p"],Vector3(side*1.32,2.22,z),Vector3(0.10,2.04,0.075),color.darkened(0.10))
		LowPolyBuilder.add_box(s["p"],Vector3(side*1.38,2.18,0),Vector3(0.08,1.95,2.5),color.darkened(0.05))
		for i in 6:
			LowPolyBuilder.add_box(s["p"],Vector3(side*1.43,1.37+i*0.30,0),Vector3(0.028,0.045,2.32),color.lightened(0.09))
		LowPolyBuilder.add_beam(s["p"],Vector3(side*1.37,1.25,-4.3),Vector3(side*1.37,3.13,-1.4),0.10,color.darkened(0.18))
		LowPolyBuilder.add_beam(s["p"],Vector3(side*1.37,1.25,4.3),Vector3(side*1.37,3.13,1.4),0.10,color.darkened(0.18))
	return _finish(s,false,false)

static func _tank() -> Dictionary:
	var s := _streams()
	_wagon_frame(s["p"],4.5,METAL)
	var color := Color(0.86,0.85,0.79)
	LowPolyBuilder.add_cylinder_between(s["p"],Vector3(0,2.21,-3.65),Vector3(0,2.21,3.65),1.06,12,color)
	for z: float in [-2.7,2.7]:
		LowPolyBuilder.add_box(s["p"],Vector3(0,1.42,z),Vector3(1.8,0.26,0.65),METAL)
		LowPolyBuilder.add_cylinder_between(s["p"],Vector3(0,2.21,z-0.08),Vector3(0,2.21,z+0.08),1.075,12,color.darkened(0.15))
	LowPolyBuilder.add_cylinder(s["p"],Vector3(0,3.25,0),0.34,0.34,0.18,10,METAL)
	for side: float in [-1,1]:
		LowPolyBuilder.add_box(s["p"],Vector3(side*0.56,3.43,0),Vector3(0.045,0.045,5.0),METAL)
		for z: float in [-2.5,0,2.5]:
			LowPolyBuilder.add_box(s["p"],Vector3(side*0.56,3.63,z),Vector3(0.04,0.42,0.04),METAL)
		LowPolyBuilder.add_box(s["p"],Vector3(side*0.56,3.84,0),Vector3(0.045,0.045,5.0),METAL)
	for i in 8:
		LowPolyBuilder.add_box(s["p"],Vector3(1.12,1.15+i*0.3,-2.2),Vector3(0.10,0.045,0.55),METAL)
	return _finish(s,false,false)

static func _coal() -> Dictionary:
	var s := _streams()
	var color := Color(0.22,0.36,0.46)
	_wagon_frame(s["p"],4.5,color)
	LowPolyBuilder.add_box(s["p"],Vector3(0,1.29,0),Vector3(2.65,0.12,8.7),color)
	for side: float in [-1,1]:
		LowPolyBuilder.add_box(s["p"],Vector3(side*1.30,2.02,0),Vector3(0.12,1.52,8.85),color)
		for z in range(-4,5):
			LowPolyBuilder.add_box(s["p"],Vector3(side*1.39,2.03,z),Vector3(0.11,1.60,0.08),color.lightened(0.08))
	for end: float in [-1,1]:
		LowPolyBuilder.add_box(s["p"],Vector3(0,2.02,end*4.35),Vector3(2.66,1.52,0.11),color)
	for side: float in [-1,1]:
		LowPolyBuilder.add_box(s["t"],Vector3(side*0.94,1.65,4.42),Vector3(0.16,0.18,0.035),WARM)
	return _finish(s,false,true)
