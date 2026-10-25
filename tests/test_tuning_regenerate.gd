extends GutTest

var _saved_field
var _saved_seed
var _saved_flight
var _saved_count := 0
var _emitted := 0


func before_each():
	_saved_field = Tuning.field
	_saved_count = _saved_field.bodies.size()
	Tuning.field = _saved_field.duplicate(true)
	_saved_seed = Telemetry.get("seed")
	_saved_flight = Telemetry.get("flight")
	_emitted = 0


func after_each():
	Tuning.field = _saved_field
	Telemetry.set("seed", _saved_seed)
	Telemetry.set("flight", _saved_flight)
	assert_eq(Tuning.field.bodies.size(), _saved_count, "regenerate leaked moons into the shared field")


func _count():
	_emitted += 1


func test_telemetry_defaults():
	assert_eq(Telemetry.get("seed"), 1)
	assert_eq(Telemetry.get("flight"), 1)


func test_regenerate_replaces_moons_keeps_planet_and_emits_once():
	var planet: BodyParams = Tuning.field.bodies[0]
	Tuning.preset_applied.connect(_count)
	Tuning.regenerate(3, 1)
	Tuning.preset_applied.disconnect(_count)
	var pic: Dictionary = WellGenerator.picture(3, 1)
	assert_eq(_emitted, 1)
	assert_same(Tuning.field.bodies[0], planet)
	assert_eq(Tuning.field.bodies.size(), 1 + pic["moons"].size())
	assert_eq(Tuning.field.bodies[1].orbit_radius, pic["moons"][0].orbit_radius)
	assert_eq(Telemetry.get("seed"), pic["seed"])
	assert_eq(Telemetry.get("flight"), 1)


func test_regenerate_twice_does_not_accumulate_moons():
	Tuning.regenerate(3, 1)
	var n := Tuning.field.bodies.size()
	Tuning.regenerate(4, 1)
	assert_between(Tuning.field.bodies.size(), 3, 4)
	assert_lte(n, 4)


func test_gravity_field_follows_generated_moon():
	Tuning.regenerate(3, 1)
	var m: BodyParams = Tuning.field.bodies[1]
	var t := 2.0
	var a := m.phase + (m.angular_speed - GravityField.frame_omega()) * t
	assert_almost_eq(GravityField.body_pos(1, t), Vector2(cos(a), sin(a)) * m.orbit_radius, Vector2(1e-6, 1e-6))


func test_save_after_regenerate_keeps_preset_planet_only():
	Tuning.regenerate(3, 1)
	assert_gt(Tuning.field.bodies.size(), 1)
	var path := "user://regen_save_test.tres"
	assert_eq(Tuning.save_preset(path, "T"), OK)
	var loaded := Tuning.load_preset(path)
	DirAccess.remove_absolute(path)
	assert_eq(loaded.field.bodies.size(), 1)
	assert_gt(Tuning.field.bodies.size(), 1, "save must not touch the live field")
