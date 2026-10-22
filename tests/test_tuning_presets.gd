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
	s.fuel_per_dv = 0.5
	s.boost_fuel_mult = 2.0
	s.spawn_radius = 321.0
	s.brake_accel = 77.0
	s.brake_fuel_mult = 1.1
	s.predict_short_steps = 11
	s.predict_full_steps = 22
	s.predict_every = 3
	Tuning.field = f
	Tuning.ship = s
	assert_eq(Tuning.save_preset(TMP, "X"), OK)
	var loaded: TuningPreset = Tuning.load_preset(TMP)
	assert_not_null(loaded)
	if loaded == null:
		return
	assert_eq(loaded.name, "X")
	_assert_field_eq(loaded.field, f)
	_assert_ship_eq(loaded.ship, s)


func _preset_with(n_bodies: int) -> TuningPreset:
	var pr := TuningPreset.new()
	pr.field = Tuning._default_field()
	pr.field.k = 42.0
	pr.field.bodies.resize(n_bodies)
	pr.ship = ShipParams.new()
	pr.ship.thrust_accel = 99.0
	return pr


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


func test_apply_rejects_body_count_mismatch() -> void:
	var f := Tuning.field
	var s := Tuning.ship
	watch_signals(Tuning)
	Tuning.apply(_preset_with(2))
	assert_push_error_count(1)
	assert_same(Tuning.field, f)
	assert_same(Tuning.ship, s)
	assert_signal_not_emitted(Tuning, "preset_applied")


const PRESET_P := {1: [2.0, 2.0, 2.0], 2: [1.0, 1.0, 1.0], 3: [1.5, 1.5, 1.5], 4: [1.0, 2.0, 2.0]}


func _load_n(n: int) -> TuningPreset:
	return Tuning.load_preset("res://presets/p%d.tres" % n)


func test_preset_p_values() -> void:
	for n in PRESET_P:
		var pr := _load_n(n)
		assert_not_null(pr, "p%d" % n)
		if pr == null:
			continue
		for i in 3:
			assert_eq(pr.field.bodies[i].p, PRESET_P[n][i], "p%d body %d" % [n, i])


func test_preset_common_params() -> void:
	var d := Tuning._default_field()
	for n in PRESET_P:
		var pr := _load_n(n)
		if pr == null:
			fail_test("p%d missing" % n)
			continue
		assert_eq(pr.field.k, 1000.0)
		assert_eq(pr.field.eps, 1.0)
		assert_eq(pr.field.fade_width, 0.5)
		_assert_ship_eq(pr.ship, ShipParams.new())
		for i in 3:
			var b := pr.field.bodies[i]
			var e := d.bodies[i]
			assert_eq(b.parent, e.parent)
			assert_eq(b.orbit_radius, e.orbit_radius)
			assert_eq(b.angular_speed, e.angular_speed)
			assert_eq(b.phase, e.phase)
			assert_eq(b.influence_radius, 80.0 if i > 0 else 0.0)


func test_preset_masses_comparable() -> void:
	var r := 600.0
	var ref := 1000.0 * 1000.0 * r / (r + 1.0)
	for n in PRESET_P:
		var pr := _load_n(n)
		if pr == null:
			fail_test("p%d missing" % n)
			continue
		var f := pr.field
		var pl := f.bodies[0]
		var v2 := f.k * pl.mass * r / (pow(r, pl.p) + f.eps)
		assert_almost_eq(v2 / ref, 1.0, 0.002, "p%d planet speed" % n)
		for i in [1, 2]:
			var m := f.bodies[i]
			var g := f.k * pl.mass / (pow(m.orbit_radius, pl.p) + f.eps)
			var want := g * (pow(40.0, m.p) + f.eps) / f.k
			assert_almost_eq(m.mass / want, 1.0, 0.01, "p%d moon %d mass" % [n, i])


func test_fresh_tuning_holds_p4() -> void:
	var t: Node = autofree(load("res://autoload/Tuning.gd").new())
	add_child(t)
	var p4 := _load_n(4)
	_assert_field_eq(t.field, p4.field)
	_assert_ship_eq(t.ship, p4.ship)
