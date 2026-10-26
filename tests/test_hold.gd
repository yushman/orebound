extends GutTest

var _saved_ship: ShipParams


func before_each() -> void:
	_saved_ship = Tuning.ship.duplicate()


func after_each() -> void:
	Tuning.ship = _saved_ship


func _cell(type: StringName, fill: float) -> HoldCell:
	var c := HoldCell.new()
	c.type = type
	c.fill = fill
	return c


func _empty() -> ShipState:
	var s := ShipState.new()
	s.hold.clear()
	s.tank.clear()
	return s


func test_mass_is_hull_mass_plus_fill_times_type_mass_over_hold_and_tank() -> void:
	var s := _empty()
	assert_eq(Hold.mass(s), Tuning.ship.hull_mass)
	s.hold.append(_cell(&"ore_rare", 0.5))
	s.hold.append(_cell(&"ice", 1.0))
	s.tank.append(_cell(&"fuel", 1.0))
	assert_almost_eq(Hold.mass(s), Tuning.ship.hull_mass + 1.5 + 1.0 + 3.0, 1e-6)


func test_used_volume_counts_partial_cell_as_whole() -> void:
	var s := _empty()
	s.hold.append(_cell(&"ice", 0.25))
	s.hold.append(_cell(&"ore_middle", 1.0))
	assert_eq(Hold.used_volume(s.hold), 2.0)


func test_add_never_exceeds_hold_capacity_and_returns_the_amount_added() -> void:
	Tuning.ship.hold_capacity = 3
	var s := _empty()
	assert_eq(Hold.add(s, &"ice", 1.5), 1.5)
	assert_eq(s.hold.size(), 2)
	assert_eq(s.hold[0].fill, 1.0)
	assert_eq(s.hold[1].fill, 0.5)
	assert_eq(Hold.add(s, &"ice", 0.25), 0.25)
	assert_eq(s.hold.size(), 2)
	assert_eq(s.hold[1].fill, 0.75)
	assert_eq(Hold.add(s, &"ore_base", 5.0), 1.0)
	assert_eq(Hold.used_volume(s.hold), 3.0)
	assert_eq(Hold.add(s, &"ice", 1.0), 0.25)
	assert_eq(Hold.add(s, &"ice", 1.0), 0.0)


func test_add_fuel_goes_to_tank_in_separate_tank_mode() -> void:
	Tuning.ship.separate_tank = true
	Tuning.ship.tank_capacity = 2
	var s := _empty()
	assert_eq(Hold.add(s, &"fuel", 3.0), 2.0)
	assert_eq(s.tank.size(), 2)
	assert_eq(s.hold.size(), 0)
	assert_eq(Hold.add(s, &"ore_base", 1.0), 1.0)
	assert_eq(s.hold.size(), 1)
	assert_eq(s.tank.size(), 2)


func test_add_fuel_goes_to_hold_in_single_hold_mode() -> void:
	Tuning.ship.separate_tank = false
	var s := _empty()
	assert_eq(Hold.add(s, &"fuel", 2.0), 2.0)
	assert_eq(s.hold.size(), 2)
	assert_eq(s.tank.size(), 0)


func test_fresh_state_holds_two_full_fuel_cells_and_has_mass_10() -> void:
	var s := ShipState.new()
	assert_eq(s.hold.size(), 2)
	assert_eq(s.hold[0].type, &"fuel")
	assert_eq(s.hold[1].fill, 1.0)
	assert_eq(s.tank.size(), 0)
	assert_almost_eq(Hold.mass(s), 10.0, 1e-6)


func test_fresh_state_loadout_goes_to_tank_in_separate_tank_mode() -> void:
	Tuning.ship.separate_tank = true
	var s := ShipState.new()
	assert_eq(s.hold.size(), 0)
	assert_eq(s.tank.size(), 2)


func test_fresh_state_loadout_is_clamped_to_capacity() -> void:
	Tuning.ship.loadout_fuel_cells = 8
	Tuning.ship.hold_capacity = 3
	assert_eq(ShipState.new().hold.size(), 3)
	Tuning.ship.separate_tank = true
	Tuning.ship.tank_capacity = 1
	assert_eq(ShipState.new().tank.size(), 1)


func test_add_rounding_residue_does_not_open_a_near_zero_cell() -> void:
	var s := _empty()
	for a in [0.2, 0.2, 0.2, 0.4]:
		Hold.add(s, &"ice", a)
	assert_eq(s.hold.size(), 1)
	assert_almost_eq(s.hold[0].fill, 1.0, 1e-6)


func test_energy_sums_fill_times_resource_energy_of_fuel_and_ice_cells() -> void:
	var s := _empty()
	s.hold.append(_cell(&"fuel", 0.5))
	s.hold.append(_cell(&"ice", 1.0))
	s.hold.append(_cell(&"ore_rare", 1.0))
	s.tank.append(_cell(&"fuel", 1.0))
	assert_almost_eq(Hold.energy(s), 2.5, 1e-6)


func test_energy_in_separate_tank_mode_counts_only_tank_fuel() -> void:
	Tuning.ship.separate_tank = true
	var s := _empty()
	s.hold.append(_cell(&"fuel", 1.0))
	s.hold.append(_cell(&"ice", 1.0))
	s.tank.append(_cell(&"fuel", 0.5))
	assert_almost_eq(Hold.energy(s), 1.5, 1e-6)


func test_drain_takes_the_partial_fuel_cell_first_then_full_fuel_then_ice_and_erases_emptied_cells() -> void:
	var s := _empty()
	s.hold.append(_cell(&"ice", 1.0))
	s.hold.append(_cell(&"fuel", 1.0))
	s.hold.append(_cell(&"ore_base", 1.0))
	s.hold.append(_cell(&"fuel", 0.5))
	assert_almost_eq(Hold.drain(s, 1.5), 1.5, 1e-6)
	assert_eq(s.hold.size(), 3)
	assert_eq(s.hold[1].type, &"fuel")
	assert_eq(s.hold[1].fill, 1.0)
	assert_almost_eq(Hold.drain(s, 0.6), 0.6, 1e-6)
	assert_almost_eq(s.hold[1].fill, 0.8, 1e-6)
	assert_almost_eq(Hold.drain(s, 2.4 + 0.5), 2.9, 1e-6)
	assert_eq(s.hold.size(), 2)
	assert_eq(s.hold[0].type, &"ice")
	assert_almost_eq(s.hold[0].fill, 0.5, 1e-6)
	assert_eq(s.hold[1].type, &"ore_base")
	assert_almost_eq(Hold.mass(s), Tuning.ship.hull_mass + 0.5 + 1.0, 1e-6)
	assert_almost_eq(Hold.drain(s, 10.0), 0.5, 1e-6)
	assert_eq(s.hold.size(), 1)
	assert_eq(s.hold[0].type, &"ore_base")
	assert_eq(Hold.drain(s, 1.0), 0.0)


func test_drain_in_separate_tank_mode_touches_only_the_tank() -> void:
	Tuning.ship.separate_tank = true
	var s := _empty()
	s.hold.append(_cell(&"ice", 1.0))
	s.tank.append(_cell(&"fuel", 1.0))
	assert_almost_eq(Hold.drain(s, 5.0), 3.0, 1e-6)
	assert_eq(s.tank.size(), 0)
	assert_eq(s.hold.size(), 1)
	assert_eq(s.hold[0].fill, 1.0)
