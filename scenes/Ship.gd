extends CharacterBody2D

var state := ShipState.new()
var input := ShipInput.new()
var _jettison_press := LongPress.new()
var _transfer_press := LongPress.new()

signal respawned


func _ready() -> void:
	respawn()
	Tuning.preset_applied.connect(respawn)


func respawn() -> void:
	state = ShipState.new()
	_jettison_press = LongPress.new()
	_transfer_press = LongPress.new()
	# Spawn on the carrier nose-down: the nose points at the planet and the
	# velocity is the carrier's motion plus the descend speed toward it
	# (co-moving with the patrolling матка AND descending).
	var t := GravityField.time()
	var pos := ShipFlight.carrier_pos(t)
	var planet_dir := (Vector2.ZERO - pos).normalized()
	state.pos = pos
	state.vel = ShipFlight.carrier_vel(t) + Tuning.ship.spawn_descend_speed * planet_dir
	state.rot = wrapf(planet_dir.angle() + PI / 2.0, -PI, PI)
	state.hull = Tuning.ship.hull_max
	position = pos
	rotation = state.rot
	respawned.emit()


func _physics_process(_delta: float) -> void:
	var report := {}
	input = _read_input()
	state = ShipFlight.step(state, input, GravityField.time(), GravityField.DT, null, report)
	if report["transferred"]:
		Telemetry.transfers += 1
	if state.crashed:
		Telemetry.crashes += 1
		respawn()
		return
	move_and_collide(state.pos - position)
	rotation = state.rot


func _read_input() -> ShipInput:
	var inp := ShipInput.new()
	inp.turn = Input.get_axis("ship_rotate_left", "ship_rotate_right")
	var stick := Input.get_vector("ship_heading_left", "ship_heading_right", "ship_heading_up", "ship_heading_down")
	if stick != Vector2.ZERO:
		inp.has_heading = true
		inp.target_heading = ShipInput.screen_heading(stick, state.pos)
	var beam_stick := Input.get_vector("ship_aim_left", "ship_aim_right", "ship_aim_up", "ship_aim_down")
	var mouse_held := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	inp.beam = Input.is_action_pressed("ship_beam")
	inp.collect = Input.is_action_pressed("ship_collect")
	inp.aim = ShipInput.aim_angle(beam_stick, mouse_held, get_global_mouse_position(), state.pos, state.rot)
	inp.thrust = Input.is_action_pressed("ship_thrust")
	inp.boost = Input.is_action_pressed("ship_boost")
	inp.soft_brake = Input.is_action_pressed("ship_brake")
	inp.drift_sync = Input.is_action_pressed("ship_drift_sync")
	_jettison_press.tap_time = Tuning.ship.jettison_tap_time
	_jettison_press.hold_time = Tuning.ship.jettison_hold_time
	_jettison_press.interval = Tuning.ship.jettison_interval
	match _jettison_press.update(Input.is_action_pressed("ship_jettison"), GravityField.DT):
		LongPress.Event.TAP:
			inp.jettison_select = true
			if not state.hold.is_empty():
				Telemetry.jettison_selects += 1
		LongPress.Event.FIRE:
			inp.jettison = true
			if not state.hold.is_empty():
				Telemetry.jettisons += 1
		LongPress.Event.CANCEL:
			Telemetry.jettison_cancelled += 1
	_transfer_press.tap_time = Tuning.ship.jettison_tap_time
	_transfer_press.hold_time = Tuning.ship.transfer_hold_time
	_transfer_press.interval = Tuning.ship.transfer_interval
	if _transfer_press.update(Input.is_action_pressed("ship_transfer"), GravityField.DT) == LongPress.Event.FIRE:
		inp.transfer = true
	return inp
