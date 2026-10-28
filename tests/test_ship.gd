extends GutTest


var _saved_planet_small


func before_each() -> void:
	_saved_planet_small = Tuning.planet
	Tuning.planet = Tuning.planet.duplicate()


func after_each() -> void:
	Tuning.planet = _saved_planet_small
	GravityField.tick = 0


func _make() -> Node:
	var ship = load("res://scenes/Ship.tscn").instantiate()
	add_child_autofree(ship)
	return ship


func test_respawns_at_carrier_at_rest() -> void:
	var ship = _make()
	var r: float = Tuning.field.carrier_orbit_radius
	var s: ShipState = ship.state
	assert_eq(s.pos, Vector2(r, 0.0))
	assert_eq(s.vel, Vector2.ZERO)
	assert_eq(ship.position, Vector2(r, 0.0))
	assert_almost_eq(Vector2.UP.rotated(s.rot), s.pos.normalized(), Vector2(1e-5, 1e-5))
	assert_almost_eq(ship.rotation, s.rot, 1e-6)
	assert_eq(s.ang_vel, 0.0)
	assert_eq(s.fuel_engine, 0.0)
	assert_eq(s.fuel_boost, 0.0)
	assert_eq(s.fuel_soft_brake, 0.0)


func test_physics_process_steps_with_post_increment_field_time() -> void:
	var ship = _make()
	GravityField.tick = 90
	var before: ShipState = ship.state.copy()
	var expected := ShipFlight.step(before, ShipInput.new(), GravityField.time(), 1.0 / 60.0)
	ship._physics_process(1.0 / 60.0)
	assert_eq(ship.state.pos, expected.pos)
	assert_eq(ship.state.vel, expected.vel)
	assert_almost_eq(ship.position, expected.pos, Vector2(0.001, 0.001))
	assert_almost_eq(ship.rotation, expected.rot, 1e-6)


func test_stick_beyond_deadzone_sets_heading_keys_set_turn() -> void:
	var ship = _make()
	Input.action_press("ship_heading_right", 1.0)
	var inp: ShipInput = ship._read_input()
	assert_true(inp.has_heading)
	var expected := ShipInput.screen_heading(Vector2(1, 0), ship.state.pos)
	assert_almost_eq(inp.target_heading, expected, 0.001)
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


func test_read_input_maps_drift_sync_action() -> void:
	var ship = _make()
	Input.action_press("ship_drift_sync")
	Input.action_press("ship_brake")
	var inp: ShipInput = ship._read_input()
	assert_true(inp.drift_sync)
	assert_true(inp.soft_brake)
	Input.action_release("ship_brake")
	Input.action_release("ship_drift_sync")
	# зажатое действие доходит до шага: у матки синхронизация гасит скорость к 0
	ship.state.vel = Vector2(3.0, 0.0)
	Input.action_press("ship_drift_sync")
	ship._physics_process(GravityField.DT)
	Input.action_release("ship_drift_sync")
	assert_true(ship.input.drift_sync)
	assert_false(ship.input.soft_brake)
	# a = -v/dt с клампом sync_accel = 6: Δv за тик = -0.1 по x, прочее — Кориолис
	assert_almost_eq(ship.state.vel.x, 2.9, 0.01)
	assert_almost_eq(ship.state.vel.y, 0.0, 0.01)


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


func test_respawn_at_carrier_is_at_rest_even_when_moon_dominates() -> void:
	var saved = Tuning.field
	var f := FieldParams.new()
	f.k = 1000.0
	f.eps = 1.0
	f.carrier_orbit_radius = 500.0
	var planet := BodyParams.new()
	planet.mass = 1000.0
	planet.p = 1.0
	var moon := BodyParams.new()
	moon.mass = 100000.0
	moon.p = 2.0
	moon.parent = 0
	moon.orbit_radius = 480.0
	moon.angular_speed = 0.1
	var bodies: Array[BodyParams] = [planet, moon]
	f.bodies = bodies
	Tuning.field = f
	var ship = _make()
	var carrier := Vector2(500.0, 0.0)
	var ref := GravityField.dominant(carrier, GravityField.time())
	Tuning.field = saved
	assert_eq(ref, 1)
	assert_eq(ship.state.pos, carrier)
	assert_eq(ship.state.vel, Vector2.ZERO)


func test_preset_applied_respawns_at_carrier_of_new_field() -> void:
	var saved_field = Tuning.field
	var saved_ship = Tuning.ship
	var ship = _make()
	ship.state.pos = Vector2(5000.0, 300.0)
	ship.state.vel = Vector2(7.0, 9.0)
	ship.state.rot = 1.2
	ship.state.ang_vel = 0.7
	ship.state.fuel_engine = 3.0
	ship.state.fuel_boost = 2.0
	ship.state.fuel_soft_brake = 1.0
	ship.rotation = 1.2
	var preset := TuningPreset.new()
	preset.field = Tuning.field.duplicate(true)
	preset.ship = Tuning.ship.duplicate(true)
	preset.field.bodies[0].p = 2.0
	preset.field.bodies[0].mass = 50000.0
	preset.field.carrier_orbit_radius = 700.0
	Tuning.apply(preset)
	var pos := Vector2(700.0, 0.0)
	assert_eq(ship.state.pos, pos)
	assert_eq(ship.position, pos)
	assert_eq(ship.state.vel, Vector2.ZERO)
	assert_almost_eq(ship.state.rot, PI / 2.0, 1e-6)
	assert_eq(ship.state.ang_vel, 0.0)
	assert_eq(ship.state.fuel_engine, 0.0)
	assert_eq(ship.state.fuel_boost, 0.0)
	assert_eq(ship.state.fuel_soft_brake, 0.0)
	assert_almost_eq(ship.rotation, PI / 2.0, 1e-6)
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


func test_stick_heading_is_screen_relative() -> void:
	var pos := Vector2(Tuning.field.carrier_orbit_radius, 0.0)
	var up := Vector2.UP.rotated(ShipInput.screen_heading(Vector2(0, -1), pos))
	assert_almost_eq(up, Vector2(1, 0), Vector2(1e-5, 1e-5))
	var right := Vector2.UP.rotated(ShipInput.screen_heading(Vector2(1, 0), pos))
	assert_almost_eq(right, Vector2(0, 1), Vector2(1e-5, 1e-5))
	var top := Vector2(0, -50.0)
	var up_top := Vector2.UP.rotated(ShipInput.screen_heading(Vector2(0, -1), top))
	assert_almost_eq(up_top, Vector2(0, -1), Vector2(1e-5, 1e-5))


func test_crashed_step_respawns_at_carrier_with_full_hull_and_counts_a_crash() -> void:
	var saved_crashes: int = Telemetry.crashes
	Telemetry.crashes = 0
	var ship = _make()
	ship.state.pos = Vector2(Tuning.field.planet_surface_radius - 10.0, 0.0)
	ship.state.hull = 12.0
	ship._physics_process(GravityField.DT)
	assert_eq(Telemetry.crashes, 1)
	assert_eq(ship.state.pos, Vector2(Tuning.field.carrier_orbit_radius, 0.0))
	assert_eq(ship.state.vel, Vector2.ZERO)
	assert_eq(ship.state.hull, Tuning.ship.hull_max)
	assert_false(ship.state.crashed)
	ship._physics_process(GravityField.DT)
	assert_eq(Telemetry.crashes, 1)
	Telemetry.crashes = saved_crashes


func test_preset_change_restores_hull_without_touching_the_crash_counter() -> void:
	var saved_crashes: int = Telemetry.crashes
	var saved_field = Tuning.field
	var saved_ship = Tuning.ship
	Telemetry.crashes = 3
	var ship = _make()
	ship.state.hull = 10.0
	Tuning.apply(Tuning.load_preset("res://presets/p1.tres"))
	assert_eq(ship.state.hull, Tuning.ship.hull_max)
	assert_eq(Telemetry.crashes, 3)
	Telemetry.crashes = saved_crashes
	Tuning.field = saved_field
	Tuning.ship = saved_ship


func test_read_input_maps_beam_and_aim() -> void:
	var ship = _make()
	var inp: ShipInput = ship._read_input()
	assert_false(inp.beam)
	assert_almost_eq(Vector2.RIGHT.rotated(inp.aim).dot(Vector2.UP.rotated(ship.state.rot)), 1.0, 0.0001)
	Input.action_press("ship_beam")
	assert_true(ship._read_input().beam)
	Input.action_release("ship_beam")


func test_read_input_maps_collect() -> void:
	var ship = _make()
	assert_false(ship._read_input().collect)
	Input.action_press("ship_collect")
	assert_true(ship._read_input().collect)
	Input.action_release("ship_collect")


func _hold_jettison(ship: Node, ticks: int) -> Array:
	var seen := []
	Input.action_press("ship_jettison")
	for i in ticks:
		seen.append(ship._read_input())
	Input.action_release("ship_jettison")
	return seen


func test_holding_jettison_for_hold_time_sets_jettison_for_one_tick() -> void:
	var saved := [Telemetry.jettisons, Telemetry.jettison_selects, Telemetry.jettison_cancelled]
	var ship = _make()
	Hold.add(ship.state, &"ice", 1.0)
	var seen := _hold_jettison(ship, 121)
	var fired := []
	for i in seen.size():
		if seen[i].jettison:
			fired.append(i)
		assert_false(seen[i].jettison_select)
	assert_eq(fired, [119])
	assert_false(ship._read_input().jettison)
	Telemetry.jettisons = saved[0]
	Telemetry.jettison_selects = saved[1]
	Telemetry.jettison_cancelled = saved[2]


func test_short_press_sets_jettison_select_for_one_tick() -> void:
	var saved: int = Telemetry.jettison_selects
	Telemetry.jettison_selects = 0
	var ship = _make()
	Hold.add(ship.state, &"ice", 1.0)
	_hold_jettison(ship, 5)
	var inp: ShipInput = ship._read_input()
	assert_true(inp.jettison_select)
	assert_false(inp.jettison)
	assert_false(ship._read_input().jettison_select)
	assert_eq(Telemetry.jettison_selects, 1)
	Telemetry.jettison_selects = saved


func test_fire_counts_jettison() -> void:
	var saved: int = Telemetry.jettisons
	Telemetry.jettisons = 0
	var ship = _make()
	Hold.add(ship.state, &"ice", 1.0)
	_hold_jettison(ship, 125)
	assert_eq(Telemetry.jettisons, 1)
	Telemetry.jettisons = saved


func test_release_between_tap_time_and_cancel_window_end_counts_jettison_cancelled() -> void:
	var saved_c: int = Telemetry.jettison_cancelled
	var saved_s: int = Telemetry.jettison_selects
	Telemetry.jettison_cancelled = 0
	Telemetry.jettison_selects = 0
	var ship = _make()
	_hold_jettison(ship, 60)
	var inp: ShipInput = ship._read_input()
	assert_false(inp.jettison)
	assert_false(inp.jettison_select)
	assert_eq(Telemetry.jettison_cancelled, 1)
	assert_eq(Telemetry.jettison_selects, 0)
	Telemetry.jettison_cancelled = saved_c
	Telemetry.jettison_selects = saved_s


func test_respawn_while_jettison_held_does_not_fire_in_new_flight() -> void:
	var saved := [Telemetry.jettisons, Telemetry.jettison_selects, Telemetry.jettison_cancelled]
	var ship = _make()
	Input.action_press("ship_jettison")
	for i in 90:
		ship._read_input()
	ship.respawn()
	Hold.add(ship.state, &"ice", 1.0)
	var fired := false
	for i in 100:
		fired = fired or ship._read_input().jettison
	Input.action_release("ship_jettison")
	assert_false(fired)
	Telemetry.jettisons = saved[0]
	Telemetry.jettison_selects = saved[1]
	Telemetry.jettison_cancelled = saved[2]


func test_holding_jettison_with_empty_hold_leaves_telemetry_jettisons_at_zero() -> void:
	var saved: int = Telemetry.jettisons
	Telemetry.jettisons = 0
	var ship = _make()
	_hold_jettison(ship, 125)
	assert_eq(Telemetry.jettisons, 0)
	Telemetry.jettisons = saved


func test_short_press_with_empty_hold_leaves_jettison_selects_at_zero() -> void:
	var saved: int = Telemetry.jettison_selects
	Telemetry.jettison_selects = 0
	var ship = _make()
	_hold_jettison(ship, 5)
	ship._read_input()
	assert_eq(Telemetry.jettison_selects, 0)
	Telemetry.jettison_selects = saved


func _hold_transfer(ship: Node, ticks: int) -> Array:
	var seen := []
	Input.action_press("ship_transfer")
	for i in ticks:
		seen.append(ship._read_input())
	Input.action_release("ship_transfer")
	return seen


func test_holding_transfer_fires_after_hold_time_and_repeats_each_interval() -> void:
	var saved: int = Telemetry.transfers
	var ship = _make()
	var seen := _hold_transfer(ship, 105)
	var fired := []
	for i in seen.size():
		if seen[i].transfer:
			fired.append(i)
		assert_false(seen[i].jettison)
		assert_false(seen[i].jettison_select)
	assert_eq(fired, [59, 101])
	Telemetry.transfers = saved


func test_jettison_and_transfer_firing_on_one_tick_counts_no_transfer() -> void:
	var saved_j: int = Telemetry.jettisons
	var saved_t: int = Telemetry.transfers
	Telemetry.transfers = 0
	Tuning.planet.asteroids_per_band = 0
	var ship = _make()
	Hold.add(ship.state, &"ice", 1.0)
	Hold.add(ship.state, &"fuel", 1.0)
	Hold.add(ship.state, &"fuel", 0.5)
	Input.action_press("ship_transfer")
	for i in 24:
		ship._physics_process(GravityField.DT)
	Input.action_press("ship_jettison")
	for i in 106:
		ship._physics_process(GravityField.DT)
	# a burn frees the tank slot between the tick 102 and tick 144 transfer fires
	ship.state.tank.remove_at(3)
	for i in 14:
		ship._physics_process(GravityField.DT)
	Input.action_release("ship_jettison")
	Input.action_release("ship_transfer")
	# both presses fire on tick 144 and the jettison takes the last ice cell
	assert_true(ship.input.jettison)
	assert_true(ship.input.transfer)
	assert_true(ship.state.hold.is_empty())
	assert_eq(ship.state.tank.size(), 3)
	assert_eq(Telemetry.transfers, 0)
	Telemetry.transfers = saved_t
	Telemetry.jettisons = saved_j


func test_transfer_freed_by_the_same_tick_drain_is_counted() -> void:
	var saved: int = Telemetry.transfers
	Telemetry.transfers = 0
	Tuning.planet.asteroids_per_band = 0
	var ship = _make()
	Hold.add(ship.state, &"ice", 1.0)
	Hold.add(ship.state, &"fuel", 1.0)
	Hold.add(ship.state, &"fuel", 0.9)
	Input.action_press("ship_thrust")
	Input.action_press("ship_transfer")
	for i in 58:
		ship._physics_process(GravityField.DT)
	var before: float = ship.state.fuel_engine
	ship._physics_process(GravityField.DT)
	# the next tick's burn must erase the partial cell: set it just under one tick of burn
	ship.state.tank[3].fill = (ship.state.fuel_engine - before) / 6.0
	ship._physics_process(GravityField.DT)
	Input.action_release("ship_thrust")
	Input.action_release("ship_transfer")
	assert_true(ship.input.transfer)
	assert_true(ship.state.hold.is_empty())
	assert_eq(ship.state.tank.size(), 4)
	assert_eq(Telemetry.transfers, 1)
	Telemetry.transfers = saved
