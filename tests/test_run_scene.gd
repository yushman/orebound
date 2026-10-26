extends GutTest

var _saved_field
var _saved_seed := 0
var _saved_flight := 0


func before_each():
	_saved_field = Tuning.field
	_saved_seed = Telemetry.seed
	_saved_flight = Telemetry.flight
	Tuning.field = _saved_field.duplicate(true)


func after_each():
	Tuning.field = _saved_field
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


func test_ship_icon_scales_with_zoom():
	var run = _run()
	var ship = run.get_node("Ship")
	var cam = run.get_node("FlightCamera")
	var poly: Node2D = ship.get_node("Visual")
	assert_eq(poly.scale, Vector2.ONE)
	cam._target_zoom = 8.0
	cam._process(1.0)
	cam._process(1.0)
	assert_almost_eq(poly.scale.x, 1.0 / cam.zoom.x, 1e-6,
			"icon scale equals the camera's current semantic zoom")
	assert_almost_eq(poly.scale.x, 8.0, 0.01)
	assert_almost_eq(poly.scale.y, poly.scale.x, 1e-9)
	# zoom back in — the icon follows the eased s at all times
	cam._target_zoom = 1.5
	cam._process(1.0)
	cam._process(1.0)
	assert_almost_eq(poly.scale.x, 1.0 / cam.zoom.x, 1e-6)
	assert_almost_eq(poly.scale.x, 1.5, 0.01)
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
	Tuning.field = _three_body_field()
	var t := GravityField.time()
	for c in run.get_children():
		if c.scene_file_path != "res://scenes/Body.tscn":
			continue
		c._physics_process(0.0)
		assert_eq(c.visible, c.index < 3, "body %d visible" % c.index)
		if c.visible:
			assert_eq(c.position, GravityField.body_pos(c.index, t))
	Tuning.field = _three_body_field()
	var field_two: FieldParams = Tuning.field
	field_two.bodies = [field_two.bodies[0], field_two.bodies[1]]
	for c in run.get_children():
		if c.scene_file_path == "res://scenes/Body.tscn":
			c._physics_process(0.0)
			assert_eq(c.visible, c.index < 2, "body %d" % c.index)


func test_run_has_reference_marker_on_reference_body():
	# Needs its own 3-body field: the marker tracks bodies[1] (a moon).
	var run = _run()
	Tuning.field = _three_body_field()
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
	Tuning.field = _three_body_field()
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


func test_flight_vector_length_equals_speed():
	# Вал стрелки — |v| в МИРОВЫХ единицах, честный масштаб 1:1
	# (дрейф 80 ед/с -> стрелка длиной 80 ед.).
	var FlightVectorScript = load("res://scenes/FlightVector.gd")
	assert_eq(FlightVectorScript.vector_len(Vector2(0.0, 80.0)), 80.0,
			"shaft length = |v| in world units")
	assert_eq(FlightVectorScript.vector_len(Vector2(-3.0, 0.0)), 3.0)
	assert_eq(FlightVectorScript.vector_len(Vector2(3.0, 4.0)), 5.0)
	assert_eq(FlightVectorScript.vector_len(Vector2.ZERO), 0.0)
	# Геометрия: конец вала = pos + v̂·|v| (== pos + vel).
	assert_eq(FlightVectorScript.shaft_end(Vector2(10.0, -2.0), Vector2(0.0, 80.0)),
			Vector2(10.0, 78.0))
	var tip: Vector2 = FlightVectorScript.shaft_end(Vector2.ZERO, Vector2(3.0, 4.0))
	assert_almost_eq(tip.x, 3.0, 1e-5)
	assert_almost_eq(tip.y, 4.0, 1e-5)
	# Головка и штрих остаются экранного размера: мир = px · s.
	assert_eq(FlightVectorScript.screen_px(8.0, 4.0), 32.0)
	assert_eq(FlightVectorScript.screen_px(2.0, 4.0), 8.0)


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
	assert_eq(names.slice(0, 10), ["AtmosphereView", "GravityHaloView", "WellView", "RingView", "AsteroidView", "Planet", "Moon1", "Moon2", "Moon3", "Ship"])
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
