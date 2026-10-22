extends CharacterBody2D

var state := ShipState.new()
var input := ShipInput.new()


func _ready() -> void:
	var pos := Vector2(Tuning.ship.spawn_radius, 0.0)
	var t := GravityField.time()
	state.pos = pos
	state.vel = Vector2(0.0, GravityField.circular_speed(GravityField.dominant(pos, t), pos, t))
	position = pos


func _physics_process(_delta: float) -> void:
	input = _read_input()
	state = ShipFlight.step(state, input, GravityField.time(), GravityField.DT)
	move_and_collide(state.pos - position)
	rotation = state.rot


func _read_input() -> ShipInput:
	var inp := ShipInput.new()
	inp.turn = Input.get_axis("ship_rotate_left", "ship_rotate_right")
	var stick := Input.get_vector("ship_heading_left", "ship_heading_right", "ship_heading_up", "ship_heading_down")
	if stick != Vector2.ZERO:
		inp.has_heading = true
		inp.target_heading = stick.angle() + PI / 2
	inp.thrust = Input.is_action_pressed("ship_thrust")
	inp.boost = Input.is_action_pressed("ship_boost")
	inp.brake = Input.is_action_pressed("ship_brake")
	return inp
