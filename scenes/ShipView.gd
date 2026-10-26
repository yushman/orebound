class_name ShipView
extends Node2D

const FLAME_BASE := 24.0
const FLAME_BOOST := 1.6
const GLOW_FAINT := 0.15
const NOZZLE_Y := 8.0
const FLAME_HALF_WIDTH := 4.0
const GLOW_RADIUS := 5.0
const GLOW_SEGMENTS := 16
const GLOW_SCALE_MIN := 0.6
const GLOW_SCALE_MAX := 1.8

var flame := Polygon2D.new()
var glow := Polygon2D.new()

@onready var _ship: Node = get_parent()


func _ready() -> void:
	(get_node("Hull") as Polygon2D).color = Palette.HULL
	(get_node("WingLeft") as Polygon2D).color = Palette.HULL_SHADE
	(get_node("WingRight") as Polygon2D).color = Palette.HULL_SHADE
	flame.name = "Flame"
	flame.color = Palette.DANGER
	add_child(flame)
	move_child(flame, 0)
	glow.name = "Glow"
	glow.position = Vector2(0.0, NOZZLE_Y)
	var ring := PackedVector2Array()
	for i in GLOW_SEGMENTS:
		ring.append(Vector2.RIGHT.rotated(TAU * i / GLOW_SEGMENTS) * GLOW_RADIUS)
	glow.polygon = ring
	add_child(glow)


func _process(_delta: float) -> void:
	var engine_off: bool = _ship.input.soft_brake or _ship.input.drift_sync
	var length := flame_length(_ship.input.thrust and not engine_off, _ship.input.boost and not engine_off, _ship.state.hold_time, _ship.state.heat, Tuning.ship)
	flame.visible = length > 0.0
	var heat: float = _ship.state.heat
	var alpha := glow_alpha(heat, Tuning.ship)
	glow.color = Color(Palette.DANGER, alpha)
	glow.visible = alpha > 0.0
	glow.scale = Vector2.ONE * lerpf(GLOW_SCALE_MIN, GLOW_SCALE_MAX, clampf(heat, 0.0, 1.0))
	if length > 0.0:
		flame.polygon = PackedVector2Array([
			Vector2(-FLAME_HALF_WIDTH, NOZZLE_Y),
			Vector2(FLAME_HALF_WIDTH, NOZZLE_Y),
			Vector2(0.0, NOZZLE_Y + length),
		])


static func flame_length(thrust: bool, boost: bool, hold_time: float, heat: float, p: ShipParams) -> float:
	if not (thrust or boost):
		return 0.0
	var scale := lerpf(p.ramp_min_fraction, 1.0, clampf(hold_time / p.ramp_time, 0.0, 1.0))
	if heat > p.heat_threshold:
		scale *= lerpf(1.0, p.min_thrust_fraction, (heat - p.heat_threshold) / (1.0 - p.heat_threshold))
	if boost:
		scale *= FLAME_BOOST
	return FLAME_BASE * scale


static func glow_alpha(heat: float, p: ShipParams) -> float:
	var h := clampf(heat, 0.0, 1.0)
	if h <= p.heat_threshold:
		return GLOW_FAINT * h / p.heat_threshold
	return lerpf(GLOW_FAINT, 1.0, (h - p.heat_threshold) / (1.0 - p.heat_threshold))

