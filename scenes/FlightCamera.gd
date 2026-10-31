class_name FlightCamera
extends Camera2D
## Local-vertical camera (D35): pure math + node behavior. View-only — never
## writes to ship state.

const ZOOM_MIN := 1.0
const ZOOM_MAX := 40.0
const ZOOM_CONTINUOUS_MAX := 8.0
# Stops above the continuous zone; on a tie the larger stop wins (36 -> 40).
const ZOOM_STOPS := [10.0, 15.0, 22.0, 32.0, 40.0]
# Step factor sized so clamp+discretize reach every stop in both directions
# (8 -> 10 -> 15 -> 22 -> 32 -> 40 up, 40 -> 32 -> 22 -> 15 -> 10 -> continuous
# down).
const ZOOM_STEP := 1.3
const ZOOM_SMOOTH := 10.0

@onready var ship: Node2D = get_node("../Ship")

var _target_zoom := 1.0
var _zoom_current := 1.0
var manual_left := 0.0
var _speed_avg := 0.0


## Screen-down axis points at the planet center from any position; the angle
## is wrapped into [-PI, PI] like the rest of the game's angles.
static func rotation_for(pos: Vector2) -> float:
	return wrapf(pos.angle() + PI / 2.0, -PI, PI)


## Semantic zoom s shows s times more world per screen; Camera2D.zoom > 1
## zooms in, so the mapping is inverse.
static func zoom_vector(s: float) -> Vector2:
	return Vector2(1.0 / s, 1.0 / s)


static func clamp_zoom(z: float) -> float:
	return clampf(z, ZOOM_MIN, ZOOM_MAX)


static func discretize_zoom(z: float) -> float:
	if z <= ZOOM_CONTINUOUS_MAX:
		return z
	var best: float = ZOOM_STOPS[0]
	for stop: float in ZOOM_STOPS:
		if absf(z - stop) <= absf(z - best):
			best = stop
	return best


static func auto_zoom(speed: float) -> float:
	var v: ViewParams = Tuning.view
	var f := clampf(inverse_lerp(v.autoscale_speed_low, v.autoscale_speed_high, speed), 0.0, 1.0)
	return lerpf(1.0, v.autoscale_max, f)


static func smooth_speed(avg: float, speed: float, delta: float) -> float:
	return lerpf(avg, speed, 1.0 - exp(-delta / maxf(Tuning.view.autoscale_speed_tau, 1e-6)))


static func ease_zoom(current: float, target: float, k: float, delta: float) -> float:
	return lerpf(current, target, 1.0 - exp(-k * delta))


func _ready() -> void:
	ignore_rotation = false


func on_zoom_press(dir: int) -> void:
	if manual_left <= 0.0:
		Telemetry.autoscale_overrides += 1
	manual_left = Tuning.view.autoscale_override_time
	var factor := ZOOM_STEP if dir > 0 else 1.0 / ZOOM_STEP
	_target_zoom = discretize_zoom(clamp_zoom(_zoom_current * factor))


func rel_speed() -> float:
	var st: ShipState = ship.state
	var t := GravityField.time()
	var ref := ShipFlight.sync_reference(st.pos, t, null, st.broken)
	if ref["valid"]:
		return (st.vel - ShipFlight.reference_vel(ref, t)).length()
	return (st.vel - ShipFlight.band_drift_vel(st.pos, st.vel, t)).length()


func update(delta: float) -> void:
	_speed_avg = smooth_speed(_speed_avg, rel_speed(), delta)
	if manual_left > 0.0:
		if _target_zoom < ZOOM_CONTINUOUS_MAX:
			manual_left = maxf(manual_left - delta, 0.0)
		_zoom_current = ease_zoom(_zoom_current, _target_zoom, ZOOM_SMOOTH, delta)
	else:
		var target := auto_zoom(_speed_avg)
		_zoom_current = ease_zoom(_zoom_current, target, Tuning.view.autoscale_smooth, delta)
	zoom = zoom_vector(_zoom_current)
	position = ship.position
	rotation = rotation_for(ship.position)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("camera_zoom_in"):
		on_zoom_press(-1)
	if Input.is_action_just_pressed("camera_zoom_out"):
		on_zoom_press(1)
	update(delta)
