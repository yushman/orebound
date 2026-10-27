class_name WellGenerator
extends RefCounted

const PHI_REL_TOL := 1e-9
const MAX_ITER := 200


static var _key: Array = []
static var _memo: Dictionary = {}
static var _shares: Array = []
static var _lock := Mutex.new()


static func _fresh(f: FieldParams, b: BodyParams, shares: Array, offset: float) -> bool:
	return not _memo.is_empty() and _key[0] == f.k and _key[1] == f.eps and _key[2] == f.fade_width \
		and _key[3] == f.atmosphere_edge and _key[4] == f.carrier_orbit_radius and _key[5] == b.mass \
		and _key[6] == b.p and _key[7] == b.influence_radius and _key[8] == offset and _shares == shares


static func tiers() -> Dictionary:
	var f: FieldParams = Tuning.field
	var shares: Array = Tuning.planet.tier_shares
	var b0: BodyParams = f.bodies[0]
	var offset: float = Tuning.planet.ceiling_offset
	_lock.lock()
	if _fresh(f, b0, shares, offset):
		var hit := _memo
		_lock.unlock()
		return hit
	_lock.unlock()
	var lo_phi: float = GravityField.planet_potential_eff(f.atmosphere_edge)
	var swing: float = GravityField.planet_potential_eff(f.carrier_orbit_radius) - lo_phi
	var boundaries: Array[float] = [f.atmosphere_edge]
	var cum := 0.0
	for i in 3:
		cum += shares[3 - i]
		boundaries.append(_radius_at(lo_phi + cum * swing, f.atmosphere_edge, f.carrier_orbit_radius, absf(swing) * PHI_REL_TOL))
	boundaries.append(f.carrier_orbit_radius)
	var out := {"boundaries": boundaries, "tow": boundaries[2], "ceiling": f.carrier_orbit_radius + offset}
	boundaries.make_read_only()
	out.make_read_only()
	_lock.lock()
	_key = [f.k, f.eps, f.fade_width, f.atmosphere_edge, f.carrier_orbit_radius, b0.mass, b0.p, b0.influence_radius, offset]
	_shares = shares.duplicate()
	_memo = out
	_lock.unlock()
	return out


static func tier_of(r: float) -> int:
	var b: Array[float] = tiers()["boundaries"]
	var i := 0
	while i < 3 and r >= b[i + 1]:
		i += 1
	return i


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
	var b: Array[float] = tiers()["boundaries"]
	for i in pl.max_tries:
		var pic := _build(seed + i, flight, b)
		if check(pic["moons"], pic["ring"]):
			return pic
	return _build(pl.fallback_seed, flight, b)


static func _build(seed: int, flight: int, bounds: Array[float] = []) -> Dictionary:
	var pl: PlanetParams = Tuning.planet
	var b: Array[float] = bounds if not bounds.is_empty() else tiers()["boundaries"]
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
