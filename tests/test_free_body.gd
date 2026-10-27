extends GutTest

var _saved_planet


func before_each():
	_saved_planet = Tuning.planet
	Tuning.planet = PlanetParams.new()
	Tuning.planet.asteroids_per_band = 0.0
	Tuning.planet.atmosphere_drag = 0.0


func after_each():
	Tuning.planet = _saved_planet


func test_integrate_matches_ship_flight_without_thrust():
	var s := ShipState.new()
	s.pos = Vector2(900.0, 300.0)
	s.vel = Vector2(-20.0, 35.0)
	var b := FreeBody.new()
	b.pos = s.pos
	b.vel = s.vel
	var dt := 1.0 / 60.0
	var t := 0.0
	for i in 120:
		s = ShipFlight.step(s, ShipInput.new(), t, dt)
		FreeBody.integrate(b, t, dt)
		t += dt
	assert_almost_eq(b.pos.x, s.pos.x, 1e-3)
	assert_almost_eq(b.pos.y, s.pos.y, 1e-3)
	assert_almost_eq(b.vel.x, s.vel.x, 1e-3)
	assert_almost_eq(b.vel.y, s.vel.y, 1e-3)


func test_copy_is_independent():
	var b := FreeBody.new()
	b.pos = Vector2(1, 2)
	b.vel = Vector2(3, 4)
	b.radius = 5.0
	b.points = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.UP])
	b.type = &"ice"
	b.amount = 7.0
	b.id = 9
	var c := b.copy()
	assert_eq(c.pos, b.pos)
	assert_eq(c.vel, b.vel)
	assert_eq(c.radius, 5.0)
	assert_eq(c.points, b.points)
	assert_eq(c.type, &"ice")
	assert_eq(c.amount, 7.0)
	assert_eq(c.id, 9)
	c.pos = Vector2(9, 9)
	c.points[0] = Vector2(5, 5)
	assert_eq(b.pos, Vector2(1, 2))
	assert_eq(b.points[0], Vector2.ZERO)
