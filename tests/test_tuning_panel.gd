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
	for p in ["thrust_accel", "boost_accel_mult", "boost_fuel_mult", "spawn_descend_speed", "brake_accel",
			"brake_fuel_mult", "climb_coefficient", "ramp_time", "ramp_min_fraction", "heat_growth_engine",
			"heat_growth_boost", "heat_threshold", "heat_cooldown", "min_thrust_fraction",
			"sync_accel", "sync_fuel_mult", "predict_every", "predict_short_steps", "hull_max",
				"hull_mass", "hold_capacity", "ref_mass", "loadout_fuel_cells", "tank_capacity",
				"beam_range", "beam_damage", "collect_angle", "collect_accel", "return_margin", "hit_radius",
				"jettison_tap_time", "jettison_hold_time", "jettison_interval", "jettison_push", "jettison_pickup_delay",
				"refiner", "transfer_hold_time", "transfer_interval"]:
		expect.append("ship." + p)
	for p in ["carrier_patrol_speed", "atmosphere_drag", "atmosphere_damage", "density_shape", "moon_mass_k", "moon_mass_exp",
			"moon_influence_k", "moon_margin", "moon_bounce", "moon_impact_damage",
				"ring_width", "ring_density", "ring_dust_density", "ring_drag_tau", "band_width", "chunk_arc", "ring_boulders_per_chunk", "chunk_gen_radius",
				"asteroids_per_band", "drop_start", "drop_ratio", "above_factor", "field_radius",
				"ast_radius_min", "ast_radius_max", "asteroid_bounce", "asteroid_impact_damage", "rest_speed", "amount_per_area", "top_ice_share",
					"piece_swallow_radius", "piece_despawn_radius", "piece_bounce", "v_safe", "impact_k",
					"split_count", "split_area_divisor", "collect_radius", "break_per_sqrt_radius", "piece_lifetime", "piece_min_radius", "piece_scatter", "piece_spread"]:
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
		"ship.spawn_descend_speed": [0.0, 20.0],
		"planet.ring_dust_density": [0.0, 1.0],
		"planet.carrier_patrol_speed": [0.0, 100.0],
	}
	for id in ranges:
		var s: HSlider = _panel.sliders[id]
		assert_eq(s.min_value, ranges[id][0], id)
		assert_eq(s.max_value, ranges[id][1], id)
	assert_eq(_panel.sliders["planet.carrier_patrol_speed"].step, 5.0)
	assert_eq(_panel.sliders["ship.spawn_descend_speed"].step, 1.0)
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


func test_hold_ship_sliders_write_ints_as_int() -> void:
	Tuning.ship = Tuning.ship.duplicate(true)
	_panel.sliders["ship.hold_capacity"].value = 12.0
	_panel.sliders["ship.tank_capacity"].value = 6.0
	_panel.sliders["ship.loadout_fuel_cells"].value = 3.0
	_panel.sliders["ship.hull_mass"].value = 5.5
	assert_eq(Tuning.ship.hold_capacity, 12)
	assert_true(Tuning.ship.hold_capacity is int)
	assert_true(Tuning.ship.tank_capacity is int)
	assert_true(Tuning.ship.loadout_fuel_cells is int)
	assert_eq(Tuning.ship.hull_mass, 5.5)


func test_hull_mass_slider_min_is_positive() -> void:
	assert_gt(_panel.sliders["ship.hull_mass"].min_value, 0.0)


func test_planet_defaults_fit_slider_ranges() -> void:
	for row in _panel.ROWS:
		if not (row[0] is String and row[0] == "planet"):
			continue
		var idx: int = row[5] if row.size() > 5 else -1
		var s: HSlider = _panel.sliders["planet." + row[1] + (str(idx) if idx >= 0 else "")]
		var v = Tuning.planet.get(row[1])
		assert_between(v[idx] if idx >= 0 else v, s.min_value, s.max_value, row[1])


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
	assert_string_contains(text, "crashes 3")
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


func test_next_seed_after_fallback_uses_requested_plus_one() -> void:
	var old_seed := Telemetry.seed
	var old_flight := Telemetry.flight
	var margin := Tuning.planet.moon_margin
	Tuning.planet.moon_margin = 1.0e7
	_panel.seed_box.value = 7
	assert_eq(Telemetry.seed, Tuning.planet.fallback_seed, "typed seed fell back")
	assert_eq(_panel.seed_box.value, float(Telemetry.seed), "box shows used seed")
	Tuning.planet.moon_margin = margin
	_panel.next_seed_button.pressed.emit()
	var expect := WellGenerator.picture(8, Telemetry.flight)
	assert_eq(Telemetry.seed, expect["seed"])
	assert_eq(_panel.seed_box.value, float(Telemetry.seed))
	_panel.next_seed_button.pressed.emit()
	assert_eq(Telemetry.seed, WellGenerator.picture(9, Telemetry.flight)["seed"])
	Telemetry.seed = old_seed
	Telemetry.flight = old_flight


func test_next_seed_after_retry_does_not_repeat_used_seed() -> void:
	var old_seed := Telemetry.seed
	var old_flight := Telemetry.flight
	var n := 0
	while WellGenerator.picture(n, 1)["seed"] != n + 1 and n < 500:
		n += 1
	assert_lt(n, 500, "found a seed whose check fails and retry passes")
	_panel.seed_box.value = n
	assert_eq(Telemetry.seed, n + 1, "typed seed retried")
	var before: Array = Tuning.picture["moons"]
	_panel.next_seed_button.pressed.emit()
	assert_ne(Telemetry.seed, n + 1, "next does not repeat the used seed")
	assert_ne(Tuning.picture["moons"], before, "moons differ")
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


func test_load_emits_preset_applied_once() -> void:
	var old_seed := Telemetry.seed
	var old_flight := Telemetry.flight
	var fired := [0]
	var cb := func() -> void: fired[0] += 1
	Tuning.preset_applied.connect(cb)
	_panel.load_button.pressed.emit()
	Tuning.preset_applied.disconnect(cb)
	assert_eq(fired[0], 1)
	Telemetry.seed = old_seed
	Telemetry.flight = old_flight


func test_gravity_slider_regenerates_moons() -> void:
	var old_seed := Telemetry.seed
	var old_flight := Telemetry.flight
	Tuning.regenerate(3, 1)
	var fired := [0]
	var cb := func() -> void: fired[0] += 1
	Tuning.preset_applied.connect(cb)
	var before: float = Tuning.field.bodies[1].angular_speed
	_panel.sliders["field.k"].value = Tuning.field.k * 2.0
	assert_eq(fired[0], 1, "field.k regenerates")
	assert_ne(Tuning.field.bodies[1].angular_speed, before, "moon angular_speed follows k")
	_panel.sliders["field.eps"].value = Tuning.field.eps + 0.5
	assert_eq(fired[0], 2, "field.eps")
	_panel.sliders["field.fade_width"].value = Tuning.field.fade_width + 0.25
	assert_eq(fired[0], 3, "field.fade_width")
	_panel.sliders["body0.mass"].value = Tuning.field.bodies[0].mass * 1.5
	assert_eq(fired[0], 4, "body0.mass")
	_panel.sliders["body0.p"].value = Tuning.field.bodies[0].p + 0.25
	assert_eq(fired[0], 5, "body0.p")
	_panel.sliders["ship.thrust_accel"].value = 10.0
	_panel.sliders["body1.p"].value = 1.5
	assert_eq(fired[0], 5, "other sliders do not regenerate")
	Tuning.preset_applied.disconnect(cb)
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
	_panel.sliders["planet.asteroids_per_band"].value = 150.0
	assert_eq(Tuning.planet.band_width, 2000.0)
	assert_eq(Tuning.planet.asteroids_per_band, 150.0)
	assert_same(Tuning.picture, kept)
	Tuning.picture = old_picture
	Telemetry.seed = old_seed
	Telemetry.flight = old_flight


func _stub_ship() -> Node:
	var script := GDScript.new()
	script.source_code = "extends Node\nvar calls := 0\nfunc respawn() -> void:\n\tcalls += 1\n"
	script.reload()
	var stub := Node.new()
	stub.set_script(script)
	add_child_autofree(stub)
	_panel.ship = stub
	return stub


func test_hold_sliders_respawn_the_ship() -> void:
	var stub := _stub_ship()
	var n := 0
	for p in ["loadout_fuel_cells", "hold_capacity", "tank_capacity"]:
		var s: HSlider = _panel.sliders["ship." + p]
		s.value = s.value + 1.0
		n += 1
		assert_eq(stub.calls, n, p)


func test_other_ship_sliders_and_sync_do_not_respawn() -> void:
	var stub := _stub_ship()
	_panel.sliders["ship.thrust_accel"].value = 12.0
	_panel.sliders["ship.hull_mass"].value = 5.5
	_panel.sliders["ship.ref_mass"].value = 12.0
	_panel.sliders["ship.climb_coefficient"].value = 0.5
	_panel._sync()
	assert_eq(stub.calls, 0)


func test_hold_slider_without_ship_does_not_error() -> void:
	_panel.ship = null
	_panel.sliders["ship.hold_capacity"].value = 12.0
	assert_eq(Tuning.ship.hold_capacity, 12)


func test_panel_has_rows_for_amount_per_area_top_ice_share_beam_range_beam_damage() -> void:
	for id in ["planet.amount_per_area", "planet.top_ice_share", "ship.beam_range", "ship.beam_damage"]:
		assert_true(_panel.sliders.has(id), id)


func test_return_knob_sliders_write_into_tuning_ship() -> void:
	_panel.sliders["ship.return_margin"].value = 1.5
	assert_eq(Tuning.ship.return_margin, 1.5)
	for k in ["mode", "tau"]:
		assert_false(_panel.sliders.has("ship.return_" + "speed_" + k))


func test_small_object_sliders_write_without_regenerate() -> void:
	var before: int = Telemetry.seed
	_panel.sliders["ship.hit_radius"].value = 20.0
	assert_eq(Tuning.ship.hit_radius, 20.0)
	assert_eq(Telemetry.seed, before)


func test_jettison_slider_writes_ship_params() -> void:
	Tuning.ship = Tuning.ship.duplicate(true)
	_panel.sliders["ship.jettison_push"].value = 8.0
	assert_eq(Tuning.ship.jettison_push, 8.0)
	_panel.sliders["ship.jettison_pickup_delay"].value = 2.5
	assert_eq(Tuning.ship.jettison_pickup_delay, 2.5)


func test_ring_boulder_and_drag_sliders_write_into_tuning_planet() -> void:
	for k in ["planet.ring_boulders_per_chunk", "planet.ring_drag_tau"]:
		assert_true(_panel.sliders.has(k), k)
		if not _panel.sliders.has(k):
			return
	var boulders: HSlider = _panel.sliders["planet.ring_boulders_per_chunk"]
	assert_eq(boulders.min_value, 0.0, "boulders min")
	assert_eq(boulders.max_value, 10.0, "boulders max")
	assert_eq(boulders.step, 0.1, "boulders step")
	var tau: HSlider = _panel.sliders["planet.ring_drag_tau"]
	assert_eq(tau.min_value, 0.05, "tau min")
	assert_eq(tau.max_value, 30.0, "tau max")
	assert_eq(tau.step, 0.05, "tau step")
	assert_between(Tuning.planet.ring_boulders_per_chunk, boulders.min_value, boulders.max_value)
	assert_between(Tuning.planet.ring_drag_tau, tau.min_value, tau.max_value)
	var before: Dictionary = Tuning.picture
	var old_seed := Telemetry.seed
	boulders.value = 2.5
	tau.value = 4.0
	assert_eq(Tuning.planet.ring_boulders_per_chunk, 2.5)
	assert_eq(Tuning.planet.ring_drag_tau, 4.0)
	assert_same(Tuning.picture, before, "no picture regeneration")
	assert_eq(Telemetry.seed, old_seed, "no regenerate")


func test_ring_dust_density_slider_writes_planet_without_regenerate() -> void:
	assert_true(_panel.sliders.has("planet.ring_dust_density"))
	var s: HSlider = _panel.sliders["planet.ring_dust_density"]
	assert_eq(s.min_value, 0.0, "dust min")
	assert_eq(s.max_value, 1.0, "dust max")
	assert_eq(s.step, 0.05, "dust step")
	assert_between(Tuning.planet.ring_dust_density, s.min_value, s.max_value)
	var before: Dictionary = Tuning.picture
	var old_seed := Telemetry.seed
	s.value = 0.35
	assert_almost_eq(Tuning.planet.ring_dust_density, 0.35, 1e-6)
	assert_same(Tuning.picture, before, "no picture regeneration")
	assert_eq(Telemetry.seed, old_seed, "no regenerate")


func test_carrier_patrol_speed_slider_writes_planet_without_regenerate() -> void:
	assert_true(_panel.sliders.has("planet.carrier_patrol_speed"))
	var s: HSlider = _panel.sliders["planet.carrier_patrol_speed"]
	assert_eq(s.min_value, 0.0, "patrol min")
	assert_eq(s.max_value, 100.0, "patrol max")
	assert_eq(s.step, 5.0, "patrol step")
	assert_eq(Tuning.planet.carrier_patrol_speed, 40.0, "playtest hypothesis default")
	var before: Dictionary = Tuning.picture
	var old_seed := Telemetry.seed
	s.value = 25.0
	assert_eq(Tuning.planet.carrier_patrol_speed, 25.0)
	assert_same(Tuning.picture, before, "no picture regeneration")
	assert_eq(Telemetry.seed, old_seed, "no regenerate")


func test_transfer_sliders_write_ship_params() -> void:
	Tuning.ship = Tuning.ship.duplicate(true)
	for k in ["ship.refiner", "ship.transfer_hold_time", "ship.transfer_interval"]:
		assert_true(_panel.sliders.has(k), k)
		if not _panel.sliders.has(k):
			return
	_panel.sliders["ship.refiner"].value = 1.0
	assert_true(Tuning.ship.refiner)
	assert_eq(typeof(Tuning.ship.refiner), TYPE_BOOL)
	_panel.sliders["ship.refiner"].value = 0.0
	assert_false(Tuning.ship.refiner)
	_panel.sliders["ship.transfer_hold_time"].value = 2.0
	assert_eq(Tuning.ship.transfer_hold_time, 2.0)
	_panel.sliders["ship.transfer_interval"].value = 1.5
	assert_eq(Tuning.ship.transfer_interval, 1.5)
