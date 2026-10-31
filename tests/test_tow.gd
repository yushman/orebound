extends GutTest


func _cell(type: StringName, fill: float) -> HoldCell:
	var c := HoldCell.new()
	c.type = type
	c.fill = fill
	return c


func _state(r: float, cells := 2) -> ShipState:
	var s := ShipState.new()
	s.pos = Vector2(r, 0)
	for i in cells:
		s.hold.append(_cell(&"ore_middle", 1.0))
	return s


func test_fee_grows_with_depth_and_hold_mass() -> void:
	var tow_r: float = WellGenerator.tiers()["tow"]
	var rc: float = Tuning.field.carrier_orbit_radius
	var near := Tow.fee(_state(rc))
	var deep := Tow.fee(_state(tow_r))
	assert_gt(deep, near)
	assert_gt(Tow.fee(_state(tow_r, 4)), deep)


func test_prices() -> void:
	var p := {&"ice": 5.0, &"ore_base": 8.0, &"ore_middle": 25.0, &"ore_rare": 70.0, &"ore_unique": 400.0, &"fuel": 20.0}
	for k in p:
		assert_eq(Tuning.resources[k].price, p[k], str(k))


func test_refusal() -> void:
	var tow_r: float = WellGenerator.tiers()["tow"]
	assert_eq(Tow.refusal(Vector2(tow_r + 1.0, 0)), "")
	assert_eq(Tow.refusal(Vector2(tow_r - 1.0, 0)), "ниже границы буксира")


func test_seized_share_and_cargo_value() -> void:
	var s := _state(WellGenerator.tiers()["tow"])
	assert_almost_eq(Tow.cargo_value(s), 50.0, 1e-6)
	var share := Tow.seized_share(s)
	assert_almost_eq(share, minf(1.0, Tow.fee(s) / 50.0), 1e-6)
	assert_eq(Tow.seized_share(ShipState.new()), 0.0)


func test_share_capped_at_one() -> void:
	var s := _state(WellGenerator.tiers()["tow"])
	s.hold = [_cell(&"ice", 0.01)]
	assert_eq(Tow.seized_share(s), 1.0)


func test_pay_scales_cells_clears_tank_and_reports() -> void:
	var s := _state(WellGenerator.tiers()["tow"], 1)
	s.hold[0].fill = 1.0
	s.hold.append(_cell(&"ice", 1.0))
	var share := Tow.seized_share(s)
	var fee := Tow.fee(s)
	var energy := Hold.energy(s)
	var r := Tow.pay(s)
	assert_almost_eq(r["share"], share, 1e-6)
	assert_almost_eq(r["fee"], fee, 1e-6)
	assert_almost_eq(r["drained_energy"], energy, 1e-6)
	assert_gt(energy, 0.0)
	assert_true(s.tank.is_empty())
	if share < 1.0:
		assert_almost_eq(s.hold[0].fill, 1.0 - share, 1e-6)
	assert_almost_eq(r["seized"][&"ore_middle"], share * 2.0, 1e-6)


func test_pay_drops_emptied_cells() -> void:
	var s := _state(WellGenerator.tiers()["tow"], 1)
	s.hold = [_cell(&"ice", 0.01)]
	var r := Tow.pay(s)
	assert_eq(r["share"], 1.0)
	assert_true(s.hold.is_empty())
