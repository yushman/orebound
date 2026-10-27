class_name Split
extends RefCounted


static func pieces(parent: FreeBody, n: int, scatter: float, spread: float, divisor: float) -> Array[FreeBody]:
	var out: Array[FreeBody] = []
	var rad := parent.radius / sqrt(divisor * n)
	var offset := spread * sqrt(AsteroidField._area(parent.points) / PI)
	for i in n:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([parent.id, i])
		var phase := rng.randf() * TAU
		var dir := Vector2.from_angle(float(i) / n * TAU + phase)
		var b := FreeBody.new()
		b.radius = rad
		b.radius0 = rad
		b.points = AsteroidField._hull(rng, rad)
		b.pos = parent.pos + dir * offset
		b.vel = parent.vel + dir * scatter
		b.type = parent.type
		b.amount = parent.amount / n
		b.id = hash([parent.id, i, "piece"])
		b.piece = true
		b.age = 0.0
		out.append(b)
	return out
