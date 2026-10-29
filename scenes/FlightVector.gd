extends Node2D
## Ship overlay (playtest #3): the speed chevron with its rounded |v| label
## along v-hat of the CURRENT velocity (no acceleration term) at a constant
## SCREEN distance and size, plus the SAFE crosshair that marks the ship while
## its look is faded at zoom. View-only — never writes to flight state.

# Playtest-tunable screen sizes; world size = px * semantic zoom s.
const STROKE_PX := 2.0
const MIN_SPEED := 1.0
const COLOR := Color(Palette.HALO, 0.85)
# Chevron: tip 16 px along v-hat, back edge 12 px, 8 px across; label beside it.
const CHEVRON_DIST_PX := 16.0
const CHEVRON_BACK_PX := 12.0
const CHEVRON_PX := 8.0
const LABEL_OFFSET_PX := 10.0
const LABEL_FONT_PX := 12
# Crosshair ticks: 4 px gap, 9 px outer radius (screen px).
const TICK_IN_PX := 4.0
const TICK_OUT_PX := 9.0
const CROSSHAIR_COLOR := Palette.SAFE

@onready var ship: Node2D = get_node("../Ship")


func _process(_delta: float) -> void:
	queue_redraw()


## Unit direction of the velocity (velocity ONLY — no gravity/thrust term).
static func vector_dir(vel: Vector2) -> Vector2:
	return vel.normalized()


## Chevron tip: a fixed 16 px SCREEN distance along v-hat — |v| moves nothing.
static func chevron_pos(pos: Vector2, vel: Vector2, s: float) -> Vector2:
	return pos + vector_dir(vel) * screen_px(CHEVRON_DIST_PX, s)


## The two chevron lines [from, to] in world units: they meet at the tip
## pointing along v-hat, the back edge 12 px out (clears the 9 px crosshair)
## and 8 px across.
static func chevron_lines(pos: Vector2, vel: Vector2, s: float) -> Array[PackedVector2Array]:
	var dir := vector_dir(vel)
	var tip := chevron_pos(pos, vel, s)
	var back := pos + dir * screen_px(CHEVRON_BACK_PX, s)
	var side := Vector2(-dir.y, dir.x) * screen_px(CHEVRON_PX * 0.5, s)
	return [
		PackedVector2Array([back + side, tip]),
		PackedVector2Array([back - side, tip]),
	]


## Label text: the rounded speed.
static func chevron_label(vel: Vector2) -> int:
	return roundi(vel.length())


## Hidden below the speed threshold.
static func vector_visible(vel: Vector2) -> bool:
	return vel.length() >= MIN_SPEED


## Crosshair opacity: the other half of the ship cross-fade (sums to 1,
## midpoint at the threshold).
static func crosshair_alpha(screen_px: float, threshold: float, width: float) -> float:
	return 1.0 - ShipView.ship_alpha(screen_px, threshold, width)


## World directions of the four ticks: the screen axes turned into the camera
## frame, so on screen (the camera shows the world rotated by -rotation_for)
## the ticks stay axis-aligned at any position.
static func tick_dirs(pos: Vector2) -> PackedVector2Array:
	var rot := FlightCamera.rotation_for(pos)
	var dirs := PackedVector2Array()
	for axis in [Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN]:
		dirs.append(axis.rotated(rot))
	return dirs


## The four tick segments [from, to] at pos in world units: the screen axes
## pushed 4..9 px out. No velocity input — the crosshair shows whenever the
## ship is faded, v = 0 included; empty at alpha 0.
static func crosshair_ticks(pos: Vector2, fade_px: float, threshold: float, width: float, s: float) -> Array[PackedVector2Array]:
	if crosshair_alpha(fade_px, threshold, width) <= 0.0:
		return []
	var ticks: Array[PackedVector2Array] = []
	for dir in tick_dirs(pos):
		ticks.append(PackedVector2Array([
			pos + dir * screen_px(TICK_IN_PX, s),
			pos + dir * screen_px(TICK_OUT_PX, s),
		]))
	return ticks


## World size that renders as `px` screen pixels at semantic zoom s.
static func screen_px(px: float, s: float) -> float:
	return px if s <= 0.0 else px * s


func _draw() -> void:
	var zoom := _camera_zoom()
	var s := 1.0 / zoom
	var stroke := screen_px(STROKE_PX, s)
	_draw_crosshair(zoom, s, stroke)
	var vel: Vector2 = ship.state.vel
	if not vector_visible(vel):
		return
	for seg in chevron_lines(ship.state.pos, vel, s):
		draw_line(seg[0], seg[1], COLOR, stroke)
	_draw_label(vel, zoom, s)


## The crosshair marks the ship while its look is faded: SAFE ticks around the
## centre, no speed gate; nothing is drawn at alpha 0.
func _draw_crosshair(zoom: float, s: float, stroke: float) -> void:
	var fade_px := ShipView.VISUAL_SPAN * zoom
	var alpha := crosshair_alpha(fade_px,
			Tuning.view.ship_fade_threshold_px, Tuning.view.ship_fade_width_px)
	if alpha <= 0.0:
		return
	var col := Color(CROSSHAIR_COLOR, alpha)
	for tick in crosshair_ticks(ship.state.pos, fade_px,
			Tuning.view.ship_fade_threshold_px, Tuning.view.ship_fade_width_px, s):
		draw_line(tick[0], tick[1], col, stroke)


## The speed label next to the chevron: the draw transform moves the origin to
## the camera and undoes its zoom and rotation, so the text keeps its 12 px
## screen size and stays upright at any zoom.
func _draw_label(vel: Vector2, zoom: float, s: float) -> void:
	var vp := get_viewport()
	var cam := vp.get_camera_2d() if vp != null else null
	var cam_pos := cam.position if cam != null else Vector2.ZERO
	var rot := FlightCamera.rotation_for(ship.state.pos)
	draw_set_transform(cam_pos, rot, Vector2.ONE * s)
	var dir_s := vector_dir(vel).rotated(-rot)
	var tip_px := (chevron_pos(ship.state.pos, vel, s) - cam_pos).rotated(-rot) * zoom
	var side := Vector2(dir_s.y, -dir_s.x) * LABEL_OFFSET_PX
	draw_string(ThemeDB.fallback_font, tip_px + side, str(chevron_label(vel)),
			HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_PX, COLOR)


func _camera_zoom() -> float:
	var vp := get_viewport()
	var cam := vp.get_camera_2d() if vp != null else null
	return cam.zoom.x if cam != null else 1.0
