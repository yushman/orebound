class_name ShipPrediction
extends RefCounted


static func run(state: ShipState, input: ShipInput, tick: int, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var s := state
	for i in steps:
		s = ShipFlight.step(s, input, GravityField.time_at(tick + i + 1), GravityField.DT)
		pts.append(s.pos)
		if s.crashed:
			break
	return pts
