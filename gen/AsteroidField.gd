class_name AsteroidField
extends RefCounted

const FIELD_MIN := 3
const FIELD_MAX := 6
const TRIES := 30
const HULL_POINTS := 9


static func band_count() -> int:
	var edge: float = Tuning.field.atmosphere_edge
	return ceili((WellGenerator.tiers()["ceiling"] - edge) / Tuning.planet.band_width)


static func band_of(r: float) -> int:
	var ceiling: float = WellGenerator.tiers()["ceiling"]
	if r < Tuning.field.atmosphere_edge or r > ceiling:
		return -1
	var edge: float = Tuning.field.atmosphere_edge
	return mini(floori((r - edge) / Tuning.planet.band_width), ceili((ceiling - edge) / Tuning.planet.band_width) - 1)


static func band_centre(k: int) -> float:
	return Tuning.field.atmosphere_edge + (k + 0.5) * Tuning.planet.band_width


static func _ring_band(k: int) -> bool:
	var ring: Dictionary = Tuning.picture["ring"]
	if ring.is_empty():
		return false
	var lo: float = Tuning.field.atmosphere_edge + k * Tuning.planet.band_width
	var half: float = ring["width"] * 0.5
	return ring["radius"] + half >= lo and ring["radius"] - half <= lo + Tuning.planet.band_width


static func band_omega(k: int) -> float:
	# the ring is its own band with one rigid omega: boulders in ring bands
	# rotate with the ring, not with the band-centre omega
	if _ring_band(k):
		return WellGenerator.relative_omega(Tuning.picture["ring"]["radius"])
	return WellGenerator.relative_omega(band_centre(k))


static func band_blocked(k: int) -> bool:
	var pad: float = Tuning.planet.field_radius + Tuning.planet.ast_radius_max
	var lo: float = Tuning.field.atmosphere_edge + k * Tuning.planet.band_width - pad
	var hi: float = lo + Tuning.planet.band_width + 2.0 * pad
	var pic: Dictionary = Tuning.picture
	for m in pic["moons"]:
		var reach: float = m.influence_radius + Tuning.planet.moon_margin
		if m.orbit_radius + reach >= lo and m.orbit_radius - reach <= hi:
			return true
	var ring: Dictionary = pic["ring"]
	if not ring.is_empty():
		var half: float = ring["width"] * 0.5
		if ring["radius"] + half >= lo and ring["radius"] - half <= hi:
			return true
	return false


static func chunk_count(k: int) -> int:
	return maxi(1, roundi(TAU * band_centre(k) / Tuning.planet.chunk_arc))


static func band_expected(k: int) -> float:
	var pl: PlanetParams = Tuning.planet
	var rc: float = Tuning.field.carrier_orbit_radius
	var centre := band_centre(k)
	if centre > rc:
		return pl.asteroids_per_band * pow(pl.drop_ratio, pl.drop_start) * pl.above_factor
	return pl.asteroids_per_band * pow(pl.drop_ratio, maxf(0.0, pl.drop_start - (rc - centre) / pl.band_width))


static func chunk(k: int, i: int, bands := -1, bounds: Array = []) -> Array:
	var out: Array = []
	if bands < 0:
		bands = band_count()
	if k < 0 or k >= bands:
		return out
	# Key-space coupling (M6): band_blocked gives asteroid fields to no band
	# touching the ring annulus, so boulders (this branch) and fields never
	# share a Vector3i(band, chunk, idx) key in ShipState.broken.
	if _ring_band(k):
		return _boulders(k, i)
	if band_blocked(k):
		return out
	var pl: PlanetParams = Tuning.planet
	var n := chunk_count(k)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([Tuning.picture["seed"], Tuning.picture["flight"], k, i])
	if rng.randf() >= band_expected(k) / (n * 0.5 * (FIELD_MIN + FIELD_MAX)):
		return out
	var dth := TAU / n
	var lo: float = Tuning.field.atmosphere_edge + k * pl.band_width
	var centre := Vector2.from_angle((i + rng.randf()) * dth) * rng.randf_range(lo, lo + pl.band_width)
	var want := rng.randi_range(FIELD_MIN, FIELD_MAX)
	var placed: Array = []
	for a in want:
		var rad := rng.randf_range(pl.ast_radius_min, pl.ast_radius_max)
		for t in TRIES:
			var off := Vector2.from_angle(rng.randf() * TAU) * (sqrt(rng.randf()) * pl.field_radius)
			var ok := true
			for q in placed:
				if off.distance_to(q["off"]) <= rad + q["radius"] + pl.ast_radius_min:
					ok = false
					break
			if ok:
				placed.append({"off": off, "radius": rad, "points": _hull(rng, rad)})
				break
	if bounds.is_empty() and not placed.is_empty():
		bounds = WellGenerator.tiers()["boundaries"]
	for j in placed.size():
		var q: Dictionary = placed[j]
		var pos: Vector2 = centre + q["off"]
		out.append({"r": pos.length(), "theta": pos.angle(), "radius": q["radius"], "points": q["points"], "type": _type_of(pos.length(), k, i, j, bounds), "amount": _area(q["points"]) * pl.amount_per_area})
	return out


static func _boulders(k: int, i: int) -> Array:
	# Ring boulders (M6): the ring band's interactive objects, ore_middle, in
	# the same entry shape and Vector3i(band, chunk, idx) space as asteroid
	# fields. Uniqueness of the keys relies on band_blocked keeping fields out
	# of every band touching the ring annulus. Rotating with the ring's single
	# omega (band_omega), placement inside the annulus, positions a formula of t.
	var pl: PlanetParams = Tuning.planet
	var per := pl.ring_boulders_per_chunk
	if per <= 0.0:
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([Tuning.picture["seed"], Tuning.picture["flight"], k, i])
	var count := int(per)
	if rng.randf() < per - count:
		count += 1
	var n := chunk_count(k)
	var dth := TAU / n
	var lo: float = Tuning.field.atmosphere_edge + k * pl.band_width
	var ring: Dictionary = Tuning.picture["ring"]
	var half: float = ring["width"] * 0.5
	var r_lo := maxf(lo, ring["radius"] - half)
	var r_hi := minf(lo + pl.band_width, ring["radius"] + half)
	var out: Array = []
	for j in count:
		var rad := rng.randf_range(pl.ast_radius_min, pl.ast_radius_max)
		var ang := (i + rng.randf()) * dth
		var r := rng.randf_range(r_lo, r_hi)
		var pts := _hull(rng, rad)
		out.append({"r": r, "theta": Vector2.from_angle(ang).angle(), "radius": rad, "points": pts, "type": &"ore_middle", "amount": _area(pts) * pl.amount_per_area})
	return out


static func _type_of(r: float, k: int, i: int, j: int, bounds: Array) -> StringName:
	var tier := 0
	while tier < 3 and r >= bounds[tier + 1]:
		tier += 1
	match tier:
		0:
			return &"ore_unique"
		1:
			return &"ore_rare"
		2:
			return &"ore_middle"
	var u := (hash([Tuning.picture["seed"], Tuning.picture["flight"], k, i, j, "comp"]) & 0xFFFFFF) / 16777216.0
	return &"ice" if u < Tuning.planet.top_ice_share else &"ore_base"


static func _area(pts: PackedVector2Array) -> float:
	var n := pts.size()
	var a := 0.0
	var prev := pts[n - 1]
	for p in pts:
		a += prev.cross(p)
		prev = p
	return absf(a) * 0.5


static func _hull(rng: RandomNumberGenerator, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for j in HULL_POINTS:
		pts.append(Vector2.from_angle(rng.randf() * TAU) * (rad * rng.randf_range(0.85, 1.0)))
	var hull := Geometry2D.convex_hull(pts)
	hull.remove_at(hull.size() - 1)
	return hull


static func chunk_index(k: int, angle: float, t: float) -> int:
	return posmod(floori((angle - band_omega(k) * t) / (TAU / chunk_count(k))), chunk_count(k))


static func state(k: int, ast: Dictionary, t: float) -> Dictionary:
	var a: Dictionary = ast.duplicate()
	a["omega"] = band_omega(k)
	return at(a, t)


static func max_speed() -> float:
	var v := 0.0
	for k in band_count():
		v = maxf(v, absf(band_omega(k)) * (band_centre(k) + Tuning.planet.band_width * 0.5 + Tuning.planet.field_radius))
	return v


static func at(ast: Dictionary, t: float) -> Dictionary:
	var a: float = ast["theta"] + ast["omega"] * t
	var pos: Vector2 = Vector2(cos(a), sin(a)) * ast["r"]
	return {"pos": pos, "vel": ast["omega"] * Vector2(-pos.y, pos.x)}


static func near(pos: Vector2, t: float, radius: float) -> Array:
	var out: Array = []
	var pl: PlanetParams = Tuning.planet
	var edge: float = Tuning.field.atmosphere_edge
	var bw := pl.band_width
	var fr := pl.field_radius
	var d := pos.length()
	var k_lo := maxi(0, floori((d - radius - fr - edge) / bw))
	var bands := band_count()
	var bounds: Array = WellGenerator.tiers()["boundaries"]
	var k_hi := mini(bands - 1, floori((d + radius + fr - edge) / bw))
	var phi := pos.angle()
	for k in range(k_lo, k_hi + 1):
		# ring bands are skipped for fields but hold boulders
		if band_blocked(k) and not _ring_band(k):
			continue
		var n := chunk_count(k)
		var om := band_omega(k)
		var lo := edge + k * bw
		var w := TAU
		if d > radius:
			w = asin(minf(1.0, radius / d)) + asin(minf(1.0, fr / lo))
		var first := 0
		var last := n - 1
		if w < PI:
			var dth := TAU / n
			first = floori((phi - om * t - w) / dth)
			last = floori((phi - om * t + w) / dth)
			if last - first + 1 >= n:
				first = 0
				last = n - 1
		for ci in range(first, last + 1):
			var i := posmod(ci, n)
			var c := chunk(k, i, bands, bounds)
			for j in c.size():
				var st := state(k, c[j], t)
				if st["pos"].distance_to(pos) <= radius:
					out.append({"pos": st["pos"], "vel": st["vel"], "radius": c[j]["radius"], "points": c[j]["points"], "type": c[j]["type"], "amount": c[j]["amount"], "band": k, "chunk": i, "idx": j, "r": c[j]["r"], "theta": c[j]["theta"], "omega": om})
	return out
