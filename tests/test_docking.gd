extends GutTest

var _saved_planet


func before_each() -> void:
	_saved_planet = Tuning.planet
	Tuning.planet = Tuning.planet.duplicate()
	Tuning.planet.carrier_patrol_speed = 0.0


func after_each() -> void:
	Tuning.planet = _saved_planet
	GravityField.tick = 0


func _at(offset: Vector2, vel: Vector2) -> ShipState:
	var s := ShipState.new()
	s.pos = ShipFlight.carrier_pos(0.0) + offset
	s.vel = vel
	return s


func test_docked_tracks_moving_carrier() -> void:
	Tuning.planet.carrier_patrol_speed = 40.0
	var s := ShipState.new()
	s.docked = true
	s = ShipFlight.step(s, ShipInput.new(), 5.0, GravityField.DT)
	assert_eq(s.pos, ShipFlight.carrier_pos(5.0))
	assert_eq(s.vel, ShipFlight.carrier_vel(5.0))


func test_approach_time_grows_inside_and_resets_outside() -> void:
	var s := _at(Vector2(1000, 0), Vector2.ZERO)
	s = ShipFlight.step(s, ShipInput.new(), 0.0, 0.1)
	assert_almost_eq(s.approach_time, 0.1, 1e-6)
	s.pos = ShipFlight.carrier_pos(0.0) + Vector2(5000, 0)
	s.vel = Vector2.ZERO
	s = ShipFlight.step(s, ShipInput.new(), 0.0, 0.1)
	assert_eq(s.approach_time, 0.0)


func test_pull_knob_defaults() -> void:
	var p := PlanetParams.new()
	assert_eq(p.pull_accel_max, 6.0)
	assert_eq(p.pull_omega, 0.3)
	assert_eq(p.dock_radius, 20.0)
	assert_eq(p.dock_speed, 2.0)


func test_pull_zero_outside_capture_radius() -> void:
	assert_eq(ShipFlight.carrier_pull(Vector2(500, 0), Vector2.ZERO), Vector2.ZERO)
	assert_eq(ShipFlight.carrier_pull(Vector2(900, 0), Vector2(1, 1)), Vector2.ZERO)


func test_pull_points_toward_carrier_and_grows_toward_centre() -> void:
	var edge := ShipFlight.carrier_pull(Vector2(490, 0), Vector2.ZERO)
	var far := ShipFlight.carrier_pull(Vector2(450, 0), Vector2.ZERO)
	var mid := ShipFlight.carrier_pull(Vector2(300, 0), Vector2.ZERO)
	assert_lt(edge.x, 0.0)
	assert_gt(far.length(), edge.length())
	assert_gt(mid.length(), far.length())


func test_pull_matches_damped_spring_formula() -> void:
	var w := 1.0 - 50.0 / 500.0
	var om := 0.3
	var expect := w * (-om * om * Vector2(50, 0) - 2.0 * om * Vector2(0, 3))
	var got := ShipFlight.carrier_pull(Vector2(50, 0), Vector2(0, 3))
	assert_almost_eq(got.x, expect.x, 1e-5)
	assert_almost_eq(got.y, expect.y, 1e-5)


func test_pull_damps_relative_velocity() -> void:
	var a := ShipFlight.carrier_pull(Vector2(300, 0), Vector2(0, 5))
	assert_lt(a.y, 0.0)


func test_pull_clamped_to_accel_max() -> void:
	var a := ShipFlight.carrier_pull(Vector2(10, 0), Vector2(-400, 0))
	assert_almost_eq(a.length(), Tuning.planet.pull_accel_max, 1e-5)


func test_capture_knob_defaults() -> void:
	var p := PlanetParams.new()
	assert_eq(p.capture_radius, 500.0)
	assert_eq(p.approach_radius, 3000.0)


func _armed(offset: Vector2, vel: Vector2) -> ShipState:
	var s := _at(offset, vel)
	s.dock_armed = true
	return s


func test_unarmed_ship_inside_zone_is_not_pulled() -> void:
	var a := ShipFlight.step(_at(Vector2(0, -300), Vector2.ZERO), ShipInput.new(), 0.0, GravityField.DT)
	var b := ShipFlight.step(_armed(Vector2(0, -300), Vector2.ZERO), ShipInput.new(), 0.0, GravityField.DT)
	assert_false(a.dock_armed)
	assert_ne(a.vel, b.vel, "armed ship is pulled, unarmed is not")


func test_armed_ship_drifting_in_converges_and_docks_without_overshoot() -> void:
	var s := _armed(Vector2(0, -450), Vector2(0, -15))
	var dir := Vector2(0, -1)
	var worst := 0.0
	var ticks := 0
	while not s.docked and ticks < 60 * 300:
		ticks += 1
		s = ShipFlight.step(s, ShipInput.new(), GravityField.time_at(ticks), GravityField.DT)
		worst = minf(worst, (s.pos - ShipFlight.carrier_pos(GravityField.time_at(ticks))).dot(dir))
	assert_true(s.docked, "docked within 300 s")
	assert_gt(worst, -Tuning.planet.dock_radius, "never crosses the carrier")


func test_docking_snaps_to_carrier() -> void:
	var s := ShipFlight.step(_armed(Vector2(10, 0), Vector2(0.5, 0)), ShipInput.new(), 0.0, GravityField.DT)
	assert_true(s.docked)
	assert_eq(s.pos, ShipFlight.carrier_pos(0.0))
	assert_eq(s.vel, ShipFlight.carrier_vel(0.0))


func test_fast_ship_inside_dock_radius_does_not_dock() -> void:
	var s := ShipFlight.step(_armed(Vector2(10, 0), Vector2(0, 5)), ShipInput.new(), 0.0, GravityField.DT)
	assert_false(s.docked)


func test_slow_ship_outside_dock_radius_does_not_dock() -> void:
	var s := ShipFlight.step(_armed(Vector2(100, 0), Vector2(0.5, 0)), ShipInput.new(), 0.0, GravityField.DT)
	assert_false(s.docked)


func test_thrust_inside_zone_changes_trajectory() -> void:
	var inp := ShipInput.new()
	inp.thrust = true
	var a := _armed(Vector2(0, -300), Vector2.ZERO)
	var b := _armed(Vector2(0, -300), Vector2.ZERO)
	for i in 30:
		a = ShipFlight.step(a, ShipInput.new(), GravityField.time_at(i + 1), GravityField.DT)
		b = ShipFlight.step(b, inp, GravityField.time_at(i + 1), GravityField.DT)
	assert_ne(a.vel, b.vel)
	assert_false(b.docked)
