extends GutTest


func test_tuning_ship_defaults() -> void:
	var s: ShipParams = Tuning.ship
	assert_not_null(s)
	assert_eq(s.thrust_accel, 9.0)
	assert_eq(s.boost_accel_mult, 2.5)
	assert_eq(s.turn_accel, 12.0)
	assert_eq(s.spin_damping, 4.0)
	assert_eq(s.heading_gain, 30.0)
	assert_eq(s.boost_fuel_mult, 3.5)
	assert_eq(s.brake_accel, 3.0)
	assert_eq(s.brake_fuel_mult, 1.0)


func test_no_fuel_per_dv_property() -> void:
	var names := Tuning.ship.get_property_list().map(func(d): return d["name"])
	assert_false("fuel_per_dv" in names)


func test_climb_coefficient_default() -> void:
	assert_eq(Tuning.ship.get("climb_coefficient"), 0.05)


func test_tuning_ship_d36_control_defaults() -> void:
	var s: ShipParams = Tuning.ship
	assert_eq(s.get("ramp_time"), 1.5)
	assert_eq(s.get("ramp_min_fraction"), 0.15)
	assert_eq(s.get("heat_growth_engine"), 0.04)
	assert_eq(s.get("heat_growth_boost"), 0.12)
	assert_eq(s.get("heat_threshold"), 0.8)
	assert_eq(s.get("heat_cooldown"), 0.18)
	assert_eq(s.get("min_thrust_fraction"), 0.2)
	assert_eq(s.get("sync_accel"), 6.0)
	assert_eq(s.get("sync_fuel_mult"), 2.0)
	assert_eq(s.get("sync_radius"), 3000.0)


func test_spawn_radius_removed_from_ship_params() -> void:
	assert_null(Tuning.ship.get("spawn_radius"), "spawn_radius must be gone from ShipParams")


func test_spawn_descend_speed_default() -> void:
	assert_eq(Tuning.ship.get("spawn_descend_speed"), 5.0)


func test_tuning_ship_prediction_defaults() -> void:
	var s: ShipParams = Tuning.ship
	assert_eq(s.predict_short_steps, 900)
	assert_eq(s.predict_every, 4)


func test_predict_full_steps_removed_from_ship_params() -> void:
	assert_null(Tuning.ship.get("predict_full_steps"), "predict_full_steps must be gone from ShipParams")


func test_tuning_ship_hull_default() -> void:
	assert_eq(Tuning.ship.get("hull_max"), 100.0)


func test_tuning_ship_hold_defaults() -> void:
	var s: ShipParams = Tuning.ship
	assert_eq(s.get("hull_mass"), 4.0)
	assert_eq(s.get("hold_capacity"), 10)
	assert_eq(s.get("ref_mass"), 10.0)
	assert_eq(s.get("loadout_fuel_cells"), 2)
	assert_false("separate_tank" in s)
	assert_eq(s.get("tank_capacity"), 4)


func test_tuning_ship_beam_defaults() -> void:
	assert_eq(Tuning.ship.get("beam_range"), 300.0)
	assert_false("beam_rate" in Tuning.ship)


func test_tuning_ship_return_defaults() -> void:
	assert_eq(Tuning.ship.get("return_margin"), 1.2)
	for k in ["mode", "tau"]:
		assert_null(Tuning.ship.get("return_" + "speed_" + k))


func test_tuning_ship_hit_radius_default() -> void:
	assert_eq(Tuning.ship.get("hit_radius"), 15.0)


func test_tuning_ship_collector_and_beam_damage_defaults() -> void:
	assert_gt(Tuning.ship.get("beam_damage"), 0.0)
	assert_eq(Tuning.ship.get("collect_angle"), 60.0)
	assert_eq(Tuning.ship.get("collect_accel"), 200.0)


func test_jettison_params_defaults() -> void:
	assert_eq(Tuning.ship.get("jettison_tap_time"), 0.7)
	assert_eq(Tuning.ship.get("jettison_hold_time"), 2.0)
	assert_eq(Tuning.ship.get("jettison_interval"), 0.7)
	assert_eq(Tuning.ship.get("jettison_push"), 5.0)
	assert_eq(Tuning.ship.get("jettison_pickup_delay"), 1.5)


func test_transfer_params_defaults() -> void:
	assert_eq(Tuning.ship.get("refiner"), false)
	assert_eq(Tuning.ship.get("transfer_hold_time"), 1.0)
	assert_eq(Tuning.ship.get("transfer_interval"), 0.7)
