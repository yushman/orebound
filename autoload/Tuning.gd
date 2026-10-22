extends Node

signal preset_applied

var field: FieldParams = _default_field()
var ship: ShipParams = ShipParams.new()


func _ready() -> void:
	var path := "res://presets/p4.tres"
	var preset := load_preset(path) if ResourceLoader.exists(path) else null
	if preset == null:
		push_warning("Tuning: %s missing, using code defaults" % path)
		return
	apply(preset)


func apply(preset: TuningPreset) -> void:
	if preset.field.bodies.size() != field.bodies.size():
		push_error("Tuning.apply: preset has %d bodies, expected %d" % [preset.field.bodies.size(), field.bodies.size()])
		return
	field = preset.field.duplicate(true)
	ship = preset.ship.duplicate(true)
	preset_applied.emit()


func save_preset(path: String, preset_name: String) -> Error:
	var preset := TuningPreset.new()
	preset.name = preset_name
	preset.field = field.duplicate(true)
	preset.ship = ship.duplicate(true)
	return ResourceSaver.save(preset, path)


func load_preset(path: String) -> TuningPreset:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningPreset


func _default_field() -> FieldParams:
	var f := FieldParams.new()
	f.k = 1000.0
	f.eps = 1.0
	f.fade_width = 0.5
	var planet := BodyParams.new()
	planet.mass = 1000.0
	planet.p = 1.0
	var bodies: Array[BodyParams] = [planet]
	for spec in [[250.0, 0.6, 0.0], [400.0, -0.4, PI]]:
		var m := BodyParams.new()
		m.mass = 100.0
		m.p = 2.0
		m.influence_radius = 80.0
		m.parent = 0
		m.orbit_radius = spec[0]
		m.angular_speed = spec[1]
		m.phase = spec[2]
		bodies.append(m)
	f.bodies = bodies
	return f
