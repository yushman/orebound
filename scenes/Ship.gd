extends CharacterBody2D

var state := ShipState.new()
var input := ShipInput.new()
var _jettison_press := LongPress.new()
var _transfer_press := LongPress.new()
var _tow_press := LongPress.new()
var warp_k := 1.0
var _approach_real := 0.0
var tow_left := -1.0
var tow_notice := ""
var tow_notice_left := 0.0
var tow_share_preview := 0.0
var tow_holding := false
var violation := ""
var violation_ticks := 0

const TOW_NOTICE_TIME := 2.0

enum Phase { FLYING, ENDED }

var phase := Phase.FLYING
var flight_start_t := 0.0

signal respawned
signal flight_ended(summary: Dictionary)


func _ready() -> void:
	Telemetry.ship = self
	Telemetry.open = false
	respawn()
	Tuning.preset_applied.connect(respawn)


func _exit_tree() -> void:
	_apply_warp(false)
	if Telemetry.ship == self:
		Telemetry.ship = null


func respawn() -> void:
	if phase == Phase.FLYING and Telemetry.open and Telemetry.flight_time >= Telemetry.RESET_MIN_TIME:
		Telemetry.end_flight(FlightSummary.build(state, "reset", Telemetry.flight_time, {}, Telemetry.real_time))
	_apply_warp(false)
	state = ShipState.new()
	phase = Phase.FLYING
	flight_start_t = GravityField.time()
	_jettison_press = LongPress.new()
	_transfer_press = LongPress.new()
	_tow_press = LongPress.new()
	_approach_real = 0.0
	tow_left = -1.0
	tow_notice = ""
	tow_notice_left = 0.0
	tow_share_preview = 0.0
	tow_holding = false
	violation = ""
	violation_ticks = 0
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
	Telemetry.begin_flight()
	respawned.emit()


func _physics_process(_delta: float) -> void:
	if phase == Phase.ENDED:
		_apply_warp(false)
		input = ShipInput.new()
		if state.docked:
			var t := GravityField.time()
			state.pos = ShipFlight.carrier_pos(t)
			state.vel = ShipFlight.carrier_vel(t)
			move_and_collide(state.pos - position)
		return
	var report := {}
	var was_docked := state.docked
	input = ShipInput.new() if state.docked else _read_input()
	_apply_warp(not state.docked)
	state = ShipFlight.step(state, input, GravityField.time(), GravityField.DT, null, report)
	_approach_real = _approach_real + TimeWarp.real_step(warp_k) if state.approach_time > 0.0 else 0.0
	if state.docked and not was_docked:
		Telemetry.docking_time = state.approach_time
		Telemetry.docking_real_time = _approach_real
		if Telemetry.flight_log:
			print("FLOG docked t=%.2f docking_time=%.2f" % [GravityField.time(), state.approach_time])
	if report.get("transferred", false):
		Telemetry.transfers += 1
	Telemetry.sample(state, input, report, warp_k)
	move_and_collide(state.pos - position)
	rotation = state.rot
	tow_notice_left = maxf(tow_notice_left - GravityField.DT, 0.0)
	if state.crashed or state.docked:
		if state.crashed:
			Telemetry.crashes += 1
		tow_left = -1.0
		tow_holding = false
		_end("crashed" if state.crashed else "returned")
		return
	var v := Tow.violation(state.pos, Tuning.ship.service_boat)
	if v != violation:
		violation = v
		violation_ticks = 0
	if v != "":
		violation_ticks += 1
		tow_share_preview = 1.0 if v == "boundary" else Tow.seized_share(state)
		if violation_ticks >= _violation_need():
			var forced := v == "boundary"
			var paid := Tow.pay(state, forced)
			paid["kind"] = "forced" if forced else "ceiling"
			Telemetry.tow_fee = paid["fee"]
			Telemetry.tow_seized_share = paid["share"]
			if forced:
				Telemetry.forced_tows += 1
			else:
				Telemetry.ceiling_tows += 1
			tow_left = -1.0
			tow_holding = false
			violation = ""
			violation_ticks = 0
			_end("towed", paid)
			return
	if tow_left >= 0.0:
		var reason := Tow.refusal(state.pos)
		if reason != "":
			tow_left = -1.0
			_notice(reason)
		else:
			tow_left -= GravityField.DT
			if tow_left <= 0.0:
				tow_left = -1.0
				tow_share_preview = Tow.seized_share(state)
				var paid := Tow.pay(state)
				paid["kind"] = "manual"
				Telemetry.tow_fee = paid["fee"]
				Telemetry.tow_seized_share = paid["share"]
				tow_holding = false
				_end("towed", paid)
				return
	tow_holding = Input.is_action_pressed("ship_tow")
	if tow_holding or tow_left >= 0.0:
		tow_share_preview = Tow.seized_share(state)


func _apply_warp(flying: bool) -> void:
	var p := Tuning.ship
	var held := Input.is_action_pressed("ship_boost")
	var ticks := TimeWarp.ticks_per_second(p.time_warp, held, flying, p.time_warp_mult)
	warp_k = TimeWarp.factor(ticks)
	Engine.physics_ticks_per_second = ticks
	Engine.max_physics_steps_per_frame = TimeWarp.max_steps(ticks)


func _violation_need() -> int:
	return ceili(Tuning.planet.violation_time / GravityField.DT)


func violation_left() -> float:
	if violation == "":
		return -1.0
	return maxi(_violation_need() - violation_ticks, 0) * GravityField.DT


func _end(outcome: String, tow := {}) -> void:
	phase = Phase.ENDED
	input = ShipInput.new()
	var summary := FlightSummary.build(state, outcome, GravityField.time() - flight_start_t, tow, Telemetry.real_time)
	Telemetry.end_flight(summary)
	flight_ended.emit(summary)


func _notice(text: String) -> void:
	tow_notice = text
	tow_notice_left = TOW_NOTICE_TIME


func _read_tow() -> void:
	_tow_press.tap_time = Tuning.ship.jettison_tap_time
	_tow_press.hold_time = Tuning.ship.tow_hold_time
	match _tow_press.update(Input.is_action_pressed("ship_tow"), TimeWarp.real_step(warp_k)):
		LongPress.Event.FIRE:
			if tow_left >= 0.0:
				return
			var reason := Tow.refusal(state.pos)
			if reason != "":
				_notice(reason)
			else:
				tow_left = Tuning.planet.tow_delay
				Telemetry.tow_calls += 1
		LongPress.Event.CANCEL:
			Telemetry.tow_cancelled += 1


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
	inp.boost = Input.is_action_pressed("ship_boost") and not Tuning.ship.time_warp
	inp.soft_brake = Input.is_action_pressed("ship_brake")
	inp.drift_sync = Input.is_action_pressed("ship_drift_sync")
	_jettison_press.tap_time = Tuning.ship.jettison_tap_time
	_jettison_press.hold_time = Tuning.ship.jettison_hold_time
	_jettison_press.interval = Tuning.ship.jettison_interval
	match _jettison_press.update(Input.is_action_pressed("ship_jettison"), TimeWarp.real_step(warp_k)):
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
	if _transfer_press.update(Input.is_action_pressed("ship_transfer"), TimeWarp.real_step(warp_k)) == LongPress.Event.FIRE:
		inp.transfer = true
	_read_tow()
	return inp
