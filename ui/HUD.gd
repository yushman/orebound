extends Control

const BOTTOM_Y := 700.0
const BASE_W := 1280.0
const CELL_SIZE := 20.0
const CELL_GAP := 6.0
const TANK_Y := 712.0
const HOLD_Y := 742.0
const HULL_Y := 772.0
const HULL_H := 14.0
const HULL_SEGMENTS := 5
const HULL_SEG_W := 28.0
const RESERVE_H := 3.0
const PATTERN_STEP := 6.0
const FRAME_PAD := 4.0
const OUTLINE_W := 2.0
enum State { CALM, NEAR, BELOW }
const LABEL_GAP := 12.0
const SCALE_H := 560.0
const STRIP_H := 60.0
const BAR_W := 28.0
const MARGIN := 60.0
const FONT_SIZE := 16
const DEBUG_POS := Vector2(16.0, 24.0)
const TIER_ALPHA := 0.6
const TIER_DARKEN := 0.2
const EDGE_COLOR := Palette.DANGER
const LINE_COLOR := Palette.HALO
const TOW_COLOR := Palette.SAFE
const CARRIER_COLOR := Palette.SAFE
const MARKER_COLOR := Palette.SAFE
const STRIP_COLOR := Color(Palette.HALO, 0.35)

var ship: Node
var panel: Control


func _ready() -> void:
	ship = get_node_or_null("../../Ship")
	panel = get_node_or_null("../TuningPanel") as Control


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var x0 := size.x - MARGIN - BAR_W
	var x1 := x0 + BAR_W
	var font := ThemeDB.fallback_font
	var state := State.CALM
	var color := reserve_color(state)
	var need := 0.0
	var reserve: float = Tuning.resources[&"fuel"].energy
	if ship != null:
		var s: ShipState = ship.state
		var mass := Hold.mass(s)
		var energy := Hold.energy(s)
		need = Fuel.climb_energy(s.pos.length(), s.vel.length(), mass)
		reserve = maxf(reserve, need)
		state = reserve_state(energy, need, reserve)
		color = reserve_color(state)
	_draw_bars(font, color, reserve)
	var segs := segments()
	for i in segs.size():
		var top := share_y(segs[i].y)
		var bot := share_y(segs[i].x)
		draw_rect(Rect2(x0, top, BAR_W, bot - top), tier_color(i))
		draw_string(font, Vector2(x0 - 16.0, (top + bot) * 0.5 + 6.0), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var carrier_y := share_y(1.0)
	var top_y := carrier_y - STRIP_H
	draw_rect(Rect2(x0, top_y, BAR_W, STRIP_H), STRIP_COLOR)
	draw_string(font, Vector2(x0 - 16.0, top_y + STRIP_H * 0.5 + 6.0), "М", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	draw_line(Vector2(x0, BOTTOM_Y), Vector2(x1, BOTTOM_Y), EDGE_COLOR, 3.0)
	draw_dashed_line(Vector2(x0 - 8.0, share_y(tow_share())), Vector2(x1 + 8.0, share_y(tow_share())), TOW_COLOR, 2.0, 6.0)
	draw_line(Vector2(x0 - 8.0, carrier_y), Vector2(x1 + 8.0, carrier_y), CARRIER_COLOR, 3.0)
	draw_line(Vector2(x0, top_y), Vector2(x1, top_y), LINE_COLOR, 1.0)
	if ship == null:
		return
	if debug_visible(panel):
		draw_string(font, DEBUG_POS, debug_text(ship.state, need), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Palette.HALO)
	var y := marker_y(ship.state.pos.length())
	draw_colored_polygon(PackedVector2Array([Vector2(x1 + 4.0, y), Vector2(x1 + 16.0, y - 7.0), Vector2(x1 + 16.0, y + 7.0)]), MARKER_COLOR)


func _draw_bars(font: Font, frame_color: Color, reserve: float) -> void:
	var p: ShipParams = Tuning.ship
	var s: ShipState = ship.state if ship != null else ShipState.new()
	_draw_cells(font, "топливо", tank_slots(s.tank), int(p.tank_capacity), TANK_Y, "")
	var tank := bar_cells(int(p.tank_capacity), size.x, TANK_Y)
	if not tank.is_empty():
		var frame := tank[0].merge(tank[tank.size() - 1]).grow(FRAME_PAD)
		draw_rect(frame, frame_color, false, OUTLINE_W)
		var x := reserve_x(tank_slots(s.tank), int(p.tank_capacity), reserve, tank)
		_draw_diagonals(Rect2(tank[0].position.x, TANK_Y + CELL_SIZE + 2.0, x - tank[0].position.x, RESERVE_H), Palette.DANGER)
	_draw_cells(font, "трюм", s.hold, int(p.hold_capacity), HOLD_Y, "масса %.1f" % Hold.mass(s))
	_draw_hull(font, s)


func _draw_cells(font: Font, label: String, cells: Array[HoldCell], capacity: int, y: float, tail: String) -> void:
	var rects := bar_cells(capacity, size.x, y)
	if rects.is_empty():
		return
	var label_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var ty := y + CELL_SIZE * 0.5 + 6.0
	draw_string(font, Vector2(rects[0].position.x - LABEL_GAP - label_w, ty), label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	if tail != "":
		draw_string(font, Vector2(rects[rects.size() - 1].end.x + LABEL_GAP, ty), tail, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	for i in rects.size():
		var full := false
		if i < cells.size():
			var c := cells[i]
			var fr := fill_rect(rects[i], c.fill)
			draw_rect(fr, Color(cell_color(c.type), 0.55))
			_draw_pattern(fr, cell_pattern(c.type), cell_color(c.type))
			full = c.fill >= 1.0
		draw_rect(rects[i], Palette.HULL if full else Palette.HULL_SHADE, false, OUTLINE_W)


func _draw_pattern(r: Rect2, pattern: StringName, color: Color) -> void:
	if r.size.x <= 0.0:
		return
	match pattern:
		&"solid":
			draw_rect(r, color)
		&"dots":
			var x := r.position.x + PATTERN_STEP * 0.5
			while x < r.end.x:
				var y := r.position.y + PATTERN_STEP * 0.5
				while y < r.end.y:
					draw_circle(Vector2(x, y), 1.5, color)
					y += PATTERN_STEP
				x += PATTERN_STEP
		&"stripes":
			_draw_diagonals(r, color)
		&"hatch_h":
			var y := r.position.y + PATTERN_STEP * 0.5
			while y < r.end.y:
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), color, 1.5)
				y += PATTERN_STEP
		&"hatch_v":
			var x := r.position.x + PATTERN_STEP * 0.5
			while x < r.end.x:
				draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), color, 1.5)
				x += PATTERN_STEP
		&"cross":
			_draw_pattern(r, &"hatch_h", color)
			_draw_pattern(r, &"hatch_v", color)


func _draw_diagonals(r: Rect2, color: Color) -> void:
	var h := r.size.y
	var k := -h
	while k < r.size.x:
		var x0 := maxf(k, 0.0)
		var x1 := minf(k + h, r.size.x)
		if x1 > x0:
			draw_line(r.position + Vector2(x0, h - (x0 - k)), r.position + Vector2(x1, h - (x1 - k)), color, 1.5)
		k += PATTERN_STEP


func _draw_hull(font: Font, s: ShipState) -> void:
	var rects := bar_cells(HULL_SEGMENTS, size.x, HULL_Y, HULL_SEG_W, HULL_H)
	var label_w := font.get_string_size("корпус", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	draw_string(font, Vector2(rects[0].position.x - LABEL_GAP - label_w, HULL_Y + HULL_H * 0.5 + 6.0), "корпус", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var on := hull_segments(s.hull, Tuning.ship.hull_max)
	for i in rects.size():
		if i < on:
			draw_rect(rects[i], Palette.HULL)
		else:
			draw_rect(rects[i], Palette.HULL_SHADE, false, OUTLINE_W)


static func cell_color(type: StringName) -> Color:
	return Palette.FUEL if type == &"fuel" else AsteroidView.color_of(type)


static func cell_pattern(type: StringName) -> StringName:
	match type:
		&"fuel":
			return &"stripes"
		&"ice":
			return &"dots"
		&"ore_middle":
			return &"hatch_h"
		&"ore_rare":
			return &"hatch_v"
		&"ore_unique":
			return &"cross"
	return &"solid"


static func tank_slots(cells: Array[HoldCell]) -> Array[HoldCell]:
	var out: Array[HoldCell] = []
	for c in cells:
		if c.fill >= 1.0:
			out.append(c)
	for c in cells:
		if c.fill < 1.0:
			out.append(c)
	return out


static func bar_cells(n: int, width: float, y: float, w := CELL_SIZE, h := CELL_SIZE) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var total := n * w + (n - 1) * CELL_GAP
	var x := (width - total) * 0.5
	for i in n:
		out.append(Rect2(x + i * (w + CELL_GAP), y, w, h))
	return out


static func fill_rect(r: Rect2, fill: float) -> Rect2:
	return Rect2(r.position, Vector2(r.size.x * clampf(fill, 0.0, 1.0), r.size.y))


static func hull_segments(hull: float, hull_max: float) -> int:
	if hull_max <= 0.0:
		return 0
	return ceili(clampf(hull / hull_max, 0.0, 1.0) * HULL_SEGMENTS)


static func reserve_state(energy: float, need: float, reserve: float) -> State:
	if energy < need:
		return State.BELOW
	if energy <= reserve:
		return State.NEAR
	return State.CALM


static func reserve_x(cells: Array[HoldCell], capacity: int, reserve: float, rects: Array[Rect2]) -> float:
	if rects.is_empty():
		return 0.0
	var unit: float = Tuning.resources[&"fuel"].energy
	var left := reserve
	for i in mini(capacity, rects.size()):
		var e := unit
		if i < cells.size():
			var c := cells[i]
			e = c.fill * Tuning.resources[c.type].energy + (1.0 - c.fill) * unit
		if e <= 0.0:
			continue
		if left <= e:
			return rects[i].position.x + rects[i].size.x * maxf(left, 0.0) / e
		left -= e
	return rects[rects.size() - 1].end.x


static func reserve_color(state: State) -> Color:
	match state:
		State.BELOW:
			return Palette.DANGER
		State.NEAR:
			return Palette.SAFE
	return Palette.HALO


static func tier_color(i: int) -> Color:
	var c := Palette.HALO.darkened(TIER_DARKEN * (3 - i % 4))
	return Color(c, TIER_ALPHA)


static func share(r: float) -> float:
	var f: FieldParams = Tuning.field
	var lo: float = GravityField.planet_potential_eff(f.atmosphere_edge)
	var swing: float = GravityField.planet_potential_eff(f.carrier_orbit_radius) - lo
	return (GravityField.planet_potential_eff(r) - lo) / swing


static func segments() -> Array[Vector2]:
	var shares: Array = Tuning.planet.tier_shares
	var out: Array[Vector2] = []
	out.resize(shares.size())
	var cum := 0.0
	for i in range(shares.size() - 1, -1, -1):
		out[i] = Vector2(cum, cum + shares[i])
		cum += shares[i]
	return out


static func tow_share() -> float:
	var shares: Array = Tuning.planet.tier_shares
	return shares[2] + shares[3]


static func share_y(s: float) -> float:
	return BOTTOM_Y - s * SCALE_H


static func marker_y(r: float) -> float:
	var f: FieldParams = Tuning.field
	if r <= f.carrier_orbit_radius:
		return share_y(maxf(share(r), 0.0))
	var t := clampf((r - f.carrier_orbit_radius) / Tuning.planet.ceiling_offset, 0.0, 1.0)
	return share_y(1.0) - t * STRIP_H


static func debug_text(s: ShipState, need: float) -> String:
	var p: ShipParams = Tuning.ship
	return "энергия %.2f · масса %.1f · трюм %d/%d · бак %d/%d · нужно %.2f" % [Hold.energy(s), Hold.mass(s), Hold.used_volume(s.hold), p.hold_capacity, Hold.used_volume(s.tank), p.tank_capacity, need]


static func debug_visible(panel: Control) -> bool:
	return panel != null and panel.visible
