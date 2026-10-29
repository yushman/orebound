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
