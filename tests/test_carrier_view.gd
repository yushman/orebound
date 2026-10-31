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


func test_contour_color_follows_the_ship_reserve_state() -> void:
	var s := ShipState.new()
	s.pos = Vector2(0, Tuning.field.carrier_orbit_radius)
	var hud = load("res://ui/HUD.gd")
	assert_eq(CarrierView.contour_color(s), hud.reserve_color(hud.ship_reserve(s)))
	s.tank.clear()
	s.pos = Vector2(0, Tuning.field.atmosphere_edge + 100.0)
	assert_eq(CarrierView.contour_color(s), Palette.DANGER)
	s = ShipState.new()
	s.pos = Vector2(0, Tuning.field.carrier_orbit_radius)
	while s.tank.size() > 1:
		s.tank.pop_back()
	assert_eq(CarrierView.contour_color(s), Palette.SAFE)
	s = ShipState.new()
	s.pos = Vector2(0, Tuning.field.carrier_orbit_radius)
	assert_eq(CarrierView.contour_color(s), Palette.HALO)


func test_view_without_a_ship_draws_without_error() -> void:
	var v: CarrierView = load("res://scenes/Carrier.tscn").instantiate()
	add_child_autofree(v)
	v.refresh(0.0, 1.0)
	v.queue_redraw()
	assert_null(v.ship)
