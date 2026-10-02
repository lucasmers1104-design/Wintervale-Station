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
		_timber_halt(st,glow,x,width,length,height,rng)
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
	var lamps: Array[Vector3] = []
	for z: float in [-length*0.28,length*0.28]:
		StationMeshes.add_bench(st,Vector3(x+width*0.25,height,z),rng)
		if level >= 2:
			StationMeshes.add_planter(st,Vector3(x+width*0.22,height,z+2),rng)
		lamps.append(_lantern_post(st,glow,Vector3(x+width/2-0.3,height,z)))
	if level >= 2:
		# Verschneite Reste auf dem geräumten Pflaster, Gepäckkarren und Kannen.
		_snow_patches(st,x,width,length,height,rng)
		_luggage_cart(st,Vector3(x+0.35,height,-length*0.15),rng)
		_milk_churns(st,Vector3(x+width/2-0.5,height,-length*0.36))
	# Safety edge is real geometry and shares the game's door-step height.
	LowPolyBuilder.add_box(st,Vector3(1.86,height+0.014,0),Vector3(0.11,0.025,length-3),Color(0.94,0.81,0.42))
	var sign_at := Vector3(x,height,length*0.36)
	var sign_y: float
	var sign_face: float
	if definition["design"] == "timber":
		sign_y = _timber_sign(st,sign_at,2.3)
		sign_face = 0.066
	else:
		sign_y = StationMeshes.add_sign(st,sign_at,2.2)
		sign_face = 0.042
	if level>=3:
		var shed := FreightMeshes.goods_shed()
		var receiving := Transform3D(Basis.IDENTITY,Vector3(5,0,length*0.57))
		st.append_from(shed["body"],0,receiving)
		if shed.get("glow"):
			glow.append_from(shed["glow"],0,receiving)
	return {"paint":st.commit(),"glow":glow.commit(),"center_x":x,"height":height,"lamps":lamps,"sign_at":sign_at,"sign_y":sign_y,"sign_face":sign_face}

static func _shelter(st: SurfaceTool, glow: SurfaceTool, at: Vector3, width: float, length: float) -> void:
	for sx: float in [-1,1]:
		for sz: float in [-1,1]:
			LowPolyBuilder.add_box(st,at+Vector3(sx*width/2,1.2,sz*length/2),Vector3(0.16,2.4,0.16),WOOD)
	LowPolyBuilder.add_box(st,at+Vector3(width/2,1.25,0),Vector3(0.10,2.4,length),WOOD)
	_roof(st,at+Vector3(0,2.45,0),width+0.5,length+0.5,0.5,ROOF)
	_snow_roof(st,at+Vector3(0,2.5,0),width+0.42,length+0.3,0.5)
	LowPolyBuilder.add_box(glow,at+Vector3(0,2.3,0),Vector3(0.3,0.15,0.3),GLASS)

static func _house(st: SurfaceTool, glow: SurfaceTool, at: Vector3, size: Vector3, color: Color, roof: Color) -> void:
	LowPolyBuilder.add_box(st,at+Vector3(0,size.y/2,0),size,color)
	LowPolyBuilder.add_box(st,at+Vector3(0,0.16,0),Vector3(size.x+0.3,0.32,size.z+0.3),IRON.lightened(0.2))
	_roof(st,at+Vector3(0,size.y,0),size.x+0.6,size.z+0.6,1.25,roof)
	_snow_roof(st,at+Vector3(0,size.y+0.07,0),size.x+0.5,size.z+0.4,1.25)
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
	_snow_roof(st,at+Vector3(0,height+0.06,0),width+0.5,width+0.5,1.1)
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


# --- Holz-Haltepunkt und Bahnsteig-Ausstattung ------------------------------

const PLANK := Color(0.5,0.33,0.2)
const FASCIA := Color(0.33,0.2,0.13)
const SHINGLE := Color(0.36,0.2,0.16)
const LAMP_IRON := Color(0.15,0.15,0.17)
const SNOW := StationMeshes.SNOW
const PAPER := Color(0.93,0.9,0.82)


## Bretterdeck auf Stelzen mit Stirnblenden, Zaun mit Durchgang und kleiner
## Treppe dort, wo die Reisenden zum Ort laufen, Unterstand und Kleinkram.
static func _timber_halt(st: SurfaceTool, glow: SurfaceTool, x: float, width: float, length: float, height: float, rng: RandomNumberGenerator) -> void:
	var back := x+width/2
	var count := int(length/0.32)
	for i in count:
		var z := -length/2+(i+0.5)*length/count
		LowPolyBuilder.add_box(st,Vector3(x,height-0.06,z),Vector3(width,0.12,length/count-0.035),PLANK.lightened(rng.randf_range(-0.04,0.07)))
	for side: float in [-1,1]:
		LowPolyBuilder.add_box(st,Vector3(x+side*(width/2-0.35),height-0.22,0),Vector3(0.2,0.2,length),FASCIA)
		LowPolyBuilder.add_box(st,Vector3(x+side*(width/2-0.04),height-0.17,0),Vector3(0.08,0.3,length+0.05),FASCIA)
	# Stelzen bis unter die Geländelinie, dazwischen Kreuzstreben.
	var z := -length/2+0.4
	var bay := 0
	while z <= length/2-0.3:
		for side: float in [-1,1]:
			var px := x+side*(width/2-0.2)
			LowPolyBuilder.add_box(st,Vector3(px,(height-0.3-0.7)/2,z),Vector3(0.2,height-0.3+0.7,0.2),FASCIA.darkened(0.1))
			if bay%2 == 0 and z+2.6 <= length/2:
				LowPolyBuilder.add_beam(st,Vector3(px+side*0.11,0.0,z),Vector3(px+side*0.11,height-0.32,z+2.6),0.08,FASCIA)
		z += 2.6
		bay += 1
	# Schneewehe an der Rückkante und einzelne Flecken auf den Brettern.
	LowPolyBuilder.add_box(st,Vector3(back-0.33,height+0.03,0),Vector3(0.5,0.06,length-1.2),SNOW)
	_snow_patches(st,x,width,length,height,rng)
	_fence(st,back-0.07,height,-length/2+0.45,length/2-0.45,Vector2(6.3,8.5))
	# Treppe durch die Zaunlücke zum Ortsweg.
	for step in 3:
		var stair_height := height*(3-step)/3.0
		LowPolyBuilder.add_box(st,Vector3(back+0.22+step*0.42,stair_height/2,7.4),Vector3(0.44,stair_height,1.7),PLANK.darkened(0.05*step))
		LowPolyBuilder.add_box(st,Vector3(back+0.22+step*0.42,stair_height+0.012,7.4),Vector3(0.3,0.02,1.4),SNOW)
	for side: float in [-1,1]:
		LowPolyBuilder.add_beam(st,Vector3(back,height+0.9,7.4+side*0.9),Vector3(back+1.3,0.9,7.4+side*0.9),0.06,FASCIA)
		LowPolyBuilder.add_box(st,Vector3(back+1.3,0.45,7.4+side*0.9),Vector3(0.08,0.9,0.08),FASCIA)
	# Endtreppen mit Handläufen.
	for end: float in [-1,1]:
		for step in 3:
			var stair_height := height*(3-step)/3.0
			LowPolyBuilder.add_box(st,Vector3(x,stair_height/2,end*(length/2+0.23+step*0.43)),Vector3(1.6,stair_height,0.46),PLANK.darkened(0.04*step))
		for side: float in [-1,1]:
			LowPolyBuilder.add_beam(st,Vector3(x+side*0.86,height+0.9,end*(length/2-0.1)),Vector3(x+side*0.86,0.9,end*(length/2+1.3)),0.06,FASCIA)
			LowPolyBuilder.add_box(st,Vector3(x+side*0.86,0.45,end*(length/2+1.3)),Vector3(0.08,0.9,0.08),FASCIA)
	_timber_shelter(st,glow,Vector3(x+0.5,height,-2.0),2.0,4.4,rng)
	_luggage_cart(st,Vector3(x+0.15,height,3.4),rng)
	_milk_churns(st,Vector3(back-0.45,height,-8.7))
	_crates(st,Vector3(back-0.5,height,4.3),rng)
	for end: float in [-1,1]:
		StationMeshes.add_planter(st,Vector3(back-0.5,height,end*(length/2-1.1)),rng)


## Unterstand mit Satteldach, Bretter-Rückwand, Fenster, Bank, Fahrplan und Laterne.
static func _timber_shelter(st: SurfaceTool, glow: SurfaceTool, at: Vector3, width: float, length: float, rng: RandomNumberGenerator) -> void:
	var h := 2.45
	var wall_x := at.x+width/2-0.05
	for sx: float in [-1,1]:
		for sz: float in [-1,1]:
			LowPolyBuilder.add_box(st,at+Vector3(sx*(width/2-0.08),h/2,sz*(length/2-0.08)),Vector3(0.16,h,0.16),FASCIA)
	# Rückwand aus senkrechten Brettern mit kleinem Fenster.
	var boards := int(length/0.22)
	for i in boards:
		var bz := at.z-length/2+(i+0.5)*length/boards
		var tint := PLANK.darkened(0.12).lightened(rng.randf_range(-0.03,0.05))
		if absf(bz-at.z) < 0.45:
			LowPolyBuilder.add_box(st,Vector3(wall_x,at.y+0.6,bz),Vector3(0.06,1.2,length/boards-0.02),tint)
			LowPolyBuilder.add_box(st,Vector3(wall_x,at.y+(h+1.9)/2,bz),Vector3(0.06,h-1.9,length/boards-0.02),tint)
		else:
			LowPolyBuilder.add_box(st,Vector3(wall_x,at.y+h/2,bz),Vector3(0.06,h,length/boards-0.02),tint)
	LowPolyBuilder.add_box(glow,Vector3(wall_x,at.y+1.55,at.z),Vector3(0.03,0.68,0.88),GLASS)
	for y: float in [1.2,1.9]:
		LowPolyBuilder.add_box(st,Vector3(wall_x,at.y+y,at.z),Vector3(0.1,0.07,1.0),StationMeshes.VALANCE)
	for wz: float in [-0.48,0.0,0.48]:
		LowPolyBuilder.add_box(st,Vector3(wall_x,at.y+1.55,at.z+wz),Vector3(0.1,0.72,0.06),StationMeshes.VALANCE)
	# Windschutz an den Seiten (halbe Tiefe).
	for sz: float in [-1,1]:
		LowPolyBuilder.add_box(st,at+Vector3(width*0.22,0.95,sz*(length/2-0.05)),Vector3(width*0.52,1.5,0.06),FASCIA.lightened(0.06))
	# Bank an der Rückwand, Blick zum Gleis.
	for bz: float in [-1.4,1.4]:
		LowPolyBuilder.add_box(st,Vector3(wall_x-0.3,at.y+0.22,at.z+bz),Vector3(0.45,0.44,0.06),LAMP_IRON)
	for i in 3:
		LowPolyBuilder.add_box(st,Vector3(wall_x-0.45+i*0.13,at.y+0.46,at.z),Vector3(0.11,0.04,3.0),PLANK.lightened(0.05))
	LowPolyBuilder.add_box(st,Vector3(wall_x-0.08,at.y+0.75,at.z),Vector3(0.04,0.14,3.0),PLANK.lightened(0.05))
	# Fahrplan-Aushang neben dem Fenster.
	LowPolyBuilder.add_box(st,Vector3(wall_x-0.04,at.y+1.55,at.z+1.15),Vector3(0.03,0.62,0.5),FASCIA)
	LowPolyBuilder.add_box(st,Vector3(wall_x-0.06,at.y+1.55,at.z+1.15),Vector3(0.02,0.54,0.42),PAPER)
	for row in 5:
		LowPolyBuilder.add_box(st,Vector3(wall_x-0.075,at.y+1.72-row*0.08,at.z+1.15),Vector3(0.01,0.02,0.32),FASCIA)
	# Satteldach mit Überstand, Schneedecke, Zierbrettern und Eiszapfen.
	var roof_at := at+Vector3(0,h,0)
	_roof(st,roof_at,width+0.7,length+0.6,0.75,SHINGLE)
	_snow_roof(st,roof_at+Vector3(0,0.07,0),width+0.62,length+0.4,0.75)
	for side: float in [-1,1]:
		StationMeshes._valance(st,Vector3(at.x+side*(width+0.7)/2,at.y+h-0.02,at.z),length+0.6,side,rng)
	# Hängelaterne unter dem First.
	LowPolyBuilder.add_box(st,roof_at+Vector3(0,0.35,0.9),Vector3(0.03,0.6,0.03),LAMP_IRON)
	LowPolyBuilder.add_box(glow,roof_at+Vector3(0,-0.1,0.9),Vector3(0.2,0.26,0.2),GLASS)
	LowPolyBuilder.add_cone(st,roof_at+Vector3(0,0.03,0.9),0.18,0.14,4,LAMP_IRON,PI/4)


## Schneedecke auf einem Satteldach (nur die beiden Dachflächen, schmilzt im Frühling).
static func _snow_roof(st: SurfaceTool, at: Vector3, width: float, length: float, rise: float) -> void:
	for side: float in [-1,1]:
		var a := at+Vector3(side*width/2,0,-length/2)
		var b := at+Vector3(side*width/2,0,length/2)
		var c := at+Vector3(0,rise,length/2)
		var d := at+Vector3(0,rise,-length/2)
		LowPolyBuilder.add_triangle_facing(st,a,b,c,SNOW,Vector3.UP)
		LowPolyBuilder.add_triangle_facing(st,a,c,d,SNOW,Vector3.UP)


## Holzzaun mit Pfosten, zwei Latten und Schneekappen; [param gap] lässt einen Durchgang frei.
static func _fence(st: SurfaceTool, fx: float, height: float, z0: float, z1: float, gap: Vector2) -> void:
	var z := z0
	while z <= z1+0.01:
		if z < gap.x-0.05 or z > gap.y+0.05:
			LowPolyBuilder.add_box(st,Vector3(fx,height+0.45,z),Vector3(0.09,0.9,0.09),FASCIA)
			LowPolyBuilder.add_box(st,Vector3(fx,height+0.92,z),Vector3(0.13,0.05,0.13),SNOW)
		z += 1.5
	for run: Vector2 in [Vector2(z0,gap.x),Vector2(gap.y,z1)]:
		var mid := (run.x+run.y)/2
		var span := run.y-run.x
		if span <= 0.1:
			continue
		for y: float in [0.38,0.76]:
			LowPolyBuilder.add_box(st,Vector3(fx,height+y,mid),Vector3(0.05,0.09,span),PLANK.darkened(0.1))
		LowPolyBuilder.add_box(st,Vector3(fx,height+0.82,mid),Vector3(0.07,0.035,span*0.92),SNOW)


## Gusseiserner Laternenmast mit Glaslaterne (leuchtet nachts). Rückgabe: Lichtpunkt.
static func _lantern_post(st: SurfaceTool, glow: SurfaceTool, base: Vector3) -> Vector3:
	LowPolyBuilder.add_box(st,base+Vector3(0,0.12,0),Vector3(0.3,0.24,0.3),LAMP_IRON)
	LowPolyBuilder.add_cylinder(st,base+Vector3(0,0.24,0),0.07,0.05,2.36,8,LAMP_IRON)
	LowPolyBuilder.add_box(st,base+Vector3(0,2.62,0),Vector3(0.14,0.06,0.14),LAMP_IRON)
	var lamp := base+Vector3(0,2.65,0)
	LowPolyBuilder.add_box(st,lamp+Vector3(0,0.02,0),Vector3(0.34,0.04,0.34),LAMP_IRON)
	LowPolyBuilder.add_box(glow,lamp+Vector3(0,0.22,0),Vector3(0.25,0.36,0.25),GLASS)
	for cx: float in [-1,1]:
		for cz: float in [-1,1]:
			LowPolyBuilder.add_box(st,lamp+Vector3(cx*0.14,0.22,cz*0.14),Vector3(0.035,0.4,0.035),LAMP_IRON)
	LowPolyBuilder.add_cone(st,lamp+Vector3(0,0.42,0),0.27,0.22,4,LAMP_IRON,PI/4)
	LowPolyBuilder.add_cone(st,lamp+Vector3(0,0.46,0),0.2,0.14,4,SNOW,PI/4,false)
	LowPolyBuilder.add_box(st,lamp+Vector3(0,0.66,0),Vector3(0.05,0.08,0.05),LAMP_IRON)
	return lamp+Vector3(0,0.22,0)


## Ortsschild aus Holz: grüne Tafel im Cremerahmen unter einem kleinen Dach.
## Rückgabe: Höhe der Tafelmitte (für die Beschriftung).
static func _timber_sign(st: SurfaceTool, at: Vector3, board_width: float) -> float:
	var board_y := 2.0
	for z: float in [-board_width*0.45,board_width*0.45]:
		LowPolyBuilder.add_box(st,at+Vector3(0,(board_y+0.3)/2,z),Vector3(0.12,board_y+0.3,0.12),FASCIA)
	LowPolyBuilder.add_box(st,at+Vector3(0,board_y,0),Vector3(0.1,0.64,board_width+0.12),StationMeshes.VALANCE)
	LowPolyBuilder.add_box(st,at+Vector3(0,board_y,0),Vector3(0.12,0.52,board_width),StationMeshes.SIGN_GREEN)
	LowPolyBuilder.add_box(st,at+Vector3(0,board_y+0.38,0),Vector3(0.36,0.06,board_width+0.3),FASCIA)
	LowPolyBuilder.add_box(st,at+Vector3(0,board_y+0.43,0),Vector3(0.32,0.05,board_width+0.2),SNOW)
	return board_y


## Verschneite Stellen auf dem Bahnsteig (abseits der Bahnsteigkante).
static func _snow_patches(st: SurfaceTool, x: float, width: float, length: float, height: float, rng: RandomNumberGenerator) -> void:
	# Zwei gegeneinander gedrehte Platten je Fleck – wirkt wie zusammengewehter Schnee.
	for i in int(length/2.6):
		var spot := Vector3(rng.randf_range(x-width*0.1,x+width/2-0.5),height+0.012,rng.randf_range(-length/2+1.0,length/2-1.0))
		for k in 2:
			var turn := Basis(Vector3.UP,rng.randf_range(-0.6,0.6))
			var offset := Vector3(rng.randf_range(-0.12,0.12),k*0.004,rng.randf_range(-0.15,0.15))
			LowPolyBuilder.add_oriented_box(st,Transform3D(turn,spot+offset),Vector3(rng.randf_range(0.25,0.55),0.02,rng.randf_range(0.25,0.6)),SNOW)


## Gepäckkarren mit zwei Koffern und einer Hutschachtel.
static func _luggage_cart(st: SurfaceTool, at: Vector3, rng: RandomNumberGenerator) -> void:
	LowPolyBuilder.add_box(st,at+Vector3(0,0.42,0),Vector3(0.8,0.06,1.3),PLANK.darkened(0.08))
	for side: float in [-1,1]:
		LowPolyBuilder.add_box(st,at+Vector3(side*0.38,0.52,0),Vector3(0.04,0.14,1.3),FASCIA)
		LowPolyBuilder.add_cylinder_between(st,at+Vector3(side*0.46,0.22,-0.3),at+Vector3(side*0.4,0.22,-0.3),0.22,10,LAMP_IRON)
		LowPolyBuilder.add_box(st,at+Vector3(side*0.3,0.2,0.5),Vector3(0.05,0.4,0.05),LAMP_IRON)
		LowPolyBuilder.add_beam(st,at+Vector3(side*0.3,0.45,0.62),at+Vector3(side*0.3,1.0,1.0),0.04,LAMP_IRON)
	LowPolyBuilder.add_beam(st,at+Vector3(-0.32,1.0,1.0),at+Vector3(0.32,1.0,1.0),0.05,PLANK)
	var leather := Color(0.55,0.3,0.18).lightened(rng.randf_range(-0.05,0.05))
	LowPolyBuilder.add_box(st,at+Vector3(0.04,0.62,-0.25),Vector3(0.62,0.34,0.5),leather)
	LowPolyBuilder.add_box(st,at+Vector3(0.04,0.62,-0.25),Vector3(0.64,0.06,0.52),FASCIA)
	LowPolyBuilder.add_box(st,at+Vector3(-0.04,0.92,-0.22),Vector3(0.48,0.26,0.38),Color(0.25,0.36,0.45))
	LowPolyBuilder.add_box(st,at+Vector3(-0.04,1.06,-0.22),Vector3(0.4,0.03,0.3),SNOW)
	LowPolyBuilder.add_cylinder(st,at+Vector3(0.1,0.45,0.32),0.18,0.18,0.22,10,PAPER.darkened(0.08))
	LowPolyBuilder.add_cylinder(st,at+Vector3(0.1,0.67,0.32),0.19,0.19,0.04,10,Color(0.62,0.18,0.15))


## Zwei Milchkannen aus Blech mit Schneehauben.
static func _milk_churns(st: SurfaceTool, at: Vector3) -> void:
	var tin := Color(0.62,0.64,0.66)
	for offset: Vector3 in [Vector3(0,0,0),Vector3(-0.1,0,0.48)]:
		var p := at+offset
		LowPolyBuilder.add_cylinder(st,p,0.2,0.2,0.48,10,tin)
		LowPolyBuilder.add_cylinder(st,p+Vector3(0,0.48,0),0.2,0.12,0.1,10,tin.darkened(0.05))
		LowPolyBuilder.add_cylinder(st,p+Vector3(0,0.58,0),0.13,0.13,0.06,10,tin.darkened(0.15))
		LowPolyBuilder.add_cylinder(st,p+Vector3(0,0.63,0),0.11,0.08,0.03,10,SNOW)
		LowPolyBuilder.add_cylinder(st,p+Vector3(0,0.2,0),0.21,0.21,0.04,10,tin.darkened(0.2))


## Zwei gestapelte Lattenkisten mit Schnee obenauf.
static func _crates(st: SurfaceTool, at: Vector3, rng: RandomNumberGenerator) -> void:
	var stack: Array[Vector3] = [Vector3(0,0.28,0),Vector3(0,0.28,0.62),Vector3(0.02,0.84,0.3)]
	for p in stack:
		var tint := PLANK.lightened(rng.randf_range(0.0,0.1))
		LowPolyBuilder.add_box(st,at+p,Vector3(0.56,0.56,0.56),tint)
		for y: float in [-0.18,0.0,0.18]:
			LowPolyBuilder.add_box(st,at+p+Vector3(0,y,0),Vector3(0.58,0.05,0.58),tint.darkened(0.12))
	LowPolyBuilder.add_box(st,at+Vector3(0.02,1.135,0.3),Vector3(0.5,0.04,0.5),SNOW)
