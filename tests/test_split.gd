extends GutTest


func _parent() -> FreeBody:
	var p := FreeBody.new()
	p.pos = Vector2(100.0, 50.0)
	p.vel = Vector2(3.0, -2.0)
	p.points = PackedVector2Array([Vector2(-50, -50), Vector2(50, -50), Vector2(50, 50), Vector2(-50, 50)])
	p.radius = 120.0
	p.type = &"ore_rare"
	p.amount = 1000.0
	p.id = Vector3i(1, 2, 3)
	return p


func test_pieces_of_a_parent_sum_to_its_amount_and_have_radius_r_over_sqrt_n():
	var p := _parent()
	var ps := Split.pieces(p, 4, 5.0, 0.7, 1.0)
	assert_eq(ps.size(), 4)
	var sum := 0.0
	var ids := {}
	for b in ps:
		sum += b.amount
		ids[b.id] = true
		assert_almost_eq(b.radius, 60.0, 0.001)
		assert_almost_eq(b.radius0, b.radius, 1e-9)
		assert_eq(b.type, &"ore_rare")
		assert_true(b.piece)
		assert_eq(b.age, 0.0)
		assert_gt(b.points.size(), 2)
		assert_almost_eq((b.vel - p.vel).length(), 5.0, 0.001)
	assert_almost_eq(sum, 1000.0, 0.0001)
	assert_eq(ids.size(), 4)


func test_same_parent_gives_identical_pieces():
	var a := Split.pieces(_parent(), 4, 5.0, 0.7, 1.0)
	var b := Split.pieces(_parent(), 4, 5.0, 0.7, 1.0)
	for i in 4:
		assert_eq(a[i].pos, b[i].pos)
		assert_eq(a[i].vel, b[i].vel)
		assert_eq(a[i].id, b[i].id)
		assert_eq(a[i].points, b[i].points)


func test_piece_centre_sits_at_spread_times_parent_area_radius():
	var p := _parent()
	var r_eq := sqrt(10000.0 / PI)
	for b in Split.pieces(p, 4, 5.0, 0.7, 1.0):
		assert_almost_eq(b.pos.distance_to(p.pos), 0.7 * r_eq, 0.001)
		assert_almost_eq(b.radius, 60.0, 0.001)


func test_three_pieces_cover_parent_area_over_divisor_and_keep_the_amount():
	var p := _parent()
	var ps := Split.pieces(p, 3, 5.0, 0.7, 1.5)
	assert_eq(ps.size(), 3)
	var sum := 0.0
	for b in ps:
		sum += b.amount
		assert_almost_eq(b.radius, 120.0 * sqrt(1.0 / 4.5), 0.001)
	assert_almost_eq(sum, 1000.0, 0.0001)
