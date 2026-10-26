extends GutTest


func _p() -> ShipParams:
	return ShipParams.new()


func test_flame_zero_without_thrust_or_boost() -> void:
	assert_eq(ShipView.flame_length(false, false, 1.0, 0.0, _p()), 0.0)


func test_flame_ramps_with_hold_time() -> void:
	var p := _p()
	var a := ShipView.flame_length(true, false, 0.0, 0.0, p)
	var b := ShipView.flame_length(true, false, p.ramp_time * 0.5, 0.0, p)
	var c := ShipView.flame_length(true, false, p.ramp_time, 0.0, p)
	assert_gt(a, 0.0)
	assert_gt(b, a)
	assert_gt(c, b)
	assert_almost_eq(a / c, p.ramp_min_fraction, 0.001)
	assert_almost_eq(ShipView.flame_length(true, false, p.ramp_time * 5.0, 0.0, p), c, 0.001)


func test_flame_falls_above_heat_threshold() -> void:
	var p := _p()
	var full := ShipView.flame_length(true, false, p.ramp_time, p.heat_threshold, p)
	var hot := ShipView.flame_length(true, false, p.ramp_time, 1.0, p)
	assert_almost_eq(ShipView.flame_length(true, false, p.ramp_time, 0.0, p), full, 0.001)
	assert_almost_eq(hot / full, p.min_thrust_fraction, 0.001)


func test_flame_longer_when_boosting() -> void:
	var p := _p()
	assert_gt(ShipView.flame_length(true, true, 1.0, 0.0, p), ShipView.flame_length(true, false, 1.0, 0.0, p))
	assert_gt(ShipView.flame_length(false, true, 1.0, 0.0, p), 0.0)


func test_glow_zero_at_zero_heat_one_at_full() -> void:
	var p := _p()
	assert_eq(ShipView.glow_alpha(0.0, p), 0.0)
	assert_almost_eq(ShipView.glow_alpha(1.0, p), 1.0, 0.0001)


func test_glow_monotone() -> void:
	var p := _p()
	var prev := -1.0
	for i in 21:
		var a := ShipView.glow_alpha(i / 20.0, p)
		assert_gte(a, prev)
		prev = a


func test_glow_faint_below_threshold_steep_after() -> void:
	var p := _p()
	var at_thr := ShipView.glow_alpha(p.heat_threshold, p)
	assert_gt(at_thr, 0.0)
	assert_lt(at_thr, 0.3)
	var slope_low := at_thr / p.heat_threshold
	var slope_high := (1.0 - at_thr) / (1.0 - p.heat_threshold)
	assert_gt(slope_high, slope_low * 2.0)


func _ship() -> Node:
	var ship: Node = load("res://scenes/Ship.tscn").instantiate()
	add_child_autofree(ship)
	return ship


func _flame_len(view: ShipView) -> float:
	var flame: Polygon2D = view.get_node("Flame")
	var y := ShipView.NOZZLE_Y
	for v in flame.polygon:
		y = maxf(y, v.y)
	return y - ShipView.NOZZLE_Y


func test_view_is_on_visual_and_flame_is_danger() -> void:
	var view := _ship().get_node("Visual") as ShipView
	assert_not_null(view)
	assert_eq((view.get_node("Flame") as Polygon2D).color, Palette.DANGER)


func test_hull_colour_is_hull_and_wings_are_hull_shade() -> void:
	var view := _ship().get_node("Visual") as ShipView
	assert_eq((view.get_node("Hull") as Polygon2D).color, Palette.HULL)
	assert_eq((view.get_node("WingLeft") as Polygon2D).color, Palette.HULL_SHADE)
	assert_eq((view.get_node("WingRight") as Polygon2D).color, Palette.HULL_SHADE)


func test_hidden_flame_does_not_reassign_polygon() -> void:
	var ship := _ship()
	var view := ship.get_node("Visual") as ShipView
	view._process(0.0)
	assert_eq(view.flame.polygon.size(), 0)
	ship.input.thrust = true
	ship.state.hold_time = Tuning.ship.ramp_time
	view._process(0.0)
	assert_eq(view.flame.polygon.size(), 3)


func test_flame_length_follows_input_and_state() -> void:
	var ship := _ship()
	var view := ship.get_node("Visual") as ShipView
	view._process(0.0)
	assert_eq(_flame_len(view), 0.0)
	ship.input.thrust = true
	ship.state.hold_time = Tuning.ship.ramp_time
	view._process(0.0)
	assert_almost_eq(_flame_len(view), ShipView.flame_length(true, false, Tuning.ship.ramp_time, 0.0, Tuning.ship), 0.001)
	ship.state.heat = 1.0
	view._process(0.0)
	assert_almost_eq(_flame_len(view), ShipView.flame_length(true, false, Tuning.ship.ramp_time, 1.0, Tuning.ship), 0.001)


func test_view_does_not_write_flight_state() -> void:
	var ship := _ship()
	var view := ship.get_node("Visual") as ShipView
	ship.input.thrust = true
	ship.state.heat = 0.7
	var before: ShipState = ship.state.copy()
	view._process(0.1)
	assert_eq(ship.state.heat, before.heat)
	assert_eq(ship.state.hold_time, before.hold_time)
	assert_eq(ship.state.pos, before.pos)


func test_glow_alpha_color_and_size_follow_heat() -> void:
	var ship := _ship()
	var view := ship.get_node("Visual") as ShipView
	var glow := view.get_node("Glow") as Polygon2D
	view._process(0.0)
	assert_eq(glow.color.a, 0.0)
	assert_false(glow.visible)
	ship.state.heat = 0.5
	view._process(0.0)
	var low_size := glow.scale.x
	assert_almost_eq(glow.color.a, ShipView.glow_alpha(0.5, Tuning.ship), 0.0001)
	assert_eq(Color(glow.color, 1.0), Color(Palette.DANGER, 1.0))
	assert_true(glow.visible)
	ship.state.heat = 1.0
	view._process(0.0)
	assert_almost_eq(glow.color.a, 1.0, 0.0001)
	assert_gt(glow.scale.x, low_size)


func test_flame_hidden_when_drift_sync_overrides_thrust() -> void:
	var ship := _ship()
	var view := ship.get_node("Visual") as ShipView
	ship.input.thrust = true
	ship.input.drift_sync = true
	view._process(0.0)
	assert_eq(_flame_len(view), 0.0)
	assert_false((view.get_node("Flame") as Polygon2D).visible)


func test_flame_hidden_when_soft_brake_overrides_thrust() -> void:
	var ship := _ship()
	var view := ship.get_node("Visual") as ShipView
	ship.input.thrust = true
	ship.input.boost = true
	ship.input.soft_brake = true
	view._process(0.0)
	assert_eq(_flame_len(view), 0.0)
	assert_false((view.get_node("Flame") as Polygon2D).visible)


func test_flame_hidden_when_hold_has_no_energy() -> void:
	var ship := _ship()
	var view := ship.get_node("Visual") as ShipView
	ship.state.hold.clear()
	ship.state.tank.clear()
	ship.input.thrust = true
	ship.state.hold_time = Tuning.ship.ramp_time
	view._process(0.0)
	assert_eq(_flame_len(view), 0.0)
	assert_false((view.get_node("Flame") as Polygon2D).visible)
