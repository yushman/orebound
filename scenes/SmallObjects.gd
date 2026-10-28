class_name SmallObjects
extends RefCounted


static func update(s: ShipState, t: float, dt: float) -> void:
	var pl: PlanetParams = Tuning.planet
	var kept: Array[FreeBody] = []
	for b in s.bodies:
		FreeBody.integrate(b, t, dt)
		if b.piece:
			if b.radius0 <= 0.0:
				b.radius0 = b.radius
			var life: float = pl.piece_lifetime * maxf(1.0, b.radius0 / pl.collect_radius)
			var old_age := b.age
			b.age += dt
			if b.age >= life:
				continue
			_shrink(b, old_age, life, pl.piece_min_radius)
		elif b.container:
			b.age += dt
		if (b.container or b.pos.distance_to(s.pos) <= pl.piece_despawn_radius) and not _blocked(b.pos, t):
			kept.append(b)
	s.bodies = kept


static func _shrink(b: FreeBody, old_age: float, life: float, min_radius: float) -> void:
	if b.radius0 <= min_radius:
		return
	var drop := 1.0 - pow(min_radius / b.radius0, 2)
	var f := (1.0 - drop * b.age / life) / (1.0 - drop * old_age / life)
	var g := sqrt(f)
	b.amount *= f
	b.radius *= g
	var pts := b.points
	for i in pts.size():
		pts[i] *= g
	b.points = pts


static func _blocked(pos: Vector2, t: float) -> bool:
	if pos.length() < Tuning.field.atmosphere_edge:
		return true
	for i in range(1, Tuning.field.bodies.size()):
		var radius: float = Tuning.field.bodies[i].radius
		if radius > 0.0 and pos.distance_to(GravityField.body_pos(i, t)) < radius:
			return true
	return false
