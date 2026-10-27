class_name SmallObjectSchedule
extends RefCounted


static func schedule(seed_: int, flight: int, tier: int, window: int) -> Array:
	var out: Array = []
	var pl: PlanetParams = Tuning.planet
	var rate: float = pl.small_rate[tier]
	if rate <= 0.0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_, flight, "small", tier, window])
	var len: float = pl.small_window
	var t := -log(1.0 - rng.randf()) * 60.0 / rate
	while t < len:
		var rad := rng.randf_range(pl.small_radius_min, pl.small_radius_max)
		var pts := AsteroidField._hull(rng, rad)
		out.append({
			"time": window * len + t,
			"angle": rng.randf() * TAU,
			"e": rng.randf_range(pl.small_e_min, pl.small_e_max),
			"nu": rng.randf() * TAU,
			"radius": rad,
			"points": pts,
			"type": _type_of(tier, seed_, flight, window, out.size()),
			"amount": AsteroidField._area(pts) * pl.amount_per_area,
			"id": hash([seed_, flight, "small", tier, window, out.size()]),
		})
		t += -log(1.0 - rng.randf()) * 60.0 / rate
	return out


static func _type_of(tier: int, seed_: int, flight: int, window: int, j: int) -> StringName:
	match tier:
		0:
			return &"ore_unique"
		1:
			return &"ore_rare"
		2:
			return &"ore_middle"
	var u := (hash([seed_, flight, "small", tier, window, j, "comp"]) & 0xFFFFFF) / 16777216.0
	return &"ice" if u < Tuning.planet.top_ice_share else &"ore_base"
