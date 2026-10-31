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


func test_respawn_at_carrier_nose_at_the_planet_descending() -> void:
	Tuning.planet.carrier_patrol_speed = 0.0
	var ship = _make()
	var r: float = Tuning.field.carrier_orbit_radius
	var s: ShipState = ship.state
	assert_eq(s.pos, Vector2(r, 0.0))
	assert_eq(s.vel, Tuning.ship.spawn_descend_speed * Vector2(-1.0, 0.0))
	assert_eq(ship.position, Vector2(r, 0.0))
	assert_almost_eq(Vector2.UP.rotated(s.rot), -s.pos.normalized(), Vector2(1e-5, 1e-5))
	assert_almost_eq(ship.rotation, s.rot, 1e-6)
	assert_eq(s.ang_vel, 0.0)
	assert_eq(s.fuel_engine, 0.0)
	assert_eq(s.fuel_boost, 0.0)
	assert_eq(s.fuel_soft_brake, 0.0)


func test_spawn_velocity_is_the_descend_speed_toward_the_planet() -> void:
	var saved_speed: float = Tuning.planet.carrier_patrol_speed
	Tuning.planet.carrier_patrol_speed = 40.0
	var ship = _make()
	var t0 := GravityField.time()
	var pos: Vector2 = ShipFlight.carrier_pos(t0)
	var planet_dir := -pos.normalized()
	assert_eq(ship.state.pos, pos, "spawn stays on the carrier")
	assert_eq(ship.state.vel, ShipFlight.carrier_vel(t0) + Tuning.ship.spawn_descend_speed * planet_dir,
			"co-moving with the patrolling carrier AND descending toward the planet")
	assert_ne(ship.state.vel, ShipFlight.carrier_vel(t0))
	assert_almost_eq(Vector2.UP.rotated(ship.state.rot), planet_dir, Vector2(1e-5, 1e-5))
	Tuning.planet.carrier_patrol_speed = saved_speed


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
	Tuning.planet.carrier_patrol_speed = 0.0
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


func test_respawn_nose_at_the_planet_even_when_moon_dominates() -> void:
	Tuning.planet.carrier_patrol_speed = 0.0
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
	assert_eq(ship.state.vel, Tuning.ship.spawn_descend_speed * (-carrier.normalized()))


func test_preset_applied_respawns_at_carrier_of_new_field() -> void:
	Tuning.planet.carrier_patrol_speed = 0.0
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
	assert_eq(ship.state.vel, Tuning.ship.spawn_descend_speed * Vector2(-1.0, 0.0))
	assert_almost_eq(ship.state.rot, -PI / 2.0, 1e-6)
	assert_eq(ship.state.ang_vel, 0.0)
	assert_eq(ship.state.fuel_engine, 0.0)
	assert_eq(ship.state.fuel_boost, 0.0)
	assert_eq(ship.state.fuel_soft_brake, 0.0)
	assert_almost_eq(ship.rotation, -PI / 2.0, 1e-6)
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


func test_crash_ends_the_flight_once_with_outcome_crashed_and_no_respawn() -> void:
	Tuning.planet.carrier_patrol_speed = 0.0
	var saved_crashes: int = Telemetry.crashes
	Telemetry.crashes = 0
	var ship = _make()
	watch_signals(ship)
	ship.state.pos = Vector2(Tuning.field.planet_surface_radius - 10.0, 0.0)
	ship.state.hull = 12.0
	ship._physics_process(GravityField.DT)
	assert_eq(Telemetry.crashes, 1)
	assert_eq(ship.phase, ship.Phase.ENDED)
	assert_true(ship.state.crashed, "no respawn")
	assert_lt(ship.state.pos.length(), Tuning.field.planet_surface_radius)
	assert_signal_emit_count(ship, "flight_ended", 1)
	var summary: Dictionary = get_signal_parameters(ship, "flight_ended")[0]
	assert_eq(summary["outcome"], "crashed")
	assert_true(summary["cargo_lost"])
	var crash_pos: Vector2 = ship.state.pos
	ship._physics_process(GravityField.DT)
	ship._physics_process(GravityField.DT)
	assert_eq(Telemetry.crashes, 1)
	assert_eq(ship.state.pos, crash_pos, "crashed ship stays at the crash point")
	assert_signal_emit_count(ship, "flight_ended", 1)
	Telemetry.crashes = saved_crashes


func test_respawn_resets_phase_and_flight_start() -> void:
	var ship = _make()
	ship.state.pos = Vector2(Tuning.field.planet_surface_radius - 10.0, 0.0)
	ship._physics_process(GravityField.DT)
	assert_eq(ship.phase, ship.Phase.ENDED)
	GravityField.tick = 120
	ship.respawn()
	assert_eq(ship.phase, ship.Phase.FLYING)
	assert_eq(ship.flight_start_t, GravityField.time())
	assert_false(ship.state.crashed)


func test_preset_applied_mid_flight_emits_no_flight_ended() -> void:
	var ship = _make()
	watch_signals(ship)
	ship.respawn()
	assert_signal_not_emitted(ship, "flight_ended")


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


func _dock(ship: Node) -> void:
	ship.state.docked = true
	ship.state.pos = ShipFlight.carrier_pos(GravityField.time())


func test_docked_ends_the_flight_returned_once_and_ignores_thrust() -> void:
	var ship = _make()
	watch_signals(ship)
	_dock(ship)
	GravityField.tick = 300
	ship._physics_process(1.0 / 60.0)
	assert_eq(ship.phase, ship.Phase.ENDED)
	assert_signal_emit_count(ship, "flight_ended", 1)
	var summary: Dictionary = get_signal_parameters(ship, "flight_ended")[0]
	assert_eq(summary["outcome"], "returned")
	assert_false(summary["cargo_lost"])
	assert_almost_eq(summary["time"], GravityField.time() - ship.flight_start_t, 1e-6)
	Input.action_press("ship_thrust")
	ship._physics_process(1.0 / 60.0)
	Input.action_release("ship_thrust")
	Input.action_press("ship_thrust")
	ship._physics_process(1.0 / 60.0)
	assert_true(ship.state.docked, "thrust does not undock")
	assert_false(ship.input.thrust, "input is empty while ended")
	assert_eq(ship.state.pos, ShipFlight.carrier_pos(GravityField.time()), "keeps tracking the carrier")
	assert_signal_emit_count(ship, "flight_ended", 1)
	Input.action_release("ship_thrust")


func test_ended_docked_ship_tracks_a_patrolling_carrier() -> void:
	Tuning.planet.carrier_patrol_speed = 40.0
	var ship = _make()
	_dock(ship)
	ship._physics_process(1.0 / 60.0)
	var p0: Vector2 = ship.state.pos
	for i in 30:
		GravityField.tick += 1
		ship._physics_process(1.0 / 60.0)
		assert_eq(ship.state.pos, ShipFlight.carrier_pos(GravityField.time()))
	assert_ne(ship.state.pos, p0)
	assert_eq(ship.state.vel, ShipFlight.carrier_vel(GravityField.time()))


func test_summary_delay_default() -> void:
	assert_eq(Tuning.view.summary_delay, 1.5)


func test_fresh_ship_leaves_capture_radius_within_70s_with_no_input() -> void:
	Tuning.planet.carrier_patrol_speed = 0.0
	var ship = _make()
	var s: ShipState = ship.state
	var left := -1.0
	for i in 60 * 70:
		var t := GravityField.time_at(i + 1)
		s = ShipFlight.step(s, ShipInput.new(), t, GravityField.DT)
		if s.pos.distance_to(ShipFlight.carrier_pos(t)) >= Tuning.planet.capture_radius:
			left = t
			break
	assert_gt(left, 0.0, "left the zone")
	assert_false(s.docked)


func test_docked_tick_writes_docking_time() -> void:
	var ship = _make()
	ship.state.dock_armed = true
	ship.state.pos = ShipFlight.carrier_pos(GravityField.time()) + Vector2(5, 0)
	ship.state.vel = ShipFlight.carrier_vel(GravityField.time())
	ship.state.approach_time = 12.5
	ship._physics_process(1.0 / 60.0)
	assert_true(ship.state.docked)
	assert_gt(Telemetry.docking_time, 12.5)


func _tow_ship() -> Node:
	var ship = _make()
	ship.state.pos = Vector2(float(WellGenerator.tiers()["tow"]) + 500.0, 0.0)
	ship.state.vel = Vector2.ZERO
	return ship


func _press_tow(ship: Node, ticks: int) -> void:
	Input.action_press("ship_tow")
	for i in ticks:
		ship._physics_process(GravityField.DT)
	Input.action_release("ship_tow")
	ship._physics_process(GravityField.DT)


func _run_ticks(ship: Node, n: int) -> void:
	for i in n:
		ship._physics_process(GravityField.DT)


func test_accepted_call_ends_towed_after_delay_with_tank_drained_and_cargo_seized() -> void:
	var calls: int = Telemetry.tow_calls
	var ship = _tow_ship()
	Hold.add(ship.state, &"ore_middle", 3.0)
	var ends := []
	ship.flight_ended.connect(func(d): ends.append(d))
	_press_tow(ship, 125)
	assert_eq(Telemetry.tow_calls, calls + 1)
	assert_gt(ship.tow_left, 0.0)
	assert_true(ends.is_empty())
	_run_ticks(ship, int(Tuning.planet.tow_delay * 60.0) + 5)
	assert_eq(ends.size(), 1)
	assert_eq(ends[0]["outcome"], "towed")
	assert_true(ship.state.tank.is_empty())
	assert_gt(ends[0]["seized_share"], 0.0)
	assert_eq(Telemetry.tow_seized_share, ends[0]["seized_share"])
	assert_gt(Telemetry.tow_fee, 0.0)
	_run_ticks(ship, 10)
	assert_eq(ends.size(), 1)


func test_tow_refused_below_boundary_sets_notice_and_no_call() -> void:
	var calls: int = Telemetry.tow_calls
	var ship = _make()
	ship.state.pos = Vector2(float(WellGenerator.tiers()["tow"]) - 500.0, 0.0)
	_press_tow(ship, 125)
	assert_eq(ship.tow_left, -1.0)
	assert_eq(ship.tow_notice, "ниже границы буксира")
	assert_eq(Telemetry.tow_calls, calls)


func test_short_press_does_nothing_and_cancel_window_counts() -> void:
	var cancelled: int = Telemetry.tow_cancelled
	var ship = _tow_ship()
	_press_tow(ship, 10)
	assert_eq(ship.tow_left, -1.0)
	assert_eq(Telemetry.tow_cancelled, cancelled)
	_press_tow(ship, 60)
	assert_eq(ship.tow_left, -1.0)
	assert_eq(Telemetry.tow_cancelled, cancelled + 1)


func test_tow_breaks_when_descending_below_boundary() -> void:
	var ship = _tow_ship()
	ship.state.pos = Vector2(float(WellGenerator.tiers()["tow"]) + 1.0, 0.0)
	_press_tow(ship, 125)
	assert_gt(ship.tow_left, 0.0)
	ship.state.pos = Vector2(float(WellGenerator.tiers()["tow"]) - 100.0, 0.0)
	_run_ticks(ship, 2)
	assert_eq(ship.tow_left, -1.0)
	assert_eq(ship.tow_notice, "ниже границы буксира")


func test_empty_tank_still_calls_and_dock_before_arrival_returns() -> void:
	var ship = _tow_ship()
	ship.state.tank.clear()
	var ends := []
	ship.flight_ended.connect(func(d): ends.append(d))
	_press_tow(ship, 125)
	assert_gt(ship.tow_left, 0.0)
	ship.state.docked = true
	_run_ticks(ship, 2)
	assert_eq(ends.size(), 1)
	assert_eq(ends[0]["outcome"], "returned")
	assert_eq(ship.tow_left, -1.0)


func test_holding_tow_updates_preview_and_flag() -> void:
	var ship = _tow_ship()
	Hold.add(ship.state, &"ore_middle", 3.0)
	Input.action_press("ship_tow")
	ship._physics_process(GravityField.DT)
	Input.action_release("ship_tow")
	assert_true(ship.tow_holding)
	assert_almost_eq(ship.tow_share_preview, Tow.seized_share(ship.state), 0.05)


func _violation_ship(r: float) -> Node:
	var ship = _make()
	ship.state.pos = Vector2(r, 0.0)
	ship.state.vel = Vector2.ZERO
	return ship


func _ceiling_r() -> float:
	return float(WellGenerator.tiers()["ceiling"]) + 500.0


func test_crossing_the_ceiling_starts_the_violation_countdown() -> void:
	var ship = _violation_ship(_ceiling_r())
	ship._physics_process(GravityField.DT)
	assert_eq(ship.violation, "ceiling")
	assert_eq(ship.violation_ticks, 1)
	var need := ceili(Tuning.planet.violation_time / GravityField.DT)
	assert_almost_eq(ship.violation_left(), (need - 1) * GravityField.DT, 1e-6)
	ship.state.pos = Vector2(float(WellGenerator.tiers()["ceiling"]) - 500.0, 0.0)
	ship._physics_process(GravityField.DT)
	assert_eq(ship.violation, "")
	assert_eq(ship.violation_ticks, 0)
	assert_eq(ship.violation_left(), -1.0)


func test_ceiling_expiry_ends_towed_after_exact_ticks_with_ceiling_kind() -> void:
	var count: int = Telemetry.ceiling_tows
	var ship = _violation_ship(_ceiling_r())
	Hold.add(ship.state, &"ore_middle", 3.0)
	var ends := []
	ship.flight_ended.connect(func(d): ends.append(d))
	var need := ceili(Tuning.planet.violation_time / GravityField.DT)
	_run_ticks(ship, need - 1)
	assert_true(ends.is_empty())
	_run_ticks(ship, 1)
	assert_eq(ends.size(), 1)
	assert_eq(ends[0]["outcome"], "towed")
	assert_eq(ends[0]["tow_kind"], "ceiling")
	assert_true(ship.state.tank.is_empty())
	assert_lt(ends[0]["seized_share"], 1.0 + 1e-9)
	assert_eq(Telemetry.ceiling_tows, count + 1)
	_run_ticks(ship, 10)
	assert_eq(ends.size(), 1)
	assert_eq(Telemetry.ceiling_tows, count + 1)


func test_boat_below_boundary_is_forced_tow_seizing_all_cargo() -> void:
	var count: int = Telemetry.forced_tows
	var ship = _violation_ship(float(WellGenerator.tiers()["tow"]) - 500.0)
	Hold.add(ship.state, &"ore_middle", 3.0)
	var ends := []
	ship.flight_ended.connect(func(d): ends.append(d))
	_run_ticks(ship, ceili(Tuning.planet.violation_time / GravityField.DT))
	assert_eq(ends.size(), 1)
	assert_eq(ends[0]["tow_kind"], "forced")
	assert_eq(ends[0]["seized_share"], 1.0)
	assert_true(ends[0]["cargo"].is_empty())
	assert_gt(Telemetry.tow_fee, 0.0)
	assert_eq(Telemetry.forced_tows, count + 1)


func test_non_boat_below_boundary_never_counts() -> void:
	var saved: ShipParams = Tuning.ship
	Tuning.ship = Tuning.ship.duplicate()
	Tuning.ship.service_boat = false
	var ship = _violation_ship(float(WellGenerator.tiers()["tow"]) - 500.0)
	var ends := []
	ship.flight_ended.connect(func(d): ends.append(d))
	_run_ticks(ship, 5)
	assert_eq(ship.violation, "")
	assert_eq(ship.violation_ticks, 0)
	Tuning.ship = saved


func test_manual_tow_above_the_ceiling_still_arrives_as_manual() -> void:
	var saved: float = Tuning.planet.violation_time
	Tuning.planet.violation_time = 60.0
	var ship = _violation_ship(_ceiling_r())
	var ends := []
	ship.flight_ended.connect(func(d): ends.append(d))
	_press_tow(ship, 125)
	assert_gt(ship.tow_left, 0.0)
	_run_ticks(ship, int(Tuning.planet.tow_delay * 60.0) + 5)
	assert_eq(ends.size(), 1)
	assert_eq(ends[0]["tow_kind"], "manual")
	Tuning.planet.violation_time = saved
