class_name CarrierView
extends Node2D

const CARRIER_LENGTH := 240.0
const MIN_PX := 24.0
const HALF_W := 40.0
const HANGAR_W := 24.0
const HANGAR_D := 22.0
const LIGHT_R := 4.0
const CONTOUR_PX := 2.0
const HUD_SCRIPT := preload("res://ui/HUD.gd")

var ship: Node


static func scale_for(s: float) -> float:
	return maxf(1.0, MIN_PX * s / CARRIER_LENGTH)


static func contour_color(s: ShipState) -> Color:
	return HUD_SCRIPT.reserve_color(HUD_SCRIPT.ship_reserve(s))


func _ready() -> void:
	ship = get_node_or_null("../Ship")


func _process(_delta: float) -> void:
	queue_redraw()
	refresh(GravityField.time(), _world_per_px())


func refresh(t: float, s: float) -> void:
	position = ShipFlight.carrier_pos(t)
	rotation = ShipFlight.carrier_angle(t) + PI / 2.0
	scale = Vector2.ONE * scale_for(s)


func _world_per_px() -> float:
	var vp := get_viewport()
	var cam := vp.get_camera_2d() if vp != null else null
	return 1.0 / cam.zoom.x if cam != null else 1.0


func _draw() -> void:
	var h := CARRIER_LENGTH * 0.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(-h, -HALF_W * 0.6), Vector2(h * 0.8, -HALF_W), Vector2(h, -HALF_W * 0.4),
		Vector2(h, HALF_W * 0.4), Vector2(h * 0.8, HALF_W), Vector2(-h, HALF_W * 0.6)]), Palette.HULL_SHADE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-h, -HALF_W * 0.6), Vector2(h * 0.8, -HALF_W), Vector2(h, -HALF_W * 0.4),
		Vector2(h, 0), Vector2(-h, 0)]), Palette.HULL)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-HANGAR_W, HALF_W), Vector2(-HANGAR_W * 0.6, HALF_W - HANGAR_D),
		Vector2(HANGAR_W * 0.6, HALF_W - HANGAR_D), Vector2(HANGAR_W, HALF_W)]), Palette.BACKGROUND)
	for x in [-h * 0.7, -h * 0.35, h * 0.35, h * 0.7]:
		draw_circle(Vector2(x, 0.0), LIGHT_R, Palette.SAFE)
	if ship == null:
		return
	var pts := PackedVector2Array([
		Vector2(-h, -HALF_W * 0.6), Vector2(h * 0.8, -HALF_W), Vector2(h, -HALF_W * 0.4),
		Vector2(h, HALF_W * 0.4), Vector2(h * 0.8, HALF_W), Vector2(-h, HALF_W * 0.6)])
	pts.append(pts[0])
	draw_polyline(pts, contour_color(ship.state), CONTOUR_PX / maxf(scale.x * get_canvas_transform().get_scale().x, 1e-6))
