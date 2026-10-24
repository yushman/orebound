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
