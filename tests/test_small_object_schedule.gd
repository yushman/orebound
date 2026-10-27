extends GutTest

var _planet: PlanetParams


func before_each() -> void:
	_planet = Tuning.planet
	Tuning.planet = _planet.duplicate(true)


func after_each() -> void:
	Tuning.planet = _planet


func test_deterministic_and_seed_sensitive() -> void:
	var a := SmallObjectSchedule.schedule(5, 1, 2, 3)
	var b := SmallObjectSchedule.schedule(5, 1, 2, 3)
	assert_gt(a.size(), 0)
	assert_eq(a, b)
	var c := SmallObjectSchedule.schedule(6, 1, 2, 3)
	assert_ne(a, c)


func test_event_fields_and_bounds() -> void:
	var pl: PlanetParams = Tuning.planet
	pl.small_rate = [30.0, 30.0, 30.0, 30.0]
	for tier in 4:
		var ev := SmallObjectSchedule.schedule(1, 1, tier, 2)
		assert_gt(ev.size(), 0)
		var ids := {}
		for e in ev:
			assert_between(e["time"], 2 * pl.small_window, 3 * pl.small_window)
			assert_between(e["e"], pl.small_e_min, pl.small_e_max)
			assert_between(e["radius"], pl.small_radius_min, pl.small_radius_max)
			assert_between(e["angle"], 0.0, TAU)
			assert_between(e["nu"], 0.0, TAU)
			assert_gte(e["points"].size(), 3)
			assert_gt(e["amount"], 0.0)
			assert_false(ids.has(e["id"]))
			ids[e["id"]] = true
	var types := {0: [&"ore_unique"], 1: [&"ore_rare"], 2: [&"ore_middle"], 3: [&"ice", &"ore_base"]}
	for tier in 4:
		for e in SmallObjectSchedule.schedule(1, 1, tier, 0):
			assert_true(e["type"] in types[tier])


func test_mean_count_matches_rate() -> void:
	var pl: PlanetParams = Tuning.planet
	pl.small_rate = [6.0, 6.0, 6.0, 6.0]
	var total := 0
	var n := 400
	for w in n:
		total += SmallObjectSchedule.schedule(3, 1, 1, w).size()
	var expect: float = 6.0 * pl.small_window / 60.0
	assert_almost_eq(float(total) / n, expect, expect * 0.15)


func test_rate_zero_is_empty() -> void:
	Tuning.planet.small_rate = [0.0, 0.0, 0.0, 0.0]
	assert_eq(SmallObjectSchedule.schedule(1, 1, 2, 0), [])


func test_asteroid_chunks_unchanged() -> void:
	var before := AsteroidField.chunk(2, 1, 4)
	SmallObjectSchedule.schedule(1, 1, 2, 0)
	assert_eq(AsteroidField.chunk(2, 1, 4), before)
