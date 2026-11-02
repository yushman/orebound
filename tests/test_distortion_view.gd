extends GutTest


func _body(id: int) -> FreeBody:
	var b := FreeBody.new()
	b.id = id
	return b


func test_hit_strength_rises_with_charge_ratio():
	assert_eq(DistortionView.STRENGTH_MIN_PX, DistortionView.STRENGTH_MAX_PX / 2.0)
	assert_eq(DistortionView.hit_strength(0.0), DistortionView.STRENGTH_MAX_PX / 2.0)
	assert_eq(DistortionView.hit_strength(1.0), DistortionView.STRENGTH_MAX_PX)
	assert_gt(DistortionView.hit_strength(0.7), DistortionView.hit_strength(0.3))


func test_broke_asteroid_key_only_once_in_broken():
	var s := ShipState.new()
	var key := Vector3i(1, 2, 3)
	assert_false(DistortionView.broke(key, 0.9, s))
	s.broken[key] = true
	assert_true(DistortionView.broke(key, 0.0, s))
	assert_false(DistortionView.broke(null, 1.0, s))


func test_broke_body_needs_vanish_and_high_ratio():
	var s := ShipState.new()
	s.bodies.append(_body(5))
	assert_false(DistortionView.broke(5, 0.9, s))
	s.bodies.clear()
	assert_true(DistortionView.broke(5, 0.9, s))
	assert_false(DistortionView.broke(5, 0.1, s))


func test_refresh_spawns_a_burst_on_break_and_it_expires():
	var v: DistortionView = add_child_autofree(DistortionView.new())
	v.beam = add_child_autofree(BeamView.new())
	var s := ShipState.new()
	s.bodies.append(_body(5))
	v.beam.has_hit = true
	v.beam.target_key = 5
	v.beam.ratio = 0.9
	v.beam.target_pos = Vector2(10, 20)
	v.beam.target_radius = 40.0
	v.refresh(s, 0.01)
	assert_eq(v.bursts.size(), 0)
	s.bodies.clear()
	v.beam.target_key = null
	v.beam.has_hit = false
	v.refresh(s, 0.01)
	assert_eq(v.bursts.size(), 1)
	assert_eq(v.bursts[0]["pos"], Vector2(10, 20))
	v.refresh(s, DistortionView.BURST_TIME + 0.1)
	assert_gte(v.bursts[0]["age"], DistortionView.BURST_TIME)


func test_fan_opens_away_from_the_ship_along_the_aim():
	var aim := Vector2.from_angle(0.7)
	assert_true(DistortionView.in_fan(aim * 10.0, aim))
	assert_false(DistortionView.in_fan(-aim * 10.0, aim))
	assert_false(DistortionView.in_fan(aim.rotated(PI * 0.5) * 10.0, aim))
