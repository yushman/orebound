class_name ShipFlight
extends RefCounted


static func reference_body(pos: Vector2, t: float) -> int:
	return GravityField.dominant(pos, t)


static func step(state: ShipState, input: ShipInput, t: float, dt: float) -> ShipState:
	var p: ShipParams = Tuning.ship
	var s := state.copy()
	var ang_acc := input.turn * p.turn_accel
	if input.has_heading:
		ang_acc = clampf(p.heading_gain * wrapf(input.target_heading - s.rot, -PI, PI) - 2.0 * sqrt(p.heading_gain) * s.ang_vel, -p.turn_accel, p.turn_accel)
	s.ang_vel = (s.ang_vel + ang_acc * dt) * exp(-p.spin_damping * dt)
	s.rot = wrapf(s.rot + s.ang_vel * dt, -PI, PI)
	var nose := Vector2.UP.rotated(s.rot)
	var thr := 0.0
	var a_b := Vector2.ZERO
	if input.brake:
		a_b = _brake_accel(s, t, dt, p)
	elif input.boost:
		thr = p.thrust_accel * p.boost_accel_mult
	elif input.thrust:
		thr = p.thrust_accel
	s.vel += (GravityField.accel(s.pos, t) + nose * thr + a_b) * dt
	s.pos += s.vel * dt
	if input.brake:
		s.fuel_brake += a_b.length() * dt * p.fuel_per_dv * p.brake_fuel_mult
	elif input.boost:
		s.fuel_boost += thr * dt * p.fuel_per_dv * p.boost_fuel_mult
	elif input.thrust:
		s.fuel_engine += thr * dt * p.fuel_per_dv
	return s


static func _brake_accel(s: ShipState, t: float, dt: float, p: ShipParams) -> Vector2:
	var ref := reference_body(s.pos, t)
	var r_rel := s.pos - GravityField.body_pos(ref, t)
	var body_v := GravityField.body_vel(ref, t)
	var v_rel := s.vel - body_v
	var cross := r_rel.cross(v_rel)
	var spin := 1.0 if absf(cross) < 1e-6 * r_rel.length() * v_rel.length() else signf(cross)
	var tangent := Vector2(-r_rel.y, r_rel.x).normalized() * spin
	var v_target := body_v + tangent * GravityField.circular_speed(ref, s.pos, t)
	return ((v_target - s.vel) / dt).limit_length(p.brake_accel)
