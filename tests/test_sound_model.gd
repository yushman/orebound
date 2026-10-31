extends GutTest

const DT := 1.0 / 60.0
const HUD_SCRIPT := preload("res://ui/HUD.gd")

var _saved_planet
var _saved_ship


func before_each() -> void:
	_saved_planet = Tuning.planet
	_saved_ship = Tuning.ship
	Tuning.planet = Tuning.planet.duplicate()
	Tuning.planet.atmosphere_drag = 0.0
	Tuning.planet.atmosphere_damage = 0.0
	Tuning.ship = Tuning.ship.duplicate()


func after_each() -> void:
	Tuning.planet = _saved_planet
	Tuning.ship = _saved_ship


func _thrust() -> ShipInput:
	var i := ShipInput.new()
	i.thrust = true
	return i


func _flying() -> ShipState:
	var s := ShipState.new()
	s.pos = Vector2(600, 0)
	return s


func test_view_params_defaults() -> void:
	var v := ViewParams.new()
	assert_eq(v.volume, 0.8)
	assert_eq(v.reserve_click_period, 4.0)
	assert_eq(v.reserve_beep_period, 2.0)
	assert_eq(v.crack_period, 0.4)


func test_pitch_lower_with_more_mass_higher_with_more_thrust() -> void:
	assert_lt(SoundModel.engine_pitch(20.0, 0.5), SoundModel.engine_pitch(10.0, 0.5))
	assert_lt(SoundModel.engine_pitch(10.0, 0.2), SoundModel.engine_pitch(10.0, 0.8))


func test_pitch_clamped() -> void:
	assert_eq(SoundModel.engine_pitch(1e9, 0.0), 0.4)
	assert_eq(SoundModel.engine_pitch(0.0, 1.0), 2.0)


func test_pitch_at_ref_mass_mid_level_is_one() -> void:
	assert_almost_eq(SoundModel.engine_pitch(Tuning.ship.ref_mass, 0.5), 1.0, 1e-4)


func test_engine_volume_has_idle_floor_and_follows_level() -> void:
	assert_almost_eq(SoundModel.engine_volume(0.0), 0.15, 1e-4)
	assert_almost_eq(SoundModel.engine_volume(1.0), 1.0, 1e-4)
	assert_lt(SoundModel.engine_volume(0.3), SoundModel.engine_volume(0.6))


func test_thrust_level_zero_without_thrust() -> void:
	assert_eq(SoundModel.thrust_level(_flying(), ShipInput.new()), 0.0)


func test_thrust_level_zero_without_energy() -> void:
	var s := _flying()
	s.tank.clear()
	assert_eq(SoundModel.thrust_level(s, _thrust()), 0.0)


func test_thrust_level_follows_ramp() -> void:
	var s := _flying()
	s.hold_time = 0.0
	assert_almost_eq(SoundModel.thrust_level(s, _thrust()), Tuning.ship.ramp_min_fraction, 1e-4)
	s.hold_time = Tuning.ship.ramp_time * 2.0
	assert_almost_eq(SoundModel.thrust_level(s, _thrust()), 1.0, 1e-4)


func test_thrust_level_falls_with_heat() -> void:
	var s := _flying()
	s.hold_time = 10.0
	s.heat = 1.0
	assert_almost_eq(SoundModel.thrust_level(s, _thrust()), Tuning.ship.min_thrust_fraction, 1e-4)


func test_thrust_level_matches_flight_acceleration() -> void:
	var k := 0.0
	for hold_time in [0.0, 0.5, 3.0]:
		for heat in [0.0, 0.9, 1.0]:
			var s0 := _flying()
			s0.hold_time = hold_time
			s0.heat = heat
			var s1 := ShipFlight.step(s0, _thrust(), 0.0, DT)
			var a := (s1.vel - s0.vel) / DT - GravityField.accel(s0.pos, 0.0) - GravityField.frame_accel(s0.pos, s0.vel)
			k = Tuning.ship.ref_mass / Hold.mass(s0)
			var probe := s1.copy()
			probe.heat = heat
			assert_almost_eq(SoundModel.thrust_level(probe, _thrust()), a.length() / (Tuning.ship.thrust_accel * k), 1e-3, "hold_time %s heat %s" % [hold_time, heat])


func test_rough_mix() -> void:
	assert_eq(SoundModel.rough_mix(0.0), 0.0)
	assert_eq(SoundModel.rough_mix(0.5), 0.0)
	assert_almost_eq(SoundModel.rough_mix(0.75), 0.5, 1e-4)
	assert_eq(SoundModel.rough_mix(1.0), 1.0)


func test_boost_on() -> void:
	var i := _thrust()
	assert_false(SoundModel.boost_on(i, 0.5))
	i.boost = true
	assert_true(SoundModel.boost_on(i, 0.5))
	assert_false(SoundModel.boost_on(i, 0.0))


func test_hiss_volume_clamped() -> void:
	assert_eq(SoundModel.hiss_volume(-0.5), 0.0)
	assert_eq(SoundModel.hiss_volume(0.4), 0.4)
	assert_eq(SoundModel.hiss_volume(3.0), 1.0)


func test_heat_click_only_on_upward_crossing() -> void:
	var th: float = Tuning.ship.heat_threshold
	assert_true(SoundModel.heat_click(th - 0.01, th + 0.01))
	assert_false(SoundModel.heat_click(th + 0.01, th + 0.02))
	assert_false(SoundModel.heat_click(th + 0.01, th - 0.01))
	assert_false(SoundModel.heat_click(0.1, 0.2))


func test_crack_due_period() -> void:
	var n := ceili(Tuning.view.crack_period / DT)
	assert_true(SoundModel.crack_due(0))
	assert_false(SoundModel.crack_due(1))
	assert_false(SoundModel.crack_due(n - 1))
	assert_true(SoundModel.crack_due(n))
	assert_true(SoundModel.crack_due(2 * n))


func test_reserve_mode_per_state() -> void:
	assert_eq(SoundModel.reserve_mode(HUD_SCRIPT.State.CALM), &"click")
	assert_eq(SoundModel.reserve_mode(HUD_SCRIPT.State.NEAR), &"double")
	assert_eq(SoundModel.reserve_mode(HUD_SCRIPT.State.BELOW), &"tone")


func test_reserve_beat_periods() -> void:
	var click := ceili(Tuning.view.reserve_click_period / DT)
	var dbl := ceili(Tuning.view.reserve_beep_period / DT)
	assert_true(SoundModel.reserve_beat(&"click", 0))
	assert_false(SoundModel.reserve_beat(&"click", click - 1))
	assert_true(SoundModel.reserve_beat(&"click", click))
	assert_true(SoundModel.reserve_beat(&"double", 0))
	assert_false(SoundModel.reserve_beat(&"double", dbl - 1))
	assert_true(SoundModel.reserve_beat(&"double", dbl))
	assert_false(SoundModel.reserve_beat(&"tone", 0))
	assert_false(SoundModel.reserve_beat(&"tone", dbl))


func test_cue_for_types() -> void:
	for t in [&"boundary", &"atmosphere", &"reserve", &"ceiling"]:
		assert_eq(SoundModel.cue_for(t), &"danger", t)
	for t in [&"tow", &"tow_refused"]:
		assert_eq(SoundModel.cue_for(t), &"info", t)
	assert_eq(SoundModel.cue_for(&"impact"), &"thud")
	assert_eq(SoundModel.cue_for(&"nonsense"), &"danger")
