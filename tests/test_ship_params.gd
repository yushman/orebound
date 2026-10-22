extends GutTest


func test_tuning_ship_defaults() -> void:
	var s: ShipParams = Tuning.ship
	assert_not_null(s)
	assert_eq(s.thrust_accel, 600.0)
	assert_eq(s.boost_accel_mult, 2.5)
	assert_eq(s.turn_accel, 12.0)
	assert_eq(s.spin_damping, 4.0)
	assert_eq(s.heading_gain, 30.0)
	assert_eq(s.fuel_per_dv, 0.001)
	assert_eq(s.boost_fuel_mult, 3.5)
	assert_eq(s.spawn_radius, 600.0)


func test_tuning_ship_prediction_defaults() -> void:
	var s: ShipParams = Tuning.ship
	assert_eq(s.predict_short_steps, 180)
	assert_eq(s.predict_full_steps, 1800)
	assert_eq(s.predict_every, 4)
