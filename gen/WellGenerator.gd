class_name WellGenerator
extends RefCounted

const PHI_REL_TOL := 1e-9
const MAX_ITER := 200


static func tiers() -> Dictionary:
	var f: FieldParams = Tuning.field
	var shares: Array = Tuning.planet.tier_shares
	var lo_phi: float = GravityField.planet_potential_eff(f.atmosphere_edge)
	var swing: float = GravityField.planet_potential_eff(f.carrier_orbit_radius) - lo_phi
	var boundaries: Array[float] = [f.atmosphere_edge]
	var cum := 0.0
	for i in 3:
		cum += shares[3 - i]
		boundaries.append(_radius_at(lo_phi + cum * swing, f.atmosphere_edge, f.carrier_orbit_radius, absf(swing) * PHI_REL_TOL))
	boundaries.append(f.carrier_orbit_radius)
	return {"boundaries": boundaries, "tow": boundaries[2], "ceiling": f.carrier_orbit_radius + Tuning.planet.ceiling_offset}


static func _radius_at(target: float, r_lo: float, r_hi: float, phi_tol: float) -> float:
	var lo := r_lo
	var hi := r_hi
	var mid := 0.5 * (lo + hi)
	for i in MAX_ITER:
		mid = 0.5 * (lo + hi)
		var d: float = GravityField.planet_potential_eff(mid) - target
		if absf(d) <= phi_tol:
			break
		if d < 0.0:
			lo = mid
		else:
			hi = mid
	return mid
