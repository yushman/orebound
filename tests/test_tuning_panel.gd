extends GutTest

const PANEL := preload("res://ui/TuningPanel.tscn")

var _field: FieldParams
var _ship: ShipParams
var _planet: PlanetParams
var _view: ViewParams
var _panel: Control


func before_each() -> void:
	_field = Tuning.field
	_ship = Tuning.ship
	Tuning.field = _field.duplicate(true)
	Tuning.ship = _ship.duplicate(true)
	_planet = Tuning.planet
	Tuning.planet = _planet.duplicate(true)
	_view = Tuning.view
	Tuning.view = _view.duplicate(true)
	_panel = PANEL.instantiate()
	add_child_autofree(_panel)


func after_each() -> void:
	Tuning.field = _field
	Tuning.ship = _ship
	Tuning.planet = _planet
	Tuning.view = _view


func test_k_slider_changes_accel_on_next_call() -> void:
	var pos := Vector2(500.0, 100.0)
	var before := GravityField.accel(pos, 0.0)
	var s: HSlider = _panel.sliders["field.k"]
	s.value = s.value * 2.0
	assert_eq(Tuning.field.k, s.value)
	assert_almost_eq(GravityField.accel(pos, 0.0).length(), before.length() * 2.0, 1e-3)


func test_slider_set_covers_all_parameters() -> void:
	var ids: Array = _panel.sliders.keys()
	var expect := ["field.k", "field.eps", "field.fade_width"]
	for i in 3:
		expect.append("body%d.p" % i)
		expect.append("body%d.mass" % i)
	for i in [1, 2]:
		expect.append("body%d.influence_radius" % i)
	for p in ["thrust_accel", "boost_accel_mult", "boost_fuel_mult", "brake_accel",
			"brake_fuel_mult", "fuel_per_dv", "ramp_time", "ramp_min_fraction", "heat_growth_engine",
			"heat_growth_boost", "heat_threshold", "heat_cooldown", "min_thrust_fraction",
			"sync_accel", "sync_fuel_mult", "predict_every", "predict_short_steps", "hull_max"]:
		expect.append("ship." + p)
	for p in ["atmosphere_drag", "atmosphere_damage", "density_shape", "moon_mass_k", "moon_mass_exp",
			"moon_influence_k", "moon_margin", "moon_bounce", "moon_impact_damage",
				"ring_width", "ring_density", "band_width", "chunk_arc", "chunk_gen_radius",
				"asteroids_per_band", "drop_start", "drop_ratio", "above_factor", "field_radius",
				"ast_radius_min", "ast_radius_max", "asteroid_bounce", "asteroid_impact_damage"]:
		expect.append("planet." + p)
	for p in ["halo_alpha", "ring_count", "ring_period", "ring_px", "ring_alpha"]:
		expect.append("view." + p)
	for id in expect:
		assert_true(ids.has(id), id)
	assert_eq(ids.size(), expect.size(), "no extra sliders (no orbit sliders)")
	for id in ["ship.sync_radius", "ship.turn_accel", "ship.spin_damping",
			"ship.heading_gain", "field.planet_surface_radius", "field.atmosphere_edge",
			"field.carrier_orbit_radius"]:
		assert_false(ids.has(id), "%s is a preset constant, not a slider" % id)


func test_slider_ranges_new_scale() -> void:
	for i in 3:
		var m: HSlider = _panel.sliders["body%d.mass" % i]
		assert_true(m.exp_edit)
		assert_eq(m.min_value, 1.0)
		assert_eq(m.max_value, 2e7)
	for i in [1, 2]:
		var inf: HSlider = _panel.sliders["body%d.influence_radius" % i]
		assert_eq(inf.min_value, 0.0)
		assert_eq(inf.max_value, 20000.0)
	var thrust: HSlider = _panel.sliders["ship.thrust_accel"]
	assert_eq(thrust.min_value, 0.0)
	assert_eq(thrust.max_value, 50.0)
	var brake: HSlider = _panel.sliders["ship.brake_accel"]
	assert_eq(brake.min_value, 0.0)
	assert_eq(brake.max_value, 50.0)
	var ranges := {
		"ship.ramp_time": [0.0, 5.0],
		"ship.ramp_min_fraction": [0.0, 1.0],
		"ship.heat_growth_engine": [0.0, 0.5],
		"ship.heat_growth_boost": [0.0, 1.0],
		"ship.heat_threshold": [0.0, 1.0],
		"ship.heat_cooldown": [0.0, 0.5],
		"ship.min_thrust_fraction": [0.0, 1.0],
		"ship.sync_accel": [0.0, 30.0],
		"ship.sync_fuel_mult": [0.0, 10.0],
	}
	for id in ranges:
		var s: HSlider = _panel.sliders[id]
		assert_eq(s.min_value, ranges[id][0], id)
		assert_eq(s.max_value, ranges[id][1], id)
	assert_eq(_panel.sliders["ship.predict_every"].min_value, 1.0)
	var ps: HSlider = _panel.sliders["ship.predict_short_steps"]
	assert_eq(ps.min_value, 300.0)
	assert_eq(ps.max_value, 1800.0)


func test_ship_defaults_fit_slider_ranges() -> void:
	for row in _panel.ROWS:
		if not (row[0] is String and row[0] == "ship"):
			continue
		var s: HSlider = _panel.sliders["ship." + row[1]]
		var v: float = Tuning.ship.get(row[1])
		assert_between(v, s.min_value, s.max_value, row[1])


func test_planet_defaults_fit_slider_ranges() -> void:
	for row in _panel.ROWS:
		if not (row[0] is String and row[0] == "planet"):
			continue
		var s: HSlider = _panel.sliders["planet." + row[1]]
		assert_between(Tuning.planet.get(row[1]), s.min_value, s.max_value, row[1])


func test_planet_atmosphere_sliders_write_into_current_tuning_planet() -> void:
	Tuning.planet = Tuning.planet.duplicate(true)
	_panel.sliders["planet.atmosphere_drag"].value = 0.3
	_panel.sliders["planet.atmosphere_damage"].value = 7.0
	_panel.sliders["planet.density_shape"].value = 1.5
	_panel.sliders["ship.hull_max"].value = 55.0
	assert_eq(Tuning.planet.atmosphere_drag, 0.3)
	assert_eq(Tuning.planet.atmosphere_damage, 7.0)
	assert_eq(Tuning.planet.density_shape, 1.5)
	assert_eq(Tuning.ship.hull_max, 55.0)


func test_sync_sets_planet_sliders_without_write_back() -> void:
	Tuning.planet.atmosphere_drag = 0.125
	_panel._sync()
	assert_eq(_panel.sliders["planet.atmosphere_drag"].value, 0.125)
	assert_eq(Tuning.planet.atmosphere_drag, 0.125)


func test_fade_width_slider_min_is_positive() -> void:
	assert_gt(_panel.sliders["field.fade_width"].min_value, 0.0)


func test_ship_slider_writes_to_current_ship_object() -> void:
	Tuning.ship = Tuning.ship.duplicate(true)
	var s: HSlider = _panel.sliders["ship.thrust_accel"]
	s.value = 21.5
	assert_eq(Tuning.ship.thrust_accel, 21.5)


func test_controls_have_no_focus() -> void:
	for c in _panel.find_children("*", "Control", true, false):
		if c.get_window() != get_tree().root:
			continue
		if c == _panel.seed_box.get_line_edit():
			continue
		assert_eq(c.focus_mode, Control.FOCUS_NONE, str(c.name))


func test_load_p2_sets_all_p_and_sliders_follow() -> void:
	assert_eq(_panel.preset_select.selected, 3, "P4 selected at start")
	_panel.preset_select.select(1)
	_panel.load_button.pressed.emit()
	assert_eq(Tuning.field.bodies[0].p, 1.0, "planet p = 1")
	assert_between(Tuning.field.bodies.size(), 3, 4, "planet plus generated moons")
	assert_eq(_panel.sliders["body0.p"].value, 1.0, "planet slider follows")
	assert_true(_panel.sliders["body0.p"].get_parent().visible, "planet row visible")
	for i in range(1, 3):
		assert_true(_panel.sliders["body%d.p" % i].get_parent().visible, "body%d row visible" % i)


func test_preset_list_shows_full_names_matching_files() -> void:
	for i in 4:
		var preset := Tuning.load_preset("res://presets/p%d.tres" % (i + 1))
		assert_eq(_panel.preset_select.get_item_text(i), preset.name)
		assert_true(preset.name.length() > 2)


func test_sync_does_not_write_back() -> void:
	_panel.preset_select.select(0)
	_panel.load_button.pressed.emit()
	var preset := Tuning.load_preset("res://presets/p1.tres")
	assert_eq(Tuning.field.bodies[0].mass, preset.field.bodies[0].mass)
	assert_eq(Tuning.ship.predict_every, preset.ship.predict_every)


func test_sync_with_one_body_field_skips_body_sliders() -> void:
	var field := Tuning.field.duplicate(true)
	field.bodies.resize(1)
	Tuning.field = field
	Tuning.field.bodies[0].p = 1.5
	Tuning.ship.thrust_accel = 123.0
	_panel._sync()
	assert_eq(_panel.sliders["body0.p"].value, 1.5, "planet row still syncs")
	assert_eq(_panel.sliders["ship.thrust_accel"].value, 123.0, "sync reaches ship rows")
	assert_true(_panel.sliders["body0.p"].get_parent().visible, "planet row visible")
	assert_false(_panel.sliders["body1.p"].get_parent().visible, "body1 row hidden")
	assert_false(_panel.sliders["body2.mass"].get_parent().visible, "body2 row hidden")


func test_save_writes_selected_preset_to_presets_dir() -> void:
	var path := "user://p2.tres"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_panel.presets_dir = "user://"
	_panel.preset_select.select(1)
	_panel.sliders["field.k"].value = 777.0
	_panel.save_button.pressed.emit()
	assert_true(FileAccess.file_exists(path))
	var saved := Tuning.load_preset(path)
	assert_eq(saved.field.k, 777.0)
	DirAccess.remove_absolute(path)


func _key_event(action: String, pressed := true) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	return e


func test_toggle_event_flips_visibility_and_is_handled() -> void:
	assert_false(_panel.visible, "hidden by default")
	get_viewport().push_input(_key_event("debug_tuning_panel"))
	assert_true(_panel.visible)
	assert_true(get_viewport().is_input_handled())
	_panel._unhandled_input(_key_event("debug_tuning_panel"))
	assert_false(_panel.visible)


func test_other_events_do_not_toggle() -> void:
	_panel._unhandled_input(_key_event("ship_thrust"))
	assert_false(_panel.visible)
	_panel._unhandled_input(_key_event("debug_tuning_panel", false))
	assert_false(_panel.visible)


func test_space_never_triggers_a_preset_load() -> void:
	_panel.visible = true
	var fired := [0]
	Tuning.preset_applied.connect(func(): fired[0] += 1)
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.physical_keycode = KEY_SPACE
	ev.pressed = true
	get_viewport().push_input(ev)
	ev = ev.duplicate()
	ev.pressed = false
	get_viewport().push_input(ev)
	assert_null(get_viewport().gui_get_focus_owner())
	assert_eq(fired[0], 0, "Space (ui_accept) must not press a panel button")


func test_readout_shows_hull_density_and_crashes() -> void:
	var crashes := Telemetry.crashes
	var ship = load("res://scenes/Ship.tscn").instantiate()
	add_child_autofree(ship)
	var f := Tuning.field
	ship.state.pos = Vector2(0.5 * (f.planet_surface_radius + f.atmosphere_edge), 0.0)
	ship.state.hull = 42.0
	Telemetry.crashes = 3
	_panel.ship = ship
	_panel.visible = true
	_panel._process(0.0)
	var text: String = _panel.readout.text
	assert_string_contains(text, "42")
	assert_string_contains(text, str(snappedf(ShipFlight.atmosphere_density(ship.state.pos), 0.001)))
	assert_string_contains(text, "3")
	Telemetry.crashes = crashes


func test_readout_without_ship_does_not_error() -> void:
	_panel.visible = true
	_panel._process(0.0)
	assert_not_null(_panel.readout)


func test_view_defaults_fit_slider_ranges() -> void:
	for row in _panel.ROWS:
		if not (row[0] is String and row[0] == "view"):
			continue
		var s: HSlider = _panel.sliders["view." + row[1]]
		var d: float = Tuning.view.get(row[1])
		assert_between(d, s.min_value, s.max_value, row[1])
		assert_almost_eq(snappedf(d - s.min_value, s.step), d - s.min_value, 1e-6, row[1] + " on grid")


func test_view_sliders_write_into_current_tuning_view() -> void:
	Tuning.view = Tuning.view.duplicate(true)
	_panel.sliders["view.halo_alpha"].value = 0.4
	_panel.sliders["view.ring_count"].value = 7.0
	_panel.sliders["view.ring_period"].value = 3.5
	_panel.sliders["view.ring_px"].value = 2.5
	_panel.sliders["view.ring_alpha"].value = 0.8
	assert_eq(Tuning.view.halo_alpha, 0.4)
	assert_eq(Tuning.view.ring_count, 7)
	assert_true(Tuning.view.ring_count is int)
	assert_eq(Tuning.view.ring_period, 3.5)
	assert_eq(Tuning.view.ring_px, 2.5)
	assert_eq(Tuning.view.ring_alpha, 0.8)


func test_sync_sets_view_sliders_without_write_back() -> void:
	Tuning.view.ring_alpha = 0.12
	_panel._sync()
	assert_eq(_panel.sliders["view.ring_alpha"].value, 0.12)
	assert_eq(Tuning.view.ring_alpha, 0.12)


func test_seed_typed_regenerates_and_next_seed_uses_used_plus_one() -> void:
	var old_seed := Telemetry.seed
	var old_flight := Telemetry.flight
	_panel.seed_box.value = 7
	var expect := WellGenerator.picture(7, 1)
	assert_eq(Telemetry.seed, expect["seed"])
	assert_eq(Tuning.field.bodies.size(), 1 + expect["moons"].size())
	assert_eq(_panel.seed_box.value, float(Telemetry.seed), "field shows used seed")
	var used := Telemetry.seed
	_panel.next_seed_button.pressed.emit()
	assert_eq(Telemetry.seed, WellGenerator.picture(used + 1, Telemetry.flight)["seed"])
	assert_eq(_panel.seed_box.value, float(Telemetry.seed))
	Telemetry.seed = old_seed
	Telemetry.flight = old_flight


func test_seed_line_edit_takes_focus_and_typed_seed_regenerates() -> void:
	var old_seed := Telemetry.seed
	var old_flight := Telemetry.flight
	var le: LineEdit = _panel.seed_box.get_line_edit()
	assert_ne(le.focus_mode, Control.FOCUS_NONE)
	le.grab_focus()
	assert_eq(get_viewport().gui_get_focus_owner(), le)
	le.text = ""
	le.insert_text_at_caret("42")
	le.text_submitted.emit(le.text)
	assert_eq(Telemetry.seed, WellGenerator.picture(42, 1)["seed"])
	assert_null(get_viewport().gui_get_focus_owner())
	Telemetry.seed = old_seed
	Telemetry.flight = old_flight


func test_preset_load_regenerates_moons_with_current_seed() -> void:
	var old_seed := Telemetry.seed
	var old_flight := Telemetry.flight
	Telemetry.seed = 5
	_panel.preset_select.select(1)
	_panel.load_button.pressed.emit()
	assert_eq(Tuning.field.bodies[0].p, 1.0)
	var n := Tuning.field.bodies.size()
	assert_between(n, 3, 4, "2-3 moons")
	for i in range(1, 4):
		var row: Control = _panel.sliders["body%d.p" % i].get_parent() if i < 3 else null
		if row == null:
			continue
		assert_eq(row.visible, i < n, "body%d row" % i)
		if i < n:
			assert_almost_eq(_panel.sliders["body%d.mass" % i].value, Tuning.field.bodies[i].mass, 0.01)
	Telemetry.seed = old_seed
	Telemetry.flight = old_flight


func test_moon_mass_k_slider_regenerates_moons_with_new_mass() -> void:
	var old_seed := Telemetry.seed
	var old_flight := Telemetry.flight
	Tuning.regenerate(3, 1)
	var used := Telemetry.seed
	var before: float = Tuning.field.bodies[1].mass
	_panel.sliders["planet.moon_mass_k"].value = Tuning.planet.moon_mass_k * 2.0
	assert_almost_eq(Tuning.field.bodies[1].mass, before * 2.0, before * 0.01)
	assert_eq(Telemetry.seed, used)
	var n := Tuning.field.bodies.size()
	_panel.sliders["planet.moon_bounce"].value = 0.25
	assert_eq(Tuning.planet.moon_bounce, 0.25)
	assert_eq(Tuning.field.bodies.size(), n)
	Telemetry.seed = old_seed
	Telemetry.flight = old_flight


func test_ring_width_slider_regenerates_picture_and_field_knobs_do_not() -> void:
	var old_seed := Telemetry.seed
	var old_flight := Telemetry.flight
	var old_picture: Dictionary = Tuning.picture
	Tuning.regenerate(3, 1)
	var before: Dictionary = Tuning.picture
	_panel.sliders["planet.ring_width"].value = 1000.0
	assert_eq(Tuning.planet.ring_width, 1000.0)
	assert_ne(Tuning.picture, before, "new picture object after ring_width change")
	if not Tuning.picture["ring"].is_empty():
		assert_eq(Tuning.picture["ring"]["width"], 1000.0)
	var after: Dictionary = Tuning.picture
	_panel.sliders["planet.ring_density"].value = 0.8
	assert_eq(Tuning.planet.ring_density, 0.8)
	assert_ne(Tuning.picture, after, "ring_density regenerates")
	var kept: Dictionary = Tuning.picture
	_panel.sliders["planet.band_width"].value = 2000.0
	_panel.sliders["planet.asteroids_per_band"].value = 9.0
	assert_eq(Tuning.planet.band_width, 2000.0)
	assert_eq(Tuning.planet.asteroids_per_band, 9.0)
	assert_same(Tuning.picture, kept)
	Tuning.picture = old_picture
	Telemetry.seed = old_seed
	Telemetry.flight = old_flight
