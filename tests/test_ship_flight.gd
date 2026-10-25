extends GutTest

const DT := 1.0 / 60.0

var _saved_field
var _saved_sync_radius := 0.0
var _saved_drag := 0.0
var _saved_damage := 0.0


func before_each():
	_saved_field = Tuning.field
	_saved_sync_radius = Tuning.ship.sync_radius
	_saved_drag = Tuning.planet.atmosphere_drag
	_saved_damage = Tuning.planet.atmosphere_damage
	Tuning.planet.atmosphere_drag = 0.0
	Tuning.planet.atmosphere_damage = 0.0


func after_each():
	Tuning.field = _saved_field
	Tuning.ship.sync_radius = _saved_sync_radius
	Tuning.planet.atmosphere_drag = _saved_drag
	Tuning.planet.atmosphere_damage = _saved_damage


func _state(pos := Vector2(600, 0), vel := Vector2.ZERO, rot := 0.0) -> ShipState:
	var s := ShipState.new()
	s.pos = pos
	s.vel = vel
	s.rot = rot
	return s


func _same(a: ShipState, b: ShipState) -> bool:
	return a.pos == b.pos and a.vel == b.vel and a.rot == b.rot and a.ang_vel == b.ang_vel \
		and a.fuel_engine == b.fuel_engine and a.fuel_boost == b.fuel_boost \
		and a.fuel_soft_brake == b.fuel_soft_brake and a.fuel_sync == b.fuel_sync \
		and a.hold_time == b.hold_time and a.heat == b.heat and a.hull == b.hull and a.crashed == b.crashed


func test_thrust_accelerates_along_the_nose() -> void:
	var rot := 0.7
	var start := _state(Vector2(600, 0), Vector2.ZERO, rot)
	start.hold_time = Tuning.ship.ramp_time
	var coast := ShipFlight.step(start.copy(), ShipInput.new(), 1.0, DT)
	var inp := ShipInput.new()
	inp.thrust = true
	var burn := ShipFlight.step(start, inp, 1.0, DT)
	var dv := burn.vel - coast.vel
	var expected := Vector2.UP.rotated(coast.rot) * Tuning.ship.thrust_accel * DT
	assert_almost_eq(dv, expected, Vector2(1e-3, 1e-3))
	assert_gt(expected.length(), 0.0)


func test_thrust_ramps_from_weak_to_full_over_ramp_time() -> void:
	var p: ShipParams = Tuning.ship
	var inp := ShipInput.new()
	inp.thrust = true
	var coast := ShipFlight.step(_state(), ShipInput.new(), 0.0, DT)
	var first := ShipFlight.step(_state(), inp, 0.0, DT)
	# first step from cold start: hold_time = dt, scale lerp(ramp_min_fraction, 1, dt / ramp_time)
	var first_scale := lerpf(p.ramp_min_fraction, 1.0, DT / p.ramp_time)
	assert_almost_eq((first.vel - coast.vel).length(), p.thrust_accel * first_scale * DT, 1e-4)
	assert_gte((first.vel - coast.vel).length(), p.ramp_min_fraction * p.thrust_accel * DT - 1e-6)
	assert_almost_eq(first.hold_time, DT, 1e-9)
	var warm := first
	for i in 89:
		warm = ShipFlight.step(warm, inp, (i + 1) * DT, DT)
	var warm_coast := ShipFlight.step(warm.copy(), ShipInput.new(), 90 * DT, DT)
	var full := ShipFlight.step(warm, inp, 90 * DT, DT)
	assert_almost_eq((full.vel - warm_coast.vel).length(), p.thrust_accel * DT, 1e-3)
	assert_almost_eq(full.hold_time, 91 * DT, 1e-9)
	# отпускание сбрасывает hold_time — следующий тап снова слабый
	var released := ShipFlight.step(full, ShipInput.new(), 91 * DT, DT)
	assert_almost_eq(released.hold_time, 0.0, 1e-9)


func test_gravity_applied_semi_implicit() -> void:
	var s := _state(Vector2(600, 0))
	var out := ShipFlight.step(s, ShipInput.new(), 1.0, DT)
	var v := (GravityField.accel(Vector2(600, 0), 1.0) + GravityField.frame_accel(Vector2(600, 0), Vector2.ZERO)) * DT
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
	var dv_e := 0.0
	var dv_b := 0.0
	for i in 30:
		e = ShipFlight.step(e, thrust, i * DT, DT)
		b = ShipFlight.step(b, boost, i * DT, DT)
		# рамп: масштаб шага k = (k·dt)/ramp_time, пока не достигнет 1
		var scale := lerpf(p.ramp_min_fraction, 1.0, minf((i + 1) * DT / p.ramp_time, 1.0))
		dv_e += p.thrust_accel * scale * DT
		dv_b += p.thrust_accel * p.boost_accel_mult * scale * DT
	assert_almost_eq(e.fuel_engine, dv_e * p.fuel_per_dv, 1e-6)
	assert_almost_eq(b.fuel_boost, dv_b * p.fuel_per_dv * p.boost_fuel_mult, 1e-6)
	assert_almost_eq((b.fuel_boost / dv_b) / (e.fuel_engine / dv_e), p.boost_fuel_mult, 1e-4)
	assert_eq(e.fuel_boost, 0.0)
	assert_eq(b.fuel_engine, 0.0)


func test_boost_alone_thrusts_with_boost_accel() -> void:
	var p: ShipParams = Tuning.ship
	var start := _state()
	start.hold_time = p.ramp_time
	var coast := ShipFlight.step(start.copy(), ShipInput.new(), 0.0, DT)
	var boost := ShipInput.new()
	boost.boost = true
	var out := ShipFlight.step(start, boost, 0.0, DT)
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


func test_band_drift_orbit_keeps_radius_within_1_percent_over_several_revolutions() -> void:
	var f := FieldParams.new()
	f.k = 1000.0
	f.eps = 1.0
	# calm omega_f: the explicit Coriolis of semi-implicit Euler adds a secular
	# drift proportional to omega_f, which must stay small against the 1% bound
	f.carrier_orbit_radius = 50000.0
	var planet := BodyParams.new()
	planet.mass = 1000.0
	planet.p = 1.0
	var bodies: Array[BodyParams] = [planet]
	f.bodies = bodies
	Tuning.field = f
	var r := 2000.0
	var band: float = GravityField.circular_speed(0, Vector2(r, 0), 0.0) - GravityField.frame_omega() * r
	var s := _state(Vector2(r, 0), Vector2(0, band))
	var angle := 0.0
	var prev := s.pos.angle()
	var max_dev := 0.0
	for i in int(2.0 * TAU * r / absf(band) / DT):
		s = ShipFlight.step(s, ShipInput.new(), i * DT, DT)
		max_dev = maxf(max_dev, absf(s.pos.length() - r) / r)
		var a := s.pos.angle()
		angle += wrapf(a - prev, -PI, PI)
		prev = a
	assert_lt(max_dev, 0.01)
	assert_gt(absf(angle), 1.8 * TAU)


func test_ship_at_rest_at_carrier_stays_in_place() -> void:
	_planet_field(1.0)
	var rc: float = Tuning.field.carrier_orbit_radius
	var s := _state(Vector2(rc, 0), Vector2.ZERO)
	var max_dev := 0.0
	for i in 180:
		s = ShipFlight.step(s, ShipInput.new(), i * DT, DT)
		max_dev = maxf(max_dev, s.pos.distance_to(Vector2(rc, 0)))
	assert_lt(max_dev, 0.1)
	assert_lt(s.vel.length(), 0.1)


func _three_body_field() -> void:
	# own planet + two moons so the test does not read the default field
	var f := FieldParams.new()
	f.k = 1000.0
	f.eps = 1.0
	f.fade_width = 0.5
	f.carrier_orbit_radius = 5000.0
	var planet := BodyParams.new()
	planet.mass = 1000.0
	planet.p = 1.0
	var moon1 := BodyParams.new()
	moon1.parent = 0
	moon1.orbit_radius = 300.0
	moon1.angular_speed = 0.5
	moon1.mass = 50.0
	moon1.p = 2.0
	moon1.influence_radius = 60.0
	var moon2 := BodyParams.new()
	moon2.parent = 0
	moon2.orbit_radius = 500.0
	moon2.angular_speed = -0.3
	moon2.phase = 2.0
	moon2.mass = 5.0
	moon2.p = 2.0
	moon2.influence_radius = 60.0
	var bodies: Array[BodyParams] = [planet, moon1, moon2]
	f.bodies = bodies
	Tuning.field = f


func test_reference_body_returns_dominant_body_near_moon1_and_planet_at_spawn() -> void:
	_three_body_field()
	var t := 0.0
	var spawn := Vector2(600.0, 0.0)
	assert_eq(ShipFlight.reference_body(spawn, t), GravityField.dominant(spawn, t))
	assert_eq(ShipFlight.reference_body(spawn, t), 0)
	var near_moon := GravityField.body_pos(1, t) + Vector2(2, 0)
	assert_eq(ShipFlight.reference_body(near_moon, t), GravityField.dominant(near_moon, t))
	assert_eq(ShipFlight.reference_body(near_moon, t), 1)


func _planet_field(p: float) -> void:
	var f := FieldParams.new()
	f.k = 1000.0
	f.eps = 1.0
	# calm omega_f keeps the rotating-frame step numerically tame for the
	# brake tolerances (see test_band_drift_orbit...)
	f.carrier_orbit_radius = 5000.0
	var planet := BodyParams.new()
	planet.mass = 1000.0
	planet.p = p
	var bodies: Array[BodyParams] = [planet]
	f.bodies = bodies
	Tuning.field = f


func _soft_brake_input() -> ShipInput:
	var inp := ShipInput.new()
	inp.soft_brake = true
	return inp


func _soft_brake_accel_of(start: ShipState) -> Vector2:
	var coast := ShipFlight.step(start.copy(), ShipInput.new(), 0.0, DT)
	var out := ShipFlight.step(start, _soft_brake_input(), 0.0, DT)
	return (out.vel - coast.vel) / DT


func test_soft_brake_geometry_full_quarter_and_null() -> void:
	var p: ShipParams = Tuning.ship
	var f: float = p.brake_accel
	# у матки гравитация и центробежное гасятся построением — измерение точное
	var rc := Vector2(Tuning.field.carrier_orbit_radius, 0.0)
	# нос (rot = 0) — вверх: −n̂ = (0, 1)
	var along := _soft_brake_accel_of(_state(rc, Vector2(0, -5), 0.0))
	assert_almost_eq(along, Vector2(0, 1) * f, Vector2(1e-3, 1e-3))
	var quarter := _soft_brake_accel_of(_state(rc, Vector2(5, 0), 0.0))
	assert_almost_eq(quarter.length(), f / sqrt(2.0), 1e-3)
	var opposite := _soft_brake_accel_of(_state(rc, Vector2(0, 5), 0.0))
	assert_almost_eq(opposite.length(), 0.0, 1e-3)
	# почти нулевая скорость — слабый толчок от носа
	var slow := _soft_brake_accel_of(_state(rc, Vector2.ZERO, 0.0))
	assert_almost_eq(slow, Vector2(0, 1) * f * 0.5, Vector2(1e-3, 1e-3))


func test_brake_accel_per_step_is_clamped_at_brake_accel() -> void:
	_planet_field(1.0)
	var p: ShipParams = Tuning.ship
	var s := _state(Vector2(600, 0), Vector2(0, -900), 0.0)
	var inp := _soft_brake_input()
	var max_ab := 0.0
	for i in 120:
		var g := GravityField.accel(s.pos, i * DT) + GravityField.frame_accel(s.pos, s.vel)
		var out := ShipFlight.step(s, inp, i * DT, DT)
		max_ab = maxf(max_ab, ((out.vel - s.vel) / DT - g).length())
		s = out
	assert_lte(max_ab, p.brake_accel + 1e-2)
	assert_gt(max_ab, p.brake_accel - 0.1)


func test_held_soft_brake_ignores_thrust_and_boost_and_accrues_fuel_soft_brake_only() -> void:
	_planet_field(1.0)
	var p: ShipParams = Tuning.ship
	var v := GravityField.circular_speed(0, Vector2(600, 0), 0.0)
	var start := _state(Vector2(600, 0), Vector2(0, v * 1.2))
	var brake := _soft_brake_input()
	var all := _soft_brake_input()
	all.thrust = true
	all.boost = true
	var a := start
	var b := start
	var dv := 0.0
	for i in 30:
		var out := ShipFlight.step(a, brake, i * DT, DT)
		dv += ((out.vel - a.vel) / DT - GravityField.accel(a.pos, i * DT) - GravityField.frame_accel(a.pos, a.vel)).length() * DT
		a = out
		b = ShipFlight.step(b, all, i * DT, DT)
	assert_true(_same(a, b))
	assert_eq(a.fuel_engine, 0.0)
	assert_eq(a.fuel_boost, 0.0)
	assert_gt(a.fuel_soft_brake, 0.0)
	assert_almost_eq(a.fuel_soft_brake, dv * p.fuel_per_dv * p.brake_fuel_mult, 1e-6)
	var coast := start
	for i in 30:
		coast = ShipFlight.step(coast, ShipInput.new(), i * DT, DT)
	assert_eq(coast.fuel_soft_brake, 0.0)


func test_soft_brake_does_not_block_rotation() -> void:
	var inp := _soft_brake_input()
	inp.turn = 1.0
	var out := ShipFlight.step(_state(), inp, 0.0, DT)
	assert_gt(out.ang_vel, 0.0)
	assert_gt(out.rot, 0.0)


func _max_heading_overshoot(target: float) -> float:
	var inp := ShipInput.new()
	inp.has_heading = true
	inp.target_heading = target
	var s := _state()
	var peak := 0.0
	for i in 300:
		s = ShipFlight.step(s, inp, 0.0, DT)
		peak = maxf(peak, s.rot - target)
	return peak / target


func test_target_heading_overshoot_is_small() -> void:
	for target in [0.3, 1.0, 2.0, 3.0]:
		assert_lt(_max_heading_overshoot(target), 0.05, "target %s" % target)


func test_rotation_stays_wrapped() -> void:
	var s := _state(Vector2(600, 0), Vector2.ZERO, 10.0 * PI)
	s.ang_vel = 5.0
	for i in 600:
		s = ShipFlight.step(s, ShipInput.new(), 0.0, DT)
		assert_between(s.rot, -PI, PI)


func _gentle_field() -> void:
	# слабое поле: силы тел и матки заметно меньше sync_accel
	var f := FieldParams.new()
	f.k = 1000.0
	f.eps = 1.0
	f.carrier_orbit_radius = 5000.0
	var planet := BodyParams.new()
	planet.mass = 10.0
	planet.p = 2.0
	var moon := BodyParams.new()
	moon.parent = 0
	moon.orbit_radius = 500.0
	moon.angular_speed = 0.05
	moon.mass = 1.0
	moon.p = 2.0
	var bodies: Array[BodyParams] = [planet, moon]
	f.bodies = bodies
	Tuning.field = f


func _drift_sync_input() -> ShipInput:
	var inp := ShipInput.new()
	inp.drift_sync = true
	return inp


func _no_reference_nearby() -> void:
	# сжимаем sync_radius: планета и матка вне радиуса — работает фолбэк
	Tuning.ship.sync_radius = 100.0


func test_sync_reference_picks_nearest_candidate_within_sync_radius() -> void:
	_three_body_field()
	var t := 0.0
	var near_moon := GravityField.body_pos(1, t) + Vector2(2, 0)
	var r_moon: Dictionary = ShipFlight.sync_reference(near_moon, t)
	assert_true(r_moon.valid)
	assert_false(r_moon.is_carrier)
	assert_eq(r_moon.index, 1)
	# ближе планета, но луна ещё ближе — побеждает ближайший, не первый
	var between: Dictionary = ShipFlight.sync_reference(Vector2(1500, 0), t)
	assert_true(between.valid)
	assert_eq(between.index, 1)
	var rc: float = Tuning.field.carrier_orbit_radius
	var r_carrier: Dictionary = ShipFlight.sync_reference(Vector2(rc, 0), t)
	assert_true(r_carrier.valid)
	assert_true(r_carrier.is_carrier)
	assert_false(ShipFlight.sync_reference(Vector2(2500, 2500), t).valid)


func test_sync_priority_soft_brake_beats_sync_beats_boost_beats_thrust() -> void:
	_planet_field(1.0)
	var start := _state(Vector2(600, 0), Vector2(0, 4), 0.0)
	var all := ShipInput.new()
	all.soft_brake = true
	all.drift_sync = true
	all.boost = true
	all.thrust = true
	var brake_only := _soft_brake_input()
	assert_true(_same(
		ShipFlight.step(start, all, 0.0, DT),
		ShipFlight.step(start, brake_only, 0.0, DT)
	))
	var sync_all := ShipInput.new()
	sync_all.drift_sync = true
	sync_all.boost = true
	sync_all.thrust = true
	var c := ShipFlight.step(start, sync_all, 0.0, DT)
	var d := ShipFlight.step(start, _drift_sync_input(), 0.0, DT)
	assert_true(_same(c, d))
	assert_eq(c.fuel_engine, 0.0)
	assert_eq(c.fuel_boost, 0.0)
	assert_gt(c.fuel_sync, 0.0)


func test_sync_to_carrier_kills_relative_velocity() -> void:
	_gentle_field()
	var rc: float = Tuning.field.carrier_orbit_radius
	var s := _state(Vector2(rc, 30.0), Vector2(2.0, -3.0))
	var inp := _drift_sync_input()
	for i in 300:
		s = ShipFlight.step(s, inp, i * DT, DT)
	assert_lt(s.vel.length(), 0.01)
	assert_gt(s.fuel_sync, 0.0)


func test_sync_to_body_matches_body_velocity() -> void:
	_gentle_field()
	var inp := _drift_sync_input()
	var near := GravityField.body_pos(1, 0.0) + Vector2(100, 0)
	var s := _state(near, GravityField.body_vel(1, 0.0) + Vector2(3.0, -4.0))
	for i in 400:
		s = ShipFlight.step(s, inp, i * DT, DT)
	assert_lt(s.vel.distance_to(GravityField.body_vel(1, 400 * DT)), 0.1)


func _check_sync_fallback_converges(p: float, steps: int) -> void:
	_planet_field(p)
	_no_reference_nearby()
	var r := 600.0
	var band: float = GravityField.circular_speed(0, Vector2(r, 0), 0.0) - GravityField.frame_omega() * r
	var s := _state(Vector2(r, 0), Vector2(band * 0.3, band * 1.3))
	var inp := _drift_sync_input()
	for i in steps:
		s = ShipFlight.step(s, inp, i * DT, DT)
	var target := absf(GravityField.circular_speed(0, s.pos, steps * DT) - GravityField.frame_omega() * s.pos.length())
	assert_almost_eq(s.vel.length(), target, target * 0.03)
	assert_almost_eq(s.vel.dot(s.pos.normalized()), 0.0, target * 0.05)


func test_sync_fallback_converges_to_band_drift_p1() -> void:
	_check_sync_fallback_converges(1.0, 6000)


func test_sync_fallback_converges_to_band_drift_p2() -> void:
	_check_sync_fallback_converges(2.0, 6000)


func test_sync_fallback_keeps_retrograde_retrograde() -> void:
	_planet_field(1.0)
	_no_reference_nearby()
	var v := GravityField.circular_speed(0, Vector2(600, 0), 0.0)
	var s := _state(Vector2(600, 0), Vector2(v * 0.2, -v * 1.2))
	var inp := _drift_sync_input()
	for i in 5000:
		s = ShipFlight.step(s, inp, i * DT, DT)
		assert_lt(s.pos.cross(s.vel), 0.0)


func test_sync_fallback_on_almost_radial_velocity_uses_spawn_direction() -> void:
	_planet_field(1.0)
	_no_reference_nearby()
	var band: float = GravityField.circular_speed(0, Vector2(600, 0), 0.0) - GravityField.frame_omega() * 600.0
	var s := _state(Vector2(600, 0), Vector2(10.0, -1e-9))
	var out := ShipFlight.step(s, _drift_sync_input(), 0.0, DT)
	assert_gt(out.vel.y * signf(band), 0.0)


func test_sync_accel_is_clamped_per_step_and_accrues_sync_fuel() -> void:
	_gentle_field()
	var p: ShipParams = Tuning.ship
	var rc: float = Tuning.field.carrier_orbit_radius
	var inp := _drift_sync_input()
	var s := _state(Vector2(rc, 0), Vector2(50.0, 0))
	var max_a := 0.0
	var dv := 0.0
	for i in 30:
		var g := GravityField.accel(s.pos, i * DT) + GravityField.frame_accel(s.pos, s.vel)
		var out := ShipFlight.step(s, inp, i * DT, DT)
		var a := (out.vel - s.vel) / DT - g
		max_a = maxf(max_a, a.length())
		dv += a.length() * DT
		s = out
	assert_lte(max_a, p.sync_accel + 1e-2)
	assert_gt(max_a, p.sync_accel - 0.1)
	assert_almost_eq(s.fuel_sync, dv * p.fuel_per_dv * p.sync_fuel_mult, 1e-6)
	assert_eq(s.fuel_engine, 0.0)
	assert_eq(s.fuel_boost, 0.0)
	assert_eq(s.fuel_soft_brake, 0.0)


func _engine_dv(start: ShipState, inp: ShipInput) -> float:
	var coast := ShipFlight.step(start.copy(), ShipInput.new(), 0.0, DT)
	var out := ShipFlight.step(start, inp, 0.0, DT)
	return (out.vel - coast.vel).length()


func test_heat_grows_on_engine_and_boost_and_cools_without_engine() -> void:
	var p: ShipParams = Tuning.ship
	var thrust := ShipInput.new()
	thrust.thrust = true
	var out := ShipFlight.step(_state(), thrust, 0.0, DT)
	assert_almost_eq(out.heat, p.heat_growth_engine * DT, 1e-9)
	var boost := ShipInput.new()
	boost.boost = true
	out = ShipFlight.step(_state(), boost, 0.0, DT)
	assert_almost_eq(out.heat, p.heat_growth_boost * DT, 1e-9)
	var warm := _state()
	warm.heat = 0.5
	out = ShipFlight.step(warm, ShipInput.new(), 0.0, DT)
	assert_almost_eq(out.heat, 0.5 - p.heat_cooldown * DT, 1e-9)
	var hot := _state()
	hot.heat = 1.0
	for i in 60:
		hot = ShipFlight.step(hot, thrust, i * DT, DT)
	assert_almost_eq(hot.heat, 1.0, 1e-9)
	var cold := _state()
	cold.heat = 0.0001
	cold = ShipFlight.step(cold, ShipInput.new(), 0.0, DT)
	assert_almost_eq(cold.heat, 0.0, 1e-9)


func test_thrust_scale_falls_linearly_above_heat_threshold() -> void:
	var p: ShipParams = Tuning.ship
	var inp := ShipInput.new()
	inp.thrust = true
	var at_threshold := _state()
	at_threshold.hold_time = p.ramp_time
	at_threshold.heat = p.heat_threshold
	assert_almost_eq(_engine_dv(at_threshold, inp), p.thrust_accel * DT, 1e-3)
	var mid := _state()
	mid.hold_time = p.ramp_time
	mid.heat = 0.5 * (p.heat_threshold + 1.0)
	var mid_scale := 0.5 * (1.0 + p.min_thrust_fraction)
	assert_almost_eq(_engine_dv(mid, inp), p.thrust_accel * mid_scale * DT, 1e-3)
	var maxed := _state()
	maxed.hold_time = p.ramp_time
	maxed.heat = 1.0
	assert_almost_eq(_engine_dv(maxed, inp), p.thrust_accel * p.min_thrust_fraction * DT, 1e-3)
	# форсаж наследует масштаб нагрева — умножает ту же базовую тягу
	var boost := ShipInput.new()
	boost.boost = true
	var hot_boost := _state()
	hot_boost.hold_time = p.ramp_time
	hot_boost.heat = 1.0
	assert_almost_eq(_engine_dv(hot_boost, boost), p.thrust_accel * p.min_thrust_fraction * p.boost_accel_mult * DT, 1e-3)


func test_heat_never_grows_on_soft_brake_and_drift_sync() -> void:
	var p: ShipParams = Tuning.ship
	var braking := _state(Vector2(600, 0), Vector2(0, 4))
	braking.heat = 0.4
	var braked := ShipFlight.step(braking, _soft_brake_input(), 0.0, DT)
	assert_almost_eq(braked.heat, 0.4 - p.heat_cooldown * DT, 1e-9)
	_gentle_field()
	var rc: float = Tuning.field.carrier_orbit_radius
	var syncing := _state(Vector2(rc, 30.0), Vector2(2.0, -3.0))
	syncing.heat = 0.4
	var synced := ShipFlight.step(syncing, _drift_sync_input(), 0.0, DT)
	assert_almost_eq(synced.heat, 0.4 - p.heat_cooldown * DT, 1e-9)


func _check_band_drift_sync(r: float, v_rel_tangential: float) -> void:
	Tuning.field = load("res://presets/p1.tres").field.duplicate(true)
	var pos := Vector2(0.0, r)
	var tangent := Vector2(-1.0, 0.0)
	var s := _state(pos, tangent * v_rel_tangential)
	var inp := _drift_sync_input()
	for i in 1500:
		s = ShipFlight.step(s, inp, i * DT, DT)
	var drift: float = GravityField.circular_speed(0, s.pos, 1500 * DT) - GravityField.frame_omega() * s.pos.length()
	var ccw := Vector2(-s.pos.y, s.pos.x).normalized()
	assert_almost_eq(s.vel.dot(ccw), drift, absf(drift) * 0.05 + 0.05)
	assert_almost_eq(s.vel.dot(s.pos.normalized()), 0.0, 0.5)


func test_sync_fallback_band_drift_below_carrier_from_both_directions() -> void:
	_check_band_drift_sync(110000.0, 45.0)
	_check_band_drift_sync(110000.0, -45.0)


func test_sync_fallback_band_drift_above_carrier_from_both_directions() -> void:
	_check_band_drift_sync(125000.0, 13.3)
	_check_band_drift_sync(125000.0, -13.3)


func test_atmosphere_density_zero_at_edge_one_at_surface_and_rises_toward_surface() -> void:
	var f := Tuning.field
	var saved_shape: float = Tuning.planet.density_shape
	var surface: float = f.planet_surface_radius
	var edge: float = f.atmosphere_edge
	Tuning.planet.density_shape = 2.0
	assert_eq(ShipFlight.atmosphere_density(Vector2(edge, 0)), 0.0)
	assert_eq(ShipFlight.atmosphere_density(Vector2(0, edge + 5000.0)), 0.0)
	assert_eq(ShipFlight.atmosphere_density(Vector2(surface, 0)), 1.0)
	assert_eq(ShipFlight.atmosphere_density(Vector2(surface - 10.0, 0)), 1.0)
	var mid := Vector2(0, 0.5 * (surface + edge))
	assert_almost_eq(ShipFlight.atmosphere_density(mid), 0.25, 1e-3)
	var upper := ShipFlight.atmosphere_density(Vector2(surface + 0.75 * (edge - surface), 0))
	var lower := ShipFlight.atmosphere_density(Vector2(surface + 0.25 * (edge - surface), 0))
	assert_gt(upper, 0.0)
	assert_gt(lower, upper)
	Tuning.planet.density_shape = 1.0
	assert_almost_eq(ShipFlight.atmosphere_density(mid), 0.5, 1e-3)
	Tuning.planet.density_shape = saved_shape


func _with_drag(drag: float) -> void:
	Tuning.planet.atmosphere_drag = drag


func test_atmospheric_drag_scales_velocity_inside_and_is_absent_above_the_edge() -> void:
	var saved_drag := _saved_drag
	var saved_dmg := _saved_damage
	Tuning.planet.atmosphere_damage = 0.0
	var f := Tuning.field
	var inside := Vector2(0.5 * (f.planet_surface_radius + f.atmosphere_edge), 0)
	var above := Vector2(f.atmosphere_edge + 2000.0, 0)
	var vel := Vector2(0, 100)
	_with_drag(2.0)
	var rho := ShipFlight.atmosphere_density(inside)
	var drag_in := ShipFlight.step(_state(inside, vel), ShipInput.new(), 1.0, DT)
	var drag_above := ShipFlight.step(_state(above, vel), ShipInput.new(), 1.0, DT)
	_with_drag(0.0)
	var free_in := ShipFlight.step(_state(inside, vel), ShipInput.new(), 1.0, DT)
	var free_above := ShipFlight.step(_state(above, vel), ShipInput.new(), 1.0, DT)
	_with_drag(saved_drag)
	Tuning.planet.atmosphere_damage = saved_dmg
	var expected := vel * (exp(-2.0 * rho * DT) - 1.0)
	assert_almost_eq((drag_in.vel - free_in.vel).y, expected.y, 1e-3)
	assert_lt(drag_in.vel.length(), free_in.vel.length())
	assert_true(_same(drag_above, free_above))


func test_unforced_band_drift_below_the_edge_loses_altitude_in_the_atmosphere() -> void:
	var f := FieldParams.new()
	f.k = 1000.0
	f.eps = 1.0
	f.planet_surface_radius = 100000.0
	f.atmosphere_edge = 101500.0
	f.carrier_orbit_radius = 121500.0
	var planet := BodyParams.new()
	planet.mass = pow(121500.0, 3.0) * 0.00255 * 0.00255 / f.k
	planet.p = 2.0
	var bodies: Array[BodyParams] = [planet]
	f.bodies = bodies
	Tuning.field = f
	var saved_dmg := _saved_damage
	Tuning.planet.atmosphere_damage = 0.0
	var r := 101250.0
	var band: float = GravityField.circular_speed(0, Vector2(r, 0), 0.0) - GravityField.frame_omega() * r
	var saved_drag := _saved_drag
	var final_r := []
	for drag in [0.0, saved_drag]:
		_with_drag(drag)
		var s := _state(Vector2(r, 0), Vector2(0, band))
		for i in 900:
			s = ShipFlight.step(s, ShipInput.new(), i * DT, DT)
		final_r.append(s.pos.length())
	_with_drag(saved_drag)
	Tuning.planet.atmosphere_damage = saved_dmg
	assert_almost_eq(final_r[0], r, 0.1)
	assert_lt(final_r[1], r - 2.0)


func test_hull_ticks_only_inside_the_atmosphere_and_crash_on_surface_or_zero_hull() -> void:
	Tuning.planet.atmosphere_damage = 5.0
	var f := Tuning.field
	var inside := Vector2(0.5 * (f.planet_surface_radius + f.atmosphere_edge), 0)
	var above := Vector2(f.atmosphere_edge + 2000.0, 0)
	var rho := ShipFlight.atmosphere_density(inside)
	var hit := ShipFlight.step(_state(inside), ShipInput.new(), 1.0, DT)
	assert_almost_eq(hit.hull, Tuning.ship.hull_max - 5.0 * rho * DT, 1e-4)
	assert_false(hit.crashed)
	var free := ShipFlight.step(_state(above), ShipInput.new(), 1.0, DT)
	assert_eq(free.hull, Tuning.ship.hull_max)
	assert_false(free.crashed)
	var weak := _state(inside)
	weak.hull = 0.001
	var dead := ShipFlight.step(weak, ShipInput.new(), 1.0, DT)
	assert_eq(dead.hull, 0.0)
	assert_true(dead.crashed)
	var touch := ShipFlight.step(_state(Vector2(f.planet_surface_radius + 0.001, 0)), ShipInput.new(), 1.0, DT)
	assert_true(touch.crashed)
	var rising := _state(Vector2(f.planet_surface_radius + 1.0, 0), Vector2(0, 0))
	assert_false(ShipFlight.step(rising, ShipInput.new(), 1.0, DT).crashed)
