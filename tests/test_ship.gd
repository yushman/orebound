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
	var s: ShipState = ship.state
	var r: float = Tuning.ship.spawn_radius
	var full := GravityField.accel(s.pos, 0.0).length()
	var own := GravityField.accel_of(0, s.pos, 0.0).length()
	Tuning.field = saved
	assert_ne(full, own)
	assert_almost_eq(s.vel.length(), sqrt(r * own), 0.01)
	assert_gt(absf(s.vel.length() - sqrt(r * full)), 0.01)


func test_spawn_near_moon_adds_moon_velocity() -> void:
	var saved = Tuning.field
	var f := FieldParams.new()
	f.k = 1000.0
	f.eps = 1.0
	var planet := BodyParams.new()
	planet.mass = 1000.0
	planet.p = 1.0
	var moon := BodyParams.new()
	moon.mass = 100000.0
	moon.p = 2.0
	moon.parent = 0
	moon.orbit_radius = Tuning.ship.spawn_radius - 20.0
	moon.angular_speed = 0.1
	var bodies: Array[BodyParams] = [planet, moon]
	f.bodies = bodies
	Tuning.field = f
	var ship = _make()
	var pos: Vector2 = ship.state.pos
	var expected := GravityField.body_vel(1, 0.0) + Vector2(0.0, GravityField.circular_speed(1, pos, 0.0))
	Tuning.field = saved
	assert_almost_eq(ship.state.vel, expected, Vector2(0.01, 0.01))


func test_preset_applied_respawns_on_circular_orbit_of_new_field() -> void:
	var saved_field = Tuning.field
	var saved_ship = Tuning.ship
	var ship = _make()
	ship.state.pos = Vector2(5000.0, 300.0)
	ship.state.vel = Vector2(7.0, 9.0)
	ship.state.rot = 1.2
	ship.state.ang_vel = 0.7
	ship.state.fuel_engine = 3.0
	ship.state.fuel_boost = 2.0
	ship.state.fuel_brake = 1.0
	ship.rotation = 1.2
	var preset := TuningPreset.new()
	preset.field = Tuning.field.duplicate(true)
	preset.ship = Tuning.ship.duplicate(true)
	preset.field.bodies[0].p = 2.0
	preset.field.bodies[0].mass = 50000.0
	Tuning.apply(preset)
	var r: float = Tuning.ship.spawn_radius
	var t := GravityField.time()
	var pos := Vector2(r, 0.0)
	assert_eq(ship.state.pos, pos)
	assert_eq(ship.position, pos)
	assert_almost_eq(ship.state.vel.length(), GravityField.circular_speed(GravityField.dominant(pos, t), pos, t), 0.01)
	assert_almost_eq(ship.state.vel.dot(pos), 0.0, 0.01)
	assert_eq(ship.state.rot, 0.0)
	assert_eq(ship.state.ang_vel, 0.0)
	assert_eq(ship.state.fuel_engine, 0.0)
	assert_eq(ship.state.fuel_boost, 0.0)
	assert_eq(ship.state.fuel_brake, 0.0)
	assert_eq(ship.rotation, 0.0)
	Tuning.field = saved_field
	Tuning.ship = saved_ship


func test_direct_field_change_does_not_respawn_ship() -> void:
	var saved_p: float = Tuning.field.bodies[0].p
	var ship = _make()
	var before: ShipState = ship.state.copy()
	Tuning.field.bodies[0].p = saved_p + 0.5
	var expected := ShipFlight.step(before, ShipInput.new(), GravityField.time(), GravityField.DT)
	ship._physics_process(GravityField.DT)
	Tuning.field.bodies[0].p = saved_p
	assert_eq(ship.state.pos, expected.pos)
	assert_eq(ship.state.vel, expected.vel)
