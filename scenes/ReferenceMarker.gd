extends Node2D

# Ring size is a constant SCREEN value: world radius = px / semantic zoom s.
const RING_PX := 28.0
const RING_STROKE_PX := 2.0

@onready var ship: Node2D = get_node("../Ship")


func _physics_process(_delta: float) -> void:
	var t := GravityField.time()
	visible = ShipFlight.sync_reference(ship.state.pos, t)["valid"]
	if visible:
		position = marker_pos(ship.state.pos, t)
	queue_redraw()


## World ring radius that renders as RING_PX screen pixels at semantic zoom s.
static func screen_radius(s: float) -> float:
	return RING_PX / s


func marker_pos(pos: Vector2, t: float) -> Vector2:
	var ref := ShipFlight.sync_reference(pos, t)
	if ref["is_carrier"]:
		return Vector2(Tuning.field.carrier_orbit_radius, 0.0)
	return GravityField.body_pos(int(ref["index"]), t)


func alpha_for(drift_sync: bool) -> float:
	return 1.0 if drift_sync else 0.35


func _camera_zoom() -> float:
	var vp := get_viewport()
	var cam := vp.get_camera_2d() if vp != null else null
	return cam.zoom.x if cam != null else 1.0


func _draw() -> void:
	var s := 1.0 / _camera_zoom()
	draw_arc(Vector2.ZERO, screen_radius(s), 0.0, TAU, 48,
			Color(1.0, 1.0, 1.0, alpha_for(ship.input.drift_sync)),
			RING_STROKE_PX / s)
