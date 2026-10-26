class_name ShipParams
extends Resource

@export var thrust_accel: float = 9.0
@export var boost_accel_mult: float = 2.5
@export var turn_accel: float = 12.0
@export var spin_damping: float = 4.0
@export var heading_gain: float = 30.0
@export var fuel_per_dv: float = 0.001
@export var boost_fuel_mult: float = 3.5
@export var brake_accel: float = 3.0
@export var brake_fuel_mult: float = 1.0
@export var ramp_time: float = 1.5
@export var ramp_min_fraction: float = 0.15
@export var heat_growth_engine: float = 0.04
@export var heat_growth_boost: float = 0.12
@export var heat_threshold: float = 0.8
@export var heat_cooldown: float = 0.18
@export var min_thrust_fraction: float = 0.2
@export var sync_accel: float = 6.0
@export var sync_fuel_mult: float = 2.0
@export var sync_radius: float = 3000.0
@export var predict_short_steps: int = 900
@export var predict_every: int = 4
@export var hull_max: float = 100.0
