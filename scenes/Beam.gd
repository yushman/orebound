class_name Beam
extends RefCounted

static func layer(entry: Dictionary, broken: Dictionary) -> Dictionary:
	if broken.has(entry["key"]):
		return {}
	return entry


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
