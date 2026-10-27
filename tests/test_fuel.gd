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


func _phi_total() -> float:
	var f: FieldParams = Tuning.field
	return GravityField.planet_potential_eff(f.carrier_orbit_radius) - GravityField.planet_potential_eff(f.atmosphere_edge)


func test_climb_energy_zero_at_carrier_at_rest() -> void:
	assert_almost_eq(Fuel.climb_energy(Tuning.field.carrier_orbit_radius, 0.0, 10.0), 0.0, 1e-9)


func test_climb_energy_formula() -> void:
	var r: float = Tuning.field.atmosphere_edge + 100.0
	var dphi := absf(GravityField.planet_potential_eff(Tuning.field.carrier_orbit_radius) - GravityField.planet_potential_eff(r))
	var expect := Fuel.per_dv() * 7.0 * (sqrt(0.9 * dphi) + 3.0) * Tuning.ship.return_margin
	assert_almost_eq(Fuel.climb_energy(r, 3.0, 7.0), expect, 1e-6)


func test_climb_energy_at_atmosphere_edge_margin_one_equals_coefficient_times_mass() -> void:
	var old: float = Tuning.ship.return_margin
	Tuning.ship.return_margin = 1.0
	var e := Fuel.climb_energy(Tuning.field.atmosphere_edge, 0.0, 5.0)
	Tuning.ship.return_margin = old
	assert_almost_eq(e, Tuning.ship.climb_coefficient * 5.0, 1e-6)


func test_climb_energy_above_carrier_uses_abs_and_scales_linearly() -> void:
	var r: float = Tuning.field.carrier_orbit_radius + 200.0
	var e1 := Fuel.climb_energy(r, 1.0, 2.0)
	assert_gt(e1, 0.0)
	assert_almost_eq(Fuel.climb_energy(r, 1.0, 4.0), e1 * 2.0, 1e-9)
	var old: float = Tuning.ship.return_margin
	Tuning.ship.return_margin = old * 2.0
	var e2 := Fuel.climb_energy(r, 1.0, 2.0)
	Tuning.ship.return_margin = old
	assert_almost_eq(e2, e1 * 2.0, 1e-9)
