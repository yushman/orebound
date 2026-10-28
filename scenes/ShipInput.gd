class_name ShipInput
extends RefCounted

var turn: float
var has_heading: bool
var target_heading: float
var thrust: bool
var boost: bool
var soft_brake: bool
var drift_sync: bool
var beam: bool
var collect: bool
var jettison: bool
var jettison_select: bool
var aim: float


## Gamepad stick heading in world axes: the camera rotates by
## FlightCamera.rotation_for(pos), so stick-up means screen-up.
static func screen_heading(stick: Vector2, pos: Vector2) -> float:
	return wrapf(stick.angle() + PI / 2 + FlightCamera.rotation_for(pos), -PI, PI)


## Beam aim in world angle: right stick (screen-relative), else the mouse
## world point while LMB or RMB is held, else the nose.
static func aim_angle(stick: Vector2, mouse_held: bool, mouse_world: Vector2, pos: Vector2, rot: float) -> float:
	if stick != Vector2.ZERO:
		return wrapf(screen_heading(stick, pos) - PI / 2, -PI, PI)
	if mouse_held:
		return (mouse_world - pos).angle()
	return wrapf(rot - PI / 2, -PI, PI)


func copy() -> ShipInput:
	var c := ShipInput.new()
	c.turn = turn
	c.has_heading = has_heading
	c.target_heading = target_heading
	c.thrust = thrust
	c.boost = boost
	c.soft_brake = soft_brake
	c.drift_sync = drift_sync
	c.beam = beam
	c.collect = collect
	c.jettison = jettison
	c.jettison_select = jettison_select
	c.aim = aim
	return c
