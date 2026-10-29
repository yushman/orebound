extends GutTest

var _saved_field
var _saved_seed := 0
var _saved_flight := 0


func before_each():
	_saved_field = Tuning.field
	_saved_seed = Telemetry.seed
	_saved_flight = Telemetry.flight
	_set_field(_saved_field.duplicate(true))


func after_each():
	_set_field(_saved_field)
	Telemetry.seed = _saved_seed
	Telemetry.flight = _saved_flight


func _three_body_field() -> FieldParams:
	var f := FieldParams.new()
	f.k = 1000.0
	f.carrier_orbit_radius = 500.0
	var planet := BodyParams.new()
	planet.mass = 1000.0
	planet.p = 1.0
	var bodies: Array[BodyParams] = [planet]
	for spec in [[250.0, 0.6, 0.0], [400.0, -0.4, PI]]:
		var m := BodyParams.new()
		m.mass = 100.0
		m.p = 2.0
		m.influence_radius = 80.0
		m.parent = 0
		m.orbit_radius = spec[0]
		m.angular_speed = spec[1]
		m.phase = spec[2]
		bodies.append(m)
	f.bodies = bodies
	return f


func _run():
	var run = load("res://scenes/Run.tscn").instantiate()
	add_child_autofree(run)
	return run


func test_camera_is_run_level_flight_camera():
	var run = _run()
	var cams: Array = run.find_children("*", "Camera2D", true, false)
	assert_eq(cams.size(), 1, "exactly one Camera2D in the scene")
	var cam = cams[0]
	assert_eq(cam.get_parent(), run, "camera sits at Run level")
	assert_eq(str(cam.name), "FlightCamera")
	assert_eq(cam.script.resource_path, "res://scenes/FlightCamera.gd")
	var ship = run.get_node("Ship")
	assert_eq(ship.find_children("*", "Camera2D", true, false).size(), 0,
			"Ship has no camera child")


func test_camera_follows_ship_local_vertical():
	var run = _run()
	var ship = run.get_node("Ship")
	var cam = run.get_node_or_null("FlightCamera")
	assert_not_null(cam)
	if cam == null:
		return
	ship.position = Vector2(100.0, 0.0)
	cam._process(0.0)
	assert_eq(cam.position, Vector2(100.0, 0.0))
	assert_almost_eq(cam.rotation, PI / 2.0, 1e-4)
	ship.position = Vector2(0.0, -50.0)
	cam._process(0.0)
	assert_eq(cam.position, Vector2(0.0, -50.0))
	assert_almost_eq(cam.rotation, 0.0, 1e-4)


func test_camera_applies_rotation():
	var run = _run()
	var cam = run.get_node("FlightCamera")
	assert_false(cam.ignore_rotation, "Camera2D must not ignore its rotation")


func test_zoom_vector_maps_semantic_zoom_to_camera_zoom():
	var FlightCameraScript = load("res://scenes/FlightCamera.gd")
	assert_eq(FlightCameraScript.zoom_vector(1.0), Vector2.ONE)
	assert_eq(FlightCameraScript.zoom_vector(2.0), Vector2(0.5, 0.5))
	var z40: Vector2 = FlightCameraScript.zoom_vector(40.0)
	assert_almost_eq(z40.x, 0.025, 1e-9)
	assert_almost_eq(z40.y, 0.025, 1e-9)


func test_zoom_out_grows_visible_world_rect():
	var run = _run()
	var cam = run.get_node("FlightCamera")
	var vp: Viewport = run.get_viewport()
	var base_width: float = vp.get_visible_rect().size.x / cam.zoom.x
	cam._target_zoom = 2.0
	cam._process(1.0)
	cam._process(1.0)
	var zoomed_width: float = vp.get_visible_rect().size.x / cam.zoom.x
	assert_almost_eq(zoomed_width, 2.0 * base_width, base_width * 0.01,
			"semantic s=2 must show ~2x more world width")


func test_ship_visual_keeps_world_size_at_any_zoom():
	var run = _run()
	var ship = run.get_node("Ship")
	var cam = run.get_node("FlightCamera")
	var visual: Node2D = ship.get_node("Visual")
	assert_false("_ship_icon" in cam, "the camera no longer scales the ship look")
	assert_eq(visual.scale, Vector2.ONE)
	cam._target_zoom = 8.0
	cam._process(1.0)
	cam._process(1.0)
	assert_almost_eq(1.0 / cam.zoom.x, 8.0, 0.01,
			"cam.zoom follows the eased semantic zoom")
	assert_eq(visual.scale, Vector2.ONE,
			"the ship look keeps its honest world size")
	cam._target_zoom = 1.5
	cam._process(1.0)
	cam._process(1.0)
	assert_almost_eq(1.0 / cam.zoom.x, 1.5, 0.01)
	assert_eq(visual.scale, Vector2.ONE)
	# view-only: the body and its collision shape are never scaled
	assert_eq(ship.scale, Vector2.ONE)
	assert_eq(ship.get_node("CollisionShape2D").scale, Vector2.ONE)


func test_camera_zoom_out_input_increases_semantic_zoom():
	var run = _run()
	var cam = run.get_node("FlightCamera")
	cam._target_zoom = 4.0
	Input.action_press("camera_zoom_out")
	cam._process(0.0)
	Input.action_release("camera_zoom_out")
	assert_almost_eq(cam._target_zoom, 4.0 * cam.ZOOM_STEP, 0.001,
			"camera_zoom_out increases s (more world per screen)")


func test_run_scene_is_main_scene_with_ship():
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/Run.tscn")
	var run = _run()
	assert_true(run is Node2D)
	var ship = run.get_node_or_null("Ship")
	assert_not_null(ship, "has Ship")
	assert_true(ship is CharacterBody2D)
	assert_null(ship.get_node_or_null("Polygon2D"), "no bare Polygon2D child")
	var visual = ship.get_node_or_null("Visual")
	assert_true(visual is Node2D)
	var hull: Array = visual.find_children("*", "Polygon2D", false, false).filter(
			func(n): return not (n.name == &"Flame" or n.name == &"Glow"))
	assert_between(hull.size(), 3, 4)
	var cs = ship.find_children("*", "CollisionShape2D", false, false)
	assert_eq(cs.size(), 1)
	assert_true(cs[0].shape is CircleShape2D)


func test_run_start_regenerates_moons_with_telemetry_seed():
	Telemetry.seed = 7
	Telemetry.flight = 1
	var expected := WellGenerator.picture(7, 1)
	_run()
	var bodies: Array = Tuning.field.bodies
	assert_eq(bodies.size(), 1 + expected["moons"].size())
	for i in expected["moons"].size():
		assert_eq(bodies[i + 1].orbit_radius, expected["moons"][i].orbit_radius)
		assert_eq(bodies[i + 1].radius, expected["moons"][i].radius)
	assert_eq(Telemetry.seed, expected["seed"])


func test_run_has_planet_and_three_moon_bodies():
	var run = _run()
	var indices := []
	for c in run.get_children():
		if c.scene_file_path == "res://scenes/Body.tscn":
			indices.append(c.index)
	indices.sort()
	assert_eq(indices, [0, 1, 2, 3])


func test_body_nodes_follow_preset_and_hide_without_body():
	var run = _run()
	_set_field(_three_body_field())
	var t := GravityField.time()
	for c in run.get_children():
		if c.scene_file_path != "res://scenes/Body.tscn":
			continue
		c._physics_process(0.0)
		assert_eq(c.visible, c.index < 3, "body %d visible" % c.index)
		if c.visible:
			assert_eq(c.position, GravityField.body_pos(c.index, t))
	_set_field(_three_body_field())
	var field_two: FieldParams = Tuning.field
	field_two.bodies = [field_two.bodies[0], field_two.bodies[1]]
	for c in run.get_children():
		if c.scene_file_path == "res://scenes/Body.tscn":
			c._physics_process(0.0)
			assert_eq(c.visible, c.index < 2, "body %d" % c.index)


func test_run_has_reference_marker_on_reference_body():
	# Needs its own 3-body field: the marker tracks bodies[1] (a moon).
	var run = _run()
	_set_field(_three_body_field())
	var marker = run.get_node_or_null("ReferenceMarker")
	assert_not_null(marker, "has ReferenceMarker")
	assert_true(marker is Node2D)
	var ship = run.get_node("Ship")
	var t := GravityField.time()
	ship.state.pos = GravityField.body_pos(1, t) + Vector2(3.0, 0.0)
	marker._physics_process(0.0)
	var ref := ShipFlight.reference_body(ship.state.pos, t)
	assert_eq(ref, 1, "moon dominates near it")
	assert_ne(GravityField.body_pos(ref, t), Vector2.ZERO)
	assert_eq(marker.position, GravityField.body_pos(ref, t))


func test_marker_tracks_sync_reference_body_or_carrier():
	# Маркер стоит на ориентире синхронизации: у луны — луна, у матки — точка
	# матки, вне sync_radius — доминантное тело; яркость — чистым хелпером.
	var run = _run()
	_set_field(_three_body_field())
	var marker = run.get_node("ReferenceMarker")
	var ship = run.get_node("Ship")
	var t := GravityField.time()

	# 1) рядом с луной 1 — маркер на её body_pos
	ship.state.pos = GravityField.body_pos(1, t) + Vector2(3.0, 0.0)
	marker._physics_process(0.0)
	var near_moon: Dictionary = ShipFlight.sync_reference(ship.state.pos, t)
	assert_true(near_moon["valid"] and not near_moon["is_carrier"],
			"moon is the sync reference")
	assert_eq(int(near_moon["index"]), 1)
	assert_eq(marker.position, GravityField.body_pos(1, t))

	# 2) рядом с маткой — маркер на точке матки
	ship.state.pos = Vector2(Tuning.field.carrier_orbit_radius + 3.0, 0.0)
	marker._physics_process(0.0)
	var near_carrier: Dictionary = ShipFlight.sync_reference(ship.state.pos, t)
	assert_true(near_carrier["valid"] and near_carrier["is_carrier"],
			"carrier is the sync reference")
	assert_eq(marker.position,
			Vector2(Tuning.field.carrier_orbit_radius, 0.0))

	# 3) beyond sync_radius there is no reference: the ring is hidden
	ship.state.pos = Vector2(5000.0, 0.0)
	marker._physics_process(0.0)
	var far: Dictionary = ShipFlight.sync_reference(ship.state.pos, t)
	assert_false(far["valid"], "no sync reference beyond sync_radius")
	assert_false(marker.visible, "no ring without a sync reference")
	ship.state.pos = Vector2(Tuning.field.carrier_orbit_radius + 3.0, 0.0)
	marker._physics_process(0.0)
	assert_true(marker.visible)

	# яркое кольцо только при drift_sync (чистый хелпер альфы)
	assert_eq(marker.alpha_for(true), 1.0)
	assert_eq(marker.alpha_for(false), 0.35)


func test_marker_screen_radius_constant():
	# Радиус кольца маркера — постоянный ЭКРАННЫЙ размер: мир = 28 px · s.
	var run = _run()
	var marker = run.get_node_or_null("ReferenceMarker")
	assert_not_null(marker, "has ReferenceMarker")
	if marker == null:
		return
	assert_eq(marker.screen_radius(1.0), 28.0)
	assert_almost_eq(marker.screen_radius(22.0), 28.0 * 22.0, 1e-9)


func test_run_has_hidden_tuning_panel_on_canvas_layer():
	var run = _run()
	var layers: Array = run.find_children("*", "CanvasLayer", false, false)
	assert_eq(layers.size(), 1, "has CanvasLayer")
	var panel = layers[0].get_node_or_null("TuningPanel")
	assert_not_null(panel, "layer holds TuningPanel")
	assert_eq(panel.scene_file_path, "res://ui/TuningPanel.tscn")
	assert_false(panel.visible)


func test_flight_vector_points_along_velocity():
	var FlightVectorScript = load("res://scenes/FlightVector.gd")
	assert_eq(FlightVectorScript.vector_dir(Vector2(3.0, 0.0)),
			Vector2(1.0, 0.0), "direction from velocity ONLY")
	assert_eq(FlightVectorScript.vector_dir(Vector2(0.0, -2.0)),
			Vector2(0.0, -1.0))
	var d: Vector2 = FlightVectorScript.vector_dir(Vector2(3.0, 4.0))
	assert_almost_eq(d.x, 0.6, 1e-6)
	assert_almost_eq(d.y, 0.8, 1e-6)


func test_flight_vector_hidden_below_threshold():
	var FlightVectorScript = load("res://scenes/FlightVector.gd")
	assert_true(FlightVectorScript.vector_visible(Vector2(1.0, 0.0)),
			"|v| = 1.0 is visible")
	assert_true(FlightVectorScript.vector_visible(Vector2(0.0, -1.0)))
	assert_false(FlightVectorScript.vector_visible(Vector2(0.99, 0.0)),
			"|v| < 1.0 is hidden")
	assert_false(FlightVectorScript.vector_visible(Vector2.ZERO))


func test_crosshair_alpha_complements_ship_fade():
	# The crosshair is the other half of the cross-fade: 1 - ship_alpha,
	# full at 9 px (ship hidden), half at the 12 px threshold, off at 15 px.
	var FlightVectorScript = load("res://scenes/FlightVector.gd")
	var thr := 12.0
	var w := 6.0
	for px in [9.0, 12.0, 15.0]:
		assert_almost_eq(FlightVectorScript.crosshair_alpha(px, thr, w)
				+ ShipView.ship_alpha(px, thr, w), 1.0, 1e-6,
				"alphas sum to 1 at %s px" % px)
	assert_eq(FlightVectorScript.crosshair_alpha(9.0, thr, w), 1.0)
	assert_almost_eq(FlightVectorScript.crosshair_alpha(12.0, thr, w), 0.5, 1e-6)
	assert_eq(FlightVectorScript.crosshair_alpha(15.0, thr, w), 0.0)


func test_crosshair_ticks_screen_axis_aligned():
	# Tick directions live in the camera frame: rotated back by
	# FlightCamera.rotation_for(pos) they give the screen axes.
	var FlightVectorScript = load("res://scenes/FlightVector.gd")
	var axes := [Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN]
	for pos in [Vector2(100.0, 0.0), Vector2(0.0, -70.0), Vector2(-300.0, 40.0), Vector2(5000.0, -8000.0)]:
		var rot: float = FlightCamera.rotation_for(pos)
		var dirs: PackedVector2Array = FlightVectorScript.tick_dirs(pos)
		assert_eq(dirs.size(), 4, "four tick directions")
		for dir in dirs:
			var back: Vector2 = dir.rotated(-rot)
			var hits := axes.filter(func(a): return a.distance_squared_to(back) < 1e-9)
			assert_eq(hits.size(), 1, "tick dir rotated back is a screen axis")


func test_crosshair_geometry_and_no_speed_gate():
	# Ticks 4..9 SCREEN px out (world = px * s), screen-axis-aligned, four of
	# them whenever the ship is faded — velocity is not an input (v = 0 ok).
	# The nose needle runs 3..7 px along the world nose (directional info).
	var FlightVectorScript = load("res://scenes/FlightVector.gd")
	var pos := Vector2(1200.0, 500.0)
	var s := 2.0
	var rot: float = FlightCamera.rotation_for(pos)
	var ticks: Array = FlightVectorScript.crosshair_ticks(pos, 9.0, 12.0, 6.0, s)
	assert_eq(ticks.size(), 4, "faded ship: four ticks (no speed gate)")
	for tick in ticks:
		# float32 at a 1200-unit offset: ~1e-5 world error, invisible on screen.
		assert_almost_eq(pos.distance_to(tick[0]), 4.0 * s, 1e-4,
				"tick starts at the 4 px gap")
		assert_almost_eq(pos.distance_to(tick[1]), 9.0 * s, 1e-4,
				"tick ends at the 9 px radius")
		var back: Vector2 = (tick[1] - tick[0]).normalized().rotated(-rot)
		var on_axis := false
		for axis in [Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN]:
			on_axis = on_axis or axis.distance_squared_to(back) < 1e-9
		assert_true(on_axis, "tick is screen-axis-aligned")
	assert_eq(FlightVectorScript.crosshair_ticks(pos, 15.0, 12.0, 6.0, s).size(), 0,
			"visible ship: no ticks (alpha 0)")
	# Nose needle: 8..14 px along the world nose Vector2.UP.rotated(rot) —
	# directional info, not counter-rotated, so rot 0 is screen-up when the
	# camera rotation is 0. 8 px slightly overlaps the 9 px tick ring, the
	# rest sticks out past the crosshair; palette red, own 3 px stroke.
	var needle: PackedVector2Array = FlightVectorScript.nose_needle(pos, 0.0, s)
	assert_almost_eq(pos.distance_to(needle[0]), 8.0 * s, 1e-4, "needle starts at 8 px")
	assert_almost_eq(pos.distance_to(needle[1]), 14.0 * s, 1e-4, "needle ends at 14 px")
	assert_almost_eq((needle[1] - needle[0]).normalized().dot(Vector2.UP), 1.0, 1e-6,
			"rot 0 needle is screen-up at camera rotation 0")
	var nrot := 0.7
	var turned: PackedVector2Array = FlightVectorScript.nose_needle(pos, nrot, s)
	var ndir: Vector2 = (turned[1] - turned[0]).normalized()
	assert_almost_eq(ndir.x, sin(nrot), 1e-4, "needle turns with the world nose")
	assert_almost_eq(ndir.y, -cos(nrot), 1e-4)
	assert_almost_eq(pos.distance_to(turned[0]), 8.0 * s, 1e-4)
	assert_almost_eq(pos.distance_to(turned[1]), 14.0 * s, 1e-4)
	assert_eq(FlightVectorScript.NEEDLE_COLOR, Palette.DANGER, "needle is the palette red")
	assert_eq(FlightVectorScript.NEEDLE_STROKE_PX, 3.0, "needle stroke is 3 px")
	assert_gt(FlightVectorScript.NEEDLE_STROKE_PX, FlightVectorScript.STROKE_PX,
			"needle stroke thicker than the ticks")
	assert_eq(FlightVectorScript.CROSSHAIR_COLOR, Palette.SAFE)


func test_chevron_sits_at_fixed_screen_distance_along_velocity():
	# Chevron tip: a fixed 30 SCREEN px along v-hat, |v| moves nothing; the
	# 25 px back edge clears the 9 px crosshair. Label: 24 px beyond the tip
	# along v-hat, centred on the anchor.
	var FlightVectorScript = load("res://scenes/FlightVector.gd")
	var pos := Vector2(10.0, -2.0)
	var s := 4.0
	assert_eq(FlightVectorScript.chevron_pos(pos, Vector2(0.0, 80.0), s),
			pos + Vector2(0.0, 30.0 * s), "tip at 30 px * s along v-hat")
	assert_eq(FlightVectorScript.chevron_pos(pos, Vector2(0.0, 8.0), s),
			pos + Vector2(0.0, 30.0 * s), "|v| does not move the chevron")
	var tip: Vector2 = FlightVectorScript.chevron_pos(pos, Vector2(3.0, 4.0), 1.0)
	assert_almost_eq(tip.x, pos.x + 0.6 * 30.0, 1e-5)
	assert_almost_eq(tip.y, pos.y + 0.8 * 30.0, 1e-5)
	# Both lines meet at the tip; the back edge is 20 px out, 12 px across.
	var lines: Array = FlightVectorScript.chevron_lines(pos, Vector2(0.0, 80.0), 1.0)
	assert_eq(lines.size(), 2, "two chevron lines, no shaft")
	for seg in lines:
		assert_almost_eq(seg[1].distance_to(pos), 30.0, 1e-6, "lines meet at the tip")
		var rel: Vector2 = seg[0] - pos
		assert_almost_eq(rel.dot(Vector2(0.0, 1.0)), 25.0, 1e-6,
				"back edge 25 px out — clears the 9 px crosshair")
		assert_almost_eq(absf(rel.dot(Vector2(1.0, 0.0))), 6.0, 1e-6,
				"back vertex +-6 px off")
	assert_almost_eq(lines[0][0].distance_to(lines[1][0]), 12.0, 1e-6,
			"chevron 12 px across the back")
	assert_gt(FlightVectorScript.CHEVRON_BACK_PX, FlightVectorScript.TICK_OUT_PX,
			"back edge clears the crosshair outer radius")
	# Label anchor: 24 px beyond the tip along v-hat — strictly past the arms
	# for any direction (30 + 24 = 54 px * s from the ship).
	for d in [Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(-1.0, 1.0), Vector2(-3.0, -4.0)]:
		var anchor: Vector2 = FlightVectorScript.label_pos(pos, d, 1.0)
		assert_almost_eq(anchor.distance_to(pos), 54.0, 1e-4,
				"label 54 px * s from the ship, any direction")
		assert_almost_eq((anchor - pos).normalized().dot(d.normalized()), 1.0, 1e-6,
				"anchor is along v-hat — beyond the tip, no overlap")
	# The offset is v-hat * 24 * s and does not depend on |v|.
	var label_off: Vector2 = FlightVectorScript.label_pos(pos, Vector2(3.0, 4.0), 2.0) \
			- FlightVectorScript.chevron_pos(pos, Vector2(3.0, 4.0), 2.0)
	# float32 at a ~100-unit offset: ~1e-5 error.
	assert_almost_eq(label_off.x, 0.6 * 24.0 * 2.0, 1e-4, "label offset is v-hat * 24")
	assert_almost_eq(label_off.y, 0.8 * 24.0 * 2.0, 1e-4)
	assert_almost_eq(FlightVectorScript.label_pos(pos, Vector2(3.0, 4.0) * 20.0, 2.0)
			.distance_to(FlightVectorScript.label_pos(pos, Vector2(3.0, 4.0), 2.0)), 0.0, 1e-6,
			"|v| does not move the label")
	# The text is centred on the anchor vertically too: the baseline sits
	# (ascent - descent) / 2 below it (both sides use the same font metrics).
	var f := ThemeDB.fallback_font
	assert_almost_eq(FlightVectorScript.label_baseline_off(f, FlightVectorScript.LABEL_FONT_PX),
			(f.get_ascent(FlightVectorScript.LABEL_FONT_PX)
					- f.get_descent(FlightVectorScript.LABEL_FONT_PX)) / 2.0, 1e-9,
			"baseline offset centres the glyphs on the anchor")
	# `in` does not see statics, so the removal goes through the method list.
	var methods := []
	for m in FlightVectorScript.get_script_method_list():
		methods.append(m.name)
	assert_false("vector_len" in methods, "shaft math is gone")
	assert_false("shaft_end" in methods, "shaft end is gone")
	assert_eq(FlightVectorScript.COLOR, Color(Palette.HALO, 0.85))
	assert_eq(FlightVectorScript.chevron_label(Vector2(3.0, 4.0)), 5)
	assert_eq(FlightVectorScript.chevron_label(Vector2(0.0, 80.6)), 81)
	assert_eq(FlightVectorScript.chevron_label(Vector2.ZERO), 0)
	assert_eq(FlightVectorScript.screen_px(8.0, 4.0), 32.0,
			"screen sizes still go through screen_px")
	assert_true(FlightVectorScript.vector_visible(Vector2(1.0, 0.0)))
	assert_false(FlightVectorScript.vector_visible(Vector2(0.99, 0.0)),
			"hidden below 1 u/s")


func test_run_scene_contains_flight_vector():
	var run = _run()
	var fv = run.get_node_or_null("FlightVector")
	assert_not_null(fv, "Run scene contains a FlightVector node")
	if fv == null:
		return
	assert_true(fv is Node2D)
	assert_eq(fv.script.resource_path, "res://scenes/FlightVector.gd")


func test_run_has_atmosphere_and_halo_before_well_view():
	var run = _run()
	var names: Array = []
	for c in run.get_children():
		names.append(str(c.name))
	assert_eq(names.slice(0, 3), ["AtmosphereView", "GravityHaloView", "WellView"])
	var atmo = run.get_node_or_null("AtmosphereView")
	if atmo == null:
		return
	assert_eq(atmo.script.resource_path, "res://scenes/AtmosphereView.gd")
	assert_eq(atmo.material.shader.resource_path, "res://shaders/atmosphere.gdshader")
	var halo = run.get_node_or_null("GravityHaloView")
	assert_not_null(halo, "has GravityHaloView")
	if halo == null:
		return
	assert_eq(halo.script.resource_path, "res://scenes/GravityHaloView.gd")
	assert_eq(halo.material.shader.resource_path, "res://shaders/gravity_halo.gdshader")
	await get_tree().process_frame


func test_isoline_layer_is_gone():
	var run = _run()
	assert_null(run.get_node_or_null("IsolineView"))
	assert_false(ResourceLoader.exists("res://scenes/IsolineView.gd"))
	assert_false(ResourceLoader.exists("res://shaders/isolines.gdshader"))


func test_run_has_ring_and_asteroid_views_between_well_view_and_ship():
	var run = _run()
	var names: Array = []
	for c in run.get_children():
		names.append(str(c.name))
	assert_eq(names.slice(0, 13), ["AtmosphereView", "GravityHaloView", "WellView", "RingView", "AsteroidView", "SmallObjectView", "Planet", "Moon1", "Moon2", "Moon3", "BeamView", "CollectorView", "Ship"])
	var ring = run.get_node_or_null("RingView")
	if ring != null:
		assert_eq(ring.script.resource_path, "res://scenes/RingView.gd")
	var ast = run.get_node_or_null("AsteroidView")
	if ast != null:
		assert_eq(ast.script.resource_path, "res://scenes/AsteroidView.gd")


func test_run_has_hud_next_to_tuning_panel_ignoring_mouse():
	var run = _run()
	var layer = run.get_node("CanvasLayer")
	var hud = layer.get_node_or_null("HUD")
	assert_not_null(hud, "layer holds HUD")
	if hud == null:
		return
	assert_eq(hud.scene_file_path, "res://ui/HUD.tscn")
	assert_not_null(layer.get_node_or_null("TuningPanel"))
	assert_eq(hud.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(hud.ship, run.get_node("Ship"), "HUD resolves Run's Ship")


func test_bodies_draw_before_ship():
	var run = _run()
	var ship_index: int = run.get_node("Ship").get_index()
	var after_ast: int = run.get_node("AsteroidView").get_index()
	for n in ["Planet", "Moon1", "Moon2", "Moon3"]:
		var i: int = run.get_node(n).get_index()
		assert_lt(i, ship_index, "%s before Ship" % n)
		assert_gt(i, after_ast, "%s after AsteroidView" % n)


func test_small_object_view_sits_right_after_asteroid_view():
	var run = _run()
	var v = run.get_node_or_null("SmallObjectView")
	assert_not_null(v)
	assert_eq(v.get_index(), run.get_node("AsteroidView").get_index() + 1)
	assert_eq(v.script.resource_path, "res://scenes/SmallObjectView.gd")


func test_beam_view_sits_after_asteroid_view_before_ship():
	var run = _run()
	var b = run.get_node_or_null("BeamView")
	assert_not_null(b)
	assert_gt(b.get_index(), run.get_node("AsteroidView").get_index())
	assert_lt(b.get_index(), run.get_node("Ship").get_index())
	assert_eq(b.script.resource_path, "res://scenes/BeamView.gd")


func test_collector_view_sits_right_after_beam_view():
	var run = _run()
	var v = run.get_node_or_null("CollectorView")
	assert_not_null(v)
	assert_eq(v.get_index(), run.get_node("BeamView").get_index() + 1)
	assert_eq(v.script.resource_path, "res://scenes/CollectorView.gd")


func _set_field(f: FieldParams) -> void:
	Tuning.lock.lock()
	Tuning.field = f
	Tuning.lock.unlock()
