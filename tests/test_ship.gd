extends GutTest


func after_each() -> void:
	GravityField.tick = 0


func _make() -> Node:
	var ship = load("res://scenes/Ship.tscn").instantiate()
	add_child_autofree(ship)
	return ship


func test_spawns_on_circular_orbit_at_spawn_radius() -> void:
	var ship = _make()
	var r: float = Tuning.ship.spawn_radius
	var s: ShipState = ship.state
	assert_eq(s.pos, Vector2(r, 0.0))
	var t := GravityField.time()
	assert_almost_eq(s.vel.length(), GravityField.circular_speed(GravityField.dominant(s.pos, t), s.pos, t), 0.01)
	assert_almost_eq(s.vel.dot(s.pos), 0.0, 0.01)
	assert_eq(s.rot, 0.0)
	assert_eq(s.ang_vel, 0.0)
	assert_eq(s.fuel_engine, 0.0)
	assert_eq(s.fuel_boost, 0.0)


func test_physics_process_steps_with_post_increment_field_time() -> void:
	var ship = _make()
	GravityField.tick = 90
	var before: ShipState = ship.state.copy()
	var expected := ShipFlight.step(before, ShipInput.new(), GravityField.time(), 1.0 / 60.0)
	ship._physics_process(1.0 / 60.0)
	assert_eq(ship.state.pos, expected.pos)
	assert_eq(ship.state.vel, expected.vel)
	assert_almost_eq(ship.position, expected.pos, Vector2(0.001, 0.001))
	assert_eq(ship.rotation, expected.rot)


func test_stick_beyond_deadzone_sets_heading_keys_set_turn() -> void:
	var ship = _make()
	Input.action_press("ship_heading_right", 1.0)
	var inp: ShipInput = ship._read_input()
	assert_true(inp.has_heading)
	assert_almost_eq(inp.target_heading, Vector2(1, 0).angle() + PI / 2, 0.001)
	Input.action_release("ship_heading_right")
	inp = ship._read_input()
	assert_false(inp.has_heading)
	Input.action_press("ship_rotate_left")
	assert_eq(ship._read_input().turn, -1.0)
	Input.action_release("ship_rotate_left")
	Input.action_press("ship_rotate_right")
	assert_eq(ship._read_input().turn, 1.0)
	Input.action_release("ship_rotate_right")
	assert_eq(ship._read_input().turn, 0.0)
	Input.action_press("ship_thrust")
	Input.action_press("ship_boost")
	inp = ship._read_input()
	assert_true(inp.thrust)
	assert_true(inp.boost)
	Input.action_release("ship_thrust")
	Input.action_release("ship_boost")


func test_physics_process_steps_with_dt_regardless_of_delta_and_stores_input() -> void:
	var ship = _make()
	GravityField.tick = 90
	Input.action_press("ship_thrust")
	var before: ShipState = ship.state.copy()
	var inp := ShipInput.new()
	inp.thrust = true
	var expected := ShipFlight.step(before, inp, GravityField.time(), GravityField.DT)
	ship._physics_process(0.5)
	Input.action_release("ship_thrust")
	assert_eq(ship.state.pos, expected.pos)
	assert_eq(ship.state.vel, expected.vel)
	assert_eq(ship.state.rot, expected.rot)
	assert_not_null(ship.input)
	assert_true(ship.input.thrust)


func test_spawn_speed_uses_dominant_body_pull_not_full_accel() -> void:
	var saved = Tuning.field
	var f := FieldParams.new()
	f.k = 1000.0
	f.eps = 1.0
	var planet := BodyParams.new()
	planet.mass = 1000.0
	planet.p = 1.0
	var moon := BodyParams.new()
	moon.mass = 100.0
	moon.p = 2.0
	moon.parent = 0
	moon.orbit_radius = Tuning.ship.spawn_radius - 30.0
	var bodies: Array[BodyParams] = [planet, moon]
	f.bodies = bodies
	Tuning.field = f
	var ship = _make()
	Tuning.field = saved
	var s: ShipState = ship.state
	var r: float = Tuning.ship.spawn_radius
	f_check(f, s, r)


func f_check(f: FieldParams, s: ShipState, r: float) -> void:
	var saved = Tuning.field
	Tuning.field = f
	var full := GravityField.accel(s.pos, 0.0).length()
	var own := GravityField.accel_of(0, s.pos, 0.0).length()
	Tuning.field = saved
	assert_ne(full, own)
	assert_almost_eq(s.vel.length(), sqrt(r * own), 0.01)
	assert_gt(absf(s.vel.length() - sqrt(r * full)), 0.01)
