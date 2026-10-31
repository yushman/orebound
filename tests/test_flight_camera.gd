extends GutTest

var _cam = load("res://scenes/FlightCamera.gd")


func _assert_angle(got: float, expected: float) -> void:
	# atan2 on the axes is off by ~1.5e-7 on this platform and the PI/-PI
	# branch point lands differently after wrapping, so compare modulo 2PI.
	assert_almost_eq(wrapf(got - expected, -PI, PI), 0.0, 1e-6)


func test_rotation_points_screen_down_at_planet_center() -> void:
	_assert_angle(_cam.rotation_for(Vector2(100.0, 0.0)), PI / 2.0)
	_assert_angle(_cam.rotation_for(Vector2(0.0, -50.0)), 0.0)
	_assert_angle(_cam.rotation_for(Vector2(-100.0, 0.0)), -PI / 2.0)
	_assert_angle(_cam.rotation_for(Vector2(0.0, 50.0)), PI)


func test_clamp_zoom_limits_range() -> void:
	assert_almost_eq(_cam.clamp_zoom(0.25), 1.0, 1e-9)
	assert_almost_eq(_cam.clamp_zoom(1.0), 1.0, 1e-9)
	assert_almost_eq(_cam.clamp_zoom(2.5), 2.5, 1e-9)
	assert_almost_eq(_cam.clamp_zoom(40.0), 40.0, 1e-9)
	assert_almost_eq(_cam.clamp_zoom(55.0), 40.0, 1e-9)


func test_discretize_zoom_follows_stop_schedule() -> void:
	# Continuous up to 8 (the ship is still visible), then the stops
	# [10, 15, 22, 32, 40]; on a distance tie the larger stop wins.
	assert_almost_eq(_cam.discretize_zoom(1.0), 1.0, 1e-9)
	assert_almost_eq(_cam.discretize_zoom(5.5), 5.5, 1e-9)
	assert_almost_eq(_cam.discretize_zoom(8.0), 8.0, 1e-9)
	assert_almost_eq(_cam.discretize_zoom(9.5), 10.0, 1e-9)
	assert_almost_eq(_cam.discretize_zoom(13.0), 15.0, 1e-9)
	assert_almost_eq(_cam.discretize_zoom(18.5), 22.0, 1e-9, "tie 15/22 -> larger")
	assert_almost_eq(_cam.discretize_zoom(25.0), 22.0, 1e-9)
	assert_almost_eq(_cam.discretize_zoom(29.0), 32.0, 1e-9)
	assert_almost_eq(_cam.discretize_zoom(36.0), 40.0, 1e-9, "tie 32/40 -> larger")
	assert_almost_eq(_cam.discretize_zoom(40.0), 40.0, 1e-9)
	assert_almost_eq(_cam.discretize_zoom(50.0), 40.0, 1e-9)


func test_zoom_step_reaches_every_stop_in_both_directions() -> void:
	# clamp+discretize with ZOOM_STEP 1.3 must visit every stop: up
	# 8 -> 10 -> 15 -> 22 -> 32 -> 40, down 40 -> 32 -> 22 -> 15 -> 10 ->
	# continuous.
	var z: float = _cam.ZOOM_CONTINUOUS_MAX
	var up: Array[float] = []
	for i in 5:
		z = _cam.discretize_zoom(_cam.clamp_zoom(z * _cam.ZOOM_STEP))
		up.append(z)
	assert_eq(up, [10.0, 15.0, 22.0, 32.0, 40.0] as Array[float],
			"zoom-out chain visits every stop from the continuous ceiling")
	z = _cam.ZOOM_MAX
	var down: Array[float] = []
	for i in 4:
		z = _cam.discretize_zoom(_cam.clamp_zoom(z / _cam.ZOOM_STEP))
		down.append(z)
	assert_eq(down, [32.0, 22.0, 15.0, 10.0] as Array[float],
			"zoom-in chain visits every stop down from the max")
	z = _cam.discretize_zoom(_cam.clamp_zoom(z / _cam.ZOOM_STEP))
	assert_lte(z, _cam.ZOOM_CONTINUOUS_MAX,
			"one more step in from the last stop lands in the continuous zone")
	assert_almost_eq(_cam.discretize_zoom(z), z, 1e-9,
			"continuous zoom is left untouched")


func test_ship_scene_visual_is_node2d_without_bare_polygon() -> void:
	var ship: Node = load("res://scenes/Ship.tscn").instantiate()
	add_child_autofree(ship)
	assert_true(ship.get_node_or_null("Visual") is Node2D)
	assert_null(ship.get_node_or_null("Polygon2D"))


func test_auto_zoom_is_1_at_or_below_20() -> void:
	assert_almost_eq(_cam.auto_zoom(0.0), 1.0, 1e-6)
	assert_almost_eq(_cam.auto_zoom(20.0), 1.0, 1e-6)


func test_auto_zoom_is_3_at_70() -> void:
	assert_almost_eq(_cam.auto_zoom(70.0), 3.0, 1e-6)


func test_auto_zoom_is_5_at_120() -> void:
	assert_almost_eq(_cam.auto_zoom(120.0), 5.0, 1e-6)


func test_ease_zoom_moves_without_overshoot_and_is_frame_rate_independent() -> void:
	var z: float = _cam.ease_zoom(1.0, 5.0, 1.5, 1.0 / 60.0)
	assert_gt(z, 1.0)
	assert_lt(z, 5.0)
	assert_almost_eq(_cam.ease_zoom(1.0, 5.0, 1.5, 1000.0), 5.0, 1e-6)
	var a: float = _cam.ease_zoom(1.0, 5.0, 1.5, 1.0 / 30.0)
	var b: float = _cam.ease_zoom(_cam.ease_zoom(1.0, 5.0, 1.5, 1.0 / 60.0), 5.0, 1.5, 1.0 / 60.0)
	assert_almost_eq(a, b, 1e-3)


func test_view_params_autoscale_defaults() -> void:
	var v: ViewParams = ViewParams.new()
	assert_eq(v.autoscale_speed_low, 20.0)
	assert_eq(v.autoscale_speed_high, 170.0)
	assert_eq(v.autoscale_max, 7.0)
	assert_eq(v.autoscale_override_time, 8.0)
	assert_eq(v.autoscale_smooth, 1.5)


func test_auto_zoom_is_6_at_145_and_7_at_or_above_170() -> void:
	assert_almost_eq(_cam.auto_zoom(145.0), 6.0, 1e-6)
	assert_almost_eq(_cam.auto_zoom(170.0), 7.0, 1e-6)
	assert_almost_eq(_cam.auto_zoom(1e6), 7.0, 1e-6)
	assert_almost_eq(_cam.auto_zoom(45.0), 2.0, 1e-6)


func test_view_params_speed_tau_default() -> void:
	assert_eq(Tuning.view.autoscale_speed_tau, 5.0)


func test_smooth_speed_converges_to_constant_speed() -> void:
	var avg := 0.0
	for i in 600:
		avg = FlightCamera.smooth_speed(avg, 80.0, 0.1)
	assert_almost_eq(avg, 80.0, 1e-3)


func test_smooth_speed_is_frame_rate_independent() -> void:
	var a := FlightCamera.smooth_speed(10.0, 90.0, 1.0 / 30.0)
	var b := FlightCamera.smooth_speed(10.0, 90.0, 1.0 / 60.0)
	b = FlightCamera.smooth_speed(b, 90.0, 1.0 / 60.0)
	assert_almost_eq(a, b, 1e-3)
