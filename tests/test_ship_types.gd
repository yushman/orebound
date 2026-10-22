extends GutTest


func test_state_copy_is_independent_and_equal() -> void:
	var s := ShipState.new()
	s.pos = Vector2(1, 2)
	s.vel = Vector2(3, 4)
	s.rot = 0.5
	s.ang_vel = 0.6
	s.fuel_engine = 0.7
	s.fuel_boost = 0.8
	var c := s.copy()
	assert_not_null(c)
	assert_ne(c, s)
	assert_eq(c.pos, s.pos)
	assert_eq(c.vel, s.vel)
	assert_eq(c.rot, s.rot)
	assert_eq(c.ang_vel, s.ang_vel)
	assert_eq(c.fuel_engine, s.fuel_engine)
	assert_eq(c.fuel_boost, s.fuel_boost)
	c.pos = Vector2(9, 9)
	c.fuel_boost = 5.0
	assert_eq(s.pos, Vector2(1, 2))
	assert_eq(s.fuel_boost, 0.8)


func test_input_copy_is_independent_and_equal() -> void:
	var i := ShipInput.new()
	i.turn = -1.0
	i.has_heading = true
	i.target_heading = 1.5
	i.thrust = true
	i.boost = true
	var c := i.copy()
	assert_not_null(c)
	assert_ne(c, i)
	assert_eq(c.turn, -1.0)
	assert_true(c.has_heading)
	assert_eq(c.target_heading, 1.5)
	assert_true(c.thrust)
	assert_true(c.boost)
	c.turn = 1.0
	c.thrust = false
	assert_eq(i.turn, -1.0)
	assert_true(i.thrust)
