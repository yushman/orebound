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
	assert_almost_eq(_cam.discretize_zoom(1.0), 1.0, 1e-9)
	assert_almost_eq(_cam.discretize_zoom(15.5), 15.5, 1e-9)
	assert_almost_eq(_cam.discretize_zoom(22.0), 22.0, 1e-9)
	assert_almost_eq(_cam.discretize_zoom(25.0), 28.0, 1e-9)
	assert_almost_eq(_cam.discretize_zoom(29.0), 28.0, 1e-9)
	assert_almost_eq(_cam.discretize_zoom(31.0), 34.0, 1e-9)
	assert_almost_eq(_cam.discretize_zoom(36.0), 34.0, 1e-9)
	assert_almost_eq(_cam.discretize_zoom(40.0), 40.0, 1e-9)
	assert_almost_eq(_cam.discretize_zoom(50.0), 40.0, 1e-9)
