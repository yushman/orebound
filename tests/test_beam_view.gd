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
