extends Node2D

@export var index: int = 0

@onready var _visual: Node2D = $Visual


func _physics_process(_delta: float) -> void:
	visible = index < Tuning.field.bodies.size()
	if visible:
		position = GravityField.body_pos(index, GravityField.time())


func _process(_delta: float) -> void:
	var vp := get_viewport()
	var cam := vp.get_camera_2d() if vp != null else null
	var s := 1.0 / cam.zoom.x if cam != null else 1.0
	_visual.scale = Vector2(s, s)
