extends Control

const BOTTOM_Y := 700.0
const SCALE_H := 560.0
const STRIP_H := 60.0
const BAR_W := 28.0
const MARGIN := 60.0
const FONT_SIZE := 16
const TIER_COLORS: Array[Color] = [Color(0.35, 0.4, 0.5, 0.6), Color(0.3, 0.45, 0.4, 0.6), Color(0.5, 0.45, 0.3, 0.6), Color(0.5, 0.3, 0.3, 0.6)]
const EDGE_COLOR := Color(1.0, 0.2, 0.2)
const LINE_COLOR := Color(1.0, 1.0, 1.0)
const MARKER_COLOR := Color(1.0, 0.9, 0.2)

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
	var segs := segments()
	for i in segs.size():
		var top := share_y(segs[i].y)
		var bot := share_y(segs[i].x)
		draw_rect(Rect2(x0, top, BAR_W, bot - top), TIER_COLORS[i % TIER_COLORS.size()])
		draw_string(font, Vector2(x0 - 16.0, (top + bot) * 0.5 + 6.0), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var carrier_y := share_y(1.0)
	var top_y := carrier_y - STRIP_H
	draw_rect(Rect2(x0, top_y, BAR_W, STRIP_H), Color(0.6, 0.6, 0.7, 0.35))
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
