extends GutTest

const RingViewScript := preload("res://scenes/RingView.gd")

var _saved_field
var _saved_planet
var _saved_picture
var _saved_telemetry := {}


func before_each():
	_saved_field = Tuning.field
	_saved_planet = Tuning.planet
	_saved_picture = Tuning.picture
	_saved_telemetry = {"seed": Telemetry.seed, "flight": Telemetry.flight, "crashes": Telemetry.crashes}
	Tuning.planet = PlanetParams.new()


func after_each():
	Tuning.field = _saved_field
	Tuning.planet = _saved_planet
	Tuning.picture = _saved_picture
	Telemetry.seed = _saved_telemetry.seed
	Telemetry.flight = _saved_telemetry.flight
	Telemetry.crashes = _saved_telemetry.crashes


func _ring() -> Dictionary:
	return {"radius": 108000.0, "width": 1500.0, "phase": 0.7}


func _set_picture(ring: Dictionary) -> void:
	Tuning.picture = {"seed": 3, "flight": 1, "moons": [], "ring": ring}


func _instances(v) -> MultiMesh:
	return v.get_node("Particles").multimesh


func test_ring_particles_stay_in_width_and_rotate_with_ring_omega():
	_set_picture(_ring())
	var v = add_child_autofree(RingViewScript.new())
	var mm := _instances(v)
	assert_gt(mm.instance_count, 0)
	assert_eq(mm.instance_count, RingViewScript.particle_count(Tuning.planet.ring_density))
	assert_eq(v.positions.size(), mm.instance_count)
	for p in v.positions:
		var r: float = p.length()
		assert_between(r, 108000.0 - 750.0 - 1.0, 108000.0 + 750.0 + 1.0)
	var t := 123.0
	var want: float = 0.7 + WellGenerator.relative_omega(108000.0) * t
	assert_almost_eq(RingViewScript.rotation_at(_ring(), t), want, 1e-6)
	v.refresh(t)
	assert_almost_eq(v.rotation, want, 1e-6)


func test_ring_view_rebuilds_on_preset_applied_and_hides_without_ring():
	_set_picture({})
	var v = add_child_autofree(RingViewScript.new())
	assert_false(v.visible)
	assert_eq(_instances(v).instance_count, 0)
	_set_picture(_ring())
	assert_false(v.visible, "no rebuild before preset_applied")
	Tuning.preset_applied.emit()
	assert_true(v.visible)
	assert_eq(_instances(v).instance_count, RingViewScript.particle_count(Tuning.planet.ring_density))
	var before: Vector2 = v.positions[0]
	v.refresh(5.0)
	assert_eq(v.positions[0], before, "refresh does not rebuild")
	_set_picture({})
	Tuning.preset_applied.emit()
	assert_false(v.visible)
	assert_eq(_instances(v).instance_count, 0)
