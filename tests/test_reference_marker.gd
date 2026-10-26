extends GutTest

var _saved_planet
var _saved_picture


func before_each():
	_saved_planet = Tuning.planet
	_saved_picture = Tuning.picture


func after_each():
	Tuning.planet = _saved_planet
	Tuning.picture = _saved_picture


func test_marker_sits_on_asteroid_reference() -> void:
	Tuning.planet = Tuning.planet.duplicate()
	Tuning.planet.asteroids_per_band = 1000.0
	var ast: Dictionary = AsteroidField.chunk(0, 0)[0]
	var st := AsteroidField.state(0, ast, 0.0)
	var pos: Vector2 = st["pos"] + Vector2(ast["radius"] + 10.0, 0.0)
	var ref := ShipFlight.sync_reference(pos, 0.0)
	assert_false(ref["asteroid"].is_empty())
	var marker: Node2D = load("res://scenes/ReferenceMarker.gd").new()
	assert_eq(marker.marker_pos(ref, 0.0), ref["asteroid"]["pos"])
	marker.free()


func test_marker_pos_takes_precomputed_ref() -> void:
	var marker: Node2D = load("res://scenes/ReferenceMarker.gd").new()
	var ref := {"asteroid": {"pos": Vector2(5.0, 6.0)}, "is_carrier": false, "index": 0}
	assert_eq(marker.marker_pos(ref, 0.0), Vector2(5.0, 6.0))
	marker.free()


func test_marker_keeps_carrier_and_body_cases() -> void:
	var marker: Node2D = load("res://scenes/ReferenceMarker.gd").new()
	var rc: float = Tuning.field.carrier_orbit_radius
	assert_eq(marker.marker_pos(ShipFlight.sync_reference(Vector2(rc, 0.0), 0.0), 0.0), Vector2(rc, 0.0))
	marker.free()
