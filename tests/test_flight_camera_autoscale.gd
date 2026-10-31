extends GutTest

var _ship: Node2D
var _cam: FlightCamera


func before_each() -> void:
	var root := Node2D.new()
	add_child_autofree(root)
	_ship = load("res://scenes/Ship.tscn").instantiate()
	_ship.name = "Ship"
	root.add_child(_ship)
	_cam = FlightCamera.new()
	root.add_child(_cam)
	Telemetry.autoscale_overrides = 0


func _fast() -> void:
	_ship.state.pos = Vector2(Tuning.field.carrier_orbit_radius * 0.8, 0.0)
	_ship.state.vel = Vector2(0.0, 5000.0)


func test_manual_zoom_press_pauses_autoscale_and_counts_one_override() -> void:
	_cam.on_zoom_press(1)
	assert_eq(Telemetry.autoscale_overrides, 1)
	assert_almost_eq(_cam.manual_left, Tuning.view.autoscale_override_time, 1e-6)
	_cam.update(1.0)
	_cam.on_zoom_press(1)
	assert_eq(Telemetry.autoscale_overrides, 1, "presses inside a pause do not count")
	assert_almost_eq(_cam.manual_left, Tuning.view.autoscale_override_time, 1e-6, "press restarts the timer")


func test_pause_holds_manual_target_then_autoscale_takes_over() -> void:
	_fast()
	_cam.on_zoom_press(-1)
	for i in 30:
		_cam.update(0.1)
	assert_almost_eq(_cam._zoom_current, 1.0, 1e-3, "manual target 1 held during the pause")
	assert_gt(_cam.manual_left, 0.0)
	for i in 60:
		_cam.update(0.1)
	assert_eq(_cam.manual_left, 0.0)
	for i in 50:
		_cam.update(0.1)
	assert_gt(_cam._zoom_current, 3.0, "autoscale zooms out for the fast ship")
	assert_eq(Telemetry.autoscale_overrides, 1)
	_cam.on_zoom_press(1)
	assert_eq(Telemetry.autoscale_overrides, 2, "a new pause counts again")


func test_autoscale_follows_ship_state() -> void:
	_fast()
	for i in 40:
		_cam.update(0.1)
	assert_gt(_cam._zoom_current, 4.0)
	assert_lte(_cam._zoom_current, FlightCamera.ZOOM_CONTINUOUS_MAX + 1e-6)


func test_begin_flight_resets_autoscale_overrides() -> void:
	Telemetry.autoscale_overrides = 3
	Telemetry.begin_flight()
	assert_eq(Telemetry.autoscale_overrides, 0)


func _set_rel_speed(speed: float) -> void:
	var pos := Vector2(Tuning.field.carrier_orbit_radius * 0.8, 0.0)
	var drift := ShipFlight.band_drift_vel(pos, Vector2(0.0, 1.0), GravityField.time())
	_ship.state.pos = pos
	_ship.state.vel = drift + drift.normalized() * speed


func test_dip_to_zero_speed_barely_moves_zoom() -> void:
	_set_rel_speed(70.0)
	_cam._speed_avg = 70.0
	_cam._zoom_current = FlightCamera.auto_zoom(70.0)
	var before := _cam._zoom_current
	_set_rel_speed(0.0)
	for i in 15:
		_cam.update(0.1)
	assert_lt(absf(_cam._zoom_current - before), 0.5, "1.5 s dip moves the zoom less than half a level")


func test_zoom_changes_monotonically_while_speed_rises() -> void:
	_set_rel_speed(40.0)
	_cam._speed_avg = 40.0
	_cam._zoom_current = FlightCamera.auto_zoom(40.0)
	var prev := _cam._zoom_current
	var max_step := 0.0
	for i in 300:
		_set_rel_speed(40.0 + 130.0 * i / 300.0)
		_cam.update(0.1)
		var d := _cam._zoom_current - prev
		if i > 0:
			assert_gt(d, 0.0, "zoom rises every frame (frame %d)" % i)
		max_step = maxf(max_step, d)
		prev = _cam._zoom_current
	assert_lt(max_step, 0.5, "no jumps")


func test_speed_filter_runs_during_manual_pause() -> void:
	_set_rel_speed(100.0)
	_cam.on_zoom_press(-1)
	for i in 60:
		_cam.update(0.1)
	assert_almost_eq(_cam._speed_avg, 100.0 * (1.0 - exp(-6.0 / 5.0)), 1.0)


func test_manual_zoom_at_8_or_more_keeps_autoscale_off_past_the_pause() -> void:
	_fast()
	_cam._zoom_current = 8.0
	_cam.on_zoom_press(1)
	assert_gte(_cam._target_zoom, FlightCamera.ZOOM_CONTINUOUS_MAX)
	for i in 200:
		_cam.update(0.1)
	assert_gt(_cam.manual_left, 0.0, "pause does not expire at >= 8")
	assert_almost_eq(_cam._zoom_current, _cam._target_zoom, 0.05)
	assert_eq(Telemetry.autoscale_overrides, 1)
	_cam.on_zoom_press(1)
	assert_eq(Telemetry.autoscale_overrides, 1, "press while disabled does not count")


func test_zooming_back_below_8_starts_the_normal_pause() -> void:
	_fast()
	_cam._zoom_current = 8.0
	_cam.on_zoom_press(1)
	for i in 200:
		_cam.update(0.1)
	_cam.on_zoom_press(-1)
	assert_lt(_cam._target_zoom, FlightCamera.ZOOM_CONTINUOUS_MAX)
	assert_almost_eq(_cam.manual_left, Tuning.view.autoscale_override_time, 1e-6)
	_cam.update(1.0)
	assert_almost_eq(_cam.manual_left, Tuning.view.autoscale_override_time - 1.0, 1e-6)
	assert_eq(Telemetry.autoscale_overrides, 1)
