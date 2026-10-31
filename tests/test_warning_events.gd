extends GutTest

var _saved_ship
var _saved_planet


func before_each() -> void:
	_saved_ship = Tuning.ship
	_saved_planet = Tuning.planet
	Tuning.ship = Tuning.ship.duplicate()
	Tuning.planet = Tuning.planet.duplicate()


func after_each() -> void:
	Tuning.ship = _saved_ship
	Tuning.planet = _saved_planet


func _snap(over := {}) -> Dictionary:
	var d := {"r": Tuning.field.carrier_orbit_radius, "hull": 100.0, "atmo_loss": 0.0, "reserve": 0, "violation": "", "tow_left": -1.0, "notice": "", "notice_left": 0.0}
	d.merge(over, true)
	return d


func _types(events: Array) -> Array:
	var out := []
	for e in events:
		out.append(e[0])
	return out


func test_crossing_below_the_tow_boundary_gives_one_boundary_event() -> void:
	Tuning.ship.service_boat = false
	var tow: float = WellGenerator.tiers().tow
	var ev := WarningEvents.detect(_snap({"r": tow + 1.0}), _snap({"r": tow - 1.0}))
	assert_eq(_types(ev), [&"boundary"])
	assert_eq(ev[0][1], "граница буксира: ниже буксир не придёт")
	assert_eq(WarningEvents.detect(_snap({"r": tow - 2.0}), _snap({"r": tow - 1.0})), [])
	assert_eq(WarningEvents.detect(_snap({"r": tow - 1.0}), _snap({"r": tow + 1.0})), [])


func test_boundary_text_for_the_service_boat_and_its_violation_gives_no_extra_event() -> void:
	Tuning.ship.service_boat = true
	Tuning.planet.violation_time = 10.0
	var tow: float = WellGenerator.tiers().tow
	var ev := WarningEvents.detect(_snap({"r": tow + 1.0}), _snap({"r": tow - 1.0, "violation": "boundary"}))
	assert_eq(_types(ev), [&"boundary"])
	assert_eq(ev[0][1], "ниже границы: принудительный буксир через 10 с")


func test_atmosphere_entry_gives_one_event() -> void:
	var edge: float = Tuning.field.atmosphere_edge
	var ev := WarningEvents.detect(_snap({"r": edge + 1.0}), _snap({"r": edge - 1.0}))
	assert_eq(_types(ev), [&"atmosphere"])
	assert_eq(ev[0][1], "атмосфера")
	assert_eq(WarningEvents.detect(_snap({"r": edge - 2.0}), _snap({"r": edge - 1.0})), [])
	assert_eq(WarningEvents.detect(_snap({"r": edge - 1.0}), _snap({"r": edge + 1.0})), [])


func test_reserve_gives_an_event_only_when_it_gets_worse() -> void:
	var ev := WarningEvents.detect(_snap({"reserve": 0}), _snap({"reserve": 1}))
	assert_eq(_types(ev), [&"reserve"])
	assert_eq(ev[0][1], "запас на пределе")
	ev = WarningEvents.detect(_snap({"reserve": 1}), _snap({"reserve": 2}))
	assert_eq(ev[0][1], "топлива не хватит на подъём")
	ev = WarningEvents.detect(_snap({"reserve": 0}), _snap({"reserve": 2}))
	assert_eq(ev[0][1], "топлива не хватит на подъём")
	assert_eq(WarningEvents.detect(_snap({"reserve": 2}), _snap({"reserve": 1})), [])
	assert_eq(WarningEvents.detect(_snap({"reserve": 1}), _snap({"reserve": 1})), [])


func test_hull_loss_above_atmosphere_damage_is_an_impact() -> void:
	var ev := WarningEvents.detect(_snap({"hull": 100.0}), _snap({"hull": 90.0, "atmo_loss": 0.05}))
	assert_eq(_types(ev), [&"impact"])
	assert_eq(ev[0][1], "удар")


func test_atmosphere_damage_alone_is_not_an_impact() -> void:
	assert_eq(WarningEvents.detect(_snap({"hull": 100.0}), _snap({"hull": 99.9, "atmo_loss": 0.1})), [])
	assert_eq(WarningEvents.detect(_snap({"hull": 100.0}), _snap({"hull": 100.0})), [])
	assert_eq(WarningEvents.detect(_snap({"hull": 90.0}), _snap({"hull": 100.0})), [])


func test_ceiling_violation_start_gives_one_event_with_countdown() -> void:
	Tuning.planet.violation_time = 9.5
	var ev := WarningEvents.detect(_snap({"violation": ""}), _snap({"violation": "ceiling"}))
	assert_eq(_types(ev), [&"ceiling"])
	assert_eq(ev[0][1], "потолок: буксир через 10 с")
	assert_eq(WarningEvents.detect(_snap({"violation": "ceiling"}), _snap({"violation": "ceiling"})), [])
	assert_eq(WarningEvents.detect(_snap({"violation": "ceiling"}), _snap({"violation": ""})), [])


func test_tow_call_gives_one_event_with_countdown() -> void:
	var ev := WarningEvents.detect(_snap({"tow_left": -1.0}), _snap({"tow_left": 4.2}))
	assert_eq(_types(ev), [&"tow"])
	assert_eq(ev[0][1], "буксир вызван · через 5 с")
	assert_eq(WarningEvents.detect(_snap({"tow_left": 4.2}), _snap({"tow_left": 4.1})), [])
	assert_eq(WarningEvents.detect(_snap({"tow_left": 0.5}), _snap({"tow_left": -1.0})), [])


func test_refused_tow_shows_the_notice_when_notice_left_rises() -> void:
	var ev := WarningEvents.detect(_snap({"notice_left": 0.0}), _snap({"notice": "ниже границы буксира", "notice_left": 2.0}))
	assert_eq(_types(ev), [&"tow_refused"])
	assert_eq(ev[0][1], "ниже границы буксира")
	assert_eq(WarningEvents.detect(_snap({"notice_left": 2.0}), _snap({"notice": "ниже границы буксира", "notice_left": 1.9})), [])
