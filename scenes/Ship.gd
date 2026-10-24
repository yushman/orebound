extends CharacterBody2D

var state := ShipState.new()
var input := ShipInput.new()


func _ready() -> void:
	respawn()
	Tuning.preset_applied.connect(respawn)


func respawn() -> void:
	state = ShipState.new()
	# The carrier is a fixed point of the rotating frame, so rest there is stable.
	var pos := Vector2(Tuning.field.carrier_orbit_radius, 0.0)
	state.pos = pos
	state.vel = Vector2.ZERO
	state.rot = FlightCamera.rotation_for(pos)
	position = pos
	rotation = state.rot


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
		inp.target_heading = ShipInput.screen_heading(stick, state.pos)
	inp.thrust = Input.is_action_pressed("ship_thrust")
	inp.boost = Input.is_action_pressed("ship_boost")
	inp.soft_brake = Input.is_action_pressed("ship_brake")
	inp.drift_sync = Input.is_action_pressed("ship_drift_sync")
	return inp
