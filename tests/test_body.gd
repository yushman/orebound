extends GutTest


func test_body_follows_field_position() -> void:
	var body = load("res://scenes/Body.tscn").instantiate()
	body.index = 1
	add_child_autofree(body)
	GravityField.tick = 90
	body._physics_process(0.0)
	var expected := GravityField.body_pos(1, GravityField.time())
	assert_ne(expected, Vector2.ZERO)
	assert_eq(body.position, expected)
	GravityField.tick = 0
