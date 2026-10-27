extends Node

const LOG_PERIOD := 1.0

var crashes: int = 0
var seed: int = 1
var flight: int = 1
var flight_log := "--flight-log" in OS.get_cmdline_user_args()
var _ship: Node
var _since := 0.0
var _last_cells := -1


func _physics_process(delta: float) -> void:
	if not flight_log:
		return
	if _ship == null:
		_ship = get_tree().current_scene.get_node_or_null("Ship") if get_tree().current_scene != null else null
		if _ship == null:
			return
		_ship.respawned.connect(func() -> void: print("FLOG respawn t=%.2f crashes=%d" % [GravityField.time(), crashes]))
	var s: ShipState = _ship.state
	_since += delta
	var cells := s.hold.size() * 100 + s.tank.size()
	if _since < LOG_PERIOD and cells == _last_cells:
		return
	_since = 0.0
	_last_cells = cells
	var hold := []
	for c in s.hold:
		hold.append("%s:%.2f" % [c.type, c.fill])
	print("FLOG t=%.2f r=%.0f v=%.1f energy=%.3f tank=%d mass=%.2f hull=%.1f need=%.3f burn[eng=%.3f boost=%.3f brake=%.3f sync=%.3f] hold=[%s]" % [
		GravityField.time(), s.pos.length(), s.vel.length(), Hold.energy(s), s.tank.size(), Hold.mass(s), s.hull,
		Fuel.climb_energy(s.pos.length(), s.vel.length(), Hold.mass(s)),
		s.fuel_engine, s.fuel_boost, s.fuel_soft_brake, s.fuel_sync, ", ".join(hold)])
