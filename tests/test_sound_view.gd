extends GutTest

const SHIP_SCENE := preload("res://scenes/Ship.tscn")
const WARNINGS_SCENE := preload("res://ui/Warnings.tscn")
const HUD_SCRIPT := preload("res://ui/HUD.gd")
const DT := 1.0 / 60.0

var _saved_planet
var _saved_view
var _saved_ship
var _saved_db := 0.0
var _saved_mute := false
var _root: Node
var _ship
var _warnings
var _view


func before_each() -> void:
	_saved_planet = Tuning.planet
	_saved_view = Tuning.view
	_saved_ship = Tuning.ship
	_saved_db = AudioServer.get_bus_volume_db(0)
	_saved_mute = AudioServer.is_bus_mute(0)
	Tuning.planet = Tuning.planet.duplicate()
	Tuning.planet.atmosphere_damage = 0.0
	Tuning.view = Tuning.view.duplicate()
	Tuning.ship = Tuning.ship.duplicate()


func after_each() -> void:
	Tuning.planet = _saved_planet
	Tuning.view = _saved_view
	Tuning.ship = _saved_ship
	AudioServer.set_bus_volume_db(0, _saved_db)
	AudioServer.set_bus_mute(0, _saved_mute)


func _scene(with_ship := true, with_warnings := true) -> void:
	_root = Node.new()
	if with_ship:
		_ship = SHIP_SCENE.instantiate()
		_ship.name = "Ship"
		_root.add_child(_ship)
	_view = SoundView.new()
	_view.name = "SoundView"
	_root.add_child(_view)
	if with_warnings:
		var layer := Node.new()
		layer.name = "CanvasLayer"
		_warnings = WARNINGS_SCENE.instantiate()
		layer.add_child(_warnings)
		_root.add_child(layer)
	add_child_autofree(_root)


func _tick(n := 1) -> void:
	for i in n:
		_view._physics_process(DT)


func _total() -> int:
	var n := 0
	for k in _view.played:
		n += _view.played[k]
	return n


func test_one_warning_shown_gives_exactly_one_cue() -> void:
	_scene()
	for t in [[&"boundary", &"danger"], [&"atmosphere", &"danger"], [&"reserve", &"danger"], [&"ceiling", &"danger"],
			[&"tow", &"info"], [&"tow_refused", &"info"], [&"impact", &"thud"]]:
		var before: int = _view.played.get(t[1], 0)
		var total := _total()
		_warnings.warning_shown.emit(t[0])
		assert_eq(_view.played.get(t[1], 0), before + 1, t[0])
		assert_eq(_total(), total + 1, t[0])


func test_docked_edge_plays_chord_once() -> void:
	_scene()
	_tick()
	_ship.state.docked = true
	_tick()
	assert_eq(_view.played.get(&"chord", 0), 1)
	_tick(3)
	assert_eq(_view.played.get(&"chord", 0), 1)


func test_docked_chord_even_when_flight_ended() -> void:
	_scene()
	_tick()
	_ship.phase = _ship.Phase.ENDED
	_ship.state.docked = true
	_tick()
	assert_eq(_view.played.get(&"chord", 0), 1)


func test_heat_crossing_plays_click_once() -> void:
	_scene()
	_ship.state.tank.clear()
	var th: float = Tuning.ship.heat_threshold
	_ship.state.heat = th - 0.01
	_tick()
	var before: int = _view.played.get(&"click", 0)
	_ship.state.heat = th + 0.01
	_tick()
	assert_eq(_view.played.get(&"click", 0), before + 1)
	_tick(2)
	assert_eq(_view.played.get(&"click", 0), before + 1)


func _mode_state(want: StringName) -> void:
	var s: ShipState = _ship.state
	match want:
		&"tone":
			s.tank.clear()
		&"double":
			while s.tank.size() > 1:
				s.tank.pop_back()
		_:
			Hold.add(s, &"fuel", 4)
	assert_eq(SoundModel.reserve_mode(HUD_SCRIPT.ship_reserve(s)), want, "precondition " + want)


func test_reserve_click_beats_follow_the_period() -> void:
	_scene()
	_mode_state(&"click")
	var period := ceili(Tuning.view.reserve_click_period / DT)
	_tick(period)
	assert_eq(_view.played.get(&"click", 0), 1, "tick 0 only")
	_tick(1)
	assert_eq(_view.played.get(&"click", 0), 2, "next period")


func test_reserve_double_beats_follow_the_period() -> void:
	_scene()
	_mode_state(&"double")
	var period := ceili(Tuning.view.reserve_beep_period / DT)
	_tick(period)
	assert_eq(_view.played.get(&"double", 0), 1)
	_tick(1)
	assert_eq(_view.played.get(&"double", 0), 2)


func test_reserve_tone_is_a_loop_without_beats() -> void:
	_scene()
	_mode_state(&"tone")
	_tick(300)
	assert_eq(_view.played.get(&"click", 0), 0)
	assert_eq(_view.played.get(&"double", 0), 0)
	assert_gt(_view.levels[&"tone"], 0.0)


func test_tone_off_outside_tone_mode() -> void:
	_scene()
	_mode_state(&"click")
	_tick()
	assert_eq(_view.levels[&"tone"], 0.0)


func test_mode_change_restarts_the_beat_counter() -> void:
	_scene()
	_mode_state(&"click")
	_tick(10)
	_mode_state(&"double")
	_tick()
	assert_eq(_view.played.get(&"double", 0), 1)


func test_atmosphere_crack_every_period_while_damaging() -> void:
	_scene()
	_mode_state(&"tone")
	_ship.state.pos = Vector2(Tuning.field.planet_surface_radius + 1.0, 0.0)
	Tuning.planet.atmosphere_damage = 5.0
	assert_gt(ShipFlight.atmosphere_density(_ship.state.pos), 0.0)
	var period := ceili(Tuning.view.crack_period / DT)
	_tick(period)
	var first := _total()
	assert_eq(first, 1, "one crack in the first period")
	_tick(1)
	assert_eq(_total(), 2)


func test_no_crack_without_damage() -> void:
	_scene()
	_mode_state(&"tone")
	_ship.state.pos = Vector2(Tuning.field.planet_surface_radius + 1.0, 0.0)
	_tick(100)
	assert_eq(_total(), 0)


func test_silent_while_ended() -> void:
	_scene()
	_mode_state(&"click")
	_ship.state.heat = 1.0
	_ship.state.pos = Vector2(Tuning.field.planet_surface_radius + 1.0, 0.0)
	Tuning.planet.atmosphere_damage = 5.0
	_tick(2)
	_ship.phase = _ship.Phase.ENDED
	var total := _total()
	_tick(600)
	assert_eq(_total(), total)
	for k in _view.levels:
		assert_eq(_view.levels[k], 0.0, k)


func test_silent_while_docked() -> void:
	_scene()
	_ship.state.docked = true
	_tick()
	var total := _total()
	_tick(600)
	assert_eq(_total(), total)
	for k in _view.levels:
		assert_eq(_view.levels[k], 0.0, k)


func test_loop_levels_follow_the_model() -> void:
	_scene()
	_mode_state(&"click")
	var s: ShipState = _ship.state
	s.hold_time = 5.0
	s.heat = 0.9
	_ship.input.thrust = true
	_ship.input.boost = true
	_tick()
	var level := SoundModel.thrust_level(s, _ship.input)
	assert_almost_eq(_view.levels[&"engine"], SoundModel.engine_volume(level), 1e-4)
	assert_almost_eq(_view.levels[&"rough"], SoundModel.rough_mix(0.9) * SoundModel.engine_volume(level), 1e-4)
	assert_gt(_view.levels[&"boost"], 0.0)
	assert_almost_eq(_view.players[&"engine"].pitch_scale, SoundModel.engine_pitch(Hold.mass(s), level), 1e-4)
	assert_almost_eq(_view.levels[&"hiss"], SoundModel.hiss_volume(ShipFlight.atmosphere_density(s.pos)), 1e-4)


func test_idle_engine_has_floor_and_no_boost() -> void:
	_scene()
	_mode_state(&"click")
	_tick()
	assert_almost_eq(_view.levels[&"engine"], 0.15, 1e-4)
	assert_eq(_view.levels[&"boost"], 0.0)
	assert_eq(_view.levels[&"rough"], 0.0)


func test_respawn_resets_the_counters() -> void:
	_scene()
	_mode_state(&"click")
	_tick(10)
	_ship.respawned.emit()
	_mode_state(&"click")
	_tick()
	assert_eq(_view.played.get(&"click", 0), 2, "tick 0 beat again after respawn")


func test_volume_applies_to_master_bus() -> void:
	_scene()
	Tuning.view.volume = 0.5
	_tick()
	assert_almost_eq(AudioServer.get_bus_volume_db(0), linear_to_db(0.5), 1e-3)
	assert_false(AudioServer.is_bus_mute(0))
	Tuning.view.volume = 0.0
	_tick()
	assert_true(AudioServer.is_bus_mute(0))


func test_null_safe_without_ship_and_warnings() -> void:
	_scene(false, false)
	_tick(3)
	_view.play(&"danger")
	assert_eq(_view.played.get(&"danger", 0), 1)


func test_null_safe_without_warnings() -> void:
	_scene(true, false)
	_tick(3)
	pass_test("no error")


func test_run_scene_has_sound_view_after_ship() -> void:
	var state: SceneState = (load("res://scenes/Run.tscn") as PackedScene).get_state()
	var ship := -1
	var sound := -1
	for i in state.get_node_count():
		match str(state.get_node_path(i)):
			"./Ship":
				ship = i
			"./SoundView":
				sound = i
	assert_gt(ship, -1)
	assert_gt(sound, ship)
