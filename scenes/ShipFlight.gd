class_name ShipFlight
extends RefCounted


static func step(state: ShipState, input: ShipInput, t: float, dt: float) -> ShipState:
	var p: ShipParams = Tuning.ship
	var s := state.copy()
	var ang_acc := input.turn * p.turn_accel
	if input.has_heading:
		ang_acc = clampf(p.heading_gain * wrapf(input.target_heading - s.rot, -PI, PI), -p.turn_accel, p.turn_accel)
	s.ang_vel = (s.ang_vel + ang_acc * dt) * exp(-p.spin_damping * dt)
	s.rot += s.ang_vel * dt
	var nose := Vector2.UP.rotated(s.rot)
	var thr := 0.0
	if input.boost:
		thr = p.thrust_accel * p.boost_accel_mult
	elif input.thrust:
		thr = p.thrust_accel
	s.vel += (GravityField.accel(s.pos, t) + nose * thr) * dt
	s.pos += s.vel * dt
	if input.boost:
		s.fuel_boost += thr * dt * p.fuel_per_dv * p.boost_fuel_mult
	elif input.thrust:
		s.fuel_engine += thr * dt * p.fuel_per_dv
	return s
