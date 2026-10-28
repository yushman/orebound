extends GutTest

const HUD_SCRIPT := preload("res://ui/HUD.gd")
const PRESETS := ["res://presets/p1.tres", "res://presets/p2.tres", "res://presets/p3.tres", "res://presets/p4.tres"]

var _field: FieldParams
var _ship: ShipParams
var _planet: PlanetParams


func before_each() -> void:
	_field = Tuning.field
	_ship = Tuning.ship
	_planet = Tuning.planet
	Tuning.field = _field.duplicate(true)
	Tuning.ship = _ship.duplicate(true)
	Tuning.planet = _planet.duplicate(true)


func after_each() -> void:
	Tuning.field = _field
	Tuning.ship = _ship
	Tuning.planet = _planet


func test_share_edge_carrier_and_tier_boundaries_for_presets() -> void:
	for path in PRESETS:
		Tuning.apply(Tuning.load_preset(path))
		var f: FieldParams = Tuning.field
		assert_almost_eq(HUD_SCRIPT.share(f.atmosphere_edge), 0.0, 1e-6, path)
		assert_almost_eq(HUD_SCRIPT.share(f.carrier_orbit_radius), 1.0, 1e-6, path)
		var b: Array = WellGenerator.tiers()["boundaries"]
		var shares: Array = Tuning.planet.tier_shares
		var cum := 0.0
		for i in 3:
			cum += shares[3 - i]
			assert_almost_eq(HUD_SCRIPT.share(b[i + 1]), cum, 1e-3, "%s boundary %d" % [path, i + 1])


func test_segments_heights_equal_tier_shares_top_to_bottom() -> void:
	var shares: Array = Tuning.planet.tier_shares
	var segs: Array[Vector2] = HUD_SCRIPT.segments()
	assert_eq(segs.size(), 4)
	if segs.size() != 4:
		return
	for i in 4:
		assert_almost_eq(segs[i].y - segs[i].x, shares[i], 1e-6, "tier %d" % i)
	assert_almost_eq(segs[0].y, 1.0, 1e-6)
	assert_almost_eq(segs[3].x, 0.0, 1e-6)
	for i in 3:
		assert_almost_eq(segs[i].x, segs[i + 1].y, 1e-6)


func test_tow_share_is_middle_tier_bottom() -> void:
	assert_almost_eq(HUD_SCRIPT.tow_share(), 0.35, 1e-6)
	var shares: Array = Tuning.planet.tier_shares
	assert_almost_eq(HUD_SCRIPT.tow_share(), shares[2] + shares[3], 1e-6)


func test_marker_y_clamps_below_edge_maps_above_carrier_and_clamps_at_ceiling() -> void:
	var f: FieldParams = Tuning.field
	var carrier_y: float = HUD_SCRIPT.BOTTOM_Y - HUD_SCRIPT.SCALE_H
	var top_y: float = carrier_y - HUD_SCRIPT.STRIP_H
	assert_almost_eq(HUD_SCRIPT.marker_y(f.atmosphere_edge * 0.5), HUD_SCRIPT.BOTTOM_Y, 1e-3)
	assert_almost_eq(HUD_SCRIPT.marker_y(f.atmosphere_edge), HUD_SCRIPT.BOTTOM_Y, 1e-3)
	assert_almost_eq(HUD_SCRIPT.marker_y(f.carrier_orbit_radius), carrier_y, 1e-3)
	var off: float = Tuning.planet.ceiling_offset
	assert_almost_eq(HUD_SCRIPT.marker_y(f.carrier_orbit_radius + off * 0.5), carrier_y - HUD_SCRIPT.STRIP_H * 0.5, 1e-3)
	assert_almost_eq(HUD_SCRIPT.marker_y(f.carrier_orbit_radius + off), top_y, 1e-3)
	assert_almost_eq(HUD_SCRIPT.marker_y(f.carrier_orbit_radius + off * 3.0), top_y, 1e-3)
	var mid := HUD_SCRIPT.share_y(0.5)
	assert_almost_eq(mid, HUD_SCRIPT.BOTTOM_Y - 0.5 * HUD_SCRIPT.SCALE_H, 1e-3)


func test_hud_ignores_mouse_and_focus_and_tolerates_missing_ship() -> void:
	var hud: Control = load("res://ui/HUD.tscn").instantiate()
	add_child_autofree(hud)
	assert_eq(hud.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(hud.focus_mode, Control.FOCUS_NONE)
	assert_null(hud.ship)
	await wait_frames(2)
	assert_true(is_instance_valid(hud))


func test_missing_ship_pushes_no_error() -> void:
	var hud: Control = load("res://ui/HUD.tscn").instantiate()
	add_child_autofree(hud)
	assert_null(hud.ship)
	await wait_frames(2)
	assert_push_error_count(0)


func test_ship_resolved_in_ready() -> void:
	var root := Node.new()
	var ship := Node.new()
	ship.name = "Ship"
	root.add_child(ship)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var hud: Control = load("res://ui/HUD.tscn").instantiate()
	layer.add_child(hud)
	add_child_autofree(root)
	assert_eq(hud.ship, ship)


func test_colors_come_from_palette() -> void:
	assert_eq(HUD_SCRIPT.EDGE_COLOR, Palette.DANGER)
	assert_eq(HUD_SCRIPT.LINE_COLOR, Palette.HALO)
	assert_eq(HUD_SCRIPT.MARKER_COLOR, Palette.SAFE)
	assert_eq(HUD_SCRIPT.STRIP_COLOR, Color(Palette.HALO, 0.35))


func test_tow_and_carrier_lines_use_safe() -> void:
	assert_eq(HUD_SCRIPT.TOW_COLOR, Palette.SAFE)
	assert_eq(HUD_SCRIPT.CARRIER_COLOR, Palette.SAFE)
	assert_eq(HUD_SCRIPT.LINE_COLOR, Palette.HALO)


func test_tier_colors_are_halo_tints_with_kept_alpha() -> void:
	var seen := {}
	for i in 4:
		var c: Color = HUD_SCRIPT.tier_color(i)
		assert_almost_eq(c.h, Palette.HALO.h, 0.01, "hue %d" % i)
		assert_almost_eq(c.a, 0.6, 1e-6, "alpha %d" % i)
		seen[c] = true
	assert_eq(seen.size(), 4)


func _cell(type: StringName, fill: float) -> HoldCell:
	var c := HoldCell.new()
	c.type = type
	c.fill = fill
	return c


func test_cell_color_is_fuel_or_asteroid_color() -> void:
	assert_eq(HUD_SCRIPT.cell_color(&"fuel"), Palette.FUEL)
	for t in [&"ice", &"ore_base", &"ore_middle", &"ore_rare", &"ore_unique"]:
		assert_eq(HUD_SCRIPT.cell_color(t), AsteroidView.color_of(t))


func test_cell_patterns_are_pairwise_distinct() -> void:
	var seen := {}
	for t in [&"fuel", &"ice", &"ore_base", &"ore_middle", &"ore_rare", &"ore_unique"]:
		seen[HUD_SCRIPT.cell_pattern(t)] = true
	assert_eq(seen.size(), 6)


func test_tank_slots_full_first_partial_last_input_unchanged() -> void:
	var cells: Array[HoldCell] = [_cell(&"fuel", 0.4), _cell(&"fuel", 1.0), _cell(&"ice", 1.0)]
	var out: Array[HoldCell] = HUD_SCRIPT.tank_slots(cells)
	assert_eq(out.size(), 3)
	assert_eq(out[0], cells[1])
	assert_eq(out[1], cells[2])
	assert_eq(out[2], cells[0])
	assert_eq(cells[0].fill, 0.4)
	assert_eq(cells[2].type, &"ice")


func test_bar_cells_are_centred_on_the_width() -> void:
	var cells: Array[Rect2] = HUD_SCRIPT.bar_cells(4, 1000.0, 700.0)
	assert_eq(cells.size(), 4)
	assert_almost_eq((cells[0].position.x + cells[3].end.x) * 0.5, 500.0, 1e-3)
	assert_eq(cells[2].position.y, 700.0)
	assert_eq(cells[1].size, Vector2(HUD_SCRIPT.CELL_SIZE, HUD_SCRIPT.CELL_SIZE))
	assert_almost_eq(cells[1].position.x - cells[0].end.x, HUD_SCRIPT.CELL_GAP, 1e-3)
	assert_eq(HUD_SCRIPT.bar_cells(0, 1000.0, 0.0).size(), 0)


func test_fill_rect_covers_fill_from_the_left() -> void:
	var r := Rect2(10, 20, 20, 20)
	assert_eq(HUD_SCRIPT.fill_rect(r, 0.25), Rect2(10, 20, 5, 20))
	assert_eq(HUD_SCRIPT.fill_rect(r, 1.0), r)
	assert_eq(HUD_SCRIPT.fill_rect(r, 2.0), r)
	assert_eq(HUD_SCRIPT.fill_rect(r, -1.0).size.x, 0.0)


func test_bars_sit_at_bottom_centre_tank_above_hold_hull_below() -> void:
	assert_lt(HUD_SCRIPT.TANK_Y, HUD_SCRIPT.HOLD_Y)
	assert_lt(HUD_SCRIPT.HOLD_Y, HUD_SCRIPT.HULL_Y)
	assert_gt(HUD_SCRIPT.TANK_Y, HUD_SCRIPT.BOTTOM_Y)
	assert_lt(HUD_SCRIPT.HULL_Y + HUD_SCRIPT.HULL_H, 800.0)


func test_hull_segments_ceil_and_clamp() -> void:
	assert_eq(HUD_SCRIPT.hull_segments(100.0, 100.0), 5)
	assert_eq(HUD_SCRIPT.hull_segments(0.0, 100.0), 0)
	assert_eq(HUD_SCRIPT.hull_segments(1.0, 100.0), 1)
	assert_eq(HUD_SCRIPT.hull_segments(50.0, 100.0), 3)
	assert_eq(HUD_SCRIPT.hull_segments(40.0, 100.0), 2)
	assert_eq(HUD_SCRIPT.hull_segments(150.0, 100.0), 5)
	assert_eq(HUD_SCRIPT.hull_segments(-5.0, 100.0), 0)


func test_reserve_state_and_colors() -> void:
	assert_eq(HUD_SCRIPT.reserve_state(9.0, 10.0, 12.0), HUD_SCRIPT.State.BELOW)
	assert_eq(HUD_SCRIPT.reserve_state(11.0, 10.0, 12.0), HUD_SCRIPT.State.NEAR)
	assert_eq(HUD_SCRIPT.reserve_state(12.0, 10.0, 12.0), HUD_SCRIPT.State.NEAR)
	assert_eq(HUD_SCRIPT.reserve_state(12.5, 10.0, 12.0), HUD_SCRIPT.State.CALM)
	assert_eq(HUD_SCRIPT.reserve_state(0.0, 0.0, 6.0), HUD_SCRIPT.State.NEAR)
	assert_eq(HUD_SCRIPT.reserve_state(7.0, 0.0, 6.0), HUD_SCRIPT.State.CALM)
	assert_eq(HUD_SCRIPT.reserve_color(HUD_SCRIPT.State.BELOW), Palette.DANGER)
	assert_eq(HUD_SCRIPT.reserve_color(HUD_SCRIPT.State.NEAR), Palette.SAFE)
	assert_eq(HUD_SCRIPT.reserve_color(HUD_SCRIPT.State.CALM), Palette.HALO)


func test_reserve_x_one_cell_grows_with_need_and_clamps() -> void:
	var e: float = Tuning.resources[&"fuel"].energy
	var cells: Array[HoldCell] = []
	for i in 2:
		var c := HoldCell.new()
		c.type = &"fuel"
		c.fill = 1.0
		cells.append(c)
	var rects := HUD_SCRIPT.bar_cells(4, 1280.0, HUD_SCRIPT.TANK_Y)
	assert_almost_eq(HUD_SCRIPT.reserve_x(cells, 4, e, rects), rects[0].end.x, 0.001)
	var half: float = rects[1].position.x + rects[1].size.x * 0.5
	assert_almost_eq(HUD_SCRIPT.reserve_x(cells, 4, e * 1.5, rects), half, 0.001)
	assert_almost_eq(HUD_SCRIPT.reserve_x(cells, 4, e * 3.0, rects), rects[2].end.x, 0.001)
	assert_almost_eq(HUD_SCRIPT.reserve_x(cells, 4, e * 100.0, rects), rects[3].end.x, 0.001)


func test_debug_text_shows_energy_mass_hold_tank_slots_and_need() -> void:
	assert_eq(HUD_SCRIPT.debug_text(ShipState.new(), 1.5), "энергия 6.00 · масса 10.0 · трюм 0/10 · бак 2/4 · нужно 1.50")


func test_debug_visible_only_with_visible_panel() -> void:
	assert_false(HUD_SCRIPT.debug_visible(null))
	var c := Control.new()
	add_child_autofree(c)
	c.visible = false
	assert_false(HUD_SCRIPT.debug_visible(c))
	c.visible = true
	assert_true(HUD_SCRIPT.debug_visible(c))


func test_hold_frame_index_is_effective_pick_minus_one_for_empty_hold() -> void:
	var s := ShipState.new()
	assert_eq(HUD_SCRIPT.hold_frame_index(s), -1)
	s.hold.append(_cell(&"ice", 1.0))
	s.hold.append(_cell(&"ore_rare", 1.0))
	assert_eq(HUD_SCRIPT.hold_frame_index(s), Hold.effective_pick(s))
	s.jettison_pick = 0
	assert_eq(HUD_SCRIPT.hold_frame_index(s), 0)
