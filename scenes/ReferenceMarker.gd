extends Node2D

const FlightVectorScript = preload("res://scenes/FlightVector.gd")

# Ring size is a constant SCREEN value: world radius = px * semantic zoom s.
const RING_PX := 28.0
const RING_STROKE_PX := 2.0
# The speed chevron of the reference rides on the ring: the back edge on the
# ring (28 px), the tip 5 px further out, the |v| label 24 px past the tip
# (57 px from the centre). It shows only on a close view (semantic zoom s < 15).
const CHEVRON_ZOOM_LIMIT := 15.0

@onready var ship: Node2D = get_node("../Ship")

# The current sync reference and its own velocity (the speed the ship would
# be dragged to by the sync).
var reference: Dictionary = {}
var reference_vel: Vector2 = Vector2.ZERO


func _physics_process(_delta: float) -> void:
	var t := GravityField.time()
	update_reference(ShipFlight.sync_reference(ship.state.pos, t, null, ship.state.broken), t)
	queue_redraw()


## Take the sync reference: the ring sits on it and the chevron shows its own
## velocity (the speed the ship would sync to).
func update_reference(ref: Dictionary, t: float) -> void:
	visible = ref["valid"]
	reference = ref
	reference_vel = ShipFlight.reference_vel(ref, t)
	if visible:
		position = marker_pos(ref, t)


## World ring radius that renders as RING_PX screen pixels at semantic zoom s.
static func screen_radius(s: float) -> float:
	return RING_PX * s


func marker_pos(ref: Dictionary, t: float) -> Vector2:
	if not ref["asteroid"].is_empty():
		return ref["asteroid"]["pos"]
	if ref["is_carrier"]:
		return ShipFlight.carrier_pos(t)
	return GravityField.body_pos(int(ref["index"]), t)


func alpha_for(drift_sync: bool) -> float:
	return 1.0 if drift_sync else 0.35


func marker_color(drift_sync: bool) -> Color:
	return Color(Palette.HALO, alpha_for(drift_sync))


## The reference chevron: the back edge on the ring, the tip 5 px further out,
## 12 px across (the shared FlightVector geometry).
static func chevron_lines(vel: Vector2, s: float) -> Array[PackedVector2Array]:
	return FlightVectorScript.chevron_lines_at(Vector2.ZERO, vel, s, RING_PX)


## The |v| label anchor: 24 px past the chevron tip (57 px from the centre).
static func chevron_label_pos(vel: Vector2, s: float) -> Vector2:
	return FlightVectorScript.label_pos_at(Vector2.ZERO, vel, s, RING_PX)


## The chevron shows only on a close view and only for a moving reference.
static func chevron_visible(s: float, vel: Vector2, has_ref: bool) -> bool:
	if not has_ref:
		return false
	if s >= CHEVRON_ZOOM_LIMIT:
		return false
	return FlightVectorScript.vector_visible(vel)


## The chevron colour: the same HALO chevron as on the ship.
static func chevron_color() -> Color:
	return FlightVectorScript.COLOR


## The label rotation: the camera's own rotation (the camera follows the
## ship), so the glyphs stand upright in the camera's frame.
static func label_rotation(cam_pos: Vector2) -> float:
	return FlightCamera.rotation_for(cam_pos)


func _camera_zoom() -> float:
	var vp := get_viewport()
	var cam := vp.get_camera_2d() if vp != null else null
	return cam.zoom.x if cam != null else 1.0


func _draw() -> void:
	var s := 1.0 / _camera_zoom()
	draw_arc(Vector2.ZERO, screen_radius(s), 0.0, TAU, 48,
			marker_color(ship.input.drift_sync),
			RING_STROKE_PX * s)
	_draw_chevron(s)


## The speed chevron of the reference: the speed the ship would be dragged to
## by the sync, drawn on the ring, close view only.
func _draw_chevron(s: float) -> void:
	var vel := reference_vel
	if not chevron_visible(s, vel, visible):
		return
	var stroke := FlightVectorScript.screen_px(FlightVectorScript.STROKE_PX, s)
	for seg in chevron_lines(vel, s):
		draw_line(seg[0], seg[1], chevron_color(), stroke)
	_draw_label(vel, s)


## The |v| label past the chevron tip: the shared draw helper keeps it
## screen-constant and upright. The compensation is against the CAMERA's
## rotation (the camera follows the ship), not against the angle of the
## reference around the planet — otherwise the glyphs stand tilted.
func _draw_label(vel: Vector2, s: float) -> void:
	var vp := get_viewport()
	var cam := vp.get_camera_2d() if vp != null else null
	var cam_pos := cam.position if cam != null else Vector2.ZERO
	var world_pos := global_position + chevron_label_pos(vel, s)
	var rot := label_rotation(cam_pos)
	FlightVectorScript.draw_label_at(self, world_pos,
			str(FlightVectorScript.chevron_label(vel)), chevron_color(),
			_camera_zoom(), s, rot, cam_pos)
