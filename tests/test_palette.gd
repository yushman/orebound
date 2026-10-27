extends GutTest

func test_constants_are_meaning_bound_values():
	assert_eq(Palette.BACKGROUND, Color("0B0F1A"))
	assert_eq(Palette.ICE, Color("7FC8F8"))
	assert_eq(Palette.ORE, Color("F2A93B"))
	assert_eq(Palette.ORE_BRIGHT, Color("FFE27A"))
	assert_eq(Palette.ORE_BASE, Color("8A7D6B"))
	assert_eq(Palette.ORE_RARE, Color("F8C65A"))
	assert_eq(Palette.DANGER, Color("FF5A36"))
	assert_eq(Palette.HALO, Color("B8D8C0"))
	assert_eq(Palette.SAFE, Color("FFD45C"))
	assert_eq(Palette.OBOD_ACCENT, Color("C9A27A"))

func test_hull_constants():
	assert_eq(Palette.HULL, Color(0.85, 0.88, 0.92))
	assert_eq(Palette.HULL_SHADE, Color(0.6, 0.65, 0.72))

func test_moon_is_neutral_grey():
	assert_eq(Palette.MOON.r, Palette.MOON.g)
	assert_eq(Palette.MOON.g, Palette.MOON.b)

func test_shade_multiplies_rgb_keeping_alpha():
	var c := Color(0.8, 0.4, 0.2, 0.5)
	var s := Palette.shade(c)
	assert_almost_eq(s.r, 0.28, 0.0001)
	assert_almost_eq(s.g, 0.14, 0.0001)
	assert_almost_eq(s.b, 0.07, 0.0001)
	assert_eq(s.a, 0.5)

func test_light_dir_is_unit():
	assert_almost_eq(Palette.LIGHT_DIR.length(), 1.0, 0.0001)

func test_lit_half_has_n_plus_one_points_on_lit_side():
	var r := 10.0
	var n := 16
	var pts := Palette.lit_half(r, n, Palette.LIGHT_DIR)
	assert_eq(pts.size(), n + 1)
	var tangent := Vector2(-Palette.LIGHT_DIR.y, Palette.LIGHT_DIR.x)
	for p in pts:
		assert_gte(p.dot(Palette.LIGHT_DIR), -0.0001)
		assert_almost_eq(p.length(), r, 0.0001)
	assert_almost_eq(pts[0].dot(Palette.LIGHT_DIR), 0.0, 0.0001)
	assert_almost_eq(pts[n].dot(Palette.LIGHT_DIR), 0.0, 0.0001)
	assert_almost_eq(pts[0].dot(tangent), -r, 0.0001)
	assert_almost_eq(pts[n].dot(tangent), r, 0.0001)

func test_lit_half_follows_light_direction():
	var pts := Palette.lit_half(5.0, 8, Vector2.UP)
	for p in pts:
		assert_lte(p.y, 0.0001)

func test_default_clear_color_matches_background():
	var c: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
	assert_eq(c, Palette.BACKGROUND)

func test_fuel_color():
	assert_eq(Palette.FUEL, Color("8FE0A0"))
