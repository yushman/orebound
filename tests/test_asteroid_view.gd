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
	return v.shown


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
		assert_lte(p.pos.distance_to(pos), Tuning.planet.chunk_gen_radius + 1.0)
	var first = polys[0]
	assert_eq(first.points, want[0]["points"])
	assert_eq(first.pos, want[0]["pos"])
	assert_eq(first.color, AsteroidViewScript.color_of(want[0]["type"]))
	# positions follow t
	v.refresh(pos, t + 5.0)
	var again := _polys(v)
	assert_eq(again.size(), want.size())
	var moved: Array = AsteroidField.near(pos, t + 5.0, Tuning.planet.chunk_gen_radius)
	assert_eq(again[0].pos, moved[0]["pos"])
	assert_ne(again[0].pos, want[0]["pos"])
	# far from every field: nothing shown
	v.refresh(Vector2(Tuning.field.carrier_orbit_radius * 3.0, 0.0), t)
	assert_eq(_polys(v).size(), 0)


func test_asteroid_view_rebuilds_when_points_change_with_same_keys():
	var v = add_child_autofree(AsteroidViewScript.new())
	var pos := _spot()
	v.refresh(pos, 10.0)
	var before: PackedVector2Array = _polys(v)[0].points
	Tuning.planet.ast_radius_min = 20.0
	Tuning.planet.ast_radius_max = 30.0
	v.refresh(pos, 10.0)
	var want: Array = AsteroidField.near(pos, 10.0, Tuning.planet.chunk_gen_radius)
	assert_ne(want[0]["points"], before)
	assert_eq(_polys(v).size(), want.size())
	assert_eq(_polys(v)[0].points, want[0]["points"])


func test_asteroid_view_rebuilds_on_preset_applied():
	var v = add_child_autofree(AsteroidViewScript.new())
	var pos := _spot()
	v.refresh(pos, 10.0)
	Tuning.preset_applied.emit()
	v.refresh(pos, 10.0)
	var want: Array = AsteroidField.near(pos, 10.0, Tuning.planet.chunk_gen_radius)
	assert_eq(_polys(v)[0].points, want[0]["points"])


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


func test_ring_boulders_draw_obod_accent_while_tier2_ore_stays_ore():
	# a ring centred in band 3, narrower than the band: exactly band 3 is the ring band
	var bw: float = Tuning.planet.band_width
	var ring := {"radius": AsteroidField.band_centre(3), "width": 0.8 * bw, "phase": 0.0}
	Tuning.picture = {"seed": 3, "flight": 1, "moons": [], "ring": ring}
	Tuning.planet.chunk_gen_radius = 3000.0
	var pos := _spot()
	var t := 10.0
	var want: Array = AsteroidField.near(pos, t, Tuning.planet.chunk_gen_radius)
	var v = add_child_autofree(AsteroidViewScript.new())
	v.refresh(pos, t)
	var polys := _polys(v)
	assert_eq(polys.size(), want.size())
	var boulders := 0
	for i in want.size():
		if AsteroidField._ring_band(want[i]["band"]):
			boulders += 1
			assert_eq(want[i]["type"], &"ore_middle", "ring-band entries are boulders")
			assert_eq(polys[i].color, Palette.OBOD_ACCENT, "boulders draw the obod accent, not the ore colour")
		else:
			assert_eq(polys[i].color, AsteroidViewScript.color_of(want[i]["type"]), "non-ring entries keep the type colour")
	assert_gt(boulders, 0, "boulders visible near the ring")
	# tier-2 ore outside the ring band keeps the ore colour, never the accent
	assert_false(AsteroidField._ring_band(0), "band 0 is outside this ring")
	assert_eq(AsteroidViewScript.color_of(&"ore_middle"), Palette.ORE)
	assert_ne(Palette.ORE, Palette.OBOD_ACCENT)


func test_asteroid_view_hides_a_broken_asteroid():
	var v = add_child_autofree(AsteroidViewScript.new())
	var pos := _spot()
	var want: Array = AsteroidField.near(pos, 10.0, Tuning.planet.chunk_gen_radius)
	var b: Dictionary = want[1]
	var k1 := Vector3i(b["band"], b["chunk"], b["idx"])
	v.refresh(pos, 10.0, {})
	var polys := _polys(v)
	assert_eq(polys.size(), want.size())
	assert_eq(polys[1].points, b["points"])
	v.refresh(pos, 10.0, {k1: true})
	polys = _polys(v)
	assert_eq(polys.size(), want.size() - 1)
	assert_eq(polys[1].points, want[2]["points"])


func test_asteroid_instances_use_the_ore_look_with_a_type_pass_twin():
	var v = add_child_autofree(AsteroidViewScript.new())
	v.refresh(_spot(), 10.0)
	assert_gt(v.shown.size(), 0)
	assert_not_null(v.layer.type_view, "asteroid layer has the rim pass")
	v.layer.sync(v)
	v.place()
	for i in v.shown.size():
		var a: Dictionary = v.shown[i]
		var mi: MeshInstance3D = v._pool[i]
		var twin: MeshInstance3D = v._twins[i]
		assert_eq(mi.material_override, v.layer.asteroid)
		assert_eq(mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3, 2 * a["points"].size() + 4 * Style.DOME_INNER_POINTS)
		assert_eq(twin.mesh, mi.mesh)
		assert_eq(twin.material_override, v.layer.type_material)
		assert_eq(twin.layers, Layer3D.TYPE_LAYER)
		assert_eq(twin.transform, mi.transform)
		assert_true(twin.visible)
	v.refresh(Vector2(Tuning.field.carrier_orbit_radius * 3.0, 0.0), 10.0)
	v.place()
	for twin in v._twins:
		assert_false(twin.visible, "twins hide with their instance")


func _placed_with_target(ratio: float, phase := 1.0):
	var v = add_child_autofree(AsteroidViewScript.new())
	var pos := _spot()
	v.refresh(pos, 10.0)
	assert_gt(v.shown.size(), 1)
	var a: Dictionary = v.shown[1]
	var hit: Vector2 = a["pos"] + Vector2(a["radius"] * 0.5, 0.0)
	v.shake_phase = phase
	v.set_target(a["key"], ratio, hit)
	v.layer.sync(v)
	v.place()
	return [v, a, hit]


func test_beam_target_asteroid_gets_the_crack_material_and_its_hit_point_in_object_space():
	var r = _placed_with_target(0.6)
	var v = r[0]
	var a: Dictionary = r[1]
	var hit: Vector2 = r[2]
	var m: ShaderMaterial = v.layer.target
	assert_eq(v._pool[1].material_override, m)
	assert_almost_eq(m.get_shader_parameter("crack_ratio"), 0.6, 1e-6)
	assert_almost_eq(m.get_shader_parameter("crack_radius"), a["radius"], 1e-4)
	var local: Vector3 = v.transform_of(a).affine_inverse() * v.layer.to_3d(hit)
	var origin: Vector2 = m.get_shader_parameter("crack_origin")
	assert_almost_eq(origin.x, local.x, 1e-3)
	assert_almost_eq(origin.y, local.y, 1e-3)
	assert_almost_eq(origin.length(), a["radius"] * 0.5, 1e-2, "hit point is relative to the rock centre")
	for i in v.shown.size():
		if i != 1:
			assert_eq(v._pool[i].material_override, v.layer.asteroid, "other asteroids keep the asteroid look")
	assert_eq(v._twins[1].transform, v._pool[1].transform, "the rim twin shakes with the target")


func test_beam_target_shakes_with_the_ratio_and_not_at_zero():
	var r = _placed_with_target(0.5)
	var v = r[0]
	var a: Dictionary = r[1]
	var s: Vector2 = AsteroidViewScript.shake_offset(0.5, 1.0)
	assert_gt(s.length(), 0.0)
	var d: Vector3 = v._pool[1].transform.origin - v.transform_of(a).origin
	assert_almost_eq(d.x, s.x, 0.02, "float32 at world scale")
	assert_almost_eq(d.y, -s.y, 0.02)
	assert_eq(v._pool[0].transform, v.transform_of(v.shown[0]), "other asteroids do not shake")
	var s1: Vector2 = AsteroidViewScript.shake_offset(1.0, 1.0)
	assert_almost_eq(s1.length(), 2.0 * s.length(), 1e-4, "offset grows with the ratio")
	assert_almost_eq(s1.x, Style.SHAKE_PX_MAX * sin(1.0), 1e-5)
	assert_almost_eq(s1.y, Style.SHAKE_PX_MAX * sin(1.37), 1e-5)
	assert_eq(AsteroidViewScript.shake_offset(0.0, 1.0), Vector2.ZERO)


func test_ratio_zero_leaves_every_asteroid_unchanged():
	var r = _placed_with_target(0.0)
	var v = r[0]
	for i in v.shown.size():
		assert_eq(v._pool[i].material_override, v.layer.asteroid)
		assert_eq(v._pool[i].transform, v.transform_of(v.shown[i]))


func test_view_reads_the_target_from_the_beam_view():
	var holder: Node2D = add_child_autofree(Node2D.new())
	var beam := BeamView.new()
	beam.name = "BeamView"
	holder.add_child(beam)
	var v = AsteroidViewScript.new()
	holder.add_child(v)
	beam.ratio = 0.4
	beam.target_key = Vector3i(1, 2, 3)
	beam.has_hit = true
	beam.end = Vector2(5, 6)
	var phase: float = v.shake_phase
	v._process(0.1)
	assert_eq(v.target_key, Vector3i(1, 2, 3))
	assert_almost_eq(v.target_ratio, 0.4, 1e-6)
	assert_eq(v.target_hit, Vector2(5, 6))
	assert_almost_eq(v.shake_phase - phase, TAU * lerpf(Style.SHAKE_HZ_MIN, Style.SHAKE_HZ_MAX, 0.4) * 0.1, 1e-4)
	beam.ratio = 0.0
	beam.target_key = null
	v._process(0.1)
	assert_almost_eq(v.target_ratio, 0.0, 1e-6)
