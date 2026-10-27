extends GutTest

var _saved_field


func before_each():
	_saved_field = Tuning.field


func after_each():
	_set_field(_saved_field)


func _planet() -> BodyParams:
	var b := BodyParams.new()
	b.parent = -1
	return b


func _moon(orbit_radius: float) -> BodyParams:
	var b := BodyParams.new()
	b.parent = 0
	b.orbit_radius = orbit_radius
	return b


func _field(bodies: Array, carrier_orbit_radius: float) -> FieldParams:
	var f := FieldParams.new()
	f.carrier_orbit_radius = carrier_orbit_radius
	var arr: Array[BodyParams] = []
	for b in bodies:
		arr.append(b)
	f.bodies = arr
	return f


func test_orbit_radii_from_field():
	var WellViewScript = load("res://scenes/WellView.gd")
	# planet-only field: the carrier orbit is the only r = const arc
	_set_field(_field([_planet()], 121500.0))
	var radii: Array[float] = WellViewScript.orbit_radii()
	assert_eq(radii.size(), 1)
	assert_eq(radii[0], 121500.0)
	# planet + two moons: carrier + moon orbits, sorted; moon with
	# orbit_radius 0 is excluded
	_set_field(_field(
		[_planet(), _moon(130000.0), _moon(90000.0), _moon(0.0)], 121500.0))
	radii = WellViewScript.orbit_radii()
	assert_eq(radii.size(), 3)
	assert_eq(radii[0], 90000.0)
	assert_eq(radii[1], 121500.0)
	assert_eq(radii[2], 130000.0)


func test_highlight_when_zoomed_out():
	var WellViewScript = load("res://scenes/WellView.gd")
	assert_between(WellViewScript.HIGHLIGHT_ZOOM, 21.0, 23.0)
	assert_false(WellViewScript.highlight_orbits(1.0))
	assert_false(WellViewScript.highlight_orbits(WellViewScript.HIGHLIGHT_ZOOM - 0.01))
	assert_true(WellViewScript.highlight_orbits(WellViewScript.HIGHLIGHT_ZOOM))
	assert_true(WellViewScript.highlight_orbits(40.0))


func test_visible_half_extent_divides_by_camera_zoom():
	var WellViewScript = load("res://scenes/WellView.gd")
	var base: float = WellViewScript.visible_half_extent(1.0)
	assert_almost_eq(base, WellViewScript.VIEW_HALF.length(), 1e-4)
	# camera zoom 0.5 == semantic s=2: the span must cover ~2x the world
	assert_almost_eq(WellViewScript.visible_half_extent(0.5), 2.0 * base, 1e-4)


func test_semantic_zoom_inverts_camera_zoom():
	var WellViewScript = load("res://scenes/WellView.gd")
	assert_almost_eq(WellViewScript.semantic_zoom(1.0), 1.0, 1e-9)
	assert_almost_eq(WellViewScript.semantic_zoom(0.5), 2.0, 1e-9)


func test_screen_px_scales_with_semantic_zoom():
	var WellViewScript = load("res://scenes/WellView.gd")
	# stroke targets are SCREEN pixels: world width = px * semantic zoom s
	assert_almost_eq(WellViewScript.screen_px(2.0, 1.0), 2.0, 1e-9)
	assert_almost_eq(WellViewScript.screen_px(2.0, 22.0), 2.0 * 22.0, 1e-9)
	assert_almost_eq(WellViewScript.screen_px(2.0, 40.0), 2.0 * 40.0, 1e-9)
	# degenerate s must not blow the width up
	assert_almost_eq(WellViewScript.screen_px(2.0, 0.0), 2.0, 1e-9)
	assert_almost_eq(WellViewScript.screen_px(2.0, -1.0), 2.0, 1e-9)


func test_carrier_marker_data():
	var WellViewScript = load("res://scenes/WellView.gd")
	# carrier point is the frame origin, read from Tuning on every call
	_set_field(_field([_planet()], 121500.0))
	assert_eq(WellViewScript.carrier_marker_pos(), Vector2(121500.0, 0.0))
	_set_field(_field([_planet()], 50000.0))
	assert_eq(WellViewScript.carrier_marker_pos(), Vector2(50000.0, 0.0))
	# constant screen size, dim marker
	assert_between(WellViewScript.CARRIER_MARKER_PX, 3.0, 5.0)
	assert_almost_eq(WellViewScript.CARRIER_MARKER_COLOR.a, 0.6, 0.05)


func test_run_scene_has_well_view():
	var run = load("res://scenes/Run.tscn").instantiate()
	add_child_autofree(run)
	var wv = run.get_node_or_null("WellView")
	assert_not_null(wv, "Run scene contains a WellView node")
	if wv == null:
		return
	assert_true(wv is Node2D)
	assert_eq(wv.script.resource_path, "res://scenes/WellView.gd")


func test_carrier_orbit_has_own_style():
	var WellViewScript = load("res://scenes/WellView.gd")
	_set_field(_field([_planet()], 121500.0))
	# pinned playtest constants: white ~0.55 alpha, 1.5 px
	assert_almost_eq(WellViewScript.CARRIER_ORBIT_COLOR.a, 0.55, 0.05)
	assert_eq(WellViewScript.CARRIER_ORBIT_PX, 1.5)
	# carrier radius -> carrier style, also when other orbits highlight
	var carrier: Dictionary = WellViewScript.orbit_style(121500.0, false)
	assert_eq(carrier["color"], WellViewScript.CARRIER_ORBIT_COLOR)
	assert_eq(carrier["px"], WellViewScript.CARRIER_ORBIT_PX)
	assert_eq(WellViewScript.orbit_style(121500.0, true), carrier)
	# another radius -> regular, or highlighted when zoomed far out
	var other: Dictionary = WellViewScript.orbit_style(130000.0, false)
	assert_eq(other["color"], WellViewScript.ORBIT_COLOR)
	assert_eq(other["px"], WellViewScript.ORBIT_PX)
	var hi: Dictionary = WellViewScript.orbit_style(130000.0, true)
	assert_eq(hi["color"], WellViewScript.ORBIT_HIGHLIGHT_COLOR)
	assert_eq(hi["px"], WellViewScript.ORBIT_HIGHLIGHT_PX)


func test_boundary_style_distinct_from_orbit_styles():
	var W = load("res://scenes/WellView.gd")
	_set_field(_field([_planet()], 121500.0))
	var atm: Dictionary = W.boundary_style("atmosphere")
	assert_eq(atm["color"], W.ATMOSPHERE_COLOR)
	assert_eq(atm["px"], W.ATMOSPHERE_PX)
	var tow: Dictionary = W.boundary_style("tow")
	var ceil_s: Dictionary = W.boundary_style("ceiling")
	assert_ne(tow["color"], ceil_s["color"])
	var orbits := [W.orbit_style(121500.0, false), W.orbit_style(130000.0, false),
			W.orbit_style(130000.0, true)]
	for st in [atm, tow, ceil_s]:
		for o in orbits:
			assert_ne(st, o)
	for st in [tow, ceil_s]:
		assert_ne(st["color"], atm["color"])


func test_visible_span_covers_view_for_any_radius():
	var WellViewScript = load("res://scenes/WellView.gd")
	var cam_pos := Vector2(121500.0, 0.0)
	var cam_zoom := 1.0 / 40.0
	var h: float = WellViewScript.visible_half_extent(cam_zoom) * WellViewScript.VIEW_MARGIN
	# arcs both inside and outside the camera radius: the span edges must
	# reach the edge of the visible disc (never cut the arc short on screen)
	for r in [100000.0, 118500.0, 121500.0, 130000.0]:
		var span: float = WellViewScript.visible_span(cam_pos, cam_zoom, r)
		assert_gt(span, 0.0)
		assert_lt(span, TAU)
		var edge: Vector2 = Vector2.from_angle(cam_pos.angle() + span * 0.5) * r
		assert_gte(edge.distance_to(cam_pos), h * 0.999, "r=%s edge reaches the view edge" % r)
	# the whole circle is visible when the view reaches around it
	assert_eq(WellViewScript.visible_span(Vector2(10.0, 0.0), 0.001, 100.0), TAU)
	# an arc entirely outside the view has no visible span
	assert_eq(WellViewScript.visible_span(cam_pos, 1.0, 50000.0), 0.0)


func test_well_view_no_longer_fills_tiers():
	var W = load("res://scenes/WellView.gd")
	for m in ["tier_bands", "annulus_points", "band_span", "band_polygons", "_draw_band"]:
		assert_false(W.has_method(m), m)
	assert_false("TIER_COLORS" in W.get_script_constant_map())


func test_special_rings_at_generator_radii():
	var W = load("res://scenes/WellView.gd")
	var t := WellGenerator.tiers()
	var rings: Array = W.special_rings()
	assert_eq(rings.size(), 3)
	if rings.size() != 3:
		return
	var by_kind := {}
	for r in rings:
		by_kind[r["kind"]] = r["radius"]
	assert_eq(by_kind.get("atmosphere"), Tuning.field.atmosphere_edge)
	assert_eq(by_kind.get("tow"), t["tow"])
	assert_eq(by_kind.get("ceiling"), t["ceiling"])


func test_stroke_hues_come_from_palette():
	var W = load("res://scenes/WellView.gd")
	_set_field(_field([_planet()], 121500.0))
	var hues := {
		"carrier": [W.orbit_style(121500.0, false)["color"], Palette.SAFE],
		"orbit": [W.orbit_style(130000.0, false)["color"], Palette.HALO],
		"highlight": [W.orbit_style(130000.0, true)["color"], Palette.HALO],
		"tow": [W.boundary_style("tow")["color"], Palette.SAFE],
		"ceiling": [W.boundary_style("ceiling")["color"], Palette.DANGER],
		"atmosphere": [W.boundary_style("atmosphere")["color"], Palette.DANGER],
		"marker": [W.CARRIER_MARKER_COLOR, Palette.SAFE],
	}
	for k in hues:
		var c: Color = hues[k][0]
		var p: Color = hues[k][1]
		assert_eq(Color(c.r, c.g, c.b), Color(p.r, p.g, p.b), k)
	assert_almost_eq(W.orbit_style(130000.0, false)["color"].a, 0.3, 0.001)
	assert_almost_eq(W.boundary_style("tow")["color"].a, 0.7, 0.001)


func test_surface_arc_removed():
	var W = load("res://scenes/WellView.gd")
	var consts: Dictionary = W.get_script_constant_map()
	assert_false("SURFACE_COLOR" in consts)
	assert_false("SURFACE_PX" in consts)


func _set_field(f: FieldParams) -> void:
	Tuning.lock.lock()
	Tuning.field = f
	Tuning.lock.unlock()
