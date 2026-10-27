class_name FreeBody
extends RefCounted

var pos: Vector2
var vel: Vector2
var radius: float
var points := PackedVector2Array()
var type: StringName
var amount: float
var id


static func integrate(b: FreeBody, t: float, dt: float) -> void:
	b.vel += (GravityField.accel(b.pos, t) + GravityField.frame_accel(b.pos, b.vel)) * dt
	b.pos += b.vel * dt


func copy() -> FreeBody:
	var c := FreeBody.new()
	c.pos = pos
	c.vel = vel
	c.radius = radius
	c.points = points.duplicate()
	c.type = type
	c.amount = amount
	c.id = id
	return c
