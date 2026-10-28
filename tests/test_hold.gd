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


func test_add_fuel_goes_to_tank() -> void:
	Tuning.ship.tank_capacity = 2
	var s := _empty()
	assert_eq(Hold.add(s, &"fuel", 3.0), 2.0)
	assert_eq(s.tank.size(), 2)
	assert_eq(s.hold.size(), 0)
	assert_eq(Hold.add(s, &"ore_base", 1.0), 1.0)
	assert_eq(s.hold.size(), 1)
	assert_eq(s.tank.size(), 2)


func test_fresh_state_tank_holds_two_full_fuel_cells_and_has_mass_10() -> void:
	var s := ShipState.new()
	assert_eq(s.tank.size(), 2)
	assert_eq(s.tank[0].type, &"fuel")
	assert_eq(s.tank[1].fill, 1.0)
	assert_eq(s.hold.size(), 0)
	assert_almost_eq(Hold.mass(s), 10.0, 1e-6)


func test_fresh_state_loadout_is_clamped_to_tank_capacity() -> void:
	Tuning.ship.loadout_fuel_cells = 8
	Tuning.ship.tank_capacity = 1
	assert_eq(ShipState.new().tank.size(), 1)


func test_add_rounding_residue_does_not_open_a_near_zero_cell() -> void:
	var s := _empty()
	for a in [0.2, 0.2, 0.2, 0.4]:
		Hold.add(s, &"ice", a)
	assert_eq(s.hold.size(), 1)
	assert_almost_eq(s.hold[0].fill, 1.0, 1e-6)


func test_energy_counts_only_tank_cells() -> void:
	var s := _empty()
	s.hold.append(_cell(&"fuel", 1.0))
	s.hold.append(_cell(&"ice", 1.0))
	s.hold.append(_cell(&"ore_rare", 1.0))
	s.tank.append(_cell(&"fuel", 0.5))
	assert_almost_eq(Hold.energy(s), 1.5, 1e-6)


func test_energy_counts_ice_cells_in_the_tank() -> void:
	var s := _empty()
	s.tank.append(_cell(&"ice", 0.5))
	s.tank.append(_cell(&"fuel", 1.0))
	assert_almost_eq(Hold.energy(s), 3.5, 1e-6)


func test_ice_added_to_hold_adds_mass_but_no_energy() -> void:
	var s := _empty()
	s.tank.append(_cell(&"fuel", 1.0))
	assert_eq(Hold.add(s, &"ice", 2.0), 2.0)
	assert_eq(s.hold.size(), 2)
	assert_almost_eq(Hold.energy(s), 3.0, 1e-6)
	assert_almost_eq(Hold.mass(s), Tuning.ship.hull_mass + 3.0 + 2.0, 1e-6)


func test_drain_takes_the_partial_tank_cell_first_and_erases_emptied_cells() -> void:
	var s := _empty()
	s.tank.append(_cell(&"fuel", 1.0))
	s.tank.append(_cell(&"fuel", 0.5))
	assert_almost_eq(Hold.drain(s, 1.5), 1.5, 1e-6)
	assert_eq(s.tank.size(), 1)
	assert_eq(s.tank[0].fill, 1.0)
	assert_almost_eq(Hold.drain(s, 0.6), 0.6, 1e-6)
	assert_almost_eq(s.tank[0].fill, 0.8, 1e-6)
	assert_almost_eq(Hold.mass(s), Tuning.ship.hull_mass + 2.4, 1e-6)
	assert_almost_eq(Hold.drain(s, 10.0), 2.4, 1e-6)
	assert_eq(s.tank.size(), 0)
	assert_eq(Hold.drain(s, 1.0), 0.0)


func test_drain_touches_only_the_tank() -> void:
	var s := _empty()
	s.hold.append(_cell(&"ice", 1.0))
	s.hold.append(_cell(&"fuel", 1.0))
	s.tank.append(_cell(&"fuel", 1.0))
	assert_almost_eq(Hold.drain(s, 5.0), 3.0, 1e-6)
	assert_eq(s.tank.size(), 0)
	assert_eq(s.hold.size(), 2)
	assert_eq(s.hold[0].fill, 1.0)
	assert_eq(s.hold[1].fill, 1.0)


func test_room_is_zero_for_a_full_hold_and_counts_the_free_part_of_a_partial_cell() -> void:
	var s := _empty()
	assert_eq(Hold.room(s, &"ice"), float(Tuning.ship.hold_capacity))
	assert_eq(Hold.room(s, &"fuel"), float(Tuning.ship.tank_capacity))
	s.hold.append(_cell(&"ice", 0.25))
	var free := Hold.room(s, &"ice")
	assert_eq(Hold.room(s, &"ice"), free)
	assert_eq(s.hold.size(), 1)
	assert_eq(s.hold[0].fill, 0.25)
	var probe := _empty()
	probe.hold.append(_cell(&"ice", 0.25))
	assert_almost_eq(Hold.add(probe, &"ice", 1000.0), free, 1e-6)
	var full := _empty()
	for i in Tuning.ship.hold_capacity:
		full.hold.append(_cell(&"ice", 1.0))
	assert_eq(Hold.room(full, &"ice"), 0.0)
	full.hold[0].fill = 0.5
	assert_almost_eq(Hold.room(full, &"ice"), 0.5, 1e-6)
	assert_eq(Hold.room(full, &"ore_middle"), 0.0)


func test_effective_pick_is_the_heaviest_hold_cell_and_advances_with_wrap() -> void:
	var s := _empty()
	assert_eq(Hold.effective_pick(s), -1)
	assert_eq(Hold.next_pick(s), -1)
	s.tank.append(_cell(&"fuel", 1.0))
	assert_eq(Hold.heaviest(s), -1)
	var light := _cell(&"ice", 0.1)
	var heavy := _cell(&"ice", 1.0)
	s.hold.append(light)
	s.hold.append(heavy)
	s.hold.append(_cell(&"ice", 1.0))
	assert_eq(Hold.heaviest(s), 1)
	assert_eq(Hold.effective_pick(s), 1)
	s.jettison_pick = 0
	assert_eq(Hold.effective_pick(s), 0)
	s.jettison_pick = 7
	assert_eq(Hold.effective_pick(s), 1)
	assert_eq(Hold.next_pick(s), 2)
	s.jettison_pick = 2
	assert_eq(Hold.next_pick(s), 0)
	s.jettison_pick = -1
	assert_eq(Hold.next_pick(s), 2)


func test_removing_a_hold_cell_returns_it_and_lowers_ship_mass() -> void:
	var s := _empty()
	s.hold.append(_cell(&"ice", 1.0))
	s.hold.append(_cell(&"ore_rare", 0.5))
	s.tank.append(_cell(&"fuel", 1.0))
	var before := Hold.mass(s)
	var c := Hold.remove_at(s, 1)
	assert_eq(c.type, &"ore_rare")
	assert_eq(s.hold.size(), 1)
	assert_eq(s.tank.size(), 1)
	assert_almost_eq(Hold.mass(s), before - 0.5 * Tuning.resources[&"ore_rare"].mass, 1e-6)


func test_drain_burns_tank_ice_before_fuel_partial_first() -> void:
	var s := _empty()
	s.tank.append(_cell(&"fuel", 0.5))
	s.tank.append(_cell(&"ice", 1.0))
	s.tank.append(_cell(&"fuel", 1.0))
	s.tank.append(_cell(&"ice", 0.5))
	s.hold.append(_cell(&"ice", 1.0))
	assert_almost_eq(Hold.drain(s, 0.5), 0.5, 1e-6)
	assert_eq(s.tank.size(), 3)
	assert_almost_eq(Hold.drain(s, 1.0), 1.0, 1e-6)
	assert_eq(s.tank.size(), 2)
	assert_eq(s.tank[0].type, &"fuel")
	assert_almost_eq(Hold.drain(s, 1.5), 1.5, 1e-6)
	assert_eq(s.tank.size(), 1)
	assert_almost_eq(s.tank[0].fill, 1.0, 1e-6)
	assert_almost_eq(Hold.drain(s, 3.0), 3.0, 1e-6)
	assert_true(s.tank.is_empty())
	assert_eq(s.hold.size(), 1)
	assert_almost_eq(s.hold[0].fill, 1.0, 1e-6)


func test_raw_transfer_moves_the_partial_ice_cell_into_the_tank() -> void:
	Tuning.ship.refiner = false
	var s := _empty()
	s.hold.append(_cell(&"ice", 1.0))
	s.hold.append(_cell(&"ice", 0.4))
	s.tank.append(_cell(&"fuel", 1.0))
	s.jettison_pick = 1
	var m := Hold.mass(s)
	assert_true(Hold.can_transfer(s))
	assert_true(Hold.transfer(s))
	assert_eq(s.hold.size(), 1)
	assert_eq(s.hold[0].fill, 1.0)
	assert_eq(s.tank.size(), 2)
	assert_eq(s.tank[1].type, &"ice")
	assert_almost_eq(s.tank[1].fill, 0.4, 1e-6)
	assert_almost_eq(Hold.mass(s), m, 1e-6)
	assert_eq(s.jettison_pick, -1)


func test_transfer_keeps_jettison_pick_on_the_same_cell() -> void:
	Tuning.ship.refiner = false
	var s := _empty()
	s.hold.append(_cell(&"ice", 0.4))
	s.hold.append(_cell(&"ore_rare", 1.0))
	s.hold.append(_cell(&"ore_base", 1.0))
	s.jettison_pick = 2
	assert_true(Hold.transfer(s))
	assert_eq(s.jettison_pick, 1)
	assert_eq(s.hold[s.jettison_pick].type, &"ore_base")


func test_raw_transfer_takes_first_ice_when_none_partial() -> void:
	Tuning.ship.refiner = false
	var s := _empty()
	s.hold.append(_cell(&"ore_base", 1.0))
	s.hold.append(_cell(&"ice", 1.0))
	assert_true(Hold.transfer(s))
	assert_eq(s.hold.size(), 1)
	assert_eq(s.tank.size(), 1)


func test_raw_transfer_fails_with_full_tank_or_no_ice() -> void:
	Tuning.ship.refiner = false
	var s := _empty()
	s.hold.append(_cell(&"ore_base", 1.0))
	assert_false(Hold.can_transfer(s))
	assert_false(Hold.transfer(s))
	s.hold.append(_cell(&"ice", 1.0))
	for i in Tuning.ship.tank_capacity:
		s.tank.append(_cell(&"fuel", 1.0))
	assert_false(Hold.can_transfer(s))
	assert_false(Hold.transfer(s))
	assert_eq(s.hold.size(), 2)
	assert_eq(s.tank.size(), Tuning.ship.tank_capacity)


func test_refined_transfer_turns_one_ice_cell_into_a_third_of_a_fuel_cell() -> void:
	Tuning.ship.refiner = true
	var s := _empty()
	s.hold.append(_cell(&"ice", 1.0))
	s.tank.append(_cell(&"fuel", 0.5))
	var e := Hold.energy(s) + 1.0
	var m := Hold.mass(s) - 1.0 + 3.0 / 3.0
	assert_true(Hold.transfer(s))
	assert_true(s.hold.is_empty())
	assert_eq(s.tank.size(), 1)
	assert_almost_eq(s.tank[0].fill, 0.5 + 1.0 / 3.0, 1e-6)
	assert_almost_eq(Hold.energy(s), e, 1e-6)
	assert_almost_eq(Hold.mass(s), m, 1e-6)


func test_refined_transfer_scales_with_fill() -> void:
	Tuning.ship.refiner = true
	var s := _empty()
	s.hold.append(_cell(&"ice", 0.6))
	assert_true(Hold.transfer(s))
	assert_almost_eq(s.tank[0].fill, 0.2, 1e-6)


func test_refined_transfer_without_room_changes_nothing() -> void:
	Tuning.ship.refiner = true
	var s := _empty()
	s.hold.append(_cell(&"ice", 1.0))
	for i in Tuning.ship.tank_capacity:
		s.tank.append(_cell(&"fuel", 1.0))
	assert_false(Hold.can_transfer(s))
	assert_false(Hold.transfer(s))
	assert_eq(s.hold.size(), 1)
	assert_eq(s.tank[0].fill, 1.0)


func test_refined_transfer_is_exact_when_room_is_a_hair_short() -> void:
	Tuning.ship.refiner = true
	var s := _empty()
	s.hold.append(_cell(&"ice", 0.5))
	s.tank.append(_cell(&"fuel", 1.0))
	s.tank.append(_cell(&"fuel", 1.0))
	s.tank.append(_cell(&"fuel", 1.0))
	var partial: float = 1.0 - 0.5 / 3.0 + 5e-7
	s.tank.append(_cell(&"fuel", partial))
	assert_false(Hold.can_transfer(s))
	assert_false(Hold.transfer(s))
	assert_eq(s.hold.size(), 1)
	assert_eq(s.tank[3].fill, partial)
