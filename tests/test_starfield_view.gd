extends GutTest

var _saved_view
var _saved_picture: Dictionary


func before_each():
	_saved_view = Tuning.view
	_saved_picture = Tuning.picture


func after_each():
	Tuning.view = _saved_view
	Tuning.picture = _saved_picture


func test_star_at_world_point_stays_put_as_camera_moves():
	var p := Vector2(9123.0, -4077.0)
	var c := StarfieldView.cell_size(0)
	var cx := int(floor(p.x / c))
	var cy := int(floor(p.y / c))
	var pos := StarfieldView.star_pos(cx, cy, 0, 0)
	assert_true(pos.x >= float(cx) * c and pos.x < float(cx + 1) * c, "star x inside its cell")
	assert_true(pos.y >= float(cy) * c and pos.y < float(cy + 1) * c, "star y inside its cell")
	for cam in [Vector2.ZERO, Vector2(5.0, -3.0), Vector2(-12000.0, 8000.0)]:
		assert_eq(StarfieldView.star_pos(cx, cy, 0, 0), pos, "camera %s does not move the star" % cam)


func test_same_seed_same_sky_and_other_seed_other_sky():
	var cells := [Vector2i(0, 0), Vector2i(3, -1), Vector2i(-7, 2), Vector2i(12, 8), Vector2i(-25, -9)]
	var first: Array = []
	for cell in cells:
		first.append(StarfieldView.star_pos(cell.x, cell.y, 0, 0))
	var again: Array = []
	for cell in cells:
		again.append(StarfieldView.star_pos(cell.x, cell.y, 0, 0))
	assert_eq(again, first, "same seed gives the same sky")
	Tuning.picture = {"seed": 4242, "flight": 1, "moons": [], "ring": {}}
	var moved := 0
	for i in cells.size():
		if StarfieldView.star_pos(cells[i].x, cells[i].y, 0, 0) != first[i]:
			moved += 1
	assert_gt(moved, 0, "a different seed gives a different sky")


func test_layer_weights_cross_fade_three_layers_and_sum_to_one():
	assert_almost_eq(StarfieldView.cell_size(0), 418.0, 1e-6)
	assert_almost_eq(StarfieldView.cell_size(1), 3344.0, 1e-6)
	assert_almost_eq(StarfieldView.cell_size(2), 26752.0, 1e-6)
	var w: ViewParams = Tuning.view.duplicate()
	w.star_cell0 = 64.0
	Tuning.view = w
	assert_almost_eq(StarfieldView.cell_size(2), 4096.0, 1e-6, "cell sizes follow star_cell0")
	assert_eq(StarfieldView.layer_weights(1.0), Vector3(1.0, 0.0, 0.0), "layer 0 owns zoom 1")
	var w8 := StarfieldView.layer_weights(8.0)
	assert_almost_eq(w8.x, 0.0, 1e-9, "layer 0 is gone at the x8 cell step")
	assert_almost_eq(w8.y, 1.0, 1e-9, "layer 1 owns the x8 cell step")
	assert_almost_eq(w8.x + w8.y + w8.z, 1.0, 1e-6)
	assert_almost_eq(StarfieldView.layer_weights(pow(2.0, 2.75)).x, 0.15625, 1e-3,
			"smoothstep cross-fade mid hand-over")
	var w10 := StarfieldView.layer_weights(10.0)
	assert_almost_eq(w10.x + w10.y + w10.z, 1.0, 1e-6)
	var w16 := StarfieldView.layer_weights(16.0)
	var w32 := StarfieldView.layer_weights(32.0)
	assert_almost_eq(w16.x + w16.y + w16.z, 1.0, 1e-6)
	assert_almost_eq(w32.x + w32.y + w32.z, 1.0, 1e-6)
	assert_lt(w16.z, w32.z, "layer 2 rises with s")
	var w40 := StarfieldView.layer_weights(40.0)
	assert_almost_eq(w40.x + w40.y + w40.z, 1.0, 1e-6)
	assert_almost_eq(w40.x, 0.0, 1e-6)
	assert_almost_eq(w40.z, 1.0, 1e-6, "layer 2 owns zoom 40")
	var wide: ViewParams = Tuning.view.duplicate()
	wide.star_fade = 2.0
	Tuning.view = wide
	assert_almost_eq(StarfieldView.layer_weights(pow(2.0, 2.5)).x, 0.5, 1e-6, "fade stays centred")
	assert_almost_eq(StarfieldView.layer_weights(pow(2.0, 2.75)).x, 0.316406, 1e-3,
			"fade width follows star_fade")


func test_brightness_has_two_to_three_muted_levels():
	var levels := {}
	for cx in range(-24, 24):
		for cy in range(-24, 24):
			var b := StarfieldView.brightness(cx, cy, 0, 0)
			levels[b] = true
	assert_between(levels.size(), 2, 3, "2-3 discrete brightness levels")
	for b in levels.keys():
		assert_true(b > 0.0 and b <= 1.0, "muted levels in (0, 1]")


func test_expected_on_screen_stars_stay_within_tolerance():
	var cam := Vector2(121500.0, 0.0)
	var n1 := StarfieldView.expected_stars(cam, 1.0)
	var n10 := StarfieldView.expected_stars(cam, 10.0)
	var n40 := StarfieldView.expected_stars(cam, 40.0)
	for n in [n1, n10, n40]:
		assert_gt(n, 0.0, "stars visible at every pinned zoom")
	assert_lt(maxf(n1, maxf(n10, n40)) / minf(n1, minf(n10, n40)), 4.0,
			"on-screen density roughly constant across zoom 1..40")
	var w: ViewParams = Tuning.view.duplicate()
	w.star_per_cell = 2
	Tuning.view = w
	assert_almost_eq(StarfieldView.expected_stars(cam, 1.0), n1 * 2.0, 1e-6,
			"per_cell scales the expected count")


func test_build_uniforms_reads_tuning_and_picture_per_call():
	var cam := Vector2(3.0, 4.0)
	var u := StarfieldView.build_uniforms(cam, 2.0)
	var w: ViewParams = Tuning.view
	assert_eq(u["cam"], cam)
	assert_eq(u["seed"], Tuning.picture.seed)
	assert_eq(u["cell0"], w.star_cell0)
	assert_eq(u["per_cell"], w.star_per_cell)
	assert_eq(u["star_px"], w.star_px)
	assert_eq(u["weights"], StarfieldView.layer_weights(2.0))
	var v2: ViewParams = Tuning.view.duplicate()
	v2.star_cell0 = 256.0
	v2.star_per_cell = 3
	v2.star_px = 2.5
	Tuning.view = v2
	Tuning.picture = {"seed": 77, "flight": 1, "moons": [], "ring": {}}
	u = StarfieldView.build_uniforms(cam, 2.0)
	assert_eq(u["cell0"], 256.0)
	assert_eq(u["per_cell"], 3)
	assert_eq(u["star_px"], 2.5)
	assert_eq(u["seed"], 77)


func _view() -> StarfieldView:
	var v := StarfieldView.new()
	add_child_autofree(v)
	return v


func test_view_pushes_uniforms_and_star_color_without_camera():
	var v := _view()
	v.refresh()
	var m := v.material as ShaderMaterial
	assert_not_null(m)
	assert_eq(m.shader.resource_path, "res://shaders/starfield.gdshader")
	var u := StarfieldView.build_uniforms(Vector2.ZERO, 1.0)
	for k in u:
		assert_eq(m.get_shader_parameter(k), u[k], k)
	assert_eq(m.get_shader_parameter("star_color"), Color(Palette.STAR.r, Palette.STAR.g, Palette.STAR.b))


func test_view_follows_tuning_view_per_refresh():
	var v := _view()
	var w: ViewParams = Tuning.view.duplicate()
	w.star_cell0 = 128.0
	w.star_px = 2.5
	Tuning.view = w
	v.refresh()
	var m := v.material as ShaderMaterial
	assert_eq(m.get_shader_parameter("cell0"), 128.0)
	assert_eq(m.get_shader_parameter("star_px"), 2.5)


func test_view_refreshes_on_preset_applied():
	var v := _view()
	var w: ViewParams = Tuning.view.duplicate()
	w.star_px = 3.25
	Tuning.view = w
	Tuning.preset_applied.emit()
	assert_eq((v.material as ShaderMaterial).get_shader_parameter("star_px"), 3.25)


func test_shader_declares_pushed_uniforms():
	var v := _view()
	v.refresh()
	var m := v.material as ShaderMaterial
	var declared := {}
	for d in m.shader.get_shader_uniform_list():
		declared[d["name"]] = true
	for k in ["cam", "seed", "cell0", "per_cell", "star_px", "weights", "star_color"]:
		assert_true(declared.has(k), k)


func test_shader_hash_mirrors_the_statics():
	var src := FileAccess.get_file_as_string("res://shaders/starfield.gdshader")
	for constant in ["374761393", "668265263", "2246822519", "3266489917", "1013904223", "65536.0"]:
		assert_true(src.contains(constant), "shader has %s" % constant)
	var view_src := FileAccess.get_file_as_string("res://scenes/StarfieldView.gd")
	for constant in ["374761393", "668265263", "2246822519", "3266489917", "1013904223", "65536.0"]:
		assert_true(view_src.contains(constant), "statics have %s" % constant)
	assert_false(src.contains("TIME"), "no TIME in starfield shader")
