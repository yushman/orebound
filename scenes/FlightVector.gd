extends Node2D
## Velocity arrow (playtest #3): from ship.state.pos strictly along v-hat of
## the CURRENT velocity (no acceleration term); the shaft is |v| long in
## WORLD units (honest 1:1 speed scale), head and stroke keep a constant
## SCREEN size. View-only — never writes to flight state.

# Playtest-tunable screen sizes; world size = px / semantic zoom s.
const STROKE_PX := 2.0
const HEAD_PX := 8.0
const MIN_SPEED := 1.0
const COLOR := Color(1.0, 1.0, 1.0, 0.85)

@onready var ship: Node2D = get_node("../Ship")


func _process(_delta: float) -> void:
	queue_redraw()


## Unit direction of the velocity (velocity ONLY — no gravity/thrust term).
static func vector_dir(vel: Vector2) -> Vector2:
	return vel.normalized()


## Shaft length in WORLD units — honest 1:1 speed scale (drift 80 u/s = 80).
static func vector_len(vel: Vector2) -> float:
	return vel.length()


## Shaft end = pos + v-hat * |v| (== pos + vel).
static func shaft_end(pos: Vector2, vel: Vector2) -> Vector2:
	return pos + vector_dir(vel) * vector_len(vel)


## Hidden below the speed threshold.
static func vector_visible(vel: Vector2) -> bool:
	return vel.length() >= MIN_SPEED


## World size that renders as `px` screen pixels at semantic zoom s.
static func screen_px(px: float, s: float) -> float:
	return px if s <= 0.0 else px / s


func _draw() -> void:
	var vel: Vector2 = ship.state.vel
	if not vector_visible(vel):
		return
	var s := 1.0 / _camera_zoom()
	var dir := vector_dir(vel)
	var tip: Vector2 = shaft_end(ship.state.pos, vel)
	var head := screen_px(HEAD_PX, s)
	var back := tip - dir * head
	var side := Vector2(-dir.y, dir.x) * head * 0.5
	var stroke := screen_px(STROKE_PX, s)
	draw_line(ship.state.pos, tip, COLOR, stroke)
	draw_line(tip, back + side, COLOR, stroke)
	draw_line(tip, back - side, COLOR, stroke)


func _camera_zoom() -> float:
	var vp := get_viewport()
	var cam := vp.get_camera_2d() if vp != null else null
	return cam.zoom.x if cam != null else 1.0
