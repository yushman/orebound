extends Node2D

@export var index: int = 0


func _physics_process(_delta: float) -> void:
	position = GravityField.body_pos(index, GravityField.time())
