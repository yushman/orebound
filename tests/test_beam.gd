extends GutTest

const SQUARE := [Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)]


func _entry(extra: Dictionary = {}) -> Dictionary:
	var e := {"key": Vector3i(1, 2, 3), "pos": Vector2.ZERO, "rot": 0.0, "radius": 20.0, "points": PackedVector2Array(SQUARE), "amount": 4.0, "type": &"ice"}
	e.merge(extra, true)
	return e


func test_layer_drops_a_broken_asteroid_and_passes_others_unchanged() -> void:
	var e := _entry()
	assert_true(Beam.layer(e, {Vector3i(1, 2, 3): true}).is_empty())
	var l := Beam.layer(e, {Vector3i(9, 9, 9): true})
	assert_eq(l["radius"], 20.0)
	assert_eq(l["points"], e["points"])
	assert_eq(l["amount"], 4.0)
	assert_eq(l["key"], Vector3i(1, 2, 3))
	assert_eq(Beam.layer(e, {}), e)


func test_hit_nearest_edge() -> void:
	var near := _entry({"key": Vector3i(0, 0, 1), "pos": Vector2(100, 0)})
	var far := _entry({"key": Vector3i(0, 0, 2), "pos": Vector2(200, 0)})
	var h := Beam.hit(Vector2.ZERO, Vector2.RIGHT, 300.0, [far, near])
	assert_eq(h["key"], Vector3i(0, 0, 1))
	assert_almost_eq((h["point"] as Vector2).x, 90.0, 1e-3)


func test_hit_miss_and_range() -> void:
	var e := _entry({"pos": Vector2(100, 0)})
	assert_true(Beam.hit(Vector2.ZERO, Vector2.UP, 300.0, [e]).is_empty())
	assert_true(Beam.hit(Vector2.ZERO, Vector2.RIGHT, 80.0, [e]).is_empty())


func test_hit_respects_rotation() -> void:
	var tri := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(0, 10)])
	var e := _entry({"pos": Vector2(100, 0), "rot": PI / 2, "points": tri})
	# rotated 90deg: (10,0)->(0,10), (0,10)->(-10,0); edge from (-10,0) to (0,10) offset by pos
	var h := Beam.hit(Vector2(0, 0), Vector2.RIGHT, 300.0, [e])
	assert_false(h.is_empty())
	assert_almost_eq((h["point"] as Vector2).x, 90.0, 1e-3)


func test_hit_in_gap_between_hull_and_radius_misses() -> void:
	var e := _entry({"pos": Vector2(100, 0), "radius": 100.0})
	assert_true(Beam.hit(Vector2.ZERO, Vector2.UP, 300.0, [e]).is_empty())
	var h := Beam.hit(Vector2(100, -50), Vector2.DOWN, 300.0, [e])
	assert_almost_eq((h["point"] as Vector2).y, -10.0, 1e-3)

