extends GutTest

const TMP := "user://test_tuning_preset.tres"

var _field: FieldParams
var _ship: ShipParams


func before_each() -> void:
	_field = Tuning.field
	_ship = Tuning.ship


func after_each() -> void:
	Tuning.field = _field
	Tuning.ship = _ship
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(TMP)


func _assert_body_eq(a: BodyParams, b: BodyParams) -> void:
	assert_eq(a.mass, b.mass)
	assert_eq(a.p, b.p)
	assert_eq(a.influence_radius, b.influence_radius)
	assert_eq(a.parent, b.parent)
	assert_eq(a.orbit_radius, b.orbit_radius)
	assert_eq(a.angular_speed, b.angular_speed)
	assert_eq(a.phase, b.phase)


func _assert_field_eq(a: FieldParams, b: FieldParams) -> void:
	assert_eq(a.k, b.k)
	assert_eq(a.eps, b.eps)
	assert_eq(a.fade_width, b.fade_width)
	assert_eq(a.planet_surface_radius, b.planet_surface_radius)
	assert_eq(a.atmosphere_edge, b.atmosphere_edge)
	assert_eq(a.carrier_orbit_radius, b.carrier_orbit_radius)
	assert_eq(a.bodies.size(), b.bodies.size())
	for i in mini(a.bodies.size(), b.bodies.size()):
		_assert_body_eq(a.bodies[i], b.bodies[i])


func _assert_ship_eq(a: ShipParams, b: ShipParams) -> void:
	for prop in a.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			assert_eq(a.get(prop.name), b.get(prop.name), prop.name)


func test_save_load_round_trip() -> void:
	var f := FieldParams.new()
	f.k = 7.0
	f.eps = 0.3
	f.fade_width = 0.7
	f.planet_surface_radius = 120.0
	f.atmosphere_edge = 170.0
	f.carrier_orbit_radius = 450.0
	var bodies: Array[BodyParams] = []
	for i in 3:
		var b := BodyParams.new()
		b.mass = 11.0 + i
		b.p = 1.5 + i * 0.1
		b.influence_radius = 5.0 + i
		b.parent = i - 1
		b.orbit_radius = 100.0 * i
		b.angular_speed = 0.25 * i
		b.phase = 0.5 * i
		bodies.append(b)
	f.bodies = bodies
	var s := ShipParams.new()
	s.thrust_accel = 123.0
	s.boost_accel_mult = 1.5
	s.turn_accel = 3.0
	s.spin_damping = 2.0
	s.heading_gain = 9.0
	s.boost_fuel_mult = 2.0
	s.brake_accel = 77.0
	s.brake_fuel_mult = 1.1
	s.predict_short_steps = 11
	s.predict_every = 3
	s.hull_mass = 5.5
	s.hold_capacity = 7
	s.ref_mass = 12.0
	s.loadout_fuel_cells = 3
	s.tank_capacity = 6
	Tuning.field = f
	Tuning.ship = s
	assert_eq(Tuning.save_preset(TMP, "X"), OK)
	var loaded: TuningPreset = Tuning.load_preset(TMP)
	assert_not_null(loaded)
	if loaded == null:
		return
	assert_eq(loaded.name, "X")
	assert_eq(loaded.field.bodies.size(), 1, "save keeps only the planet")
	var expected: FieldParams = f.duplicate(true)
	expected.bodies = [f.bodies[0]]
	_assert_field_eq(loaded.field, expected)
	_assert_ship_eq(loaded.ship, s)


func _preset_with(n_bodies: int) -> TuningPreset:
	var pr := TuningPreset.new()
	pr.field = Tuning._default_field()
	pr.field.k = 42.0
	pr.field.bodies.resize(n_bodies)
	for i in n_bodies:
		if pr.field.bodies[i] == null:
			pr.field.bodies[i] = BodyParams.new()
	pr.ship = ShipParams.new()
	pr.ship.thrust_accel = 99.0
	return pr


func test_apply_accepts_preset_with_any_body_count() -> void:
	var pr := _preset_with(3)
	watch_signals(Tuning)
	Tuning.apply(pr)
	assert_push_error_count(0)
	assert_eq(Tuning.field.bodies.size(), 3, "3-body preset applied on 1-body default")
	assert_signal_emit_count(Tuning, "preset_applied", 1)
	assert_eq(Tuning.field.k, 42.0)
	assert_eq(Tuning.ship.thrust_accel, 99.0)


func test_apply_deep_copies_and_emits() -> void:
	var pr := _preset_with(3)
	watch_signals(Tuning)
	Tuning.apply(pr)
	assert_signal_emit_count(Tuning, "preset_applied", 1)
	assert_eq(Tuning.field.k, 42.0)
	assert_eq(Tuning.ship.thrust_accel, 99.0)
	var before := pr.field.bodies[0].p
	Tuning.field.bodies[0].p = before + 1.0
	Tuning.ship.thrust_accel = 1.0
	assert_eq(pr.field.bodies[0].p, before)
	assert_eq(pr.ship.thrust_accel, 99.0)


func test_apply_with_emit_false_is_silent() -> void:
	var pr := _preset_with(3)
	watch_signals(Tuning)
	Tuning.apply(pr, false)
	assert_signal_not_emitted(Tuning, "preset_applied")
	assert_eq(Tuning.field.k, 42.0)
	assert_eq(Tuning.ship.thrust_accel, 99.0)


const PRESET_P := {1: 2.0, 2: 1.0, 3: 1.5, 4: 2.0}


func _load_n(n: int) -> TuningPreset:
	return Tuning.load_preset("res://presets/p%d.tres" % n)


func test_preset_p_values() -> void:
	for n in PRESET_P:
		var pr := _load_n(n)
		assert_not_null(pr, "p%d" % n)
		if pr == null:
			continue
		assert_eq(pr.field.bodies[0].p, PRESET_P[n], "p%d planet" % n)


func test_preset_common_params() -> void:
	for n in PRESET_P:
		var pr := _load_n(n)
		if pr == null:
			fail_test("p%d missing" % n)
			continue
		assert_eq(pr.field.k, 1000.0)
		assert_eq(pr.field.eps, 1.0)
		assert_eq(pr.field.fade_width, 0.5)
		var ship := ShipParams.new()
		if n == 4:
			ship.thrust_accel = 30.5
		_assert_ship_eq(pr.ship, ship)
		assert_eq(pr.field.bodies.size(), 1, "p%d presets carry only the planet" % n)
		var pl := pr.field.bodies[0]
		assert_eq(pl.angular_speed, 0.0, "p%d planet static" % n)
		assert_eq(pl.parent, -1, "p%d planet parent" % n)
		assert_eq(pl.orbit_radius, 0.0, "p%d planet orbit" % n)


func test_preset_files_define_hold_params() -> void:
	var names := ["hull_mass", "hold_capacity", "ref_mass", "loadout_fuel_cells", "tank_capacity", "climb_coefficient"]
	for n in PRESET_P:
		var text := FileAccess.get_file_as_string("res://presets/p%d.tres" % n)
		var i := text.find("ShipParams.gd\" id=\"") + 19
		var id := text.substr(i, text.find("\"", i) - i)
		var start := text.find("script = ExtResource(\"%s\")" % id)
		var end := text.find("\n\n", start)
		var block := text.substr(start, end - start)
		for name in names:
			assert_true(block.contains("\n%s = " % name), "p%d defines %s" % [n, name])


func test_presets_pin_d35_frame_radii() -> void:
	# R5: the D35 radii are written into the .tres explicitly (they used to
	# come from script defaults by omission).
	for n in PRESET_P:
		var pr := _load_n(n)
		if pr == null:
			fail_test("p%d missing" % n)
			continue
		assert_eq(pr.field.planet_surface_radius, 100000.0, "p%d planet_surface_radius" % n)
		assert_eq(pr.field.atmosphere_edge, 101500.0, "p%d atmosphere_edge" % n)
		assert_eq(pr.field.carrier_orbit_radius, 121500.0, "p%d carrier_orbit_radius" % n)


func _phi_unit(p: float, r: float) -> float:
	# Antiderivative of g = μ/r^p per unit μ (ε → 0), the same shape as
	# GravityField._phi_raw.
	if absf(p - 1.0) < 1e-4:
		return log(r)
	return -pow(r, 1.0 - p) / (p - 1.0)


func _c_of_p(p: float) -> float:
	# ΔΦ_eff per unit μ for the carrier → edge swing: the gravity swing
	# Φ(r_c) − Φ(r_e) minus the centrifugal term at Ω_f² = μ/r_c^(p+1).
	var rc := 121500.0
	var re := 101500.0
	return (_phi_unit(p, rc) - _phi_unit(p, re)) - 0.5 * (rc * rc - re * re) / pow(rc, p + 1.0)


func _target_swing() -> float:
	# D35 reference recipe (p = 2): μ₂ = Ω_f²·r_c³ with Ω_f = 0.00255.
	return pow(0.00255, 2.0) * pow(121500.0, 3.0) * _c_of_p(2.0)


func test_preset_planet_masses_equal_swing() -> void:
	# μ(p) = ΔΦ_target/C(p), mass = μ(p)/k — every planet curve gives the
	# same full carrier → edge swing.
	for n in PRESET_P:
		var pr := _load_n(n)
		if pr == null:
			fail_test("p%d missing" % n)
			continue
		var f := pr.field
		var pl := f.bodies[0]
		var want := _target_swing() / _c_of_p(pl.p) / f.k
		assert_almost_eq(pl.mass / want, 1.0, 1e-9, "p%d planet mass = μ(p)/k" % n)


func test_equal_d35_delta_phi_eff_across_presets() -> void:
	# Planet-only fields built from each preset's planet (moons would add
	# phase noise): the full Φ_eff swing carrier → atmosphere edge is the
	# same in all four presets (D29/D35 «честное сравнение»).
	var swings := {}
	for n in PRESET_P:
		var pr := _load_n(n)
		if pr == null:
			fail_test("p%d missing" % n)
			continue
		var f := FieldParams.new()
		f.k = pr.field.k
		f.eps = pr.field.eps
		f.fade_width = pr.field.fade_width
		f.planet_surface_radius = pr.field.planet_surface_radius
		f.atmosphere_edge = pr.field.atmosphere_edge
		f.carrier_orbit_radius = pr.field.carrier_orbit_radius
		f.bodies = [pr.field.bodies[0].duplicate()]
		Tuning.field = f
		var swing: float = GravityField.potential_eff(Vector2(121500.0, 0.0), 0.0) - GravityField.potential_eff(Vector2(101500.0, 0.0), 0.0)
		swings[n] = swing
		assert_almost_eq(swing / _target_swing(), 1.0, 0.02, "p%d swing vs target" % n)
	var ref: float = swings[1]
	for n in swings:
		assert_almost_eq(float(swings[n]) / ref, 1.0, 0.02, "p%d swing vs p1" % n)
	assert_almost_eq(ref / 4409.0, 1.0, 0.02, "known-good R1 magnitude")


func test_defaults_are_d35() -> void:
	var t: Node = autofree(load("res://autoload/Tuning.gd").new())
	add_child(t)
	assert_eq(t.field.bodies.size(), 1, "single planet, no moons")
	var pl: BodyParams = t.field.bodies[0]
	assert_eq(pl.p, 2.0)
	assert_eq(pl.parent, -1)
	assert_almost_eq(pl.mass, pow(0.00255, 2.0) * pow(121500.0, 3.0) / 1000.0, 1.0)
	assert_eq(t.field.k, 1000.0)
	assert_eq(t.field.planet_surface_radius, 100000.0)
	assert_eq(t.field.atmosphere_edge, 101500.0)
	assert_eq(t.field.carrier_orbit_radius, 121500.0)
	Tuning.field = t.field
	assert_almost_eq(GravityField.frame_omega(), 0.00255, 1e-6, "frame omega on defaults")
