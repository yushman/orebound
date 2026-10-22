extends Node2D

const RADIUS := 40.0

@onready var ship: Node2D = get_node("../Ship")


func _physics_process(_delta: float) -> void:
	var t := GravityField.time()
	position = GravityField.body_pos(ShipFlight.reference_body(ship.state.pos, t), t)
	queue_redraw()


func _draw() -> void:
	var alpha := 1.0 if ship.input.brake else 0.35
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, alpha), 2.0)
