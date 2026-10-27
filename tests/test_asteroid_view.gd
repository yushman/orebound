extends GutTest

const AsteroidViewScript := preload("res://scenes/AsteroidView.gd")

var _saved_field
var _saved_planet
var _saved_picture


func before_each():
	_saved_field = Tuning.field
	_saved_planet = Tuning.planet
	_saved_picture = Tuning.picture
	Tuning.planet = PlanetParams.new()
	Tuning.planet.asteroids_per_band = 20.0
	Tuning.picture = {"seed": 3, "flight": 1, "moons": [], "ring": {}}


func after_each():
	Tuning.field = _saved_field
	Tuning.planet = _saved_planet
	Tuning.picture = _saved_picture


func _polys(v) -> Array:
	var out := []
	for c in v.get_children():
		if c is Polygon2D and c.visible:
			out.append(c)
	return out


func _spot() -> Vector2:
	return Vector2(Tuning.field.atmosphere_edge + 3.5 * Tuning.planet.band_width, 0.0)


func test_asteroid_view_shows_one_polygon_per_asteroid_within_gen_radius():
	var v = add_child_autofree(AsteroidViewScript.new())
	var pos := _spot()
	var t := 10.0
	var want: Array = AsteroidField.near(pos, t, Tuning.planet.chunk_gen_radius)
	assert_gt(want.size(), 0)
	v.refresh(pos, t)
	var polys := _polys(v)
	assert_eq(polys.size(), want.size())
	for p in polys:
		assert_lte(p.position.distance_to(pos), Tuning.planet.chunk_gen_radius + 1.0)
	var first = polys[0]
	assert_eq(first.polygon, want[0]["points"])
	assert_eq(first.position, want[0]["pos"])
	assert_eq(first.color, AsteroidViewScript.color_of(want[0]["type"]))
	# positions follow t, pool is kept
	v.refresh(pos, t + 5.0)
	var again := _polys(v)
	assert_eq(again.size(), want.size())
	assert_true(again[0] == first, "pool not rebuilt while the set is unchanged")
	var moved: Array = AsteroidField.near(pos, t + 5.0, Tuning.planet.chunk_gen_radius)
	assert_eq(first.position, moved[0]["pos"])
	assert_ne(first.position, want[0]["pos"])
	# far from every field: nothing shown
	v.refresh(Vector2(Tuning.field.carrier_orbit_radius * 3.0, 0.0), t)
	assert_eq(_polys(v).size(), 0)


func test_asteroid_view_rebuilds_when_points_change_with_same_keys():
	var v = add_child_autofree(AsteroidViewScript.new())
	var pos := _spot()
	v.refresh(pos, 10.0)
	var before: PackedVector2Array = _polys(v)[0].polygon
	Tuning.planet.ast_radius_min = 20.0
	Tuning.planet.ast_radius_max = 30.0
	v.refresh(pos, 10.0)
	var want: Array = AsteroidField.near(pos, 10.0, Tuning.planet.chunk_gen_radius)
	assert_ne(want[0]["points"], before)
	assert_eq(_polys(v).size(), want.size())
	assert_eq(_polys(v)[0].polygon, want[0]["points"])


func test_asteroid_view_rebuilds_on_preset_applied():
	var v = add_child_autofree(AsteroidViewScript.new())
	var pos := _spot()
	v.refresh(pos, 10.0)
	var p = _polys(v)[0]
	p.polygon = PackedVector2Array()
	Tuning.preset_applied.emit()
	v.refresh(pos, 10.0)
	var want: Array = AsteroidField.near(pos, 10.0, Tuning.planet.chunk_gen_radius)
	assert_eq(_polys(v)[0].polygon, want[0]["points"])


func test_asteroid_view_rotates_polygons_with_omega_t():
	var v = add_child_autofree(AsteroidViewScript.new())
	var pos := _spot()
	var t := 3000.0
	v.refresh(pos, t)
	var want: Array = AsteroidField.near(pos, t, Tuning.planet.chunk_gen_radius)
	var polys := _polys(v)
	for i in want.size():
		assert_almost_eq(polys[i].rotation, wrapf(want[i]["omega"] * t, -PI, PI), 0.0001)


func test_asteroid_view_hides_all_after_preset_applied_leaves_no_asteroids():
	var v = add_child_autofree(AsteroidViewScript.new())
	var pos := _spot()
	v.refresh(pos, 10.0)
	assert_gt(_polys(v).size(), 0)
	var moon := BodyParams.new()
	moon.orbit_radius = pos.length()
	moon.influence_radius = 100000.0
	Tuning.picture = {"seed": 3, "flight": 1, "moons": [moon], "ring": {}}
	assert_eq(AsteroidField.near(pos, 10.0, Tuning.planet.chunk_gen_radius).size(), 0)
	Tuning.preset_applied.emit()
	v.refresh(pos, 10.0)
	assert_eq(_polys(v).size(), 0)


func test_asteroid_polygons_are_coloured_by_type():
	assert_eq(AsteroidViewScript.color_of(&"ice"), Palette.ICE)
	assert_eq(AsteroidViewScript.color_of(&"ore_base"), Palette.ORE_BASE)
	assert_eq(AsteroidViewScript.color_of(&"ore_middle"), Palette.ORE)
	assert_eq(AsteroidViewScript.color_of(&"ore_rare"), Palette.ORE_RARE)
	assert_eq(AsteroidViewScript.color_of(&"ore_unique"), Palette.ORE_BRIGHT)
	var v = add_child_autofree(AsteroidViewScript.new())
	var pos := _spot()
	v.refresh(pos, 10.0)
	var want: Array = AsteroidField.near(pos, 10.0, Tuning.planet.chunk_gen_radius)
	var polys := _polys(v)
	for i in want.size():
		assert_eq(polys[i].color, AsteroidViewScript.color_of(want[i]["type"]))


func test_asteroid_view_hides_a_broken_asteroid():
	var v = add_child_autofree(AsteroidViewScript.new())
	var pos := _spot()
	var want: Array = AsteroidField.near(pos, 10.0, Tuning.planet.chunk_gen_radius)
	var b: Dictionary = want[1]
	var k1 := Vector3i(b["band"], b["chunk"], b["idx"])
	v.refresh(pos, 10.0, {})
	var polys := _polys(v)
	assert_eq(polys.size(), want.size())
	assert_eq(polys[1].polygon, b["points"])
	v.refresh(pos, 10.0, {k1: true})
	polys = _polys(v)
	assert_eq(polys.size(), want.size() - 1)
	assert_eq(polys[1].polygon, want[2]["points"])
