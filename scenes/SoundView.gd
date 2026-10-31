class_name SoundView
extends Node

const HUD_SCRIPT := preload("res://ui/HUD.gd")
const GAIN := {&"engine": 0.6, &"rough": 0.4, &"boost": 0.5, &"hiss": 0.3, &"tone": 0.15}
const TONE_LEVEL := 1.0
const MIN_DB := -80.0

var played := {}
var levels := {}
var players := {}
var _ship: Node
var _prev_heat := 0.0
var _prev_docked := false
var _mode := &""
var _beat_ticks := 0
var _crack_ticks := 0


func _ready() -> void:
	for n in SoundBank.LOOPS:
		levels[n] = 0.0
		players[n] = _player(n)
		players[n].volume_db = MIN_DB
		players[n].play()
	for n in SoundBank.SHOTS:
		players[n] = _player(n)
	_ship = get_node_or_null("../Ship")
	if _ship != null:
		_ship.respawned.connect(_reset)
	var warnings := get_node_or_null("../CanvasLayer/Warnings")
	if warnings != null:
		warnings.warning_shown.connect(func(type: StringName) -> void: play(SoundModel.cue_for(type), type))
	_apply_volume()


func _player(n: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = SoundBank.stream(n)
	add_child(p)
	return p


func play(n: StringName, label := &"") -> void:
	played[n] = played.get(n, 0) + 1
	if players.has(n):
		players[n].play()
	if Telemetry.flight_log:
		print("FLOG sound %s%s t=%.2f" % [n, "" if label == &"" else " (%s)" % label, GravityField.time()])


func _reset() -> void:
	_prev_heat = 0.0
	_prev_docked = false
	_mode = &""
	_beat_ticks = 0
	_crack_ticks = 0


func _apply_volume() -> void:
	var v: float = Tuning.view.volume
	AudioServer.set_bus_volume_db(0, linear_to_db(v) if v > 0.0 else MIN_DB)
	AudioServer.set_bus_mute(0, v <= 0.0)


func _set_level(n: StringName, v: float) -> void:
	levels[n] = v
	players[n].volume_db = maxf(linear_to_db(v * GAIN[n]), MIN_DB) if v > 0.0 else MIN_DB


func _silence() -> void:
	for n in SoundBank.LOOPS:
		_set_level(n, 0.0)


func _physics_process(_delta: float) -> void:
	_apply_volume()
	if _ship == null:
		_silence()
		return
	var s: ShipState = _ship.state
	if s.docked and not _prev_docked:
		play(&"chord")
	_prev_docked = s.docked
	if s.docked or _ship.phase == _ship.Phase.ENDED:
		_silence()
		_prev_heat = s.heat
		return
	var level := SoundModel.thrust_level(s, _ship.input)
	var engine := SoundModel.engine_volume(level)
	_set_level(&"engine", engine)
	players[&"engine"].pitch_scale = SoundModel.engine_pitch(Hold.mass(s), level)
	_set_level(&"rough", SoundModel.rough_mix(s.heat) * engine)
	_set_level(&"boost", 1.0 if SoundModel.boost_on(_ship.input, level) else 0.0)
	var density := ShipFlight.atmosphere_density(s.pos)
	_set_level(&"hiss", SoundModel.hiss_volume(density))
	if SoundModel.heat_click(_prev_heat, s.heat):
		play(&"click", &"heat")
	_prev_heat = s.heat
	if Tuning.planet.atmosphere_damage * density > 0.0:
		if SoundModel.crack_due(_crack_ticks):
			play(&"click", &"crack")
		_crack_ticks += 1
	else:
		_crack_ticks = 0
	var mode := SoundModel.reserve_mode(HUD_SCRIPT.ship_reserve(s))
	if mode != _mode:
		_mode = mode
		_beat_ticks = 0
		if Telemetry.flight_log:
			print("FLOG sound reserve_mode=%s t=%.2f" % [mode, GravityField.time()])
	_set_level(&"tone", TONE_LEVEL if mode == &"tone" else 0.0)
	if SoundModel.reserve_beat(mode, _beat_ticks):
		play(mode, &"reserve")
	_beat_ticks += 1
