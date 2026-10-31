extends GutTest


func _in_atmosphere() -> ShipState:
	var s := ShipState.new()
	var f: FieldParams = Tuning.field
	s.pos = Vector2((f.atmosphere_edge + f.planet_surface_radius) * 0.5, 0)
	return s


func test_atmosphere_tick_reports_atmosphere_damage_equal_to_hull_loss() -> void:
	var s := _in_atmosphere()
	var report := {}
	var out := ShipFlight.step(s, ShipInput.new(), 0.0, GravityField.DT, null, report)
	var loss := s.hull - out.hull
	assert_gt(loss, 0.0)
	assert_almost_eq(report["damage"]["atmosphere"], loss, 1e-6)
	assert_eq(report["damage"]["moon"], 0.0)
	assert_eq(report["damage"]["asteroid"], 0.0)
	assert_eq(report["damage"]["piece"], 0.0)
	assert_false(report["heat_limited"])


func test_heat_limited_when_engine_on_above_threshold() -> void:
	var s := ShipState.new()
	s.pos = Vector2(Tuning.field.carrier_orbit_radius, 0)
	s.heat = 0.5 * (1.0 + Tuning.ship.heat_threshold)
	var input := ShipInput.new()
	input.thrust = true
	var report := {}
	ShipFlight.step(s, input, 0.0, GravityField.DT, null, report)
	assert_true(report["heat_limited"])


func test_report_does_not_change_result() -> void:
	var s := _in_atmosphere()
	var a := ShipFlight.step(s, ShipInput.new(), 0.0, GravityField.DT)
	var b := ShipFlight.step(s, ShipInput.new(), 0.0, GravityField.DT, null, {})
	assert_eq(a.hull, b.hull)
	assert_eq(a.pos, b.pos)
	assert_eq(a.vel, b.vel)


func test_band_drift_accel_matches_band_drift_vel() -> void:
	var s := ShipState.new()
	s.pos = Vector2(Tuning.field.carrier_orbit_radius * 0.9, 0)
	s.vel = Vector2(3.0, 40.0)
	var dt := GravityField.DT
	var limit := 5.0
	var v := ShipFlight.band_drift_vel(s.pos, s.vel, 0.0)
	var expect := ((v - s.vel) / dt).limit_length(limit)
	assert_eq(ShipFlight._band_drift_accel(s, 0.0, dt, limit), expect)
