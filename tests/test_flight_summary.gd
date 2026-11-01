extends GutTest


func _cell(type: StringName, fill: float) -> HoldCell:
	var c := HoldCell.new()
	c.type = type
	c.fill = fill
	return c


func _state() -> ShipState:
	var s := ShipState.new()
	s.hold.append(_cell(&"ice", 1.0))
	s.hold.append(_cell(&"ore_middle", 0.5))
	s.hold.append(_cell(&"ice", 0.5))
	s.fuel_engine = 1.5
	s.fuel_boost = 2.5
	s.fuel_soft_brake = 0.25
	s.fuel_sync = 0.75
	return s


func test_build_gives_returned_with_cargo_mass_by_type_and_fuel_by_category() -> void:
	var d := FlightSummary.build(_state(), "returned", 83.0)
	assert_eq(d["outcome"], "returned")
	assert_false(d["cargo_lost"])
	assert_eq(d["cargo"].size(), 2)
	assert_almost_eq(d["cargo"][&"ice"], 1.5, 1e-6)
	assert_almost_eq(d["cargo"][&"ore_middle"], 1.0, 1e-6)
	assert_eq(d["fuel"], {"engine": 1.5, "boost": 2.5, "soft_brake": 0.25, "sync": 0.75})
	assert_eq(d["time"], 83.0)


func test_crashed_marks_cargo_lost_but_still_lists_it() -> void:
	var d := FlightSummary.build(_state(), "crashed", 10.0)
	assert_eq(d["outcome"], "crashed")
	assert_true(d["cargo_lost"])
	assert_almost_eq(d["cargo"][&"ice"], 1.5, 1e-6)


func test_empty_hold_has_empty_cargo() -> void:
	var d := FlightSummary.build(ShipState.new(), "returned", 0.0)
	assert_true(d["cargo"].is_empty())


func test_build_carries_seized_mass_by_type_and_share_for_towed() -> void:
	var d := FlightSummary.build(_state(), "towed", 5.0, {"seized": {&"ice": 0.5}, "share": 0.25})
	assert_eq(d["outcome"], "towed")
	assert_eq(d["seized"], {&"ice": 0.5})
	assert_eq(d["seized_share"], 0.25)


func test_seized_defaults_are_empty() -> void:
	var d := FlightSummary.build(_state(), "returned", 5.0)
	assert_true(d["seized"].is_empty())
	assert_eq(d["seized_share"], 0.0)


func test_tow_kind_for_towed_only() -> void:
	assert_eq(FlightSummary.build(_state(), "towed", 5.0, {"kind": "ceiling"})["tow_kind"], "ceiling")
	assert_eq(FlightSummary.build(_state(), "towed", 5.0, {"kind": "manual"})["tow_kind"], "manual")
	assert_eq(FlightSummary.build(_state(), "returned", 5.0)["tow_kind"], "")


func test_build_carries_real_time() -> void:
	assert_eq(FlightSummary.build(_state(), "returned", 83.0, {}, 21.0)["real_time"], 21.0)


func test_summary_lines_end_with_build_label() -> void:
	var rows: PackedStringArray = load("res://ui/Summary.gd").lines(FlightSummary.build(_state(), "returned", 83.0, {}, 21.0))
	assert_eq(rows[rows.size() - 1], BuildInfo.label())
	assert_eq(rows[rows.size() - 2], "Enter / A — следующий вылет")
