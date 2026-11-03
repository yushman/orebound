extends GutTest

const ViewScript := preload("res://scenes/SmallObjectView.gd")


func _body(pos: Vector2, type: StringName) -> FreeBody:
	var b := FreeBody.new()
	b.pos = pos
	b.type = type
	b.points = PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(0, 2)])
	return b


func _visible(v) -> Array:
	return v.shown


func test_view_draws_one_polygon_per_body_in_composition_colour():
	var v = add_child_autofree(ViewScript.new())
	var bodies: Array[FreeBody] = [_body(Vector2(10, 20), &"ice"), _body(Vector2(-5, 7), &"ore_rare")]
	v.refresh(bodies)
	var polys := _visible(v)
	assert_eq(polys.size(), 2)
	for i in 2:
		assert_eq(polys[i].points, bodies[i].points)
		assert_eq(polys[i].pos, bodies[i].pos)
		assert_eq(polys[i].color, AsteroidView.color_of(bodies[i].type))
	bodies[0].pos = Vector2(11, 21)
	v.refresh(bodies)
	assert_eq(_visible(v)[0].pos, Vector2(11, 21))


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


func _piece(radius0: float, id: int) -> FreeBody:
	var rng := RandomNumberGenerator.new()
	rng.seed = id
	var b := _body(Vector2(id * 100, 0), &"ore_rare")
	b.points = AsteroidField._hull(rng, radius0)
	b.radius = radius0
	b.radius0 = radius0
	b.piece = true
	b.id = id
	return b


func test_large_pieces_get_the_ore_look_small_pieces_and_containers_do_not():
	var v = add_child_autofree(ViewScript.new())
	var cr: float = Tuning.planet.collect_radius
	var large := _piece(cr * 2.0, 1)
	var small := _piece(cr * 0.5, 2)
	var box := _body(Vector2(5, 5), &"ice")
	box.container = true
	box.radius = cr * 2.0
	box.radius0 = cr * 2.0
	box.id = 3
	box.points = PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)])
	var bodies: Array[FreeBody] = [large, small, box]
	v.refresh(bodies)
	v.layer.sync(v)
	v.place()
	assert_eq(v._pool[0].material_override, v.layer.asteroid)
	assert_eq(v._pool[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3, 2 * large.points.size() + 4 * Style.DOME_INNER_POINTS)
	assert_true(v._twins[0].visible)
	assert_eq(v._twins[0].mesh, v._pool[0].mesh)
	assert_eq(v._twins[0].layers, Layer3D.TYPE_LAYER)
	assert_eq(v._twins[0].transform, v._pool[0].transform)
	assert_eq(v._pool[1].material_override, v.layer.piece)
	assert_eq(v._pool[1].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3, 6 * small.points.size())
	assert_false(v._twins[1].visible)
	assert_eq(v._pool[2].material_override, v.layer.solid)
	assert_false(v._twins[2].visible)
	# large is fixed at birth: a shrunk large piece keeps the look
	large.radius = cr * 0.5
	v.place()
	assert_eq(v._pool[0].material_override, v.layer.asteroid)

