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


func _event(angle := 0.7, e := 0.5, nu := 1.0) -> Dictionary:
	return {"time": 0.0, "angle": angle, "e": e, "nu": nu, "radius": 30.0,
		"points": PackedVector2Array([Vector2(-10, -10), Vector2(10, -10), Vector2(0, 12)]),
		"type": &"ice", "amount": 5.0, "id": 42}


func test_spawn_sits_at_spawn_radius_from_ship() -> void:
	var ship := Vector2(121500.0, 0.0)
	var b := SmallObjects.spawn(_event(), ship, 0.0)
	assert_not_null(b)
	assert_almost_eq(b.pos.distance_to(ship), Tuning.planet.small_spawn_radius, 1e-2)
	assert_almost_eq((b.pos - ship).angle(), 0.7, 1e-4)
	assert_eq(b.id, 42)
	assert_eq(b.type, &"ice")
	assert_eq(b.radius, 30.0)


func test_spawn_velocity_gives_orbit_of_event_eccentricity() -> void:
	var ship := Vector2(121500.0, 0.0)
	for e in [0.3, 0.55, 0.8]:
		var b := SmallObjects.spawn(_event(0.7, e, 2.0), ship, 0.0)
		var r := b.pos.length()
		var gm := r * r * GravityField.accel_of(0, b.pos, 0.0).length()
		var om := GravityField.frame_omega()
		var v := b.vel + om * Vector2(-b.pos.y, b.pos.x)
		var h := b.pos.cross(v)
		var energy := 0.5 * v.length_squared() - gm / r
		var ecc := sqrt(maxf(1.0 + 2.0 * energy * h * h / (gm * gm), 0.0))
		assert_almost_eq(ecc, e, 1e-3)


func test_spawn_skips_atmosphere_and_moon() -> void:
	var inside := Vector2(101600.0, 0.0)
	assert_null(SmallObjects.spawn(_event(PI), inside, 0.0))
	var f: FieldParams = Tuning.field.duplicate(true)
	var moon := BodyParams.new()
	moon.parent = 0
	moon.orbit_radius = 121500.0
	moon.phase = 0.0
	moon.radius = 500.0
	moon.mass = 1.0
	moon.p = 2.0
	var bodies: Array[BodyParams] = [f.bodies[0], moon]
	f.bodies = bodies
	Tuning.field = f
	var ship := Vector2(121500.0, Tuning.planet.small_spawn_radius)
	assert_null(SmallObjects.spawn(_event(-PI / 2.0), ship, 0.0))


func _busy() -> void:
	var rates: Array[float] = [20.0, 20.0, 20.0, 20.0]
	Tuning.planet.small_rate = rates


func _ship_at(pos: Vector2) -> ShipState:
	var s := ShipState.new()
	s.pos = pos
	return s


func _ids(s: ShipState) -> Array:
	var out: Array = []
	for b in s.bodies:
		out.append(b.id)
	return out


func test_update_spawns_only_events_due_in_the_step() -> void:
	_busy()
	var ship := Vector2(121500.0, 0.0)
	var events := SmallObjectSchedule.schedule(Tuning.picture["seed"], Tuning.picture["flight"], 3, 0)
	assert_gt(events.size(), 1)
	var ev: Dictionary = events[0]
	var dt := 1.0 / 60.0
	var s := _ship_at(ship)
	SmallObjects.update(s, ev["time"] - 2.0 * dt, dt)
	assert_false(_ids(s).has(ev["id"]))
	SmallObjects.update(s, ev["time"], dt)
	assert_true(_ids(s).has(ev["id"]))
	SmallObjects.update(s, ev["time"], dt)
	assert_eq(_ids(s).count(ev["id"]), 1)


func test_update_stops_at_max_bodies() -> void:
	_busy()
	Tuning.planet.small_max_bodies = 2
	Tuning.planet.small_despawn_radius = 1e9
	var s := _ship_at(Vector2(121500.0, 0.0))
	SmallObjects.update(s, 30.0, 30.0)
	assert_eq(s.bodies.size(), 2)


func test_update_integrates_bodies_like_free_body() -> void:
	var s := _ship_at(Vector2(121500.0, 0.0))
	var b := FreeBody.new()
	b.pos = Vector2(121500.0, 500.0)
	b.vel = Vector2(-30.0, 10.0)
	s.bodies.append(b)
	var ref := b.copy()
	var rates: Array[float] = [0.0, 0.0, 0.0, 0.0]
	Tuning.planet.small_rate = rates
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
	var rates: Array[float] = [0.0, 0.0, 0.0, 0.0]
	Tuning.planet.small_rate = rates
	var s := _ship_at(Vector2(121500.0, 1000.0))
	for pos in [Vector2(121500.0, 5000.0), Vector2(101000.0, 0.0), Vector2(121500.0, 100.0), Vector2(121500.0, 1500.0)]:
		var b := FreeBody.new()
		b.pos = pos
		s.bodies.append(b)
	SmallObjects.update(s, 0.0, 1.0 / 60.0)
	assert_eq(s.bodies.size(), 1)
	assert_almost_eq(s.bodies[0].pos.y, 1500.0, 1.0)
