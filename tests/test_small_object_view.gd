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


func test_large_piece_targeted_by_the_beam_gets_the_crack_material_and_shakes():
	var v = add_child_autofree(ViewScript.new())
	var cr: float = Tuning.planet.collect_radius
	var hit_one := _piece(cr * 2.0, 1)
	var other := _piece(cr * 2.0, 2)
	var bodies: Array[FreeBody] = [hit_one, other]
	v.refresh(bodies)
	var hit := hit_one.pos + Vector2(0.0, cr)
	v.shake_phase = 1.0
	v.set_target(hit_one.id, 0.5, hit)
	v.layer.sync(v)
	v.place()
	var m: ShaderMaterial = v.layer.target
	assert_eq(v._pool[0].material_override, m)
	assert_almost_eq(m.get_shader_parameter("crack_ratio"), 0.5, 1e-6)
	var base: Transform3D = v.transform_of(hit_one, v.mesh_of(hit_one)[1])
	var local: Vector3 = base.affine_inverse() * v.layer.to_3d(hit)
	var origin: Vector2 = m.get_shader_parameter("crack_origin")
	assert_almost_eq(origin.x, local.x, 1e-3)
	assert_almost_eq(origin.y, local.y, 1e-3)
	var s: Vector2 = AsteroidView.shake_offset(0.5, 1.0)
	var d: Vector3 = v._pool[0].transform.origin - base.origin
	assert_almost_eq(d.x, s.x, 1e-3)
	assert_almost_eq(d.y, -s.y, 1e-3)
	assert_eq(v._twins[0].transform, v._pool[0].transform, "the rim twin shakes with the piece")
	assert_eq(v._pool[1].material_override, v.layer.asteroid, "untargeted large piece keeps the asteroid look")
	assert_eq(v._pool[1].transform, v.transform_of(other, v.mesh_of(other)[1]))
	v.set_target(hit_one.id, 0.0, hit)
	v.place()
	assert_eq(v._pool[0].material_override, v.layer.asteroid, "ratio 0 changes nothing")
	assert_eq(v._pool[0].transform, base)


func test_view_reads_the_target_from_the_beam_view():
	var holder: Node2D = add_child_autofree(Node2D.new())
	var beam := BeamView.new()
	beam.name = "BeamView"
	holder.add_child(beam)
	var v = ViewScript.new()
	holder.add_child(v)
	beam.ratio = 0.3
	beam.target_key = 42
	beam.has_hit = true
	beam.end = Vector2(7, 8)
	var phase: float = v.shake_phase
	v._process(0.1)
	assert_eq(v.target_key, 42)
	assert_almost_eq(v.target_ratio, 0.3, 1e-6)
	assert_eq(v.target_hit, Vector2(7, 8))
	assert_almost_eq(v.shake_phase - phase, TAU * lerpf(Style.SHAKE_HZ_MIN, Style.SHAKE_HZ_MAX, 0.3) * 0.1, 1e-4)
