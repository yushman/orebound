extends Node

const DT := 1.0 / 60.0

var tick: int = 0


func time_at(n: int) -> float:
	return n / 60.0


func time() -> float:
	return time_at(tick)


func _physics_process(_delta: float) -> void:
	tick += 1


func body_pos(i: int, t: float) -> Vector2:
	var b: BodyParams = Tuning.field.bodies[i]
	var origin := Vector2.ZERO if b.parent < 0 else body_pos(b.parent, t)
	var a := b.phase + (b.angular_speed - frame_omega()) * t
	return origin + Vector2(cos(a), sin(a)) * b.orbit_radius


func accel(pos: Vector2, t: float) -> Vector2:
	var sum := Vector2.ZERO
	for i in Tuning.field.bodies.size():
		sum += accel_of(i, pos, t)
	return sum


func accel_of(i: int, pos: Vector2, t: float) -> Vector2:
	var f: FieldParams = Tuning.field
	var b: BodyParams = f.bodies[i]
	var d := body_pos(i, t) - pos
	var r := d.length()
	if r == 0.0:
		return Vector2.ZERO
	return d / r * (f.k * b.mass / (pow(r, b.p) + f.eps)) * _fade(b, f.fade_width, r)


func potential(pos: Vector2, t: float) -> float:
	var f: FieldParams = Tuning.field
	var sum := 0.0
	for i in f.bodies.size():
		var b: BodyParams = f.bodies[i]
		var r := (pos - body_pos(i, t)).length()
		sum += _phi_body(b, f.k * b.mass, f.fade_width, r)
	return sum


func potential_eff(pos: Vector2, t: float) -> float:
	var om := frame_omega()
	return potential(pos, t) - 0.5 * om * om * pos.length_squared()


func planet_potential_eff(r: float) -> float:
	var f: FieldParams = Tuning.field
	var b: BodyParams = f.bodies[0]
	var om := frame_omega()
	return _phi_body(b, f.k * b.mass, f.fade_width, r) - 0.5 * om * om * r * r


func _phi_raw(km: float, p: float, r: float) -> float:
	if absf(p - 1.0) < 1e-4:
		return km * log(r)
	return -km * pow(r, 1.0 - p) / (p - 1.0)


func _fade(b: BodyParams, w: float, r: float) -> float:
	if b.influence_radius <= 0.0:
		return 1.0
	var x := clampf((r - b.influence_radius) / (b.influence_radius * w), 0.0, 1.0)
	return 1.0 - x * x * (3.0 - 2.0 * x)


func _phi_body(b: BodyParams, km: float, w: float, r: float) -> float:
	var big_r := b.influence_radius
	if big_r <= 0.0:
		return _phi_raw(km, b.p, r)
	var outer := big_r * (1.0 + w)
	if r >= outer:
		return 0.0
	if r > big_r:
		return -_fade_integral(b, km, w, r, outer)
	return _phi_raw(km, b.p, r) - _phi_raw(km, b.p, big_r) - _fade_integral(b, km, w, big_r, outer)


func _fade_integral(b: BodyParams, km: float, w: float, from: float, to: float) -> float:
	const N := 32
	var h := (to - from) / N
	var sum := 0.0
	for j in N + 1:
		var x := from + h * j
		var wt := 1.0 if j == 0 or j == N else (4.0 if j % 2 == 1 else 2.0)
		sum += wt * km / pow(x, b.p) * _fade(b, w, x)
	return sum * h / 3.0


func dominant(pos: Vector2, t: float) -> int:
	var best := 0
	var best_a := -1.0
	for i in Tuning.field.bodies.size():
		var a := accel_of(i, pos, t).length()
		if a > best_a:
			best_a = a
			best = i
	return best


func body_vel(i: int, t: float) -> Vector2:
	var b: BodyParams = Tuning.field.bodies[i]
	if b.parent < 0:
		return Vector2.ZERO
	var a := b.phase + (b.angular_speed - frame_omega()) * t
	return body_vel(b.parent, t) + Vector2(-sin(a), cos(a)) * (b.orbit_radius * (b.angular_speed - frame_omega()))


func circular_speed(i: int, pos: Vector2, t: float) -> float:
	var r := (pos - body_pos(i, t)).length()
	return sqrt(r * accel_of(i, pos, t).length())


func frame_omega() -> float:
	var f: FieldParams = Tuning.field
	var b: BodyParams = f.bodies[0]
	var rc := f.carrier_orbit_radius
	var g := f.k * b.mass / (pow(rc, b.p) + f.eps) * _fade(b, f.fade_width, rc)
	return sqrt(g / rc)


func frame_accel(pos: Vector2, vel: Vector2) -> Vector2:
	var om := frame_omega()
	return pos * (om * om) - Vector2(-vel.y, vel.x) * (2.0 * om)
