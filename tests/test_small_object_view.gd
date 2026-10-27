extends GutTest

const ViewScript := preload("res://scenes/SmallObjectView.gd")


func _body(pos: Vector2, type: StringName) -> FreeBody:
	var b := FreeBody.new()
	b.pos = pos
	b.type = type
	b.points = PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(0, 2)])
	return b


func _visible(v) -> Array:
	var out := []
	for p in v.get_children():
		if p.visible:
			out.append(p)
	return out


func test_view_draws_one_polygon_per_body_in_composition_colour():
	var v = add_child_autofree(ViewScript.new())
	var bodies: Array[FreeBody] = [_body(Vector2(10, 20), &"ice"), _body(Vector2(-5, 7), &"ore_rare")]
	v.refresh(bodies)
	var polys := _visible(v)
	assert_eq(polys.size(), 2)
	for i in 2:
		assert_eq(polys[i].polygon, bodies[i].points)
		assert_eq(polys[i].position, bodies[i].pos)
		assert_eq(polys[i].color, AsteroidView.color_of(bodies[i].type))
	bodies[0].pos = Vector2(11, 21)
	v.refresh(bodies)
	assert_eq(_visible(v)[0].position, Vector2(11, 21))


func test_view_hides_extra_polygons_when_bodies_disappear():
	var v = add_child_autofree(ViewScript.new())
	var bodies: Array[FreeBody] = [_body(Vector2.ZERO, &"ice"), _body(Vector2.ONE, &"ice")]
	v.refresh(bodies)
	bodies.pop_back()
	v.refresh(bodies)
	assert_eq(_visible(v).size(), 1)
	v.refresh([] as Array[FreeBody])
	assert_eq(_visible(v).size(), 0)


func test_view_reads_bodies_from_ship_state():
	var holder := Node2D.new()
	var ship = load("res://scenes/Ship.tscn").instantiate()
	ship.name = "Ship"
	holder.add_child(ship)
	var v = ViewScript.new()
	holder.add_child(v)
	add_child_autofree(holder)
	ship.state.bodies.append(_body(Vector2(3, 4), &"ice"))
	v._process(0.0)
	assert_eq(_visible(v).size(), 1)
