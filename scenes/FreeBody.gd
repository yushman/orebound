class_name FreeBody
extends RefCounted

var pos: Vector2
var vel: Vector2
var radius: float
var radius0 := 0.0
var points := PackedVector2Array()
var type: StringName
var amount: float
var id
var piece := false
var container := false
var age := 0.0
var pull_speed := 0.0


static func integrate(b: FreeBody, t: float, dt: float) -> void:
	b.vel += (GravityField.accel(b.pos, t) + GravityField.frame_accel(b.pos, b.vel)) * dt
	b.pos += b.vel * dt


func copy() -> FreeBody:
	var c := FreeBody.new()
	c.pos = pos
	c.vel = vel
	c.radius = radius
	c.radius0 = radius0
	c.points = points.duplicate()
	c.type = type
	c.amount = amount
	c.id = id
	c.piece = piece
	c.container = container
	c.age = age
	c.pull_speed = pull_speed
	return c
