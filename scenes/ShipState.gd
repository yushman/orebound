class_name ShipState
extends RefCounted

var pos: Vector2
var vel: Vector2
var rot: float
var ang_vel: float
var fuel_engine: float
var fuel_boost: float
var fuel_soft_brake: float
var hold_time: float
var heat: float
var fuel_sync: float


func copy() -> ShipState:
	var c := ShipState.new()
	c.pos = pos
	c.vel = vel
	c.rot = rot
	c.ang_vel = ang_vel
	c.fuel_engine = fuel_engine
	c.fuel_boost = fuel_boost
	c.fuel_soft_brake = fuel_soft_brake
	c.hold_time = hold_time
	c.heat = heat
	c.fuel_sync = fuel_sync
	return c
