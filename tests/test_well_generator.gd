extends GutTest

const PRESETS := ["res://presets/p1.tres", "res://presets/p2.tres", "res://presets/p3.tres", "res://presets/p4.tres"]

var _saved_field
var _saved_ship
var _saved_planet


func before_each():
	_saved_field = Tuning.field
	_saved_ship = Tuning.ship
	_saved_planet = Tuning.planet


func after_each():
	Tuning.field = _saved_field
	Tuning.ship = _saved_ship
	Tuning.planet = _saved_planet


func _setups() -> Array:
	var out := [null]
	out.append_array(PRESETS)
	return out


func _use(setup) -> void:
	if setup != null:
		Tuning.apply(Tuning.load_preset(setup))


func test_boundaries_ascending_between_edge_and_carrier():
	for setup in _setups():
		_use(setup)
		var b: Array = WellGenerator.tiers()["boundaries"]
		assert_eq(b.size(), 5, str(setup))
		if b.size() != 5:
			continue
		assert_eq(b[0], Tuning.field.atmosphere_edge)
		assert_eq(b[4], Tuning.field.carrier_orbit_radius)
		for i in 4:
			assert_gt(b[i + 1], b[i], "%s boundary %d" % [setup, i])


func test_adjacent_boundaries_differ_by_share_times_swing():
	for setup in _setups():
		_use(setup)
		var b: Array = WellGenerator.tiers()["boundaries"]
		if b.size() != 5:
			assert_eq(b.size(), 5)
			continue
		var swing: float = GravityField.planet_potential_eff(b[4]) - GravityField.planet_potential_eff(b[0])
		var shares: Array = Tuning.planet.tier_shares
		for i in 4:
			var d: float = GravityField.planet_potential_eff(b[i + 1]) - GravityField.planet_potential_eff(b[i])
			var want: float = shares[3 - i] * swing
			assert_almost_eq(d, want, absf(want) * 1e-3, "%s tier %d" % [setup, i])


func test_inner_radii_differ_between_presets():
	Tuning.apply(Tuning.load_preset(PRESETS[0]))
	var b1: Array = WellGenerator.tiers()["boundaries"]
	Tuning.apply(Tuning.load_preset(PRESETS[1]))
	var b2: Array = WellGenerator.tiers()["boundaries"]
	assert_eq(b1.size(), 5)
	assert_eq(b2.size(), 5)
	if b1.size() == 5 and b2.size() == 5:
		assert_ne(b1[2], b2[2])


func test_tow_is_middle_tier_bottom_and_ceiling_is_carrier_plus_offset():
	for setup in _setups():
		_use(setup)
		var t: Dictionary = WellGenerator.tiers()
		var b: Array = t["boundaries"]
		assert_eq(b.size(), 5, str(setup))
		if b.size() != 5:
			continue
		assert_eq(t["tow"], b[2])
		var lo: float = GravityField.planet_potential_eff(b[0])
		var swing: float = GravityField.planet_potential_eff(b[4]) - lo
		assert_almost_eq(GravityField.planet_potential_eff(t["tow"]) - lo, 0.35 * swing, swing * 1e-3, str(setup))
		assert_eq(t["ceiling"], Tuning.field.carrier_orbit_radius + Tuning.planet.ceiling_offset)


func test_ceiling_follows_planet_offset_without_cache():
	var before: float = WellGenerator.tiers()["ceiling"]
	var p := PlanetParams.new()
	p.ceiling_offset = 777.0
	Tuning.planet = p
	assert_eq(WellGenerator.tiers()["ceiling"], Tuning.field.carrier_orbit_radius + 777.0)
	assert_ne(WellGenerator.tiers()["ceiling"], before)


func _same_picture(a: Dictionary, b: Dictionary) -> bool:
	if a["seed"] != b["seed"] or a["flight"] != b["flight"] or a["moons"].size() != b["moons"].size():
		return false
	for i in a["moons"].size():
		var x: BodyParams = a["moons"][i]
		var y: BodyParams = b["moons"][i]
		if x.radius != y.radius or x.orbit_radius != y.orbit_radius or x.phase != y.phase or x.mass != y.mass:
			return false
	return true


func test_same_seed_and_flight_give_identical_picture():
	var a: Dictionary = WellGenerator.picture(5, 1)
	var b: Dictionary = WellGenerator.picture(5, 1)
	assert_true(_same_picture(a, b))


func test_different_seed_gives_different_picture():
	var a: Dictionary = WellGenerator._build(5, 1)
	var b: Dictionary = WellGenerator._build(6, 1)
	assert_false(_same_picture(a, b))


func test_build_uses_passed_tier_bounds():
	var b: Array[float] = WellGenerator.tiers()["boundaries"]
	var shifted: Array[float] = []
	for r in b:
		shifted.append(r * 1.01)
	assert_true(_same_picture(WellGenerator._build(5, 1), WellGenerator._build(5, 1, b)))
	assert_false(_same_picture(WellGenerator._build(5, 1), WellGenerator._build(5, 1, shifted)))
	var pic: Dictionary = WellGenerator.picture(5, 1)
	assert_true(_same_picture(pic, WellGenerator._build(pic["seed"], 1, b)))


func test_picture_leaves_tuning_untouched():
	var bodies: Array = Tuning.field.bodies.duplicate()
	WellGenerator.picture(3, 1)
	assert_eq(Tuning.field.bodies, bodies)


func test_picture_moon_mix_and_params():
	var pl: PlanetParams = Tuning.planet
	for setup in _setups():
		_use(setup)
		var bd: Array = WellGenerator.tiers()["boundaries"]
		for s in 20:
			var pic: Dictionary = WellGenerator._build(s, 1)
			var moons: Array = pic["moons"]
			assert_between(moons.size(), pl.moon_count_min, pl.moon_count_max)
			assert_between(moons[0].radius, pl.moon_large_radius_min, pl.moon_large_radius_max)
			assert_between(moons[0].orbit_radius, bd[3], bd[4])
			for i in range(1, moons.size()):
				assert_between(moons[i].radius, pl.moon_small_radius_min, pl.moon_small_radius_max)
				assert_between(moons[i].orbit_radius, bd[1], bd[3])
			for m in moons:
				assert_eq(m.parent, 0)
				assert_eq(m.p, 2.0)
				var r: float = m.orbit_radius
				var g: float = GravityField.accel_of(0, Vector2(r, 0.0), 0.0).length()
				assert_almost_eq(m.angular_speed, sqrt(r * g) / r, 1e-12)
				assert_almost_eq(m.mass, pl.moon_mass_k * pow(m.radius, pl.moon_mass_exp), 1e-6)
				assert_almost_eq(m.influence_radius, pl.moon_influence_k * m.radius, 1e-6)


func _mk(radius: float, orbit: float) -> BodyParams:
	var m := BodyParams.new()
	m.radius = radius
	m.orbit_radius = orbit
	m.influence_radius = Tuning.planet.moon_influence_k * radius
	return m


func test_check_accepts_valid_layout():
	assert_true(WellGenerator.check([_mk(1500.0, 119000.0), _mk(500.0, 108000.0)]))


func test_check_rejects_moon_whose_influence_reaches_carrier_orbit():
	var m := _mk(1500.0, 119000.0)
	m.influence_radius = Tuning.field.carrier_orbit_radius - m.orbit_radius - Tuning.planet.moon_margin
	assert_false(WellGenerator.check([m]))


func test_check_rejects_overlapping_moon_pair():
	var a := _mk(500.0, 108000.0)
	var b := _mk(500.0, 108000.0 + a.influence_radius * 2.0 + Tuning.planet.moon_margin)
	assert_false(WellGenerator.check([a, b]))
	b.orbit_radius += 1.0
	assert_true(WellGenerator.check([a, b]))


func test_check_rejects_disc_below_atmosphere_edge():
	var m := _mk(1000.0, Tuning.field.atmosphere_edge + 999.0)
	assert_false(WellGenerator.check([m]))


func test_picture_falls_back_to_fallback_seed_after_max_tries():
	var p := PlanetParams.new()
	p.moon_margin = 1e9
	p.max_tries = 3
	p.fallback_seed = 777
	Tuning.planet = p
	var pic: Dictionary = WellGenerator.picture(10, 1)
	assert_eq(pic["seed"], 777)
	assert_true(_same_picture(pic, WellGenerator._build(777, 1)))


func test_picture_retries_with_next_seed_before_fallback():
	for s in 100:
		var pic: Dictionary = WellGenerator.picture(s, 1)
		var first: Dictionary = WellGenerator._build(s, 1)
		if not WellGenerator.check(first["moons"], first["ring"]):
			var expected: int = Tuning.planet.fallback_seed
			for i in range(1, Tuning.planet.max_tries):
				var nxt: Dictionary = WellGenerator._build(s + i, 1)
				if WellGenerator.check(nxt["moons"], nxt["ring"]):
					expected = s + i
					break
			assert_ne(pic["seed"], s)
			assert_eq(pic["seed"], expected)
			return
	fail_test("no failing seed in 0..99")


func test_fallback_seed_passes_check_with_ring():
	for setup in _setups():
		_use(setup)
		var pic: Dictionary = WellGenerator._build(Tuning.planet.fallback_seed, 1)
		assert_true(WellGenerator.check(pic["moons"], pic["ring"]), str(setup))


func test_at_least_half_of_seeds_pass_first_try_with_ring():
	for setup in _setups():
		_use(setup)
		var ok := 0
		for s in 100:
			var pic: Dictionary = WellGenerator._build(s, 1)
			if WellGenerator.check(pic["moons"], pic["ring"]):
				ok += 1
		assert_gte(ok, 50, "%s passed %d/100" % [setup, ok])


func test_relative_omega_matches_d35_at_tier_boundaries():
	var b: Array[float] = WellGenerator.tiers()["boundaries"]
	var expected := [7.9e-4, 7.4e-4, 6.2e-4, 3.6e-4]
	for i in 4:
		assert_almost_eq(WellGenerator.relative_omega(b[i]), expected[i], 0.1 * expected[i], "b%d" % i)
	assert_almost_eq(WellGenerator.relative_omega(Tuning.field.carrier_orbit_radius), 0.0, 1e-6)


func _annuli_clear(ring: Dictionary, moons: Array) -> bool:
	var m: float = Tuning.planet.moon_margin
	for mo in moons:
		var reach: float = mo.influence_radius + m
		if ring["radius"] + ring["width"] * 0.5 > mo.orbit_radius - reach and ring["radius"] - ring["width"] * 0.5 < mo.orbit_radius + reach:
			return false
	return true


func test_built_ring_lies_in_ring_tier_and_clears_moon_annuli():
	var b: Array[float] = WellGenerator.tiers()["boundaries"]
	var tier: int = Tuning.planet.ring_tier
	var found := 0
	for s in 40:
		var pic: Dictionary = WellGenerator._build(s, 1)
		var ring: Dictionary = pic["ring"]
		if ring.is_empty():
			continue
		found += 1
		assert_almost_eq(ring["width"], Tuning.planet.ring_width, 1e-6)
		assert_gte(ring["radius"] - ring["width"] * 0.5, b[tier] - 1e-6)
		assert_lte(ring["radius"] + ring["width"] * 0.5, b[tier + 1] + 1e-6)
		assert_between(ring["phase"], 0.0, TAU)
		assert_true(_annuli_clear(ring, pic["moons"]), "seed %d" % s)
		assert_eq(WellGenerator._build(s, 1)["ring"], ring)
	assert_gt(found, 0)
	var p := PlanetParams.new()
	p.ring_width = 1e7
	Tuning.planet = p
	assert_true(WellGenerator._build(1, 1)["ring"].is_empty())


func test_check_rejects_ring_crossing_moon_annulus():
	var m := _mk(500.0, 108000.0)
	var reach: float = m.influence_radius + Tuning.planet.moon_margin
	var far := {"radius": 108000.0 + reach + 800.0, "width": 1500.0, "phase": 0.0}
	var near := {"radius": 108000.0 + reach + 700.0, "width": 1500.0, "phase": 0.0}
	assert_true(WellGenerator.check([m]))
	assert_true(WellGenerator.check([m], far))
	assert_false(WellGenerator.check([m], near))
	assert_false(WellGenerator.check([m], {}))


func test_tier_of_maps_radii_to_tiers_and_clamps():
	var b: Array[float] = WellGenerator.tiers()["boundaries"]
	assert_eq(WellGenerator.tier_of(b[0] - 100.0), 0)
	assert_eq(WellGenerator.tier_of(b[0]), 0)
	for i in 4:
		assert_eq(WellGenerator.tier_of(0.5 * (b[i] + b[i + 1])), i)
	assert_eq(WellGenerator.tier_of(b[1]), 1)
	assert_eq(WellGenerator.tier_of(b[4] + 5000.0), 3)
