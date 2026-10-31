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


func test_default_moon_generation_knobs():
	var p: PlanetParams = Tuning.planet
	assert_gt(p.get("moon_influence_k"), 1.0)
	assert_almost_eq(p.get("moon_mass_k") * pow(1500.0, p.get("moon_mass_exp")), 500.0, 25.0)
	assert_almost_eq(p.get("moon_mass_k") * pow(500.0, p.get("moon_mass_exp")), 70.0, 5.0)
	assert_gt(p.get("moon_margin"), 0.0)
	assert_eq(p.get("max_tries"), 8)
	assert_gt(p.get("moon_bounce"), 0.0)
	assert_gt(p.get("moon_impact_damage"), 0.0)
	assert_not_null(p.get("fallback_seed"))


func test_default_rest_speed():
	assert_eq(Tuning.planet.get("rest_speed"), 0.3)


func test_default_carrier_patrol_speed():
	assert_eq(Tuning.planet.get("carrier_patrol_speed"), 40.0)


func test_default_band_chunk_and_asteroid_knobs():
	var p: PlanetParams = Tuning.planet
	assert_almost_eq(float(p.get("band_width")), 1500.0, 500.0)
	assert_almost_eq(float(p.get("chunk_arc")), 4000.0, 1500.0)
	assert_gt(float(p.get("chunk_gen_radius")), float(p.get("chunk_arc")))
	assert_eq(float(p.get("asteroids_per_band")), 200.0)
	assert_between(float(p.get("drop_ratio")), 0.001, 0.999)
	assert_gt(float(p.get("drop_start")), 0.0)
	assert_between(float(p.get("above_factor")), 0.0, 0.999)
	assert_gt(float(p.get("field_radius")), 0.0)
	assert_gt(float(p.get("ast_radius_min")), 0.0)
	assert_gt(float(p.get("ast_radius_max")), float(p.get("ast_radius_min")))
	assert_between(float(p.get("asteroid_bounce")), 0.001, 1.0)
	assert_gt(float(p.get("asteroid_impact_damage")), 0.0)


func test_default_composition_knobs():
	assert_eq(Tuning.planet.top_ice_share, 0.6)
	assert_almost_eq(Tuning.planet.amount_per_area, 1.1e-4, 1e-9)


func test_default_small_object_knobs():
	var p: PlanetParams = Tuning.planet
	assert_gt(p.piece_swallow_radius, 0.0)
	assert_gt(p.piece_despawn_radius, p.piece_swallow_radius)
	assert_between(p.piece_bounce, 0.0, 1.0)
	assert_eq(p.v_safe, 12.0)
	assert_gt(p.impact_k, 0.0)


func test_default_split_and_piece_knobs() -> void:
	var p: PlanetParams = Tuning.planet
	assert_eq(p.split_count, 3)
	assert_eq(p.split_area_divisor, 1.5)
	assert_eq(p.collect_radius, 20.0)
	assert_eq(p.break_per_sqrt_radius, 0.5)
	assert_false("break_per_area" in p)
	assert_eq(p.piece_lifetime, 100.0)
	assert_eq(p.piece_min_radius, 5.0)
	assert_eq(p.piece_spread, 0.7)
	assert_almost_eq(p.piece_scatter, 5.0 / 3.0, 1e-6)


func test_scheduled_small_body_params_are_gone() -> void:
	var names: Array = []
	for pr in PlanetParams.new().get_property_list():
		names.append(pr["name"])
	for n in ["small_rate", "small_window", "small_e_min", "small_e_max", "small_radius_min",
			"small_radius_max", "small_spawn_radius", "small_max_bodies"]:
		assert_false(names.has(n), n)


func test_planet_defaults_include_ring_boulders_and_drag() -> void:
	var p: PlanetParams = Tuning.planet
	assert_eq(p.get("ring_boulders_per_chunk"), 1.0, "ring_boulders_per_chunk")
	assert_eq(p.get("ring_drag_tau"), 15.0, "ring_drag_tau")
	assert_eq(p.get("ring_dust_density"), 0.5, "ring_dust_density")


func test_piece_knobs_use_piece_names() -> void:
	var p := PlanetParams.new()
	assert_eq(p.get("piece_despawn_radius"), 3000.0)
	assert_eq(p.get("piece_swallow_radius"), 25.0)
	assert_eq(p.get("piece_bounce"), 0.5)
	for n in ["small_despawn_radius", "swallow_radius", "small_bounce"]:
		assert_null(p.get(n), n)
