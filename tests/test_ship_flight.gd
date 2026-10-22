extends GutTest

const DT := 1.0 / 60.0

var _saved_field


func before_each():
	_saved_field = Tuning.field


func after_each():
	Tuning.field = _saved_field


func _state(pos := Vector2(600, 0), vel := Vector2.ZERO, rot := 0.0) -> ShipState:
	var s := ShipState.new()
	s.pos = pos
	s.vel = vel
	s.rot = rot
	return s


func _same(a: ShipState, b: ShipState) -> bool:
	return a.pos == b.pos and a.vel == b.vel and a.rot == b.rot and a.ang_vel == b.ang_vel \
		and a.fuel_engine == b.fuel_engine and a.fuel_boost == b.fuel_boost


func test_thrust_accelerates_along_the_nose() -> void:
	var rot := 0.7
	var coast := ShipFlight.step(_state(Vector2(600, 0), Vector2.ZERO, rot), ShipInput.new(), 1.0, DT)
	var inp := ShipInput.new()
	inp.thrust = true
	var burn := ShipFlight.step(_state(Vector2(600, 0), Vector2.ZERO, rot), inp, 1.0, DT)
	var dv := burn.vel - coast.vel
	var expected := Vector2.UP.rotated(coast.rot) * Tuning.ship.thrust_accel * DT
	assert_almost_eq(dv, expected, Vector2(1e-3, 1e-3))
	assert_gt(expected.length(), 0.0)


func test_gravity_applied_semi_implicit() -> void:
	var s := _state(Vector2(600, 0))
	var out := ShipFlight.step(s, ShipInput.new(), 1.0, DT)
	var v := GravityField.accel(Vector2(600, 0), 1.0) * DT
	assert_almost_eq(out.vel, v, Vector2(1e-3, 1e-3))
	assert_almost_eq(out.pos, Vector2(600, 0) + v * DT, Vector2(1e-4, 1e-4))


func test_step_is_deterministic_and_does_not_mutate() -> void:
	var s := _state(Vector2(500, 100), Vector2(10, -20), 0.3)
	var s_before := s.copy()
	var inp := ShipInput.new()
	inp.thrust = true
	inp.turn = 1.0
	var inp_before := inp.copy()
	var a := ShipFlight.step(s, inp, 2.0, DT)
	var b := ShipFlight.step(s, inp, 2.0, DT)
	assert_true(_same(a, b))
	assert_ne(a, s)
	assert_true(_same(s, s_before))
	assert_eq(inp.turn, inp_before.turn)
	assert_eq(inp.thrust, inp_before.thrust)
	assert_eq(inp.boost, inp_before.boost)
	assert_eq(inp.has_heading, inp_before.has_heading)


func test_turn_input_accelerates_rotation() -> void:
	var inp := ShipInput.new()
	inp.turn = 1.0
	var out := ShipFlight.step(_state(), inp, 0.0, DT)
	var p: ShipParams = Tuning.ship
	var expected := p.turn_accel * DT * exp(-p.spin_damping * DT)
	assert_almost_eq(out.ang_vel, expected, 1e-5)
	assert_almost_eq(out.rot, expected * DT, 1e-6)
	inp.turn = -1.0
	assert_lt(ShipFlight.step(_state(), inp, 0.0, DT).ang_vel, 0.0)


func test_spin_damping_decays_ang_vel_without_turn_input() -> void:
	var s := _state()
	s.ang_vel = 3.0
	var out := ShipFlight.step(s, ShipInput.new(), 0.0, DT)
	assert_almost_eq(out.ang_vel, 3.0 * exp(-Tuning.ship.spin_damping * DT), 1e-5)
	for i in 120:
		out = ShipFlight.step(out, ShipInput.new(), 0.0, DT)
	assert_lt(absf(out.ang_vel), 0.01)


func test_target_heading_converges() -> void:
	var inp := ShipInput.new()
	inp.has_heading = true
	inp.target_heading = 2.0
	var s := _state()
	for i in 300:
		s = ShipFlight.step(s, inp, 0.0, DT)
	assert_almost_eq(s.rot, 2.0, 0.01)
	assert_lt(absf(s.ang_vel), 0.01)


func test_target_heading_takes_shortest_way() -> void:
	var inp := ShipInput.new()
	inp.has_heading = true
	inp.target_heading = -PI + 0.2
	var s := _state(Vector2(600, 0), Vector2.ZERO, PI - 0.2)
	var out := ShipFlight.step(s, inp, 0.0, DT)
	assert_gt(out.ang_vel, 0.0)


func test_boost_costs_boost_fuel_mult_times_more_fuel_per_delta_v() -> void:
	var p: ShipParams = Tuning.ship
	var thrust := ShipInput.new()
	thrust.thrust = true
	var boost := ShipInput.new()
	boost.boost = true
	var e := _state()
	var b := _state()
	for i in 30:
		e = ShipFlight.step(e, thrust, 0.0, DT)
		b = ShipFlight.step(b, boost, 0.0, DT)
	var dv_e := p.thrust_accel * 30 * DT
	var dv_b := p.thrust_accel * p.boost_accel_mult * 30 * DT
	assert_almost_eq(e.fuel_engine, dv_e * p.fuel_per_dv, 1e-6)
	assert_almost_eq(b.fuel_boost, dv_b * p.fuel_per_dv * p.boost_fuel_mult, 1e-6)
	assert_almost_eq((b.fuel_boost / dv_b) / (e.fuel_engine / dv_e), p.boost_fuel_mult, 1e-4)
	assert_eq(e.fuel_boost, 0.0)
	assert_eq(b.fuel_engine, 0.0)


func test_boost_alone_thrusts_with_boost_accel() -> void:
	var p: ShipParams = Tuning.ship
	var coast := ShipFlight.step(_state(), ShipInput.new(), 0.0, DT)
	var boost := ShipInput.new()
	boost.boost = true
	var out := ShipFlight.step(_state(), boost, 0.0, DT)
	var expected := Vector2.UP * p.thrust_accel * p.boost_accel_mult * DT
	assert_almost_eq(out.vel - coast.vel, expected, Vector2(1e-3, 1e-3))


func test_thrust_with_boost_uses_only_boost() -> void:
	var both := ShipInput.new()
	both.thrust = true
	both.boost = true
	var out := ShipFlight.step(_state(), both, 0.0, DT)
	assert_eq(out.fuel_engine, 0.0)
	assert_gt(out.fuel_boost, 0.0)


func test_no_thrust_uses_no_fuel() -> void:
	var out := ShipFlight.step(_state(), ShipInput.new(), 0.0, DT)
	assert_eq(out.fuel_engine, 0.0)
	assert_eq(out.fuel_boost, 0.0)


func test_circular_orbit_keeps_radius_within_1_percent_over_several_orbits() -> void:
	var f := FieldParams.new()
	f.k = 1000.0
	f.eps = 1.0
	var planet := BodyParams.new()
	planet.mass = 1000.0
	planet.p = 1.0
	var bodies: Array[BodyParams] = [planet]
	f.bodies = bodies
	Tuning.field = f
	var r := 600.0
	var speed := sqrt(r * GravityField.accel(Vector2(r, 0), 0.0).length())
	var s := _state(Vector2(r, 0), Vector2(0, speed))
	var angle := 0.0
	var prev := s.pos.angle()
	var max_dev := 0.0
	for i in int(5.0 * TAU * r / speed / DT):
		s = ShipFlight.step(s, ShipInput.new(), i * DT, DT)
		max_dev = maxf(max_dev, absf(s.pos.length() - r) / r)
		var a := s.pos.angle()
		angle += wrapf(a - prev, -PI, PI)
		prev = a
	assert_lt(max_dev, 0.01)
	assert_gt(absf(angle), 4.5 * TAU)
