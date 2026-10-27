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
var hull: float = Tuning.ship.hull_max
var crashed: bool
var hold: Array[HoldCell] = []
var tank: Array[HoldCell] = []
var mined: Dictionary = {}
var bodies: Array[FreeBody] = []


func _init(with_loadout := true) -> void:
	if with_loadout:
		Hold.add(self, &"fuel", Tuning.ship.loadout_fuel_cells)


func copy() -> ShipState:
	var c := ShipState.new(false)
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
	c.hull = hull
	c.crashed = crashed
	for cell in hold:
		c.hold.append(cell.copy())
	for cell in tank:
		c.tank.append(cell.copy())
	c.mined = mined.duplicate()
	for b in bodies:
		c.bodies.append(b.copy())
	return c
