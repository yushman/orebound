class_name ShipState
extends RefCounted

var pos: Vector2
var vel: Vector2
var rot: float
var ang_vel: float
var fuel_engine: float
var fuel_boost: float


func copy() -> ShipState:
	var c := ShipState.new()
	c.pos = pos
	c.vel = vel
	c.rot = rot
	c.ang_vel = ang_vel
	c.fuel_engine = fuel_engine
	c.fuel_boost = fuel_boost
	return c
