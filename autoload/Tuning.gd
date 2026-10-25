extends Node

signal preset_applied

var field: FieldParams = _default_field()
var ship: ShipParams = ShipParams.new()
var planet: PlanetParams = _default_planet()
var view: ViewParams = ViewParams.new()


func apply(preset: TuningPreset) -> void:
	field = preset.field.duplicate(true)
	ship = preset.ship.duplicate(true)
	preset_applied.emit()


func regenerate(seed: int, flight: int) -> void:
	var pic := WellGenerator.picture(seed, flight)
	var bodies: Array[BodyParams] = [field.bodies[0]]
	bodies.append_array(pic["moons"])
	field.bodies = bodies
	Telemetry.seed = pic["seed"]
	Telemetry.flight = pic["flight"]
	preset_applied.emit()


func save_preset(path: String, preset_name: String) -> Error:
	var preset := TuningPreset.new()
	preset.name = preset_name
	preset.field = field.duplicate(true)
	preset.field.bodies = [preset.field.bodies[0]]
	preset.ship = ship.duplicate(true)
	return ResourceSaver.save(preset, path)


func load_preset(path: String) -> TuningPreset:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningPreset


func _default_field() -> FieldParams:
	# D35 defaults: single planet at the origin; mu = frame_omega^2 * r_c^3
	# with frame_omega = 0.00255 and r_c = 121500, mass = mu / k.
	var f := FieldParams.new()
	f.k = 1000.0
	f.eps = 1.0
	f.fade_width = 0.5
	f.planet_surface_radius = 100000.0
	f.atmosphere_edge = 101500.0
	f.carrier_orbit_radius = 121500.0
	var planet := BodyParams.new()
	planet.p = 2.0
	planet.mass = pow(0.00255, 2.0) * pow(121500.0, 3.0) / f.k
	f.bodies = [planet]
	return f


func _default_planet() -> PlanetParams:
	return PlanetParams.new()
