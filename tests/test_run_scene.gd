extends GutTest


func test_run_scene_has_ship_and_is_main_scene():
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/Run.tscn")
	var scene: PackedScene = load("res://scenes/Run.tscn")
	assert_not_null(scene, "Run.tscn loads")
	var run = scene.instantiate()
	add_child_autofree(run)
	assert_true(run is Node2D)
	assert_eq(run.find_children("*", "Camera2D", false, false).size(), 0, "no Run-level Camera2D")
	var ship = run.get_node_or_null("Ship")
	assert_not_null(ship, "has Ship")
	assert_true(ship is CharacterBody2D)
	var cams = ship.find_children("*", "Camera2D", false, false)
	assert_eq(cams.size(), 1, "camera is a child of ship")
	assert_true(cams[0].ignore_rotation)
	assert_eq(ship.find_children("*", "Polygon2D", false, false).size(), 1)
	var cs = ship.find_children("*", "CollisionShape2D", false, false)
	assert_eq(cs.size(), 1)
	assert_true(cs[0].shape is CircleShape2D)


func test_run_has_planet_and_two_moons():
	var run = load("res://scenes/Run.tscn").instantiate()
	add_child_autofree(run)
	var indices := []
	for c in run.get_children():
		if c.scene_file_path == "res://scenes/Body.tscn":
			indices.append(c.index)
	indices.sort()
	assert_eq(indices, [0, 1, 2])


func test_run_has_reference_marker_on_reference_body():
	var run = load("res://scenes/Run.tscn").instantiate()
	add_child_autofree(run)
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


func test_run_has_hidden_tuning_panel_on_canvas_layer():
	var run = load("res://scenes/Run.tscn").instantiate()
	add_child_autofree(run)
	var layers: Array = run.find_children("*", "CanvasLayer", false, false)
	assert_eq(layers.size(), 1, "has CanvasLayer")
	var panel = layers[0].get_node_or_null("TuningPanel")
	assert_not_null(panel, "layer holds TuningPanel")
	assert_eq(panel.scene_file_path, "res://ui/TuningPanel.tscn")
	assert_false(panel.visible)
