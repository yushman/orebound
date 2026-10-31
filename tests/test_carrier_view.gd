extends GutTest

var _saved_planet


func before_each() -> void:
	_saved_planet = Tuning.planet
	Tuning.planet = Tuning.planet.duplicate()


func after_each() -> void:
	Tuning.planet = _saved_planet


func test_scale_for_has_world_size_floor_and_min_screen_size() -> void:
	assert_eq(CarrierView.scale_for(1.0), 1.0)
	assert_almost_eq(CarrierView.scale_for(40.0), 4.0, 1e-6)


func test_view_sits_at_carrier_pos_along_the_orbit_tangent() -> void:
	Tuning.planet.carrier_patrol_speed = 40.0
	var v: CarrierView = load("res://scenes/Carrier.tscn").instantiate()
	add_child_autofree(v)
	v.refresh(7.0, 1.0)
	assert_eq(v.position, ShipFlight.carrier_pos(7.0))
	var tangent := Vector2.RIGHT.rotated(v.rotation)
	assert_almost_eq(tangent, ShipFlight.carrier_vel(7.0).normalized(), Vector2(1e-5, 1e-5))
