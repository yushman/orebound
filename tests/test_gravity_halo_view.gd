extends GutTest

var _saved_field
var _saved_view


func before_each():
	_saved_field = Tuning.field
	_saved_view = Tuning.view


func after_each():
	Tuning.field = _saved_field
	Tuning.view = _saved_view


func _moon_field() -> FieldParams:
	var f := Tuning.load_preset("res://presets/p1.tres").field
	var specs := [[118500.0, 2000.0, 500.0, 0.0], [103500.0, 700.0, 70.0, -0.1]]
	for sp in specs:
		var b := BodyParams.new()
		b.mass = sp[2]
		b.p = 2.0
		b.influence_radius = sp[1]
		b.parent = 0
		b.orbit_radius = sp[0]
		b.angular_speed = 0.003
		b.phase = sp[3]
		f.bodies.append(b)
	return f


func test_build_uniforms_packs_moons_only_padded():
	Tuning.field = _moon_field()
	var f: FieldParams = Tuning.field
	var cam := Vector2(121500.0, 3000.0)
	var t := 2.5
	var u := GravityHaloView.build_uniforms(cam, t)
	var idx: Array[int] = []
	for i in range(1, f.bodies.size()):
		if f.bodies[i].influence_radius > 0.0:
			idx.append(i)
	assert_gt(idx.size(), 0, "preset has moons")
	assert_eq(u["moon_count"], idx.size())
	assert_eq(u["rel"].size(), GravityHaloView.MAX_BODIES)
	assert_eq(u["outer"].size(), GravityHaloView.MAX_BODIES)
	for k in idx.size():
		var i := idx[k]
		assert_eq(u["rel"][k], GravityField.body_pos(i, t) - cam)
		assert_almost_eq(u["outer"][k], f.bodies[i].influence_radius * (1.0 + f.fade_width), 1e-6)
	for k in range(idx.size(), GravityHaloView.MAX_BODIES):
		assert_eq(u["rel"][k], Vector2.ZERO)
		assert_eq(u["outer"][k], 0.0)
	assert_false(u.has("cam"))


func test_build_uniforms_skips_zero_radius_moon_and_reads_field_per_call():
	Tuning.field = _moon_field()
	var f: FieldParams = Tuning.field
	var before: int = GravityHaloView.build_uniforms(Vector2.ZERO, 0.0)["moon_count"]
	f.bodies[1].influence_radius = 0.0
	assert_eq(GravityHaloView.build_uniforms(Vector2.ZERO, 0.0)["moon_count"], before - 1)
	f.bodies[0].influence_radius = 5000.0
	assert_eq(GravityHaloView.build_uniforms(Vector2.ZERO, 0.0)["moon_count"], before - 1, "planet never included")


func _u_of_ring(k: float, time: float) -> float:
	# u where n * ring_phase(u) + time / period == k, found by bisection
	var target: float = k - time / Tuning.view.ring_period
	var lo := 0.0
	var hi := 0.999
	for _i in 60:
		var mid := (lo + hi) * 0.5
		if Tuning.view.ring_count * GravityHaloView.ring_phase(mid) < target:
			lo = mid
		else:
			hi = mid
	return lo


func test_ring_phase_moves_inward_and_faster_near_moon():
	var n: int = Tuning.view.ring_count
	var dt := 0.01
	var k_far := n * GravityHaloView.ring_phase(0.8)
	var k_near := n * GravityHaloView.ring_phase(0.2)
	var f1 := _u_of_ring(k_far, 0.0)
	var f2 := _u_of_ring(k_far, dt)
	var n1 := _u_of_ring(k_near, 0.0)
	var n2 := _u_of_ring(k_near, dt)
	assert_lt(f2, f1, "ring moves inward")
	assert_lt(n2, n1)
	assert_gt(absf(n2 - n1), absf(f2 - f1), "faster near the moon")
	assert_almost_eq(GravityHaloView.ring_phase(0.25), 0.125, 1e-6)
	assert_eq(GravityHaloView.ring_phase(1.0), 0.0)
	assert_eq(GravityHaloView.ring_phase(1.5), 0.0)


func test_halo_alpha_profile_and_reads_view_per_call():
	var saved: float = Tuning.view.halo_alpha
	Tuning.view.halo_alpha = 0.25
	assert_almost_eq(GravityHaloView.halo_alpha(0.0), 0.25, 1e-6)
	assert_almost_eq(GravityHaloView.halo_alpha(0.5), 0.0625, 1e-6)
	assert_eq(GravityHaloView.halo_alpha(1.0), 0.0)
	assert_eq(GravityHaloView.halo_alpha(2.0), 0.0)
	Tuning.view.halo_alpha = 0.5
	assert_almost_eq(GravityHaloView.halo_alpha(0.5), 0.125, 1e-6)
	Tuning.view.halo_alpha = saved


func _view() -> GravityHaloView:
	var v := GravityHaloView.new()
	add_child_autofree(v)
	return v


func test_view_pushes_uniforms_and_view_knobs():
	Tuning.field = _moon_field()
	var v := _view()
	v.refresh()
	var m := v.material as ShaderMaterial
	assert_not_null(m)
	assert_eq(m.shader.resource_path, "res://shaders/gravity_halo.gdshader")
	var u := GravityHaloView.build_uniforms(Vector2.ZERO, GravityField.time())
	for k in u:
		assert_eq(m.get_shader_parameter(k), u[k], k)
	var w: ViewParams = Tuning.view
	assert_eq(m.get_shader_parameter("halo_alpha"), w.halo_alpha)
	assert_eq(m.get_shader_parameter("ring_count"), w.ring_count)
	assert_eq(m.get_shader_parameter("ring_time_phase"), 0.0)
	assert_eq(m.get_shader_parameter("ring_px"), w.ring_px)
	assert_eq(m.get_shader_parameter("ring_alpha"), w.ring_alpha)
	assert_eq(m.get_shader_parameter("halo_color"), Color(Palette.HALO.r, Palette.HALO.g, Palette.HALO.b))


func test_view_follows_tuning_view_per_refresh():
	var v := _view()
	var w: ViewParams = Tuning.view.duplicate()
	w.ring_count = Tuning.view.ring_count + 3
	w.halo_alpha = 0.6
	Tuning.view = w
	v.refresh()
	var m := v.material as ShaderMaterial
	assert_eq(m.get_shader_parameter("ring_count"), w.ring_count)
	assert_eq(m.get_shader_parameter("halo_alpha"), 0.6)


func test_view_refreshes_on_preset_applied():
	var v := _view()
	var w: ViewParams = Tuning.view.duplicate()
	w.ring_px = 3.25
	Tuning.view = w
	Tuning.preset_applied.emit()
	assert_eq((v.material as ShaderMaterial).get_shader_parameter("ring_px"), 3.25)


func test_shader_declares_pushed_uniforms():
	var v := _view()
	v.refresh()
	var m := v.material as ShaderMaterial
	var declared := {}
	for d in m.shader.get_shader_uniform_list():
		declared[d["name"]] = true
	for k in ["moon_count", "rel", "outer", "halo_alpha", "ring_count", "ring_time_phase", "ring_px", "ring_alpha", "halo_color"]:
		assert_true(declared.has(k), k)


func test_advance_phase_wraps_and_survives_period_change():
	assert_almost_eq(GravityHaloView.advance_phase(0.9, 0.5, 2.0), 0.15, 1e-6)
	var p := GravityHaloView.advance_phase(0.5, 0.0, 4.0)
	assert_almost_eq(p, 0.5, 1e-6)
	assert_almost_eq(GravityHaloView.advance_phase(p, 0.0, 1.0), 0.5, 1e-6)
	assert_almost_eq(GravityHaloView.advance_phase(0.0, 3600.0, 2.0), 0.0, 1e-6)
