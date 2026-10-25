extends GutTest

const N := 120


func after_each() -> void:
	GravityField.tick = 0
	Input.action_release("ship_thrust")
	Input.action_release("ship_brake")


func _make() -> Node:
	var ship = load("res://scenes/Ship.tscn").instantiate()
	add_child_autofree(ship)
	return ship


func _check(thrust: bool, soft_brake := false) -> void:
	var ship = _make()
	GravityField.tick = 50
	if soft_brake:
		ship.state.vel = Vector2(3.0, -2.0)
		Input.action_press("ship_brake")
	if thrust:
		Input.action_press("ship_thrust")
	ship._physics_process(GravityField.DT)
	var start: ShipState = ship.state.copy()
	var inp: ShipInput = ship.input
	var start_tick := GravityField.tick
	var pts := ShipPrediction.run(ship.state, inp, start_tick, N)
	assert_eq(pts.size(), N)
	assert_eq(ship.input.thrust, thrust)
	assert_eq(ship.input.soft_brake, soft_brake)
	assert_eq(ship.state.pos, start.pos)
	assert_eq(ship.state.vel, start.vel)
	for i in N:
		GravityField.tick += 1
		ship._physics_process(GravityField.DT)
		assert_eq(pts[i], ship.state.pos, "point %d" % i)


func test_predicted_points_equal_flight_with_thrust() -> void:
	_check(true)


func test_predicted_points_equal_flight_without_thrust() -> void:
	_check(false)


func test_predicted_points_equal_flight_with_brake_on_perturbed_orbit() -> void:
	_check(false, true)


func _run_scene() -> Array:
	var run = load("res://scenes/Run.tscn").instantiate()
	add_child_autofree(run)
	return [run.get_node("Ship"), run.get_node("Prediction")]


func test_prediction_line_always_shown() -> void:
	# No input held: the line is still the full predict_short_steps points.
	var nodes := _run_scene()
	var ship = nodes[0]
	var line: Line2D = nodes[1]
	GravityField.tick = Tuning.ship.predict_every * 5
	ship._physics_process(GravityField.DT)
	line._physics_process(GravityField.DT)
	assert_eq(line.points.size(), Tuning.ship.predict_short_steps)
	assert_eq(line.points, ShipPrediction.run(ship.state, ship.input,
			GravityField.tick, Tuning.ship.predict_short_steps))


func test_prediction_line_short() -> void:
	var nodes := _run_scene()
	var ship = nodes[0]
	var line: Line2D = nodes[1]
	assert_eq(line.get_index(), ship.get_index() + 1)
	assert_eq(line.ship, ship)
	assert_false(line.width == 0.0)
	Input.action_press("ship_thrust")
	var every: int = Tuning.ship.predict_every
	GravityField.tick = every * 5
	ship._physics_process(GravityField.DT)
	line._physics_process(GravityField.DT)
	var expected := ShipPrediction.run(ship.state, ship.input, GravityField.tick, Tuning.ship.predict_short_steps)
	assert_eq(line.points.size(), Tuning.ship.predict_short_steps)
	assert_eq(line.points, expected)
	GravityField.tick += every
	ship._physics_process(GravityField.DT)
	line._physics_process(GravityField.DT)
	assert_eq(line.points.size(), Tuning.ship.predict_short_steps)
	assert_eq(line.points, ShipPrediction.run(ship.state, ship.input, GravityField.tick, Tuning.ship.predict_short_steps))
	var before := line.points
	GravityField.tick += 1
	ship._physics_process(GravityField.DT)
	line._physics_process(GravityField.DT)
	assert_eq(line.points, before)


func test_predict_every_zero_updates_line() -> void:
	var nodes := _run_scene()
	var ship = nodes[0]
	var line: Line2D = nodes[1]
	var saved: int = Tuning.ship.predict_every
	Tuning.ship.predict_every = 0
	GravityField.tick = 7
	Input.action_press("ship_thrust")
	ship._physics_process(GravityField.DT)
	line._physics_process(GravityField.DT)
	Tuning.ship.predict_every = saved
	assert_eq(line.points, ShipPrediction.run(ship.state, ship.input, GravityField.tick, Tuning.ship.predict_short_steps))


func test_preset_applied_refreshes_line_immediately() -> void:
	var nodes := _run_scene()
	var ship = nodes[0]
	var line: Line2D = nodes[1]
	GravityField.tick = Tuning.ship.predict_every * 5
	ship.state.pos = Vector2(5000.0, 300.0)
	Input.action_press("ship_thrust")
	ship._physics_process(GravityField.DT)
	line._physics_process(GravityField.DT)
	GravityField.tick += 1
	var preset := TuningPreset.new()
	preset.field = Tuning.field.duplicate(true)
	preset.ship = Tuning.ship.duplicate(true)
	Tuning.apply(preset)
	assert_eq(line.points, ShipPrediction.run(ship.state, ship.input, GravityField.tick, Tuning.ship.predict_short_steps))


func test_prediction_line_screen_width() -> void:
	# Толщина линии — постоянные ЭКРАННЫЕ 2 px: мир = 2.0 · s = 2.0 / cam.zoom.x.
	var run = load("res://scenes/Run.tscn").instantiate()
	add_child_autofree(run)
	var ship = run.get_node("Ship")
	var line: Line2D = run.get_node("Prediction")
	var cam: Camera2D = run.get_node("FlightCamera")
	Input.action_press("ship_thrust")
	ship._physics_process(GravityField.DT)
	cam._target_zoom = 4.0
	cam._process(1.0)
	cam._process(1.0)
	line._update()
	assert_almost_eq(line.width, 2.0 / cam.zoom.x, 1e-6,
			"world width renders as 2 screen px at any zoom")
	cam._target_zoom = 1.0
	cam._process(1.0)
	cam._process(1.0)
	line._update()
	assert_almost_eq(line.width, 2.0, 1e-6)


func test_prediction_line_ignores_held_turn() -> void:
	var nodes := _run_scene()
	var ship = nodes[0]
	var line: Line2D = nodes[1]
	Input.action_press("ship_thrust")
	Input.action_press("ship_rotate_right")
	GravityField.tick = Tuning.ship.predict_every * 5
	ship._physics_process(GravityField.DT)
	line._update()
	Input.action_release("ship_rotate_right")
	assert_eq(ship.input.turn, 1.0)
	var no_turn: ShipInput = ship.input.copy()
	no_turn.turn = 0.0
	assert_eq(line.points, ShipPrediction.run(ship.state, no_turn,
			GravityField.tick, Tuning.ship.predict_short_steps))


func test_prediction_stops_at_the_first_crashed_state_and_matches_flight_up_to_it() -> void:
	var f := Tuning.field
	var start := ShipState.new()
	start.pos = Vector2(f.planet_surface_radius + 100.0, 0.0)
	start.vel = Vector2(-50.0, 0.0)
	var steps := 600
	var pts := ShipPrediction.run(start, ShipInput.new(), 10, steps)
	assert_gt(pts.size(), 0)
	assert_lt(pts.size(), steps)
	var s := start.copy()
	for i in pts.size():
		s = ShipFlight.step(s, ShipInput.new(), GravityField.time_at(10 + i + 1), GravityField.DT)
		assert_eq(pts[i], s.pos, "point %d" % i)
		assert_eq(s.crashed, i == pts.size() - 1, "crashed at %d" % i)
