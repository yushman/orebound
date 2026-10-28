class_name LongPress
extends RefCounted

enum Event { NONE, TAP, FIRE, CANCEL }

const CANCEL_WINDOW := 1.0

var tap_time: float
var hold_time: float
var interval: float

var _held := 0.0
var _down := false
var _fired := false
var _next_fire := 0.0


func _init(p_tap_time: float = 0.7, p_hold_time: float = 2.0, p_interval: float = 0.7) -> void:
	tap_time = p_tap_time
	hold_time = p_hold_time
	interval = p_interval


func update(pressed: bool, dt: float) -> Event:
	if pressed:
		if not _down:
			_down = true
			_held = 0.0
			_fired = false
			_next_fire = hold_time
		_held += dt
		if _held >= _next_fire - 1e-6:
			_fired = true
			_next_fire += interval
			return Event.FIRE
		return Event.NONE
	if not _down:
		return Event.NONE
	_down = false
	if _fired:
		return Event.NONE
	if _held < tap_time - 1e-6:
		return Event.TAP
	if _held < minf(tap_time + CANCEL_WINDOW, hold_time) - 1e-6:
		return Event.CANCEL
	return Event.NONE
