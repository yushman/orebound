extends Node2D


func _ready() -> void:
	Tuning.regenerate(Telemetry.seed, Telemetry.flight)
