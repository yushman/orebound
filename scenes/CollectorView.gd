class_name CollectorView
extends Polygon2D

const ARC_POINTS := 16
const ALPHA := 0.25


func _init() -> void:
	color = Color(Palette.FUEL, ALPHA)
	visible = false


func _process(_delta: float) -> void:
	var ship := get_node_or_null("../Ship")
	if ship == null:
		visible = false
		return
	refresh(ship.state, ship.input)


func refresh(state: ShipState, input: ShipInput) -> void:
	visible = input.collect
	if not input.collect:
		return
	var r := Tuning.ship.beam_range * 0.5
	var half := deg_to_rad(Tuning.ship.collect_angle) * 0.5
	var pts := PackedVector2Array([state.pos])
	for i in ARC_POINTS + 1:
		pts.append(state.pos + Vector2.RIGHT.rotated(input.aim - half + 2.0 * half * i / ARC_POINTS) * r)
	polygon = pts
