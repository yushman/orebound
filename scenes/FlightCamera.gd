class_name FlightCamera
extends Camera2D
## Local-vertical camera (D35): pure math + node behavior. View-only — never
## writes to ship state.

const ZOOM_MIN := 1.0
const ZOOM_MAX := 40.0
const ZOOM_CONTINUOUS_MAX := 22.0
# Stops above the continuous zone; on a tie the larger stop wins (31 -> 34).
const ZOOM_STOPS := [28.0, 34.0, 40.0]
# Step factor sized so clamp+discretize reach every stop in both directions
# (22 -> 28 -> 34 -> 40 up, 40 -> 28 -> continuous down).
const ZOOM_STEP := 1.3
const ZOOM_SMOOTH := 10.0

@onready var ship: Node2D = get_node("../Ship")
# Visual icon child of the ship; scaled to keep a constant screen size.
# View-only: the flight state and the collision shape are never touched.
@onready var _ship_icon: Node2D = ship.get_node_or_null("Visual")

var _target_zoom := 1.0
var _zoom_current := 1.0


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


func _ready() -> void:
	ignore_rotation = false


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("camera_zoom_in"):
		_target_zoom = discretize_zoom(clamp_zoom(_target_zoom / ZOOM_STEP))
	if Input.is_action_just_pressed("camera_zoom_out"):
		_target_zoom = discretize_zoom(clamp_zoom(_target_zoom * ZOOM_STEP))
	_zoom_current = lerpf(_zoom_current, _target_zoom, 1.0 - exp(-ZOOM_SMOOTH * delta))
	zoom = zoom_vector(_zoom_current)
	if _ship_icon != null:
		_ship_icon.scale = Vector2(_zoom_current, _zoom_current)
	position = ship.position
	rotation = rotation_for(ship.position)
