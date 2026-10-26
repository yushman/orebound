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


func test_cargo_count_rounds_and_clamps() -> void:
	assert_eq(HUD_SCRIPT.cargo_count(0.0), 0)
	assert_eq(HUD_SCRIPT.cargo_count(1.0), HUD_SCRIPT.CARGO_MAX)
	assert_eq(HUD_SCRIPT.cargo_count(0.5), roundi(0.5 * HUD_SCRIPT.CARGO_MAX))
	assert_eq(HUD_SCRIPT.cargo_count(-1.0), 0)
	assert_eq(HUD_SCRIPT.cargo_count(2.0), HUD_SCRIPT.CARGO_MAX)
	assert_eq(HUD_SCRIPT.cargo_count(0.26), roundi(0.26 * HUD_SCRIPT.CARGO_MAX))


func test_cargo_cells_are_a_centred_row_of_cargo_max() -> void:
	assert_eq(HUD_SCRIPT.CARGO_MAX, 6)
	var cells: Array[Rect2] = HUD_SCRIPT.cargo_cells()
	assert_eq(cells.size(), HUD_SCRIPT.CARGO_MAX)
	for i in cells.size():
		assert_eq(cells[i].size, Vector2(HUD_SCRIPT.CELL_SIZE, HUD_SCRIPT.CELL_SIZE))
		assert_eq(cells[i].position.y, cells[0].position.y)
		if i > 0:
			assert_gt(cells[i].position.x, cells[i - 1].end.x)
	var left: float = cells[0].position.x
	var right: float = cells[cells.size() - 1].end.x
	assert_almost_eq((left + right) * 0.5, 640.0, 1e-3)
	assert_gt(cells[0].position.y, HUD_SCRIPT.BOTTOM_Y)
	assert_lt(cells[0].end.y, 800.0)


func test_cargo_filled_count_follows_fill() -> void:
	for fill in [0.0, 0.2, 0.5, 1.0]:
		var filled := 0
		for i in HUD_SCRIPT.CARGO_MAX:
			if HUD_SCRIPT.cell_filled(i, fill):
				filled += 1
		assert_eq(filled, HUD_SCRIPT.cargo_count(fill))
	assert_true(HUD_SCRIPT.cell_filled(0, 1.0))
	assert_false(HUD_SCRIPT.cell_filled(HUD_SCRIPT.CARGO_MAX - 1, 0.0))


func test_cargo_colors_come_from_palette() -> void:
	assert_eq(HUD_SCRIPT.CARGO_FILL_COLOR, Palette.ORE)
	assert_eq(HUD_SCRIPT.CARGO_EMPTY_COLOR, Palette.HALO)


func test_debug_text_shows_energy_mass_and_hold_slots() -> void:
	assert_eq(HUD_SCRIPT.debug_text(ShipState.new()), "энергия 6.00 · масса 10.0 · трюм 2/10")


func test_debug_text_with_separate_tank_adds_tank_slots() -> void:
	Tuning.ship.separate_tank = true
	assert_eq(HUD_SCRIPT.debug_text(ShipState.new()), "энергия 6.00 · масса 10.0 · трюм 0/10 · бак 2/4")
