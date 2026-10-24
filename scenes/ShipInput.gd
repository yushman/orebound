class_name ShipInput
extends RefCounted

var turn: float
var has_heading: bool
var target_heading: float
var thrust: bool
var boost: bool
var soft_brake: bool
var drift_sync: bool


## Gamepad stick heading in world axes: the camera rotates by
## FlightCamera.rotation_for(pos), so stick-up means screen-up.
static func screen_heading(stick: Vector2, pos: Vector2) -> float:
	return wrapf(stick.angle() + PI / 2 + FlightCamera.rotation_for(pos), -PI, PI)


func copy() -> ShipInput:
	var c := ShipInput.new()
	c.turn = turn
	c.has_heading = has_heading
	c.target_heading = target_heading
	c.thrust = thrust
	c.boost = boost
	c.soft_brake = soft_brake
	c.drift_sync = drift_sync
	return c
