extends GutTest

var _saved_field
var _saved_planet
var _saved_picture


func before_each():
	_saved_field = Tuning.field
	_saved_planet = Tuning.planet
	_saved_picture = Tuning.picture
	Tuning.field = _saved_field.duplicate(true)
	Tuning.planet = _saved_planet.duplicate(true)


func after_each():
	Tuning.field = _saved_field
	Tuning.planet = _saved_planet
	Tuning.picture = _saved_picture


func test_band_centre_and_omega_follow_band_width():
	var edge: float = Tuning.field.atmosphere_edge
	var bw: float = Tuning.planet.band_width
	assert_eq(AsteroidField.band_of(edge + 1.0), 0)
	assert_eq(AsteroidField.band_of(edge + bw + 1.0), 1)
	assert_eq(AsteroidField.band_of(edge - 1.0), -1)
	assert_eq(AsteroidField.band_of(WellGenerator.tiers()["ceiling"] + 1.0), -1)
	assert_almost_eq(AsteroidField.band_centre(2), edge + 2.5 * bw, 1e-6)
	assert_almost_eq(AsteroidField.band_omega(2), WellGenerator.relative_omega(edge + 2.5 * bw), 1e-12)
	Tuning.planet.band_width = 1000.0
	assert_eq(AsteroidField.band_of(edge + 1500.0), 1)
	assert_almost_eq(AsteroidField.band_centre(2), edge + 2500.0, 1e-6)
	assert_almost_eq(AsteroidField.band_omega(2), WellGenerator.relative_omega(edge + 2500.0), 1e-12)


func _moon(orbit: float, influence: float) -> BodyParams:
	var m := BodyParams.new()
	m.orbit_radius = orbit
	m.influence_radius = influence
	return m


func test_bands_crossing_moon_annulus_or_ring_have_no_fields():
	var edge: float = Tuning.field.atmosphere_edge
	var bw: float = Tuning.planet.band_width
	var margin: float = Tuning.planet.moon_margin
	var moon_orbit := edge + 3.5 * bw
	var ring_r := edge + 10.5 * bw
	Tuning.picture = {"seed": 1, "flight": 1, "moons": [_moon(moon_orbit, 100.0)], "ring": {"radius": ring_r, "width": 800.0, "phase": 0.0}}
	assert_true(AsteroidField.band_blocked(3), "band holding the moon orbit")
	assert_true(AsteroidField.band_blocked(10), "band holding the ring")
	assert_false(AsteroidField.band_blocked(1))
	assert_false(AsteroidField.band_blocked(6))
	assert_false(AsteroidField.band_blocked(12))
	var reach := 100.0 + margin
	var pad: float = Tuning.planet.field_radius + Tuning.planet.ast_radius_max
	Tuning.picture["moons"] = [_moon(edge + 5.0 * bw - reach + 1.0, 100.0)]
	assert_true(AsteroidField.band_blocked(4))
	assert_true(AsteroidField.band_blocked(5))
	# annulus edge within field spread of the band
	Tuning.picture["moons"] = [_moon(edge + 5.0 * bw - reach - pad + 1.0, 100.0)]
	assert_true(AsteroidField.band_blocked(5), "spill of a field reaches the annulus")
	Tuning.picture["moons"] = [_moon(edge + 5.0 * bw - reach - pad - 1.0, 100.0)]
	assert_false(AsteroidField.band_blocked(5))
	Tuning.picture["moons"] = []
	Tuning.picture["ring"] = {"radius": edge + 8.0 * bw + pad + 400.0 - 1.0, "width": 800.0, "phase": 0.0}
	assert_true(AsteroidField.band_blocked(7), "ring within field spread of the band")
	Tuning.picture["ring"]["radius"] = edge + 8.0 * bw + pad + 400.0 + 1.0
	assert_false(AsteroidField.band_blocked(7))
	_dense()
	Tuning.picture["moons"] = [_moon(edge + 20.5 * bw, 300.0)]
	Tuning.picture["ring"] = {"radius": edge + 30.5 * bw, "width": 800.0, "phase": 0.0}
	var m_reach := 300.0 + margin
	for ctr in [edge + 20.5 * bw, edge + 30.5 * bw]:
		for s in 4:
			Tuning.picture["seed"] = s
			var half := m_reach if ctr < edge + 25.0 * bw else 400.0
			for e in AsteroidField.near(Vector2(ctr, 0.0), 0.0, 4.0 * bw):
				assert_gte(absf(e["r"] - ctr), half + e["radius"], "no asteroid inside the exclusion")
	Tuning.picture = {"seed": 1, "flight": 1, "moons": [], "ring": {}}
	assert_false(AsteroidField.band_blocked(3))


func _dense(s := 5) -> void:
	Tuning.planet.asteroids_per_band = 1.0e6
	Tuning.picture = {"seed": s, "flight": 1, "moons": [], "ring": {}}


func _is_convex(pts: PackedVector2Array) -> bool:
	var sign_ := 0.0
	for j in pts.size():
		var a := pts[j]
		var b := pts[(j + 1) % pts.size()]
		var c := pts[(j + 2) % pts.size()]
		var cr := (b - a).cross(c - b)
		if absf(cr) < 1e-9:
			continue
		if sign_ == 0.0:
			sign_ = signf(cr)
		elif signf(cr) != sign_:
			return false
	return true


func test_chunk_count_follows_chunk_arc():
	var k := 5
	var expect := roundi(TAU * AsteroidField.band_centre(k) / Tuning.planet.chunk_arc)
	assert_eq(AsteroidField.chunk_count(k), expect)


func test_chunk_is_pure_function_of_seed_flight_band_index():
	_dense()
	var a := AsteroidField.chunk(5, 3)
	assert_gt(a.size(), 0)
	assert_eq(AsteroidField.chunk(5, 3), a)
	assert_ne(AsteroidField.chunk(5, 4), a)
	assert_ne(AsteroidField.chunk(6, 3), a)
	Tuning.picture["seed"] = 6
	assert_ne(AsteroidField.chunk(5, 3), a)
	Tuning.picture["seed"] = 5
	Tuning.picture["flight"] = 2
	assert_ne(AsteroidField.chunk(5, 3), a)


func test_chunk_holds_one_field_of_disjoint_convex_asteroids():
	_dense()
	var pl: PlanetParams = Tuning.planet
	for i in 6:
		var c := AsteroidField.chunk(5, i)
		assert_between(c.size(), 1, 6)
		for x in c:
			assert_between(x["radius"], pl.ast_radius_min, pl.ast_radius_max)
			assert_gte(x["points"].size(), 3)
			assert_true(_is_convex(x["points"]))
			for p in x["points"]:
				assert_lte(p.length(), x["radius"] + 1e-6)
		for a in c.size():
			var pa: Vector2 = Vector2.from_angle(c[a]["theta"]) * c[a]["r"]
			for b in range(a + 1, c.size()):
				var pb: Vector2 = Vector2.from_angle(c[b]["theta"]) * c[b]["r"]
				assert_lte(pa.distance_to(pb), 2.0 * pl.field_radius)
				assert_gt(pa.distance_to(pb), c[a]["radius"] + c[b]["radius"])


func test_hull_points_reach_near_contact_radius():
	_dense()
	for s in 20:
		Tuning.picture["seed"] = s
		for i in 6:
			for x in AsteroidField.chunk(5, i):
				var far := 0.0
				for p in x["points"]:
					far = maxf(far, p.length())
				assert_gte(far, 0.85 * x["radius"] - 1e-6, "hull reaches the contact radius")


func test_chunk_empty_in_blocked_band():
	_dense()
	Tuning.picture["ring"] = {"radius": AsteroidField.band_centre(5), "width": 500.0, "phase": 0.0}
	assert_eq(AsteroidField.chunk(5, 3), [])


func _band_total(k: int, seeds: int) -> float:
	var total := 0
	for s in seeds:
		Tuning.picture = {"seed": s + 1, "flight": 1, "moons": [], "ring": {}}
		for i in AsteroidField.chunk_count(k):
			total += AsteroidField.chunk(k, i).size()
	return float(total) / seeds


func test_band_density_drops_toward_carrier_and_above():
	var pl: PlanetParams = Tuning.planet
	pl.asteroids_per_band = 20.0
	pl.above_factor = 0.5
	var rc: float = Tuning.field.carrier_orbit_radius
	var kc := AsteroidField.band_of(rc)
	var seeds := 60
	assert_almost_eq(_band_total(kc - 12, seeds), 20.0, 4.0)
	var below := kc
	while AsteroidField.band_centre(below) > rc:
		below -= 1
	var d := (rc - AsteroidField.band_centre(below)) / pl.band_width
	var want := 20.0 * pow(pl.drop_ratio, maxf(0.0, pl.drop_start - d))
	assert_almost_eq(_band_total(below, seeds), want, maxf(want * 0.4, 1.0))
	assert_lt(_band_total(below, seeds), 10.0)
	var above := 0.0
	var n_above := 0
	var first_above := below + 1
	while AsteroidField.band_centre(first_above) <= rc:
		first_above += 1
	assert_lt(AsteroidField.band_expected(first_above), AsteroidField.band_expected(below))
	var at_carrier := 20.0 * pow(pl.drop_ratio, pl.drop_start) * pl.above_factor
	assert_almost_eq(AsteroidField.band_expected(first_above), at_carrier, 1e-6)
	for k in range(below + 1, AsteroidField.band_count()):
		if AsteroidField.band_centre(k) > rc:
			above += _band_total(k, seeds)
			n_above += 1
	assert_gt(n_above, 0)
	assert_almost_eq(above, at_carrier * n_above, at_carrier * n_above * 0.4 + 1.0)


func test_asteroid_rotates_rigidly_with_band():
	_dense()
	var k := 5
	var om := AsteroidField.band_omega(k)
	var n := AsteroidField.chunk_count(k)
	var dth := TAU / n
	var x: Dictionary = AsteroidField.chunk(k, 3)[0]
	for t in [0.0, 7.5, 1000.0, -40.0]:
		var s := AsteroidField.state(k, x, t)
		var ang: float = x["theta"] + om * t
		var pos: Vector2 = Vector2.from_angle(ang) * x["r"]
		assert_almost_eq(s["pos"], pos, Vector2(0.05, 0.05))
		assert_almost_eq(s["vel"], om * Vector2(-pos.y, pos.x), Vector2(1e-4, 1e-4))
		assert_almost_eq(s["pos"].length(), x["r"], 0.05)
		var want: int = posmod(floori((s["pos"].angle() - om * t) / dth), n)
		assert_eq(AsteroidField.chunk_index(k, s["pos"].angle(), t), want)
		assert_eq(AsteroidField.chunk_index(k, s["pos"].angle(), t), AsteroidField.chunk_index(k, x["theta"], 0.0))


func _key(a: Dictionary) -> String:
	return "%d:%d:%d" % [a["band"], a["chunk"], a["idx"]]


func test_near_matches_brute_force_within_radius():
	_dense()
	Tuning.planet.asteroids_per_band = 400.0
	Tuning.picture["moons"] = [_moon(AsteroidField.band_centre(9), 100.0)]
	var radius := 5000.0
	var edge: float = Tuning.field.atmosphere_edge
	var bw: float = Tuning.planet.band_width
	var total := 0
	for t in [0.0, 333.0]:
		var all: Array = []
		for k in AsteroidField.band_count():
			for i in AsteroidField.chunk_count(k):
				var c := AsteroidField.chunk(k, i)
				for j in c.size():
					var s := AsteroidField.state(k, c[j], t)
					all.append({"key": "%d:%d:%d" % [k, i, j], "pos": s["pos"]})
		var spots: Array = []
		for k in [3, 7, 8, 20]:
			var om := AsteroidField.band_omega(k)
			var dth := TAU / AsteroidField.chunk_count(k)
			for i in [0, 5, AsteroidField.chunk_count(k) - 1]:
				for r in [edge + k * bw, edge + (k + 1) * bw, edge + (k + 0.5) * bw]:
					spots.append(Vector2.from_angle(i * dth + om * t) * r)
		spots.append(Vector2(100.0, 50.0))
		spots.append(Vector2(-9000.0, 0.0))
		for p in spots:
			var want: Array = []
			for a in all:
				if a["pos"].distance_to(p) <= radius:
					want.append(a["key"])
			var got: Array = AsteroidField.near(p, t, radius)
			var keys: Array = got.map(_key)
			want.sort()
			keys.sort()
			assert_eq(keys, want, "near %s t %s" % [p, t])
			total += got.size()
			for a in got:
				assert_true(a.has_all(["pos", "vel", "radius", "points", "band", "chunk", "idx"]))
				assert_lte(a["pos"].distance_to(p), radius)
		var p0: Vector2 = spots[0]
		assert_eq(AsteroidField.near(p0, t, radius), AsteroidField.near(p0, t, radius))
	assert_gt(total, 20)


func test_near_entries_carry_r_theta_omega_for_formula_position() -> void:
	Tuning.planet.asteroids_per_band = 1000.0
	var ast: Dictionary = AsteroidField.chunk(0, 0)[0]
	var st := AsteroidField.state(0, ast, 0.0)
	var found := AsteroidField.near(st["pos"], 0.0, 1.0)
	assert_gt(found.size(), 0)
	var a: Dictionary = found[0]
	var t := 37.0
	var expected := AsteroidField.state(a["band"], AsteroidField.chunk(a["band"], a["chunk"])[a["idx"]], t)
	assert_almost_eq(AsteroidField.at(a, t)["pos"], expected["pos"], Vector2(0.001, 0.001))
	assert_almost_eq(a["omega"], AsteroidField.band_omega(a["band"]), 0.000001)


func test_max_speed_bounds_every_near_entry_speed() -> void:
	var saved_planet = Tuning.planet
	Tuning.planet = saved_planet.duplicate()
	Tuning.planet.asteroids_per_band = 1000.0
	var vmax := AsteroidField.max_speed()
	var pl: PlanetParams = Tuning.planet
	var k := AsteroidField.band_count() - 1
	assert_gte(vmax, absf(AsteroidField.band_omega(k)) * (AsteroidField.band_centre(k) + pl.band_width * 0.5 + pl.field_radius) - 1e-6)
	var seen := 0
	for b in AsteroidField.band_count():
		var c := Vector2.from_angle(0.3) * AsteroidField.band_centre(b)
		for e in AsteroidField.near(c, 5.0, 20000.0):
			seen += 1
			assert_lte(e["vel"].length(), vmax + 1e-6)
	Tuning.planet = saved_planet
	assert_gt(seen, 0)


func test_band_of_ceiling_clamped_to_last_band():
	var edge: float = Tuning.field.atmosphere_edge
	var span: float = WellGenerator.tiers()["ceiling"] - edge
	Tuning.planet.band_width = span / 4.0
	assert_eq(AsteroidField.band_count(), 4)
	assert_eq(AsteroidField.band_of(WellGenerator.tiers()["ceiling"]), AsteroidField.band_count() - 1)


func _all_entries() -> Array:
	var out: Array = []
	for k in AsteroidField.band_count():
		for i in AsteroidField.chunk_count(k):
			out.append_array(AsteroidField.chunk(k, i))
	return out


func test_chunk_asteroids_carry_type_by_tier_and_are_deterministic():
	_dense()
	var all := _all_entries()
	assert_gt(all.size(), 50)
	var top := {}
	for a in all:
		var tier := WellGenerator.tier_of(a["r"])
		var t: StringName = a["type"]
		match tier:
			0: assert_eq(t, &"ore_unique")
			1: assert_eq(t, &"ore_rare")
			2: assert_eq(t, &"ore_middle")
			_:
				assert_true(t == &"ice" or t == &"ore_base", str(t))
				top[t] = true
	assert_eq(top.size(), 2)
	assert_eq(_all_entries(), all)
	Tuning.planet.top_ice_share = 1.0
	for a in _all_entries():
		if WellGenerator.tier_of(a["r"]) == 3:
			assert_eq(a["type"], &"ice")


func test_comp_draw_does_not_shift_geometry():
	_dense()
	var a := AsteroidField.chunk(5, 3)
	Tuning.planet.top_ice_share = 0.0
	var b := AsteroidField.chunk(5, 3)
	for j in a.size():
		assert_eq(a[j]["points"], b[j]["points"])
		assert_eq(a[j]["r"], b[j]["r"])


func test_near_entries_carry_type():
	_dense()
	var ast: Dictionary = AsteroidField.chunk(5, 3)[0]
	var st := AsteroidField.state(5, ast, 0.0)
	var found := AsteroidField.near(st["pos"], 0.0, 1.0)
	assert_eq(found[0]["type"], ast["type"])


func test_asteroid_amount_equals_hull_area_times_amount_per_area():
	_dense()
	var c := AsteroidField.chunk(5, 3)
	assert_gt(c.size(), 0)
	for a in c:
		var pts: PackedVector2Array = a["points"]
		var area := 0.0
		for j in pts.size():
			area += pts[j].cross(pts[(j + 1) % pts.size()])
		assert_almost_eq(a["amount"], absf(area) * 0.5 * Tuning.planet.amount_per_area, 1e-6)
		assert_gt(a["amount"], 0.0)
	Tuning.planet.amount_per_area *= 2.0
	assert_almost_eq(AsteroidField.chunk(5, 3)[0]["amount"], c[0]["amount"] * 2.0, 1e-6)
	var st := AsteroidField.state(5, c[0], 0.0)
	var found := AsteroidField.near(st["pos"], 0.0, 1.0)
	assert_almost_eq(found[0]["amount"], c[0]["amount"] * 2.0, 1e-6)
