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


func test_marker_carrier_case_follows_the_patrol() -> void:
	var marker: Node2D = load("res://scenes/ReferenceMarker.gd").new()
	var ref := {"asteroid": {}, "is_carrier": true, "index": -1}
	assert_eq(marker.marker_pos(ref, 7.5), ShipFlight.carrier_pos(7.5))
	marker.free()


func test_marker_color_is_halo_with_alpha_unchanged() -> void:
	var marker: Node2D = load("res://scenes/ReferenceMarker.gd").new()
	var on: Color = marker.marker_color(true)
	var off: Color = marker.marker_color(false)
	assert_eq(Color(on.r, on.g, on.b), Color(Palette.HALO.r, Palette.HALO.g, Palette.HALO.b))
	assert_eq(Color(off.r, off.g, off.b), Color(Palette.HALO.r, Palette.HALO.g, Palette.HALO.b))
	assert_eq(on.a, 1.0)
	assert_almost_eq(off.a, 0.35, 0.0001)
	marker.free()


func test_marker_draws_the_speed_chevron_while_the_view_is_close() -> void:
	# The chevron of the sync reference rides on the ring: the back edge on the
	# ring (28 px), the tip 5 px further out (33 px), 12 px across; the |v|
	# label 24 px past the tip (57 px from the centre).
	var marker: Node2D = load("res://scenes/ReferenceMarker.gd").new()
	var s := 2.0
	var vel := Vector2(0.0, 30.0)
	var lines: Array = marker.chevron_lines(vel, s)
	assert_eq(lines.size(), 2, "two chevron lines, no shaft")
	for seg in lines:
		assert_almost_eq(seg[1].distance_to(Vector2.ZERO), 33.0 * s, 1e-3,
				"the tip is 33 px from the centre")
		var rel: Vector2 = seg[0]
		assert_almost_eq(rel.dot(Vector2(0.0, 1.0)), 28.0 * s, 1e-3,
				"the back edge is on the ring (28 px)")
		assert_almost_eq(absf(rel.dot(Vector2(1.0, 0.0))), 6.0 * s, 1e-3,
				"the back vertex is +-6 px off (12 px across)")
	assert_almost_eq(lines[0][0].distance_to(lines[1][0]), 12.0 * s, 1e-3,
			"the chevron is 12 px across")
	var anchor: Vector2 = marker.chevron_label_pos(vel, s)
	assert_almost_eq(anchor.distance_to(Vector2.ZERO), 57.0 * s, 1e-3,
			"the |v| label is 57 px from the centre")
	# Close view only, moving reference only, and only with a reference.
	assert_true(marker.chevron_visible(1.0, vel, true), "close view: the chevron is there")
	assert_true(marker.chevron_visible(10.0, vel, true), "s = 10: the chevron is there")
	assert_false(marker.chevron_visible(15.0, vel, true), "s >= 15: no chevron")
	assert_false(marker.chevron_visible(22.0, vel, true), "far away: no chevron")
	assert_false(marker.chevron_visible(1.0, Vector2(0.5, 0.0), true),
			"a still reference has no chevron")
	assert_false(marker.chevron_visible(1.0, vel, false),
			"no reference: no chevron")
	# The chevron colour is the ship chevron colour.
	var FlightVectorScript = load("res://scenes/FlightVector.gd")
	assert_eq(marker.chevron_color(), FlightVectorScript.COLOR)
	marker.free()


func test_marker_label_follows_the_camera_rotation_not_the_reference_angle() -> void:
	# The camera follows the ship, so its rotation comes from the camera
	# position. The |v| label of the reference must be compensated against
	# that angle, not against the angle of the reference around the planet:
	# otherwise the glyphs stand tilted in the camera frame.
	var marker: Node2D = load("res://scenes/ReferenceMarker.gd").new()
	var cam_pos := Vector2(30000.0, 4000.0)
	var ref_pos := Vector2(30000.0, 7000.0)
	assert_gt(absf(FlightCamera.rotation_for(cam_pos) - FlightCamera.rotation_for(ref_pos)),
			0.01, "the camera and the reference are at different angles")
	assert_almost_eq(marker.label_rotation(cam_pos), FlightCamera.rotation_for(cam_pos), 1e-6,
			"the label is compensated against the camera rotation")
	assert_almost_eq(marker.label_rotation(ref_pos), FlightCamera.rotation_for(ref_pos), 1e-6,
			"the label rotation follows the camera position")
	marker.free()


func test_marker_takes_the_reference_velocity_from_the_reference() -> void:
	# The chevron shows the speed the ship would be dragged to by the sync:
	# the velocity of the reference itself.
	var marker: Node2D = load("res://scenes/ReferenceMarker.gd").new()
	var t := 2.0
	var ref := {"valid": true, "index": -1, "is_carrier": true, "asteroid": {}}
	marker.update_reference(ref, t)
	assert_true(marker.visible, "a valid reference shows the marker")
	assert_eq(marker.reference_vel, ShipFlight.reference_vel(ref, t),
			"the marker reads the reference velocity")
	var none := {"valid": false, "index": -1, "is_carrier": false, "asteroid": {}}
	marker.update_reference(none, t)
	assert_false(marker.visible, "no reference hides the marker")
	assert_eq(marker.reference_vel, Vector2.ZERO, "no reference: no speed")
	marker.free()
