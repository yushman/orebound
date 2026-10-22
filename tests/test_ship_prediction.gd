extends GutTest

const N := 120


func after_each() -> void:
	GravityField.tick = 0
	Input.action_release("ship_thrust")
	Input.action_release("ship_brake")
	Input.action_release("ship_full_trajectory")


func _make() -> Node:
	var ship = load("res://scenes/Ship.tscn").instantiate()
	add_child_autofree(ship)
	return ship


func _check(thrust: bool, brake := false) -> void:
	var ship = _make()
	GravityField.tick = 50
	if brake:
		ship.state.vel *= Vector2(0.6, 1.4)
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
	assert_eq(ship.input.brake, brake)
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


func test_prediction_line_short() -> void:
	var nodes := _run_scene()
	var ship = nodes[0]
	var line: Line2D = nodes[1]
	assert_eq(line.get_index(), ship.get_index() + 1)
	assert_eq(line.ship, ship)
	assert_false(line.width == 0.0)
	var every: int = Tuning.ship.predict_every
	GravityField.tick = every * 5
	ship._physics_process(GravityField.DT)
	line._physics_process(GravityField.DT)
	var expected := ShipPrediction.run(ship.state, ship.input, GravityField.tick, Tuning.ship.predict_short_steps)
	assert_eq(line.points.size(), Tuning.ship.predict_short_steps)
	assert_eq(line.points, expected)
	var before := line.points
	GravityField.tick += 1
	ship._physics_process(GravityField.DT)
	line._physics_process(GravityField.DT)
	assert_eq(line.points, before)


func test_prediction_line_full_while_held() -> void:
	var nodes := _run_scene()
	var ship = nodes[0]
	var line: Line2D = nodes[1]
	var every: int = Tuning.ship.predict_every
	GravityField.tick = every * 5
	ship._physics_process(GravityField.DT)
	Input.action_press("ship_full_trajectory")
	line._physics_process(GravityField.DT)
	var expected := ShipPrediction.run(ship.state, ShipInput.new(), GravityField.tick, Tuning.ship.predict_full_steps)
	assert_eq(line.points, expected)
	Input.action_release("ship_full_trajectory")
	GravityField.tick += every
	ship._physics_process(GravityField.DT)
	line._physics_process(GravityField.DT)
	assert_eq(line.points, ShipPrediction.run(ship.state, ship.input, GravityField.tick, Tuning.ship.predict_short_steps))


func test_predict_every_zero_updates_line() -> void:
	var nodes := _run_scene()
	var ship = nodes[0]
	var line: Line2D = nodes[1]
	var saved: int = Tuning.ship.predict_every
	Tuning.ship.predict_every = 0
	GravityField.tick = 7
	ship._physics_process(GravityField.DT)
	line._physics_process(GravityField.DT)
	Tuning.ship.predict_every = saved
	assert_eq(line.points, ShipPrediction.run(ship.state, ship.input, GravityField.tick, Tuning.ship.predict_short_steps))
