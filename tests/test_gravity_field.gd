extends GutTest

var _saved_field


func before_each():
	_saved_field = Tuning.field


func after_each():
	Tuning.field = _saved_field


func _body(parent: int, orbit_radius: float, angular_speed: float, phase: float) -> BodyParams:
	var b := BodyParams.new()
	b.parent = parent
	b.orbit_radius = orbit_radius
	b.angular_speed = angular_speed
	b.phase = phase
	return b


func test_moon_body_pos_follows_parent_orbit():
	var f := FieldParams.new()
	f.bodies = [_body(-1, 0.0, 0.0, 0.0), _body(0, 300.0, 0.5, 1.0), _body(1, 50.0, 2.0, 0.3)]
	Tuning.field = f
	var t := 3.7
	var om: float = GravityField.frame_omega()
	var a1 := 1.0 + (0.5 - om) * t
	var p1 := Vector2(cos(a1), sin(a1)) * 300.0
	var a2 := 0.3 + (2.0 - om) * t
	var p2 := p1 + Vector2(cos(a2), sin(a2)) * 50.0
	assert_eq(GravityField.body_pos(0, t), Vector2.ZERO)
	assert_almost_eq(GravityField.body_pos(1, t), p1, Vector2(1e-3, 1e-3))
	assert_almost_eq(GravityField.body_pos(2, t), p2, Vector2(1e-3, 1e-3))


func test_time_advances_one_sixtieth_per_tick():
	var start: int = GravityField.tick
	GravityField._physics_process(0.5)
	GravityField._physics_process(0.001)
	assert_eq(GravityField.tick, start + 2)
	assert_almost_eq(GravityField.time(), (start + 2) / 60.0, 1e-9)


func test_default_field_is_single_d35_planet() -> void:
	var f: FieldParams = _saved_field
	assert_not_null(f)
	assert_gt(f.fade_width, 0.0)
	assert_eq(f.bodies.size(), 1)
	assert_eq(f.planet_surface_radius, 100000.0)
	assert_eq(f.atmosphere_edge, 101500.0)
	assert_eq(f.carrier_orbit_radius, 121500.0)
	var planet := f.bodies[0]
	assert_eq(planet.p, 2.0)
	assert_eq(planet.parent, -1)
	assert_eq(planet.orbit_radius, 0.0)
	assert_eq(planet.influence_radius, 0.0)
	assert_almost_eq(GravityField.frame_omega(), 0.00255, 1e-6)


func _field(bodies: Array, k := 2.0, eps := 0.001, fade := 0.5) -> FieldParams:
	var f := FieldParams.new()
	f.k = k
	f.eps = eps
	f.fade_width = fade
	var arr: Array[BodyParams] = []
	for b in bodies:
		arr.append(b)
	f.bodies = arr
	return f


func _static_body(mass: float, p: float, at := Vector2.ZERO, influence := 0.0) -> BodyParams:
	var b := _body(-1, 0.0, 0.0, 0.0)
	b.mass = mass
	b.p = p
	b.influence_radius = influence
	return b


func _fd_grad(pos: Vector2, t: float) -> Vector2:
	var h := 0.01
	return Vector2(
		(GravityField.potential(pos + Vector2(h, 0), t) - GravityField.potential(pos - Vector2(h, 0), t)) / (2 * h),
		(GravityField.potential(pos + Vector2(0, h), t) - GravityField.potential(pos - Vector2(0, h), t)) / (2 * h))


func test_minus_grad_potential_matches_accel_for_p_values():
	for p in [2.0, 1.0, 1.5]:
		Tuning.field = _field([_static_body(3.0, p)])
		for pos in [Vector2(5, 0), Vector2(3, 4), Vector2(-7, 2)]:
			var a: Vector2 = GravityField.accel(pos, 0.0)
			var g := -_fd_grad(pos, 0.0)
			assert_almost_eq(a, g, Vector2(1e-3, 1e-3), "p=%s pos=%s" % [p, pos])


func test_accel_points_toward_body_with_magnitude_kM_over_r_p():
	Tuning.field = _field([_static_body(3.0, 2.0)], 2.0, 0.0)
	var a: Vector2 = GravityField.accel(Vector2(4, 0), 0.0)
	assert_almost_eq(a, Vector2(-6.0 / 16.0, 0), Vector2(1e-6, 1e-6))


func test_mixed_p_sums_per_body_contributions():
	var b1 := _static_body(3.0, 1.0)
	var b2 := _body(0, 10.0, 0.0, 0.0)
	b2.mass = 2.0
	b2.p = 2.0
	Tuning.field = _field([b1, b2], 2.0, 0.0)
	var pos := Vector2(0, 5)
	var a1 := Vector2(0, -1) * (2.0 * 3.0 / 5.0)
	var d := Vector2(10, 0) - pos
	var a2 := d.normalized() * (2.0 * 2.0 / d.length_squared())
	assert_almost_eq(GravityField.accel(pos, 0.0), a1 + a2, Vector2(1e-5, 1e-5))
	var phi := 2.0 * 3.0 * log(5.0) - 2.0 * 2.0 / d.length()
	assert_almost_eq(GravityField.potential(pos, 0.0), phi, 1e-5)


func test_same_inputs_same_outputs():
	Tuning.field = _field([_static_body(3.0, 1.5)])
	var pos := Vector2(6, 1)
	assert_eq(GravityField.accel(pos, 1.3), GravityField.accel(pos, 1.3))
	assert_eq(GravityField.potential(pos, 1.3), GravityField.potential(pos, 1.3))


func _moon_field(p := 2.0) -> void:
	Tuning.field = _field([_static_body(3.0, p, Vector2.ZERO, 10.0)], 2.0, 0.001, 0.5)


func test_moon_contribution_is_zero_beyond_fade_zone():
	_moon_field()
	for r in [15.0, 15.5, 40.0]:
		assert_eq(GravityField.accel(Vector2(r, 0), 0.0), Vector2.ZERO)
		assert_eq(GravityField.potential(Vector2(r, 0), 0.0), 0.0)


func test_moon_accel_and_potential_continuous_at_boundaries():
	_moon_field()
	for r in [10.0, 15.0]:
		var e := 1e-4
		var a_in: Vector2 = GravityField.accel(Vector2(r - e, 0), 0.0)
		var a_out: Vector2 = GravityField.accel(Vector2(r + e, 0), 0.0)
		assert_almost_eq(a_in, a_out, Vector2(1e-3, 1e-3), "accel r=%s" % r)
		assert_almost_eq(GravityField.potential(Vector2(r - e, 0), 0.0), GravityField.potential(Vector2(r + e, 0), 0.0), 1e-3, "phi r=%s" % r)


func test_moon_fade_zone_gradient_matches_accel():
	for p in [2.0, 1.0, 1.5]:
		_moon_field(p)
		for pos in [Vector2(5, 0), Vector2(11, 0), Vector2(0, 12.5), Vector2(10.6, 10.6), Vector2(14, 0)]:
			var a: Vector2 = GravityField.accel(pos, 0.0)
			assert_almost_eq(a, -_fd_grad(pos, 0.0), Vector2(1e-3, 1e-3), "p=%s pos=%s" % [p, pos])


func test_unlimited_body_has_no_fade():
	Tuning.field = _field([_static_body(3.0, 2.0)], 2.0, 0.0)
	assert_ne(GravityField.accel(Vector2(1000, 0), 0.0), Vector2.ZERO)


func test_time_at_is_tick_over_60_and_dt_is_1_60():
	assert_eq(GravityField.DT, 1.0 / 60.0)
	for n in [0, 1, 7, 90, 12345]:
		assert_eq(GravityField.time_at(n), n / 60.0)
	GravityField.tick = 77
	assert_eq(GravityField.time(), GravityField.time_at(77))
	GravityField.tick = 0


func _three_bodies() -> void:
	var planet := _static_body(50.0, 1.0)
	var m1 := _body(0, 300.0, 0.5, 1.0)
	m1.mass = 5.0
	m1.p = 2.0
	m1.influence_radius = 60.0
	var m2 := _body(0, 500.0, -0.3, 2.0)
	m2.mass = 5.0
	m2.p = 2.0
	m2.influence_radius = 60.0
	Tuning.field = _field([planet, m1, m2])


func test_accel_equals_sum_of_accel_of():
	_three_bodies()
	var t := 2.5
	for pos in [Vector2(600, 0), GravityField.body_pos(1, t) + Vector2(30, 0), Vector2(-100, 200)]:
		var sum := Vector2.ZERO
		for i in 3:
			sum += GravityField.accel_of(i, pos, t)
		assert_almost_eq(GravityField.accel(pos, t), sum, Vector2(1e-9, 1e-9))
		assert_ne(GravityField.accel_of(0, pos, t), Vector2.ZERO)


func test_dominant_returns_moon_next_to_moon1_and_planet_far_from_it():
	_three_bodies()
	var t := 1.0
	assert_eq(GravityField.dominant(GravityField.body_pos(1, t) + Vector2(3, 0), t), 1)
	assert_eq(GravityField.dominant(GravityField.body_pos(2, t) + Vector2(0, 3), t), 2)
	assert_eq(GravityField.dominant(Vector2(600, 0), t), 0)


func test_body_vel_matches_finite_difference_of_body_pos():
	_three_bodies()
	var h := 1e-2
	for t in [0.0, 3.3]:
		assert_eq(GravityField.body_vel(0, t), Vector2.ZERO)
		for i in [1, 2]:
			var fd: Vector2 = (GravityField.body_pos(i, t + h) - GravityField.body_pos(i, t - h)) / (2 * h)
			assert_almost_eq(GravityField.body_vel(i, t), fd, Vector2(0.1, 0.1))
			assert_gt(GravityField.body_vel(i, t).length(), 0.0)


func test_body_vel_of_nested_moon_adds_parent_velocity():
	var m1 := _body(0, 300.0, 0.5, 1.0)
	var m2 := _body(1, 50.0, 2.0, 0.3)
	Tuning.field = _field([_static_body(1.0, 1.0), m1, m2])
	var h := 1e-2
	var fd: Vector2 = (GravityField.body_pos(2, 2.0 + h) - GravityField.body_pos(2, 2.0 - h)) / (2 * h)
	assert_almost_eq(GravityField.body_vel(2, 2.0), fd, Vector2(0.1, 0.1))


func test_circular_speed_is_sqrt_r_times_own_pull_relative_to_body():
	_three_bodies()
	var t := 1.7
	var pos := GravityField.body_pos(1, t) + Vector2(0, 4)
	var expected := sqrt(4.0 * GravityField.accel_of(1, pos, t).length())
	assert_gt(expected, 0.0)
	assert_almost_eq(GravityField.circular_speed(1, pos, t), expected, 1e-6)
	var far := Vector2(600, 0)
	var r := (far - GravityField.body_pos(0, t)).length()
	assert_almost_eq(GravityField.circular_speed(0, far, t), sqrt(r * GravityField.accel_of(0, far, t).length()), 1e-6)
	assert_eq(GravityField.circular_speed(1, GravityField.body_pos(1, t), t), 0.0)


func test_frame_omega_is_sqrt_planet_pull_at_carrier_radius():
	var f := _field([_static_body(3.0, 2.0)], 2.0, 0.0)
	var rc := 450.0
	f.carrier_orbit_radius = rc
	Tuning.field = f
	var expected := sqrt(2.0 * 3.0 / (rc * rc) / rc)
	assert_almost_eq(GravityField.frame_omega(), expected, 1e-10)
	var g: float = GravityField.accel_of(0, Vector2(rc, 0), 0.0).length()
	var om: float = GravityField.frame_omega()
	assert_almost_eq(g, om * om * rc, 1e-9)


func test_frame_accel_is_centrifugal_plus_coriolis():
	Tuning.field = _field([_static_body(3.0, 2.0)])
	var om: float = GravityField.frame_omega()
	var pos := Vector2(3, 4)
	assert_almost_eq(GravityField.frame_accel(pos, Vector2.ZERO), pos * (om * om), Vector2(1e-12, 1e-12))
	var vel := Vector2(5, -7)
	var cor: Vector2 = GravityField.frame_accel(Vector2.ZERO, vel)
	assert_almost_eq(cor.dot(vel), 0.0, 1e-9)
	assert_almost_eq(cor.length(), 2.0 * om * vel.length(), 1e-8)


func test_potential_eff_peaks_at_carrier_radius():
	var f := _field([_static_body(3.0, 2.0)], 2.0, 0.0)
	var rc := 450.0
	f.carrier_orbit_radius = rc
	Tuning.field = f
	var peak: float = GravityField.potential_eff(Vector2(rc, 0), 0.0)
	for dr in [10.0, 50.0, 150.0]:
		assert_gt(peak, GravityField.potential_eff(Vector2(rc - dr, 0), 0.0), "below by %s" % dr)
		assert_gt(peak, GravityField.potential_eff(Vector2(rc + dr, 0), 0.0), "above by %s" % dr)


func test_d35_calibration_numbers():
	var f := FieldParams.new()
	f.k = 1.0
	f.eps = 1.0
	f.planet_surface_radius = 100000.0
	f.atmosphere_edge = 101500.0
	f.carrier_orbit_radius = 121500.0
	var planet := BodyParams.new()
	planet.mass = pow(0.00255, 2.0) * pow(121500.0, 3.0)
	planet.p = 2.0
	f.bodies = [planet]
	Tuning.field = f
	var om: float = GravityField.frame_omega()
	assert_almost_eq(om / 0.00255, 1.0, 0.001)
	var bottom := Vector2(101500.0, 0.0)
	var drift: float = GravityField.circular_speed(0, bottom, 0.0) - om * 101500.0
	assert_almost_eq(drift / 80.0, 1.0, 0.03)
	var r := 116500.0
	var g_eff: float = GravityField.accel(Vector2(r, 0), 0.0).length() - om * om * r
	assert_almost_eq(g_eff / 0.10, 1.0, 0.05)
	var d_phi: float = GravityField.potential_eff(Vector2(121500.0, 0.0), 0.0) - GravityField.potential_eff(bottom, 0.0)
	assert_almost_eq(d_phi / 4400.0, 1.0, 0.02)
	assert_almost_eq(sqrt(2.0 * d_phi) / 94.0, 1.0, 0.02)


func test_jacobi_integral_conserved_in_free_flight():
	Tuning.field = _field([_static_body(1000.0, 1.0)], 1000.0, 1.0)
	var r := 450.0
	var band: float = GravityField.circular_speed(0, Vector2(r, 0), 0.0) - GravityField.frame_omega() * r
	var s := ShipState.new()
	s.pos = Vector2(r, 0)
	s.vel = Vector2(0, band * 1.05)
	var scale := 0.5 * pow(GravityField.circular_speed(0, Vector2(r, 0), 0.0), 2.0)
	var j0 := 0.5 * s.vel.length_squared() + GravityField.potential_eff(s.pos, 0.0)
	var dt := GravityField.DT
	var max_drift := 0.0
	for i in 900:
		s = ShipFlight.step(s, ShipInput.new(), i * dt, dt)
		var j := 0.5 * s.vel.length_squared() + GravityField.potential_eff(s.pos, 0.0)
		max_drift = maxf(max_drift, absf(j - j0))
	assert_gt(absf(band), 1.0)
	assert_lt(max_drift, 0.01 * scale)


func _load_preset_field(i: int) -> FieldParams:
	return (Tuning.load_preset("res://presets/p%d.tres" % i) as TuningPreset).field.duplicate(true)


func test_planet_potential_eff_ignores_moons_and_matches_planet_only_field():
	var full := _load_preset_field(1)
	var only := full.duplicate(true)
	only.bodies = [only.bodies[0]] as Array[BodyParams]
	for r in [101500.0, 110000.0, 121500.0]:
		Tuning.field = full
		var with_moons: float = GravityField.planet_potential_eff(r)
		Tuning.field = only
		var planet_only: float = GravityField.planet_potential_eff(r)
		assert_eq(with_moons, planet_only)
		assert_almost_eq(planet_only, GravityField.potential_eff(Vector2(r, 0), 0.0), absf(planet_only) * 1e-7)


func test_planet_potential_eff_strictly_increasing_on_tier_span():
	var fields: Array = [_saved_field]
	for i in range(1, 5):
		fields.append(_load_preset_field(i))
	for f in fields:
		Tuning.field = f
		var prev := -INF
		var n := 200
		for j in n + 1:
			var r: float = lerpf(f.atmosphere_edge, f.carrier_orbit_radius, float(j) / n)
			var v: float = GravityField.planet_potential_eff(r)
			assert_gt(v, prev)
			prev = v
