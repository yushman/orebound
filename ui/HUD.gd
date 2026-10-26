extends Control

const BOTTOM_Y := 700.0
const BASE_W := 1280.0
const CARGO_MAX := 6
const CELL_SIZE := 20.0
const CELL_GAP := 6.0
const CELL_Y := 750.0
const LABEL_GAP := 12.0
const SCALE_H := 560.0
const STRIP_H := 60.0
const BAR_W := 28.0
const MARGIN := 60.0
const FONT_SIZE := 16
const TIER_ALPHA := 0.6
const TIER_DARKEN := 0.2
const EDGE_COLOR := Palette.DANGER
const LINE_COLOR := Palette.HALO
const MARKER_COLOR := Palette.SAFE
const CARGO_FILL_COLOR := Palette.ORE
const CARGO_EMPTY_COLOR := Palette.HALO
const STRIP_COLOR := Color(Palette.HALO, 0.35)

var ship: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var x0 := size.x - MARGIN - BAR_W
	var x1 := x0 + BAR_W
	var font := ThemeDB.fallback_font
	_draw_hold(font)
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
	draw_dashed_line(Vector2(x0 - 8.0, share_y(tow_share())), Vector2(x1 + 8.0, share_y(tow_share())), LINE_COLOR, 2.0, 6.0)
	draw_line(Vector2(x0 - 8.0, carrier_y), Vector2(x1 + 8.0, carrier_y), LINE_COLOR, 3.0)
	draw_line(Vector2(x0, top_y), Vector2(x1, top_y), LINE_COLOR, 1.0)
	if ship == null:
		ship = get_node_or_null("../../Ship")
	if ship == null:
		return
	var y := marker_y(ship.state.pos.length())
	draw_colored_polygon(PackedVector2Array([Vector2(x1 + 4.0, y), Vector2(x1 + 16.0, y - 7.0), Vector2(x1 + 16.0, y + 7.0)]), MARKER_COLOR)


func _draw_hold(font: Font) -> void:
	var cells := cargo_cells(size.x)
	var label_w := font.get_string_size("трюм", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	draw_string(font, Vector2(cells[0].position.x - LABEL_GAP - label_w, CELL_Y + CELL_SIZE * 0.5 + 6.0), "трюм", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	for i in cells.size():
		if cell_filled(i, Tuning.view.cargo_fill):
			draw_rect(cells[i], CARGO_FILL_COLOR)
		else:
			draw_rect(cells[i], CARGO_EMPTY_COLOR, false, 2.0)


static func cargo_count(fill: float) -> int:
	return roundi(clampf(fill, 0.0, 1.0) * CARGO_MAX)


static func cell_filled(i: int, fill: float) -> bool:
	return i < cargo_count(fill)


static func cargo_cells(width := BASE_W) -> Array[Rect2]:
	var total := CARGO_MAX * CELL_SIZE + (CARGO_MAX - 1) * CELL_GAP
	var x := (width - total) * 0.5
	var out: Array[Rect2] = []
	for i in CARGO_MAX:
		out.append(Rect2(x + i * (CELL_SIZE + CELL_GAP), CELL_Y, CELL_SIZE, CELL_SIZE))
	return out


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
