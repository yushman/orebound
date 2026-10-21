extends GutTest


func test_autoloads_present_under_root():
	for n in ["GravityField", "Tuning", "Telemetry"]:
		var node = get_tree().root.get_node_or_null(n)
		assert_not_null(node, "/root/%s exists" % n)
		if node:
			assert_eq(node.get_class(), "Node")
			assert_not_null(node.get_script())
