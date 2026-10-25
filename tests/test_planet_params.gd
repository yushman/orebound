extends GutTest


func test_default_planet_tier_shares_and_ceiling_offset():
	var p: PlanetParams = Tuning.planet
	assert_eq(p.tier_shares, [0.25, 0.40, 0.25, 0.10])
	var sum := 0.0
	for s in p.tier_shares:
		sum += s
	assert_almost_eq(sum, 1.0, 1e-9)
	assert_eq(p.ceiling_offset, 5000.0)


func test_default_planet_moon_and_ring_placeholders():
	var p: PlanetParams = Tuning.planet
	assert_between(p.moon_count_min, 2, 3)
	assert_between(p.moon_count_max, p.moon_count_min, 3)
	assert_between(p.moon_large_radius_min, 1000.0, 2000.0)
	assert_between(p.moon_large_radius_max, p.moon_large_radius_min, 2000.0)
	assert_between(p.moon_small_radius_min, 300.0, 700.0)
	assert_between(p.moon_small_radius_max, p.moon_small_radius_min, 700.0)
	assert_between(p.ring_tier, 0, 3)
	assert_gt(p.ring_width, 0.0)
	assert_gt(p.ring_density, 0.0)


func test_apply_keeps_planet():
	var planet = Tuning.planet
	var preset: TuningPreset = Tuning.load_preset("res://presets/p1.tres")
	var saved_field = Tuning.field
	var saved_ship = Tuning.ship
	Tuning.apply(preset)
	assert_same(Tuning.planet, planet)
	Tuning.field = saved_field
	Tuning.ship = saved_ship


func test_default_planet_atmosphere():
	var p: PlanetParams = Tuning.planet
	assert_eq(p.get("atmosphere_drag"), 0.5)
	assert_eq(p.get("atmosphere_damage"), 5.0)
	assert_eq(p.get("density_shape"), 2.0)
