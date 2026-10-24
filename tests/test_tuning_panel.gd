extends GutTest

const PANEL := preload("res://ui/TuningPanel.tscn")

var _field: FieldParams
var _ship: ShipParams
var _panel: Control


func before_each() -> void:
	_field = Tuning.field
	_ship = Tuning.ship
	Tuning.field = _field.duplicate(true)
	Tuning.ship = _ship.duplicate(true)
	_panel = PANEL.instantiate()
	add_child_autofree(_panel)


func after_each() -> void:
	Tuning.field = _field
	Tuning.ship = _ship


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
			"sync_accel", "sync_fuel_mult", "predict_every", "predict_short_steps"]:
		expect.append("ship." + p)
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
		assert_eq(c.focus_mode, Control.FOCUS_NONE, str(c.name))


func test_load_p2_sets_all_p_and_sliders_follow() -> void:
	assert_eq(_panel.preset_select.selected, 3, "P4 selected at start")
	_panel.preset_select.select(1)
	_panel.load_button.pressed.emit()
	assert_eq(Tuning.field.bodies[0].p, 1.0, "planet p = 1")
	assert_eq(Tuning.field.bodies[1].p, 2.0, "moon p = 2")
	assert_eq(Tuning.field.bodies[2].p, 2.0, "moon p = 2")
	for i in 3:
		assert_eq(_panel.sliders["body%d.p" % i].value, Tuning.field.bodies[i].p, "body%d slider follows" % i)
		assert_true(_panel.sliders["body%d.p" % i].get_parent().visible, "body%d row back after 3-body load" % i)


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
