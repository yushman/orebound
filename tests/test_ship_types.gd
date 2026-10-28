extends GutTest


func test_state_copy_is_independent_and_equal() -> void:
	var s := ShipState.new()
	s.pos = Vector2(1, 2)
	s.vel = Vector2(3, 4)
	s.rot = 0.5
	s.ang_vel = 0.6
	s.fuel_engine = 0.7
	s.fuel_boost = 0.8
	s.fuel_soft_brake = 0.9
	var c := s.copy()
	assert_not_null(c)
	assert_ne(c, s)
	assert_eq(c.pos, s.pos)
	assert_eq(c.vel, s.vel)
	assert_eq(c.rot, s.rot)
	assert_eq(c.ang_vel, s.ang_vel)
	assert_eq(c.fuel_engine, s.fuel_engine)
	assert_eq(c.fuel_boost, s.fuel_boost)
	assert_eq(c.fuel_soft_brake, s.fuel_soft_brake)
	c.pos = Vector2(9, 9)
	c.fuel_boost = 5.0
	c.fuel_soft_brake = 6.0
	assert_eq(s.pos, Vector2(1, 2))
	assert_eq(s.fuel_boost, 0.8)
	assert_eq(s.fuel_soft_brake, 0.9)


func test_state_copy_carries_hold_time_heat_and_sync_counters() -> void:
	var s := ShipState.new()
	s.hold_time = 1.25
	s.heat = 0.5
	s.fuel_sync = 2.5
	var c := s.copy()
	assert_eq(c.hold_time, 1.25)
	assert_eq(c.heat, 0.5)
	assert_eq(c.fuel_sync, 2.5)
	c.hold_time = 9.0
	c.heat = 1.0
	c.fuel_sync = 8.0
	assert_eq(s.hold_time, 1.25)
	assert_eq(s.heat, 0.5)
	assert_eq(s.fuel_sync, 2.5)


func test_input_copy_is_independent_and_equal() -> void:
	var i := ShipInput.new()
	i.turn = -1.0
	i.has_heading = true
	i.target_heading = 1.5
	i.thrust = true
	i.boost = true
	i.soft_brake = true
	i.drift_sync = true
	var c := i.copy()
	assert_not_null(c)
	assert_ne(c, i)
	assert_eq(c.turn, -1.0)
	assert_true(c.has_heading)
	assert_eq(c.target_heading, 1.5)
	assert_true(c.thrust)
	assert_true(c.boost)
	assert_true(c.soft_brake)
	assert_true(c.drift_sync)
	c.turn = 1.0
	c.thrust = false
	c.soft_brake = false
	c.drift_sync = false
	assert_eq(i.turn, -1.0)
	assert_true(i.thrust)
	assert_true(i.soft_brake)
	assert_true(i.drift_sync)


func test_state_copy_carries_hull_and_crashed_independently() -> void:
	var s := ShipState.new()
	s.hull = 42.5
	s.crashed = true
	var c := s.copy()
	assert_eq(c.hull, 42.5)
	assert_true(c.crashed)
	c.hull = 1.0
	c.crashed = false
	assert_eq(s.hull, 42.5)
	assert_true(s.crashed)


func _cell(type: StringName, fill: float) -> HoldCell:
	var c := HoldCell.new()
	c.type = type
	c.fill = fill
	return c


func test_state_copy_deep_copies_hold_and_tank_cells() -> void:
	var s := ShipState.new()
	s.hold.clear()
	s.tank.clear()
	s.hold.append(_cell(&"ice", 0.5))
	s.tank.append(_cell(&"fuel", 1.0))
	var c := s.copy()
	assert_eq(c.hold.size(), 1)
	assert_eq(c.hold[0].type, &"ice")
	assert_eq(c.hold[0].fill, 0.5)
	assert_eq(c.tank[0].type, &"fuel")
	c.hold[0].fill = 0.9
	c.tank[0].fill = 0.1
	c.hold.append(_cell(&"ice", 1.0))
	c.tank.append(_cell(&"fuel", 1.0))
	assert_eq(s.hold[0].fill, 0.5)
	assert_eq(s.tank[0].fill, 1.0)
	assert_eq(s.hold.size(), 1)
	assert_eq(s.tank.size(), 1)


func test_state_copy_deep_copies_the_broken_layer() -> void:
	var s := ShipState.new()
	assert_true(s.broken.is_empty())
	s.broken[Vector3i(1, 2, 3)] = true
	var c := s.copy()
	assert_true(c.broken[Vector3i(1, 2, 3)])
	c.broken[Vector3i(0, 0, 0)] = true
	assert_eq(s.broken.size(), 1)


func test_state_copy_carries_beam_target_and_charge() -> void:
	var s := ShipState.new()
	assert_null(s.beam_target)
	assert_eq(s.beam_charge, 0.0)
	s.beam_target = Vector3i(1, 2, 3)
	s.beam_charge = 0.4
	var c := s.copy()
	assert_eq(c.beam_target, Vector3i(1, 2, 3))
	assert_eq(c.beam_charge, 0.4)


func test_input_copy_carries_beam_and_aim() -> void:
	var i := ShipInput.new()
	i.beam = true
	i.aim = 0.7
	var c := i.copy()
	assert_true(c.beam)
	assert_eq(c.aim, 0.7)
	c.beam = false
	assert_true(i.beam)


func test_beam_aim_prefers_stick_then_mouse_then_nose() -> void:
	var pos := Vector2(Tuning.field.carrier_orbit_radius, 0.0)
	var cam := FlightCamera.rotation_for(pos)
	var stick := Vector2(0.0, -1.0)
	var a := ShipInput.aim_angle(stick, true, pos + Vector2(0, 100), pos, 0.3)
	assert_almost_eq(Vector2.RIGHT.rotated(a).dot(Vector2.UP.rotated(cam)), 1.0, 0.0001)
	a = ShipInput.aim_angle(Vector2.ZERO, true, pos + Vector2(0, 100), pos, 0.3)
	assert_almost_eq(a, PI / 2, 0.0001)
	a = ShipInput.aim_angle(Vector2.ZERO, false, pos + Vector2(0, 100), pos, 0.3)
	assert_almost_eq(Vector2.RIGHT.rotated(a).dot(Vector2.UP.rotated(0.3)), 1.0, 0.0001)


func test_state_copy_deep_copies_bodies() -> void:
	var s := ShipState.new()
	assert_eq(s.bodies.size(), 0)
	var b := FreeBody.new()
	b.pos = Vector2(1, 2)
	b.id = 3
	s.bodies.append(b)
	var c := s.copy()
	assert_eq(c.bodies.size(), 1)
	assert_eq(c.bodies[0].pos, Vector2(1, 2))
	assert_eq(c.bodies[0].id, 3)
	c.bodies[0].pos = Vector2(9, 9)
	c.bodies.append(FreeBody.new())
	assert_eq(s.bodies[0].pos, Vector2(1, 2))
	assert_eq(s.bodies.size(), 1)


func test_input_copy_carries_collect() -> void:
	var i := ShipInput.new()
	i.collect = true
	var c := i.copy()
	assert_true(c.collect)
	c.collect = false
	assert_true(i.collect)


func test_copy_keeps_jettison_select_pick_and_container() -> void:
	var i := ShipInput.new()
	i.jettison = true
	i.jettison_select = true
	var ic := i.copy()
	assert_true(ic.jettison)
	assert_true(ic.jettison_select)
	ic.jettison = false
	assert_true(i.jettison)
	var s := ShipState.new()
	assert_eq(s.jettison_pick, -1)
	s.jettison_pick = 1
	var sc := s.copy()
	assert_eq(sc.jettison_pick, 1)
	sc.jettison_pick = 0
	assert_eq(s.jettison_pick, 1)
	var b := FreeBody.new()
	assert_false(b.container)
	b.container = true
	var bc := b.copy()
	assert_true(bc.container)
	bc.container = false
	assert_true(b.container)


func test_copy_keeps_transfer() -> void:
	var i := ShipInput.new()
	assert_false(i.transfer)
	i.transfer = true
	var ic := i.copy()
	assert_true(ic.transfer)
	ic.transfer = false
	assert_true(i.transfer)
