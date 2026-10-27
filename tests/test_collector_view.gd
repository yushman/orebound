extends GutTest


func _inp(collect: bool, aim: float) -> ShipInput:
	var i := ShipInput.new()
	i.collect = collect
	i.aim = aim
	return i


func test_collector_view_draws_the_sector_along_the_aim_while_collect_is_held():
	var v = add_child_autofree(CollectorView.new())
	var s := ShipState.new()
	s.pos = Vector2(1000.0, 500.0)
	var aim := 0.7
	v.refresh(s, _inp(true, aim))
	assert_true(v.visible)
	var r: float = Tuning.ship.beam_range * 0.5
	var half := deg_to_rad(Tuning.ship.collect_angle) * 0.5
	var pts: PackedVector2Array = v.polygon
	assert_gt(pts.size(), 3)
	assert_eq(pts[0], s.pos)
	assert_almost_eq((pts[1] - s.pos).length(), r, 0.01)
	assert_almost_eq((pts[1] - s.pos).angle(), aim - half, 0.001)
	assert_almost_eq((pts[pts.size() - 1] - s.pos).angle(), aim + half, 0.001)


func test_collector_view_is_hidden_when_collect_is_off():
	var v = add_child_autofree(CollectorView.new())
	var s := ShipState.new()
	v.refresh(s, _inp(true, 0.0))
	v.refresh(s, _inp(false, 0.0))
	assert_false(v.visible)


func test_collector_view_uses_palette_colour_and_hides_without_ship():
	var v = add_child_autofree(CollectorView.new())
	assert_eq(Color(v.color, 1.0), Palette.FUEL)
	v.visible = true
	v._process(0.0)
	assert_false(v.visible)
