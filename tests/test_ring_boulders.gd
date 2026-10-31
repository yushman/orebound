extends GutTest

# M6 ring boulders: bands overlapping the ring annulus hold ore_middle boulders
# in the same Vector3i(band, chunk, idx) space as asteroid fields.

const DT := 1.0 / 60.0
const BAND := 2

var _saved_field
var _saved_planet
var _saved_picture
var _saved_ship


func before_each():
	_saved_field = Tuning.field
	_saved_planet = Tuning.planet
	_saved_picture = Tuning.picture
	_saved_ship = Tuning.ship
	Tuning.planet = Tuning.planet.duplicate(true)


func after_each():
	Tuning.field = _saved_field
	Tuning.planet = _saved_planet
	Tuning.picture = _saved_picture
	Tuning.ship = _saved_ship


# one wide band (6000) with a narrow ring (800) centred 2000 off the band
# centre, so the ring omega differs from the band-centre omega measurably
func _ring_setup(s := 7) -> Dictionary:
	Tuning.planet.band_width = 6000.0
	Tuning.planet.asteroids_per_band = 0.0
	Tuning.planet.ring_boulders_per_chunk = 1.0
	var ring := {"radius": AsteroidField.band_centre(BAND) + 2000.0, "width": 800.0, "phase": 0.0}
	Tuning.picture = {"seed": s, "flight": 1, "moons": [], "ring": ring}
	return ring


func _key(a: Dictionary) -> String:
	return "%d:%d:%d" % [a["band"], a["chunk"], a["idx"]]


func _is_convex(pts: PackedVector2Array) -> bool:
	var sign_ := 0.0
	for j in pts.size():
		var a := pts[j]
		var b := pts[(j + 1) % pts.size()]
		var c := pts[(j + 2) % pts.size()]
		var cr := (b - a).cross(c - b)
		if absf(cr) < 1e-9:
			continue
		if sign_ == 0.0:
			sign_ = signf(cr)
		elif signf(cr) != sign_:
			return false
	return true


func test_ring_band_chunks_hold_ore_middle_boulders_rotating_with_ring_omega() -> void:
	var ring := _ring_setup()
	var pl: PlanetParams = Tuning.planet
	var om: float = WellGenerator.relative_omega(ring["radius"])
	# the ring band is exactly the band overlapping the annulus; its omega is the
	# ring omega, measurably not the band-centre one
	assert_true(AsteroidField.band_blocked(BAND), "ring band is blocked for fields")
	assert_false(AsteroidField.band_blocked(BAND - 1), "band below the annulus spill")
	assert_almost_eq(AsteroidField.band_omega(BAND), om, 1e-12)
	assert_gt(absf(AsteroidField.band_omega(BAND) - WellGenerator.relative_omega(AsteroidField.band_centre(BAND))), 1e-9)
	var n := AsteroidField.chunk_count(BAND)
	var half: float = ring["width"] * 0.5
	for i in n:
		var c := AsteroidField.chunk(BAND, i)
		assert_eq(c.size(), 1, "one boulder per chunk at the default knob")
		if c.is_empty():
			continue
		var b: Dictionary = c[0]
		assert_eq(b.size(), 6, "entry shaped exactly like an asteroid entry")
		assert_true(b.has_all(["r", "theta", "radius", "points", "type", "amount"]))
		assert_between(b["radius"], pl.ast_radius_min, pl.ast_radius_max)
		assert_gte(b["points"].size(), 3)
		assert_true(_is_convex(b["points"]))
		for p in b["points"]:
			assert_lte(p.length(), b["radius"] + 1e-6)
		assert_eq(b["type"], &"ore_middle")
		var pts: PackedVector2Array = b["points"]
		var area := 0.0
		for j in pts.size():
			area += pts[j].cross(pts[(j + 1) % pts.size()])
		assert_almost_eq(b["amount"], absf(area) * 0.5 * pl.amount_per_area, 1e-9)
		assert_between(b["r"], ring["radius"] - half, ring["radius"] + half)
		assert_eq(AsteroidField.chunk_index(BAND, b["theta"], 0.0), i, "boulder sits in its own chunk")
		for t in [0.0, 300.0, -120.0]:
			var st := AsteroidField.state(BAND, b, t)
			var ang: float = b["theta"] + om * t
			var pos: Vector2 = Vector2.from_angle(ang) * b["r"]
			assert_almost_eq(st["pos"], pos, Vector2(0.05, 0.05), "pos formula at ring omega")
			assert_almost_eq(st["vel"], om * Vector2(-pos.y, pos.x), Vector2(1e-4, 1e-4), "vel formula at ring omega")
			assert_eq(AsteroidField.chunk_index(BAND, st["pos"].angle(), t), i, "chunk membership is t-independent")


func test_ring_boulders_follow_the_knob_and_keep_asteroid_fields_out() -> void:
	var ring := _ring_setup()
	var n := AsteroidField.chunk_count(BAND)
	# dense fields everywhere they are still allowed
	Tuning.planet.asteroids_per_band = 1000.0
	Tuning.planet.ring_boulders_per_chunk = 0.0
	for i in n:
		assert_eq(AsteroidField.chunk(BAND, i), [], "ring band without boulders holds no fields")
	var fields := 0
	for i in AsteroidField.chunk_count(BAND - 1):
		fields += AsteroidField.chunk(BAND - 1, i).size()
	assert_gt(fields, 0, "bands clear of the ring still hold fields")
	# the default knob gives one boulder per chunk, fields stay excluded
	Tuning.planet.ring_boulders_per_chunk = 1.0
	for i in n:
		for b in AsteroidField.chunk(BAND, i):
			assert_eq(b["type"], &"ore_middle", "only boulders in the ring band")
	# the knob scales the count (integer draws: exactly per-chunk)
	Tuning.planet.ring_boulders_per_chunk = 2.0
	var total := 0
	for i in n:
		total += AsteroidField.chunk(BAND, i).size()
	assert_eq(total, 2 * n)


func test_boulder_chunks_are_pure_functions_of_seed_and_flight() -> void:
	_ring_setup(11)
	var a := AsteroidField.chunk(BAND, 3)
	assert_gt(a.size(), 0)
	assert_eq(AsteroidField.chunk(BAND, 3), a)
	Tuning.picture["seed"] = 12
	assert_ne(AsteroidField.chunk(BAND, 3), a)
	Tuning.picture["seed"] = 11
	Tuning.picture["flight"] = 2
	assert_ne(AsteroidField.chunk(BAND, 3), a)


func test_max_speed_bounds_boulder_speed() -> void:
	var ring := _ring_setup()
	Tuning.planet.ring_boulders_per_chunk = 4.0
	var vmax := AsteroidField.max_speed()
	var om: float = WellGenerator.relative_omega(ring["radius"])
	var seen := 0
	for t in [0.0, 500.0]:
		var centre: Vector2 = Vector2.from_angle(0.4 + om * t) * (ring["radius"] as float)
		for e in AsteroidField.near(centre, t, 20000.0):
			seen += 1
			assert_almost_eq(e["omega"], om, 1e-12, "boulders rotate with the ring omega")
			assert_lte(e["vel"].length(), vmax + 1e-6)
	assert_gt(seen, 0)


func test_near_matches_brute_force_across_the_ring_band() -> void:
	var ring := _ring_setup()
	Tuning.planet.ring_boulders_per_chunk = 3.0
	var radius := 6000.0
	var om: float = WellGenerator.relative_omega(ring["radius"])
	var total := 0
	for t in [0.0, 250.0]:
		var all: Array = []
		for k in AsteroidField.band_count():
			for i in AsteroidField.chunk_count(k):
				var c := AsteroidField.chunk(k, i)
				for j in c.size():
					var st := AsteroidField.state(k, c[j], t)
					all.append({"key": "%d:%d:%d" % [k, i, j], "pos": st["pos"]})
		var n := AsteroidField.chunk_count(BAND)
		var spots: Array = []
		for i in [0, 4, n - 1]:
			for rr in [ring["radius"] - 300.0, ring["radius"], ring["radius"] + 300.0]:
				spots.append(Vector2.from_angle(i * TAU / n + om * t) * (rr as float))
		spots.append(Vector2.from_angle(1.1) * ((ring["radius"] as float) + 2000.0))
		for p in spots:
			var want: Array = []
			for a in all:
				if a["pos"].distance_to(p) <= radius:
					want.append(a["key"])
			var got := AsteroidField.near(p, t, radius)
			var keys := got.map(_key)
			want.sort()
			keys.sort()
			assert_eq(keys, want, "near %s t %s" % [p, t])
			for e in got:
				assert_eq(e["band"], BAND, "only the ring band holds objects here")
			total += got.size()
	assert_gt(total, 0)


func test_ship_flight_beam_breaks_a_boulder_into_collectible_middle_ore_pieces() -> void:
	var ring := _ring_setup()
	var pl: PlanetParams = Tuning.planet
	pl.ast_radius_min = 90.0
	pl.ast_radius_max = 110.0
	pl.collect_radius = 60.0
	Tuning.ship = Tuning.ship.duplicate()
	Tuning.ship.beam_range = 900.0
	var cs := AsteroidField.chunk(BAND, 4)
	assert_gt(cs.size(), 0, "ring band chunk holds a boulder")
	if cs.is_empty():
		return
	var boulder: Dictionary = cs[0]
	var key := Vector3i(BAND, 4, 0)
	var st := AsteroidField.state(BAND, boulder, 0.0)
	var s := ShipState.new()
	s.pos = st["pos"] + Vector2(boulder["radius"] + 60.0, 0.0)
	s.vel = st["vel"]
	var inp := ShipInput.new()
	inp.beam = true
	inp.aim = (st["pos"] - s.pos).angle()
	var threshold: float = Tuning.planet.break_per_sqrt_radius * sqrt(sqrt(AsteroidField._area(boulder["points"]) / PI))
	s.beam_target = key
	s.beam_charge = threshold - Tuning.ship.beam_damage * DT * 0.5
	var out := ShipFlight.step(s, inp, 0.0, DT)
	assert_true(out.broken.has(key), "the beam breaks the boulder")
	assert_eq(out.bodies.size(), pl.split_count)
	for b in out.bodies:
		assert_eq(b.type, &"ore_middle", "pieces are middle ore")
		assert_lte(b.radius, pl.collect_radius, "pieces are collectible")
		assert_gt(b.amount, 0.0)
	# the pieces reach the hold through the collector / small-body pickup
	var cur := out
	for i in 300:
		if cur.bodies.is_empty():
			break
		var ic := ShipInput.new()
		ic.collect = true
		ic.aim = (cur.bodies[0].pos - cur.pos).angle()
		cur = ShipFlight.step(cur, ic, (i + 1) * DT, DT)
		if not cur.hold.is_empty():
			break
	assert_gt(cur.hold.size(), 0, "a boulder piece reaches the hold")
	if not cur.hold.is_empty():
		assert_eq(cur.hold[0].type, &"ore_middle")


func test_ship_flight_drift_sync_to_a_boulder_zeroes_relative_velocity() -> void:
	var ring := _ring_setup()
	var cs := AsteroidField.chunk(BAND, 5)
	assert_gt(cs.size(), 0, "ring band chunk holds a boulder")
	if cs.is_empty():
		return
	var boulder: Dictionary = cs[0]
	var st := AsteroidField.state(BAND, boulder, 0.0)
	# same radius as the boulder, 300 u behind along the orbit: the boulder is
	# the nearest reference and the band drag target (if any) matches its flow
	var pos: Vector2 = Vector2.from_angle(st["pos"].angle() - 300.0 / boulder["r"]) * (boulder["r"] as float)
	var near := AsteroidField.near(pos, 0.0, Tuning.ship.sync_radius)
	assert_gt(near.size(), 0)
	var ref := ShipFlight.sync_reference(pos, 0.0)
	assert_true(ref.valid)
	assert_false(ref.is_carrier)
	assert_eq(ref.index, -1)
	assert_almost_eq(ref.asteroid["pos"], st["pos"], Vector2(1e-6, 1e-6), "the boulder is the reference")
	assert_almost_eq(ref.asteroid["vel"], st["vel"], Vector2(1e-9, 1e-9))
	var s := ShipState.new()
	s.pos = pos
	s.vel = st["vel"] + Vector2(0.4, -0.3)
	var inp := ShipInput.new()
	inp.drift_sync = true
	var steps := 120
	for i in steps:
		s = ShipFlight.step(s, inp, i * DT, DT)
	var end := AsteroidField.state(BAND, boulder, steps * DT)
	assert_lt(s.vel.distance_to(end["vel"]), 0.1, "relative velocity to the boulder is zeroed")
	assert_gt(s.fuel_sync, 0.0)


func test_live_and_snapshot_queries_return_identical_boulder_entries() -> void:
	var ring := _ring_setup()
	Tuning.planet.ring_boulders_per_chunk = 4.0
	var pos: Vector2 = Vector2.from_angle(1.1) * (ring["radius"] as float)
	var snap := AsteroidField.near(pos, 0.0, 3000.0)
	var live := ShipFlight._asteroids(pos, 5.0, 1500.0, null, {})
	var snapped := ShipFlight._asteroids(pos, 5.0, 1500.0, snap, {})
	assert_gt(live.size(), 0, "boulders around the ring radius")
	assert_eq(live.size(), snapped.size())
	for i in live.size():
		for f in ["key", "pos", "vel", "radius", "points", "rot", "type", "amount"]:
			assert_eq(live[i][f], snapped[i][f], f)
		assert_eq(live[i]["type"], &"ore_middle")
		assert_eq(live[i]["key"].x, BAND)
		if i > 0:
			assert_true(ShipFlight._key_less(live[i - 1], live[i]))
	var key: Vector3i = live[0]["key"]
	var broken := {key: true}
	for a in ShipFlight._asteroids(pos, 5.0, 1500.0, null, broken):
		assert_ne(a["key"], key, "a broken boulder is dropped by key")
	for a in ShipFlight._asteroids(pos, 5.0, 1500.0, snap, broken):
		assert_ne(a["key"], key, "a broken boulder is dropped by key")
