extends GutTest


func test_run_scene_has_ship_and_is_main_scene():
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/Run.tscn")
	var scene: PackedScene = load("res://scenes/Run.tscn")
	assert_not_null(scene, "Run.tscn loads")
	var run = scene.instantiate()
	add_child_autofree(run)
	assert_true(run is Node2D)
	assert_not_null(run.find_children("*", "Camera2D", false, false).front() if run.find_children("*", "Camera2D", false, false).size() > 0 else null, "has Camera2D")
	var ship = run.get_node_or_null("Ship")
	assert_not_null(ship, "has Ship")
	assert_true(ship is CharacterBody2D)
	assert_null(ship.get_script())
	assert_eq(ship.find_children("*", "Polygon2D", false, false).size(), 1)
	var cs = ship.find_children("*", "CollisionShape2D", false, false)
	assert_eq(cs.size(), 1)
	assert_true(cs[0].shape is CircleShape2D)
