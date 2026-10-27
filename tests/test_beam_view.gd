extends GutTest

var _saved_planet
var _saved_picture


func before_each():
	_saved_planet = Tuning.planet
	_saved_picture = Tuning.picture
	Tuning.planet = PlanetParams.new()
	Tuning.planet.asteroids_per_band = 0.0
	Tuning.picture = {"seed": 3, "flight": 1, "moons": [], "ring": {}}


func after_each():
	Tuning.planet = _saved_planet
	Tuning.picture = _saved_picture


func _inp(beam: bool, aim: float) -> ShipInput:
	var i := ShipInput.new()
	i.beam = beam
	i.aim = aim
	return i


func test_beam_view_draws_a_line_from_the_ship_to_the_hit_point_while_the_beam_is_held():
	Tuning.planet.asteroids_per_band = 20.0
	var v = add_child_autofree(BeamView.new())
	var s := ShipState.new()
	s.pos = Vector2(Tuning.field.atmosphere_edge + 3.5 * Tuning.planet.band_width, 0.0)
	var t := 10.0
	var a: Dictionary = AsteroidField.near(s.pos, t, Tuning.planet.chunk_gen_radius)[0]
	var dir := Vector2.from_angle(a["theta"] + 0.3)
	s.pos = a["pos"] + dir * (a["radius"] + 50.0)
	var aim: float = (a["pos"] - s.pos).angle()
	var key := Vector3i(a["band"], a["chunk"], a["idx"])
	a["key"] = key
	a["rot"] = a["omega"] * t
	var h := Beam.hit(s.pos, aim, Tuning.ship.beam_range, [a])
	assert_false(h.is_empty())
	v.refresh(s, _inp(true, aim), t)
	assert_true(v.visible)
	assert_eq(v.points.size(), 2)
	assert_eq(v.points[0], s.pos)
	assert_almost_eq(v.points[1], h["point"], Vector2(0.01, 0.01))
	assert_lt(v.points[1].distance_to(s.pos), Tuning.ship.beam_range)
	v.refresh(s, _inp(false, aim), t)
	assert_false(v.visible)


func test_beam_view_runs_full_range_on_a_miss():
	var v = add_child_autofree(BeamView.new())
	var s := ShipState.new()
	s.pos = Vector2(1000.0, 0.0)
	v.refresh(s, _inp(true, PI * 0.5), 1.0)
	assert_true(v.visible)
	assert_almost_eq(v.points[1], s.pos + Vector2(0, Tuning.ship.beam_range), Vector2(0.01, 0.01))


func test_beam_view_ends_at_the_hit_point_on_a_non_collectible_body_and_passes_through_a_collectible_one():
	var v = add_child_autofree(BeamView.new())
	var s := ShipState.new()
	var R: float = Tuning.field.carrier_orbit_radius
	s.pos = Vector2(R, 0.0)
	var big := FreeBody.new()
	big.pos = s.pos + Vector2(150.0, 0.0)
	big.radius = 40.0
	big.points = PackedVector2Array([Vector2(-40, -40), Vector2(40, -40), Vector2(40, 40), Vector2(-40, 40)])
	big.id = 1
	var small := big.copy()
	small.pos = s.pos + Vector2(80.0, 0.0)
	small.radius = 15.0
	small.id = 2
	s.bodies = [small, big]
	v.refresh(s, _inp(true, 0.0), 0.0)
	assert_almost_eq(v.points[1], s.pos + Vector2(110.0, 0.0), Vector2(0.01, 0.01))
	s.bodies = [small]
	v.refresh(s, _inp(true, 0.0), 0.0)
	assert_almost_eq(v.points[1], s.pos + Vector2(Tuning.ship.beam_range, 0.0), Vector2(0.01, 0.01))
