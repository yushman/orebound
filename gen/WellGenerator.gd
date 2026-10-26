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


static func picture(seed: int, flight: int) -> Dictionary:
	var pl: PlanetParams = Tuning.planet
	for i in pl.max_tries:
		var pic := _build(seed + i, flight)
		if check(pic["moons"], pic["ring"]):
			return pic
	return _build(pl.fallback_seed, flight)


static func _build(seed: int, flight: int) -> Dictionary:
	var pl: PlanetParams = Tuning.planet
	var b: Array[float] = tiers()["boundaries"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, flight])
	var n := maxi(1, rng.randi_range(pl.moon_count_min, pl.moon_count_max))
	var moons: Array[BodyParams] = [_moon(rng, pl.moon_large_radius_min, pl.moon_large_radius_max, b[3], b[4])]
	for i in n - 1:
		moons.append(_moon(rng, pl.moon_small_radius_min, pl.moon_small_radius_max, b[1], b[3]))
	return {"seed": seed, "flight": flight, "moons": moons, "ring": _ring(rng, b, moons)}


static func _ring(rng: RandomNumberGenerator, b: Array[float], moons: Array[BodyParams]) -> Dictionary:
	var pl: PlanetParams = Tuning.planet
	var lo: float = b[pl.ring_tier]
	var hi: float = b[pl.ring_tier + 1]
	var blocked: Array = []
	for m in moons:
		var reach: float = m.influence_radius + pl.moon_margin
		blocked.append([m.orbit_radius - reach, m.orbit_radius + reach])
	blocked.sort_custom(func(x, y): return x[0] < y[0])
	var gaps: Array = []
	var cur := lo
	for iv in blocked:
		var end := minf(iv[0], hi)
		if end - cur >= pl.ring_width:
			gaps.append([cur, end])
		cur = maxf(cur, iv[1])
	if hi - cur >= pl.ring_width:
		gaps.append([cur, hi])
	if gaps.is_empty():
		return {}
	var gap: Array = gaps[rng.randi_range(0, gaps.size() - 1)]
	var half := pl.ring_width * 0.5
	return {"radius": rng.randf_range(gap[0] + half, gap[1] - half), "width": pl.ring_width, "phase": rng.randf_range(0.0, TAU)}


static func _moon(rng: RandomNumberGenerator, r_min: float, r_max: float, o_min: float, o_max: float) -> BodyParams:
	var pl: PlanetParams = Tuning.planet
	var m := BodyParams.new()
	m.radius = rng.randf_range(r_min, r_max)
	m.orbit_radius = rng.randf_range(o_min, o_max)
	m.phase = rng.randf_range(0.0, TAU)
	m.parent = 0
	m.p = 2.0
	m.mass = pl.moon_mass_k * pow(m.radius, pl.moon_mass_exp)
	m.influence_radius = pl.moon_influence_k * m.radius
	var g: float = GravityField.accel_of(0, Vector2(m.orbit_radius, 0.0), 0.0).length()
	m.angular_speed = sqrt(m.orbit_radius * g) / m.orbit_radius
	return m


static func relative_omega(r: float) -> float:
	var g: float = GravityField.accel_of(0, Vector2(r, 0.0), 0.0).length()
	return sqrt(g / r) - GravityField.frame_omega()


static func check(moons: Array, ring = null) -> bool:
	var f: FieldParams = Tuning.field
	var margin: float = Tuning.planet.moon_margin
	for i in moons.size():
		var a: BodyParams = moons[i]
		if a.orbit_radius - a.radius <= f.atmosphere_edge:
			return false
		if absf(f.carrier_orbit_radius - a.orbit_radius) <= a.influence_radius + margin:
			return false
		for j in range(i + 1, moons.size()):
			var b: BodyParams = moons[j]
			if absf(a.orbit_radius - b.orbit_radius) <= a.influence_radius + b.influence_radius + margin:
				return false
	if ring != null:
		if ring.is_empty():
			return false
		for m in moons:
			var reach: float = m.influence_radius + margin
			if absf(ring["radius"] - m.orbit_radius) < reach + ring["width"] * 0.5:
				return false
	return true
