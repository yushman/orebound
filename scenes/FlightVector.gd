extends Node2D
## Ship overlay (playtest #3): the speed chevron with its rounded |v| label
## along v-hat of the CURRENT velocity (no acceleration term) at a constant
## SCREEN distance and size, plus the SAFE crosshair that marks the ship while
## its look is faded at zoom. View-only — never writes to flight state.

# Playtest-tunable screen sizes; world size = px * semantic zoom s.
const STROKE_PX := 2.0
const MIN_SPEED := 1.0
const COLOR := Color(Palette.HALO, 0.85)
# Chevron: tip 30 px along v-hat, back edge 25 px, 12 px across; label past it.
const CHEVRON_BACK_PX := 25.0
const CHEVRON_DEPTH_PX := 5.0
const CHEVRON_DIST_PX := CHEVRON_BACK_PX + CHEVRON_DEPTH_PX
const CHEVRON_PX := 12.0
const LABEL_OFFSET_PX := 24.0
const LABEL_FONT_PX := 20
# Crosshair ticks: 4 px gap, 9 px outer radius (screen px).
const TICK_IN_PX := 4.0
const TICK_OUT_PX := 9.0
const CROSSHAIR_COLOR := Palette.SAFE
# Nose needle: 8..14 px along the ship nose (screen px) in the palette red,
# its own 3 px stroke (thicker than the ticks; 8 slightly overlaps the 9 px
# tick ring so it reads attached).
const NEEDLE_IN_PX := 8.0
const NEEDLE_OUT_PX := 14.0
const NEEDLE_STROKE_PX := 3.0
const NEEDLE_COLOR := Palette.DANGER

@onready var ship: Node2D = get_node("../Ship")


func _process(_delta: float) -> void:
	queue_redraw()


## Unit direction of the velocity (velocity ONLY — no gravity/thrust term).
static func vector_dir(vel: Vector2) -> Vector2:
	return vel.normalized()


## Chevron tip: a fixed 30 px SCREEN distance along v-hat — |v| moves nothing.
static func chevron_pos(pos: Vector2, vel: Vector2, s: float) -> Vector2:
	return pos + vector_dir(vel) * screen_px(CHEVRON_DIST_PX, s)


## The two chevron lines [from, to] in world units: they meet at the tip
## pointing along v-hat, the back edge 25 px out (clears the 9 px crosshair)
## and 12 px across.
static func chevron_lines(pos: Vector2, vel: Vector2, s: float) -> Array[PackedVector2Array]:
	return chevron_lines_at(pos, vel, s, CHEVRON_BACK_PX)


## The chevron lines with the back edge at base_px SCREEN px from the centre:
## the shared geometry of the ship chevron and the reference marker chevron.
## The tip is CHEVRON_DEPTH_PX further out, 12 px across.
static func chevron_lines_at(pos: Vector2, vel: Vector2, s: float, base_px: float) -> Array[PackedVector2Array]:
	var dir := vector_dir(vel)
	var back := pos + dir * screen_px(base_px, s)
	var tip := pos + dir * screen_px(base_px + CHEVRON_DEPTH_PX, s)
	var side := Vector2(-dir.y, dir.x) * screen_px(CHEVRON_PX * 0.5, s)
	return [
		PackedVector2Array([back + side, tip]),
		PackedVector2Array([back - side, tip]),
	]


## Label text: the rounded speed.
static func chevron_label(vel: Vector2) -> int:
	return roundi(vel.length())


## Label anchor: LABEL_OFFSET_PX beyond the chevron tip along v-hat — strictly
## past the arms for any direction.
static func label_pos(pos: Vector2, vel: Vector2, s: float) -> Vector2:
	return label_pos_at(pos, vel, s, CHEVRON_BACK_PX)


## Label anchor with the chevron back edge at base_px: the tip is
## CHEVRON_DEPTH_PX further out and the label LABEL_OFFSET_PX past the tip.
static func label_pos_at(pos: Vector2, vel: Vector2, s: float, base_px: float) -> Vector2:
	return pos + vector_dir(vel) * screen_px(base_px + CHEVRON_DEPTH_PX + LABEL_OFFSET_PX, s)


## Draw a screen-constant, upright label at a world point: the transform moves
## the origin to the camera and undoes its zoom and rotation, so the text keeps
## its LABEL_FONT_PX screen size and stays upright at any zoom. Shared by the
## ship overlay and the reference marker.
static func draw_label_at(ci: Node2D, world_pos: Vector2, text: String,
		color: Color, zoom: float, s: float, rot: float, cam_pos: Vector2) -> void:
	ci.draw_set_transform(cam_pos - ci.global_position, rot, Vector2.ONE * s)
	var text_w := ThemeDB.fallback_font.get_string_size(text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_PX).x
	var anchor_px := (world_pos - cam_pos).rotated(-rot) * zoom
	# Horizontally and vertically centred on the anchor: the x shift by half
	# the measured width (draw_string centres only for a width > 0) and the
	# baseline offset from the font metrics.
	var off := Vector2(-text_w * 0.5, label_baseline_off(ThemeDB.fallback_font, LABEL_FONT_PX))
	ci.draw_string(ThemeDB.fallback_font, anchor_px + off, text,
			HORIZONTAL_ALIGNMENT_CENTER, text_w, LABEL_FONT_PX, color)


## Baseline y-offset from the label anchor that centres the glyphs on it:
## baseline = anchor.y + (ascent - descent) / 2 (Godot's draw_string pos.y is
## the baseline; font-level metrics at LABEL_FONT_PX, Godot 4.7 has no
## per-string ascent/descent accessors).
static func label_baseline_off(font: Font, font_px: int) -> float:
	return (font.get_ascent(font_px) - font.get_descent(font_px)) / 2.0


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


## Nose needle [from, to] on the crosshair: 8..14 px along the world nose
## Vector2.UP.rotated(rot). Directional info — world orientation, never
## counter-rotated, so it turns with the world on screen.
static func nose_needle(pos: Vector2, rot: float, s: float) -> PackedVector2Array:
	var dir := Vector2.UP.rotated(rot)
	return PackedVector2Array([
		pos + dir * screen_px(NEEDLE_IN_PX, s),
		pos + dir * screen_px(NEEDLE_OUT_PX, s),
	])


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
## centre plus the nose needle along the world nose, no speed gate; nothing is
## drawn at alpha 0.
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
	var needle := nose_needle(ship.state.pos, ship.state.rot, s)
	draw_line(needle[0], needle[1], Color(NEEDLE_COLOR, alpha),
			screen_px(NEEDLE_STROKE_PX, s))


## The speed label beyond the chevron tip: the shared draw helper moves the
## origin to the camera and undoes its zoom and rotation, so the text keeps its
## 20 px screen size and stays upright at any zoom.
func _draw_label(vel: Vector2, zoom: float, s: float) -> void:
	var vp := get_viewport()
	var cam := vp.get_camera_2d() if vp != null else null
	var cam_pos := cam.position if cam != null else Vector2.ZERO
	var rot := FlightCamera.rotation_for(ship.state.pos)
	draw_label_at(self, label_pos(ship.state.pos, vel, s), str(chevron_label(vel)),
			COLOR, zoom, s, rot, cam_pos)


func _camera_zoom() -> float:
	var vp := get_viewport()
	var cam := vp.get_camera_2d() if vp != null else null
	return cam.zoom.x if cam != null else 1.0
