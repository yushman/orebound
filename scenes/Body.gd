extends Node2D

const MOON_SCALE := 0.6
const DISC_RADIUS := 12.0
const DISC_POINTS := 32
const MOON_COLOR := Color(0.7, 0.85, 1.0)

@export var index: int = 0

@onready var _visual: Polygon2D = $Visual


func _ready() -> void:
	if index > 0:
		_visual.color = MOON_COLOR
		var pts := PackedVector2Array()
		for k in DISC_POINTS:
			pts.append(Vector2.from_angle(TAU * k / DISC_POINTS) * DISC_RADIUS)
		_visual.polygon = pts


func _physics_process(_delta: float) -> void:
	visible = index < Tuning.field.bodies.size()
	if visible:
		position = GravityField.body_pos(index, GravityField.time())


func _process(_delta: float) -> void:
	var vp := get_viewport()
	var cam := vp.get_camera_2d() if vp != null else null
	var s := 1.0 / cam.zoom.x if cam != null else 1.0
	var bodies := Tuning.field.bodies
	var radius: float = bodies[index].radius if index < bodies.size() else 0.0
	var k := visual_scale(index, s, radius)
	_visual.scale = Vector2(k, k)


## Marker scale for semantic zoom s: constant screen size, smaller for moons;
## a moon with a world radius is a disc of that radius at any zoom.
static func visual_scale(i: int, s: float, radius := 0.0) -> float:
	if i > 0 and radius > 0.0:
		return radius / DISC_RADIUS
	return s if i == 0 else s * MOON_SCALE
