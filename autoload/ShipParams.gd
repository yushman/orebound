class_name ShipParams
extends Resource

@export var thrust_accel: float = 600.0
@export var boost_accel_mult: float = 2.5
@export var turn_accel: float = 12.0
@export var spin_damping: float = 4.0
@export var heading_gain: float = 30.0
@export var fuel_per_dv: float = 0.001
@export var boost_fuel_mult: float = 3.5
@export var spawn_radius: float = 600.0
@export var brake_accel: float = 200.0
@export var brake_fuel_mult: float = 1.25
@export var predict_short_steps: int = 180
@export var predict_full_steps: int = 1800
@export var predict_every: int = 4
