extends GutTest

# Headless-прокси точности float32 в масштабе D35 при r ≈ 1.2e5: покой у матки
# и дрейф у дна на 180 с (10 800 шагов по 1/60). Поле строится по калибровочному
# рецепту R1: μ = Ω_f²·r_c³ при Ω_f = 0.00255, r_c = 121 500 (декомпозировано
# через k = 1000 и p = 2), дно атмосферы 101 500 с дрейфом ≈ 80.

const DT := 1.0 / 60.0
const STEPS := 10800
const CARRIER_RADIUS := 121500.0
const BOTTOM_RADIUS := 101500.0
const OMEGA_F := 0.00255

var _saved_field
var _saved_planet_small


func before_each() -> void:
	_saved_field = Tuning.field
	_saved_planet_small = Tuning.planet
	Tuning.planet = Tuning.planet.duplicate()


func after_each() -> void:
	Tuning.field = _saved_field
	Tuning.planet = _saved_planet_small


func _d35_field() -> FieldParams:
	var f := FieldParams.new()
	f.k = 1000.0
	f.eps = 1.0
	f.planet_surface_radius = 100000.0
	f.atmosphere_edge = BOTTOM_RADIUS
	f.carrier_orbit_radius = CARRIER_RADIUS
	var planet := BodyParams.new()
	planet.mass = pow(CARRIER_RADIUS, 3.0) * OMEGA_F * OMEGA_F / f.k
	planet.p = 2.0
	var bodies: Array[BodyParams] = [planet]
	f.bodies = bodies
	return f


func test_rest_at_carrier_holds_over_minutes() -> void:
	Tuning.field = _d35_field()
	# рецепт R1: из массы выводится именно Ω_f ≈ 0.00255
	assert_almost_eq(GravityField.frame_omega(), OMEGA_F, 1e-6)
	var carrier := Vector2(CARRIER_RADIUS, 0.0)
	var s := ShipState.new()
	s.pos = carrier
	var max_dev := 0.0
	for i in STEPS:
		s = ShipFlight.step(s, ShipInput.new(), i * DT, DT)
		max_dev = maxf(max_dev, s.pos.distance_to(carrier))
	# остаточная тяга от ε=1 и округления float32 (ulp ≈ 0.016 при r ≈ 1.2e5)
	# дают дрейф много меньше единицы: допуск 1 ед. ≈ 64 ulp («единицы, не десятки»)
	assert_lt(max_dev, 1.0)
	assert_lt(s.vel.length(), 0.01)


func test_band_drift_at_bottom_holds_altitude() -> void:
	Tuning.field = _d35_field()
	var s := ShipState.new()
	s.pos = Vector2(BOTTOM_RADIUS, 0.0)
	s.vel = Vector2(0.0, 80.0)
	var max_dev := 0.0
	for i in STEPS:
		s = ShipFlight.step(s, ShipInput.new(), i * DT, DT)
		max_dev = maxf(max_dev, absf(s.pos.length() - BOTTOM_RADIUS) / BOTTOM_RADIUS)
	# v = 80 отличается от точного дрейфа полосы (~80.15) на эпицикл ~50 ед.
	# ≈ 0.05% радиуса; процентный допуск оставляет запас на вековой дрейф Кориолиса
	assert_lt(max_dev, 0.01)
