extends GutTest

const N := 120

var _saved_field: FieldParams
var _saved_planet_small


func before_each() -> void:
	_saved_field = Tuning.field
	_saved_planet_small = Tuning.planet
	Tuning.planet = Tuning.planet.duplicate()


func after_each() -> void:
	_set_field(_saved_field)
	Tuning.planet = _saved_planet_small
	GravityField.tick = 0
	Input.action_release("ship_thrust")
	Input.action_release("ship_brake")


func _make() -> Node:
	var ship = load("res://scenes/Ship.tscn").instantiate()
	add_child_autofree(ship)
	return ship


func _check(thrust: bool, soft_brake := false, cargo := false, sliver := -1.0) -> void:
	var ship = _make()
	if sliver >= 0.0:
		ship.state.tank.resize(1)
		ship.state.tank[0].fill = sliver
	if cargo:
		Hold.add(ship.state, &"ore_middle", 5.0)
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


func test_predicted_points_equal_flight_with_cargo_and_thrust() -> void:
	_check(true, false, true)


func test_predicted_points_equal_flight_when_energy_runs_out_mid_line() -> void:
	_check(true, false, false, 0.01)


func test_predicted_points_equal_flight_while_cells_drain() -> void:
	_check(true, false, false, 0.5)


func test_predicted_points_equal_flight_without_thrust() -> void:
	_check(false)


func test_predicted_points_equal_flight_with_brake_on_perturbed_orbit() -> void:
	_check(false, true)


func test_predicted_points_equal_flight_through_moon_bounce() -> void:
	var f := FieldParams.new()
	f.k = 0.0
	f.carrier_orbit_radius = 500.0
	f.planet_surface_radius = 10.0
	f.atmosphere_edge = 20.0
	var planet := BodyParams.new()
	planet.mass = 1000.0
	planet.p = 1.0
	var moon := BodyParams.new()
	moon.mass = 1.0
	moon.p = 2.0
	moon.parent = 0
	moon.orbit_radius = 1000.0
	moon.radius = 50.0
	var bodies: Array[BodyParams] = [planet, moon]
	f.bodies = bodies
	Tuning.field = f
	var ship = _make()
	ship.state.pos = Vector2(1100.0, 0.0)
	ship.state.vel = Vector2(-30.0, 0.0)
	var start_tick := GravityField.tick
	var pts := ShipPrediction.run(ship.state, ship.input, start_tick, N)
	var bounced := false
	for i in N:
		GravityField.tick += 1
		ship._physics_process(GravityField.DT)
		assert_eq(pts[i], ship.state.pos, "point %d" % i)
		bounced = bounced or ship.state.vel.x > 0.0
	assert_true(bounced, "ship bounced off the moon")


func test_predicted_points_equal_flight_through_asteroid_bounce() -> void:
	var saved_planet = Tuning.planet
	var saved_picture = Tuning.picture
	var saved_field = Tuning.field
	Tuning.planet = saved_planet.duplicate()
	Tuning.planet.asteroids_per_band = 1000.0
	var ast: Dictionary = AsteroidField.chunk(0, 0)[0]
	var st := AsteroidField.state(0, ast, GravityField.time())
	var ship = _make()
	ship.state.pos = st["pos"] + Vector2(ast["radius"] + 15.0, 0.0)
	ship.state.vel = st["vel"] + Vector2(-10.0, 0.0)
	var hull0: float = ship.state.hull
	var start_tick := GravityField.tick
	var pts := ShipPrediction.run(ship.state, ship.input, start_tick, N)
	var hit := false
	for i in N:
		GravityField.tick += 1
		ship._physics_process(GravityField.DT)
		assert_eq(pts[i], ship.state.pos, "point %d" % i)
		hit = hit or ship.state.hull < hull0
	Tuning.planet = saved_planet
	Tuning.picture = saved_picture
	Tuning.field = saved_field
	assert_true(hit, "ship hit the asteroid")


func _median_ms(start: ShipState, input: ShipInput) -> float:
	var times: Array = []
	for r in 5:
		var t0 := Time.get_ticks_usec()
		ShipPrediction.run(start, input, 0, 900)
		times.append((Time.get_ticks_usec() - t0) / 1000.0)
	times.sort()
	return times[2]


func _overhead(start: ShipState, input: ShipInput, label: String) -> float:
	var saved_planet = Tuning.planet
	Tuning.planet = saved_planet.duplicate()
	var med: Array = []
	for density in [0.0, 1000.0]:
		Tuning.planet.asteroids_per_band = density
		med.append(_median_ms(start, input))
	Tuning.planet = saved_planet
	print("prediction 900 steps ", label, ", median ms: ", med[1], " (no asteroids: ", med[0], ")")
	return med[1] - med[0]


func _dense_start(vel_extra: Vector2) -> ShipState:
	var saved_planet = Tuning.planet
	Tuning.planet = saved_planet.duplicate()
	Tuning.planet.asteroids_per_band = 1000.0
	var ast: Dictionary = AsteroidField.chunk(0, 0)[0]
	Tuning.planet = saved_planet
	var st := AsteroidField.state(0, ast, 0.0)
	var start := ShipState.new()
	start.pos = st["pos"] + Vector2(ast["radius"] + 200.0, 0.0)
	start.vel = st["vel"] + vel_extra
	return start


func test_prediction_900_steps_among_asteroids_within_budget() -> void:
	var saved_planet = Tuning.planet
	Tuning.planet = saved_planet.duplicate()
	Tuning.planet.asteroids_per_band = 1000.0
	var start := _dense_start(Vector2(-3.0, 0.0))
	Tuning.planet = saved_planet
	assert_lt(_overhead(start, ShipInput.new(), "dense"), 3.0)


func test_prediction_900_steps_high_speed_start_within_budget() -> void:
	var saved_planet = Tuning.planet
	Tuning.planet = saved_planet.duplicate()
	Tuning.planet.asteroids_per_band = 1000.0
	var start := _dense_start(Vector2(0.0, 300.0))
	Tuning.planet = saved_planet
	assert_lt(_overhead(start, ShipInput.new(), "high-speed"), 3.0)


func test_prediction_900_steps_accelerating_within_budget() -> void:
	var saved_planet = Tuning.planet
	Tuning.planet = saved_planet.duplicate()
	Tuning.planet.asteroids_per_band = 1000.0
	var start := _dense_start(Vector2.ZERO)
	Tuning.planet = saved_planet
	var inp := ShipInput.new()
	inp.thrust = true
	start.rot = PI * 0.5
	assert_lt(_overhead(start, inp, "accelerating"), 3.0)


func test_prediction_equals_flight_when_accelerating_into_asteroids() -> void:
	var saved_planet = Tuning.planet
	Tuning.planet = saved_planet.duplicate()
	Tuning.planet.asteroids_per_band = 1000.0
	var saved_ship = Tuning.ship
	Tuning.ship = saved_ship.duplicate()
	Tuning.ship.thrust_accel = 30.5
	var ast: Dictionary = AsteroidField.chunk(0, 0)[0]
	var st := AsteroidField.state(0, ast, 0.0)
	var dir := Vector2.from_angle(ast["theta"] - 0.4)
	var start := ShipState.new()
	start.pos = st["pos"] + dir * 3000.0
	start.vel = st["vel"]
	start.rot = (-dir).angle() + PI * 0.5
	var inp := ShipInput.new()
	inp.thrust = true
	var pts := ShipPrediction.run(start, inp, 0, 900)
	var s := start.copy()
	var diverged := 0
	for i in pts.size():
		s = ShipFlight.step(s, inp, GravityField.time_at(i + 1), GravityField.DT)
		if pts[i] != s.pos:
			diverged += 1
	var hull: float = s.hull
	Tuning.planet = saved_planet
	Tuning.ship = saved_ship
	assert_eq(pts.size(), 900)
	assert_eq(diverged, 0)
	assert_lt(hull, start.hull, "ship hit asteroids")


func _run_scene() -> Array:
	var run = load("res://scenes/Run.tscn").instantiate()
	add_child_autofree(run)
	return [run.get_node("Ship"), run.get_node("Prediction")]


func _expected(ship) -> PackedVector2Array:
	var held: ShipInput = ship.input.copy()
	held.turn = 0.0
	return ShipPrediction.run(ship.state, held, GravityField.tick, Tuning.ship.predict_short_steps)


func _settle(line, advance := 0) -> void:
	while line._task >= 0 and not WorkerThreadPool.is_task_completed(line._task):
		OS.delay_msec(1)
	GravityField.tick += advance
	line._physics_process(GravityField.DT)


func test_prediction_line_always_shown() -> void:
	var nodes := _run_scene()
	var ship = nodes[0]
	var line: Line2D = nodes[1]
	GravityField.tick = Tuning.ship.predict_every * 5
	ship._physics_process(GravityField.DT)
	line._physics_process(GravityField.DT)
	_settle(line)
	assert_eq(line.points.size(), Tuning.ship.predict_short_steps)
	assert_eq(line.points, _expected(ship))


func test_prediction_line_is_picked_up_from_the_worker_task_and_trimmed() -> void:
	var nodes := _run_scene()
	var ship = nodes[0]
	var line: Line2D = nodes[1]
	Input.action_press("ship_thrust")
	GravityField.tick = Tuning.ship.predict_every * 5
	ship._physics_process(GravityField.DT)
	line._physics_process(GravityField.DT)
	assert_eq(line.points.size(), 0)
	var expected := _expected(ship)
	_settle(line, 3)
	assert_eq(line.points, expected.slice(3))


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
	_settle(line)
	assert_eq(line.points.size(), Tuning.ship.predict_short_steps)
	assert_eq(line.points, _expected(ship))
	GravityField.tick += every
	ship._physics_process(GravityField.DT)
	line._physics_process(GravityField.DT)
	_settle(line)
	assert_eq(line.points.size(), Tuning.ship.predict_short_steps)
	assert_eq(line.points, _expected(ship))
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
	_settle(line)
	Tuning.ship.predict_every = saved
	assert_eq(line.points, _expected(ship))


func test_preset_applied_refreshes_line_immediately() -> void:
	var nodes := _run_scene()
	var ship = nodes[0]
	var line: Line2D = nodes[1]
	GravityField.tick = Tuning.ship.predict_every * 5
	ship.state.pos = Vector2(5000.0, 300.0)
	Input.action_press("ship_thrust")
	ship._physics_process(GravityField.DT)
	line._physics_process(GravityField.DT)
	_settle(line)
	GravityField.tick += 1
	var preset := TuningPreset.new()
	preset.field = Tuning.field.duplicate(true)
	preset.ship = Tuning.ship.duplicate(true)
	Tuning.apply(preset)
	assert_eq(line.points.size(), 0)
	_settle(line)
	_settle(line)
	assert_eq(line.points, _expected(ship))


func test_crash_respawn_refreshes_line_with_predict_every_gt_1() -> void:
	var nodes := _run_scene()
	var ship = nodes[0]
	var line: Line2D = nodes[1]
	var saved: int = Tuning.ship.predict_every
	Tuning.ship.predict_every = 5
	GravityField.tick = 5
	ship.state.pos = Vector2(5000.0, 300.0)
	line._physics_process(GravityField.DT)
	GravityField.tick = 6
	ship.state.hull = 0.0
	ship._physics_process(GravityField.DT)
	line._physics_process(GravityField.DT)
	_settle(line)
	_settle(line)
	Tuning.ship.predict_every = saved
	assert_eq(line.points, _expected(ship))


func test_result_of_a_task_started_before_respawn_is_dropped_and_a_fresh_task_starts_at_once() -> void:
	var nodes := _run_scene()
	var ship = nodes[0]
	var line: Line2D = nodes[1]
	var saved: int = Tuning.ship.predict_every
	Tuning.ship.predict_every = 5
	GravityField.tick = 5
	ship.state.pos = Vector2(5000.0, 300.0)
	line._physics_process(GravityField.DT)
	var old := _expected(ship)
	ship.respawn()
	assert_eq(line.points.size(), 0)
	_settle(line)
	assert_eq(line.points.size(), 0)
	_settle(line)
	Tuning.ship.predict_every = saved
	assert_ne(line.points, old)
	assert_eq(line.points, _expected(ship))


func test_removing_the_line_waits_for_its_running_task() -> void:
	var nodes := _run_scene()
	var line: Line2D = nodes[1]
	line._physics_process(GravityField.DT)
	var id: int = line._task
	assert_true(id >= 0)
	line.get_parent().remove_child(line)
	assert_eq(line._result.size(), Tuning.ship.predict_short_steps)
	assert_eq(line._task, -1)
	line.free()


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
	line._process(1.0)
	assert_almost_eq(line.width, 2.0 / cam.zoom.x, 1e-6,
			"world width renders as 2 screen px at any zoom")
	cam._target_zoom = 1.0
	cam._process(1.0)
	cam._process(1.0)
	line._process(1.0)
	assert_almost_eq(line.width, 2.0, 1e-6)


func test_prediction_line_ignores_held_turn() -> void:
	var nodes := _run_scene()
	var ship = nodes[0]
	var line: Line2D = nodes[1]
	Input.action_press("ship_thrust")
	Input.action_press("ship_rotate_right")
	GravityField.tick = Tuning.ship.predict_every * 5
	ship._physics_process(GravityField.DT)
	line._physics_process(GravityField.DT)
	_settle(line)
	Input.action_release("ship_rotate_right")
	assert_eq(ship.input.turn, 1.0)
	assert_eq(line.points, _expected(ship))


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



func test_prediction_equals_flight_while_beaming_and_around_a_broken_asteroid() -> void:
	var saved_planet = Tuning.planet
	Tuning.planet = saved_planet.duplicate()
	Tuning.planet.asteroids_per_band = 1000.0
	var a: Dictionary = AsteroidField.near(Vector2(AsteroidField.band_centre(0), 0.0), 0.0, 3000.0)[0]
	var key := Vector3i(a["band"], a["chunk"], a["idx"])
	var ap: Vector2 = AsteroidField.at(a, 0.0)["pos"]
	var start := ShipState.new()
	start.pos = ap + Vector2.from_angle(a["theta"] + 0.3) * (a["radius"] + 50.0)
	start.vel = AsteroidField.at(a, 0.0)["vel"]
	start.broken[key] = true
	var inp := ShipInput.new()
	inp.beam = true
	inp.aim = (ap - start.pos).angle()
	var pts := ShipPrediction.run(start, inp, 0, 300)
	var s := start.copy()
	var diverged := 0
	for i in pts.size():
		s = ShipFlight.step(s, inp, GravityField.time_at(i + 1), GravityField.DT)
		if pts[i] != s.pos:
			diverged += 1
	Tuning.planet = saved_planet
	assert_eq(pts.size(), 300)
	assert_eq(diverged, 0)


func test_prediction_equals_flight_with_beam_and_collector_held_near_an_asteroid() -> void:
	var saved_planet = Tuning.planet
	Tuning.planet = saved_planet.duplicate()
	Tuning.planet.asteroids_per_band = 1000.0
	Tuning.planet.break_per_sqrt_radius = 0.01
	var a: Dictionary = AsteroidField.near(Vector2(AsteroidField.band_centre(0), 0.0), 0.0, 3000.0)[0]
	var ap: Vector2 = AsteroidField.at(a, 0.0)["pos"]
	var start := ShipState.new()
	start.pos = ap + Vector2.from_angle(a["theta"] + 0.3) * (a["radius"] + 50.0)
	start.vel = AsteroidField.at(a, 0.0)["vel"]
	var inp := ShipInput.new()
	inp.beam = true
	inp.collect = true
	inp.aim = (ap - start.pos).angle()
	var pts := ShipPrediction.run(start, inp, 0, 300)
	var s := start.copy()
	var diverged := 0
	var max_bodies := 0
	for i in pts.size():
		s = ShipFlight.step(s, inp, GravityField.time_at(i + 1), GravityField.DT)
		max_bodies = maxi(max_bodies, s.bodies.size())
		if pts[i] != s.pos:
			diverged += 1
	Tuning.planet = saved_planet
	assert_eq(pts.size(), 300)
	assert_eq(diverged, 0)
	assert_gt(max_bodies, 0, "an asteroid broke")


func _big_body(ship_pos: Vector2) -> FreeBody:
	var b := FreeBody.new()
	b.pos = ship_pos + Vector2(60.0, 0.0)
	b.vel = Vector2(-20.0, 0.0)
	b.radius = 40.0
	b.radius0 = 40.0
	b.piece = true
	b.points = PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(0, 1)])
	b.type = &"ice"
	b.amount = 5.0
	b.id = 7
	return b


func test_predicted_points_equal_flight_with_small_bodies_and_show_deflection() -> void:
	var ship = _make()
	ship.state.bodies.append(_big_body(ship.state.pos))
	var start_tick := GravityField.tick
	var pts := ShipPrediction.run(ship.state, ship.input, start_tick, N)
	assert_eq(pts.size(), N)
	var deflected := false
	for i in N:
		GravityField.tick += 1
		ship._physics_process(GravityField.DT)
		assert_eq(pts[i], ship.state.pos, "point %d" % i)
		deflected = deflected or ship.state.vel.x < -1.0
	assert_true(deflected, "ship was pushed by the large body")


func test_prediction_900_steps_with_max_bodies_within_budget() -> void:
	var start := ShipState.new()
	start.pos = Vector2(121500.0, 0.0)
	var base := _median_ms(start, ShipInput.new())
	for i in 8:
		var b := _big_body(start.pos)
		b.pos = start.pos + Vector2.RIGHT.rotated(i) * 800.0
		b.vel = Vector2.ZERO
		b.id = i
		start.bodies.append(b)
	var with_bodies := _median_ms(start, ShipInput.new())
	print("prediction 900 steps, ", start.bodies.size(), " bodies, median ms: ", with_bodies, " (none: ", base, ")")
	assert_lt(with_bodies, base + 150.0)


func test_prediction_900_steps_at_rest_without_bodies_within_budget() -> void:
	var start := ShipState.new()
	start.pos = Vector2(Tuning.field.carrier_orbit_radius, 0.0)
	var med := _median_ms(start, ShipInput.new())
	print("prediction 900 steps at rest, no bodies, median ms: ", med)
	assert_lt(med, 25.0)


func test_regenerate_to_fewer_moons_while_a_task_runs_waits_for_it_and_next_line_matches() -> void:
	var nodes := _run_scene()
	var ship = nodes[0]
	var line: Line2D = nodes[1]
	var saved_steps: int = Tuning.ship.predict_short_steps
	Tuning.ship.predict_short_steps = 20000
	var f: FieldParams = Tuning.field.duplicate(true)
	var bodies: Array[BodyParams] = [f.bodies[0]]
	for i in 6:
		bodies.append(f.bodies[1] if f.bodies.size() > 1 else f.bodies[0].duplicate())
	f.bodies = bodies
	Tuning.field = f
	line._physics_process(GravityField.DT)
	var id: int = line._task
	assert_true(id >= 0)
	OS.delay_msec(30)
	Tuning.regenerate(3, 1)
	assert_true(WorkerThreadPool.is_task_completed(id), "regenerate returned while the prediction task still ran")
	Tuning.ship.predict_short_steps = 300
	_settle(line)
	_settle(line)
	Tuning.ship.predict_short_steps = saved_steps
	assert_eq(line.points, ShipPrediction.run(ship.state, ship.input.copy(), GravityField.tick, 300))


func _set_field(f: FieldParams) -> void:
	Tuning.lock.lock()
	Tuning.field = f
	Tuning.lock.unlock()
