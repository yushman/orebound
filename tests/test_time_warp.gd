extends GutTest


func test_ticks_per_second_is_60_times_mult_only_with_warp_held_flying() -> void:
	assert_eq(TimeWarp.ticks_per_second(true, true, true, 4), 240)
	assert_eq(TimeWarp.ticks_per_second(false, true, true, 4), 60)
	assert_eq(TimeWarp.ticks_per_second(true, false, true, 4), 60)
	assert_eq(TimeWarp.ticks_per_second(true, true, false, 4), 60)


func test_factor_is_ticks_over_base_and_real_step_divides_dt() -> void:
	assert_eq(TimeWarp.factor(60), 1.0)
	assert_eq(TimeWarp.factor(240), 4.0)
	assert_almost_eq(TimeWarp.real_step(4.0), GravityField.DT / 4.0, 1e-9)


func test_max_steps_covers_mult() -> void:
	assert_eq(TimeWarp.max_steps(60), 8)
	assert_eq(TimeWarp.max_steps(600), 20)
