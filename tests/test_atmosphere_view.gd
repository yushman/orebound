extends GutTest

var _saved_planet


func before_each():
	_saved_planet = Tuning.planet


func after_each():
	Tuning.planet = _saved_planet


func _check_density_matches() -> void:
	var A = load("res://scenes/AtmosphereView.gd")
	var f: FieldParams = Tuning.field
	var u: Dictionary = A.build_uniforms(Vector2(120000.0, 5.0))
	var mid := 0.5 * (f.planet_surface_radius + f.atmosphere_edge)
	for r in [f.planet_surface_radius, mid, 0.9 * f.atmosphere_edge + 0.1 * f.planet_surface_radius, f.atmosphere_edge, f.atmosphere_edge + 500.0]:
		assert_almost_eq(A.density(r, u), ShipFlight.atmosphere_density(Vector2(r, 0.0)), 1e-6, "r=%s" % r)


func test_density_mirror_equals_ship_flight():
	_check_density_matches()
	var A = load("res://scenes/AtmosphereView.gd")
	var f: FieldParams = Tuning.field
	assert_almost_eq(A.density(0.5 * (f.planet_surface_radius + f.atmosphere_edge), A.build_uniforms(Vector2.ZERO)), pow(0.5, Tuning.planet.density_shape), 1e-6)


func test_density_mirror_follows_changed_shape():
	var p: PlanetParams = Tuning.planet.duplicate()
	p.density_shape = Tuning.planet.density_shape + 1.3
	Tuning.planet = p
	_check_density_matches()


func _view() -> Node2D:
	var v: Node2D = load("res://scenes/AtmosphereView.gd").new()
	add_child_autofree(v)
	return v


func test_view_pushes_uniforms_to_material():
	var A = load("res://scenes/AtmosphereView.gd")
	var v := _view()
	v.refresh()
	var m := v.material as ShaderMaterial
	assert_not_null(m)
	assert_eq(m.shader.resource_path, "res://shaders/atmosphere.gdshader")
	var u: Dictionary = A.build_uniforms(Vector2.ZERO)
	for k in u:
		assert_eq(m.get_shader_parameter(k), u[k], k)
	assert_eq(m.get_shader_parameter("GLOW_COLOR"), A.GLOW_COLOR)
	assert_eq(m.get_shader_parameter("ATMO_ALPHA"), A.ATMO_ALPHA)


func test_view_follows_tuning_per_refresh():
	var v := _view()
	var p: PlanetParams = Tuning.planet.duplicate()
	p.density_shape = Tuning.planet.density_shape + 0.7
	Tuning.planet = p
	v.refresh()
	assert_eq((v.material as ShaderMaterial).get_shader_parameter("shape"), p.density_shape)


func test_view_refreshes_on_preset_applied():
	var v := _view()
	var p: PlanetParams = Tuning.planet.duplicate()
	p.density_shape = Tuning.planet.density_shape + 0.7
	Tuning.planet = p
	Tuning.preset_applied.emit()
	assert_eq((v.material as ShaderMaterial).get_shader_parameter("shape"), p.density_shape)


func test_shader_declares_pushed_uniforms():
	var v := _view()
	v.refresh()
	var m := v.material as ShaderMaterial
	var declared := {}
	for d in m.shader.get_shader_uniform_list():
		declared[d["name"]] = true
	for k in ["cam", "surface", "edge", "shape", "GLOW_COLOR", "ATMO_ALPHA"]:
		assert_true(declared.has(k), k)
