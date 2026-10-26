extends GutTest

var _saved_field: FieldParams


func before_each() -> void:
	_saved_field = Tuning.field


func after_each() -> void:
	Tuning.field = _saved_field
	GravityField.tick = 0


func _field_with_moon() -> FieldParams:
	var f := FieldParams.new()
	f.k = 1000.0
	f.eps = 1.0
	f.carrier_orbit_radius = 500.0
	var planet := BodyParams.new()
	planet.mass = 1000.0
	planet.p = 1.0
	var moon := BodyParams.new()
	moon.mass = 100000.0
	moon.p = 2.0
	moon.parent = 0
	moon.orbit_radius = 480.0
	moon.angular_speed = 0.1
	var bodies: Array[BodyParams] = [planet, moon]
	f.bodies = bodies
	return f


func test_body_follows_field_position() -> void:
	Tuning.field = _field_with_moon()
	var body = load("res://scenes/Body.tscn").instantiate()
	body.index = 1
	add_child_autofree(body)
	GravityField.tick = 90
	body._physics_process(0.0)
	var t := GravityField.time()
	var expected := GravityField.body_pos(1, t)
	assert_ne(expected, Vector2.ZERO)
	assert_eq(body.position, expected)
	# same point from the orbit formula: phase + (angular_speed - frame_omega)*t
	var a := (0.1 - GravityField.frame_omega()) * t
	assert_eq(body.position, Vector2(cos(a), sin(a)) * 480.0)


func _extent(poly: PackedVector2Array) -> float:
	var e := 0.0
	for v in poly:
		e = maxf(e, v.length())
	return e


func _zoom_to(zoom: float) -> void:
	var cam := Camera2D.new()
	add_child_autofree(cam)
	cam.zoom = Vector2(1.0 / zoom, 1.0 / zoom)
	cam.make_current()


func test_planet_is_disc_of_surface_radius_with_lit_half() -> void:
	var f := _field_with_moon()
	f.planet_surface_radius = 100000.0
	Tuning.field = f
	var body = load("res://scenes/Body.tscn").instantiate()
	body.index = 0
	add_child_autofree(body)
	var visual: Polygon2D = body.get_node("Visual")
	var lit: Polygon2D = body.get_node("Visual/Lit")
	assert_eq(visual.color, Palette.shade(Palette.OBOD_ACCENT))
	assert_eq(lit.color, Palette.OBOD_ACCENT)
	assert_gte(visual.polygon.size(), 256, "smooth edge")
	for zoom in [1.0, 40.0]:
		_zoom_to(zoom)
		body._process(0.0)
		assert_almost_eq(_extent(visual.polygon) * visual.scale.x, 100000.0, 0.1, "zoom %s" % zoom)
	for v in lit.polygon:
		assert_gte(v.dot(Palette.LIGHT_DIR), -0.001, "lit points on the light side")
	assert_false(body.get_script().has_method("visual_scale"), "no constant-size marker")


func test_moon_is_grey_disc_with_shaded_dark_side_and_lit_half() -> void:
	var f := _field_with_moon()
	f.bodies[1].radius = 500.0
	Tuning.field = f
	var body = load("res://scenes/Body.tscn").instantiate()
	body.index = 1
	add_child_autofree(body)
	var visual: Polygon2D = body.get_node("Visual")
	var lit: Polygon2D = body.get_node("Visual/Lit")
	assert_eq(visual.color, Palette.shade(Palette.MOON))
	assert_eq(lit.color, Palette.MOON)
	assert_gt(visual.polygon.size(), 8, "disc polygon")
	assert_false("MOON_COLOR" in body.get_script().get_script_constant_map())
	for zoom in [1.0, 8.0, 40.0]:
		_zoom_to(zoom)
		body._process(0.0)
		assert_almost_eq(_extent(visual.polygon) * visual.scale.x, 500.0, 0.01, "zoom %s" % zoom)
		assert_eq(lit.scale, Vector2.ONE, "lit scales with its parent")


func test_moon_disc_uses_fewer_points_than_the_planet_disc() -> void:
	var f := _field_with_moon()
	f.bodies[1].radius = 500.0
	Tuning.field = f
	var planet = load("res://scenes/Body.tscn").instantiate()
	planet.index = 0
	add_child_autofree(planet)
	var moon = load("res://scenes/Body.tscn").instantiate()
	moon.index = 1
	add_child_autofree(moon)
	var pv: Polygon2D = planet.get_node("Visual")
	var mv: Polygon2D = moon.get_node("Visual")
	assert_lt(mv.polygon.size(), pv.polygon.size(), "moon disc is coarser")
	assert_lt(moon.get_node("Visual/Lit").polygon.size(), planet.get_node("Visual/Lit").polygon.size())
	assert_gte(mv.polygon.size(), 32, "moon still round")
