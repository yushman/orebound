class_name SmallObjects
extends RefCounted


static func spawn(event: Dictionary, ship_pos: Vector2, t: float) -> FreeBody:
	var pos: Vector2 = ship_pos + Vector2.RIGHT.rotated(event["angle"]) * Tuning.planet.small_spawn_radius
	if _blocked(pos, t):
		return null
	var rel := pos - GravityField.body_pos(0, t)
	var r := rel.length()
	var gm := r * r * GravityField.accel_of(0, pos, t).length()
	var e: float = event["e"]
	var nu: float = event["nu"]
	var k := sqrt(gm / (r * (1.0 + e * cos(nu))))
	var radial := rel / r
	var tangent := Vector2(-radial.y, radial.x)
	var v_in := radial * (k * e * sin(nu)) + tangent * (k * (1.0 + e * cos(nu)))
	var b := FreeBody.new()
	b.pos = pos
	b.vel = v_in - GravityField.frame_omega() * Vector2(-pos.y, pos.x)
	b.radius = event["radius"]
	b.points = event["points"]
	b.type = event["type"]
	b.amount = event["amount"]
	b.id = event["id"]
	return b


static func update(s: ShipState, t: float, dt: float) -> void:
	var pl: PlanetParams = Tuning.planet
	var tier := WellGenerator.tier_of(s.pos.length())
	var first := int(floor((t - dt) / pl.small_window))
	var last := int(floor(t / pl.small_window))
	for w in range(first, last + 1):
		for ev in SmallObjectSchedule.schedule(Tuning.picture["seed"], Tuning.picture["flight"], tier, w):
			if ev["time"] <= t - dt or ev["time"] > t:
				continue
			if s.bodies.size() >= pl.small_max_bodies:
				break
			if _has(s, ev["id"]):
				continue
			var b := spawn(ev, s.pos, t)
			if b != null:
				s.bodies.append(b)
	var kept: Array[FreeBody] = []
	for b in s.bodies:
		FreeBody.integrate(b, t, dt)
		if b.pos.distance_to(s.pos) <= pl.small_despawn_radius and not _blocked(b.pos, t):
			kept.append(b)
	s.bodies = kept


static func _has(s: ShipState, id) -> bool:
	for b in s.bodies:
		if b.id == id:
			return true
	return false


static func _blocked(pos: Vector2, t: float) -> bool:
	if pos.length() < Tuning.field.atmosphere_edge:
		return true
	for i in range(1, Tuning.field.bodies.size()):
		var radius: float = Tuning.field.bodies[i].radius
		if radius > 0.0 and pos.distance_to(GravityField.body_pos(i, t)) < radius:
			return true
	return false
