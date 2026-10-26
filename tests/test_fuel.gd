extends GutTest


func test_per_dv_times_dv_ref_equals_climb_coefficient() -> void:
	var f: FieldParams = Tuning.field
	var lo: float = Tuning.field.atmosphere_edge
	var dphi: float = GravityField.planet_potential_eff(f.carrier_orbit_radius) - GravityField.planet_potential_eff(lo)
	var dv_ref := sqrt(2.0 * 0.45 * dphi)
	assert_almost_eq(Fuel.per_dv() * dv_ref, Tuning.ship.climb_coefficient, 1e-6)


func test_per_dv_follows_climb_coefficient() -> void:
	var before := Fuel.per_dv()
	var old: float = Tuning.ship.climb_coefficient
	Tuning.ship.climb_coefficient = old * 2.0
	var after := Fuel.per_dv()
	Tuning.ship.climb_coefficient = old
	assert_almost_eq(after, before * 2.0, 1e-9)


func test_per_dv_follows_gravity() -> void:
	var before := Fuel.per_dv()
	var old: float = Tuning.field.k
	Tuning.field.k = old * 2.0
	var after := Fuel.per_dv()
	Tuning.field.k = old
	assert_ne(after, before)


func test_per_dv_zero_when_carrier_at_atmosphere_edge() -> void:
	var old: float = Tuning.field.carrier_orbit_radius
	Tuning.field.carrier_orbit_radius = Tuning.field.atmosphere_edge
	var v := Fuel.per_dv()
	Tuning.field.carrier_orbit_radius = old
	assert_eq(v, 0.0)
