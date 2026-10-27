class_name Fuel
extends RefCounted


static func per_dv() -> float:
	var rc: float = Tuning.field.carrier_orbit_radius
	var lo: float = Tuning.field.atmosphere_edge
	var dphi: float = GravityField.planet_potential_eff(rc) - GravityField.planet_potential_eff(lo)
	if dphi <= 0.0:
		return 0.0
	return Tuning.ship.climb_coefficient / sqrt(2.0 * 0.45 * dphi)


static func climb_energy(r: float, speed: float, mass: float) -> float:
	var rc: float = Tuning.field.carrier_orbit_radius
	var dphi := absf(GravityField.planet_potential_eff(rc) - GravityField.planet_potential_eff(r))
	return per_dv() * mass * (sqrt(0.9 * dphi) + speed) * Tuning.ship.return_margin
