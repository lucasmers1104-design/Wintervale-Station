## Six separately composed station architectures, built into two batched meshes.
class_name EpochStationMeshes
extends RefCounted

const WOOD := Color(0.47,0.31,0.18)
const CREAM := Color(0.89,0.82,0.64)
const BRICK := Color(0.53,0.25,0.19)
const IRON := Color(0.19,0.25,0.27)
const ROOF := Color(0.22,0.28,0.31)
const GLASS := Color(0.95,0.72,0.35)

static func build(level: int) -> Dictionary:
	var definition := EpochCatalog.epoch(level)
	var st := TrainMeshes._new_st()
	var glow := TrainMeshes._new_st()
	var length := float(definition["length"])
	var width := float(definition["width"])
	var height := TrainCar.RAIL_TOP + TrainMeshes.STEP_UPPER_Y
	var x := 1.78 + width * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 3300 + level
	if definition["design"] == "timber":
		for i in int(length / 0.32):
			LowPolyBuilder.add_box(st,Vector3(x,height-0.10,-length/2+(i+0.5)*0.32),Vector3(width,0.20,0.29),WOOD.lightened((i%3)*0.035))
		for z: float in [-8,-4,0,4,8]:
			for side: float in [-1,1]:
				LowPolyBuilder.add_box(st,Vector3(x+side*(width/2-0.2),height/2,z),Vector3(0.22,height,0.22),WOOD.darkened(0.2))
		_shelter(st,glow,Vector3(x+0.25,height,0),2.2,3.8)
		for end: float in [-1,1]:
			for step in 3:
				var stair_height := height*(3-step)/3.0
				LowPolyBuilder.add_box(st,Vector3(x,stair_height/2,end*(length/2+0.23+step*0.43)),Vector3(1.6,stair_height,0.46),WOOD)
	else:
		st.append_from(StationMeshes.create_platform(length,width,height,rng),0,Transform3D(Basis.IDENTITY,Vector3(x,0,0)))
		match String(definition["design"]):
			"country":
				_house(st,glow,Vector3(x+width/2+2.0,height,0),Vector3(3.7,3.2,7),CREAM,Color(0.47,0.21,0.15))
				_shelter(st,glow,Vector3(x,height,5),2.6,5)
			"village":
				_house(st,glow,Vector3(x+width/2+2.6,height,-3),Vector3(5,4.8,11),BRICK,ROOF)
				_house(st,glow,Vector3(x+width/2+2.6,height,6),Vector3(5,2.8,5),CREAM,ROOF)
				StationMeshes.add_canopy(st,Vector3(x,height,-4),17,width+0.4,3.4,rng)
				_clock_tower(st,glow,Vector3(x+width/2+2.5,height,-9),2.5,6.7)
			"town":
				_house(st,glow,Vector3(x+width/2+3.5,height,-3),Vector3(6.5,6,10),CREAM,ROOF)
				for end: float in [-1,1]:
					_house(st,glow,Vector3(x+width/2+3.5,height,end*10),Vector3(6.5,3.4,5),BRICK,ROOF)
				StationMeshes.add_canopy(st,Vector3(x,height,0),30,width+0.8,3.8,rng)
				LowPolyBuilder.add_box(st,Vector3(x+width+5,height+0.1,0),Vector3(6,0.18,28),Color(0.5,0.51,0.48))
			"city":
				for end: float in [-1,1]:
					_house(st,glow,Vector3(x+width/2+4,height,end*12),Vector3(7.5,7,9),BRICK,ROOF)
				_hall(st,glow,Vector3(x+width/2+4,height,0),7.5,16,7.0)
				_clock_tower(st,glow,Vector3(x+width/2+4,height,-17),3.8,10.2)
				StationMeshes.add_canopy(st,Vector3(x,height,0),44,width+0.8,4.2,rng)
			"central":
				_hall(st,glow,Vector3(x+width/2+6,height,0),11,36,10)
				for end: float in [-1,1]:
					_house(st,glow,Vector3(x+width/2+6,height,end*24),Vector3(11,8.6,10),CREAM,ROOF)
					_clock_tower(st,glow,Vector3(x+width/2+6,height,end*30),4,12)
				StationMeshes.add_canopy(st,Vector3(x,height,0),70,width+1.1,5.0,rng)
				for z: float in [-35,-18,0,18,35]:
					LowPolyBuilder.add_beam(st,Vector3(x,height+4.6,z),Vector3(x+width+5,height+5.8,z),0.18,IRON)
	for z: float in [-length*0.28,length*0.28]:
		StationMeshes.add_bench(st,Vector3(x+width*0.25,height,z),rng)
		if level >= 2:
			StationMeshes.add_planter(st,Vector3(x+width*0.22,height,z+2),rng)
		LowPolyBuilder.add_box(st,Vector3(x+width/2-0.3,height+1.5,z),Vector3(0.10,3,0.10),IRON)
		LowPolyBuilder.add_box(glow,Vector3(x+width/2-0.3,height+3.05,z),Vector3(0.30,0.28,0.30),GLASS)
	# Safety edge is real geometry and shares the game's door-step height.
	LowPolyBuilder.add_box(st,Vector3(1.86,height+0.014,0),Vector3(0.11,0.025,length-3),Color(0.94,0.81,0.42))
	StationMeshes.add_sign(st,Vector3(x,height,length*0.36),2.2)
	if level>=3:
		var shed := FreightMeshes.goods_shed()
		var receiving := Transform3D(Basis.IDENTITY,Vector3(5,0,length*0.57))
		st.append_from(shed["body"],0,receiving)
		if shed.get("glow"):
			glow.append_from(shed["glow"],0,receiving)
	return {"paint":st.commit(),"glow":glow.commit(),"center_x":x,"height":height}

static func _shelter(st: SurfaceTool, glow: SurfaceTool, at: Vector3, width: float, length: float) -> void:
	for sx: float in [-1,1]:
		for sz: float in [-1,1]:
			LowPolyBuilder.add_box(st,at+Vector3(sx*width/2,1.2,sz*length/2),Vector3(0.16,2.4,0.16),WOOD)
	LowPolyBuilder.add_box(st,at+Vector3(width/2,1.25,0),Vector3(0.10,2.4,length),WOOD)
	_roof(st,at+Vector3(0,2.45,0),width+0.5,length+0.5,0.5,ROOF)
	LowPolyBuilder.add_box(glow,at+Vector3(0,2.3,0),Vector3(0.3,0.15,0.3),GLASS)

static func _house(st: SurfaceTool, glow: SurfaceTool, at: Vector3, size: Vector3, color: Color, roof: Color) -> void:
	LowPolyBuilder.add_box(st,at+Vector3(0,size.y/2,0),size,color)
	LowPolyBuilder.add_box(st,at+Vector3(0,0.16,0),Vector3(size.x+0.3,0.32,size.z+0.3),IRON.lightened(0.2))
	_roof(st,at+Vector3(0,size.y,0),size.x+0.6,size.z+0.6,1.25,roof)
	for floor_index in maxi(1,int(size.y/2.7)):
		for z in range(int(-size.z/2)+1,int(size.z/2),2):
			var p := at+Vector3(-size.x/2-0.015,1.7+floor_index*2.6,z)
			LowPolyBuilder.add_box(st,p,Vector3(0.12,1.25,1.05),CREAM.lightened(0.08))
			LowPolyBuilder.add_box(glow,p+Vector3(-0.075,0,0),Vector3(0.025,1.02,0.82),GLASS)
	LowPolyBuilder.add_box(st,at+Vector3(-size.x/2-0.10,1.1,0),Vector3(0.12,2.2,1.3),WOOD.darkened(0.15))
	LowPolyBuilder.add_box(st,at+Vector3(-size.x/2-0.8,0.10,0),Vector3(1.5,0.20,2.2),CREAM)
	LowPolyBuilder.add_box(st,at+Vector3(size.x*0.22,size.y+0.8,size.z*0.28),Vector3(0.65,1.7,0.65),BRICK)

static func _roof(st: SurfaceTool, at: Vector3, width: float, length: float, rise: float, color: Color) -> void:
	for side: float in [-1,1]:
		var a := at+Vector3(side*width/2,0,-length/2)
		var b := at+Vector3(side*width/2,0,length/2)
		var c := at+Vector3(0,rise,length/2)
		var d := at+Vector3(0,rise,-length/2)
		LowPolyBuilder.add_triangle_facing(st,a,b,c,color,Vector3.UP)
		LowPolyBuilder.add_triangle_facing(st,a,c,d,color,Vector3.UP)
	for end: float in [-1,1]:
		LowPolyBuilder.add_triangle_facing(st,at+Vector3(-width/2,0,end*length/2),at+Vector3(width/2,0,end*length/2),at+Vector3(0,rise,end*length/2),color.darkened(0.08),Vector3(0,0,end))

static func _clock_tower(st: SurfaceTool, glow: SurfaceTool, at: Vector3, width: float, height: float) -> void:
	LowPolyBuilder.add_box(st,at+Vector3(0,height/2,0),Vector3(width,height,width),CREAM)
	_roof(st,at+Vector3(0,height,0),width+0.6,width+0.6,1.1,ROOF)
	var face := at+Vector3(-width/2-0.02,height-1.2,0)
	LowPolyBuilder.add_cylinder_between(glow,face,face-Vector3(0.05,0,0),0.65,16,CREAM.lightened(0.08))
	LowPolyBuilder.add_beam(st,face-Vector3(0.07,0,0),face+Vector3(-0.07,0.42,0),0.06,IRON)
	LowPolyBuilder.add_beam(st,face-Vector3(0.08,0,0),face+Vector3(-0.08,0.12,0.32),0.06,IRON)

static func _hall(st: SurfaceTool, glow: SurfaceTool, at: Vector3, width: float, length: float, height: float) -> void:
	# Faceted barrel roof with glazed clerestory and individual structural ribs.
	for z in range(int(-length/2),int(length/2)+1,4):
		for side: float in [-1,1]:
			LowPolyBuilder.add_box(st,at+Vector3(side*width/2,height*0.34,z),Vector3(0.24,height*0.68,0.24),IRON)
		for i in 8:
			var t0 := PI*i/8.0
			var t1 := PI*(i+1)/8.0
			var a := at+Vector3(cos(t0)*width/2,height*0.64+sin(t0)*height*0.36,z)
			var b := at+Vector3(cos(t1)*width/2,height*0.64+sin(t1)*height*0.36,z)
			LowPolyBuilder.add_beam(st,a,b,0.16,IRON)
			if z < length/2:
				LowPolyBuilder.add_triangle_facing(glow,a,b,b+Vector3(0,0,4),Color(0.39,0.53,0.54),Vector3.UP)
				LowPolyBuilder.add_triangle_facing(glow,a,b+Vector3(0,0,4),a+Vector3(0,0,4),Color(0.39,0.53,0.54),Vector3.UP)
	LowPolyBuilder.add_box(st,at+Vector3(0,0.14,0),Vector3(width,0.28,length),CREAM)
