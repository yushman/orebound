extends GutTest

var _saved_field: FieldParams


func before_each() -> void:
	_saved_field = Tuning.field


func after_each() -> void:
	Tuning.field = _saved_field
	GravityField.tick = 0


func _field_with_moon() -> FieldParams:
	var f := FieldParams.new()
	f.k = 1000.0
	f.eps = 1.0
	f.carrier_orbit_radius = 500.0
	var planet := BodyParams.new()
	planet.mass = 1000.0
	planet.p = 1.0
	var moon := BodyParams.new()
	moon.mass = 100000.0
	moon.p = 2.0
	moon.parent = 0
	moon.orbit_radius = 480.0
	moon.angular_speed = 0.1
	var bodies: Array[BodyParams] = [planet, moon]
	f.bodies = bodies
	return f


func test_body_follows_field_position() -> void:
	Tuning.field = _field_with_moon()
	var body = load("res://scenes/Body.tscn").instantiate()
	body.index = 1
	add_child_autofree(body)
	GravityField.tick = 90
	body._physics_process(0.0)
	var t := GravityField.time()
	var expected := GravityField.body_pos(1, t)
	assert_ne(expected, Vector2.ZERO)
	assert_eq(body.position, expected)
	# same point from the orbit formula: phase + (angular_speed - frame_omega)*t
	var a := (0.1 - GravityField.frame_omega()) * t
	assert_eq(body.position, Vector2(cos(a), sin(a)) * 480.0)


func test_visual_scale_keeps_constant_screen_size() -> void:
	var BodyScript = load("res://scenes/Body.gd")
	assert_almost_eq(BodyScript.visual_scale(0, 1.0), 1.0, 1e-9)
	assert_almost_eq(BodyScript.visual_scale(0, 40.0), 40.0, 1e-9)
	# moons use a smaller marker than the planet, still scaled by s
	assert_almost_eq(BodyScript.visual_scale(1, 40.0), 40.0 * BodyScript.MOON_SCALE, 1e-9)
	assert_lt(BodyScript.MOON_SCALE, 1.0)
