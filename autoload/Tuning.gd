extends Node

var field: FieldParams = _default_field()


func _default_field() -> FieldParams:
	var f := FieldParams.new()
	f.k = 1000.0
	f.eps = 1.0
	f.fade_width = 0.5
	var planet := BodyParams.new()
	planet.mass = 1000.0
	planet.p = 1.0
	var bodies: Array[BodyParams] = [planet]
	for spec in [[250.0, 0.6, 0.0], [400.0, -0.4, PI]]:
		var m := BodyParams.new()
		m.mass = 100.0
		m.p = 2.0
		m.influence_radius = 80.0
		m.parent = 0
		m.orbit_radius = spec[0]
		m.angular_speed = spec[1]
		m.phase = spec[2]
		bodies.append(m)
	f.bodies = bodies
	return f
