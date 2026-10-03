## Shared measurements for visible stairs, NPC routes, ground sampling and path snaps.
class_name StationAccess
extends RefCounted

const RISERS := 7
const TREAD := 0.38
const WIDTH := 1.9

static func describe(level: int) -> Dictionary:
	var data := EpochCatalog.epoch(level)
	var width := float(data["width"])
	var length := float(data["length"])
	return {"level":level,"back":1.78+width,"z":7.4 if level==1 else length*0.34,"width":width,"length":length,"height":TrainCar.RAIL_TOP+TrainMeshes.STEP_UPPER_Y}

static func platform_local(point: Vector3, data: Dictionary) -> bool:
	return point.x>=1.5 and point.x<=float(data["back"])+0.03 and absf(point.z)<=float(data["length"])/2+0.2

static func ground_local(point: Vector3, data: Dictionary) -> float:
	var back := float(data["back"])
	var height := float(data["height"])
	if point.x>=back and point.x<back+RISERS*TREAD and absf(point.z-float(data["z"]))<=WIDTH/2:
		return height*(RISERS-clampi(floori((point.x-back)/TREAD),0,RISERS-1))/RISERS
	if platform_local(point,data):
		var edge := float(data["length"])/2
		if int(data.get("level",1))>=2 and absf(point.z)>edge-StationMeshes.RAMP_LENGTH:
			return height*clampf((edge-absf(point.z))/StationMeshes.RAMP_LENGTH,0,1)
		return height
	return NAN

static func local_path(from: Vector3, to: Vector3, data: Dictionary) -> PackedVector3Array:
	var result := PackedVector3Array([from])
	var start_platform := platform_local(from,data)
	var end_platform := platform_local(to,data)
	var lane := 2.65
	var back := float(data["back"])
	var z := float(data["z"])
	var height := float(data["height"])
	if start_platform==end_platform:
		if start_platform:
			result.append(Vector3(lane,height,from.z))
			result.append(Vector3(lane,height,to.z))
		result.append(to)
		return result
	var outside := to if start_platform else from
	# Stay outside the building wings until the official entrance is reached.
	var bypass := maxf(back+RISERS*TREAD+0.7,float(data.get("outside_x",20.8)))
	var entry := PackedVector3Array([
		outside,Vector3(maxf(bypass,outside.x),outside.y,outside.z),
		Vector3(maxf(bypass,outside.x),0,z),Vector3(back+RISERS*TREAD+0.30,0,z),
		Vector3(back-0.25,height,z),Vector3(lane,height,z)])
	if start_platform:
		result.append(Vector3(lane,height,from.z))
		entry.reverse()
	else:
		result.clear()
	for point in entry:
		if result.is_empty() or result[-1].distance_to(point)>0.04:
			result.append(point)
	if not start_platform:
		result.append(Vector3(lane,height,to.z))
	result.append(to)
	return result
