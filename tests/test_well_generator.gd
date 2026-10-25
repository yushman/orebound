extends GutTest

const PRESETS := ["res://presets/p1.tres", "res://presets/p2.tres", "res://presets/p3.tres", "res://presets/p4.tres"]

var _saved_field
var _saved_ship
var _saved_planet


func before_each():
	_saved_field = Tuning.field
	_saved_ship = Tuning.ship
	_saved_planet = Tuning.planet


func after_each():
	Tuning.field = _saved_field
	Tuning.ship = _saved_ship
	Tuning.planet = _saved_planet


func _setups() -> Array:
	var out := [null]
	out.append_array(PRESETS)
	return out


func _use(setup) -> void:
	if setup != null:
		Tuning.apply(Tuning.load_preset(setup))


func test_boundaries_ascending_between_edge_and_carrier():
	for setup in _setups():
		_use(setup)
		var b: Array = WellGenerator.tiers()["boundaries"]
		assert_eq(b.size(), 5, str(setup))
		if b.size() != 5:
			continue
		assert_eq(b[0], Tuning.field.atmosphere_edge)
		assert_eq(b[4], Tuning.field.carrier_orbit_radius)
		for i in 4:
			assert_gt(b[i + 1], b[i], "%s boundary %d" % [setup, i])


func test_adjacent_boundaries_differ_by_share_times_swing():
	for setup in _setups():
		_use(setup)
		var b: Array = WellGenerator.tiers()["boundaries"]
		if b.size() != 5:
			assert_eq(b.size(), 5)
			continue
		var swing: float = GravityField.planet_potential_eff(b[4]) - GravityField.planet_potential_eff(b[0])
		var shares: Array = Tuning.planet.tier_shares
		for i in 4:
			var d: float = GravityField.planet_potential_eff(b[i + 1]) - GravityField.planet_potential_eff(b[i])
			var want: float = shares[3 - i] * swing
			assert_almost_eq(d, want, absf(want) * 1e-3, "%s tier %d" % [setup, i])


func test_inner_radii_differ_between_presets():
	Tuning.apply(Tuning.load_preset(PRESETS[0]))
	var b1: Array = WellGenerator.tiers()["boundaries"]
	Tuning.apply(Tuning.load_preset(PRESETS[1]))
	var b2: Array = WellGenerator.tiers()["boundaries"]
	assert_eq(b1.size(), 5)
	assert_eq(b2.size(), 5)
	if b1.size() == 5 and b2.size() == 5:
		assert_ne(b1[2], b2[2])


func test_tow_is_middle_tier_bottom_and_ceiling_is_carrier_plus_offset():
	for setup in _setups():
		_use(setup)
		var t: Dictionary = WellGenerator.tiers()
		var b: Array = t["boundaries"]
		assert_eq(b.size(), 5, str(setup))
		if b.size() != 5:
			continue
		assert_eq(t["tow"], b[2])
		var lo: float = GravityField.planet_potential_eff(b[0])
		var swing: float = GravityField.planet_potential_eff(b[4]) - lo
		assert_almost_eq(GravityField.planet_potential_eff(t["tow"]) - lo, 0.35 * swing, swing * 1e-3, str(setup))
		assert_eq(t["ceiling"], Tuning.field.carrier_orbit_radius + Tuning.planet.ceiling_offset)


func test_ceiling_follows_planet_offset_without_cache():
	var before: float = WellGenerator.tiers()["ceiling"]
	var p := PlanetParams.new()
	p.ceiling_offset = 777.0
	Tuning.planet = p
	assert_eq(WellGenerator.tiers()["ceiling"], Tuning.field.carrier_orbit_radius + 777.0)
	assert_ne(WellGenerator.tiers()["ceiling"], before)
