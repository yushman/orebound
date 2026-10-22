class_name ShipInput
extends RefCounted

var turn: float
var has_heading: bool
var target_heading: float
var thrust: bool
var boost: bool
var brake: bool


func copy() -> ShipInput:
	var c := ShipInput.new()
	c.turn = turn
	c.has_heading = has_heading
	c.target_heading = target_heading
	c.thrust = thrust
	c.boost = boost
	c.brake = brake
	return c
