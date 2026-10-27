class_name ShipPrediction
extends RefCounted

const NARROW_MARGIN := 800.0


static func run(state: ShipState, input: ShipInput, tick: int, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var s := state
	var vmax := AsteroidField.max_speed()
	var q := maxf(Tuning.planet.ast_radius_min, Tuning.planet.ast_radius_max)
	if input.drift_sync:
		q = maxf(q, Tuning.ship.sync_radius)
	if input.beam:
		q += Tuning.ship.beam_range
	var full: Array = []
	var cover := -1.0
	var c0 := Vector2.ZERO
	var t0 := 0.0
	var local: Array = []
	var centre := Vector2.ZERO
	var t_c := -INF
	for i in steps:
		var t := GravityField.time_at(tick + i + 1)
		if cover < 0.0 or s.pos.distance_to(c0) + s.vel.length() * GravityField.DT + 1.0 + vmax * (t - t0) + q + NARROW_MARGIN > cover:
			cover = (s.vel.length() + vmax) * (steps - i) * GravityField.DT + q + 2.0 * NARROW_MARGIN
			c0 = s.pos
			t0 = t
			full = AsteroidField.near(c0, t0, cover)
			t_c = -INF
		if t_c == -INF or s.pos.distance_to(centre) + s.vel.length() * GravityField.DT + 1.0 + vmax * (t - t_c) + q > q + NARROW_MARGIN:
			centre = s.pos
			t_c = t
			local = []
			for a in full:
				if AsteroidField.at(a, t)["pos"].distance_to(centre) <= q + NARROW_MARGIN:
					local.append(a)
		s = ShipFlight.step(s, input, t, GravityField.DT, local)
		pts.append(s.pos)
		if s.crashed:
			break
	return pts
