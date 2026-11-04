extends GutTest

const BodyScript := preload("res://scenes/Body.gd")
const WellViewScript := preload("res://scenes/WellView.gd")

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


func _planet_with_camera(cam_pos: Vector2, zoom: float) -> Node:
	var f := _field_with_moon()
	f.planet_surface_radius = 100000.0
	Tuning.field = f
	var body = load("res://scenes/Body.tscn").instantiate()
	body.index = 0
	add_child_autofree(body)
	var cam := Camera2D.new()
	add_child_autofree(cam)
	cam.position = cam_pos
	cam.zoom = Vector2(1.0 / zoom, 1.0 / zoom)
	cam.make_current()
	body._physics_process(0.0)
	body._process(0.0)
	return body


func test_planet_visual_is_camera_centred_square_covering_the_view() -> void:
	var cam_pos := Vector2(3000.0, -100150.0)
	for zoom in [1.0, 40.0]:
		var body := _planet_with_camera(cam_pos, zoom)
		var visual: Polygon2D = body.get_node("Visual")
		var mat: ShaderMaterial = visual.material
		assert_eq(mat.shader, preload("res://shaders/planet.gdshader"), "planet shader")
		assert_eq(mat.get_shader_parameter("lit_color"), Palette.OBOD_ACCENT)
		assert_eq(mat.get_shader_parameter("dark_color"), Palette.shade(Palette.OBOD_ACCENT))
		assert_eq(visual.scale, Vector2.ONE, "scale 1 at zoom %s" % zoom)
		var centre: Vector2 = cam_pos - body.position
		var h := WellViewScript.visible_half_extent(1.0 / zoom) * WellViewScript.VIEW_MARGIN
		assert_eq(visual.polygon.size(), 4, "square")
		var lo := Vector2(INF, INF)
		var hi := -lo
		for v in visual.polygon:
			lo = lo.min(v)
			hi = hi.max(v)
		assert_almost_eq((lo + hi) * 0.5, centre, Vector2(0.01, 0.01), "centred on camera at zoom %s" % zoom)
		assert_almost_eq(hi - lo, Vector2(2.0 * h, 2.0 * h), Vector2(0.01, 0.01), "half side at zoom %s" % zoom)
		assert_almost_eq(mat.get_shader_parameter("cam"), centre, Vector2(0.01, 0.01))
		assert_eq(mat.get_shader_parameter("planet_r"), 100000.0)


func test_planet_gets_style_knobs_and_scale_table() -> void:
	var body := _planet_with_camera(Vector2(0.0, -100150.0), 1.0)
	var mat: ShaderMaterial = body.get_node("Visual").material
	assert_eq(mat.get_shader_parameter("detail_count"), 7)
	assert_almost_eq(mat.get_shader_parameter("detail_albedo"), Style.PLANET_DETAIL_ALBEDO, 1e-6)
	assert_almost_eq(mat.get_shader_parameter("lava"), Style.PLANET_LAVA_INTENSITY, 1e-6)
	assert_almost_eq(mat.get_shader_parameter("haze"), Style.PLANET_HAZE_STRENGTH, 1e-6)
	assert_eq(mat.get_shader_parameter("lava_color"), Palette.LAVA)
	assert_eq(mat.get_shader_parameter("haze_color"), Palette.HAZE)
	assert_eq(mat.get_shader_parameter("fade_px"), Style.PLANET_DETAIL_FADE_PX)
	var sizes: PackedFloat32Array = mat.get_shader_parameter("sc_size")
	assert_almost_eq(sizes[0], Style.PLANET_DETAIL_MAX, 1e-3)
	assert_almost_eq(sizes[6], Style.PLANET_DETAIL_MIN * 1.5625, 1e-3)
	assert_almost_eq(sizes[7], Style.PLANET_LAVA_SIZE, 1e-3)
	assert_almost_eq(sizes[8], Style.PLANET_LAVA_SIZE_FINE, 1e-3)
	assert_almost_eq(sizes[9], Style.PLANET_LAVA_SIZE * 3.0, 1e-3)


func test_scale_table_splits_camera_into_cell_base_and_fraction() -> void:
	var cam := Vector2(70710.68, -70710.69)
	var sizes := PackedFloat32Array([20000.0, 312.5, 200.0, 400.0, 7500.0])
	var t := BodyScript.scale_table(cam, sizes)
	var base: PackedVector2Array = t["base"]
	var frac: PackedVector2Array = t["frac"]
	assert_eq(base.size(), sizes.size())
	for i in sizes.size():
		var qx: float = cam.x / sizes[i]
		var qy: float = cam.y / sizes[i]
		assert_almost_eq(base[i].x + frac[i].x, qx, 1e-6, "x, size %s" % sizes[i])
		assert_almost_eq(base[i].y + frac[i].y, qy, 1e-6, "y, size %s" % sizes[i])
		assert_eq(base[i], Vector2(floorf(qx), floorf(qy)))
		assert_true(frac[i].x >= 0.0 and frac[i].x < 1.0 and frac[i].y >= 0.0 and frac[i].y < 1.0, "frac in [0, 1)")


func test_moon_is_grey_disc_with_shaded_dark_side_and_lit_half() -> void:
	var f := _field_with_moon()
	f.bodies[1].radius = 500.0
	Tuning.field = f
	var body = load("res://scenes/Body.tscn").instantiate()
	body.index = 1
	add_child_autofree(body)
	var visual: Polygon2D = body.get_node("Visual")
	assert_eq(visual.material.get_shader_parameter("dark_color"), Palette.shade(Palette.MOON))
	assert_eq(visual.material.get_shader_parameter("lit_color"), Palette.MOON)
	assert_gt(visual.polygon.size(), 8, "disc polygon")
	assert_false("MOON_COLOR" in body.get_script().get_script_constant_map())
	for zoom in [1.0, 8.0, 40.0]:
		_zoom_to(zoom)
		body._process(0.0)
		assert_almost_eq(_extent(visual.polygon) * visual.scale.x, 500.0, 0.01, "zoom %s" % zoom)


func _moon_body(i: int, archetypes: Array, picture_seed := 3) -> Node:
	var f := _field_with_moon()
	f.bodies[1].radius = 500.0
	Tuning.field = f
	Tuning.picture = {"seed": picture_seed, "flight": 1, "moons": [], "ring": {}, "archetypes": archetypes}
	var body = load("res://scenes/Body.tscn").instantiate()
	body.index = i
	add_child_autofree(body)
	body._process(0.0)
	return body


func test_moon_takes_lit_colour_and_crater_density_from_its_picture_archetype() -> void:
	for a in Style.MOON_ARCHETYPES.size():
		var row: Dictionary = Style.MOON_ARCHETYPES[a]
		var mat: ShaderMaterial = _moon_body(1, [a]).get_node("Visual").material
		assert_eq(mat.get_shader_parameter("lit_color"), row["lit"], "lit %d" % a)
		assert_eq(mat.get_shader_parameter("dark_color"), Palette.shade(row["lit"]))
		assert_almost_eq(mat.get_shader_parameter("crater_density"), clampf(Style.MOON_CRATER_DENSITY * row["craters"], 0.0, 1.0), 1e-6)
		assert_almost_eq(mat.get_shader_parameter("maria_coverage"), Style.MOON_MARIA_COVERAGE * row["maria"], 1e-6)
		assert_eq(mat.get_shader_parameter("ray_craters"), row["rays"])
		assert_eq(mat.get_shader_parameter("lineae"), row["lineae"])
		assert_eq(mat.get_shader_parameter("blotch"), row["blotch"])
		assert_eq(mat.get_shader_parameter("blotch_color"), row["alt"])
	assert_eq(Style.MOON_ARCHETYPES[1]["lit"], Palette.MOON_ICE)
	assert_eq(Style.MOON_ARCHETYPES[3]["alt"], Palette.MOON_RUST_ALT)


func test_moon_without_archetypes_falls_back_to_grey() -> void:
	var mat: ShaderMaterial = _moon_body(1, []).get_node("Visual").material
	assert_eq(mat.get_shader_parameter("lit_color"), Palette.MOON)


func test_moon_gets_shared_look_knobs() -> void:
	var mat: ShaderMaterial = _moon_body(1, [0]).get_node("Visual").material
	assert_eq(mat.get_shader_parameter("maria_scale"), Style.MOON_MARIA_SCALE)
	assert_eq(mat.get_shader_parameter("ray_rays"), Style.MOON_RAY_RAYS)
	assert_eq(mat.get_shader_parameter("lineae_px"), Style.MOON_LINEAE_PX)
	assert_eq(mat.get_shader_parameter("blotch_scale"), Style.MOON_BLOTCH_SCALE)


func test_planet_material_has_no_moon_uniforms() -> void:
	var mat: ShaderMaterial = _moon_body(0, [1]).get_node("Visual").material
	for u in ["maria_coverage", "ray_craters", "lineae", "blotch", "spin", "earth_strength", "crater_density"]:
		assert_null(mat.get_shader_parameter(u), u)


func test_moon_spin_angle_follows_game_time_at_seeded_speed() -> void:
	var body := _moon_body(1, [0])
	var mat: ShaderMaterial = body.get_node("Visual").material
	var h := posmod(hash([3, 1, 1, "spin"]), 1000) / 1000.0
	var speed := Style.MOON_SPIN_SPEED * (1.0 + Style.MOON_SPIN_VARIATION * (2.0 * h - 1.0))
	assert_between(speed, Style.MOON_SPIN_SPEED * (1.0 - Style.MOON_SPIN_VARIATION), Style.MOON_SPIN_SPEED * (1.0 + Style.MOON_SPIN_VARIATION))
	GravityField.tick = 600
	body._process(0.0)
	var t := GravityField.time()
	assert_gt(t, 0.0)
	var expected := Basis(Vector3(0.0, -cos(Style.MOON_SPIN_TILT), sin(Style.MOON_SPIN_TILT)).normalized(), speed * t)
	var got: Basis = mat.get_shader_parameter("spin")
	assert_true(got.is_equal_approx(expected), "spin basis %s vs %s" % [got, expected])
	GravityField.tick = 1200
	body._process(0.0)
	var t2 := GravityField.time()
	expected = Basis(Vector3(0.0, -cos(Style.MOON_SPIN_TILT), sin(Style.MOON_SPIN_TILT)).normalized(), speed * t2)
	assert_true((mat.get_shader_parameter("spin") as Basis).is_equal_approx(expected), "follows time")


func test_moon_earthshine_points_to_planet() -> void:
	var body := _moon_body(1, [0])
	var mat: ShaderMaterial = body.get_node("Visual").material
	GravityField.tick = 90
	body._physics_process(0.0)
	body._process(0.0)
	var to_planet: Vector2 = (GravityField.body_pos(0, GravityField.time()) - body.position).normalized()
	var d: Vector3 = mat.get_shader_parameter("planet_dir")
	assert_almost_eq(d.x, to_planet.x, 1e-5)
	assert_almost_eq(d.y, to_planet.y, 1e-5)
	assert_almost_eq(d.z, Style.MOON_EARTHSHINE_ELEVATION, 1e-6)
	assert_eq(mat.get_shader_parameter("earth_strength"), Style.MOON_EARTHSHINE_STRENGTH)
	assert_eq(mat.get_shader_parameter("earth_color"), Palette.OBOD_ACCENT)
	assert_eq(mat.get_shader_parameter("earth_falloff"), Style.MOON_EARTHSHINE_FALLOFF)
