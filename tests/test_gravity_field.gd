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
	var a1 := 1.0 + 0.5 * t
	var p1 := Vector2(cos(a1), sin(a1)) * 300.0
	var a2 := 0.3 + 2.0 * t
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


func test_default_field_has_planet_and_two_moons():
	var f: FieldParams = _saved_field
	assert_not_null(f)
	assert_gt(f.fade_width, 0.0)
	assert_eq(f.bodies.size(), 3)
	var planet := f.bodies[0]
	assert_eq(planet.p, 1.0)
	assert_eq(planet.parent, -1)
	assert_eq(planet.orbit_radius, 0.0)
	assert_eq(planet.influence_radius, 0.0)
	for i in [1, 2]:
		var m := f.bodies[i]
		assert_eq(m.p, 2.0)
		assert_eq(m.parent, 0)
		assert_between(m.orbit_radius, 100.0, 600.0)
		assert_gt(m.influence_radius, 0.0)


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
