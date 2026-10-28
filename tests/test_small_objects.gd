extends GutTest

var _saved_field
var _saved_planet


func before_each():
	_saved_field = Tuning.field
	_saved_planet = Tuning.planet
	Tuning.planet = PlanetParams.new()
	Tuning.planet.asteroids_per_band = 0.0


func after_each():
	Tuning.field = _saved_field
	Tuning.planet = _saved_planet


func _ship_at(pos: Vector2) -> ShipState:
	var s := ShipState.new()
	s.pos = pos
	return s


func test_update_integrates_bodies_like_free_body() -> void:
	var s := _ship_at(Vector2(121500.0, 0.0))
	var b := FreeBody.new()
	b.pos = Vector2(121500.0, 500.0)
	b.vel = Vector2(-30.0, 10.0)
	s.bodies.append(b)
	var ref := b.copy()
	SmallObjects.update(s, 1.0, 1.0 / 60.0)
	FreeBody.integrate(ref, 1.0, 1.0 / 60.0)
	assert_eq(s.bodies.size(), 1)
	assert_eq(s.bodies[0].pos, ref.pos)


func test_update_removes_far_atmosphere_and_moon_bodies() -> void:
	var f: FieldParams = Tuning.field.duplicate(true)
	var moon := BodyParams.new()
	moon.parent = 0
	moon.orbit_radius = 121500.0
	moon.radius = 500.0
	moon.mass = 1.0
	moon.p = 2.0
	var bodies: Array[BodyParams] = [f.bodies[0], moon]
	f.bodies = bodies
	Tuning.field = f
	var s := _ship_at(Vector2(121500.0, 1000.0))
	for pos in [Vector2(121500.0, 5000.0), Vector2(101000.0, 0.0), Vector2(121500.0, 100.0), Vector2(121500.0, 1500.0)]:
		var b := FreeBody.new()
		b.pos = pos
		s.bodies.append(b)
	SmallObjects.update(s, 0.0, 1.0 / 60.0)
	assert_eq(s.bodies.size(), 1)
	assert_almost_eq(s.bodies[0].pos.y, 1500.0, 1.0)


func _near_body(is_piece: bool) -> FreeBody:
	var b := FreeBody.new()
	b.pos = Vector2(121500.0, 500.0)
	b.piece = is_piece
	return b


func test_piece_crumbles_at_lifetime() -> void:
	Tuning.planet.piece_lifetime = 1.0
	var s := _ship_at(Vector2(121500.0, 0.0))
	s.bodies.append(_near_body(true))
	var dt := 0.25
	SmallObjects.update(s, 1.0, dt)
	assert_eq(s.bodies.size(), 1)
	assert_almost_eq(s.bodies[0].age, dt, 1e-6)
	for i in 3:
		SmallObjects.update(s, 1.0, dt)
	assert_eq(s.bodies.size(), 0)


func _sized_piece(radius: float) -> FreeBody:
	var b := _near_body(true)
	b.radius = radius
	b.radius0 = radius
	return b


func test_piece_lifetime_scales_with_radius_over_collect_radius() -> void:
	Tuning.planet.piece_lifetime = 10.0
	Tuning.planet.collect_radius = 20.0
	var cases := [[40.0, 19.0, 1], [40.0, 20.0, 0], [10.0, 10.0, 0], [10.0, 9.0, 1]]
	for c in cases:
		var s := _ship_at(Vector2(121500.0, 0.0))
		s.bodies.append(_sized_piece(c[0]))
		SmallObjects.update(s, 1.0, c[1])
		assert_eq(s.bodies.size(), c[2], "r %s age %s" % [c[0], c[1]])


func test_update_with_no_bodies_spawns_nothing() -> void:
	var s := _ship_at(Vector2(121500.0, 0.0))
	for i in 300:
		SmallObjects.update(s, float(i + 1), 1.0)
	assert_eq(s.bodies.size(), 0)


func _shrinking_piece(r0: float) -> FreeBody:
	var b := _sized_piece(r0)
	b.amount = 6.0
	b.points = PackedVector2Array([Vector2(-r0, -r0), Vector2(r0, -r0), Vector2(r0, r0), Vector2(-r0, r0)])
	return b


func test_piece_area_falls_linearly_to_min_radius_over_its_life() -> void:
	Tuning.planet.piece_lifetime = 10.0
	Tuning.planet.collect_radius = 20.0
	Tuning.planet.piece_min_radius = 5.0
	var life := 20.0
	var s := _ship_at(Vector2(121500.0, 0.0))
	s.bodies.append(_shrinking_piece(40.0))
	var dt := 0.5
	for i in int(life / 2.0 / dt):
		SmallObjects.update(s, 1.0, dt)
	var k := (1.0 + pow(5.0 / 40.0, 2)) / 2.0
	var b: FreeBody = s.bodies[0]
	assert_almost_eq(b.amount, 6.0 * k, 1e-3)
	assert_almost_eq(b.radius, 40.0 * sqrt(k), 1e-3)
	assert_almost_eq(b.points[1].x, 40.0 * sqrt(k), 1e-3)
	while s.bodies.size() > 0 and s.bodies[0].age < life - dt - 1e-6:
		SmallObjects.update(s, 1.0, dt)
	assert_eq(s.bodies.size(), 1)
	var k_late := 1.0 - (1.0 - pow(5.0 / 40.0, 2)) * s.bodies[0].age / life
	assert_almost_eq(s.bodies[0].radius, 40.0 * sqrt(k_late), 1e-3)
	SmallObjects.update(s, 1.0, dt)
	assert_eq(s.bodies.size(), 0)


func test_partial_pickup_is_not_restored_by_shrinking() -> void:
	Tuning.planet.piece_lifetime = 10.0
	Tuning.planet.piece_min_radius = 5.0
	var s := _ship_at(Vector2(121500.0, 0.0))
	s.bodies.append(_shrinking_piece(40.0))
	for i in 10:
		SmallObjects.update(s, 1.0, 0.5)
	var before: float = s.bodies[0].amount
	s.bodies[0].amount = before / 2.0
	SmallObjects.update(s, 1.0, 0.5)
	assert_lt(s.bodies[0].amount, before / 2.0)
	assert_gt(s.bodies[0].amount, before / 2.0 * 0.9)


func test_piece_born_below_min_radius_keeps_its_size() -> void:
	Tuning.planet.piece_lifetime = 10.0
	Tuning.planet.piece_min_radius = 5.0
	var s := _ship_at(Vector2(121500.0, 0.0))
	s.bodies.append(_shrinking_piece(4.0))
	SmallObjects.update(s, 1.0, 5.0)
	assert_eq(s.bodies[0].radius, 4.0)
	assert_eq(s.bodies[0].amount, 6.0)
	SmallObjects.update(s, 1.0, 5.0)
	assert_eq(s.bodies.size(), 0)


func test_container_ages_without_shrinking_or_expiring() -> void:
	Tuning.planet.piece_lifetime = 1.0
	var s := _ship_at(Vector2(121500.0, 0.0))
	var b := _near_body(false)
	b.container = true
	b.radius = 3.0
	b.amount = 0.7
	b.pos = Vector2(121500.0, Tuning.planet.piece_despawn_radius + 5000.0)
	s.bodies.append(b)
	for i in 8:
		SmallObjects.update(s, 1.0, 0.25)
	assert_eq(s.bodies.size(), 1)
	assert_eq(s.bodies[0].radius, 3.0)
	assert_eq(s.bodies[0].amount, 0.7)
	assert_eq(s.bodies[0].age, 2.0)
	assert_eq(s.bodies[0].points.size(), 0)
	s.bodies[0].pos = Vector2(0.0, 100.0)
	SmallObjects.update(s, 1.0, 0.25)
	assert_eq(s.bodies.size(), 0)
