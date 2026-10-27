class_name ShipFlight
extends RefCounted


static func reference_body(pos: Vector2, t: float) -> int:
	return GravityField.dominant(pos, t)


static func sync_reference(pos: Vector2, t: float, snapshot = null, mined := {}) -> Dictionary:
	# candidates: all bodies, the carrier point and asteroids; nearest within sync_radius wins
	var best_d := Tuning.ship.sync_radius
	var index := -1
	var is_carrier := false
	var asteroid := {}
	for i in Tuning.field.bodies.size():
		var d := pos.distance_to(GravityField.body_pos(i, t))
		if d < best_d:
			best_d = d
			index = i
	var d_carrier := pos.distance_to(Vector2(Tuning.field.carrier_orbit_radius, 0.0))
	if d_carrier < best_d:
		index = -1
		is_carrier = true
		best_d = d_carrier
	for a in _asteroids(pos, t, best_d, snapshot, mined):
		var d: float = pos.distance_to(a["pos"])
		if d < best_d:
			best_d = d
			index = -1
			is_carrier = false
			asteroid = {"pos": a["pos"], "vel": a["vel"]}
	return {"valid": index >= 0 or is_carrier or not asteroid.is_empty(), "index": index, "is_carrier": is_carrier, "asteroid": asteroid}


static func atmosphere_density(pos: Vector2) -> float:
	var f: FieldParams = Tuning.field
	var depth := (f.atmosphere_edge - pos.length()) / (f.atmosphere_edge - f.planet_surface_radius)
	return pow(clampf(depth, 0.0, 1.0), Tuning.planet.density_shape)


static func step(state: ShipState, input: ShipInput, t: float, dt: float, snapshot = null) -> ShipState:
	var p: ShipParams = Tuning.ship
	var s := state.copy()
	var ang_acc := input.turn * p.turn_accel
	if input.has_heading:
		ang_acc = clampf(p.heading_gain * wrapf(input.target_heading - s.rot, -PI, PI) - 2.0 * sqrt(p.heading_gain) * s.ang_vel, -p.turn_accel, p.turn_accel)
	s.ang_vel = (s.ang_vel + ang_acc * dt) * exp(-p.spin_damping * dt)
	s.rot = wrapf(s.rot + s.ang_vel * dt, -PI, PI)
	var nose := Vector2.UP.rotated(s.rot)
	var k := p.ref_mass / Hold.mass(s)
	var thr := 0.0
	var a_b := Vector2.ZERO
	var engine := false
	if input.soft_brake:
		# soft brake (D36): half force against velocity, half backwards from the nose
		s.hold_time = 0.0
		a_b = _soft_brake_accel(s.vel, nose, p) * k
		var need := a_b.length() * Hold.mass(s) * dt * Fuel.per_dv() * p.brake_fuel_mult
		var got := Hold.drain(s, need)
		if need > 0.0:
			a_b *= got / need
		s.fuel_soft_brake += got
	elif input.drift_sync:
		# drift sync with the nearest reference (body, carrier or asteroid);
		# no reference within sync_radius: converge to band drift
		s.hold_time = 0.0
		var ref := sync_reference(s.pos, t, snapshot, s.mined)
		if ref["valid"]:
			var v_ref := Vector2.ZERO
			if not ref["asteroid"].is_empty():
				v_ref = ref["asteroid"]["vel"]
			elif not ref["is_carrier"]:
				v_ref = GravityField.body_vel(int(ref["index"]), t)
			a_b = ((v_ref - s.vel) / dt).limit_length(p.sync_accel * k)
		else:
			a_b = _band_drift_accel(s, t, dt, p.sync_accel * k)
		var need := a_b.length() * Hold.mass(s) * dt * Fuel.per_dv() * p.sync_fuel_mult
		var got := Hold.drain(s, need)
		if need > 0.0:
			a_b *= got / need
		s.fuel_sync += got
	elif (input.boost or input.thrust) and Hold.energy(s) > Hold.EPS:
		# thrust ramp (boost inherits): scale grows from ramp_min_fraction to 1 over ramp_time
		engine = true
		s.hold_time += dt
		thr = p.thrust_accel * k * lerpf(p.ramp_min_fraction, 1.0, clampf(s.hold_time / p.ramp_time, 0.0, 1.0))
		# above the heat threshold thrust falls linearly to the minimum at heat = 1
		if s.heat > p.heat_threshold:
			thr *= lerpf(1.0, p.min_thrust_fraction, (s.heat - p.heat_threshold) / (1.0 - p.heat_threshold))
		var mult := 1.0
		if input.boost:
			thr *= p.boost_accel_mult
			mult = p.boost_fuel_mult
			s.heat += p.heat_growth_boost * dt
		else:
			s.heat += p.heat_growth_engine * dt
		var need := thr * Hold.mass(s) * dt * Fuel.per_dv() * mult
		var got := Hold.drain(s, need)
		if need > 0.0:
			thr *= got / need
		if input.boost:
			s.fuel_boost += got
		else:
			s.fuel_engine += got
	else:
		s.hold_time = 0.0
	if not engine:
		s.heat -= p.heat_cooldown * dt
	s.heat = clampf(s.heat, 0.0, 1.0)
	s.vel *= exp(-Tuning.planet.atmosphere_drag * atmosphere_density(s.pos) * dt)
	s.vel += (GravityField.accel(s.pos, t) + GravityField.frame_accel(s.pos, s.vel) + nose * thr + a_b) * dt
	s.pos += s.vel * dt
	var near = null
	if input.beam:
		near = _mine(s, input.aim, t, dt, snapshot)
	_moon_contact(s, t)
	_asteroid_contact(s, t, snapshot, near)
	s.hull = maxf(s.hull - Tuning.planet.atmosphere_damage * atmosphere_density(s.pos) * dt, 0.0)
	s.crashed = s.pos.length() <= Tuning.field.planet_surface_radius or s.hull <= 0.0
	return s


static func _moon_contact(s: ShipState, t: float) -> void:
	var pl: PlanetParams = Tuning.planet
	for i in Tuning.field.bodies.size():
		var radius: float = Tuning.field.bodies[i].radius
		if radius <= 0.0:
			continue
		var center := GravityField.body_pos(i, t)
		var d := s.pos - center
		if d.length() >= radius:
			continue
		var n := d.normalized() if d.length() > 0.0 else Vector2.RIGHT
		s.pos = center + n * radius
		var v_rel := s.vel - GravityField.body_vel(i, t)
		var v_n := v_rel.dot(n)
		_contact(s, n, v_n, pl.moon_bounce, pl.moon_impact_damage)


static func _contact(s: ShipState, n: Vector2, v_n: float, bounce: float, damage: float) -> void:
	if v_n >= 0.0:
		return
	if -v_n < Tuning.planet.rest_speed:
		s.vel -= n * v_n
		return
	s.vel -= n * v_n * (1.0 + bounce)
	s.hull = maxf(s.hull + damage * v_n, 0.0)


static func _asteroids(pos: Vector2, t: float, radius: float, snapshot, mined := {}) -> Array:
	var raw: Array
	var out: Array = []
	if snapshot == null:
		raw = AsteroidField.near(pos, t, radius)
		for a in raw:
			a["key"] = Vector3i(a["band"], a["chunk"], a["idx"])
			a["rot"] = a["omega"] * t
			out.append(a)
	else:
		var d := pos.length()
		var r2 := radius * radius
		for a in snapshot:
			var r: float = a["r"]
			if absf(r - d) > radius:
				continue
			var om: float = a["omega"]
			var ang: float = a["theta"] + om * t
			var ap := Vector2(cos(ang), sin(ang)) * r
			if ap.distance_squared_to(pos) <= r2:
				out.append({"key": Vector3i(a["band"], a["chunk"], a["idx"]), "pos": ap, "vel": om * Vector2(-ap.y, ap.x), "radius": a["radius"], "points": a["points"], "rot": om * t, "type": a["type"], "amount": a["amount"]})
	if not mined.is_empty():
		var layered: Array = []
		for a in out:
			var l := Beam.layer(a, mined)
			if not l.is_empty():
				layered.append(l)
		out = layered
	if out.size() > 1:
		out.sort_custom(_key_less)
	return out


static func _key_less(a: Dictionary, b: Dictionary) -> bool:
	var ka: Vector3i = a["key"]
	var kb: Vector3i = b["key"]
	if ka.x != kb.x:
		return ka.x < kb.x
	if ka.y != kb.y:
		return ka.y < kb.y
	return ka.z < kb.z


static func _mine(s: ShipState, aim: float, t: float, dt: float, snapshot) -> Array:
	var p: ShipParams = Tuning.ship
	var cands := _asteroids(s.pos, t, p.beam_range + maxf(Tuning.planet.ast_radius_min, Tuning.planet.ast_radius_max), snapshot, s.mined)
	var h := Beam.hit(s.pos, aim, p.beam_range, cands)
	if h.is_empty():
		return cands
	for i in cands.size():
		var a: Dictionary = cands[i]
		if a["key"] != h["key"]:
			continue
		var remaining: float = a["amount"]
		var added := Hold.add(s, a["type"], minf(p.beam_rate * dt, remaining))
		if added > 0.0:
			s.mined[h["key"]] = remaining - added
			var left := remaining - added
			if left <= Beam.MIN_REMAINING:
				cands.remove_at(i)
			else:
				a["radius"] = float(a["radius"]) * sqrt(left / remaining)
		break
	return cands


static func _asteroid_contact(s: ShipState, t: float, snapshot = null, near = null) -> void:
	var pl: PlanetParams = Tuning.planet
	if near == null:
		near = _asteroids(s.pos, t, maxf(pl.ast_radius_min, pl.ast_radius_max), snapshot, s.mined)
	for a in near:
		var d: Vector2 = s.pos - a["pos"]
		if d.length() >= a["radius"]:
			continue
		var n := d.normalized() if d.length() > 0.0 else Vector2.RIGHT
		s.pos = a["pos"] + n * a["radius"]
		var v_n: float = (s.vel - a["vel"]).dot(n)
		_contact(s, n, v_n, pl.asteroid_bounce, pl.asteroid_impact_damage)


static func _soft_brake_accel(vel: Vector2, nose: Vector2, p: ShipParams) -> Vector2:
	# near rest only the nose-backwards half is applied
	var half := 0.5 * p.brake_accel
	if vel.length() < 1.0:
		return -nose * half
	return (-vel.normalized() - nose) * half


static func _band_drift_accel(s: ShipState, t: float, dt: float, limit: float) -> Vector2:
	var ref := reference_body(s.pos, t)
	var r_rel := s.pos - GravityField.body_pos(ref, t)
	var body_v := GravityField.body_vel(ref, t)
	var omega := GravityField.frame_omega()
	var v_in := s.vel - body_v + omega * Vector2(-r_rel.y, r_rel.x)
	var cross := r_rel.cross(v_in)
	var spin := 1.0 if absf(cross) < 1e-6 * r_rel.length() * v_in.length() else signf(cross)
	var tangent := Vector2(-r_rel.y, r_rel.x).normalized() * spin
	var v_c := GravityField.circular_speed(ref, s.pos, t)
	var v_target := body_v + tangent * v_c - omega * Vector2(-r_rel.y, r_rel.x)
	return ((v_target - s.vel) / dt).limit_length(limit)
