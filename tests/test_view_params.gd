extends GutTest


func test_view_defaults():
	var v: ViewParams = Tuning.view
	assert_eq(v.halo_alpha, 0.25)
	assert_eq(v.ring_count, 4)
	assert_eq(typeof(v.ring_count), TYPE_INT)
	assert_eq(v.ring_period, 2.0)
	assert_eq(v.ring_px, 1.5)
	assert_eq(v.ring_alpha, 0.5)
	assert_eq(v.cargo_fill, 0.5)
	for old in ["levels", "line_px", "dim", "bright", "near_px"]:
		assert_false(old in v, old)


func test_apply_keeps_view():
	var view = Tuning.view
	var saved_field = Tuning.field
	var saved_ship = Tuning.ship
	Tuning.apply(Tuning.load_preset("res://presets/p1.tres"))
	assert_same(Tuning.view, view)
	Tuning.field = saved_field
	Tuning.ship = saved_ship


func test_save_and_load_leave_view_untouched():
	var view = Tuning.view
	view.ring_alpha = 0.55
	var path := "user://test_view_preset.tres"
	assert_eq(Tuning.save_preset(path, "t"), OK)
	var loaded := Tuning.load_preset(path)
	assert_same(Tuning.view, view)
	assert_eq(Tuning.view.ring_alpha, 0.55)
	assert_false("view" in loaded)
	view.ring_alpha = 0.5
	DirAccess.remove_absolute(path)
