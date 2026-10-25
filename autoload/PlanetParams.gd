class_name PlanetParams
extends Resource

@export var tier_shares: Array[float] = [0.25, 0.40, 0.25, 0.10]
@export var ceiling_offset: float = 5000.0
@export var moon_count_min: int = 2
@export var moon_count_max: int = 3
@export var moon_large_radius_min: float = 1000.0
@export var moon_large_radius_max: float = 2000.0
@export var moon_small_radius_min: float = 300.0
@export var moon_small_radius_max: float = 700.0
@export var ring_tier: int = 2
@export var ring_width: float = 1500.0
@export var ring_density: float = 0.5
@export var atmosphere_drag: float = 0.5
@export var atmosphere_damage: float = 5.0
@export var density_shape: float = 2.0
@export var moon_mass_k: float = 0.001032
@export var moon_mass_exp: float = 1.79
@export var moon_influence_k: float = 1.2
@export var moon_margin: float = 100.0
@export var max_tries: int = 8
@export var fallback_seed: int = 1
@export var moon_bounce: float = 0.5
@export var moon_impact_damage: float = 0.05
