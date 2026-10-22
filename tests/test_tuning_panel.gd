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
	for p in ["thrust_accel", "boost_accel_mult", "boost_fuel_mult", "brake_accel", "brake_fuel_mult", "fuel_per_dv", "predict_every", "predict_short_steps", "predict_full_steps"]:
		expect.append("ship." + p)
	for id in expect:
		assert_true(ids.has(id), id)
	assert_eq(ids.size(), expect.size(), "no extra sliders (no orbit sliders)")


func test_mass_sliders_and_predict_every_ranges() -> void:
	for i in 3:
		var s: HSlider = _panel.sliders["body%d.mass" % i]
		assert_true(s.exp_edit)
		assert_gte(s.max_value, 1e6)
	assert_eq(_panel.sliders["ship.predict_every"].min_value, 1.0)


func test_fade_width_slider_min_is_positive() -> void:
	assert_gt(_panel.sliders["field.fade_width"].min_value, 0.0)


func test_ship_slider_writes_to_current_ship_object() -> void:
	Tuning.ship = Tuning.ship.duplicate(true)
	var s: HSlider = _panel.sliders["ship.thrust_accel"]
	s.value = 321.0
	assert_eq(Tuning.ship.thrust_accel, 321.0)


func test_controls_have_no_focus() -> void:
	for c in _panel.find_children("*", "Control", true, false):
		if c.get_window() != get_tree().root:
			continue
		assert_eq(c.focus_mode, Control.FOCUS_NONE, str(c.name))


func test_load_p2_sets_all_p_and_sliders_follow() -> void:
	assert_eq(_panel.preset_select.selected, 3, "P4 selected at start")
	_panel.preset_select.select(1)
	_panel.load_button.pressed.emit()
	for i in 3:
		assert_eq(Tuning.field.bodies[i].p, 1.0)
		assert_eq(_panel.sliders["body%d.p" % i].value, 1.0)


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
