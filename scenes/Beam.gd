class_name Beam
extends RefCounted

const MIN_REMAINING := 1e-3


static func layer(entry: Dictionary, mined: Dictionary) -> Dictionary:
	var key: Vector3i = entry["key"]
	if not mined.has(key):
		return entry
	var remaining: float = minf(mined[key], float(entry["amount"]))
	if remaining <= MIN_REMAINING:
		return {}
	var k := sqrt(remaining / float(entry["amount"]))
	var out := entry.duplicate()
	out["radius"] = float(entry["radius"]) * k
	var pts := PackedVector2Array()
	for p in entry["points"] as PackedVector2Array:
		pts.append(p * k)
	out["points"] = pts
	out["amount"] = remaining
	return out


## aim is a world direction vector or a world angle.
static func hit(pos: Vector2, aim: Variant, range_: float, candidates: Array) -> Dictionary:
	var dir: Vector2 = aim if aim is Vector2 else Vector2.from_angle(aim)
	var end := pos + dir * range_
	var best := {}
	var best_d := INF
	for c in candidates:
		var pts: PackedVector2Array = c["points"]
		var n := pts.size()
		if n < 2:
			continue
		var cpos: Vector2 = c["pos"]
		var rot: float = c["rot"]
		for i in n:
			var a := cpos + pts[i].rotated(rot)
			var b := cpos + pts[(i + 1) % n].rotated(rot)
			var p: Variant = Geometry2D.segment_intersects_segment(pos, end, a, b)
			if p == null:
				continue
			var d := pos.distance_to(p)
			if d < best_d:
				best_d = d
				best = {"key": c["key"], "point": p}
	return best
